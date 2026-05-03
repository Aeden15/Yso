--========================================================--
-- magi_focus.lua
--  * Duel affliction / convergence route for Magi.
--  * Keeps route-local priorities local while sharing chassis helpers.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.magi = Yso.off.magi or {}
Yso.magi = Yso.magi or {}

Yso.off.magi.focus = Yso.off.magi.focus or {}
local MF = Yso.off.magi.focus
MF.alias_owned = true

local function _load_magi_peer(file_name)
  local info = debug.getinfo(1, "S")
  local source = info and info.source or ""
  if source:sub(1, 1) ~= "@" then return false end
  local dir = source:sub(2):match("^(.*)[/\\][^/\\]+$") or "."
  local path = dir .. "/" .. tostring(file_name or "")
  return pcall(dofile, path)
end

local function _ensure_magi_peer(mod_name, file_name, getter)
  local value = getter()
  if type(value) == "table" then return value end
  if type(require) == "function" then
    pcall(require, mod_name)
    value = getter()
  end
  if type(value) == "table" then return value end
  _load_magi_peer(file_name)
  value = getter()
  assert(type(value) == "table", tostring(mod_name) .. " unavailable")
  return value
end

local RC = _ensure_magi_peer("magi_route_core", "magi_route_core.lua", function()
  return Yso and Yso.off and Yso.off.magi and Yso.off.magi.route_core or nil
end)

local Dissonance = _ensure_magi_peer("magi_dissonance", "magi_dissonance.lua", function()
  return Yso and Yso.magi and Yso.magi.dissonance or nil
end)

local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
if not (RI and type(RI.ensure_hooks) == "function") and type(require) == "function" then
  pcall(require, "Yso.Combat.route_interface")
  pcall(require, "Yso.xml.route_interface")
  RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
end

local PENDING_SLOTS = {
  "horripilation",
  "freeze",
  "bombard",
  "fulminate",
  "firelash",
  "magma",
  "dissonance",
  "convergence",
  "destroy",
}

MF.route_contract = MF.route_contract or {
  id = "magi_focus",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "opener_setup",
    "freeze_reopen",
    "resonance_progress",
    "fulminate_branch",
    "dissonance_push",
    "convergence_now",
    "postconv_finish",
    "maintenance",
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
  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(MF, MF.route_contract)
  end
end

MF.cfg = MF.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,
  same_target_repeat_s = 0.75,
  horripilation_pending_s = 1.00,
  freeze_pending_s = 1.00,
  bombard_pending_s = 1.00,
  fulminate_pending_s = 1.00,
  firelash_pending_s = 1.00,
  magma_pending_s = 1.00,
  dissonance_pending_s = 4.00,
  convergence_pending_s = 1.00,
  destroy_pending_s = 1.00,
  destroy_hp_threshold = 40,
  destroy_require_conflagration = true,
  destroy_enforce_hp_gate = false,
}

