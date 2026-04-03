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
local ROOT_DIR = join_path(SCRIPT_DIR, "..", "..")
local AK_PATH = join_path(ROOT_DIR, "mudlet packages", "AK.xml")
local BASHER_PATH = join_path(ROOT_DIR, "mudlet packages", "Legacy Basher V2.1.xml")
local API_PATH = join_path(ROOT_DIR, "Occultist", "modules", "Yso", "Core", "api.lua")
local TATTOOS_PATH = join_path(ROOT_DIR, "Occultist", "modules", "Yso", "xml", "yso_target_tattoos.lua")
local SIGHTGATE_PATH = join_path(ROOT_DIR, "Occultist", "modules", "Yso", "xml", "sightgate.lua")
local PRONE_PATH = join_path(ROOT_DIR, "Occultist", "modules", "Yso", "xml", "pronecontroller.lua")

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

local function assert_contains(label, haystack, needle)
  if not tostring(haystack or ""):find(needle, 1, true) then
    fail(label, string.format("missing %s", needle))
    return
  end
  pass()
end

local function assert_not_contains(label, haystack, needle)
  if tostring(haystack or ""):find(needle, 1, true) then
    fail(label, string.format("unexpected %s", needle))
    return
  end
  pass()
end

local function count_occurrences(haystack, needle)
  local text = tostring(haystack or "")
  local want = tostring(needle or "")
  if want == "" then
    return 0
  end

  local idx = 1
  local count = 0
  while true do
    local s = text:find(want, idx, true)
    if not s then
      return count
    end
    count = count + 1
    idx = s + #want
  end
end

print("=== Test 1: static package remediation markers ===")
do
  local ak = read_all(AK_PATH)
  local basher = read_all(BASHER_PATH)
  local api = read_all(API_PATH)
  local sightgate = read_all(SIGHTGATE_PATH)
  local prone = read_all(PRONE_PATH)

  assert_not_contains("1a: AK no compslit typo", ak, "compslit")
  assert_not_contains("1b: AK no incata math bug", ak, "+ incata")
  assert_not_contains("1c: AK no stray targetrelay zero", ak, "0Targets:")
  assert_not_contains("1d: AK no classlock wsys branch", ak, "if ndba and wsys then")
  assert_not_contains("1e: AK no classlock svo branch", ak, "elseif svo and ndb then")
  assert_not_contains("1f: AK no raw reckless fallback insert", ak, "table.insert( classlock, \"reckless\" )")
  assert_not_contains("1g: Legacy Basher typo removed", basher, "BashercurrentTar")
  assert_contains("1h: API fallback uses wall clock", api, "os.time() * 1000")
  assert_not_contains("1i: API fallback no longer uses os.clock", api, "os.clock() * 1000")
  assert_contains("1j: sightgate honors slickness entity", sightgate, "ents.slickness or ents.asthma or \"bubonis\"")
  assert_not_contains("1k: pronecontroller no longer softscores aeon", prone, "softscore_affs = { \"aeon\"")
  assert_contains("1l: Legacy Basher has attack-package helper", basher, "function Legacy.Basher.queueAttackPackage(")
  assert_eq("1m: raw basher requeue send collapsed to helper", count_occurrences(basher, "send(\"queue add freestand basher\")"), 1)
  assert_eq("1n: raw big/small damage freestand sends collapsed", count_occurrences(basher, "send(\"queue add freestand \"..v.cmd)"), 0)
  assert_eq("1o: raw shieldbreak fallback freestand send collapsed", count_occurrences(basher, "send(\"queue addclear freestand \"..nr_cmd)"), 0)
end

print("\n=== Test 2: target sensory helpers read affstrack.score ===")
do
  function cecho() end
  function echo() end
  function getEpoch() return 1000 end

  _G.affstrack = { score = { deaf = 100, blind = 0 } }
  _G.Yso = { tgt = {} }
  _G.yso = _G.Yso

  dofile(TATTOOS_PATH)

  assert_false("2a: deaf target cannot hear without mindseye", Yso.tgt.can_hear("foe"))
  assert_true("2b: non-blind target can see without mindseye", Yso.tgt.can_see("foe"))

  affstrack.score.deaf = 0
  affstrack.score.blind = 100
  assert_true("2c: non-deaf target can hear", Yso.tgt.can_hear("foe"))
  assert_false("2d: blind target cannot see without mindseye", Yso.tgt.can_see("foe"))

  Yso.tgt.set_mindseye("foe", true, true)
  assert_true("2e: mindseye overrides deafness", Yso.tgt.can_hear("foe"))
  assert_true("2f: mindseye overrides blindness", Yso.tgt.can_see("foe"))
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
