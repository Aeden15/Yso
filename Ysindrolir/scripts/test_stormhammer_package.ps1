[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$doc=[xml][IO.File]::ReadAllText($PackagePath)
function Assert($ok,$message){if(-not $ok){throw $message}}
$elemental=$doc.SelectSingleNode('//AliasGroup[name="Magi"]/AliasGroup[name="Elementalism"]')
Assert ($null -ne $elemental) 'Magi Elementalism folder missing'
$trans=$elemental.SelectSingleNode('Alias[name="Transfixed"]')
Assert ($null -ne $trans) 'Transfixed alias missing'
Assert ($trans.regex -ceq '^tfix$') 'Transfixed pattern differs'
Assert ($trans.script -ceq 'sendAll("cq all", "cast transfix " ..target)') 'Transfixed script differs'
foreach($pair in @(@('Hammer time','^sth$'),@('Target Switcher','^shtar (\S+)$'))){
  $node=$elemental.SelectSingleNode('AliasGroup[name="Stormhammer"]/Alias[name="'+$pair[0]+'"]')
  Assert ($null -ne $node -and $node.isActive -eq 'yes' -and $node.regex -ceq $pair[1]) ('Missing active alias '+$pair[0])
}
foreach($pair in @(@('Magi weapons','Magi/magi_weapons.lua'),@('Stormhammer','Magi/magi_stormhammer.lua'),@('Yso target priority','Yso/xml/yso_target_priority.lua'))){
  $nodes=$doc.SelectNodes('//Script[name="'+$pair[0]+'"]')
  Assert ($nodes.Count -eq 1 -and $nodes[0].isActive -eq 'yes') ('Expected one active '+$pair[0])
  $source=[IO.File]::ReadAllText((Join-Path $root $pair[1])).Replace("`r`n","`n").TrimEnd()
  Assert ($nodes[0].script.Replace("`r`n","`n").TrimEnd() -ceq $source) ('Embedded source mismatch '+$pair[0])
}
$scripts=@($doc.SelectNodes('//Script'))
$names=@($scripts | ForEach-Object {$_.name})
Assert ([array]::IndexOf($names,'Yso target priority') -lt [array]::IndexOf($names,'Stormhammer')) 'Priority must load before Stormhammer'
Assert ([array]::IndexOf($names,'Magi weapons') -lt [array]::IndexOf($names,'Stormhammer')) 'Weapons must load before Stormhammer'
Assert ($doc.SelectNodes('//Trigger[name="tprio announced"]').Count -eq 1) 'Priority trigger missing or duplicated'
$misc=$doc.SelectSingleNode('//Script[name="Miscellaneous scripts"]/script').InnerText
Assert ($misc -notmatch 'magistaff\s*=\s*"staff\d+"') 'Fixed staff assignment remains'
Assert ($misc -match 'magishield') 'Shield variable missing'
$lua=@'
local sent={}
function sendAll(...) sent={...} end
target='Example'
'@
$lua+="`nassert(load([====["+$trans.script+"]====]))()`nassert(sent[1]=='cq all' and sent[2]=='cast transfix Example')`n"
foreach($node in $doc.SelectNodes('//script')){
  if($node.InnerText.Trim()){$lua+="`nassert(load([======["+$node.InnerText+"]======], [======["+$node.ParentNode.name+"]======]))`n"}
}
$lua+="`nprint('PASS: packaged XML structure, source parity, load order, Transfixed and all Lua syntax')"
$lua | & lua -
Assert ($LASTEXITCODE -eq 0) 'Package Lua validation failed'
Push-Location (Split-Path $root -Parent)
try{ & lua 'Ysindrolir/Yso/Tests and rebuilds/test_magi_stormhammer.lua'; Assert ($LASTEXITCODE -eq 0) 'Stormhammer behavior regression failed' }finally{Pop-Location}
Push-Location (Split-Path $root -Parent)
try{ & lua 'Ysindrolir/Yso/Tests and rebuilds/test_magi_login_safety.lua'; Assert ($LASTEXITCODE -eq 0) 'Equipment login safety regression failed' }finally{Pop-Location}
