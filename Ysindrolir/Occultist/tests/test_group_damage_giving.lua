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
local ROUTE_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "routes", "group_damage.lua")

local pass_count = 0
local fail_count = 0

local function pass()
  pass_count = pass_count + 1
end

local function fail(label, detail)
  fail_count = fail_count + 1
  io.stderr:write(string.format("FAIL: %s%s\n", label, detail and (" - " .. detail) or ""))
end

local function assert_eq(label, got, expected)
  if got ~= expected then
    fail(label, string.format("expected %s, got %s", tostring(expected), tostring(got)))
    return
  end
  pass()
end

local function assert_nil(label, got)
  if got ~= nil and tostring(got) ~= "" then
    fail(label, string.format("expected nil/empty, got %s", tostring(got)))
    return
  end
  pass()
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

local function defaulted_scores(src)
  local row = src or {}
  return setmetatable(row, { __index = function() return 0 end })
end

local function make_world(opts)
  opts = opts or {}
  local now_s = tonumber(opts.now_s or 1000) or 1000
  local current_target = tostring(opts.target or "foe")
  local aff_scores = defaulted_scores(opts.aff_scores)

  install_mudlet_stubs(function() return now_s end)

  _G.Yso = nil
  _G.yso = nil
  _G.target = current_target
  _G.affstrack = { score = aff_scores, score_updated_at = now_s }
  _G.gmcp = {
    Char = {
      Status = { class = "Occultist" },
      Vitals = { eq = "1", bal = "1", balance = "1", equilibrium = "1" },
    },
    Room = { Info = { num = "1001" } },
  }

  _G.Yso = {
    Combat = {
      RouteInterface = {
        ensure_hooks = function() return true end,
      },
    },
    util = {
      now = function() return now_s end,
    },
    off = {
      oc = {
        loyals_active_for = function() return true end,
        entity_registry = {
          slime_should_refresh = function(tgt)
            if type(opts.slime_should_refresh) == "function" then
              local ok, v = pcall(opts.slime_should_refresh, tgt)
              if ok then return v == true end
            end
            if opts.slime_should_refresh == nil then return true end
            return opts.slime_should_refresh == true
          end,
        },
      },
      core = {
        register = function() return true end,
      },
    },
    mode = {
      is_party = function() return true end,
      party_route = function() return "dam" end,
      route_loop_active = function(id) return id == "group_damage" end,
      schedule_route_loop = function() return true end,
      stop_route_loop = function() return true end,
    },
    state = {
      eq_ready = function() return opts.eq_ready ~= false end,
      bal_ready = function() return opts.bal_ready ~= false end,
      ent_ready = function() return opts.ent_ready ~= false end,
    },
    get_target = function()
      return current_target
    end,
    target_is_valid = function(tgt)
      if opts.force_invalid_target == true then return false end
      return tostring(tgt or "") ~= ""
    end,
    offense_paused = function() return false end,
    is_occultist = function() return true end,
    emit = function() return true end,
  }
  _G.yso = _G.Yso

  dofile(ROUTE_PATH)

  local GD = _G.Yso.off.oc.group_damage
  GD.state.enabled = true
  GD.state.loop_enabled = true
  GD.cfg.enabled = true
  GD.init()

  return {
    GD = GD,
    scores = aff_scores,
    set_target = function(who)
      current_target = tostring(who or "")
      _G.target = current_target
    end,
    set_lanes = function(eq_ready, bal_ready, ent_ready)
      opts.eq_ready = eq_ready
      opts.bal_ready = bal_ready
      opts.ent_ready = ent_ready
    end,
  }
end

local function preview(world)
  local payload, why = world.GD.build_payload({})
  return payload, why
end

print("=== Test 1: canonical giving order on EQ lane ===")
do
  local world = make_world({ eq_ready = true, ent_ready = false, bal_ready = true })

  local payload = preview(world)
  assert_eq("1a: first giving aff is paralysis", payload and payload.lanes and payload.lanes.eq or nil, "instill foe with paralysis")

  world.scores.paralysis = 100
  payload = preview(world)
  assert_eq("1b: second giving aff is asthma", payload and payload.lanes and payload.lanes.eq or nil, "instill foe with asthma")

  world.scores.asthma = 100
  payload = preview(world)
  assert_eq("1c: third giving aff is sensitivity", payload and payload.lanes and payload.lanes.eq or nil, "instill foe with sensitivity")

  world.scores.sensitivity = 100
  payload = preview(world)
  assert_eq("1d: fourth giving aff is haemophilia", payload and payload.lanes and payload.lanes.eq or nil, "instill foe with haemophilia")

  world.scores.haemophilia = 100
  payload = preview(world)
  assert_eq("1e: fifth giving aff is healthleech", payload and payload.lanes and payload.lanes.eq or nil, "instill foe with healthleech")
