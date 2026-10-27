-- Route-owned burst: confirmed Corrupt, balanceless Contemplate, and one Sap/rebuild.
local root=arg[1] or 'Ysindrolir'
local clock,sent,consumed=100,{},0
getEpoch=function() return clock end
local trigger_id=0
local triggers={}
tempRegexTrigger=function(pattern,callback)
 trigger_id=trigger_id+1;triggers[trigger_id]={pattern=pattern,callback=callback};return trigger_id
end
killTrigger=function(id) triggers[id]=nil end
target='Saibel'
gmcp={Char={Status={class='Apostate'},Vitals={bal='1',eq='1',mp='1000'}}}
ak={defs={}};affstrack={score={}}
Yso={get_target=function() return target end,
 mode={is_combat=function() return true end},
 send=function(command) sent[#sent+1]={free=command};return true end,
 emit=function(payload) sent[#sent+1]=payload;return true end}
dofile(root..'/Yso/xml/apostate_utilities.lua')
dofile(root..'/Apostate/evileye_reference.lua')
local M=dofile(root..'/Apostate/lock_route.lua')
assert(type(M.note_corrupt)=='function','missing confirmed Corrupt adapter')
assert(type(M.note_corrupt_started)=='function','missing Corrupt accepted-output adapter')
assert(type(M.note_mana)=='function','missing route-owned Contemplate response')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function full()
 return {deaf=100,paralysis=100,impatience=100,asthma=100,manaleech=100,
  slickness=100,anorexia=100,disloyalty=100}
end
OppLostAff=function(aff) affstrack.score[aff]=0 end
OppGainedAff=function(aff) affstrack.score[aff]=100 end
dofile(root..'/Apostate/ak_tracking.lua')
local original_consume=ak.apostate.consume_corrupt
ak.apostate.consume_corrupt=function(name,retained)
 consumed=consumed+1
 return original_consume(name,retained)
end
local function reset(scores)
 target='Saibel';clock=clock+20;sent={};consumed=0
 M.alias_loop_prepare_start({});M.state.loop_enabled=true;M.state.victim=target
 Yso.offense_paused=nil;Yso.inhibit=nil;Yso.apostate.cancelled_contemplates={};Yso.apostate.cancelled_corrupts={}
 ak.defs={};affstrack.score=scores or full();ak.apostate.evileye_active={}
 for _,aff in ipairs({'paralysis','impatience','asthma','manaleech','slickness','anorexia'}) do
  ak.apostate.evileye_active[aff]='saibel'
 end
 gmcp.Char.Vitals={bal='1',eq='1',mp='1000'}
end

-- The supplied two-line combat output installs both confirmation adapters by default.
local started_pattern,retained_pattern=M.Corrupt_success_pattern,M.Corrupt_retained_pattern
assert(type(started_pattern)=='string' and type(retained_pattern)=='string')
assert(M.corrupt_trigger and M.corrupt_retained_trigger)
M.configure_corrupt_confirmation(nil)
reset();assert(not M.attack_function());eq(#sent,0)
eq(M.state.reason,'corrupt_confirmation_unconfigured')
assert(M.configure_corrupt_confirmation(started_pattern,retained_pattern))
local function corrupt()
 assert(M.attack_function());eq(sent[#sent].eq,'demon corrupt Saibel anorexia')
 eq(consumed,0);eq(affstrack.score.paralysis,100)
 assert(not M.attack_function());eq(#sent,1)
end
local function confirm()
 assert(M.note_corrupt_started('Saibel'))
 assert(M.note_corrupt('Saibel','anorexia'))
 M.note_prompt()
 eq(consumed,1);eq(affstrack.score.anorexia,100)
 eq(affstrack.score.paralysis,0);eq(affstrack.score.asthma,0)
 eq(affstrack.score.disloyalty,100)
end
local function contemplate()
 gmcp.Char.Vitals.bal='0';gmcp.Char.Vitals.eq='0'
 assert(not M.attack_function());eq(#sent,1)
 gmcp.Char.Vitals.bal='1'
 assert(M.attack_function());eq(sent[2].free,'contemplate Saibel')
 eq(sent[2].eq,nil);eq(sent[2].bal,nil)
 assert(not M.attack_function());eq(#sent,2)
end

-- Confirmed full lock and ready EQ are prerequisites; Corrupt does not need BAL.
reset();gmcp.Char.Vitals.eq='0';assert(not M.attack_function());eq(#sent,0)
gmcp.Char.Vitals.eq='1';gmcp.Char.Vitals.bal='0';corrupt()
assert(not M.note_corrupt_started('Other'));eq(consumed,0)
assert(not M.note_corrupt('Other','anorexia'));eq(consumed,0)
assert(not M.note_corrupt('Saibel','anorexia'));eq(consumed,0) -- Retention alone is not acceptance.
assert(not M.note_corrupt('Saibel','paralysis'));eq(consumed,0)
confirm();assert(not M.note_corrupt('Saibel','anorexia'));eq(consumed,1)
contemplate()

-- Bad or unrelated reports cannot consume the outstanding request.
assert(not M.note_mana('Other',1,100))
for _,values in ipairs({{-1,100},{101,100},{1,0},{1,-100},{0/0,100},{1,math.huge}}) do
 assert(not M.note_mana('Saibel',values[1],values[2]))
end
assert(Yso.apostate.note_mana('Saibel',49,100))
assert(not M.note_mana('Saibel',80,100))
assert(not M.attack_function());eq(#sent,2) -- EQ remains down.
clock=clock+3;gmcp.Char.Vitals.eq='1'
Yso.offense_paused=function() return true end
assert(not M.attack_function());eq(#sent,2)
Yso.offense_paused=nil;assert(M.attack_function())
eq(sent[3].eq,'demon catharsis Saibel');eq(M.is_enabled(),true)
assert(not M.attack_function());eq(#sent,3)
gmcp.Char.Vitals.eq='0';M.note_prompt()
clock=clock+5;gmcp.Char.Vitals.eq='1'
assert(not M.attack_function());eq(M.is_enabled(),false)

-- Exactly half mana selects one Sap, then normal pressure resumes, not Contemplate.
reset();corrupt();confirm();contemplate()
assert(Yso.apostate.note_mana('Saibel',50,100))
clock=clock+3;gmcp.Char.Vitals.eq='1'
assert(M.attack_function());eq(sent[3].eq,'demon sap Saibel')
assert(not M.attack_function());eq(#sent,3)
gmcp.Char.Vitals.eq='0';assert(not M.attack_function())
clock=clock+3;gmcp.Char.Vitals.eq='1'
assert(M.attack_function());eq(sent[4].bal,'deadeyes Saibel paralysis impatience')
M.note_pressure('eyes','Saibel');M.note_prompt()
affstrack.score=full();clock=clock+3
assert(M.attack_function());eq(sent[5].eq,'demon corrupt Saibel anorexia')

-- A lock missing Disloyalty still gets Disfigure before any burst.
local incomplete=full();incomplete.disloyalty=0
reset(incomplete);assert(M.attack_function());eq(sent[1].eq,'disfigure Saibel')

-- An actual retained-affliction mismatch settles the real outcome before stopping.
reset();corrupt();assert(M.note_corrupt_started('Saibel'))
assert(not M.note_corrupt('Saibel','manaleech'))
eq(consumed,1);eq(affstrack.score.manaleech,100);eq(affstrack.score.anorexia,0)
eq(affstrack.score.paralysis,0);eq(M.is_enabled(),false);eq(#sent,1)
assert(not M.attack_function());eq(#sent,1)

-- Missing confirmations and missing mana reports stop without issuing follow-ups.
reset();corrupt();clock=clock+11
assert(not M.attack_function());eq(M.is_enabled(),false);eq(#sent,1)

-- A cancelled Corrupt response cannot confirm a restarted same-target attempt.
reset();corrupt();M.stop('manual')
M.alias_loop_prepare_start({});M.state.loop_enabled=true;M.state.victim=target
clock=clock+3;assert(not M.attack_function());eq(#sent,1)
eq(M.state.reason,'waiting_cancelled_corrupt')
assert(not M.note_corrupt('Saibel','anorexia'));eq(consumed,0)
assert(M.attack_function());eq(sent[2].eq,'demon corrupt Saibel anorexia')
assert(M.note_corrupt_started('Saibel'))
assert(M.note_corrupt('Saibel','anorexia'));eq(consumed,1)

-- No reply after cancellation produces a visible, explicitly resettable hold.
reset();corrupt();M.stop('manual')
M.alias_loop_prepare_start({});M.state.loop_enabled=true;M.state.victim=target
clock=clock+30;assert(not M.attack_function());eq(#sent,1)
eq(M.state.reason,'waiting_cancelled_corrupt')
assert(not M.clear_cancelled_finishers('Saibel')) -- Cannot reconcile during offense.
M.stop('manual');assert(M.clear_cancelled_finishers('Saibel'))
M.alias_loop_prepare_start({});M.state.loop_enabled=true;M.state.victim=target
assert(M.attack_function());assert(M.note_corrupt_started('Saibel'))
assert(M.note_corrupt('Saibel','anorexia'))
reset();corrupt();confirm();contemplate();clock=clock+11
assert(not M.attack_function());eq(M.is_enabled(),false);eq(#sent,2)

-- Cancelled Contemplate replies are consumed before the standalone helper.
reset();corrupt();confirm();contemplate();M.stop('manual')
eq(Yso.apostate.cancelled_contemplates.saibel,1)
sendAll=function() error('late route response attempted standalone Catharsis') end
assert(not Yso.apostate.note_mana('Saibel',1,100))
eq(Yso.apostate.cancelled_contemplates.saibel,0);eq(#sent,2)
assert(not M.note_corrupt('Saibel','anorexia'))

-- An unanswered cancelled mana query holds the next burst before another send.
reset();corrupt();confirm();contemplate();M.stop('manual')
affstrack.score=full()
M.alias_loop_prepare_start({});M.state.loop_enabled=true;M.state.victim=target
clock=clock+30;assert(not M.attack_function());eq(#sent,2)
eq(M.state.reason,'waiting_cancelled_contemplate')
assert(not Yso.apostate.note_mana('Saibel',1,100)) -- Drain only the old request.
gmcp.Char.Vitals.eq='1'
assert(M.attack_function());eq(sent[3].eq,'demon corrupt Saibel anorexia')

-- A target change cancels the pending burst rather than retargeting it.
reset();corrupt();target='Other'
assert(not M.note_corrupt('Saibel','anorexia'));eq(consumed,0)
assert(not M.attack_function());eq(M.is_enabled(),false);eq(#sent,1)

-- Replay the registered callbacks with the captured screenshot's two lines.
local function accepted_output(name)
 matches={'You command your baalzadeen to corrupt the soul of '..name..'.',name}
 triggers[M.corrupt_trigger].callback()
end
local function retained_output(name,aff)
 matches={'Your Baalzadeen informs you that the '..aff..' affliction still burdens '..name..'.',aff,name}
 triggers[M.corrupt_retained_trigger].callback()
end
reset();corrupt()
retained_output('Saibel','anorexia');eq(consumed,0)
accepted_output('Other');eq(M.state.pending.accepted,nil)
accepted_output('Saibel');eq(M.state.pending.accepted,true);eq(consumed,0)
retained_output('Other','anorexia');eq(consumed,0)
retained_output('Saibel','manaleech')
eq(consumed,1);eq(affstrack.score.manaleech,100);eq(affstrack.score.anorexia,0)
eq(M.is_enabled(),false);eq(#sent,1)
reset();corrupt();accepted_output('Saibel');retained_output('Saibel','anorexia')
eq(consumed,1);eq(affstrack.score.anorexia,100);eq(M.state.finisher.phase,'contemplate')
contemplate()

-- Self paralysis must pause every phase without consuming its next action.
local self_paralyzed=false
Yso.self={has_aff=function(aff) return aff=='paralysis' and self_paralyzed end}
for _,phase in ipairs({'corrupt','contemplate','catharsis','sap'}) do
 reset()
 if phase~='corrupt' then corrupt();confirm() end
 if phase=='catharsis' or phase=='sap' then
  contemplate();assert(Yso.apostate.note_mana('Saibel',phase=='sap' and 50 or 49,100))
  clock=clock+3;gmcp.Char.Vitals.eq='1'
 end
 local before=#sent
 self_paralyzed=true
 local ok,reason=M.attack_function()
 eq(ok,false);eq(reason,'paralysis');eq(#sent,before);eq(M.is_enabled(),true)
 eq(M.state.pending,nil)
 self_paralyzed=false
 assert(M.attack_function());eq(#sent,before+1)
 local expected=phase=='contemplate' and 'contemplate Saibel' or ('demon '..phase..' Saibel'..(phase=='corrupt' and ' anorexia' or ''))
 eq(sent[#sent][phase=='contemplate' and 'free' or 'eq'],expected)
end

print('PASS Truelocks finisher: Corrupt confirmation/provenance, balanceless Contemplate, strict threshold, one Sap/rebuild, cancellation, target guards and self-paralysis resume in every phase')
