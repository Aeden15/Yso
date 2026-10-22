-- Exercise the real emitter and compatible queue implementation at the send boundary.
local root=assert(arg[1],'pass Ysindrolir root')
local sent,clock={},100
getEpoch=function() return clock end
send=function(s) sent[#sent+1]=s end
cecho=function() end
tempTimer=function() return 1 end;killTimer=function() end
tempRegexTrigger=function() return 1 end;killTrigger=function() end
registerAnonymousEventHandler=function() return 1 end
killAnonymousEventHandler=function() end
raiseEvent=function() end
gmcp={Char={Status={class='Apostate'},Vitals={bal='1',eq='0'}}}
Yso={cfg={cmd_sep='&&'},get_target=function() return 'Saibel' end}
ak={apostate={}};affstrack={venoms={notechis='haemophilia'}}
dofile(root..'/Yso/xml/api_stuff.lua')
local D=dofile(root..'/Apostate/daegger_envenom.lua');D.stock.notechis=true
assert(D.emit_attack('puncture','Saibel',{'haemophilia'},{}))
assert(#sent==1 and sent[1]=='wipe daegger&&envenom daegger with notechis&&daegger puncture Saibel')
sent={}
clock=clock+3
dofile(root..'/Yso/Core/queue.lua')
assert(D.emit_attack('puncture','Saibel',{'haemophilia'},{}))
assert(#sent==1,'preparation must not use a separate EQ-gated queue')
assert(sent[1]:find('b!p!w!t wipe daegger&&envenom daegger with notechis&&daegger puncture Saibel',1,true),sent[1])
-- Contemplate remains balanceless even in profiles with the compatibility queue.
sent={};target='Saibel';Yso.mode={is_combat=function() return true end}
dofile(root..'/Yso/xml/apostate_utilities.lua')
local M=dofile(root..'/Apostate/truelock.lua')
M.state.loop_enabled=true;M.state.victim='Saibel';M.state.phase='contemplate'
assert(M.attack_function());assert(#sent==1 and sent[1]=='contemplate Saibel',sent[1])
sent={};Yso.queue.set_owned('eq',{route='another_route',cmd='unrelated'})
M.alias_loop_on_stopped({reason='manual'})
assert(sent[1]=='CLEARQUEUE b!p!w!t','stopping must cancel its own queued BAL batch')
assert(Yso.queue.get_owned('eq').route=='another_route','unrelated lane ownership must survive')
-- Conditional support uses the real EQ queue even with BAL unavailable.
sent={};clock=clock+5
gmcp.Char.Vitals={bal='0',eq='1',mp='6817'}
affstrack.score={asthma=100,manaleech=100}
ak.classlockresolve=function() return {'voyria'} end
ak.classlockresolveclass=function() return 'apostate' end
dofile(root..'/Apostate/evileye_reference.lua')
dofile(root..'/Apostate/necromancy_reference.lua')
M.state.loop_enabled=true;M.state.phase='pressure';M.state.pending=nil
assert(M.attack_function());assert(#sent==1 and sent[1]:find('disfigure Saibel',1,true),sent[1])
assert(Yso.queue.get_owned('eq').route==M.key,'support must be owned by Truelocks')
assert(M.state.pending==nil,'support must not replace the pressure confirmation slot')
print('PASS real emitter: ordered daegger batch with BAL ready / EQ down, direct and queued profiles')
