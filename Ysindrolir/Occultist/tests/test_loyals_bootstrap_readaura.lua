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
local PARTY_AFF_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "routes", "party_aff.lua")
local OCC_AFF_BURST_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "Combat", "routes", "occ_aff_burst.lua")

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

local function assert_nil(label, got)
  if got ~= nil then
    fail(label, string.format("expected nil, got %s", tostring(got)))
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
  if got == true then
    fail(label, "expected false")
    return
  end
  pass()
end

local function get_upvalue(fn, wanted)
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return value end
  end
  error("missing upvalue: " .. tostring(wanted))
end

local function install_common_stubs()
  function getEpoch() return 1000 end
  function send() return true end
  function cecho() end
  function echo() end
  function tempAlias() return 1 end
  function tempTimer() return 1 end
  function killTimer() end
  function tempRegexTrigger() return 1 end
  function killTrigger() end
  function registerAnonymousEventHandler() return 1 end
  function killAnonymousEventHandler() end
  function selectString() return 0 end
  function resetFormat() end
  function deleteLine() end
  function deselect() end
  function getCurrentLine() return "" end
end

local function new_env(mode_name)
  install_common_stubs()

  local env = {
    aff_scores = {},
    aura_begins = {},
    recent_tags = {},
    readaura_ready_calls = {},
    snapshot = { fresh = true, read_complete = true },
    target = "spartarget",
    mental_score = 100,
    txn_status = { active = false, matched = false },
  }

  _G.gmcp = { Char = { Vitals = { eq = "1", bal = "1" } } }
  _G.ak = {}
  _G.affstrack = nil

  local mode = {
    is_hunt = function() return false end,
    is_party = function() return mode_name == "party" end,
    route_loop_active = function(route)
      if mode_name == "party" then return route == "party_aff" end
      if mode_name == "occ" then return route == "occ_aff_burst" end
      return false
    end,
  }
  if mode_name == "party" then
    mode.party_route = function() return "aff" end
  end

  _G.Yso = {
    sep = "&&",
    state = {},
    mode = mode,
    get_target = function() return env.target end,
    offense_paused = function() return false end,
    target_is_valid = function() return true end,
    loyals_attack = function(tgt)
      return _G.Yso.state.loyals_hostile == true and _G.Yso.state.loyals_target == tgt
    end,
    set_loyals_attack = function(hostile, tgt)
      _G.Yso.state.loyals_hostile = (hostile == true)
      _G.Yso.state.loyals_target = (hostile == true) and tgt or nil
    end,
    oc = {
      ak = {
        get_aff_score = function(aff)
          return env.aff_scores[tostring(aff or "")] or 0
        end,
        scores = {
          mental = function() return env.mental_score end,
        },
      },
    },
    occ = {
      aura_txn_status = function()
        return env.txn_status
      end,
      readaura_is_ready = function()
        return false
      end,
      aura_begin = function(tgt, why)
        env.aura_begins[#env.aura_begins + 1] = { target = tgt, why = why }
      end,
      set_readaura_ready = function(v, why)
        env.readaura_ready_calls[#env.readaura_ready_calls + 1] = { value = v, why = why }
      end,
      truebook = {
        can_utter = function() return false end,
      },
    },
    off = {
      state = {
        recent = function(tag)
          return env.recent_tags[tostring(tag or "")] == true
        end,
        note = function() return true end,
      },
      oc = {
        cleanseaura = {
          snapshot = function() return env.snapshot end,
        },
        entity_registry = {
          worm_should_refresh = function() return false end,
          syc_should_refresh = function() return false end,
          target_swap = function() end,
        },
      },
    },
  }
  _G.yso = _G.Yso

  return env
end

local function load_party_aff()
  local env = new_env("party")
  local lock_affs = {
    "asthma",
    "haemophilia",
    "addiction",
    "clumsiness",
    "healthleech",
    "weariness",
    "sensitivity",
    "manaleech",
  }
  for i = 1, #lock_affs do
    env.aff_scores[lock_affs[i]] = 100
  end

  dofile(PARTY_AFF_PATH)

  local PA = Yso.off.oc.party_aff
  PA.cfg.echo = false
  PA.cfg.attend_aff_floor = 99
  PA.cfg.mental_target = 3
  PA.reset("test")

  return {
    env = env,
    PA = PA,
    payload_line = get_upvalue(PA.attack_function, "_payload_line"),
    plan_eq = get_upvalue(PA.attack_function, "_plan_eq"),
    plan_free = get_upvalue(PA.attack_function, "_plan_free"),
  }
end

local function load_occ_aff_burst()
  local env = new_env("occ")

  dofile(OCC_AFF_BURST_PATH)

  local AB = Yso.off.oc.occ_aff_burst
  AB.cfg.echo = false
  AB.reset("test")

  local eq_plan = get_upvalue(AB.attack_function, "_eq_plan")
  return {
    env = env,
    AB = AB,
    eq_plan = eq_plan,
    payload_line = get_upvalue(AB.attack_function, "_payload_line"),
    loyals_open_cmd = get_upvalue(AB.attack_function, "_loyals_open_cmd"),
    bootstrap_readaura_plan = get_upvalue(eq_plan, "_bootstrap_readaura_plan"),
  }
end

do
  local T = load_party_aff()
  local tgt = T.env.target

  local free_cmd = select(1, T.plan_free(tgt))
  local eq_cmd = select(1, T.plan_eq(tgt, { loyals_bootstrap_pending = true }))
  assert_eq("party bootstrap free", free_cmd, ("order entourage kill %s"):format(tgt))
  assert_eq("party bootstrap eq", eq_cmd, ("readaura %s"):format(tgt))
  assert_eq(
    "party bootstrap line",
    T.payload_line({ lanes = { free = free_cmd, eq = eq_cmd, bal = nil, entity = nil } }),
    ("order entourage kill %s&&readaura %s"):format(tgt, tgt)
  )

  T.env.txn_status = { active = true, matched = true }
  assert_nil(
    "party bootstrap suppressed by active txn",
    select(1, T.plan_eq(tgt, { loyals_bootstrap_pending = true }))
  )

  T.env.txn_status = { active = false, matched = false }
  _G.gmcp.Char.Vitals.eq = "0"
  assert_nil(
    "party bootstrap suppressed when eq down",
    select(1, T.plan_eq(tgt, { loyals_bootstrap_pending = true }))
  )
  assert_eq("party free survives eq down", select(1, T.plan_free(tgt)), ("order entourage kill %s"):format(tgt))

  _G.gmcp.Char.Vitals.eq = "1"
  T.PA.state.loyals_sent_for = tgt
  assert_nil("party already-hostile skips free bootstrap", select(1, T.plan_free(tgt)))
  assert_nil(
    "party already-hostile does not force bootstrap readaura",
    select(1, T.plan_eq(tgt, { loyals_bootstrap_pending = false }))
  )

  T.PA.on_sent({
    target = tgt,
    lanes = {
      free = ("order entourage kill %s"):format(tgt),
      eq = ("readaura %s"):format(tgt),
    },
  }, { target = tgt })
  assert_eq("party on_sent marks loyals target", T.PA.state.loyals_sent_for, tgt)
  assert_eq("party on_sent aura_begin count", #T.env.aura_begins, 1)
  assert_eq("party on_sent aura_begin reason", T.env.aura_begins[1].why, "party_aff_send")
  assert_eq("party on_sent readaura_ready count", #T.env.readaura_ready_calls, 1)
  assert_false("party on_sent marks readaura not ready", T.env.readaura_ready_calls[1].value)
  assert_eq("party on_sent readaura reason", T.env.readaura_ready_calls[1].why, "sent")
end

do
  local T = load_occ_aff_burst()
  local tgt = T.env.target
  local plan = {
    loyals_bootstrap_pending = true,
    readaura_via_loyals = true,
    cleanseaura_ready = false,
    needs_mana_bury = false,
  }

  local free_cmd = select(1, T.loyals_open_cmd(tgt))
  local eq_cmd = select(1, T.eq_plan(tgt, plan, nil))
  assert_eq("occ bootstrap free", free_cmd, ("order entourage kill %s"):format(tgt))
  assert_eq("occ bootstrap eq", eq_cmd, ("readaura %s"):format(tgt))
  assert_eq(
    "occ bootstrap line",
    T.payload_line({ lanes = { free = free_cmd, eq = eq_cmd, bal = nil, entity = nil } }),
    ("order entourage kill %s&&readaura %s"):format(tgt, tgt)
  )

  T.env.txn_status = { active = true, matched = true }
  assert_nil(
    "occ bootstrap suppressed by active txn",
    select(1, T.bootstrap_readaura_plan(tgt, plan))
  )

  T.env.txn_status = { active = false, matched = false }
  _G.gmcp.Char.Vitals.eq = "0"
  assert_nil("occ bootstrap suppressed when eq down", select(1, T.eq_plan(tgt, plan, nil)))
  assert_eq("occ free survives eq down", select(1, T.loyals_open_cmd(tgt)), ("order entourage kill %s"):format(tgt))

  _G.gmcp.Char.Vitals.eq = "1"
  T.AB.state.loyals_sent_for = tgt
  assert_nil("occ already-hostile skips free bootstrap", select(1, T.loyals_open_cmd(tgt)))
  assert_nil(
    "occ already-hostile does not force bootstrap readaura",
    select(1, T.bootstrap_readaura_plan(tgt, {
      loyals_bootstrap_pending = false,
      readaura_via_loyals = true,
    }))
  )

  T.AB.state.explain = {}
  T.AB.on_sent({
    target = tgt,
    lanes = {
      free = ("order entourage kill %s"):format(tgt),
      eq = ("readaura %s"):format(tgt),
    },
    meta = {},
  }, { target = tgt })
  assert_eq("occ on_sent marks loyals target", T.AB.state.loyals_sent_for, tgt)
  assert_eq("occ on_sent aura_begin count", #T.env.aura_begins, 1)
  assert_eq("occ on_sent aura_begin reason", T.env.aura_begins[1].why, "occ_aff_burst_send")
  assert_eq("occ on_sent readaura_ready count", #T.env.readaura_ready_calls, 1)
  assert_false("occ on_sent marks readaura not ready", T.env.readaura_ready_calls[1].value)
  assert_eq("occ on_sent readaura reason", T.env.readaura_ready_calls[1].why, "sent")
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
