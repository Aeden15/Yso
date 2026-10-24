-- Toggle lifecycle with the real scheduler, including failed sends and repeated cleanup.
local root=arg[1] or 'Ysindrolir'
local sent,events,timers={},{},{}
local clock,serial=100,0
getEpoch=function() return clock end
tempTimer=function(_,fn) serial=serial+1;timers[serial]=fn;return serial end
killTimer=function(id) timers[id]=nil end
registerAnonymousEventHandler=function(e,fn) events[e]=fn;return e end
killAnonymousEventHandler=function() end
cecho=function() end
send=function(s) sent[#sent+1]=s end
target='Saibel'
gmcp={Char={Status={class='Apostate'},Vitals={bal='0',eq='0'}}}
Yso={get_target=function() return target end}
dofile(root..'/Yso/Combat/route_registry.lua')
dofile(root..'/Yso/xml/yso_modes.lua')
dofile(root..'/Yso/xml/apostate_utilities.lua')
local M=dofile(root..'/Apostate/lock_route.lua')
local kill='order entourage kill Saibel&&order daemonite kill Saibel&&order bloodworms kill Saibel&&order nightmare kill Saibel'
local passive='order entourage passive&&order daemonite passive&&order bloodworms passive&&order nightmare passive'
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function orders()
 local out={};for _,s in ipairs(sent) do if s:match('^order ') then out[#out+1]=s end end;return out
end
local function start() assert(Yso.util.toggle_route_alias(M.key,'tlock')) end
local function tick()
 local id=M.state.timer_id;local fn=assert(timers[id]);timers[id]=nil;clock=clock+1;fn()
end
start();eq(orders()[1],kill);eq(#orders(),1);eq(M.state.pending,nil)
M.alias_loop_on_started();eq(#orders(),1) -- Duplicate callbacks cannot re-order pets.
start();eq(orders()[2],passive);eq(M.is_enabled(),false)
M.alias_loop_on_stopped({reason='manual'});eq(#orders(),2)
for _,reason in ipairs({'confirmation_timeout','target_slain','route_error','catharsis_sent','manual'}) do
 sent={};start();M.stop(reason);eq(#orders(),2);eq(orders()[2],passive)
 M.stop(reason);eq(#orders(),2)
end
-- A target change before the first pressure tick must stop rather than retarget the pets.
sent={};start();target='Other';tick();eq(M.is_enabled(),false);eq(orders()[2],passive);target='Saibel'
sent={};start();events['sysDisconnectionEvent']();eq(orders()[2],passive)
sent={};start();gmcp.Char.Status.class='Monk';events['gmcp.Char.Status']()
eq(M.is_enabled(),false);eq(orders()[2],passive);gmcp.Char.Status.class='Apostate'
for _,bad in ipairs({'','Saibel&&quit'}) do
 target=bad;sent={};start();tick();eq(#orders(),0);eq(M.is_enabled(),false)
end
target='Saibel';gmcp.Char.Status.class='Monk';sent={};start();tick()
eq(#orders(),0);eq(M.is_enabled(),false);gmcp.Char.Status.class='Apostate'
-- An unavailable or throwing sender must stop cleanly without a pending attack.
local rawsend=send
for _,sender in ipairs({false,function() error('sender failed') end}) do
 send=sender;sent={};start();tick();eq(M.is_enabled(),false);eq(M.state.pending,nil)
end
send=rawsend
-- Yso.send is preferred, and its failure is not retried through the raw sender.
Yso.send=function() return false end;sent={};start();tick()
eq(M.is_enabled(),false);eq(#orders(),0);Yso.send=nil
-- Fallback stop without a scheduler still returns commanded creatures to passive.
sent={};start();local stop=Yso.mode.stop_route_loop;Yso.mode.stop_route_loop=nil
M.stop('manual');eq(orders()[2],passive);eq(M.is_enabled(),false);Yso.mode.stop_route_loop=stop
print('PASS creature toggle batches, deduplication, automatic stops, target guards, sender failures')
