-- The default package must retain Alchemist code without permitting its offense.
local root=arg[1] or 'Ysindrolir'
local sent={}
send=function(command) sent[#sent+1]=command end
cecho=function() end
getEpoch=function() return 100 end
tempRegexTrigger=function() return 1 end
killTrigger=function() end
registerAnonymousEventHandler=function() return 1 end
killAnonymousEventHandler=function() end
Yso={}; yso=Yso; yajl=nil
dofile(root..'/Yso/xml/api_stuff.lua')
assert(Yso.features and Yso.features.alchemist_offense==false,'Alchemist offense must default to suspended')
local function blocked(payload,opts)
  local before=#sent
  local ok,why=Yso.emit(payload,opts or {kind='offense',force=true})
  assert(ok==false and why=='alchemist_offense_suspended','suspended payload was not rejected')
  assert(#sent==before,'suspended payload reached send')
end
blocked({bal='wrack Foe paralysis',route='alchemist_duel_route'})
blocked({lanes={eq='aurify Foe'}},{kind='utility',force=true})
blocked('queue addclearfull eqbal reave Foe')
blocked({free={'look','homunculus corrupt Foe'}})
blocked({bal='cast fulminate Foe'},{route='alchemist_group_damage',kind='utility'})
assert(Yso.send('educe salt'),'self-curing Salt must remain available')
assert(Yso.send('cast fulminate Foe'),'Magi offense must remain available')
assert(Yso.send('demon corrupt Foe paralysis'),'Apostate offense must remain available')
assert(not Yso.alchemist_offense.blocks({eq='cast fulminate Reave',target='Reave',reason='temper',route='magi_duel'}),'metadata or a target name was classified as a command')
assert(not Yso.send('homunculus attack Foe'),'direct Alchemist sends must be blocked')
assert(not Yso.send('educe magnesium'),'Alchemist Battlerage must remain suspended')
assert(not Yso.send('throw caustic at Foe'),'Alchemist Battlerage phials must remain suspended')
dofile(root..'/Yso/Core/queue.lua')
local before_queue=#sent
assert(not Yso.queue.install_lane('bal','wrack Foe asthma',{route='alchemist_duel_route',force=true}),'legacy lane install bypassed suspension')
assert(not Yso.queue.stage('eq','aurify Foe',{route='alchemist_aurify_route'}),'legacy staging bypassed suspension')
assert(not Yso.queue.addclear('eqbal','reave Foe'),'legacy queue send bypassed suspension')
assert(#sent==before_queue,'legacy queue emitted suspended class offense')

local killed={}
killTimer=function(id) killed[id]=true end
local cleared={}
Yso.queue={
  get_owned=function(lane) return lane=='bal' and {route='alchemist_duel_route',cmd='wrack Foe asthma'} or nil end,
  clear_lane=function(lane) cleared[lane]=true end,
  get_staged_owner=function(lane) return lane=='eq' and {route='alchemist_aurify_route'} or nil end,
  clear=function(lane) cleared[lane]=true end,
}
local old={state={enabled=true,loop_enabled=true,timer_id=77,timer_generation=1,pending={cmd='wrack Foe asthma'},waiting={queue=true}},cfg={enabled=true}}
Yso.session={is_ready=function() return true end}
Yso.off={alc={duel_route=old}}
Yso.mode={route_loop={active='alchemist_duel_route'}}
assert(Yso.alchemist_offense.set_enabled(false))
assert(killed[77] and cleared.bal and cleared.eq,'suspension must cancel owned queued work')
assert(old.state.enabled==false and old.state.loop_enabled==false and old.state.pending==nil)
assert(Yso.mode.route_loop.active=='','stale scheduler ownership survived suspension')
Yso.queue=nil

dofile(root..'/Alchemist/Core/physiology.lua')
local P=Yso.alc.phys
P.begin_evaluate('Foe')
assert(P.finish_evaluate('Foe'),'evaluation must not require yajl')
P.cfg.debug=true
Yso.trace={push=function() error('diagnostic failure') end}
assert(P.note_evaluate_request('Other','test'),'diagnostic failure interrupted evaluation')
assert(not P.fire_reave('Foe',{},{}),'direct Reave must remain suspended')
dofile(root..'/Alchemist/Core/duel route.lua')
local route=Yso.off.alc.duel_route
assert(not route.start('manual'),'direct route start bypassed suspension')
assert(not route.attack_function({preview=true}),'preview planner bypassed suspension')
dofile(root..'/Alchemist/Core/group damage.lua')
dofile(root..'/Yso/Combat/route_registry.lua')
dofile(root..'/Yso/xml/yso_modes.lua')
gmcp={Char={Status={class='Alchemist'}}}
local started,reason=Yso.mode.start_route_loop(' gd ','test')
assert(started==false and reason=='alchemist_offense_suspended','generic or whitespace aliases bypassed suspension')
Yso.off.alc.group_damage.state.loop_enabled=true
assert(not Yso.mode.schedule_route_loop('gd',0),'direct scheduling bypassed suspension')
assert(not Yso.mode.tick_route_loop('gd'),'stale scheduler tick bypassed suspension')
assert(Yso.off.alc.group_damage.state.loop_enabled==false,'stale suspended scheduler state was not canceled')
local count_before_reload=#sent
local original_stop=route.stop
route.stop=function() send('must not stop an idle or unauthenticated route through raw send') end
route.state.enabled=false;route.state.loop_enabled=false
assert(Yso.alchemist_offense.set_enabled(false))
assert(#sent==count_before_reload,'idle suspension emitted cleanup commands')
Yso.session={is_ready=function() return false end}
route.state.enabled=true;route.state.loop_enabled=true
assert(Yso.alchemist_offense.set_enabled(false))
assert(#sent==count_before_reload,'unauthenticated suspension emitted cleanup commands')
route.stop=original_stop

local before=#sent
Yso.session={is_ready=function() return true end,subscribe=function(_,ready) ready() end}
dofile(root..'/Alchemist/Core/formulation.lua')
assert(#sent==before,'suspended Alchemist automatic discovery sent a command')

assert(Yso.alchemist_offense.set_enabled(true))
dofile(root..'/Yso/xml/api_stuff.lua')
assert(Yso.features.alchemist_offense==true,'reload lost explicit future reactivation')
assert(Yso.send('wrack Foe asthma'),'explicitly enabled offense is still blocked')
dofile(root..'/Yso/Core/queue.lua')
assert(Yso.queue.stage('free','homunculus attack Foe',{route='alchemist_duel_route',kind='offense'}))
assert(Yso.queue.stage('free','eat bloodroot',{route='apostate_truelock',kind='cure'}))
assert(Yso.alchemist_offense.set_enabled(false))
local remaining=Yso.queue.list('free')
assert(#remaining==1 and remaining[1]=='eat bloodroot','suspension must discard only its owned free-lane offense')
dofile(root..'/Yso/xml/api_stuff.lua')
assert(Yso.features.alchemist_offense==false,'reload reactivated suspended offense')
print('PASS: Alchemist suspension, emission gates, cleanup, safe logging and explicit reactivation')
