-- Finisher commands must really dispatch through the canonical emitter and queue.
local root=arg[1] or 'Ysindrolir'
local sent,clock={},100
getEpoch=function() return clock end
send=function(command) sent[#sent+1]=command end
cecho=function() end
tempTimer=function() return 1 end;killTimer=function() end
tempRegexTrigger=function() return 1 end;killTrigger=function() end
registerAnonymousEventHandler=function() return 1 end;killAnonymousEventHandler=function() end
raiseEvent=function() end
target='Saibel'
gmcp={Char={Status={class='Apostate'},Vitals={bal='1',eq='1',mp='1000'}}}
Yso={cfg={cmd_sep='&&'},get_target=function() return target end,
 mode={is_combat=function() return true end}}
ak={defs={}}
affstrack={score={deaf=100,paralysis=100,impatience=100,asthma=100,
 manaleech=100,slickness=100,anorexia=100,disloyalty=100}}
dofile(root..'/Yso/xml/api_stuff.lua')
dofile(root..'/Yso/xml/apostate_utilities.lua')
dofile(root..'/Yso/Core/queue.lua')
dofile(root..'/Apostate/entourage.lua')
local M=dofile(root..'/Apostate/lock_route.lua')
assert(type(M.note_corrupt_started)=='function','missing Corrupt accepted-output adapter')
assert(M.corrupt_trigger and M.corrupt_retained_trigger,'default Corrupt output adapters missing')
local Q=Yso.queue
ak.apostate={consume_corrupt=function(name,retained)
 assert(name=='Saibel' and retained=='anorexia')
 for _,aff in ipairs({'paralysis','impatience','asthma','manaleech','slickness'}) do
  affstrack.score[aff]=0
 end
 return true
end}
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
M.alias_loop_prepare_start({});M.state.loop_enabled=true;M.alias_loop_on_started()
eq(sent[1],'order daemonite kill Saibel')
local ok,reason=M.attack_function()
assert(ok,'Corrupt must dispatch through the real queue: '..tostring(reason))
assert(sent[2]:find('QUEUE ADDCLEAR ',1,true),sent[2])
assert(sent[2]:find('demon corrupt Saibel anorexia',1,true),sent[2])
eq(Q.get_owned('eq').route,M.key);eq(Q.list('eq'),nil)
eq(M.state.pending.action,'corrupt')
assert(M.note_corrupt_started('Saibel'))
assert(M.note_corrupt('Saibel','anorexia'))

-- Contemplate waits for BAL scheduling but does not spend or require EQ.
gmcp.Char.Vitals.eq='0';gmcp.Char.Vitals.bal='0'
assert(not M.attack_function());eq(#sent,2)
gmcp.Char.Vitals.bal='1'
assert(M.attack_function());eq(sent[3],'contemplate Saibel')
eq(#Q.list('free'),0);eq(Q.get_owned('free'),nil)
eq(M.state.pending.action,'contemplate')
assert(Yso.apostate.note_mana('Saibel',49,100))
assert(not M.attack_function());eq(#sent,3)

-- Runtime recovery releases the EQ dispatch latch before the next EQ action.
clock=clock+3;gmcp.Char.Vitals.eq='1'
Q.clear_lane_dispatched('eq','test_recovery')
assert(M.attack_function())
eq(#sent,4)
assert(sent[4]:find('demon catharsis Saibel',1,true),sent[4])
assert(sent[4]:find('QUEUE ADDCLEAR ',1,true),sent[4])
assert(M.is_enabled(),'do not stop and clear Catharsis before it executes')
eq(M.state.pending.action,'catharsis')
for _,command in ipairs(sent) do
 assert(not command:find('CLEARQUEUE',1,true),'Catharsis cancelled immediately after dispatch')
end

-- Spend and recovery, rather than queue installation, complete the attempt.
gmcp.Char.Vitals.eq='0';M.note_prompt()
assert(not M.attack_function());eq(#sent,4)
clock=clock+5;gmcp.Char.Vitals.eq='1'
M.attack_function()
eq(M.is_enabled(),false)
local passives=0
for _,command in ipairs(sent) do
 if command=='order daemonite passive' then passives=passives+1 end
end
eq(passives,1)
print('PASS Truelocks finisher real emitter: committed EQ, immediate balanceless Contemplate, Catharsis spend/recovery and daemonite cleanup')
