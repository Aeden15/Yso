--========================================================--
-- magi_group_damage.lua
--  * Party damage route for Magi.
--  * Strategy:
--      - CAST FREEZE until AK confirms frozen.
--      - CAST MUDSLIDE when frozen but slickness is missing.
--      - CAST EMANATION AT <target> WATER when frozen+slickness are present,
--        disrupt is missing, and water resonance is major.
--      - CAST GLACIATE as the steady frozen follow-up.
--  * Alias-controlled loop ownership lives in Yso.mode.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.magi = Yso.off.magi or {}

Yso.off.magi.group_damage = Yso.off.magi.group_damage or {}
local MGD = Yso.off.magi.group_damage
Yso.off.magi.dmg = MGD
MGD.alias_owned = true

MGD.route_contract = MGD.route_contract or {
  id = "magi_group_damage",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "freeze_setup",
    "salve_pressure",
    "disrupt_setup",
    "glaciate_burst",
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
  mudslide_pending_s = 0.8,
  emanation_pending_s = 2.6,
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
  last_sent_category = "",
  last_sent_at = 0,
  explain = {},
  template = { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" },
  pending = {
    mudslide = { target = "", until_t = 0 },
    emanation = { target = "", until_t = 0 },
  },
  cold = {
    target = "",
    room_id = "",
    phase = "unknown",
    opened = false,
    seen_frostbite = false,
    seen_frozen = false,
    progressed_at = 0,
  },
}

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _lc(s)
  return _trim(s):lower()
end

local function _same_target(a, b)
  a = _lc(a)
  b = _lc(b)
  return a ~= "" and a == b
end

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    if ok and tonumber(v) then return tonumber(v) end
  end
  if type(getEpoch) == "function" then
    local v = tonumber(getEpoch()) or os.time()
    if v > 20000000000 then v = v / 1000 end
    return v
  end
  return os.time()
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
  if type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok and _trim(v) ~= "" then return _trim(v) end
  end

  local cur = rawget(_G, "target")
  if type(cur) == "string" and _trim(cur) ~= "" then return _trim(cur) end

  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    if type(ak.target) == "string" and _trim(ak.target) ~= "" then return _trim(ak.target) end
    if type(ak.tgt) == "string" and _trim(ak.tgt) ~= "" then return _trim(ak.tgt) end
  end

  return ""
end

local function _room_id()
  local g = rawget(_G, "gmcp")
  local info = g and g.Room and g.Room.Info
  if info and info.num ~= nil then return tostring(info.num) end
  if info and info.id ~= nil then return tostring(info.id) end
  return ""
end

local function _tgt_valid(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return false end
  if type(Yso.target_is_valid) == "function" then
    local ok, v = pcall(Yso.target_is_valid, tgt)
    if ok then return v == true end
  end
  return true
end

local function _eq_ready()
  if Yso and Yso.locks and type(Yso.locks.eq_ready) == "function" then
    local ok, v = pcall(Yso.locks.eq_ready)
    if ok then return v == true end
  end
  if Yso and Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then return v == true end
  end

  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(v.eq or v.equilibrium or "") == "1" or (v.eq == true or v.equilibrium == true)
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
  aff = _lc(aff)
  if aff == "" then return 0 end

  if Yso and Yso.oc and Yso.oc.ak and type(Yso.oc.ak.get_aff_score) == "function" then
    local ok, v = pcall(Yso.oc.ak.get_aff_score, aff)
    if ok and tonumber(v) then return tonumber(v) end
  end

  local A = rawget(_G, "affstrack")
  if type(A) == "table" and type(A.score) == "table" then
    local row = A.score[aff]
    if type(row) == "number" then
      return tonumber(row) or 0
    end
    if type(row) == "table" then
      return tonumber(row.current or row.score or row.value or 0) or 0
    end
  end

  if Yso and Yso.ak and type(Yso.ak.has) == "function" then
    local ok, v = pcall(Yso.ak.has, aff)
    if ok and v == true then return 100 end
  end

  return 0
end

local function _has_aff(aff, threshold)
  return _score_aff(aff) >= (tonumber(threshold or 100) or 100)
end

local function _water_res_actual()
  local R = Yso and Yso.magi and Yso.magi.resonance or nil
  local synced = false
  if type(R) == "table" and type(R.sync_from_ak) == "function" then
    local ok, v = pcall(R.sync_from_ak)
    if ok then synced = (v == true) end
  end
  if type(R) == "table" and type(R.get) == "function" then
    local ok, v = pcall(R.get, "water")
    if ok then return tonumber(v) or 0, synced end
  end
  if type(R) == "table" and type(R.state) == "table" then
    return tonumber(R.state.water or 0) or 0, synced
  end
  return 0, synced
end

local function _cold_slot()
  MGD.state.cold = MGD.state.cold or {
    target = "",
    room_id = "",
    phase = "unknown",
    opened = false,
    seen_frostbite = false,
    seen_frozen = false,
    progressed_at = 0,
  }
  return MGD.state.cold
end

local function _reset_cold(reason)
  local cold = _cold_slot()
  cold.target = ""
  cold.room_id = ""
  cold.phase = "unknown"
  cold.opened = false
  cold.seen_frostbite = false
  cold.seen_frozen = false
  cold.progressed_at = 0
  cold.reason = tostring(reason or "")
  return cold
end

local function _ensure_cold_context(tgt)
  local cold = _cold_slot()
  local room = _room_id()
  local room_changed = cold.room_id ~= "" and room ~= "" and cold.room_id ~= room
  local target_changed = cold.target ~= "" and tgt ~= "" and not _same_target(cold.target, tgt)

  if room_changed then
    cold = _reset_cold("room_change")
  elseif target_changed then
    cold = _reset_cold("target_change")
  end

  cold.target = _trim(tgt or "")
  cold.room_id = room
  return cold
end

local function _refresh_cold_state(tgt, frozen, frostbite)
  local cold = _ensure_cold_context(tgt)
  if frostbite then cold.seen_frostbite = true end
  if frozen then cold.seen_frozen = true end
  if cold.phase == "unknown" and (cold.seen_frostbite or cold.seen_frozen) then
    cold.phase = "progressed"
    cold.progressed_at = _now()
  end
  return cold
end

local function _pending_slot(name)
  MGD.state.pending = MGD.state.pending or {}
  MGD.state.pending[name] = MGD.state.pending[name] or { target = "", until_t = 0 }
  return MGD.state.pending[name]
end

local function _clear_pending(name)
  local slot = _pending_slot(name)
  slot.target = ""
  slot.until_t = 0
end

local function _clear_pending_all()
  _clear_pending("mudslide")
  _clear_pending("emanation")
end

local function _mark_pending(name, tgt, seconds)
  local slot = _pending_slot(name)
  slot.target = _trim(tgt)
  slot.until_t = _now() + (tonumber(seconds) or 0)
end

local function _pending_active(name, tgt)
  local slot = _pending_slot(name)
  return _same_target(slot.target, tgt) and _now() < (tonumber(slot.until_t) or 0)
end

local function _effective_state(tgt)
  local frozen = _has_aff("frozen")
  local frostbite = _has_aff("frostbite")
  local stuttering = _has_aff("stuttering")
  local anorexia = _has_aff("anorexia")
  local slick_raw = _has_aff("slickness")
  local disrupt_raw = _has_aff("disrupt")
  local cold = _refresh_cold_state(tgt, frozen, frostbite)
  local mudslide_pending = _pending_active("mudslide", tgt)
  local emanation_pending = _pending_active("emanation", tgt)
  local water_raw, resonance_synced = _water_res_actual()
  local apply_count = 0
  if frozen then apply_count = apply_count + 1 end
  if stuttering then apply_count = apply_count + 1 end
  if anorexia then apply_count = apply_count + 1 end

  return {
    frozen = frozen,
    frostbite = frostbite,
    stuttering = stuttering,
    anorexia = anorexia,
    apply_count = apply_count,
    cold_phase = cold.phase or "unknown",
    cold_opened = (cold.opened == true),
    slickness = slick_raw or mudslide_pending,
    disrupt = disrupt_raw or emanation_pending,
    water_res = emanation_pending and 0 or water_raw,
    resonance_synced = resonance_synced,
    raw = {
      frozen = _score_aff("frozen"),
      frostbite = _score_aff("frostbite"),
      stuttering = _score_aff("stuttering"),
      anorexia = _score_aff("anorexia"),
      slickness = _score_aff("slickness"),
      disrupt = _score_aff("disrupt"),
      water_res = water_raw,
    },
    pending = {
      mudslide = mudslide_pending,
      emanation = emanation_pending,
    },
    cold = {
      target = cold.target,
      room_id = cold.room_id,
      phase = cold.phase,
      opened = cold.opened,
      seen_frostbite = cold.seen_frostbite,
      seen_frozen = cold.seen_frozen,
      progressed_at = cold.progressed_at,
    },
  }
end

local function _select_command(tgt)
  local st = _effective_state(tgt)
  if not st.frozen then
    local reason = (st.cold_phase == "progressed") and "refreeze_after_progress" or "initial_freeze"
    return ("cast freeze at %s"):format(tgt), "freeze_setup", st, reason
  end
  if not st.slickness then
    return ("cast mudslide at %s"):format(tgt), "salve_pressure", st, "salve_pressure"
  end
  if not st.disrupt and st.water_res >= 3 then
    return ("cast emanation at %s water"):format(tgt), "disrupt_setup", st, "disrupt_setup"
  end
  return ("cast glaciate at %s"):format(tgt), "glaciate_burst", st, "glaciate_burst"
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
    local ok, sent_payload = Q.commit(opts)
    if ok then
      Q._commit_hint = nil
      if type(MGD.on_payload_sent) == "function" then
        pcall(MGD.on_payload_sent, sent_payload)
      end
      return true
    end
    Q._commit_hint = opts
    if Yso and Yso.pulse and type(Yso.pulse.wake) == "function"
      and not (Yso.pulse.state and Yso.pulse.state._in_flush) then
      pcall(Yso.pulse.wake, "emit:staged")
    end
    return true
  end

  if type(send) == "function" then
    local cmd = _trim(payload and payload.eq or "")
    if cmd == "" then return false end
    send(cmd, false)
    if type(MGD.on_payload_sent) == "function" then
      pcall(MGD.on_payload_sent, { eq = cmd })
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
  local who = _trim(_lc(cmd):match(pat) or "")
  return who
end

local function _attack_opts(arg)
  if type(arg) == "table" and (arg.preview ~= nil or arg.ctx ~= nil) then
    return arg.ctx, (arg.preview == true)
  end
  return arg, false
end

function MGD.init()
  MGD.cfg = MGD.cfg or {}
  MGD.state = MGD.state or {}
  MGD.state.template = MGD.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  MGD.state.pending = MGD.state.pending or {
    mudslide = { target = "", until_t = 0 },
    emanation = { target = "", until_t = 0 },
  }
  MGD.state.cold = MGD.state.cold or {
    target = "",
    room_id = "",
    phase = "unknown",
    opened = false,
    seen_frostbite = false,
    seen_frozen = false,
    progressed_at = 0,
  }
  MGD.state.loop_delay = tonumber(MGD.state.loop_delay or MGD.cfg.loop_delay or 0.15) or 0.15
  MGD.state.busy = (MGD.state.busy == true)
  _set_loop_enabled((MGD.state.loop_enabled == true) or (MGD.state.enabled == true))
  return true
end

function MGD.reset(reason)
  MGD.init()
  _clear_pending_all()
  _reset_cold(reason or "manual")
  MGD.state.busy = false
  MGD.state.last_target = ""
  MGD.state.last_cmd = ""
  MGD.state.last_category = ""
  MGD.state.last_sent_cmd = ""
  MGD.state.last_sent_category = ""
  MGD.state.last_sent_at = 0
  MGD.state.explain = {}
  MGD.state.template.last_reason = tostring(reason or "manual")
  MGD.state.template.last_payload = nil
  MGD.state.template.last_target = ""
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
    return false, "no_target"
  end
  if not _is_magi() then return false, "wrong_class" end
  if not _tgt_valid(tgt) then
    _reset_cold("invalid_target")
    return false, "invalid_target"
  end
  _ensure_cold_context(tgt)
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
  local payload = {
    route = "magi_group_damage",
    target = tgt,
    lanes = { eq = cmd },
    meta = {
      main_lane = "eq",
      main_category = category,
      main_reason = reason,
      state = st,
    },
  }

  MGD.state.template.last_reason = reason
  MGD.state.template.last_payload = payload
  MGD.state.template.last_target = tgt
  MGD.state.explain = {
    route = "magi_group_damage",
    target = tgt,
    decision = category,
    reason = reason,
    state = st,
  }

  if preview then return payload end

  local sent = _emit_payload({ eq = cmd }, category)
  if not sent then return false, "emit_failed" end

  MGD.state.last_cmd = cmd
  MGD.state.last_category = category
  return true, cmd, payload
end

function MGD.build_payload(ctx)
  return MGD.attack_function({ ctx = ctx, preview = true })
end

function MGD.evaluate(ctx)
  local payload, why = MGD.build_payload(ctx)
  if not payload then return { ok = false, reason = why } end
  return { ok = true, payload = payload }
end

function MGD.explain()
  local tgt = _target()
  local st = _effective_state(tgt)
  local current_reason = ""
  if not st.frozen then
    current_reason = (st.cold_phase == "progressed") and "refreeze_after_progress" or "initial_freeze"
  end
  return {
    route = "magi_group_damage",
    enabled = MGD.is_enabled(),
    active = MGD.is_active(),
    target = tgt,
    decision = MGD.state and MGD.state.last_category or "",
    last_reason = MGD.state and MGD.state.template and MGD.state.template.last_reason or "",
    current_reason = current_reason,
    cold_phase = st.cold_phase,
    apply_count = st.apply_count,
    water_res = st.water_res,
    resonance_synced = st.resonance_synced,
    last_cmd = MGD.state and MGD.state.last_cmd or "",
    last_disable_reason = MGD.state and MGD.state.template and MGD.state.template.last_disable_reason or "",
    state = st,
    pending = MGD.state and MGD.state.pending or {},
  }
end

function MGD.status()
  return MGD.explain()
end

function MGD.on_payload_sent(payload)
  _payload_each_eq(payload, function(cmd)
    cmd = _trim(cmd)
    if cmd == "" then return end

    local lc = _lc(cmd)
    MGD.state.last_sent_cmd = cmd
    MGD.state.last_sent_at = _now()

    local mud_tgt = _capture_target(lc, "^cast%s+mudslide%s+at%s+(.+)$")
    if mud_tgt ~= "" then
      MGD.state.last_sent_category = "salve_pressure"
      _mark_pending("mudslide", mud_tgt, MGD.cfg.mudslide_pending_s)
      return
    end

    local ema_tgt = _capture_target(lc, "^cast%s+emanation%s+at%s+(.+)%s+water$")
    if ema_tgt ~= "" then
      MGD.state.last_sent_category = "disrupt_setup"
      _mark_pending("emanation", ema_tgt, MGD.cfg.emanation_pending_s)
      return
    end

    if lc:match("^cast%s+glaciate%s+at%s+") then
      MGD.state.last_sent_category = "glaciate_burst"
    elseif lc:match("^cast%s+freeze%s+at%s+") then
      MGD.state.last_sent_category = "freeze_setup"
      local freeze_tgt = _capture_target(lc, "^cast%s+freeze%s+at%s+(.+)$")
      if freeze_tgt ~= "" then
        local cold = _ensure_cold_context(freeze_tgt)
        cold.opened = true
      end
    end
  end)
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
    _clear_eq_queue()
    MGD.state.last_target = _trim(new_target)
    MGD.state.last_cmd = ""
    MGD.state.last_category = ""
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
  MGD.on_payload_sent(payload)
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
  _clear_eq_queue()
  MGD.state.busy = false
  _echo("Magi team damage loop ON.")
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
  _clear_eq_queue()
  MGD.state.busy = false
  MGD.state.template.last_disable_reason = reason
  if ctx.silent ~= true then
    _echo(string.format("Magi team damage loop OFF (%s).", reason))
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

return MGD
