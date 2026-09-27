--========================================================--
-- Magi_water_group.lua
--  * Alias-owned Magi water-group route (^gwater$ / magi_water_group).
--  * Instant wields via Yso.send when ids are set; one EQ cast via Yso.emit.
--  * Affs via AK (RC.has_aff / RC.score_aff). No queues or pipe stacks.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.magi = Yso.off.magi or {}

local M = Yso.off.magi.water_group or {}
Yso.off.magi.water_group = M

M.key = "magi_water_group"
M.name = "Magi Water Group"
M.alias_owned = true
M.cfg = M.cfg or { loop_delay = 0.15, echo = true }
M.state = M.state or {}

local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
Yso.off.magi.route_core = Yso.off.magi.route_core or {}
local RC = Yso.off.magi.route_core

local PENDING_SLOTS = {
  "stormhammer",
  "erode",
  "glaciate",
  "hypothermia",
  "dehydrate",
  "freeze",
  "emanation",
  "mudslide",
  "bombard",
  "fulminate",
}

M.route_contract = M.route_contract or {
  id = "magi_water_group",
  interface_version = 1,
  shared_categories = { "defense_break" },
  route_local_categories = { "execute", "water_group" },
  capabilities = {
    uses_eq = true,
    uses_bal = false,
    uses_entity = false,
    supports_burst = true,
    supports_bootstrap = false,
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
  if type(RC.trim) == "function" then return RC.trim(s) end
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _echo(msg)
  if M.cfg.echo ~= true then return end
  if type(cecho) == "function" then
    cecho(string.format("<cadet_blue>[Yso:Magi] <reset>%s\n", tostring(msg)))
  elseif type(echo) == "function" then
    echo(string.format("[Yso:Magi] %s\n", tostring(msg)))
  end
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
  local D = Yso and Yso.magi and Yso.magi.defs
  if type(D) == "table" and type(D.is_magi) == "function" then
    local ok, v = pcall(D.is_magi)
    if ok then return v == true end
  end
  return false
end

local function _target_hp()
  if type(RC.get_target_hp_percent) == "function" then
    local ok, v = pcall(RC.get_target_hp_percent)
    if ok and tonumber(v) then return tonumber(v) end
  end
  return nil
end

local function _target()
  if type(RC.get_target) == "function" then
    local t = _trim(RC.get_target())
    if t ~= "" then return t end
  end
  return _trim(rawget(_G, "target") or "")
end

local function _shielded(tgt)
  tgt = _trim(tgt):lower()
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

local function _cast(spell, tgt, extra)
  extra = _trim(extra)
  if extra ~= "" then
    return "cast " .. spell .. " at " .. tgt .. " " .. extra
  end
  return "cast " .. spell .. " at " .. tgt
end

local function _route_is_active()
  if not _is_magi() then return false end
  if not (Yso and Yso.mode and type(Yso.mode.is_combat) == "function" and Yso.mode.is_combat() == true) then
    return false
  end
  if Yso.mode and type(Yso.mode.route_loop_active) == "function" then
    return Yso.mode.route_loop_active("magi_water_group") == true
  end
  return M.state and M.state.loop_enabled == true
end

local function _select_command(tgt)
  local hp = _target_hp()
  local res = (type(RC.read_resonance) == "function" and RC.read_resonance()) or { air = 0, earth = 0, fire = 0, water = 0 }
  local water = tonumber(res.water) or 0
  local earth = tonumber(res.earth) or 0
  local fire = tonumber(res.fire) or 0
  local air = tonumber(res.air) or 0
  local frozen = RC.has_aff("frozen")
  local hypothermia = RC.has_aff("hypothermia")
  local shivering = RC.has_aff("shivering")
  local nausea = RC.has_aff("nausea")
  local calcified = RC.has_aff("calcifiedtorso")

  if hp ~= nil and hp <= 20 then
    return _cast("stormhammer", tgt), "execute", "hp_stormhammer"
  end
  if _shielded(tgt) then
    return _cast("erode", tgt, "shield"), "defense_break", "shielded"
  end
  if frozen and hypothermia and water == 2 and air == 2 then
    return _cast("glaciate", tgt), "glaciate_burst", "glaciate_ready"
  end
  if frozen and water == 2 and air == 2 and not hypothermia then
    return _cast("hypothermia", tgt), "freeze_setup", "hypothermia_missing"
  end
  if shivering and nausea and not frozen then
    return _cast("dehydrate", tgt), "disrupt_setup", "shiver_nausea"
  end
  if shivering then
    return _cast("freeze", tgt), "freeze_setup", "shivering"
  end
  if water == 0 and fire == 2 and earth <= 1 then
    return _cast("dehydrate", tgt), "disrupt_setup", "water0_fire2"
  end
  if water == 3 and fire == 2 and earth <= 1 then
    return _cast("emanation", tgt, "water"), "water_promotion", "water_major_fire2"
  end
  if calcified and water == 3 and earth == 1 then
    return _cast("dehydrate", tgt), "disrupt_setup", "calcified_earth1"
  end
  if calcified and water == 3 and earth == 0 then
    return _cast("mudslide", tgt), "salve_pressure", "calcified_earth0"
  end
  if water == 3 and earth == 3 then
    return _cast("emanation", tgt, "earth"), "earth_promotion", "water_earth_major"
  end
  if water == 3 and earth == 2 then
    return _cast("bombard", tgt), "salve_pressure", "water_major_earth2"
  end
  if water == 2 and earth == 1 and air == 1 then
    return _cast("mudslide", tgt), "salve_pressure", "water2_earth1_air1"
  end
  if air == 0 and water == 2 then
    return _cast("freeze", tgt), "freeze_setup", "air0_water2"
  end
  if water == 2 and earth == 1 and fire == 1 then
    return _cast("fulminate", tgt), "kelp_pressure", "fulminate"
  end
  if water == 1 and earth == 0 then
    return _cast("mudslide", tgt), "salve_pressure", "water1_earth0"
  end
  return _cast("dehydrate", tgt), "disrupt_setup", "default_dehydrate"
end

local function _send_wields()
  local W = Yso and Yso.magi and Yso.magi.weapons
  if type(W) == "table" and type(W.send_wields) == "function" then
    pcall(W.send_wields)
  end
end

local function _emit_payload(cmd, target, category)
  cmd = _trim(cmd)
  target = _trim(target)
  if cmd == "" then return false, "empty", nil end

  local opts = {
    reason = "magi_water_group:" .. tostring(category or "attack"),
    kind = "offense",
    commit = true,
    route = "magi_water_group",
    target = target,
  }

  if RI and type(RI.emit_route_payload) == "function" then
    return RI.emit_route_payload("magi_water_group", {
      target = target,
      lanes = { eq = cmd },
      meta = {
        route = "magi_water_group",
        main_lane = "eq",
        main_category = tostring(category or ""),
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
  if type(send) == "function" then
    local ok = pcall(send, cmd, false)
    if ok then return true, cmd, payload end
    return false, "send_failed", nil
  end
  return false, "no_send", nil
end

function M.init()
  M.state = M.state or {}
  M.state.loop_delay = tonumber(M.state.loop_delay or M.cfg.loop_delay or 0.15) or 0.15
  M.state.template = M.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  if type(RC.ensure_pending) == "function" then
    RC.ensure_pending(M.state, PENDING_SLOTS)
  end
  if RI and type(RI.ensure_waiting_state) == "function" then
    RI.ensure_waiting_state(M.state, "magi_water_group")
  end
  return true
end

function M.is_enabled()
  return M.state and M.state.enabled == true
end

function M.is_active()
  M.init()
  return _route_is_active()
end

function M.can_run(reason)
  M.init()
  local ctx = type(reason) == "table" and reason or {}
  if not M.is_enabled() then return false, "disabled" end
  if not M.is_active() then return false, "inactive" end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return false, "paused" end
  local tgt = _trim((ctx and ctx.target) or _target())
  if tgt == "" then return false, "no_target" end
  if not _is_magi() then return false, "wrong_class" end
  if type(RC.target_valid) == "function" and not RC.target_valid(tgt) then
    return false, "invalid_target"
  end
  if type(RC.eq_ready) == "function" and not RC.eq_ready() then
    return false, "eq_down"
  end
  return true, tgt
end

function M.attack_function(arg)
  M.init()
  local ctx = type(arg) == "table" and arg or { reason = tostring(arg or "loop") }
  local ok, info = M.can_run(ctx)
  if not ok then return false, info end
  local tgt = info
  local cmd, category, reason = _select_command(tgt)
  M.state.template.last_reason = reason
  M.state.template.last_target = tgt
  if not cmd or cmd == "" then return false, reason or "empty" end

  _send_wields()
  local sent, emit_detail, ack_payload = _emit_payload(cmd, tgt, category)
  if sent ~= true then return false, emit_detail or "emit_failed" end

  if RI and type(RI.mark_waiting) == "function" then
    RI.mark_waiting(M.state, "magi_water_group", ack_payload or { eq = cmd, target = tgt }, {
      cmd = cmd,
      target = tgt,
      main_lane = "eq",
    })
  end
  local has_ack_bus = Yso and Yso.locks and type(Yso.locks.note_payload) == "function"
  local dry_run = (Yso and Yso.net and Yso.net.cfg and Yso.net.cfg.dry_run == true)
  local queue_live = Yso and Yso.queue and type(Yso.queue.commit) == "function"
  if (not has_ack_bus or dry_run or not queue_live) and type(M.on_payload_queued) == "function" then
    pcall(M.on_payload_queued, ack_payload or { eq = cmd, target = tgt })
  end

  M.state.last_cmd = cmd
  M.state.last_category = category
  M.state.last_target = tgt
  return true, cmd
end

function M.on_payload_queued(payload)
  M.init()
  payload = type(payload) == "table" and payload or {}
  local lanes = type(payload.lanes) == "table" and payload.lanes or payload
  local cmd = _trim(lanes.eq or payload.eq or payload.cmd)
  local tgt = _trim(payload.target or _target())
  if cmd ~= "" and type(RC.mark_pending) == "function" then
    local slot = cmd:match("^cast%s+(%S+)")
    if slot then RC.mark_pending(M.state, slot, tgt, 1.0) end
  end
  if RI and type(RI.clear_waiting_on_ack) == "function" then
    RI.clear_waiting_on_ack(M.state, "magi_water_group", payload, { require_route = false })
  end
  return true
end

function M.on_payload_sent(payload)
  return M.on_payload_queued(payload)
end

function M.on_send_result(payload, ctx)
  payload = type(payload) == "table" and payload or {}
  local lanes = type(payload.lanes) == "table" and payload.lanes or payload
  M.state.last_fired_cmd = _trim(lanes.eq or payload.eq or payload.cmd)
  return true
end

M.alias_loop_stop_details = M.alias_loop_stop_details or {
  inactive = true,
  disabled = true,
  no_target = true,
  invalid_target = true,
  wrong_class = true,
}

function M.alias_loop_prepare_start(ctx)
  M.init()
  return ctx or {}
end

function M.alias_loop_on_started(ctx)
  M.init()
  if type(RC.clear_pending_all) == "function" then
    RC.clear_pending_all(M.state, PENDING_SLOTS)
  end
  _echo("Water group loop ON.")
  local tgt = _target()
  if tgt == "" then
    _echo("No target yet; holding.")
  end
end

function M.alias_loop_on_stopped(ctx)
  M.init()
  ctx = ctx or {}
  local reason = tostring(ctx.reason or "manual")
  M.state.template.last_disable_reason = reason
  if ctx.silent ~= true then
    _echo(string.format("Water group loop OFF (%s).", reason))
  end
end

function M.alias_loop_waiting_blocks()
  return false
end

function M.alias_loop_clear_waiting()
  if RI and type(RI.clear_waiting) == "function" then
    return RI.clear_waiting(M.state, "magi_water_group")
  end
  return true
end

function M.alias_loop_on_error(err)
  _echo("Water group loop error: " .. tostring(err))
end

function M.on_exit(ctx)
  if Yso and Yso.mode and type(Yso.mode.stop_route_loop) == "function" then
    Yso.mode.stop_route_loop("magi_water_group", "exit", true)
  end
  return true
end

if Yso.off.core and type(Yso.off.core.register) == "function" then
  pcall(Yso.off.core.register, M.key, M)
end

return M
