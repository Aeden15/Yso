[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Legacy Basher V2.1.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$doc=[xml][IO.File]::ReadAllText($PackagePath)
$basher=$doc.SelectSingleNode('//Script[name="Basher"]')
$toggle=$doc.SelectSingleNode('//Alias[name="Hunting Toggle"]')
$helper=$doc.SelectSingleNode('//Script[name="Apostate hunting Soulstorm"]')
$lua=[Collections.Generic.List[string]]::new()
$lua.Add(@'
local sent,events,timers={},{},{}
local callbacks={}
local clock=1000
getEpoch=function() return clock end
send=function(s) sent[#sent+1]=s end
cecho=function() end
registerAnonymousEventHandler=function(e,f)
 events[e]=f;callbacks[e]=callbacks[e] or {};table.insert(callbacks[e],f);return e
end
killAnonymousEventHandler=function() end
raiseEvent=function() end
tempTimer=function(_,f) timers[#timers+1]=f;return #timers end
killTimer=function() end
table.contains=function(t,value) for _,v in pairs(t or {}) do if v==value then return true end end return false end
table.size=function(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
gmcp={Char={Status={name='Tester',class='Apostate'},Vitals={hp='5000',eq='1',bal='1'},
 Items={List={items={{id='214001',attrib='m',name='a massive gour'}}}}},
 Room={Info={num=1,area='Test',exits={}}},IRE={Target={Set='214001',Info={npc=true,hpperc='100',short_desc='a massive gour'}}}}
Legacy={Tester={Vitals={hpPer=100},rage=0}}
Yso={}
'@)
$lua.Add($basher.script)
if($helper){$lua.Add('assert(load([====['+$helper.script+']====]))()')}
$lua.Add('local toggle=function() '+$toggle.script+"`n"+'end')
$lua.Add('local triggers={}')
foreach($kind in @('confirmed','already active','faded')){
 $trigger=$doc.SelectSingleNode('//Trigger[name="Apostate Soulstorm '+$kind+'"]')
 if($trigger){$lua.Add('triggers["'+$kind+'"]=function(label) matches={"",label};'+$trigger.script+' end')}
}
$lua.Add(@'
Basher_Setup()
local H=assert(Legacy.Basher.Soulstorm,'missing Soulstorm startup integration')
local S=Legacy.Settings.Basher
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function queues()
 local out={};for _,s in ipairs(sent) do if s:match('^queue ') then out[#out+1]=s end end;return out
end
local function reset(class)
 H.reset();sent={};attacked=false;sendCount=0
 gmcp.Char.Status.class=class or 'Apostate';gmcp.Char.Vitals={hp='5000',eq='1',bal='1'}
 gmcp.IRE.Target.Set='214001';gmcp.IRE.Target.Info={npc=true,hpperc='100',short_desc='a massive gour'}
 gmcp.Room.Info.num=1
 S.Classes[gmcp.Char.Status.class]={attack='decay @tar',pre='',configRage={bigDamage=20,smallDamage=0}}
 Legacy.Settings.Basher.Rage()
 S.status=false;S.queued=false;S.flee=false;S.shield=false;S.onlyTarget=false;S.useRage=false
 S.currentTar='214001';S.desc='a massive gour';S.possibleTargets={['214001']='a massive gour'}
end
reset();toggle();Legacy.Basher.Attack()
eq(queues()[1],'queue addclear freestand soulstorm 214001')
eq(queues()[2],'queue add freestand basher');eq(#queues(),2)
eq(H.effect,nil) -- Sending is not confirmation.
Legacy.Basher.Attack();eq(#queues(),2)
triggers.confirmed('a massive gour');assert(H.effect and H.effect.active)
S.queued=false;sent={};Legacy.Basher.Attack();eq(queues()[1],'queue add freestand basher')
toggle();eq(S.status,false);sent={};toggle();Legacy.Basher.Attack()
eq(queues()[1],'queue add freestand basher') -- Retoggle skips a confirmed active effect.
triggers.faded('A massive gour');eq(H.effect.active,false)
S.queued=false;sent={};Legacy.Basher.Attack();eq(queues()[1],'queue add freestand basher')
toggle();toggle();sent={};Legacy.Basher.Attack();eq(queues()[1],'queue addclear freestand soulstorm 214001')
triggers['already active']('a massive gour');eq(H.effect.active,true)
triggers.faded('a different creature');eq(H.effect.active,true)
-- Readiness and existing basher safety gates hold the opener until legal.
for _,gate in ipairs({'eq','bal','fleeing','onlyTarget','fool','webbed','shield'}) do
 reset();toggle()
 if gate=='eq' or gate=='bal' then gmcp.Char.Vitals[gate]='0'
 elseif gate=='webbed' then Legacy.Curing.Affs.webbed=true
 elseif gate=='fool' then Yso.fool={blocks_basher=function() return true end}
 else S[gate]=true end
 Legacy.Basher.Attack();eq(#queues(),0)
 Yso.fool=nil;Legacy.Curing.Affs.webbed=nil;S.fleeing=false;S.onlyTarget=false;S.shield=false
 gmcp.Char.Vitals.eq='1';gmcp.Char.Vitals.bal='1';S.queued=false;sent={}
 Legacy.Basher.Attack();eq(queues()[1],'queue addclear freestand soulstorm 214001')
end
reset('Magi');toggle();Legacy.Basher.Attack();eq(queues()[1],'queue add freestand basher')
reset('Occultist');toggle();Legacy.Basher.Attack()
eq(queues()[1],'queue addclear freestand attend @tar&&cleanseaura @tar')
reset();toggle();gmcp.IRE.Target.Set='Player';gmcp.IRE.Target.Info.npc=false
Legacy.Basher.Attack();assert(not table.concat(queues(),' '):find('soulstorm',1,true))
reset();toggle();Legacy.Basher.Attack();gmcp.IRE.Target.Set='999';gmcp.IRE.Target.Info.short_desc='another creature'
triggers.confirmed('a massive gour');eq(H.effect,nil)
reset();toggle();Legacy.Basher.Attack();gmcp.Room.Info.num=2
triggers.confirmed('a massive gour');eq(H.effect,nil)
reset();toggle();Legacy.Basher.Attack();toggle();S.queued=false;sent={};Legacy.Basher.Attack();eq(#queues(),0)
reset();triggers['already active']('a massive gour');toggle();Legacy.Basher.Attack()
eq(queues()[1],'queue add freestand basher') -- Manual confirmation before hunt also counts.
H.reset();reset();toggle();gmcp.IRE.Target.Set='';S.currentTar='';S.possibleTargets={}
Legacy.Basher.Attack();eq(#queues(),0)
gmcp.IRE.Target.Set='214001';S.currentTar='214001';S.possibleTargets={['214001']='a massive gour'}
Legacy.Basher.Attack();eq(queues()[1],'queue addclear freestand soulstorm 214001')
reset();toggle();gmcp.IRE.Target.Set='214001&&quit';S.currentTar=gmcp.IRE.Target.Set
Legacy.Basher.Attack();assert(not table.concat(queues(),' '):find('soulstorm',1,true))
reset();toggle();gmcp.IRE.Target.Info.hpperc='0';Legacy.Basher.Attack()
assert(not table.concat(queues(),' '):find('soulstorm',1,true))
gmcp.IRE.Target.Info.hpperc='100';S.queued=false;sent={};Legacy.Basher.Attack()
eq(queues()[1],'queue addclear freestand soulstorm 214001')
reset();toggle();local original=Legacy.Basher.queueAttackPackage
Legacy.Basher.queueAttackPackage=function() return false end
Legacy.Basher.Attack();eq(#queues(),0);eq(H.pending,true)
Legacy.Basher.queueAttackPackage=original;Legacy.Basher.Attack()
eq(queues()[1],'queue addclear freestand soulstorm 214001')
reset();toggle();Legacy.Basher.queueAttackPackage=function() error('partial queue failure') end
Legacy.Basher.Attack();eq(S.status,false);eq(H.pending,false);eq(#queues(),0)
Legacy.Basher.queueAttackPackage=original
reset();triggers.confirmed('a massive gour');events['sysDisconnectionEvent']();eq(H.effect,nil)
reset();triggers.confirmed('a massive gour');H.stop();gmcp.Room.Info.num=2
for _,fn in ipairs(callbacks['gmcp.Room.Info'] or {}) do if type(fn)=='function' then fn() end end
eq(H.effect,nil);gmcp.Room.Info.num=1;toggle();Legacy.Basher.Attack()
eq(queues()[1],'queue addclear freestand soulstorm 214001')
reset();triggers.confirmed('a massive gour');local expires=H.effect.expires_at
clock=clock+20;triggers['already active']('a massive gour');eq(H.effect.expires_at,expires)
clock=clock+20;toggle();Legacy.Basher.Attack()
eq(queues()[1],'queue addclear freestand soulstorm 214001') -- Missed fade cannot cache forever.
reset();triggers.confirmed('a massive gour');gmcp.Char.Status.class='Magi';events['gmcp.Char.Status']();eq(H.effect,nil)
print('PASS Soulstorm startup, trigger confirmations, expiry, readiness, target guards, other classes and queue order')
'@)
($lua -join "`n") | & lua -
if($LASTEXITCODE -ne 0){throw 'Apostate hunting behavior checks failed'}
$fixtures=@(
 @('confirmed','You call forth an unholy tide of necromantic essence and release it, engulfing a massive gour in a profane soulstorm.'),
 @('already active',"Necromantic essence still profanes a massive gour's soul."),
 @('faded','A massive gour steadies as the profane aura around it fades.')
)
foreach($fixture in $fixtures){
 $node=$doc.SelectSingleNode('//Trigger[name="Apostate Soulstorm '+$fixture[0]+'"]')
 if(-not $node -or $node.isActive -ne 'yes'){throw 'Missing active Soulstorm adapter'}
 if($fixture[1] -cnotmatch $node.regexCodeList.string){throw ('Captured Soulstorm line rejected: '+$fixture[0])}
 if(('(Party): '+$fixture[1]) -cmatch $node.regexCodeList.string){throw 'Chat matched Soulstorm adapter'}
}
$source=[IO.File]::ReadAllText((Join-Path $root 'Apostate/hunting_soulstorm.lua'))
if($source.Replace("`r`n","`n") -cne $helper.script.Replace("`r`n","`n")){throw 'Soulstorm source/package mismatch'}
foreach($node in $doc.SelectNodes('//Script | //Alias | //Trigger')){
 ('assert(load([====['+$node.script+']====]))') | & lua -
 if($LASTEXITCODE -ne 0){throw ('Invalid packaged Lua: '+$node.name)}
}
Write-Output 'PASS Soulstorm captured messages, source parity, and Legacy Basher Lua syntax'
$scratch=[IO.Path]::GetTempFileName()
try{
 Copy-Item -LiteralPath $PackagePath -Destination $scratch -Force
 $before=(Get-FileHash -LiteralPath $scratch).Hash
 & (Join-Path $PSScriptRoot 'build_apostate_hunting_package.ps1') -PackagePath $scratch
 if((Get-FileHash -LiteralPath $scratch).Hash -cne $before){throw 'Soulstorm package rebuild is not idempotent'}
 Write-Output 'PASS Soulstorm package rebuild idempotence'
}finally{Remove-Item -LiteralPath $scratch}
