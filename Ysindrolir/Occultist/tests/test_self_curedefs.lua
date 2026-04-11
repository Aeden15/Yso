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
local DEFS_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Curing", "self_curedefs.lua")

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

function cecho() end

_G.Yso = { curing = {} }
_G.yso = _G.Yso

dofile(DEFS_PATH)
local D = Yso.curing.defs

print("=== Test 1: validation status + allowlist ===")
local ok, errs = D.validate()
assert_true("1a: curedefs validate", ok)
assert_eq("1b: no bucket validation errors", #(errs or {}), 0)
assert_true("1c: known bucket includes bloodroot", D.known_buckets.bloodroot == true)
local spot_ok, spot_warnings = D.startup_spotcheck()
assert_true("1d: startup spotcheck validate", spot_ok == true)
assert_eq("1e: startup spotcheck warning count", #(spot_warnings or {}), 0)

print("\n=== Test 2: alternatives always table ===")
for aff, row in pairs(D.by_aff) do
  assert_eq("2: alternatives table for " .. tostring(aff), type(row.alternatives), "table")
end

print("\n=== Test 3: drift checkpoints from reference data ===")
local paralysis = D.get("Paralysis")
assert_eq("3a: paralysis canon", paralysis and paralysis.canon, "paralysis")
assert_eq("3b: paralysis action", paralysis and paralysis.action, "eat")
assert_eq("3c: paralysis bucket", paralysis and paralysis.bucket, "bloodroot")

local blind = D.get("Blindness")
assert_eq("3d: blindness canonical lookup", blind and blind.canon, "blind")
assert_eq("3e: blindness bucket", blind and blind.bucket, "epidermal")

local sensitivity = D.get("Sensitivity")
assert_eq("3f: sensitivity canon", sensitivity and sensitivity.canon, "sensitivity")
assert_eq("3g: sensitivity bucket", sensitivity and sensitivity.bucket, "kelp")

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
