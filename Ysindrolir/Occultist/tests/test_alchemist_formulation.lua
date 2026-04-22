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

local function assert_contains(label, got, needle)
  local text = tostring(got or "")
  if not text:find(needle, 1, true) then
    fail(label, string.format("expected '%s' to contain '%s'", text, tostring(needle)))
    return
  end
  pass()
end

local function make_world()
  _G.Yso = nil
  _G.yso = nil
  _G.getEpoch = function() return 1000000 end
  local sent = {}
  _G.send = function(cmd)
    sent[#sent + 1] = tostring(cmd or "")
    return true
  end

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
  return F, warnings, sent
end

local function load_phials(F, lines)
  F.parse_phiallist("Phial | Compound | Months | Potency | Volatility | Stability")
  for _, line in ipairs(lines or {}) do
    F.parse_phiallist(line)
  end
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

print("=== Test 2: alteration helpers accept phial IDs directly ===")
do
  local F = make_world()
  local cmd = F.build_adjustment("enhance", "potency", "phial658898")
  assert_eq("2a: adjustment command targets explicit phial id", cmd, "ENHANCE POTENCY OF PHIAL658898")
end

print("=== Test 3: reserved enhancement mismatch warns without auto-correction ===")
do
  local F, warnings = make_world()
  load_phials(F, {
    "Phial658898 | Endorphin | -- | 1 | 1 | 1",
    "Phial475762 | Endorphin | -- | 1 | 1 | 2",
    "Phial454568 | Empty | -- | 1 | 1 | 1",
  })

  local mismatch = F.remind_reserved_mismatch("enhancement")
  assert_eq("3a: mismatch detected", mismatch, true)
  assert_eq(
    "3b: mismatch warning format",
    warnings[#warnings],
    "Enhancement slot mismatch: Phial475762 currently holds Endorphin. Use EMPTY PHIAL475762 when ready."
  )
end

print("=== Test 4: unsafe Amalgamate blocks on multiple empty phials ===")
do
  local F, warnings = make_world()
  load_phials(F, {
    "Phial658898 | Endorphin | -- | 1 | 1 | 1",
    "Phial475762 | Enhancement | -- | 1 | 1 | 2",
    "Phial454568 | Empty | -- | 1 | 1 | 1",
    "Phial | Compound | Months left | Quantity",
    "Phial402228 | Empty | 23 | 1",
  })

  local cmd = F.build_role_amalgamate("gas", "monoxide")
  assert_eq("4a: command blocked when empties are not unique", cmd, nil)
  assert_contains("4b: warning names multiple empties", warnings[#warnings], "multiple empty phials detected")
end

print("=== Test 5: safe Amalgamate sends command then phiallist refresh ===")
do
  local F, warnings, sent = make_world()
  load_phials(F, {
    "Phial658898 | Endorphin | -- | 1 | 1 | 1",
    "Phial475762 | Enhancement | -- | 1 | 1 | 2",
    "Phial454568 | Empty | -- | 1 | 1 | 1",
  })

  local cmd = F.send_role_amalgamate("offensive_flex", "monoxide")
  assert_eq("5a: safe command is emitted", cmd, "AMALGAMATE MONOXIDE")
  assert_eq("5b: first send is amalgamate", sent[1], "AMALGAMATE MONOXIDE")
  assert_eq("5c: second send requests phiallist", sent[2], "phiallist")
  assert_eq("5d: no warnings on safe send", #warnings, 0)
end

print("=== Test 6: offensive gas pool excludes Halophilic ===")
do
  local F, warnings = make_world()
  load_phials(F, {
    "Phial658898 | Endorphin | -- | 1 | 1 | 1",
    "Phial475762 | Enhancement | -- | 1 | 1 | 2",
    "Phial454568 | Empty | -- | 1 | 1 | 1",
  })

  local cmd = F.build_role_amalgamate("gas", "halophilic")
  assert_eq("6a: halophilic blocked for offensive flex helper", cmd, nil)
  assert_eq("6b: warning calls out exclusion", warnings[#warnings], "Offensive gas flex pool excludes Halophilic.")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
