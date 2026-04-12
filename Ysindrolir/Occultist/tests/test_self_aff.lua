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
local _queue_blocks = {}
local _queue_unblocks = {}
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
  is_actively_fighting = function() return false end,
  mode = {
    is_combat = function() return false end,
    is_party = function() return false end,
    active_route_id = function() return "" end,
    auto = { state = { combat_until = 0 } },
  },
  curing = {
    policy = {
      state = { aggression_until = 0 },
    },
  },
  queue = {
    block_lane = function(lane, reason)
      _queue_blocks[#_queue_blocks + 1] = {
        lane = tostring(lane or ""),
        reason = tostring(reason or ""),
      }
      return true
    end,
    unblock_lane = function(lane, reason)
      _queue_unblocks[#_queue_unblocks + 1] = {
        lane = tostring(lane or ""),
        reason = tostring(reason or ""),
      }
      return true
    end,
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
assert_eq("1e: roped alias canonicalizes to bound", SA.normalize("roped"), "bound")

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
assert_true(
  "4c2: hardblock bound bypasses stale guard",
  SA.ingest_text_gain("bound", { source = "text.hardblock.bound", force = true })
)
assert_true("4c3: bound active from hardblock text", SA.has_aff("bound"))
advance(2)
assert_true("4d: text accepted once gmcp is stale", SA.ingest_text_gain("asthma"))
assert_true("4e: asthma active", SA.has_aff("asthma"))
SA.cfg.gmcp_list_barrier_ms = 400
SA.cfg.text_stale_guard_s = 0
advance(1)
SA.sync_full({ "paralysis" }, "gmcp.full")
advance(0.25)
assert_false("4f: text still blocked inside ms barrier", SA.ingest_text_gain("asthma"))
advance(0.20)
assert_true("4g: text allowed once ms barrier expires", SA.ingest_text_gain("asthma"))
SA.cfg.gmcp_list_barrier_ms = nil
SA.cfg.text_stale_guard_s = 1.25

print("\n=== Test 5: reset gating in combat context ===")
_G.Yso.curing.policy.state.aggression_until = _clock + 5
local ok_reset, why_reset = SA.reset("test")
assert_false("5a: reset blocked while combat active", ok_reset)
assert_eq("5b: reset reason", why_reset, "combat_active")
assert_true("5c: forced reset allowed", SA.reset("test", { force = true }))
_G.Yso.curing.policy.state.aggression_until = 0
_G.Yso.mode.is_combat = function() return true end
_G.Yso.mode.active_route_id = function() return "" end
assert_true("5d: reset allowed when only mode=combat and no active route", SA.reset("test"))
_G.Yso.is_actively_fighting = function() return true end
local ok_fight, why_fight = SA.reset("test")
assert_false("5e: reset blocked while actively fighting", ok_fight)
assert_eq("5f: active-fight reason", why_fight, "combat_active")
_G.Yso.is_actively_fighting = function() return false end
_G.Yso.mode.is_combat = function() return false end

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
assert_true("8d: list_writhe_affs reports webbed", table.concat(Yso.self.list_writhe_affs(), ",") == "webbed")
Yso.self.gain("roped", "manual")
assert_true("8e: roped gain marks canonical bound writhe aff", Yso.self.has_aff("bound"))
assert_true("8f: expanded writhe-family helper recognizes pinned", Yso.self.is_writhe_aff("pinned"))

print("\n=== Test 9: writhe-family lane block/unblock hooks ===")
local saw_eq_block = false
local saw_bal_block = false
for i = 1, #_queue_blocks do
  local row = _queue_blocks[i]
  if row.lane == "eq" then saw_eq_block = true end
  if row.lane == "bal" then saw_bal_block = true end
end
assert_true("9a: eq lane blocked on writhe gain", saw_eq_block)
assert_true("9b: bal lane blocked on writhe gain", saw_bal_block)
Yso.self.cure("webbed", "manual")
Yso.self.cure("bound", "manual")
local saw_eq_unblock = false
local saw_bal_unblock = false
for i = 1, #_queue_unblocks do
  local row = _queue_unblocks[i]
  if row.lane == "eq" then saw_eq_unblock = true end
  if row.lane == "bal" then saw_bal_unblock = true end
end
assert_true("9c: eq lane unblocked on writhe clear", saw_eq_unblock)
assert_true("9d: bal lane unblocked on writhe clear", saw_bal_unblock)

print("\n=== Test 10: arms-unusable hardblock guard + gmcp remove ===")
Yso.self.reset("test", { force = true })
local blocks_before = #_queue_blocks
Yso.self.gain("damagedleftarm", "manual")
local ok_guarded, why_guarded = SA.ingest_text_arms_unusable({ source = "text.hardblock.bound" })
assert_false("10a: hardblock ignored when arm damage active", ok_guarded == true)
assert_eq("10b: guard reason", why_guarded, "arm_damage_active")
assert_false("10c: bound not force-gained with damaged arm", Yso.self.has_aff("bound"))
assert_eq("10d: no new lane block when guard fires", #_queue_blocks, blocks_before)

Yso.self.cure("damagedleftarm", "manual")
local ok_bound = SA.ingest_text_arms_unusable({ source = "text.hardblock.bound" })
assert_true("10e: hardblock force-gains bound when no arm damage", ok_bound == true)
assert_true("10f: bound active after hardblock ingest", Yso.self.has_aff("bound"))

local unblocks_before = #_queue_unblocks
_G.gmcp.Char.Afflictions.Remove = { name = "bound" }
assert_true("10g: gmcp remove ingests", SA.ingest_gmcp_remove())
assert_false("10h: bound cured by gmcp remove", Yso.self.has_aff("bound"))
assert_true("10i: gmcp remove releases writhe lane block", #_queue_unblocks > unblocks_before)

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
