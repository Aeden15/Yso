-- Real API, queue, targeting and route scheduler; only Mudlet I/O is simulated.
local here = debug.getinfo(1, 'S').source:sub(2):match('^(.*[/\\])')
local root = arg[2] or here .. '../../'
local sent, timers, messages, aliases = {}, {}, {}, {}
local serial = 0
function send(cmd) sent[#sent + 1] = cmd end
function cecho(msg) messages[#messages + 1] = msg end
function echo(msg) messages[#messages + 1] = msg end
function getEpoch() return 10000 end
function tempTimer(_, fn) serial=serial+1; timers[serial]=fn; return serial end
function killTimer(id) timers[id]=nil; return true end
function tempAlias(pattern, fn) serial=serial+1; aliases[serial]={pattern,fn}; return serial end
function killAlias(id) aliases[id]=nil end
function tempRegexTrigger() serial=serial+1; return serial end
function killTrigger() end
Yso={cfg={cmd_sep='&&'},net={cfg={dry_run=false}},class='magi',
  state={eq_ready=function() return true end,bal_ready=function() return true end}}
yso=Yso
gmcp={Char={Status={class='magi'},Vitals={eq='1',bal='1'}}}
dofile(root .. 'Yso/xml/api_stuff.lua')
dofile(arg[3] or root .. 'Yso/Core/queue.lua')
dofile(root .. 'Yso/xml/route_registry.lua')
dofile(root .. 'Yso/xml/yso_modes.lua')
dofile(root .. 'Yso/Combat/offense_core.lua')
dofile(root .. 'Yso/xml/yso_targeting.lua')
Yso.set_target('FoE','test')
local path = arg[1] or root .. 'Yso/Combat/deliverance.lua'
local D=dofile(path)
assert(type(D.observe)=='function','Deliverance observation API missing')
assert(Yso.Combat.RouteRegistry.resolve('monk_shikudo_duel'),'registry lost Monk duel route')
assert(Yso.Combat.RouteRegistry.resolve('apostate_truelock'),'registry lost Apostate route')

local routes={}
for _,id in ipairs(Yso.Combat.RouteRegistry.active_ids()) do
  local entry=Yso.Combat.RouteRegistry.resolve(id)
  local parent=Yso
  local parts={}; for p in entry.namespace:gmatch('[^.]+') do parts[#parts+1]=p end
  for i=2,#parts-1 do parent[parts[i]]=parent[parts[i]] or {}; parent=parent[parts[i]] end
  local r={key=id,alias_owned=true,cfg={enabled=true},state={enabled=true,loop_enabled=true,
    timer_id=tempTimer(1,function() error('stopped timer ran') end),pending={attack=true},cooldown={attack=true}},
    attack_function=function() return Yso.emit({eq='cast firelash at FoE'},{kind='offense',force=true}) end}
  parent[parts[#parts]]=r; routes[#routes+1]=r
end
local extra={enabled=true,state={enabled=true,loop_enabled=true,timer_id=tempTimer(1,function() end)},
  attack_function=function() return false end}
Yso.off.extra={route=extra}
Yso.off.core.register('unlisted_route',extra)
Yso.off.core.state.active='unlisted_route'
Yso.queue.stage('eq','cast firelash at FoE',{kind='offense'})
Yso.queue.install_lane('bal','kick FoE',{kind='offense',qtype='eb'})
Yso.queue.install_lane('free','attack FoE',{kind='offense',route='magi_focus'})
assert(not D.observe('Other','channeling'),'non-target must not stop routes')
assert(not D.is_held() and routes[1].state.enabled,'non-target changed automation')
assert(D.observe(' foe ','channeling'),'current target was not recognized')
assert(D.is_held() and Yso.offense_paused(),'hold must gate shared offense')
assert(Yso.get_target():lower()=='foe','Deliverance must preserve the target')
for _,r in ipairs(routes) do
  assert(not r.state.enabled and not r.state.loop_enabled and not r.cfg.enabled,'route still enabled: '..r.key)
  assert(r.state.timer_id==nil and next(r.state.pending or {})==nil and r.state.cooldown==nil,'route retained attack state: '..r.key)
end
assert(not extra.enabled and not extra.state.enabled and not extra.state.loop_enabled,'unlisted route was not stopped')
assert(extra.state.timer_id==nil and Yso.off.core.state.active=='','unlisted route timer/selection survived')
assert(Yso.queue.list('eq')==nil and Yso.queue.get_owned('bal')==nil,'queue survived stop')
assert(Yso.queue.get_owned('free')==nil,'free attack queue survived stop')
local clears={}; for _,cmd in ipairs(sent) do if cmd:match('CLEARQUEUE') then clears[#clears+1]=cmd end end
assert(#clears>=4,'server attack queues were not cleared')
assert(table.concat(clears,'\n'):find('CLEARQUEUE eb\n',1,true),'custom attack queue was not cleared')
local count=#messages
D.observe('FoE','channeling'); assert(#messages==count,'duplicate channel warning')
D.observe('FoE','active'); assert(#messages>count and D.status().stage=='active','stage change not reported')
D.observe('FoE','channeling'); assert(D.status().stage=='active','late channel message regressed stage')
Yso.set_target('Other','test')
assert(D.is_held() and Yso.offense_paused(),'target change released hold')
Yso.pause_offense(false,'test',true)
assert(Yso.offense_paused(),'ordinary resume bypassed hold')
assert(not Yso.mode.start_route_loop('magi_focus','test'),'route toggle bypassed hold')
assert(not Yso.off.core.on('unlisted_route'),'offense core bypassed hold')
local before=#sent
assert(not Yso.emit({eq='attack Other'},{kind='offense',force=true}),'forced emit bypassed hold')
assert(not Yso.emit('attack Other',{kind='offense',force=true}),'raw attack emit bypassed hold')
assert(not Yso.queue.stage('eq','attack Other',{kind='offense'}),'direct stage bypassed hold')
assert(not Yso.queue.install_lane('eq','attack Other',{kind='offense',force_blocked=true}),'direct install bypassed hold')
assert(not Yso.queue.commit({eq='attack Other',kind='offense',force=true}),'direct commit bypassed hold')
assert(not Yso.queue.addclear('eq','attack Other'),'legacy addclear bypassed hold')
assert(not Yso.queue.addclearfull('eq','attack Other'),'legacy addclearfull bypassed hold')
assert(not Yso.queue.add('bal','attack Other'),'legacy add bypassed hold')
assert(not Yso.queue.eq_clear('attack Other'),'legacy lane helper bypassed hold')
assert(not Yso.queue.raw('QUEUE ADDCLEAR eq attack Other'),'raw queue bypassed hold')
assert(#sent==before,'attack reached server during hold')
assert(Yso.emit({eq='touch shield'},{kind='defense',commit=true,force=true}),'defense was blocked')
assert(Yso.emit({free='eat kelp'},{kind='cure',commit=true}),'curing was blocked')
assert(Yso.emit({free='look'},{kind='utility',commit=true}),'utility was blocked')
Yso.pause_offense(true,'unrelated',true)
assert(D.release(),'release failed')
assert(not D.is_held() and Yso.offense_paused(),'release cleared unrelated pause')
for _,r in ipairs(routes) do assert(not r.state.loop_enabled,'release restarted route') end
assert(not extra.state.enabled,'release restarted unlisted route')
Yso.pause_offense(false,'test',true)
assert(not Yso.offense_paused(),'ordinary pause did not release')
assert(Yso.mode.start_route_loop('magi_focus','test'),'explicit start after release failed')

-- One broken stop hook must not leave other controllers or queues running.
Yso.set_target('FoE','test')
extra.state.enabled=true; extra.state.loop_enabled=true
extra.on_stop=function() error('test stop failure') end
routes[1].alias_loop_on_stopped=function() error('registered hook failure') end
assert(D.observe('FoE','active'))
assert(not extra.state.enabled and #D.status().failures>0,'stop failure was hidden or prevented fallback')
assert(#D.status().failures>=2,'scheduler swallowed a registered stop-hook failure')
assert(not routes[1].state.enabled,'broken stop prevented remaining shutdown')

-- Legacy source loading has a separate fallback scheduler outside route.state.
-- Invalidating its row must make an already queued callback harmless after release.
D.release()
Yso.mode=nil
yajl={to_string=function() error('standalone test: no diagnostic log') end}
dofile(root .. 'Yso/Core/api.lua')
local fallback={cfg={enabled=false},state={enabled=false,loop_enabled=false},
  is_active=function() return false end,
  attack_function=function() send('ATTACK FROM STALE FALLBACK'); return true end}
fallback.start=function() fallback.state.enabled=true; fallback.state.loop_enabled=true; return true end
Yso.off.alc=Yso.off.alc or {}; Yso.off.alc.group_damage=fallback
assert(Yso.util.toggle_route_alias('alchemist_group_damage','test'),'fallback route did not start')
local loop=Yso.util._route_alias_fallback.loops.alchemist_group_damage
assert(loop and loop.timer_id,'fallback scheduler did not create timer')
local stale=timers[loop.timer_id]
assert(D.observe('FoE','active'))
assert(next(Yso.util._route_alias_fallback.loops)==nil,'fallback scheduler rows survived shutdown')
assert(loop.timer_id==nil,'fallback timer survived shutdown')
D.release()
local before_stale=#sent
stale()
assert(#sent==before_stale,'stale fallback attacked after release')
print('PASS: Deliverance stops all routes, latches, clears queues and preserves non-offense actions')
