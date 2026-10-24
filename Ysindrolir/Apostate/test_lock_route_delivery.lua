local root=arg[1] or 'Ysindrolir'
local clock,sent=100,{}
getEpoch=function() return clock end
target='Saibel';gmcp={Char={Status={class='Apostate'},Vitals={bal='1',eq='1',mp='1000'}}}
ak={defs={}};affstrack={score={}}
Yso={get_target=function() return target end,apostate={active=function() return true end},
 mode={is_combat=function() return true end},emit=function(payload) sent[#sent+1]=payload;return true end}
local M=dofile(root..'/Apostate/lock_route.lua')
dofile(root..'/Apostate/evileye_reference.lua')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function reset(scores)
 clock=clock+20;sent={};M.alias_loop_prepare_start({});M.state.loop_enabled=true
 M.state.victim=target;affstrack.score=scores or {};ak.defs={}
 gmcp.Char.Vitals={bal='1',eq='1',mp='1000'}
end
reset();ak.defs.shield=true;assert(M.attack_function());eq(sent[1].bal,'deadeyes Saibel paralysis impatience')
eq(affstrack.score.paralysis,nil);assert(not M.attack_function());eq(#sent,1)
M.note_pressure('eyes','Other');M.note_prompt();assert(M.state.pending)
M.note_pressure('eyes',target);M.note_prompt();eq(M.state.pending,nil)
assert(not M.attack_function());clock=clock+2;assert(M.attack_function())
reset();ak.defs.curseward=true;assert(M.attack_function());eq(sent[1].bal,'deadeyes Saibel breach paralysis')
eq(ak.defs.curseward,true);M.note_pressure('eyes',target);M.note_prompt();assert(M.state.pending)
ak.defs.curseward=false;M.note_prompt();eq(M.state.pending,nil)
reset();assert(M.attack_function());M.note_eye_rejected('curseward',target);M.note_prompt()
eq(ak.defs.curseward,true);eq(M.state.pending,nil)
clock=clock+2;assert(M.attack_function());eq(sent[2].bal,'deadeyes Saibel breach paralysis')
reset();gmcp.Char.Vitals.eq='0';assert(not M.attack_function());eq(#sent,0)
reset();gmcp.Char.Vitals.bal='0';assert(not M.attack_function());eq(#sent,0)
reset();gmcp.Char.Vitals.mp='1';assert(not M.attack_function());eq(#sent,0)
reset();ak.defs.curseward=true;gmcp.Char.Vitals.mp='194';assert(not M.attack_function());eq(#sent,0)
reset();Yso.offense_paused=function() return true end;assert(not M.attack_function());eq(#sent,0);Yso.offense_paused=nil
reset();Yso.inhibit={active=function() return true end};assert(not M.attack_function());eq(#sent,0);Yso.inhibit=nil
reset();gmcp.Char.Vitals.dead='1';assert(not M.attack_function());eq(#sent,0)
reset();M.state.victim='Other';assert(not M.attack_function());eq(M.is_enabled(),false)
reset();assert(M.attack_function());clock=clock+11;assert(not M.attack_function());eq(M.is_enabled(),false)
local complete={paralysis=100,impatience=100,asthma=100,manaleech=100,slickness=100,anorexia=100}
reset(complete);gmcp.Char.Vitals.bal='0';assert(M.attack_function());eq(sent[1].eq,'disfigure Saibel')
assert(not M.attack_function());clock=clock+3;complete.disloyalty=100;assert(not M.attack_function());eq(#sent,1)
complete.disloyalty=0;reset(complete);ak.defs.shield=true;assert(not M.attack_function());eq(#sent,0)
-- No Corrupt, Contemplate, or unsolicited Catharsis is part of the replacement.
sendAll=function() error('unexpected Catharsis') end
dofile(root..'/Yso/xml/apostate_utilities.lua')
assert(not Yso.apostate.note_mana('Saibel',1,100));eq(type(M.note_corrupt),'nil')
print('PASS lock delivery: confirmation, Breach, readiness, mana, suppression, timeout, Disfigure and finisher retirement')
