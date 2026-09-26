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

local function assert_true(label, value)
  if value ~= true then
    fail(label, string.format("expected true, got %s", tostring(value)))
    return
  end
  pass()
end

local sent = {}
local alias_fns = {}
local trig_fns = {}
local set_calls = {}

_G.send = function(cmd)
  sent[#sent + 1] = cmd
  return true
end
_G.cecho = function() end
_G.echo = function() end
_G.killAlias = function() end
_G.killTrigger = function() end
_G.tempAlias = function(pat, fn)
  alias_fns[pat] = fn
  return pat
end
_G.tempRegexTrigger = function(pat, fn)
  trig_fns[pat] = fn
  return pat
end
_G.expandAlias = function(cmd)
  local name = tostring(cmd or ""):match("^t (%S+)$")
  local fn = alias_fns["^t (\\S+)$"]
  if name and type(fn) == "function" then
    matches = { cmd, name }
    fn()
    return true
  end
  return false
end

_G.Yso = {
  targeting = {
    set = function(name, source, opts)
      set_calls[#set_calls + 1] = { name = name, source = source, opts = opts }
      return true
    end,
  },
}
_G.partyReporting = nil
_G.raidLead = nil
_G.target = nil
_G.gmcp = { Char = { Status = { name = "Ysindrolir" } } }
_G.matches = nil

dofile(join_path(script_dir(), "..", "xml", "yso_party_targeting.lua"))

local function reset_sent()
  sent = {}
  set_calls = {}
end

local function joined()
  return table.concat(sent, "|")
end

print("=== t Entaro sends st, enemy, tunnelvision, and a party call ===")
do
  reset_sent()
  partyReporting = true
  Yso.party_target._from_follow = false
  matches = { "t Entaro", "Entaro" }
  alias_fns["^t (\\S+)$"]()
  assert_eq("1a: command list", joined(), "st Entaro|enemy Entaro|tunnelvision on|pt Target: Entaro")
  assert_eq("1b: global target", target, "Entaro")
  assert_eq("1c: mirror name", set_calls[1] and set_calls[1].name or "", "Entaro")
  assert_eq("1d: mirror source", set_calls[1] and set_calls[1].source or "", "manual")
  assert_true("1e: no_ak", set_calls[1] and set_calls[1].opts and set_calls[1].opts.no_ak == true)
end

print("=== t none keeps the titled name and turns tunnelvision off ===")
do
  reset_sent()
  matches = { "t none", "none" }
  alias_fns["^t (\\S+)$"]()
  assert_eq("2a: command list", joined(), "st None|enemy None|tunnelvision off|pt Target: None")
end

print("=== party reporting can be off ===")
do
  reset_sent()
  partyReporting = false
  matches = { "t Entaro", "entaro" }
  alias_fns["^t (\\S+)$"]()
  assert_eq("3a: no party line", joined(), "st Entaro|enemy Entaro|tunnelvision on")
  partyReporting = true
end

print("=== rlead none does nothing; rlead sets the lead ===")
do
  reset_sent()
  raidLead = ""
  matches = { "rlead none", "none" }
  alias_fns["^rlead (\\w+)$"]()
  assert_eq("4a: none leaves the lead empty", raidLead, "")
  assert_eq("4b: none sends nothing", joined(), "")
  matches = { "rlead iaxus", "iaxus" }
  alias_fns["^rlead (\\w+)$"]()
  assert_eq("4c: lead stored", raidLead, "Iaxus")
  assert_eq("4d: follow announcement", joined(), "pt Following targets from Iaxus")
end

print("=== only the raid lead is followed, and follows do not rebroadcast ===")
do
  reset_sent()
  raidLead = "Iaxus"
  local party_pat = [[^\(Party\): (\w+) says, "(?:Targeting|TARGET|Target):? (\S+)\."$]]
  local follow = trig_fns[party_pat]
  assert_true("5a: party trigger registered", type(follow) == "function")

  matches = { "", "Someone", "Entaro" }
  follow()
  assert_eq("5b: other caller ignored", joined(), "")

  matches = { "", "Iaxus", "Entaro" }
  follow()
  assert_eq(
    "5c: lead follow commands",
    joined(),
    "st Entaro|enemy Entaro|tunnelvision on"
  )
  assert_true("5d: follow flag cleared", Yso.party_target._from_follow ~= true)

  reset_sent()
  gmcp.Char.Status.name = "Iaxus"
  matches = { "", "Iaxus", "Entaro" }
  follow()
  assert_eq("5e: own call ignored", joined(), "")
  gmcp.Char.Status.name = "Ysindrolir"
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
