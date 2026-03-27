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
local HELPERS_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "occultist", "offense_helpers.lua")

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

local function assert_true(label, got)
  if got ~= true then
    fail(label, string.format("expected true, got %s", tostring(got)))
    return
  end
  pass()
end

local function assert_false(label, got)
  if got ~= false then
    fail(label, string.format("expected false, got %s", tostring(got)))
    return
  end
  pass()
end

local function assert_nil(label, got)
  if got ~= nil then
    fail(label, string.format("expected nil, got %s", tostring(got)))
    return
  end
  pass()
end

local function make_world(opts)
  opts = opts or {}

  local emits = {}
  local shieldbreak_calls = 0

  function cecho() end
  function echo() end
  function send() return true end
  function expandAlias() end

  _G.affstrack = {
    score = opts.aff_scores or {},
  }
  _G.gmcp = {
    Char = {
      Vitals = {
        eq = opts.eq_ready == false and "0" or "1",
        equilibrium = opts.eq_ready == false and "0" or "1",
      },
    },
  }

  _G.Yso = {
    state = {
      eq_ready = function()
        if opts.eq_ready == nil then return true end
        return opts.eq_ready == true
      end,
      ent_ready = function()
        if opts.ent_ready == nil then return true end
        return opts.ent_ready == true
      end,
    },
    get_target = function()
      return opts.target or "foe"
    end,
    target_is_valid = function()
      return opts.target_valid ~= false
    end,
    offense_paused = function()
      return opts.paused == true
    end,
    emit = function(payload, meta)
      emits[#emits + 1] = { payload = payload, meta = meta }
      return true
    end,
    off = {
      oc = {},
      util = {
        maybe_shieldbreak = function(tgt)
          shieldbreak_calls = shieldbreak_calls + 1
          return opts.shieldbreak_cmd
        end,
      },
    },
    occ = {
      truebook = {
        can_utter = function()
          return opts.can_utter == true
        end,
      },
    },
  }
  _G.yso = _G.Yso

  dofile(HELPERS_PATH)

  local Off = Yso.off.oc
  Off.state.enabled = opts.enabled == true
  Off.cfg.use_aeon_module = false
  Off.queue_attend_if_needed = opts.queue_attend_if_needed
  Off.phase = opts.phase_fn
  Off.sg_pick_missing_aff = opts.sg_pick_missing_aff
  Off.sg_entity_cmd_for_aff = opts.sg_entity_cmd_for_aff

  return {
    Off = Off,
    emits = emits,
    shieldbreak_calls = function() return shieldbreak_calls end,
  }
end

print("=== Test 1: no-op paths return false ===")
do
  local disabled = make_world({ enabled = false })
  assert_false("1a: disabled returns false", disabled.Off.tick("manual"))

  local paused = make_world({ enabled = true, paused = true })
  assert_false("1b: paused returns false", paused.Off.tick("manual"))

  local no_target = make_world({ enabled = true, target = "" })
  assert_false("1c: empty target returns false", no_target.Off.tick("manual"))

  local no_payload = make_world({ enabled = true, eq_ready = false, ent_ready = false })
  assert_false("1d: no payload returns false", no_payload.Off.tick("manual"))
end

print("\n=== Test 2: non-shieldbreak tick checks shieldbreak only once ===")
do
  local world = make_world({
    enabled = true,
    eq_ready = true,
    shieldbreak_cmd = nil,
  })
  local ret = world.Off.tick("manual")
  assert_nil("2a: successful emit keeps nil return", ret)
  assert_eq("2b: shieldbreak checked once", world.shieldbreak_calls(), 1)
  assert_eq("2c: one payload emitted", #world.emits, 1)
  assert_eq("2d: normal eq pressure command emitted", world.emits[1].payload.eq, "instill foe with healthleech")
end

print("\n=== Test 3: shieldbreak remains Off.tick authority ===")
do
  local world = make_world({
    enabled = true,
    eq_ready = true,
    shieldbreak_cmd = "command gremlin at foe",
  })
  local ret = world.Off.tick("manual")
  assert_nil("3a: shieldbreak emit keeps nil return", ret)
  assert_eq("3b: shieldbreak checked once", world.shieldbreak_calls(), 1)
  assert_eq("3c: one payload emitted", #world.emits, 1)
  assert_eq("3d: shieldbreak command emitted", world.emits[1].payload.eq, "command gremlin at foe")
  assert_eq("3e: shieldbreak reason", world.emits[1].meta.reason, "shieldbreak")
  assert_eq("3f: shieldbreak emitted solo", world.emits[1].meta.solo, true)
  assert_eq("3g: shieldbreak wake lane", world.emits[1].meta.wake_lane, "eq")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
