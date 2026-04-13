--========================================================--
-- magi_group_damage.lua
--  * Party damage route for Magi.
--  * Strategy:
--      - STAFF CAST HORRIPILATION while waterbonds are missing.
--      - CAST FREEZE as the default baseline until freeze-side pressure exists.
--      - Keep the existing mudslide / water-emanation / glaciate water line.
--      - Once frozen or frostbite is established on the current target, branch
--        into fire pressure without abandoning the water side.
--      - Use MAGMA / FIRELASH / CONFLAGRATE / EMANATION FIRE conditionally.
--  * Alias-controlled loop ownership lives in Yso.mode.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.magi = Yso.off.magi or {}

Yso.off.magi.group_damage = Yso.off.magi.group_damage or {}
local MGD = Yso.off.magi.group_damage
Yso.off.magi.dmg = MGD
MGD.alias_owned = true

local function _load_magi_peer(file_name)
  local info = debug.getinfo(1, "S")
  local source = info and info.source or ""
  if source:sub(1, 1) ~= "@" then return false end
  local dir = source:sub(2):match("^(.*)[/\\][^/\\]+$") or "."
  local path = dir .. "/" .. tostring(file_name or "")
  local ok = pcall(dofile, path)
  return ok
end

local RC = Yso.off.magi.route_core
if type(RC) ~= "table" and type(require) == "function" then
  pcall(require, "magi_route_core")
  RC = Yso.off.magi.route_core
end
if type(RC) ~= "table" and _load_magi_peer("magi_route_core.lua") then
  RC = Yso.off.magi.route_core
end
assert(type(RC) == "table", "Yso.off.magi.route_core unavailable")

local PENDING_SLOTS = {
  "horripilation",
  "freeze",
  "mudslide",
  "emanation_water",
  "magma",
  "firelash",
  "conflagrate",
  "emanation_fire",
  "glaciate",
}

MGD.route_contract = MGD.route_contract or {
  id = "magi_group_damage",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "opener_setup",
    "freeze_setup",
    "salve_pressure",
    "disrupt_setup",
    "glaciate_burst",
    "fire_build",
    "fire_payoff",
    "fire_promotion",
  },
  capabilities = {
    uses_eq = true,
    uses_bal = false,
    uses_entity = false,
    supports_burst = true,
    supports_bootstrap = true,
    needs_target = true,
    shares_defense_break = false,
    shares_anti_tumble = false,
  },
  override_policy = {
    mode = "narrow_global_only",
    allowed = {
      target_invalid = true,
      target_slain = true,
      route_off = true,
      pause = true,
      manual_suppression = true,
      target_swap_bootstrap = true,
    },
  },
  lifecycle = {
    on_enter = true,
    on_exit = true,
    on_target_swap = true,
    on_pause = true,
    on_resume = true,
    on_manual_success = true,
    on_send_result = true,
    evaluate = true,
    explain = true,
  },
}

do
  local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(MGD, MGD.route_contract)
  end
end

MGD.cfg = MGD.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,
  same_target_repeat_s = 0.75,
  horripilation_pending_s = 1.00,
  freeze_pending_s = 1.00,
  mudslide_pending_s = 0.80,
  water_emanation_pending_s = 2.60,
  magma_pending_s = 1.00,
  firelash_pending_s = 1.00,
  conflagrate_pending_s = 1.00,
  fire_emanation_pending_s = 2.60,
  glaciate_pending_s = 1.00,
}

