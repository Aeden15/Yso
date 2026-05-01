--========================================================--
-- Alchemist / group damage.lua
--  Party damage route for Alchemist lane-combo payloads.
--========================================================--

_G.Yso = _G.Yso or _G.yso or {}
_G.yso = _G.Yso

Yso = _G.Yso
Yso.off = Yso.off or {}
Yso.off.alc = Yso.off.alc or {}

Yso.off.alc.group_damage = Yso.off.alc.group_damage or {}
local GD = Yso.off.alc.group_damage
GD.alias_owned = true

local function _load_alchemist_peer(file_name)
  local info = debug.getinfo(1, "S")
  local source = info and info.source or ""
  if source:sub(1, 1) ~= "@" then
    return false
  end
  local dir = source:sub(2):match("^(.*)[/\\][^/\\]+$") or "."
  local path = dir .. "/" .. tostring(file_name or "")
  local ok = pcall(dofile, path)
  return ok
end

if type(require) == "function" then
  pcall(require, "Yso")
end
if not (Yso.alc and Yso.alc.phys and type(Yso.alc.phys.target) == "function") then
  _load_alchemist_peer("physiology.lua")
end

local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
if not (RI and type(RI.ensure_hooks) == "function") and type(require) == "function" then
  pcall(require, "Yso.Combat.route_interface")
  pcall(require, "Yso.xml.route_interface")
  RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
end

GD.route_contract = GD.route_contract or {
  id = "alchemist_group_damage",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "evaluate",
    "defense_break",
    "aurify",
    "reave",
    "self_purge",
    "burst",
    "pressure",
    "hold",
  },
  capabilities = {
    uses_eq = true,
    uses_bal = true,
    uses_entity = false,
    supports_burst = true,
    supports_bootstrap = true,
    needs_target = true,
    shares_defense_break = true,
    shares_anti_tumble = true,
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

GD.cfg = GD.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,
  evaluate_pending_s = 1.2,
  pending_class_timeout_s = 2.5,
  salt_min_affs = 2,
  salt_cooldown_s = 3.2,
  burst_pressure_pct = 75,
}

GD.giving_default = GD.giving_default or {
  "paralysis",
  "nausea",
  "sensitivity",
  "haemophilia",
}

GD.state = GD.state or {
  enabled = false,
  loop_enabled = false,
  timer_id = nil,
  busy = false,
  waiting = { queue = nil, main_lane = nil, lanes = nil, at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil },
  template = { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" },
  explain = {},
  last_hold_reason = "",
  last_hold_at = 0,
  homunculus_attack_sent = false,
  homunculus_attack_target = "",
  last_salt_at = 0,
}

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _lc(s)
  return _trim(s):lower()
end

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    if ok and tonumber(v) then
      return tonumber(v)
    end
  end
  if type(getEpoch) == "function" then
    local v = tonumber(getEpoch()) or os.time()
    if v > 20000000000 then
      v = v / 1000
    end
    return v
  end
  return os.time()
end

local function _echo(msg)
  if GD.cfg.echo ~= true then
    return
  end
  if type(cecho) == "function" then
    cecho(string.format("<orange>[Yso:Alchemist] <reset>%s\n", tostring(msg)))
  elseif type(echo) == "function" then
    echo(string.format("[Yso:Alchemist] %s\n", tostring(msg)))
  end
end

local function _debug(msg)
  if not (Yso and Yso.ak and Yso.ak.debug == true) then
    return
  end
  _echo(msg)
end

local function _phys()
  return Yso and Yso.alc and Yso.alc.phys or nil
end

local function _sep()
  local s = _trim((Yso and (Yso.sep or (Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep)))) or "&&")
  if s == "" then s = "&&" end
  return s
end

local function _use_queueing_enabled()
  local cfg = Yso and Yso.cfg or nil
  if type(cfg) ~= "table" then
    return true
  end
  local raw = cfg.UseQueueing
  if raw == nil then raw = cfg.use_queueing end
  if raw == nil then raw = cfg.queueing end
  if raw == nil then
    return true
  end
  local t = type(raw)
  if t == "boolean" then
    return raw
  end
  local s = _lc(raw)
  if s == "no" or s == "false" or s == "0" or s == "off" then
    return false
  end
  return true
end

local function _target()
  if type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok and _trim(v) ~= "" then
      return _trim(v)
    end
  end
  local t = rawget(_G, "target")
  if type(t) == "string" and _trim(t) ~= "" then
    return _trim(t)
  end
  return ""
end

local function _target_valid(tgt)
  if type(Yso.target_is_valid) == "function" then
    local ok, v = pcall(Yso.target_is_valid, tgt)
    if ok then
      return v == true
    end
  end
  return _trim(tgt) ~= ""
end

local function _is_alchemist()
  if type(Yso.is_alchemist) == "function" then
    local ok, v = pcall(Yso.is_alchemist)
    if ok then
      return v == true
    end
  end
  local cls = gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class or ""
  return _lc(cls) == "alchemist"
end

local function _eq_ready()
  if Yso and Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then
      return v == true
    end
  end
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(v.eq or v.equilibrium or "") == "1" or (v.eq == true or v.equilibrium == true)
end

