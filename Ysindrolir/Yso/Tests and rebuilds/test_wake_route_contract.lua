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
local MODES_PATH = join_path(SCRIPT_DIR, "..", "Core", "modes.lua")
local WAKE_PATH = join_path(SCRIPT_DIR, "..", "Core", "wake_bus.lua")

local pass_count = 0
local fail_count = 0

local function fail(label, detail)
  fail_count = fail_count + 1
  io.stderr:write(string.format("FAIL: %s%s\n", label, detail and (" - " .. detail) or ""))
end

local function pass()
  pass_count = pass_count + 1
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

local _clock = 5000
local _timer_id = 0
local _scheduled = {}

_G.setConsoleBufferSize = function() end
_G.registerAnonymousEventHandler = function() return 1 end
_G.killAnonymousEventHandler = function() end
_G.tempAlias = function() return 1 end
_G.killAlias = function() end
_G.expandAlias = function() return true end
_G.raiseEvent = function() end
_G.cecho = function() end
_G.echo = function() end
_G.send = function() return true end
_G.getEpoch = function() return _clock * 1000 end
_G.tempTimer = function(delay, fn)
  _timer_id = _timer_id + 1
  _scheduled[#_scheduled + 1] = { id = _timer_id, delay = tonumber(delay) or 0, fn = fn }
  return _timer_id
end
_G.killTimer = function(id)
  for i = #_scheduled, 1, -1 do
    if _scheduled[i].id == id then
      table.remove(_scheduled, i)
    end
  end
end
_G.deleteLine = function() return true end

local ack_payloads = {}

_G.Yso = {
  cfg = { cmd_sep = "&&", pipe_sep = "&&" },
  util = {
    now = function() return _clock end,
    tick_once = function(_, _, fn)
      if type(fn) == "function" then
        fn()
      end
      return true
    end,
  },
  net = { cfg = { dry_run = true } },
  state = {
    eq_ready = function() return true end,
    bal_ready = function() return true end,
    ent_ready = function() return true end,
    set_ent_ready = function() return true end,
  },
  locks = {
    note_payload = function(payload)
      ack_payloads[#ack_payloads + 1] = payload
      return true
    end,
  },
  Combat = {
    RouteRegistry = {
      resolve = function(id)
        if tostring(id) == "magi_focus" then
          return { id = "magi_focus", namespace = "Yso.off.magi.focus", module_name = "magi_focus" }
        elseif tostring(id) == "magi_group_damage" then
          return { id = "magi_group_damage", namespace = "Yso.off.magi.group_damage", module_name = "magi_group_damage" }
        end
        return nil
      end,
      active_ids = function()
        return { "magi_focus", "magi_group_damage" }
      end,
      for_mode = function()
        return {}
      end,
    },
  },
  off = {
    magi = {
      focus = {
        state = { loop_enabled = true, busy = false, timer_id = nil },
      },
    },
  },
}
_G.yso = _G.Yso

dofile(QUEUE_PATH)
dofile(MODES_PATH)
dofile(WAKE_PATH)

print("=== Test 1: queue ack includes route/target attribution (single lane) ===")
do
  local Q = Yso.queue
  assert_true("1a: stage eq command", Q.stage("eq", "cast freeze at foe"))
  local committed = Q.commit({ route = "magi_focus", target = "foe", allow_eqbal = true })
  assert_true("1b: commit success", committed == true)
  local ack = ack_payloads[#ack_payloads] or {}
  assert_eq("1c: ack route", ack.route, "magi_focus")
  assert_eq("1d: ack target", ack.target, "foe")
  assert_eq("1e: lane route attribution", type(ack.route_by_lane) == "table" and ack.route_by_lane.eq, "magi_focus")
  assert_eq("1f: lane target attribution", type(ack.target_by_lane) == "table" and ack.target_by_lane.eq, "foe")
end

print("\n=== Test 2: queue ack includes multi-lane attribution ===")
do
  local Q = Yso.queue
  Q.clear()
  assert_true("2a: stage eq lane", Q.stage("eq", "cast magma at foe"))
  assert_true("2b: stage bal lane", Q.stage("bal", "fling needle at foe"))
  local committed = Q.commit({ route = "magi_group_damage", target = "foe", allow_eqbal = true })
  assert_true("2c: commit success", committed == true)
  local ack = ack_payloads[#ack_payloads] or {}
  assert_eq("2d: eq route_by_lane", type(ack.route_by_lane) == "table" and ack.route_by_lane.eq, nil)
  assert_eq("2e: bal route_by_lane", type(ack.route_by_lane) == "table" and ack.route_by_lane.bal, "magi_group_damage")
  assert_eq("2f: eq target_by_lane", type(ack.target_by_lane) == "table" and ack.target_by_lane.eq, nil)
  assert_eq("2g: bal target_by_lane", type(ack.target_by_lane) == "table" and ack.target_by_lane.bal, "foe")
end

print("\n=== Test 3: mode nudge dedupes bursts and re-schedules after window ===")
do
  local M = Yso.mode
  M.route_loop = M.route_loop or {}
  M.route_loop.nudges = {}
  _clock = _clock + 1
  local ok1 = M.nudge_route_loop("magi_focus", "unit:first")
  assert_true("3a: first nudge schedules", ok1 == true)
  local after_first = #_scheduled
  local ok2, why2 = M.nudge_route_loop("magi_focus", "unit:burst")
  assert_false("3b: second nudge deduped", ok2 == true)
  assert_eq("3c: dedupe reason", why2, "deduped")
  assert_eq("3d: no extra timer during dedupe", #_scheduled, after_first)
  _clock = _clock + 0.10
  local ok3 = M.nudge_route_loop("magi_focus", "unit:after_window")
  assert_true("3e: nudge schedules again after dedupe window", ok3 == true)
  assert_eq("3f: nudge reschedule keeps one active timer slot", #_scheduled, after_first)
end

print("\n=== Test 4: wake bus nudges routes from line and ack events ===")
do
  local calls = {}
  Yso.mode.nudge_route_loop = function(route_id, reason)
    calls[#calls + 1] = { route = route_id, reason = tostring(reason or "") }
    return true
  end

  local ok_line = Yso.pulse.handle_line_event("line:eq_blocked", { gag = false, echo = false })
  assert_true("4a: line event handled", ok_line == true)
  assert_eq("4b: line event nudge reason", calls[1] and calls[1].reason or "", "line:eq_blocked")

  calls = {}
  Yso.pulse.on_payload_ack({
    route = "magi_focus",
    route_by_lane = { eq = "magi_focus", bal = "magi_magi_group_damage" },
  }, "queue.commit")
  assert_eq("4c: payload ack deduped route count", #calls, 2)
  assert_eq("4d: payload ack first route", calls[1] and calls[1].route or "", "magi_focus")
  assert_eq("4e: payload ack second route", calls[2] and calls[2].route or "", "magi_magi_group_damage")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end



