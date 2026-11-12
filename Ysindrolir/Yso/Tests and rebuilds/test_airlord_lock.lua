local prefix=assert(arg[1], 'pass extracted package prefix')
local checks=0
local function check(ok,why) assert(ok,why);checks=checks+1 end
local function world()
  local clock,target,sent=0,'Enemy',{}
  Yso={util={now=function() return clock end},get_target=function() return target end,
    target_is_valid=function(t) return t==target and t~='' end}
  gmcp={Char={Status={class='air elemental lord'},Vitals={bal='1'}}}
  affstrack={score={}};ak={duress={},defs={}}
  Yso.emit=function(payload) sent[#sent+1]=payload;return true end
  assert(loadfile(prefix..'.compression.lua'))()
  local runtime=io.open(prefix..'.runtime.lua')
  if runtime then runtime:close();assert(loadfile(prefix..'.runtime.lua'))() end
  assert(loadfile(prefix..'.lock.lua'))()
  local M=Yso.off.airlord.lock
  M.state.enabled=true;M.state.loop_enabled=true
  return M,sent,function(t) clock=t end,function(t) target=t end
end

local M,sent,time,target=world()
check(Yso.off.airlord.damage==nil,'loading lock must not create a damage route')
local function pick(want)
  local got=M.select_command('Enemy')
  check(got==want,'expected '..want..', got '..tostring(got))
end
pick('aero asphyxiate Enemy')
ak.duress.asphyxiate=true
pick('aero strangle Enemy')
ak.duress.stranglerelapse=true
pick('manifest zephyr Enemy')
ak.duress.zephyrrelapse=true
pick('aero scour Enemy')
ak.duress.scourrelapse=true
pick('aero tension Enemy')
M.state.last_cmd='aero tension Enemy'
pick('aero pressure Enemy')
M.state.last_cmd=nil
affstrack.score.deadening,affstrack.score.disloyalty=100,100
ak.duress.asphyxiate=false
pick('aero pressure Enemy')
affstrack.score.deadening,affstrack.score.disloyalty=0,0
Yso.off.airlord.compression.observe('Enemy',5)
pick('aero pressure Enemy')
Yso.off.airlord.compression.clear()
ak.duress={asphyxiate=true};affstrack.score.deadening=50;affstrack.score.manaleech=50
pick('aero strangle Enemy')
affstrack.score.deadening=100
Yso.off.airlord.compression.observe('Enemy',1)
pick('aero pressure Enemy')
Yso.off.airlord.compression.observe('Enemy',6)
pick('aero compression Enemy')
ak.defs.shield=true;pick('manifest gale Enemy');ak.defs.shield=false
time(4);pick('manifest zephyr Enemy')
ak.duress.relapse_pending=function(skill,who)
  return who=='Enemy' and skill=='zephyr'
end
pick('aero scour Enemy')

-- A submitted execute must not repeat on each scheduler tick.
M,sent,time,target=world();ak.duress.asphyxiate=true
Yso.off.airlord.compression.observe('Enemy',6)
check(M.attack_function()==true,'execute should submit')
local _,why=M.attack_function();check(why=='execute_inflight','execute must await confirmation')
gmcp.Char.Vitals.bal='0';M.attack_function()
gmcp.Char.Vitals.bal='1';time(0.2)
_,why=M.attack_function();check(why=='execute_waiting_gauge','balance recovery requires a new Gauge')
time(0.3);Yso.off.airlord.compression.observe('Enemy',6)
check(M.attack_function()==true,'fresh terminal Gauge permits retry after recovery')
Yso.off.airlord.compression.invalidate('Enemy')
check(not M.state.execute_inflight,'pressure invalidation must release execute')

-- Setup suppresses duplicates and observations remain free while BAL is down.
M,sent,time,target=world()
check(M.attack_function()==true,'setup should submit')
_,why=M.attack_function();check(why=='pending','setup must not submit each tick')
check(#sent==2 and sent[1].free=='gauge Enemy','lock observations must be Gauge only')
gmcp.Char.Vitals.bal='0';time(1.1);M.attack_function()
check(#sent==3 and sent[3].free=='gauge Enemy','Gauge must continue off balance')
gmcp.Char.Vitals.bal='1';check(M.attack_function()==true,'setup should resume after balance recovery')

-- Changing target must discard the old route-owned attack and Gauge.
local cleared=0
Yso.queue={get_owned=function() return {route=M.key,cmd='aero asphyxiate Enemy'} end,
  clear_lane=function() cleared=cleared+1 end}
target('Other');time(1.2);M.attack_function()
check(cleared==1,'target swap must clear old owned attack')
check(sent[#sent].bal=='aero asphyxiate Other','new attack must use shared target')
M.alias_loop_on_stopped({silent=true})
check(M.state.pending==nil and M.state.last_cmd==nil,'stop must reset local attack state')

-- The route must respect pauses even when invoked outside the scheduler.
M,sent=world()
Yso.Combat={Pause={blocked=function() return true,'paralysis' end}}
_,why=M.attack_function()
check(why=='paralysis' and #sent==0,'pause must block observations and attacks')
-- Reloading an old combined route must remove its strategy and owned work.
M,sent=world()
M.state.pending={cmd='manifest updraft Enemy',category='updraft'}
M.state.staged_bal='manifest updraft Enemy'
M.state.observation_target='Enemy'
local staged='manifest updraft Enemy'
Yso.queue={list=function() return staged end,
  get_staged_owner=function() return {route=M.key,cmd=staged} end,
  clear=function() staged=nil end}
local killed
killAnonymousEventHandler=function(id) killed=id end
M.room_handler=42
M.sync_updraft=function() error('legacy Updraft retained') end
M.sync_buffet=function() error('legacy Buffet retained') end
M.observations=function(t) return {'gauge '..t,'assess '..t} end
M.on_command=function() error('legacy strategy callback retained') end
assert(loadfile(prefix..'.lock.lua'))()
check(M.sync_updraft==nil and M.sync_buffet==nil,'reload must remove old lock strategy hooks')
check(killed==42 and M.room_handler==nil,'reload must remove the old room handler')
check(staged==nil and M.state.pending==nil,'reload must cancel old strategy work')
check(M.observations==nil and M.on_command==nil,'reload must remove old observation/command hooks')
check(M.attack_function()==true and sent[1].free=='gauge Enemy','reloaded lock must use basic lock observations')
killAnonymousEventHandler=nil

-- Confirmation timeout uses active time, not a long paralysis wall-clock gap.
M,sent,time=world()
local active_time=0
Yso.Combat={Pause={blocked=function() return false end,
  confirmation_now=function() return active_time end}}
M.attack_function();time(100)
_,why=M.attack_function()
check(why=='pending','paralysis time must not expire the submission')
active_time=3
check(M.attack_function()==true,'active confirmation timeout must permit a genuine retry')
print('Airlord lock: '..checks..' checks passed')
