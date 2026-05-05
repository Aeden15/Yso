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
local COORD_PATH = join_path(SCRIPT_DIR, "..", "xml", "yso_offense_coordination.lua")

local pass_count = 0
local fail_count = 0

local function pass() pass_count = pass_count + 1 end

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

local function contains_text(list, text)
  for i = 1, #list do
    if tostring(list[i] or ""):find(text, 1, true) then
      return true
    end
  end
  return false
end

local reset_calls = {}
local clear_lane_calls = {}
local clear_calls = {}
local clear_owned_calls = {}
local clear_dispatched_calls = {}
local sent = {}

local function reset_mod(id)
  return {
    state = { loop_enabled = true, enabled = true },
    reset_route_state = function(reason, target)
      reset_calls[#reset_calls + 1] = { id = id, reason = reason, target = target }
      return true
    end,
  }
end

_G.Yso = {
  target = "Tharonus",
  get_target = function() return "Tharonus" end,
  mode = {
    active_route_id = function() return "alchemist_group_damage" end,
  },
  Combat = {
    RouteRegistry = {
      resolve = function(id)
        local namespaces = {
          alchemist_group_damage = "Yso.off.alc.group_damage",
          alchemist_duel_route = "Yso.off.alc.duel_route",
          alchemist_aurify_route = "Yso.off.alc.aurify_route",
        }
        if namespaces[id] then
          return { id = id, namespace = namespaces[id] }
        end
        return nil
      end,
    },
  },
  off = {
    alc = {
      group_damage = reset_mod("group"),
      duel_route = reset_mod("duel"),
      aurify_route = reset_mod("aurify"),
    },
  },
  queue = {
    clear_lane = function(lane)
      clear_lane_calls[#clear_lane_calls + 1] = lane
      return true
    end,
    clear = function(lane)
      clear_calls[#clear_calls + 1] = lane
      return true
    end,
    clear_owned = function(lane)
      clear_owned_calls[#clear_owned_calls + 1] = lane
      return true
    end,
    clear_lane_dispatched = function(lane, reason)
      clear_dispatched_calls[#clear_dispatched_calls + 1] = { lane = lane, reason = reason }
      return true
    end,
  },
  util = { now = function() return 12345 end },
}
_G.yso = _G.Yso
_G.send = function(cmd)
  sent[#sent + 1] = tostring(cmd or "")
  return true
end

dofile(COORD_PATH)

print("=== Test 1: external reset cleans Alchemist route and queue state ===")
do
  local ok = Yso.off.coord.on_external_reset("ak_reset_success")
  assert_true("1a: external reset returns true", ok == true)
  assert_true("1b: group route reset", reset_calls[1] ~= nil)
  assert_true("1c: duel route reset", #reset_calls >= 2)
  assert_true("1d: aurify route reset", #reset_calls >= 3)
  assert_eq("1e: first reset reason", reset_calls[1] and reset_calls[1].reason, "ak_reset_success")
  assert_eq("1f: reset target", reset_calls[1] and reset_calls[1].target, "Tharonus")
  assert_false("1g: external reset does not call live clear_lane", contains_text(clear_lane_calls, "class"))
  assert_true("1h: local class queue cleared", contains_text(clear_calls, "class"))
  assert_true("1i: local eq queue cleared", contains_text(clear_calls, "eq"))
  assert_true("1j: local bal queue cleared", contains_text(clear_calls, "bal"))
  assert_true("1k: local free queue cleared", contains_text(clear_calls, "free"))
  assert_true("1l: local class ownership cleared", contains_text(clear_owned_calls, "class"))
  assert_true("1m: lane dispatch debounce cleared", clear_dispatched_calls[1] ~= nil)
  assert_false("1n: external reset does not send server CLEARQUEUE", contains_text(sent, "CLEARQUEUE"))
  assert_true("1o: active route remains enabled", Yso.off.alc.group_damage.state.loop_enabled == true)
  assert_eq("1p: diagnostic source recorded", Yso.off.coord.state.last_external_reset.source, "ak_reset_success")
end

print("\n=== Test 2: AK reset bridge trigger body calls coordination hook ===")
do
  local seen = ""
  Yso.off.coord.on_external_reset = function(source)
    seen = tostring(source or "")
    return true
  end
  local trigger_body = [[
if Yso and Yso.off and Yso.off.coord and type(Yso.off.coord.on_external_reset) == "function" then
  Yso.off.coord.on_external_reset("ak_reset_success")
end
]]
  local loader = loadstring or load
  local fn = loader(trigger_body)
  assert_true("2a: trigger body loads", fn ~= nil)
  assert_true("2b: trigger body executes", pcall(fn))
  assert_eq("2c: trigger source", seen, "ak_reset_success")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
