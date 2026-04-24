--========================================================--
-- Alchemist / duel route.lua
--  Duel lock-pressure route for Alchemist.
--  Alias-controlled loop ownership is handled by Yso.mode via ^aduel$.
--========================================================--

_G.Yso = _G.Yso or _G.yso or {}
_G.yso = _G.Yso

Yso = _G.Yso
Yso.off = Yso.off or {}
Yso.off.alc = Yso.off.alc or {}

Yso.off.alc.duel_route = Yso.off.alc.duel_route or {}
local DR = Yso.off.alc.duel_route
DR.alias_owned = true

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

DR.route_contract = DR.route_contract or {
  id = "alchemist_duel_route",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "evaluate",
    "eq_finisher",
    "reave",
    "corrupt",
    "inundate",
    "temper",
    "truewrack",
    "wrack_filler",
    "hold",
  },
  capabilities = {
    uses_eq = true,
    uses_bal = true,
    uses_entity = false,
    supports_burst = false,
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

DR.cfg = DR.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,
  evaluate_pending_s = 1.2,
  inundate_humour = "phlegmatic",
  inundate_min_temper = 2,
}

Yso.giving = (type(Yso.giving) == "table" and Yso.giving) or {
  "paralysis",
  "asthma",
  "impatience",
}

DR.state = DR.state or {
  enabled = false,
  loop_enabled = false,
  timer_id = nil,
  busy = false,
  waiting = { queue = nil, main_lane = nil, lanes = nil, at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil },
  template = { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" },
  explain = {},
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
  if DR.cfg.echo ~= true then
    return
  end
  if type(cecho) == "function" then
    cecho(string.format("<orange>[Yso:Alchemist] <reset>%s\n", tostring(msg)))
  elseif type(echo) == "function" then
    echo(string.format("[Yso:Alchemist] %s\n", tostring(msg)))
  end
end

local function _phys()
  return Yso and Yso.alc and Yso.alc.phys or nil
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
  if Yso and Yso.classinfo and type(Yso.classinfo.is) == "function" then
    local ok, v = pcall(Yso.classinfo.is, "Alchemist")
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

local function _evaluate_ready()
  if Yso.alc and type(Yso.alc.evaluate_ready) == "function" then
    local ok, v = pcall(Yso.alc.evaluate_ready)
    if ok then
      return v == true
    end
  end
  return Yso and Yso.bal and Yso.bal.evaluate ~= false
end

local function _humour_ready()
  if Yso.alc and type(Yso.alc.humour_ready) == "function" then
    local ok, v = pcall(Yso.alc.humour_ready)
    if ok then
      return v == true
    end
  end
  return Yso and Yso.bal and Yso.bal.humour ~= false
end

local function _homunculus_ready()
  if Yso.alc and type(Yso.alc.homunculus_ready) == "function" then
    local ok, v = pcall(Yso.alc.homunculus_ready)
    if ok then
      return v == true
    end
  end
  return Yso and Yso.bal and Yso.bal.homunculus ~= false
end

local function _same_target(a, b)
  return _lc(a) ~= "" and _lc(a) == _lc(b)
end

local function _is_duel_route()
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
    if id ~= "" and id ~= "none" and id ~= "alchemist_duel_route" and id ~= "aduel" then
      return false
    end
  end
  if type(M.route_loop_active) == "function" then
    local ok, v = pcall(M.route_loop_active, "alchemist_duel_route")
    if ok and v ~= true then
      return false
    end
  end
  return true
end

local function _evaluate_pending_for(tgt)
  local P = _phys()
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
  return (_now() - at) <= (tonumber(DR.cfg.evaluate_pending_s or 1.2) or 1.2)
end

local function _giving_set()
  return type(Yso.giving) == "table" and Yso.giving or {}
end

local function _emit_payload(payload)
  if type(Yso.emit) == "function" then
    return Yso.emit(payload, {
      reason = "alchemist_duel_route:" .. tostring(payload.category or "action"),
      kind = "offense",
      commit = true,
      route = "alchemist_duel_route",
      target = payload.target,
    }) == true
  end

  local Q = Yso and Yso.queue or nil
  if Q and type(Q.stage) == "function" and type(Q.commit) == "function" then
    if payload.free then
      Q.stage("free", payload.free, { route = "alchemist_duel_route", target = payload.target })
    end
    if payload.eq then
      Q.stage("eq", payload.eq, { route = "alchemist_duel_route", target = payload.target })
    end
    if payload.bal then
      Q.stage("bal", payload.bal, { route = "alchemist_duel_route", target = payload.target })
    end
    local ok = Q.commit({ route = "alchemist_duel_route", target = payload.target, allow_eqbal = true })
    return ok == true
  end

  if payload.free and type(send) == "function" then
    return pcall(send, payload.free, false) == true
  end
  if payload.eq and type(send) == "function" then
    return pcall(send, payload.eq, false) == true
  end
  if payload.bal and type(send) == "function" then
    return pcall(send, payload.bal, false) == true
  end

  return false
end

local function _make_payload(tgt, lane, cmd, category, reason)
  local payload = {
    route = "alchemist_duel_route",
    target = tgt,
    category = category,
    reason = reason,
    lanes = {},
  }
  payload[lane] = cmd
  payload.lanes[lane] = cmd
  return payload
end

local function _pick_missing_aff(tgt, giving, P)
  if type(P.pick_missing_aff) ~= "function" then
    return nil
  end
  local aff = _trim(P.pick_missing_aff(tgt, giving))
  if aff == "" then
    return nil
  end
  return aff
end

local function _select_action(ctx)
  DR.init()

  local tgt = _trim((ctx and ctx.target) or _target())
  local P = _phys()
  if P and type(P.reave_sync_target) == "function" then
    P.reave_sync_target(tgt, "duel_route_tick")
  end
  if tgt == "" then
    return nil, "no_target"
  end
  if not _target_valid(tgt) then
    if P and type(P.reave_sync_target) == "function" then
      P.reave_sync_target("", "duel_invalid_target")
    end
    return nil, "invalid_target"
  end

  if not P then
    return nil, "phys_unavailable"
  end

  local giving = _giving_set()
  -- Evaluate refresh if needed.
  local needs_eval = (type(P.target_needs_evaluate) == "function") and (P.target_needs_evaluate(tgt) == true) or false
  if needs_eval and _evaluate_ready() and not _evaluate_pending_for(tgt) then
    local cmd = string.format("evaluate %s humours", tgt)
    if type(P.note_evaluate_request) == "function" then
      P.note_evaluate_request(tgt, "route")
    end
    return {
      kind = "emit",
      lane = "free",
      cmd = cmd,
      payload = _make_payload(tgt, "free", cmd, "evaluate", "humour_intel_dirty"),
      reason = "humour_intel_dirty",
      category = "evaluate",
      explain = {
        target = tgt,
        needs_eval = true,
      },
    }
  end

  -- Instant kills / eq finishers.
  -- Aurification execute window should resolve before normal duel progression.
  if _eq_ready() and type(P.can_aurify) == "function" and P.can_aurify(tgt) then
    local cmd = string.format("aurify %s", tgt)
    return {
      kind = "emit",
      lane = "eq",
      cmd = cmd,
      payload = _make_payload(tgt, "eq", cmd, "eq_finisher", "aurify_window"),
      reason = "aurify_window",
      category = "eq_finisher",
      explain = {
        target = tgt,
        aurify = true,
        health_pct = P.health_pct and P.health_pct(tgt) or nil,
        mana_pct = P.mana_pct and P.mana_pct(tgt) or nil,
      },
    }
  end

  -- Reave execute window (channeled humour-balance finisher).
  if _humour_ready() and type(P.can_reave) == "function" then
    local can_reave, profile = P.can_reave(tgt)
    if can_reave then
      local cmd = string.format("reave %s", tgt)
      return {
        kind = "direct",
        lane = "humour",
        cmd = cmd,
        reason = "reave_window",
        category = "reave",
        explain = {
          target = tgt,
          reave = true,
          reave_profile = profile,
        },
      }
    end
  end

  if _homunculus_ready() then
    local corrupt_active = false
    if type(P.corruption_active) == "function" then
      corrupt_active = (P.corruption_active(tgt) == true)
    end
    if not corrupt_active then
      local cmd = string.format("homunculus corrupt %s", tgt)
      return {
        kind = "direct",
        lane = "homunculus",
        cmd = cmd,
        reason = "corrupt_window",
        category = "corrupt",
        explain = {
          target = tgt,
          corruption_active = false,
        },
      }
    end
  end

  if _humour_ready() then
    local inundate_humour = _trim(DR.cfg.inundate_humour or "phlegmatic")
    local min_temper = tonumber(DR.cfg.inundate_min_temper or 2) or 2
    local count = tonumber(type(P.current_humour_count) == "function" and P.current_humour_count(tgt, inundate_humour) or 0) or 0
    local missing = _pick_missing_aff(tgt, giving, P)
    if count >= min_temper and missing then
      local cmd = string.format("inundate %s %s", tgt, inundate_humour)
      return {
        kind = "direct",
        lane = "humour",
        cmd = cmd,
        reason = "inundate_window",
        category = "inundate",
        explain = {
          target = tgt,
          humour = inundate_humour,
          missing_aff = missing,
          humour_count = count,
        },
      }
    end
  end

  if _humour_ready() and type(P.pick_temper_humour) == "function" then
    local humour = _trim(P.pick_temper_humour(tgt, giving))
    if humour ~= "" then
      local cmd = string.format("temper %s %s", tgt, humour)
      return {
        kind = "direct",
        lane = "humour",
        cmd = cmd,
        reason = "temper_window",
        category = "temper",
        explain = {
          target = tgt,
          humour = humour,
        },
      }
    end
  end

  if _bal_ready() then
    if type(P.build_truewrack) == "function" then
      local cmd, filler, forced = P.build_truewrack(tgt, giving)
      if cmd and cmd ~= "" then
        return {
          kind = "emit",
          lane = "bal",
          cmd = cmd,
          payload = _make_payload(tgt, "bal", cmd, "truewrack", "missing_aff_pressure"),
          reason = "missing_aff_pressure",
          category = "truewrack",
          explain = {
            target = tgt,
            filler_humour = filler,
            forced_aff = forced,
          },
        }
      end
    end

    if type(P.build_wrack_fallback) == "function" then
      local cmd, aff = P.build_wrack_fallback(tgt, giving)
      if cmd and cmd ~= "" then
        return {
          kind = "emit",
          lane = "bal",
          cmd = cmd,
          payload = _make_payload(tgt, "bal", cmd, "wrack_filler", "hybrid_not_useful"),
          reason = "hybrid_not_useful",
          category = "wrack_filler",
          explain = {
            target = tgt,
            forced_aff = aff,
          },
        }
      end
    end
  end

  return nil, "no_legal_action"
end

function DR.init()
  DR.cfg = DR.cfg or {}
  DR.state = DR.state or {}
  DR.state.waiting = DR.state.waiting or { queue = nil, main_lane = nil, lanes = nil, at = 0 }
  DR.state.last_attack = DR.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil }
  DR.state.template = DR.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  DR.state.explain = DR.state.explain or {}
  DR.state.loop_enabled = (DR.state.loop_enabled == true)
  DR.state.enabled = (DR.state.enabled == true)
  DR.state.busy = (DR.state.busy == true)
  DR.cfg.loop_delay = tonumber(DR.cfg.loop_delay or 0.15) or 0.15

  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(DR, DR.route_contract)
  end
  if Yso and Yso.off and Yso.off.core and type(Yso.off.core.register) == "function" then
    pcall(Yso.off.core.register, "alchemist_duel_route", DR)
    pcall(Yso.off.core.register, "aduel", DR)
  end
  return true
end

function DR.is_active()
  if not _is_alchemist() then
    return false
  end
  if DR.cfg.enabled ~= true or DR.state.enabled ~= true or DR.state.loop_enabled ~= true then
    return false
  end
  if type(Yso.offense_paused) == "function" then
    local ok, v = pcall(Yso.offense_paused)
    if ok and v == true then
      return false
    end
  end
  return _is_duel_route()
end

function DR.alias_loop_on_started()
  _echo("Alchemist duel route loop ON.")
end

function DR.alias_loop_on_stopped(ctx)
  ctx = ctx or {}
  if ctx.silent ~= true then
    _echo(string.format("Alchemist duel route loop OFF (%s).", tostring(ctx.reason or "manual")))
  end
end

function DR.alias_loop_clear_waiting()
  DR.state.waiting = DR.state.waiting or {}
  DR.state.waiting.queue = nil
  DR.state.waiting.main_lane = nil
  DR.state.waiting.lanes = nil
  DR.state.waiting.at = 0
end

function DR.alias_loop_waiting_blocks()
  return false
end

DR.alias_loop_stop_details = DR.alias_loop_stop_details or {
  no_target = true,
  invalid_target = true,
  wrong_class = true,
  route_inactive = true,
}

function DR.build_payload(ctx)
  local action, why = _select_action(ctx or {})
  if not action then
    return nil, why
  end
  if action.kind == "emit" then
    return action.payload, action.reason
  end
  return {
    route = "alchemist_duel_route",
    target = action.explain and action.explain.target or _target(),
    direct = action.cmd,
    lane = action.lane,
    category = action.category,
  }, action.reason
end

function DR.attack_function(ctx)
  DR.init()
  if not DR.is_active() then
    return false, "route_inactive"
  end
  local P = _phys()

  local action, why = _select_action(ctx or {})
  if not action then
    DR.state.template.last_reason = why or "no_legal_action"
    return false, why
  end

  local sent = false
  if action.kind == "emit" then
    sent = (_emit_payload(action.payload) == true)
  elseif action.kind == "direct" then
    if action.category == "reave" and P and type(P.fire_reave) == "function" then
      sent = (P.fire_reave(action.explain and action.explain.target or _target(), action.explain and action.explain.reave_profile or nil) == true)
    elseif type(send) == "function" then
      sent = pcall(send, action.cmd, false) == true
    end
    if sent == true and action.category == "temper" and Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
      Yso.alc.set_humour_ready(false, "temper_sent")
    elseif sent == true and action.category == "inundate" and Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
      Yso.alc.set_humour_ready(false, "inundate_sent")
    elseif sent == true and action.category == "corrupt" and Yso.alc and type(Yso.alc.set_homunculus_ready) == "function" then
      Yso.alc.set_homunculus_ready(false, "corrupt_sent")
    end
  end

  if sent ~= true then
    return false, "send_failed"
  end

  local tgt = action.explain and action.explain.target or _target()
  DR.state.last_attack = DR.state.last_attack or {}
  DR.state.last_attack.at = _now()
  DR.state.last_attack.target = tgt
  DR.state.last_attack.main_lane = action.lane
  DR.state.last_attack.lanes = action.payload and action.payload.lanes or nil
  DR.state.last_attack.cmd = action.cmd
  DR.state.template = DR.state.template or {}
  DR.state.template.last_payload = action.payload or { direct = action.cmd }
  DR.state.template.last_target = tgt
  DR.state.template.last_reason = action.reason
  DR.state.explain = action.explain or {}
  DR.state.explain.kind = action.kind
  DR.state.explain.cmd = action.cmd
  DR.state.explain.category = action.category
  DR.state.explain.reason = action.reason
  return true, action.lane
end

function DR.start()
  DR.init()
  DR.cfg.enabled = true
  DR.state.enabled = true
  DR.state.loop_enabled = true
  DR.state.busy = false
  DR.alias_loop_clear_waiting()
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    pcall(Yso.mode.schedule_route_loop, "alchemist_duel_route", 0)
  end
  return true
end

function DR.stop(reason)
  DR.init()
  DR.state.loop_enabled = false
  DR.state.enabled = false
  DR.cfg.enabled = false
  DR.state.busy = false
  DR.alias_loop_clear_waiting()
  DR.state.template = DR.state.template or {}
  DR.state.template.last_disable_reason = tostring(reason or "manual")
  return true
end

function DR.evaluate(ctx)
  local payload, why = DR.build_payload(ctx)
  if not payload then
    return { ok = false, reason = why }
  end
  return { ok = true, payload = payload, reason = why }
end

function DR.explain()
  DR.init()
  return DR.state.explain or {}
end

return DR
