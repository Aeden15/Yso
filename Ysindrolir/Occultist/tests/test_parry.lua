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
local PARRY_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "parry.lua")

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

local function make_world(opts)
  opts = opts or {}

  function cecho() end
  function echo() end
  function send() return true end
  function tempRegexTrigger() return 1 end
  function killTrigger() end
  function registerAnonymousEventHandler() return 1 end
  function killAnonymousEventHandler() end
  function getEpoch() return 1000 end

  _G.target = opts.target or "enemy"
  _G.CurrentCureset = opts.cureset
  _G.gmcp = {
    Char = {
      Vitals = {
        position = opts.position or "standing",
      },
    },
  }
  _G.Legacy = {
    CT = {
      Enemies = opts.enemies or {},
    },
    Curing = {
      Affs = opts.legacy_affs or {},
    },
  }
  _G.affstrack = {
    score = opts.scores or {},
  }
  _G.Yso = {
    toggles = {
      parry = opts.parry_enabled ~= false,
    },
    self = opts.self_state,
    util = {
      now = function() return 1000 end,
    },
  }
  _G.yso = _G.Yso

  dofile(PARRY_PATH)

  local P = Yso.parry
  P.cfg.enabled = true
  P.cfg.threshold = tonumber(opts.threshold or 100) or 100
  P._current = nil
  P._last_sent_limb = ""
  P._last_sent_at = 0
  P._restore = {
    active = false,
    started_at = 0,
    last_cured_leg = "",
  }

  return {
    P = P,
  }
end

print("=== Test 1: restore override returns raw arm score ===")
do
  local world = make_world({
    cureset = "blademaster",
    scores = {
      leftarm = 80,
      rightarm = 140,
      damagedleftleg = 100,
    },
  })
  world.P._restore.active = true
  world.P._restore.started_at = 995
  local limb, score, reason = world.P.evaluate()
  assert_eq("1a: selected arm", limb, "leftarm")
  assert_eq("1b: raw arm score returned", score, 80)
  assert_eq("1c: override reason", reason, "bm_restore_override")
end

print("\n=== Test 2: note_sent accepts mixed-case display names ===")
do
  local world = make_world()
  assert_true("2a: mixed-case display limb accepted", world.P.note_sent("Left Leg"))
  assert_eq("2b: normalized current limb", world.P._current, "leftleg")
  assert_true("2c: full command accepted", world.P.note_sent("Parry Right Arm"))
  assert_eq("2d: normalized command limb", world.P._current, "rightarm")
end

print("\n=== Test 3: secondary limb can still win by score ===")
do
  local world = make_world({
    enemies = { enemy = "Blademaster" },
    scores = {
      leftleg = 120,
      rightleg = 110,
      leftarm = 180,
      rightarm = 90,
    },
  })
  local limb, score, reason = world.P.evaluate()
  assert_eq("3a: highest-score secondary limb chosen", limb, "leftarm")
  assert_eq("3b: chosen score", score, 180)
  assert_eq("3c: standard reason", reason, "standard")
end

print("\n=== Test 4: BM riftlock special case still prefers the higher-damage arm ===")
do
  local world = make_world({
    enemies = { enemy = "Blademaster" },
    scores = {
      leftleg = 250,
      rightleg = 240,
      leftarm = 170,
      rightarm = 150,
    },
  })
  local limb, score, reason = world.P.evaluate()
  assert_eq("4a: riftlock arm selected", limb, "leftarm")
  assert_eq("4b: riftlock score preserved", score, 170)
  assert_eq("4c: standard reason", reason, "standard")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
