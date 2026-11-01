local root=arg[1] or 'Ysindrolir'
local clock,sent,paralyzed=100,{},false
getEpoch=function() return clock end
target='Saibel';gmcp={Char={Status={class='Apostate'},Vitals={bal='1',eq='1',mp='1000'}}}
Yso={get_target=function() return target end,mode={is_combat=function() return true end},
 apostate={active=function() return true end},
 self={has_aff=function(a) return a=='paralysis' and paralyzed end},
 selfaff={meta={afflictions_ready=true,full_sync_confirmed=true,awaiting_full_sync=false}},
 emit=function(p) sent[#sent+1]=p;return true end}
ak={defs={}};affstrack={score={}}
local T=dofile(root..'/Apostate/lock_route.lua')
local V=dofile(root..'/Apostate/vivisect_route.lua')
dofile(root..'/Apostate/evileye_reference.lua')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function reset()
 clock=clock+30;sent={};paralyzed=false;ak.defs={}
 T.state.loop_enabled=false;V.alias_loop_prepare_start({});V.state.loop_enabled=true;V.state.victim=target
 affstrack.score={deaf=100,paralysis=100,impatience=100,asthma=100,manaleech=100,
  slickness=100,anorexia=100,disloyalty=100,confusion=100,prone=100}
 gmcp.Char.Vitals={bal='1',eq='1',mp='1000'}
 Yso.selfaff.meta.afflictions_ready=true
end
reset();eq(T.key,'apostate_truelock');eq(V.key,'apostate_vivisect');assert(T.state~=V.state)
affstrack.score.confusion=0;assert(V.attack_function());eq(sent[1].bal,'stare Saibel confusion')
reset();affstrack.score.disloyalty=0;assert(V.attack_function());eq(sent[1].eq,'disfigure Saibel')
reset();affstrack.score.paralysis=0;assert(V.attack_function());assert(sent[1].bal:find('paralysis',1,true))
reset();affstrack.score.prone=0;local ok,why=V.attack_function();eq(ok,false);eq(why,'waiting_prone');eq(#sent,0)
reset();assert(V.attack_function());eq(sent[1].bal,'trample');eq(V.state.pending.action,'trample')
assert(not V.attack_function());eq(#sent,1)
V.note_pressure('trample',target);V.note_prompt();eq(V.state.pending,nil)
clock=clock+5;affstrack.score.leftarm=100;affstrack.score.rightarm=100
assert(V.attack_function());eq(sent[2].bal,'trample')
V.note_pressure('trample',target);V.note_prompt();clock=clock+5
affstrack.score.leftleg=100;affstrack.score.rightleg=100;affstrack.score.prone=0
assert(V.attack_function());eq(sent[3].eq,'vivisect Saibel');assert(not V.attack_function());eq(#sent,3)
gmcp.Char.Vitals.eq='0';V.note_prompt();clock=clock+5;gmcp.Char.Vitals.eq='1'
assert(not V.attack_function());eq(V.is_enabled(),false)
reset();affstrack.score.leftarm=300;affstrack.score.rightarm=100;affstrack.score.leftleg=0;affstrack.score.rightleg=0
affstrack.tramplescore=4;assert(V.attack_function());eq(sent[1].bal,'trample')
reset();for _,l in ipairs({'leftarm','rightarm','leftleg','rightleg'}) do affstrack.score[l]=100 end
affstrack.score.leftleg=99;assert(V.attack_function());eq(sent[1].bal,'trample')
reset();paralyzed=true;ok,why=V.attack_function();eq(ok,false);eq(why,'paralysis');eq(V.is_enabled(),true);eq(#sent,0)
paralyzed=false;assert(V.attack_function());eq(sent[1].bal,'trample')
reset();Yso.selfaff.meta.afflictions_ready=false;ok,why=V.attack_function();eq(why,'self_tracking_unavailable');eq(#sent,0)
reset();gmcp.Char.Vitals.bal='0';assert(not V.attack_function());eq(#sent,0)
reset();for _,l in ipairs({'leftarm','rightarm','leftleg','rightleg'}) do affstrack.score[l]=100 end
gmcp.Char.Vitals.mp='299';ok,why=V.attack_function();eq(why,'mana');eq(#sent,0)
reset();ak.defs.curseward=true;affstrack.score.confusion=0;assert(V.attack_function());eq(sent[1].bal,'deadeyes Saibel breach confusion')
reset();T.state.loop_enabled=true;ok,why=V.attack_function();eq(why,'other_route_active');eq(#sent,0)
reset();assert(V.attack_function());V.note_eye_rejected('balance');V.note_prompt();eq(V.state.pending,nil)
reset();assert(V.attack_function());gmcp.Char.Vitals.bal='0';V.note_prompt();eq(V.state.pending,nil)
reset();assert(V.attack_function());paralyzed=true;clock=clock+11
ok,why=V.attack_function();eq(why,'paralysis');eq(V.is_enabled(),true)
paralyzed=false;gmcp.Char.Vitals.bal='0';V.note_prompt();clock=clock+5;gmcp.Char.Vitals.bal='1'
assert(V.attack_function());eq(sent[2].bal,'trample')
reset();local A=dofile(root..'/Apostate/ak_tracking.lua')
OppGainedAff=function(a) affstrack.score[a]=100 end
assert(V.attack_function());assert(A.trample(target,'left','arm'));eq(affstrack.score.leftarm,100)
V.note_prompt();eq(V.state.pending,nil);assert(not A.trample('Other','right','leg'));eq(affstrack.score.rightleg,nil)
-- A queued action remains pending across a long paralysis pause; no duplicate send.
reset();assert(V.attack_function());paralyzed=true;clock=clock+11
eq(select(2,V.attack_function()),'paralysis');paralyzed=false
assert(not V.attack_function());eq(V.is_enabled(),true);eq(V.state.reason,'waiting_trample');eq(#sent,1)
print('PASS Vivisect: lock/confusion, prone, confirmed limbs, cures, pauses, readiness and active AK callbacks')
