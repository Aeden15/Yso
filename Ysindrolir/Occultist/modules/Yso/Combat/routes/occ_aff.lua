--========================================================--
-- occ_aff.lua
--  Thin Occultist affliction loop (Sunder-style)
--  Canonical module: Yso.off.oc.occ_aff
--  Compatibility aliases: Yso.off.oc.aff, Yso.off.oc.occ_aff_burst
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

Yso.off.oc.occ_aff = Yso.off.oc.occ_aff or Yso.off.oc.aff or Yso.off.oc.occ_aff_burst or {}
Yso.off.oc.aff = Yso.off.oc.occ_aff
Yso.off.oc.occ_aff_burst = Yso.off.oc.occ_aff

local A = Yso.off.oc.occ_aff
A.alias_owned = true

A.route_contract = A.route_contract or {
  id = "occ_aff",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "open",
    "pressure",
    "maintain_pressure",
    "cleanse_truename",
    "whisper_enlighten",
    "unravel",
  },
  capabilities = {
    uses_eq = true,
    uses_bal = true,
    uses_entity = true,
    supports_burst = true,
    supports_bootstrap = true,
    needs_target = true,
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

A.cfg = A.cfg or {
  echo = true,
  enabled = false,
  loop_delay = 0.15,
  readaura_every = 8,
  max_observe = 3,
  enlighten_target = 5,
  unravel_mentals = 4,
  loyals_on_cmd = "order loyals kill %s",
  off_passive_cmd = "order loyals passive",

  -- Instill priority list for the EQ slot during open/pressure phase.
  -- Each entry is a plain aff name (string) or
  -- { aff = "name", cond = function(tgt, has) return bool end }
  -- for affs that require a condition before instilling.
  aff_prio = {
    "healthleech",
    "sensitivity",
    "asthma",
    { aff = "paralysis", cond = function(tgt, has) return has(tgt, "asthma") end },
    { aff = "slickness", cond = function(tgt, has) return has(tgt, "asthma") end },
    "clumsiness",
    "darkshade",
  },

  -- Entity pressure priority for the class/entity slot.
  -- Same structure + cmd pattern (%s = target name).
  ent_prio = {
    { aff = "asthma",      cmd = "command bubonis at %s" },
    { aff = "paralysis",   cmd = "command slime at %s",   cond = function(tgt, has) return has(tgt, "asthma") end },
    { aff = "slickness",   cmd = "command bubonis at %s", cond = function(tgt, has) return has(tgt, "asthma") end },
    { aff = "clumsiness",  cmd = "command storm at %s" },
    { aff = "healthleech", cmd = "command worm at %s" },
    { aff = "haemophilia", cmd = "command bloodleech at %s" },
    { aff = "weariness",   cmd = "command hound at %s" },
    { aff = "addiction",   cmd = "command humbug at %s" },
  },

  -- Convert-phase firelord conversions.
  -- Fires when src aff is present and dest aff is missing.
  ent_convert = {
    { src = "whisperingmadness",  dest = "recklessness",   cmd = "command firelord at %s recklessness" },
    { src = "whispering_madness", dest = "recklessness",   cmd = "command firelord at %s recklessness" },
    { src = "manaleech",          dest = "anorexia",       cmd = "command firelord at %s anorexia" },
    { src = "healthleech",        dest = "psychic_damage", cmd = "command firelord at %s psychic_damage" },
  },
}

A.state = A.state or {
  enabled = (A.cfg.enabled == true),
  loop_enabled = (A.cfg.enabled == true),
  busy = false,
  timer_id = nil,
  waiting = { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" },
  in_flight = { fingerprint = "", target = "", route = "occ_aff", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" },
  debug = { last_no_send_reason = "", last_retry_reason = "" },
  template = { last_payload = nil, last_emitted_payload = nil, last_target = "", last_reason = "", last_disable_reason = "" },
  loop_delay = tonumber(A.cfg.loop_delay or 0.15) or 0.15,
  last_target = "",
  last_readaura = 0,
  observe_tries = {},
  defer_unnamable = nil,
  explain = {},
}

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _lc(s)
  return _trim(s):lower()
end

-- #region agent log
local _DBG_FILE = "debug-c8972a.log"
local _DBG_SESSION = "c8972a"
local _DBG_RUN = "pre-fix-1"

local function _dbg_json(v)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "boolean" then return v and "true" or "false" end
  if t == "number" then return tostring(v) end
  if t == "string" then
    return '"' .. v:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\r", "\\r"):gsub("\n", "\\n") .. '"'
  end
  if t == "table" then
    local is_arr = true
    local max_i = 0
    for k, _ in pairs(v) do
      if type(k) ~= "number" then is_arr = false break end
      if k > max_i then max_i = k end
    end
    local out = {}
    if is_arr then
      for i = 1, max_i do out[#out + 1] = _dbg_json(v[i]) end
      return "[" .. table.concat(out, ",") .. "]"
    end
    for k, vv in pairs(v) do
      out[#out + 1] = _dbg_json(tostring(k)) .. ":" .. _dbg_json(vv)
    end
    return "{" .. table.concat(out, ",") .. "}"
  end
  return _dbg_json(tostring(v))
end

local function _dbg_log(hypothesis_id, location, message, data)
  local row = {
    sessionId = _DBG_SESSION,
    runId = _DBG_RUN,
    hypothesisId = tostring(hypothesis_id or ""),
    location = tostring(location or "occ_aff.lua"),
    message = tostring(message or ""),
    data = type(data) == "table" and data or { value = tostring(data or "") },
    timestamp = math.floor((os.time() or 0) * 1000),
  }
  local fh = io.open(_DBG_FILE, "a")
  if not fh then return end
  fh:write(_dbg_json(row), "\n")
  fh:close()
end
-- #endregion

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  if type(getEpoch) == "function" then
    local ok, v = pcall(getEpoch)
    v = ok and tonumber(v) or nil
    if v then
      if v > 1e12 then v = v / 1000 end
      return v
    end
  end
  return os.time()
end

local function _companions()
  local C = Yso and Yso.occ and Yso.occ.companions or nil
  return type(C) == "table" and C or nil
end

local function _echo_toggle(msg)
  if A.cfg.echo ~= true then return end
  local line = string.format("<orange>[Yso:Occultist] <HotPink>%s<reset>", tostring(msg))
  if Yso and Yso.util and type(Yso.util.cecho_line) == "function" then
    Yso.util.cecho_line(line)
  elseif type(cecho) == "function" then
    cecho(line .. "\n")
  elseif type(echo) == "function" then
    echo(("[Yso:Occultist] %s\n"):format(tostring(msg)))
  end
end

local function _eq()
  if Yso and Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then return v == true end
  end
  local vit = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(vit.eq or vit.equilibrium or "") == "1" or vit.eq == true or vit.equilibrium == true
end

local function _bal()
  if Yso and Yso.state and type(Yso.state.bal_ready) == "function" then
    local ok, v = pcall(Yso.state.bal_ready)
    if ok then return v == true end
  end
  local vit = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(vit.bal or vit.balance or "") == "1" or vit.bal == true or vit.balance == true
end

local function _ent()
  if Yso and Yso.state and type(Yso.state.ent_ready) == "function" then
    local ok, v = pcall(Yso.state.ent_ready)
    if ok then return v == true end
  end
  return true
end

local function _ra_due()
  local every = tonumber(A.cfg.readaura_every or 8) or 8
  return (_now() - (tonumber(A.state.last_readaura or 0) or 0)) >= every
end

local function _command_sep()
  local sep = _trim((Yso and (Yso.sep or (Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep)))) or "&&")
  if sep == "" then sep = "&&" end
  return sep
end

local function _attack_opts(arg)
  if type(arg) == "table" and (arg.preview ~= nil or arg.ctx ~= nil) then
    return arg.ctx, (arg.preview == true)
  end
  return arg, false
end

local function _payload_line(payload)
  local lanes = type(payload) == "table" and (payload.lanes or payload) or {}
  local parts = {}
  local free_lane = lanes.free or lanes.pre
  if type(free_lane) == "table" then
    for i = 1, #free_lane do
      local s = _trim(free_lane[i])
      if s ~= "" then parts[#parts + 1] = s end
    end
  elseif type(free_lane) == "string" then
    local s = _trim(free_lane)
    if s ~= "" then parts[#parts + 1] = s end
  end
  local eq_cmd = _trim(lanes.eq)
  local bal_cmd = _trim(lanes.bal)
  local ent_cmd = _trim(lanes.entity or lanes.class or lanes.ent)
  if eq_cmd ~= "" then parts[#parts + 1] = eq_cmd end
  if bal_cmd ~= "" then parts[#parts + 1] = bal_cmd end
  if ent_cmd ~= "" then parts[#parts + 1] = ent_cmd end
  return table.concat(parts, _command_sep())
end

local function _set_debug_field(key, value)
  A.state.debug = A.state.debug or { last_no_send_reason = "", last_retry_reason = "" }
  A.state.debug[key] = value
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
  local lane_tbl = type(payload) == "table" and (payload.lanes or payload) or {}

  local function add(name, cmd)
    name = _lc(name)
    if name == "entity" then name = "class" end
    if name == "" or name == "free" or seen[name] then return end
    if _trim(cmd) == "" then return end
    seen[name] = true
    lanes[#lanes + 1] = name
  end

  add("eq", lane_tbl.eq)
  add("bal", lane_tbl.bal)
  add("class", lane_tbl.class or lane_tbl.ent or lane_tbl.entity)
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
    "occ_aff",
    _lc(payload.target or ""),
    _trim(lanes.eq),
    _trim(lanes.entity or lanes.class or lanes.ent),
    _trim(lanes.bal),
    _trim(lanes.free),
  }, "|")
end

local function _same_attack_is_hot(cmd)
  cmd = _trim(cmd)
  if cmd == "" then return false end
  local last = A.state.last_attack or {}
  if _trim(last.cmd) ~= cmd then return false end
  local hot_window = math.max(0.10, (tonumber(A.state.loop_delay or A.cfg.loop_delay or 0.15) or 0.15) * 0.75)
  return (_now() - (tonumber(last.at) or 0)) < hot_window
end

local function _same_fingerprint_in_flight(payload)
  local fingerprint = _action_fingerprint(payload)
  local flight = A.state and A.state.in_flight or nil
  if fingerprint == "" or type(flight) ~= "table" then return false end
  if _trim(flight.fingerprint) == "" or _trim(flight.target) == "" then return false end
  if _lc(payload.target or "") ~= _lc(flight.target) then return false end
  if fingerprint ~= _trim(flight.fingerprint) then return false end
  local window = math.max(0.10, (tonumber(A.state.loop_delay or A.cfg.loop_delay or 0.15) or 0.15) * 0.9)
  return (_now() - (tonumber(flight.at) or 0)) < window
end

local function _loyals_active_for(tgt)
  local C = _companions()
  if C and type(C.is_active_for) == "function" then
    local ok, v = pcall(C.is_active_for, tgt)
    if ok then return v == true end
  end

  tgt = _trim(tgt)
  if tgt == "" then return false end
  if type(Yso.loyals_attack) == "function" then
    local ok, v = pcall(Yso.loyals_attack, tgt)
    if ok and v == true then return true end
  end
  if Yso and Yso.state then
    local hostile = (Yso.state.loyals_hostile == true)
    local keyed = _trim(Yso.state.loyals_target)
    if hostile and (keyed == "" or keyed:lower() == tgt:lower()) then
      return true
    end
  end
  return false
end

local function _loyals_any_active()
  local C = _companions()
  if C and type(C.is_any_active) == "function" then
    local ok, v = pcall(C.is_any_active)
    if ok then return v == true end
  end

  if type(Yso.loyals_attack) == "function" then
    local ok, v = pcall(Yso.loyals_attack)
    if ok and v == true then return true end
  end
  return (Yso and Yso.state and Yso.state.loyals_hostile == true) or false
end

local function _set_loyals_hostile(v, tgt)
  local C = _companions()
  if C and type(C.note_order_sent) == "function" then
    if v == true then
      local ok, handled = pcall(C.note_order_sent, ("order loyals kill %s"):format(_trim(tgt)), tgt)
      if ok and handled == true then return end
    else
      local ok, handled = pcall(C.note_order_sent, "order loyals passive", tgt)
      if ok and handled == true then return end
    end
  end

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

local function _emit_free(cmd, reason, tgt)
  cmd = _trim(cmd)
  if cmd == "" then return false end
  local payload = { free = { cmd }, eq = nil, bal = nil, class = nil, target = _trim(tgt) }
  local ok = false
  if type(Yso.emit) == "function" then
    local sent_ok, sent = pcall(Yso.emit, payload, { reason = reason or "occ_aff:free", kind = "offense", commit = true, target = tgt })
    ok = (sent_ok == true and sent == true)
  elseif Yso.queue and type(Yso.queue.emit) == "function" then
    local sent_ok, sent = pcall(Yso.queue.emit, payload, { reason = reason or "occ_aff:free", kind = "offense", commit = true, target = tgt })
    ok = (sent_ok == true and sent == true)
  elseif type(send) == "function" then
    local sent_ok, sent = pcall(send, cmd)
    ok = (sent_ok == true and sent ~= false)
  end
  return ok == true
end

local function _emit_payload(payload)
  local lane_tbl = type(payload) == "table" and (payload.lanes or payload) or nil
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

  if type(Yso.emit) == "function" then
    local ok = Yso.emit(emit_payload, {
      reason = "occ_aff:emit",
      kind = "offense",
      target = target,
      commit = true,
      allow_eqbal = true,
      prefer = "eq",
    }) == true
    if not ok then return false, "emit_failed" end
  else
    local Q = Yso and Yso.queue or nil
    if not (Q and type(Q.emit) == "function") then
      return false, "queue_emit_unavailable"
    end
    local ok, res = pcall(Q.emit, emit_payload, {
      reason = "occ_aff:emit",
      kind = "offense",
      target = target,
      commit = true,
      allow_eqbal = true,
      prefer = "eq",
    })
    if not ok then return false, res end
    if res ~= true then return false, "queue_emit_failed" end
  end

  return true, cmd
end

local function _route_gate_finalize(payload, ctx, tgt)
  if not (Yso and Yso.route_gate and type(Yso.route_gate.finalize) == "function") then
    return payload, nil
  end
  return Yso.route_gate.finalize(payload, {
    route = "occ_aff",
    target = tgt,
    lane_ready = {
      eq = _eq(),
      bal = _bal(),
      entity = _ent(),
    },
    required_entities = {},
    ctx = ctx,
  })
end

local function _final_pre_emit_payload(payload)
  if type(payload) ~= "table" or type(payload.lanes) ~= "table" then return payload, nil end
  local lanes = payload.lanes
  if lanes.entity == nil then lanes.entity = lanes.class or lanes.ent end
  if lanes.class == nil then lanes.class = lanes.entity end
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

  A.state.last_attack = A.state.last_attack or {}
  A.state.last_attack.cmd = _trim(cmd)
  A.state.last_attack.at = _now()
  A.state.last_attack.target = _trim(type(payload) == "table" and payload.target or "")
  A.state.last_attack.main_lane = main_lane
  A.state.last_attack.lanes = lanes
  A.state.last_attack.fingerprint = fingerprint

  A.state.waiting = A.state.waiting or {}
  A.state.waiting.queue = A.state.last_attack.cmd
  A.state.waiting.main_lane = main_lane
  A.state.waiting.lanes = lanes
  A.state.waiting.fingerprint = fingerprint
  A.state.waiting.reason = wait_reason
  A.state.waiting.at = A.state.last_attack.at

  A.state.in_flight = A.state.in_flight or {}
  A.state.in_flight.fingerprint = fingerprint
  A.state.in_flight.target = A.state.last_attack.target
  A.state.in_flight.route = "occ_aff"
  A.state.in_flight.at = A.state.last_attack.at
  A.state.in_flight.lanes = lanes
  A.state.in_flight.eq = _trim(type(payload) == "table" and payload.lanes and payload.lanes.eq or "")
  A.state.in_flight.entity = _trim(type(payload) == "table" and payload.lanes and (payload.lanes.entity or payload.lanes.class) or "")
  A.state.in_flight.reason = wait_reason

  if type(tempTimer) == "function" then
    local clear_after = math.max(0.10, tonumber(A.state.loop_delay or A.cfg.loop_delay or 0.15) or 0.15)
    pcall(tempTimer, clear_after, function()
      if A and type(A.alias_loop_clear_waiting) == "function" then
        pcall(A.alias_loop_clear_waiting)
      end
    end)
  end
end

local function _emit(payload)
  A.state.waiting = A.state.waiting or { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 }
  A.state.last_attack = A.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" }
  local line = _payload_line(payload)
  if line == "" then
    _note_no_send_reason("empty")
    return false, "empty"
  end
  if _same_fingerprint_in_flight(payload) then
    _note_no_send_reason("duplicate_action_suppressed")
    return false, "duplicate_action_suppressed"
  end
  if _same_attack_is_hot(line) then
    _note_no_send_reason("duplicate_action_suppressed")
    return false, "duplicate_action_suppressed"
  end

  local sent, err = _emit_payload(payload)
  if not sent then
    _note_retry_reason("retry_hard_fail")
    return false, err
  end
  _remember_attack(line, payload)
  return true, line
end

-- Check whether a target currently has an affliction.
-- Tries AK score export, affstrack, then Yso state APIs in that order.
local function _tgt_has(tgt, aff)
  tgt = _trim(tgt)
  aff = tostring(aff or ""):lower()
  if tgt == "" or aff == "" then return false end
  if Yso and Yso.oc and Yso.oc.ak and type(Yso.oc.ak.get_aff_score) == "function" then
    local ok, v = pcall(Yso.oc.ak.get_aff_score, aff)
    local n = ok and tonumber(v) or nil
    if n then return n >= 100 end
  end
  if type(affstrack) == "table" and type(affstrack.score) == "table" then
    local n = tonumber(affstrack.score[aff] or 0) or 0
    if n >= 100 then return true end
  end
  if Yso and Yso.tgt and type(Yso.tgt.has_aff) == "function" then
    local ok, v = pcall(Yso.tgt.has_aff, tgt, aff)
    if ok then return v == true end
  end
  if Yso and Yso.state and type(Yso.state.tgt_has_aff) == "function" then
    local ok, v = pcall(Yso.state.tgt_has_aff, tgt, aff)
    if ok then return v == true end
  end
  return false
end

-- Return current mental aff score (used for enlighten/unravel thresholds).
local function _mental_score()
  if Yso and Yso.oc and Yso.oc.ak and Yso.oc.ak.scores and type(Yso.oc.ak.scores.mental) == "function" then
    local ok, v = pcall(Yso.oc.ak.scores.mental)
    if ok then
      local n = tonumber(v)
      if n then return n end
    end
  end
  if type(affstrack) == "table" and type(affstrack.mentalscore) == "number" then
    return tonumber(affstrack.mentalscore) or 0
  end
  return 0
end

local function _target_mana_pct(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return nil end
  if Yso and Yso.tgt and type(Yso.tgt.get_mana_pct) == "function" then
    local ok, v = pcall(Yso.tgt.get_mana_pct, tgt)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  if Yso and Yso.state and type(Yso.state.tgt_mana_pct) == "function" then
    local ok, v = pcall(Yso.state.tgt_mana_pct, tgt)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  return nil
end

local function _cleanse_ready(tgt)
  local mana = _target_mana_pct(tgt)
  local cap = tonumber(A.cfg.mana_burst_pct or 40) or 40
  if mana ~= nil and mana <= cap then return true end

  if Yso and Yso.occ and type(Yso.occ.aura_need_attend) == "function" then
    local ok, v = pcall(Yso.occ.aura_need_attend, tgt)
    if ok and v == true then return true end
  end
  return false
end

local function _burst_ready(tgt, ctx)
  ctx = type(ctx) == "table" and ctx or {}
  local eq_cmd = _lc(ctx.eq_cmd or "")
  local mana = _target_mana_pct(tgt)
  local cap = tonumber(A.cfg.mana_burst_pct or 40) or 40
  local in_cleanseaura_window = (mana ~= nil and mana <= cap) or false
  if eq_cmd:match("^cleanseaura%s+") then
    -- #region agent log
    _dbg_log("H12", "occ_aff.lua:_burst_ready", "burst_ready_true", { reason = "eq_cleanseaura", target = tgt, mana = mana, cap = cap, in_window = in_cleanseaura_window })
    -- #endregion
    return true
  end
  if eq_cmd:match("^utter%s+truename%s+") then
    -- #region agent log
    _dbg_log("H12", "occ_aff.lua:_burst_ready", "burst_ready_true", { reason = "eq_utter_truename", target = tgt, mana = mana, cap = cap, in_window = in_cleanseaura_window })
    -- #endregion
    return true
  end

  if _cleanse_ready(tgt) ~= true then return false end

  if Yso and Yso.occ and Yso.occ.truebook and type(Yso.occ.truebook.can_utter) == "function" then
    local ok, v = pcall(Yso.occ.truebook.can_utter, tgt)
    if ok and v == true then
      -- #region agent log
      _dbg_log("H12", "occ_aff.lua:_burst_ready", "burst_ready_true", { reason = "truebook_can_utter", target = tgt, mana = mana, cap = cap, in_window = in_cleanseaura_window })
      -- #endregion
      return true
    end
  end

  if in_cleanseaura_window then
    -- #region agent log
    _dbg_log("H12", "occ_aff.lua:_burst_ready", "burst_ready_true", { reason = "mana_window", target = tgt, mana = mana, cap = cap, in_window = in_cleanseaura_window })
    -- #endregion
    return true
  end
  -- #region agent log
  _dbg_log("H12", "occ_aff.lua:_burst_ready", "burst_ready_false", { reason = "no_convert_window", target = tgt, mana = mana, cap = cap, in_window = in_cleanseaura_window, eq_cmd = eq_cmd })
  -- #endregion
  return false
end

-- Pick the next instill command for the EQ slot (open/pressure phase).
-- Walks A.cfg.aff_prio in order; respects per-entry conditions.
-- Falls through to whisperingmadness then devolve if all affs are present.
local function _pick_instill(tgt)
  for _, entry in ipairs(A.cfg.aff_prio or {}) do
    local aff  = type(entry) == "string" and entry or entry.aff
    local cond = type(entry) == "table"  and entry.cond or nil
    if not _tgt_has(tgt, aff) then
      if cond == nil or cond(tgt, _tgt_has) then
        return ("instill %s with %s"):format(tgt, aff)
      end
    end
  end
  if not (_tgt_has(tgt, "whisperingmadness") or _tgt_has(tgt, "whispering_madness")) then
    return ("whisperingmadness %s"):format(tgt)
  end
  return ("devolve %s"):format(tgt)
end

-- Pick the next entity command.
-- During convert/finish uses A.cfg.ent_convert (firelord conversions).
-- All other phases walk A.cfg.ent_prio in order.
local function _pick_entity(tgt, phase)
  phase = tostring(phase or ""):lower()
  if phase == "convert" or phase == "finish" then
    for _, entry in ipairs(A.cfg.ent_convert or {}) do
      if _tgt_has(tgt, entry.src) and not _tgt_has(tgt, entry.dest) then
        return entry.cmd:format(tgt)
      end
    end
    return nil
  end
  for _, entry in ipairs(A.cfg.ent_prio or {}) do
    if not _tgt_has(tgt, entry.aff) then
      if entry.cond == nil or entry.cond(tgt, _tgt_has) then
        return entry.cmd:format(tgt)
      end
    end
  end
  return nil
end

-- Pick the EQ command for convert/finish phase (enlighten → unravel path).
local function _pick_convert(tgt, ctx)
  ctx = type(ctx) == "table" and ctx or {}
  local phase = tostring(ctx.phase or "convert"):lower()
  if phase ~= "convert" and phase ~= "finish" then return nil end

  local enlighten_target = tonumber(ctx.enlighten_target or A.cfg.enlighten_target or 5) or 5
  local unravel_mentals  = tonumber(ctx.unravel_mentals  or A.cfg.unravel_mentals  or 4) or 4
  local mental           = _mental_score()

  local has_wm = _tgt_has(tgt, "whisperingmadness") or _tgt_has(tgt, "whispering_madness")
  if not has_wm then
    -- #region agent log
    _dbg_log("H13", "occ_aff.lua:_pick_convert", "convert_choice", { target = tgt, phase = phase, reason = "missing_whisperingmadness", cmd = ("whisperingmadness %s"):format(tgt), mental = mental, enlighten_target = enlighten_target, unravel_mentals = unravel_mentals })
    -- #endregion
    return ("whisperingmadness %s"):format(tgt)
  end

  local enlightened = _tgt_has(tgt, "enlightened")
  if not enlightened then
    if mental >= enlighten_target then
      -- #region agent log
      _dbg_log("H13", "occ_aff.lua:_pick_convert", "convert_choice", { target = tgt, phase = phase, reason = "enlighten_threshold", cmd = ("enlighten %s"):format(tgt), mental = mental, enlighten_target = enlighten_target, unravel_mentals = unravel_mentals })
      -- #endregion
      return ("enlighten %s"):format(tgt)
    end
    local ra_ready = true
    if Yso.occ and type(Yso.occ.readaura_is_ready) == "function" then
      local ok, v = pcall(Yso.occ.readaura_is_ready)
      ra_ready = (ok and v == true)
    end
    if ra_ready then
      -- #region agent log
      _dbg_log("H13", "occ_aff.lua:_pick_convert", "convert_choice", { target = tgt, phase = phase, reason = "prep_readaura", cmd = ("readaura %s"):format(tgt), mental = mental, enlighten_target = enlighten_target, unravel_mentals = unravel_mentals })
      -- #endregion
      return ("readaura %s"):format(tgt)
    end
    -- #region agent log
    _dbg_log("H13", "occ_aff.lua:_pick_convert", "convert_choice", { target = tgt, phase = phase, reason = "fallback_whisperingmadness", cmd = ("whisperingmadness %s"):format(tgt), mental = mental, enlighten_target = enlighten_target, unravel_mentals = unravel_mentals })
    -- #endregion
    return ("whisperingmadness %s"):format(tgt)
  end

  if mental >= unravel_mentals then
    return ("unravel %s"):format(tgt)
  end
  local ra_ready = true
  if Yso.occ and type(Yso.occ.readaura_is_ready) == "function" then
    local ok, v = pcall(Yso.occ.readaura_is_ready)
    ra_ready = (ok and v == true)
  end
  if ra_ready then return ("readaura %s"):format(tgt) end
  return ("unravel %s"):format(tgt)
end

function A.init()
  A.cfg = A.cfg or {}
  A.state = A.state or {}
  A.state.waiting = A.state.waiting or { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 }
  A.state.last_attack = A.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" }
  A.state.in_flight = A.state.in_flight or { fingerprint = "", target = "", route = "occ_aff", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" }
  A.state.debug = A.state.debug or { last_no_send_reason = "", last_retry_reason = "" }
  A.state.template = A.state.template or { last_payload = nil, last_emitted_payload = nil, last_target = "", last_reason = "", last_disable_reason = "" }
  A.state.observe_tries = A.state.observe_tries or {}
  A.state.last_attend_at = type(A.state.last_attend_at) == "table" and A.state.last_attend_at or {}
  A.state.last_unnamable_at = type(A.state.last_unnamable_at) == "table" and A.state.last_unnamable_at or {}
  A.state.explain = type(A.state.explain) == "table" and A.state.explain or {}
  if A.state.loop_delay == nil then
    A.state.loop_delay = tonumber(A.cfg.loop_delay or 0.15) or 0.15
  end
  return true
end

function A.reset(reason)
  A.init()
  local target = _trim(A.state.last_target)
  A.state.waiting = { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 }
  A.state.last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" }
  A.state.in_flight = { fingerprint = "", target = "", route = "occ_aff", at = 0, resolved_at = _now(), lanes = nil, eq = "", entity = "", reason = "" }
  A.state.debug = { last_no_send_reason = "", last_retry_reason = "" }
  A.state.template = { last_payload = nil, last_emitted_payload = nil, last_target = "", last_reason = tostring(reason or "manual"), last_disable_reason = "" }
  A.state.defer_unnamable = nil
  A.state.observe_tries = {}
  A.state.last_attend_at = {}
  A.state.last_unnamable_at = {}
  A.state.last_readaura = 0
  if target ~= "" and Yso.occ and type(Yso.occ.set_phase) == "function" then
    pcall(Yso.occ.set_phase, target, "open", reason or "reset")
  end
  return true
end

function A.is_enabled()
  return A.state and (A.state.enabled == true or A.state.loop_enabled == true)
end

function A.is_active()
  if Yso and Yso.mode and type(Yso.mode.route_loop_active) == "function" then
    return Yso.mode.route_loop_active("occ_aff") == true
  end
  return A.state and A.state.loop_enabled == true
end

function A.can_run(ctx)
  A.init()
  local has_route_loop_manager = Yso and Yso.mode and type(Yso.mode.route_loop_active) == "function"
  local enforce_loop_state = has_route_loop_manager
  if type(ctx) == "table" and ctx.enforce_loop_state ~= nil then
    enforce_loop_state = (ctx.enforce_loop_state == true)
  end
  local enabled = A.is_enabled()
  local active = A.is_active()
  if enforce_loop_state and not enabled then
    -- #region agent log
    _dbg_log("H1", "occ_aff.lua:can_run", "can_run_blocked", {
      reason = "disabled",
      enabled = enabled,
      active = active,
      enforce_loop_state = enforce_loop_state,
      has_route_loop_manager = has_route_loop_manager,
    })
    -- #endregion
    return false, "disabled"
  end
  if enforce_loop_state and not active then
    -- #region agent log
    _dbg_log("H1", "occ_aff.lua:can_run", "can_run_blocked", {
      reason = "inactive",
      enabled = enabled,
      active = active,
      enforce_loop_state = enforce_loop_state,
      has_route_loop_manager = has_route_loop_manager,
    })
    -- #endregion
    return false, "inactive"
  end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() == true then
    -- #region agent log
    _dbg_log("H1", "occ_aff.lua:can_run", "can_run_blocked", { reason = "paused", enabled = enabled, active = active })
    -- #endregion
    return false, "paused"
  end
  local tgt = _trim((ctx and ctx.target) or "")
  if tgt == "" and type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok then tgt = _trim(v) end
  end
  if tgt == "" then
    local ak = rawget(_G, "ak")
    if type(ak) == "table" then
      tgt = _trim(ak.target or ak.tgt)
    end
  end
  if tgt == "" then
    -- #region agent log
    _dbg_log("H2", "occ_aff.lua:can_run", "can_run_blocked", { reason = "no_target", enabled = enabled, active = active })
    -- #endregion
    return false, "no_target"
  end
  if type(Yso.target_is_valid) == "function" then
    local ok, valid = pcall(Yso.target_is_valid, tgt)
    if ok and valid ~= true then
      -- #region agent log
      _dbg_log("H2", "occ_aff.lua:can_run", "can_run_blocked", { reason = "target_invalid", target = tgt, enabled = enabled, active = active })
      -- #endregion
      return false, "target_invalid"
    end
  end
  -- #region agent log
  _dbg_log("H1", "occ_aff.lua:can_run", "can_run_ok", { target = tgt, enabled = enabled, active = active })
  -- #endregion
  return true, tgt
end

function A.schedule_loop(delay)
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    return Yso.mode.schedule_route_loop("occ_aff", delay)
  end
  return false
end

A.alias_loop_stop_details = A.alias_loop_stop_details or {
  inactive = true,
  disabled = true,
  no_target = true,
  paused = true,
  target_invalid = true,
  target_slain = true,
  route_off = true,
}

function A.alias_loop_prepare_start(ctx)
  A.init()
  A.state.enabled = true
  A.state.loop_enabled = true
  A.state.busy = false
  A.state.waiting = { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 }
  A.state.in_flight = { fingerprint = "", target = "", route = "occ_aff", at = 0, resolved_at = _now(), lanes = nil, eq = "", entity = "", reason = "" }
  A.state.debug = A.state.debug or { last_no_send_reason = "", last_retry_reason = "" }
  A.state.template = A.state.template or { last_payload = nil, last_emitted_payload = nil, last_target = "", last_reason = "", last_disable_reason = "" }
  return ctx or {}
end

function A.alias_loop_on_started(ctx)
  A.state.busy = false
  A.alias_loop_clear_waiting()
  _echo_toggle("AFF LOOP ON.")
  local ok, tgt_or_reason = A.can_run(ctx)
  if not ok then
    if tgt_or_reason == "no_target" then
      _echo_toggle("No target yet; holding.")
    elseif tgt_or_reason == "target_invalid" then
      local tgt = _trim(A.state and A.state.last_target or "")
      if tgt ~= "" then
        _echo_toggle(string.format("%s is not in room; holding.", tgt))
      else
        _echo_toggle("Target invalid; holding.")
      end
    end
  end
  return true
end

function A.alias_loop_on_stopped(ctx)
  A.init()
  ctx = ctx or {}
  local reason = tostring(ctx.reason or "manual")
  A.state.enabled = false
  A.state.loop_enabled = false
  A.state.busy = false
  A.alias_loop_clear_waiting()
  A.state.template = A.state.template or { last_payload = nil, last_emitted_payload = nil, last_target = "", last_reason = "", last_disable_reason = "" }
  A.state.template.last_reason = reason
  A.state.template.last_disable_reason = reason
  if _loyals_any_active() then
    local C = _companions()
    local sent = false
    if C and type(C.passive) == "function" then
      local ok = nil
      ok, _ = C.passive({ emit = true, target = _trim(A.state.last_target) })
      sent = (ok == true)
    end
    if not sent then
      local passive = _trim(tostring(A.cfg.off_passive_cmd or "order loyals passive"))
      if passive ~= "" then
        _emit_free(passive, "occ_aff:off_passive", _trim(A.state.last_target))
      end
      _set_loyals_hostile(false)
    end
  end
  local C = _companions()
  if C and type(C.reset_recovery) == "function" then
    pcall(C.reset_recovery, "route_off")
  end
  if not (type(ctx) == "table" and ctx.silent == true) then
    _echo_toggle(string.format("AFF LOOP OFF (%s).", tostring(reason):upper()))
  end
  return true
end

function A.alias_loop_clear_waiting()
  A.state.waiting = A.state.waiting or {}
  A.state.waiting.queue = nil
  A.state.waiting.main_lane = nil
  A.state.waiting.lanes = nil
  A.state.waiting.fingerprint = ""
  A.state.waiting.reason = ""
  A.state.waiting.at = 0
  A.state.in_flight = A.state.in_flight or {}
  A.state.in_flight.resolved_at = _now()
  A.state.in_flight.fingerprint = ""
  A.state.in_flight.target = ""
  A.state.in_flight.lanes = nil
  A.state.in_flight.eq = ""
  A.state.in_flight.entity = ""
  A.state.in_flight.reason = ""
  return true
end

function A.alias_loop_waiting_blocks()
  local queue = _trim(A.state and A.state.waiting and A.state.waiting.queue)
  if queue ~= "" then
    local age = _now() - (tonumber(A.state.waiting and A.state.waiting.at) or 0)
    local stale_s = math.max(0.45, (tonumber(A.state.loop_delay or A.cfg.loop_delay or 0.15) or 0.15) * 6)
    -- #region agent log
    _dbg_log("H3", "occ_aff.lua:alias_loop_waiting_blocks", "waiting_present", { queue = queue, age = age, stale_s = stale_s, reason = A.state and A.state.waiting and A.state.waiting.reason or "" })
    -- #endregion
    if age >= stale_s then
      A.alias_loop_clear_waiting()
    end
  end
  -- Keep offense loop reevaluating continuously; queued ownership handles replacement.
  -- This prevents stale queued-state stalls when a staged emit does not commit.
  return false
end

function A.alias_loop_on_error(err)
  if A.cfg.echo == true then
    if type(cecho) == "function" then
      cecho(string.format("<HotPink>[Occultism] <reset>Loop error: %s\n", tostring(err)))
    elseif type(echo) == "function" then
      echo(string.format("[Occultism] Loop error: %s\n", tostring(err)))
    end
  end
  return true
end

function A.attack_function(arg)
  local ctx, preview = _attack_opts(arg)
  -- #region agent log
  _dbg_log("H2", "occ_aff.lua:attack_function", "attack_enter", { preview = preview == true, ctx_target = _trim(ctx and ctx.target or "") })
  -- #endregion
  local ok, info = A.can_run(ctx)
  if not ok then
    -- #region agent log
    _dbg_log("H1", "occ_aff.lua:attack_function", "attack_blocked", { reason = info, preview = preview == true })
    -- #endregion
    if preview then return nil, info end
    return false, info
  end
  local tgt = info

  local tkey = tgt:lower()
  A.state.last_target = tgt

  if _trim(A.state.phase_tgt) ~= tkey then
    A.state.phase_tgt = tkey
    A.state.observe_tries[tkey] = 0
    A.state.defer_unnamable = nil
    if Yso.occ and type(Yso.occ.set_phase) == "function" then
      pcall(Yso.occ.set_phase, tgt, "open", "new_target")
    end
  end

  local payload = {
    target = tgt,
    route = "occ_aff",
    free = {},
    eq = "",
    bal = "",
    class = "",
  }

  local phase = "open"
  if Yso.occ and type(Yso.occ.get_phase) == "function" then
    local ok, v = pcall(Yso.occ.get_phase, tgt)
    if ok and type(v) == "string" and _trim(v) ~= "" then
      phase = _trim(v)
    end
  end

  -- 1 open
  if not _loyals_active_for(tgt) then
    local C = _companions()
    local opener = nil
    local opener_reason = ""
    if C and type(C.kill) == "function" then
      local ok, res, why = pcall(C.kill, tgt, { include_stand = true, emit = false })
      if ok then
        opener = res
        opener_reason = _trim(why)
      end
    end
    if type(opener) == "table" then
      for i = 1, #opener do
        local cmd = _trim(opener[i])
        if cmd ~= "" then payload.free[#payload.free + 1] = cmd end
      end
    elseif type(opener) == "string" and _trim(opener) ~= "" then
      payload.free[#payload.free + 1] = _trim(opener)
    elseif opener_reason == "recovering" then
      -- Companion helper intentionally suppresses kill orders while recovering.
    else
      payload.free[#payload.free + 1] = string.format("order loyals kill %s", tgt)
    end
  end

  local ra_ready = true
  if Yso.occ and type(Yso.occ.readaura_is_ready) == "function" then
    local ok, v = pcall(Yso.occ.readaura_is_ready)
    ra_ready = (ok and v == true)
  end
  local cleanse_live = false
  cleanse_live = (_cleanse_ready(tgt) == true)

  if phase == "open" then
    if Yso.occ and type(Yso.occ.set_phase) == "function" then
      pcall(Yso.occ.set_phase, tgt, "pressure", "open_done")
    end
  elseif phase == "pressure" and cleanse_live then
    if Yso.occ and type(Yso.occ.set_phase) == "function" then
      pcall(Yso.occ.set_phase, tgt, "cleanse", "cleanse_gate_on")
    end
  elseif phase == "cleanse" and not cleanse_live then
    if Yso.occ and type(Yso.occ.set_phase) == "function" then
      pcall(Yso.occ.set_phase, tgt, "pressure", "cleanse_gate_drop")
    end
  end
  phase = "open"
  if Yso.occ and type(Yso.occ.get_phase) == "function" then
    local ok, v = pcall(Yso.occ.get_phase, tgt)
    if ok and type(v) == "string" and _trim(v) ~= "" then
      phase = _trim(v)
    end
  end

  -- 2 pressure
  if (phase == "open" or phase == "pressure") and payload.eq == "" and _eq() then
    payload.eq = _trim(_pick_instill(tgt) or "")
  end
  if (phase == "open" or phase == "pressure") and payload.eq == "" and _eq() and ra_ready and _ra_due() then
    payload.eq = "readaura " .. tgt
  end

  -- 3 cleanse/truename
  if phase == "cleanse" then
    local now_ts = _now()
    local attend_lock_s = tonumber(A.cfg.attend_lock_s or 2.4) or 2.4
    local unnamable_lock_s = tonumber(A.cfg.unnamable_lock_s or 2.4) or 2.4
    local last_attend = tonumber(A.state.last_attend_at[tkey] or 0) or 0
    local last_unnamable = tonumber(A.state.last_unnamable_at[tkey] or 0) or 0
    local attend_ready = ((now_ts - last_attend) >= attend_lock_s)
    local unnamable_ready = ((now_ts - last_unnamable) >= unnamable_lock_s)
    local need_attend = false
    if Yso.occ and type(Yso.occ.aura_need_attend) == "function" then
      local ok, v = pcall(Yso.occ.aura_need_attend, tgt)
      need_attend = (ok and v == true)
    end

    if need_attend and payload.eq == "" and _eq() and attend_ready then
      payload.eq = "attend " .. tgt
    elseif need_attend and payload.eq == "" and _eq() and not attend_ready then
      -- #region agent log
      _dbg_log("H14", "occ_aff.lua:cleanse", "attend_suppressed_cooldown", { target = tgt, tkey = tkey, now = now_ts, last_attend = last_attend, lock_s = attend_lock_s })
      -- #endregion
    end

    if need_attend and payload.class == "" and _ent() then
      payload.class = "command chimera at " .. tgt
    end

    if payload.eq == ("attend " .. tgt) then
      A.state.defer_unnamable = tkey
      if not preview then
        A.state.last_attend_at[tkey] = now_ts
      end
      -- #region agent log
      _dbg_log("H14", "occ_aff.lua:cleanse", "attend_selected", { target = tgt, tkey = tkey, now = now_ts, lock_s = attend_lock_s, preview = preview == true })
      -- #endregion
    end

    if A.state.defer_unnamable == tkey and payload.bal == "" and _bal() and unnamable_ready then
      payload.bal = "unnamable speak"
      if not preview then
        A.state.last_unnamable_at[tkey] = now_ts
        A.state.defer_unnamable = nil
      end
      -- #region agent log
      _dbg_log("H14", "occ_aff.lua:cleanse", "unnamable_selected", { target = tgt, tkey = tkey, now = now_ts, lock_s = unnamable_lock_s, preview = preview == true })
      -- #endregion
    elseif A.state.defer_unnamable == tkey and payload.bal == "" and _bal() and not unnamable_ready then
      -- #region agent log
      _dbg_log("H14", "occ_aff.lua:cleanse", "unnamable_suppressed_cooldown", { target = tgt, tkey = tkey, now = now_ts, last_unnamable = last_unnamable, lock_s = unnamable_lock_s })
      -- #endregion
    end

    local can_utter = false
    if Yso.occ and Yso.occ.truebook and type(Yso.occ.truebook.can_utter) == "function" then
      local ok, v = pcall(Yso.occ.truebook.can_utter, tgt)
      can_utter = (ok and v == true)
    end

    if cleanse_live then
      if can_utter and payload.eq == "" and _eq() then
        payload.eq = "utter truename " .. tgt
      elseif payload.eq == "" and _eq() and ra_ready and _ra_due()
          and (tonumber(A.state.observe_tries[tkey] or 0) or 0) < (tonumber(A.cfg.max_observe or 3) or 3) then
        payload.eq = "readaura " .. tgt
      elseif payload.eq == "" and _eq() then
        payload.eq = "cleanseaura " .. tgt
      end
    end

    local burst_ready = false
    burst_ready = (_burst_ready(tgt, {
      phase = phase,
      eq_cmd = payload.eq,
      need_attend = need_attend,
      cleanse_ready = cleanse_live,
    }) == true)
    if burst_ready then
      if Yso.occ and type(Yso.occ.set_phase) == "function" then
        pcall(Yso.occ.set_phase, tgt, "convert", "cleanse_branch_active")
      end
    end
  end

  phase = "open"
  if Yso.occ and type(Yso.occ.get_phase) == "function" then
    local ok, v = pcall(Yso.occ.get_phase, tgt)
    if ok and type(v) == "string" and _trim(v) ~= "" then
      phase = _trim(v)
    end
  end

  -- Keep generic readaura fallback out of convert/finish so convert logic can drive EQ.
  if payload.eq == "" and _eq() and ra_ready and _ra_due()
      and phase ~= "convert" and phase ~= "finish" then
    payload.eq = "readaura " .. tgt
  end

  -- 5 whisperingmadness->enlighten / unravel
  if payload.eq == "" and _eq() and (phase == "convert" or phase == "finish") then
    payload.eq = _trim(_pick_convert(tgt, {
      phase = phase,
      enlighten_target = tonumber(A.cfg.enlighten_target or 5) or 5,
      unravel_mentals  = tonumber(A.cfg.unravel_mentals  or 4) or 4,
    }) or "")
  end

  local target_enlightened = _tgt_has(tgt, "enlightened")
  if target_enlightened then
    if Yso.occ and type(Yso.occ.set_phase) == "function" then
      pcall(Yso.occ.set_phase, tgt, "finish", "target_enlightened")
    end
  end
  phase = "open"
  if Yso.occ and type(Yso.occ.get_phase) == "function" then
    local ok, v = pcall(Yso.occ.get_phase, tgt)
    if ok and type(v) == "string" and _trim(v) ~= "" then
      phase = _trim(v)
    end
  end

  -- 4 maintain pressure (entity fallback -- runs after cleanse so chimera roar gets priority)
  if payload.class == "" and _ent() then
    payload.class = _trim(_pick_entity(tgt, phase) or "")
  end

  local free_cmd = ""
  if type(payload.free) == "table" and #payload.free > 0 then
    free_cmd = table.concat(payload.free, _command_sep())
  end
  local eq_cmd = _trim(payload.eq)
  local bal_cmd = _trim(payload.bal)
  local class_cmd = _trim(payload.class)

  local function _eq_category(cmd, p)
    local lc = _lc(cmd)
    if lc == "" then return nil end
    if lc:match("^attend%s+") then return "mental_pressure" end
    if lc == "unnamable speak" then return "mental_pressure" end
    if lc:match("^utter%s+truename%s+") then return "reserved_burst" end
    if lc:match("^cleanseaura%s+") then return "truename_acquire" end
    if lc:match("^readaura%s+") then return "team_coordination" end
    if lc:match("^instill%s+") then return "pressure" end
    if p == "convert" or p == "finish" then return "reserved_burst" end
    return "pressure"
  end

  local eq_cat = _eq_category(eq_cmd, phase)
  local bal_cat = (_lc(bal_cmd) == "unnamable speak") and "mental_pressure" or ((_trim(bal_cmd) ~= "") and "pressure" or nil)
  local class_cat = (_trim(class_cmd) ~= "") and ((phase == "cleanse" and _lc(class_cmd):match("^command%s+chimera%s+at%s+")) and "mental_pressure" or "entity_support") or nil
  local main_lane = ""
  local main_category = nil
  if eq_cmd ~= "" then
    main_lane = "eq"
    main_category = eq_cat
  elseif bal_cmd ~= "" then
    main_lane = "bal"
    main_category = bal_cat
  elseif class_cmd ~= "" then
    main_lane = "entity"
    main_category = class_cat
  elseif free_cmd ~= "" then
    main_lane = "free"
    main_category = "team_coordination"
  end

  local route_payload = {
    route = "occ_aff",
    target = tgt,
    lanes = {
      free = (free_cmd ~= "") and free_cmd or nil,
      eq = (eq_cmd ~= "") and eq_cmd or nil,
      bal = (bal_cmd ~= "") and bal_cmd or nil,
      entity = (class_cmd ~= "") and class_cmd or nil,
      class = (class_cmd ~= "") and class_cmd or nil,
    },
    meta = {
      phase = phase,
      route = "occ_aff",
      free_category = (free_cmd ~= "") and "team_coordination" or nil,
      eq_category = eq_cat,
      bal_category = bal_cat,
      entity_category = class_cat,
      main_lane = main_lane,
      main_category = main_category,
      free_parts = (type(payload.free) == "table" and #payload.free > 0) and payload.free or nil,
    },
  }

  route_payload, _ = _route_gate_finalize(route_payload, ctx, tgt)
  -- #region agent log
  _dbg_log("H4", "occ_aff.lua:attack_function", "payload_planned", {
    target = tgt,
    phase = phase,
    eq = _trim(route_payload and route_payload.lanes and route_payload.lanes.eq or ""),
    bal = _trim(route_payload and route_payload.lanes and route_payload.lanes.bal or ""),
    entity = _trim(route_payload and route_payload.lanes and (route_payload.lanes.entity or route_payload.lanes.class) or ""),
    free = _trim(route_payload and route_payload.lanes and route_payload.lanes.free or ""),
  })
  -- #endregion
  A.state.template.last_payload = route_payload
  A.state.template.last_target = tgt
  local gate = type(route_payload) == "table" and (route_payload._route_gate or (route_payload.meta and route_payload.meta.route_gate)) or nil
  A.state.explain = {
    route = "occ_aff",
    target = tgt,
    phase = phase,
    planned = gate and gate.planned and gate.planned.lanes or route_payload.lanes,
    gated = gate and gate.gated and gate.gated.lanes or route_payload.lanes,
    blocked_reasons = gate and gate.blocked_reasons or {},
    hindrance = gate and gate.hinder or {},
    required_entities = gate and gate.entities and gate.entities.required or {},
    entity_obligations = gate and gate.entities and gate.entities.obligations or {},
    emitted = gate and gate.emitted or {},
    confirmed = gate and gate.confirmed or {},
  }

  if preview then
    local planner_empty = not route_payload.lanes.free and not route_payload.lanes.eq and not route_payload.lanes.bal and not route_payload.lanes.entity
    if planner_empty then return nil, "empty" end
    return route_payload
  end

  local emit_payload = (Yso and Yso.route_gate and type(Yso.route_gate.payload_for_emit) == "function")
    and Yso.route_gate.payload_for_emit(route_payload)
    or route_payload
  local emit_empty = not emit_payload.lanes.free and not emit_payload.lanes.eq and not emit_payload.lanes.bal and not emit_payload.lanes.entity
  if emit_empty then
    _note_no_send_reason("empty")
    return false, "empty"
  end
  local emit_err = nil
  emit_payload, emit_err = _final_pre_emit_payload(emit_payload)
  if not emit_payload then
    _note_no_send_reason(emit_err or "empty")
    return false, emit_err or "empty"
  end

  local sent, cmd_or_err = _emit(emit_payload)
  if not sent then
    -- #region agent log
    _dbg_log("H5", "occ_aff.lua:attack_function", "emit_failed", { reason = tostring(cmd_or_err or ""), target = tgt })
    -- #endregion
    return false, cmd_or_err
  end
  -- #region agent log
  _dbg_log("H5", "occ_aff.lua:attack_function", "emit_ok", { target = tgt, cmd = tostring(cmd_or_err or "") })
  -- #endregion

  A.state.template.last_emitted_payload = emit_payload
  if Yso and Yso.route_gate and type(Yso.route_gate.note_emitted) == "function" then
    pcall(Yso.route_gate.note_emitted, route_payload, emit_payload, ctx)
  end
  local has_ack_bus = Yso and Yso.locks and type(Yso.locks.note_payload) == "function"
  -- #region agent log
  _dbg_log("H11", "occ_aff.lua:attack_function", "post_emit_ack_path", {
    target = tgt,
    has_ack_bus = has_ack_bus == true,
    eq = _trim(emit_payload and emit_payload.lanes and emit_payload.lanes.eq or ""),
  })
  -- #endregion
  local on_sent_ok, on_sent_res = pcall(A.on_sent, emit_payload, { target = tgt, via_ack_bus = has_ack_bus == true })
  -- #region agent log
  _dbg_log("H11", "occ_aff.lua:attack_function", "post_emit_on_sent_result", {
    target = tgt,
    has_ack_bus = has_ack_bus == true,
    ok = on_sent_ok == true,
    result = on_sent_res == true,
  })
  -- #endregion
  return true, cmd_or_err, route_payload
end

function A.build_payload(ctx)
  return A.attack_function({ ctx = ctx, preview = true })
end

local function _clear_owned_lanes(payload)
  local Q = Yso and Yso.queue or nil
  if not (Q and type(Q.clear_owned) == "function") then return end

  local lanes = type(payload) == "table" and (payload.lanes or payload) or {}
  local cleared = {}
  local function clear_lane(lane)
    if cleared[lane] then return end
    cleared[lane] = true
    pcall(Q.clear_owned, lane)
  end

  local free_lane = lanes.free or lanes.pre
  if (type(free_lane) == "table" and #free_lane > 0) or _trim(free_lane) ~= "" then
    clear_lane("free")
  end
  if _trim(lanes.eq) ~= "" then
    clear_lane("eq")
  end
  if _trim(lanes.bal) ~= "" then
    clear_lane("bal")
  end
  if _trim(lanes.class) ~= "" or _trim(lanes.entity) ~= "" or _trim(lanes.ent) ~= "" then
    clear_lane("class")
  end
end

function A.on_sent(payload, ctx)
  payload = type(payload) == "table" and payload or {}
  local tgt = _trim(payload.target or (type(ctx) == "table" and ctx.target) or A.state.last_target)
  if tgt == "" then return false end

  local lanes = payload.lanes or payload
  local eq_cmd = _trim(lanes.eq)
  local free = lanes.free or lanes.pre
  local sep = _command_sep()
  local C = _companions()
  local function _each_free_part(fn)
    if type(free) == "table" then
      for i = 1, #free do
        local part = _trim(free[i])
        if part ~= "" then fn(part) end
      end
      return
    end
    local body = _trim(free)
    if body == "" then return end
    local idx = 1
    while true do
      local a, b = body:find(sep, idx, true)
      local part = a and body:sub(idx, a - 1) or body:sub(idx)
      part = _trim(part)
      if part ~= "" then fn(part) end
      if not a then break end
      idx = b + 1
    end
  end

  if C and type(C.note_order_sent) == "function" then
    _each_free_part(function(cmd)
      pcall(C.note_order_sent, cmd, tgt)
    end)
  else
    _each_free_part(function(cmd)
      if _lc(cmd) == ("order loyals kill " .. _lc(tgt)) then
        _set_loyals_hostile(true, tgt)
      end
    end)
  end

  if eq_cmd == ("readaura " .. tgt) then
    A.state.last_readaura = _now()
    if Yso.occ and type(Yso.occ.aura_begin) == "function" then
      pcall(Yso.occ.aura_begin, tgt, "occ_aff_send")
    end
    if Yso.occ and type(Yso.occ.set_readaura_ready) == "function" then
      pcall(Yso.occ.set_readaura_ready, false, "sent")
    end
    local phase = ""
    if Yso.occ and type(Yso.occ.get_phase) == "function" then
      local ok, v = pcall(Yso.occ.get_phase, tgt)
      if ok and type(v) == "string" then
        phase = _trim(v)
      end
    end
    if phase == "cleanse" then
      local tkey = _lc(tgt)
      A.state.observe_tries[tkey] = (tonumber(A.state.observe_tries[tkey] or 0) or 0) + 1
    end
  end

  if eq_cmd == ("attend " .. tgt) then
    A.state.defer_unnamable = tgt:lower()
  end

  -- Allow loop routes to requeue the same lane command on the next pass.
  _clear_owned_lanes(payload)

  return true
end

A.S = A.S or {}
function A.S.loyals_hostile(tgt)
  tgt = _trim(tgt)
  if tgt ~= "" then
    return _loyals_active_for(tgt)
  end
  return _loyals_any_active()
end

function A.evaluate(ctx)
  local payload, why = A.build_payload(ctx)
  if not payload then return { ok = false, reason = why } end
  return { ok = true, payload = payload }
end

function A.status()
  local tgt = _trim(A.state.last_target)
  return {
    route = "occ_aff",
    enabled = A.is_enabled(),
    active = A.is_active(),
    target = tgt,
    phase = (function()
      if tgt == "" then return "open" end
      if Yso.occ and type(Yso.occ.get_phase) == "function" then
        local ok, v = pcall(Yso.occ.get_phase, tgt)
        if ok and type(v) == "string" and _trim(v) ~= "" then return _trim(v) end
      end
      return "open"
    end)(),
    waiting = A.state and A.state.waiting or {},
    in_flight = A.state and A.state.in_flight or {},
    last_no_send_reason = A.state and A.state.debug and A.state.debug.last_no_send_reason or "",
    last_retry_reason = A.state and A.state.debug and A.state.debug.last_retry_reason or "",
  }
end

function A.on_enter(ctx)
  A.init()
  return true
end

function A.on_exit(ctx)
  if Yso and Yso.mode and type(Yso.mode.stop_route_loop) == "function" then
    pcall(Yso.mode.stop_route_loop, "occ_aff", "exit", true)
  end
  A.reset("exit")
  return true
end

function A.on_target_swap(old_target, new_target)
  old_target = _trim(old_target)
  new_target = _trim(new_target)
  if old_target:lower() ~= new_target:lower() then
    A.state.phase_tgt = ""
    A.state.last_target = new_target
    if new_target ~= "" and Yso.occ and type(Yso.occ.set_phase) == "function" then
      pcall(Yso.occ.set_phase, new_target, "open", "target_swap")
    end
    A.alias_loop_clear_waiting()
    if A.state.loop_enabled == true then
      A.schedule_loop(0)
    end
  end
  return true
end

function A.on_pause(ctx)
  return true
end

function A.on_resume(ctx)
  if A.state.loop_enabled == true then
    A.schedule_loop(0)
  end
  return true
end

function A.on_manual_success(ctx)
  if A.state.loop_enabled == true then
    A.schedule_loop(A.state.loop_delay)
  end
  return true
end

function A.on_send_result(payload, ctx)
  return A.on_sent(payload, ctx)
end

function A.on_payload_sent(payload)
  return A.on_sent(payload, nil)
end

function A.explain()
  local ex = A.state and A.state.explain or {}
  ex.route = ex.route or "occ_aff"
  ex.route_enabled = A.is_enabled()
  ex.active = A.is_active()
  ex.waiting = A.state and A.state.waiting or {}
  ex.in_flight = A.state and A.state.in_flight or {}
  ex.last_no_send_reason = A.state and A.state.debug and A.state.debug.last_no_send_reason or ""
  ex.last_retry_reason = A.state and A.state.debug and A.state.debug.last_retry_reason or ""
  A.state.explain = ex
  return ex
end

do
  local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(A, A.route_contract)
  end
end

return A
