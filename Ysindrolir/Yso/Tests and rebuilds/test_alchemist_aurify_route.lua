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
local PHYS_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Core", "physiology.lua")
local ROUTE_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Aurify route.lua")

local pass_count = 0
local fail_count = 0

local function fail(label, detail)
  fail_count = fail_count + 1
  io.stderr:write(string.format("FAIL: %s%s\n", label, detail and (" - " .. detail) or ""))
end

local function pass() pass_count = pass_count + 1 end

local function assert_eq(label, got, expected)
  if got ~= expected then
    fail(label, string.format("expected %s, got %s", tostring(expected), tostring(got)))
    return
  end
  pass()
end

local function assert_true(label, cond)
  if cond ~= true then
    fail(label, "expected true")
    return
  end
  pass()
end

local function assert_false(label, cond)
  if cond ~= false then
    fail(label, "expected false")
    return
  end
  pass()
end

local function contains_text(list, text)
  for i = 1, #list do
    if tostring(list[i] or ""):find(text, 1, true) then
      return true
    end
  end
  return false
end

local function free_has(payload, text)
  local free = payload and payload.free or nil
  if type(free) == "table" then
    for i = 1, #free do
      if tostring(free[i] or ""):find(text, 1, true) then
        return true
      end
    end
    return false
  end
  return tostring(free or ""):find(text, 1, true) ~= nil
end

