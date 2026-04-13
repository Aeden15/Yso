--Group damage offense logic
--========================================================--
-- group_damage.lua  (Achaea / Occultist / Yso)
--  * Group damage automation (party / team damage):
--      Track: healthleech, sensitivity, clumsiness (core) + slickness (optional fourth)
--      Setup: build/refresh missing core pieces using EQ instills + entity pressure
--      Burst: paired WARP + FIRELORD(healthleech) when healthleech is tracked and both lanes are ready
--
--  * Uses Yso.emit() lane table => lane-table payload transport (default separator: &&)
--  * Payload modes (GLOBAL, via Yso.cfg.payload_mode):
--      - "as_available" semantics are enforced by Yso.queue.commit() lane isolation (wake_lane)
--
--  Requirement (freestyle update):
--    - Freestyle combined payloads are allowed, with one action per lane.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

-- Canonical group damage driver lives here:
Yso.off.oc.group_damage = Yso.off.oc.group_damage or {}
local GD = Yso.off.oc.group_damage
--========================================================--
-- Occultist ENTITY pool (defaulted)
--  * Shared across Occultist offense routes (duel / party / utilities).
--  * The pool is intended to be stable; routes may READ from it, not redefine it.
--========================================================--
Yso.off.oc.entity_pool = Yso.off.oc.entity_pool or {
  rotation = { "worm", "storm", "bubonis", "slime", "sycophant", "bloodleech", "hound", "humbug", "chimera", "firelord" },
}

-- Compatibility aliases (callers may refer to these):
Yso.off.oc.dmg = GD
Yso.off.oc.gd_simple = GD
GD.alias_owned = true

