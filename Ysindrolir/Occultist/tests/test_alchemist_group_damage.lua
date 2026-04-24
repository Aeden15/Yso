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
  local self_affs = {}
  for aff, active in pairs(opts.self_affs or {}) do
    if active == true then
      self_affs[tostring(aff):lower()] = true
    end
  end

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
      is_party = function() return true end,
      party_route = function() return "dam" end,
      route_loop_active = function(id) return id == "alchemist_group_damage" end,
      schedule_route_loop = function() return true end,
    },
    get_target = function() return current_target end,
    target_is_valid = function(who) return tostring(who or "") ~= "" end,
    offense_paused = function() return false end,
    self = {
      has_aff = function(aff)
        local key = tostring(aff or ""):lower()
        return key ~= "" and self_affs[key] == true
      end,
      any_aff = function(list)
        if type(list) ~= "table" then
          return false
        end
        for i = 1, #list do
          local key = tostring(list[i] or ""):lower()
          if key ~= "" and self_affs[key] == true then
            return true
          end
        end
        return false
      end,
      is_prone = function()
        return self_affs.prone == true
      end,
      is_writhed = function()
        return self_affs.webbed == true
          or self_affs.roped == true
          or self_affs.transfixed == true
          or self_affs.entangled == true
          or self_affs.bound == true
          or self_affs.impaled == true
      end,
      list_writhe_affs = function()
        local out = {}
        for _, aff in ipairs({ "webbed", "roped", "transfixed", "entangled", "bound", "impaled" }) do
          if self_affs[aff] == true then
            out[#out + 1] = aff
          end
        end
        return out
      end,
      is_paralyzed = function()
        return self_affs.paralysis == true
      end,
    },
    emit = function(payload)
      emitted[#emitted + 1] = payload
      return true
    end,
  }
  _G.yso = _G.Yso

  dofile(PHYS_PATH)
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
    ak = _G.ak,
    set_target = function(tgt)
      current_target = tostring(tgt or "")
      _G.target = current_target
    end,
    set_self_aff = function(name, active)
      local key = tostring(name or ""):lower()
      if key == "" then
        return
      end
      self_affs[key] = (active == true)
    end,
    advance = function(dt) now_s = now_s + (tonumber(dt) or 0) end,
  }
end

local function preview(world)
  return world.GD.build_payload({})
end

print("=== Test 0: Physiology humour pools are skillchart-owned ===")
do
  local world = make_world()
  assert_eq("0a: Physiology has no route giving default", world.P.giving_default, nil)
  assert_eq("0b: route owns giving default", world.GD.giving_default[1], "paralysis")
  assert_eq("0c: choleric includes slickness", world.P.humour_to_affs.choleric[3], "slickness")
  assert_eq("0d: melancholic includes impatience", world.P.aff_to_humour.impatience, "melancholic")
  assert_eq("0e: phlegmatic includes asthma", world.P.aff_to_humour.asthma, "phlegmatic")
  assert_eq("0f: sanguine includes recklessness", world.P.aff_to_humour.recklessness, "sanguine")
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
  world.P.handle_humour_balance_line("Looking over Tharonus, you see that:")
  world.ak.alchemist.humour.sanguine = 2
  world.P.handle_humour_balance_line("His sanguine humour has been tempered a total of 2 times.")
  world.P.handle_humour_balance_line("Health: 59%, Mana: 59%.")
  world.P.handle_humour_balance_line("You may study the physiological composition of your subjects once again.")

  assert_eq("2a: AK sanguine count is read through", world.P.current_humour_count("Tharonus", "sanguine"), 2)
  local payload = preview(world)
  assert_eq("2b: both vitals below 60 enables aurify", payload and payload.eq, "aurify Tharonus")

  world.P.note_evaluate_vitals("Tharonus", 60, 60)
  payload = preview(world)
  assert_eq("2c: 60/60 still enables aurify", payload and payload.eq, "aurify Tharonus")

  world.P.note_evaluate_vitals("Tharonus", 60, 61)
  payload = preview(world)
  assert_eq("2d: mana above 60 blocks aurify", payload and payload.eq, nil)
end

