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

  kelp_target_count = 3,
  mental_target = 3,
  asthma_stable_count = 2,

  attend_aff_floor = 3,
  shieldbreak_lockout_s = 1.0,
  attend_lockout_s = 2.3,
  instill_lockout_s = 2.5,
  enervate_lockout_s = 4.0,

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
  waiting = { queue = nil, main_lane = nil, lanes = nil, at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil },
  template = { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" },
  last_target = "",
  loyals_sent_for = "",
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
  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    if type(ak.shield) == "function" then
      local ok, v = pcall(ak.shield, tgt)
      if ok then
        if type(v) == "boolean" then return v end
        if tonumber(v) ~= nil then return tonumber(v) ~= 0 end
      end
    end
    local defs = ak.defs
    if type(defs) == "table" then
      local s = defs.shield
      if type(s) == "boolean" then return s end
    end
  end
  if Yso and Yso.shield and type(Yso.shield.is_up) == "function" then
    local ok, v = pcall(Yso.shield.is_up, tgt)
    if ok and v == true then return true end
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

local function _first_missing_lock_aff(tgt)
  local order = { "asthma", "haemophilia", "addiction", "clumsiness", "healthleech", "weariness", "sensitivity" }
  for i = 1, #order do
    if not _has_aff(tgt, order[i]) then return order[i] end
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
  if PA.cfg.echo and type(cecho) == "function" then
    cecho(string.format("<dark_orchid>[Occultism] <reset>%s\n", tostring(msg)))
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

  local emit_payload = {
    free = lane_tbl.free or lane_tbl.pre,
    eq = lane_tbl.eq,
    bal = lane_tbl.bal,
    class = lane_tbl.class or lane_tbl.ent or lane_tbl.entity,
  }
  local cmd = _payload_line({ lanes = emit_payload })
  if _trim(cmd) == "" then return false, "empty" end

  local Q = Yso and Yso.queue or nil
  local used_queue = false
  if Q and type(Q.emit) == "function" then
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
  PA.state.waiting = PA.state.waiting or { queue = nil, main_lane = nil, lanes = nil, at = 0 }
  PA.state.last_attack = PA.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil }
  return enabled
end

