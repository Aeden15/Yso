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
local RI_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "route_interface.lua")
local ROUTE_PATH = join_path(SCRIPT_DIR, "..", "..", "Magi", "Magi_duel_dam.lua")

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

local function assert_eq(label, got, expected)
  if got ~= expected then
    fail(label, string.format("expected %s, got %s", tostring(expected), tostring(got)))
    return
  end
  pass()
end

local send_count = 0
local emit_rows = {}
local ack_rows = {}
local now_s = 7000

_G.setConsoleBufferSize = function() end
_G.registerAnonymousEventHandler = function() return 1 end
_G.killAnonymousEventHandler = function() end
_G.tempAlias = function() return 1 end
_G.killAlias = function() end
_G.expandAlias = function() return true end
_G.raiseEvent = function() end
_G.cecho = function() end
_G.echo = function() end
_G.send = function()
  send_count = send_count + 1
  return true
end
_G.getEpoch = function() return now_s * 1000 end

_G.affstrack = {
  score = setmetatable({}, { __index = function() return 0 end }),
}

_G.gmcp = {
  Char = {
    Status = { class = "Magi" },
    Vitals = { eq = "1", equilibrium = "1" },
  },
}

_G.target = "foe"

_G.Yso = {
  Combat = {},
  off = { magi = {} },
  util = { now = function() return now_s end },
  state = {
    eq_ready = function() return true end,
  },
  locks = {
    note_payload = function(payload)
      ack_rows[#ack_rows + 1] = payload
      return true
    end,
  },
  get_target = function()
    return "foe"
  end,
  emit = function(payload, opts)
    emit_rows[#emit_rows + 1] = { payload = payload, opts = opts }
    return true
  end,
}
_G.yso = _G.Yso

dofile(RI_PATH)
dofile(ROUTE_PATH)

local M = Yso.off.magi.dmg
M.on()

print("=== Test 1: magi_dmg emits through Yso.emit route pipeline ===")
do
  local ok = M.attack_function()
  assert_true("1a: attack succeeded", ok == true)
  assert_eq("1b: direct send path bypassed", send_count, 0)
  assert_eq("1c: one emit payload", #emit_rows, 1)
  local row = emit_rows[1]
  assert_eq("1d: eq payload command", row and row.payload and row.payload.eq, "cast magma foe")
  assert_eq("1e: explicit route opts", row and row.opts and row.opts.route, "magi_dmg")
  assert_eq("1f: explicit target opts", row and row.opts and row.opts.target, "foe")
end

print("\n=== Test 2: waiting lifecycle clears on routed ack ===")
do
  assert_true("2a: waiting set after emit", type(M.state.waiting) == "table" and tostring(M.state.waiting.queue or "") ~= "")
  local ack = {
    route = "magi_dmg",
    target = "foe",
    lanes = { eq = "cast magma foe" },
    route_by_lane = { eq = "magi_dmg" },
  }
  M.on_payload_sent(ack)
  assert_eq("2b: waiting queue cleared on ack", M.state.waiting.queue, nil)
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
