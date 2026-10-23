-- Actual packaged scheduler/emitter; only Mudlet transport and game state are stubbed.
local root=arg[1] or 'Ysindrolir'
Yso={};yso=Yso
local clock,serial=10000,0
local timers,sent,output,events,affs={},{},{},{},{}
getEpoch=function() return clock end
tempTimer=function(_,fn) serial=serial+1;timers[serial]=fn;return serial end
killTimer=function(id) timers[id]=nil end
tempAlias=function() serial=serial+1;return serial end
tempRegexTrigger=function() serial=serial+1;return serial end
killTrigger=function() end;killAlias=function() end
registerAnonymousEventHandler=function(name,fn) events[name]=events[name] or {};table.insert(events[name],fn);serial=serial+1;return serial end
killAnonymousEventHandler=function() end
send=function(command) sent[#sent+1]=command end
cecho=function(text) output[#output+1]=text end
raiseEvent=function() end
target='Maldrantus';shikstaff='staff123'
gmcp={Char={Status={name='Tester',class='Monk'},Vitals={hp='5666',eq='1',bal='1'}},Room={Players={}}}
Legacy={Settings={Curing={status=true}},Room={players={Maldrantus=true}}}
dofile(arg[3] or root..'/Yso/xml/api_stuff.lua')
Yso.get_target=function() return target end
Yso.ak.has=function(name) return affs[name]==true end
Yso.shield={up=function() return false end}
Yso.self.has_aff=function() return false end;Yso.self.is_prone=function() return false end
IsTargetted=function(name) return name==target end
dofile(root..'/Yso/xml/route_registry.lua');dofile(arg[2] or root..'/Yso/xml/yso_modes.lua')
for _,name in ipairs{'monk_reference','combo','shikudo_forms','shikudo_duel_selector','limb_tracker','shikudo_limb_bridge'} do dofile(root..'/Monk/'..name..'.lua') end
local locked=false
Yso.monk.mindlock={is_locked=function() return locked end}
dofile(arg[4] or root..'/Monk/shikudo_duel.lua')
local M,F=Yso.off.monk.duel,Yso.monk.shikudo
lb.resetAll(target);M.alias('lock')
local a,why=M.preview()
assert(a and a.command=='adopt rain form','Current Legacy presence must survive stale startup data: '..tostring(why))
M.note_room_player('Alice',true);assert(M.preview());M.note_room_player('Alice',false);assert(M.preview())
gmcp.Room.Players={{name='Tester'}};M.note_room_players(true);assert(M.preview(),'Unlisted is not departed')
M.note_room_player(target,false);a,why=M.preview();assert(not a and why=='target_not_in_room')
M.note_room_player(target,true);assert(M.preview())
M.note_room_info();a,why=M.preview();assert(not a and why=='unknown_target_reach')
gmcp.Room.Players={{name=target}};M.note_room_players(true)
M.alias('on')
local function pulse()
  clock=clock+1
  local id=M.state.timer_id;assert(id and timers[id],'Actual route scheduler must be armed')
  local callback=timers[id];timers[id]=nil;callback()
end
local function count(command) local n=0;for _,line in ipairs(sent) do if line==command then n=n+1 end end;return n end
pulse();assert(count('wield staff123&&adopt rain form')==1)
F.set_form('rain');pulse();assert(count('wield staff123&&hyperfocus head')==1)
M.note_hyperfocus('head');gmcp.Char.Vitals.bal='0';M.note_vitals();pulse()
assert(count('mind lock Maldrantus')==1 and not M.state.mental,'Mindlock must use no EQ/BAL record')
Yso.monk.mindlock.pending_target=target
gmcp.Char.Vitals.bal='1';M.note_vitals();pulse()
assert(count('wield staff123&&combo Maldrantus ruku left ruku right')==1,'Actual emitter must send physical prep before mindlock success')
for i=1,12 do M.note_recovery('left arm');M.note_recovery('right arm');pulse() end
assert(count('mind lock Maldrantus')==1 and M.is_enabled(),'Variable-duration forming lock must neither duplicate nor stop physical pressure')
locked=true;Yso.monk.mindlock.pending_target=nil;pulse()
assert(count('mind impatience Maldrantus')==0 and not M.state.mental,'EQ support must wait for the physical recovery opening')
M.note_recovery('left arm');M.note_recovery('right arm');pulse()
assert(count('mind impatience Maldrantus')==0 and not M.state.mental,'Preparation must continue physically without early Impatience')
affs.anorexia=true;affs.asthma=true;affs.slickness=true;affs.paralysis=true
M.state.cooldown.next_lock_plan={stage='harden'}
F.set_form('willow');F.set_kata(4)
M.note_recovery('left arm');M.note_recovery('right arm');pulse()
assert(count('mind impatience Maldrantus')==1 and M.state.mental,'Actual emitter must send closing Impatience through EQ')
assert(count('wield staff123&&mind impatience Maldrantus')==0,'EQ actions must not be wield-wrapped')
gmcp.Char.Vitals.eq='0';M.note_vitals();affs.impatience=true;M.note_aff(target,'impatience')
gmcp.Char.Vitals.eq='1';M.note_vitals()
M.note_recovery('left arm');M.note_recovery('right arm');pulse()
locked=false;pulse();assert(count('mind lock Maldrantus')==2,'Re-establish freely without waiting on physical recovery')
assert(not M.note_target_grace('Alice'))
assert(M.note_target_grace(target) and not M.is_enabled())
M.alias('on');pulse();assert(count('wield staff123&&hyperfocus head')==2,'Restart must not inherit phantom mindlock recovery')
M.note_hyperfocus('head');M.note_full_recovery();pulse()
assert(M.note_target_unavailable())
a,why=M.preview();assert(not a and why=='target_not_in_room')
assert(M.note_local_target_activity(target));assert(M.preview())
M.alias('on');M.note_hyperfocus('head')
M.state.pending=nil;M.state.cooldown=nil;M.state.mental=nil;M.state.mindlock_request=nil
gmcp.Char.Vitals.eq='0';output={};locked=true;M.attack_function()
assert(table.concat(output):find('equilibrium_down',1,true),'EQ holds must remain visible')
gmcp.Char.Vitals.eq='1';locked=false
Yso.emit=function() return false end
output={};M.attack_function()
assert(table.concat(output):find('emit_failed',1,true))
assert(not M.state.mindlock_request,'Rejected transport must not invent a forming request')
local s=M.status();assert(s.stage and s.timer_scheduled~=nil and s.room_source and s.physical_wait~=nil)
print('PASS staged startup: real timer/emitter, free variable-duration mindlock, physical overlap, EQ pressure, room authority, rejection and visible holds')
