local root=arg[1] or 'Ysindrolir'
local sent={}
send=function(c) sent[#sent+1]=c end
cecho=function() end
tempRegexTrigger=function() return 1 end;killTrigger=function() end
registerAnonymousEventHandler=function() return 1 end;killAnonymousEventHandler=function() end
getEpoch=function() return 100 end
Yso={features={alchemist_offense=true}};yso=Yso
gmcp={Char={Status={class='Magi'},Vitals={bal='1',eq='1'}}}
dofile(root..'/Yso/xml/api_stuff.lua')
dofile(root..'/Yso/Core/queue.lua')
dofile(root..'/Yso/Combat/route_registry.lua')
dofile(root..'/Yso/xml/yso_modes.lua')
Yso.off={magi={focus={alias_owned=true,state={},alias_loop_on_started=function() send('must not start during release') end}}}
for _,hold in ipairs({'busy','restart_required'}) do
  YsoWorkspaceLink={busy=false,restart_required=false};YsoWorkspaceLink[hold]=true
  Yso.pause.offense.active=true
  local before=#sent
  assert(not Yso.send('cast fulminate Foe'),'Yso.send bypassed '..hold)
  assert(not Yso.emit({eq='cast fulminate Foe'},{kind='offense',force=true,commit=true}),'forced Yso.emit bypassed '..hold)
  assert(not Yso.emit_now({free='look'},{kind='utility'}),'utility emit_now bypassed '..hold)
  assert(not Yso.queue.install_lane('eq','cast fulminate Foe',{kind='offense',force=true,force_blocked=true}),'queue install bypassed '..hold)
  assert(not Yso.queue.addclear('eq','cast fulminate Foe'),'raw queue send bypassed '..hold)
  assert(not Yso.queue.commit({kind='utility',force=true}),'queue commit bypassed '..hold)
  assert(not Yso.mode.start_route_loop('magi_focus','test'),'route activation bypassed '..hold)
  assert(#sent==before,'automation emitted during '..hold)
  send('user typed look')
  assert(#sent==before+1,'normal user send was wrapped or blocked')
end
-- Compatibility API reloads cannot remove the independent release hold.
dofile(root..'/Yso/Core/api.lua')
YsoWorkspaceLink={restart_required=true,busy=false}
local before_compat=#sent
assert(not Yso.emit_now({eq='cast fulminate Foe'},{kind='utility',force=true}),'compatibility API bypassed restart hold')
assert(#sent==before_compat,'compatibility API emitted during restart hold')
local release_blocked=Yso.release_blocked;Yso.release_blocked=nil
assert(not Yso.queue.install_lane('eq','cast fulminate Foe',{force=true}),'queue depended on a missing API hold helper')
Yso.release_blocked=release_blocked
dofile(root..'/Alchemist/Core/formulation.lua')
dofile(root..'/Alchemist/Core/formulation_resolve.lua')
dofile(root..'/Alchemist/Core/formulation_phials.lua')
Yso.session={is_ready=function() return true end}
local F=Yso.alc.form
assert(not F.request_discovery(),'automatic phiallist bypassed release hold')
assert(not F.send_adjustment('enhance','potency','corrosive'),'formulation sender bypassed release hold')
assert(#sent==before_compat,'formulation emitted during restart hold')
dofile(root..'/Alchemist/Core/physiology.lua')
dofile(root..'/Alchemist/Core/duel route.lua')
dofile(root..'/Alchemist/Core/group damage.lua')
dofile(root..'/Alchemist/Aurify route.lua')
Yso.alc.reaving=true;Yso.alc.reave_pp_paused=true;Yso.alc.reave_target='Foe'
for _,route in pairs(Yso.off.alc) do
  if type(route)=='table' and type(route.stop)=='function' then route.stop('release test') end
end
assert(#sent==before_compat,'direct Alchemist pacification bypassed release hold')
YsoWorkspaceLink={busy=false,restart_required=false}
Yso.pause.offense.active=false
assert(Yso.send('curing on'),'normal startup curing restoration remained blocked')
assert(Yso.emit_now({eq='cast fulminate Foe'},{kind='offense'}),'normal emission did not recover after hold')
print('PASS: release busy/restart holds block forced and legacy automation without wrapping user input')
