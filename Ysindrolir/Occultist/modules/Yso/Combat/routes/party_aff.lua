--========================================================--
-- party_aff.lua  (Achaea / Occultist / Yso)
--  Party/group affliction pressure route for Occultist.
--
--  Strategy:
--    Build kelp-line afflictions (asthma, clumsiness, sensitivity,
--    healthleech) and layer mental pressure (whisperingmadness, attend)
--    to support team kills.
--
--  Lanes:
--    EQ  = instill / attend / enervate / cleanseaura / shieldbreak
--    BAL = ruinate (manaleech / lovers / moon) / fling support
--    ENT = entity commands (bubonis, storm, worm, slime, sycophant, chimera)
--    FREE= loyals open / doppleganger coordination
--
--  Alias-controlled: the shared route-loop controller owns timer scheduling.
--  This route provides payload planning, emit helpers, and lifecycle hooks.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

Yso.off.oc.party_aff = Yso.off.oc.party_aff or {}
local PA = Yso.off.oc.party_aff
local AP = Yso.off.oc.aura_planner or {}
PA.alias_owned = true

PA.route_contract = PA.route_contract or {
  id = "party_aff",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "kelp_pressure",
    "mental_pressure",
    "mana_drain",
    "entity_support",
    "team_coordination",
  },
  capabilities = {
    uses_eq = true,
    uses_bal = true,
    uses_entity = true,
    supports_burst = false,
    supports_bootstrap = true,
    needs_target = true,
    shares_defense_break = true,
    shares_anti_tumble = true,
  },
  override_policy = {
    mode = "narrow_global_only",
    allowed = {
      reserved_burst       = true,
      target_invalid       = true,
      target_slain         = true,
      route_off            = true,
      pause                = true,
      manual_suppression   = true,
      target_swap_bootstrap= true,
      defense_break        = true,
      anti_tumble          = true,
    },
  },
  lifecycle = {
    on_enter          = true,
    on_exit           = true,
    on_target_swap    = true,
    on_pause          = true,
    on_resume         = true,
    on_manual_success = true,
    on_send_result    = true,
    evaluate          = true,
    explain           = true,
  },
}

PA.cfg = PA.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,
  sequence_enabled = true,

  kelp_target_count = 3,
  mental_target = 3,
  asthma_stable_count = 2,
  cleanseaura_mana_pct = 40,

  attend_aff_floor = 3,
  shieldbreak_lockout_s = 1.0,
  attend_lockout_s = 2.3,
  instill_lockout_s = 2.5,
  enervate_lockout_s = 4.0,
  readaura_requery_s = 8.0,
  readaura_lockout_s = 1.0,
  cleanseaura_lockout_s = 4.1,
  pinchaura_lockout_s = 4.1,
  speed_hold_s = 3.2,
  utter_follow_s = 5.0,
  unnamable_lockout_s = 4.0,

  loyals_on_cmd = "order entourage kill %s",
}

local function _offense_state()
  return Yso and Yso.off and Yso.off.state or nil
end

