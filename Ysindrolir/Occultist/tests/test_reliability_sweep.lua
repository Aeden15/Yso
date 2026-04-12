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
local OFFENSE_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "offense_driver.lua")
local QUEUE_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Core", "queue.lua")
local HINDER_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "hinder.lua")
local ENTITIES_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "entities.lua")
local TARGETING_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "xml", "yso_targeting.lua")

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

local function assert_eq(label, got, expected)
  if got ~= expected then
    fail(label, string.format("expected %s, got %s", tostring(expected), tostring(got)))
    return
  end
  pass()
end

local function read_all(path)
  local fh = assert(io.open(path, "rb"))
  local data = fh:read("*a")
  fh:close()
  return data
end

print("=== Test 1: offense_driver dead-clear callback guard present ===")
do
  local src = read_all(OFFENSE_PATH)
  assert_true("1a: stale timer id guard is present", src:find("if C%._tm%.dead_clear ~= my_id then return end") ~= nil)
end

print("\n=== Test 2: offense_driver toggle rolls back on pulse wake error ===")
do
  _G.cecho = function() end
  _G.echo = function() end
  _G.getEpoch = function() return 1000 end
  _G.tempRegexTrigger = function() return 1 end
  _G.tempAlias = function() return 1 end
  _G.registerAnonymousEventHandler = function() return 1 end
  _G.killTrigger = function() end
  _G.killAlias = function() end
  _G.killAnonymousEventHandler = function() end

  _G.Yso = {
    util = { now = function() return 1000 end },
    off = { oc = {} },
    pulse = {
      wake = function()
        error("wake failed")
      end,
    },
  }
  _G.yso = _G.Yso

  dofile(OFFENSE_PATH)
  local D = Yso.off.driver

  D.state.enabled = false
  D.cfg.enabled = false
  local toggled = D.toggle(true)
  assert_eq("2a: toggle returned rolled-back state", toggled, false)
  assert_eq("2b: driver state rolled back", D.state.enabled, false)
  assert_eq("2c: driver cfg rolled back", D.cfg.enabled, false)
end

print("\n=== Test 3: queue.flush_staged clears all staged lanes ===")
do
  _G.send = function() return true end
  _G.cecho = function() end
  _G.echo = function() end
  _G.getEpoch = function() return 1000 end
  _G.Yso = {
    util = { now = function() return 1000 end },
    cfg = { cmd_sep = "&&", pipe_sep = "&&" },
    net = { cfg = { dry_run = false } },
    state = {
      eq_ready = function() return true end,
      bal_ready = function() return true end,
      ent_ready = function() return true end,
    },
  }
  _G.yso = _G.Yso

  dofile(QUEUE_PATH)
  local Q = Yso.queue

  Q.stage("free", "touch tree")
  Q.stage("eq", "instill foe with asthma")
  Q.stage("bal", "fling fool at me")
  Q.stage("class", "command worm at foe")
  assert_true("3a: flush_staged exists", type(Q.flush_staged) == "function")
  Q.flush_staged()
  assert_eq("3b: free cleared", #Q.list("free"), 0)
  assert_eq("3c: eq cleared", Q.list("eq"), nil)
  assert_eq("3d: bal cleared", Q.list("bal"), nil)
  assert_eq("3e: class cleared", Q.list("class"), nil)
end

print("\n=== Test 4: hinder.reset clears snapshot and lane block flags ===")
do
  _G.Yso = {
    util = { now = function() return 1000 end },
  }
  _G.yso = _G.Yso

  dofile(HINDER_PATH)
  local H = Yso.hinder

  H.state.snapshot = { at = 999 }
  H.state.lane_blocked = { eq = true, bal = true }
  H.reset("unit")
  assert_eq("4a: snapshot reset", H.state.snapshot, nil)
  assert_eq("4b: eq lane reset", H.state.lane_blocked.eq, false)
  assert_eq("4c: bal lane reset", H.state.lane_blocked.bal, false)
end

print("\n=== Test 5: entities hooks uninstall and reinstall cleanly ===")
do
  local trig_id = 0
  local killed = {}
  _G.tempRegexTrigger = function(_, _)
    trig_id = trig_id + 1
    return trig_id
  end
  _G.killTrigger = function(id)
    killed[#killed + 1] = id
    return true
  end
  _G.Yso = {
    util = { now = function() return 1000 end },
    off = { oc = { entity_registry = { note_worm_proc = function() end } } },
  }
  _G.yso = _G.Yso

  dofile(ENTITIES_PATH)
  local E = Yso.entities

  assert_true("5a: install hooks", E.install_hooks())
  local first = E._hook_ids and E._hook_ids.worm_chew or nil
  assert_true("5b: first hook id captured", first ~= nil)
  assert_true("5c: uninstall hooks", E.uninstall_hooks())
  assert_eq("5d: hooks_installed reset", E.state.hooks_installed, false)
  assert_eq("5e: hook id cleared", E._hook_ids.worm_chew, nil)
  assert_eq("5f: first hook kill recorded", killed[1], first)
  assert_true("5g: reinstall hooks", E.install_hooks())
  local second = E._hook_ids and E._hook_ids.worm_chew or nil
  assert_true("5h: reinstall produced new id", second ~= nil and second ~= first)
end

print("\n=== Test 6: targeting reset hooks run on swap and clear ===")
do
  local flush_calls = 0
  local unblock_calls = 0
  local hinder_resets = 0

  _G.tempRegexTrigger = function() return 1 end
  _G.tempAlias = function() return 1 end
  _G.killTrigger = function() end
  _G.killAlias = function() end
  _G.send = function() return true end
  _G.expandAlias = function() end
  _G.echo = function() end
  _G.getEpoch = function() return 1000 end

  _G.Yso = {
    queue = {
      flush_staged = function()
        flush_calls = flush_calls + 1
      end,
      unblock_lane = function(_, _, _)
        unblock_calls = unblock_calls + 1
      end,
    },
    hinder = {
      reset = function(_)
        hinder_resets = hinder_resets + 1
      end,
    },
  }
  _G.yso = _G.Yso

  dofile(TARGETING_PATH)
  local TG = Yso.targeting
  TG.set("alpha", "manual", { silent = true })
  TG.set("beta", "manual", { silent = true })
  TG.clear("manual", "unit", true)

  assert_eq("6a: flush called on swap + clear", flush_calls, 2)
  assert_eq("6b: unblock eq/bal called on swap + clear", unblock_calls, 4)
  assert_eq("6c: hinder.reset called on swap + clear", hinder_resets, 2)
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