local function _bal_ready()
  if Yso and Yso.state and type(Yso.state.bal_ready) == "function" then
    local ok, v = pcall(Yso.state.bal_ready)
    if ok then
      return v == true
    end
  end
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(v.bal or v.balance or "") == "1" or (v.bal == true or v.balance == true)
end

local function _class_ready()
  if Yso.alc and type(Yso.alc.humour_ready) == "function" then
    local ok, v = pcall(Yso.alc.humour_ready)
    if ok then
      return v == true
    end
  end
  return Yso and Yso.bal and Yso.bal.humour ~= false
end

local function _evaluate_ready()
  if Yso.alc and type(Yso.alc.evaluate_ready) == "function" then
    local ok, v = pcall(Yso.alc.evaluate_ready)
    if ok then
      return v == true
    end
  end
  return Yso and Yso.bal and Yso.bal.evaluate ~= false
end

local function _same_target(a, b)
  return _lc(a) ~= "" and _lc(a) == _lc(b)
end

local function _self_has(aff)
  aff = _lc(aff)
  if aff == "" then
    return false
  end
  if Yso and Yso.self and type(Yso.self.has_aff) == "function" then
    local ok, v = pcall(Yso.self.has_aff, aff)
    if ok and v == true then
      return true
    end
  end
  if Yso and type(Yso.affs) == "table" and Yso.affs[aff] == true then
    return true
  end
  return false
end

local function _self_aff_count()
  if Yso and Yso.self_aff and type(Yso.self_aff.count) == "function" then
    local ok, v = pcall(Yso.self_aff.count)
    if ok and tonumber(v) then
      return tonumber(v)
    end
  end

  local count = 0
  if Yso and type(Yso.affs) == "table" then
    for _, present in pairs(Yso.affs) do
      if present then
        count = count + 1
      end
    end
  end
  return count
end

local function _can_plan_bal()
  local Q = Yso and Yso.queue or nil
  if not (Q and type(Q.can_plan_lane) == "function") then
    return true
  end
  local ok, allowed = pcall(Q.can_plan_lane, "bal")
  if not ok then
    return true
  end
  return allowed == true
end

local function _shielded(tgt)
  tgt = _lc(tgt)

  if Yso and Yso.shield and type(Yso.shield.up) == "function" and tgt ~= "" then
    local ok, v = pcall(Yso.shield.up, tgt)
    if ok then return v == true end
  end

  local ak = rawget(_G, "ak")
  if ak and ak.defs then
    if type(ak.defs.shield_by_target) == "table" and tgt ~= "" then
      return ak.defs.shield_by_target[tgt] == true
    end
    return ak.defs.shield == true
  end

  return false
end

local function _evaluate_pending_for(tgt)
  local P = _phys()
  if P and type(P.evaluate_staged_for_target) == "function" and P.evaluate_staged_for_target(tgt) then
    return true
  end
  local row = P and P.state and P.state.evaluate or nil
  if type(row) ~= "table" then
    return false
  end
  if not _same_target(row.target, tgt) then
    return false
  end
  local at = tonumber(row.requested_at or 0) or 0
  if at <= 0 then
    return false
  end
  return (_now() - at) <= (tonumber(GD.cfg.evaluate_pending_s or 1.2) or 1.2)
end

local function _is_party_damage_route()
  local M = Yso and Yso.mode or nil
  if type(M) ~= "table" then
    return false
  end
  if type(M.party_route) == "function" then
    local ok, v = pcall(M.party_route)
    local route = ok and _lc(v) or ""
    if route ~= "" and route ~= "dam" then
      return false
    end
  end
  if type(M.route_loop_active) == "function" then
    local ok, v = pcall(M.route_loop_active, "alchemist_group_damage")
    if ok and v ~= true then
      return false
    end
  end
  return true
end

local function _schedule_loop(delay, reason)
  local M = Yso and Yso.mode or nil
  if type(M) ~= "table" then
    return false
  end
  if type(M.schedule_route_loop) == "function" then
    local ok, scheduled = pcall(M.schedule_route_loop, "alchemist_group_damage", delay or 0)
    if ok and scheduled == true then
      return true
    end
  end
  if type(M.nudge_route_loop) == "function" then
    local ok, nudged = pcall(M.nudge_route_loop, "alchemist_group_damage", tostring(reason or "route"))
    if ok and nudged == true then
      return true
    end
  end
  return false
end

local function _set_hold_explain(reason, tgt, extra)
  GD.state = GD.state or {}
  GD.state.last_hold_reason = tostring(reason or "hold")
  GD.state.last_hold_at = _now()
  GD.state.explain = {
    route = "alchemist_group_damage",
    target = _trim(tgt or _target()),
    category = "hold",
    reason = GD.state.last_hold_reason,
    eq = nil,
    class = nil,
    bal = nil,
    free = nil,
    direct_order = nil,
  }
  if type(extra) == "table" then
    for k, v in pairs(extra) do
      GD.state.explain[k] = v
    end
  end
end

