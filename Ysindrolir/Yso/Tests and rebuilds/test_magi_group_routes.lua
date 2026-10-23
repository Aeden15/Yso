local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
local root=arg[1] or here..'../../'
local killed,attacks={},{ }
function killTimer(id) killed[id]=true end
function cecho() end
function getEpoch() return 10000 end
function send() end
Yso={class='magi',off={magi={}},util={},mode={route_loop={active='magi_group_damage',nudges={}}}}
yso=Yso
dofile(root..'Yso/Core/queue.lua')
Yso.queue.install_lane('eq','old attack',{route='magi_group_damage'})
Yso.queue.install_lane('bal','other attack',{route='magi_firestorm'})
Yso.queue.stage('eq','replacement staged attack')
Yso.queue._commit_hint={route='magi_water_group'}
local old={cfg={enabled=true},state={enabled=true,loop_enabled=true,timer_id=17,pending={attack=true}}}
Yso.off.magi.group_damage=old
Yso.off.core={routes={magi_group_damage=old},state={active='magi_group_damage'}}
Yso.util._route_alias_fallback={loops={magi_group_damage={route=old,timer_id=18}}}
local R=dofile(root..'Yso/Combat/route_registry.lua')
assert(not R.resolve('magi_group_damage'),'retired route remains registered')
assert(not R.resolve('mdam'),'retired alias still selects a route')
assert(not R.resolve('gd') and not R.resolve('dmg') and not R.resolve('dam'),'generic Magi aliases resurrect retired group selection')
assert(R.resolve('gwater').id=='magi_water_group','water route missing')
assert(R.resolve('fstorm').id=='magi_firestorm','firestorm route missing')
dofile(root..'Magi/retire_group_damage.lua')
assert(killed[17] and killed[18],'retired timers survived import')
assert(not old.cfg.enabled and not old.state.loop_enabled,'retired route remained enabled')
assert(Yso.off.magi.group_damage==nil and Yso.off.core.routes.magi_group_damage==nil,'retired route cache survived')
assert(Yso.off.core.state.active=='' and Yso.mode.route_loop.active=='','retired active route survived')
assert(next(Yso.util._route_alias_fallback.loops)==nil,'retired fallback survived')
assert(Yso.queue.get_owned('eq')==nil,'retired attack queue survived migration')
assert(Yso.queue.get_owned('bal').route=='magi_firestorm','replacement route queue was cleared by migration')
assert(Yso.queue.list('eq')=='replacement staged attack','replacement staging was cleared with an old server queue')
dofile(root..'Magi/retire_group_damage.lua') -- repeat imports are harmless
Yso.class='alchemist'
assert(R.resolve('gd').id=='alchemist_group_damage','Alchemist generic alias was removed')
Yso.class='magi'
gmcp={Char={Status={class='magi'},Vitals={eq='1',bal='1'}}}
affstrack={score={}}
Yso.get_target=function() return 'Foe' end
Yso.is_magi=function() return Yso.class=='magi' end
Yso.state={eq_ready=function() return true end}
Yso.mode.is_combat=function() return true end
Yso.mode.route_loop_active=function() return true end
Yso.emit=function(payload) attacks[#attacks+1]=payload.eq;return true end
dofile(root..'Magi/magi_route_core.lua')
local W=dofile(root..'Magi/Magi_water_group.lua')
local F=dofile(root..'Magi/Magi_firestorm.lua')
W.state.enabled=true;W.state.loop_enabled=true
F.state.enabled=true;F.state.loop_enabled=true
local water_ok,water_reason=W.attack_function();assert(water_ok,'replacement water route: '..tostring(water_reason))
local fire_ok,fire_reason=F.attack_function();assert(fire_ok,'replacement firestorm route: '..tostring(fire_reason))
assert(#attacks==2,'replacement routes did not emit')
local D=dofile(root..'Yso/Combat/deliverance.lua')
function send() end
assert(D.observe('Foe','active'))
assert(not W.state.loop_enabled and not F.state.loop_enabled,'Deliverance did not stop replacement routes')
assert(not W.attack_function() and not F.attack_function(),'replacement route attacked after stop')
print('PASS: retired route cannot restart; Water and Firestorm replace it and respect Deliverance')
