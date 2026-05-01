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
local QUEUE_PATH = join_path(SCRIPT_DIR, "..", "Core", "queue.lua")

local pass_count = 0
local fail_count = 0

local function pass()
  pass_count = pass_count + 1
end

local function fail(label, detail)
  fail_count = fail_count + 1
  io.stderr:write(string.format("FAIL: %s%s\n", label, detail and (" - " .. detail) or ""))
end

local function assert_true(label, value)
  if value ~= true then
    fail(label, string.format("expected true, got %s", tostring(value)))
    return
  end
  pass()
end

local function assert_false(label, value)
  if value ~= false then
    fail(label, string.format("expected false, got %s", tostring(value)))
    return
  end
  pass()
end

local function assert_eq(label, got, expected)
  if got ~= expected then
    fail(label, string.format("expected %s, got %s", tostring(expected), tostring(got)))
    return
  end
  pass()
end

local _clock = 9000
local function now() return _clock end

local _send_lines = {}
function send(cmd)
  _send_lines[#_send_lines + 1] = tostring(cmd or "")
end
function getEpoch() return _clock end
function cecho() end
function echo() end

_G.Yso = {
  util = { now = now },
  cfg = { cmd_sep = "&&", pipe_sep = "&&" },
  net = { cfg = { dry_run = false } },
  state = {
    eq_ready = function() return true end,
    bal_ready = function() return true end,
    ent_ready = function() return true end,
  },
}
_G.yso = _G.Yso

dofile(QUEUE_PATH)
local Q = Yso.queue

print("=== Test 0: alchemist wrack commands infer BAL lane ===")
assert_true("0a: wrack inferred as bal", Q.stage("wrack Bob paralysis"))
assert_eq("0b: wrack staged on bal", Q.list("bal"), "wrack Bob paralysis")
Q.clear("bal")
assert_true("0c: truewrack inferred as bal", Q.stage("truewrack Bob sanguine paralysis"))
assert_eq("0d: truewrack staged on bal", Q.list("bal"), "truewrack Bob sanguine paralysis")
Q.clear("bal")
assert_true("0e: educe iron remains eq", Q.stage("educe iron Bob"))
assert_eq("0f: educe iron staged on eq", Q.list("eq"), "educe iron Bob")
Q.clear("eq")

print("=== Test 1: install EQ lane command ===")
assert_true("1a: stage eq command", Q.stage("eq", "instill target with asthma"))
local ok_commit_1 = Q.commit({ allow_eqbal = true })
assert_true("1b: commit queued eq", ok_commit_1 == true)
assert_true("1c: eq ownership recorded", type(Q.get_owned("eq")) == "table")

print("\n=== Test 2: writhe lane block clears stale queue ownership ===")
local blocked, why_block = Q.block_lane("eq", "webbed", {
  source = "unit:writhe",
  clear_owned = true,
  clear_staged = true,
})
assert_true("2a: block_lane accepted", blocked == true and (why_block == "blocked" or why_block == "unchanged"))
local lane_blocked, lane_reason = Q.lane_blocked("eq")
assert_true("2b: lane marked blocked", lane_blocked == true)
assert_eq("2c: lane reason", lane_reason, "webbed")
assert_eq("2d: owned eq cleared", Q.get_owned("eq"), nil)
assert_eq("2e: staged eq cleared", Q.list("eq"), nil)

local saw_clearqueue = false
for i = 1, #_send_lines do
  if _send_lines[i] == "CLEARQUEUE e!p!w!t" then
    saw_clearqueue = true
    break
  end
end
assert_true("2f: clearqueue sent for blocked lane", saw_clearqueue)

print("\n=== Test 3: blocked lane does not keep stale command armed ===")
local before_send_count = #_send_lines
local ok_stage_blocked = Q.stage("eq", "instill target with slickness")
assert_false("3a: stage rejected while blocked", ok_stage_blocked == true)
local ok_commit_blocked = Q.commit({ allow_eqbal = true })
assert_false("3b: commit no-op while blocked", ok_commit_blocked == true)
assert_eq("3c: no new queue send while blocked", #_send_lines, before_send_count)

print("\n=== Test 4: send-time lane recheck catches mid-cycle block ===")
assert_true("4a: unblock lane for race sim", Q.unblock_lane("eq", "writhe_clear"))
assert_true("4b: stage eq command for race sim", Q.stage("eq", "instill target with clumsiness"))
local original_lane_blocked = Q.lane_blocked
local lane_blocked_calls = 0
Q.lane_blocked = function(lane)
  lane_blocked_calls = lane_blocked_calls + 1
  if tostring(lane or "") == "eq" and lane_blocked_calls >= 2 then
    return true, "webbed"
  end
  return false, ""
end
local before_race_send = #_send_lines
local ok_commit_race = Q.commit({ allow_eqbal = true })
Q.lane_blocked = original_lane_blocked
assert_false("4c: commit suppressed when lane blocks mid-cycle", ok_commit_race == true)
assert_eq("4d: no queue send for blocked race payload", #_send_lines, before_race_send)

print("\n=== Test 5: final pre-send lane recheck blocks late race ===")
assert_true("5a: lane unblock stable", Q.unblock_lane("eq", "writhe_clear"))
assert_true("5b: stage eq command for final recheck", Q.stage("eq", "instill target with dizziness"))
local original_lane_blocked_2 = Q.lane_blocked
local lane_blocked_calls_2 = 0
Q.lane_blocked = function(lane)
  if tostring(lane or "") == "eq" then
    lane_blocked_calls_2 = lane_blocked_calls_2 + 1
    if lane_blocked_calls_2 >= 3 then
      return true, "webbed"
    end
  end
  return false, ""
end
local before_race_send_2 = #_send_lines
local ok_commit_race_2 = Q.commit({ allow_eqbal = true })
Q.lane_blocked = original_lane_blocked_2
assert_false("5c: final pre-send recheck suppresses leak", ok_commit_race_2 == true)
assert_eq("5d: no queue send after late lane block", #_send_lines, before_race_send_2)

print("\n=== Test 6: unblock rebuilds from fresh payload ===")
assert_true("6a: lane unblock stable", Q.unblock_lane("eq", "writhe_clear"))
assert_true("6b: stage fresh eq command", Q.stage("eq", "instill target with slickness"))
local ok_commit_2 = Q.commit({ allow_eqbal = true })
assert_true("6c: commit fresh eq command", ok_commit_2 == true)
local last_line = _send_lines[#_send_lines] or ""
assert_true("6d: last queue send is refreshed command", last_line:find("slickness", 1, true) ~= nil)

print("\n=== Test 7: addclearfull execute bypasses dedupe and clears other ownership ===")
if type(Q.clear_lane_dispatched) == "function" then Q.clear_lane_dispatched("eq", "unit:clearfull") end
assert_true("7a: stage same destroy command", Q.stage("eq", "cast destroy at target"))
Q.set_owned("eq", {
  cmd = "cast destroy at target",
  fingerprint = Q.fingerprint("cast destroy at target", { route = "magi_dmg", target = "target" }),
  route = "magi_dmg",
  target = "target",
})
Q.set_owned("class", {
  cmd = "temper target sanguine",
  fingerprint = Q.fingerprint("temper target sanguine", { route = "alchemist_duel_route", target = "target" }),
  route = "alchemist_duel_route",
  target = "target",
})
assert_true("7b: stage sidecar class command", Q.stage("class", "temper target sanguine"))
local before_clearfull = #_send_lines
local ok_clearfull = Q.commit({
  route = "magi_dmg",
  target = "target",
  allow_eqbal = true,
  queue_verb = "addclearfull",
  clearfull_lane = "eq",
})
assert_true("7c: clearfull commit succeeds despite same command", ok_clearfull == true)
assert_eq("7d: clearfull sent exact queue command", _send_lines[#_send_lines], "QUEUE ADDCLEARFULL e!p!w!t cast destroy at target")
assert_eq("7e: clearfull bypassed unchanged dedupe", #_send_lines, before_clearfull + 1)
assert_eq("7f: stale class ownership cleared", Q.get_owned("class"), nil)
assert_eq("7g: staged class sidecar dropped", Q.list("class"), nil)
assert_eq("7h: execute ownership retained", Q.get_owned("eq") and Q.get_owned("eq").queue_verb, "ADDCLEARFULL")

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end

