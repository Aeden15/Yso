# Static startup audit for the external Lua 5.1/Mudlet packages. Behavioral
# completion/disconnect coverage lives in test_legacy_login_safety_package.ps1.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$count=0;$events=0
foreach($file in @('AK.xml','Legacy V2.1.xml','Legacy UI V2.0.xml','Legacy Basher V2.1.xml','limb.1.2.xml')){
 $doc=[xml][IO.File]::ReadAllText((Join-Path $root ('mudlet packages/'+$file)))
 foreach($node in $doc.SelectNodes('//Script[script]')){
  $count++
  if($node.script -match 'registerAnonymousEventHandler\s*\(\s*[''\"](?:sysConnectionEvent|sysLoadEvent)' -or $node.eventHandlerList.InnerText -match 'sysConnectionEvent|sysLoadEvent'){
   $events++;throw "External startup event requires behavioral audit: $file / $($node.name)"
  }
 }
 Write-Host ('PASS: parsed and inspected startup hooks in '+$file)
}
Write-Host ('PASS: '+$count+' external Script bodies inspected; '+$events+' native connection/load handlers')
Write-Host 'SKIP: complete external-package execution needs native Mudlet/Lua 5.1, saved AK class tables and Geyser UI. Installed Lua 5.4 rejects pre-existing Legacy_Install string escapes (for example \( at line 1061). No external startup behavior is claimed from this static inspection.'
& (Join-Path $PSScriptRoot 'test_legacy_login_safety_package.ps1')
