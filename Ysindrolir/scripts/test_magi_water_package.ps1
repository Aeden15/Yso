param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$taskTemp=Join-Path ([IO.Path]::GetTempPath()) ('magi-water-'+[guid]::NewGuid())
function Assert($condition,[string]$message){if(-not $condition){throw $message}}
function Normalize([string]$text){$text.Trim().Replace("`r`n","`n")}
function Mask([string]$text){
  foreach($name in @('Magi water group','Magi resonance feedback')){
    $pattern='(?s)(<Script\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?)<script>.*?</script>'
    $text=[regex]::Replace($text,$pattern,'$1<script>MASKED</script>')
  }
  $text
}
New-Item -ItemType Directory -Path $taskTemp | Out-Null
try{
  $copy=Join-Path $taskTemp 'package.xml'
  Copy-Item -LiteralPath $PackagePath -Destination $copy
  $before=[IO.File]::ReadAllText($copy)
  & (Join-Path $PSScriptRoot 'build_magi_water_package.ps1') -PackagePath $copy
  $after=[IO.File]::ReadAllText($copy)
  Assert ((Mask $before) -ceq (Mask $after)) 'Water build changed unrelated XML or native metadata'
  & (Join-Path $PSScriptRoot 'build_magi_water_package.ps1') -PackagePath $copy
  Assert ($after -ceq [IO.File]::ReadAllText($copy)) 'Water build is not idempotent'
  [xml]$doc=$after
  $paths=@()
  foreach($entry in @(@('Magi water group','Magi/Magi_water_group.lua'),@('Magi resonance feedback','Magi/resonance_feedback.lua'))){
    $nodes=$doc.SelectNodes('//Script[name="'+$entry[0]+'"]/script')
    Assert ($nodes.Count -eq 1) ('Expected one native script '+$entry[0])
    Assert ((Normalize $nodes[0].InnerText) -ceq (Normalize ([IO.File]::ReadAllText((Join-Path $root $entry[1]))))) ('Source drift: '+$entry[0])
    $path=Join-Path $taskTemp ([IO.Path]::GetFileName($entry[1]))
    [IO.File]::WriteAllText($path,$nodes[0].InnerText,[Text.UTF8Encoding]::new($false))
    $paths+=$path
    & luac -p $path
    Assert ($LASTEXITCODE -eq 0) ('Invalid embedded Lua: '+$entry[0])
  }
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_magi_water_group.lua') ($root.Replace('\','/')+'/') $paths[0] $paths[1]
  Assert ($LASTEXITCODE -eq 0) 'Embedded Water behavioral regressions failed'
  Write-Host 'PASS: Water scoped build, source parity, idempotence, syntax and embedded behavior'
}finally{
  $resolved=(Resolve-Path -LiteralPath $taskTemp).Path
  if((Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') -or
      (Split-Path $resolved -Leaf) -notlike 'magi-water-*'){throw 'Unexpected test directory; refusing cleanup'}
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
