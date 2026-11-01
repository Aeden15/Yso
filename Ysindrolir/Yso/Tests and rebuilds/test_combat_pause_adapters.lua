local root=arg[1] or 'Ysindrolir'
local clock,paralyzed,stopped=100,false,nil
local callbacks={}
getEpoch=function() return clock end
tempTimer=function(_,fn) callbacks[#callbacks+1]=fn;return #callbacks end
killTimer=function() end;cecho=function() end
target='Bob';gmcp={Char={Status={class='Apostate'},Vitals={hp='1000',mp='1000',bal='1',eq='1'}}}
Yso={get_target=function() return target end,self={has_aff=function(a) return a=='paralysis' and paralyzed end},
 selfaff={meta={afflictions_ready=true,full_sync_confirmed=true}},
 mode={is_combat=function() return true end,stop_route_loop=function(_,why) stopped=why end},
 apostate={active=function() return true end},emit=function() return true end}
ak={defs={}};affstrack={score={deaf=100}}
local P=dofile(root..'/Yso/Combat/combat_pause.lua')
local T=dofile(root..'/Apostate/lock_route.lua')
local V=dofile(root..'/Apostate/vivisect_route.lua')
for _,M in ipairs({T,V}) do
 T.state.loop_enabled=false;V.state.loop_enabled=false;M.state.loop_enabled=true;M.state.victim=target
 M.state.pending={at=P.confirmation_now(M.key),target=target,action='eyes'}
 paralyzed=true;assert(select(2,M.attack_function())=='paralysis')
 clock=clock+30;assert(select(2,M.attack_function())=='paralysis');assert(M.state.loop_enabled)
 paralyzed=false;local ok,why=M.attack_function();assert(not ok and why=='waiting_eyes',tostring(why));assert(M.state.loop_enabled)
 M.state.loop_enabled=false
end
-- The Monk recovery handshake must not expire during a long paralysis hold.
gmcp.Char.Status.class='Monk';gmcp.Char.Vitals.bal='0';gmcp.Char.Vitals.eq='0'
Yso.monk={shikudo={form='willow'},mindlock={is_locked=function() return true end}}
local G=dofile(root..'/Monk/shikudo_group_damage.lua')
G.state.loop_enabled=true;G.state.enabled=true
G.state.pending={at=P.confirmation_now(G.key),target=target,kind='combo',form='willow',recovered={}}
paralyzed=true;P.blocked(G.key);clock=clock+30;stopped=nil
G.can_run();assert(stopped==nil,'Monk confirmation expired during paralysis')
paralyzed=false;P.blocked(G.key);G.can_run();assert(stopped==nil)
-- Alchemist's asynchronous watchdog needs the same active-time clock.
yajl={to_string=function() return '{}' end}
gmcp.Char.Status.class='Alchemist';gmcp.Char.Vitals.bal='1';gmcp.Char.Vitals.eq='1'
dofile(root..'/Alchemist/Core/physiology.lua')
local A=Yso.alc.phys
assert(A.note_pending_class('temper',target,'sanguine','temper Bob sanguine','alchemist_duel_route'))
local callback=callbacks[#callbacks]
paralyzed=true;P.blocked('alchemist_duel_route');clock=clock+30;callback()
assert(A.state.pending_timeout_event==nil,'Alchemist async watchdog expired during paralysis')
paralyzed=false;P.blocked('alchemist_duel_route');clock=clock+3;callbacks[#callbacks]()
assert(A.state.pending_timeout_event,'Watchdog must still detect a genuine active-time timeout')
print('PASS actual Apostate, Monk and Alchemist confirmation clocks across long paralysis pauses')
