$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$y=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/Yso system.xml'))
$a=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/AK.xml'))
if([IO.File]::ReadAllText((Join-Path $root 'Yso/Combat/route_registry.lua')) -cne [IO.File]::ReadAllText((Join-Path $root 'Yso/xml/route_registry.lua'))){throw 'Route registry mirror drift'}
$curing=$y.SelectSingleNode('//TriggerGroup[name="Yso Triggers"]/TriggerGroup[name="Curing"]')
$cases=@(
 @('Self paralysis gained','^A prickly stinging overcomes your body, fading away into numbness\.$','A prickly stinging overcomes your body, fading away into numbness.'),
 @('Self paralysis cured','^Your muscles unlock; you are no longer paralysed\.$','Your muscles unlock; you are no longer paralysed.')
)
$luaRoot=$root.Replace('\','/')
$code="dofile([==[$luaRoot/Yso/Core/self_aff.lua]==]);Yso.selfaff.sync_full({},'gmcp.full')`n"
foreach($c in $cases){
 $t=$curing.SelectSingleNode('./Trigger[name="'+$c[0]+'"]')
 if(-not $t -or $t.isActive -ne 'yes'){throw ('Missing permanent Curing trigger: '+$c[0])}
 if($t.regexCodeList.string -cne $c[1]){throw 'Unexpected paralysis pattern'}
 if($c[2] -cnotmatch $c[1] -or ('Afflicted msg: '+$c[2]) -cmatch $c[1]){throw 'Paralysis pattern does not isolate live output'}
 $expected=if($c[0] -eq 'Self paralysis gained'){'true'}else{'false'}
 $code+=$t.script+"`nassert(Yso.self.has_aff('paralysis')==$expected)`n"
}
$code | & lua -
if($LASTEXITCODE -ne 0){throw 'Self paralysis trigger replay failed'}
$ride=$a.SelectSingleNode('//TriggerGroup[name="Riding Group"]/Trigger[name="Trample"]')
$patterns=@($ride.regexCodeList.string)
foreach($mount in @('An alabaster pegasus','A steppe eagle','A stone gargoyle','Obsidian, the ancient winged terror')){
 foreach($verb in @('breaks','crushes','pulverises','smashes')){
  foreach($side in @('left','right')){foreach($limb in @('arm','leg')){
   $line="$mount $verb the $side $limb of Saibel."
   if($line -cnotmatch $patterns[0] -or $Matches[1] -ne $side -or $Matches[2] -ne $limb -or $Matches[3] -ne 'Saibel'){throw "Mount pattern failure: $line"}
  }}
 }
}
if('A mount crushes the middle wing of Saibel.' -cmatch $patterns[0]){throw 'Invalid anatomy accepted'}
# Replay the actual packaged handler, including duplicate and off-target outcomes.
$trampleCode=@'
local gains=0;target='Saibel';ak={ai=function() return false end};affstrack={score={leftarm=300}}
OppGainedAff=function(a) gains=gains+1;affstrack.score[a]=100 end
'@+"`ndofile([==[$luaRoot/Apostate/ak_tracking.lua]==])`n"
foreach($fixture in @(@('left','arm','Saibel'),@('right','leg','Saibel'),@('right','leg','Saibel'),@('left','leg','Other'))){
 $trampleCode+="matches={[2]='$($fixture[0])',[3]='$($fixture[1])',[4]='$($fixture[2])'}`n"+$ride.script+"`n"
}
($trampleCode+"assert(gains==1);assert(affstrack.score.leftarm==300);assert(affstrack.score.rightleg==100);assert(affstrack.score.leftleg==nil)") | & lua -
if($LASTEXITCODE -ne 0){throw 'Packaged Trample confirmation replay failed'}
$alias=$y.SelectSingleNode('//AliasGroup[name="Apostasy"]/Alias[name="Vivisect route"]')
if(-not $alias -or $alias.regex -cne '^vivi$' -or $alias.isActive -ne 'yes'){throw 'Missing active Vivisect route alias in Apostasy'}
if($alias.script -cne "Yso.util.toggle_route_alias('apostate_vivisect', 'vivi')"){throw 'Incorrect vivi toggle body'}
if(-not $alias.ParentNode.SelectSingleNode('./Alias[name="Truelocks"]')){throw 'Vivisect must be beside Truelocks'}
$prefix="local original=dofile;local embedded={}`n"
foreach($entry in @(@('Apostate Truelocks','Apostate/lock_route.lua'),@('Apostate Vivisect','Apostate/vivisect_route.lua'),@('Apostate reference','Apostate/evileye_reference.lua'),@('Apostate utilities','Yso/xml/apostate_utilities.lua'),@('Route registry','Yso/Combat/route_registry.lua'))){
 $body=$y.SelectSingleNode('//Script[name="'+$entry[0]+'"]').script
 $source=[IO.File]::ReadAllText((Join-Path $root $entry[1]))
 if($body.Replace("`r`n","`n").Trim() -cne $source.Replace("`r`n","`n").Trim()){throw ('Source drift: '+$entry[0])}
 $prefix+='embedded[ [==['+$luaRoot+'/'+$entry[1]+']==] ]=[====['+$body+"]====]`n"
}
$prefix+='dofile=function(p) if embedded[p] then return assert(load(embedded[p],p))() end return original(p) end'+"`n"
($prefix+'arg={[1]=[==['+$luaRoot+']==]};original([==['+$luaRoot+'/Apostate/test_vivisect.lua]==])') | & lua -
if($LASTEXITCODE -ne 0){throw 'Packaged Vivisect regression failed'}
($prefix+'arg={[1]=[==['+$luaRoot+']==]};original([==['+$luaRoot+'/Apostate/test_vivisect_emission.lua]==])') | & lua -
if($LASTEXITCODE -ne 0){throw 'Packaged Vivisect emitter regression failed'}
($prefix+'arg={[1]=[==['+$luaRoot+']==]};original([==['+$luaRoot+'/Apostate/test_vivisect_lifecycle.lua]==])') | & lua -
if($LASTEXITCODE -ne 0){throw 'Packaged Vivisect lifecycle regression failed'}
Write-Host 'PASS permanent paralysis triggers, generic mount patterns, alias and packaged Vivisect route'
