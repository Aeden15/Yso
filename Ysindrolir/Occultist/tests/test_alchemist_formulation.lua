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
local CORE_DIR = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Core")

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

local function make_world()
  _G.Yso = nil
  _G.yso = nil
  _G.getEpoch = function() return 1000000 end
  _G.send = function() return true end

  dofile(join_path(CORE_DIR, "formulation.lua"))
  dofile(join_path(CORE_DIR, "formulation_resolve.lua"))
  dofile(join_path(CORE_DIR, "formulation_phials.lua"))
  dofile(join_path(CORE_DIR, "formulation_build.lua"))

  local F = Yso.alc.form
  local warnings = {}
  F.warn = function(msg)
    warnings[#warnings + 1] = tostring(msg or "")
  end
  F.parse_phiallist("Phial123 | Monoxide | 24 | 1 | 1 | 1")
  return F, warnings
end

print("=== Test 1: thrown Formulation phials require explicit ground or direction ===")
do
  local F, warnings = make_world()
  local cmd = F.build_use("monoxide", "")
  assert_eq("1a: empty throw argument fails safely", cmd, nil)
  assert_eq("1b: empty throw argument warns", warnings[1], "Monoxide needs 'ground' or a direction.")

  cmd = F.build_use("monoxide", "ground")
  assert_eq("1c: ground builds room throw", cmd, "WIELD MONOXIDE && THROW MONOXIDE AT GROUND")

  cmd = F.build_use("monoxide", "at ground")
  assert_eq("1d: at ground builds room throw", cmd, "WIELD MONOXIDE && THROW MONOXIDE AT GROUND")

  cmd = F.build_use("monoxide", "east")
  assert_eq("1e: direction builds directional throw", cmd, "WIELD MONOXIDE && THROW MONOXIDE EAST")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