MGD.state = MGD.state or {
  enabled = false,
  loop_enabled = false,
  timer_id = nil,
  busy = false,
  last_target = "",
  last_cmd = "",
  last_category = "",
  last_sent_cmd = "",
  last_sent_target = "",
  last_sent_category = "",
  last_sent_at = 0,
  explain = {},
  template = { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" },
  pending = {
    horripilation = { target = "", until_t = 0 },
    freeze = { target = "", until_t = 0 },
    mudslide = { target = "", until_t = 0 },
    emanation_water = { target = "", until_t = 0 },
    magma = { target = "", until_t = 0 },
    firelash = { target = "", until_t = 0 },
    conflagrate = { target = "", until_t = 0 },
    emanation_fire = { target = "", until_t = 0 },
    glaciate = { target = "", until_t = 0 },
  },
  cold = {
    target = "",
    room_id = "",
    phase = "reset",
    seen_frostbite = false,
    seen_frozen = false,
    progressed_at = 0,
    reason = "init",
  },
  route = {
    target = "",
    room_id = "",
    freeze_step_done = false,
    branch_stage = "reset",
    last_reset_reason = "init",
  },
}

local function _trim(s)
  return RC.trim(s)
end

local function _lc(s)
  return RC.lc(s)
end

local function _same_target(a, b)
  return RC.same_target(a, b)
end

local function _now()
  return RC.now()
end

local function _echo(msg)
  if MGD.cfg.echo ~= true then return end
  if type(cecho) == "function" then
    cecho(string.format("<cadet_blue>[Yso:Magi] <reset>%s\n", tostring(msg)))
  elseif type(echo) == "function" then
    echo(string.format("[Yso:Magi] %s\n", tostring(msg)))
  end
end

local function _current_class()
  local C = Yso and Yso.classinfo or nil
  if type(C) == "table" then
    if type(C.get) == "function" then
      local ok, v = pcall(C.get)
      if ok and type(v) == "string" and _trim(v) ~= "" then return v end
    end
    if type(C.current_class) == "function" then
      local ok, v = pcall(C.current_class)
      if ok and type(v) == "string" and _trim(v) ~= "" then return v end
    end
  end

  local gmcp = rawget(_G, "gmcp")
  local cls = gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class or nil
  if type(cls) == "string" and _trim(cls) ~= "" then return cls end

  if type(Yso.class) == "string" and _trim(Yso.class) ~= "" then return Yso.class end
  return ""
end

local function _is_magi()
  if type(Yso.is_magi) == "function" then
    local ok, v = pcall(Yso.is_magi)
    if ok then return v == true end
  end

  local C = Yso and Yso.classinfo or nil
  if type(C) == "table" and type(C.is_magi) == "function" then
    local ok, v = pcall(C.is_magi)
    if ok then return v == true end
  end

  return _lc(_current_class()) == "magi"
end

local function _target()
  return RC.get_target()
end

local function _room_id()
  return RC.room_id()
end

local function _tgt_valid(tgt)
  return RC.target_valid(tgt)
end

local function _eq_ready()
  return RC.eq_ready()
end

local function _party_damage_context_active()
  if not _is_magi() then return false end
  local M = Yso and Yso.mode or nil
  if not M then return false end

  local is_party = false
  if type(M.is_party) == "function" then
    local ok, v = pcall(M.is_party)
    if ok then is_party = (v == true) end
  else
    is_party = (_lc(M.state or "") == "party")
  end
  if not is_party then return false end

  local route = ""
  if type(M.party_route) == "function" then
    local ok, v = pcall(M.party_route)
    if ok then route = _lc(v or "") end
  elseif M.party then
    route = _lc(M.party.route or "")
  end
  if route == "dmg" then route = "dam" end
  return route == "" or route == "dam"
end

local function _route_is_active()
  if not _party_damage_context_active() then return false end
  if Yso and Yso.mode and type(Yso.mode.route_loop_active) == "function" then
    return Yso.mode.route_loop_active("magi_group_damage") == true
  end
  return MGD.state and MGD.state.loop_enabled == true
end

local function _set_loop_enabled(on)
  local enabled = (on == true)
  MGD.state.enabled = enabled
  MGD.state.loop_enabled = enabled
  MGD.loop_enabled = enabled
  MGD.cfg.enabled = enabled
  MGD.state.loop_delay = tonumber(MGD.state.loop_delay or MGD.cfg.loop_delay or 0.15) or 0.15
  return enabled
end

local function _score_aff(aff)
  return RC.score_aff(aff)
end

local function _score_positive(aff)
  return RC.has_aff(aff)
end

local function _res_actual(element)
  local res = RC.read_resonance()
  element = _lc(element)
  if element == "" then return 0, false end
  return tonumber(res[element] or 0) or 0, res.synced == true
end

local function _res_major(element)
  local value, synced = _res_actual(element)
  return value >= 3, value, synced
end

local function _cold_slot()
  MGD.state.cold = MGD.state.cold or {
    target = "",
    room_id = "",
    phase = "reset",
    seen_frostbite = false,
    seen_frozen = false,
    progressed_at = 0,
    reason = "init",
  }
  return MGD.state.cold
end

local function _reset_cold(reason)
  local cold = _cold_slot()
  cold.target = ""
  cold.room_id = ""
  cold.phase = "reset"
  cold.seen_frostbite = false
  cold.seen_frozen = false
  cold.progressed_at = 0
  cold.reason = tostring(reason or "")
  return cold
end

local function _route_slot()
  MGD.state.route = MGD.state.route or {
    target = "",
    room_id = "",
    freeze_step_done = false,
    branch_stage = "reset",
    last_reset_reason = "init",
  }
  return MGD.state.route
end

local function _reset_route(reason)
  local route = _route_slot()
  route.target = ""
  route.room_id = ""
  route.freeze_step_done = false
  route.branch_stage = "reset"
  route.last_reset_reason = tostring(reason or "")
  return route
end

local function _ensure_context(tgt)
  local room = _room_id()
  local cold = _cold_slot()
  local route = _route_slot()

  local room_changed = false
  if cold.room_id ~= "" and room ~= "" and cold.room_id ~= room then room_changed = true end
  if route.room_id ~= "" and room ~= "" and route.room_id ~= room then room_changed = true end

  local target_changed = false
  if cold.target ~= "" and tgt ~= "" and not _same_target(cold.target, tgt) then target_changed = true end
  if route.target ~= "" and tgt ~= "" and not _same_target(route.target, tgt) then target_changed = true end

  if room_changed then
    cold = _reset_cold("room_change")
    route = _reset_route("room_change")
  elseif target_changed then
    cold = _reset_cold("target_change")
    route = _reset_route("target_change")
  end

  cold.target = _trim(tgt or "")
  cold.room_id = room
  route.target = _trim(tgt or "")
  route.room_id = room
  return cold, route
end

local function _set_branch_stage(tgt, stage)
  local _, route = _ensure_context(tgt)
  route.branch_stage = tostring(stage or "")
  return route
end

local function _refresh_cold_state(tgt, frozen, frostbite)
  local cold = _ensure_context(tgt)
  if frostbite == true then cold.seen_frostbite = true end
  if frozen == true then cold.seen_frozen = true end

  if (cold.seen_frozen or cold.seen_frostbite) and tonumber(cold.progressed_at or 0) <= 0 then
    cold.progressed_at = _now()
  end
  if cold.seen_frozen or cold.seen_frostbite then
    cold.phase = "progressed"
  else
    cold.phase = "freeze_baseline"
  end
  return cold
end

local function _pending_slot(name)
  return RC.pending_slot(MGD.state, name)
end

local function _clear_pending(name)
  return RC.clear_pending(MGD.state, name)
end

local function _clear_pending_all()
  return RC.clear_pending_all(MGD.state, PENDING_SLOTS)
end

local function _mark_pending(name, tgt, seconds)
  return RC.mark_pending(MGD.state, name, tgt, seconds)
end

local function _pending_active(name, tgt)
  return RC.pending_active(MGD.state, name, tgt)
end

local function _spell_guard(slot_name, tgt, cmd)
  return RC.guard_spell({
    state = MGD.state,
    cfg = MGD.cfg,
    slot = slot_name,
    target = tgt,
    cmd = cmd,
    target_valid = _tgt_valid(tgt),
    eq_ready = _eq_ready(),
  })
end

local function _freeze_stable()
  return _score_positive("frozen") or _score_positive("frostbite")
end

local function _has_conflagrate()
  return _score_positive("conflagrate")
end

local function _has_ablaze()
  return _score_positive("aflame")
end

local function _aflame_ready_for_conflagrate()
  return _score_aff("aflame") >= 200
end

local function _fire_res_major()
  return _res_major("fire")
end

local function _water_res_major()
  return _res_major("water")
end

local function _can_cast_horripilation(tgt)
  local cmd = ("staff cast horripilation %s"):format(tgt)
  local ok, why = _spell_guard("horripilation", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_freeze(tgt)
  local cmd = ("cast freeze at %s"):format(tgt)
  local ok, why = _spell_guard("freeze", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_mudslide(tgt)
  local cmd = ("cast mudslide at %s"):format(tgt)
  local ok, why = _spell_guard("mudslide", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_glaciate(tgt)
  local cmd = ("cast glaciate at %s"):format(tgt)
  if not _score_positive("frozen") then return false, "frozen_required", cmd end
  local ok, why = _spell_guard("glaciate", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_magma(tgt)
  local cmd = ("cast magma at %s"):format(tgt)
  local ok, why = _spell_guard("magma", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_firelash(tgt)
  local cmd = ("cast firelash at %s"):format(tgt)
  local ok, why = _spell_guard("firelash", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_conflagrate(tgt)
  local cmd = ("cast conflagrate at %s"):format(tgt)
  if not _has_ablaze() then return false, "ablaze_required", cmd end
  if not _aflame_ready_for_conflagrate() then return false, "aflame_not_ready", cmd end
  local ok, why = _spell_guard("conflagrate", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_water_emanation(tgt)
  local major = _water_res_major()
  local cmd = ("cast emanation at %s water"):format(tgt)
  if major ~= true then return false, "water_not_major", cmd end
  local ok, why = _spell_guard("emanation_water", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_fire_emanation(tgt)
  local major = _fire_res_major()
  local cmd = ("cast emanation at %s fire"):format(tgt)
  if major ~= true then return false, "fire_not_major", cmd end
  if not _has_conflagrate() then return false, "conflagrate_required", cmd end
  if not _freeze_stable() then return false, "freeze_stable_required", cmd end
  local ok, why = _spell_guard("emanation_fire", tgt, cmd)
  return ok, why, cmd
end

local function _effective_state(tgt)
  local base = RC.build_snapshot({
    state = MGD.state,
    target = tgt,
    affs = {
      "waterbonds",
      "frozen",
      "frostbite",
      "slickness",
      "disrupt",
      "scalded",
      "conflagrate",
      "aflame",
    },
    pending_slots = PENDING_SLOTS,
  })
  local frozen = base.frozen == true
  local frostbite = base.frostbite == true
  local slick_actual = base.slickness == true
  local disrupt_actual = base.disrupt == true
  local waterbonds_actual = base.waterbonds == true
  local scalded_actual = base.scalded == true
  local conflagrate = base.conflagrate == true
  local ablaze = _has_ablaze()
  local aflame = tonumber(base.raw.aflame or 0) or 0
  local water_res = tonumber(base.res.water or 0) or 0
  local fire_res = tonumber(base.res.fire or 0) or 0
  local water_major = base.res.water_major == true
  local fire_major = base.res.fire_major == true
  local cold = _refresh_cold_state(tgt, frozen, frostbite)
  local _, route = _ensure_context(tgt)

  local slickness = slick_actual or _pending_active("mudslide", tgt)
  local disrupt = disrupt_actual or _pending_active("emanation_water", tgt)
  local waterbonds = waterbonds_actual or _pending_active("horripilation", tgt)
  local scalded = scalded_actual or _pending_active("magma", tgt)
  local fire_branch_eligible = (route.freeze_step_done == true) and _freeze_stable()

  return {
    target = _trim(tgt or ""),
    target_valid = _tgt_valid(tgt),
    waterbonds = waterbonds,
    waterbonds_actual = waterbonds_actual,
    frozen = frozen,
    frostbite = frostbite,
    freeze_stable = _freeze_stable(),
    slickness = slickness,
    slickness_actual = slick_actual,
    disrupt = disrupt,
    disrupt_actual = disrupt_actual,
    scalded = scalded,
    scalded_actual = scalded_actual,
    conflagrate = conflagrate,
    ablaze = ablaze,
    aflame = aflame,
    aflame_ready = aflame >= 200,
    water_res = water_res,
    water_res_major = water_major,
    fire_res = fire_res,
    fire_res_major = fire_major,
    resonance_synced = base.res.synced == true,
    freeze_step_done = (route.freeze_step_done == true),
    fire_branch_eligible = fire_branch_eligible,
    route = {
      target = route.target,
      room_id = route.room_id,
      freeze_step_done = route.freeze_step_done,
      branch_stage = route.branch_stage,
      last_reset_reason = route.last_reset_reason,
    },
    cold = {
      target = cold.target,
      room_id = cold.room_id,
      phase = cold.phase,
      seen_frostbite = cold.seen_frostbite,
      seen_frozen = cold.seen_frozen,
      progressed_at = cold.progressed_at,
      reason = cold.reason,
    },
    pending = {
      horripilation = _pending_active("horripilation", tgt),
      freeze = _pending_active("freeze", tgt),
      mudslide = _pending_active("mudslide", tgt),
      emanation_water = _pending_active("emanation_water", tgt),
      magma = _pending_active("magma", tgt),
      firelash = _pending_active("firelash", tgt),
      conflagrate = _pending_active("conflagrate", tgt),
      emanation_fire = _pending_active("emanation_fire", tgt),
      glaciate = _pending_active("glaciate", tgt),
    },
    raw = {
      waterbonds = tonumber(base.raw.waterbonds or 0) or 0,
      frozen = tonumber(base.raw.frozen or 0) or 0,
      frostbite = tonumber(base.raw.frostbite or 0) or 0,
      slickness = tonumber(base.raw.slickness or 0) or 0,
      disrupt = tonumber(base.raw.disrupt or 0) or 0,
      scalded = tonumber(base.raw.scalded or 0) or 0,
      conflagrate = tonumber(base.raw.conflagrate or 0) or 0,
      aflame = aflame,
      water_res = water_res,
      fire_res = fire_res,
    },
  }
end

local function _should_mudslide(st)
  return st.frozen == true and st.slickness ~= true
end

local function _should_water_emanation(st)
  return st.frozen == true and st.slickness == true and st.disrupt ~= true and st.water_res_major == true
end

local function _should_glaciate(st, tgt)
  if st.frozen ~= true then return false end
  if st.slickness ~= true then return false end
  if st.disrupt ~= true and st.water_res_major == true then return false end
  if _same_target(MGD.state.last_sent_target or "", tgt) and MGD.state.last_sent_category == "glaciate_burst" then
    return false
  end
  return true
end

local function _should_fire_emanation(st)
  return st.conflagrate == true
    and st.freeze_stable == true
    and st.fire_res_major == true
end

local function _select_command(tgt)
  local st = _effective_state(tgt)

  if not st.target_valid then
    _set_branch_stage(tgt, "invalid_target")
    return nil, nil, st, "invalid_target"
  end

  if not st.waterbonds then
    local ok, why, cmd = _can_cast_horripilation(tgt)
    _set_branch_stage(tgt, ok and "opener_setup" or "opener_wait")
    if ok then
      return cmd, "opener_setup", st, "waterbonds_missing"
    end
    return nil, nil, st, why ~= "" and why or "waterbonds_missing"
  end

  if st.freeze_step_done ~= true then
    local ok, why, cmd = _can_cast_freeze(tgt)
    _set_branch_stage(tgt, ok and "freeze_setup" or "freeze_wait")
    if ok then
      return cmd, "freeze_setup", st, "freeze_step_gate"
    end
    return nil, nil, st, why ~= "" and why or "freeze_step_gate"
  end

  if _should_mudslide(st) then
    local ok, why, cmd = _can_cast_mudslide(tgt)
    _set_branch_stage(tgt, ok and "salve_pressure" or "mudslide_wait")
    if ok then
      return cmd, "salve_pressure", st, "mudslide_window"
    end
    return nil, nil, st, why ~= "" and why or "mudslide_window"
  end

  do
    local ok, _, cmd = _can_cast_glaciate(tgt)
    if ok and _should_glaciate(st, tgt) then
      _set_branch_stage(tgt, "glaciate_burst")
      return cmd, "glaciate_burst", st, "glaciate_window"
    end
  end

  if st.freeze_stable ~= true then
    local ok, why, cmd = _can_cast_freeze(tgt)
    _set_branch_stage(tgt, ok and "freeze_setup" or "freeze_wait")
    if ok then
      return cmd, "freeze_setup", st, "freeze_baseline"
    end
    return nil, nil, st, why ~= "" and why or "freeze_baseline"
  end

  if _should_water_emanation(st) then
    local ok, _, cmd = _can_cast_water_emanation(tgt)
    if ok then
      _set_branch_stage(tgt, "disrupt_setup")
      return cmd, "disrupt_setup", st, "water_emanation_setup"
    end
  end

  if st.fire_branch_eligible == true and st.conflagrate ~= true and st.aflame_ready == true and st.ablaze == true then
    local ok, _, cmd = _can_cast_conflagrate(tgt)
    if ok then
      _set_branch_stage(tgt, "fire_payoff")
      return cmd, "fire_payoff", st, "conflagrate_ready"
    end
  end

  if st.fire_branch_eligible == true and _should_fire_emanation(st) then
    local ok, _, cmd = _can_cast_fire_emanation(tgt)
    if ok then
      _set_branch_stage(tgt, "fire_promotion")
      return cmd, "fire_promotion", st, "fire_emanation_promote"
    end
  end

  if st.fire_branch_eligible == true and st.scalded ~= true then
    local ok, _, cmd = _can_cast_magma(tgt)
    if ok then
      _set_branch_stage(tgt, "fire_build")
      return cmd, "fire_build", st, "scalded_missing"
    end
  end

  if st.fire_branch_eligible == true and st.conflagrate ~= true then
    local ok, _, cmd = _can_cast_firelash(tgt)
    if ok then
      _set_branch_stage(tgt, "fire_build")
      return cmd, "fire_build", st, "firelash_builder"
    end
  end

  do
    local ok, _, cmd = _can_cast_glaciate(tgt)
    if ok and st.frozen == true then
      _set_branch_stage(tgt, "glaciate_burst")
      return cmd, "glaciate_burst", st, "glaciate_fallback"
    end
  end

  if st.fire_branch_eligible == true then
    local ok, _, cmd = _can_cast_firelash(tgt)
    if ok then
      _set_branch_stage(tgt, "fire_build")
      return cmd, "fire_build", st, "maintain_fire_pressure"
    end
  end

  do
    local ok, why, cmd = _can_cast_freeze(tgt)
    if ok then
      _set_branch_stage(tgt, "freeze_setup")
      return cmd, "freeze_setup", st, "freeze_refresh"
    end
    _set_branch_stage(tgt, "hold")
    return nil, nil, st, why ~= "" and why or "no_legal_action"
  end
end

local function _clear_eq_queue()
  if Yso and Yso.queue and type(Yso.queue.clear) == "function" then
    pcall(Yso.queue.clear, "eq")
  end
end

local function _emit_payload(payload, category)
  local opts = {
    reason = "magi_group_damage:" .. tostring(category or "attack"),
    kind = "offense",
    commit = true,
  }

  if type(Yso.emit) == "function" then
    return Yso.emit(payload, opts) == true
  end

  local Q = Yso and Yso.queue or nil
  if Q and type(Q.stage) == "function" and type(Q.commit) == "function" then
    if payload.eq ~= nil then Q.stage("eq", payload.eq, opts) end
    local ok = Q.commit(opts)
    if ok then
      Q._commit_hint = nil
      return true
    end
    Q._commit_hint = opts
    if Yso and Yso.pulse and type(Yso.pulse.wake) == "function"
      and not (Yso.pulse.state and Yso.pulse.state._in_flush) then
      pcall(Yso.pulse.wake, "emit:staged")
    end
    return true
  end

  return false
end

local function _payload_each_eq(payload, fn)
  if type(payload) ~= "table" or type(fn) ~= "function" then return end
  local row = payload.eq or (type(payload.lanes) == "table" and payload.lanes.eq)
  if type(row) == "string" then
    fn(row)
    return
  end
  if type(row) == "table" then
    for i = 1, #row do
      if type(row[i]) == "string" then fn(row[i]) end
    end
  end
end

local function _capture_target(cmd, pat)
  return _trim(_lc(cmd):match(pat) or "")
end

local function _attack_opts(arg)
  if type(arg) == "table" and (arg.preview ~= nil or arg.ctx ~= nil) then
    return arg.ctx, (arg.preview == true)
  end
  return arg, false
end

local function _update_explain(tgt, st, category, reason, planned_cmd)
  MGD.state.explain = RC.build_explain({
    route = "magi_group_damage",
    target = tgt,
    decision = category or "",
    reason = reason or "",
    planned = { eq = planned_cmd or "" },
    branch_stage = (_route_slot().branch_stage or (st and st.route and st.route.branch_stage) or ""),
    freeze_step_done = st and st.freeze_step_done == true or false,
    fire_branch_eligible = st and st.fire_branch_eligible == true or false,
    state = st or {},
    last_cmd = MGD.state and MGD.state.last_cmd or "",
    last_sent_cmd = MGD.state and MGD.state.last_sent_cmd or "",
    pending = MGD.state and MGD.state.pending or {},
    route_enabled = MGD.is_enabled and MGD.is_enabled() or false,
    active = MGD.is_active and MGD.is_active() or false,
  })
end

local function _clear_runtime_state(reason)
  RC.reset_runtime_state(MGD.state, reason)
end

function MGD.init()
  MGD.cfg = MGD.cfg or {}
  MGD.state = MGD.state or {}
  MGD.state.template = MGD.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  RC.ensure_pending(MGD.state, PENDING_SLOTS)
  _cold_slot()
  _route_slot()
  MGD.state.loop_delay = tonumber(MGD.state.loop_delay or MGD.cfg.loop_delay or 0.15) or 0.15
  MGD.state.busy = (MGD.state.busy == true)
  _set_loop_enabled((MGD.state.loop_enabled == true) or (MGD.state.enabled == true))
  return true
end

function MGD.reset(reason)
  MGD.init()
  _clear_pending_all()
  _reset_cold(reason or "manual")
  _reset_route(reason or "manual")
  _clear_runtime_state(reason or "manual")
  return true
end

function MGD.is_enabled()
  return MGD.state and MGD.state.enabled == true
end

function MGD.is_active()
  return _route_is_active()
end

function MGD.can_run(ctx)
  MGD.init()
  if not MGD.is_enabled() then return false, "disabled" end
  if not MGD.is_active() then return false, "inactive" end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return false, "paused" end

  local tgt = _trim((ctx and ctx.target) or _target())
  if tgt == "" then
    _reset_cold("no_target")
    _reset_route("no_target")
    return false, "no_target"
  end
  if not _is_magi() then return false, "wrong_class" end
  if not _tgt_valid(tgt) then
    _reset_cold("invalid_target")
    _reset_route("invalid_target")
    return false, "invalid_target"
  end
  _ensure_context(tgt)
  return true, tgt
end

function MGD.attack_function(arg)
  local ctx, preview = _attack_opts(arg)
  local ok, info = MGD.can_run(ctx)
  if not ok then
    if preview then return nil, info end
    return false, info
  end

  local tgt = info
  if MGD.state.last_target ~= "" and not _same_target(MGD.state.last_target, tgt) then
    _clear_pending_all()
  end
  MGD.state.last_target = tgt

  local cmd, category, st, reason = _select_command(tgt)
  MGD.state.template.last_reason = reason
  MGD.state.template.last_target = tgt
  _update_explain(tgt, st, category, reason, cmd)

  if not cmd or cmd == "" then
    MGD.state.template.last_payload = nil
    if preview then return nil, reason end
    return false, reason
  end

  local payload = {
    route = "magi_group_damage",
    target = tgt,
    lanes = { eq = cmd },
    meta = {
      main_lane = "eq",
      main_category = category,
      main_reason = reason,
      state = st,
      explain = MGD.state.explain,
    },
  }

  MGD.state.template.last_payload = { eq = cmd, meta = payload.meta }

  if preview then return payload end

  local queued_payload = { eq = cmd }
  local sent = _emit_payload(queued_payload, category)
  if not sent then return false, "emit_failed" end
  local has_ack_bus = Yso and Yso.locks and type(Yso.locks.note_payload) == "function"
  if not has_ack_bus and type(MGD.on_payload_queued) == "function" then
    pcall(MGD.on_payload_queued, queued_payload)
  end

  MGD.state.last_cmd = cmd
  MGD.state.last_category = category
  return true, cmd, payload
end

function MGD.build_payload(ctx)
  return MGD.attack_function({ ctx = ctx, preview = true })
end

function MGD.build(reason)
  local ctx = type(reason) == "table" and reason or { reason = tostring(reason or "") }
  return MGD.build_payload(ctx)
end

function MGD.evaluate(ctx)
  local payload, why = MGD.build_payload(ctx)
  if not payload then return { ok = false, reason = why } end
  return { ok = true, payload = payload }
end

function MGD.explain()
  MGD.init()
  local ex = type(MGD.state.explain) == "table" and MGD.state.explain or {}
  local tgt = _target()
  local st = _effective_state(tgt)
  ex.route = "magi_group_damage"
  ex.enabled = MGD.is_enabled()
  ex.route_enabled = MGD.is_enabled()
  ex.active = MGD.is_active()
  ex.target = tgt
  ex.last_reason = MGD.state and MGD.state.template and MGD.state.template.last_reason or ""
  ex.last_disable_reason = MGD.state and MGD.state.template and MGD.state.template.last_disable_reason or ""
  ex.last_cmd = MGD.state and MGD.state.last_cmd or ""
  ex.last_sent_cmd = MGD.state and MGD.state.last_sent_cmd or ""
  ex.decision = ex.decision or (MGD.state and MGD.state.last_category or "")
  ex.branch_stage = (st.route and st.route.branch_stage) or ex.branch_stage or ""
  ex.freeze_step_done = st.freeze_step_done == true
  ex.fire_branch_eligible = st.fire_branch_eligible == true
  ex.state = st
  ex.pending = MGD.state and MGD.state.pending or {}
  return ex
end

function MGD.status()
  return MGD.explain()
end

function MGD.on_payload_queued(payload)
  _payload_each_eq(payload, function(cmd)
    cmd = _trim(cmd)
    if cmd == "" then return end

    local lc = _lc(cmd)
    MGD.state.last_sent_cmd = cmd
    MGD.state.last_sent_at = _now()

    local horr_tgt = _capture_target(lc, "^staff%s+cast%s+horripilation%s+(.+)$")
    if horr_tgt ~= "" then
      MGD.state.last_sent_target = horr_tgt
      MGD.state.last_sent_category = "opener_setup"
      _mark_pending("horripilation", horr_tgt, MGD.cfg.horripilation_pending_s)
      _set_branch_stage(horr_tgt, "opener_setup")
      return
    end

    local freeze_tgt = _capture_target(lc, "^cast%s+freeze%s+at%s+(.+)$")
    if freeze_tgt ~= "" then
      local _, route = _ensure_context(freeze_tgt)
      route.freeze_step_done = true
      route.branch_stage = "freeze_setup"
      MGD.state.last_sent_target = freeze_tgt
      MGD.state.last_sent_category = "freeze_setup"
      _mark_pending("freeze", freeze_tgt, MGD.cfg.freeze_pending_s)
      return
    end

    local mud_tgt = _capture_target(lc, "^cast%s+mudslide%s+at%s+(.+)$")
    if mud_tgt ~= "" then
      MGD.state.last_sent_target = mud_tgt
      MGD.state.last_sent_category = "salve_pressure"
      _mark_pending("mudslide", mud_tgt, MGD.cfg.mudslide_pending_s)
      _set_branch_stage(mud_tgt, "salve_pressure")
      return
    end

    local ema_water_tgt = _capture_target(lc, "^cast%s+emanation%s+at%s+(.+)%s+water$")
    if ema_water_tgt ~= "" then
      MGD.state.last_sent_target = ema_water_tgt
      MGD.state.last_sent_category = "disrupt_setup"
      _mark_pending("emanation_water", ema_water_tgt, MGD.cfg.water_emanation_pending_s)
      _set_branch_stage(ema_water_tgt, "disrupt_setup")
      return
    end

    local magma_tgt = _capture_target(lc, "^cast%s+magma%s+at%s+(.+)$")
    if magma_tgt ~= "" then
      MGD.state.last_sent_target = magma_tgt
      MGD.state.last_sent_category = "salve_pressure"
      _mark_pending("magma", magma_tgt, MGD.cfg.magma_pending_s)
      _set_branch_stage(magma_tgt, "fire_build")
      return
    end

    local firelash_tgt = _capture_target(lc, "^cast%s+firelash%s+at%s+(.+)$")
    if firelash_tgt ~= "" then
      MGD.state.last_sent_target = firelash_tgt
      MGD.state.last_sent_category = "fire_build"
      _mark_pending("firelash", firelash_tgt, MGD.cfg.firelash_pending_s)
      _set_branch_stage(firelash_tgt, "fire_build")
      return
    end

    local conflagrate_tgt = _capture_target(lc, "^cast%s+conflagrate%s+at%s+(.+)$")
    if conflagrate_tgt ~= "" then
      MGD.state.last_sent_target = conflagrate_tgt
      MGD.state.last_sent_category = "fire_payoff"
      _mark_pending("conflagrate", conflagrate_tgt, MGD.cfg.conflagrate_pending_s)
      _set_branch_stage(conflagrate_tgt, "fire_payoff")
      return
    end

    local ema_fire_tgt = _capture_target(lc, "^cast%s+emanation%s+at%s+(.+)%s+fire$")
    if ema_fire_tgt ~= "" then
      MGD.state.last_sent_target = ema_fire_tgt
      MGD.state.last_sent_category = "fire_promotion"
      _mark_pending("emanation_fire", ema_fire_tgt, MGD.cfg.fire_emanation_pending_s)
      _set_branch_stage(ema_fire_tgt, "fire_promotion")
      return
    end

    local glaciate_tgt = _capture_target(lc, "^cast%s+glaciate%s+at%s+(.+)$")
    if glaciate_tgt ~= "" then
      MGD.state.last_sent_target = glaciate_tgt
      MGD.state.last_sent_category = "glaciate_burst"
      _mark_pending("glaciate", glaciate_tgt, MGD.cfg.glaciate_pending_s)
      _set_branch_stage(glaciate_tgt, "glaciate_burst")
      return
    end
  end)
end

function MGD.on_payload_sent(payload)
  return MGD.on_payload_queued(payload)
end

function MGD.on_payload_fired(payload)
  payload = payload or {}
  MGD.state.last_fired_cmd = _trim(payload.eq or payload.cmd or "")
  MGD.state.last_fired_at = _now()
end

function MGD.on_enter(ctx)
  MGD.init()
  return true
end

function MGD.on_exit(ctx)
  if Yso and Yso.mode and type(Yso.mode.stop_route_loop) == "function" then
    Yso.mode.stop_route_loop("magi_group_damage", "exit", true)
  end
  MGD.reset("exit")
  _clear_eq_queue()
  return true
end

function MGD.on_target_swap(old_target, new_target)
  if not _same_target(old_target, new_target) then
    _clear_pending_all()
    _reset_cold("target_swap")
    _reset_route("target_swap")
    _clear_eq_queue()
    _clear_runtime_state("target_swap")
    if MGD.state.loop_enabled == true then
      MGD.schedule_loop(0)
    end
  end
  return true
end

function MGD.on_pause(ctx)
  return true
end

function MGD.on_resume(ctx)
  if MGD.state and MGD.state.loop_enabled == true then
    MGD.schedule_loop(0)
  end
  return true
end

function MGD.on_manual_success(ctx)
  if MGD.state and MGD.state.loop_enabled == true then
    MGD.schedule_loop(MGD.state.loop_delay)
  end
  return true
end

function MGD.on_send_result(payload, ctx)
  MGD.on_payload_fired(payload)
  return true
end

function MGD.schedule_loop(delay)
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    return Yso.mode.schedule_route_loop("magi_group_damage", delay)
  end
  return false
end

MGD.alias_loop_stop_details = MGD.alias_loop_stop_details or {
  inactive = true,
  disabled = true,
  no_target = true,
  invalid_target = true,
  wrong_class = true,
}

function MGD.alias_loop_prepare_start(ctx)
  MGD.init()
  return ctx or {}
end

function MGD.alias_loop_on_started(ctx)
  _clear_pending_all()
  _reset_cold("loop_start")
  _reset_route("loop_start")
  _clear_eq_queue()
  _clear_runtime_state("loop_start")
  _echo("Group damage loop ON.")
  local tgt = _target()
  if tgt == "" then
    _echo("No target yet; holding.")
  elseif not _tgt_valid(tgt) then
    _echo(string.format("%s is not in room; holding.", tgt))
  end
end

function MGD.alias_loop_on_stopped(ctx)
  MGD.init()
  ctx = ctx or {}
  local reason = tostring(ctx.reason or "manual")
  _clear_pending_all()
  _reset_cold(reason)
  _reset_route(reason)
  _clear_eq_queue()
  _clear_runtime_state(reason)
  MGD.state.template.last_disable_reason = reason
  if ctx.silent ~= true then
    _echo(string.format("Group damage loop OFF (%s).", reason))
  end
end

function MGD.alias_loop_waiting_blocks()
  return false
end

function MGD.alias_loop_clear_waiting()
  return true
end

function MGD.alias_loop_on_error(err)
  _echo("Magi team damage loop error: " .. tostring(err))
end

if Yso and Yso.off and Yso.off.core and type(Yso.off.core.register) == "function" then
  pcall(Yso.off.core.register, "magi_group_damage", MGD)
end

return MGD
