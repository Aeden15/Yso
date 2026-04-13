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
  if opts.legacy_route_debug ~= nil or opts.legacy_state_debug ~= nil then
    Yso.off = Yso.off or {}
    Yso.off.oc = Yso.off.oc or {}
    Yso.off.oc.occ_aff = Yso.off.oc.occ_aff or {}
    if opts.legacy_route_debug ~= nil then
      Yso.off.oc.occ_aff.debug = opts.legacy_route_debug
    end
    if opts.legacy_state_debug ~= nil then
      Yso.off.oc.occ_aff.state = Yso.off.oc.occ_aff.state or {}
      Yso.off.oc.occ_aff.state.debug = opts.legacy_state_debug
    end
  end

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
  local emit_attempts = 0
  local loyals_attack = (opts.loyals_active == true)
  local ent_ready = (opts.ent_ready ~= false)

  local queue = {}

  local function lane_value(payload, lane)
    if lane == "free" then
      if type(payload.free) == "string" then
        return tostring(payload.free)
      end
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
    emit_attempts = emit_attempts + 1
    if tonumber(opts.emit_fail_on) == emit_attempts then
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
    if changed then
      emit_calls = emit_calls + 1
    end
    return changed
  end

  function queue.clear_owned(lane)
    clear_calls[#clear_calls + 1] = lane
    queue_owned[lane] = nil
    return true
  end
  function queue.get_owned(lane)
    local lane_key = tostring(lane or "")
    local cmd = queue_owned[lane_key]
    if tostring(cmd or "") == "" then return nil end
    return {
      cmd = tostring(cmd),
      route = "occ_aff",
      target = tostring(opts.target or "Test"),
    }
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
    pressure = function(tgt)
      local preset = tostring(opts.pressure_cmd or "")
      if preset ~= "" then return preset end
      return "instill " .. tgt .. " with healthleech"
    end,
    ent_refresh = function(tgt)
      local preset = tostring(opts.ent_cmd or "")
      if preset ~= "" then return preset end
      return "command worm at " .. tostring(tgt):lower()
    end,
  }

  Yso.state = {
    eq_ready = function() return true end,
    bal_ready = function() return true end,
    ent_ready = function() return ent_ready end,
  }
  Yso.cfg = {
    payload_mode = tostring(opts.payload_mode or "paired"),
    emit_prefer = tostring(opts.emit_prefer or "eq"),
    cmd_sep = "&&",
    pipe_sep = "&&",
  }
  Yso.net = { cfg = { dry_run = (opts.dry_run == true) } }

  Yso.get_target = function() return tostring(opts.target or "Test") end
  Yso.target_is_valid = function() return true end
  Yso.loyals_attack = function() return loyals_attack end
  Yso.loyals_attacking = function() return loyals_attack end
  Yso.set_loyals_attack = function(v)
    loyals_attack = (v == true)
  end

  dofile(ROUTE_PATH)

  return {
    route = Yso.off.oc.occ_aff,
    clear_calls = clear_calls,
    emit_calls = function() return emit_calls end,
    emit_attempts = function() return emit_attempts end,
    clear_owned_lane = function(lane) return queue.clear_owned(lane) end,
    set_ent_ready = function(v) ent_ready = (v == true) end,
    owned_lane = function(lane) return queue_owned[lane] end,
    timers = timers,
    run_timer = function(id)
      local fn = timers[id]
      if type(fn) == "function" then fn() end
    end,
  }
end

print("=== test_occ_aff_loop_requeue ===")
local world = setup_world({ loyals_active = true })
local A = world.route

local sent1 = A.attack_function()
assert_true("first tick sends", sent1)
assert_true("eq lane ownership captured after first send", tostring(world.owned_lane("eq") or "") ~= "")
assert_true("class lane ownership captured after first send", tostring(world.owned_lane("class") or "") ~= "")

local sent2 = A.attack_function()
assert_eq("second tick suppresses identical payload", sent2, false)

