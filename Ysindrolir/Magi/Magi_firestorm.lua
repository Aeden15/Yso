--========================================================--
-- Magi_firestorm.lua
--  * Alias-owned Magi firestorm route (^fstorm$ / magi_firestorm).
--  * One EQ cast per tick via Yso.emit. No queues or pipe stacks.
--  * AK resonance: Magma -> Bombard/Fulminate -> Firestorm -> Conflagrate.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.magi = Yso.off.magi or {}

local M = Yso.off.magi.firestorm or {}
Yso.off.magi.firestorm = M

M.key = "magi_firestorm"
M.name = "Magi Firestorm"
M.alias_owned = true
M.cfg = M.cfg or { loop_delay = 0.15, echo = true }
M.state = M.state or {}

local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
Yso.off.magi.route_core = Yso.off.magi.route_core or {}
local RC = Yso.off.magi.route_core

-- Magma's Scalded effect lasts 20 seconds. Keep the send window target-local
-- while AK catches up; Earth setup must not bypass an existing Scalded effect.
local MAGMA_DURATION = 20

local PENDING_SLOTS = {
  "pebble",
  "stormhammer",
  "destroy",
  "erode",
  "conflagrate",
  "magma",
  "mudslide",
  "shalestorm",
  "dehydrate",
  "emanation",
  "firelash",
  "fulminate",
  "firestorm",
  "bombard",
}

