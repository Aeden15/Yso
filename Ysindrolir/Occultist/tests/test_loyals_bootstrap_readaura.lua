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
local ENTITY_REG_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "occultist", "entity_registry.lua")
local HELPERS_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "occultist", "offense_helpers.lua")
local OCC_AFF_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "routes", "occ_aff.lua")

local pass_count = 0
local fail_count = 0

local function fail(label, detail)
  fail_count = fail_count + 1
  io.stderr:write(string.format("FAIL: %s%s\n", label, detail and (" - " .. detail) or ""))
end

local function pass()
  pass_count = pass_count + 1
end

local function assert_true(label, got)
  if got ~= true then
    fail(label, string.format("expected true, got %s", tostring(got)))
    return
  end
  pass()
end

local function assert_false(label, got)
  if got == true then
    fail(label, string.format("expected false, got %s", tostring(got)))
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

local function assert_nil(label, got)
  if got ~= nil then
    fail(label, string.format("expected nil, got %s", tostring(got)))
    return
  end
  pass()
end

local function setup_world(opts)
  opts = opts or {}

  local timers = {}
  local emitted = {}
  local readaura_begins = 0
  local set_ready_calls = 0
  local convert_calls = 0
  local pressure_calls = 0
  local starting_attack_calls = 0

  function getEpoch() return 1000 end
  function send() return true end
  function cecho() end
  function echo() end
  function tempAlias() return 1 end
  function killAlias() end
  function tempRegexTrigger() return 1 end
  function killTrigger() end
  function registerAnonymousEventHandler() return 1 end
  function killAnonymousEventHandler() end
  function tempTimer(_, fn)
    timers[#timers + 1] = fn
    return #timers
  end

  _G.gmcp = { Char = { Vitals = { eq = "1", bal = "1" } } }
  _G.affstrack = { score = {} }

  local target = opts.target or "foe"
  local tgt_affs = opts.tgt_affs or {}
  local mana_pct = (opts.mana_pct == nil) and 30 or opts.mana_pct
  local aura_need_attend = (opts.aura_need_attend == true)

  local doms = {
    worm = { name = "worm", syntax = { "command worm at <target>" }, bal_cost = 2.0 },
    danaeus = { name = "storm", syntax = { "command storm at <target>" }, bal_cost = 2.0 },
    ninkharsag = { name = "slime", syntax = { "command slime at <target>" }, bal_cost = 2.0 },
    rixil = { name = "sycophant", syntax = { "command sycophant at <target>" }, bal_cost = 2.0 },
    nemesis = { name = "humbug", syntax = { "command humbug at <target>" }, bal_cost = 2.0 },
    pyradius = {
      name = "pyradius",
      syntax = { "command firelord at <target> <affliction>" },
      bal_cost = 2.0,
      converts = { whisperingmadness = "recklessness", manaleech = "anorexia", healthleech = "psychic_damage" },
    },
  }

  _G.Yso = {
    sep = "&&",
    waiting = { queue = "GLOBAL_WAIT" },
    class = "Occultist",
    state = {
      eq_ready = function() return opts.eq_ready ~= false end,
      bal_ready = function() return opts.bal_ready == true end,
      ent_ready = function() return opts.ent_ready ~= false end,
      tgt_has_aff = function(tgt, aff)
        if tostring(tgt):lower() ~= tostring(target):lower() then return false end
        return tgt_affs[tostring(aff):lower()] == true
      end,
    },
    target_is_valid = function() return opts.target_valid ~= false end,
    get_target = function() return target end,
    loyals_attack = function() return false end,
    set_loyals_attack = function() return true end,
    starting_attack = function()
      starting_attack_calls = starting_attack_calls + 1
      if type(((_G.Yso or {}).off or {}).oc) == "table" and type(((_G.Yso.off.oc or {}).occ_aff or {}).attack_function) ~= "function" then
        error("attack_function_not_defined")
      end
    end,
    tgt = {
      has_aff = function(tgt, aff)
        if tostring(tgt):lower() ~= tostring(target):lower() then return false end
        return tgt_affs[tostring(aff):lower()] == true
      end,
      get_mana_pct = function(tgt)
        if tostring(tgt):lower() ~= tostring(target):lower() then return nil end
        return mana_pct
      end,
    },
    oc = {
      ak = {
        scores = {
          mental = function() return tonumber(opts.mental_score or 0) or 0 end,
        },
      },
    },
    queue = {
      emit = function(payload)
        emitted[#emitted + 1] = payload
        if opts.emit_mode == "nil" then
          return nil
        end
        if opts.emit_mode == "false" then
          return false
        end
        if opts.emit_return ~= nil then
          return opts.emit_return
        end
        return true
      end,
    },
    off = {
      oc = {},
    },
    occ = {
      getDom = function(key)
        return doms[tostring(key or ""):lower()]
      end,
      aura_need_attend = function()
        return aura_need_attend
      end,
      aura_begin = function()
        readaura_begins = readaura_begins + 1
      end,
      set_readaura_ready = function()
        set_ready_calls = set_ready_calls + 1
      end,
      readaura_is_ready = function()
        if opts.readaura_ready == nil then return true end
        return opts.readaura_ready == true
      end,
      truebook = {
        can_utter = function()
          return opts.can_utter == true
        end,
      },
    },
  }
  _G.yso = _G.Yso

  dofile(ENTITY_REG_PATH)
  dofile(HELPERS_PATH)

  local orig_convert = Yso.occ.convert
  Yso.occ.convert = function(...)
    convert_calls = convert_calls + 1
    return orig_convert(...)
  end

  local orig_pressure = Yso.occ.pressure
  Yso.occ.pressure = function(...)
    pressure_calls = pressure_calls + 1
    return orig_pressure(...)
  end

  dofile(OCC_AFF_PATH)
  local AB = Yso.off.oc.occ_aff
  AB.cfg.echo = false
  AB.cfg.loop_delay = 1.0
  AB.init()

  local function run_timers()
    local pending = timers
    timers = {}
    for i = 1, #pending do
      local fn = pending[i]
      if type(fn) == "function" then fn() end
    end
  end

  return {
    AB = AB,
    emitted = emitted,
    run_timers = run_timers,
    target = target,
    tgt_affs = tgt_affs,
    set_mana = function(v) mana_pct = v end,
    set_aura_need_attend = function(v) aura_need_attend = (v == true) end,
    calls = {
      convert = function() return convert_calls end,
      pressure = function() return pressure_calls end,
      start = function() return starting_attack_calls end,
      aura_begin = function() return readaura_begins end,
      set_ready = function() return set_ready_calls end,
    },
  }
end

print("=== Test 1: helper surface exists and module load does not call starting_attack ===")
do
  local W = setup_world({ mana_pct = 50 })
  assert_eq("1a: starting_attack not called during load", W.calls.start(), 0)
  assert_true("1b: cleanse_ready exists", type(Yso.occ.cleanse_ready) == "function")
  assert_true("1c: ent_refresh exists", type(Yso.occ.ent_refresh) == "function")
  assert_true("1d: ent_for_aff exists", type(Yso.occ.ent_for_aff) == "function")
  assert_true("1e: firelord exists", type(Yso.occ.firelord) == "function")
  assert_true("1f: phase exists", type(Yso.occ.phase) == "function")
  assert_true("1g: set_phase exists", type(Yso.occ.set_phase) == "function")
  assert_true("1h: get_phase exists", type(Yso.occ.get_phase) == "function")
  assert_true("1i: burst exists", type(Yso.occ.burst) == "function")
  assert_true("1j: pressure exists", type(Yso.occ.pressure) == "function")
  assert_true("1k: convert exists", type(Yso.occ.convert) == "function")
end

print("\n=== Test 2: phase regression guard (cleanse -> pressure) ===")
do
  local W = setup_world({ mana_pct = 80 })
  Yso.occ.set_phase(W.target, "cleanse", "test")
  W.AB.state.phase_tgt = W.target:lower()
  local preview = W.AB.build_payload({ target = W.target })
  assert_true("2a: build_payload table", type(preview) == "table")
  assert_eq("2b: phase falls back to pressure", Yso.occ.get_phase(W.target), "pressure")
end

print("\n=== Test 3: convert guard does not run before convert/finish ===")
do
  local W = setup_world({ mana_pct = 80 })
  Yso.occ.set_phase(W.target, "pressure", "test")
  W.AB.state.phase_tgt = W.target:lower()
  W.AB.state.last_readaura = 1000
  local preview = W.AB.build_payload({ target = W.target })
  assert_true("3a: preview generated", type(preview) == "table")
  assert_eq("3b: convert not called in pressure", W.calls.convert(), 0)

  Yso.occ.set_phase(W.target, "convert", "test")
  W.AB.state.last_readaura = 1000
  preview = W.AB.build_payload({ target = W.target })
  assert_true("3c: preview generated in convert", type(preview) == "table")
  assert_true("3d: convert called in convert phase", W.calls.convert() > 0)
end

print("\n=== Test 4: cleanse attend precedence over pressure filler ===")
do
  local W = setup_world({ mana_pct = 25, aura_need_attend = true, can_utter = false, bal_ready = true })
  Yso.occ.set_phase(W.target, "cleanse", "test")
  W.AB.state.phase_tgt = W.target:lower()
  local preview = W.AB.build_payload({ target = W.target })
  assert_eq("4a: attend owns EQ in cleanse", preview.lanes.eq, "attend " .. W.target)
  assert_true("4b: pressure helper not used in cleanse branch", W.calls.pressure() == 0)
  assert_eq("4c: deferred bal followup present", preview.lanes.bal, "unnamable speak")
end

print("\n=== Test 5: target-side enlightened transitions to finish ===")
do
  local W = setup_world({ mana_pct = 25, tgt_affs = { enlightened = true } })
  Yso.occ.set_phase(W.target, "convert", "test")
  W.AB.state.phase_tgt = W.target:lower()
  local preview = W.AB.build_payload({ target = W.target })
  assert_true("5a: preview generated", type(preview) == "table")
  assert_eq("5b: phase transitioned to finish", Yso.occ.get_phase(W.target), "finish")
end

print("\n=== Test 6: local wait/dedup only, no global waiting mutation ===")
do
  local W = setup_world({ mana_pct = 80, emit_return = true })
  Yso.occ.set_phase(W.target, "pressure", "test")
  W.AB.state.phase_tgt = W.target:lower()

  local sent1 = W.AB.attack_function()
  assert_true("6a: first emit succeeds", sent1 == true)
  assert_true("6b: route-local waiting set", tostring(W.AB.state.waiting.queue or "") ~= "")
  assert_eq("6c: global waiting unchanged", tostring((Yso.waiting or {}).queue), "GLOBAL_WAIT")

  local sent2 = W.AB.attack_function()
  assert_false("6d: second tick blocked by local wait", sent2 == true)

  W.run_timers()
  assert_nil("6e: local wait clears via timer", W.AB.state.waiting.queue)
end

print("\n=== Test 7: emit failure (nil/false) fails closed without waiting state ===")
do
  local Wnil = setup_world({ mana_pct = 80, emit_mode = "nil" })
  Yso.occ.set_phase(Wnil.target, "pressure", "test")
  Wnil.AB.state.phase_tgt = Wnil.target:lower()
  local sent_nil = Wnil.AB.attack_function()
  assert_false("7a: nil emit return treated as failure", sent_nil == true)
  assert_nil("7b: nil emit does not set waiting", Wnil.AB.state.waiting.queue)

  local Wfalse = setup_world({ mana_pct = 80, emit_mode = "false" })
  Yso.occ.set_phase(Wfalse.target, "pressure", "test")
  Wfalse.AB.state.phase_tgt = Wfalse.target:lower()
  local sent_false = Wfalse.AB.attack_function()
  assert_false("7c: false emit return treated as failure", sent_false == true)
  assert_nil("7d: false emit does not set waiting", Wfalse.AB.state.waiting.queue)
end

print("\n=== Test 8: readaura fallback path remains active ===")
do
  local W = setup_world({ mana_pct = 25, aura_need_attend = false, readaura_ready = true, can_utter = false })
  Yso.occ.set_phase(W.target, "cleanse", "test")
  W.AB.state.phase_tgt = W.target:lower()
  W.AB.state.last_readaura = 0
  local preview = W.AB.build_payload({ target = W.target })
  assert_true("8a: cleanse path still issues eq action", type(preview.lanes.eq) == "string" and preview.lanes.eq ~= "")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
