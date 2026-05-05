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
local ROUTE_PATH = join_path(SCRIPT_DIR, "..", "..", "Magi", "magi_group_damage.lua")
local API_PATH = join_path(SCRIPT_DIR, "..", "Core", "api.lua")
local QUEUE_PATH = join_path(SCRIPT_DIR, "..", "Core", "queue.lua")

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

local function defaulted_scores(src)
  local row = src or {}
  return setmetatable(row, { __index = function() return 0 end })
end

local function install_mudlet_stubs(now_ref, dry_lines)
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
  _G.cecho = function(msg)
    msg = tostring(msg or "")
    if dry_lines and msg:find("[Yso.queue:DRY]", 1, true) then
      dry_lines[#dry_lines + 1] = msg
    end
  end
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
  local dry_lines = {}
  local aff_scores = defaulted_scores(opts.aff_scores)
  local resonance = {
    water = tonumber(opts.water_res or 0) or 0,
    fire = tonumber(opts.fire_res or 0) or 0,
  }

  install_mudlet_stubs(function() return now_s end, dry_lines)

  _G.Yso = nil
  _G.yso = nil
  _G.affstrack = { score = aff_scores }
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
    util = {
      now = function() return now_s end,
    },
    state = {
      eq_ready = function() return opts.eq_ready ~= false end,
    },
    mode = {
      is_combat = function() return true end,
      route_loop_active = function(id) return id == "magi_group_damage" end,
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
    magi = {
      resonance = {
        state = resonance,
        sync_from_ak = function() return true end,
        get = function(element)
          return resonance[tostring(element or ""):lower()] or 0
        end,
      },
    },
    queue = {
      clear = function() return true end,
    },
  }
  _G.yso = _G.Yso

  if opts.emit_mode == "queue" then
    Yso.net = { cfg = { dry_run = true } }
    dofile(API_PATH)
    Yso.state.eq_ready = function() return opts.eq_ready ~= false end
    Yso.mode.is_combat = function() return true end
    Yso.mode.route_loop_active = function(id) return id == "magi_group_damage" end
    Yso.mode.schedule_route_loop = function() return true end
    Yso.mode.stop_route_loop = function() return true end
    Yso.get_target = function() return current_target end
    Yso.target_is_valid = function(who) return tostring(who or "") ~= "" end
    Yso.offense_paused = function() return false end
    Yso.magi = Yso.magi or {}
    Yso.magi.resonance = {
      state = resonance,
      sync_from_ak = function() return true end,
      get = function(element)
        return resonance[tostring(element or ""):lower()] or 0
      end,
    }
    dofile(QUEUE_PATH)
    Yso.net.cfg.dry_run = true
  else
    Yso.emit = function(payload)
      emits[#emits + 1] = payload
      return true
    end
  end

  dofile(ROUTE_CORE_PATH)
  dofile(ROUTE_PATH)

  local MGD = Yso.off.magi.group_damage
  MGD.state.enabled = true
  MGD.state.loop_enabled = true
  MGD.cfg.enabled = true
  MGD.init()

  return {
    MGD = MGD,
    emits = emits,
    dry_lines = dry_lines,
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
    advance = function(dt)
      now_s = now_s + (tonumber(dt) or 0)
    end,
  }
end

local function preview_eq(world)
  local payload, why = world.MGD.build_payload({})
  if not payload then return nil, why end
  local lanes = type(payload.lanes) == "table" and payload.lanes or {}
  local meta = type(payload.meta) == "table" and payload.meta or {}
  return lanes.eq, meta.main_reason
end

local function note_sent(world, cmd)
  world.MGD.on_payload_sent({ eq = cmd })
end

print("=== Test 1: opener and freeze reset ===")
do
  local world = make_world({
    aff_scores = {
      frozen = 100,
      frostbite = 100,
      slickness = 100,
      disrupt = 100,
    },
  })
  local cmd = preview_eq(world)
  assert_eq("1a: missing waterbonds opens with horripilation", cmd, "staff cast horripilation foe")

  world.scores.waterbonds = 100
  cmd = preview_eq(world)
  assert_eq("1b: fresh target still forces freeze step", cmd, "cast freeze at foe")
end

print("\n=== Test 2: water branch still sets up water disrupt before fire ===")
do
  local world = make_world({
    aff_scores = {
      waterbonds = 100,
      frozen = 100,
      slickness = 100,
    },
    water_res = 3,
  })
  note_sent(world, "cast freeze at foe")
  local cmd = preview_eq(world)
  assert_eq("2a: water emanation remains legal mixed pressure", cmd, "cast emanation at foe water")
end

print("\n=== Test 3: fire branch builder ordering ===")
do
  local world = make_world({
    aff_scores = {
      waterbonds = 100,
      frostbite = 100,
    },
  })
  note_sent(world, "cast freeze at foe")
  local cmd = preview_eq(world)
  assert_eq("3a: missing scalded prefers magma", cmd, "cast magma at foe")

  world.scores.scalded = 100
  cmd = preview_eq(world)
  assert_eq("3b: firelash is the next builder once scalded exists", cmd, "cast firelash at foe")
end

print("\n=== Test 4: conflagrate legality gate ===")
do
  local world = make_world({
    aff_scores = {
      waterbonds = 100,
      frostbite = 100,
      scalded = 100,
      aflame = 100,
    },
  })
  note_sent(world, "cast freeze at foe")
  local cmd = preview_eq(world)
  assert_eq("4a: below aflame threshold stays on firelash", cmd, "cast firelash at foe")

  world.scores.aflame = 200
  cmd = preview_eq(world)
  assert_eq("4b: aflame threshold enables conflagrate", cmd, "cast conflagrate at foe")
end

print("\n=== Test 5: fire emanation promotion beats magma ===")
do
  local world = make_world({
    aff_scores = {
      waterbonds = 100,
      frostbite = 100,
      conflagrate = 100,
      aflame = 200,
    },
    fire_res = 3,
  })
  note_sent(world, "cast freeze at foe")
  local cmd = preview_eq(world)
  assert_eq("5a: active conflagrate plus major fire promotes fire emanation", cmd, "cast emanation at foe fire")
end

print("\n=== Test 6: target switch resets freeze-step progress ===")
do
  local world = make_world({
    aff_scores = {
      waterbonds = 100,
      frozen = 100,
      slickness = 100,
      disrupt = 100,
      scalded = 100,
    },
  })
  note_sent(world, "cast freeze at foe")
  world.set_target("foe2")
  world.MGD.on_target_swap("foe", "foe2")
  local cmd = preview_eq(world)
  assert_eq("6a: target switch forces freeze baseline again", cmd, "cast freeze at foe2")
end

print("\n=== Test 7: anti-repeat blocks immediate identical opener resend ===")
do
  local world = make_world({})
  note_sent(world, "staff cast horripilation foe")
  local cmd = preview_eq(world)
  assert_eq("7a: opener is not resent while pending", cmd, "cast freeze at foe")
  world.advance(1.2)
  cmd = preview_eq(world)
  assert_eq("7b: opener returns once the pending window expires without waterbonds", cmd, "staff cast horripilation foe")
end

print("\n=== Test 8: live queue acknowledgement advances route state ===")
do
  local world = make_world({ emit_mode = "queue" })

  local ok, cmd = world.MGD.attack_function({})
  assert_eq("8a: first queue-backed attack succeeds", ok, true)
  assert_eq("8b: first live emit is horripilation", cmd, "staff cast horripilation foe")
  assert_eq("8c: queue ack updates last_sent_cmd", world.MGD.state.last_sent_cmd, "staff cast horripilation foe")
  assert_eq("8d: queue ack marks opener pending target", world.MGD.state.pending.horripilation.target, "foe")
  assert_eq("8e: queue ack advances branch stage", world.MGD.explain().branch_stage, "opener_setup")

  world.scores.waterbonds = 100
  world.advance(0.5)
  ok, cmd = world.MGD.attack_function({})
  assert_eq("8f: second queue-backed attack succeeds", ok, true)
  assert_eq("8g: second live emit advances to freeze", cmd, "cast freeze at foe")
  assert_eq("8h: queue ack updates last_sent_cmd again", world.MGD.state.last_sent_cmd, "cast freeze at foe")
  assert_eq("8i: queue ack records freeze setup", world.MGD.explain().branch_stage, "freeze_setup")
  assert_eq("8j: queue ack marks freeze step done", world.MGD.explain().freeze_step_done, true)
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end

