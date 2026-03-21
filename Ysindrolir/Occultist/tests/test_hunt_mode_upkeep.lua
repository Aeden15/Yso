-- Test harness for yso_hunt_mode_upkeep.lua
-- Run with: lua test_hunt_mode_upkeep.lua
-- Simulates Mudlet globals and walks through every scenario.

local _clock = 1000.0
local _sends = {}
local _triggers = {}
local _timers = {}
local _events = {}
local _timer_id = 0
local _trigger_id = 0
local _event_id = 0
local _current_line = ""

-- Mudlet stubs
function getEpoch() return _clock end
function send(cmd, show)
  _sends[#_sends + 1] = cmd
end
function expandAlias() end
function cecho(msg) io.write(msg) end
function echo() end
function tempRegexTrigger(pattern, fn)
  _trigger_id = _trigger_id + 1
  _triggers[_trigger_id] = { pattern = pattern, fn = fn }
  return _trigger_id
end
function killTrigger(id) _triggers[id] = nil end
function tempTimer(secs, fn)
  _timer_id = _timer_id + 1
  _timers[_timer_id] = { at = _clock + secs, fn = fn }
  return _timer_id
end
function killTimer(id) _timers[id] = nil end
function registerAnonymousEventHandler(event, fn)
  _event_id = _event_id + 1
  _events[_event_id] = { event = event, fn = fn }
  return _event_id
end
function killAnonymousEventHandler(id) _events[id] = nil end
function getCurrentLine() return _current_line end

-- helpers
local function clear_sends() _sends = {} end
local function send_count() return #_sends end
local function last_send() return _sends[#_sends] end
local function all_sends() return table.concat(_sends, ", ") end

local function fire_trigger(pattern_fragment)
  for _, t in pairs(_triggers) do
    if t.pattern:find(pattern_fragment, 1, true) then
      t.fn()
      return true
    end
  end
  return false
end

local function fire_line(text)
  _current_line = text
  for _, t in pairs(_triggers) do
    -- tempRegexTrigger patterns are PCRE; approximate with plain find on
    -- the literal core of each pattern (strip anchors / escapes).
    local core = t.pattern:gsub("^%^", ""):gsub("%$$", ""):gsub("\\%.", ".")
    if text:find(core, 1, true) or text:find(core, 1, false) then
      t.fn()
    end
  end
end

local function advance_timers(secs)
  _clock = _clock + secs
  local fired = {}
  for id, t in pairs(_timers) do
    if _clock >= t.at then
      fired[#fired + 1] = { id = id, fn = t.fn }
    end
  end
  for _, f in ipairs(fired) do
    _timers[f.id] = nil
    f.fn()
  end
end

local function fire_event(name, ...)
  for _, e in pairs(_events) do
    if e.event == name then
      e.fn(...)
    end
  end
end

local pass_count = 0
local fail_count = 0
local function assert_eq(label, got, expected)
  if got ~= expected then
    fail_count = fail_count + 1
    io.write(string.format("FAIL: %s — expected %s, got %s\n", label, tostring(expected), tostring(got)))
  else
    pass_count = pass_count + 1
  end
end

local function assert_true(label, val)  assert_eq(label, val, true) end
local function assert_false(label, val) assert_eq(label, (val == true), false) end

-- Setup: global Yso with mode table
_G.Yso = {
  mode = {
    state = "bash",
    is_bash = function() return _G.Yso.mode.state == "bash" end,
  },
}
_G.yso = _G.Yso

-- Load the module
dofile("../modules/Yso/xml/yso_hunt_mode_upkeep.lua")
local M = Yso.huntmode

-- enable debug for trace
M.cfg.debug = true

print("=== Test 1: refresh sends exactly one ENT ===")
clear_sends()
M.refresh("test")
assert_eq("1: send count", send_count(), 1)
assert_eq("1: command", last_send(), "ent")

print("\n=== Test 2: calling _act before ent synced does nothing ===")
clear_sends()
-- ent.synced is false after refresh/request_ent
assert_false("2: ent synced", M.state.ent.synced)
-- Simulate what would happen if something called _act directly
-- (it's local, so we test via trigger paths instead)
-- The ent_header trigger just sets scanning, doesn't call _act
fire_line("The following beings are in your entourage:")
assert_eq("2: no sends from header", send_count(), 0)

print("\n=== Test 3: ENT with no entities → sends all 3 summons exactly once ===")
clear_sends()
fire_line("There are no beings in your entourage.")
assert_eq("3: send count", send_count(), 3)
assert_eq("3: cmd 1", _sends[1], "summon orb")
assert_eq("3: cmd 2", _sends[2], "summon hound")
assert_eq("3: cmd 3", _sends[3], "summon pathfinder")

print("\n=== Test 4: repeated calls do NOT re-send (sent flags block) ===")
clear_sends()
-- Simulate 100 hypothetical ticks — nothing should call _act again
-- because there's no vitals handler. But even if someone did:
-- _act is local, so we can only trigger it via triggers.
-- Let's verify the sent flags are set:
assert_true("4: orb sent flag", M.state.sent.orb)
assert_true("4: hound sent flag", M.state.sent.hound)
assert_true("4: pathfinder sent flag", M.state.sent.pathfinder)

print("\n=== Test 5: summon confirmations → mask sent once all present ===")
clear_sends()
fire_line("A swirling portal of chaos opens, spits out a chaos orb, then vanishes.")
assert_eq("5a: after orb confirm, sends", send_count(), 0) -- still missing hound+pathfinder
assert_true("5a: orb present", M.state.present.orb)

fire_line("A swirling portal of chaos opens, spits out a chaos hound, then vanishes.")
assert_eq("5b: after hound confirm, sends", send_count(), 0) -- still missing pathfinder

fire_line("A swirling portal of chaos opens, spits out a pathfinder, then vanishes.")
assert_eq("5c: after pathfinder confirm, send count", send_count(), 1) -- mask!
assert_eq("5c: mask sent", last_send(), "mask")

print("\n=== Test 6: mask sent flag prevents re-send ===")
clear_sends()
assert_true("6: mask sent flag", M.state.sent.mask)
-- Even if somehow _act ran again, mask won't re-send
-- (can't call _act directly, but the flag proves it)

print("\n=== Test 7: mask confirmation sets mask_active ===")
fire_line("Calling upon your powers within, you mask the movements of your chaos entities from the world.")
assert_true("7: mask_active", M.state.mask_active)

print("\n=== Test 8: ENT with partial entities → only missing ones summoned ===")
clear_sends()
M.refresh("test-partial")
assert_eq("8a: refresh sends ent", send_count(), 1)
-- Simulate ENT output: orb and pathfinder present, hound missing
clear_sends()
fire_line("The following beings are in your entourage:")
_current_line = "a chaos orb#12345, a pathfinder#67890."
-- fire the #\d+ trigger
for _, t in pairs(_triggers) do
  if t.pattern == [[#\d+]] then
    t.fn()
    break
  end
end
assert_eq("8b: only hound summoned", send_count(), 1)
assert_eq("8b: command", last_send(), "summon hound")

print("\n=== Test 9: rescan timer fires after interval ===")
clear_sends()
-- Reset to known state
M.state.mask_active = true
M.state.ent.synced = true
advance_timers(M.cfg.rescan_interval + 0.1)
-- Timer should have fired _request_ent
local found_ent = false
for _, s in ipairs(_sends) do
  if s == "ent" then found_ent = true end
end
assert_true("9: rescan sent ent", found_ent)

print("\n=== Test 10: not in bash mode → everything is no-op ===")
clear_sends()
_G.Yso.mode.state = "combat"
M.refresh("test-combat")
assert_eq("10a: refresh in combat sends ent", send_count(), 1) -- refresh still sends ent
-- But after ENT parse, _act should not summon
clear_sends()
M.state.ent.synced = true
M.state.present = { orb = false, hound = false, pathfinder = false }
M.state.sent = { orb = false, hound = false, pathfinder = false, mask = false }
-- Simulate calling _act via a trigger
fire_line("There are no beings in your entourage.")
-- _apply_none calls _act, but _is_bash_mode() is false
assert_eq("10b: no summons in combat mode", send_count(), 0)

print("\n=== Test 11: mode change to bash triggers refresh ===")
clear_sends()
fire_event("yso.mode.changed", "yso.mode.changed", "combat", "bash", "alias")
_G.Yso.mode.state = "bash"
-- Should have sent ent
local has_ent = false
for _, s in ipairs(_sends) do
  if s == "ent" then has_ent = true end
end
assert_true("11: mode→bash sent ent", has_ent)

print("\n=== Test 12: no gmcp.Char.Vitals handler exists ===")
local has_vitals = false
for _, e in pairs(_events) do
  if e.event == "gmcp.Char.Vitals" then
    has_vitals = true
    break
  end
end
assert_false("12: no vitals handler", has_vitals)

print("\n=== Test 13: stress — fire summon triggers 1000x, count sends ===")
_G.Yso.mode.state = "bash"
clear_sends()
M.refresh("stress-test")
-- 1 send for ent
assert_eq("13a: refresh = 1 ent", send_count(), 1)

-- Simulate ENT empty
clear_sends()
fire_line("There are no beings in your entourage.")
assert_eq("13b: 3 summons", send_count(), 3)

-- Now fire hound confirm 1000 times
clear_sends()
for i = 1, 1000 do
  fire_line("A swirling portal of chaos opens, spits out a chaos hound, then vanishes.")
end
-- Should see 0 extra sends — hound is already present, orb/pathfinder already sent
assert_eq("13c: 1000x hound confirm = 0 sends", send_count(), 0)

-- Fire all 3 confirmations
fire_line("A swirling portal of chaos opens, spits out a chaos orb, then vanishes.")
local count_before = send_count()
fire_line("A swirling portal of chaos opens, spits out a pathfinder, then vanishes.")
-- pathfinder confirm should trigger mask (all present now)
assert_eq("13d: mask sent once", send_count(), count_before + 1)
assert_eq("13d: it was mask", last_send(), "mask")

-- Fire mask confirm 1000 times
clear_sends()
for i = 1, 1000 do
  fire_line("Calling upon your powers within, you mask the movements of your chaos entities from the world.")
end
assert_eq("13e: 1000x mask confirm = 0 sends", send_count(), 0)

print("\n=== Test 14: stable state → rescan timer stops, no ent sent ===")
-- State: all present, mask_active = true (from test 13 mask confirm)
assert_true("14a: mask_active", M.state.mask_active)
assert_true("14a: all present", M.state.present.orb and M.state.present.hound and M.state.present.pathfinder)

-- Advance past 5 rescan intervals — timer should NOT fire (stopped at stability)
for cycle = 1, 5 do
  clear_sends()
  advance_timers(M.cfg.rescan_interval + 0.1)
  assert_eq("14b-" .. cycle .. ": no sends at all", send_count(), 0)
end
assert_eq("14c: timer is nil (stopped)", M._rescan_timer, nil)

print("\n=== Test 15: entity death during stable → refresh re-summons ===")
-- Simulate: player manually types ENT or refresh is called after entity dies
clear_sends()
M.refresh("test-entity-death")
assert_eq("15a: ent sent", _sends[1], "ent")
-- ENT response: hound died
clear_sends()
fire_line("The following beings are in your entourage:")
_current_line = "a chaos orb#501520, a pathfinder#423950."
for _, t in pairs(_triggers) do
  if t.pattern == [[#\d+]] then t.fn(); break end
end
-- Should summon hound only, mask_active should be false
assert_eq("15b: 1 summon", send_count(), 1)
assert_eq("15b: summon hound", _sends[1], "summon hound")
assert_false("15b: mask cleared", M.state.mask_active)
-- Hound returns
clear_sends()
fire_line("A swirling portal of chaos opens, spits out a chaos hound, then vanishes.")
assert_eq("15c: mask sent", send_count(), 1)
assert_eq("15c: it was mask", _sends[1], "mask")
-- Mask confirms
fire_line("Calling upon your powers within, you mask the movements of your chaos entities from the world.")
assert_true("15d: mask active again", M.state.mask_active)
-- Timer should stop again
assert_eq("15e: timer stopped at stability", M._rescan_timer, nil)

print("\n=== Test 16: refresh → all entities lost → re-summons all 3 ===")
clear_sends()
M.refresh("test-all-lost")
clear_sends()
fire_line("There are no beings in your entourage.")
assert_eq("16: 3 summons", send_count(), 3)

print("")
print(string.format("=== Results: %d passed, %d failed ===", pass_count, fail_count))
if fail_count > 0 then
  os.exit(1)
end
