-- Magi_duel_dam.lua
-- Thin-alias route module for the Magi duel damage route.
-- Intended toggle:
--   ^mdam$  ->  Yso.off.core.toggle("magi_dmg")
--
-- The route logic below preserves the same priority/order that was planned
-- for the Magi damage alias body, while living in an external file so it
-- remains easy to edit.

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.magi = Yso.off.magi or {}

local M = Yso.off.magi.dmg or {}
Yso.off.magi.dmg = M

M.key  = "magi_dmg"
M.name = "Magi Duel Damage"

-- Required by the mode engine loop (modes.lua tick_route_loop).
-- _loop_state() reads these tables; loop_delay is the re-fire interval in seconds.
M.cfg   = M.cfg   or { loop_delay = 0.15 }
M.state = M.state or {}
M.alias_owned = true

local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
if not (RI and type(RI.ensure_hooks) == "function") and type(require) == "function" then
  pcall(require, "Yso.Combat.route_interface")
  pcall(require, "Yso.xml.route_interface")
  RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
end

M.route_contract = M.route_contract or {
  id = "magi_dmg",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = { "duel_damage" },
  capabilities = {
    uses_eq = true,
    uses_bal = false,
    uses_entity = false,
    supports_burst = true,
    supports_bootstrap = true,
    needs_target = true,
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
    RI.ensure_hooks(M, M.route_contract)
  end
end

local function _trim(s)
  s = tostring(s or "")
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function _lc(s)
  return _trim(s):lower()
end

local function _vitals()
  return (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
end

local function _eq_ready()
  if Yso and Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then return v == true end
  end
  local v = _vitals()
  return tostring(v.eq or v.equilibrium or "") == "1" or v.eq == true or v.equilibrium == true
end

local function _target()
  if Yso and type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    v = ok and _trim(v) or ""
    if v ~= "" then return v end
  end

  if Yso and Yso.targeting then
    if type(Yso.targeting.get) == "function" then
      local ok, v = pcall(Yso.targeting.get)
      v = ok and _trim(v) or ""
      if v ~= "" then return v end
    elseif type(Yso.targeting.get_target) == "function" then
      local ok, v = pcall(Yso.targeting.get_target)
      v = ok and _trim(v) or ""
      if v ~= "" then return v end
    elseif type(Yso.targeting.target) == "string" then
      local v = _trim(Yso.targeting.target)
      if v ~= "" then return v end
    end
  end

  return _trim(rawget(_G, "target") or "")
end

local function _score(name)
  local score = (_G.affstrack and affstrack.score) or {}
  return tonumber(score[name] or 0) or 0
end

local function _assess()
  return tonumber(Yso.magi_assess or 999) or 999
end

local function _shielded(tgt)
  tgt = string.lower(_trim(tgt))

  if Yso and Yso.shield and type(Yso.shield.up) == "function" and tgt ~= "" then
    local ok, v = pcall(Yso.shield.up, tgt)
    if ok then return v == true end
  end

  if ak and ak.defs then
    if type(ak.defs.shield_by_target) == "table" and tgt ~= "" then
      return ak.defs.shield_by_target[tgt] == true
    end
    return ak.defs.shield == true
  end

  return false
end

function M.init()
  M.state = M.state or {}
  M.state.enabled = (M.state.enabled == true or M.enabled == true)
  M.state.loop_enabled = (M.state.loop_enabled == true or M.state.enabled == true or M.enabled == true)
  M.state.loop_delay = tonumber(M.state.loop_delay or M.cfg.loop_delay or 0.15) or 0.15
  M.state.template = M.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  if RI and type(RI.ensure_waiting_state) == "function" then
    RI.ensure_waiting_state(M.state, "magi_dmg")
  else
    M.state.waiting = M.state.waiting or { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 }
    M.state.last_attack = M.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" }
    M.state.in_flight = M.state.in_flight or { fingerprint = "", target = "", route = "magi_dmg", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" }
  end
  return true
end

function M.can_run(reason)
  M.init()
  local cls = tostring((gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class) or Yso.class or "")
  if cls:lower() ~= "magi" then return false, "wrong_class" end
  if not _eq_ready() then return false, "eq_down" end
  if _target() == "" then return false, "no_target" end
  return true
end

function M.build(reason)
  local tgt = _target()
  if tgt == "" then return nil end

  local assess = _assess()

  -- Shield handling
  if _shielded(tgt) then
    return "cast erode " .. tgt .. " maintain"

  -- Instant kills
  elseif _score("conflagrate") >= 100 and assess <= 40 then
    return "cast destroy at " .. tgt

  elseif assess <= 25 or (assess <= 30 and _score("sensitivity") >= 100) then
    return "cast stormhammer at " .. tgt

  -- Debuff timer setup
  elseif _score("scalded") < 100 then
    return "cast magma " .. tgt

  elseif _score("scalded") >= 100 and _score("waterbonds") < 100 then
    return "staff cast horripilation at " .. tgt

  -- Affliction pressure
  elseif _score("clumsiness") < 100 then
    return "cast bombard " .. tgt

  elseif _score("clumsiness") >= 100 and _score("slickness") < 100 then
    return "cast mudslide " .. tgt

  elseif _score("nausea") < 100 and _score("weariness") < 100 then
    return "cast dehydrate " .. tgt

  else
    local fulm_score =
      _score("clumsiness") +
      _score("weariness") +
      _score("slickness") +
      _score("nausea") +
      _score("sensitivity")

    if fulm_score > 200 then
      return "cast fulminate " .. tgt
    end

    local earth_res = tonumber((((ak or {}).magi or {}).resonance or {})["Earth"] or 0) or 0
    if earth_res == 2 then
      return "cast shalestorm at " .. tgt
    end
  end

  return nil
end

function M.after_send(cmd, reason)
  M.last_cmd = cmd
  M.last_reason = tostring(reason or "")
  M.last_target = _target()
end

function M.on_start()
  return M.on(true)
end

function M.on_stop()
  return M.off()
end

local function _is_destroy_cmd(cmd)
  return _lc(cmd):match("^cast%s+destroy%s+at%s+") ~= nil
end

local function _apply_execute_opts(opts, cmd)
  if _is_destroy_cmd(cmd) then
    opts.queue_verb = "addclearfull"
    opts.clearfull_lane = "eq"
  end
  return opts
end

local function _send_destroy_addclearfull(cmd)
  cmd = _trim(cmd)
  if not _is_destroy_cmd(cmd) then return nil end
  local Q = Yso and Yso.queue or nil
  local opts = _apply_execute_opts({
    route = "magi_dmg",
    target = _target(),
    reason = "magi_dmg:destroy",
    kind = "offense",
  }, cmd)
  if Q and type(Q.install_lane) == "function" then
    local ok = Q.install_lane("eq", cmd, opts)
    if ok == true then
      if type(Q.mark_lane_dispatched) == "function" then
        pcall(Q.mark_lane_dispatched, "eq", "destroy:addclearfull")
      end
      if type(Q.mark_payload_fired) == "function" then
        pcall(Q.mark_payload_fired, { eq = cmd, target = opts.target })
      end
      return true
    end
    return false
  end
  if Q and type(Q.addclearfull) == "function" then
    return Q.addclearfull("e!p!w!t", cmd) == true
  end
  if type(send) == "function" then
    return pcall(send, "QUEUE ADDCLEARFULL e!p!w!t " .. cmd, false) == true
  end
  return false
end

local function _emit_payload(cmd, target, reason)
  cmd = _trim(cmd)
  target = _trim(target)
  if cmd == "" then return false, "empty", nil end

  local opts = {
    reason = "magi_dmg:" .. tostring(reason or "attack"),
    kind = "offense",
    commit = true,
    route = "magi_dmg",
    target = target,
  }
  _apply_execute_opts(opts, cmd)

  if RI and type(RI.emit_route_payload) == "function" then
    return RI.emit_route_payload("magi_dmg", {
      target = target,
      lanes = { eq = cmd },
      meta = {
        route = "magi_dmg",
        main_lane = "eq",
        main_category = "duel_damage",
      },
    }, opts)
  end

  local payload = { eq = cmd, target = target }
  if type(Yso.emit) == "function" then
    if Yso.emit(payload, opts) == true then
      return true, cmd, payload
    end
    return false, "emit_failed", nil
  end

  local Q = Yso and Yso.queue or nil
  if Q and type(Q.stage) == "function" and type(Q.commit) == "function" then
    Q.stage("eq", cmd, opts)
    local ok = Q.commit(opts)
    if ok then
      Q._commit_hint = nil
      return true, cmd, payload
    end
    Q._commit_hint = opts
    if Yso and Yso.pulse and type(Yso.pulse.wake) == "function"
      and not (Yso.pulse.state and Yso.pulse.state._in_flush) then
      pcall(Yso.pulse.wake, "emit:staged")
    end
    return true, cmd, payload
  end

  if type(send) == "function" then
    local destroy_sent = _send_destroy_addclearfull(cmd)
    if destroy_sent ~= nil then
      if destroy_sent == true then return true, cmd, payload end
      return false, "send_failed", nil
    end
    local ok = pcall(send, cmd)
    if ok then return true, cmd, payload end
    return false, "send_failed", nil
  end

  return false, "no_send", nil
end

-- Called by modes.lua tick_route_loop on every scheduled timer tick.
-- Must return true on a successful send, false/nil otherwise.
function M.attack_function(arg)
  M.init()
  local ctx = type(arg) == "table" and arg or { reason = tostring(arg or "loop") }

  local ok_check, can, why = pcall(M.can_run, ctx)
  if not ok_check or not can then return false, (why or "cannot_run") end

  local ok_build, cmd = pcall(M.build, ctx)
  if not ok_build or not cmd or cmd == "" then return false, "empty" end

  local tgt = _target()
  local sent, emit_detail, ack_payload = _emit_payload(cmd, tgt, ctx.reason or "loop")
  if sent ~= true then return false, (emit_detail or "emit_failed") end

  if RI and type(RI.mark_waiting) == "function" then
    RI.mark_waiting(M.state, "magi_dmg", ack_payload or { eq = cmd, target = tgt }, {
      cmd = cmd,
      target = tgt,
      main_lane = "eq",
    })
  end

  local has_ack_bus = Yso and Yso.locks and type(Yso.locks.note_payload) == "function"
  local dry_run = (Yso and Yso.net and Yso.net.cfg and Yso.net.cfg.dry_run == true)
  if (not has_ack_bus or dry_run) and type(M.on_payload_sent) == "function" then
    pcall(M.on_payload_sent, ack_payload or { eq = cmd, target = tgt })
  end

  M.after_send(cmd, ctx.reason or "loop")
  return true, cmd
end

-- Standalone tick helper (useful for direct testing outside the mode engine).
function M.tick(reason)
  return M.attack_function({ reason = tostring(reason or "tick") })
end

function M.on()
  M.init()
  M.enabled = true
  M.state.enabled = true
  M.state.loop_enabled = true
  return true
end

function M.off()
  M.init()
  M.enabled = false
  M.state.enabled = false
  M.state.loop_enabled = false
  return true
end

function M.toggle()
  M.init()
  M.enabled = not (M.enabled == true or M.state.enabled == true or M.state.loop_enabled == true)
  M.state.enabled = (M.enabled == true)
  M.state.loop_enabled = (M.enabled == true)
  return M.enabled
end

function M.on_payload_sent(payload)
  M.init()
  if RI and type(RI.payload_has_any_route) == "function" and RI.payload_has_any_route(payload)
    and not RI.payload_has_route(payload, "magi_dmg")
  then
    return false
  end
  if RI and type(RI.clear_waiting_on_ack) == "function" then
    RI.clear_waiting_on_ack(M.state, "magi_dmg", payload, { require_route = false })
  end

  payload = type(payload) == "table" and payload or {}
  local lanes = type(payload.lanes) == "table" and payload.lanes or payload
  local cmd = _trim(lanes.eq or payload.eq or payload.cmd)
  if cmd ~= "" then
    M.after_send(cmd, "ack")
  end
  return true
end

function M.on_send_result(payload, ctx)
  payload = type(payload) == "table" and payload or {}
  local lanes = type(payload.lanes) == "table" and payload.lanes or payload
  M.state.last_fired_cmd = _trim(lanes.eq or payload.eq or payload.cmd)
  return true
end

-- Mode engine lifecycle callbacks -------------------------------------------

local function _echo(msg)
  if type(cecho) == "function" then
    cecho(string.format("<cadet_blue>[Yso:Magi] <reset>%s\n", tostring(msg)))
  elseif type(echo) == "function" then
    echo(string.format("[Yso:Magi] %s\n", tostring(msg)))
  end
end

function M.alias_loop_on_started(ctx)
  M.init()
  local tgt = _target()
  _echo("Duel damage loop ON.")
  if tgt == "" then
    _echo("No target set; will hold until target is available.")
  end
end

function M.alias_loop_on_stopped(ctx)
  M.init()
  ctx = ctx or {}
  local reason = tostring(ctx.reason or "manual")
  M.state.template = M.state.template or {}
  M.state.template.last_disable_reason = reason
  _echo(string.format("Duel damage loop OFF (%s).", reason))
end

function M.alias_loop_on_error(err)
  _echo("Duel damage loop error: " .. tostring(err))
end

function M.alias_loop_waiting_blocks()
  return false
end

function M.alias_loop_clear_waiting()
  if RI and type(RI.clear_waiting) == "function" then
    return RI.clear_waiting(M.state, "magi_dmg")
  end
  return true
end

if Yso.off.core and type(Yso.off.core.register) == "function" then
  pcall(Yso.off.core.register, M.key, M)
end

return M