PA.state = PA.state or {
  enabled = false,
  loop_enabled = false,
  timer_id = nil,
  busy = false,
  waiting = { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" },
  in_flight = { fingerprint = "", target = "", route = "party_aff", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" },
  debug = { last_no_send_reason = "", last_retry_reason = "" },
  template = { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" },
  last_target = "",
  loyals_sent_for = "",
  unnamable_sent_for = "",
  explain = {},
}

local function _trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function _lc(s) return _trim(s):lower() end

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

local function _bal_ready()
  if Yso and Yso.locks and type(Yso.locks.bal_ready) == "function" then
    local ok, v = pcall(Yso.locks.bal_ready)
    if ok then return v == true end
  end
  if Yso and Yso.state and type(Yso.state.bal_ready) == "function" then
    local ok, v = pcall(Yso.state.bal_ready)
    if ok then return v == true end
  end
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(v.bal or v.balance or "") == "1" or (v.bal == true or v.balance == true)
end

local function _ent_ready()
  if Yso and Yso.locks and type(Yso.locks.ent_ready) == "function" then
    local ok, v = pcall(Yso.locks.ent_ready)
    if ok then return v == true end
  end
  if Yso and Yso.state and type(Yso.state.ent_ready) == "function" then
    local ok, v = pcall(Yso.state.ent_ready)
    if ok then return v == true end
  end
  return true
end

local function _aff_score(tgt, aff)
  aff = tostring(aff or "")
  if aff == "" then return 0 end
  if Yso and Yso.oc and Yso.oc.ak and type(Yso.oc.ak.get_aff_score) == "function" then
    local ok, v = pcall(Yso.oc.ak.get_aff_score, aff)
    if ok and tonumber(v) then return tonumber(v) end
  end
  local A = rawget(_G, "affstrack")
  if type(A) == "table" then
    if type(A.score) == "table" and tonumber(A.score[aff]) then return tonumber(A.score[aff]) end
    local row = A[aff]
    if type(row) == "table" and tonumber(row.score) then return tonumber(row.score) end
  end
  if tgt ~= "" and Yso and Yso.tgt and type(Yso.tgt.has_aff) == "function" then
    local ok, v = pcall(Yso.tgt.has_aff, tgt, aff)
    if ok and v == true then return 100 end
  end
  return 0
end

local function _has_aff(tgt, aff) return _aff_score(tgt, aff) >= 100 end

local function _mental_score()
  if Yso and Yso.oc and Yso.oc.ak and Yso.oc.ak.scores and type(Yso.oc.ak.scores.mental) == "function" then
    local ok, v = pcall(Yso.oc.ak.scores.mental)
    if ok and tonumber(v) then return tonumber(v) end
  end
  local A = rawget(_G, "affstrack")
  return (type(A) == "table" and tonumber(A.mentalscore)) or 0
end

local function _bool_field(v)
  if v == nil then return nil end
  return v == true
end

local function _truebook_can_utter(tgt)
  local TB = Yso and Yso.occ and Yso.occ.truebook or nil
  if TB and type(TB.can_utter) == "function" then
    local ok, v = pcall(TB.can_utter, tgt)
    if ok then return v == true end
  end
  return false
end

local function _mana_pct(tgt, snap, fresh)
  if Yso and Yso.tgt and type(Yso.tgt.get_mana_pct) == "function" then
    local ok, v = pcall(Yso.tgt.get_mana_pct, tgt)
    if ok and tonumber(v) then return tonumber(v) end
  end
  if fresh and type(snap) == "table" and snap.had_mana == true and tonumber(snap.mana_pct) then
    return tonumber(snap.mana_pct)
  end
  return nil
end

-- _cleanseaura_snapshot, _aura_txn_active_for moved to occ_aura_planner.lua (AP.*)

local function _snapshot_view(tgt)
  local snap = AP.snapshot and AP.snapshot(tgt) or {}
  local fresh = (snap.fresh == true)
  local read_complete = fresh and (snap.read_complete == true)
  local parse_window_open = fresh and (snap.parse_window_open == true)
  local deaf = nil
  local speed = nil
  if read_complete then
    deaf = _bool_field(snap.deaf)
    speed = _bool_field(snap.speed)
  end
  local mana = _mana_pct(tgt, snap, fresh)
  local cap = tonumber(PA.cfg.cleanseaura_mana_pct or 40) or 40
  local needs_readaura = false
  local readaura_reason = ""
  if type(AP.needs_readaura) == "function" then
    needs_readaura, readaura_reason = AP.needs_readaura(tgt, snap)
  end

  return {
    snapshot = snap,
    snapshot_fresh = fresh,
    snapshot_read_complete = read_complete,
    parse_window_open = parse_window_open,
    deaf = deaf,
    speed = speed,
    mana_pct = mana,
    cleanseaura_ready = (mana ~= nil and mana <= cap) or false,
    needs_readaura = needs_readaura,
    readaura_reason = readaura_reason,
  }
end

local function _loyals_active_for(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return false end
  if type(Yso.loyals_attack) == "function" then
    local ok, v = pcall(Yso.loyals_attack, tgt)
    if ok and v == true then return true end
  end
  return _lc(PA.state.loyals_sent_for or "") == _lc(tgt)
end

local function _set_loyals_hostile(v, tgt)
  local hostile = (v == true)
  tgt = _trim(tgt)
  if type(Yso.set_loyals_attack) == "function" then
    pcall(Yso.set_loyals_attack, hostile, tgt)
    return
  end
  if Yso and Yso.state then
    Yso.state.loyals_hostile = hostile
    if hostile and tgt ~= "" then
      Yso.state.loyals_target = tgt
    elseif not hostile then
      Yso.state.loyals_target = nil
    end
  end
  rawset(_G, "loyals_attack", hostile)
end

local function _loyals_any_active()
  if type(Yso.loyals_attack) == "function" then
    local ok, v = pcall(Yso.loyals_attack)
    if ok and v == true then return true end
  end
  return _trim(PA.state.loyals_sent_for or "") ~= ""
end

PA.S = PA.S or {}
function PA.S.loyals_hostile(tgt)
  tgt = _trim(tgt)
  if tgt ~= "" then
    return _loyals_active_for(tgt)
  end
  return _loyals_any_active()
end

local function _readaura_tag(tgt)
  return AP.readaura_tag and AP.readaura_tag(tgt) or ("occ:eq:readaura:" .. _lc(tgt))
end

local function _cleanseaura_tag(tgt)
  return AP.cleanseaura_tag and AP.cleanseaura_tag(tgt) or ("occ:eq:cleanseaura:" .. _lc(tgt))
end

local function _pin_tag(tgt)
  return AP.pinchaura_tag and AP.pinchaura_tag(tgt) or ("occ:eq:pinchaura:" .. _lc(tgt))
end

local function _utter_tag(tgt)
  return "pa:eq:utter:" .. _lc(tgt)
end

local function _sequence_plan(tgt, opts)
  local cached = type(opts) == "table" and opts.sequence or nil
  if type(cached) == "table" then return cached end

  local snap = _snapshot_view(tgt)
  local loyals_bootstrap_pending = (type(opts) == "table" and opts.loyals_bootstrap_pending == true)
  local unnamable_pending = (snap.deaf == false) and (_lc(PA.state.unnamable_sent_for or "") ~= _lc(tgt))

  return {
    enabled = (PA.cfg.sequence_enabled ~= false),
    loyals_bootstrap_pending = loyals_bootstrap_pending,
    deaf = snap.deaf,
    speed = snap.speed,
    mana_pct = snap.mana_pct,
    can_utter = _truebook_can_utter(tgt),
    cleanseaura_ready = (snap.cleanseaura_ready == true),
    needs_readaura = (snap.needs_readaura == true),
    readaura_reason = tostring(snap.readaura_reason or ""),
    snapshot_fresh = (snap.snapshot_fresh == true),
    snapshot_read_complete = (snap.snapshot_read_complete == true),
    unnamable_pending = unnamable_pending,
    bal_only_tick = (_bal_ready() and not _ent_ready()),
  }
end

local function _focus_lock_count(tgt)
  local list = { "asthma", "haemophilia", "addiction", "clumsiness", "healthleech", "weariness", "sensitivity" }
  local n = 0
  for i = 1, #list do
    if _has_aff(tgt, list[i]) then n = n + 1 end
  end
  return n
end

local function _lock_stable(tgt)
  local need = tonumber(PA.cfg.lock_stable_count or 3) or 3
  return _focus_lock_count(tgt) >= need
end

local function _recent_sent(tag, within_s)
  local S = _offense_state()
  if not (S and type(S.recent) == "function") then return false end
  return S.recent(tag, within_s)
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

local function _shield_is_up(tgt)
  if Yso and Yso.shield and type(Yso.shield.is_up) == "function" then
    local ok, v = pcall(Yso.shield.is_up, tgt)
    if ok then return v == true end
  end
  return false
end

local function _entity_refresh_state(tgt)
  local ER = Yso and Yso.off and Yso.off.oc and Yso.off.oc.entity_registry or nil
  local out = { registry = ER, worm_refresh = true, syc_refresh = true }
  if ER and type(ER.worm_should_refresh) == "function" then
    local ok, v = pcall(ER.worm_should_refresh, tgt)
    if ok then out.worm_refresh = (v == true) end
  end
  if ER and type(ER.syc_should_refresh) == "function" then
    local ok, v = pcall(ER.syc_should_refresh, tgt)
    if ok then out.syc_refresh = (v == true) end
  end
  return out
end

local function _first_missing_lock_aff(tgt, skip_aff)
  local order = { "asthma", "haemophilia", "addiction", "clumsiness", "healthleech", "weariness", "sensitivity", "agoraphobia", "dementia", "claustrophobia", "confusion", "hallucinations", }
  skip_aff = _lc(skip_aff)
  for i = 1, #order do
    if order[i] ~= skip_aff and not _has_aff(tgt, order[i]) then return order[i] end
  end
  return nil
end

local function _entity_cmd_for_aff(aff, tgt)
  aff = tostring(aff or "")
  local Off = Yso and Yso.off and Yso.off.oc or nil
  if Off and type(Off.sg_entity_cmd_for_aff) == "function" then
    local ok, cmd = pcall(Off.sg_entity_cmd_for_aff, aff, tgt)
    cmd = _trim(ok and cmd or "")
    if cmd ~= "" then return cmd end
  end
  if Yso.ent_cmd_for_aff and type(Yso.ent_cmd_for_aff) == "function" then
    local cmd = Yso.ent_cmd_for_aff(aff, tgt, _has_aff)
    if cmd then return cmd end
  end
  if aff == "asthma" then return ("command bubonis at %s"):format(tgt) end
  if aff == "clumsiness" then return ("command storm at %s"):format(tgt) end
  if aff == "healthleech" then return ("command worm at %s"):format(tgt) end
  return nil
end

local function _party_aff_context_active()
  local M = Yso and Yso.mode or nil
  if type(M) ~= "table" then return true end
  if type(M.is_party) == "function" then
    local ok, v = pcall(M.is_party)
    if ok then if v ~= true then return false end end
  else
    if _lc(M.state or "") ~= "party" then return false end
  end
  local route = ""
  if type(M.party_route) == "function" then
    local ok, v = pcall(M.party_route)
    if ok then route = _lc(v or "") end
  elseif M.party then
    route = _lc(M.party.route or "")
  end
  return route == "" or route == "aff"
end

local function _route_is_active()
  if not _party_aff_context_active() then return false end
  if Yso and Yso.mode and type(Yso.mode.route_loop_active) == "function" then
    return Yso.mode.route_loop_active("party_aff") == true
  end
  return PA.state and PA.state.loop_enabled == true
end

local function _automation_allowed()
  return _route_is_active()
end

local function _echo(msg)
  if not PA.cfg.echo then return end
  local line = string.format("<dark_orchid>[Occultism] <reset>%s", tostring(msg))
  if Yso and Yso.util and type(Yso.util.cecho_line) == "function" then
    Yso.util.cecho_line(line)
  elseif type(cecho) == "function" then
    cecho(line .. "\n")
  end
end

local function _command_sep()
  local sep = _trim((Yso and (Yso.sep or (Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep)))) or "&&")
  if sep == "" then sep = "&&" end
  return sep
end

local function _safe_send(cmd)
  cmd = _trim(cmd)
  if cmd == "" or type(send) ~= "function" then return false, "send_unavailable" end
  local ok, err = pcall(send, cmd, false)
  if not ok then return false, err end
  return true
end

local _payload_line
local _plan_entity

local function _set_debug_field(key, value)
  PA.state.debug = PA.state.debug or { last_no_send_reason = "", last_retry_reason = "" }
  PA.state.debug[key] = value
  return value
end

local function _note_no_send_reason(reason)
  return _set_debug_field("last_no_send_reason", _trim(reason))
end

local function _note_retry_reason(reason)
  return _set_debug_field("last_retry_reason", _trim(reason))
end

local function _waiting_lanes_from_payload(payload)
  local lanes = {}
  local seen = {}
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

local function _action_fingerprint(payload)
  if type(payload) ~= "table" then return "" end
  local lanes = payload.lanes or payload
  if type(lanes) ~= "table" then return "" end
  return table.concat({
    "party_aff",
    _lc(payload.target or ""),
    _trim(lanes.eq),
    _trim(lanes.entity or lanes.class or lanes.ent),
    _trim(lanes.bal),
    _trim(lanes.free),
  }, "|")
end

local function _same_fingerprint_in_flight(payload)
  local fingerprint = _action_fingerprint(payload)
  local flight = PA.state and PA.state.in_flight or nil
  if fingerprint == "" or type(flight) ~= "table" then return false end
  if _trim(flight.fingerprint) == "" or _trim(flight.target) == "" then return false end
  if _lc(payload.target or "") ~= _lc(flight.target) then return false end
  if fingerprint ~= _trim(flight.fingerprint) then return false end
  return (_now() - (tonumber(flight.at) or 0)) < 3.0
end

local function _lane_ready(lane)
  lane = _lc(lane)
  if lane == "eq" then return _eq_ready() end
  if lane == "bal" then return _bal_ready() end
  if lane == "entity" or lane == "class" then return _ent_ready() end
  return true
end

local function _emit_payload(payload)
  local lane_tbl = type(payload) == "table" and payload.lanes or payload
  if type(lane_tbl) ~= "table" then return false, "invalid_payload" end

  local target = _trim(type(payload) == "table" and payload.target or "")
  local emit_payload = {
    free = lane_tbl.free or lane_tbl.pre,
    eq = lane_tbl.eq,
    bal = lane_tbl.bal,
    class = lane_tbl.class or lane_tbl.ent or lane_tbl.entity,
  }
  local cmd = _payload_line({ target = target, lanes = emit_payload })
  if _trim(cmd) == "" then return false, "empty" end

  local Q = Yso and Yso.queue or nil
  local used_queue = false
  local wants_compound = _trim(emit_payload.bal) ~= "" and _trim(emit_payload.class) ~= "" and cmd:find("&&command ", 1, true) ~= nil
  if wants_compound then
    local sent, err = _safe_send(cmd)
    if not sent then return false, err end
  elseif Q and type(Q.emit) == "function" then
    local ok, res = pcall(Q.emit, emit_payload)
    if not ok then return false, res end
    if res ~= true then return false, "queue_emit_failed" end
    used_queue = true
  else
    local sent, err = _safe_send(cmd)
    if not sent then return false, err end
  end

  if Yso and Yso.locks and type(Yso.locks.note_send) == "function" then
    if _trim(emit_payload.eq) ~= "" then pcall(Yso.locks.note_send, "eq") end
    if _trim(emit_payload.bal) ~= "" then pcall(Yso.locks.note_send, "bal") end
    if not used_queue and _trim(emit_payload.class) ~= "" then
      pcall(Yso.locks.note_send, "class")
    end
  end
  if not used_queue and _trim(emit_payload.class) ~= "" and Yso and Yso.state and type(Yso.state.set_ent_ready) == "function" then
    pcall(Yso.state.set_ent_ready, false, "party_aff:fallback_emit")
  end

  return true, cmd
end

local function _set_loop_enabled(on)
  local enabled = (on == true)
  PA.state.enabled = enabled
  PA.state.loop_enabled = enabled
  PA.state.loop_delay = tonumber(PA.state.loop_delay or PA.cfg.loop_delay or 0.15) or 0.15
  PA.state.waiting = PA.state.waiting or { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 }
  PA.state.last_attack = PA.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" }
  PA.state.in_flight = PA.state.in_flight or { fingerprint = "", target = "", route = "party_aff", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" }
  PA.state.debug = PA.state.debug or { last_no_send_reason = "", last_retry_reason = "" }
  return enabled
end

local function _clear_waiting()
  PA.state.waiting = PA.state.waiting or {}
  PA.state.waiting.queue = nil
  PA.state.waiting.main_lane = nil
  PA.state.waiting.lanes = nil
  PA.state.waiting.fingerprint = ""
  PA.state.waiting.reason = ""
  PA.state.waiting.at = 0
  PA.state.in_flight = PA.state.in_flight or {}
  PA.state.in_flight.resolved_at = _now()
  PA.state.in_flight.fingerprint = ""
  PA.state.in_flight.target = ""
  PA.state.in_flight.lanes = nil
  PA.state.in_flight.eq = ""
  PA.state.in_flight.entity = ""
  PA.state.in_flight.reason = ""
end

local function _kill_loop_timer()
  if PA.state and PA.state.timer_id then
    pcall(killTimer, PA.state.timer_id)
    PA.state.timer_id = nil
  end
end

local function _eq_lane_score(cat)
  cat = tostring(cat or "")
  if cat == "defense_break" then return 122 end
  if cat == "mental_pressure" then return 40 end
  if cat == "mana_drain" then return 38 end
  return 36
end

local function _bal_lane_score(cat)
  cat = tostring(cat or "")
  if cat == "mental_pressure" then return 22 end
  return 16
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

_payload_line = function(payload)
  if type(payload) ~= "table" or type(payload.lanes) ~= "table" then return "" end
  local lanes = payload.lanes
  local entity_cmd = _trim(lanes.entity or lanes.class)
  local card_a, card_b, card_tgt = _trim(lanes.bal):match("^outd%s+([%w_%-]+)%s*&&%s*fling%s+([%w_%-]+)%s+at%s+(.+)$")
  local cmds = {}
  if _trim(lanes.free) ~= "" then cmds[#cmds + 1] = _trim(lanes.free) end
  if _trim(lanes.eq) ~= "" then cmds[#cmds + 1] = _trim(lanes.eq) end
  if _trim(card_a) ~= "" and card_a == card_b and _lc(card_tgt or "") == _lc(payload.target or "") and entity_cmd ~= "" then
    cmds[#cmds + 1] = ("outd %s&&%s&&fling %s at %s"):format(card_a, entity_cmd, card_a, payload.target)
    return table.concat(cmds, _command_sep())
  end
  if _trim(lanes.bal) ~= "" then cmds[#cmds + 1] = _trim(lanes.bal) end
  if entity_cmd ~= "" then cmds[#cmds + 1] = entity_cmd end
  return table.concat(cmds, _command_sep())
end

local function _route_gate_finalize(payload, ctx, tgt)
  if not (Yso and Yso.route_gate and type(Yso.route_gate.finalize) == "function") then
    return payload, nil
  end
  return Yso.route_gate.finalize(payload, {
    route = "party_aff",
    target = tgt,
    lane_ready = {
      eq = _eq_ready(),
      bal = _bal_ready(),
      entity = _ent_ready(),
    },
    required_entities = {
      sycophant = _has_aff(tgt, "manaleech") == true,
    },
    ctx = ctx,
  })
end

local function _shieldbreak_tag(tgt)
  return "pa:eq:shieldbreak:" .. _lc(tgt)
end

local function _final_pre_emit_payload(payload)
  if type(payload) ~= "table" or type(payload.lanes) ~= "table" then return payload, nil end
  local tgt = _trim(payload.target)
  if tgt == "" then return payload, nil end

  payload.meta = payload.meta or {}
  local lanes = payload.lanes

  if _shield_is_up(tgt) then
    local tag = _shieldbreak_tag(tgt)
    local S = _offense_state()
    local lockout = tonumber(PA.cfg.shieldbreak_lockout_s or 1.0) or 1.0
    if _recent_sent(tag, lockout) then
      _note_no_send_reason("duplicate_action_suppressed")
      return nil, "duplicate_action_suppressed"
    end
    if S and type(S.locked) == "function" then
      local ok, locked = pcall(S.locked, tag)
      if ok and locked == true then
        _note_no_send_reason("duplicate_action_suppressed")
        return nil, "duplicate_action_suppressed"
      end
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
    payload.meta.shieldbreak_override = tag
    _note_retry_reason("retry_shieldbreak")
    return payload, nil
  end

  if _trim(lanes.eq) ~= "" and _trim(lanes.entity or lanes.class) == "" and _ent_ready() then
    local entity_cmd, entity_cat = _plan_entity(tgt)
    if _trim(entity_cmd) ~= "" then
      lanes.entity = entity_cmd
      payload.meta.entity_category = entity_cat
      _note_retry_reason("retry_entity_ready")
    end
  end

  return payload, nil
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
  PA.state.last_attack = PA.state.last_attack or {}
  PA.state.last_attack.cmd = _trim(cmd)
  PA.state.last_attack.at = _now()
  PA.state.last_attack.target = _trim(type(payload) == "table" and payload.target or "")
  PA.state.last_attack.main_lane = main_lane
  PA.state.last_attack.lanes = lanes
  PA.state.last_attack.fingerprint = fingerprint
  PA.state.waiting = PA.state.waiting or {}
  PA.state.waiting.queue = PA.state.last_attack.cmd
  PA.state.waiting.main_lane = main_lane
  PA.state.waiting.lanes = lanes
  PA.state.waiting.fingerprint = fingerprint
  PA.state.waiting.reason = wait_reason
  PA.state.waiting.at = PA.state.last_attack.at
  PA.state.in_flight = PA.state.in_flight or {}
  PA.state.in_flight.fingerprint = fingerprint
  PA.state.in_flight.target = PA.state.last_attack.target
  PA.state.in_flight.route = "party_aff"
  PA.state.in_flight.at = PA.state.last_attack.at
  PA.state.in_flight.lanes = lanes
  PA.state.in_flight.eq = _trim(type(payload) == "table" and payload.lanes and payload.lanes.eq or "")
  PA.state.in_flight.entity = _trim(type(payload) == "table" and payload.lanes and (payload.lanes.entity or payload.lanes.class) or "")
  PA.state.in_flight.reason = wait_reason
end

local function _waiting_blocks_tick()
  local wait = PA.state.waiting or {}
  local queued = _trim(wait.queue)
  if queued == "" then return false end
  if (_now() - (tonumber(wait.at) or 0)) >= 3.0 then
    _clear_waiting()
    return false
  end
  local lanes = wait.lanes
  if type(lanes) == "table" and #lanes > 0 then
    local blocked_eq, blocked_ent = false, false
    for i = 1, #lanes do
      if not _lane_ready(lanes[i]) then
        if lanes[i] == "eq" then blocked_eq = true end
        if lanes[i] == "class" then blocked_ent = true end
        local reason = "waiting_outcome"
        if blocked_eq and not blocked_ent and #lanes == 1 then
          reason = "waiting_eq"
        elseif blocked_ent and not blocked_eq and #lanes == 1 then
          reason = "waiting_ent"
        end
        wait.reason = reason
        if PA.state.in_flight then PA.state.in_flight.reason = reason end
        _note_no_send_reason(reason)
        return true
      end
    end
    if blocked_ent or table.concat(lanes, ","):find("class", 1, true) then
      _note_retry_reason("retry_entity_ready")
    end
    _clear_waiting()
    return false
  end
  local lane = _lc(wait.main_lane or "")
  if lane == "eq" then
    if _eq_ready() then _clear_waiting(); return false end
    wait.reason = "waiting_eq"
    if PA.state.in_flight then PA.state.in_flight.reason = wait.reason end
    _note_no_send_reason(wait.reason)
    return true
  end
  if lane == "bal" then
    if _bal_ready() then _clear_waiting(); return false end
    wait.reason = "waiting_outcome"
    if PA.state.in_flight then PA.state.in_flight.reason = wait.reason end
    _note_no_send_reason(wait.reason)
    return true
  end
  if lane == "entity" or lane == "class" then
    if _ent_ready() then
      _note_retry_reason("retry_entity_ready")
      _clear_waiting()
      return false
    end
    wait.reason = "waiting_ent"
    if PA.state.in_flight then PA.state.in_flight.reason = wait.reason end
    _note_no_send_reason(wait.reason)
    return true
  end
  _clear_waiting()
  return false
end

local function _same_attack_is_hot(cmd)
  cmd = _trim(cmd)
  if cmd == "" then return false end
  local last = PA.state.last_attack or {}
  if _trim(last.cmd) ~= cmd then return false end
  local hot_window = math.max(0.20, (tonumber(PA.state.loop_delay or PA.cfg.loop_delay or 0.15) or 0.15) + 0.05)
  return (_now() - (tonumber(last.at) or 0)) < hot_window
end

local function _plan_eq(tgt, opts)
  if not _eq_ready() then return nil, nil, nil, nil end

  local tag_prefix = "pa:eq:"
  local tkey = _lc(tgt)
  local seq = _sequence_plan(tgt, opts)
  local bootstrap_pending = (type(opts) == "table" and opts.loyals_bootstrap_pending == true)

  if bootstrap_pending and type(AP.bootstrap_readaura_plan) == "function" then
    local plan_tbl = { loyals_bootstrap_pending = true, readaura_via_loyals = true }
    local ra_cmd, ra_cat, ra_tag, ra_lock = AP.bootstrap_readaura_plan(tgt, plan_tbl)
    if ra_cmd then
      return ra_cmd, "team_coordination", ra_tag, ra_lock
    end
  end

  if seq.enabled and seq.needs_readaura == true then
    if type(AP.readaura_plan) == "function" then
      local ra_cmd, ra_cat, ra_tag, ra_lock = AP.readaura_plan(tgt, seq, false)
      if ra_cmd then
        return ra_cmd, "team_coordination", ra_tag, ra_lock
      end
    end
    return nil, nil, nil, nil
  end

  if seq.enabled and seq.deaf == true then
    local tag = tag_prefix .. "attend:" .. tkey
    local lock = tonumber(PA.cfg.attend_lockout_s or 2.3) or 2.3
    if not _recent_sent(tag, lock) then
      return ("attend %s"):format(tgt), "mental_pressure", tag, lock
    end
  end

  if seq.enabled and seq.unnamable_pending == true then
    local tag = tag_prefix .. "unnamable:" .. tkey
    local lock = tonumber(PA.cfg.unnamable_lockout_s or 4.0) or 4.0
    if not _recent_sent(tag, lock) then
      return "unnamable speak", "mental_pressure", tag, lock
    end
  end

  if seq.enabled and seq.cleanseaura_ready == true and _has_aff(tgt, "manaleech") and seq.can_utter ~= true then
    local tag = _cleanseaura_tag(tgt)
    local lock = tonumber(PA.cfg.cleanseaura_lockout_s or 4.1) or 4.1
    if not _recent_sent(tag, lock) then
      return ("cleanseaura %s"):format(tgt), "truename_acquire", tag, lock
    end
  end

  if seq.enabled and seq.can_utter == true then
    if seq.speed == true and not _recent_sent(_pin_tag(tgt), tonumber(PA.cfg.speed_hold_s or 3.2) or 3.2) then
      return ("pinchaura %s speed"):format(tgt), "speed_strip_window", _pin_tag(tgt), tonumber(PA.cfg.pinchaura_lockout_s or 4.1) or 4.1
    end
    local tag = _utter_tag(tgt)
    local lock = tonumber(PA.cfg.utter_follow_s or 5.0) or 5.0
    if not _recent_sent(tag, lock) then
      return ("utter truename %s"):format(tgt), "reserved_burst", tag, lock
    end
  end

  if seq.enabled then
    return nil, nil, nil, nil
  end

  if _shield_is_up(tgt) then
    local tag = tag_prefix .. "shieldbreak:" .. tkey
    local lock = tonumber(PA.cfg.shieldbreak_lockout_s or 1.0)
    if not _recent_sent(tag, lock) then
      local cmd = ("command gremlin at %s"):format(tgt)
      if Yso and Yso.off and Yso.off.util and type(Yso.off.util.maybe_shieldbreak) == "function" then
        local ok, v = pcall(Yso.off.util.maybe_shieldbreak, tgt)
        local c = _trim(ok and v or "")
        if c ~= "" then cmd = c end
      end
      return cmd, "defense_break", tag, lock
    end
  end

  local lock_count = _focus_lock_count(tgt)
  local stable = _lock_stable(tgt)

  if stable and _has_aff(tgt, "manaleech") then
    local needs_ra = type(AP.needs_readaura) == "function" and AP.needs_readaura(tgt) or false
    if needs_ra and type(AP.readaura_plan) == "function" then
      local ra_cmd, ra_cat, ra_tag, ra_lock = AP.readaura_plan(tgt, nil, false)
      if ra_cmd then
        return ra_cmd, "team_coordination", ra_tag, ra_lock
      end
    end
  end

  if lock_count >= tonumber(PA.cfg.attend_aff_floor or 3) then
    local tag = tag_prefix .. "attend:" .. tkey
    local lock = tonumber(PA.cfg.attend_lockout_s or 2.3)
    if not _recent_sent(tag, lock) then
      return ("attend %s"):format(tgt), "mental_pressure", tag, lock
    end
  end

  if not _has_aff(tgt, "manaleech") and _lock_stable(tgt) then
    local tag = tag_prefix .. "enervate:" .. tkey
    local lock = tonumber(PA.cfg.enervate_lockout_s or 4.0)
    if not _recent_sent(tag, lock) then
      return ("enervate %s"):format(tgt), "mana_drain", tag, lock
    end
  end

  local skip_aff = _trim(type(opts) == "table" and opts.skip_aff or "")
  local missing = _first_missing_lock_aff(tgt, skip_aff)
  if missing then
    local tag = tag_prefix .. "instill:" .. tkey .. ":" .. missing
    local lock = tonumber(PA.cfg.instill_lockout_s or 2.5)
    if not _recent_sent(tag, lock) then
      return ("instill %s with %s"):format(tgt, missing), "lock_pressure", tag, lock
    end
  end

  return nil, nil, nil, nil
end

local function _plan_bal(tgt, opts)
  if not _bal_ready() then return nil, nil end
  local seq = _sequence_plan(tgt, opts)

  if seq.enabled then
    if seq.deaf == false then
      return ("outd moon&&fling moon at %s"):format(tgt), "mental_pressure"
    end
    return nil, nil
  end

  if not _lock_stable(tgt) then return nil, nil end

  if not _has_aff(tgt, "manaleech") then
    return ("ruinate lovers at %s"):format(tgt), "mana_drain"
  end

  if _mental_score() < tonumber(PA.cfg.mental_target or 3) then
    return ("outd moon&&fling moon at %s"):format(tgt), "mental_pressure"
  end

  return nil, nil
end

_plan_entity = function(tgt, opts)
  if not _ent_ready() then return nil, nil end
  local seq = _sequence_plan(tgt, opts)

  if seq.enabled then
    local eq_tag = _trim(type(opts) == "table" and opts.eq_tag or "")
    local eq_cmd = _trim(type(opts) == "table" and opts.eq_cmd or "")
    local is_setup_eq = (eq_tag:find(":readaura:", 1, true) ~= nil)
      or (eq_tag:find(":unnamable:", 1, true) ~= nil)
      or (eq_tag:find(":cleanseaura:", 1, true) ~= nil)
      or (eq_tag:find(":pinchaura:", 1, true) ~= nil)
      or (eq_tag:find(":utter:", 1, true) ~= nil)
      or (eq_cmd:find("^readaura%s+") ~= nil)
      or (eq_cmd:find("^unnamable%s+") ~= nil)
      or (eq_cmd:find("^cleanseaura%s+") ~= nil)
      or (eq_cmd:find("^pinchaura%s+") ~= nil)
      or (eq_cmd:find("^utter%s+truename%s+") ~= nil)
    if is_setup_eq then return nil, nil end

    if seq.deaf == true or seq.deaf == false then
      return ("command chimera at %s"):format(tgt), "mental_pressure"
    end
    return nil, nil
  end

  local ES = _entity_refresh_state(tgt)
  local ER = ES.registry
  if ER and type(ER.target_swap) == "function" then pcall(ER.target_swap, tgt) end

  local eq_aff = _trim(type(opts) == "table" and opts.eq_aff or "")
  local missing = _first_missing_lock_aff(tgt, eq_aff)
  if missing then
    local cmd = _entity_cmd_for_aff(missing, tgt)
    if cmd then return cmd, "lock_pressure" end
  end

  if _has_aff(tgt, "manaleech") and ES.syc_refresh then
    return ("command sycophant at %s"):format(tgt), "mana_drain"
  end

  local ER2 = Yso and Yso.off and Yso.off.oc and Yso.off.oc.entity_registry or nil
  if ER2 and type(ER2.pick) == "function" then
    local ctx = {
      route = "party_aff",
      target = tgt,
      target_valid = _tgt_valid(tgt),
      ent_ready = true,
      eq_ready = _eq_ready(),
      bal_ready = _bal_ready(),
      has_aff = function(a) return _has_aff(tgt, a) end,
      category = "entity_support",
      need = {},
    }
    local ok, cand = pcall(ER2.pick, ctx)
    if ok and type(cand) == "table" and cand.cmd then
      return cand.cmd, cand.category or "entity_support"
    end
  end

  return nil, nil
end

local function _plan_free(tgt)
  if _loyals_active_for(tgt) then return nil, nil end
  local cmd = (tostring(PA.cfg.loyals_on_cmd or "order entourage kill %s")):format(tgt)
  return cmd, "team_coordination"
end

function PA.schedule_loop(delay)
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    return Yso.mode.schedule_route_loop("party_aff", delay)
  end
  return false
end

PA.alias_loop_stop_details = PA.alias_loop_stop_details or {
  inactive = true,
  disabled = true,
  policy = true,
}

function PA.alias_loop_prepare_start(ctx)
  PA.init()
  return ctx or {}
end

function PA.alias_loop_on_started(ctx)
  PA.state.busy = false
  _clear_waiting()
  _echo("Party aff loop ON.")
  local tgt = _target()
  if tgt == "" then
    _echo("No target yet; holding.")
  elseif not _tgt_valid(tgt) then
    _echo(string.format("%s is not in room; holding.", tgt))
  end
end

function PA.alias_loop_on_stopped(ctx)
  PA.init()
  ctx = ctx or {}
  local reason = tostring(ctx.reason or "manual")
  if ctx.silent ~= true then
    _echo(string.format("Party aff loop OFF (%s).", reason))
  end
end

function PA.alias_loop_clear_waiting()
  return _clear_waiting()
end

function PA.alias_loop_waiting_blocks()
  return _waiting_blocks_tick()
end

function PA.alias_loop_on_error(err)
  _echo("Party aff loop error: " .. tostring(err))
end

function PA.tick(reasons)
  return false
end

function PA.init()
  PA.cfg = PA.cfg or {}
  PA.state = PA.state or {}
  PA.state.loyals_sent_for = _trim(PA.state.loyals_sent_for or "")
  PA.state.unnamable_sent_for = _trim(PA.state.unnamable_sent_for or "")
  PA.state.template = PA.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  PA.state.waiting = PA.state.waiting or { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 }
  PA.state.last_attack = PA.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" }
  PA.state.in_flight = PA.state.in_flight or { fingerprint = "", target = "", route = "party_aff", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" }
  PA.state.debug = PA.state.debug or { last_no_send_reason = "", last_retry_reason = "" }
  PA.state.busy = (PA.state.busy == true)
  PA.state.loop_delay = tonumber(PA.state.loop_delay or PA.cfg.loop_delay or 0.15) or 0.15
  _set_loop_enabled((PA.state.loop_enabled == true) or (PA.state.enabled == true))
  return true
end

function PA.reset(reason)
  PA.init()
  PA.state.explain = {}
  PA.state.last_target = ""
  PA.state.loyals_sent_for = ""
  PA.state.unnamable_sent_for = ""
  PA.state.busy = false
  _clear_waiting()
  PA.state.last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" }
  PA.state.in_flight = { fingerprint = "", target = "", route = "party_aff", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" }
  PA.state.debug = { last_no_send_reason = "", last_retry_reason = "" }
  PA.state.template.last_reason = tostring(reason or "manual")
  PA.state.template.last_payload = nil
  return true
end

function PA.is_enabled() return PA.state and (PA.state.enabled == true or PA.state.loop_enabled == true) end
function PA.is_active()  return _route_is_active() end

function PA.can_run(ctx)
  PA.init()
  if not PA.is_enabled() then return false, "disabled" end
  if not PA.is_active() then return false, "inactive" end
  if not _automation_allowed() then return false, "policy" end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return false, "paused" end
  if Yso and Yso.mode and type(Yso.mode.is_hunt) == "function" and Yso.mode.is_hunt() then return false, "hunt_mode" end
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

function PA.attack_function(arg)
  local ctx, preview = _attack_opts(arg)
  local ok, info = PA.can_run(ctx)
  if not ok then
    if preview then return nil, info end
    return false, info
  end
  if not preview and _waiting_blocks_tick() then
    return false, PA.state and PA.state.waiting and PA.state.waiting.reason or "waiting_outcome"
  end
  local tgt = info
  local free_cmd, free_cat = _plan_free(tgt)
  local loyals_bootstrap_pending = (_trim(free_cmd) ~= "")
  local seq = _sequence_plan(tgt, { loyals_bootstrap_pending = loyals_bootstrap_pending })
  local preview_eq_cmd, preview_eq_cat, preview_eq_tag, preview_eq_lock = _plan_eq(tgt, {
    loyals_bootstrap_pending = loyals_bootstrap_pending,
    sequence = seq,
  })
  local bal_cmd, bal_cat = _plan_bal(tgt, {
    sequence = seq,
  })
  local main = _choose_main_lane(preview_eq_cmd, preview_eq_cat, bal_cmd, bal_cat)
  local selected_eq = (main.lane == "eq") and main.cmd or nil
  local selected_bal = (main.lane == "bal") and main.cmd or nil
  local eq_aff = _trim((selected_eq or ""):match("^instill%s+.-%s+with%s+([%w_%-]+)$"))
  local eq_cmd, eq_cat, eq_tag, eq_lock = preview_eq_cmd, preview_eq_cat, preview_eq_tag, preview_eq_lock
  if main.lane ~= "eq" then
    eq_cmd, eq_cat, eq_tag, eq_lock = nil, nil, nil, nil
  end
  local class_cmd, class_cat = _plan_entity(tgt, {
    sequence = seq,
    eq_cmd = selected_eq,
    eq_tag = eq_tag,
    eq_aff = eq_aff,
  })
  local bal_only_tick = (seq.enabled == true and seq.bal_only_tick == true and _trim(bal_cmd) ~= "" and _trim(eq_cmd) == "" and _trim(free_cmd) == "")
  if bal_only_tick then
    class_cmd, class_cat = nil, nil
  end
  local main_lane = main.lane
  if main_lane == "" and _trim(class_cmd) ~= "" then main_lane = "entity" end
  if main_lane == "" and _trim(free_cmd) ~= "" then main_lane = "free" end
  local payload = {
    route = "party_aff",
    target = tgt,
    lanes = { free = free_cmd, eq = selected_eq, bal = selected_bal, entity = class_cmd },
    meta = {
      free_category = free_cat,
      eq_category = (main.lane == "eq") and main.category or nil,
      bal_category = (main.lane == "bal") and main.category or nil,
      entity_category = class_cat,
      main_lane = main_lane,
      main_category = main.category,
      bal_only_tick = (bal_only_tick == true),
      free_parts = (_trim(free_cmd) ~= "") and {
        { cmd = free_cmd, offense = true },
      } or nil,
    },
  }
  payload, _ = _route_gate_finalize(payload, ctx, tgt)
  PA.state.last_target = tgt
  local gate = type(payload) == "table" and (payload._route_gate or (payload.meta and payload.meta.route_gate)) or nil
  PA.state.explain = {
    route = "party_aff",
    target = tgt,
    focus_lock_count = _focus_lock_count(tgt),
    lock_stable = _lock_stable(tgt),
    manaleech = _has_aff(tgt, "manaleech"),
    loyals_bootstrap_pending = loyals_bootstrap_pending,
    mental_score = _mental_score(),
    sequence = {
      enabled = (seq.enabled == true),
      needs_readaura = (seq.needs_readaura == true),
      readaura_reason = tostring(seq.readaura_reason or ""),
      deaf = seq.deaf,
      speed = seq.speed,
      mana_pct = seq.mana_pct,
      can_utter = (seq.can_utter == true),
      cleanseaura_ready = (seq.cleanseaura_ready == true),
      unnamable_pending = (seq.unnamable_pending == true),
      bal_only_tick = (bal_only_tick == true),
    },
    planned = gate and gate.planned and gate.planned.lanes or { free = free_cmd, eq = eq_cmd, bal = bal_cmd, entity = class_cmd },
    gated = gate and gate.gated and gate.gated.lanes or (payload and payload.lanes) or {},
    categories = { free = free_cat, eq = eq_cat, bal = bal_cat, entity = class_cat },
    blocked_reasons = gate and gate.blocked_reasons or {},
    hindrance = gate and gate.hinder or {},
    required_entities = gate and gate.entities and gate.entities.required or {},
    entity_obligations = gate and gate.entities and gate.entities.obligations or {},
    emitted = gate and gate.emitted or {},
    confirmed = gate and gate.confirmed or {},
  }
  PA.state.template.last_payload = payload
  PA.state.template.last_target = tgt
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
  if not emit_payload then return false, emit_err or "empty" end
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
  local sent, err = _emit_payload(emit_payload)
  if not sent then
    _note_retry_reason("retry_hard_fail")
    return false, err
  end
  PA.state.template.last_emitted_payload = emit_payload
  if Yso and Yso.route_gate and type(Yso.route_gate.note_emitted) == "function" then
    pcall(Yso.route_gate.note_emitted, payload, emit_payload, ctx)
  end
  if emit_payload.meta and type(emit_payload.meta.shieldbreak_override) == "string" then
    local S = _offense_state()
    if S and type(S.note) == "function" then
      pcall(S.note, emit_payload.meta.shieldbreak_override, cmd, {
        lockout = tonumber(PA.cfg.shieldbreak_lockout_s or 1.0) or 1.0,
        state_sig = "party_aff:shieldbreak",
      })
    end
  end
  PA.on_sent(emit_payload, ctx)
  _remember_attack(cmd, emit_payload)
  return true, cmd, payload
end

function PA.on_sent(payload, ctx)
  PA.init()
  if type(payload) ~= "table" then return true end
  local tgt = _trim(payload.target or (ctx and ctx.target) or "")
  if tgt ~= "" then
    local loyals_cmd = (tostring(PA.cfg.loyals_on_cmd or "order entourage kill %s")):format(tgt)
    local free = payload.lanes and payload.lanes.free or payload.free
    if type(free) == "string" and free == loyals_cmd then
      PA.state.loyals_sent_for = tgt
      _set_loyals_hostile(true, tgt)
    end
    local eq_lane = payload.lanes and payload.lanes.eq or payload.eq
    local readaura_cmd = ("readaura %s"):format(tgt)
    if type(eq_lane) == "string" and eq_lane == readaura_cmd and Yso and Yso.occ then
      if type(Yso.occ.aura_begin) == "function" then
        pcall(Yso.occ.aura_begin, tgt, "party_aff_send")
      end
      if type(Yso.occ.set_readaura_ready) == "function" then
        pcall(Yso.occ.set_readaura_ready, false, "sent")
      end
    elseif type(eq_lane) == "string" and _trim(eq_lane) == "unnamable speak" then
      PA.state.unnamable_sent_for = tgt
    end
  end
  local class_lane = payload.lanes and (payload.lanes.class or payload.lanes.entity) or payload.class or payload.entity
  if class_lane and Yso and Yso.off and Yso.off.oc and Yso.off.oc.entity_registry
    and type(Yso.off.oc.entity_registry.note_payload_sent) == "function" then
    pcall(Yso.off.oc.entity_registry.note_payload_sent, { class = class_lane })
  end
  return true
end

function PA.build_payload(ctx)
  return PA.attack_function({ ctx = ctx, preview = true })
end

function PA.evaluate(ctx)
  local payload, why = PA.build_payload(ctx)
  if not payload then return { ok = false, reason = why } end
  return { ok = true, payload = payload }
end

function PA.explain()
  local ex = PA.state and PA.state.explain or {}
  ex.route = ex.route or "party_aff"
  ex.route_enabled = PA.is_enabled()
  ex.active = PA.is_active()
  ex.waiting = PA.state and PA.state.waiting or {}
  ex.in_flight = PA.state and PA.state.in_flight or {}
  ex.last_no_send_reason = PA.state and PA.state.debug and PA.state.debug.last_no_send_reason or ""
  ex.last_retry_reason = PA.state and PA.state.debug and PA.state.debug.last_retry_reason or ""
  return ex
end

function PA.status()
  local snapshot = {
    route = "party_aff",
    enabled = PA.is_enabled(),
    active = PA.is_active(),
    target = _target(),
    focus_lock_count = _focus_lock_count(_target()),
    explain = PA.explain(),
  }
  if type(cecho) == "function" then
    local line = string.format("<dark_orchid>[Occultism] <reset>party aff enabled=%s active=%s target=%s lock=%d no_send=%s retry=%s",
      tostring(snapshot.enabled), tostring(snapshot.active), tostring(snapshot.target), snapshot.focus_lock_count,
      tostring(PA.state and PA.state.debug and PA.state.debug.last_no_send_reason or ""),
      tostring(PA.state and PA.state.debug and PA.state.debug.last_retry_reason or ""))
    if Yso and Yso.util and type(Yso.util.cecho_line) == "function" then
      Yso.util.cecho_line(line)
    else
      cecho(line .. "\n")
    end
  end
  return snapshot
end

function PA.on_enter(ctx)   PA.init(); return true end
function PA.on_exit(ctx)
  if Yso and Yso.mode and type(Yso.mode.stop_route_loop) == "function" then
    Yso.mode.stop_route_loop("party_aff", "exit", true)
  end
  PA.reset("exit")
  return true
end
function PA.on_pause(ctx)   return true end
function PA.on_resume(ctx)
  if PA.state and PA.state.loop_enabled == true then
    PA.schedule_loop(0)
  end
  return true
end
function PA.on_manual_success(ctx) return true end
function PA.on_send_result(payload, ctx) return PA.on_sent(payload, ctx) end

function PA.on_target_swap(old_target, new_target)
  if _lc(old_target) ~= _lc(new_target) then
    PA.reset("target_swap")
    PA.state.last_target = _trim(new_target)
    if PA.state.loop_enabled == true then
      PA.schedule_loop(0)
    end
  end
  return true
end

do
  local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(PA, PA.route_contract)
  end
end

return PA
