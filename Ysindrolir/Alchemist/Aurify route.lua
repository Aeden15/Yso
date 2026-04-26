--========================================================--
-- Alchemist / Aurify route.lua
--  Aurify-focused route for bleed pressure and execute setup.
--========================================================--

_G.Yso = _G.Yso or _G.yso or {}
_G.yso = _G.Yso

Yso = _G.Yso
Yso.off = Yso.off or {}
Yso.off.alc = Yso.off.alc or {}

Yso.off.alc.aurify_route = Yso.off.alc.aurify_route or {}
local AR = Yso.off.alc.aurify_route
AR.alias_owned = true

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
  _load_alchemist_peer("Core/physiology.lua")
end

local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
if not (RI and type(RI.ensure_hooks) == "function") and type(require) == "function" then
  pcall(require, "Yso.Combat.route_interface")
  pcall(require, "Yso.xml.route_interface")
  RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
end

AR.route_contract = AR.route_contract or {
  id = "alchemist_aurify_route",
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

AR.cfg = AR.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,
  evaluate_pending_s = 1.2,
  salt_min_affs = 2,
  salt_cooldown_s = 3.2,
  allow_reave = true,
}

AR.giving_default = AR.giving_default or {
  "paralysis",
  "nausea",
  "sensitivity",
  "haemophilia",
}

