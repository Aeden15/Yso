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
local TRIGGER_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Triggers", "Alchemy", "Physiology", "humour_balance.lua")
local ROUTE_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Core", "duel route.lua")

local pass_count = 0
local fail_count = 0

local function fail(label, detail)
  fail_count = fail_count + 1
  io.stderr:write(string.format("FAIL: %s%s\n", label, detail and (" - " .. detail) or ""))
end

local function pass()
  pass_count = pass_count + 1
end

local function assert_eq(label, got, expected)
  if got ~= expected then
    fail(label, string.format("expected %s, got %s", tostring(expected), tostring(got)))
    return
  end
  pass()
end

local function assert_true(label, value)
  if value ~= true then
    fail(label, string.format("expected true, got %s", tostring(value)))
    return
  end
  pass()
end

local function scores(src)
  return setmetatable(src or {}, { __index = function() return 0 end })
end

local function make_world(opts)
  opts = opts or {}
  local now_s = tonumber(opts.now_s or 1500) or 1500
  local current_target = opts.target or "Tharonus"
  local emitted = {}
  local sent = {}

  _G.Yso = nil
  _G.yso = nil
  _G.ak = {
    alchemist = {
      humour = {
        choleric = tonumber(opts.choleric or 0) or 0,
        melancholic = tonumber(opts.melancholic or 0) or 0,
        phlegmatic = tonumber(opts.phlegmatic or 0) or 0,
        sanguine = tonumber(opts.sanguine or 0) or 0,
      },
    },
  }
  _G.affstrack = { score = scores(opts.aff_scores) }
  _G.target = current_target
  _G.matches = {}
  _G.getCurrentLine = function() return "" end
  _G.getEpoch = function() return now_s * 1000 end
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

  _G.Yso = {
    Combat = {
      RouteInterface = {
        ensure_hooks = function() return true end,
      },
    },
    off = {
      alc = {},
      core = {
        register = function() return true end,
      },
    },
    util = {
      now = function() return now_s end,
    },
    state = {
      eq_ready = function() return opts.eq_ready ~= false end,
      bal_ready = function() return opts.bal_ready ~= false end,
    },
    mode = {
      is_party = function() return false end,
      active_route_id = function() return "alchemist_duel_route" end,
      route_loop_active = function(id) return id == "alchemist_duel_route" end,
      schedule_route_loop = function() return true end,
    },
    get_target = function() return current_target end,
    target_is_valid = function(who) return tostring(who or "") ~= "" end,
    offense_paused = function() return false end,
    emit = function(payload)
      emitted[#emitted + 1] = payload
      return true
    end,
  }
  _G.yso = _G.Yso

  dofile(PHYS_PATH)
  dofile(TRIGGER_PATH)
  dofile(ROUTE_PATH)

  local DR = Yso.off.alc.duel_route
  DR.cfg.enabled = true
  DR.state.enabled = true
  DR.state.loop_enabled = true
  DR.init()

  return {
    DR = DR,
    P = Yso.alc.phys,
    emitted = emitted,
    sent = sent,
    affs = _G.affstrack.score,
    ak = _G.ak,
    set_target = function(tgt) current_target = tgt; _G.target = tgt end,
    advance = function(dt) now_s = now_s + (tonumber(dt) or 0) end,
  }
end

local function preview(world)
  return world.DR.build_payload({})
end

print("=== Test 0: route defaults ===")
do
  local world = make_world()
  assert_eq("0a: route id default list index 1", world.DR.giving_default[1], "paralysis")
  assert_eq("0b: route id default list index 2", world.DR.giving_default[2], "asthma")
  assert_eq("0c: route id default list index 3", world.DR.giving_default[3], "impatience")
end

print("=== Test 1: dirty intel evaluates once ===")
do
  local world = make_world()
  local payload, why = preview(world)
  assert_eq("1a: dirty target asks for evaluate", payload and payload.free, "evaluate Tharonus humours")
  assert_eq("1b: evaluate reason is dirty intel", why, "humour_intel_dirty")

  local payload2 = preview(world)
  assert_eq("1c: pending evaluate suppresses repeat evaluate", payload2 and payload2.free, nil)
end

print("\n=== Test 2: aurify window fires in duel route ===")
do
  local world = make_world()
  world.P.handle_humour_balance_line("Looking over Tharonus, you see that:")
  world.ak.alchemist.humour.sanguine = 2
  world.P.handle_humour_balance_line("His sanguine humour has been tempered a total of 2 times.")
  world.P.handle_humour_balance_line("Health: 58%, Mana: 57%.")
  world.P.handle_humour_balance_line("You may study the physiological composition of your subjects once again.")

  local payload, why = preview(world)
  assert_eq("2a: aurify command selected", payload and payload.eq, "aurify Tharonus")
  assert_eq("2b: aurify reason", why, "aurify_window")
end

print("\n=== Test 3: homunculus corrupt window before humour lane ===")
do
  local world = make_world()
  world.P.finish_evaluate("Tharonus")
  world.P.note_evaluate_vitals("Tharonus", 70, 70)
  local payload, why = preview(world)
  assert_eq("3a: direct corrupt command", payload and payload.direct, "homunculus corrupt Tharonus")
  assert_eq("3b: corrupt reason", why, "corrupt_window")
end

print("\n=== Test 4: inundate phlegmatic at conservative threshold ===")
do
  local world = make_world({ phlegmatic = 2, sanguine = 0 })
  world.P.finish_evaluate("Tharonus")
  world.P.note_evaluate_vitals("Tharonus", 80, 80)
  Yso.alc.set_homunculus_ready(false, "test_disable_corrupt")
  local payload, why = preview(world)
  assert_eq("4a: direct inundate command", payload and payload.direct, "inundate Tharonus phlegmatic")
  assert_eq("4b: inundate reason", why, "inundate_window")
end

print("\n=== Test 5: temper fallback when inundate unavailable ===")
do
  local world = make_world({ phlegmatic = 1, sanguine = 0 })
  world.P.finish_evaluate("Tharonus")
  world.P.note_evaluate_vitals("Tharonus", 80, 80)
  Yso.alc.set_homunculus_ready(false, "test_disable_corrupt")
  local payload, why = preview(world)
  local is_temper = payload and type(payload.direct) == "string" and payload.direct:match("^temper Tharonus ") ~= nil
  assert_true("5a: temper command selected", is_temper == true)
  assert_eq("5b: temper reason", why, "temper_window")
end

print("\n=== Test 6: BAL truewrack then affliction wrack fallback ===")
do
  local world = make_world({ sanguine = 2, phlegmatic = 1 })
  world.P.finish_evaluate("Tharonus")
  world.P.note_evaluate_vitals("Tharonus", 80, 80)
  Yso.alc.set_homunculus_ready(false, "test_disable_corrupt")
  Yso.alc.set_humour_ready(false, "test_disable_humour_lane")
  local payload = preview(world)
  assert_eq("6a: truewrack selected when second lane has value", payload and payload.bal, "truewrack Tharonus phlegmatic paralysis")

  world.ak.alchemist.humour.phlegmatic = 0
  payload = preview(world)
  assert_eq("6b: fallback is affliction wrack", payload and payload.bal, "wrack Tharonus paralysis")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
