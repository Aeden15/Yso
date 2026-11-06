-- Behavioral regressions for gwater. Mudlet's transport/clock are the only fakes.
local here = debug.getinfo(1, 'S').source:sub(2):match('^(.*[/\\])')
local root = arg[1] or here .. '../../'
local route_file = arg[2] or root .. 'Magi/Magi_water_group.lua'
local feedback_file = arg[3] or root .. 'Magi/resonance_feedback.lua'
local W, RC, now, target, sent, emit_ok, synchronous, eq, paused
local passed, failed = 0, 0
local function reset()
  now, target, sent, emit_ok, synchronous, eq, paused = 10000, 'Foe', {}, true, false, true, false
  function getEpoch() return now end
  function cecho() end
  gmcp = {Char={Status={class='Magi'},Vitals={eq='1'}}}
  affstrack = {score={scalded=100,waterbonds=100}}
  ak = {magi={resonance={Water=2,Earth=1,Fire=1,Air=2}},defs={}}
  Yso = {off={magi={}},magi={},get_target=function() return target end,
    is_magi=function() return true end,target_is_valid=function() return true end,
    offense_paused=function() return paused end,state={eq_ready=function() return eq end},
    mode={is_combat=function() return true end,route_loop_active=function() return true end},
    locks={note_payload=function() end},queue={commit=function() end}}
  yso = Yso
  dofile(root .. 'Yso/Combat/route_interface.lua')
  RC = dofile(root .. 'Magi/magi_route_core.lua')
  dofile(root .. 'Yso/xml/yso_ak_score_exports.lua')
  W = dofile(route_file)
  W.state = {enabled=true,loop_enabled=true}
  Yso.emit = function(payload, opts)
    if not emit_ok then return false end
    payload.route = opts.route
    sent[#sent+1] = payload
    if synchronous then W.on_payload_sent(payload) end
    return true
  end
end
local function want(command)
  local p, why = W.attack_function({preview=true})
  local actual = type(p)=='table' and p.lanes.eq or tostring(why or p)
  assert(actual==command, 'expected '..command..', got '..actual)
end
local function acknowledge(payload)
  Yso._last_eq_ack_payload=payload
  return W.on_payload_sent(payload)
end
local function test(name, body)
  reset()
  local ok, err = pcall(body)
  if ok then passed=passed+1 else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
end

test('possible frozen never enables burst', function()
  affstrack.score.frozen, affstrack.score.hypothermia = 1, 100
  want('cast freeze at Foe')
end)
test('insulation strip is not fully frozen', function()
  affstrack.score.frozen = 100
  want('cast freeze at Foe')
end)
test('weariness prevents choosing dehydrate as a freeze', function()
  affstrack.score.frozen, affstrack.score.nausea, affstrack.score.weariness = 200, 100, 100
  want('cast freeze at Foe')
end)
test('shivering nausea without weariness permits dehydrate', function()
  affstrack.score.frozen, affstrack.score.nausea = 200, 100
  want('cast dehydrate at Foe')
end)
test('ready glaciate precedes optional pebble', function()
  affstrack.score.frozen, affstrack.score.hypothermia, affstrack.score.scalded = 300, 100, 0
  ak.magi.resonance.Earth = 0
  want('cast glaciate at Foe')
end)
test('possible hypothermia is not confirmed', function()
  W.cfg.allow_hypothermia = true
  affstrack.score.frozen, affstrack.score.hypothermia = 300, 50
  want('cast hypothermia at Foe')
end)
test('unverified hypothermia casting defaults off', function()
  affstrack.score.frozen = 300
  want('cast mudslide at Foe')
end)
test('explicit hypothermia opt in', function()
  W.cfg.allow_hypothermia = true
  affstrack.score.frozen = 300
  want('cast hypothermia at Foe')
end)
test('capped fire water still builds missing air', function()
  ak.magi.resonance = {Water=3,Fire=3,Earth=0,Air=0}
  want('cast bombard at Foe')
end)
test('air deficit with earth already moderate uses fulminate', function()
  ak.magi.resonance = {Water=2,Fire=2,Earth=2,Air=1}
  want('cast fulminate at Foe')
end)
test('fully capped resonance spends earth', function()
  ak.magi.resonance = {Water=3,Fire=3,Earth=3,Air=3}
  affstrack.score.frozen = 300
  want('cast emanation at Foe earth')
end)
test('unsupported calcification aliases do not control decisions', function()
  ak.magi.resonance = {Water=3,Fire=3,Earth=0,Air=2}
  affstrack.score.frozen, affstrack.score.calcifiedhead = 300, 100
  want('cast emanation at Foe water')
  affstrack.score.calcifiedhead, affstrack.score.calcifiedtorso = 0, 100
  want('cast emanation at Foe water')
end)
test('shield special and execute priority preserved', function()
  affstrack.score.frozen, affstrack.score.hypothermia = 300, 100
  RC.get_target_hp_percent = function() return 20 end
  RC.special_action = function() return 'cast destroy at Foe', 'destroy_ready' end
  ak.defs.shield = true; want('cast erode at Foe shield')
  ak.defs.shield = false; want('cast destroy at Foe')
  RC.special_action = function() return nil end
  want('cast stormhammer at Foe')
end)
test('one in flight submission even when selected spell changes', function()
  ak.magi.resonance.Water=0
  assert(W.attack_function())
  ak.magi.resonance.Water=2
  now=now+.15
  assert(not W.attack_function(), 'sent another EQ spell before acknowledgement')
  assert(#sent==1)
  assert(W.alias_loop_waiting_blocks(), 'loop must respect submission wait')
end)
test('matching ack resolves wait and does not confirm game effects', function()
  ak.magi.resonance.Water=0
  assert(W.attack_function())
  acknowledge(sent[1])
  assert(not W.alias_loop_waiting_blocks())
  assert(not W.attack_function(), 'same spell immediately retried after ack')
  assert(ak.magi.resonance.Water==0 and not affstrack.score.hypothermia)
  now=now+1.1
  assert(W.attack_function())
end)
test('synchronous ack does not leave phantom wait', function()
  synchronous=true
  assert(W.attack_function())
  assert(not W.alias_loop_waiting_blocks(), 'ack inside emit was overwritten')
  assert(not W.state.waiting.queue, 'interface retained an acknowledged wait')
end)
test('unrelated acks do not resolve submission', function()
  assert(W.attack_function())
  W.on_payload_sent({eq=sent[1].eq,target='Other',route=W.key})
  W.on_payload_sent({bal='kick Foe',target='Foe',route=W.key})
  W.on_payload_sent({eq=sent[1].eq,target='Foe',route='magi_firestorm'})
  assert(W.alias_loop_waiting_blocks())
end)
test('rejected submission can retry immediately', function()
  emit_ok=false
  assert(not W.attack_function())
  emit_ok=true
  assert(W.attack_function())
  acknowledge(sent[1])
  W.on_send_result(sent[1],{success=false})
  assert(W.attack_function(), 'matching rejection left pending suppression')
  local current=sent[2]
  W.on_send_result(sent[1],{success=false})
  assert(not W.attack_function(), 'stale rejection cleared newer attempt')
  acknowledge(current)
end)
test('bounded timeout never stalls indefinitely', function()
  assert(W.attack_function())
  now=now+1.1
  assert(not W.alias_loop_waiting_blocks())
  assert(W.attack_function())
end)
test('stop clears pending before restart', function()
  assert(W.attack_function())
  W.alias_loop_on_stopped({silent=true})
  assert(not W.alias_loop_waiting_blocks())
  assert(W.attack_function())
end)
test('target swap discards stale pending including return to prior target', function()
  assert(W.attack_function())
  target='Other'; assert(W.attack_function())
  target='Foe'; assert(W.attack_function())
  W.on_payload_sent(sent[2])
  assert(W.alias_loop_waiting_blocks(), 'old target ack cleared new target wait')
end)
test('preview is side effect free while waiting', function()
  assert(W.attack_function())
  local submission, count = W.state.submission, #sent
  now=now+2
  W.attack_function({preview=true})
  assert(W.state.submission==submission and #sent==count)
end)
test('pause and invalid context cannot attack', function()
  paused=true; assert(not W.attack_function()); paused=false
  assert(not W.attack_function({target='Other'}), 'used current target afflictions against another target')
  eq=false; assert(not W.attack_function())
  assert(#sent==0)
end)
test('all resonance combinations produce a single legal EQ choice', function()
  for water=0,3 do for earth=0,3 do for fire=0,3 do for air=0,3 do
    ak.magi.resonance = {Water=water,Earth=earth,Fire=fire,Air=air}
    local p=W.attack_function({preview=true})
    assert(type(p)=='table' and p.lanes.eq:match('^cast [%a]+ at Foe'), 'missing EQ choice')
    assert(not p.lanes.eq:find('|',1,true))
    local plane=p.lanes.eq:match('^cast emanation at Foe (%a+)$')
    if plane then assert(RC.read_resonance()[plane]>=3, 'emanation below major') end
    assert(p.lanes.eq~='cast hypothermia at Foe', 'unverified automatic Hypothermia')
  end end end end
  assert(#sent==0)
end)
test('verified resonance rejection releases only the latest matching EQ action', function()
  local feedback=dofile(feedback_file)
  ak.magi.resonance = {Water=3,Fire=3,Earth=0,Air=2}
  affstrack.score.frozen = 300
  assert(W.attack_function())
  local first=sent[1]
  Yso._last_eq_ack_payload=first
  acknowledge(first)
  feedback.failure('moderate','Air')
  assert(not W.attack_function(), 'unrelated requirement cleared pending')
  feedback.failure('major','Water')
  assert(W.attack_function(), 'matching resonance rejection did not reopen')
  local second=sent[2]
  Yso._last_eq_ack_payload=second
  acknowledge(second)
  Yso._last_eq_ack_payload={eq='cast fulminate at Foe',route='magi_firestorm'}
  feedback.failure('major','Water')
  assert(not W.attack_function(), 'later EQ action did not invalidate rejection correlation')
end)
test('preview does not allocate a new pending spell slot', function()
  assert(W.attack_function())
  acknowledge(sent[1])
  affstrack.score.frozen, affstrack.score.hypothermia = 300, 100
  assert(W.state.pending.glaciate==nil)
  want('cast glaciate at Foe')
  assert(W.state.pending.glaciate==nil, 'preview allocated runtime pending state')
end)
test('real queue acknowledgement reaches Water synchronously', function()
  function tempRegexTrigger() return 1 end
  function registerAnonymousEventHandler() return 1 end
  function send() return true end
  Yso.class, Yso.locks, Yso.queue = 'magi', nil, nil
  dofile(root .. 'Yso/xml/api_stuff.lua')
  dofile(root .. 'Yso/Core/queue.lua')
  local core=dofile(root .. 'Yso/Combat/offense_core.lua')
  core.register(W.key,W)
  assert(W.attack_function(), 'actual queue/API refused Water')
  assert(W.state.submission.acknowledged, 'actual locks/core bus missed route callback')
  assert(not W.alias_loop_waiting_blocks() and not W.state.waiting.queue)
  assert(affstrack.score.frozen==nil and ak.magi.resonance.Water==2, 'actual send predicted game state')
end)
test('replayed old ack cannot resolve a repeated command or clear it on rejection', function()
  assert(W.attack_function())
  local old=sent[1]
  now=now+1.1
  assert(W.attack_function())
  W.on_payload_sent(old)
  W.on_send_result(old,{success=false})
  assert(W.alias_loop_waiting_blocks(), 'stale acknowledgement/rejection resolved the newer request')
  acknowledge(sent[2])
  assert(not W.alias_loop_waiting_blocks())
end)
test('hot reload clears old reservations and acknowledged suppression', function()
  assert(W.attack_function())
  W=dofile(route_file)
  assert(W.is_enabled() and not W.alias_loop_waiting_blocks())
  assert(W.attack_function())
  acknowledge(sent[2])
  W=dofile(route_file)
  assert(W.attack_function(), 'reload retained old spell suppression')
end)
test('actual pause API clears pending in both attack and scheduler paths', function()
  Yso.queue, Yso.locks = nil, nil
  function registerAnonymousEventHandler() return 1 end
  function tempRegexTrigger() return 1 end
  dofile(root .. 'Yso/xml/api_stuff.lua')
  Yso.emit=function(p) sent[#sent+1]=p;return true end
  Yso.locks={note_payload=function() end};Yso.queue={commit=function() end}
  assert(W.attack_function())
  Yso.pause_offense(true,'test',true)
  assert(not W.attack_function() and W.state.submission==nil)
  Yso.pause_offense(false,'test',true)
  assert(W.attack_function())
  Yso.pause_offense(true,'test',true)
  assert(not W.alias_loop_waiting_blocks() and W.state.submission==nil)
end)
test('installed current Hypothermia confirmation enables automatic setup and burst', function()
  local T=dofile(root .. 'Magi/magi_spell_feedback.lua')
  W=dofile(route_file)
  affstrack.score.frozen=300
  want('cast hypothermia at Foe')
  function OppGainedAff(aff) affstrack.score[aff]=100 end
  assert(T.handle('hypothermia','Foe'))
  want('cast glaciate at Foe')
  affstrack.score.hypothermia=0
  want('cast hypothermia at Foe')
end)
test('cold startup tolerates deferred core and resumes once it loads', function()
  Yso.off.magi.route_core=nil
  local loaded,route=pcall(dofile,route_file)
  assert(loaded,'route failed before shared core loaded: '..tostring(route))
  W=route
  W.state.enabled,W.state.loop_enabled=true,true
  local ran,reason=W.attack_function()
  assert(not ran and reason=='core_unavailable' and #sent==0)
  assert(not W.alias_loop_waiting_blocks())
  dofile(root .. 'Magi/magi_route_core.lua')
  want('cast freeze at Foe')
end)
test('named shield state takes precedence over global fallback', function()
  ak.defs.shield=true
  ak.defs.shield_by_target={foe=false}
  want('cast freeze at Foe')
end)
test('public can_run accepts absent or string context', function()
  assert(W.can_run())
  assert(W.can_run('loop'))
  assert(W.init()==true)
end)
test('Horripilation requires at least shivering and missing Waterbonds', function()
  affstrack.score.waterbonds=0
  for _,cold in ipairs({0,1,99,100,199}) do
    affstrack.score.frozen=cold
    want('cast freeze at Foe')
  end
  for _,cold in ipairs({200,299,300}) do
    affstrack.score.frozen=cold
    want('staff cast horripilation at Foe')
  end
  affstrack.score.frozen,affstrack.score.waterbonds=200,100
  want('cast freeze at Foe')
  affstrack.score.waterbonds=50
  want('staff cast horripilation at Foe')
end)
test('Horripilation setup preserves defence and finisher priority', function()
  affstrack.score.frozen,affstrack.score.waterbonds,affstrack.score.hypothermia=300,0,100
  RC.get_target_hp_percent=function() return 20 end
  RC.special_action=function() return 'cast destroy at Foe','destroy_ready' end
  ak.defs.shield=true;want('cast erode at Foe shield')
  ak.defs.shield=false;want('cast destroy at Foe')
  RC.special_action=function() return nil end
  want('cast stormhammer at Foe')
  RC.get_target_hp_percent=function() return 100 end
  want('cast glaciate at Foe')
  affstrack.score.hypothermia,affstrack.score.scalded=0,0
  ak.magi.resonance.Earth=0
  want('staff cast horripilation at Foe')
  affstrack.score.waterbonds=100
  want('cast pebble at Foe')
end)
test('staff cast has its own pending window and never predicts Waterbonds', function()
  affstrack.score.frozen,affstrack.score.waterbonds=200,0
  local sent_ok,command=W.attack_function()
  assert(sent_ok and command=='staff cast horripilation at Foe')
  assert(affstrack.score.frozen==200 and affstrack.score.waterbonds==0)
  assert(W.state.submission.slot=='horripilation')
  acknowledge(sent[1])
  local repeated,why=W.attack_function()
  assert(not repeated and why=='horripilation_pending' and #sent==1)
  affstrack.score.waterbonds=100
  want('cast freeze at Foe')
  now=now+1.1
  affstrack.score.waterbonds=0
  want('staff cast horripilation at Foe')
end)
print(('Water route: %d passed, %d failed'):format(passed,failed))
assert(failed==0, 'water route regressions failed')
