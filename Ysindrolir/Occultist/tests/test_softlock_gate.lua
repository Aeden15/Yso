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
local SOFTLOCK_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "occultist", "softlock_gate.lua")

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

local function assert_true(label, got)
  if got ~= true then
    fail(label, string.format("expected true, got %s", tostring(got)))
    return
  end
  pass()
end

local function assert_false(label, got)
  if got ~= false then
    fail(label, string.format("expected false, got %s", tostring(got)))
    return
  end
  pass()
end

local function assert_nil(label, got)
  if got ~= nil then
    fail(label, string.format("expected nil, got %s", tostring(got)))
    return
  end
  pass()
end

local function assert_contains(label, haystack, needle)
  haystack = tostring(haystack or "")
  needle = tostring(needle or "")
  if haystack:find(needle, 1, true) == nil then
    fail(label, string.format("expected to find %q in %q", needle, haystack))
    return
  end
  pass()
end

local function assert_not_contains(label, haystack, needle)
  haystack = tostring(haystack or "")
  needle = tostring(needle or "")
  if haystack:find(needle, 1, true) ~= nil then
    fail(label, string.format("did not expect %q in %q", needle, haystack))
    return
  end
  pass()
end

local function count_keys(tbl)
  local n = 0
  for _ in pairs(tbl or {}) do
    n = n + 1
  end
  return n
end

local function get_upvalue(fn, wanted)
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return value end
  end
  error("missing upvalue: " .. tostring(wanted))
end