end

print("\n=== Test 2: lane-first emits available lane only ===")
do
  local world = make_world({ eq_ready = false, ent_ready = true, bal_ready = true })
  local payload = preview(world)
  assert_nil("2a: eq lane stays empty when not ready", payload and payload.lanes and payload.lanes.eq or nil)
  assert_eq("2b: entity lane still fires asthma pressure", payload and payload.lanes and payload.lanes.entity or nil, "command bubonis at foe")
end

print("\n=== Test 3: healthleech tracked uses lane-specific damage spam ===")
do
  local world_eq = make_world({
    eq_ready = true, ent_ready = false, bal_ready = true,
    aff_scores = { healthleech = 100 },
  })
  local payload = preview(world_eq)
  assert_eq("3a: eq-ready sends warp immediately", payload and payload.lanes and payload.lanes.eq or nil, "warp foe")
  assert_nil("3b: entity empty when not ready", payload and payload.lanes and payload.lanes.entity or nil)

  local world_ent = make_world({
    eq_ready = false, ent_ready = true, bal_ready = true,
    aff_scores = { healthleech = 100 },
  })
  payload = preview(world_ent)
  assert_nil("3c: eq empty when not ready", payload and payload.lanes and payload.lanes.eq or nil)
  assert_eq("3d: entity-ready sends firelord conversion immediately", payload and payload.lanes and payload.lanes.entity or nil, "command firelord at foe healthleech")

  local world_both = make_world({
    eq_ready = true, ent_ready = true, bal_ready = true,
    aff_scores = { healthleech = 100 },
  })
  payload = preview(world_both)
  assert_eq("3e: both-ready includes warp", payload and payload.lanes and payload.lanes.eq or nil, "warp foe")
  assert_eq("3f: both-ready includes firelord", payload and payload.lanes and payload.lanes.entity or nil, "command firelord at foe healthleech")
end

print("\n=== Test 4: justice is opportunistic-only ===")
do
  local world_with_pressure = make_world({
    eq_ready = true, ent_ready = false, bal_ready = true,
    aff_scores = { paralysis = 100, asthma = 100 },
  })
  local payload = preview(world_with_pressure)
  assert_eq("4a: giving pressure still selected on EQ", payload and payload.lanes and payload.lanes.eq or nil, "instill foe with sensitivity")
  assert_nil("4b: justice does not preempt pressure", payload and payload.lanes and payload.lanes.bal or nil)

  local world_filler = make_world({
    eq_ready = false, ent_ready = false, bal_ready = true,
    aff_scores = { paralysis = 100, asthma = 100 },
  })
  payload = preview(world_filler)
  assert_eq("4c: justice can fill bal lane opportunistically", payload and payload.lanes and payload.lanes.bal or nil, "ruinate justice foe")
end

print("\n=== Test 5: stop conditions still report correctly ===")
do
  local world_no_target = make_world({ target = "" })
  local payload, why = preview(world_no_target)
  assert_eq("5a: no target returns no_target", why, "no_target")
  assert_nil("5b: no target yields no payload", payload)

  local world_invalid = make_world({ force_invalid_target = true })
  payload, why = preview(world_invalid)
  assert_eq("5c: invalid target returns invalid_target", why, "invalid_target")
  assert_nil("5d: invalid target yields no payload", payload)
end

print("\n=== Test 6: slime paralysis is asthma-gated with EQ fallback ===")
do
  local world = make_world({
    eq_ready = true, ent_ready = true, bal_ready = true,
    aff_scores = { asthma = 0, paralysis = 0 },
  })
  local payload = preview(world)
  assert_eq("6a: eq still gives paralysis when asthma absent", payload and payload.lanes and payload.lanes.eq or nil, "instill foe with paralysis")
  assert_eq("6b: entity does not attempt slime when asthma absent", payload and payload.lanes and payload.lanes.entity or nil, "command bubonis at foe")
end

print("\n=== Test 7: slime recast obeys refresh gate ===")
do
  local active_world = make_world({
    eq_ready = false, ent_ready = true, bal_ready = true,
    slime_should_refresh = false,
    aff_scores = { asthma = 100, paralysis = 0 },
  })
  local payload = preview(active_world)
  assert_eq("7a: active slime window suppresses slime recast", payload and payload.lanes and payload.lanes.entity or nil, "command worm at foe")

  local refresh_world = make_world({
    eq_ready = false, ent_ready = true, bal_ready = true,
    slime_should_refresh = true,
    aff_scores = { asthma = 100, paralysis = 0 },
  })
  payload = preview(refresh_world)
  assert_eq("7b: refresh/end window allows slime recast", payload and payload.lanes and payload.lanes.entity or nil, "command slime at foe")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