MF.state = MF.state or {
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
  pending = {},
  route = {
    target = "",
    room_id = "",
    phase = "reset",
    subphase = "reset",
    bucket = "reset",
    postconv = false,
    last_reset_reason = "init",
  },
  waiting = { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" },
  in_flight = { fingerprint = "", target = "", route = "magi_focus", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" },
}

local function _trim(s) return RC.trim(s) end
local function _lc(s) return RC.lc(s) end
local function _same_target(a, b) return RC.same_target(a, b) end
local function _now() return RC.now() end

local function _echo(msg)
  if MF.cfg.echo ~= true then return end
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

local function _target() return RC.get_target() end
local function _room_id() return RC.room_id() end
local function _tgt_valid(tgt) return RC.target_valid(tgt) end
local function _eq_ready() return RC.eq_ready() end
local function _score_positive(aff) return RC.has_aff(aff) end

local function _kelpscore()
  local A = rawget(_G, "affstrack")
  if type(A) == "table" and tonumber(A.kelpscore) then
    return tonumber(A.kelpscore) or 0
  end
  return 0
end

local function _combat_focus_context_active()
  return _is_magi() and Yso and Yso.mode and type(Yso.mode.is_combat) == "function" and Yso.mode.is_combat() == true
end

local function _route_is_active()
  if not _combat_focus_context_active() then return false end
  if Yso and Yso.mode and type(Yso.mode.route_loop_active) == "function" then
    if Yso.mode.route_loop_active("magi_focus") == true then return true end
    if Yso.mode.route_loop_active("focus") == true then return true end
    return false
  end
  return MF.state and MF.state.loop_enabled == true
end

local function _set_loop_enabled(on)
  local enabled = (on == true)
  MF.state.enabled = enabled
  MF.state.loop_enabled = enabled
  MF.cfg.enabled = enabled
end

local function _pending_slot(name) return RC.pending_slot(MF.state, name) end
local function _clear_pending(name) return RC.clear_pending(MF.state, name) end
local function _clear_pending_all() return RC.clear_pending_all(MF.state, PENDING_SLOTS) end
local function _mark_pending(name, tgt, seconds) return RC.mark_pending(MF.state, name, tgt, seconds) end
local function _pending_active(name, tgt) return RC.pending_active(MF.state, name, tgt) end

local function _spell_guard(slot_name, tgt, cmd)
  return RC.guard_spell({
    state = MF.state,
    cfg = MF.cfg,
    slot = slot_name,
    target = tgt,
    cmd = cmd,
    target_valid = _tgt_valid(tgt),
    eq_ready = _eq_ready(),
  })
end

local function _route_slot()
  MF.state.route = MF.state.route or {
    target = "",
    room_id = "",
    phase = "reset",
    subphase = "reset",
    bucket = "reset",
    postconv = false,
    last_reset_reason = "init",
  }
  return MF.state.route
end

local function _reset_route(reason)
  local route = _route_slot()
  route.target = ""
  route.room_id = ""
  route.phase = "reset"
  route.subphase = "reset"
  route.bucket = "reset"
  route.postconv = false
  route.last_reset_reason = tostring(reason or "")
  return route
end

local function _ensure_context(tgt)
  local room = _room_id()
  local route = _route_slot()
  local room_changed = route.room_id ~= "" and room ~= "" and route.room_id ~= room
  local target_changed = route.target ~= "" and tgt ~= "" and not _same_target(route.target, tgt)

  if room_changed then
    route = _reset_route("room_change")
  elseif target_changed then
    route = _reset_route("target_change")
  end

  route.target = _trim(tgt or "")
  route.room_id = room
  return route
end

local function _set_route_stage(tgt, phase, subphase, bucket)
  local route = _ensure_context(tgt)
  route.phase = tostring(phase or "")
  route.subphase = tostring(subphase or "")
  route.bucket = tostring(bucket or "")
  return route
end

local function _set_postconv(tgt, on)
  local route = _ensure_context(tgt)
  route.postconv = (on == true)
  if route.postconv == true and route.phase ~= "postconv" then
    route.phase = "postconv"
  end
  return route
end

local function _freeze_package_intact(st)
  return (st.frozen == true and st.frostbite == true) or st.pending.freeze == true
end

local function _focus_armed()
  local crystal = Yso and Yso.magi and Yso.magi.crystalism or nil
  if type(crystal) == "table" and type(crystal.has_focus) == "function" then
    local ok, v = pcall(crystal.has_focus)
    if ok then return v == true end
  end
  return false
end

local function _fulm_stage_from_state(st)
  if st.paralysis == true then return 3 end
  if st.epilepsy == true then return 2 end
  if st.fulminated == true or st.pending.fulminate == true then return 1 end
  return 0
end

local function _fulm_reason(st)
  if st.fulm_stage <= 0 then return "fulminate_seed" end
  if st.fulm_stage == 1 then return "epilepsy_missing" end
  if st.fulm_stage == 2 then return "paralysis_missing" end
  return "fulminate_live"
end

local function _destroy_aff_present(st)
  return st.conflagrate == true or st.conflagration == true
end

local function _target_hp_percent()
  if Yso and Yso.magi and Yso.magi.elemental and type(Yso.magi.elemental.get_target_hp_percent) == "function" then
    local ok, v = pcall(Yso.magi.elemental.get_target_hp_percent)
    if ok and tonumber(v) then return tonumber(v) end
  end
  return nil
end

local function _destroy_window()
  if MF.cfg.destroy_enforce_hp_gate == true then
    local hp = _target_hp_percent()
    if hp == nil then return false, "hp_unknown", "unknown" end
    if hp > (tonumber(MF.cfg.destroy_hp_threshold or 40) or 40) then
      return false, "hp_window_closed", string.format("%.1f>%d", hp, tonumber(MF.cfg.destroy_hp_threshold or 40) or 40)
    end
    return true, "", string.format("%.1f<=%d", hp, tonumber(MF.cfg.destroy_hp_threshold or 40) or 40)
  end
  return true, "", "stubbed"
end

local function _conv_missing(res)
  local out = {}
  if tonumber(res.air or 0) < 2 then out[#out + 1] = "air" end
  if tonumber(res.earth or 0) < 2 then out[#out + 1] = "earth" end
  if tonumber(res.fire or 0) < 2 then out[#out + 1] = "fire" end
  if tonumber(res.water or 0) < 2 then out[#out + 1] = "water" end
  return out
end

local function _next_conv_gate(st)
  if #st.conv_missing > 0 then return "moderate:" .. table.concat(st.conv_missing, "/") end
  if st.dissonance_stage < 4 then return "dissonance:" .. tostring(st.dissonance_stage) end
  return "ready"
end

local function _conv_blocker(st)
  if #st.conv_missing > 0 then
    return "missing_moderate:" .. table.concat(st.conv_missing, "/")
  end
  if st.dissonance_stage < 4 then
    return "dissonance_stage_" .. tostring(st.dissonance_stage)
  end
  return ""
end

local function _choose_threshold_rule(st)
  if st.postconv == true then return "postconv_overlay" end
  if st.kelpscore > 1 and st.fulm_stage < 3 and st.conv_ready ~= true then
    return "kelp_pressure_established"
  end
  if st.bombard_need == true then
    return st.bombard_reason
  end
  if tonumber(st.res.fire or 0) < 2 then
    return "fire_moderate_missing"
  end
  if st.dissonance_stage < 4 then
    return "dissonance_stage_" .. tostring(st.dissonance_stage)
  end
  return "maintenance"
end

local function _snapshot(tgt)
  local base = RC.build_snapshot({
    state = MF.state,
    target = tgt,
    affs = {
      "waterbonds",
      "frozen",
      "frostbite",
      "clumsiness",
      "asthma",
      "fulminated",
      "epilepsy",
      "paralysis",
      "dissonance",
      "conflagrate",
      "conflagration",
      "scalded",
    },
    pending_slots = PENDING_SLOTS,
  })
  local route = _ensure_context(tgt)
  local dis = Dissonance.snapshot(tgt)

  if tonumber(base.raw.dissonance or 0) > 0 and tonumber(dis.stage or 0) < 1 then
    Dissonance.note(tgt, "tracked", { stage = 1, confidence = "medium", evidence = "ak_dissonance" })
    dis = Dissonance.snapshot(tgt)
  end

  local st = {
    target = base.target,
    room_id = base.room_id,
    target_valid = base.target_valid,
    eq_ready = base.eq_ready,
    waterbonds = base.waterbonds == true or base.pending.horripilation == true,
    frozen = base.frozen == true,
    frostbite = base.frostbite == true,
    clumsiness = base.clumsiness == true or base.pending.bombard == true,
    -- Bombard directly inflicts clumsiness, not asthma; asthma comes from Air
    -- resonance procs, so only trust the actual aff state here.
    asthma = base.asthma == true,
    fulminated = base.fulminated == true,
    epilepsy = base.epilepsy == true,
    paralysis = base.paralysis == true,
    dissonance = base.dissonance == true,
    conflagrate = base.conflagrate == true,
    conflagration = base.conflagration == true,
    scalded = base.scalded == true or base.pending.magma == true,
    kelpscore = _kelpscore(),
    res = {
      air = tonumber(base.res.air or 0) or 0,
      earth = tonumber(base.res.earth or 0) or 0,
      fire = tonumber(base.res.fire or 0) or 0,
      water = tonumber(base.res.water or 0) or 0,
      synced = base.res.synced == true,
    },
    pending = base.pending,
    raw = base.raw,
    route = {
      target = route.target,
      room_id = route.room_id,
      phase = route.phase,
      subphase = route.subphase,
      bucket = route.bucket,
      postconv = route.postconv == true,
      last_reset_reason = route.last_reset_reason,
    },
    focus_punish_armed = _focus_armed(),
    dissonance_stage = tonumber(dis.stage or 0) or 0,
    dissonance_confidence = tostring(dis.confidence or "low"),
    dissonance_last_evidence = tostring(dis.last_evidence or ""),
  }

  st.fulm_stage = _fulm_stage_from_state(st)
  st.epilepsy_live = st.epilepsy == true
  st.para_conversion_ready = st.fulm_stage == 2
  st.conv_missing = _conv_missing(st.res)
  st.conv_ready = (#st.conv_missing == 0) and st.dissonance_stage >= 4
  st.conv_blocker = _conv_blocker(st)
  st.next_gate = _next_conv_gate(st)
  st.postconv = st.route.postconv == true
  st.freeze_package_intact = _freeze_package_intact(st)
  st.freeze_missing = st.freeze_package_intact ~= true
  st.water_moderate_ready = tonumber(st.res.water or 0) >= 2
  st.freeze_requires_water_refresh = st.freeze_missing == true and st.water_moderate_ready ~= true

  st.bombard_reason = ""
  if st.clumsiness ~= true then
    st.bombard_reason = "clumsiness_missing"
  elseif st.asthma ~= true then
    st.bombard_reason = "asthma_missing"
  elseif st.res.air < 2 and st.res.earth < 2 then
    st.bombard_reason = "air_earth_moderate_missing"
  elseif st.res.air < 2 then
    st.bombard_reason = "air_moderate_missing"
  elseif st.res.earth < 2 then
    st.bombard_reason = "earth_moderate_missing"
  end
  st.bombard_need = st.bombard_reason ~= ""
  st.fulminate_need = st.kelpscore > 1 and st.fulm_stage < 3 and st.conv_ready ~= true
  st.threshold_rule = _choose_threshold_rule(st)

  local hp_open, hp_blocker, hp_window = _destroy_window()
  st.destroy_ready = st.postconv == true and _destroy_aff_present(st) and hp_open == true
  st.destroy_blocker = ""
  if st.postconv ~= true then
    st.destroy_blocker = "postconv_required"
  elseif MF.cfg.destroy_require_conflagration ~= false and not _destroy_aff_present(st) then
    st.destroy_blocker = "conflagration_missing"
  elseif hp_open ~= true then
    st.destroy_blocker = hp_blocker
  end
  st.destroy_hp_window = hp_window
  return st
end

local function _can_staffcast_horripilation(tgt)
  local cmd = ("staff cast horripilation %s"):format(tgt)
  local ok, why = _spell_guard("horripilation", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_freeze(tgt)
  local cmd = ("cast freeze at %s"):format(tgt)
  local ok, why = _spell_guard("freeze", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_bombard(tgt)
  local cmd = ("cast bombard at %s"):format(tgt)
  local ok, why = _spell_guard("bombard", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_fulminate(tgt)
  local cmd = ("cast fulminate at %s"):format(tgt)
  local ok, why = _spell_guard("fulminate", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_firelash(tgt)
  local cmd = ("cast firelash at %s"):format(tgt)
  local ok, why = _spell_guard("firelash", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_magma(tgt)
  local cmd = ("cast magma at %s"):format(tgt)
  local ok, why = _spell_guard("magma", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_convergence(tgt)
  local cmd = ("cast convergence at %s"):format(tgt)
  local ok, why = _spell_guard("convergence", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_destroy(tgt)
  local cmd = ("cast destroy at %s"):format(tgt)
  local ok, why = _spell_guard("destroy", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_or_embed_dissonance_builder(tgt)
  local cmd = "embed dissonance"
  local ok, why = _spell_guard("dissonance", tgt, cmd)
  return ok, why, cmd
end

local function _choice(cmd, category, decision, reason, phase, subphase, bucket)
  return {
    cmd = cmd,
    category = category,
    decision = decision,
    reason = reason,
    phase = phase,
    subphase = subphase,
    bucket = bucket,
  }
end

local function _reject(rejects, decision, reason)
  rejects[#rejects + 1] = {
    decision = tostring(decision or ""),
    reason = tostring(reason or ""),
  }
end

local function _pick_bombard_revisit(st, rejects)
  if st.bombard_need ~= true then
    _reject(rejects, "bombard_revisit", "not_needed")
    return nil
  end
  local ok, why, cmd = _can_cast_bombard(st.target)
  if ok then
    return _choice(cmd, "resonance_progress", "bombard_revisit", st.bombard_reason, "progress", "bombard", "resonance_progress")
  end
  _reject(rejects, "bombard_revisit", why ~= "" and why or st.bombard_reason)
  return nil
end

local function _pick_fulminate_branch(st, rejects)
  if st.fulminate_need ~= true then
    _reject(rejects, "fulminate_continue", "not_needed")
    return nil
  end
  local ok, why, cmd = _can_cast_fulminate(st.target)
  if ok then
    return _choice(cmd, "fulminate_branch", "fulminate_continue", _fulm_reason(st), "progress", "fulminate", "fulminate_branch")
  end
  _reject(rejects, "fulminate_continue", why ~= "" and why or _fulm_reason(st))
  return nil
end

local function _pick_fire_progress(st, rejects)
  if tonumber(st.res.fire or 0) >= 2 then
    _reject(rejects, "fire_progress", "fire_moderate_ready")
    return nil
  end

  if st.scalded ~= true or tonumber(st.res.earth or 0) < 2 then
    local ok_magma, why_magma, cmd_magma = _can_cast_magma(st.target)
    if ok_magma then
      local why = (tonumber(st.res.earth or 0) < 2) and "fire_earth_progress" or "fire_progress_scalded"
      return _choice(cmd_magma, "resonance_progress", "fire_progress", why, "progress", "fire", "resonance_progress")
    end
    _reject(rejects, "fire_progress_magma", why_magma ~= "" and why_magma or "magma_blocked")
  end

  local ok, why, cmd = _can_cast_firelash(st.target)
  if ok then
    return _choice(cmd, "resonance_progress", "fire_progress", "fire_moderate_missing", "progress", "fire", "resonance_progress")
  end
  _reject(rejects, "fire_progress_firelash", why ~= "" and why or "firelash_blocked")
  return nil
end

local function _pick_dissonance_push(st, rejects)
  if st.dissonance_stage >= 4 then
    _reject(rejects, "dissonance_push", "stage_4")
    return nil
  end
  local ok, why, cmd = _can_cast_or_embed_dissonance_builder(st.target)
  if ok then
    return _choice(cmd, "dissonance_push", "dissonance_push", "dissonance_stage_" .. tostring(st.dissonance_stage), "gate", "dissonance", "dissonance_push")
  end
  _reject(rejects, "dissonance_push", why ~= "" and why or ("dissonance_stage_" .. tostring(st.dissonance_stage)))
  return nil
end

local function _pick_postconv_action(st, rejects)
  if st.postconv ~= true then
    _reject(rejects, "postconv_action", "postconv_false")
    return nil
  end

  if st.destroy_ready == true then
    local ok, why, cmd = _can_cast_destroy(st.target)
    if ok then
      return _choice(cmd, "postconv_finish", "destroy_now", "destroy_ready", "postconv", "destroy", "postconv_finish")
    end
    _reject(rejects, "destroy_now", why ~= "" and why or "destroy_ready")
  else
    _reject(rejects, "destroy_now", st.destroy_blocker)
  end

  if st.fulminate_need == true then
    local ok, why, cmd = _can_cast_fulminate(st.target)
    if ok then
      return _choice(cmd, "postconv_finish", "fulminate_continue", _fulm_reason(st), "postconv", "fulminate", "postconv_finish")
    end
    _reject(rejects, "postconv_fulminate", why ~= "" and why or _fulm_reason(st))
  end

  if st.scalded ~= true then
    local ok_magma, why_magma, cmd_magma = _can_cast_magma(st.target)
    if ok_magma then
      return _choice(cmd_magma, "postconv_finish", "burst_pressure", "postconv_magma_pressure", "postconv", "burst", "postconv_finish")
    end
    _reject(rejects, "postconv_magma", why_magma ~= "" and why_magma or "magma_blocked")
  end

  do
    local ok_firelash, why_firelash, cmd_firelash = _can_cast_firelash(st.target)
    if ok_firelash then
      return _choice(cmd_firelash, "postconv_finish", "burst_pressure", "postconv_firelash_pressure", "postconv", "burst", "postconv_finish")
    end
    _reject(rejects, "postconv_firelash", why_firelash ~= "" and why_firelash or "firelash_blocked")
  end

  if st.freeze_missing == true then
    local ok, why, cmd = _can_cast_freeze(st.target)
    if ok then
      return _choice(cmd, "maintenance", "maintenance_refresh", "freeze_package_incomplete", "postconv", "maintenance", "maintenance")
    end
    _reject(rejects, "postconv_freeze", why ~= "" and why or "freeze_package_incomplete")
  end

  if st.bombard_need == true then
    local ok, why, cmd = _can_cast_bombard(st.target)
    if ok then
      return _choice(cmd, "maintenance", "maintenance_refresh", st.bombard_reason, "postconv", "maintenance", "maintenance")
    end
    _reject(rejects, "postconv_bombard", why ~= "" and why or st.bombard_reason)
  end

  return nil
end

local function _select_command(tgt)
  local st = _snapshot(tgt)
  local rejects = {}

  if st.target_valid ~= true then
    _set_route_stage(tgt, "hold", "invalid_target", "maintenance")
    return nil, st, rejects, "invalid_target"
  end

  if st.waterbonds ~= true then
    local ok, why, cmd = _can_staffcast_horripilation(tgt)
    _set_route_stage(tgt, ok and "opener" or "hold", "horripilation", "opener_setup")
    if ok then
      return _choice(cmd, "opener_setup", "horripilation_open", "waterbonds_missing", "opener", "horripilation", "opener_setup"), st, rejects, ""
    end
    _reject(rejects, "horripilation_open", why ~= "" and why or "waterbonds_missing")
    return nil, st, rejects, why ~= "" and why or "waterbonds_missing"
  end

  if st.freeze_missing == true and st.postconv ~= true then
    if st.freeze_requires_water_refresh == true then
      local ok, why, cmd = _can_cast_freeze(tgt)
      _set_route_stage(tgt, ok and "opener" or "hold", "freeze", "freeze_reopen")
      if ok then
        return _choice(cmd, "freeze_reopen", "freeze_reopen", "water_moderate_missing", "opener", "freeze", "freeze_reopen"), st, rejects, ""
      end
      _reject(rejects, "freeze_reopen", why ~= "" and why or "water_moderate_missing")
      return nil, st, rejects, why ~= "" and why or "water_moderate_missing"
    end
    _reject(rejects, "freeze_reopen", "deferred_for_resonance_pivot")
  end

  if st.postconv == true then
    local postconv = _pick_postconv_action(st, rejects)
    if postconv then
      _set_route_stage(tgt, postconv.phase, postconv.subphase, postconv.bucket)
      return postconv, st, rejects, ""
    end
    _set_route_stage(tgt, "hold", "postconv", "postconv_finish")
    return nil, st, rejects, "postconv_no_legal_action"
  end

  if st.conv_ready == true then
    local ok, why, cmd = _can_cast_convergence(tgt)
    _set_route_stage(tgt, ok and "gate" or "hold", "convergence", "convergence_now")
    if ok then
      return _choice(cmd, "convergence_now", "convergence_now", "all_gates_satisfied", "gate", "convergence", "convergence_now"), st, rejects, ""
    end
    _reject(rejects, "convergence_now", why ~= "" and why or "all_gates_satisfied")
    return nil, st, rejects, why ~= "" and why or "all_gates_satisfied"
  end
  _reject(rejects, "convergence_now", st.conv_blocker)

  local bombard = _pick_bombard_revisit(st, rejects)
  if bombard then
    _set_route_stage(tgt, bombard.phase, bombard.subphase, bombard.bucket)
    return bombard, st, rejects, ""
  end

  local fulm = _pick_fulminate_branch(st, rejects)
  if fulm then
    _set_route_stage(tgt, fulm.phase, fulm.subphase, fulm.bucket)
    return fulm, st, rejects, ""
  end

  local fire = _pick_fire_progress(st, rejects)
  if fire then
    _set_route_stage(tgt, fire.phase, fire.subphase, fire.bucket)
    return fire, st, rejects, ""
  end

  local diss = _pick_dissonance_push(st, rejects)
  if diss then
    _set_route_stage(tgt, diss.phase, diss.subphase, diss.bucket)
    return diss, st, rejects, ""
  end

  if st.freeze_missing == true then
    local ok, why, cmd = _can_cast_freeze(tgt)
    if ok then
      _set_route_stage(tgt, "maintenance", "freeze", "maintenance")
      return _choice(cmd, "maintenance", "maintenance_refresh", "freeze_package_incomplete", "maintenance", "freeze", "maintenance"), st, rejects, ""
    end
    _reject(rejects, "maintenance_freeze", why ~= "" and why or "freeze_package_incomplete")
  end

  _set_route_stage(tgt, "hold", "idle", "maintenance")
  return nil, st, rejects, "no_legal_action"
end

local function _is_destroy_cmd(cmd)
  return _lc(cmd):match("^cast%s+destroy%s+at%s+") ~= nil
end

local function _apply_execute_opts(opts, payload)
  local cmd = type(payload) == "table" and _trim(payload.eq) or ""
  if _is_destroy_cmd(cmd) then
    opts.queue_verb = "addclearfull"
    opts.clearfull_lane = "eq"
  end
  return opts
end

local function _clear_eq_queue()
  if Yso and Yso.queue and type(Yso.queue.clear) == "function" then
    pcall(Yso.queue.clear, "eq")
  end
end

local function _emit_payload(payload, category)
  local opts = {
    reason = "magi_focus:" .. tostring(category or "attack"),
    kind = "offense",
    commit = true,
    route = "magi_focus",
    target = _trim(type(payload) == "table" and payload.target or ""),
  }
  _apply_execute_opts(opts, payload)

  if RI and type(RI.emit_route_payload) == "function" then
    return RI.emit_route_payload("magi_focus", {
      target = opts.target,
      lanes = { eq = payload and payload.eq },
      meta = {
        route = "magi_focus",
        main_lane = "eq",
        main_category = tostring(category or ""),
      },
    }, opts)
  end

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
  local row = payload.eq
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

local function _update_explain(tgt, st, choice, rejects, blocker)
  local route = _route_slot()
  MF.state.explain = RC.build_explain({
    route = "focus",
    target = tgt,
    active = MF.is_active and MF.is_active() or false,
    route_enabled = MF.is_enabled and MF.is_enabled() or false,
    debug = MF.state and MF.state.debug == true or false,
    postconv = st and st.postconv == true or false,
    stage = route.phase or "",
    phase = route.phase or "",
    subphase = route.subphase or "",
    bucket = route.bucket or "",
    decision = choice and choice.decision or "",
    reason = choice and choice.reason or "",
    blocker = blocker or "",
    planned = { eq = choice and choice.cmd or "" },
    threshold_rule = st and st.threshold_rule or "",
    resonance = st and {
      air = st.res.air,
      earth = st.res.earth,
      fire = st.res.fire,
      water = st.res.water,
      missing_moderate = table.concat(st.conv_missing or {}, "/"),
      water_moderate_ready = st.water_moderate_ready == true,
    } or {},
    freeze = st and {
      freeze_missing = st.freeze_missing == true,
      freeze_package_intact = st.freeze_package_intact == true,
      water_refresh_required = st.freeze_requires_water_refresh == true,
    } or {},
    dissonance = st and {
      stage = st.dissonance_stage,
      confidence = st.dissonance_confidence,
      last_evidence = st.dissonance_last_evidence,
    } or {},
    pressure = st and { kelpscore = st.kelpscore, threshold_rule = st.threshold_rule } or {},
    fulminate = st and {
      focus_punish_armed = st.focus_punish_armed == true,
      epilepsy_live = st.epilepsy_live == true,
      para_conversion_ready = st.para_conversion_ready == true,
    } or {},
    convergence = st and {
      conv_ready = st.conv_ready == true,
      conv_blocker = st.conv_blocker,
      next_gate = st.next_gate,
    } or {},
    destroy = st and {
      destroy_ready = st.destroy_ready == true,
      destroy_blocker = st.destroy_blocker,
      conflagration = _destroy_aff_present(st),
      hp_window = st.destroy_hp_window,
    } or {},
    rejects = rejects or {},
    state = st or {},
    last_cmd = MF.state and MF.state.last_cmd or "",
    last_sent_cmd = MF.state and MF.state.last_sent_cmd or "",
    pending = MF.state and MF.state.pending or {},
  })
end

local function _clear_runtime_state(reason)
  RC.reset_runtime_state(MF.state, reason)
end

function MF.init()
  MF.cfg = MF.cfg or {}
  MF.state = MF.state or {}
  MF.state.template = MF.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  RC.ensure_pending(MF.state, PENDING_SLOTS)
  if RI and type(RI.ensure_waiting_state) == "function" then
    RI.ensure_waiting_state(MF.state, "magi_focus")
  end
  _route_slot()
  MF.state.loop_delay = tonumber(MF.state.loop_delay or MF.cfg.loop_delay or 0.15) or 0.15
  MF.state.busy = (MF.state.busy == true)
  _set_loop_enabled((MF.state.loop_enabled == true) or (MF.state.enabled == true))
  return true
end

function MF.reset(reason)
  MF.init()
  _clear_pending_all()
  _reset_route(reason or "manual")
  _clear_runtime_state(reason or "manual")
  if RI and type(RI.clear_waiting) == "function" then
    RI.clear_waiting(MF.state, "magi_focus")
  end
  Dissonance.reset()
  return true
end

function MF.is_enabled()
  return MF.state and MF.state.enabled == true
end

function MF.is_active()
  return _route_is_active()
end

function MF.can_run(ctx)
  MF.init()
  if not MF.is_enabled() then return false, "disabled" end
  if not MF.is_active() then return false, "inactive" end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return false, "paused" end

  local tgt = _trim((ctx and ctx.target) or _target())
  if tgt == "" then
    _reset_route("no_target")
    return false, "no_target"
  end
  if not _is_magi() then return false, "wrong_class" end
  if not _tgt_valid(tgt) then
    _reset_route("invalid_target")
    return false, "invalid_target"
  end
  _ensure_context(tgt)
  return true, tgt
end

function MF.attack_function(arg)
  local ctx, preview = _attack_opts(arg)
  local ok, info = MF.can_run(ctx)
  if not ok then
    if preview then return nil, info end
    return false, info
  end

  local tgt = info
  if MF.state.last_target ~= "" and not _same_target(MF.state.last_target, tgt) then
    _clear_pending_all()
    _reset_route("target_swap")
    _clear_runtime_state("target_swap")
    Dissonance.reset()
  end
  MF.state.last_target = tgt

  local choice, st, rejects, blocker = _select_command(tgt)
  MF.state.template.last_reason = blocker
  MF.state.template.last_target = tgt
  _update_explain(tgt, st, choice, rejects, blocker)

  if not choice or _trim(choice.cmd) == "" then
    MF.state.template.last_payload = nil
    if preview then return nil, blocker end
    return false, blocker
  end

  local payload = {
    route = "magi_focus",
    target = tgt,
    lanes = { eq = choice.cmd },
    meta = {
      main_lane = "eq",
      main_category = choice.category,
      main_reason = choice.reason,
      decision = choice.decision,
      state = st,
      rejects = rejects,
      explain = MF.state.explain,
    },
  }

  MF.state.template.last_payload = payload

  if preview then return payload end

  local queued_payload = { eq = choice.cmd, target = tgt }
  local sent, emit_detail, ack_payload = _emit_payload(queued_payload, choice.category)
  if sent ~= true then return false, emit_detail or "emit_failed" end
  if RI and type(RI.mark_waiting) == "function" then
    RI.mark_waiting(MF.state, "magi_focus", ack_payload or queued_payload, {
      cmd = _trim(choice.cmd),
      target = tgt,
      main_lane = "eq",
    })
  end
  local has_ack_bus = Yso and Yso.locks and type(Yso.locks.note_payload) == "function"
  if not has_ack_bus and type(MF.on_payload_queued) == "function" then
    pcall(MF.on_payload_queued, ack_payload or queued_payload)
  end

  MF.state.last_cmd = choice.cmd
  MF.state.last_category = choice.category
  return true, choice.cmd, payload
end

function MF.build_payload(ctx)
  return MF.attack_function({ ctx = ctx, preview = true })
end

function MF.build(reason)
  local ctx = type(reason) == "table" and reason or { reason = tostring(reason or "") }
  return MF.build_payload(ctx)
end

function MF.evaluate(ctx)
  local payload, why = MF.build_payload(ctx)
  if not payload then return { ok = false, reason = why } end
  return { ok = true, payload = payload }
end

function MF.explain()
  MF.init()
  local ex = type(MF.state.explain) == "table" and MF.state.explain or {}
  local tgt = _target()
  local st = _snapshot(tgt)
  local route = _route_slot()
  ex.route = "focus"
  ex.enabled = MF.is_enabled()
  ex.route_enabled = MF.is_enabled()
  ex.active = MF.is_active()
  ex.target = tgt
  ex.last_reason = MF.state and MF.state.template and MF.state.template.last_reason or ""
  ex.last_disable_reason = MF.state and MF.state.template and MF.state.template.last_disable_reason or ""
  ex.last_cmd = MF.state and MF.state.last_cmd or ""
  ex.last_sent_cmd = MF.state and MF.state.last_sent_cmd or ""
  ex.stage = route.phase or ex.stage or ""
  ex.phase = route.phase or ex.phase or ""
  ex.subphase = route.subphase or ex.subphase or ""
  ex.bucket = route.bucket or ex.bucket or ""
  ex.postconv = route.postconv == true
  ex.decision = ex.decision or (MF.state and MF.state.last_category or "")
  ex.state = st
  ex.pending = MF.state and MF.state.pending or {}
  return ex
end

function MF.status()
  return MF.explain()
end

function MF.on_payload_queued(payload)
  _payload_each_eq(payload, function(cmd)
    cmd = _trim(cmd)
    if cmd == "" then return end

    local lc = _lc(cmd)
    MF.state.last_sent_cmd = cmd
    MF.state.last_sent_at = _now()

    local horr_tgt = _capture_target(lc, "^staff%s+cast%s+horripilation%s+(.+)$")
    if horr_tgt ~= "" then
      MF.state.last_sent_target = horr_tgt
      MF.state.last_sent_category = "opener_setup"
      _mark_pending("horripilation", horr_tgt, MF.cfg.horripilation_pending_s)
      _set_route_stage(horr_tgt, "opener", "horripilation", "opener_setup")
      return
    end

    local freeze_tgt = _capture_target(lc, "^cast%s+freeze%s+at%s+(.+)$")
    if freeze_tgt ~= "" then
      MF.state.last_sent_target = freeze_tgt
      MF.state.last_sent_category = "freeze_reopen"
      _mark_pending("freeze", freeze_tgt, MF.cfg.freeze_pending_s)
      _set_route_stage(freeze_tgt, "opener", "freeze", "freeze_reopen")
      return
    end

    local bombard_tgt = _capture_target(lc, "^cast%s+bombard%s+at%s+(.+)$")
    if bombard_tgt ~= "" then
      MF.state.last_sent_target = bombard_tgt
      MF.state.last_sent_category = "resonance_progress"
      _mark_pending("bombard", bombard_tgt, MF.cfg.bombard_pending_s)
      _set_route_stage(bombard_tgt, "progress", "bombard", "resonance_progress")
      return
    end

    local fulm_tgt = _capture_target(lc, "^cast%s+fulminate%s+at%s+(.+)$")
    if fulm_tgt ~= "" then
      MF.state.last_sent_target = fulm_tgt
      MF.state.last_sent_category = "fulminate_branch"
      _mark_pending("fulminate", fulm_tgt, MF.cfg.fulminate_pending_s)
      _set_route_stage(fulm_tgt, "progress", "fulminate", "fulminate_branch")
      return
    end

    local firelash_tgt = _capture_target(lc, "^cast%s+firelash%s+at%s+(.+)$")
    if firelash_tgt ~= "" then
      MF.state.last_sent_target = firelash_tgt
      MF.state.last_sent_category = "resonance_progress"
      _mark_pending("firelash", firelash_tgt, MF.cfg.firelash_pending_s)
      _set_route_stage(firelash_tgt, "progress", "fire", "resonance_progress")
      return
    end

    local magma_tgt = _capture_target(lc, "^cast%s+magma%s+at%s+(.+)$")
    if magma_tgt ~= "" then
      MF.state.last_sent_target = magma_tgt
      MF.state.last_sent_category = "resonance_progress"
      _mark_pending("magma", magma_tgt, MF.cfg.magma_pending_s)
      _set_route_stage(magma_tgt, "progress", "fire", "resonance_progress")
      return
    end

    if lc == "embed dissonance" then
      local raw_tgt = MF.state.template and MF.state.template.last_target or ""
      local diss_tgt = _trim(raw_tgt)
      if diss_tgt == "" then diss_tgt = _trim(_target()) end
      if diss_tgt ~= "" then
        MF.state.last_sent_target = diss_tgt
        MF.state.last_sent_category = "dissonance_push"
        _mark_pending("dissonance", diss_tgt, MF.cfg.dissonance_pending_s)
        Dissonance.note(diss_tgt, "route_send", { confidence = "medium", evidence = "embed_dissonance" })
        _set_route_stage(diss_tgt, "gate", "dissonance", "dissonance_push")
      end
      return
    end

    local conv_tgt = _capture_target(lc, "^cast%s+convergence%s+at%s+(.+)$")
    if conv_tgt ~= "" then
      MF.state.last_sent_target = conv_tgt
      MF.state.last_sent_category = "convergence_now"
      _mark_pending("convergence", conv_tgt, MF.cfg.convergence_pending_s)
      _set_postconv(conv_tgt, true)
      _set_route_stage(conv_tgt, "postconv", "convergence", "postconv_finish")
      return
    end

    local destroy_tgt = _capture_target(lc, "^cast%s+destroy%s+at%s+(.+)$")
    if destroy_tgt ~= "" then
      MF.state.last_sent_target = destroy_tgt
      MF.state.last_sent_category = "postconv_finish"
      _mark_pending("destroy", destroy_tgt, MF.cfg.destroy_pending_s)
      _set_route_stage(destroy_tgt, "postconv", "destroy", "postconv_finish")
      return
    end
  end)
end

function MF.on_payload_sent(payload)
  if RI and type(RI.payload_has_any_route) == "function" and RI.payload_has_any_route(payload)
    and not RI.payload_has_route(payload, "magi_focus")
  then
    return false
  end
  if RI and type(RI.clear_waiting_on_ack) == "function" then
    RI.clear_waiting_on_ack(MF.state, "magi_focus", payload, { require_route = false })
  end
  return MF.on_payload_queued(payload)
end

function MF.on_payload_fired(payload)
  payload = payload or {}
  MF.state.last_fired_cmd = _trim(payload.eq or payload.cmd or "")
  MF.state.last_fired_at = _now()
end

function MF.on_enter(ctx)
  MF.init()
  return true
end

function MF.on_exit(ctx)
  if Yso and Yso.mode and type(Yso.mode.stop_route_loop) == "function" then
    Yso.mode.stop_route_loop("magi_focus", "exit", true)
  end
  MF.reset("exit")
  _clear_eq_queue()
  return true
end

function MF.on_target_swap(old_target, new_target)
  if not _same_target(old_target, new_target) then
    _clear_pending_all()
    _reset_route("target_swap")
    _clear_eq_queue()
    _clear_runtime_state("target_swap")
    Dissonance.reset()
    if MF.state.loop_enabled == true then
      MF.schedule_loop(0)
    end
  end
  return true
end

function MF.on_pause(ctx)
  return true
end

function MF.on_resume(ctx)
  if MF.state and MF.state.loop_enabled == true then
    MF.schedule_loop(0)
  end
  return true
end

function MF.on_manual_success(ctx)
  if MF.state and MF.state.loop_enabled == true then
    MF.schedule_loop(MF.state.loop_delay)
  end
  return true
end

function MF.on_send_result(payload, ctx)
  MF.on_payload_fired(payload)
  return true
end

function MF.schedule_loop(delay)
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    return Yso.mode.schedule_route_loop("magi_focus", delay)
  end
  return false
end

MF.alias_loop_stop_details = MF.alias_loop_stop_details or {
  inactive = true,
  disabled = true,
  no_target = true,
  invalid_target = true,
  wrong_class = true,
}

function MF.alias_loop_prepare_start(ctx)
  MF.init()
  return ctx or {}
end

function MF.alias_loop_on_started(ctx)
  _clear_pending_all()
  _reset_route("loop_start")
  _clear_eq_queue()
  _clear_runtime_state("loop_start")
  Dissonance.reset()
  _echo("Focus loop ON.")
  local tgt = _target()
  if tgt == "" then
    _echo("No target yet; holding.")
  elseif not _tgt_valid(tgt) then
    _echo(string.format("%s is not in room; holding.", tgt))
  end
end

function MF.alias_loop_on_stopped(ctx)
  MF.init()
  ctx = ctx or {}
  local reason = tostring(ctx.reason or "manual")
  _clear_pending_all()
  _reset_route(reason)
  _clear_eq_queue()
  _clear_runtime_state(reason)
  Dissonance.reset()
  MF.state.template.last_disable_reason = reason
  if ctx.silent ~= true then
    _echo(string.format("Focus loop OFF (%s).", reason))
  end
end

function MF.alias_loop_waiting_blocks()
  return false
end

function MF.alias_loop_clear_waiting()
  if RI and type(RI.clear_waiting) == "function" then
    return RI.clear_waiting(MF.state, "magi_focus")
  end
  return true
end

function MF.alias_loop_on_error(err)
  _echo("Magi focus loop error: " .. tostring(err))
end

if Yso and Yso.off and Yso.off.core and type(Yso.off.core.register) == "function" then
  pcall(Yso.off.core.register, "magi_focus", MF)
  pcall(Yso.off.core.register, "focus", MF)
end

return MF