local function make_world(opts)
  opts = opts or {}

  local logs = {}
  local queue_calls = {}
  local orig_calls = { count = 0 }
  local state = { target = opts.target or "target" }

  function getEpoch() return 1000 end
  function send() return true end
  function echo() end
  function tempAlias() return 1 end
  function tempTimer() return 1 end
  function killTimer() end
  function tempRegexTrigger() return 1 end
  function killTrigger() end
  function registerAnonymousEventHandler() return 1 end
  function killAnonymousEventHandler() return 1 end
  function selectString() return 0 end
  function resetFormat() end
  function deleteLine() end
  function deselect() end
  function getCurrentLine() return "" end
  function expandAlias() end
  function cecho(msg)
    logs[#logs + 1] = tostring(msg or "")
  end

  _G.gmcp = {
    Char = {
      Vitals = {
        eq = "1",
        bal = "1",
        position = "standing",
      },
    },
  }
  _G.affstrack = nil

  local Yso = {
    sep = "&&",
    state = {},
    get_target = function()
      return state.target
    end,
    offense_paused = function()
      return false
    end,
    target_is_valid = function()
      return true
    end,
    occ = {
      aura_txn_status = function()
        return { active = false, matched = false }
      end,
      readaura_is_ready = function()
        return false
      end,
      aura_begin = function() end,
      set_readaura_ready = function() end,
      truebook = {
        can_utter = function()
          return false
        end,
      },
    },
    off = {
      state = {
        recent = function()
          return false
        end,
        note = function()
          return true
        end,
      },
      oc = {},
    },
  }

  if opts.preload_queue then
    Yso.queue = {
      addclear = function(qtype, piped)
        queue_calls[#queue_calls + 1] = { qtype = qtype, piped = piped }
        return true
      end,
    }
  end

  if opts.preload_try_kelp_bury then
    Yso.off.oc.try_kelp_bury = function(t, afftbl)
      orig_calls.count = orig_calls.count + 1
      return string.format("orig:%s", tostring(t))
    end
  end

  if opts.preload_phase then
    Yso.off.oc.phase = function(t, afftbl)
      return "UNRAVEL"
    end
  end

  _G.Yso = Yso
  _G.yso = Yso

  dofile(SOFTLOCK_PATH)

  local off = Yso.off.oc
  off.cfg.softlock_gate = off.cfg.softlock_gate or {}

  return {
    logs = logs,
    queue_calls = queue_calls,
    orig_calls = orig_calls,
    state = state,
    Yso = Yso,
    off = off,
  }
end

local function attach_queue(world)
  world.Yso.queue = {
    addclear = function(qtype, piped)
      world.queue_calls[#world.queue_calls + 1] = { qtype = qtype, piped = piped }
      return true
    end,
  }
end

local function softscore_fn(off)
  local softlock_ready = get_upvalue(off.try_softlock_setup, "_softlock_ready")
  return get_upvalue(softlock_ready, "_softscore")
end

print("=== Test 1: _softscore ignores _G.softscore ===")
do
  local world = make_world({ preload_queue = true, preload_try_kelp_bury = true, target = "alpha" })
  _G.softscore = 99
  local softscore = softscore_fn(world.off)
  local got = softscore({ asthma = 100, slickness = 100, anorexia = 0 })
  assert_eq("1: local aff score wins", got, 2)
  _G.softscore = nil
end

print("\n=== Test 2: late-bound queue works after module load ===")
do
  local world = make_world({ preload_queue = false, preload_try_kelp_bury = true, target = "beta" })
  attach_queue(world)
  world.off.cfg.softlock_gate.keep_paralysis = true
  local ok = world.off.try_softlock_setup("beta", { asthma = 0, slickness = 0, anorexia = 0 })
  assert_true("2: setup queued once queue exists", ok)
  assert_true("2: queue called", #world.queue_calls > 0)
end

print("\n=== Test 3: current-target-only cleanup on target switch ===")
do
  local world = make_world({ preload_queue = true, preload_try_kelp_bury = true, target = "alpha" })
  world.off.cfg.softlock_gate.keep_paralysis = true

  local ready = { asthma = 100, slickness = 100, anorexia = 0 }
  assert_false("3a: ready gate returns false", world.off.try_softlock_setup("alpha", ready))
  assert_eq("3b: alpha marked done", world.off._softlock_done.alpha, true)

  world.state.target = "beta"
  local not_ready = { asthma = 0, slickness = 0, anorexia = 0 }
  world.off.try_softlock_setup("beta", not_ready)
  assert_nil("3c: alpha state cleared on target switch", world.off._softlock_done.alpha)
  assert_eq("3d: only current target retained", count_keys(world.off._softlock_done), 1)
end

print("\n=== Test 4: keep_paralysis = true preserves paralysis filler ===")
do
  local world = make_world({ preload_queue = true, preload_try_kelp_bury = true, target = "gamma" })
  world.off.cfg.softlock_gate.keep_paralysis = true
  local ok = world.off.try_softlock_setup("gamma", { asthma = 0, slickness = 0, anorexia = 0 })
  assert_true("4a: softlock queued", ok)
  assert_true("4b: queued command exists", #world.queue_calls > 0)
  assert_contains("4c: paralysis filler used", world.queue_calls[1].piped, "instill gamma with paralysis")
end

print("\n=== Test 5: keep_paralysis = false uses branch-specific filler ===")
do
  local asthma_world = make_world({ preload_queue = true, preload_try_kelp_bury = true, target = "delta" })
  asthma_world.off.cfg.softlock_gate.keep_paralysis = false
  local ok = asthma_world.off.try_softlock_setup("delta", { asthma = 0, slickness = 0, anorexia = 0 })
  assert_true("5a: asthma branch queued", ok)
  assert_contains("5b: asthma branch uses asthma filler", asthma_world.queue_calls[1].piped, "instill delta with asthma")
  assert_not_contains("5c: asthma branch does not use paralysis", asthma_world.queue_calls[1].piped, "paralysis")

  local slick_world = make_world({ preload_queue = true, preload_try_kelp_bury = true, target = "epsilon" })
  slick_world.off.cfg.softlock_gate.keep_paralysis = false
  slick_world.off.cfg.softlock_gate.slickness_via_bubonis_followup = true
  local ok2 = slick_world.off.try_softlock_setup("epsilon", { asthma = 100, slickness = 0, anorexia = 0 })
  assert_true("5d: slickness branch queued", ok2)
  assert_contains("5e: slickness branch uses slickness filler", slick_world.queue_calls[1].piped, "instill epsilon with slickness")
  assert_not_contains("5f: slickness branch does not use paralysis", slick_world.queue_calls[1].piped, "paralysis")
end

print("\n=== Test 6: try_kelp_bury defers to softlock setup until ready ===")
do
  local world = make_world({ preload_queue = true, preload_try_kelp_bury = true, target = "zeta" })
  world.off.cfg.softlock_gate.keep_paralysis = true

  local not_ready = { asthma = 0, slickness = 0, anorexia = 0 }
  local ret = world.off.try_kelp_bury("zeta", not_ready)
  assert_eq("6a: wrapper returns true while deferring", ret, true)
  assert_eq("6b: original kelp-bury not called", world.orig_calls.count, 0)
  assert_true("6c: softlock queued before kelp-bury", #world.queue_calls > 0)

  local ready = { asthma = 100, slickness = 100, anorexia = 0 }
  local ret2 = world.off.try_kelp_bury("zeta", ready)
  assert_eq("6d: original kelp-bury called once gate ready", world.orig_calls.count, 1)
  assert_eq("6e: wrapper returns original result", ret2, "orig:zeta")
end

print("\n=== Test 7: missing hooks stay pending without startup warning ===")
do
  local world = make_world({ preload_queue = true, preload_try_kelp_bury = false, target = "eta" })
  local text = table.concat(world.logs, "\n")
  assert_eq("7a: install pending when no hook target exists", world.off._softlock_gate_pending, true)
  assert_not_contains("7b: no eager missing-hook warning", text, "Off.try_kelp_bury not found")
end

print("\n=== Test 8: phase wrapper installs and forces SOFTLOCK_SETUP until ready ===")
do
  local world = make_world({ preload_queue = true, preload_try_kelp_bury = false, preload_phase = true, target = "theta" })
  assert_eq("8a: phase-wrapper mode selected", world.off._softlock_gate_mode, "phase_wrapper")

  local p1 = world.off.phase("theta", { asthma = 0, slickness = 0, anorexia = 0 })
  assert_eq("8b: not-ready target forced into softlock setup", p1, "SOFTLOCK_SETUP")

  local p2 = world.off.phase("theta", { asthma = 100, slickness = 100, anorexia = 0 })
  assert_eq("8c: ready target falls through to original phase", p2, "UNRAVEL")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
