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

local function read_all(path)
  local fh = assert(io.open(path, "rb"))
  local data = fh:read("*a")
  fh:close()
  return data
end

local SCRIPT_DIR = script_dir()
local MODES_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Core", "modes.lua")
local OCC_GD_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "routes", "group_damage.lua")
local MAGI_GD_PATH = join_path(SCRIPT_DIR, "..", "..", "Magi", "magi_group_damage.lua")

local pass_count = 0
local fail_count = 0
local echoes = {}
local current_class = "Occultist"

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
  assert_eq(label, value == true, true)
end

local function reset_echoes()
  echoes = {}
end

local function echo_count(fragment)
  local n = 0
  for i = 1, #echoes do
    if echoes[i]:find(fragment, 1, true) then
      n = n + 1
    end
  end
  return n
end

function cecho(msg)
  echoes[#echoes + 1] = tostring(msg or "")
end

function echo(msg)
  echoes[#echoes + 1] = tostring(msg or "")
end

function tempAlias() return 1 end
function killAlias() end
function tempTimer() return 1 end
function killTimer() end
function raiseEvent() end
function getEpoch() return 1000 end

local function make_route(prefix)
  return {
    alias_owned = true,
    cfg = { echo = true, loop_delay = 0.15 },
    state = {},
    init = function(self)
      self.state = self.state or {}
      self.cfg = self.cfg or { loop_delay = 0.15 }
      self.state.loop_enabled = (self.state.loop_enabled == true)
      return true
    end,
    alias_loop_on_started = function()
      cecho(string.format("%sGroup damage loop ON.\n", prefix))
    end,
    alias_loop_on_stopped = function(ctx)
      ctx = ctx or {}
      if ctx.silent ~= true then
        cecho(string.format("%sGroup damage loop OFF (%s).\n", prefix, tostring(ctx.reason or "manual")))
      end
    end,
  }
end

_G.Yso = {
  off = {
    oc = {
      group_damage = make_route("[Yso:Occultist] "),
      party_aff = {
        alias_owned = false,
        cfg = { loop_delay = 0.15 },
        state = {},
        init = function(self)
          self.state = self.state or {}
          self.state.enabled = (self.state.enabled == true)
          return true
        end,
        start = function(self)
          self.state.enabled = true
          return true
        end,
        stop = function(self)
          self.state.enabled = false
          return true
        end,
      },
    },
    magi = {
      group_damage = make_route("[Yso:Magi] "),
    },
  },
  Combat = {
    RouteRegistry = {
      resolve = function(name)
        name = tostring(name or "")
        if name == "group_damage" then
          return {
            id = "group_damage",
            mode = "party",
            party_route = "dam",
            namespace = "Yso.off.oc.group_damage",
          }
        end
        if name == "magi_group_damage" then
          return {
            id = "magi_group_damage",
            mode = "party",
            party_route = "dam",
            namespace = "Yso.off.magi.group_damage",
          }
        end
        if name == "party_aff" or name == "aff" then
          return {
            id = "party_aff",
            mode = "party",
            party_route = "aff",
            namespace = "Yso.off.oc.party_aff",
          }
        end
        return nil
      end,
      active_ids = function()
        return { "group_damage", "magi_group_damage", "party_aff" }
      end,
      for_mode = function(mode)
        if tostring(mode or "") ~= "party" then return {} end
        return {
          _G.Yso.Combat.RouteRegistry.resolve("group_damage"),
          _G.Yso.Combat.RouteRegistry.resolve("magi_group_damage"),
          _G.Yso.Combat.RouteRegistry.resolve("party_aff"),
        }
      end,
      for_party_route = function(route)
        route = tostring(route or "")
        if route == "aff" then
          return _G.Yso.Combat.RouteRegistry.resolve("party_aff")
        end
        if route == "dam" then
          if current_class == "Magi" then
            return _G.Yso.Combat.RouteRegistry.resolve("magi_group_damage")
          end
          return _G.Yso.Combat.RouteRegistry.resolve("group_damage")
        end
        return nil
      end,
    },
  },
}
_G.yso = _G.Yso

dofile(MODES_PATH)

local M = Yso.mode

print("=== Test 1: source prefixes updated ===")
do
  local occ_src = read_all(OCC_GD_PATH)
  assert_true("1a: occultist route uses explicit class prefix", occ_src:find("[Yso:Occultist]", 1, true) ~= nil)
  assert_true("1b: old GD prefix removed", occ_src:find("[Yso:GD]", 1, true) == nil)

  local magi_src = read_all(MAGI_GD_PATH)
  assert_true("1c: magi route uses generic loop ON text", magi_src:find("Group damage loop ON.", 1, true) ~= nil)
  assert_true("1d: old magi team damage text removed", magi_src:find("Magi team damage loop ON.", 1, true) == nil)
end

print("\n=== Test 2: real shared mode change emits once ===")
do
  reset_echoes()
  M.state = "combat"
  M.party.route = "dam"
  M.set("party", "test")
  assert_eq("2a: one shared line on real mode change", echo_count("[Yso]"), 1)
  assert_true("2b: shared line reports party mode", echoes[1] and echoes[1]:find("Mode: party (route: dam)", 1, true) ~= nil)
end

print("\n=== Test 3: real shared route change emits once ===")
do
  reset_echoes()
  current_class = "Occultist"
  M.state = "party"
  M.party.route = "dam"
  M.set_party_route("aff", "test")
  assert_eq("3a: one shared line on real route change", echo_count("[Yso]"), 1)
  assert_true("3b: shared line reports new route", echoes[1] and echoes[1]:find("Mode: party (route: aff)", 1, true) ~= nil)
end

print("\n=== Test 4: no-op mode and route stay quiet ===")
do
  reset_echoes()
  M.state = "party"
  M.party.route = "aff"
  M.set("party", "noop")
  assert_eq("4a: no shared echo on party noop", #echoes, 0)

  reset_echoes()
  M.set_party_route("aff", "noop")
  assert_eq("4b: no shared echo on route noop", #echoes, 0)
end

print("\n=== Test 5: Magi loop toggle yields one shared line and one class line ===")
do
  reset_echoes()
  current_class = "Magi"
  Yso.off.magi.group_damage.state.loop_enabled = false
  M.state = "combat"
  M.party.route = "dam"
  M.route_loop.active = ""
  M.start_route_loop("magi_group_damage", "alias")
  assert_eq("5a: one shared line on loop arm", echo_count("[Yso]"), 1)
  assert_eq("5b: one Magi class line on loop arm", echo_count("[Yso:Magi]"), 1)
  assert_eq("5c: no duplicate route-state line remains", #echoes, 2)
end

print("\n=== Test 6: Occultist loop toggle yields one shared line and one class line ===")
do
  reset_echoes()
  current_class = "Occultist"
  Yso.off.oc.group_damage.state.loop_enabled = false
  M.state = "combat"
  M.party.route = "dam"
  M.route_loop.active = ""
  M.start_route_loop("group_damage", "alias")
  assert_eq("6a: one shared line on loop arm", echo_count("[Yso]"), 1)
  assert_eq("6b: one Occultist class line on loop arm", echo_count("[Yso:Occultist]"), 1)
  assert_eq("6c: old GD class line is gone", echo_count("[Yso:GD]"), 0)
  assert_eq("6d: no duplicate route-state line remains", #echoes, 2)
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
