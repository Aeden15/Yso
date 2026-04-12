local PATH_SEP = package.config:sub(1, 1)

local function script_dir()
  local source = debug.getinfo(1, "S").source or ""
  if source:sub(1, 1) == "@" then source = source:sub(2) end
  return source:match("^(.*)[/\\][^/\\]+$") or "."
end

local function join_path(...)
  local parts = { ... }
  local out = table.remove(parts, 1) or ""
  for i = 1, #parts do
    local part = tostring(parts[i] or "")
    if part ~= "" then
      if out ~= "" and out:sub(-1) ~= PATH_SEP then
        out = out .. PATH_SEP
      end
      out = out .. part
    end
  end
  return out
end

local SCRIPT_DIR = script_dir()
local ROUTE_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "routes", "occ_aff.lua")

local pass_count = 0
local fail_count = 0

local function pass()
  pass_count = pass_count + 1
end

local function fail(label, detail)
  fail_count = fail_count + 1
  io.stderr:write(string.format("FAIL: %s%s\n", label, detail and (" - " .. detail) or ""))
end

local function assert_true(label, got)
  if got ~= true then
    fail(label, string.format("expected true, got %s", tostring(got)))
    return
  end
  pass()
end

local function assert_eq(label, got, expected)
  if got ~= expected then
    fail(label, string.format("expected %s, got %s", tostring(expected), tostring(got)))
    return
  end
  pass()
end

local function assert_has(label, list, wanted)
  for i = 1, #list do
    if list[i] == wanted then
      pass()
      return
    end
  end
  fail(label, string.format("missing value %s", tostring(wanted)))
end

local function setup_world(opts)
  opts = opts or {}
  _G.Yso = {}
  _G.yso = _G.Yso

  local epoch_ms = 0
  _G.getEpoch = function()
    epoch_ms = epoch_ms + 200
    return epoch_ms
  end

  local timer_id = 0
  local timers = {}
  _G.tempTimer = function(_, fn)
    timer_id = timer_id + 1
    timers[timer_id] = fn
    if opts.defer_timers ~= true and type(fn) == "function" then
      fn()
    end
    return timer_id
  end
  _G.cecho = function() end
  _G.echo = function() end

  local queue_owned = {}
  local clear_calls = {}
  local emit_calls = 0

  local queue = {}

  local function lane_value(payload, lane)
    if lane == "free" then
      if type(payload.free) ~= "table" then return "" end
      local out = {}
      for i = 1, #payload.free do
        local cmd = tostring(payload.free[i] or "")
        if cmd ~= "" then out[#out + 1] = cmd end
      end
      return table.concat(out, "&&")
    end
    return tostring(payload[lane] or "")
  end

  function queue.emit(payload, _)
    emit_calls = emit_calls + 1
    if tonumber(opts.emit_fail_on) == emit_calls then
      return false
    end
    local changed = false
    for _, lane in ipairs({ "free", "eq", "bal", "class" }) do
      local cmd = lane_value(payload, lane)
      if cmd ~= "" then
        if queue_owned[lane] ~= cmd then
          queue_owned[lane] = cmd
          changed = true
        end
      end
    end
    return changed
  end

  function queue.clear_owned(lane)
    clear_calls[#clear_calls + 1] = lane
    queue_owned[lane] = nil
    return true
  end

  Yso.queue = queue
  Yso.emit = function(payload, opts)
    return queue.emit(payload, opts)
  end

  local phases = {}
  Yso.occ = {
    get_phase = function(tgt)
      return phases[tostring(tgt):lower()] or "open"
    end,
    set_phase = function(tgt, phase)
      phases[tostring(tgt):lower()] = tostring(phase or "open")
      return true
    end,
    readaura_is_ready = function() return false end,
    cleanse_ready = function() return false end,
    pressure = function(tgt) return "instill " .. tgt .. " with healthleech" end,
    ent_refresh = function(tgt) return "command worm at " .. tostring(tgt):lower() end,
  }

  Yso.state = {
    eq_ready = function() return true end,
    bal_ready = function() return true end,
    ent_ready = function() return true end,
  }

  Yso.get_target = function() return "Test" end
  Yso.target_is_valid = function() return true end
  Yso.loyals_attacking = function() return false end
  Yso.set_loyals_attack = function() end

  dofile(ROUTE_PATH)

  return {
    route = Yso.off.oc.occ_aff,
    clear_calls = clear_calls,
    emit_calls = function() return emit_calls end,
    timers = timers,
    run_timer = function(id)
      local fn = timers[id]
      if type(fn) == "function" then fn() end
    end,
  }
end

print("=== test_occ_aff_loop_requeue ===")
local world = setup_world()
local A = world.route

local sent1 = A.attack_function()
assert_true("first tick sends", sent1)

local sent2 = A.attack_function()
assert_true("second tick requeues same payload", sent2)

assert_eq("emit called twice", world.emit_calls(), 2)
assert_has("cleared free lane ownership", world.clear_calls, "free")
assert_has("cleared eq lane ownership", world.clear_calls, "eq")
assert_has("cleared class lane ownership", world.clear_calls, "class")

print("\n=== Test 2: emit failure clears in-flight fingerprint for retry ===")
do
  local world2 = setup_world({ defer_timers = true, emit_fail_on = 2 })
  local A2 = world2.route

  local sent_ok = A2.attack_function()
  assert_true("2a: first attack sends", sent_ok)
  assert_true("2b: in_flight fingerprint set after first send", tostring(A2.state.in_flight.fingerprint or "") ~= "")

  local sent_fail = A2.attack_function()
  assert_eq("2c: second attack send fails", sent_fail, false)
  assert_eq("2d: in_flight fingerprint cleared on emit failure", tostring(A2.state.in_flight.fingerprint or ""), "")
  assert_eq("2e: in_flight target cleared on emit failure", tostring(A2.state.in_flight.target or ""), "")
end

print("\n=== Test 3: waiting clear timer respects fingerprint guard ===")
do
  local world3 = setup_world({ defer_timers = true })
  local A3 = world3.route

  local sent_ok = A3.attack_function()
  assert_true("3a: first attack sends", sent_ok)
  local first_wait_fp = tostring(A3.state.waiting and A3.state.waiting.fingerprint or "")
  assert_true("3b: waiting fingerprint captured", first_wait_fp ~= "")

  local stale_timer_id = nil
  for id, _ in pairs(world3.timers) do
    stale_timer_id = id
    break
  end
  assert_true("3c: waiting clear timer captured", stale_timer_id ~= nil)

  A3.state.waiting.queue = "new attack waiting"
  A3.state.waiting.fingerprint = "new-fingerprint"
  world3.run_timer(stale_timer_id)

  assert_eq("3d: stale timer does not clear newer waiting fingerprint", tostring(A3.state.waiting.fingerprint or ""), "new-fingerprint")
  assert_eq("3e: stale timer does not clear newer waiting queue", tostring(A3.state.waiting.queue or ""), "new attack waiting")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
