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
local FORM_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Core", "formulation.lua")
local TRIGGER_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Triggers", "Alchemy", "Physiology", "humour_balance.lua")
local ROUTE_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Core", "group damage.lua")

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

local function scores(src)
  return setmetatable(src or {}, { __index = function() return 0 end })
end

local function make_world(opts)
  opts = opts or {}
  local now_s = tonumber(opts.now_s or 1000) or 1000
  local current_target = opts.target or "Tharonus"
  local emitted = {}
  local sent = {}

  _G.Yso = nil
  _G.yso = nil
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
      is_party = function() return true end,
      party_route = function() return "dam" end,
      route_loop_active = function(id) return id == "alchemist_group_damage" end,
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

  dofile(FORM_PATH)
  dofile(TRIGGER_PATH)
  dofile(ROUTE_PATH)

  local GD = Yso.off.alc.group_damage
  GD.cfg.enabled = true
  GD.state.enabled = true
  GD.state.loop_enabled = true
  GD.init()

  return {
    GD = GD,
    P = Yso.alc.phys,
    emitted = emitted,
    sent = sent,
    affs = _G.affstrack.score,
    advance = function(dt) now_s = now_s + (tonumber(dt) or 0) end,
  }
end

local function preview(world)
  return world.GD.build_payload({})
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

print("\n=== Test 2: evaluate count, vitals, and aurify gate ===")
do
  local world = make_world()
  world.P.note_all_normal("Tharonus")
  world.P.handle_humour_balance_line("Looking over Tharonus, you see that:")
  world.P.handle_humour_balance_line("His sanguine humour has been tempered a total of 2 times.")
  world.P.handle_humour_balance_line("Health: 59%, Mana: 59%.")
  world.P.handle_humour_balance_line("You may study the physiological composition of your subjects once again.")

  local row = world.P.humour("Tharonus", "sanguine")
  assert_eq("2a: steady sanguine count parsed", row.steady_count, 2)
  local payload = preview(world)
  assert_eq("2b: both vitals below 60 enables aurify", payload and payload.eq, "aurify Tharonus")

  world.P.note_evaluate_vitals("Tharonus", 59, 60)
  payload = preview(world)
  assert_eq("2c: mana at 60 blocks aurify", payload and payload.eq, nil)
end

print("\n=== Test 3: paralysis needs steady sanguine >= 2 ===")
do
  local world = make_world()
  world.P.note_all_normal("Tharonus")
  world.P.note_temper_success("Tharonus", "sanguine")
  world.P.note_temper_success("Tharonus", "sanguine")
  Yso.bal.humour = false
  local payload = preview(world)
  assert_eq("3a: inferred-only sanguine does not legalize paralysis", payload and payload.bal, "truewrack Tharonus sanguine nausea")

  world.P.note_steady_count("Tharonus", "sanguine", 2)
  payload = preview(world)
  assert_eq("3b: steady sanguine two legalizes paralysis", payload and payload.bal, "truewrack Tharonus choleric paralysis")
end

print("\n=== Test 4: missing aff selector skips affs already present ===")
do
  local world = make_world({ aff_scores = { paralysis = 100 } })
  world.P.note_all_normal("Tharonus")
  world.P.note_steady_count("Tharonus", "sanguine", 2)
  Yso.bal.humour = false
  local payload = preview(world)
  assert_eq("4a: paralysis already present selects nausea", payload and payload.bal, "truewrack Tharonus sanguine nausea")
end

print("\n=== Test 5: educe iron counts exactly the giving set ===")
do
  local world = make_world({ aff_scores = { paralysis = 100, nausea = 100, sensitivity = 100, asthma = 100 } })
  world.P.note_all_normal("Tharonus")
  local payload = preview(world)
  assert_eq("5a: exactly three giving affs enables iron", payload and payload.eq, "educe iron Tharonus")

  world.affs.haemophilia = 100
  payload = preview(world)
  assert_eq("5b: four giving affs blocks iron", payload and payload.eq, nil)
end

print("\n=== Test 6: live trigger success bookkeeping ===")
do
  local world = make_world()
  world.P.note_all_normal("Tharonus")
  world.P.handle_humour_balance_line("You redirect Tharonus's internal fluids, tempering his choleric humour.")
  assert_eq("6a: temper success captures humour, not pronoun", world.P.humour("Tharonus", "choleric").inferred_count, 1)
  assert_eq("6b: temper success marks humour balance false", Yso.bal.humour, false)

  world.P.handle_humour_balance_line("You send ripples throughout Tharonus's body, wracking his choleric humour.")
  assert_eq("6c: single wrack updates humour timestamp", world.P.humour("Tharonus", "choleric").last_wracked_at > 0, true)

  world.P.handle_humour_balance_line("You send ripples throughout Tharonus's body, wracking his choleric humour and his sanguine humour.")
  assert_eq("6d: truewrack updates first humour timestamp", world.P.humour("Tharonus", "choleric").last_wracked_at > 0, true)
  assert_eq("6e: truewrack updates second humour timestamp", world.P.humour("Tharonus", "sanguine").last_wracked_at > 0, true)
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
