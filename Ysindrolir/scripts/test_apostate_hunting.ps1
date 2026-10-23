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
local callbacks,handlers={},{}
local nextHandler=0
local clock=1000
getEpoch=function() return clock end
send=function(s) sent[#sent+1]=s end
cecho=function() end
registerAnonymousEventHandler=function(e,f)
 nextHandler=nextHandler+1
 events[e]=f;callbacks[e]=callbacks[e] or {};callbacks[e][nextHandler]=f
 handlers[nextHandler]=e;return nextHandler
end
killAnonymousEventHandler=function(id)
 local e=handlers[id];if e then callbacks[e][id]=nil;handlers[id]=nil end
end
raiseEvent=function(e,...)
 local pending={};for id,f in pairs(callbacks[e] or {}) do pending[id]=f end
 for _,f in pairs(pending) do
  if type(f)=='string' then
   local resolved=_G;for key in f:gmatch('[^.]+') do resolved=resolved[key] end;f=resolved
  end
  f(e,...)
 end
end
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
$slain=$doc.SelectSingleNode('//Trigger[name="Mob Slain"]')
$lua.Add('triggers.slain=function(label) matches={"",label};'+$slain.script+' end')
foreach($kind in @('confirmed','already active','faded')){
 $trigger=$doc.SelectSingleNode('//Trigger[name="Apostate Soulstorm '+$kind+'"]')
 if($trigger){$lua.Add('triggers["'+$kind+'"]=function(label) matches={"",label};'+$trigger.script+' end')}
}
$lua.Add(@'
-- Legacy_Load restores data-only tables AFTER all package scripts initialize.
-- The runtime must rebind its functions to the restored tables before setup.
local sentinelCalls=0
local sentinel=registerAnonymousEventHandler('unrelated-event',function() sentinelCalls=sentinelCalls+1 end)
Legacy.Basher={Targets={Test={'a massive gour'}},Soulstorm={pending=true,handlers={['gmcp.Char.Status']=sentinel}}}
local loaded,loadError=pcall(raiseEvent,'LegacyLoaded')
assert(loaded,'saved-profile startup must finish: '..tostring(loadError))
raiseEvent('unrelated-event')
assert(sentinelCalls==1,'restored handler IDs must not unregister unrelated runtime events')
assert(table.size(callbacks.sysDisconnectionEvent)==1,'saved restore must replace old helper callbacks')
local H=assert(Legacy.Basher.Soulstorm,'missing Soulstorm startup integration')
local S=Legacy.Settings.Basher
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
eq(S.currentTar,'')
assert(type(S.possibleTargets)=='table','fresh startup must initialize target candidates')
local function queues()
 local out={};for _,s in ipairs(sent) do if s:match('^queue ') then out[#out+1]=s end end;return out
end
local function reset(class)
 H.reset();sent={};attacked=false;sendCount=0
 S._removedHuntTarget=nil;S.roomMobs=nil;S.mobRoom=nil
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
toggle();toggle();sent={};Legacy.Basher.Attack();eq(queues()[1],'queue add freestand basher')
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
raiseEvent('gmcp.Room.Info')
eq(H.effect,nil);gmcp.Room.Info.num=1;toggle();Legacy.Basher.Attack()
eq(queues()[1],'queue addclear freestand soulstorm 214001')
reset();triggers.confirmed('a massive gour');local expires=H.effect.expires_at
clock=clock+20;triggers['already active']('a massive gour');eq(H.effect.expires_at,expires)
clock=clock+20;toggle();Legacy.Basher.Attack()
eq(queues()[1],'queue add freestand basher') -- No refresh on a surviving target, even after expiry.
reset();triggers.confirmed('a massive gour');gmcp.Char.Status.class='Magi';events['gmcp.Char.Status']();eq(H.effect,nil)
-- Replay Legacy's actual target selector and slain trigger through three mobs.
reset();S.roomMobs=nil;S.mobRoom=nil;S.currentTar='';gmcp.IRE.Target.Set=''
gmcp.Char.Items.List.items={
 {id='214001',attrib='m',name='a massive gour'},
 {id='214002',attrib='m',name='a massive gour'},
 {id='214003',attrib='m',name='a massive gour'},
}
toggle()
local opened={}
for index=1,3 do
 local selected=S.currentTar
 assert(selected~='' and not opened[selected],'Legacy must select a different living mob')
 gmcp.IRE.Target.Set=selected
 gmcp.IRE.Target.Info={id=selected,npc=true,hpperc='100',short_desc='a massive gour'}
 sent={};raiseEvent('gmcp.Char.Vitals')
 eq(queues()[1],'queue addclear freestand soulstorm '..selected)
 eq(queues()[2],'queue add freestand basher');eq(#queues(),2)
 opened[selected]=true;triggers.confirmed('a massive gour')
 S.queued=false;sent={};raiseEvent('gmcp.Char.Vitals')
 eq(queues()[1],'queue add freestand basher')
 triggers.slain('a massive gour')
 eq(H.effect,nil);eq(S.possibleTargets[selected],nil)
 assert(S.currentTar~=selected,'slain target must be removed before Legacy selects again')
 -- GMCP may still describe the slain mob until the server confirms retargeting.
 sent={};raiseEvent('gmcp.Char.Vitals');eq(#queues(),0)
end
eq(table.size(opened),3)
-- Removing an old mob before its slain line must not clear its selected successor.
reset();S.roomMobs=nil;S.mobRoom=nil
gmcp.Char.Items.List.items={
 {id='214001',attrib='m',name='a massive gour'},
 {id='214002',attrib='m',name='a massive gour'},
}
toggle();raiseEvent('gmcp.Char.Vitals');triggers.confirmed('a massive gour')
gmcp.Char.Items.Remove={location='room',item={id='214001',name='a massive gour'}}
raiseEvent('gmcp.Char.Items.Remove');eq(H.effect,nil);eq(S.currentTar,'214002')
gmcp.IRE.Target.Set='214002';gmcp.IRE.Target.Info={id='214002',npc=true,hpperc='100',short_desc='a massive gour'}
-- The delayed slain line belongs to the same output batch, before next Vitals.
triggers.slain('a massive gour');eq(S.currentTar,'214002')
sent={};raiseEvent('gmcp.Char.Vitals');eq(queues()[1],'queue addclear freestand soulstorm 214002')
triggers.confirmed('a massive gour')
-- Returning to an opened living target must not issue another opener.
gmcp.Char.Items.Add={location='room',item={id='214003',attrib='m',name='another gour'}}
raiseEvent('gmcp.Char.Items.Add')
S.currentTar='214003';gmcp.IRE.Target.Set='214003';gmcp.IRE.Target.Info={id='214003',npc=true,hpperc='100',short_desc='another gour'}
S.queued=false;sent={};raiseEvent('gmcp.Char.Vitals');eq(queues()[1],'queue addclear freestand soulstorm 214003')
S.currentTar='214002';gmcp.IRE.Target.Set='214002';gmcp.IRE.Target.Info={id='214002',npc=true,hpperc='100',short_desc='a massive gour'}
S.queued=false;sent={};raiseEvent('gmcp.Char.Vitals');eq(queues()[1],'queue add freestand basher')
-- A flee with no slain line must not steal a later same-named target's death.
reset();S.roomMobs=nil;S.mobRoom=nil
gmcp.Char.Items.List.items={
 {id='214001',attrib='m',name='a massive gour'},
 {id='214002',attrib='m',name='a massive gour'},
}
toggle();raiseEvent('gmcp.Char.Vitals');triggers.confirmed('a massive gour')
gmcp.Char.Items.Remove={location='room',item={id='214001',name='a massive gour'}}
raiseEvent('gmcp.Char.Items.Remove');eq(S.currentTar,'214002')
gmcp.IRE.Target.Set='214002';gmcp.IRE.Target.Info={id='214002',npc=true,hpperc='100',short_desc='a massive gour'}
sent={};raiseEvent('gmcp.Char.Vitals');triggers.confirmed('a massive gour')
triggers.slain('a massive gour');eq(S.currentTar,'');eq(H.effect,nil);eq(S.possibleTargets['214002'],nil)
gmcp.Char.Items.List.items={{id='214001',attrib='m',name='a massive gour'}}
-- Use registered event handlers, with no helper calls to manually drive Attack.
reset('Magi');gmcp.IRE.Target.Set='';S.currentTar='';S.possibleTargets={}
raiseEvent('gmcp.Char.Items.List');eq(next(S.possibleTargets),nil)
sent={};toggle()
eq(S.currentTar,'214001');assert(table.concat(sent,'|'):find('st 214001',1,true),'hunt must select a mob already in the room')
gmcp.IRE.Target.Set='214001';sent={};raiseEvent('gmcp.Char.Vitals')
eq(queues()[1],'queue add freestand basher')
toggle();sent={};raiseEvent('gmcp.Char.Vitals');eq(#queues(),0)
-- Unknown status is off, not an instruction to deactivate hunting again.
S.status=nil;toggle();eq(S.status,true)
-- Room additions/removals use ID keys and the current area's name priorities.
gmcp.Char.Items.List.items={};raiseEvent('gmcp.Char.Items.List')
S.currentTar='';gmcp.IRE.Target.Set='';sent={}
gmcp.Char.Items.Add={location='room',item={id=214002,attrib='mx',name='A massive gour'}}
raiseEvent('gmcp.Char.Items.Add');eq(S.possibleTargets['214002'],'A massive gour')
eq(S.currentTar,'214002');eq(Legacy.Settings.Basher.mobCount(),1)
gmcp.Char.Items.Remove={location='room',item={id=214002,name='A massive gour'}}
raiseEvent('gmcp.Char.Items.Remove');eq(S.possibleTargets['214002'],nil)
eq(Legacy.Settings.Basher.mobCount(),0)
S.Ignore={'a massive gour'};raiseEvent('gmcp.Char.Items.Add');eq(S.possibleTargets['214002'],nil)
S.Ignore={};gmcp.Char.Items.List.items={{id='214001',attrib='mx',name='a massive gour'}}
raiseEvent('gmcp.Char.Items.List');eq(S.possibleTargets['214001'],'a massive gour')
print('PASS Soulstorm startup, trigger confirmations, expiry, readiness, target guards, other classes and queue order')
print('PASS saved-profile restore, fresh target initialization, hunt activation/deactivation and room mob events')
print('PASS per-denizen openers, three identical-name targets, slain cleanup, reversed removal order and no survivor refresh')
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