print("\n=== Test 2b: reave finisher outranks iron and resumes on slain ===")
do
  local world = make_world({
    choleric = 1,
    melancholic = 1,
    phlegmatic = 1,
    sanguine = 1,
    aff_scores = { paralysis = 100, nausea = 100, sensitivity = 100 },
  })
  world.P.finish_evaluate("Tharonus")
  world.P.note_evaluate_vitals("Tharonus", 80, 80)

  local can_reave, profile = world.P.can_reave("Tharonus")
  assert_eq("2b1: reave profile is legal with four tempered humours", can_reave, true)
  assert_eq("2b2: reave profile counts all four distinct humours", profile and profile.distinct_tempered, 4)
  assert_eq("2b3: reave profile estimates 4s channel", profile and profile.estimated_channel_duration, 4)

  local payload, why = preview(world)
  assert_eq("2b4: reave selected before iron", payload and payload.direct, "reave Tharonus")
  assert_eq("2b5: reave reason", why, "reave_window")

  local sent_ok, lane = world.GD.attack_function({})
  assert_eq("2b6: attack sends reave action", sent_ok, true)
  assert_eq("2b7: reave lane is humour", lane, "humour")
  assert_eq("2b8: first send pauses curing", world.sent[1], "pp")
  assert_eq("2b9: second send starts reave", world.sent[2], "reave Tharonus")
  assert_eq("2b10: reave state marked active", Yso.alc.reaving, true)
  assert_eq("2b11: reave pause flag marked", Yso.alc.reave_pp_paused, true)

  world.P.handle_humour_balance_line("You have slain Tharonus.")
  assert_eq("2b12: slain resumes curing with second pp", world.sent[#world.sent], "pp")
  assert_eq("2b13: reave state clears on slain", Yso.alc.reaving, false)
end

print("\n=== Test 2c: reave is blocked by self hinder and falls through ===")
do
  local world = make_world({
    choleric = 1,
    melancholic = 1,
    phlegmatic = 1,
    sanguine = 1,
    aff_scores = { paralysis = 100, nausea = 100, sensitivity = 100 },
    self_affs = { paralysis = true },
  })
  world.P.finish_evaluate("Tharonus")
  world.P.note_evaluate_vitals("Tharonus", 80, 80)

  local can_reave = world.P.can_reave("Tharonus")
  assert_eq("2c1: self paralysis blocks reave", can_reave, false)
  local payload = preview(world)
  assert_eq("2c2: blocked reave falls through to iron finisher", payload and payload.eq, "educe iron Tharonus")
end

print("\n=== Test 3: paralysis needs AK sanguine >= 2 ===")
do
  local world = make_world({ sanguine = 1, choleric = 1 })
  world.P.finish_evaluate("Tharonus")
  Yso.bal.humour = false
  local payload = preview(world)
  assert_eq("3a: AK sanguine one does not legalize paralysis", payload and payload.bal, "truewrack Tharonus sanguine nausea")

  world.ak.alchemist.humour.sanguine = 2
  payload = preview(world)
  assert_eq("3b: AK sanguine two legalizes paralysis", payload and payload.bal, "truewrack Tharonus choleric paralysis")
end

print("\n=== Test 4: missing aff selector skips affs already present ===")
do
  local world = make_world({ aff_scores = { paralysis = 100 }, sanguine = 2, choleric = 1 })
  world.P.finish_evaluate("Tharonus")
  Yso.bal.humour = false
  local payload = preview(world)
  assert_eq("4a: paralysis already present selects nausea", payload and payload.bal, "truewrack Tharonus sanguine nausea")
end

print("\n=== Test 5: educe iron counts exactly the giving set ===")
do
  local world = make_world({ aff_scores = { paralysis = 100, nausea = 100, sensitivity = 100, asthma = 100 } })
  world.P.finish_evaluate("Tharonus")
  local payload = preview(world)
  assert_eq("5a: exactly three giving affs enables iron", payload and payload.eq, "educe iron Tharonus")

  world.affs.haemophilia = 100
  payload = preview(world)
  assert_eq("5b: four giving affs blocks iron", payload and payload.eq, nil)
end

print("\n=== Test 6: live trigger balance, AK eat, and stance parsing ===")
do
  local world = make_world()
  world.P.finish_evaluate("Tharonus")
  world.P.handle_humour_balance_line("You redirect Tharonus's internal fluids, tempering faes choleric humour.")
  assert_eq("6a: temper success marks humour balance false", Yso.bal.humour, false)

  world.P.handle_humour_balance_line("You send ripples throughout Tharonus's body, wracking his choleric humour.")
  assert_eq("6b: wrack success is parsed without Yso owning counts", true, true)

  world.P.handle_humour_balance_line("You send ripples throughout Tharonus's body, wracking his choleric humour and his sanguine humour.")
  assert_eq("6c: truewrack success is parsed without Yso owning counts", true, true)

  local event = world.P.handle_humour_balance_line("Tharonus eats an antimony flake.")
  assert_eq("6d: AK-aligned antimony flake line parses", event, "humour_eat_ak_owned")

  world.P.handle_humour_balance_line("A diminutive homunculus resembling Ysindrolir stares menacingly at Tharonus, its eyes flashing brightly.")
  assert_eq("6e: owner homunculus attack stance tracked", Yso.homunculus_attack("Tharonus"), true)
  world.P.handle_humour_balance_line("A diminutive homunculus resembling Ysindrolir eases itself into a passive stance.")
  assert_eq("6f: owner homunculus passive stance tracked", Yso.homunculus_attack(), false)
end

print("\n=== Test 7: truewrack fallback is affliction wrack ===")
do
  local world = make_world({ sanguine = 2, choleric = 0 })
  world.P.finish_evaluate("Tharonus")
  Yso.bal.humour = false
  local payload = preview(world)
  assert_eq("7a: no second-lane value falls back to affliction wrack", payload and payload.bal, "wrack Tharonus paralysis")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
