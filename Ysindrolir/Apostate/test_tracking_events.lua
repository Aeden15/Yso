local root=arg[1] or 'Ysindrolir'
local handlers,serial={},0
registerAnonymousEventHandler=function(event,fn)
 serial=serial+1;handlers[serial]={event=event,fn=fn};return serial
end
killAnonymousEventHandler=function(id) handlers[id]=nil end
local function fire(event)
 for _,handler in pairs(handlers) do
  if handler.event==event then handler.fn(event) end
 end
end
local clock,sent,paralyzed=100,{},true
getEpoch=function() return clock end
target='Saibel';gmcp={Char={Status={class='Apostate'},Vitals={bal='1',eq='1',mp='1000'}}}
ak={defs={}};affstrack={score={deaf=100}}
Yso={get_target=function() return target end,
 apostate={active=function() return gmcp.Char.Status.class=='Apostate' end},
 self={has_aff=function(aff) return aff=='paralysis' and paralyzed end},
 mode={is_combat=function() return true end},
 emit=function(payload) sent[#sent+1]=payload;return true end}
local A=dofile(root..'/Apostate/ak_tracking.lua')
local M=dofile(root..'/Apostate/lock_route.lua')
dofile(root..'/Apostate/evileye_reference.lua')
local stop_reason
local stop=M.stop
M.stop=function(reason) stop_reason=reason;return stop(reason) end
local function check(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function start()
 M.alias_loop_prepare_start({});M.state.loop_enabled=true;M.state.victim=target
end
local function status(class,classname)
 gmcp.Char.Status={class=class,classname=classname};fire('gmcp.Char.Status')
end
start()
local ok,reason=M.attack_function();check(ok,false);check(reason,'paralysis')
fire('gmcp.Char.Status');check(M.is_enabled(),true)
paralyzed=false;fire('gmcp.Char.Status');check(M.is_enabled(),true)
assert(M.attack_function());check(#sent,1)
local pending=M.state.pending
A.eye_target=target;A.eye_pending={{aff='asthma'}}
A.evileye_active.asthma='saibel'
fire('gmcp.Char.Status')
check(M.state.pending,pending);check(A.eye_target,target)
check(A.evileye_active.asthma,'saibel')
-- The tracking listener alone must ignore cosmetic/missing class updates.
-- The route's independent wrong-class listener is outside this check.
killAnonymousEventHandler(M.handlers['gmcp.Char.Status'])
status(' APOSTATE ');check(M.is_enabled(),true)
status(nil,'Apostate');check(M.is_enabled(),true)
status('');status(nil);check(M.is_enabled(),true)
status('Occultist');check(M.is_enabled(),false)
check(stop_reason,'tracking_reset');check(A.eye_target,nil)
check(next(A.evileye_active),nil)
-- Missing class information must not discard the last known class.
status(nil);status('Apostate');start();fire('gmcp.Char.Status')
check(M.is_enabled(),true)
-- Reload replaces the old listeners instead of leaving a resetting handler.
local old=A.tracking_handlers['gmcp.Char.Status']
A=dofile(root..'/Apostate/ak_tracking.lua')
check(handlers[old],nil);fire('gmcp.Char.Status');check(M.is_enabled(),true)
local count=0
for _,handler in pairs(handlers) do
 if handler.event=='gmcp.Char.Status' then count=count+1 end
end
check(count,1)
for _,event in ipairs({'yso.target.changed','yso.target.cleared','sysDisconnectionEvent'}) do
 start();A.eye_target=target;fire(event)
 check(M.is_enabled(),false);check(A.eye_target,nil)
end
-- A reconnect's first class report establishes a fresh baseline.
start();status('Occultist');check(M.is_enabled(),true)
status('Apostate');check(M.is_enabled(),false)
-- Initial load before GMCP arrives also establishes a baseline without stopping.
status(nil);A=dofile(root..'/Apostate/ak_tracking.lua');start()
status('Apostate');check(M.is_enabled(),true)
status('Occultist');check(M.is_enabled(),false)
print('PASS tracking events: unchanged status, paralysis resume, class changes, missing class, reconnect, reload and target resets')
