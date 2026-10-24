-- Exercise the simplified route through the real emitter, with and without legacy queues.
local root=assert(arg[1],'pass Ysindrolir root')
local sent,clock={},100
getEpoch=function() return clock end
send=function(command) sent[#sent+1]=command end
cecho=function() end
tempTimer=function() return 1 end;killTimer=function() end
tempRegexTrigger=function() return 1 end;killTrigger=function() end
registerAnonymousEventHandler=function() return 1 end;killAnonymousEventHandler=function() end
raiseEvent=function() end
target='Saibel';gmcp={Char={Status={class='Apostate'},Vitals={bal='1',eq='1',mp='1000'}}}
Yso={cfg={cmd_sep='&&'},get_target=function() return target end,mode={is_combat=function() return true end}}
ak={defs={}};affstrack={score={}}
dofile(root..'/Yso/xml/api_stuff.lua')
dofile(root..'/Yso/xml/apostate_utilities.lua')
dofile(root..'/Apostate/evileye_reference.lua')
local M=dofile(root..'/Apostate/lock_route.lua')
M.state.loop_enabled=true
assert(M.attack_function());assert(#sent==1 and sent[1]:find('deadeyes Saibel paralysis impatience',1,true),tostring(sent[1]))
assert(affstrack.score.paralysis==nil)
M.note_pressure('eyes',target);M.note_prompt();clock=clock+3;sent={}
dofile(root..'/Yso/Core/queue.lua')
assert(M.attack_function());assert(#sent==1 and sent[1]:find('deadeyes Saibel paralysis impatience',1,true),tostring(sent[1]))
assert(Yso.queue.get_owned('bal').route==M.key)
Yso.queue.set_owned('eq',{route='another_route',cmd='unrelated'})
sent={};M.alias_loop_on_stopped({reason='manual'})
assert(sent[1]=='CLEARQUEUE b!p!w!t','stop must cancel its own BAL batch')
assert(Yso.queue.get_owned('eq').route=='another_route')
sent={};gmcp.Char.Vitals.bal='0';gmcp.Char.Vitals.eq='0'
M.alias_loop_on_started()
assert(sent[1]=='order entourage kill Saibel&&order daemonite kill Saibel&&order bloodworms kill Saibel&&order nightmare kill Saibel')
M.alias_loop_on_stopped({reason='manual'})
assert(sent[2]=='order entourage passive&&order daemonite passive&&order bloodworms passive&&order nightmare passive')
-- A failed send can leave a staged command without dispatched ownership.
clock=clock+10;gmcp.Char.Vitals.bal='1';gmcp.Char.Vitals.eq='1'
M.alias_loop_prepare_start({});M.state.loop_enabled=true;sent={}
local rawsend=send;send=function() error('simulated sender failure') end
local ok=pcall(M.attack_function)
assert(not ok);assert(Yso.queue.list('bal')=='deadeyes Saibel paralysis impatience')
assert(Yso.queue.get_owned('bal')==nil)
send=rawsend;M.stop('route_error')
assert(Yso.queue.list('bal')==nil,'OFF must discard its staged attack even without dispatched ownership')
Yso.queue.commit({route=M.key,target=target})
for _,command in ipairs(sent) do assert(not command:find('deadeyes',1,true),'attack leaked after OFF') end
print('PASS lock route real emitter, legacy queue ownership and balanceless creature orders')
