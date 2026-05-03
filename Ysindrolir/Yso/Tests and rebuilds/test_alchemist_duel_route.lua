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
local ROUTE_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Core", "duel route.lua")
local PHYS_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Core", "physiology.lua")

local pass_count = 0
local fail_count = 0

local function fail(label, detail)
  fail_count = fail_count + 1
  io.stderr:write(string.format("FAIL: %s%s\n", label, detail and (" - " .. detail) or ""))
end

local function pass() pass_count = pass_count + 1 end

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

local function free_has(payload, text)
  local free = payload and payload.free or nil
  if type(free) == "table" then
    for i = 1, #free do
      if tostring(free[i] or ""):find(text, 1, true) then
        return true
      end
    end
    return false
  end
  return tostring(free or ""):find(text, 1, true) ~= nil
end

local function make_world(opts)
  opts = opts or {}
  local now_s = tonumber(opts.now_s or 1300) or 1300
  local current_target = opts.target or "TargetOne"
  local sent = {}
  local clear_staged_calls = {}
  local mark_dirty_calls = {}
  local pending_clear_calls = {}
  local queue_clear_calls = {}
  local queue_clear_owned_calls = {}
  local queue_clear_dispatched_calls = {}
  local pending_status_active = (opts.pending_active == true)
  local pending_timeout_once = (opts.pending_timeout_once == true)
  local pending_last = nil
  local fire_reave_opts = nil

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
    evaluate_staged_for_target = function() return opts.evaluate_pending == true end,
    reave_sync_target = function() return false end,
    clear_staged_for_target = function(tgt, why)
      clear_staged_calls[#clear_staged_calls + 1] = { target = tgt, reason = why }
      return true
    end,
    mark_all_eval_dirty = function(tgt, why)
      mark_dirty_calls[#mark_dirty_calls + 1] = { target = tgt, reason = why }
      return true
    end,
    note_pending_class = function(action, tgt, humour, cmd, route, source)
      pending_status_active = true
      pending_last = {
        action = action,
        target = tgt,
        humour = humour,
        cmd = cmd,
        route = route,
        source = source,
      }
      return true
    end,
    clear_pending_class = function(why, args)
      pending_status_active = false
      pending_clear_calls[#pending_clear_calls + 1] = { reason = why, args = args }
      return true
    end,
    pending_class_status = function()
      if pending_timeout_once == true then
        pending_timeout_once = false
        pending_status_active = true
        return true, "temper_pending", { action = "temper", target = current_target }
      end
      if pending_status_active == true then
        return true, "temper_pending", { action = "temper", target = current_target }
      end
      return false, nil, nil
    end,
    can_aurify = function() return opts.can_aurify == true end,
    can_reave = function()
      if opts.can_reave == true then
        return true, { legal = true }
      end
      return false, { legal = false }
    end,
    fire_reave = function(name, _, call_opts)
      fire_reave_opts = call_opts
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
    build_truewrack = function() return opts.truewrack_cmd end,
    build_wrack_fallback = function() return opts.wrack_cmd end,
    current_humour_count = function(_, humour)
      humour = tostring(humour or ""):lower()
      return (opts.humours and opts.humours[humour]) or 0
    end,
    health_pct = function() return opts.hp end,
    mana_pct = function() return opts.mp end,
    alchemy_debuff_active = function()
      if opts.vitri_active then
        return true, "vitrification", {}
      end
      return false, nil, nil
    end,
    corruption_active = function()
      return opts.corrupt_active == true
    end,
    clear_all_humours = function() return true end,
  }

  _G.Yso = {
    cfg = { UseQueueing = "NO", pipe_sep = "&&" },
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
    util = { now = function() return now_s end },
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
      is_party = function() return false end,
      active_route_id = function() return "alchemist_duel_route" end,
      route_loop_active = function(id) return id == "alchemist_duel_route" end,
      schedule_route_loop = function() return true end,
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
      if homunculus_state.active ~= true then return false end
      tgt = tostring(tgt or "")
      if tgt == "" then return true end
      return homunculus_state.target:lower() == tgt:lower()
    end,
  }
  _G.yso = _G.Yso

  _G.Yso.alc.set_humour_ready = function(ready)
    _G.Yso.bal.humour = (ready == true)
    return _G.Yso.bal.humour
  end
  _G.Yso.alc.humour_ready = function() return _G.Yso.bal.humour ~= false end
  _G.Yso.alc.set_evaluate_ready = function(ready)
    _G.Yso.bal.evaluate = (ready == true)
    return _G.Yso.bal.evaluate
  end
  _G.Yso.alc.evaluate_ready = function() return _G.Yso.bal.evaluate ~= false end
  _G.Yso.alc.set_homunculus_ready = function(ready)
    _G.Yso.bal.homunculus = (ready == true)
    return _G.Yso.bal.homunculus
  end
  _G.Yso.alc.homunculus_ready = function() return _G.Yso.bal.homunculus ~= false end

  _G.Yso.queue = {
    can_plan_lane = function() return true end,
    clear = function(lane)
      queue_clear_calls[#queue_clear_calls + 1] = lane
      return true
    end,
    clear_owned = function(lane)
      queue_clear_owned_calls[#queue_clear_owned_calls + 1] = lane
      return true
    end,
    clear_lane_dispatched = function(lane, reason)
      queue_clear_dispatched_calls[#queue_clear_dispatched_calls + 1] = { lane = lane, reason = reason }
      return true
    end,
  }

  _G.ak = {
    defs = {
      shield_by_target = {
        [string.lower(current_target)] = (opts.shielded == true),
      },
      shield = (opts.shielded == true),
    },
  }

  dofile(ROUTE_PATH)
  local R = _G.Yso.off.alc.duel_route
  R.init()
  R.cfg.enabled = true
  R.state.enabled = true
  R.state.loop_enabled = true

  return {
    R = R,
    sent = sent,
    clear_staged_calls = clear_staged_calls,
    mark_dirty_calls = mark_dirty_calls,
    pending_clear_calls = pending_clear_calls,
    queue_clear_calls = queue_clear_calls,
    queue_clear_owned_calls = queue_clear_owned_calls,
    queue_clear_dispatched_calls = queue_clear_dispatched_calls,
    fire_reave_opts = function() return fire_reave_opts end,
    pending_last = function() return pending_last end,
    set_target = function(t)
      current_target = t
      _G.target = t
    end,
    set_pending_timeout_once = function(v)
      pending_timeout_once = (v == true)
    end,
  }
end

print("=== Test 1: shieldbreak supports staged truewrack combo ===")
do
  local world = make_world({
    shielded = true,
    temper_humour = "choleric",
    truewrack_cmd = "truewrack TargetOne melancholic paralysis",
    require_staged = true,
  })
  local payload = world.R.build_payload({ target = "TargetOne" })
  assert_eq("1a: shield uses copper", payload and payload.eq, "educe copper TargetOne")
  assert_eq("1b: temper appended", payload and payload.class, "temper TargetOne choleric")
  assert_eq("1c: staged truewrack appended", payload and payload.bal, "truewrack TargetOne melancholic paralysis")
end

print("\n=== Test 2: aurify/reave blocked by shield ===")
do
  local aur_world = make_world({ shielded = true, can_aurify = true, temper_humour = "choleric" })
  local p_aur = aur_world.R.build_payload({ target = "TargetOne" })
  assert_eq("2a: aurify not fired through shield", p_aur and p_aur.eq, "educe copper TargetOne")
  assert_false("2b: payload not direct aurify", (p_aur and p_aur.eq == "aurify TargetOne"))

  local reave_world = make_world({ shielded = true, can_reave = true, temper_humour = "choleric" })
  local p_reave = reave_world.R.build_payload({ target = "TargetOne" })
  assert_false("2c: reave not fired through shield", tostring(p_reave and p_reave.class or ""):find("reave TargetOne", 1, true) ~= nil)
end

print("\n=== Test 2b: duel pressure uses one chained class payload ===")
do
  local world = make_world({
    temper_humour = "choleric",
    wrack_cmd = "wrack TargetOne paralysis",
  })
  local payload = world.R.build_payload({ target = "TargetOne" })
  assert_eq("2b-a: pressure class combo", payload and payload.class, "temper TargetOne choleric&&evaluate TargetOne humours&&educe iron TargetOne&&wrack TargetOne paralysis")
  assert_eq("2b-b: no separate eq lane", payload and payload.eq, nil)
  assert_eq("2b-c: no separate bal lane", payload and payload.bal, nil)
  assert_eq("2b-d: configurable combo verb defaults to add", payload and payload.queue_verb, "add")
  assert_eq("2b-e: combo queues on c", payload and payload.qtype, "c")
end

print("\n=== Test 3: duel keeps homunculus corrupt as free/pre action ===")
do
  local world = make_world({
    shielded = false,
    can_aurify = false,
    can_reave = false,
    class_ready = false,
    eq_ready = false,
    bal_ready = false,
    homunculus_ready = true,
    corrupt_active = false,
  })
  local payload = world.R.build_payload({ target = "TargetOne" })
  assert_true("3a: payload contains homunculus corrupt", free_has(payload, "homunculus corrupt TargetOne"))
end

print("\n=== Test 3b: duel reave execute requests addclearfull ===")
do
  local world = make_world({ can_reave = true })
  local payload = world.R.build_payload({ target = "TargetOne" })
  assert_eq("3b-a: reave selected on class lane", payload and payload.class, "reave TargetOne")
  assert_eq("3b-b: reave payload drops bootstrap sidecar", payload and payload.free, nil)
  local ok = world.R.attack_function({ target = "TargetOne" })
  assert_true("3b-c: reave attack succeeds", ok == true)
  local opts = world.fire_reave_opts()
  assert_eq("3b-d: reave queue verb", opts and opts.queue_verb, "addclearfull")
  assert_eq("3b-e: reave clearfull lane", opts and opts.clearfull_lane, "class")
end

print("\n=== Test 4: lifecycle pacify and target swap homunculus attack ===")
do
  local world = make_world({ temper_humour = "choleric", wrack_cmd = "wrack TargetOne paralysis" })
  local R = world.R

  R.start()
  local p1 = R.build_payload({ target = "TargetOne" })
  assert_true("4a: start arms homunculus attack", free_has(p1, "homunculus attack TargetOne"))

  world.set_target("TargetTwo")
  local p2 = R.build_payload({ target = "TargetTwo" })
  assert_true("4b: target swap rearms homunculus attack", free_has(p2, "homunculus attack TargetTwo"))

  R.stop("manual")
  assert_true("4c: stop sends pacify", contains_text(world.sent, "homunculus pacify"))
  assert_false("4d: stop never sends passive", contains_text(world.sent, "homunculus passive"))
end

print("\n=== Test 5: duel hard gate holds on dirty humour intel ===")
do
  local world_eval = make_world({ needs_eval = true })
  local payload_eval, why_eval = world_eval.R.build_payload({ target = "TargetOne" })
  assert_eq("5a: dirty intel emits evaluate payload", why_eval, "humour_intel_dirty")
  assert_true("5b: evaluate command emitted", free_has(payload_eval, "evaluate TargetOne humours"))

  local world_pending = make_world({ needs_eval = true, evaluate_pending = true })
  local payload_pending, why_pending = world_pending.R.build_payload({ target = "TargetOne" })
  assert_eq("5c: pending evaluate holds payload", payload_pending, nil)
  assert_eq("5d: pending evaluate reason", why_pending, "evaluate_pending")

  local world_not_ready = make_world({ needs_eval = true })
  _G.Yso.alc.set_evaluate_ready(false, "test")
  local payload_not_ready, why_not_ready = world_not_ready.R.build_payload({ target = "TargetOne" })
  assert_eq("5e: evaluate-not-ready holds payload", payload_not_ready, nil)
  assert_eq("5f: evaluate-not-ready reason", why_not_ready, "evaluate_not_ready")
end

print("\n=== Test 6: duel target swap clears stale state ===")
do
  local world = make_world({ needs_eval = true })
  local R = world.R
  R.state.homunculus_attack_sent = true
  R.state.homunculus_attack_target = "TargetOne"
  R.state.busy = true

  local ok = R.on_target_swap("TargetOne", "TargetTwo")
  assert_true("6a: on_target_swap returns true", ok == true)
  assert_true("6b: old target staged lanes cleared", #(world.clear_staged_calls or {}) >= 1)
  assert_eq("6c: pending clear reason target_swap", world.pending_clear_calls[1] and world.pending_clear_calls[1].reason, "target_swap")
  assert_false("6d: homunculus sent reset", R.state.homunculus_attack_sent == true)
  assert_eq("6e: homunculus target reset", R.state.homunculus_attack_target, "")
  assert_true("6f: new target marked dirty", #(world.mark_dirty_calls or {}) >= 1)
  assert_eq("6g: dirty mark target is new target", world.mark_dirty_calls[1] and world.mark_dirty_calls[1].target, "TargetTwo")
end

print("\n=== Test 6b: duel reset_route_state clears stale route-local state ===")
do
  local world = make_world({ temper_humour = "choleric", wrack_cmd = "wrack TargetOne paralysis" })
  local R = world.R
  R.state.busy = true
  R.state.waiting.queue = "class"
  R.state.waiting.main_lane = "class"
  R.state.waiting.lanes = { class = true }
  R.state.waiting.at = 123
  R.state.homunculus_attack_sent = true
  R.state.homunculus_attack_target = "TargetOne"
  R.state.last_attack = { at = 123, target = "TargetOne", main_lane = "class", cmd = "temper TargetOne choleric" }

  local ok = R.reset_route_state("unit_reset", "TargetOne")
  assert_true("6b-a: reset returns true", ok == true)
  assert_false("6b-b: busy cleared", R.state.busy == true)
  assert_eq("6b-c: waiting queue cleared", R.state.waiting.queue, nil)
  assert_eq("6b-d: homunculus target cleared", R.state.homunculus_attack_target, "")
  assert_eq("6b-e: last attack target cleared", R.state.last_attack.target, "")
  assert_true("6b-f: pending class cleared", #(world.pending_clear_calls or {}) >= 1)
  assert_true("6b-g: local class queue cleared", contains_text(world.queue_clear_calls, "class"))
  assert_false("6b-h: reset does not send server CLEARQUEUE", contains_text(world.sent, "CLEARQUEUE"))
end

print("\n=== Test 7: duel temper pending hold + timeout reason ===")
do
  local world = make_world({
    temper_humour = "sanguine",
    class_ready = true,
    bal_ready = false,
    eq_ready = false,
  })

  local ok = world.R.attack_function({ target = "TargetOne" })
  assert_true("7a: first temper send succeeds", ok == true)

  local payload_pending, why_pending = world.R.build_payload({ target = "TargetOne" })
  assert_eq("7b: pending temper holds payload", payload_pending, nil)
  assert_eq("7c: pending temper reason", why_pending, "temper_pending")

  world.set_pending_timeout_once(true)
  local payload_timeout, why_timeout = world.R.build_payload({ target = "TargetOne" })
  assert_eq("7d: timeout tick holds once", payload_timeout, nil)
  assert_eq("7e: timeout remains pending", why_timeout, "temper_pending")
end

print("\n=== Test 8: duel/shared wrack legality surface ===")
do
  _G.Yso = nil
  _G.yso = nil
  _G.target = "TargetOne"
  _G.getEpoch = function() return 2300 * 1000 end
  _G.cecho = function() end
  _G.echo = function() end
  _G.send = function() return true end
  _G.ak = {
    alchemist = {
      humour = { choleric = 0, melancholic = 0, phlegmatic = 0, sanguine = 0 },
    },
  }
  _G.affstrack = { score = setmetatable({}, { __index = function() return 0 end }) }
  _G.Yso = {
    get_target = function() return "TargetOne" end,
    target = "TargetOne",
    bal = { humour = true, evaluate = true, homunculus = true },
    util = { now = function() return 2300 end },
    self = {
      has_aff = function() return false end,
      is_prone = function() return false end,
      list_writhe_affs = function() return {} end,
      is_writhed = function() return false end,
    },
    tgt = { has_aff = function() return false end },
    queue = {
      list = function() return nil end,
      clear = function() return true end,
      stage = function() return true end,
    },
  }
  _G.yso = _G.Yso

  dofile(PHYS_PATH)
  local P = _G.Yso.alc.phys
  P.begin_evaluate("TargetOne")
  P.finish_evaluate("TargetOne")

  local giving = { "haemophilia", "nausea", "sensitivity", "paralysis" }
  local wrack0 = P.build_wrack_fallback("TargetOne", giving)
  assert_eq("8a: duel-shared explicit aff legal from untempered pool", wrack0, "wrack TargetOne haemophilia")

  local keyword0 = P.can_wrack_humour_arg("TargetOne", "choleric")
  assert_false("8b: duel-shared humour keyword blocked at zero", keyword0 == true)

  _G.ak.alchemist.humour.choleric = 1
  local keyword1 = P.can_wrack_humour_arg("TargetOne", "choleric")
  assert_true("8c: duel-shared humour keyword legal when tempered", keyword1 == true)

  _G.ak.alchemist.humour.choleric = 0
  local staged_keyword = P.can_wrack_humour_arg("TargetOne", "choleric", { temper_humour = "choleric" })
  assert_true("8d: duel-shared staged temper legalizes humour keyword", staged_keyword == true)

  _G.ak.alchemist.humour.sanguine = 1
  local para_block = P.can_wrack_aff_arg("TargetOne", "paralysis")
  assert_false("8e: duel-shared paralysis blocked below effective 2", para_block == true)
  local para_ok = P.can_wrack_aff_arg("TargetOne", "paralysis", { temper_humour = "sanguine" })
  assert_true("8f: duel-shared staged sanguine unlocks paralysis", para_ok == true)
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