local function _make_payload(tgt, category, reason)
  return {
    route = "alchemist_group_damage",
    target = tgt,
    category = category,
    reason = reason,
    lanes = {},
    free = nil,
    eq = nil,
    bal = nil,
    class = nil,
    class_category = nil,
    direct_order = nil,
  }
end

local function _set_lane(payload, lane, cmd)
  cmd = _trim(cmd)
  if cmd == "" then
    return
  end
  if lane == "free" then
    if payload.free == nil then
      payload.free = cmd
    elseif type(payload.free) == "table" then
      payload.free[#payload.free + 1] = cmd
    else
      payload.free = { payload.free, cmd }
    end
    return
  end
  payload[lane] = cmd
  payload.lanes[lane] = cmd
end

local function _ensure_homunculus_attack(R, tgt)
  tgt = _trim(tgt)
  if tgt == "" then return nil end

  if type(Yso.homunculus_attack) == "function" and Yso.homunculus_attack(tgt) then
    return nil
  end

  R.state = R.state or {}

  if R.state.homunculus_attack_target ~= tgt then
    R.state.homunculus_attack_target = tgt
    R.state.homunculus_attack_sent = false
  end

  if R.state.homunculus_attack_sent == true then
    return nil
  end

  R.state.homunculus_attack_sent = true

  if type(Yso.set_homunculus_attack) == "function" then
    Yso.set_homunculus_attack(true, tgt)
  end

  return "homunculus attack " .. tgt
end

local function _homunculus_pacify_on_stop(R)
  R.state = R.state or {}
  if type(send) == "function" then
    pcall(send, "homunculus pacify", false)
  end
  if type(Yso.set_homunculus_attack) == "function" then
    Yso.set_homunculus_attack(false)
  end
  R.state.homunculus_attack_sent = false
  R.state.homunculus_attack_target = ""
end

local function _clear_route_owned_queues(reason)
  local Q = Yso and Yso.queue or nil
  local lanes = { "class", "eq", "bal", "free" }
  reason = tostring(reason or "route_reset")

  if Q then
    for i = 1, #lanes do
      local lane = lanes[i]
      if type(Q.clear) == "function" then
        pcall(Q.clear, lane)
      end
      if type(Q.clear_owned) == "function" then
        pcall(Q.clear_owned, lane)
      end
      if type(Q.clear_lane_dispatched) == "function" and lane ~= "free" then
        pcall(Q.clear_lane_dispatched, lane, reason)
      end
    end
  end
end

local function _self_purge_candidate(R)
  if not _eq_ready() then return nil end

  if _self_has("stupidity") then
    return nil, "salt_blocked_by_stupidity"
  end

  local now = _now()
  local last = tonumber(R.state.last_salt_at or 0) or 0
  local cd = tonumber(R.cfg.salt_cooldown_s or 3.2) or 3.2
  if (now - last) < cd then
    return nil
  end

  local aff_count = _self_aff_count()
  local min_aff = tonumber(R.cfg.salt_min_affs or 2) or 2
  if aff_count >= min_aff then
    return "educe salt", "salt_self_purge"
  end

  return nil
end

local function _vitrification_active(P, tgt)
  if type(P.alchemy_debuff_active) == "function" then
    local active, kind = P.alchemy_debuff_active(tgt)
    return active == true and _lc(kind) == "vitrification"
  end
  return false
end

local function _pick_wrack(P, tgt, giving, staged)
  if not _bal_ready() then
    return nil, "bal_not_ready_for_wrack"
  end
  if not _can_plan_bal() then
    return nil, "bal_lane_debounce"
  end
  if type(P.build_truewrack_with_staged) == "function" then
    local cmd = P.build_truewrack_with_staged(tgt, giving, staged)
    if _trim(cmd) ~= "" then
      return cmd, "truewrack"
    end
  end
  if type(P.build_wrack_fallback_with_staged) == "function" then
    local cmd = P.build_wrack_fallback_with_staged(tgt, giving, staged)
    if _trim(cmd) ~= "" then
      return cmd, "wrack"
    end
  end
  if type(P.build_truewrack) == "function" then
    local cmd = P.build_truewrack(tgt, giving)
    if _trim(cmd) ~= "" then
      return cmd, "truewrack"
    end
  end
  if type(P.build_wrack_fallback) == "function" then
    local cmd = P.build_wrack_fallback(tgt, giving)
    if _trim(cmd) ~= "" then
      return cmd, "wrack"
    end
  end
  return nil, "no_legal_wrack_aff_or_temper"
end

local function _note_wrack_result(R, cmd, why)
  if _trim(cmd) ~= "" then return end
  why = _trim(why)
  if why == "" then return end
  R.state = R.state or {}
  R.state.template = R.state.template or {}
  R.state.template.last_no_wrack_reason = why
  R.state.explain = R.state.explain or {}
  R.state.explain.last_no_wrack_reason = why
end

local function _pick_group_inundate(P, tgt)
  if not _class_ready() then
    return nil
  end

  local hp = tonumber(type(P.health_pct) == "function" and P.health_pct(tgt) or nil)
  local mp = tonumber(type(P.mana_pct) == "function" and P.mana_pct(tgt) or nil)
  local chol = tonumber(type(P.current_humour_count) == "function" and P.current_humour_count(tgt, "choleric") or 0) or 0
  local mel = tonumber(type(P.current_humour_count) == "function" and P.current_humour_count(tgt, "melancholic") or 0) or 0
  local sang = tonumber(type(P.current_humour_count) == "function" and P.current_humour_count(tgt, "sanguine") or 0) or 0
  local pressure_pct = tonumber(GD.cfg.burst_pressure_pct or 75) or 75

  local function _hp_candidate(required, burst)
    if chol < required or hp == nil then
      return nil
    end
    local after = hp - burst
    if after <= pressure_pct then
      return {
        humour = "choleric",
        cmd = "inundate " .. tgt .. " choleric",
        reason = "inundate_health_burst",
        count = chol,
        estimated_burst_pct = burst,
        predicted_after_pct = after,
      }
    end
    return nil
  end

  local function _mp_candidate(required, burst)
    if mel < required or mp == nil then
      return nil
    end
    local after = mp - burst
    if after <= pressure_pct then
      return {
        humour = "melancholic",
        cmd = "inundate " .. tgt .. " melancholic",
        reason = "inundate_mana_burst",
        count = mel,
        estimated_burst_pct = burst,
        predicted_after_pct = after,
      }
    end
    return nil
  end

  local c8 = _hp_candidate(8, 77)
  if c8 then return c8 end
  local m8 = _mp_candidate(8, 77)
  if m8 then return m8 end
  local c6 = _hp_candidate(6, 50)
  if c6 then return c6 end
  local m6 = _mp_candidate(6, 50)
  if m6 then return m6 end

  local can_aurify = type(P.can_aurify) == "function" and P.can_aurify(tgt) == true
  if sang >= 6 and not can_aurify and _vitrification_active(P, tgt) then
    local out = {
      humour = "sanguine",
      cmd = "inundate " .. tgt .. " sanguine",
      reason = (sang >= 8) and "inundate_bleed_burst_tbd_8" or "inundate_bleed_burst",
      count = sang,
      estimated_bleeding = 2304,
    }
    if sang >= 8 then
      out.exact_bleeding_unknown = true
    end
    return out
  end

  return nil
end

local function _pick_temper(P, tgt, giving)
  if not _class_ready() then
    return nil
  end
  if type(P.pick_temper_humour) ~= "function" then
    return nil
  end
  local humour = _trim(P.pick_temper_humour(tgt, giving))
  if humour == "" then
    return nil
  end
  return {
    humour = humour,
    cmd = "temper " .. tgt .. " " .. humour,
    reason = "temper_window",
  }
end

local function _build_direct_order(payload, shield_order)
  local order = {}

  local function add_cmd(cmd)
    cmd = _trim(cmd)
    if cmd ~= "" then
      order[#order + 1] = cmd
    end
  end

  if type(payload.free) == "table" then
    for i = 1, #payload.free do
      add_cmd(payload.free[i])
    end
  else
    add_cmd(payload.free)
  end

  if shield_order == true then
    add_cmd(payload.eq)
    add_cmd(payload.class)
    add_cmd(payload.bal)
  else
    add_cmd(payload.class)
    add_cmd(payload.eq)
    add_cmd(payload.bal)
  end

  if #order > 0 then
    payload.direct_order = order
  end
end

local function _execute_lane(payload)
  if type(payload) ~= "table" then return nil end
  if payload.category == "aurify" then return "eq" end
  if payload.category == "reave" then return "class" end
  return nil
end

local function _execute_qtype(lane)
  local Q = Yso and Yso.queue or nil
  if Q and type(Q.qtype_for_lane) == "function" then
    local qtype = _trim(Q.qtype_for_lane(lane))
    if qtype ~= "" then return qtype end
  end
  return (lane == "class") and "c!p!w!t" or "e!p!w!t"
end

local function _execute_opts(payload)
  local lane = _execute_lane(payload)
  if lane then
    payload.free = nil
    payload.queue_verb = "addclearfull"
    payload.clearfull_lane = lane
  end
  return {
    reason = "alchemist_group_damage:" .. tostring(payload.category or "action"),
    kind = "offense",
    commit = true,
    route = "alchemist_group_damage",
    target = payload.target,
    allow_eqbal = true,
    queue_verb = lane and "addclearfull" or nil,
    clearfull_lane = lane,
  }
end

local function _send_execute_addclearfull(payload)
  local lane = _execute_lane(payload)
  if not lane then return nil end
  payload.free = nil
  local cmd = _trim(payload[lane])
  if cmd == "" then return false end

  local Q = Yso and Yso.queue or nil
  local opts = _execute_opts(payload)
  if Q and type(Q.install_lane) == "function" then
    local ok = Q.install_lane(lane, cmd, opts)
    if ok == true then
      if type(Q.mark_lane_dispatched) == "function" and lane ~= "free" then
        pcall(Q.mark_lane_dispatched, lane, "addclearfull")
      end
      if type(Q.mark_payload_fired) == "function" then
        pcall(Q.mark_payload_fired, { [lane] = cmd, target = payload.target })
      end
      return true
    end
    return false
  end

  if Q and type(Q.addclearfull) == "function" then
    return Q.addclearfull(_execute_qtype(lane), cmd) == true
  end

  if type(send) == "function" then
    return pcall(send, ("QUEUE ADDCLEARFULL %s %s"):format(_execute_qtype(lane), cmd), false) == true
  end
  return false
end

local function _post_send(payload)
  local P = _phys()
  local tgt = _trim(payload and payload.target or "")
  if payload and payload.class_category == "temper" then
    local humour = _lc((payload.class or ""):match("^temper%s+[%w'%-]+%s+([a-z]+)$") or "")
    if P and type(P.note_pending_class) == "function" then
      P.note_pending_class("temper", tgt, humour, payload.class, "alchemist_group_damage", "route_send")
    end
    _set_hold_explain("temper_pending", tgt, {
      humour = humour,
      pending_cmd = payload.class,
    })
  elseif payload and payload.class_category == "inundate" then
    if Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
      Yso.alc.set_humour_ready(false, "inundate_sent")
    end
    if P and type(P.clear_pending_class) == "function" then
      P.clear_pending_class("inundate_sent", { clear_any = true, clear_staged = true })
    end
    if P and type(P.clear_all_humours) == "function" and tgt ~= "" then
      P.clear_all_humours(tgt, "inundate_sent")
    end
  elseif payload and payload.category == "reave" and Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
    Yso.alc.set_humour_ready(false, "reave_sent")
  end

  if payload and _lc(payload.eq or "") == "educe salt" then
    GD.state.last_salt_at = _now()
  end

  _schedule_loop(0, "payload_sent")
end

local function _emit_payload(payload)
  local P = _phys()
  local execute_lane = _execute_lane(payload)

  if payload.category == "reave" and P and type(P.fire_reave) == "function" then
    local ok, fired = pcall(P.fire_reave, payload.target, payload.reave_profile, _execute_opts(payload))
    if ok and fired == true then
      _post_send(payload)
      return true
    end
    return false
  end

  if not execute_lane and type(payload.direct_order) == "table" and #payload.direct_order > 0 and not _use_queueing_enabled() and type(send) == "function" then
    local line = table.concat(payload.direct_order, _sep())
    if _trim(line) ~= "" and pcall(send, line, false) == true then
      _post_send(payload)
      return true
    end
    return false
  end

  if type(Yso.emit) == "function" then
    local ok = (Yso.emit(payload, _execute_opts(payload)) == true)
    if ok then
      _post_send(payload)
    end
    return ok
  end

  local Q = Yso and Yso.queue or nil
  if Q and type(Q.stage) == "function" and type(Q.commit) == "function" then
    if payload.free then Q.stage("free", payload.free, { route = "alchemist_group_damage", target = payload.target }) end
    if payload.eq then Q.stage("eq", payload.eq, { route = "alchemist_group_damage", target = payload.target }) end
    if payload.class then Q.stage("class", payload.class, { route = "alchemist_group_damage", target = payload.target }) end
    if payload.bal then Q.stage("bal", payload.bal, { route = "alchemist_group_damage", target = payload.target }) end
    local ok = Q.commit(_execute_opts(payload))
    if ok == true then
      _post_send(payload)
    end
    return ok == true
  end

  if execute_lane then
    local ok = _send_execute_addclearfull(payload)
    if ok == true then
      _post_send(payload)
    end
    return ok == true
  end

  if type(payload.direct_order) == "table" and #payload.direct_order > 0 and type(send) == "function" then
    local line = table.concat(payload.direct_order, _sep())
    if _trim(line) ~= "" and pcall(send, line, false) == true then
      _post_send(payload)
      return true
    end
  end

  return false
end

local function _select_payload(ctx)
  GD.init()

  local P = _phys()
  if not P then
    return nil, "phys_unavailable"
  end

  local tgt = _trim((ctx and ctx.target) or _target())
  if type(P.reave_sync_target) == "function" then
    pcall(P.reave_sync_target, tgt, "group_select")
  end
  if tgt == "" then
    return nil, "no_target"
  end
  if not _target_valid(tgt) then
    return nil, "invalid_target"
  end

  local giving = type(GD.giving_default) == "table" and GD.giving_default or {}
  local free_bootstrap = _ensure_homunculus_attack(GD, tgt)

  local needs_eval = (type(P.target_needs_evaluate) == "function") and (P.target_needs_evaluate(tgt) == true) or false
  if needs_eval then
    if _evaluate_ready() and not _evaluate_pending_for(tgt) then
      local payload = _make_payload(tgt, "evaluate", "humour_intel_dirty")
      if free_bootstrap then _set_lane(payload, "free", free_bootstrap) end
      _set_lane(payload, "free", "evaluate " .. tgt .. " humours")
      if type(P.note_evaluate_request) == "function" then
        local noted = P.note_evaluate_request(tgt, "route")
        if noted ~= true then
          return nil, "evaluate_duplicate"
        end
      end
      _build_direct_order(payload, false)
      return payload, payload.reason
    end
    if _evaluate_pending_for(tgt) then
      return nil, "evaluate_pending"
    end
    return nil, "evaluate_not_ready"
  end

  if type(P.pending_class_status) == "function" then
    local pending_active, pending_reason, pending = P.pending_class_status("alchemist_group_damage", tgt, GD.cfg.pending_class_timeout_s)
    if pending_reason == "temper_sent_no_confirm_timeout" then
      return nil, "temper_sent_no_confirm_timeout"
    end
    if pending_active == true and pending and _lc(pending.action or "") == "temper" then
      return nil, "temper_pending"
    end
  end

  local shielded = _shielded(tgt)
  if shielded and _eq_ready() then
    local payload = _make_payload(tgt, "defense_break", "shieldbreak")
    if free_bootstrap then _set_lane(payload, "free", free_bootstrap) end
    _set_lane(payload, "eq", "educe copper " .. tgt)

    local class_inundate = _pick_group_inundate(P, tgt)
    local staged = nil
    if class_inundate and _trim(class_inundate.cmd) ~= "" then
      _set_lane(payload, "class", class_inundate.cmd)
      payload.class_category = "inundate"
      payload.reason = class_inundate.reason or payload.reason
    else
      local class_temper = _pick_temper(P, tgt, giving)
      if class_temper then
        _set_lane(payload, "class", class_temper.cmd)
        payload.class_category = "temper"
        payload.reason = class_temper.reason or payload.reason
        staged = { temper_humour = class_temper.humour }
      end
    end

    if payload.class_category ~= "inundate" then
      local bal_cmd, bal_reason = _pick_wrack(P, tgt, giving, staged)
      if bal_cmd then
        _set_lane(payload, "bal", bal_cmd)
      else
        _note_wrack_result(GD, bal_cmd, bal_reason)
      end
    end

    _build_direct_order(payload, true)
    return payload, payload.reason
  end

  if _eq_ready() and type(P.can_aurify) == "function" and P.can_aurify(tgt) then
    local payload = _make_payload(tgt, "aurify", "aurify_window")
    _set_lane(payload, "eq", "aurify " .. tgt)
    _build_direct_order(payload, false)
    return payload, payload.reason
  end

  if type(P.can_reave) == "function" then
    local can_reave, profile = P.can_reave(tgt)
    if can_reave == true then
      local payload = _make_payload(tgt, "reave", "reave_window")
      _set_lane(payload, "class", "reave " .. tgt)
      payload.class_category = "reave"
      payload.reave_profile = profile
      _build_direct_order(payload, false)
      return payload, payload.reason
    end
  end

  local salt_cmd, salt_reason = _self_purge_candidate(GD)
  if salt_cmd then
    local payload = _make_payload(tgt, "self_purge", salt_reason or "salt_self_purge")
    if free_bootstrap then _set_lane(payload, "free", free_bootstrap) end
    _set_lane(payload, "eq", salt_cmd)
    _build_direct_order(payload, false)
    return payload, payload.reason
  end

  local payload = _make_payload(tgt, "pressure", "pressure")
  if free_bootstrap then _set_lane(payload, "free", free_bootstrap) end

  local inundate = _pick_group_inundate(P, tgt)
  local staged = nil
  if inundate and _trim(inundate.cmd) ~= "" then
    _set_lane(payload, "class", inundate.cmd)
    payload.class_category = "inundate"
    payload.category = "burst"
    payload.reason = inundate.reason or "inundate_burst"
  else
    local temper = _pick_temper(P, tgt, giving)
    if temper then
      _set_lane(payload, "class", temper.cmd)
      payload.class_category = "temper"
      staged = { temper_humour = temper.humour }
    end

    if _eq_ready() then
      _set_lane(payload, "eq", "educe iron " .. tgt)
    end

    local bal_cmd, bal_reason = _pick_wrack(P, tgt, giving, staged)
    if bal_cmd then
      _set_lane(payload, "bal", bal_cmd)
    else
      _note_wrack_result(GD, bal_cmd, bal_reason)
    end
  end

  _build_direct_order(payload, false)
  if not payload.eq and not payload.class and not payload.bal and not payload.free then
    if _class_ready() ~= true then
      return nil, "class_balance_not_ready"
    end
    return nil, "no_legal_action"
  end
  return payload, payload.reason
end

function GD.init()
  GD.cfg = GD.cfg or {}
  GD.state = GD.state or {}
  GD.state.waiting = GD.state.waiting or { queue = nil, main_lane = nil, lanes = nil, at = 0 }
  GD.state.last_attack = GD.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil }
  GD.state.template = GD.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  GD.state.explain = GD.state.explain or {}
  GD.state.last_hold_reason = _trim(GD.state.last_hold_reason)
  GD.state.last_hold_at = tonumber(GD.state.last_hold_at or 0) or 0
  GD.state.loop_enabled = (GD.state.loop_enabled == true)
  GD.state.enabled = (GD.state.enabled == true)
  GD.state.busy = (GD.state.busy == true)
  GD.state.homunculus_attack_sent = (GD.state.homunculus_attack_sent == true)
  GD.state.homunculus_attack_target = _trim(GD.state.homunculus_attack_target)
  GD.state.last_salt_at = tonumber(GD.state.last_salt_at or 0) or 0
  GD.cfg.loop_delay = tonumber(GD.cfg.loop_delay or 0.15) or 0.15
  GD.cfg.pending_class_timeout_s = tonumber(GD.cfg.pending_class_timeout_s or 2.5) or 2.5

  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(GD, GD.route_contract)
  end
  if Yso and Yso.off and Yso.off.core and type(Yso.off.core.register) == "function" then
    pcall(Yso.off.core.register, "alchemist_group_damage", GD)
    pcall(Yso.off.core.register, "adam", GD)
  end
  return true
end

function GD.is_active()
  if not _is_alchemist() then
    return false
  end
  if GD.cfg.enabled ~= true or GD.state.enabled ~= true or GD.state.loop_enabled ~= true then
    return false
  end
  if type(Yso.offense_paused) == "function" then
    local ok, v = pcall(Yso.offense_paused)
    if ok and v == true then
      return false
    end
  end
  return _is_party_damage_route()
end

function GD.reset_route_state(reason, target)
  GD.init()
  reason = tostring(reason or "reset")
  target = _trim(target or "")

  local P = _phys()
  GD.state.busy = false
  GD.alias_loop_clear_waiting()
  GD.state.homunculus_attack_sent = false
  GD.state.homunculus_attack_target = ""
  GD.state.last_attack = { at = 0, target = "", main_lane = nil, lanes = nil, cmd = "" }

  GD.state.template = GD.state.template or {}
  GD.state.template.last_reset_reason = reason
  GD.state.template.last_reset_target = target
  GD.state.template.last_payload = nil
  GD.state.template.last_target = ""
  GD.state.template.last_reason = reason
  GD.state.explain = { target = target, reason = reason }

  if P and type(P.reave_sync_target) == "function" then
    pcall(P.reave_sync_target, "", reason)
  end
  if P and type(P.clear_staged_for_target) == "function" and target ~= "" then
    pcall(P.clear_staged_for_target, target, reason)
  end
  if P and type(P.clear_pending_class) == "function" then
    pcall(P.clear_pending_class, reason, { clear_any = true, clear_staged = true })
  end
  if P and P.state and type(P.state.evaluate) == "table" then
    P.state.evaluate.active = false
    P.state.evaluate.target = ""
    P.state.evaluate.requested_at = 0
    P.state.evaluate.started_at = 0
  end
  _clear_route_owned_queues(reason)
  return true
end

function GD.alias_loop_prepare_start(ctx)
  ctx = ctx or {}
  GD.reset_route_state(tostring(ctx.reason or "prepare_start"), _target())
  return ctx
end

function GD.alias_loop_on_started(ctx)
  ctx = ctx or {}
  GD.reset_route_state(tostring(ctx.reason or "loop_started"), _target())
  _echo("Alchemist group damage loop ON.")
end

function GD.alias_loop_on_stopped(ctx)
  ctx = ctx or {}
  local P = _phys()
  local tgt = _trim((GD.state and GD.state.last_attack and GD.state.last_attack.target) or _target())
  if P and type(P.clear_staged_for_target) == "function" and tgt ~= "" then
    P.clear_staged_for_target(tgt, tostring(ctx.reason or "loop_stopped"))
  end
  if P and type(P.clear_pending_class) == "function" then
    P.clear_pending_class("loop_stopped", { clear_any = true, clear_staged = true })
  end
  if P and P.state and type(P.state.evaluate) == "table" then
    P.state.evaluate.active = false
    P.state.evaluate.target = ""
    P.state.evaluate.requested_at = 0
    P.state.evaluate.started_at = 0
  end
  _clear_route_owned_queues(tostring(ctx.reason or "loop_stopped"))
  _homunculus_pacify_on_stop(GD)
  if ctx.silent ~= true then
    _echo(string.format("Alchemist group damage loop OFF (%s).", tostring(ctx.reason or "manual")))
  end
end

function GD.alias_loop_clear_waiting()
  GD.state.waiting = GD.state.waiting or {}
  GD.state.waiting.queue = nil
  GD.state.waiting.main_lane = nil
  GD.state.waiting.lanes = nil
  GD.state.waiting.at = 0
end

function GD.alias_loop_waiting_blocks()
  return false
end

GD.alias_loop_stop_details = GD.alias_loop_stop_details or {
  no_target = true,
  invalid_target = true,
  wrong_class = true,
  route_inactive = true,
}

function GD.build_payload(ctx)
  return _select_payload(ctx or {})
end

function GD.attack_function(ctx)
  GD.init()
  if not GD.is_active() then
    local P = _phys()
    local tgt = _trim((GD.state and GD.state.last_attack and GD.state.last_attack.target) or _target())
    if P and type(P.reave_sync_target) == "function" then
      pcall(P.reave_sync_target, "", "route_inactive")
    end
    if P and type(P.clear_staged_for_target) == "function" and tgt ~= "" then
      P.clear_staged_for_target(tgt, "route_inactive")
    end
    _set_hold_explain("route_inactive", tgt)
    return false, "route_inactive"
  end

  local payload, why = GD.build_payload(ctx)
  if not payload then
    GD.state.template.last_reason = why or "no_legal_action"
    _set_hold_explain(why or "no_legal_action", _target())
    return false, why
  end

  local sent = _emit_payload(payload)
  if sent ~= true then
    return false, "send_failed"
  end

  local cmd = (type(payload.direct_order) == "table" and table.concat(payload.direct_order, _sep()))
    or payload.class or payload.eq or payload.bal or payload.free or ""

  GD.state.last_attack = GD.state.last_attack or {}
  GD.state.last_attack.at = _now()
  GD.state.last_attack.target = _trim(payload.target)
  GD.state.last_attack.main_lane = payload.class and "class" or (payload.eq and "eq" or (payload.bal and "bal" or "free"))
  GD.state.last_attack.lanes = payload.lanes
  GD.state.last_attack.cmd = cmd

  GD.state.template = GD.state.template or {}
  GD.state.template.last_payload = payload
  GD.state.template.last_target = payload.target
  GD.state.template.last_reason = payload.reason

  GD.state.explain = {
    target = payload.target,
    category = payload.category,
    reason = payload.reason,
    eq = payload.eq,
    class = payload.class,
    bal = payload.bal,
    free = payload.free,
    direct_order = payload.direct_order,
  }

  return true, GD.state.last_attack.main_lane
end

function GD.start(reason)
  GD.init()
  GD.cfg.enabled = true
  GD.state.enabled = true
  GD.state.loop_enabled = true
  GD.reset_route_state(tostring(reason or "start"), _target())
  _schedule_loop(0, "start")
  return true
end

function GD.stop(reason)
  GD.init()
  local P = _phys()
  local tgt = _trim((GD.state and GD.state.last_attack and GD.state.last_attack.target) or _target())
  if P and type(P.reave_sync_target) == "function" then
    pcall(P.reave_sync_target, "", "route_stop")
  end
  if P and type(P.clear_staged_for_target) == "function" and tgt ~= "" then
    P.clear_staged_for_target(tgt, tostring(reason or "manual_stop"))
  end
  if P and type(P.clear_pending_class) == "function" then
    P.clear_pending_class("route_stop", { clear_any = true, clear_staged = true })
  end
  if P and P.state and type(P.state.evaluate) == "table" then
    P.state.evaluate.active = false
    P.state.evaluate.target = ""
    P.state.evaluate.requested_at = 0
    P.state.evaluate.started_at = 0
  end

  _clear_route_owned_queues(tostring(reason or "route_stop"))
  _homunculus_pacify_on_stop(GD)

  GD.state.loop_enabled = false
  GD.state.enabled = false
  GD.cfg.enabled = false
  GD.state.busy = false
  GD.alias_loop_clear_waiting()
  GD.state.template = GD.state.template or {}
  GD.state.template.last_disable_reason = tostring(reason or "manual")
  return true
end

function GD.on_enter(ctx)
  GD.init()
  return true
end

function GD.on_exit(ctx)
  return GD.stop("exit")
end

function GD.on_target_swap(old_target, new_target, reason)
  local ctx = {}
  if type(old_target) == "table" then
    ctx = old_target
  else
    ctx.old_target = old_target
    ctx.new_target = new_target
    ctx.reason = reason
  end

  local P = _phys()
  local old_tgt = _trim(ctx.old_target or ctx.old or "")
  local new_tgt = _trim(ctx.new_target or ctx.new or _target())

  GD.reset_route_state("target_swap", old_tgt)

  if P and new_tgt ~= "" and type(P.target_needs_evaluate) == "function" and type(P.mark_all_eval_dirty) == "function" then
    if P.target_needs_evaluate(new_tgt) == true then
      P.mark_all_eval_dirty(new_tgt, "target_swap")
    end
  end

  _set_hold_explain("target_swap_clear", new_tgt, {
    old_target = old_tgt,
    new_target = new_tgt,
  })

  _schedule_loop(0, "target_swap")
  return true
end

function GD.on_pause(ctx)
  return true
end

function GD.on_resume(ctx)
  if GD.state and GD.state.loop_enabled == true then
    _schedule_loop(0, "resume")
  end
  return true
end

function GD.on_manual_success(ctx)
  if GD.state and GD.state.loop_enabled == true then
    _schedule_loop(tonumber(GD.cfg.loop_delay or 0.15) or 0.15, "manual_success")
  end
  return true
end

function GD.on_send_result(payload, ctx)
  payload = payload or {}
  if RI and type(RI.payload_has_any_route) == "function"
    and RI.payload_has_any_route(payload)
    and type(RI.payload_has_route) == "function"
    and not RI.payload_has_route(payload, "alchemist_group_damage")
  then
    return false
  end

  local tgt = _trim(payload.target or _target())
  local class_cmd = _trim(payload.class or "")
  if class_cmd:match("^temper%s+") then
    _set_hold_explain("temper_pending", tgt, { pending_cmd = class_cmd })
  end

  if GD.state and GD.state.loop_enabled == true then
    _schedule_loop(0, "send_result")
  end
  return true
end

function GD.evaluate(ctx)
  local payload, why = GD.build_payload(ctx)
  if not payload then
    return { ok = false, reason = why }
  end
  return { ok = true, payload = payload, reason = why }
end

function GD.explain()
  GD.init()
  return GD.state.explain or {}
end

return GD
