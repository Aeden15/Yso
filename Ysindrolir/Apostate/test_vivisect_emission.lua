local root=arg[1] or 'Ysindrolir'
local sent,clock={},100
getEpoch=function() return clock end
send=function(s) sent[#sent+1]=s end
cecho=function() end;tempTimer=function() return 1 end;killTimer=function() end
tempRegexTrigger=function() return 1 end;killTrigger=function() end
registerAnonymousEventHandler=function() return 1 end;killAnonymousEventHandler=function() end
raiseEvent=function() end
target='Saibel';gmcp={Char={Status={class='Apostate'},Vitals={bal='1',eq='1',mp='1000'}}}
Yso={cfg={cmd_sep='&&'},get_target=function() return target end,mode={is_combat=function() return true end}}
ak={defs={}};affstrack={score={deaf=100,paralysis=100,impatience=100,asthma=100,
 manaleech=100,slickness=100,anorexia=100,disloyalty=100,confusion=100,prone=100}}
dofile(root..'/Yso/xml/api_stuff.lua')
dofile(root..'/Yso/xml/apostate_utilities.lua')
dofile(root..'/Yso/Core/queue.lua')
dofile(root..'/Yso/Core/self_aff.lua');Yso.selfaff.sync_full({},'gmcp.full')
dofile(root..'/Apostate/entourage.lua')
dofile(root..'/Yso/Combat/combat_pause.lua')
dofile(root..'/Apostate/lock_route.lua')
local V=dofile(root..'/Apostate/vivisect_route.lua')
V.alias_loop_prepare_start({});V.state.loop_enabled=true;V.alias_loop_on_started()
assert(V.attack_function());assert(sent[2]:find('trample',1,true),tostring(sent[2]))
assert(Yso.queue.get_owned('bal').route==V.key)
local n=#sent
Yso.selfaff.gain('paralysis','text.paralysis.gained',{force_text=true});Yso.Combat.Pause.blocked(V.key);clock=clock+11
assert(not V.attack_function());assert(V.is_enabled());assert(V.state.reason=='paralysis')
Yso.selfaff.cure('paralysis','text.paralysis.cured',{force_text=true})
assert(not V.attack_function());assert(V.is_enabled());assert(V.state.pending.action=='trample');assert(#sent==n)
-- An unrelated mana report must never launch the standalone Catharsis helper.
sendAll=function(...) sent[#sent+1]=table.concat({...},'&&') end
assert(not Yso.apostate.note_mana(target,1,100));assert(#sent==n,'Vivisect allowed standalone Catharsis')
gmcp.Char.Vitals.bal='0';V.note_prompt();clock=clock+5;gmcp.Char.Vitals.bal='1'
Yso.queue.clear_lane_dispatched('bal','test_recovery')
-- Partial outcomes require a second identical Trample through the real queue.
assert(V.attack_function(),'second Trample must dispatch with limbs still missing')
assert(#sent==n+1);assert(sent[#sent]:find('trample',1,true));n=#sent
gmcp.Char.Vitals.bal='0';V.note_prompt();clock=clock+5;gmcp.Char.Vitals.bal='1'
Yso.queue.clear_lane_dispatched('bal','test_second_recovery')
for _,l in ipairs({'leftarm','rightarm','leftleg','rightleg'}) do affstrack.score[l]=100 end
Yso.selfaff.gain('paralysis','text.paralysis.gained',{force_text=true})
assert(not V.attack_function());assert(#sent==n);assert(V.is_enabled())
Yso.selfaff.cure('paralysis','text.paralysis.cured',{force_text=true})
assert(V.attack_function());assert(sent[#sent]:find('vivisect Saibel',1,true))
assert(Yso.queue.get_owned('eq').route==V.key)
assert(not V.attack_function());assert(#sent==n+1)
gmcp.Char.Vitals.eq='0';V.note_prompt();clock=clock+5;gmcp.Char.Vitals.eq='1'
V.attack_function();assert(not V.is_enabled())
local passive=0;for _,s in ipairs(sent) do if s=='order daemonite passive' then passive=passive+1 end end
assert(passive==1,'daemonite must be stopped exactly once')
-- A staged wake is not a sent command and cannot leave an old execute queued.
V.alias_loop_prepare_start({});V.state.loop_enabled=true;V.state.victim=target
Yso.queue.clear_lane_dispatched('eq','test_reset')
local emit=Yso.emit
Yso.emit=function(p) Yso.queue.stage('eq',p.eq);return true end
assert(not V.attack_function());assert(V.state.pending==nil);assert(Yso.queue.list('eq')==nil)
Yso.emit=emit
print('PASS Vivisect real emitter, queue ownership, no standalone Catharsis, text paralysis resume and staged cleanup')