local function make_world(opts)
  opts = opts or {}
  local now_s = tonumber(opts.now_s or 1700) or 1700
  local current_target = opts.target or "TargetOne"
  local sent = {}
  local queue_clear_calls = {}
  local queue_clear_owned_calls = {}
  local queue_clear_dispatched_calls = {}

  _G.Yso = nil
  _G.yso = nil
  _G.target = current_target
  _G.getEpoch = function() return now_s * 1000 end
  _G.getCurrentLine = function() return "" end
  _G.cecho = function() end
  _G.echo = function() end
  _G.send = function(cmd)
    sent[#sent + 1] = cmd
    return true
  end

  _G.gmcp = {
    Char = {
      Status = { class = "Alchemist" },
      Vitals = { eq = "1", equilibrium = "1", bal = "1", balance = "1" },
    },
  }

  _G.ak = {
    defs = { shield = (opts.shielded == true), shield_by_target = { [string.lower(current_target)] = (opts.shielded == true) } },
    alchemist = {
      humour = {
        choleric = opts.choleric or 0,
        melancholic = opts.melancholic or 0,
        phlegmatic = opts.phlegmatic or 0,
        sanguine = opts.sanguine or 0,
      },
    },
  }

  local homunculus_state = { active = false, target = "" }

  _G.Yso = {
    cfg = { UseQueueing = "NO", pipe_sep = "&&" },
    Combat = {
      RouteInterface = {
        ensure_hooks = function() return true end,
      },
    },
    off = {
      alc = {},
      core = { register = function() return true end },
    },
    util = { now = function() return now_s end },
    state = {
      eq_ready = function() return true end,
      bal_ready = function() return true end,
    },
    bal = { humour = true, evaluate = true, homunculus = true },
    mode = {
      is_party = function() return false end,
      active_route_id = function() return "alchemist_aurify_route" end,
      route_loop_active = function(id) return id == "alchemist_aurify_route" end,
      schedule_route_loop = function() return true end,
    },
    get_target = function() return current_target end,
    target_is_valid = function(who) return tostring(who or "") ~= "" end,
    offense_paused = function() return false end,
    shield = { up = function() return opts.shielded == true end },
    set_homunculus_attack = function(v, tgt)
      homunculus_state.active = (v == true)
      homunculus_state.target = (v == true) and tostring(tgt or "") or ""
      return homunculus_state.active
    end,
    homunculus_attack = function(tgt)
      if homunculus_state.active ~= true then return false end
      tgt = tostring(tgt or "")
      if tgt == "" then return true end
      return homunculus_state.target:lower() == tgt:lower()
    end,
    self = {
      has_aff = function(aff)
        return opts.self_affs and opts.self_affs[tostring(aff or ""):lower()] == true
      end,
      is_prone = function() return false end,
      list_writhe_affs = function() return {} end,
      is_writhed = function() return false end,
    },
    tgt = { has_aff = function() return false end },
    queue = {
      can_plan_lane = function() return true end,
      list = function() return nil end,
      clear = function(lane)
        queue_clear_calls[#queue_clear_calls + 1] = lane
        return true
      end,
      clear_owned = function(lane)
        queue_clear_owned_calls[#queue_clear_owned_calls + 1] = lane
        return true
      end,
      clear_lane_dispatched = function(lane, reason)
        queue_clear_dispatched_calls[#queue_clear_dispatched_calls + 1] = { lane = lane, reason = reason }
        return true
      end,
      stage = function() return true end,
    },
  }
  _G.yso = _G.Yso

  dofile(PHYS_PATH)

  local P = _G.Yso.alc.phys
  P.begin_evaluate(current_target)
  P.finish_evaluate(current_target)
  P.note_evaluate_vitals(current_target, tonumber(opts.hp or 80), tonumber(opts.mp or 80))

  dofile(ROUTE_PATH)
  local R = _G.Yso.off.alc.aurify_route
  R.init()
  R.cfg.enabled = true
  R.state.enabled = true
  R.state.loop_enabled = true

  return {
    R = R,
    P = P,
    sent = sent,
    queue_clear_calls = queue_clear_calls,
    queue_clear_owned_calls = queue_clear_owned_calls,
    queue_clear_dispatched_calls = queue_clear_dispatched_calls,
    set_target = function(t)
      current_target = t
      _G.target = t
      _G.Yso.target = t
      P.begin_evaluate(t)
      P.finish_evaluate(t)
    end,
    set_vitals = function(hp, mp)
      P.note_evaluate_vitals(current_target, hp, mp)
    end,
    set_humours = function(ch, me, ph, sa)
      _G.ak.alchemist.humour.choleric = ch or 0
      _G.ak.alchemist.humour.melancholic = me or 0
      _G.ak.alchemist.humour.phlegmatic = ph or 0
      _G.ak.alchemist.humour.sanguine = sa or 0
    end,
  }
end

print("=== Test 1: physiology aurify default requires both vitals ===")
do
  local world = make_world({ hp = 59, mp = 80 })
  assert_eq("1a: default require-both enabled", world.P.cfg.aurify_require_both, true)
  assert_false("1b: hp-only low does not aurify", world.P.can_aurify("TargetOne"))

  world.set_vitals(80, 59)
  assert_false("1c: mp-only low does not aurify", world.P.can_aurify("TargetOne"))

  world.set_vitals(60, 60)
  assert_true("1d: both at threshold allow aurify", world.P.can_aurify("TargetOne"))
end

print("\n=== Test 2: aurify route execute + no inundate&&aurify chain ===")
do
  local world = make_world({ hp = 80, mp = 80, choleric = 6, melancholic = 0, sanguine = 0 })
  local p_burst = world.R.build_payload({ target = "TargetOne" })
  assert_true("2a: burst step chooses inundate first", tostring(p_burst and p_burst.class or ""):find("inundate TargetOne choleric", 1, true) ~= nil)
  assert_eq("2b: no bal after inundate", p_burst and p_burst.bal, nil)

  world.set_vitals(60, 60)
  local p_exec = world.R.build_payload({ target = "TargetOne" })
  assert_eq("2c: aurify selected once both vitals low", p_exec and p_exec.eq, "aurify TargetOne")
  assert_false("2d: no same-payload inundate with aurify", tostring(p_exec and p_exec.class or ""):find("inundate", 1, true) ~= nil)
  assert_eq("2e: execute payload drops bootstrap sidecar", p_exec and p_exec.free, nil)

  local ok = world.R.attack_function({ target = "TargetOne" })
  assert_true("2f: aurify attack succeeds", ok == true)
  assert_true("2g: aurify uses addclearfull", contains_text(world.sent, "QUEUE ADDCLEARFULL e!p!w!t aurify TargetOne"))
end

print("\n=== Test 3: lifecycle homunculus attack/pacify ===")
do
  local world = make_world({ hp = 80, mp = 80, choleric = 0, melancholic = 0, sanguine = 0 })
  local R = world.R

  R.start()
  local p1 = R.build_payload({ target = "TargetOne" })
  assert_true("3a: start arms homunculus attack", free_has(p1, "homunculus attack TargetOne"))

  world.set_target("TargetTwo")
  local p2 = R.build_payload({ target = "TargetTwo" })
  assert_true("3b: target swap re-arms homunculus attack", free_has(p2, "homunculus attack TargetTwo"))

  R.stop("manual")
  assert_true("3c: stop sends pacify", contains_text(world.sent, "homunculus pacify"))
  assert_false("3d: stop never sends passive", contains_text(world.sent, "homunculus passive"))
end

print("\n=== Test 3b: aurify pressure uses one chained class payload ===")
do
  local world = make_world({ hp = 80, mp = 80, choleric = 0, melancholic = 0, sanguine = 0 })
  local payload = world.R.build_payload({ target = "TargetOne" })
  assert_eq("3b-a: pressure class combo", payload and payload.class, "temper TargetOne choleric&&evaluate TargetOne humours&&vitrify TargetOne&&truewrack TargetOne choleric choleric")
  assert_eq("3b-b: no separate eq lane", payload and payload.eq, nil)
  assert_eq("3b-c: no separate bal lane", payload and payload.bal, nil)
  assert_eq("3b-d: configurable combo verb defaults to add", payload and payload.queue_verb, "add")
  assert_eq("3b-e: combo queues on c", payload and payload.qtype, "c")
end

print("\n=== Test 4: aurify reset_route_state clears stale route-local state ===")
do
  local world = make_world({ hp = 60, mp = 60 })
  local R = world.R
  local P = world.P

  R.state.busy = true
  R.state.waiting.queue = "class"
  R.state.waiting.main_lane = "class"
  R.state.waiting.lanes = { class = true }
  R.state.waiting.at = 123
  R.state.homunculus_attack_sent = true
  R.state.homunculus_attack_target = "TargetOne"
  R.state.last_attack = { at = 123, target = "TargetOne", main_lane = "class", cmd = "reave TargetOne" }
  P.state.evaluate.active = true
  P.state.evaluate.target = "TargetOne"
  P.state.evaluate.requested_at = 100
  P.state.evaluate.started_at = 101

  local ok = R.reset_route_state("unit_reset", "TargetOne")
  assert_true("4a: reset returns true", ok == true)
  assert_false("4b: busy cleared", R.state.busy == true)
  assert_eq("4c: waiting queue cleared", R.state.waiting.queue, nil)
  assert_eq("4d: homunculus target cleared", R.state.homunculus_attack_target, "")
  assert_eq("4e: last attack target cleared", R.state.last_attack.target, "")
  assert_false("4f: evaluate inactive", P.state.evaluate.active == true)
  assert_true("4g: local class queue cleared", contains_text(world.queue_clear_calls, "class"))
  assert_false("4h: reset does not send server CLEARQUEUE", contains_text(world.sent, "CLEARQUEUE"))
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
