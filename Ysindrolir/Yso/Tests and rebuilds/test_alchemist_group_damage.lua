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
local PHYS_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Core", "physiology.lua")
local TRIGGER_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Triggers", "Alchemy", "Physiology", "humour_balance.lua")
local ROUTE_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Core", "group damage.lua")
local WRAP_GROUP = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "alchemist_group_damage.lua")
local WRAP_DUEL = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "alchemist_duel_route.lua")

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

local function assert_true(label, cond)
  if cond ~= true then
    fail(label, "expected true")
    return
  end
  pass()
end

local function assert_false(label, cond)
  if cond ~= false then
    fail(label, "expected false")
    return
  end
  pass()
end

local function contains_text(list, text)
  for i = 1, #list do
    if tostring(list[i] or ""):find(text, 1, true) then
      return true
    end
  end
  return false
end

local function scores(src)
  return setmetatable(src or {}, { __index = function() return 0 end })
end

local function make_route_world(opts)
  opts = opts or {}
  local now_s = tonumber(opts.now_s or 1000) or 1000
  local current_target = opts.target or "TargetOne"
  local sent = {}
  local emitted = {}
  local staged = {}
  local committed = {}
  local clear_all_calls = {}

  _G.Yso = nil
  _G.yso = nil
  _G.target = current_target
  _G.matches = {}
  _G.getCurrentLine = function() return "" end
  _G.getEpoch = function() return now_s * 1000 end
  _G.cecho = function() end
  _G.echo = function() end
  _G.send = function(cmd)
    sent[#sent + 1] = cmd
    return true
  end

  _G.gmcp = {
    Char = {
      Status = { class = "Alchemist" },
      Vitals = { eq = "1", equilibrium = "1", bal = "1", balance = "1" },
    },
  }

  local homunculus_state = { active = false, target = "" }

  local stub_P = {
    target = function(name) return { name = name } end,
    target_needs_evaluate = function() return opts.needs_eval == true end,
    note_evaluate_request = function() return true end,
    reave_sync_target = function() return false end,
    clear_staged_for_target = function() return true end,
    can_aurify = function() return opts.can_aurify == true end,
    can_reave = function()
      if opts.can_reave == true then
        return true, { legal = true }
      end
      return false, { legal = false }
    end,
    fire_reave = function(name)
      sent[#sent + 1] = "reave " .. tostring(name or "")
      return true
    end,
    pick_temper_humour = function()
      return opts.temper_humour
    end,
    build_truewrack_with_staged = function(_, _, staged_info)
      if opts.require_staged == true and (not staged_info or staged_info.temper_humour ~= opts.temper_humour) then
        return nil
      end
      return opts.truewrack_cmd
    end,
    build_wrack_fallback_with_staged = function(_, _, staged_info)
      if opts.require_staged == true and (not staged_info or staged_info.temper_humour ~= opts.temper_humour) then
        return nil
      end
      return opts.wrack_cmd
    end,
    build_truewrack = function()
      return opts.truewrack_cmd
    end,
    build_wrack_fallback = function()
      return opts.wrack_cmd
    end,
    current_humour_count = function(_, humour)
      humour = tostring(humour or ""):lower()
      return (opts.humours and opts.humours[humour]) or 0
    end,
    health_pct = function() return opts.hp end,
    mana_pct = function() return opts.mp end,
    alchemy_debuff_active = function()
      if opts.vitri_active == true then
        return true, "vitrification", {}
      end
      return false, nil, nil
    end,
    clear_all_humours = function(tgt, reason)
      clear_all_calls[#clear_all_calls + 1] = { tgt = tgt, reason = reason }
      return true
    end,
  }

  _G.Yso = {
    cfg = { UseQueueing = opts.use_queueing, pipe_sep = "&&" },
    Combat = {
      RouteInterface = {
        ensure_hooks = function() return true end,
      },
    },
    off = {
      alc = {},
      core = {
        register = function() return true end,
      },
    },
    util = {
      now = function() return now_s end,
    },
    state = {
      eq_ready = function() return opts.eq_ready ~= false end,
      bal_ready = function() return opts.bal_ready ~= false end,
    },
    bal = {
      humour = opts.class_ready ~= false,
      evaluate = true,
      homunculus = opts.homunculus_ready ~= false,
    },
    alc = {
      phys = stub_P,
    },
    mode = {
      is_party = function() return true end,
      party_route = function() return "dam" end,
      route_loop_active = function(id) return id == "alchemist_group_damage" end,
      schedule_route_loop = function(id) staged[#staged + 1] = "schedule:" .. tostring(id); return true end,
    },
    get_target = function() return current_target end,
    target_is_valid = function(who) return tostring(who or "") ~= "" end,
    offense_paused = function() return false end,
    shield = {
      up = function() return opts.shielded == true end,
    },
    set_homunculus_attack = function(v, tgt)
      homunculus_state.active = (v == true)
      homunculus_state.target = (v == true) and tostring(tgt or "") or ""
      return homunculus_state.active
    end,
    homunculus_attack = function(tgt)
      if homunculus_state.active ~= true then
        return false
      end
      tgt = tostring(tgt or "")
      if tgt == "" then
        return true
      end
      return homunculus_state.target:lower() == tgt:lower()
    end,
  }
  _G.yso = _G.Yso

  _G.Yso.alc.set_humour_ready = function(ready)
    _G.Yso.bal.humour = (ready == true)
    return _G.Yso.bal.humour
  end
  _G.Yso.alc.humour_ready = function()
    return _G.Yso.bal.humour ~= false
  end
  _G.Yso.alc.set_evaluate_ready = function(ready)
    _G.Yso.bal.evaluate = (ready == true)
    return _G.Yso.bal.evaluate
  end
  _G.Yso.alc.evaluate_ready = function()
    return _G.Yso.bal.evaluate ~= false
  end
  _G.Yso.alc.set_homunculus_ready = function(ready)
    _G.Yso.bal.homunculus = (ready == true)
    return _G.Yso.bal.homunculus
  end
  _G.Yso.alc.homunculus_ready = function()
    return _G.Yso.bal.homunculus ~= false
  end

  if opts.self_affs then
    _G.Yso.affs = {}
    for k, v in pairs(opts.self_affs) do
      _G.Yso.affs[k] = v
    end
  end

  if opts.use_emit == true then
    _G.Yso.emit = function(payload)
      emitted[#emitted + 1] = payload
      return true
    end
  end

  if opts.queue_mode == true then
    _G.Yso.queue = {
      can_plan_lane = function() return true end,
      stage = function(lane, cmd)
        staged[#staged + 1] = lane .. ":" .. tostring(cmd)
        return true
      end,
      commit = function()
        committed[#committed + 1] = true
        return true
      end,
    }
  else
    _G.Yso.queue = { can_plan_lane = function() return true end }
  end

  _G.ak = {
    defs = {
      shield_by_target = {
        [string.lower(current_target)] = (opts.shielded == true),
      },
      shield = (opts.shielded == true),
    },
  }

  dofile(ROUTE_PATH)

  local R = _G.Yso.off.alc.group_damage
  R.init()
  R.cfg.enabled = true
  R.state.enabled = true
  R.state.loop_enabled = true

  return {
    R = R,
    sent = sent,
    emitted = emitted,
    staged = staged,
    committed = committed,
    clear_all_calls = clear_all_calls,
    set_target = function(t)
      current_target = t
      _G.target = t
    end,
  }
end

local function make_phys_world(opts)
  opts = opts or {}
  local now_s = tonumber(opts.now_s or 2000) or 2000
  local current_target = opts.target or "TargetOne"

  _G.Yso = nil
  _G.yso = nil
  _G.target = current_target
  _G.getEpoch = function() return now_s * 1000 end
  _G.getCurrentLine = function() return "" end
  _G.cecho = function() end
  _G.echo = function() end
  _G.send = function() return true end

  _G.ak = {
    alchemist = {
      humour = {
        choleric = 0,
        melancholic = 0,
        phlegmatic = 0,
        sanguine = 0,
      },
    },
  }

  _G.Yso = {
    get_target = function() return current_target end,
    target = current_target,
    bal = { humour = true, evaluate = true, homunculus = true },
    util = { now = function() return now_s end },
    self = {
      has_aff = function() return false end,
      is_prone = function() return false end,
      list_writhe_affs = function() return {} end,
      is_writhed = function() return false end,
    },
    tgt = {
      has_aff = function() return false end,
    },
    queue = {
      list = function() return nil end,
      clear = function() return true end,
      stage = function() return true end,
    },
  }
  _G.yso = _G.Yso

  dofile(PHYS_PATH)
  dofile(TRIGGER_PATH)

  local P = _G.Yso.alc.phys
  P.begin_evaluate(current_target)
  P.finish_evaluate(current_target)
  P.note_evaluate_vitals(current_target, tonumber(opts.hp or 80), tonumber(opts.mp or 80))

  return {
    P = P,
    set_target = function(t)
      current_target = t
      _G.target = t
      _G.Yso.target = t
    end,
  }
end

print("=== Test 1: lifecycle homunculus bootstrap + stop pacify ===")
do
  local world = make_route_world({
    temper_humour = "choleric",
    wrack_cmd = "wrack TargetOne paralysis",
    use_queueing = "NO",
  })
  local R = world.R

  R.start()
  local p1 = R.build_payload({ target = "TargetOne" })
  assert_true("1a: first payload includes homunculus attack", tostring(p1 and p1.free or ""):find("homunculus attack TargetOne", 1, true) ~= nil)

  local p2 = R.build_payload({ target = "TargetOne" })
  local free2 = tostring(p2 and p2.free or "")
  assert_false("1b: same target does not resend homunculus attack", free2:find("homunculus attack TargetOne", 1, true) ~= nil)

  world.set_target("TargetTwo")
  local p3 = R.build_payload({ target = "TargetTwo" })
  assert_true("1c: target swap re-arms homunculus attack", tostring(p3 and p3.free or ""):find("homunculus attack TargetTwo", 1, true) ~= nil)

  R.stop("test")
  assert_true("1d: stop sends homunculus pacify", contains_text(world.sent, "homunculus pacify"))
  assert_false("1e: stop never sends homunculus passive", contains_text(world.sent, "homunculus passive"))
end

print("\n=== Test 2: shieldbreak compound payload logic ===")
do
  local world = make_route_world({
    shielded = true,
    temper_humour = "choleric",
    wrack_cmd = "wrack TargetOne paralysis",
  })
  local payload = world.R.build_payload({ target = "TargetOne" })
  assert_eq("2a: shieldbreak uses copper", payload and payload.eq, "educe copper TargetOne")
  assert_eq("2b: shieldbreak keeps class temper", payload and payload.class, "temper TargetOne choleric")
  assert_eq("2c: shieldbreak keeps bal wrack", payload and payload.bal, "wrack TargetOne paralysis")
  assert_true("2d: shieldbreak not copper-only when follow-ups legal", payload and payload.class ~= nil and payload.bal ~= nil)
end

do
  local world = make_route_world({ shielded = true, class_ready = false, bal_ready = false })
  local payload = world.R.build_payload({ target = "TargetOne" })
  assert_eq("2e: copper-only fallback when no legal follow-up", payload and payload.eq, "educe copper TargetOne")
  assert_eq("2f: no class follow-up", payload and payload.class, nil)
  assert_eq("2g: no bal follow-up", payload and payload.bal, nil)
end

print("\n=== Test 3: aurify/reave shield gate + salt ordering ===")
do
  local shield_world = make_route_world({ shielded = true, can_aurify = true })
  local p_shield = shield_world.R.build_payload({ target = "TargetOne" })
  assert_eq("3a: aurify blocked by shieldbreak", p_shield and p_shield.eq, "educe copper TargetOne")

  local ik_world = make_route_world({ can_aurify = true, self_affs = { paralysis = true, asthma = true, impatience = true } })
  local p_ik = ik_world.R.build_payload({ target = "TargetOne" })
  assert_eq("3b: salt does not override aurify window", p_ik and p_ik.eq, "aurify TargetOne")

  local salt_world = make_route_world({ self_affs = { paralysis = true, asthma = true }, class_ready = false, bal_ready = false })
  local p_salt = salt_world.R.build_payload({ target = "TargetOne" })
  assert_eq("3c: salt fires after shield/IK fail", p_salt and p_salt.eq, "educe salt")
  assert_eq("3d: salt payload has no bal", p_salt and p_salt.bal, nil)

  local stup_world = make_route_world({ self_affs = { paralysis = true, asthma = true, stupidity = true }, class_ready = false, bal_ready = false })
  local p_stup = stup_world.R.build_payload({ target = "TargetOne" })
  assert_false("3e: salt blocked by stupidity", p_stup and p_stup.eq == "educe salt")
end

print("\n=== Test 4: normal pressure + inundate constraints ===")
do
  local world = make_route_world({
    temper_humour = "melancholic",
    wrack_cmd = "wrack TargetOne impatience",
    hp = 99,
    mp = 99,
  })
  local payload = world.R.build_payload({ target = "TargetOne" })
  assert_eq("4a: normal pressure class temper", payload and payload.class, "temper TargetOne melancholic")
  assert_eq("4b: normal pressure eq iron", payload and payload.eq, "educe iron TargetOne")
  assert_eq("4c: normal pressure bal wrack", payload and payload.bal, "wrack TargetOne impatience")
end

do
  local world = make_route_world({
    humours = { choleric = 6 },
    hp = 70,
    class_ready = true,
    bal_ready = true,
    wrack_cmd = "wrack TargetOne paralysis",
  })
  local payload = world.R.build_payload({ target = "TargetOne" })
  assert_true("4d: inundate selected at burst threshold", tostring(payload and payload.class or ""):find("inundate TargetOne choleric", 1, true) ~= nil)
  assert_eq("4e: no bal appended after inundate", payload and payload.bal, nil)
  assert_false("4f: no temper+inundate same payload", tostring(payload and payload.class or ""):find("temper", 1, true) ~= nil)
end

print("\n=== Test 5: direct order + queue staging class lane ===")
do
  local world = make_route_world({
    shielded = true,
    temper_humour = "choleric",
    truewrack_cmd = "truewrack TargetOne melancholic paralysis",
    use_queueing = "NO",
  })
  local ok = world.R.attack_function({ target = "TargetOne" })
  assert_true("5a: direct send succeeds", ok == true)
  local line = tostring(world.sent[#world.sent] or "")
  assert_true("5b: direct order emitted as && line", line:find("&&", 1, true) ~= nil)
end

do
  local world = make_route_world({
    temper_humour = "choleric",
    wrack_cmd = "wrack TargetOne paralysis",
    queue_mode = true,
    use_emit = false,
  })
  local ok = world.R.attack_function({ target = "TargetOne" })
  assert_true("5c: queued send succeeds", ok == true)
  local saw_class = false
  for i = 1, #world.staged do
    if tostring(world.staged[i]):find("class:", 1, true) then
      saw_class = true
      break
    end
  end
  assert_true("5d: queue mode stages class lane", saw_class)
end

print("\n=== Test 6: physiology staged humour + inundate math + clear-all ===")
do
  local world = make_phys_world({ target = "TargetOne", hp = 80, mp = 80 })
  local P = world.P

  _G.ak.alchemist.humour.choleric = 0
  local staged_count = P.staged_humour_count("TargetOne", "choleric", { temper_humour = "choleric" })
  assert_eq("6a: staged temper increments humour count", staged_count, 1)
  local wrack_ok = P.can_wrack_with_staged("TargetOne", "choleric", 1, { temper_humour = "choleric" })
  assert_true("6b: staged temper can legalize wrack", wrack_ok == true)

  _G.ak.alchemist.humour = { choleric = 6, melancholic = 0, phlegmatic = 0, sanguine = 0 }
  local c6 = P.inundate_candidate("TargetOne", "alchemist_group_damage")
  assert_eq("6c: choleric 6 burst pct", c6 and c6.estimated_burst_pct, 50)
  assert_eq("6d: choleric 6 predicted after", c6 and c6.predicted_after_pct, 30)

  _G.ak.alchemist.humour.choleric = 8
  local c8 = P.inundate_candidate("TargetOne", "alchemist_group_damage")
  assert_eq("6e: choleric 8 burst pct", c8 and c8.estimated_burst_pct, 77)
  assert_eq("6f: choleric 8 predicted after", c8 and c8.predicted_after_pct, 3)

  _G.ak.alchemist.humour = { choleric = 0, melancholic = 6, phlegmatic = 0, sanguine = 0 }
  local m6 = P.inundate_candidate("TargetOne", "alchemist_group_damage")
  assert_eq("6g: melancholic 6 burst pct", m6 and m6.estimated_burst_pct, 50)
  assert_eq("6h: melancholic 6 predicted after", m6 and m6.predicted_after_pct, 30)

  _G.ak.alchemist.humour.melancholic = 8
  local m8 = P.inundate_candidate("TargetOne", "alchemist_group_damage")
  assert_eq("6i: melancholic 8 burst pct", m8 and m8.estimated_burst_pct, 77)
  assert_eq("6j: melancholic 8 predicted after", m8 and m8.predicted_after_pct, 3)

  _G.ak.alchemist.humour = { choleric = 0, melancholic = 0, phlegmatic = 0, sanguine = 6 }
  local s6 = P.inundate_candidate("TargetOne", "alchemist_group_damage")
  assert_eq("6k: sanguine 6 bleeding estimate", s6 and s6.estimated_bleeding, 2304)

  _G.ak.alchemist.humour.sanguine = 8
  local s8 = P.inundate_candidate("TargetOne", "alchemist_group_damage")
  assert_eq("6l: sanguine 8 keeps known floor", s8 and s8.estimated_bleeding, 2304)
  assert_true("6m: sanguine 8 marks unknown exact bleed", s8 and s8.exact_bleeding_unknown == true)

  P.set_humour_level("TargetOne", "choleric", 3, "test")
  P.set_humour_level("TargetOne", "melancholic", 2, "test")
  P.set_humour_level("TargetOne", "phlegmatic", 1, "test")
  P.set_humour_level("TargetOne", "sanguine", 4, "test")

  P.handle_humour_balance_line("You inundate TargetOne's choleric humour, and a look of pain crosses their face.")
  local row = P.target("TargetOne")
  assert_true("6n: inundate success marks target dirty", row and row.eval_dirty == true)
  assert_eq("6o: inundate clears choleric level", row and row.humours and row.humours.choleric and row.humours.choleric.level, 0)
  assert_eq("6p: inundate clears melancholic level", row and row.humours and row.humours.melancholic and row.humours.melancholic.level, 0)
end

print("\n=== Test 7: wrapper load and generic target naming ===")
do
  _G.Yso = nil
  _G.yso = nil
  _G.target = "TargetOne"
  _G.cecho = function() end
  _G.echo = function() end
  _G.send = function() return true end
  _G.getEpoch = function() return 1000 end
  _G.gmcp = { Char = { Status = { class = "Alchemist" }, Vitals = { eq = "1", bal = "1" } } }
  _G.ak = { alchemist = { humour = { choleric = 0, melancholic = 0, phlegmatic = 0, sanguine = 0 } } }

  dofile(PHYS_PATH)
  local g = dofile(WRAP_GROUP)
  local d = dofile(WRAP_DUEL)
  assert_true("7a: group wrapper loads", type(g) == "table")
  assert_true("7b: duel wrapper loads", type(d) == "table")

  local world = make_route_world({ temper_humour = "choleric", wrack_cmd = "wrack TargetOne paralysis" })
  local p = world.R.build_payload({ target = "TargetOne" })
  local line = table.concat(p and p.direct_order or {}, "&&")
  assert_false("7c: no hard-coded live target names in emitted line", line:find("Tharonus", 1, true) ~= nil)
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