GD.route_contract = GD.route_contract or {
  id = "group_damage",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "bootstrap",
    "required_core_refresh",
    "required_core_application",
    "fallback_support",
    "reserved_burst",
    "passive_pressure_only",
  },
  capabilities = {
    uses_eq = true,
    uses_bal = true,
    uses_entity = true,
    supports_burst = true,
    supports_bootstrap = true,
    needs_target = true,
    uses_primebond_scoring = true,
    shares_defense_break = true,
    shares_anti_tumble = true,
  },
  override_policy = {
    mode = "narrow_global_only",
    allowed = {
      reserved_burst = true,
      target_invalid = true,
      target_slain = true,
      route_off = true,
      pause = true,
      manual_suppression = true,
      target_swap_bootstrap = true,
      defense_break = true,
      anti_tumble = true,
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
    RI.ensure_hooks(GD, GD.route_contract)
  end
end

local function _ER()
  return Yso and Yso.off and Yso.off.oc and Yso.off.oc.entity_registry or nil
end

local function _offense_state()
  return Yso and Yso.off and Yso.off.state or nil
end

GD.cfg = GD.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,

  -- No entourage opener in Occultist group damage.
  opener_enable = false,
  opener_cmd = nil,

  -- Route-off cleanup (all loyals, every time), gated by a ready wake.
  loyals_on_cmd = "order loyals kill %s",
  off_passive_cmd = "order loyals passive",

  -- Entity pool used by this route when an entity can contribute required/follow-up value.
  entity_rotation = { "worm", "storm", "bubonis", "slime", "sycophant", "bloodleech", "hound", "humbug", "chimera", "firelord" },

  -- Entity duration / refresh policy.
  prefer_storm_clumsiness = true,
  prefer_worm_for_healthleech = true,
  prefer_sycophant_rixil = true,
  avoid_overlap = true,
  worm_duration_s = 20,
  worm_refresh_lead_s = 1.0,
  sycophant_duration_s = 30,
  sycophant_refresh_lead_s = 1.0,

  -- Commit semantics: freestyle combined payload, one action per lane.
  freestyle_isolate_lanes = false,

  -- minimum send throttles (milliseconds)
  dupe_window_ms = 120,
}

-- Lust/Empress reactive rescue automation (anti-tumble + empress pull)
-- CANCELLED by default per project decision (2026-03-01).
GD.cfg.rescue_lust_empress = false  -- CANCELLED per project decision (2026-03-01).


-- Entity pool policy: default + lock to the shared Occultist pool unless explicitly unlocked.
if GD.cfg.lock_entity_pool == nil then GD.cfg.lock_entity_pool = true end
if GD.cfg.lock_entity_pool == true then
  GD.cfg.entity_rotation = (Yso.off.oc.entity_pool and Yso.off.oc.entity_pool.rotation) or GD.cfg.entity_rotation
end

GD.state = GD.state or {
  enabled = false,
  loop_enabled = false,
  timer_id = nil,
  busy = false,
  waiting = { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" },
  in_flight = { fingerprint = "", target = "", route = "group_damage", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" },
  debug = { last_no_send_reason = "", last_retry_reason = "", entity_no_send_reasons = {}, last_shield_target = "" },
  loop_delay = tonumber(GD.cfg.loop_delay or 0.15) or 0.15,
  opener_sent_for = "",
  rr_idx = 0,
  stop_pending = false,
  last_room_id = "",
  last_target = "",
  entity_target = "",
  worm = { target = "", until_t = 0, proc_count = 0, proc_window_until = 0 },
  syc = { target = "", until_t = 0 },
}

-- Anti-tumble / Empress rescue state (Lust+Empress recovery)
GD.state.tumble = GD.state.tumble or { target = "", dir = "", at = 0, until_t = 0, fired = false }
GD.state.empress = GD.state.empress or { pending = false, target = "", dir = "", started_at = 0, last_try = 0, fail_until = 0 }
GD.state.justice_once = GD.state.justice_once or {}
local function _trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function _lc(s) return _trim(s):lower() end
local function _tkey(s) return _lc(s) end

local function _companions()
  local C = Yso and Yso.occ and Yso.occ.companions or nil
  return type(C) == "table" and C or nil
end

local function _now()
  -- Use canonical clock (seconds, handles getEpoch ms) to keep worm timers sane.
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok,v = pcall(Yso.util.now)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  if type(getEpoch) == "function" then
    local ok,v = pcall(getEpoch)
    v = ok and tonumber(v) or nil
    if v then
      if v > 1e12 then v = v / 1000 end
      return v
    end
  end
  return os.time()
end

-- Worm (Domination: COMMAND WORM) behaves like a ~20s DoT.
-- We gate re-commanding per-target using a simple timer so we don't spam entity balance.
--========================================================--
-- Entity effect duration gates (route-local)
--  * worm:     20s infestation window (fallback: 2nd chew-proc line)
--  * sycophant:30s rixil window
--  * Entities retarget to the current target; duration gates reset on target change.
--========================================================--

local function _worm_reset()
  GD.state.worm = GD.state.worm or { target = "", until_t = 0, proc_count = 0, proc_window_until = 0 }
  GD.state.worm.target, GD.state.worm.until_t, GD.state.worm.proc_count, GD.state.worm.proc_window_until = "", 0, 0, 0
end

local function _worm_is_active(tgt)
  local w = GD.state.worm or {}
  return _tkey(tgt) ~= "" and _tkey(tgt) == _tkey(w.target) and _now() < (w.until_t or 0)
end

local function _worm_mark_used(tgt, dur)
  local w = GD.state.worm or {}
  GD.state.worm = w
  w.target = tgt
  w.until_t = _now() + (dur or GD.cfg.worm_duration_s)
  w.proc_count = 0
  w.proc_window_until = _now() + math.max(5, (dur or GD.cfg.worm_duration_s) + 15)
end

function GD.note_worm_sent(tgt)
  if _tkey(tgt) == "" then return end
  local ER = _ER()
  if ER and type(ER.note_sent) == "function" then pcall(ER.note_sent, "worm", tgt, { source = "gd" }) end
end

local function _worm_should_refresh(tgt)
  if _tkey(tgt) == "" then return false end
  local ER = _ER()
  if ER and type(ER.worm_should_refresh) == "function" then
    local ok, v = pcall(ER.worm_should_refresh, tgt)
    if ok then return v == true end
  end
  local w = GD.state.worm or {}
  if _tkey(w.target) ~= _tkey(tgt) then return true end
  return _now() >= (w.until_t or 0)
end

function GD.note_worm_proc(tgt)
  if _tkey(tgt) == "" then return end
  local ER = _ER()
  if ER and type(ER.note_worm_proc) == "function" then pcall(ER.note_worm_proc, tgt) end
end

local function _syc_reset()
  GD.state.syc = GD.state.syc or { target = "", until_t = 0 }
  GD.state.syc.target, GD.state.syc.until_t = "", 0
end

local function _syc_is_active(tgt)
  local s = GD.state.syc or {}
  return _tkey(tgt) ~= "" and _tkey(tgt) == _tkey(s.target) and _now() < (s.until_t or 0)
end

local function _syc_mark_used(tgt, dur)
  local s = GD.state.syc or {}
  GD.state.syc = s
  s.target = tgt
  s.until_t = _now() + (dur or GD.cfg.sycophant_duration_s)
end

function GD.note_syc_sent(tgt)
  if _tkey(tgt) == "" then return end
  local ER = _ER()
  if ER and type(ER.note_sent) == "function" then pcall(ER.note_sent, "sycophant", tgt, { source = "gd" }) end
end

local function _syc_should_refresh(tgt)
  if _tkey(tgt) == "" then return false end
  local ER = _ER()
  if ER and type(ER.syc_should_refresh) == "function" then
    local ok, v = pcall(ER.syc_should_refresh, tgt)
    if ok then return v == true end
  end
  local s = GD.state.syc or {}
  return _now() >= (s.until_t or 0)
end

-- Reset duration gates on target change.
local function _reset_entity_gates_on_target_change(tgt)
  local last = GD.state.entity_target or ""
  if _tkey(last) ~= _tkey(tgt) then
    GD.state.entity_target = tgt
    GD.state.rr_idx = 0
    GD.state.opener_sent_for = ""
    local ER = _ER()
    if ER and type(ER.target_swap) == "function" then pcall(ER.target_swap, tgt) end
  end
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

local function _set_loyals_hostile(v)
  local C = _companions()
  if C and type(C.note_order_sent) == "function" then
    if v == true then
      local tgt = _trim(GD.state and GD.state.last_target or "")
      if tgt == "" then
        tgt = _trim(rawget(_G, "target") or "")
      end
      local ok, handled = pcall(C.note_order_sent, ("order loyals kill %s"):format(tgt), tgt)
      if ok and handled == true then return end
    else
      local ok, handled = pcall(C.note_order_sent, "order loyals passive", _trim(GD.state and GD.state.last_target or ""))
      if ok and handled == true then return end
    end
  end

  if not Yso.state then return end
  if type(Yso.state.loyals_hostile) == "function" then
    pcall(Yso.state.loyals_hostile, v)
  else
    Yso.state.loyals_hostile = (v == true)
  end
end

local function _vitals()
  return (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
end

local function _eq_ready()
  if Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then return v == true end
  end
  local v = _vitals()
  local eq = v.eq or v.equilibrium
  return eq == true or tostring(eq or "") == "1"
end

local function _bal_ready()
  if Yso.state and type(Yso.state.bal_ready) == "function" then
    local ok, v = pcall(Yso.state.bal_ready)
    if ok then return v == true end
  end
  local v = _vitals()
  local bal = v.bal or v.balance
  return bal == true or tostring(bal or "") == "1"
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
    if type(ak.Target) == "string" and _trim(ak.Target) ~= "" then return _trim(ak.Target) end
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

local function _worm_active(tgt)
  return not _worm_should_refresh(tgt)
end

local function _worm_mark(tgt, dur)
  local ER = _ER()
  if ER and type(ER.note_sent) == "function" then return pcall(ER.note_sent, "worm", tgt, { source = "mark", dur = dur }) end
  return _worm_mark_used(tgt, dur)
end

local function _syc_mark(tgt, dur)
  local ER = _ER()
  if ER and type(ER.note_sent) == "function" then return pcall(ER.note_sent, "sycophant", tgt, { source = "mark", dur = dur }) end
  return _syc_mark_used(tgt, dur)
end

local function _ent_ready()
  if Yso.state and type(Yso.state.ent_ready) == "function" then
    local ok,v = pcall(Yso.state.ent_ready); if ok then return v==true end
  end
  -- fallback: allow, but lane throttling in Yso.emit / locks should backoff if the server rejects
  return true
end

local function _target_matches_active(tgt)
  tgt = _trim(tgt)
  return tgt ~= "" and _lc(tgt) == _lc(_target())
end

local function _affstrack_score_is_fresh(A)
  if type(A) ~= "table" then return false end
  local ts = tonumber(A.score_updated_at or A.updated_at or A.last_updated_at or A.last_update_at or A.ts)
  if not ts then return true end
  if ts > 1e12 then ts = ts / 1000 end
  local max_age = tonumber(GD.cfg.aff_score_max_age_s or 1.25) or 1.25
  return (_now() - ts) <= max_age
end

-- Prefer AK score exports for the active designated target only.
-- For non-target observations, fall back to target-scoped tracking.
local function _aff_score(tgt, aff)
  aff = _lc(aff)
  tgt = _trim(tgt)
  if aff == "" then return 0 end

  if _target_matches_active(tgt) then
    if Yso.oc and Yso.oc.ak and type(Yso.oc.ak.get_aff_score) == "function" then
      local ok, v = pcall(Yso.oc.ak.get_aff_score, aff)
      if ok and tonumber(v) then return tonumber(v) end
    end
    if type(affstrack) == "table" and type(affstrack.score) == "table" and _affstrack_score_is_fresh(affstrack) then
      return tonumber(affstrack.score[aff] or 0) or 0
    end
  end

  if tgt ~= "" and Yso.tgt and type(Yso.tgt.has_aff) == "function" then
    local ok, v = pcall(Yso.tgt.has_aff, tgt, aff)
    if ok and v == true then return 100 end
  end
  return 0
end

local function _has_aff(tgt, aff) return (tonumber(_aff_score(tgt, aff)) or 0) >= 100 end

local function _ak_speed_is_down()
  local A = rawget(_G, "ak")
  return type(A) == "table" and type(A.defs) == "table" and A.defs.speed == false
end

local function _prone_is_forced(tgt)
  return _aff_score(tgt, "prone") >= 100
end

local function _random_crone_arm(tgt)
  local salt = math.floor((_now() * 1000) + (#_trim(tgt) * 17))
  return ((salt % 2) == 0) and "left arm" or "right arm"
end

local JUSTICE_CONVERSION_AFFS = {
  "paralysis", "sensitivity", "healthleech",
  "haemophilia", "weariness", "asthma", "clumsiness",
}

local function _justice_conversion_count(tgt)
  local n = 0
  for i = 1, #JUSTICE_CONVERSION_AFFS do
    if _aff_score(tgt, JUSTICE_CONVERSION_AFFS[i]) >= 100 then
      n = n + 1
    end
  end
  return n
end

local function _justice_already_sent(tgt)
  local k = _lc(tgt)
  return k ~= "" and GD.state and GD.state.justice_once and GD.state.justice_once[k] == true
end

local function _mark_justice_sent(tgt)
  local k = _lc(tgt)
  if k == "" then return end
  GD.state.justice_once = GD.state.justice_once or {}
  GD.state.justice_once[k] = true
end

local function _echo(msg)
  if not GD.cfg.echo then return end
  local line = string.format("<orange>[Yso:Occultist] <reset>%s", tostring(msg))
  if Yso and Yso.util and type(Yso.util.cecho_line) == "function" then
    Yso.util.cecho_line(line)
  elseif type(cecho) == "function" then
    cecho(line .. string.char(10))
  end
end

local function _command_sep()
  local sep = _trim((Yso and (Yso.sep or (Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep)))) or "&&")
  if sep == "" then sep = "&&" end
  return sep
end

local function _each_sep_part(text, sep, fn)
  text = tostring(text or "")
  sep = tostring(sep or "&&")
  if text == "" then return end
  if sep == "" then
    fn(text)
    return
  end
  local i = 1
  while true do
    local s, e = text:find(sep, i, true)
    if not s then
      fn(text:sub(i))
      break
    end
    fn(text:sub(i, s - 1))
    i = e + 1
  end
end

local function _echo_toggle(msg)
  if not GD.cfg.echo then return end
  local line = string.format("<orange>[Yso:Occultist] <HotPink>%s<reset>", tostring(msg))
  if Yso and Yso.util and type(Yso.util.cecho_line) == "function" then
    Yso.util.cecho_line(line)
  elseif type(cecho) == "function" then
    cecho(line .. string.char(10))
  end
end

local _tarot_entity_payload
local _payload_line

local function _emit_lanes(payload, reason)
  local lanes = type(payload) == "table" and payload.lanes or payload
  if type(lanes) ~= "table" then return false, "invalid_payload" end
  local emit_payload = {
    free = lanes.free or lanes.pre,
    eq = lanes.eq,
    bal = lanes.bal,
    class = lanes.class or lanes.ent or lanes.entity,
    target = _trim(type(payload) == "table" and payload.target or ""),
  }
  if type(Yso.emit) == "function" then
    local ok = Yso.emit(emit_payload, {
      reason = reason or "group_damage:emit",
      kind = "offense",
      commit = true,
      target = emit_payload.target,
    }) == true
    if not ok then return false, "emit_failed" end
    return true, _payload_line({ target = emit_payload.target, lanes = emit_payload })
  end
  local Q = Yso and Yso.queue or nil
  if Q and type(Q.emit) == "function" then
    local ok, res = pcall(Q.emit, emit_payload, {
      reason = reason or "group_damage:emit",
      kind = "offense",
      commit = true,
      target = emit_payload.target,
    })
    if not ok then return false, res end
    if res ~= true then return false, "queue_emit_failed" end
    return true, _payload_line({ target = emit_payload.target, lanes = emit_payload })
  end
  return false, "queue_emit_unavailable"
end

local function _set_debug_field(key, value)
  GD.state.debug = GD.state.debug or { last_no_send_reason = "", last_retry_reason = "", entity_no_send_reasons = {}, last_shield_target = "" }
  GD.state.debug[key] = value
  return value
end

local function _note_no_send_reason(reason)
  return _set_debug_field("last_no_send_reason", _trim(reason))
end

local function _note_retry_reason(reason)
  return _set_debug_field("last_retry_reason", _trim(reason))
end

local function _reset_entity_no_send_reasons()
  GD.state.debug = GD.state.debug or {}
  GD.state.debug.entity_no_send_reasons = {}
end

local function _note_entity_no_send(reason)
  reason = _trim(reason)
  if reason == "" then return end
  GD.state.debug = GD.state.debug or {}
  local rows = GD.state.debug.entity_no_send_reasons
  if type(rows) ~= "table" then
    rows = {}
    GD.state.debug.entity_no_send_reasons = rows
  end
  for i = 1, #rows do
    if rows[i] == reason then return end
  end
  rows[#rows + 1] = reason
end

local function _locks_class_reason()
  local L = Yso and Yso.locks or nil
  local lane = L and L._lane and L._lane.class or nil
  if type(lane) ~= "table" then return nil end
  local now = _now()
  if tonumber(lane.pending_until or 0) > now then return "blocked_by_pending" end
  if tonumber(lane.backoff_until or 0) > now then return "blocked_by_backoff" end
  return nil
end

local function _waiting_lanes_from_payload(payload)
  local lanes, seen = {}, {}
  local lane_tbl = type(payload) == "table" and payload.lanes or payload

  local function add(name, cmd)
    name = _lc(name)
    if name == "entity" then name = "class" end
    if name == "" or name == "free" or seen[name] then return end
    if _trim(cmd) == "" then return end
    seen[name] = true
    lanes[#lanes + 1] = name
  end

  if type(lane_tbl) == "table" then
    add("eq", lane_tbl.eq)
    add("bal", lane_tbl.bal)
    add("class", lane_tbl.class or lane_tbl.ent or lane_tbl.entity)
  end
  if #lanes == 0 and type(payload) == "table" and type(payload.meta) == "table" then
    add(payload.meta.main_lane, "__fallback__")
  end

  return lanes
end

local function _lane_ready(lane)
  lane = _lc(lane)
  if lane == "eq" then return _eq_ready() end
  if lane == "bal" then return _bal_ready() end
  if lane == "entity" or lane == "class" then return _ent_ready() end
  return true
end

local function _action_fingerprint(payload)
  if type(payload) ~= "table" then return "" end
  local lanes = payload.lanes or payload
  if type(lanes) ~= "table" then return "" end
  local eq = _trim(lanes.eq)
  local entity = _trim(lanes.entity or lanes.class or lanes.ent)
  local bal = _trim(lanes.bal)
  local free = _trim(lanes.free)
  return table.concat({
    "group_damage",
    _lc(payload.target or ""),
    eq,
    entity,
    bal,
    free,
  }, "|")
end

local function _set_loop_enabled(on)
  local enabled = (on == true)
  GD.state.enabled = enabled
  GD.state.loop_enabled = enabled
  GD.loop_enabled = enabled
  GD.cfg.enabled = enabled
  GD.state.loop_delay = tonumber(GD.state.loop_delay or GD.cfg.loop_delay or 0.15) or 0.15
  GD.state.waiting = GD.state.waiting or { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 }
  GD.state.last_attack = GD.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" }
  GD.state.in_flight = GD.state.in_flight or { fingerprint = "", target = "", route = "group_damage", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" }
  GD.state.debug = GD.state.debug or { last_no_send_reason = "", last_retry_reason = "", entity_no_send_reasons = {}, last_shield_target = "" }
  return enabled
end

local function _clear_waiting()
  GD.state.waiting = GD.state.waiting or {}
  GD.state.waiting.queue = nil
  GD.state.waiting.main_lane = nil
  GD.state.waiting.lanes = nil
  GD.state.waiting.fingerprint = ""
  GD.state.waiting.reason = ""
  GD.state.waiting.at = 0
  GD.state.in_flight = GD.state.in_flight or {}
  GD.state.in_flight.resolved_at = _now()
  GD.state.in_flight.fingerprint = ""
  GD.state.in_flight.target = ""
  GD.state.in_flight.lanes = nil
  GD.state.in_flight.eq = ""
  GD.state.in_flight.entity = ""
  GD.state.in_flight.reason = ""
end

local function _remember_attack(cmd, payload)
  local meta = type(payload) == "table" and (payload.meta or {}) or {}
  local main_lane = _lc(meta.main_lane or "")
  local lanes = _waiting_lanes_from_payload(payload)
  local fingerprint = _action_fingerprint(payload)
  local wait_reason = "waiting_outcome"
  if #lanes == 1 then
    if lanes[1] == "eq" then
      wait_reason = "waiting_eq"
    elseif lanes[1] == "class" then
      wait_reason = "waiting_ent"
    end
  end
  GD.state.last_attack = GD.state.last_attack or {}
  GD.state.last_attack.cmd = _trim(cmd)
  GD.state.last_attack.at = _now()
  GD.state.last_attack.target = _trim(type(payload) == "table" and payload.target or "")
  GD.state.last_attack.main_lane = main_lane
  GD.state.last_attack.lanes = lanes
  GD.state.last_attack.fingerprint = fingerprint
  GD.state.waiting = GD.state.waiting or {}
  GD.state.waiting.queue = GD.state.last_attack.cmd
  GD.state.waiting.main_lane = main_lane
  GD.state.waiting.lanes = lanes
  GD.state.waiting.fingerprint = fingerprint
  GD.state.waiting.reason = wait_reason
  GD.state.waiting.at = GD.state.last_attack.at
  GD.state.in_flight = GD.state.in_flight or {}
  GD.state.in_flight.fingerprint = fingerprint
  GD.state.in_flight.target = GD.state.last_attack.target
  GD.state.in_flight.route = "group_damage"
  GD.state.in_flight.at = GD.state.last_attack.at
  GD.state.in_flight.lanes = lanes
  GD.state.in_flight.eq = _trim(type(payload) == "table" and payload.lanes and payload.lanes.eq or "")
  GD.state.in_flight.entity = _trim(type(payload) == "table" and payload.lanes and (payload.lanes.entity or payload.lanes.class) or "")
  GD.state.in_flight.reason = wait_reason
end

local function _waiting_blocks_tick()
  -- Keep offense loop reevaluating continuously; queued ownership handles replacement.
  -- We keep wait state for explain/debug, but do not hard-block route ticks.
  return false
end

local function _same_attack_is_hot(cmd)
  cmd = _trim(cmd)
  if cmd == "" then return false end
  local last = GD.state.last_attack or {}
  if _trim(last.cmd) ~= cmd then return false end
  local hot_window = math.max(0.10, (tonumber(GD.state.loop_delay or GD.cfg.loop_delay or 0.15) or 0.15) * 0.75)
  return (_now() - (tonumber(last.at) or 0)) < hot_window
end

local function _eq_lane_score(cat)
  cat = tostring(cat or "")
  if cat == "anti_tumble" then return 120 end
  return 30
end

local function _bal_lane_score(cat)
  cat = tostring(cat or "")
  if cat == "anti_tumble" then return 118 end
  return 12
end

local function _choose_main_lane(eq_cmd, eq_cat, bal_cmd, bal_cat)
  local pick_eq = { lane = "eq", cmd = eq_cmd, category = eq_cat, score = _eq_lane_score(eq_cat) }
  local pick_bal = { lane = "bal", cmd = bal_cmd, category = bal_cat, score = _bal_lane_score(bal_cat) }

  if _trim(eq_cmd) == "" and _trim(bal_cmd) == "" then
    return { lane = "", cmd = nil, category = nil, score = 0, alt = nil }
  end
  if _trim(eq_cmd) == "" then
    return { lane = pick_bal.lane, cmd = pick_bal.cmd, category = pick_bal.category, score = pick_bal.score, alt = nil }
  end
  if _trim(bal_cmd) == "" then
    return { lane = pick_eq.lane, cmd = pick_eq.cmd, category = pick_eq.category, score = pick_eq.score, alt = nil }
  end

  if pick_bal.score > pick_eq.score then
    pick_bal.alt = pick_eq
    return pick_bal
  end

  pick_eq.alt = pick_bal
  return pick_eq
end

_tarot_entity_payload = function(bal_cmd, entity_cmd, tgt)
  bal_cmd = _trim(bal_cmd)
  entity_cmd = _trim(entity_cmd)
  tgt = _trim(tgt)
  if bal_cmd == "" or entity_cmd == "" or tgt == "" then return nil end
  local sep = _command_sep()
  local sep_pat = sep:gsub("(%W)", "%%%1")
  local card_a, card_b, card_tgt = bal_cmd:match("^outd%s+([%w_%-]+)%s*" .. sep_pat .. "%s*fling%s+([%w_%-]+)%s+at%s+(.+)$")
  if _trim(card_a) == "" or card_a ~= card_b or _lc(card_tgt or "") ~= _lc(tgt) then return nil end
  return ("outd %s%s%s%sfling %s at %s"):format(card_a, sep, entity_cmd, sep, card_a, tgt)
end

_payload_line = function(payload)
  if type(payload) ~= "table" or type(payload.lanes) ~= "table" then return "" end
  local lanes = payload.lanes
  local entity_cmd = _trim(lanes.entity or lanes.class)
  local compound = _tarot_entity_payload(lanes.bal, entity_cmd, payload.target)
  local cmds = {}
  if _trim(lanes.free) ~= "" then cmds[#cmds + 1] = _trim(lanes.free) end
  if _trim(lanes.eq) ~= "" then cmds[#cmds + 1] = _trim(lanes.eq) end
  if compound then
    cmds[#cmds + 1] = compound
    return table.concat(cmds, _command_sep())
  end
  if _trim(lanes.bal) ~= "" then cmds[#cmds + 1] = _trim(lanes.bal) end
  if entity_cmd ~= "" then cmds[#cmds + 1] = entity_cmd end
  return table.concat(cmds, _command_sep())
end

local function _route_gate_finalize(payload, ctx)
  if not (Yso and Yso.route_gate and type(Yso.route_gate.finalize) == "function") then
    return payload, nil
  end
  return Yso.route_gate.finalize(payload, {
    route = "group_damage",
    target = type(payload) == "table" and payload.target or "",
    lane_ready = {
      eq = _eq_ready(),
      bal = _bal_ready(),
      entity = _ent_ready(),
    },
    required_entities = {
      worm = true,
      sycophant = true,
    },
    ctx = ctx,
  })
end

local _core_state
local _entity_pick
local _primebonded

local function _shield_is_up(tgt)
  if Yso and Yso.shield and type(Yso.shield.is_up) == "function" then
    local ok, v = pcall(Yso.shield.is_up, tgt)
    if ok then return v == true end
  end
  return false
end

local function _shieldbreak_tag(tgt)
  return "gd:eq:shieldbreak:" .. _lc(tgt)
end

local function _shieldbreak_pending(tgt)
  local S = _offense_state()
  if not S then return false end
  local tag = _shieldbreak_tag(tgt)
  if type(S.locked) == "function" then
    local ok, locked = pcall(S.locked, tag)
    if ok and locked == true then return true end
  end
  if type(S.recent) == "function" then
    local window = math.max(1.0, (tonumber(GD.cfg.dupe_window_ms or 120) or 120) / 1000)
    local ok, seen = pcall(S.recent, tag, window)
    if ok and seen == true then return true end
  end
  return false
end

local function _note_shieldbreak_sent(tgt, cmd)
  local S = _offense_state()
  if not (S and type(S.note) == "function") then return end
  local window = math.max(1.0, (tonumber(GD.cfg.dupe_window_ms or 120) or 120) / 1000)
  pcall(S.note, _shieldbreak_tag(tgt), cmd, { lockout = window, state_sig = "group_damage:shieldbreak" })
end

local function _entity_need_flags(tgt, st)
  st = type(st) == "table" and st or _core_state(tgt)
  return {
    healthleech = not (st.healthleech == true),
    sensitivity = not (st.sensitivity == true),
    clumsiness = not (st.clumsiness == true),
    slickness = not (st.slickness == true),
    addiction = _primebonded("humbug") and not _has_aff(tgt, "addiction"),
  }
end

local function _entity_need_any(need)
  if type(need) ~= "table" then return false end
  for _, v in pairs(need) do
    if v == true then return true end
  end
  return false
end

local function _entity_debug_reason_from_pick(need, dbg)
  if not _entity_need_any(need) then return "target_not_missing" end
  local lock_reason = _locks_class_reason()
  if lock_reason then return lock_reason end
  if not _ent_ready() then return "precommit_ent_not_ready" end
  if type(dbg) == "table" and dbg.global == "target_invalid" then return "target_not_missing" end
  return "no_valid_pick"
end

local function _same_fingerprint_in_flight(payload)
  local fingerprint = _action_fingerprint(payload)
  local flight = GD.state and GD.state.in_flight or nil
  if fingerprint == "" or type(flight) ~= "table" then return false end
  if _trim(flight.fingerprint) == "" or _trim(flight.target) == "" then return false end
  if _lc(payload.target or "") ~= _lc(flight.target) then return false end
  if fingerprint ~= _trim(flight.fingerprint) then return false end
  return (_now() - (tonumber(flight.at) or 0)) < 3.0
end

local function _final_pre_emit_payload(payload)
  if type(payload) ~= "table" or type(payload.lanes) ~= "table" then return payload, nil end
  local tgt = _trim(payload.target)
  if tgt == "" then return payload, nil end

  payload.meta = payload.meta or {}
  local lanes = payload.lanes

  if _shield_is_up(tgt) then
    _set_debug_field("last_shield_target", tgt)
    _note_entity_no_send("shieldbreak_override")
    _note_no_send_reason("shieldbreak_override")
    if _shieldbreak_pending(tgt) then
      _note_no_send_reason("duplicate_action_suppressed")
      return nil, "duplicate_action_suppressed"
    end

    local cmd = ("command gremlin at %s"):format(tgt)
    if Yso and Yso.off and Yso.off.util and type(Yso.off.util.maybe_shieldbreak) == "function" then
      local ok, v = pcall(Yso.off.util.maybe_shieldbreak, tgt)
      local alt = _trim(ok and v or "")
      if alt ~= "" then cmd = alt end
    end

    lanes.eq = cmd
    lanes.bal = nil
    lanes.entity = nil
    lanes.class = nil
    payload.meta.eq_category = "defense_break"
    payload.meta.bal_category = nil
    payload.meta.entity_category = nil
    payload.meta.main_lane = "eq"
    payload.meta.main_category = "defense_break"
    payload.meta.shieldbreak_override = true
    _note_retry_reason("retry_shieldbreak")
    return payload, nil
  end

  if _trim(lanes.eq) ~= "" and _trim(lanes.entity or lanes.class) == "" then
    local st = payload.meta.core_state or _core_state(tgt)
    local need = _entity_need_flags(tgt, st)
    if not _entity_need_any(need) then
      _note_entity_no_send("target_not_missing")
      return payload, nil
    end

    local lock_reason = _locks_class_reason()
    if lock_reason then
      _note_entity_no_send(lock_reason)
      _note_entity_no_send("degraded_to_eq_only")
      return payload, nil
    end

    if not _ent_ready() then
      _note_entity_no_send("precommit_ent_not_ready")
      _note_entity_no_send("degraded_to_eq_only")
      return payload, nil
    end

    local category = (need.healthleech or need.clumsiness) and "required_core_refresh" or "fallback_support"
    local entity_cmd, entity_cat, dbg = _entity_pick(tgt, st, category, {
      need_healthleech = need.healthleech == true,
      need_sensitivity = need.sensitivity == true,
      need_clumsiness = need.clumsiness == true,
      need_slickness = need.slickness == true,
      need_addiction = need.addiction == true,
    })
    if _trim(entity_cmd) ~= "" then
      lanes.entity = entity_cmd
      payload.meta.entity_category = entity_cat or category
      _note_retry_reason("retry_entity_ready")
      return payload, nil
    end

    _note_entity_no_send(_entity_debug_reason_from_pick(need, dbg))
    _note_entity_no_send("degraded_to_eq_only")
  end

  return payload, nil
end

------------------------------------------------------------
-- Opener helper disabled for this route
-- NOTE: retained as no-op helpers for compatibility.
------------------------------------------------------------
local function _want_opener(tgt)
  return nil
end

local function _mark_opener_sent(tgt)
  return nil
end


------------------------------------------------------------
-- Route helpers
------------------------------------------------------------
_core_state = function(tgt)
  local st = {
    healthleech = _has_aff(tgt, "healthleech"),
    sensitivity = _has_aff(tgt, "sensitivity"),
    clumsiness  = _has_aff(tgt, "clumsiness"),
    slickness   = _has_aff(tgt, "slickness"),
    asthma      = _has_aff(tgt, "asthma"),
    aeon        = _has_aff(tgt, "aeon"),
    entangled   = _has_aff(tgt, "entangled"),
  }
  local n = 0
  if st.healthleech then n = n + 1 end
  if st.sensitivity then n = n + 1 end
  if st.clumsiness then n = n + 1 end
  st.count = n
  return st
end

local function _count_core_affs(tgt)
  return _core_state(tgt).count
end

local function _cmd_entity(ent, tgt, extra)
  ent = tostring(ent or ""):lower()
  tgt = tostring(tgt or "")
  if ent == "" or tgt == "" then return nil end
  if ent == "firelord" and extra and extra ~= "" then
    return ("command %s at %s %s"):format(ent, tgt, extra)
  end
  return ("command %s at %s"):format(ent, tgt)
end


_primebonded = function(ent)
  local ER = _ER()
  if ER and type(ER.is_primebonded) == "function" then
    local ok, v = pcall(ER.is_primebonded, ent)
    if ok then return v == true end
  end
  return false
end

-- Inline entity priority list — edit this table to change which entities are
-- commanded and in what order. Each entry fires when the target is missing that
-- aff and (if cond is present) the condition passes. Entries with a 'cond' that
-- references _primebonded require that entity to be primebonded before firing.
GD.cfg.ent_prio = GD.cfg.ent_prio or {
  { aff = "healthleech", cmd = "command worm at %s" },
  { aff = "clumsiness",  cmd = "command storm at %s" },
  { aff = "asthma",      cmd = "command bubonis at %s" },
  { aff = "slickness",   cmd = "command bubonis at %s",    cond = function(tgt, has) return has(tgt, "asthma") end },
  { aff = "paralysis",   cmd = "command slime at %s",      cond = function(tgt, has) return has(tgt, "asthma") end },
  { aff = "addiction",   cmd = "command humbug at %s",     cond = function(tgt, has) return _primebonded("humbug") end },
  { aff = "weariness",   cmd = "command hound at %s",      cond = function(tgt, has) return _primebonded("hound") end },
  { aff = "haemophilia", cmd = "command bloodleech at %s", cond = function(tgt, has) return _primebonded("bloodleech") end },
}

-- Walk GD.cfg.ent_prio and return the first entity command for an aff the
-- target is missing. skip_aff (from opts) is excluded so EQ and entity don't
-- redundantly cover the same aff when the caller already has an explicit pair.
_entity_pick = function(tgt, st, category, opts)
  opts = opts or {}
  if not _ent_ready() then return nil, nil, nil end
  local skip = _lc(opts.skip_aff or "")
  for _, entry in ipairs(GD.cfg.ent_prio or {}) do
    if entry.aff ~= skip and not _has_aff(tgt, entry.aff) then
      if not entry.cond or entry.cond(tgt, _has_aff) then
        return (entry.cmd):format(tgt), entry.category or category, nil
      end
    end
  end
  return nil, nil, nil
end

local function _pick_entity_cmd(tgt, st, opts)
  opts = opts or {}
  if not _ent_ready() then
    _note_entity_no_send("snapshot_ent_not_ready")
    return nil, nil
  end
  local skip_aff = _lc(opts.skip_aff)
  if skip_aff == "clumsiness" then
    return ("command storm at %s"):format(tgt), tostring(opts.category or "required_core_refresh")
  end
  if skip_aff == "healthleech" then
    return ("command worm at %s"):format(tgt), tostring(opts.category or "required_core_application")
  end
  if skip_aff == "slickness" and _has_aff(tgt, "asthma") then
    return ("command bubonis at %s"):format(tgt), tostring(opts.category or "fallback_support")
  end
  if skip_aff == "asthma" then
    return ("command bubonis at %s"):format(tgt), tostring(opts.category or "required_core_refresh")
  end
  if skip_aff == "paralysis" and _has_aff(tgt, "asthma") then
    return ("command slime at %s"):format(tgt), tostring(opts.category or "fallback_support")
  end
  return _entity_pick(tgt, st, tostring(opts.category or "fallback_support"), opts)
end

local function _loyals_active_for(tgt)
  local C = _companions()
  if C and type(C.is_active_for) == "function" then
    local ok, v = pcall(C.is_active_for, tgt)
    if ok then return v == true end
  end

  local Off = Yso and Yso.off and Yso.off.oc or nil
  if Off and type(Off.loyals_active_for) == "function" then
    local ok, v = pcall(Off.loyals_active_for, tgt)
    if ok then return v == true end
  end
  return false
end

local function _plan_free(tgt)
  if _loyals_active_for(tgt) then return nil, nil end

  local C = _companions()
  if C and type(C.kill) == "function" then
    local ok, res, why = pcall(C.kill, tgt, {
      include_stand = (Yso and Yso.legality and Yso.legality.queue_stand == true),
      emit = false,
    })
    local open_reason = ok and _trim(why) or ""
    if ok and type(res) == "table" then
      local parts = {}
      for i = 1, #res do
        local cmd = _trim(res[i])
        if cmd ~= "" then parts[#parts + 1] = cmd end
      end
      if #parts > 0 then
        return table.concat(parts, _command_sep()), "team_coordination"
      end
    elseif ok and type(res) == "string" and _trim(res) ~= "" then
      return _trim(res), "team_coordination"
    elseif open_reason == "recovering" then
      -- Companion helper intentionally suppresses kill orders while recovering.
      return nil, nil
    end
  end

  local parts = {}
  if Yso and Yso.legality and Yso.legality.queue_stand == true then
    parts[#parts + 1] = "stand"
  end
  parts[#parts + 1] = (tostring(GD.cfg.loyals_on_cmd or "order loyals kill %s")):format(tgt)
  return table.concat(parts, _command_sep()), "team_coordination"
end

local function _plan_bal_support(tgt, st, eq_cmd, class_cmd, opts)
  opts = opts or {}
  if not _bal_ready() then return nil, nil, nil end
  if eq_cmd or class_cmd then return nil, nil, nil end

  if not st.aeon and _ak_speed_is_down() then
    if _ent_ready() then
      local filler_cmd, filler_category = _pick_entity_cmd(tgt, st, {
        category = "fallback_support",
        need_healthleech = opts.need_healthleech == true,
        need_sensitivity = opts.need_sensitivity == true,
        need_clumsiness = opts.need_clumsiness == true,
        need_slickness = opts.need_slickness == true,
        need_addiction = opts.need_addiction == true,
      })
      if filler_cmd then
        local A = Yso and Yso.occ and Yso.occ.aeon or nil
        local aeon_bal = nil
        if A and type(A.bal_payload) == "function" then
          local ok, cmd = pcall(A.bal_payload, tgt, { request_if_needed = true })
          if ok and type(cmd) == "string" and _trim(cmd) ~= "" then
            aeon_bal = cmd
          end
        elseif A and type(A.request) == "function" and type(A.tick) == "function" and Yso and type(Yso.emit_capture) == "function" then
          -- Fallback path if bal_payload is unavailable: attempt centralized tick via payload capture.
          pcall(A.request, tgt, { finisher = false })
          local ok_tick, payload = pcall(Yso.emit_capture, function()
            return A.tick(tgt, "group_damage_bal_support")
          end)
          if ok_tick and type(payload) == "table" then
            local bal = _trim(payload.bal)
            if bal ~= "" then aeon_bal = bal end
          end
        end
        if aeon_bal then
          return aeon_bal, filler_cmd, filler_category or "fallback_support"
        end
      end
    end
  elseif not st.entangled and _prone_is_forced(tgt) then
    if _ent_ready() then
      local sep = _command_sep()
      return ("outd hangedman%sfling hangedman at %s"):format(sep, tgt),
        ("command crone at %s %s"):format(tgt, _random_crone_arm(tgt)),
        "fallback_support"
    end
  end

  if _justice_conversion_count(tgt) >= 2 and not _justice_already_sent(tgt) then
    return ("ruinate justice %s"):format(tgt), nil, nil
  end

  return nil, nil, nil
end

local function _plan_route(tgt)
  local st = _core_state(tgt)
  local p = {
    eq = nil, bal = nil, class = nil, st = st,
    eq_category = nil, bal_category = nil, class_category = nil,
    eq_aff = nil,
  }

  local miss_hl = not st.healthleech
  local miss_sens = not st.sensitivity
  local miss_clum = not st.clumsiness
  local miss_slick = not st.slickness
  local need_addiction = _primebonded("humbug") and (not _has_aff(tgt, "addiction"))

  local ER = _ER()
  local bootstrap_done = true
  if ER and type(ER.bootstrap_done) == "function" then
    local ok, v = pcall(ER.bootstrap_done, tgt, {
      target = tgt,
      target_valid = _tgt_valid(tgt),
      ent_ready = _ent_ready(),
      eq_ready = _eq_ready(),
      has_aff = function(aff_name) return _has_aff(tgt, aff_name) end,
      route_state = st,
      need = { healthleech = miss_hl, clumsiness = miss_clum },
    })
    if ok then bootstrap_done = (v == true) end
  end

  local function pick_class(category)
    local cmd, solved = _pick_entity_cmd(tgt, st, {
      category = category,
      need_healthleech = miss_hl,
      need_sensitivity = miss_sens,
      need_clumsiness = miss_clum,
      need_slickness = miss_slick,
      need_addiction = need_addiction,
      skip_aff = p.eq_aff,
    })
    if cmd and not p.class then
      p.class = cmd
      p.class_category = solved or category
    end
    return p.class
  end

  local function apply_bal_support()
    local bal_cmd, bal_class_cmd, bal_class_category = _plan_bal_support(tgt, st, p.eq, p.class, {
      need_healthleech = miss_hl,
      need_sensitivity = miss_sens,
      need_clumsiness = miss_clum,
      need_slickness = miss_slick,
      need_addiction = need_addiction,
    })
    if bal_class_cmd and not p.class then
      p.class = bal_class_cmd
      p.class_category = bal_class_category or "fallback_support"
    end
    p.bal = bal_cmd
    if p.bal then p.bal_category = "fallback_support" end
  end

  -- Reserved paired burst is the only category allowed to outrank a dropped core.
  if st.healthleech and _eq_ready() and _ent_ready() then
    local burst_cmd, solved = _pick_entity_cmd(tgt, st, {
      category = "reserved_paired_burst",
      need_healthleech = false,
      need_sensitivity = false,
      need_clumsiness = false,
      need_slickness = miss_slick,
      need_addiction = need_addiction,
    })
    if burst_cmd then
      p.eq = ("warp %s"):format(tgt)
      p.eq_category = "reserved_paired_burst"
      p.class = burst_cmd
      p.class_category = solved or "reserved_paired_burst"
      return p
    end
  end

  if not bootstrap_done then
    pick_class("bootstrap_setup")
  end

  -- Core refresh/application wins after any reserved burst and bootstrap work.
  if miss_sens then
    if _eq_ready() then
      p.eq = ("instill %s with sensitivity"):format(tgt)
      p.eq_category = "required_core_refresh"
      p.eq_aff = "sensitivity"
    end
    if not p.class then pick_class("required_core_refresh") end
    if not p.class then pick_class("required_core_application") end
    apply_bal_support()
    return p
  end

  if miss_clum then
    if not p.class then pick_class("required_core_refresh") end
    if not p.class then pick_class("required_core_application") end
    if not p.class and _eq_ready() then
      p.eq = ("instill %s with clumsiness"):format(tgt)
      p.eq_category = "required_core_refresh"
      p.eq_aff = "clumsiness"
    end
    apply_bal_support()
    return p
  end

  if miss_hl then
    if st.count >= 2 and _eq_ready() then
      p.eq = ("warp %s"):format(tgt)
      p.eq_category = "required_core_application"
    elseif _eq_ready() and not _ent_ready() then
      p.eq = ("instill %s with healthleech"):format(tgt)
      p.eq_category = "required_core_application"
      p.eq_aff = "healthleech"
    end
    if not p.class then pick_class("required_core_refresh") end
    if not p.class then pick_class("required_core_application") end
    apply_bal_support()
    return p
  end

  -- Full core present: reserve paired burst when EQ is ready; otherwise use support lanes only.
  if st.healthleech and _eq_ready() then
    -- Hold EQ for burst reservation until entity lane can pair with Firelord.
    apply_bal_support()
    return p
  end

  -- Optional support: addiction (primebonded humbug) and general fallback entity pressure.
  if not p.class then pick_class("fallback_support") end
  if not p.class then pick_class("passive_pressure_only") end

  -- Optional slickness is lower than missing-core work, but higher than fallback BAL support when EQ is free.
  if miss_slick and _eq_ready() then
    p.eq = ("instill %s with slickness"):format(tgt)
    p.eq_category = "fallback_support"
    p.eq_aff = "slickness"
  end

  apply_bal_support()
  return p
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------
------------------------------------------------------------
-- Template Contract Facade
--  * Standardized surface matching the Offense Template guidance.
--  * Keeps legacy propose/tick behavior intact while exposing a uniform
--    route API for future routes and tooling.
------------------------------------------------------------
local function _party_damage_context_active()
  local M = Yso and Yso.mode or nil
  if type(M) ~= "table" then return true end

  local is_party = true
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
    return Yso.mode.route_loop_active("group_damage") == true
  end
  return GD.state and GD.state.loop_enabled == true
end
local function _automation_allowed()
  return _route_is_active()
end

function GD.init()
  GD.cfg = GD.cfg or {}
  GD.state = GD.state or {}
  GD.state.justice_once = GD.state.justice_once or {}
  GD.state.template = GD.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = GD.state.last_target or "" }
  GD.state.waiting = GD.state.waiting or { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 }
  GD.state.last_attack = GD.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" }
  GD.state.in_flight = GD.state.in_flight or { fingerprint = "", target = "", route = "group_damage", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" }
  GD.state.debug = GD.state.debug or { last_no_send_reason = "", last_retry_reason = "", entity_no_send_reasons = {}, last_shield_target = "" }
  GD.state.busy = (GD.state.busy == true)
  GD.state.loop_delay = tonumber(GD.state.loop_delay or GD.cfg.loop_delay or 0.15) or 0.15
  _set_loop_enabled((GD.state.loop_enabled == true) or (GD.state.enabled == true))
  return true
end
function GD.reset(reason)
  GD.init()
  GD.state.opener_sent_for = ""
  GD.state.rr_idx = 0
  GD.state.stop_pending = false
  GD.state.last_room_id = ""
  GD.state.last_target = ""
  GD.state.entity_target = ""
  GD.state.busy = false
  _clear_waiting()
  GD.state.last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" }
  GD.state.in_flight = { fingerprint = "", target = "", route = "group_damage", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" }
  GD.state.debug = { last_no_send_reason = "", last_retry_reason = "", entity_no_send_reasons = {}, last_shield_target = "" }
  GD.state.template.last_reason = tostring(reason or "manual")
  GD.state.template.last_payload = nil
  _worm_reset()
  _syc_reset()
  GD.state.tumble = { target = "", dir = "", at = 0, until_t = 0, fired = false }
  GD.state.empress = { pending = false, target = "", dir = "", started_at = 0, last_try = 0, fail_until = 0 }
  return true
end

function GD.is_enabled()
  return GD.state and GD.state.enabled == true
end

function GD.is_active()
  return _route_is_active()
end

function GD.can_run(ctx)
  GD.init()
  if not GD.is_enabled() then return false, "disabled" end
  if not GD.is_active() then return false, "inactive" end
  if not _automation_allowed() then return false, "policy" end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return false, "paused" end
  if Yso and type(Yso.is_occultist) == "function" then
    local ok_class, is_occ = pcall(Yso.is_occultist)
    if ok_class and is_occ ~= true then return false, "wrong_class" end
  end
  local tgt = _trim((ctx and ctx.target) or _target())
  if tgt == "" then return false, "no_target" end
  if not _tgt_valid(tgt) then return false, "invalid_target" end
  return true, tgt
end

local function _attack_opts(arg)
  if type(arg) == "table" and (arg.preview ~= nil or arg.ctx ~= nil) then
    return arg.ctx, (arg.preview == true)
  end
  return arg, false
end

function GD.attack_function(arg)
  local ctx, preview = _attack_opts(arg)
  local ok, info = GD.can_run(ctx)
  if not ok then
    if preview then return nil, info end
    return false, info
  end

  local tgt = info
  local now = (ctx and tonumber(ctx.now)) or _now()
  _reset_entity_gates_on_target_change(tgt)
  if not preview and _waiting_blocks_tick() then
    return false, GD.state and GD.state.waiting and GD.state.waiting.reason or "waiting_outcome"
  end
  _reset_entity_no_send_reasons()

  local eq_cmd, eq_cat = nil, nil
  local bal_cmd, bal_cat = nil, nil
  local entity_cmd, entity_cat = nil, nil
  local free_cmd, free_cat = _plan_free(tgt)
  local st = _core_state(tgt)
  local p = nil
  local rescue = nil

  -- A. Anti-defensive measures on target.
  if GD.cfg.rescue_lust_empress == true then
    local anti = _rescue_antitumble_action(now)
    local empress = _rescue_empress_action(now)
    rescue = anti
    if empress and (not rescue or tonumber(empress.score or 0) > tonumber(rescue.score or 0)) then
      rescue = empress
    end
    if rescue then
      if rescue.qtype == "eq" then
        eq_cmd, eq_cat = rescue.cmd, rescue.category or "anti_tumble"
      elseif rescue.qtype == "bal" then
        bal_cmd, bal_cat = rescue.cmd, rescue.category or "anti_tumble"
      end
    end
  end

  -- B. Defensive measures on me.
  -- No self-defense pre-send branch lives in this route today.

  -- C. Main offensive spam logic.
  if not eq_cmd and not bal_cmd then
    p = _plan_route(tgt)
    if not p then
      if preview then return nil, "no_plan" end
      return false, "no_plan"
    end

    if GD.cfg.avoid_overlap and p.eq and type(p.eq) == "string" then
      local eqlc = p.eq:lower()
      if eqlc:match("^%s*instill%s+") and eqlc:find("with%s+healthleech") then
        local clc = tostring(p.class or ""):lower()
        if clc:find("^%s*command%s+worm") or _worm_active(tgt) then
          p.eq = nil
        end
      end
    end

    eq_cmd, eq_cat = p.eq, p.eq_category
    bal_cmd, bal_cat = p.bal, p.bal_category
    entity_cmd, entity_cat = p.class, p.class_category
    st = p.st or st
  end

  -- D. Offensive conditions / overrides.
  local main = _choose_main_lane(eq_cmd, eq_cat, bal_cmd, bal_cat)
  local selected_eq = (main.lane == "eq") and main.cmd or nil
  local selected_bal = (main.lane == "bal") and main.cmd or nil
  if main.lane == "bal" and _trim(entity_cmd) == "" and p and _trim(p.eq_aff) ~= "" then
    local compensate_cmd, compensate_cat = _pick_entity_cmd(tgt, st, {
      category = p.class_category or "fallback_support",
      skip_aff = p.eq_aff,
    })
    if _trim(compensate_cmd) ~= "" then
      entity_cmd = compensate_cmd
      entity_cat = compensate_cat or entity_cat
    end
  end
  local main_lane = main.lane
  if main_lane == "" and _trim(entity_cmd) ~= "" then
    main_lane = "entity"
  end
  if main_lane == "" and _trim(free_cmd) ~= "" then
    main_lane = "free"
  end

  -- E. Misc / bookkeeping / optional echoes.
  local payload = {
    route = "group_damage",
    target = tgt,
    lanes = {
      free = free_cmd,
      eq = selected_eq,
      bal = selected_bal,
      entity = entity_cmd,
    },
    meta = {
      free_category = free_cat,
      eq_category = (main.lane == "eq") and main.category or nil,
      bal_category = (main.lane == "bal") and main.category or nil,
      entity_category = entity_cat,
      core_state = st,
      main_lane = main_lane,
      main_category = main.category,
      alt_lane = main.alt and main.alt.lane or nil,
      alt_category = main.alt and main.alt.category or nil,
      rescue_tag = rescue and rescue.tag or nil,
    },
  }
  payload, _ = _route_gate_finalize(payload, ctx)
  GD.state.template.last_payload = payload
  GD.state.template.last_target = tgt

  local emit_payload = (Yso and Yso.route_gate and type(Yso.route_gate.payload_for_emit) == "function")
    and Yso.route_gate.payload_for_emit(payload)
    or payload
  local planner_empty = not payload.lanes.free and not payload.lanes.eq and not payload.lanes.bal and not payload.lanes.entity
  local emit_empty = not emit_payload.lanes.free and not emit_payload.lanes.eq and not emit_payload.lanes.bal and not emit_payload.lanes.entity

  if preview then
    if planner_empty then return nil, "empty" end
    return payload
  end

  if emit_empty then return false, "empty" end
  local emit_err = nil
  emit_payload, emit_err = _final_pre_emit_payload(emit_payload)
  if not emit_payload then
    _note_no_send_reason(emit_err or "empty")
    return false, emit_err or "empty"
  end
  local cmd = _payload_line(emit_payload)
  if _trim(cmd) == "" then return false, "empty" end
  if _same_fingerprint_in_flight(emit_payload) then
    _note_no_send_reason("duplicate_action_suppressed")
    return false, "duplicate_action_suppressed"
  end
  if _same_attack_is_hot(cmd) then
    _note_no_send_reason("duplicate_action_suppressed")
    return false, "duplicate_action_suppressed"
  end

  local sent, err = _emit_lanes(emit_payload, "group_damage:attack")
  if not sent then
    _note_retry_reason("retry_hard_fail")
    return false, err
  end
  if emit_payload.meta and emit_payload.meta.shieldbreak_override == true then
    _note_shieldbreak_sent(tgt, cmd)
  end

  GD.state.template.last_emitted_payload = emit_payload
  if Yso and Yso.route_gate and type(Yso.route_gate.note_emitted) == "function" then
    pcall(Yso.route_gate.note_emitted, payload, emit_payload, ctx)
  end
  local has_ack_bus = Yso and Yso.locks and type(Yso.locks.note_payload) == "function"
  if not has_ack_bus then
    GD.on_sent(emit_payload, ctx)
  end

  _remember_attack(cmd, emit_payload)
  return true, cmd, payload
end

function GD.build_payload(ctx)
  return GD.attack_function({ ctx = ctx, preview = true })
end

function GD.build(reason)
  local ctx = type(reason) == "table" and reason or { reason = tostring(reason or "") }
  return GD.build_payload(ctx)
end
function GD.on_sent(payload, ctx)
  GD.init()
  local legacy = payload
  if type(payload) == "table" and payload.lanes then
    legacy = {
      eq = payload.lanes.eq,
      bal = payload.lanes.bal,
      class = payload.lanes.entity,
      free = payload.lanes.free,
    }
  end
  GD.state.template.last_emitted_payload = payload
  do
    local C = _companions()
    if C and type(C.note_order_sent) == "function" and type(payload) == "table" then
      local free = payload.free or (payload.lanes and payload.lanes.free) or nil
      local tgt = _trim(payload.target or (payload.lanes and payload.lanes.target) or GD.state.last_target)
      local sep = _command_sep()
      local function note_one(cmd)
        cmd = _trim(cmd)
        if cmd ~= "" then pcall(C.note_order_sent, cmd, tgt) end
      end
      if type(free) == "table" then
        for i = 1, #free do
          local raw = _trim(free[i])
          _each_sep_part(raw, sep, note_one)
        end
      elseif type(free) == "string" and _trim(free) ~= "" then
        _each_sep_part(free, sep, note_one)
      end
    end
  end
  return GD.on_payload_sent(legacy)
end

function GD.evaluate(ctx)
  local payload, why = GD.build_payload(ctx)
  if not payload then return { ok = false, reason = why } end
  return { ok = true, payload = payload }
end

function GD.explain()
  local tgt = _target()
  local st = _core_state(tgt)
  local last_payload = GD.state and GD.state.template and GD.state.template.last_payload or nil
  local gate = type(last_payload) == "table" and (last_payload._route_gate or (last_payload.meta and last_payload.meta.route_gate)) or nil
  return {
    route = "group_damage",
    enabled = GD.is_enabled(),
    active = GD.is_active(),
    target = tgt,
    core = st,
    last_reason = GD.state and GD.state.template and GD.state.template.last_reason or "",
    last_disable_reason = GD.state and GD.state.template and GD.state.template.last_disable_reason or "",
    last_no_send_reason = GD.state and GD.state.debug and GD.state.debug.last_no_send_reason or "",
    last_retry_reason = GD.state and GD.state.debug and GD.state.debug.last_retry_reason or "",
    entity_no_send_reasons = GD.state and GD.state.debug and GD.state.debug.entity_no_send_reasons or {},
    waiting = GD.state and GD.state.waiting or {},
    in_flight = GD.state and GD.state.in_flight or {},
    last_entity_debug = GD.state and GD.state.last_entity_debug or nil,
    planned = gate and gate.planned and gate.planned.lanes or {},
    gated = gate and gate.gated and gate.gated.lanes or (last_payload and last_payload.lanes) or {},
    blocked_reasons = gate and gate.blocked_reasons or {},
    hindrance = gate and gate.hinder or {},
    required_entities = gate and gate.entities and gate.entities.required or {},
    entity_obligations = gate and gate.entities and gate.entities.obligations or {},
    emitted = gate and gate.emitted or {},
    confirmed = gate and gate.confirmed or {},
    last_payload = last_payload,
  }
end

function GD.on_enter(ctx)
  GD.init()
  return true
end

function GD.on_exit(ctx)
  if Yso and Yso.mode and type(Yso.mode.stop_route_loop) == "function" then
    Yso.mode.stop_route_loop("group_damage", "exit", true)
  end
  GD.reset("exit")
  return true
end

function GD.on_target_swap(old_target, new_target)
  if _lc(old_target) ~= _lc(new_target) then
    GD.reset("target_swap")
    GD.state.last_target = _trim(new_target)
    if GD.state.loop_enabled == true then
      GD.schedule_loop(0)
    end
  end
  return true
end

function GD.on_pause(ctx)
  return true
end

function GD.on_resume(ctx)
  if GD.state and GD.state.loop_enabled == true then
    GD.schedule_loop(0)
  end
  return true
end

function GD.on_manual_success(ctx)
  if GD.state and GD.state.loop_enabled == true then
    GD.schedule_loop(GD.state.loop_delay)
  end
  return true
end

function GD.on_send_result(payload, ctx)
  return GD.on_sent(payload, ctx)
end

local function _kill_loop_timer()
  if GD.state and GD.state.timer_id then
    pcall(killTimer, GD.state.timer_id)
    GD.state.timer_id = nil
  end
end

function GD.schedule_loop(delay)
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    return Yso.mode.schedule_route_loop("group_damage", delay)
  end
  return false
end

GD.alias_loop_stop_details = GD.alias_loop_stop_details or {
  inactive = true,
  disabled = true,
  policy = true,
}

function GD.alias_loop_prepare_start(ctx)
  GD.init()
  return ctx or {}
end

function GD.alias_loop_on_started(ctx)
  GD.state.stop_pending = false
  GD.state.busy = false
  _clear_waiting()

  _echo_toggle("GROUP DAMAGE LOOP ON.")
  local tgt = _target()
  if tgt == "" then
    _echo("No target yet; holding.")
  elseif not _tgt_valid(tgt) then
    _echo(string.format("%s is not in room; holding.", tgt))
  end
end

function GD.alias_loop_on_stopped(ctx)
  GD.init()
  ctx = ctx or {}
  local reason = tostring(ctx.reason or "manual")
  GD.state.stop_pending = false

  local C = _companions()
  local sent_passive = false
  if C and type(C.passive) == "function" then
    local ok = nil
    ok, _ = C.passive({ emit = true, target = _target() })
    sent_passive = (ok == true)
  end
  if not sent_passive then
    local passive = _trim(tostring(GD.cfg.off_passive_cmd or "order loyals passive"))
    if passive ~= "" then
      _emit_lanes({ lanes = { free = passive }, target = _target() }, "group_damage:off_passive")
    end
    _set_loyals_hostile(false)
  end
  if C and type(C.reset_recovery) == "function" then
    pcall(C.reset_recovery, "route_off")
  end

  if ctx.silent ~= true then
    _echo_toggle(string.format("GROUP DAMAGE LOOP OFF (%s).", tostring(reason):upper()))
  end
end

function GD.alias_loop_clear_waiting()
  return _clear_waiting()
end

function GD.alias_loop_waiting_blocks()
  return _waiting_blocks_tick()
end

function GD.alias_loop_on_error(err)
  _echo("Group damage loop error: " .. tostring(err))
end
------------------------------------------------------------
-- Anti-tumble / Empress rescue (stateful)
--  * Wired by triggers in yso_offense_coordination.lua:
--      - tumble_begin -> GD.mark_tumble(tgt, dir)
--      - tumble_out   -> GD.mark_tumble_out(tgt, DIRU)
--  * Wired by Tarot triggers:
--      - Empress fail  -> GD.mark_empress_fail()
--      - Lust success  -> GD.mark_lust_landed(tgt)
------------------------------------------------------------
local function _tgt_present(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return false end
  if Yso and Yso.room and type(Yso.room.has) == "function" then
    local ok, v = pcall(Yso.room.has, tgt)
    if ok then return v == true end
  end
  if type(Yso.target_is_valid) == "function" then
    local ok, v = pcall(Yso.target_is_valid, tgt)
    if ok then return v == true end
  end
  return false
end

function GD.mark_tumble(tgt, dir)
  tgt = _trim(tgt); dir = _trim(dir)
  if tgt == "" then return end
  local now = _now()
  local T = GD.state.tumble
  T.target  = tgt
  T.dir     = dir
  T.at      = now
  T.until_t = now + 0.75
  T.fired   = false
  local C = _companions()
  if C and type(C.invalidate) == "function" then
    pcall(C.invalidate, "tumble_begin", { target = tgt, dir = dir })
  end
  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    Yso.pulse.wake("gd:tumble_begin")
  end
end

function GD.mark_tumble_out(tgt, diru)
  tgt = _trim(tgt); diru = _trim(diru)
  if tgt == "" then return end
  GD.mark_tumble(tgt, diru)
  local now = _now()
  local E = GD.state.empress
  E.pending    = true
  E.target     = tgt
  E.dir        = diru
  E.started_at = now
  local C = _companions()
  if C and type(C.invalidate) == "function" then
    pcall(C.invalidate, "tumble_out", { target = tgt, dir = diru })
  end
  -- don't clear fail_until here: if we just failed empress, keep the backoff
  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    Yso.pulse.wake("gd:tumble_out")
  end
end

function GD.mark_empress_fail()
  local now = _now()
  local E = GD.state.empress
  E.fail_until = now + 10.0
  -- keep pending true so we retry after backoff (once Lust lands)
  if GD.cfg.echo then _echo("Empress failed: backing off 10s (need Lust).") end
end

function GD.mark_lust_landed(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return end
  local E = GD.state.empress
  if E.pending and _lc(E.target) == _lc(tgt) then
    E.fail_until = 0
    if Yso.pulse and type(Yso.pulse.wake) == "function" then
      Yso.pulse.wake("gd:lust_landed")
    end
  end
end

local function _rescue_antitumble_action(now)
  if GD.cfg.rescue_lust_empress ~= true then return nil end

  local T = GD.state.tumble
  if T.target == "" then return nil end
  if now > (tonumber(T.until_t) or 0) then
    T.target = ""; T.dir = ""; T.fired = false
    return nil
  end
  if T.fired then return nil end

  local tgt = _target()
  if tgt == "" or _lc(tgt) ~= _lc(T.target) then return nil end

  local sm_ready = false
  if Yso and type(Yso.soulmaster_ready) == "function" then
    local ok, v = pcall(Yso.soulmaster_ready)
    if ok then sm_ready = (v == true) end
  else
    sm_ready = (rawget(_G, "soulmaster_ready") == true)
  end

  if sm_ready and Yso and Yso.occ and type(Yso.occ.sm_cmd_tumble) == "function" and _eq_ready() then
    local ok, cmd = pcall(Yso.occ.sm_cmd_tumble, tgt, T.dir)
    cmd = _trim(ok and cmd or "")
    if cmd ~= "" then
      return {
        cmd = cmd,
        qtype = "eq",
        kind = "offense",
        score = 120,
        tag = "gd:anti:eq:" .. _lc(tgt) .. ":" .. _lc(T.dir),
        category = "anti_tumble",
        lockout = 0.75,
      }
    end
  end

  if not _bal_ready() then return nil end
  return {
    cmd = ("fling lust at %s"):format(tgt),
    qtype = "bal",
    kind = "offense",
    score = 118,
    tag = "gd:anti:bal:" .. _lc(tgt) .. ":" .. _lc(T.dir),
    category = "anti_tumble",
    lockout = 0.75,
  }
end

local function _rescue_empress_action(now)
  if GD.cfg.rescue_lust_empress ~= true then return nil end

  local E = GD.state.empress
  if not E.pending then return nil end

  local tgt = _trim(E.target)
  if tgt == "" then E.pending = false; return nil end
  if _tgt_present(tgt) then E.pending = false; return nil end
  if E.started_at ~= 0 and (now - (tonumber(E.started_at) or 0)) > 15.0 then
    E.pending = false
    return nil
  end
  if now < (tonumber(E.fail_until) or 0) then return nil end
  if not _bal_ready() then return nil end
  if (now - (tonumber(E.last_try) or 0)) < 0.9 then return nil end

  return {
    cmd = ("outd empress%sfling empress %s"):format(_command_sep(), tgt),
    qtype = "bal",
    kind = "offense",
    score = 116,
    tag = "gd:empress:" .. _lc(tgt) .. ":" .. _lc(E.dir),
    category = "anti_tumble",
    lockout = 0.9,
    no_repeat = false,
  }
end
-- Main tick
------------------------------------------------------------
function GD.tick(reasons)
  -- Alias-owned loop is the primary automated driver for this route.
  return false
end


-- =========================================================
-- Commit hook (called from Yso.locks.note_payload)
-- Used for per-target timers that must only latch on *actual* send.
-- =========================================================
local function _payload_contains_cmd(payload, lane, cmd)
  if type(payload) ~= "table" then return false end
  local row = payload[lane]
  if row == nil then return false end
  if type(row) == "string" then return row == cmd end
  if type(row) == "table" then
    for i=1,#row do
      if row[i] == cmd then return true end
    end
  end
  return false
end

local function _mark_justice_payload(payload)
  local function note(cmd)
    cmd = _trim(cmd)
    local tgt = cmd:match("^ruinate%s+justice%s+(.+)$")
    if tgt and tgt ~= "" then
      _mark_justice_sent(tgt)
    end
  end

  local bal = payload.bal
  if type(bal) == "string" then
    note(bal)
  elseif type(bal) == "table" then
    for i = 1, #bal do
      note(bal[i])
    end
  end
end

function GD.on_payload_sent(payload)
  if type(payload) ~= "table" then return end
  _mark_justice_payload(payload)

  -- OFF-cleanup bookkeeping: if we successfully sent the passive command, finalize shutdown.
  if GD.state.stop_pending then
    local want = tostring(GD.cfg.off_passive_cmd or "order loyals passive")
    local free = payload.free
    local ok = false
    if type(free) == "string" then
      ok = (free == want)
    elseif type(free) == "table" then
      for i=1,#free do if free[i] == want then ok = true; break end end
    end

    if ok then
      _set_loyals_hostile(false)
      GD.state.stop_pending = false
      GD.state.enabled = false
      GD.state.opener_sent_for = ""
      GD.state.last_room_id = ""
      GD.state.last_target = ""
      _echo("Group damage OFF. loyals passive.")
    end
  end

  local now = _now()
  local T = GD.state and GD.state.tumble or nil
  if type(T) == "table" and T.target ~= "" and T.fired ~= true then
    local lust_cmd = ("fling lust at %s"):format(T.target)
    if _payload_contains_cmd(payload, "bal", lust_cmd) then
      T.fired = true
    elseif Yso and Yso.occ and type(Yso.occ.sm_cmd_tumble) == "function" then
      local ok, cmd = pcall(Yso.occ.sm_cmd_tumble, T.target, T.dir)
      cmd = _trim(ok and cmd or "")
      if cmd ~= "" and _payload_contains_cmd(payload, "eq", cmd) then
        T.fired = true
      end
    end
  end

  local E = GD.state and GD.state.empress or nil
  if type(E) == "table" and E.pending then
    local empress_cmd = ("outd empress%sfling empress %s"):format(_command_sep(), _trim(E.target))
    if _payload_contains_cmd(payload, "bal", empress_cmd) then
      E.last_try = now
    end
  end

  -- Opener sent bookkeeping (best-effort).
  local pend = GD.state and GD.state._pending_opener
  if pend and type(pend) == "table" and pend.cmd and pend.tkey then
    local free = payload.free
    local sent = false
    if type(free) == "string" then
      sent = (free == pend.cmd)
    elseif type(free) == "table" then
      for i=1,#free do if free[i] == pend.cmd then sent = true; break end end
    end
    if sent then
      _mark_opener_sent(pend.tkey)
      GD.state._pending_opener = nil
    end
  end
end

-- Mudlet/party-mode friendly surface:
function GD.status()
  local tgt = _target()
  local st = _core_state(tgt)
  local snapshot = {
    route = "group_damage",
    enabled = tostring(GD.state and GD.state.loop_enabled == true),
    active = tostring(GD.is_active()),
    target = tostring(tgt),
    core_count = st.count,
    healthleech = st.healthleech,
    sensitivity = st.sensitivity,
    clumsiness = st.clumsiness,
    slickness = st.slickness,
    addiction = _has_aff(tgt, "addiction"),
    last_reason = GD.state and GD.state.template and GD.state.template.last_reason or "",
    last_disable_reason = GD.state and GD.state.template and GD.state.template.last_disable_reason or "",
    last_no_send_reason = GD.state and GD.state.debug and GD.state.debug.last_no_send_reason or "",
    last_retry_reason = GD.state and GD.state.debug and GD.state.debug.last_retry_reason or "",
  }
  _echo(string.format("loop=%s active=%s target=%s core=%d/3 (hl=%s sens=%s clumsy=%s slick=%s addiction=%s) last_no_send=%s retry=%s",
    snapshot.enabled, snapshot.active, snapshot.target, snapshot.core_count,
    tostring(snapshot.healthleech), tostring(snapshot.sensitivity), tostring(snapshot.clumsiness), tostring(snapshot.slickness), tostring(snapshot.addiction),
    tostring(snapshot.last_no_send_reason), tostring(snapshot.last_retry_reason)
  ))
  return snapshot
end

if Yso and Yso.off and Yso.off.core and type(Yso.off.core.register) == "function" then
  pcall(Yso.off.core.register, "group_damage", GD)
  pcall(Yso.off.core.register, "dam", GD)
  pcall(Yso.off.core.register, "gd", GD)
end


