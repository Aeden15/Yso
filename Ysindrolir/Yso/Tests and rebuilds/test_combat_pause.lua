local root=arg[1] or 'Ysindrolir'
local clock,paralyzed,serial=100,false,0
local timers,handlers,sent={},{},{}
getEpoch=function() return clock end
tempTimer=function(_,fn) serial=serial+1;timers[serial]=fn;return serial end
killTimer=function(id) timers[id]=nil end
registerAnonymousEventHandler=function(e,fn) serial=serial+1;handlers[serial]={event=e,fn=fn};return serial end
killAnonymousEventHandler=function(id) handlers[id]=nil end
cecho=function() end;send=function(s) sent[#sent+1]=s end
local function fire(e,...)
 for _,h in pairs(handlers) do if h.event==e then h.fn(e,...) end end
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
target='Bob';gmcp={Char={Status={class='Apostate'},Vitals={bal='1',eq='1',mp='1000'}}}
Yso={features={alchemist_offense=true},get_target=function() return target end,self={has_aff=function(a) return a=='paralysis' and paralyzed end}}
local RR=dofile(root..'/Yso/Combat/route_registry.lua')
local RI=dofile(root..'/Yso/Combat/route_interface.lua')
local P=dofile(root..'/Yso/Combat/combat_pause.lua')
dofile(root..'/Yso/xml/yso_modes.lua')
-- An entirely new registry entry inherits the same contract with no route guard.
local future={id='future_combat',namespace='Yso.off.future',mode='combat',active=true,alias_owned=true}
local resolve,for_mode=RR.resolve,RR.for_mode
RR.resolve=function(id) if id==future.id then return future end;return resolve(id) end
RR.for_mode=function(mode) local rows=for_mode(mode);if mode=='combat' then rows[#rows+1]=future end;return rows end
-- Every registered combat route inherits the gate, independent of its own code.
for _,entry in ipairs(RR.for_mode('combat')) do
 local node=_G;local parts={};for part in entry.namespace:gmatch('[^.]+') do parts[#parts+1]=part end
 for i=1,#parts-1 do node[parts[i]]=node[parts[i]] or {};node=node[parts[i]] end
 local calls,starts,waiting=0,0,0
 local mod={state={loop_enabled=false},alias_owned=true,
  is_active=function() return true end,
  alias_loop_on_started=function() starts=starts+1 end,
  alias_loop_waiting_blocks=function() waiting=waiting+1;return false end,
  attack_function=function() calls=calls+1;return true end}
 node[parts[#parts]]=mod
 paralyzed=true;fire('yso.self.aff.changed','paralysis',true,'text')
 assert(Yso.mode.start_route_loop(entry.id));eq(starts,0)
 Yso.mode.tick_route_loop(entry.id);eq(calls,0);eq(waiting,0);eq(mod.state.loop_enabled,true)
 local before=P.confirmation_now(entry.id);clock=clock+30
 Yso.mode.tick_route_loop(entry.id);eq(P.confirmation_now(entry.id),before)
 paralyzed=false;fire('yso.self.aff.changed','paralysis',false,'gmcp.remove')
 Yso.mode.tick_route_loop(entry.id);eq(starts,1);eq(calls,1);eq(waiting,1)
 -- Terminal events remain effective while paused.
 paralyzed=true;fire('yso.self.aff.changed','paralysis',true,'text')
 fire('sysDisconnectionEvent');eq(mod.state.loop_enabled,false)
 paralyzed=false;fire('yso.self.aff.changed','paralysis',false,'text')
 Yso.mode.tick_route_loop(entry.id);eq(calls,1)
 assert(Yso.mode.start_route_loop(entry.id));Yso.mode.tick_route_loop(entry.id);eq(calls,2)
 -- An explicit stop while paused remains stopped after cure.
 paralyzed=true;fire('yso.self.aff.changed','paralysis',true,'text')
 Yso.mode.stop_route_loop(entry.id,'manual',true)
 paralyzed=false;fire('yso.self.aff.changed','paralysis',false,'text')
 Yso.mode.tick_route_loop(entry.id);eq(calls,2);eq(mod.state.loop_enabled,false)
end
-- Death and target invalidation remain stops while the shared gate is closed.
local mod=Yso.off.future
paralyzed=true;assert(Yso.mode.start_route_loop('future_combat'))
gmcp.Char.Vitals.dead='1';Yso.mode.tick_route_loop('future_combat');eq(mod.state.loop_enabled,false)
gmcp.Char.Vitals.dead='0';assert(Yso.mode.start_route_loop('future_combat'))
target='';Yso.mode.tick_route_loop('future_combat');eq(mod.state.loop_enabled,false)
target='Bob';assert(Yso.mode.start_route_loop('future_combat'));fire('yso.target.changed');eq(mod.state.loop_enabled,false)
-- Repeated event observations never reset the active confirmation budget.
paralyzed=false;local start=P.confirmation_now('apostate_truelock');clock=clock+2
paralyzed=true;P.blocked('apostate_truelock');clock=clock+40;P.blocked('apostate_truelock')
paralyzed=false;P.blocked('apostate_truelock');eq(P.confirmation_now('apostate_truelock')-start,2)
clock=clock+3;eq(P.confirmation_now('apostate_truelock')-start,5)
-- Non-offense and hunting payloads remain available, including forced sends.
paralyzed=true
eq(P.blocks_emission({eq='attack'},{kind='offense',route='apostate_truelock',force=true}),true)
eq(P.blocks_emission({free='order entourage kill Bob'},{kind='offense',route='magi_focus'}),true)
for _,kind in ipairs({'cure','defense','utility'}) do eq(P.blocks_emission({eq='safe'},{kind=kind,route='apostate_truelock'}),false) end
Yso.mode.state='bash';eq(P.blocks_emission({bal='hunt'},{kind='offense',route='legacy_hunt'}),false)
-- Staging cleanup is scoped; already dispatched ownership remains untouched.
local staged={eq={route='apostate_truelock'},bal={route='another_route'}};local cleared={}
Yso.queue={get_staged_owner=function(l) return staged[l] end,clear=function(l) cleared[l]=true end,
 get_owned=function() return {route='apostate_truelock',cmd='already sent'} end}
P.discard_staged('apostate_truelock');eq(cleared.eq,true);eq(cleared.bal,nil)
-- Reloading the policy replaces its events, not duplicate cure nudges.
dofile(root..'/Yso/Combat/combat_pause.lua')
local count=0;for _,h in pairs(handlers) do if h.event=='yso.self.aff.changed' then count=count+1 end end;eq(count,1)
print('PASS shared combat paralysis: all registered routes, deferred startup, clocks, manual stop, emit policy and hunting isolation')
