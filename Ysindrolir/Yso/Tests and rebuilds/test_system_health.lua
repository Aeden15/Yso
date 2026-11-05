local root=(arg[1] or 'Ysindrolir/'):gsub('[/\\]*$','/')
local sent=0
send=function() sent=sent+1;error('health check sent gameplay') end
sendGMCP=send;installModule=send;reloadModule=send;uninstallPackage=send
registerAnonymousEventHandler=function() return 1 end
local packages={'AK','Yso system','Legacy V2.1','Legacy Basher V2.1','Legacy UI V2.0','limb.1.2','Yso Workspace Link'}
getPackages=function() return packages end;getModules=function() return {} end
gmcp={Char={Status={class='Magi'}}}
Yso={features={alchemist_offense=false},session={is_ready=function() return true end},
 Combat={RouteRegistry={active_ids=function() return {'magi_focus'} end,
 resolve=function() return {namespace='Yso.off.magi.focus'} end}},
 off={magi={focus={state={loop_enabled=true,explain={reason='waiting_eq'}},explain=function() error('diagnostic called a mutating route helper') end}}},
 magi={weapons={ids={staff='123',shield='456'}}},
 curing={policy={status=function() return {set_untrusted=false,current_set='default'} end}},
 mode={active_route_id=function() return 'magi_focus' end},
 pause={offense={active=false}},locks={eq_ready=function() return false end,bal_ready=function() return true end}}
Legacy={Curing={ActiveServerSet='default'},NDB={network_status=function() return {mode='cache_only',refresh_enabled=false} end}}
local release_packages={};for _,name in ipairs(packages) do release_packages[#release_packages+1]={name=name,installed=true,consistent=true} end
ak={};affstrack={score={}};YsoWorkspaceLink={status=function() return {busy=false,changed=false,release={id='fixture',consistent=true,restart_required=false,packages=release_packages}} end}
local path=root..'Yso/Integration/system_health.lua'
local f=io.open(path,'rb');assert(f,'unified health service is missing');f:close()
dofile(path)
local function check(id,result)
 for _,row in ipairs(result.checks) do if row.id==id then return row end end
 error('missing check '..id)
end
local before=Yso.off.magi.focus.state.loop_enabled
local result=Yso.system.check({echo=false})
assert(result.ok and type(result.checks)=='table','healthy fixture must pass')
assert(check('feature.alchemist_offense',result).status=='disabled','suspension must be expected')
assert(check('ndb.refresh',result).status=='warn','cache-only data must be visible')
assert(check('route.magi_focus',result).detail:find('waiting_eq',1,true),'route blocker must be visible')
assert(Yso.off.magi.focus.state.loop_enabled==before and sent==0,'check changed automation')
YsoWorkspaceLink.status=function() return {busy=false,changed=false} end
result=Yso.system.check({echo=false})
assert(not result.ok and check('release',result).status=='blocked','missing release proof must fail closed')
YsoWorkspaceLink.status=function() return {release={id='fixture',consistent=true,packages={}}} end
result=Yso.system.check({echo=false})
assert(not result.ok,'an empty package proof must not pass')
YsoWorkspaceLink.status=function() return {busy=false,changed=false,release={id='fixture',consistent=true,restart_required=false,packages=release_packages}} end
Yso.curing.policy.status=function() return {} end;Legacy.Curing.ActiveServerSet=nil
result=Yso.system.check({echo=false})
assert(not result.ok and check('curing',result).status=='blocked','unknown curing state must not claim readiness')
Yso.curing.policy.status=function() return {set_untrusted=false,current_set='default'} end
Legacy.Curing.ActiveServerSet='default'
Yso.session.is_ready=function() return false end
result=Yso.system.check({echo=false})
assert(not result.ok and check('session',result).status=='blocked','runtime auth must fail closed')
result=Yso.system.check({scope='install',echo=false})
assert(result.ok,'offline installation must not need authentication')
YsoWorkspaceLink.status=function() return {restart_required=true,release={restart_required=true}} end
result=Yso.system.check({echo=false})
assert(check('release.restart',result).status=='blocked','restart requirement must block gameplay')
YsoWorkspaceLink.status=function() error('missing receipt') end
result=Yso.system.check({echo=false})
assert(not result.ok and check('release',result).status=='blocked','broken status must be visible without throwing')
YsoWorkspaceLink=nil;packages={};ak=nil;Legacy=nil
result=Yso.system.check({echo=false})
assert(not result.ok and check('dependency.ak',result).status=='blocked','missing AK must be reported')
assert(sent==0,'checks must never send or install')
print('PASS unified readiness, disabled class, route diagnostics, disconnected and failure cases without side effects')