AR.state = AR.state or {
  enabled = false,
  loop_enabled = false,
  timer_id = nil,
  busy = false,
  waiting = { queue = nil, main_lane = nil, lanes = nil, at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil },
  template = { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" },
  explain = {},
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
  if AR.cfg.echo ~= true then
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
  return (_now() - at) <= (tonumber(AR.cfg.evaluate_pending_s or 1.2) or 1.2)
end

local function _is_aurify_route()
  local M = Yso and Yso.mode or nil
  if type(M) ~= "table" then
    return false
  end
  if type(M.is_party) == "function" then
    local ok, v = pcall(M.is_party)
    if ok and v == true then
      return false
    end
  end
  if type(M.active_route_id) == "function" then
    local ok, v = pcall(M.active_route_id)
    local id = ok and _lc(v) or ""
    if id ~= "" and id ~= "none" and id ~= "alchemist_aurify_route" then
      return false
    end
  end
  if type(M.route_loop_active) == "function" then
    local ok, v = pcall(M.route_loop_active, "alchemist_aurify_route")
    if ok and v ~= true then
      return false
    end
  end
  return true
end

local function _make_payload(tgt, category, reason)
  return {
    route = "alchemist_aurify_route",
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
  if not (_bal_ready() and _can_plan_bal()) then
    return nil
  end
  if type(P.build_truewrack_with_staged) == "function" then
    local cmd = P.build_truewrack_with_staged(tgt, giving, staged)
    if _trim(cmd) ~= "" then return cmd end
  end
  if type(P.build_wrack_fallback_with_staged) == "function" then
    local cmd = P.build_wrack_fallback_with_staged(tgt, giving, staged)
    if _trim(cmd) ~= "" then return cmd end
  end
  if type(P.build_truewrack) == "function" then
    local cmd = P.build_truewrack(tgt, giving)
    if _trim(cmd) ~= "" then return cmd end
  end
  if type(P.build_wrack_fallback) == "function" then
    local cmd = P.build_wrack_fallback(tgt, giving)
    if _trim(cmd) ~= "" then return cmd end
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

local function _pick_threshold_temper(P, tgt, giving)
  if not _class_ready() then
    return nil
  end

  local chol = tonumber(type(P.current_humour_count) == "function" and P.current_humour_count(tgt, "choleric") or 0) or 0
  local mel = tonumber(type(P.current_humour_count) == "function" and P.current_humour_count(tgt, "melancholic") or 0) or 0
  local sang = tonumber(type(P.current_humour_count) == "function" and P.current_humour_count(tgt, "sanguine") or 0) or 0

  if chol < 6 then
    return { humour = "choleric", cmd = "temper " .. tgt .. " choleric", reason = "temper_to_choleric_6" }
  end
  if mel < 6 then
    return { humour = "melancholic", cmd = "temper " .. tgt .. " melancholic", reason = "temper_to_melancholic_6" }
  end
  if sang < 6 then
    return { humour = "sanguine", cmd = "temper " .. tgt .. " sanguine", reason = "temper_to_sanguine_6" }
  end
  if chol < 8 then
    return { humour = "choleric", cmd = "temper " .. tgt .. " choleric", reason = "temper_to_choleric_8" }
  end
  if mel < 8 then
    return { humour = "melancholic", cmd = "temper " .. tgt .. " melancholic", reason = "temper_to_melancholic_8" }
  end
  return _pick_temper(P, tgt, giving)
end

local function _pick_execute_inundate(P, tgt)
  if not _class_ready() then
    return nil
  end

  local hp = tonumber(type(P.health_pct) == "function" and P.health_pct(tgt) or nil)
  local mp = tonumber(type(P.mana_pct) == "function" and P.mana_pct(tgt) or nil)
  local chol = tonumber(type(P.current_humour_count) == "function" and P.current_humour_count(tgt, "choleric") or 0) or 0
  local mel = tonumber(type(P.current_humour_count) == "function" and P.current_humour_count(tgt, "melancholic") or 0) or 0
  local sang = tonumber(type(P.current_humour_count) == "function" and P.current_humour_count(tgt, "sanguine") or 0) or 0

  local function _after(vital, burst)
    if vital == nil then return nil end
    local n = vital - burst
    if n < 0 then n = 0 end
    return n
  end

  if chol >= 8 and hp ~= nil then
    local after = _after(hp, 77)
    if after and after <= 60 then
      return { humour = "choleric", cmd = "inundate " .. tgt .. " choleric", reason = "inundate_health_execute", predicted_after_pct = after }
    end
  end
  if chol >= 6 and hp ~= nil then
    local after = _after(hp, 50)
    if after and after <= 60 then
      return { humour = "choleric", cmd = "inundate " .. tgt .. " choleric", reason = "inundate_health_execute", predicted_after_pct = after }
    end
  end

  if mel >= 8 and mp ~= nil then
    local after = _after(mp, 77)
    if after and after <= 60 then
      return { humour = "melancholic", cmd = "inundate " .. tgt .. " melancholic", reason = "inundate_mana_execute", predicted_after_pct = after }
    end
  end
  if mel >= 6 and mp ~= nil then
    local after = _after(mp, 50)
    if after and after <= 60 then
      return { humour = "melancholic", cmd = "inundate " .. tgt .. " melancholic", reason = "inundate_mana_execute", predicted_after_pct = after }
    end
  end

  if sang >= 6 and _vitrification_active(P, tgt) then
    local out = {
      humour = "sanguine",
      cmd = "inundate " .. tgt .. " sanguine",
      reason = (sang >= 8) and "inundate_bleed_burst_tbd_8" or "inundate_bleed_burst",
      estimated_bleeding = 2304,
    }
    if sang >= 8 then
      out.exact_bleeding_unknown = true
    end
    return out
  end

  return nil
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

local function _post_send(payload)
  local P = _phys()
  local tgt = _trim(payload and payload.target or "")
  if payload and payload.class_category == "temper" and Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
    Yso.alc.set_humour_ready(false, "temper_sent")
  elseif payload and payload.class_category == "inundate" then
    if Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
      Yso.alc.set_humour_ready(false, "inundate_sent")
    end
    if P and type(P.clear_all_humours) == "function" and tgt ~= "" then
      P.clear_all_humours(tgt, "inundate_sent")
    end
  elseif payload and payload.category == "reave" and Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
    Yso.alc.set_humour_ready(false, "reave_sent")
  end

  if payload and _lc(payload.eq or "") == "educe salt" then
    AR.state.last_salt_at = _now()
  end
end

local function _emit_payload(payload)
  local P = _phys()

  if payload.category == "reave" and P and type(P.fire_reave) == "function" then
    local ok, fired = pcall(P.fire_reave, payload.target, payload.reave_profile)
    if ok and fired == true then
      _post_send(payload)
      return true
    end
    return false
  end

  if type(payload.direct_order) == "table" and #payload.direct_order > 0 and not _use_queueing_enabled() and type(send) == "function" then
    local line = table.concat(payload.direct_order, _sep())
    if _trim(line) ~= "" and pcall(send, line, false) == true then
      _post_send(payload)
      return true
    end
    return false
  end

  if type(Yso.emit) == "function" then
    local ok = (Yso.emit(payload, {
      reason = "alchemist_aurify_route:" .. tostring(payload.category or "action"),
      kind = "offense",
      commit = true,
      route = "alchemist_aurify_route",
      target = payload.target,
      allow_eqbal = true,
    }) == true)
    if ok then
      _post_send(payload)
    end
    return ok
  end

  local Q = Yso and Yso.queue or nil
  if Q and type(Q.stage) == "function" and type(Q.commit) == "function" then
    if payload.free then Q.stage("free", payload.free, { route = "alchemist_aurify_route", target = payload.target }) end
    if payload.eq then Q.stage("eq", payload.eq, { route = "alchemist_aurify_route", target = payload.target }) end
    if payload.class then Q.stage("class", payload.class, { route = "alchemist_aurify_route", target = payload.target }) end
    if payload.bal then Q.stage("bal", payload.bal, { route = "alchemist_aurify_route", target = payload.target }) end
    local ok = Q.commit({ route = "alchemist_aurify_route", target = payload.target, allow_eqbal = true })
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
  AR.init()

  local P = _phys()
  if not P then
    return nil, "phys_unavailable"
  end

  local tgt = _trim((ctx and ctx.target) or _target())
  if type(P.reave_sync_target) == "function" then
    pcall(P.reave_sync_target, tgt, "aurify_select")
  end
  if tgt == "" then
    return nil, "no_target"
  end
  if not _target_valid(tgt) then
    return nil, "invalid_target"
  end

  local giving = type(AR.giving_default) == "table" and AR.giving_default or {}
  local free_bootstrap = _ensure_homunculus_attack(AR, tgt)

  local needs_eval = (type(P.target_needs_evaluate) == "function") and (P.target_needs_evaluate(tgt) == true) or false
  if needs_eval and _evaluate_ready() and not _evaluate_pending_for(tgt) then
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

  local shielded = _shielded(tgt)

  if shielded and _eq_ready() then
    local payload = _make_payload(tgt, "defense_break", "shieldbreak")
    if free_bootstrap then _set_lane(payload, "free", free_bootstrap) end
    _set_lane(payload, "eq", "educe copper " .. tgt)

    local inundate = _pick_execute_inundate(P, tgt)
    local staged = nil
    if inundate then
      _set_lane(payload, "class", inundate.cmd)
      payload.class_category = "inundate"
      payload.reason = inundate.reason
    else
      local temper = _pick_threshold_temper(P, tgt, giving)
      if temper then
        _set_lane(payload, "class", temper.cmd)
        payload.class_category = "temper"
        payload.reason = temper.reason
        staged = { temper_humour = temper.humour }
      end
    end

    if payload.class_category ~= "inundate" then
      local bal_cmd = _pick_wrack(P, tgt, giving, staged)
      if bal_cmd then
        _set_lane(payload, "bal", bal_cmd)
      end
    end

    _build_direct_order(payload, true)
    return payload, payload.reason
  end

  if _eq_ready() and type(P.can_aurify) == "function" and P.can_aurify(tgt) then
    local payload = _make_payload(tgt, "aurify", "aurify_window")
    if free_bootstrap then _set_lane(payload, "free", free_bootstrap) end
    _set_lane(payload, "eq", "aurify " .. tgt)
    _build_direct_order(payload, false)
    return payload, payload.reason
  end

  if AR.cfg.allow_reave == true and type(P.can_reave) == "function" then
    local can_reave, profile = P.can_reave(tgt)
    if can_reave == true then
      local payload = _make_payload(tgt, "reave", "reave_window")
      if free_bootstrap then _set_lane(payload, "free", free_bootstrap) end
      _set_lane(payload, "class", "reave " .. tgt)
      payload.class_category = "reave"
      payload.reave_profile = profile
      _build_direct_order(payload, false)
      return payload, payload.reason
    end
  end

  local salt_cmd, salt_reason = _self_purge_candidate(AR)
  if salt_cmd then
    local payload = _make_payload(tgt, "self_purge", salt_reason or "salt_self_purge")
    if free_bootstrap then _set_lane(payload, "free", free_bootstrap) end
    _set_lane(payload, "eq", salt_cmd)
    _build_direct_order(payload, false)
    return payload, payload.reason
  end

  local payload = _make_payload(tgt, "pressure", "pressure")
  if free_bootstrap then _set_lane(payload, "free", free_bootstrap) end

  local inundate = _pick_execute_inundate(P, tgt)
  local staged = nil
  if inundate then
    _set_lane(payload, "class", inundate.cmd)
    payload.class_category = "inundate"
    payload.reason = inundate.reason
    payload.category = "burst"
  else
    local temper = _pick_threshold_temper(P, tgt, giving)
    if temper then
      _set_lane(payload, "class", temper.cmd)
      payload.class_category = "temper"
      payload.reason = temper.reason
      staged = { temper_humour = temper.humour }
    end

    if _eq_ready() then
      _set_lane(payload, "eq", "educe iron " .. tgt)
    end

    local bal_cmd = _pick_wrack(P, tgt, giving, staged)
    if bal_cmd then
      _set_lane(payload, "bal", bal_cmd)
    end
  end

  _build_direct_order(payload, false)
  if not payload.eq and not payload.class and not payload.bal and not payload.free then
    return nil, "no_legal_action"
  end
  return payload, payload.reason
end

function AR.init()
  AR.cfg = AR.cfg or {}
  AR.state = AR.state or {}
  AR.state.waiting = AR.state.waiting or { queue = nil, main_lane = nil, lanes = nil, at = 0 }
  AR.state.last_attack = AR.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil }
  AR.state.template = AR.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  AR.state.explain = AR.state.explain or {}
  AR.state.loop_enabled = (AR.state.loop_enabled == true)
  AR.state.enabled = (AR.state.enabled == true)
  AR.state.busy = (AR.state.busy == true)
  AR.state.homunculus_attack_sent = (AR.state.homunculus_attack_sent == true)
  AR.state.homunculus_attack_target = _trim(AR.state.homunculus_attack_target)
  AR.state.last_salt_at = tonumber(AR.state.last_salt_at or 0) or 0
  AR.cfg.loop_delay = tonumber(AR.cfg.loop_delay or 0.15) or 0.15

  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(AR, AR.route_contract)
  end
  if Yso and Yso.off and Yso.off.core and type(Yso.off.core.register) == "function" then
    pcall(Yso.off.core.register, "alchemist_aurify_route", AR)
    pcall(Yso.off.core.register, "bleed", AR)
  end
  return true
end

function AR.is_active()
  if not _is_alchemist() then
    return false
  end
  if AR.cfg.enabled ~= true or AR.state.enabled ~= true or AR.state.loop_enabled ~= true then
    return false
  end
  if type(Yso.offense_paused) == "function" then
    local ok, v = pcall(Yso.offense_paused)
    if ok and v == true then
      return false
    end
  end
  return _is_aurify_route()
end

function AR.alias_loop_on_started()
  _echo("Alchemist aurify route loop ON.")
end

function AR.alias_loop_on_stopped(ctx)
  ctx = ctx or {}
  local P = _phys()
  local tgt = _trim((AR.state and AR.state.last_attack and AR.state.last_attack.target) or _target())
  if P and type(P.clear_staged_for_target) == "function" and tgt ~= "" then
    P.clear_staged_for_target(tgt, tostring(ctx.reason or "loop_stopped"))
  end
  if ctx.silent ~= true then
    _echo(string.format("Alchemist aurify route loop OFF (%s).", tostring(ctx.reason or "manual")))
  end
end

function AR.alias_loop_clear_waiting()
  AR.state.waiting = AR.state.waiting or {}
  AR.state.waiting.queue = nil
  AR.state.waiting.main_lane = nil
  AR.state.waiting.lanes = nil
  AR.state.waiting.at = 0
end

function AR.alias_loop_waiting_blocks()
  return false
end

AR.alias_loop_stop_details = AR.alias_loop_stop_details or {
  no_target = true,
  invalid_target = true,
  wrong_class = true,
  route_inactive = true,
}

function AR.build_payload(ctx)
  return _select_payload(ctx or {})
end

function AR.attack_function(ctx)
  AR.init()
  if not AR.is_active() then
    local P = _phys()
    local tgt = _trim((AR.state and AR.state.last_attack and AR.state.last_attack.target) or _target())
    if P and type(P.reave_sync_target) == "function" then
      pcall(P.reave_sync_target, "", "route_inactive")
    end
    if P and type(P.clear_staged_for_target) == "function" and tgt ~= "" then
      P.clear_staged_for_target(tgt, "route_inactive")
    end
    return false, "route_inactive"
  end

  local payload, why = AR.build_payload(ctx)
  if not payload then
    AR.state.template.last_reason = why or "no_legal_action"
    return false, why
  end

  local sent = _emit_payload(payload)
  if sent ~= true then
    return false, "send_failed"
  end

  local cmd = (type(payload.direct_order) == "table" and table.concat(payload.direct_order, _sep()))
    or payload.class or payload.eq or payload.bal or payload.free or ""

  AR.state.last_attack = AR.state.last_attack or {}
  AR.state.last_attack.at = _now()
  AR.state.last_attack.target = _trim(payload.target)
  AR.state.last_attack.main_lane = payload.class and "class" or (payload.eq and "eq" or (payload.bal and "bal" or "free"))
  AR.state.last_attack.lanes = payload.lanes
  AR.state.last_attack.cmd = cmd

  AR.state.template = AR.state.template or {}
  AR.state.template.last_payload = payload
  AR.state.template.last_target = payload.target
  AR.state.template.last_reason = payload.reason

  AR.state.explain = {
    target = payload.target,
    category = payload.category,
    reason = payload.reason,
    eq = payload.eq,
    class = payload.class,
    bal = payload.bal,
    free = payload.free,
    direct_order = payload.direct_order,
  }

  return true, AR.state.last_attack.main_lane
end

function AR.start()
  AR.init()
  AR.cfg.enabled = true
  AR.state.enabled = true
  AR.state.loop_enabled = true
  AR.state.busy = false
  AR.state.homunculus_attack_sent = false
  AR.state.homunculus_attack_target = ""
  AR.alias_loop_clear_waiting()
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    pcall(Yso.mode.schedule_route_loop, "alchemist_aurify_route", 0)
  end
  return true
end

function AR.stop(reason)
  AR.init()
  local P = _phys()
  local tgt = _trim((AR.state and AR.state.last_attack and AR.state.last_attack.target) or _target())
  if P and type(P.reave_sync_target) == "function" then
    pcall(P.reave_sync_target, "", "route_stop")
  end
  if P and type(P.clear_staged_for_target) == "function" and tgt ~= "" then
    P.clear_staged_for_target(tgt, tostring(reason or "manual_stop"))
  end
  if P and P.state and type(P.state.evaluate) == "table" then
    P.state.evaluate.active = false
    P.state.evaluate.target = ""
    P.state.evaluate.requested_at = 0
    P.state.evaluate.started_at = 0
  end

  _homunculus_pacify_on_stop(AR)

  AR.state.loop_enabled = false
  AR.state.enabled = false
  AR.cfg.enabled = false
  AR.state.busy = false
  AR.alias_loop_clear_waiting()
  AR.state.template = AR.state.template or {}
  AR.state.template.last_disable_reason = tostring(reason or "manual")
  return true
end

function AR.evaluate(ctx)
  local payload, why = AR.build_payload(ctx)
  if not payload then
    return { ok = false, reason = why }
  end
  return { ok = true, payload = payload, reason = why }
end

function AR.explain()
  AR.init()
  return AR.state.explain or {}
end

return AR
