local root=arg[1] or 'Ysindrolir'
local sent,timers,events,clock,serial={},{},{},100,0
getEpoch=function() return clock end
tempTimer=function(_,fn) serial=serial+1;timers[serial]=fn;return serial end
killTimer=function(id) timers[id]=nil end
registerAnonymousEventHandler=function(e,fn) events[e]=fn;return e end
killAnonymousEventHandler=function() end;cecho=function() end
send=function(s) sent[#sent+1]=s end
target='Saibel';gmcp={Char={Status={class='Apostate'},Vitals={bal='0',eq='0'}}}
Yso={get_target=function() return target end};ak={defs={}};affstrack={score={deaf=100}}
dofile(root..'/Yso/Combat/route_registry.lua')
dofile(root..'/Yso/xml/yso_modes.lua')
dofile(root..'/Yso/xml/apostate_utilities.lua')
dofile(root..'/Apostate/entourage.lua')
local T=dofile(root..'/Apostate/lock_route.lua')
local V=dofile(root..'/Apostate/vivisect_route.lua')
assert(Yso.util.toggle_route_alias(V.key,'vivi'));assert(V.is_enabled());assert(not T.is_enabled())
assert(sent[1]=='order daemonite kill Saibel');assert(timers[V.state.timer_id])
assert(Yso.util.toggle_route_alias(T.key,'tlock'));assert(T.is_enabled());assert(not V.is_enabled())
assert(Yso.util.toggle_route_alias(V.key,'vivi'));assert(V.is_enabled());assert(not T.is_enabled())
local id=V.state.timer_id;assert(timers[id]);clock=clock+1;timers[id]()
assert(V.is_enabled());assert(V.state.reason=='self_tracking_unavailable')
local paralyzed=true
Yso.selfaff={meta={afflictions_ready=true,full_sync_confirmed=true}}
Yso.self={has_aff=function(a) return a=='paralysis' and paralyzed end}
id=V.state.timer_id;clock=clock+1;timers[id]();assert(V.state.reason=='paralysis');assert(V.is_enabled())
paralyzed=false;id=V.state.timer_id;clock=clock+1;timers[id]()
assert(V.state.reason=='balance');assert(V.is_enabled())
target='Other';id=V.state.timer_id;clock=clock+1;timers[id]();assert(not V.is_enabled())
local passive=0;for _,s in ipairs(sent) do if s=='order daemonite passive' then passive=passive+1 end end
assert(passive==3,'each route stop must return the daemonite passive once')
print('PASS vivi alias scheduler, exclusive route switching, synchronization and paralysis resume, target cleanup')