local function _clear_waiting()
  PA.state.waiting = PA.state.waiting or {}
  PA.state.waiting.queue = nil
  PA.state.waiting.main_lane = nil
  PA.state.waiting.lanes = nil
  PA.state.waiting.at = 0
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
  local cmds = {}
  if _trim(lanes.free) ~= "" then cmds[#cmds + 1] = _trim(lanes.free) end
  if _trim(lanes.eq) ~= "" then cmds[#cmds + 1] = _trim(lanes.eq) end
  if _trim(lanes.bal) ~= "" then cmds[#cmds + 1] = _trim(lanes.bal) end
  local entity_cmd = _trim(lanes.entity or lanes.class)
  if entity_cmd ~= "" then cmds[#cmds + 1] = entity_cmd end
  return table.concat(cmds, _command_sep())
end

local function _remember_attack(cmd, payload)
  local meta = type(payload) == "table" and (payload.meta or {}) or {}
  local main_lane = _lc(meta.main_lane or "")
  local lanes = _waiting_lanes_from_payload(payload)
  PA.state.last_attack = PA.state.last_attack or {}
  PA.state.last_attack.cmd = _trim(cmd)
  PA.state.last_attack.at = _now()
  PA.state.last_attack.target = _trim(type(payload) == "table" and payload.target or "")
  PA.state.last_attack.main_lane = main_lane
  PA.state.last_attack.lanes = lanes
  PA.state.waiting = PA.state.waiting or {}
  PA.state.waiting.queue = PA.state.last_attack.cmd
  PA.state.waiting.main_lane = main_lane
  PA.state.waiting.lanes = lanes
  PA.state.waiting.at = PA.state.last_attack.at
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
    for i = 1, #lanes do
      if not _lane_ready(lanes[i]) then
        return true
      end
    end
    _clear_waiting()
    return false
  end
  local lane = _lc(wait.main_lane or "")
  if lane == "eq" then
    if _eq_ready() then _clear_waiting(); return false end
    return true
  end
  if lane == "bal" then
    if _bal_ready() then _clear_waiting(); return false end
    return true
  end
  if lane == "entity" or lane == "class" then
    if _ent_ready() then _clear_waiting(); return false end
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

local function _plan_eq(tgt)
  if not _eq_ready() then return nil, nil, nil, nil end

  local tag_prefix = "pa:eq:"
  local tkey = _lc(tgt)

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
    local snap = nil
    if Yso and Yso.off and Yso.off.oc and Yso.off.oc.cleanseaura and type(Yso.off.oc.cleanseaura.snapshot) == "function" then
      local ok, s = pcall(Yso.off.oc.cleanseaura.snapshot, tgt)
      if ok then snap = s end
    end
    local needs_readaura = not snap or not snap.fresh or not snap.read_complete
    if needs_readaura and Yso and Yso.occ and type(Yso.occ.readaura_is_ready) == "function" then
      local ok, ready = pcall(Yso.occ.readaura_is_ready)
      if ok and ready == true then
        local tag = tag_prefix .. "readaura:" .. tkey
        if not _recent_sent(tag, 8) then
          return ("readaura %s"):format(tgt), "team_coordination", tag, 1.0
        end
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

  local missing = _first_missing_lock_aff(tgt)
  if missing then
    local tag = tag_prefix .. "instill:" .. tkey .. ":" .. missing
    local lock = tonumber(PA.cfg.instill_lockout_s or 2.5)
    if not _recent_sent(tag, lock) then
      return ("instill %s with %s"):format(tgt, missing), "lock_pressure", tag, lock
    end
  end

  return nil, nil, nil, nil
end

local function _plan_bal(tgt)
  if not _bal_ready() then return nil, nil end

  if not _lock_stable(tgt) then return nil, nil end

  if not _has_aff(tgt, "manaleech") then
    return ("ruinate lovers at %s"):format(tgt), "mana_drain"
  end

  if _mental_score() < tonumber(PA.cfg.mental_target or 3) then
    return ("outd moon&&fling moon at %s"):format(tgt), "mental_pressure"
  end

  return nil, nil
end

local function _plan_entity(tgt)
  if not _ent_ready() then return nil, nil end

  local ES = _entity_refresh_state(tgt)
  local ER = ES.registry
  if ER and type(ER.target_swap) == "function" then pcall(ER.target_swap, tgt) end

  local missing = _first_missing_lock_aff(tgt)
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
  if _lc(PA.state.loyals_sent_for or "") == _lc(tgt) then return nil, nil end
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
  PA.state.template = PA.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  PA.state.waiting = PA.state.waiting or { queue = nil, main_lane = nil, lanes = nil, at = 0 }
  PA.state.last_attack = PA.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil }
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
  PA.state.busy = false
  _clear_waiting()
  PA.state.last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil }
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
  local tgt = info
  local free_cmd, free_cat = _plan_free(tgt)
  local eq_cmd, eq_cat, eq_tag, eq_lock = _plan_eq(tgt)
  local bal_cmd, bal_cat = _plan_bal(tgt)
  local class_cmd, class_cat = _plan_entity(tgt)
  local main = _choose_main_lane(eq_cmd, eq_cat, bal_cmd, bal_cat)
  local selected_eq = (main.lane == "eq") and main.cmd or nil
  local selected_bal = (main.lane == "bal") and main.cmd or nil
  local main_lane = main.lane
  if main_lane == "" and _trim(class_cmd) ~= "" then main_lane = "entity" end
  if main_lane == "" and _trim(free_cmd) ~= "" then main_lane = "free" end
  local payload = {
    route = "party_aff",
    target = tgt,
    lanes = { free = free_cmd, eq = selected_eq, bal = selected_bal, entity = class_cmd },
    meta = {
      eq_category = (main.lane == "eq") and main.category or nil,
      bal_category = (main.lane == "bal") and main.category or nil,
      entity_category = class_cat,
      main_lane = main_lane,
      main_category = main.category,
    },
  }
  PA.state.last_target = tgt
  PA.state.explain = {
    route = "party_aff",
    target = tgt,
    focus_lock_count = _focus_lock_count(tgt),
    lock_stable = _lock_stable(tgt),
    manaleech = _has_aff(tgt, "manaleech"),
    mental_score = _mental_score(),
    planned = { free = free_cmd, eq = eq_cmd, bal = bal_cmd, class = class_cmd },
    categories = { free = free_cat, eq = eq_cat, bal = bal_cat, class = class_cat },
  }
  PA.state.template.last_payload = payload
  PA.state.template.last_target = tgt
  if not payload.lanes.free and not payload.lanes.eq and not payload.lanes.bal and not payload.lanes.entity then
    if preview then return nil, "empty" end
    return false, "empty"
  end
  if preview then return payload end
  local cmd = _payload_line(payload)
  if _trim(cmd) == "" then return false, "empty" end
  if _same_attack_is_hot(cmd) then return false, "hot_attack" end
  local sent, err = _emit_payload(payload)
  if not sent then return false, err end
  PA.on_sent(payload, ctx)
  _remember_attack(cmd, payload)
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
  return PA.state and PA.state.explain or {}
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
    cecho(string.format("<dark_orchid>[Occultism] <reset>party aff enabled=%s active=%s target=%s lock=%d\n",
      tostring(snapshot.enabled), tostring(snapshot.active), tostring(snapshot.target), snapshot.focus_lock_count))
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
