-- Behavioral regressions: route selection, confirmed delivery, and finisher lifecycle.
local root=arg[1] or 'Ysindrolir'
local clock,serial,emitted,sent,events=100,0,{},{},{}
getEpoch=function() return clock end
local timers={}
tempTimer=function(delay,fn) serial=serial+1;timers[serial]={at=clock+delay,fn=fn};return serial end
killTimer=function(id) timers[id]=nil end
cecho=function() end
send=function() end -- scheduler configuration sends are separate from the Catharsis batch
sendAll=function(...) for _,c in ipairs({...}) do sent[#sent+1]=c end end
registerAnonymousEventHandler=function(e,f) events[e]=events[e] or {};table.insert(events[e],f);return f end
killAnonymousEventHandler=function() end
raiseEvent=function(e,...) for _,f in ipairs(events[e] or {}) do f(...) end end
enableTrigger=function() end;disableTrigger=function() end
target='Saibel'
gmcp={Char={Status={class='Apostate'},Vitals={bal='1',eq='1',mp='6817'}}}
Yso={get_target=function() return target end}
local paused=false
local support_emitted={}
Yso.offense_paused=function() return paused end
Yso.emit=function(p,o)
 if paused then return false end
 local log=o.reason=='apostate_truelock:support' and support_emitted or emitted
 log[#log+1]=p;return true
end
affstrack={score={},venoms={digitalis='shyness',curare='paralysis',kalmia='asthma',gecko='slickness',slike='anorexia',
 vernalius='weariness',aconite='stupidity',eurypteria='recklessness',voyria='voyria',notechis='haemophilia',selarnia='selarnia'}}
local cls='apostate';local extras={'voyria'}
ak={ai=function() return false end,classlockresolve=function() return extras end,
 classlockresolveclass=function() return cls end,scoreup=function() end}
dofile(root..'/Apostate/ak_target_check.lua')
if TruelocksTargetCheck then TruelocksTargetCheck() end
OppGainedAff=function(a,source) for k in a:gmatch('%S+') do affstrack.score[k]=100 end end
OppLostAff=function(a) affstrack.score[a]=0 end
dofile(root..'/Yso/Combat/route_registry.lua')
dofile(root..'/Yso/xml/yso_modes.lua')
dofile(root..'/Apostate/evileye_reference.lua')
dofile(root..'/Apostate/necromancy_reference.lua')
dofile(root..'/Apostate/deadeyes.lua')
dofile(root..'/Yso/xml/apostate_utilities.lua')
dofile(root..'/Apostate/ak_tracking.lua')
dofile(root..'/Apostate/daegger_envenom.lua')
local M=dofile(root..'/Apostate/truelock.lua')
local D=Yso.apostate.daegger
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function tick() return Yso.mode.tick_route_loop(M.key) end
local function reset()
 if M.is_enabled() then Yso.mode.stop_route_loop(M.key,'test',true) end
 clock=clock+20;emitted={};support_emitted={};sent={};affstrack.score={};ak.apostate.reset_tracking()
 target='Saibel';cls='apostate';extras={'voyria'};paused=false;ak.defs={}
 gmcp.Char.Status.class='Apostate';gmcp.Char.Vitals.bal='1';gmcp.Char.Vitals.eq='1';gmcp.Char.Vitals.mp='6817'
 currentvenoms={};D.stock.notechis=false
end
local function start()
 if TruelocksAlias then TruelocksAlias() else assert(Yso.util.toggle_route_alias('apostate_truelock','tlock')) end
end
local function full() for _,a in ipairs({'paralysis','impatience','asthma','slickness','anorexia','weariness','stupidity','recklessness','clumsiness','addiction','voyria','manaleech','dizziness','epilepsy','shyness','sensitivity'}) do affstrack.score[a]=100 end end
local function eye(k) ak.apostate.capture_eye(target,k) end
local function prompt() ak.apostate.commit_eyes();M.note_prompt() end
local function ward_down(kind)
 if TruelocksWardResponses then TruelocksWardResponses[kind]() else ak.defs.curseward=false end
 eq(ak.defs.curseward,false)
end
local function scheduled()
 local id=M.state.timer_id;local timer=assert(timers[id],'route must schedule its next tick')
 timers[id]=nil;clock=math.max(clock,timer.at);timer.fn()
end
-- Stable RNG makes route assertions reproducible; the padding suite tests actual randomness.
math.random=function() return 1 end
local function deliver()
 local cmd=emitted[#emitted].bal
 local first,second=cmd:match('^deadeyes %S+ (%S+) (%S+)$')
 if first then eye(first);eye(second) else eye(assert(cmd:match('^stare %S+ (%S+)$'))) end
 prompt();clock=clock+3
end
reset();start();scheduled();eq(emitted[1].bal,'deadeyes Saibel impatience dizzy')
eq(affstrack.score.impatience,nil);eq(affstrack.score.dizziness,nil)
scheduled();eq(#emitted,1)
deliver();scheduled();eq(emitted[2].bal,'stare Saibel epilepsy')
deliver();scheduled();eq(emitted[3].bal,'deadeyes Saibel asthma clumsy')
deliver();scheduled();eq(emitted[4].bal,'stare Saibel sensitivity')
deliver();scheduled();eq(emitted[5].bal,'deadeyes Saibel manaleech stupid')
deliver();scheduled();eq(emitted[6].bal,'deadeyes Saibel sicken anorexia')
deliver();eq(affstrack.score.slickness,100);eq(affstrack.score.anorexia,100)
-- Independent EQ support may still be recovering; wait for it before closing eyes.
clock=clock+3;scheduled();eq(emitted[7].bal,'stare Saibel plague')
deliver();scheduled();eq(emitted[8].bal,'stare Saibel paralysis')
deliver();scheduled();eq(emitted[9].eq,'demon corrupt Saibel paralysis')
-- Old shipped orders migrate; custom requirements survive but cannot bypass stages.
local new_default={'impatience','asthma','manaleech','slickness','anorexia','paralysis'}
for _,old in ipairs({
 {'paralysis','impatience','asthma','slickness','anorexia','weariness','stupidity','recklessness'},
 {'paralysis','asthma','slickness','impatience','anorexia','weariness','stupidity','recklessness','clumsiness','addiction'},
 {'paralysis','clumsiness','addiction','asthma','slickness','impatience','anorexia','weariness','stupidity','recklessness'},
}) do
 M.priorities=old;dofile(root..'/Apostate/truelock.lua');eq(table.concat(M.priorities,','),table.concat(new_default,','))
end
local custom={'paralysis','addiction'};M.priorities=custom;dofile(root..'/Apostate/truelock.lua')
eq(M.priorities,custom);reset();start();scheduled();eq(emitted[1].bal,'deadeyes Saibel impatience dizzy')
M.priorities=new_default
-- Half-confidence main afflictions and padding advance without rewriting AK scores.
reset();affstrack.score={impatience=50,dizziness=50,epilepsy=50,asthma=50,clumsiness=50,sensitivity=50}
start();scheduled();eq(emitted[1].bal,'deadeyes Saibel manaleech stupid')
eq(affstrack.score.impatience,50);eq(affstrack.score.asthma,50)
reset();full();affstrack.score.impatience=50;start();scheduled()
eq(emitted[1].bal,'stare Saibel impatience') -- Corrupt still needs confirmed core scores.
-- Random Digitalis padding uses a real venom delivery; unknown stock holds safely.
reset();affstrack.score={impatience=100,stupidity=100}
local random=math.random;math.random=function(n) return n end
D.stock.digitalis=nil;dofile(root..'/Apostate/daegger_envenom.lua');eq(D.available('digitalis'),true)
for _,stock in ipairs({false,0,12}) do
 D.stock.digitalis=stock;dofile(root..'/Apostate/daegger_envenom.lua');eq(D.stock.digitalis,stock)
end
D.stock.digitalis=true
start();scheduled()
eq(emitted[1].bal,'wipe daegger&&envenom daegger with digitalis&&daegger puncture Saibel')
math.random=random
-- Sicken only follows confirmed manaleech, and never gets selected for damage alone.
reset();full();affstrack.score.manaleech=50;affstrack.score.slickness=0;start();scheduled()
assert(emitted[1].bal:find('manaleech',1,true));assert(not emitted[1].bal:find('sicken',1,true))
deliver();clock=clock+3;scheduled();eq(emitted[2].bal,'stare Saibel sicken')
deliver();eq(affstrack.score.slickness,100)
-- Recipient matching, actual Curseward adapters, and rejected second eyes remain intact.
target='MAldrantus';eq(IsTargetted('Maldrantus'),true);eq(IsTargetted('Other'),false)
target='mal';eq(IsTargetted('Maldrantus'),true);target='Saibel'
if TruelocksTargetCheck then
 for _,response in ipairs({'mixed_no_effect','mixed_shattered'}) do
  reset();target='MAldrantus';ak.defs.curseward=true;start();scheduled()
  ak.apostate.capture_eye('Maldrantus','breach');ward_down(response)
  ak.apostate.capture_eye('Maldrantus','impatience');prompt()
  eq(M.state.pending,nil);clock=clock+3;scheduled()
  eq(emitted[2].bal,'deadeyes MAldrantus dizzy epilepsy')
 end
end
reset();ak.defs.curseward=true;start();scheduled()
eq(emitted[1].bal,'deadeyes Saibel breach impatience')
eye('breach');eye('impatience');prompt();clock=clock+3;scheduled();eq(#emitted,1)
ward_down('shattered');M.note_prompt();scheduled();eq(emitted[2].bal,'deadeyes Saibel dizzy epilepsy')
eye('dizzy');eye('epilepsy');ak.apostate.fail_eye();prompt()
eq(affstrack.score.dizziness,100);eq(affstrack.score.epilepsy,nil)
clock=clock+3;scheduled();eq(emitted[3].bal,'stare Saibel epilepsy')
-- Combined mana cost (Breach 125 + Impatience 45), readiness, pause and shield.
reset();ak.defs.curseward=true;gmcp.Char.Vitals.mp='169';start();scheduled()
eq(#emitted,0);eq(M.status().reason,'mana');gmcp.Char.Vitals.mp='170';scheduled()
eq(emitted[1].bal,'deadeyes Saibel breach impatience')
reset();start();paused=true;eq(tick(),false);eq(#emitted,0);paused=false
gmcp.Char.Vitals.bal='0';eq(tick(),false);gmcp.Char.Vitals.bal='1'
gmcp.Char.Vitals.eq='0';eq(tick(),false);gmcp.Char.Vitals.eq='1'
ak.defs.shield=true;eq(tick(),false);ak.defs.shield=false
Yso.inhibit={active=function() return true end};eq(tick(),false);Yso.inhibit=nil
tick();target='Other';M.note_prompt();eq(M.is_enabled(),false)
local quiet=cecho;local stops=0
cecho=function(s) if s:find('OFF (confirmation_timeout)',1,true) then stops=stops+1 end end
reset();start();scheduled();clock=clock+11;scheduled();eq(M.is_enabled(),false);eq(stops,1);cecho=quiet
reset();start();scheduled();start();eq(M.is_enabled(),false);eq(M.state.pending,nil)
-- Venom-only class requirements bypass Curseward and do not need EQ readiness.
reset();full();cls='magi';extras={'haemophilia'};ak.defs.curseward=true;D.stock.notechis=true
gmcp.Char.Vitals.eq='0';start();scheduled()
eq(emitted[1].bal,'wipe daegger&&envenom daegger with notechis&&daegger puncture Saibel')
eq(ak.defs.curseward,true)
currentvenoms={['a wicked-looking daegger']={'notechis'}}
ak.apostate.puncture('Other');eq(affstrack.score.haemophilia,nil)
currentvenoms['a wicked-looking daegger']={'notechis'};ak.apostate.puncture('Saibel');prompt()
eq(affstrack.score.haemophilia,100)
reset();full();cls='magi';extras={'haemophilia'};start();tick();eq(M.status().reason,'missing_venom:notechis')
reset();full();extras={'prone'};start();tick();eq(M.status().reason,'unsupported_affliction:prone')
reset();full();cls='';start();eq(tick(),false);eq(M.status().reason,'class_coverage_unverified')
-- Corrupt provenance and the existing solicited Contemplate/Catharsis lifecycle.
reset();full();eye('asthma');eye('paralysis');prompt();start();tick()
eq(emitted[1].eq,'demon corrupt Saibel paralysis');eq(tick(),false)
M.note_corrupt('accepted','Saibel');M.note_corrupt('retained','Saibel','paralysis');M.note_prompt()
eq(affstrack.score.asthma,0);eq(affstrack.score.paralysis,100);eq(affstrack.score.weariness,100)
tick();eq(emitted[2].free,'contemplate Saibel');eq(Yso.apostate.note_mana('Other',1,100),false)
Yso.apostate.note_mana('Saibel',49,100);eq(#sent,0)
gmcp.Char.Vitals.eq='0';eq(tick(),false);clock=clock+3.1;gmcp.Char.Vitals.eq='1'
tick();eq(emitted[3].free,'contemplate Saibel');Yso.apostate.note_mana('Saibel',49,100)
eq(sent[1],'cq all');eq(sent[2],'demon catharsis Saibel');eq(M.is_enabled(),false)
reset();full();start();tick();M.note_corrupt('accepted','Saibel');M.note_corrupt('rejected','Saibel');M.note_prompt()
eq(M.is_enabled(),false)
reset();full();start();tick();M.note_corrupt('accepted','Saibel');M.note_prompt();tick()
Yso.apostate.note_mana('Saibel',50,100);eq(M.status().phase,'pressure');eq(#sent,0)
reset();full();start();tick();M.note_corrupt('accepted','Saibel');M.note_prompt();tick()
clock=clock+11;tick();eq(M.is_enabled(),false);Yso.apostate.note_mana('Saibel',49,100);eq(#sent,0)
Yso.apostate.catharsis_sent_at=nil;Yso.apostate.note_mana('Saibel',49,100);eq(sent[2],'demon catharsis Saibel')
reset();full();start();tick();M.note_corrupt('accepted','Saibel');M.note_prompt();tick();start()
Yso.apostate.note_mana('Saibel',49,100);eq(#sent,0)
-- EQ support is independent of BAL pressure and never infers afflictions on send.
local function support_case(scores)
 reset();affstrack.score=scores;gmcp.Char.Vitals.bal='0';start();scheduled()
end
support_case({asthma=100,manaleech=100})
eq(#support_emitted,1);eq(support_emitted[1].eq,'disfigure Saibel')
eq(affstrack.score.disloyalty,nil);eq(#emitted,0)
scheduled();eq(#support_emitted,1)
clock=clock+2.7;scheduled();eq(#support_emitted,1)
clock=clock+0.2;scheduled();eq(#support_emitted,2)
affstrack.score.disloyalty=100;clock=clock+3;scheduled();eq(#support_emitted,2)
affstrack.score.disloyalty=0;scheduled();eq(#support_emitted,3)
-- Zero/partial scores do not satisfy the two confirmed affliction prerequisites.
for _,scores in ipairs({{asthma=0,manaleech=0},{asthma=99,manaleech=100},{asthma=100,manaleech=99}}) do
 support_case(scores);eq(#support_emitted,0)
end
for _,aff in ipairs({'slickness','anorexia'}) do
 support_case({[aff]=100});eq(support_emitted[1].eq,'chill Saibel')
 eq(affstrack.score.frozen,nil);clock=clock+2.1;scheduled();eq(#support_emitted,1)
 clock=clock+0.2;affstrack.score.frozen=100;scheduled()
 eq(support_emitted[2].eq,'shrivel left leg Saibel');eq(affstrack.score.leftleg,nil)
 -- Either confirmed leg is sufficient padding: never go after the second leg.
 affstrack.score.leftleg=100;clock=clock+3;scheduled();eq(#support_emitted,2)
 affstrack.score.leftleg=0;affstrack.score.rightleg=100;scheduled();eq(#support_emitted,2)
 affstrack.score.rightleg=0;scheduled();eq(support_emitted[3].eq,'shrivel left leg Saibel')
end
support_case({slickness=99,anorexia=0,frozen=100});eq(#support_emitted,0)
support_case({slickness=100,frozen=99});eq(support_emitted[1].eq,'chill Saibel')
support_case({frozen=100});eq(#support_emitted,0)
-- Priority is Disfigure, frozen-target Shrivel, then Chill.
support_case({asthma=100,manaleech=100,slickness=100,frozen=100})
eq(support_emitted[1].eq,'disfigure Saibel');affstrack.score.disloyalty=100
clock=clock+3;scheduled();eq(support_emitted[2].eq,'shrivel left leg Saibel')
-- Eye attacks need EQ readiness too, despite spending BAL. Puncture remains BAL-only.
reset();gmcp.Char.Vitals.eq='0';start();scheduled();eq(#emitted,0);eq(M.state.pending,nil)
gmcp.Char.Vitals.eq='1';scheduled();eq(emitted[1].bal,'deadeyes Saibel impatience dizzy')
-- Reproduce the log: Disfigure spends EQ, Curseward comes up, and BAL returns first.
reset();affstrack.score={asthma=100,manaleech=100};start();scheduled()
eq(emitted[1].bal,'deadeyes Saibel impatience dizzy');eq(support_emitted[1].eq,'disfigure Saibel')
local pressure_pending=M.state.pending;scheduled();eq(M.state.pending,pressure_pending)
eye('impatience');eye('dizzy');prompt();affstrack.score.disloyalty=100
ak.defs.curseward=true;gmcp.Char.Vitals.eq='0';clock=clock+2;scheduled()
eq(#emitted,1);eq(M.state.pending,nil);eq(M.is_enabled(),true)
gmcp.Char.Vitals.eq='1';clock=clock+1;scheduled()
eq(emitted[2].bal,'deadeyes Saibel breach epilepsy');eq(#support_emitted,1)
-- Explicit rejections cannot leave an unexecuted eye batch waiting for a hit.
eq(type(M.note_eye_rejected),'function')
local function reject(reason,name)
 if TruelocksEyeRejections and TruelocksEyeRejections[reason] and not name then
  TruelocksEyeRejections[reason]()
 else M.note_eye_rejected(reason,name) end
end
for _,lane in ipairs({'equilibrium','balance'}) do
 reset();start();scheduled();local p=M.state.pending
 reject(lane);eq(M.state.pending,p);prompt();eq(M.state.pending,nil)
 gmcp.Char.Vitals[lane=='equilibrium' and 'eq' or 'bal']='0'
 clock=clock+11;scheduled();eq(#emitted,1);eq(M.is_enabled(),true)
 gmcp.Char.Vitals[lane=='equilibrium' and 'eq' or 'bal']='1'
 ak.defs.curseward=true;scheduled();eq(emitted[2].bal,'deadeyes Saibel breach impatience')
end
reset();start();scheduled();local before=M.state.pending
reject('curseward','Other');eq(before.rejected,nil)
reject('curseward');prompt();eq(M.state.pending,nil);eq(ak.defs.curseward,true)
clock=clock+3;scheduled();eq(emitted[2].bal,'deadeyes Saibel breach impatience')
-- A rejected second eye does not erase the first eye's confirmed affliction.
reset();start();scheduled();eye('impatience')
if TruelocksEyeRejections then TruelocksEyeRejections.curseward_stare() else reject('curseward') end
prompt();eq(affstrack.score.impatience,100);eq(affstrack.score.dizziness,nil)
clock=clock+3;scheduled();eq(emitted[2].bal,'deadeyes Saibel breach dizzy')
reset();start();scheduled();reject('blind');eq(M.is_enabled(),false)
eq(M.state.template.last_disable_reason,'eyes_blind')
-- Non-Evileye actions remain usable through Curseward.
for _,case in ipairs({
 {scores={asthma=100,manaleech=100},cmd='disfigure Saibel'},
 {scores={slickness=100},cmd='chill Saibel'},
 {scores={slickness=100,frozen=100},cmd='shrivel left leg Saibel'},
}) do
 reset();affstrack.score=case.scores;ak.defs.curseward=true;gmcp.Char.Vitals.bal='0'
 start();scheduled();eq(support_emitted[1].eq,case.cmd)
end
reset();full();ak.defs.curseward=true;start();scheduled()
eq(emitted[1].eq,'demon corrupt Saibel paralysis')
local corrupt_pending=M.state.pending;reject('equilibrium');eq(M.state.pending,corrupt_pending)
eq(corrupt_pending.rejected,nil)
-- Support also runs while a prior BAL batch awaits confirmation, without replacing it.
reset();start();scheduled();local pending=M.state.pending
affstrack.score.asthma=100;affstrack.score.manaleech=100;scheduled()
eq(support_emitted[1].eq,'disfigure Saibel');eq(M.state.pending,pending)
-- Readiness, resource, pause, shield and target gates apply to support.
for _,gate in ipairs({'eq','mana','pause','shield','inhibit','dead','ak_target'}) do
 reset();affstrack.score={slickness=100,frozen=100};gmcp.Char.Vitals.bal='0'
 if gate=='eq' then gmcp.Char.Vitals.eq='0'
 elseif gate=='mana' then gmcp.Char.Vitals.mp='299'
 elseif gate=='pause' then paused=true
 elseif gate=='shield' then ak.defs.shield=true
 elseif gate=='inhibit' then Yso.inhibit={active=function() return true end}
 elseif gate=='dead' then gmcp.Char.Vitals.dead='1'
 elseif gate=='ak_target' then Yso.get_target=function() return 'Other' end end
 start();scheduled();eq(#support_emitted,0)
 Yso.inhibit=nil;gmcp.Char.Vitals.dead=nil;Yso.get_target=function() return target end
end
-- Complete lock and pending finisher retain EQ; support cannot postpone Corrupt.
reset();full();affstrack.score.manaleech=100;start();scheduled()
eq(emitted[1].eq,'demon corrupt Saibel paralysis');eq(#support_emitted,0)
scheduled();eq(#support_emitted,0)
-- Stop/reset removes support timing and any subsequent scheduled attacks.
-- Do not spend the same reported mana twice when BAL and EQ fire together.
reset();affstrack.score={slickness=100,frozen=100};gmcp.Char.Vitals.mp='394';start();scheduled()
eq(emitted[1].bal,'deadeyes Saibel impatience dizzy');eq(#support_emitted,0)
scheduled();eq(#support_emitted,0) -- same stale vitals while Deadeyes is still pending
gmcp.Char.Vitals.mp='299';scheduled();eq(#support_emitted,0) -- updated mana already includes BAL cost
gmcp.Char.Vitals.mp='300';scheduled();eq(support_emitted[1].eq,'shrivel left leg Saibel')
reset();affstrack.score={slickness=100,frozen=100};gmcp.Char.Vitals.mp='395';start();scheduled()
eq(support_emitted[1].eq,'shrivel left leg Saibel')
support_case({slickness=100});eq(#support_emitted,1);start()
eq(M.state.support_until,nil);eq(M.state.timer_id,nil)
reset();affstrack.score={slickness=100};gmcp.Char.Vitals.bal='0';start();scheduled()
eq(support_emitted[1].eq,'chill Saibel');target='Other';scheduled();eq(M.is_enabled(),false)
eq(#support_emitted,1);eq(M.state.support_until,nil)
print('PASS Apostate Truelocks lifecycle, pressure, conditional EQ support, Corrupt and Catharsis')
