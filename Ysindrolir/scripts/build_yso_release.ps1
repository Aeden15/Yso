[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$ReleaseDirectory=(Join-Path (Split-Path $PSScriptRoot -Parent) 'releases'))
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path $PSScriptRoot -Parent
$releaseRoot=[IO.Path]::GetFullPath($ReleaseDirectory)
$specText=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'yso_release_manifest.json'))
$spec=$specText | ConvertFrom-Json -AsHashtable
if($spec.schema_version -ne 1 -or $spec.release_id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or $spec.release_id.Contains('..')){throw 'Invalid source release manifest'}
$expected=[ordered]@{legacy='Legacy V2.1';ak='AK';limb='limb.1.2';yso='Yso system';basher='Legacy Basher V2.1';ui='Legacy UI V2.0';controller='Yso Workspace Link'}
if($spec.packages.Count -ne $expected.Count){throw 'Release manifest must contain exactly the seven coordinated packages'}
$seen=@{}
foreach($p in $spec.packages){
 if(-not $expected.Contains($p.id) -or $seen.ContainsKey($p.id) -or $p.name -cne $expected[$p.id] -or $p.file -cne ($p.name+'.xml') -or $p.required -ne $true){throw 'Invalid or duplicate release package'}
 foreach($dependency in $p.depends_on){if(-not $seen.ContainsKey($dependency)){throw ('Unresolved release dependency: '+$p.id)}}
 $seen[$p.id]=$true
}
if(-not $PSCmdlet.ShouldProcess($releaseRoot,'Verify and publish an immutable coordinated Yso release')){return}
# App-container TEMP prefixes can exceed 120 characters. Lua's Windows CRT
# opens the unreduced ../ fixture paths, so keep the unique scratch leaf short.
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('yso-r-'+[guid]::NewGuid().ToString('N').Substring(0,16))
$pendingPointer=$null
try {
 [IO.Directory]::CreateDirectory($scratch) | Out-Null
 # Existing standalone fixtures intentionally use workspace-relative Ysindrolir/.
 $snapshot=Join-Path $scratch 'Ysindrolir'
 $payload=Join-Path $scratch 'bundle'
 [IO.Directory]::CreateDirectory($snapshot) | Out-Null
 [IO.Directory]::CreateDirectory($payload) | Out-Null
 # Verify the exact frozen source tree whose packages will be published. Live
 # edits during this potentially long test run cannot enter the bundle later.
 foreach($folder in @('scripts','Yso','Alchemist','Apostate','Magi','Airlord','Dragon','Information','mudlet packages')){
  $from=Join-Path $root $folder
  if(Test-Path -LiteralPath $from){Copy-Item -LiteralPath $from -Destination $snapshot -Recurse}
 }
 # The workspace-sync regression verifies this root wrapper too.
 $syncWrapper=Join-Path (Split-Path $root -Parent) 'sync_workspace.ps1'
 if(Test-Path -LiteralPath $syncWrapper){Copy-Item -LiteralPath $syncWrapper -Destination (Join-Path $scratch 'sync_workspace.ps1')}
 if([IO.File]::ReadAllText((Join-Path $snapshot 'scripts/yso_release_manifest.json')) -cne $specText){throw 'Release manifest changed while freezing inputs'}
 $frozen=@{}
 foreach($file in Get-ChildItem -LiteralPath $snapshot -File -Recurse){$frozen[$file.FullName]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
 $verification=Join-Path $payload 'verification'
 & pwsh -NoProfile -File (Join-Path $snapshot 'scripts/verify_yso.ps1') -SystemRoot $snapshot -SkipReleaseArtifacts -OutputDirectory $verification
 if($LASTEXITCODE -ne 0){
  $failedReport=Join-Path $releaseRoot ('failed-verification-'+[guid]::NewGuid())
  [IO.Directory]::CreateDirectory($releaseRoot) | Out-Null
  if(Test-Path -LiteralPath $verification){Copy-Item -LiteralPath $verification -Destination $failedReport -Recurse}
  throw ('Unified verification failed; the current release was preserved. Diagnostics: '+$failedReport)
 }
 $after=@(Get-ChildItem -LiteralPath $snapshot -File -Recurse)
 if($after.Count -ne $frozen.Count){throw 'Verification changed its frozen inputs; the current release was preserved'}
 foreach($file in $after){if(-not $frozen.ContainsKey($file.FullName) -or (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -cne $frozen[$file.FullName]){throw 'Verification changed its frozen inputs; the current release was preserved'}}
 foreach($p in $spec.packages){
  $source=Join-Path $snapshot ('mudlet packages/'+$p.file)
  $bytes=[IO.File]::ReadAllBytes($source)
  $text=[Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
  $doc=[xml]$text
  if($doc.DocumentElement.LocalName -cne 'MudletPackage'){throw ('Invalid Mudlet root: '+$p.name)}
  if($text -match '(?i)discord(?:app)?\.com/api/webhooks'){throw ('Embedded webhook destination in '+$p.name)}
  $metadata=[Text.StringBuilder]::new()
  $luaChunks=0
  foreach($node in $doc.SelectNodes('//script')){
   $body=$node.InnerText;if([string]::IsNullOrWhiteSpace($body)){continue}
   [void]$metadata.Append([Text.Encoding]::UTF8.GetByteCount($body).ToString()+"`n"+$body)
   $luaChunks++
  }
  $p.sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
  $metadataBytes=[Text.Encoding]::UTF8.GetBytes($metadata.ToString())
  $p.lua_sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($metadataBytes)).ToLowerInvariant()
  $p.lua_chunks=$luaChunks
  [IO.File]::WriteAllBytes((Join-Path $payload $p.file),$bytes)
  $prefix=[Text.Encoding]::UTF8.GetBytes($bytes.Length.ToString()+"`n")
  $receipt=[byte[]]($prefix+$bytes+$metadataBytes)
  [IO.File]::WriteAllBytes((Join-Path $payload ($p.name+'.validated')),$receipt)
 }
 $manifest=$spec | ConvertTo-Json -Depth 8
 [IO.File]::WriteAllText((Join-Path $payload 'manifest.json'),$manifest,[Text.UTF8Encoding]::new($false))
 $digest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($manifest))).ToLowerInvariant()
 $directory=$spec.release_id+'-'+$digest.Substring(0,12)
 [IO.Directory]::CreateDirectory($releaseRoot) | Out-Null
 $destination=Join-Path $releaseRoot $directory
 if(Test-Path -LiteralPath $destination){
  # An immutable release can be reused only if every stored input is exact.
  foreach($file in Get-ChildItem -LiteralPath $payload -File){
   $existing=Join-Path $destination $file.Name
   if(-not (Test-Path -LiteralPath $existing -PathType Leaf) -or (Get-FileHash -LiteralPath $existing).Hash -cne (Get-FileHash -LiteralPath $file.FullName).Hash){throw ('Existing immutable release differs: '+$file.Name)}
  }
 } else {
  # Stage on the destination volume so publishing is a directory rename.
  $staging=Join-Path $releaseRoot ('.pending-'+[guid]::NewGuid())
  try {Copy-Item -LiteralPath $payload -Destination $staging -Recurse;[IO.Directory]::Move($staging,$destination)} finally {
   if(Test-Path -LiteralPath $staging){
    $resolved=[IO.Path]::GetFullPath($staging)
    if((Split-Path $resolved -Parent) -cne $releaseRoot -or (Split-Path $resolved -Leaf) -notlike '.pending-*'){throw 'Unsafe release staging cleanup'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
   }
  }
 }
 $pointer=@{schema_version=1;release_id=$spec.release_id;directory=$directory} | ConvertTo-Json -Compress
 $pendingPointer=Join-Path $releaseRoot ('.current-'+[guid]::NewGuid()+'.tmp')
 [IO.File]::WriteAllText($pendingPointer,$pointer,[Text.UTF8Encoding]::new($false))
 [IO.File]::Move($pendingPointer,(Join-Path $releaseRoot 'current.json'),$true)
 Write-Output ('PASS coordinated release '+$spec.release_id+': '+$destination)
} finally {
 if($pendingPointer -and (Test-Path -LiteralPath $pendingPointer)){Remove-Item -LiteralPath $pendingPointer -Force}
 $resolved=[IO.Path]::GetFullPath($scratch)
 if((Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') -or (Split-Path $resolved -Leaf) -notlike 'yso-r-*'){throw 'Unsafe release build cleanup'}
 if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
