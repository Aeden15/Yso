$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (Test-Path (Join-Path $root 'Monk')) { throw 'Retired Monk source directory remains' }
foreach ($file in Get-ChildItem (Join-Path $root 'mudlet packages') -Filter *.xml) {
  $doc = [xml][IO.File]::ReadAllText($file.FullName)
  foreach ($node in $doc.SelectNodes('//*[name]')) {
    if ([string]$node.name -match '(?i)monk|shikudo|tekura|kaido|mind.?lock|radiance') {
      throw "Retired package entry: $($file.Name): $($node.name)"
    }
  }
  foreach ($node in $doc.SelectNodes('//Trigger')) {
    if ($node.regexCodeList -and $node.regexCodeList.InnerText -match '(?i)kaido|mindlock|shikudo|tekura|Kai energy|Kai Trance') {
      throw "Retired tracking pattern: $($file.Name): $($node.name)"
    }
  }
}
$package = [xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/Yso system.xml'))
foreach ($name in @('Deliverance','Deliverance safety','Deliverance channeling','Deliverance up','Deliverance down','Enemy Deliverance','Enemy Deliverance stage 2','Enemy Deliverance safety','Deliverance resource','Soaring')) {
  if (@($package.SelectNodes("//*[name='$name']")).Count -ne 1) { throw "Missing preserved entry: $name" }
}
foreach ($file in Get-ChildItem $PSScriptRoot -Filter 'build_*.ps1') {
  if ([IO.File]::ReadAllText($file.FullName) -match '(?i)Monk[/\\]|build_shdam|build_shikudo') { throw "Builder references retired source: $($file.Name)" }
}
$hashes=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'deliverance-preserved-bodies.json') | ConvertFrom-Json -AsHashtable
foreach ($name in $hashes.Keys) {
  $body=$package.SelectSingleNode("//*[name='$name']/script").InnerText
  $actual=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($body)))
  if ($actual -cne $hashes[$name]) { throw "Preserved Deliverance body changed: $name" }
}
Write-Host 'PASS: Monk retired; Deliverance and Airlord soar preserved'
