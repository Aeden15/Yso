param([string]$LogPath)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$y=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/Yso system.xml'))
$a=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/AK.xml'))
$alias=$y.SelectSingleNode('//Alias[name="Truelocks"]')
if(-not $alias -or $alias.regex -cne '^tlock$' -or $alias.isActive -ne 'yes'){throw 'Missing active Truelocks alias'}
$pairs=@(
 @('Apostate/entourage.lua','Apostate entourage',$y),
 @('Apostate/daegger_envenom.lua','Apostate daegger envenom',$y),
 @('Apostate/lock_route.lua','Apostate Truelocks',$y),
 @('Apostate/evileye_reference.lua','Apostate reference',$y),
 @('Apostate/ak_tracking.lua','Apostate tracking',$a),
 @('Yso/xml/apostate_utilities.lua','Apostate utilities',$y),
 @('Yso/Combat/route_registry.lua','Route registry',$y)
)
$prefix=[Collections.Generic.List[string]]::new()
$prefix.Add('local original=dofile;local embedded={}')
$luaRoot=$root.Replace('\','/')
foreach($entry in $pairs){
 $node=$entry[2].SelectSingleNode('//Script[name="'+$entry[1]+'"]')
 $source=[IO.File]::ReadAllText((Join-Path $root $entry[0]))
 if(-not $node -or $node.script.Replace("`r`n","`n").Trim() -cne $source.Replace("`r`n","`n").Trim()){throw ('Source/package drift: '+$entry[1])}
 $prefix.Add('embedded[ [==['+$luaRoot+'/'+$entry[0]+']==] ]=[====['+$node.script+']====]')
}
$prefix.Add('dofile=function(path) if embedded[path] then return assert(load(embedded[path],path))() end return original(path) end')
foreach($test in @('test_entourage.lua','test_lock_route.lua','test_lock_route_delivery.lua','test_truelock_creatures.lua','test_truelock_emission.lua')){
 $code=($prefix -join "`n")+"`n"+'arg={[1]=[==['+$luaRoot+']==]};original([==['+$luaRoot+'/Apostate/'+$test+']==])'
 $code | & lua -
 if($LASTEXITCODE -ne 0){throw ('Embedded route test failed: '+$test)}
}
$scriptNames=@($y.SelectNodes('//Script') | ForEach-Object {$_.name})
if([array]::IndexOf($scriptNames,'Apostate entourage') -ge [array]::IndexOf($scriptNames,'Apostate Truelocks')){throw 'Entourage must load before the lock route'}
# Replay the actual packaged curseward trigger scripts, including other targets.
$checks=[Collections.Generic.List[string]]::new()
$checks.Add('target="Saibel";ak={defs={},ai=function() return false end,scoreup=function() end};IsTargetted=function(name) return name==target end')
foreach($entry in @(@('CurseWard Up','Saibel',1,'true'),@('CurseWard Up','Other',1,'false'),@('CurseWard Down','Saibel',1,'false'),@('CurseWard Down','Other',1,'true'))){
 $node=$a.SelectSingleNode('//Trigger[name="'+$entry[0]+'"]')
 if(-not $node -or $node.isActive -ne 'yes'){throw 'Missing active curseward trigger'}
 $expected=$entry[3];$initial=if($expected -eq 'true'){'false'}else{'true'}
 if($entry[1] -eq 'Other'){$initial=$expected}
 $checks.Add('ak.defs.curseward='+$initial+';matches={"", "'+$entry[1]+'"};assert(load([====['+$node.script+']====]))();assert(ak.defs.curseward=='+$expected+')')
}
foreach($entry in @(@('CurseWard Up','A shimmering curseward appears around Saibel.'),@('CurseWard Up','You try to curse Saibel, but she is warded.'),@('CurseWard Down',"Saibel's curseward shatters!"),@('CurseWard Down',"Your attempt to breach Saibel's curseward has no effect."))){
 $node=$a.SelectSingleNode('//Trigger[name="'+$entry[0]+'"]');$matched=$false
 foreach($pattern in $node.regexCodeList.string){if($entry[1] -cmatch $pattern -and $Matches[1] -ceq 'Saibel'){$matched=$true}}
 if(-not $matched){throw ('Curseward fixture failed: '+$entry[1])}
}
$checks.Add('print("PASS packaged curseward triggers and target isolation")')
($checks -join "`n") | & lua -
if($LASTEXITCODE -ne 0){throw 'Curseward trigger replay failed'}
if($a.SelectNodes('//Trigger[starts-with(name,"Apostate Corrupt ")]').Count -ne 0){throw 'Obsolete Corrupt adapters remain'}
$rejection=$y.SelectSingleNode('//Trigger[name="Truelocks eye rejected"]')
if(-not $rejection -or $rejection.script.Trim() -cne ([IO.File]::ReadAllText((Join-Path $root 'Apostate/eye_rejected.lua'))).Trim()){throw 'Eye rejection source/package drift'}
Write-Output 'PASS active alias, embedded simplified route, curseward adapters and source parity'
