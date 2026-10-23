local here = debug.getinfo(1, 'S').source:sub(2):match('^(.*[/\\])')
local root = arg[1] or here .. '../../'
local now, attacks, emit_ok = 10000, {}, true
function getEpoch() return now end
function cecho() end
Yso = {
  class = 'magi', off = { magi = {} },
  get_target = function() return 'Foe' end,
  is_magi = function() return true end,
  state = { eq_ready = function() return true end },
  mode = { is_combat = function() return true end, route_loop_active = function() return true end },
  emit = function(payload)
    if not emit_ok then return false end
    assert(type(payload.eq) == 'string' and not payload.eq:find('|', 1, true), 'one EQ command per payload')
    attacks[#attacks + 1] = payload.eq
    return true
  end,
}
affstrack = { score = {} }
ak = { magi = { resonance = {} }, defs = {} }
dofile(root .. 'Magi/magi_route_core.lua')
local RC = Yso.off.magi.route_core
local W = dofile(root .. 'Magi/Magi_water_group.lua')
local F = dofile(root .. 'Magi/Magi_firestorm.lua')
local function reset(M, earth, score)
  M.state = { enabled = true, loop_enabled = true }
  now = now + 10
  attacks, emit_ok = {}, true
  affstrack.score = { scalded = score or 0 }
  ak = { healthpercent = 100, magi = { resonance = { Earth = earth, Water = 0, Air = 0, Fire = 0 } }, defs = {} }
  Yso.locks, Yso.queue = nil, nil
  Yso.magi.special = nil
end
local function preview(M) return M.attack_function({ preview = true }) end
local function want(M, command, label)
  local plan = preview(M)
  assert(type(plan) == 'table' and plan.lanes.eq == command,
    label .. ': expected ' .. command .. ', got ' .. tostring(type(plan) == 'table' and plan.lanes.eq or plan))
end
for _, M in ipairs({ W, F }) do
  local label = M.key
  -- Removing either condition would wrongly Pebble a confirmed Scalded target or existing Earth.
  for _, case in ipairs({
    { 0, 0, true }, { 0, 100, false }, { 1, 0, false }, { 1, 100, false }, { 0, 99, true },
  }) do
    reset(M, case[1], case[2])
    local plan = preview(M)
    assert((plan.lanes.eq == 'cast pebble at Foe') == case[3], label .. ': scalded/earth truth table')
  end
  reset(M, 0)
  ak.defs.shield = true
  want(M, 'cast erode at Foe shield', label .. ': shield precedes Pebble')
  reset(M, 0)
  ak.healthpercent = 10
  want(M, 'cast stormhammer at Foe', label .. ': execute precedes Pebble')
  reset(M, 0)
  local special = RC.special_action
  RC.special_action = function() return 'special action', 'fixture', false end
  want(M, 'special action', label .. ': special precedes Pebble')
  RC.special_action = function() return nil, 'special_hold', true end
  local ok, reason = M.attack_function()
  assert(not ok and reason == 'special_hold', label .. ': special hold precedes Pebble')
  RC.special_action = special

  reset(M, 0)
  assert(M.attack_function())
  assert(#attacks == 1 and attacks[1] == 'cast pebble at Foe', label .. ': sends Pebble')
  assert(ak.magi.resonance.Earth == 0 and affstrack.score.scalded == 0, label .. ': send does not predict game state')
  local sent, why = M.attack_function()
  assert(not sent and why == 'pebble_pending' and #attacks == 1, label .. ': pending prevents duplicate')
  assert(M.state.template.last_reason == 'pebble_pending', label .. ': debug shows pending')
  now = now + 1.1
  assert(M.attack_function() and #attacks == 2, label .. ': timeout permits retry')
  ak.magi.resonance.Earth = 1
  want(M, M == W and 'cast dehydrate at Foe' or 'cast magma at Foe', label .. ': real Earth resumes setup')
  ak.magi.resonance.Earth = 0
  now = now + 1.1
  want(M, 'cast pebble at Foe', label .. ': depleted Earth is reeligible')

  reset(M, 0)
  emit_ok = false
  assert(not M.attack_function(), label .. ': rejected emission')
  emit_ok = true
  assert(M.attack_function() and #attacks == 1, label .. ': failed submission permits retry')

  reset(M, 0)
  -- A live ack bus delays acknowledgement; submission still needs a bounded pending window.
  Yso.locks = { note_payload = function() end }
  Yso.queue = { commit = function() end }
  assert(M.attack_function())
  assert(not M.attack_function() and #attacks == 1, label .. ': suppresses before delayed acknowledgement')
  M.on_payload_sent({ eq = 'cast pebble at Foe', target = 'Foe' })
  assert(not M.attack_function() and #attacks == 1, label .. ': sent acknowledgement preserves suppression')
  affstrack.score.scalded = 100
  want(M, M == W and 'cast dehydrate at Foe' or 'cast bombard at Foe', label .. ': confirmed Scalded resumes setup')
end
reset(W, 0)
affstrack.score.frozen, affstrack.score.hypothermia = 100, 100
ak.magi.resonance.Water, ak.magi.resonance.Air = 2, 2
want(W, 'cast pebble at Foe', 'water: Pebble precedes Glaciate')
affstrack.score.hypothermia = 0
want(W, 'cast pebble at Foe', 'water: Pebble precedes Hypothermia')
affstrack.score.frozen, affstrack.score.shivering = 0, 100
want(W, 'cast pebble at Foe', 'water: Pebble precedes Freeze')
print('PASS: group Pebble conditions, priority, acknowledgements, timeout, retry and confirmed-state setup')
