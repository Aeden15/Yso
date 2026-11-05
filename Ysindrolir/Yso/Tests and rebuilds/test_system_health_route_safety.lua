-- Exercise the real Magi explanation path: diagnostics must not reset its planner.
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
dofile(here..'test_magi_focus.lua')
local MF=Yso.off.magi.focus
Yso.session={is_ready=function() return true end}
Yso.curing={policy={status=function() return {set_untrusted=false,current_set='default'} end}}
Yso.Combat.RouteRegistry={active_ids=function() return {'magi_focus'} end,
  resolve=function() return {namespace='Yso.off.magi.focus'} end}
Yso.mode.active_route_id=function() return 'magi_focus' end
getPackages=function() return {} end;getModules=function() return {} end
ak={};Legacy={Curing={}}
YsoWorkspaceLink={status=function() return {busy=false,changed=false} end}
dofile(here..'../Integration/system_health.lua')
MF.state.route.target='different';MF.state.route.room_id='different'
MF.state.route.phase='postconv';MF.state.pending.dehydrate.target='foe'
MF.state.pending.dehydrate.until_at=999999
local result=Yso.system.check({echo=false})
assert(not result.ok,'missing release proof must fail closed')
assert(MF.state.route.phase=='postconv','readiness check reset the live route phase')
assert(MF.state.pending.dehydrate.target=='foe','readiness check cleared an outstanding confirmation')
assert(MF.state.pending.dehydrate.until_at==999999,'readiness check changed a pending deadline')
print('PASS unified health preserves real Magi planner and pending confirmations')
