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
local POLICY_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Curing", "serverside_policy.lua")

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

local _clock = 5000
local function now() return _clock end
local function advance(dt) _clock = _clock + (tonumber(dt) or 0) end

local _send_lines = {}
local _profile_calls = {}
local _prio_calls = {}
local _tree_calls = {}
local _queue_calls = {}
local _event_calls = {}

local function clear_calls()
  _send_lines = {}
  _profile_calls = {}
  _prio_calls = {}
  _tree_calls = {}
  _queue_calls = {}
  _event_calls = {}
end

function getEpoch() return _clock end
function cecho() end
function echo() end
function send(cmd)
  _send_lines[#_send_lines + 1] = cmd
end
function tempRegexTrigger() return 1 end
function killTrigger() end
function registerAnonymousEventHandler() return 1 end
function killAnonymousEventHandler() end
function raiseEvent(name, ...)
  _event_calls[#_event_calls + 1] = { name = name, args = { ... } }
end

_G.target = "enemy"
_G.enClass = ""
_G.CurrentCureset = ""

_G.Legacy = {
  CT = {
    Enemies = {},
    timers = {},
  },
  Curing = {
    ActiveServerSet = "",
    Prios = {
      baseSets = {
        default = {
          paralysis = 3,
          asthma = 6,
          slickness = 8,
        },
      },
    },
  },
}

_G.Yso = {
  util = {
    now = now,
  },
  selfaff = {
    normalize = function(v)
      v = tostring(v or ""):lower()
      v = v:gsub("[%.,;:!%?]+$", "")
      v = v:gsub("[_%-]+", " ")
      v = v:gsub("%s+", "")
      return v
    end,
  },
  mode = {
    auto = { state = { combat_until = 0 } },
    is_hunt = function() return false end,
  },
  get_target = function() return "enemy" end,
  curing = {
    adapters = {
      use_profile = function(name)
        _profile_calls[#_profile_calls + 1] = tostring(name or "")
        _G.CurrentCureset = tostring(name or "")
      end,
      set_aff_prio = function(aff, prio)
        _prio_calls[#_prio_calls + 1] = { aff = tostring(aff or ""), prio = tonumber(prio) or 0 }
      end,
      set_tree_policy = function(mode)
        _tree_calls[#_tree_calls + 1] = tostring(mode or "")
      end,
      queue_emergency = function(cmd, opts)
        _queue_calls[#_queue_calls + 1] = {
          cmd = tostring(cmd or ""),
          qtype = tostring((opts and opts.qtype) or ""),
          index = tonumber(opts and opts.index),
        }
        return true
      end,
    },
  },
}
_G.yso = _G.Yso

dofile(POLICY_PATH)
local P = Yso.curing.policy

print("=== Test 1: startup resync emits baseline probes ===")
assert_true("1a: profile switched to default", _profile_calls[1] == "default")
local saw_list = false
for i = 1, #_send_lines do
  if _send_lines[i] == "curing priority list" then
    saw_list = true
    break
  end
end
assert_true("1b: priority list requested", saw_list)

print("\n=== Test 2: blademaster overlay applies in aggression ===")
clear_calls()
Legacy.CT.Enemies.enemy = "Blademaster"
P.note_hostile_hit("attacker1", "unit")
local _, reason_overlay = P.tick("unit.overlay", true)
assert_eq("2a: mode", P.state.mode, "class_overlay")
assert_eq("2b: overlay", P.state.active_overlay, "blademaster")
assert_true("2c: priorities applied", #_prio_calls > 0)
assert_eq("2d: tick reason", reason_overlay, "applied")
local prio_count = #_prio_calls
P.tick("unit.overlay.stable", true)
assert_eq("2e: delta-only no repeat prios", #_prio_calls, prio_count)

print("\n=== Test 3: manual grace suppresses writes for 8s ===")
clear_calls()
advance(1.0)
assert_true("3z: manual intervention accepted", P.note_manual_intervention("unit.manual"))
local _, reason_manual = P.tick("unit.manual.tick", true)
assert_eq("3a: manual grace reason", reason_manual, "manual_grace")
assert_eq("3b: no prio writes", #_prio_calls, 0)
assert_eq("3c: no profile writes", #_profile_calls, 0)
advance(8.1)
local _, reason_post_grace = P.tick("unit.manual.expired", true)
assert_false("3d: grace expired", reason_post_grace == "manual_grace")

print("\n=== Test 4: group override takes precedence over overlay ===")
clear_calls()
P.set_group_override(true, "unit.group")
assert_eq("4a: mode is group", P.state.mode, "group")
assert_true("4b: group active", P.state.group_active == true)
assert_eq("4c: overlay suspended", P.state.active_overlay, nil)
assert_true("4d: switched to group set", _profile_calls[#_profile_calls] == "group")

print("\n=== Test 5: clearing group restores default then re-evaluates overlay ===")
clear_calls()
P.set_group_override(nil, "unit.group.clear")
local saw_default = false
for i = 1, #_profile_calls do
  if _profile_calls[i] == "default" then
    saw_default = true
    break
  end
end
assert_true("5a: restores default first", saw_default)

print("\n=== Test 6: aggression timeout clears overlay and returns default mode ===")
clear_calls()
P.state.aggression_until = now() - 1
P.state.last_hostile_at = now() - 999
Legacy.CT.Enemies.enemy = ""
P.tick("unit.calm", true)
assert_eq("6a: default mode", P.state.mode, "default")
assert_eq("6b: no overlay", P.state.active_overlay, nil)

print("\n=== Test 7: emergency queue dedupe + manual grace guard ===")
clear_calls()
local ok1, why1 = P.queue_emergency("touch tree", { qtype = "bal" })
assert_true("7a: first emergency accepted", ok1 == true and why1 == nil)
assert_eq("7b: one queue call", #_queue_calls, 1)
local ok2, why2 = P.queue_emergency("touch tree", { qtype = "bal" })
assert_false("7c: duplicate denied", ok2)
assert_eq("7d: duplicate reason", why2, "dedupe")
advance(1.0)
assert_true("7z: manual intervention accepted", P.note_manual_intervention("unit.manual.queue"))
local ok3, why3 = P.queue_emergency("touch tree", { qtype = "bal" })
assert_false("7e: blocked during manual grace", ok3)
assert_eq("7f: manual grace reason", why3, "manual_grace")
advance(8.1)

print("\n=== Test 8: conservative group hysteresis enter/hold/exit ===")
clear_calls()
P.set_group_override(nil, "unit.hysteresis.clear")
P.state.group_active = false
P.state.group_since = 0
P.state.last_hostile_at = 0
P.state.hit_log = {}
P.state.attacker_seen = {}
Legacy.CT.timers = {}
_G.enClass = ""

for i = 1, 8 do
  P.note_hostile_hit("att" .. tostring((i % 3) + 1), "unit.hits")
end
P.tick("unit.hits.enter", true)
assert_true("8a: group entered", P.state.group_active == true)

advance(5)
P.state.hit_log = {}
P.tick("unit.hits.hold", true)
assert_true("8b: holds during min dwell", P.state.group_active == true)

advance(20)
P.state.hit_log = {}
P.state.last_hostile_at = now() - 20
P.tick("unit.hits.exit", true)
assert_false("8c: group exits after calm window", P.state.group_active == true)

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
