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
local SELF_AFF_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Core", "self_aff.lua")

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

local function assert_true(label, value)
  assert_eq(label, value, true)
end

local function assert_false(label, value)
  assert_eq(label, value, false)
end

local _clock = 1000
local function advance(dt)
  _clock = _clock + (tonumber(dt) or 0)
end

function getEpoch() return _clock end
function cecho() end
function echo() end
function tempRegexTrigger() return 1 end
function killTrigger() end
function registerAnonymousEventHandler() return 1 end
function killAnonymousEventHandler() end

local _events = {}
function raiseEvent(name, ...)
  _events[#_events + 1] = { name = name, args = { ... } }
end

_G.gmcp = {
  Char = {
    Afflictions = {},
    Vitals = {},
  },
}

_G.Yso = {
  util = {
    now = function() return _clock end,
  },
  mode = {
    is_combat = function() return false end,
    auto = { state = { combat_until = 0 } },
  },
  curing = {
    policy = {
      state = { aggression_until = 0 },
    },
  },
}
_G.yso = _G.Yso

dofile(SELF_AFF_PATH)

local SA = Yso.selfaff

print("=== Test 1: normalization and aliases ===")
assert_eq("1a: Blindness -> blind", SA.normalize("Blindness."), "blind")
assert_eq("1b: mana-leech -> manaleech", SA.normalize("mana-leech"), "manaleech")
assert_eq("1c: sleeping -> sleep", SA.normalize("sleeping"), "sleep")
assert_eq("1d: underscores collapse", SA.normalize("health_leech"), "healthleech")

print("\n=== Test 2: gain/cure row timestamps and source ===")
SA.reset("test")
advance(1)
assert_true("2a: gain asthma", SA.gain("asthma", "manual"))
local r1 = SA.affs.asthma
assert_true("2b: row active", r1 and r1.active == true)
assert_eq("2c: first_seen stamp", r1 and r1.first_seen, 1001)
assert_eq("2d: last_seen stamp", r1 and r1.last_seen, 1001)
assert_eq("2e: source stamp", r1 and r1.source, "manual")
advance(2)
assert_true("2f: cure asthma", SA.cure("asthma", "manual"))
local r2 = SA.affs.asthma
assert_false("2g: row inactive", r2 and r2.active == true)
assert_eq("2h: last_cured stamp", r2 and r2.last_cured, 1003)
advance(1)
assert_true("2i: re-gain asthma", SA.gain("asthma", "manual"))
local r3 = SA.affs.asthma
assert_eq("2j: first_seen resets on fresh gain", r3 and r3.first_seen, 1004)

print("\n=== Test 3: full sync and compatibility mirror ===")
advance(1)
SA.sync_full({ "paralysis", { name = "asthma" } }, "gmcp.full")
assert_true("3a: paralysis active", SA.has_aff("paralysis"))
assert_true("3b: asthma active", SA.has_aff("asthma"))
assert_eq("3c: active count", SA.aff_count(), 2)
assert_true("3d: compatibility mirror asthma", Yso.affs.asthma == true)
assert_true("3e: list sorted", table.concat(SA.list_affs(), ",") == "asthma,paralysis")

print("\n=== Test 4: GMCP precedence over text fallback ===")
advance(1)
SA.sync_full({ "paralysis" }, "gmcp.full")
assert_false("4a: asthma removed by full sync", SA.has_aff("asthma"))
assert_false("4b: text blocked immediately after gmcp", SA.ingest_text_gain("asthma"))
assert_false("4c: still no asthma", SA.has_aff("asthma"))
advance(2)
assert_true("4d: text accepted once gmcp is stale", SA.ingest_text_gain("asthma"))
assert_true("4e: asthma active", SA.has_aff("asthma"))

print("\n=== Test 5: reset gating in combat context ===")
_G.Yso.curing.policy.state.aggression_until = _clock + 5
local ok_reset, why_reset = SA.reset("test")
assert_false("5a: reset blocked while combat active", ok_reset)
assert_eq("5b: reset reason", why_reset, "combat_active")
assert_true("5c: forced reset allowed", SA.reset("test", { force = true }))
_G.Yso.curing.policy.state.aggression_until = 0

print("\n=== Test 6: broader self state helpers ===")
_G.gmcp.Char.Vitals = { position = "prone", bleeding = "23" }
SA.ingest_gmcp_vitals()
assert_true("6a: prone from vitals", SA.is_prone())
assert_eq("6b: bleeding numeric", SA.bleeding(), 23)
_G.gmcp.Char.Vitals = { position = "standing", bleeding = "0" }
SA.ingest_gmcp_vitals()
assert_false("6c: prone cleared from standing", SA.is_prone())
assert_eq("6d: bleeding clear", SA.bleeding(), 0)

print("\n=== Test 7: compat mirror writes route to tracker ===")
Yso.self.reset("test", { force = true })
Yso.affs.paralysis = true
assert_true("7a: compat write gain", Yso.self.has_aff("paralysis"))
Yso.affs.paralysis = nil
assert_false("7b: compat write cure", Yso.self.has_aff("paralysis"))

print("\n=== Test 8: public Yso.self write/query wrappers ===")
Yso.self.reset("test")
Yso.self.gain("blackout", "manual")
assert_true("8a: wrapper has_aff", Yso.self.has_aff("blackout"))
Yso.self.cure("blackout", "manual")
assert_false("8b: wrapper cure", Yso.self.has_aff("blackout"))
Yso.self.sync_full({ "webbed" }, "manual")
assert_true("8c: wrapper sync_full", Yso.self.is_writhed())

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
