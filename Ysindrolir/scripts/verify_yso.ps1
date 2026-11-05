# One non-mutating verification entrypoint. Tests build only disposable copies.
[CmdletBinding()]
param(
  [string]$SystemRoot=(Split-Path $PSScriptRoot -Parent),
  [ValidateSet('All','Static','Lua','Packages')][string]$Suite='All',
  [string]$OutputDirectory,
  [switch]$SkipReleaseArtifacts
)
$ErrorActionPreference='Stop'
$system=[IO.Path]::GetFullPath($SystemRoot)
$workspace=Split-Path $system -Parent
if(-not $OutputDirectory){$OutputDirectory=Join-Path ([IO.Path]::GetTempPath()) ('yso-verification-'+[guid]::NewGuid())}
$output=[IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($output) | Out-Null
$results=[Collections.Generic.List[object]]::new()
function Result([string]$id,[string]$status,[string]$detail=''){
  $results.Add([pscustomobject]@{id=$id;status=$status;detail=$detail})
  Write-Host ($status.ToUpper()+' '+$id+$(if($detail){' — '+$detail}else{''}))
}
function LuaLiteral([string]$s){
  $equals='===='
  while($s.Contains(']'+$equals+']')){$equals+='='}
  return '['+$equals+'['+$s+']'+$equals+']'
}
function Run([string]$id,[string]$executable,[string[]]$Arguments){
  $log=Join-Path $output (($id -replace '[^a-zA-Z0-9._-]','_')+'.log')
  try {
    $lines=& $executable @Arguments 2>&1
    $code=$LASTEXITCODE
    [IO.File]::WriteAllLines($log,@($lines | ForEach-Object {[string]$_}),[Text.UTF8Encoding]::new($false))
    if($code -eq 0){Result $id 'pass'}else{Result $id 'fail' ('exit '+$code+'; '+$log)}
  } catch {Result $id 'fail' $_.Exception.Message}
}
$started=[datetime]::UtcNow
try {
  if(-not (Test-Path -LiteralPath $system -PathType Container)){throw 'SystemRoot is missing'}
  $lua=(Get-Command lua -ErrorAction Stop).Source
  $luac=(Get-Command luac -ErrorAction Stop).Source
  $pwsh=(Get-Command pwsh -ErrorAction Stop).Source
  $version=& $lua -v 2>&1
  Result 'runtime.lua' 'pass' ([string]($version -join ' '))
  Result 'runtime.luac' 'pass' $luac
  if($Suite -in @('All','Static')){
    $manifestPath=Join-Path $system 'scripts/yso_release_manifest.json'
    try {
      $manifest=Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
      if($manifest.schema_version -ne 1 -or -not $manifest.release_id -or @($manifest.packages).Count -eq 0){throw 'Invalid release manifest'}
      $ids=@($manifest.packages | ForEach-Object {$_.id})
      if(@($ids | Sort-Object -Unique).Count -ne $ids.Count){throw 'Duplicate package IDs'}
      foreach($p in $manifest.packages){
        if(-not $p.name -or -not $p.file -or [IO.Path]::GetFileName($p.file) -cne $p.file){throw 'Unsafe or missing package filename'}
        if(-not (Test-Path -LiteralPath (Join-Path $system ('mudlet packages/'+$p.file)))){throw ('Missing release package '+$p.file)}
        foreach($dependency in $p.depends_on){if($dependency -notin $ids){throw ('Unknown dependency '+$dependency)}}
      }
      Result 'release.manifest' 'pass'
    }catch{Result 'release.manifest' 'fail' $_.Exception.Message}
    $files=@(Get-ChildItem -LiteralPath (Join-Path $system 'mudlet packages') -Filter '*.xml')
    if($files.Count -eq 0){Result 'packages.xml' 'fail' 'No package XMLs found'}
    foreach($file in $files){
      try {
        $doc=[xml][IO.File]::ReadAllText($file.FullName)
        if($doc.DocumentElement.LocalName -cne 'MudletPackage'){throw 'Invalid root element'}
        Result ('xml.'+$file.BaseName) 'pass'
        $chunks=[Collections.Generic.List[string]]::new()
        $chunks.Add('local compile=loadstring or load')
        foreach($body in $doc.SelectNodes('//script')){
          if([string]::IsNullOrWhiteSpace($body.InnerText)){continue}
          $name=$body.ParentNode.SelectSingleNode('name').InnerText
          $chunks.Add('do local ok,err=compile('+(LuaLiteral $body.InnerText)+','+(LuaLiteral ($file.Name+':'+$name))+'); if not ok then io.stderr:write(err.."\n");os.exit(1) end end')
        }
        $compile=Join-Path $output ('syntax-'+$file.BaseName+'.lua')
        [IO.File]::WriteAllLines($compile,$chunks,[Text.UTF8Encoding]::new($false))
        Run ('syntax.'+$file.BaseName) $lua @($compile)
      } catch {Result ('xml.'+$file.BaseName) 'fail' $_.Exception.Message}
    }
    $credentialFiles=@(Get-ChildItem -LiteralPath $system -Recurse -File | Where-Object {
      $_.Extension -in @('.lua','.xml','.json') -and $_.FullName -notmatch '[\\/](?:\.workspace-link-publish|\.verification|releases)[\\/]' -and $_.Name -notlike 'test_*'
    })
    $found=@($credentialFiles | Where-Object {[IO.File]::ReadAllText($_.FullName) -match 'discord(?:app)?\.com/api/webhooks/\d+'})
    if($found.Count){Result 'security.webhooks' 'fail' ('Credentialed webhook URLs found in '+(($found | ForEach-Object {$_.Name}) -join ', '))}else{Result 'security.webhooks' 'pass'}
    $exporter=Join-Path $system 'scripts/export_yso_system_xml.ps1'
    if(Test-Path -LiteralPath $exporter){
      try{
        $source=[IO.File]::ReadAllText($exporter)
        $map=[regex]::Match($source,'(?s)\$ScriptToSourcePath = \[ordered\]@\{(.*?)\r?\n\}').Groups[1].Value
        $dirs=@{YsoDir=(Join-Path $system 'Yso');AlchemistDir=(Join-Path $system 'Alchemist');MagiDir=(Join-Path $system 'Magi');Ysindrolir=$system}
        $doc=[xml][IO.File]::ReadAllText((Join-Path $system 'mudlet packages/Yso system.xml'))
        $count=0
        foreach($m in [regex]::Matches($map,"'(?<name>[^']+)'\s*= Join-Path \`$(?<dir>\w+) '(?<path>[^']+)'")){
          $name=$m.Groups['name'].Value
          $body=$doc.SelectSingleNode("//Script[name='$name']/script")
          if(-not $body){continue} # Historical mappings are not all installed runtime entries.
          $path=Join-Path $dirs[$m.Groups['dir'].Value] $m.Groups['path'].Value
          if($body.InnerText.Replace("`r`n","`n").Trim() -cne [IO.File]::ReadAllText($path).Replace("`r`n","`n").Trim()){throw ('Source/XML drift: '+$name)}
          $count++
        }
        Result 'sources.parity' 'pass' ($count.ToString()+' installed exporter mappings')
      }catch{Result 'sources.parity' 'fail' $_.Exception.Message}
    }
  }
  if($Suite -in @('All','Lua')){
    $covered=@{ 'test_airlord_damage.lua'='test_airlord_damage_package.ps1'; 'test_airlord_lock.lua'='test_airlord_lock_package.ps1'; 'test_package_login_startup.lua'='test_login_safety_package.ps1'; 'test_legacy_network.lua'='test_legacy_security_package.ps1' }
    $paths=@('Yso/Tests and rebuilds','Apostate') | ForEach-Object {Join-Path $system $_} | Where-Object {Test-Path -LiteralPath $_}
    $tests=@(foreach($path in $paths){Get-ChildItem -LiteralPath $path -Filter 'test_*.lua'})
    $fixtureWrappers=@{}
    Push-Location $workspace
    try{
      foreach($test in $tests){
        if($covered.ContainsKey($test.Name)){
          if(-not (Test-Path -LiteralPath (Join-Path $system ('scripts/'+$covered[$test.Name])))){Result ('lua.'+$test.BaseName) 'fail' 'Required package fixture wrapper missing'}
          else{
            Result ('lua.'+$test.BaseName) 'skip' ('Direct invocation replaced by '+$covered[$test.Name])
            $fixtureWrappers[$covered[$test.Name]]=$true
          }
          continue
        }
        $prefix='package.path='+(LuaLiteral ($system.Replace('\','/')+'/?.lua;'+$system.Replace('\','/')+'/?/init.lua;'))+'..package.path;yajl={to_string=function() return nil end}'
        $arguments=@('-e',$prefix,$test.FullName)
        if($test.Name -eq 'test_truelock_emission.lua'){$arguments+=($system.Replace('\','/')+'/')}
        Run ('lua.'+$test.BaseName) $lua $arguments
      }
      if($Suite -eq 'Lua'){
        foreach($wrapper in $fixtureWrappers.Keys | Sort-Object){
          Run ('fixture.'+$wrapper) $pwsh @('-NoProfile','-File',(Join-Path $system ('scripts/'+$wrapper)))
        }
      }
    }finally{Pop-Location}
  }
  if($Suite -in @('All','Packages')){
    foreach($test in Get-ChildItem -LiteralPath (Join-Path $system 'scripts') -Filter 'test_*.ps1' | Sort-Object Name){
      if($SkipReleaseArtifacts -and $test.Name -eq 'test_release_artifacts.ps1'){Result ('package.'+$test.BaseName) 'skip' 'Recursive release-publisher fixture excluded';continue}
      Run ('package.'+$test.BaseName) $pwsh @('-NoProfile','-File',$test.FullName)
    }
  }
}catch{Result 'verification' 'fail' $_.Exception.Message}
$passed=@($results | Where-Object status -eq 'pass').Count
$failed=@($results | Where-Object status -eq 'fail').Count
$skipped=@($results | Where-Object status -eq 'skip').Count
$report=[ordered]@{schema_version=1;started_utc=$started.ToString('o');finished_utc=[datetime]::UtcNow.ToString('o');system_root=$system;passed=$passed;failed=$failed;skipped=$skipped;results=@($results)}
[IO.File]::WriteAllText((Join-Path $output 'results.json'),($report | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
Write-Host ('Verification: '+$passed+' passed, '+$failed+' failed, '+$skipped+' fixture/recursion skips. Report: '+(Join-Path $output 'results.json'))
if($failed){exit 1}
exit 0