M.route_contract = M.route_contract or {
  id = "magi_firestorm",
  interface_version = 1,
  shared_categories = { "defense_break" },
  route_local_categories = { "execute", "firestorm" },
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
    return Yso.mode.route_loop_active("magi_firestorm") == true
  end
  return M.state and M.state.loop_enabled == true
end

local function _room_key()
  local g = rawget(_G, "gmcp")
  local info = g and g.Room and g.Room.Info or {}
  return tostring(info.num or info.id or "unknown")
end

local function _select_command(tgt)
  local hp = _target_hp()
  local res = RC.read_resonance()
  local air, earth, fire = tonumber(res.air) or 0, tonumber(res.earth) or 0, tonumber(res.fire) or 0
  local water = tonumber(res.water) or 0
  local conflag = RC.has_aff("conflagrate") or RC.has_aff("conflagration")
  local aflame_ready = RC.score_aff("aflame") >= 200
  local scalded = RC.has_aff("scalded") or RC.pending_active(M.state, "magma", tgt)
  local threshold = 3 -- Firestorm requires major resonance in both Air and Fire.
  local room_sent = M.state.firestorm_rooms and M.state.firestorm_rooms[_room_key()] == true

  if _shielded(tgt) then
    return _cast("erode", tgt, "shield"), "defense_break", "shielded"
  end
  local special, reason, hold = RC.special_action(tgt)
  if special or hold then return special, "special", reason end
  if hp ~= nil and hp < 25 then
    return _cast("stormhammer", tgt), "execute", "hp_stormhammer"
  end

  if RC.score_aff("scalded") < 100 and earth == 0 then
    return _cast("pebble", tgt), "earth_setup", "scalded_missing_earth0"
  end

  if not scalded then
    return _cast("magma", tgt), "fire_build", "scalded_missing"
  end

  -- Bombard builds Air/Earth; Fulminate builds Air/Fire. Read the actual
  -- resonance triggers each tick rather than incrementing on a send.
  if not room_sent then
    if air < threshold and earth < 2 then
      return _cast("bombard", tgt), "resonance_build", "air_earth_build"
    end
    if air >= threshold and fire < threshold and water < 2 then
      return _cast("dehydrate", tgt), "resonance_build", "fire_water_build"
    end
    if air >= threshold and fire < threshold then
      return _cast("firelash", tgt), "resonance_build", "fire_only_build"
    end
    if air < threshold or fire < threshold then
      return _cast("fulminate", tgt), "resonance_build", "air_fire_build"
    end
    -- Firestorm is a room spell: no 'at <target>' suffix.
    return "cast firestorm", "firestorm", "firestorm_ready"
  end

  if not conflag and aflame_ready and fire >= 2 then
    return _cast("conflagrate", tgt), "fire_payoff", "conflagrate_ready"
  end
  if not conflag and fire >= 3 then
    return _cast("emanation", tgt, "fire"), "fire_promotion", "ablaze_setup"
  end
  if conflag and earth >= 3 then
    return _cast("emanation", tgt, "earth"), "earth_promotion", "conflag_emanate_earth"
  end
  if fire < threshold and water < 2 then
    return _cast("dehydrate", tgt), "fire_build", "fire_water_pressure"
  end
  if air >= threshold and fire < threshold then
    return _cast("firelash", tgt), "fire_build", "fire_only_pressure"
  end
  return _cast("fulminate", tgt), "fire_build", "fulminate_pressure"
end

local function _emit_payload(cmd, target, category)
  cmd = _trim(cmd)
  target = _trim(target)
  if cmd == "" then return false, "empty", nil end

  local opts = {
    reason = "magi_firestorm:" .. tostring(category or "attack"),
    kind = "offense",
    commit = true,
    route = "magi_firestorm",
    target = target,
  }

  if RI and type(RI.emit_route_payload) == "function" then
    return RI.emit_route_payload("magi_firestorm", {
      target = target,
      lanes = { eq = cmd },
      meta = {
        route = "magi_firestorm",
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
    RI.ensure_waiting_state(M.state, "magi_firestorm")
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
  if type(RC.entourage_sync) == "function" then
    RC.entourage_sync(M, ctx.target or _target(), _is_magi(), ctx.preview)
  end
  local ok, info = M.can_run(ctx)
  if not ok then return false, info end
  local tgt = info
  local cmd, category, reason = _select_command(tgt)
  M.state.template.last_reason = reason
  M.state.template.last_target = tgt
  if not cmd or cmd == "" then return false, reason or "empty" end

  if cmd == _cast("pebble", tgt) and RC.pending_active(M.state, "pebble", tgt) then
    M.state.template.last_reason = "pebble_pending"
    return false, "pebble_pending"
  end

  if ctx.preview then return {target=tgt,lanes={eq=cmd},meta={main_category=category,main_reason=reason}} end

  local sent, emit_detail, ack_payload = _emit_payload(cmd, tgt, category)
  if sent ~= true then return false, emit_detail or "emit_failed" end
  -- Cover the submission-to-ack gap without predicting resonance or limb damage.
  if cmd == _cast("pebble", tgt) then RC.mark_pending(M.state, "pebble", tgt, 1.0) end
  RC.note_special_queued(cmd, tgt)

  if RI and type(RI.mark_waiting) == "function" then
    RI.mark_waiting(M.state, "magi_firestorm", ack_payload or { eq = cmd, target = tgt }, {
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
  local cmd = _trim(lanes.eq or payload.eq)
  if cmd == "" and payload.lanes == nil and not (payload.bal or payload.free
      or payload.class or payload.ent or payload.entity) then
    cmd = _trim(payload.cmd)
  end
  local tgt = _trim(payload.target or _target())
  -- A generic server rejection belongs only to the outstanding EQ action.
  -- Shared EQ history also detects later actions sent by another route,
  -- even when subsequent acknowledgements spend only other lanes.
  if cmd ~= "" then M.state.firestorm_dispatch = nil end
  if cmd ~= "" and type(RC.mark_pending) == "function" then
    local slot = cmd:match("^cast%s+(%S+)")
    if slot then RC.mark_pending(M.state, slot, tgt, slot == "magma" and MAGMA_DURATION or 1.0) end
  end
  if cmd == "cast firestorm" then
    -- This records a dispatched attempt, not a confirmed active room effect.
    -- One attempt per room per loop activation prevents a room-spell resend
    -- on every EQ regain, including when the target changes.
    M.state.firestorm_rooms = M.state.firestorm_rooms or {}
    M.state.firestorm_rooms[_room_key()] = true
    M.state.firestorm_dispatch = {
      payload = payload, room = _room_key(),
      eq_ack = Yso._last_eq_ack_payload or (Yso.queue and Yso.queue._last_ack_payload),
    }
  end
  if RI and type(RI.clear_waiting_on_ack) == "function" then
    RI.clear_waiting_on_ack(M.state, "magi_firestorm", payload, { require_route = false })
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
  local dispatch = M.state.firestorm_dispatch
  if type(ctx) == "table" and ctx.success == false and dispatch
      and dispatch.payload == payload and M.state.last_fired_cmd == "cast firestorm" then
    M.state.firestorm_rooms[dispatch.room] = nil
    M.state.firestorm_dispatch = nil
    if type(RC.clear_pending) == "function" then RC.clear_pending(M.state, "firestorm") end
  end
  return true
end

function M.on_resonance_failure(required, element)
  local dispatch = M.state.firestorm_dispatch
  if not dispatch or required ~= 3 or (element ~= "air" and element ~= "fire") then return false end
  local latest = Yso._last_eq_ack_payload or (Yso.queue and Yso.queue._last_ack_payload)
  if latest and latest ~= dispatch.eq_ack and latest ~= dispatch.payload then
    local lanes = type(latest.lanes) == "table" and latest.lanes or latest
    if _trim(lanes.eq or latest.eq) ~= "" then
      M.state.firestorm_dispatch = nil
      return false
    end
  end
  return M.on_send_result(dispatch.payload, { success = false })
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
  if type(RC.entourage_sync) == "function" then
    RC.entourage_sync(M, _target(), _is_magi())
  end
  M.state.firestorm_rooms = {}
  M.state.firestorm_dispatch = nil
  if type(RC.clear_pending_all) == "function" then
    RC.clear_pending_all(M.state, PENDING_SLOTS)
  end
  _echo("Firestorm loop ON.")
  local tgt = _target()
  if tgt == "" then
    _echo("No target yet; holding.")
  end
end

-- A confirmed end/failure trigger can reopen the room step without toggling.
function M.on_firestorm_ended()
  M.state.firestorm_rooms = M.state.firestorm_rooms or {}
  M.state.firestorm_rooms[_room_key()] = nil
  return true
end

function M.alias_loop_on_stopped(ctx)
  M.init()
  if type(RC.entourage_passive) == "function" then RC.entourage_passive(M) end
  ctx = ctx or {}
  local reason = tostring(ctx.reason or "manual")
  M.state.template.last_disable_reason = reason
  if ctx.silent ~= true then
    _echo(string.format("Firestorm loop OFF (%s).", reason))
  end
end

function M.alias_loop_waiting_blocks()
  return false
end

function M.alias_loop_clear_waiting()
  if RI and type(RI.clear_waiting) == "function" then
    return RI.clear_waiting(M.state, "magi_firestorm")
  end
  return true
end

function M.alias_loop_on_error(err)
  _echo("Firestorm loop error: " .. tostring(err))
end

function M.on_exit(ctx)
  if type(RC.entourage_passive) == "function" then RC.entourage_passive(M) end
  if Yso and Yso.mode and type(Yso.mode.stop_route_loop) == "function" then
    Yso.mode.stop_route_loop("magi_firestorm", "exit", true)
  end
  return true
end

if Yso.off.core and type(Yso.off.core.register) == "function" then
  pcall(Yso.off.core.register, M.key, M)
end

return M
