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
local PRIO_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "xml", "prio_baselines.lua")

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

local warn_count = 0
function cecho(_)
  warn_count = warn_count + 1
end

local original_deepcopy = table.deepcopy

local function clone_shallow(t)
  local out = {}
  for k, v in pairs(t or {}) do
    out[k] = v
  end
  return out
end

local function fresh_env(with_deepcopy)
  warn_count = 0
  Legacy = {
    Curing = {
      Prios = {
        baseSets = {},
      },
      ActiveServerSet = "default",
    },
  }
  if with_deepcopy == true then
    table.deepcopy = clone_shallow
  else
    table.deepcopy = nil
  end
  dofile(PRIO_PATH)
end

print("=== Test 1: ApplyCapturedBaseline uses available baseline helper path ===")
fresh_env(true)
Legacy.Curing.Prios.baseSets.default = { paralysis = 2 }
local P = Legacy.Curing.Prios
P.UseBaseline = function(set)
  P._used_set = tostring(set or "")
  return true
end
local applied_1, set_1, warned_1 = P.ApplyCapturedBaseline("default", { warn = true })
assert_true("1a: applied via UseBaseline", applied_1)
assert_eq("1b: set returned", set_1, "default")
assert_false("1c: no warning on success", warned_1)
assert_eq("1d: helper called for requested set", P._used_set, "default")

print("\n=== Test 2: fallback avoids temp aliasing when deepcopy is unavailable ===")
fresh_env(false)
Legacy.Curing.Prios.baseSets.default = { asthma = 6 }
P = Legacy.Curing.Prios
P.UseBaseline = nil
Legacy.Curing.UseBaseline = nil
local applied_2 = P.ApplyCapturedBaseline("default", { warn = true })
assert_true("2a: fallback applied from baseSets", applied_2 == true)
assert_true("2b: legacy baseline points to set table", P.legacy == P.baseSets.default)
assert_eq("2c: temp left nil when deepcopy missing", P.temp, nil)

print("\n=== Test 3: warning emitted once per missing set ===")
fresh_env(false)
P = Legacy.Curing.Prios
P.UseBaseline = nil
Legacy.Curing.UseBaseline = nil
P.baseSets = {}
local applied_3a, _, warned_3a = P.ApplyCapturedBaseline("missing", { warn = true })
assert_false("3a: missing set not applied", applied_3a)
assert_true("3b: first missing-set warning emitted", warned_3a)
assert_eq("3c: one warning emitted", warn_count, 1)

local applied_3b, _, warned_3b = P.ApplyCapturedBaseline("missing", { warn = true })
assert_false("3d: second missing-set call still not applied", applied_3b)
assert_false("3e: second warning suppressed for same set", warned_3b)
assert_eq("3f: warning count unchanged for same set", warn_count, 1)

local applied_3c, _, warned_3c = P.ApplyCapturedBaseline("othermissing", { warn = true })
assert_false("3g: different missing set not applied", applied_3c)
assert_true("3h: warning emitted for different set", warned_3c)
assert_eq("3i: warning count increments for different set", warn_count, 2)

table.deepcopy = original_deepcopy

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