assert_eq("emit called once", world.emit_calls(), 1)
assert_eq("lane ownership is not cleared post-send", #world.clear_calls, 0)
assert_true("eq lane ownership persists after suppressed second tick", tostring(world.owned_lane("eq") or "") ~= "")
assert_true("class lane ownership persists after suppressed second tick", tostring(world.owned_lane("class") or "") ~= "")

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

print("\n=== Test 4: exact pressure pair does not re-emit in dry loop ===")
do
  local world4 = setup_world({
    target = "Valkya",
    loyals_active = true,
    pressure_cmd = "instill Valkya with healthleech",
    ent_cmd = "command bubonis at Valkya",
  })
  local A4 = world4.route

  local sent_first = A4.attack_function()
  assert_true("4a: first exact-pair tick sends", sent_first)
  assert_eq("4b: eq lane keeps exact instill", tostring(world4.owned_lane("eq") or ""), "instill Valkya with healthleech")
  assert_eq("4c: class lane keeps exact companion command", tostring(world4.owned_lane("class") or ""), "command bubonis at Valkya")

  local sent_second = A4.attack_function()
  assert_eq("4d: second exact-pair tick suppresses identical payload", sent_second, false)
  assert_eq("4e: exact-pair emit count remains one", world4.emit_calls(), 1)
  assert_eq("4f: exact-pair lane ownership is not cleared", #world4.clear_calls, 0)
end

print("\n=== Test 5: opener tick emits free lane only before pressure ===")
do
  local world5 = setup_world({ target = "Valkya", loyals_active = false })
  local A5 = world5.route

  local sent_first = A5.attack_function()
  assert_true("5a: opener tick sends", sent_first)
  assert_eq("5b: opener tick emits no eq lane", tostring(world5.owned_lane("eq") or ""), "")
  assert_eq("5c: opener tick emits no class lane", tostring(world5.owned_lane("class") or ""), "")
  assert_eq("5d: opener tick emits loyals free command", tostring(world5.owned_lane("free") or ""), "order loyals kill Valkya")

  local sent_second = A5.attack_function()
  assert_true("5e: second tick transitions into pressure payload", sent_second)
  assert_true("5f: second tick now carries eq pressure lane", tostring(world5.owned_lane("eq") or "") ~= "")
  assert_true("5g: second tick now carries class pressure lane", tostring(world5.owned_lane("class") or "") ~= "")
end

print("\n=== Test 6: legacy debug boolean state does not crash ===")
do
  local world6 = setup_world({
    target = "Valkya",
    loyals_active = true,
    legacy_route_debug = true,
    legacy_state_debug = true,
  })
  local A6 = world6.route

  local sent = A6.attack_function()
  assert_true("6a: attack still sends with legacy debug booleans", sent)
  local ex = A6.explain()
  assert_true("6b: explain returns table with debug flag", type(ex) == "table" and ex.debug_enabled == true)
  assert_true("6c: state debug normalized to table", type(A6.state and A6.state.debug) == "table")
  assert_true("6d: route debug normalized to table", type(A6.debug) == "table")
end

print("\n=== Test 7: explain surface reports real plan/next/stage fields ===")
do
  local world7 = setup_world({
    target = "Valkya",
    loyals_active = true,
    pressure_cmd = "instill Valkya with healthleech",
    ent_cmd = "command bubonis at Valkya",
  })
  local A7 = world7.route
  local sent = A7.attack_function()
  assert_true("7a: pressure tick sends", sent)
  local ex = A7.explain()
  assert_true("7b: explain has compat plan table", type(ex.plan) == "table")
  assert_eq("7c: explain plan.eq reflects emitted pressure", tostring(ex.plan.eq or ""), "instill Valkya with healthleech")
  assert_eq("7d: explain plan.class reflects emitted entity cmd", tostring(ex.plan.class or ""), "command bubonis at Valkya")
  assert_true("7e: explain stage populated", tostring(ex.stage or "") ~= "")
  assert_true("7f: explain next populated", tostring(ex.next or "") ~= "")
  assert_true("7f2: explain blocker populated", tostring(ex.blocker or "") ~= "")
  assert_eq("7f3: finish_transition stage mirrors stage", tostring(ex.finish_transition and ex.finish_transition.stage or ""), tostring(ex.stage or ""))
  assert_eq("7f4: finish_transition next mirrors next", tostring(ex.finish_transition and ex.finish_transition.next_action or ""), tostring(ex.next or ""))
  assert_eq("7f5: finish_transition blocker mirrors blocker", tostring(ex.finish_transition and ex.finish_transition.blocker or ""), tostring(ex.blocker or ""))
  assert_true("7g: explain route_enabled key present", type(ex.route_enabled) == "boolean")
  assert_true("7h: explain target populated", tostring(ex.target or "") == "Valkya")
  assert_true("7i: explain selector exposes chosen pressure aff", tostring(ex.selector and ex.selector.pressure_aff or "") == "healthleech")
  assert_true("7j: explain selector exposes chosen entity cmd", tostring(ex.selector and ex.selector.entity_cmd or "") == "command bubonis at Valkya")
  assert_true("7k: explain snapshot_state does not blank when missing", tostring(ex.snapshot_state or "") ~= "")
end

print("\n=== Test 8: opener explain reports free plan when loyals bootstrap pending ===")
do
  local world8 = setup_world({ target = "Valkya", loyals_active = false })
  local A8 = world8.route
  local sent = A8.attack_function()
  assert_true("8a: opener sends", sent)
  local ex = A8.explain()
  assert_eq("8b: opener explain plan.free shows kill order", tostring(ex.plan and ex.plan.free or ""), "order loyals kill Valkya")
  assert_eq("8c: opener explain plan.eq remains empty", tostring(ex.plan and ex.plan.eq or ""), "")
  assert_true("8d: opener explain source annotation present", tostring(ex.opener and ex.opener.source or "") ~= "")
end

print("\n=== Test 9: explain runtime persists dry/mode/prefer settings ===")
do
  local world9 = setup_world({
    target = "Valkya",
    loyals_active = true,
    dry_run = true,
    payload_mode = "paired",
    emit_prefer = "eq",
  })
  local A9 = world9.route
  local sent = A9.attack_function()
  assert_true("9a: tick sends", sent)
  local ex = A9.explain()
  assert_eq("9b: explain runtime dry_run tracks setting", tostring(ex.runtime and ex.runtime.dry_run), "true")
  assert_eq("9c: explain runtime payload_mode tracks setting", tostring(ex.runtime and ex.runtime.payload_mode or ""), "paired")
  assert_eq("9d: explain runtime emit_prefer tracks setting", tostring(ex.runtime and ex.runtime.emit_prefer or ""), "eq")
  assert_eq("9e: compat dry_run field present", tostring(ex.dry_run), "true")
  assert_eq("9f: compat mode field present", tostring(ex.mode or ""), "paired")
  assert_eq("9g: compat prefer field present", tostring(ex.prefer or ""), "eq")
end

print("\n=== Test 10: explain reflects ack-cleared class lane immediately ===")
do
  local world10 = setup_world({
    target = "Valkya",
    loyals_active = true,
    pressure_cmd = "instill Valkya with healthleech",
    ent_cmd = "command bubonis at Valkya",
  })
  local A10 = world10.route
  local sent = A10.attack_function()
  assert_true("10a: pressure tick sends", sent)
  local ex1 = A10.explain()
  assert_eq("10b: class planned before ack clear", tostring(ex1.plan and ex1.plan.class or ""), "command bubonis at Valkya")

  world10.clear_owned_lane("class")
  A10.state.waiting = A10.state.waiting or {}
  A10.state.waiting.queue = "queued-pending"
  A10.state.waiting.fingerprint = "fp-pending"
  A10.state.in_flight = A10.state.in_flight or {}
  A10.state.in_flight.fingerprint = "fp-pending"
  local ex2 = A10.explain()
  assert_eq("10c: class planned clears after ack clear", tostring(ex2.plan and ex2.plan.class or ""), "")
  assert_true("10d: explain stage compat key stays populated", tostring(ex2.stage_name or "") ~= "")
  assert_true("10e: explain next compat key stays populated", tostring(ex2.nextaction or "") ~= "")
  assert_true("10f: explain blocker compat key stays populated", tostring(ex2.reason or "") ~= "")
end

print("\n=== Test 11: explain primes planned lanes before first emit tick ===")
do
  local world11 = setup_world({ target = "Valkya", loyals_active = false })
  local A11 = world11.route
  local ex = A11.explain()
  assert_true("11a: explain planned table available pre-first-tick", type(ex.planned) == "table")
  assert_true("11b: explain pre-first-tick exposes at least one planned lane", tostring(ex.planned.free or ex.planned.eq or ex.planned.class or ex.planned.bal or "") ~= "")
  assert_true("11c: explain finish_transition stage populated pre-first-tick", tostring(ex.finish_transition and ex.finish_transition.stage or "") ~= "")
end

print("\n=== Test 12: explain class clears same-cycle when ENT goes down ===")
do
  local world12 = setup_world({
    target = "Valkya",
    loyals_active = true,
    pressure_cmd = "instill Valkya with healthleech",
    ent_cmd = "command bubonis at Valkya",
    ent_ready = true,
  })
  local A12 = world12.route
  local sent = A12.attack_function()
  assert_true("12a: pressure tick sends", sent)
  local ex1 = A12.explain()
  assert_eq("12b: class is present while ENT ready", tostring(ex1.plan and ex1.plan.class or ""), "command bubonis at Valkya")

  world12.set_ent_ready(false)
  local ex2 = A12.explain()
  assert_eq("12c: class clears immediately when ENT down", tostring(ex2.plan and ex2.plan.class or ""), "")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
