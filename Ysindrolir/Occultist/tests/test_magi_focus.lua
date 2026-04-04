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
local ROUTE_CORE_PATH = join_path(SCRIPT_DIR, "..", "..", "Magi", "magi_route_core.lua")
local DISS_PATH = join_path(SCRIPT_DIR, "..", "..", "Magi", "magi_dissonance.lua")
local FOCUS_PATH = join_path(SCRIPT_DIR, "..", "..", "Magi", "magi_focus.lua")

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
  assert_eq(label, value == true, true)
end

local function defaulted_scores(src)
  local row = src or {}
  return setmetatable(row, { __index = function() return 0 end })
end

local function install_mudlet_stubs(now_ref)
  _G.setConsoleBufferSize = function() end
  _G.registerAnonymousEventHandler = function() return 1 end
  _G.killAnonymousEventHandler = function() end
  _G.tempRegexTrigger = function() return 1 end
  _G.killTrigger = function() end
  _G.tempAlias = function() return 1 end
  _G.killAlias = function() end
  _G.tempTimer = function() return 1 end
  _G.killTimer = function() end
  _G.expandAlias = function() return true end
  _G.raiseEvent = function() end
  _G.getCurrentLine = function() return "" end
  _G.matches = {}
  _G.cecho = function() end
  _G.echo = function() end
  _G.send = function() return true end
  _G.getEpoch = function() return now_ref() * 1000 end
end

