local root=arg[1] or 'Ysindrolir'
Yso={};yso=Yso
local clock,serial=10000,0
local emitted,timers,affs,output={},{},{},{}
getEpoch=function() return clock end
tempTimer=function(_,fn) serial=serial+1;timers[serial]=fn;return serial end
killTimer=function(id) timers[id]=nil end
tempAlias=function() serial=serial+1;return serial end
killAlias=function() end
local registered={}
registerAnonymousEventHandler=function(event,fn) serial=serial+1;registered[event]=fn;return serial end
killAnonymousEventHandler=function() end
cecho=function(text) output[#output+1]=text end
raiseEvent=function() end
send=function() end
target='Bob';shikstaff='staff123'
gmcp={Char={Status={class='Monk'},Vitals={bal='1',eq='1',hp='5000'}},Room={Players={{name='Bob'}}}}
Legacy={Settings={Curing={status=true}}}
IsTargetted=function(name) return name==target end
Yso.get_target=function() return target end
Yso.ak={has=function(aff) return affs[aff]==true end}
Yso.shield={up=function() return false end}
Yso.self={has_aff=function() return false end,is_prone=function() return false end}
Yso.emit=function(p) emitted[#emitted+1]=p;return true end
dofile(root..'/Yso/xml/route_registry.lua');dofile(root..'/Yso/xml/yso_modes.lua')
for _,name in ipairs{'monk_reference','combo','shikudo_forms','shikudo_duel_selector','limb_tracker','shikudo_limb_bridge'} do dofile(root..'/Monk/'..name..'.lua') end
local locked=false
Yso.monk.mindlock={is_locked=function() return locked end}
dofile(arg[2] or root..'/Monk/shikudo_duel.lua')
local M,F=Yso.off.monk.duel,Yso.monk.shikudo
do
 local count=#output
 M.alias_loop_on_stopped({reason='target_slain'})
 assert(#output==count,'target slain must not print the old SHDUEL diagnostic')
 registered['yso.target.cleared']()
 assert(#output==count,'a delayed clear must not print OFF for an inactive route')
 M.alias_loop_on_stopped({reason='manual'})
 assert(#output==count+1,'manual stop feedback must remain visible')
end
assert(type(M.note_impatience_success)=='function','Telepathy success adapter missing')
local gains=0
OppGainedAff=function(aff) gains=gains+1;affs[aff]=true end
assert(not M.note_impatience_success('Other') and gains==0,'Foreign success must not alter current target')
assert(M.note_impatience_success('Bob') and M.snapshot().affs.impatience)
assert(M.note_impatience_success('Bob') and gains==1,'Duplicate confirmation must not apply the affliction twice')
affs.impatience=nil
assert(not M.snapshot().affs.impatience,'An AK cure must remain authoritative')
lb.resetAll('Bob')
local function tick() clock=clock+0.2;return Yso.mode.tick_route_loop(M.key) end
local function recover() M.note_recovery('left arm');M.note_recovery('right arm') end
M.alias('lock');M.alias('on')
assert(tick());assert(emitted[#emitted].bal=='wield staff123&&adopt rain form' and not emitted[#emitted].free)
F.set_form('rain');assert(tick());assert(emitted[#emitted].bal=='wield staff123&&hyperfocus head')
assert(not tick(),'Do not start mindlock before head focus confirms')
M.note_hyperfocus('head');gmcp.Char.Vitals.bal='0';M.note_vitals()
assert(tick());assert(emitted[#emitted].free=='mind lock Bob' and not emitted[#emitted].eq and not emitted[#emitted].bal)
assert(not tick(),'An outstanding free request must not be duplicated')
gmcp.Char.Vitals.bal='1';M.note_vitals()
assert(tick());assert(emitted[#emitted].bal=='wield staff123&&combo Bob ruku left ruku right','Physical preparation must run before lock success')
assert(lb.Bob.hits['left arm']==0,'Emitting an attack does not populate limb damage')
locked=true
assert(not tick(),'EQ support must not be sent during physical recovery')
recover();assert(tick());assert(emitted[#emitted].bal and not emitted[#emitted].eq,'No early Impatience during preparation')
assert(not tick(),'Neither physical nor EQ attacks may duplicate while awaiting real recovery')
gmcp.Char.Vitals.eq='0';M.note_vitals()
locked=false;assert(tick());assert(emitted[#emitted].free=='mind lock Bob' and not emitted[#emitted].eq and not emitted[#emitted].bal,'Free re-lock must work even while EQ is down')
locked=true
gmcp.Char.Vitals.eq='1';M.note_vitals()
affs.impatience=nil
lb.addHit('Bob','left arm',94);lb.addHit('Bob','right arm',94);lb.addHit('Bob','left leg',94)
F.set_kata(6);recover();assert(tick())
assert(emitted[#emitted].bal:find('transition oak',1,true))
assert((M.state.lock_plan or {}).stage~='pressure','A send cannot establish a new stage')
recover();assert(not tick(),'An inline transition also needs confirmed destination form')
F.set_form('oak');assert(tick());assert(M.state.lock_plan.stage=='pressure')
assert(emitted[#emitted].bal:find('nervestrike light livestrike light',1,true))
F.set_kata(2);recover();assert(tick());assert(emitted[#emitted].bal:find('livestrike light ruku light torso',1,true))
F.set_kata(4);recover();assert(tick());assert(emitted[#emitted].bal:find('nervestrike light ruku light torso',1,true))
affs.impatience=nil
F.set_kata(6);recover();assert(tick())
assert(emitted[#emitted].bal=='wield staff123&&combo Bob ruku left ruku right transition willow')
affs.leftarm=true;affs.rightarm=true;lb.addHit('Bob','left arm',7.6);lb.addHit('Bob','right arm',7.6)
F.set_form('willow');recover();assert(tick())
assert(emitted[#emitted].bal=='wield staff123&&combo Bob sweep flashheel left')
affs.leftleg=true;affs.prone=true;lb.addHit('Bob','left leg',7.6)
recover();assert(not tick(),'A sent kick must retain its actual leg recovery requirement')
M.note_recovery('legs');assert(tick())
assert(emitted[#emitted].bal=='wield staff123&&combo Bob hiraku light hiru light')
affs.anorexia=true;affs.asthma=true;affs.slickness=true;affs.paralysis=true
F.set_kata(4);recover();assert(tick())
assert(emitted[#emitted].eq=='mind impatience Bob' and not emitted[#emitted].bal,'Closing mental action must use EQ, without wield or a simultaneous combo')
assert(M.state.mental and not M.state.pending and M.status().stage=='harden')
assert(M.status().lock_level=='venomlock','A send cannot establish hardlock')
gmcp.Char.Vitals.eq='0';M.note_vitals()
assert(not tick(),'Real EQ recovery is required')
assert(M.note_impatience_success('Bob'))
assert(M.status().lock_level=='hardlock')
affs.weariness=true;assert(M.status().lock_level=='truelock')
affs.impatience=nil
gmcp.Char.Vitals.eq='1';M.note_vitals();assert(tick())
assert(emitted[#emitted].bal and not emitted[#emitted].eq,'A rapid cure must allow physical pressure before another mental attempt')
recover();assert(tick());assert(emitted[#emitted].eq=='mind impatience Bob')
gmcp.Char.Vitals.eq='0';M.note_vitals();assert(M.note_impatience_success('Bob'))
gmcp.Char.Vitals.eq='1';M.note_vitals();assert(tick());assert(M.status().stage=='maintain')
affs.anorexia=nil;F.set_kata(6);recover();assert(tick())
assert(M.status().stage=='prepare','A cured close must reassess rather than remain on anorexia')
local count=#emitted;M.alias('preview');M.alias('status');assert(#emitted==count)
assert(table.concat(output):find('stage=',1,true))
locked=false;assert(tick());assert(emitted[#emitted].free=='mind lock Bob' and not emitted[#emitted].bal)
assert(not tick(),'Re-establishment must not generate a new resource wait or duplicate request')
target='Alice';M.note_room_player('Alice',true)
assert(tick());assert(emitted[#emitted].free=='mind lock Alice' and not emitted[#emitted].bal,'Old-target BAL debt must survive target changes')
assert(M.snapshot().lock_plan.stage=='prepare')
assert(M.note_target_grace('Alice'));assert(not M.is_enabled())
M.alias('on');assert(not tick(),'Restart cannot bypass old-target physical debt or new Hyperfocus requirement')
F.set_form('rain');recover();assert(tick());assert(emitted[#emitted].bal:find('hyperfocus head',1,true))
M.note_hyperfocus('head');M.note_full_recovery();M.alias('off');M.alias('on')
assert(tick(),'Historical focus confirmation must survive rapid off/on recovery')
assert(emitted[#emitted].bal:find('hyperfocus head',1,true))
M.note_hyperfocus('head');M.note_full_recovery();Legacy.Settings.Curing.status=false
assert(not tick() and M.status().hold_reason=='curing_paused')
Legacy.Settings.Curing.status=true;Yso.monk.kai={deliverance={state='active'}}
assert(not tick() and M.status().hold_reason=='deliverance')
Yso.monk.kai.deliverance.state='idle'
Yso.self.is_prone=function() return true end;assert(not tick())
Yso.self.is_prone=function() return false end
Yso.self.has_aff=function(name) return name=='paralysis' end;assert(not tick())
Yso.self.has_aff=function() return false end
assert(tick());assert(emitted[#emitted].free=='mind lock Alice' and emitted[#emitted].bal,'Free lock and physical assault must be able to share one payload')
locked=true;affs.impatience=nil;clock=clock+3;recover()
local function closing_window()
  affs.anorexia=true;affs.asthma=true;affs.slickness=true;affs.paralysis=true
  M.state.lock_plan={target=target,stage='harden'};F.set_form('willow');F.set_kata(4)
  if M.state.cooldown then M.state.cooldown.next_lock_plan={stage='harden'} end
end
closing_window()
assert(tick());assert(emitted[#emitted].eq=='mind impatience Alice')

assert(M.note_resource_refusal('bal'),'Exact balance refusal must correlate with the fresh mental send')
assert(not M.is_enabled() and not M.state.mental,'A refused cast must not create phantom EQ debt')
M.alias('on');recover();assert(tick())
-- Restart first re-establishes Hyperfocus; explicitly acknowledge its recovery.
M.note_hyperfocus('head');M.note_full_recovery();closing_window();assert(tick())
assert(emitted[#emitted].eq=='mind impatience Alice')
gmcp.Char.Vitals.eq='0';M.note_vitals()
assert(M.note_resource_refusal('eq'))
assert(M.state.mental and M.state.mental.eq_down,'A refusal cannot erase already observed EQ debt')
M.alias('on');clock=clock+3
assert(not M.note_resource_refusal('bal'),'An old action cannot absorb an unrelated denial')
M.state.mental.at=clock
assert(M.note_target_unavailable(),'A fresh independent EQ cast refusal must correlate even when the physical send is old')
assert(not M.is_enabled() and M.state.mental and M.state.mental.eq_down,'Refusal must preserve actual EQ recovery debt')
gmcp.Char.Vitals.eq='1';M.note_vitals();M.alias('on');M.note_local_target_activity('Alice')
M.note_room_player('Alice',false);assert(not tick())
gmcp.Char.Vitals.hp='0';assert(not tick() and not M.is_enabled())
gmcp.Char.Vitals.hp='5000';M.alias('on');M.state.pending=nil;M.state.cooldown=nil
M.state.mental={kind='mental',lane='eq',target='Alice',at=clock-11}
assert(not tick() and not M.is_enabled())
assert(table.concat(output):find('Timeout: mental target=Alice lane=eq down=false recovered=false',1,true),'Timeouts must identify the stale resource record')
print('PASS staged lock controller: free mindlock, recovered mental openings, exact refusals, confirmed stages, recovery debt, pauses, target changes, timeout diagnostics')
