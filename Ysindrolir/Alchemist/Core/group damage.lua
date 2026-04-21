--========================================================--
-- Alchemist / group damage.lua
--  Party damage route for Alchemist.
--  Alias-controlled loop ownership is handled by Yso.mode via ^adam$.
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
    "eq_finisher",
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

GD.cfg = GD.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,
  evaluate_pending_s = 1.2,
}

GD.giving_default = GD.giving_default or {
  "paralysis", -- Can only be given once sanguine is confirmed at two steady tempers.
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

local function _same_target(a, b)
  return _lc(a) ~= "" and _lc(a) == _lc(b)
end

local function _is_party_damage_route()
  local M = Yso and Yso.mode or nil
  if type(M) ~= "table" then
    return false
  end
  if type(M.is_party) == "function" then
    local ok, v = pcall(M.is_party)
    if ok and v ~= true then
      return false
    end
  end
  if type(M.party_route) == "function" then
    local ok, v = pcall(M.party_route)
    local route = ok and _lc(v) or ""
    if route ~= "" and route ~= "dam" and route ~= "dmg" then
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
  return (_now() - at) <= (tonumber(GD.cfg.evaluate_pending_s or 1.2) or 1.2)
end

local function _giving_set()
  return type(GD.giving_default) == "table" and GD.giving_default or {}
end

local function _emit_payload(payload)
  if type(Yso.emit) == "function" then
    return Yso.emit(payload, {
      reason = "alchemist_group_damage:" .. tostring(payload.category or "action"),
      kind = "offense",
      commit = true,
      route = "alchemist_group_damage",
      target = payload.target,
    }) == true
  end

  local Q = Yso and Yso.queue or nil
  if Q and type(Q.stage) == "function" and type(Q.commit) == "function" then
    if payload.free then
      Q.stage("free", payload.free, { route = "alchemist_group_damage", target = payload.target })
    end
    if payload.eq then
      Q.stage("eq", payload.eq, { route = "alchemist_group_damage", target = payload.target })
    end
    if payload.bal then
      Q.stage("bal", payload.bal, { route = "alchemist_group_damage", target = payload.target })
    end
    local ok = Q.commit({ route = "alchemist_group_damage", target = payload.target, allow_eqbal = true })
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
    route = "alchemist_group_damage",
    target = tgt,
    category = category,
    reason = reason,
    lanes = {},
  }
  payload[lane] = cmd
  payload.lanes[lane] = cmd
  return payload
end

local function _select_action(ctx)
  GD.init()

  local tgt = _trim((ctx and ctx.target) or _target())
  if tgt == "" then
    return nil, "no_target"
  end
  if not _target_valid(tgt) then
    return nil, "invalid_target"
  end

  local P = _phys()
  if not P then
    return nil, "phys_unavailable"
  end

  local giving = _giving_set()
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

  if _eq_ready() and type(P.iron_aff_count) == "function" and P.iron_aff_count(tgt, giving) == 3 then
    local cmd = string.format("educe iron %s", tgt)
    return {
      kind = "emit",
      lane = "eq",
      cmd = cmd,
      payload = _make_payload(tgt, "eq", cmd, "eq_finisher", "iron_window"),
      reason = "iron_window",
      category = "eq_finisher",
      explain = {
        target = tgt,
        iron_aff_count = 3,
      },
    }
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
      local cmd, humour = P.build_wrack_fallback(tgt)
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
            filler_humour = humour,
          },
        }
      end
    end
  end

  return nil, "no_legal_action"
end

function GD.init()
  GD.cfg = GD.cfg or {}
  GD.state = GD.state or {}
  GD.state.waiting = GD.state.waiting or { queue = nil, main_lane = nil, lanes = nil, at = 0 }
  GD.state.last_attack = GD.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil }
  GD.state.template = GD.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  GD.state.explain = GD.state.explain or {}
  GD.state.loop_enabled = (GD.state.loop_enabled == true)
  GD.state.enabled = (GD.state.enabled == true)
  GD.state.busy = (GD.state.busy == true)
  GD.cfg.loop_delay = tonumber(GD.cfg.loop_delay or 0.15) or 0.15

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

function GD.alias_loop_on_started()
  _echo("Alchemist group damage loop ON.")
end

function GD.alias_loop_on_stopped(ctx)
  ctx = ctx or {}
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
  local action, why = _select_action(ctx or {})
  if not action then
    return nil, why
  end
  if action.kind == "emit" then
    return action.payload, action.reason
  end
  return {
    route = "alchemist_group_damage",
    target = action.explain and action.explain.target or _target(),
    direct = action.cmd,
    lane = action.lane,
    category = action.category,
  }, action.reason
end

function GD.attack_function(ctx)
  GD.init()
  if not GD.is_active() then
    return false, "route_inactive"
  end

  local action, why = _select_action(ctx or {})
  if not action then
    GD.state.template.last_reason = why or "no_legal_action"
    return false, why
  end

  local sent = false
  if action.kind == "emit" then
    sent = (_emit_payload(action.payload) == true)
  elseif action.kind == "direct" then
    if type(send) == "function" then
      sent = pcall(send, action.cmd, false) == true
    end
    if sent == true and Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
      Yso.alc.set_humour_ready(false, "temper_sent")
    end
  end

  if sent ~= true then
    return false, "send_failed"
  end

  local tgt = action.explain and action.explain.target or _target()
  GD.state.last_attack = GD.state.last_attack or {}
  GD.state.last_attack.at = _now()
  GD.state.last_attack.target = tgt
  GD.state.last_attack.main_lane = action.lane
  GD.state.last_attack.lanes = action.payload and action.payload.lanes or nil
  GD.state.last_attack.cmd = action.cmd
  GD.state.template = GD.state.template or {}
  GD.state.template.last_payload = action.payload or { direct = action.cmd }
  GD.state.template.last_target = tgt
  GD.state.template.last_reason = action.reason
  GD.state.explain = action.explain or {}
  GD.state.explain.kind = action.kind
  GD.state.explain.cmd = action.cmd
  GD.state.explain.category = action.category
  GD.state.explain.reason = action.reason
  return true, action.lane
end

function GD.start()
  GD.init()
  GD.cfg.enabled = true
  GD.state.enabled = true
  GD.state.loop_enabled = true
  GD.state.busy = false
  GD.alias_loop_clear_waiting()
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    pcall(Yso.mode.schedule_route_loop, "alchemist_group_damage", 0)
  end
  return true
end

function GD.stop(reason)
  GD.init()
  GD.state.loop_enabled = false
  GD.state.enabled = false
  GD.cfg.enabled = false
  GD.state.busy = false
  GD.alias_loop_clear_waiting()
  GD.state.template = GD.state.template or {}
  GD.state.template.last_disable_reason = tostring(reason or "manual")
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