local function make_world(opts)
  opts = opts or {}

  local current_target = opts.target or "foe"
  local current_room = tostring(opts.room_id or "1001")
  local now_s = tonumber(opts.now_s or 1000) or 1000
  local emits = {}
  local focus_active = (opts.focus_active == true)
  local hp_pct = opts.hp_pct
  local aff_scores = defaulted_scores(opts.aff_scores)
  local resonance = {
    air = tonumber(opts.air_res or 0) or 0,
    earth = tonumber(opts.earth_res or 0) or 0,
    fire = tonumber(opts.fire_res or 0) or 0,
    water = tonumber(opts.water_res or 0) or 0,
  }

  install_mudlet_stubs(function() return now_s end)

  _G.Yso = nil
  _G.yso = nil
  _G.affstrack = {
    score = aff_scores,
    kelpscore = tonumber(opts.kelpscore or 0) or 0,
  }
  _G.target = current_target
  _G.gmcp = {
    Char = {
      Status = { class = "Magi" },
      Vitals = { eq = "1", equilibrium = "1" },
    },
    Room = {
      Info = { num = current_room },
    },
  }

  _G.Yso = {
    Combat = {
      RouteInterface = {
        ensure_hooks = function() return true end,
      },
    },
    off = {
      magi = {},
    },
    magi = {
      resonance = {
        state = resonance,
        sync_from_ak = function() return true end,
        get = function(element)
          return resonance[tostring(element or ""):lower()] or 0
        end,
      },
      crystalism = {
        has_focus = function() return focus_active == true end,
        note_focus = function() focus_active = true end,
        clear_focus = function() focus_active = false end,
      },
      elemental = {
        get_target_hp_percent = function() return hp_pct end,
      },
    },
    util = {
      now = function() return now_s end,
    },
    classinfo = {
      get = function() return "Magi" end,
      is_magi = function() return true end,
    },
    state = {
      eq_ready = function() return opts.eq_ready ~= false end,
    },
    mode = {
      is_party = function() return false end,
      is_combat = function() return true end,
      route_loop_active = function(id) return id == "focus" end,
      schedule_route_loop = function() return true end,
      stop_route_loop = function() return true end,
    },
    get_target = function()
      return current_target
    end,
    target_is_valid = function(who)
      return tostring(who or "") ~= ""
    end,
    offense_paused = function()
      return false
    end,
    queue = {
      clear = function() return true end,
    },
    emit = function(payload)
      emits[#emits + 1] = payload
      return true
    end,
  }
  _G.yso = _G.Yso

  dofile(ROUTE_CORE_PATH)
  dofile(DISS_PATH)
  dofile(FOCUS_PATH)

  local MF = Yso.off.magi.focus
  MF.state.enabled = true
  MF.state.loop_enabled = true
  MF.cfg.enabled = true
  MF.init()

  if tonumber(opts.dissonance_stage) then
    Yso.magi.dissonance.note(current_target, "tracked", {
      stage = tonumber(opts.dissonance_stage),
      confidence = opts.dissonance_confidence or "medium",
      evidence = opts.dissonance_evidence or "seeded",
    })
  end

  return {
    MF = MF,
    emits = emits,
    scores = aff_scores,
    set_target = function(who)
      current_target = tostring(who or "")
      _G.target = current_target
    end,
    set_room = function(room_id)
      current_room = tostring(room_id or "")
      _G.gmcp.Room.Info.num = current_room
    end,
    set_res = function(element, value)
      resonance[tostring(element or ""):lower()] = tonumber(value or 0) or 0
    end,
    set_focus = function(on)
      focus_active = (on == true)
    end,
    set_dissonance = function(stage, confidence, evidence)
      Yso.magi.dissonance.reset_target(current_target)
      if tonumber(stage or 0) > 0 then
        Yso.magi.dissonance.note(current_target, "tracked", {
          stage = tonumber(stage),
          confidence = confidence or "medium",
          evidence = evidence or "seeded",
        })
      end
    end,
    advance = function(dt)
      now_s = now_s + (tonumber(dt) or 0)
    end,
  }
end

local function preview_eq(world)
  local payload, why = world.MF.build_payload({})
  if not payload then return nil, why end
  local lanes = type(payload.lanes) == "table" and payload.lanes or {}
  local meta = type(payload.meta) == "table" and payload.meta or {}
  return lanes.eq, meta.main_reason
end

local function note_sent(world, cmd)
  world.MF.on_payload_sent({ eq = cmd })
end

print("=== Test 1: horripilation opener ===")
do
  local world = make_world({})
  local cmd = preview_eq(world)
  assert_eq("1a: missing waterbonds opens with horripilation", cmd, "staff cast horripilation foe")
end

print("\n=== Test 2: freeze reopens if either frozen or frostbite is missing ===")
do
  local world = make_world({
    aff_scores = {
      waterbonds = 100,
      frozen = 100,
    },
  })
  local cmd = preview_eq(world)
  assert_eq("2a: frostbite gap reopens freeze", cmd, "cast freeze at foe")
  world.set_focus(true)
  preview_eq(world)
  local ex = world.MF.explain()
  assert_eq("2b: explain uses planner route key", ex.route, "focus")
  assert_eq("2c: explain decision uses planner wording", ex.decision, "freeze_reopen")
  assert_eq("2d: explain reason tracks the missing piece", ex.reason, "frostbite_missing")
  assert_true("2e: explain exposes focus overlay state", ex.fulminate and ex.fulminate.focus_punish_armed == true)
end

print("\n=== Test 3: bombard revisit remains a live branch ===")
do
  local world = make_world({
    aff_scores = {
      waterbonds = 100,
      frozen = 100,
      frostbite = 100,
      clumsiness = 100,
    },
    air_res = 1,
    earth_res = 1,
    fire_res = 2,
    water_res = 2,
  })
  local cmd, reason = preview_eq(world)
  assert_eq("3a: missing asthma revisits bombard", cmd, "cast bombard at foe")
  assert_eq("3b: bombard reason is planner-local", reason, "asthma_missing")
end

print("\n=== Test 4: fulminate continuation swaps in ahead of later gates ===")
do
  local world = make_world({
    aff_scores = {
      waterbonds = 100,
      frozen = 100,
      frostbite = 100,
      clumsiness = 100,
      asthma = 100,
      fulminated = 100,
    },
    kelpscore = 2,
    air_res = 2,
    earth_res = 2,
    fire_res = 2,
    water_res = 2,
    dissonance_stage = 2,
  })
  local cmd, reason = preview_eq(world)
  assert_eq("4a: partial fulminate chain continues when kelp pressure is live", cmd, "cast fulminate at foe")
  assert_eq("4b: fulminate reason names the missing continuation", reason, "epilepsy_missing")
end

print("\n=== Test 5: convergence immediately outranks fulminate once legal ===")
do
  local world = make_world({
    aff_scores = {
      waterbonds = 100,
      frozen = 100,
      frostbite = 100,
      clumsiness = 100,
      asthma = 100,
      fulminated = 100,
    },
    kelpscore = 2,
    air_res = 2,
    earth_res = 2,
    fire_res = 2,
    water_res = 2,
    dissonance_stage = 4,
  })
  local cmd, reason = preview_eq(world)
  assert_eq("5a: convergence fires as soon as all gates are satisfied", cmd, "cast convergence at foe")
  assert_eq("5b: convergence reason stays planner-friendly", reason, "all_gates_satisfied")
end

print("\n=== Test 6: post-convergence overlay starts with destroy ===")
do
  local world = make_world({
    aff_scores = {
      waterbonds = 100,
      frozen = 100,
      frostbite = 100,
      clumsiness = 100,
      asthma = 100,
      conflagrate = 100,
    },
    air_res = 2,
    earth_res = 2,
    fire_res = 2,
    water_res = 2,
    dissonance_stage = 4,
  })
  note_sent(world, "cast convergence at foe")
  local cmd = preview_eq(world)
  assert_eq("6a: postconv prefers destroy first", cmd, "cast destroy at foe")
end

print("\n=== Test 7: pending windows advance the route and suppress identical repeats ===")
do
  local world = make_world({
    aff_scores = {
      waterbonds = 100,
      frozen = 100,
      clumsiness = 100,
      asthma = 100,
    },
    air_res = 2,
    earth_res = 2,
    fire_res = 2,
    water_res = 2,
  })
  local cmd = preview_eq(world)
  assert_eq("7a: initial freeze reopen fires", cmd, "cast freeze at foe")
  note_sent(world, "cast freeze at foe")
  cmd = preview_eq(world)
  assert_eq("7b: pending freeze advances to dissonance push instead of repeating freeze", cmd, "embed dissonance")
  note_sent(world, "embed dissonance")
  cmd = preview_eq(world)
  assert_eq("7c: pending dissonance blocks immediate identical resend", cmd, nil)
end

print("\n=== Test 8: loop reset clears route-local state deterministically ===")
do
  local world = make_world({
    aff_scores = {
      waterbonds = 100,
      frozen = 100,
      frostbite = 100,
      clumsiness = 100,
      asthma = 100,
      conflagrate = 100,
    },
    air_res = 2,
    earth_res = 2,
    fire_res = 2,
    water_res = 2,
    dissonance_stage = 4,
  })
  note_sent(world, "cast convergence at foe")
  note_sent(world, "embed dissonance")
  world.MF.alias_loop_on_stopped({ silent = true, reason = "manual" })
  world.MF.alias_loop_on_started({})
  local ex = world.MF.explain()
  local dis = Yso.magi.dissonance.snapshot("foe")
  assert_eq("8a: reset clears last sent command", world.MF.state.last_sent_cmd, "")
  assert_eq("8b: reset clears postconv state", ex.postconv, false)
  assert_eq("8c: reset clears dissonance tracker", dis.stage, 0)
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
