--========================================================--
-- Yso/Core/queue.lua
--  * Canonical lane-aware queue implementation.
--  * Mirrors to modules/Yso/xml/yso_queue.lua -> package slot "Yso.queue".
--  * Keeps staged lane commits for modern offense code and raw QUEUE wrappers
--    for older XML-resident helpers that still expect addclear/addclearfull.
--========================================================--

------------------------------------------------------------
-- Locals
------------------------------------------------------------
local _G = _G
local rawget = rawget
local type = type
local tostring = tostring
local pcall = pcall
local pairs = pairs
local ipairs = ipairs
local table_concat = table.concat
local table_insert = table.insert

-- Normalize root namespace so both _G.Yso and _G.yso exist and match.
do
  local root = rawget(_G, "Yso")
  if type(root) ~= "table" then root = rawget(_G, "yso") end
  if type(root) ~= "table" then root = {} end
  _G.Yso = root
  _G.yso = root
end

local Yso = _G.Yso
Yso.cfg = Yso.cfg or {}
Yso.net = Yso.net or {}
Yso.net.cfg = Yso.net.cfg or {}
Yso.queue = Yso.queue or {}
Yso._queued = Yso._queued or {}

local Q = Yso.queue

Q.cfg = Q.cfg or {
  debug = false,
  legacy_autocommit = false,
  lane_dispatch_debounce_s = 0.25,
}

Q._staged = Q._staged or {
  free = {},
  eq = nil,
  bal = nil,
  class = nil,
}
Q._blocked = Q._blocked or {}
Q._lane_dispatched = Q._lane_dispatched or {
  eq = nil,
  bal = nil,
  class = nil,
}

Q._impl_version = "2026-04-05.1"

------------------------------------------------------------
-- Constants
------------------------------------------------------------

-- Maps canonical lane keys to Achaea QUEUE command type strings.
local _QTYPE_MAP = {
  eq    = "e!p!w!t",
  bal   = "b!p!w!t",
  class = "c!p!w!t",
  free  = "eb!w!p!t",
}
-- Lanes that can act as the wake trigger in a commit (free is never a wake lane).
local _VALID_WAKE_LANES = { eq = true, bal = true, class = true }

------------------------------------------------------------
-- Internal helpers
------------------------------------------------------------

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    if ok and tonumber(v) then return tonumber(v) end
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

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Normalises any lane alias (including raw Achaea queue-type strings like
-- "e!p!w!t") to one of the four canonical keys: eq / bal / class / free.
local function _lane_key(lane)
  lane = _trim(lane):lower()
  if lane == "" then return nil end
  if lane == "entity" or lane == "ent" or lane == "c" or lane == "class" or lane == "c!p!w!t" then
    return "class"
  end
  if lane == "eq" or lane == "e" or lane == "e!p!w!t" then
    return "eq"
  end
  if lane == "bal" or lane == "b" or lane == "bu" or lane == "b!p!w!t" then
    return "bal"
  end
  if lane == "free" or lane == "f" then
    return "free"
  end
  return nil
end

local function _route_from_opts(opts)
  if type(opts) ~= "table" then return "" end
  -- Route identity must be explicit. We do not infer it from free-form reason/src.
  local route = _trim(opts.route)
  return route
end

local function _infer_lane_from_payload(payload)
  if type(payload) ~= "string" then return nil end

  local cmd = _trim(payload):lower()
  if cmd == "" then return nil end

  if cmd == "stand"
     or cmd == "diag"
     or cmd == "diagnose"
     or cmd:match("^writhe%s+")
     or cmd:match("^contemplate%s+")
     or (cmd:match("^order%s+") and not cmd:match("^order%s+soulmaster%s+"))
     or cmd:match("^out[dc]%s+")
  then
    return "free"
  end

  if cmd:match("^command%s+")
     and not cmd:match("^command%s+gremlin%s+")
     and not cmd:match("^command%s+soulmaster%s+")
  then
    return "class"
  end

  if cmd:match("^fling%s+")
     or cmd:match("^flick%s+")
     or cmd:match("^toss%s+")
     or cmd:match("^ruinate%s+")
     or cmd:match("^throw%s+")
     or cmd:match("^wipe%s+")
     or cmd:match("^envenom%s+")
     or cmd:match("^wrack%s+")
     or cmd:match("^truewrack%s+")
  then
    return "bal"
  end

  return "eq"
end

-- Resolves (lane, payload) into (canonical_key, payload, compat_note).
--  • "swapped"  – caller passed args in reverse order; we silently correct it.
--  • "inferred" – no lane was given; lane was guessed from the payload string.
--  • nil note   – normal path.
local function _coerce_stage_args(lane, payload)
  local key = _lane_key(lane)
  if key then return key, payload, nil end

  local swapped = _lane_key(payload)
  if swapped and type(lane) == "string" then
    return swapped, lane, "swapped"
  end

  if payload == nil and type(lane) == "string" then
    local inferred = _infer_lane_from_payload(lane)
    if inferred then
      return inferred, lane, "inferred"
    end
  end

  return nil, payload, nil
end

local function _clear_targets(token)
  if token == nil then return {} end
  token = _trim(token):lower()
  if token == "" then return {} end
  if token == "all" or token == "full" then return { "free", "eq", "bal", "class" } end
  if token == "eqbal" or token == "be" or token == "eb" then return { "eq", "bal" } end

  local lane = _lane_key(token)
  if lane then return { lane } end
  return {}
end

local function _clone_free(list)
  local out = {}
  if type(list) ~= "table" then return out end
  for i = 1, #list do
    out[#out + 1] = list[i]
  end
  return out
end

local function _snapshot()
  return {
    free = _clone_free(Q._staged.free),
    eq = Q._staged.eq,
    bal = Q._staged.bal,
    class = Q._staged.class,
  }
end

local function _command_sep()
  return (Yso and Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep))
      or (Yso and Yso.sep)
      or "&&"
end

local function _debug(msg)
  if not Q.cfg.debug or type(cecho) ~= "function" then return end
  cecho(string.format("<dim_grey>[Yso.queue] <reset>%s\n", tostring(msg)))
end

local function _split_free(payload)
  local out = {}

  if type(payload) == "table" then
    for i = 1, #payload do
      local part = _trim(payload[i])
      if part ~= "" then out[#out + 1] = part end
    end
    return out
  end

  payload = _trim(payload)
  if payload == "" then return out end

  local sep = _command_sep()
  local idx = 1
  while true do
    local a, b = payload:find(sep, idx, true)
    local part = a and payload:sub(idx, a - 1) or payload:sub(idx)
    part = _trim(part)
    if part ~= "" then out[#out + 1] = part end
    if not a then break end
    idx = b + 1
  end

  return out
end

local function _payload_has_value(payload)
  if type(payload) ~= "table" then return false end
  if type(payload.free) == "table" and #payload.free > 0 then return true end
  if _trim(payload.eq) ~= "" then return true end
  if _trim(payload.bal) ~= "" then return true end
  if _trim(payload.class) ~= "" then return true end
  return false
end

local function _payload_line(payload)
  local cmds = {}

  if type(payload.free) == "table" then
    for i = 1, #payload.free do
      local cmd = _trim(payload.free[i])
      if cmd ~= "" then cmds[#cmds + 1] = cmd end
    end
  end

  local eq = _trim(payload.eq)
  if eq ~= "" then cmds[#cmds + 1] = eq end

  local bal = _trim(payload.bal)
  if bal ~= "" then cmds[#cmds + 1] = bal end

  local class_cmd = _trim(payload.class)
  if class_cmd ~= "" then cmds[#cmds + 1] = class_cmd end

  return table_concat(cmds, _command_sep())
end

local function _prefer_lane(opts)
  local prefer = _trim(opts and opts.prefer or ""):lower()
  if prefer ~= "bal" and prefer ~= "eq" then
    prefer = _trim((Yso and Yso.cfg and Yso.cfg.emit_prefer) or "eq"):lower()
  end
  if prefer ~= "bal" then prefer = "eq" end
  return prefer
end

local function _lane_ready(lane)
  if lane == "free" then return true end
  if type(Q.lane_blocked) == "function" then
    local blocked = Q.lane_blocked(lane)
    if blocked == true then return false end
  end
  if type(Q.can_plan_lane) == "function" and Q.can_plan_lane(lane) ~= true then
    return false
  end

  if Yso and Yso.locks and type(Yso.locks.ready) == "function" then
    local ok, res = pcall(Yso.locks.ready, lane)
    if ok and res ~= nil then return res == true end
  end

  if lane == "eq" and Yso and Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, res = pcall(Yso.state.eq_ready)
    if ok and res ~= nil then return res == true end
  elseif lane == "bal" and Yso and Yso.state and type(Yso.state.bal_ready) == "function" then
    local ok, res = pcall(Yso.state.bal_ready)
    if ok and res ~= nil then return res == true end
  elseif lane == "class" then
    if Yso and type(Yso.is_alchemist) == "function" then
      local ok_is, is_alc = pcall(Yso.is_alchemist)
      if ok_is and is_alc == true and Yso.alc and type(Yso.alc.humour_ready) == "function" then
        local ok, res = pcall(Yso.alc.humour_ready)
        if ok and res ~= nil then return res == true end
      end
    end
    if Yso and Yso.state and type(Yso.state.ent_ready) == "function" then
      local ok, res = pcall(Yso.state.ent_ready)
      if ok and res ~= nil then return res == true end
    end
  end

  return true
end

local function _mark_payload_queued(payload)
  if Yso and Yso.trace and type(Yso.trace.push) == "function" then
    local lanes = {}
    if type(payload.free) == "table" and #payload.free > 0 then lanes[#lanes + 1] = "free" end
    if _trim(payload.eq) ~= "" then lanes[#lanes + 1] = "eq" end
    if _trim(payload.bal) ~= "" then lanes[#lanes + 1] = "bal" end
    if _trim(payload.class) ~= "" then lanes[#lanes + 1] = "class" end
    pcall(Yso.trace.push, "queue.queued", {
      ts = _now(),
      lanes = table_concat(lanes, ","),
      cmd = _payload_line(payload),
    })
  end
end

local function _ack_payload(payload)
  payload = type(payload) == "table" and payload or {}
  local lanes = {
    free = payload.free,
    eq = payload.eq,
    bal = payload.bal,
    class = payload.class or payload.entity or payload.ent,
  }

  local route_by_lane, target_by_lane = {}, {}
  local route, target = "", ""

  local function bind_lane(lane)
    local cmd = lanes[lane]
    if lane == "free" then
      if type(cmd) == "table" and #cmd == 0 then return end
      if type(cmd) ~= "table" and _trim(cmd) == "" then return end
    elseif _trim(cmd) == "" then
      return
    end

    local rec = type(Q.get_owned) == "function" and Q.get_owned(lane) or nil
    if type(rec) ~= "table" then return end
    local lane_route = _trim(rec.route)
    local lane_target = _trim(rec.target)
    if lane_route ~= "" then
      route_by_lane[lane] = lane_route
      if route == "" then route = lane_route end
    end
    if lane_target ~= "" then
      target_by_lane[lane] = lane_target
      if target == "" then target = lane_target end
    end
  end

  bind_lane("eq")
  bind_lane("bal")
  bind_lane("class")
  bind_lane("free")

  local ack = {
    route = route,
    target = target,
    lanes = {
      free = lanes.free,
      eq = lanes.eq,
      bal = lanes.bal,
      class = lanes.class,
      entity = lanes.class,
    },
    meta = {
      route = route,
      target = target,
      route_by_lane = route_by_lane,
      target_by_lane = target_by_lane,
      source = "queue.commit",
    },
    route_by_lane = route_by_lane,
    target_by_lane = target_by_lane,
  }
  ack.free = lanes.free
  ack.eq = lanes.eq
  ack.bal = lanes.bal
  ack.class = lanes.class
  ack.entity = lanes.class
  ack.ent = lanes.class
  ack.cmd = _payload_line(ack)
  return ack
end

local function _mark_payload_fired(payload)
  local ack_payload = _ack_payload(payload)
  Q._last_ack_payload = ack_payload

  if Yso and Yso.locks then
    if type(Yso.locks.note_payload) == "function" then
      pcall(Yso.locks.note_payload, ack_payload)
    elseif type(Yso.locks.note_send) == "function" then
      if _trim(ack_payload.eq) ~= "" then pcall(Yso.locks.note_send, "eq") end
      if _trim(ack_payload.bal) ~= "" then pcall(Yso.locks.note_send, "bal") end
      if _trim(ack_payload.class) ~= "" then pcall(Yso.locks.note_send, "class") end
    end
  end

  if Yso and Yso.pulse and type(Yso.pulse.on_payload_ack) == "function" then
    pcall(Yso.pulse.on_payload_ack, ack_payload, "queue.commit")
  end
end

local function _send_compound(body)
  body = _trim(body)
  if body == "" then return false end

  if Yso and Yso.net and Yso.net.cfg and Yso.net.cfg.dry_run == true then
    if type(cecho) == "function" then
      cecho(string.format("<dim_grey>[Yso.queue:DRY] <reset>%s\n", body))
    end
    return true
  end

  if type(send) == "function" then
    send(body, false)
    return true
  end

  if type(expandAlias) == "function" then
    expandAlias(body)
    return true
  end

  return false
end

local function _commit_payload(opts)
  opts = opts or {}

  local out = { free = _clone_free(Q._staged.free) }
  local wake = _lane_key(opts.wake_lane)
  local piggyback = (opts.piggyback == true)

  local function _staged_cmd(lane)
    return _trim(Q._staged[lane])
  end

  local function _take_lane(lane)
    if _staged_cmd(lane) == "" then return false end
    if not _lane_ready(lane) then return false end
    out[lane] = Q._staged[lane]
    return true
  end

  if _VALID_WAKE_LANES[wake] == true then
    local took = _take_lane(wake)
    if took then
      if piggyback and wake == "eq" then _take_lane("class") end
      if piggyback and wake == "class" then _take_lane("eq") end
      return out
    end
  elseif wake == "free" then
    return out
  end

  local eq_ready = (_staged_cmd("eq") ~= "") and _lane_ready("eq")
  local bal_ready = (_staged_cmd("bal") ~= "") and _lane_ready("bal")
  local class_ready = (_staged_cmd("class") ~= "") and _lane_ready("class")

  if class_ready then out.class = Q._staged.class end

  if opts.allow_eqbal == true then
    if eq_ready then out.eq = Q._staged.eq end
    if bal_ready then out.bal = Q._staged.bal end
  else
    if eq_ready and bal_ready then
      local prefer = _prefer_lane(opts)
      if prefer == "bal" then
        out.bal = Q._staged.bal
      else
        out.eq = Q._staged.eq
      end
    elseif eq_ready then
      out.eq = Q._staged.eq
    elseif bal_ready then
      out.bal = Q._staged.bal
    end
  end

  return out
end

local function _clear_payload(payload)
  if type(payload.free) == "table" and #payload.free > 0 then
    Q._staged.free = {}
  end
  if _trim(payload.eq) ~= "" then Q._staged.eq = nil end
  if _trim(payload.bal) ~= "" then Q._staged.bal = nil end
  if _trim(payload.class) ~= "" then Q._staged.class = nil end
end

local function _raw_queue(verb, qtype, payload)
  verb = _trim(verb):upper()
  qtype = _trim(qtype)
  if type(payload) == "boolean" then
    _debug("raw queue rejected boolean payload for " .. qtype)
    return false
  end
  if type(payload) ~= "string" then
    if type(payload) == "number" then
      payload = tostring(payload)
    else
      return false
    end
  end
  payload = _trim(payload)
  if verb == "" or qtype == "" or payload == "" then return false end
  return _send_compound(("QUEUE %s %s %s"):format(verb, qtype, payload))
end

local function _owned_table()
  Yso._queued = Yso._queued or {}
  return Yso._queued
end

------------------------------------------------------------
-- Public: ownership tracking
------------------------------------------------------------

function Q.qtype_for_lane(lane)
  local key = _lane_key(lane)
  if key and _QTYPE_MAP[key] then return _QTYPE_MAP[key] end
  local qtype = _trim(lane)
  if qtype ~= "" then return qtype end
  return nil
end

function Q.get_owned(lane)
  local key = _lane_key(lane)
  if not key then return nil end
  return _owned_table()[key]
end

function Q.set_owned(lane, rec)
  local key = _lane_key(lane)
  if not key or type(rec) ~= "table" then return false end
  _owned_table()[key] = rec
  return true
end

function Q.clear_owned(lane)
  local key = _lane_key(lane)
  if not key then return false end
  _owned_table()[key] = nil
  return true
end

function Q.fingerprint(cmd, opts)
  cmd = _trim(cmd)
  if cmd == "" then return "" end
  opts = opts or {}
  local target = _trim(opts.target)
  local route = _route_from_opts(opts)
  return table_concat({ cmd:lower(), target:lower(), route:lower() }, "|")
end

function Q.same_lane_cmd(lane, cmd, opts)
  local key = _lane_key(lane)
  if not key then return false end
  local owned = Q.get_owned(key)
  if type(owned) ~= "table" then return false end
  local fp = Q.fingerprint(cmd, opts)
  if fp == "" then return false end
  if _trim(owned.fingerprint) == fp then return true end
  return _trim(owned.cmd) == _trim(cmd)
end

function Q.clear_lane(lane, opts)
  opts = opts or {}
  local key = _lane_key(lane)
  if not key then return false, "invalid_lane" end
  local qtype = _trim(opts.qtype or Q.qtype_for_lane(key))
  if qtype == "" then return false, "invalid_qtype" end
  local ok = Q.raw("CLEARQUEUE " .. qtype)
  if not ok then return false, "clear_failed" end
  Q.clear_owned(key)
  if type(Q.clear_lane_dispatched) == "function" and key ~= "free" then
    Q.clear_lane_dispatched(key, "clear_lane")
  end
  return true
end

function Q.mark_lane_dispatched(lane, reason)
  local key = _lane_key(lane)
  if not key or key == "free" then return false, "invalid_lane" end
  local now = _now()
  local debounce = tonumber(Q.cfg.lane_dispatch_debounce_s or 0.25) or 0.25
  if debounce < 0.05 then debounce = 0.05 end
  Q._lane_dispatched = Q._lane_dispatched or {}
  Q._lane_dispatched[key] = {
    active = true,
    at = now,
    until_at = now + debounce,
    reason = _trim(reason),
  }
  if key == "bal" then
    _debug("[Queue] BAL dispatched; suppressing same-tick re-entry")
  end
  return true
end

function Q.clear_lane_dispatched(lane, reason)
  local key = _lane_key(lane)
  if not key or key == "free" then return false, "invalid_lane" end
  local row = Q._lane_dispatched and Q._lane_dispatched[key] or nil
  if type(row) ~= "table" or row.active ~= true then
    return true, "already_clear"
  end
  Q._lane_dispatched[key] = nil
  if key == "bal" then
    _debug("[Queue] BAL dispatch settled: " .. tostring(reason or "clear"))
  end
  return true
end

function Q.can_plan_lane(lane)
  local key = _lane_key(lane)
  if not key then return false end
  if key == "free" then return true end
  local row = Q._lane_dispatched and Q._lane_dispatched[key] or nil
  if type(row) ~= "table" or row.active ~= true then
    return true
  end
  if tonumber(row.until_at or 0) > 0 and _now() >= tonumber(row.until_at or 0) then
    Q.clear_lane_dispatched(key, "debounce_timeout")
    return true
  end
  return false
end

local function _lane_send_allowed(lane, cmd)
  if _trim(cmd) == "" then return false end
  local blocked = type(Q.lane_blocked) == "function" and Q.lane_blocked(lane) or false
  if blocked == true then
    -- Recheck at send time so newly-applied writhe blocks cannot leak stale lane payloads.
    Q._staged[lane] = nil
    return false
  end
  return true
end

------------------------------------------------------------
-- Public: lane block / unblock
------------------------------------------------------------

function Q.lane_blocked(lane)
  local key = _lane_key(lane)
  if not key or key == "free" then return false, "" end
  local row = Q._blocked and Q._blocked[key] or nil
  if type(row) ~= "table" then return false, "" end
  if row.active ~= true then return false, "" end
  return true, _trim(row.reason), row
end

function Q.block_lane(lane, reason, opts)
  opts = opts or {}
  local key = _lane_key(lane)
  if not key or key == "free" then return false, "invalid_lane" end

  local was_blocked = Q.lane_blocked(key)
  local now = _now()
  local why = _trim(reason)
  if why == "" then why = "blocked" end

  Q._blocked = type(Q._blocked) == "table" and Q._blocked or {}
  Q._blocked[key] = {
    active = true,
    reason = why,
    source = _trim(opts.source),
    blocked_at = now,
  }

  if opts.clear_staged ~= false then
    Q._staged[key] = nil
  end

  if opts.clear_owned == true then
    local owned = type(Q.get_owned) == "function" and Q.get_owned(key) or nil
    if type(owned) == "table" and type(Q.clear_lane) == "function" then
      local ok = Q.clear_lane(key, { qtype = opts.qtype })
      if not ok and type(Q.clear_owned) == "function" then
        Q.clear_owned(key)
      end
    elseif type(Q.clear_owned) == "function" then
      Q.clear_owned(key)
    end
  end

  if Yso and Yso.trace and type(Yso.trace.push) == "function" then
    pcall(Yso.trace.push, "queue.block", {
      ts = now,
      lane = key,
      reason = why,
      source = _trim(opts.source),
      changed = (was_blocked ~= true),
    })
  end

  return true, was_blocked and "unchanged" or "blocked", Q._blocked[key]
end

function Q.unblock_lane(lane, reason, opts)
  opts = opts or {}
  local key = _lane_key(lane)
  if not key or key == "free" then return false, "invalid_lane" end

  local blocked, _, prev = Q.lane_blocked(key)
  if blocked ~= true then return true, "already_clear" end

  Q._blocked[key] = nil
  local now = _now()
  if Yso and Yso.trace and type(Yso.trace.push) == "function" then
    pcall(Yso.trace.push, "queue.unblock", {
      ts = now,
      lane = key,
      reason = _trim(reason),
      prior_reason = type(prev) == "table" and _trim(prev.reason) or "",
      source = _trim(opts.source),
    })
  end
  return true
end

------------------------------------------------------------
-- Public: lane install / staging / clearing
------------------------------------------------------------

function Q.install_lane(lane, cmd, opts)
  opts = opts or {}
  local key = _lane_key(lane)
  if not key then return false, "invalid_lane" end
  local blocked = Q.lane_blocked(key)
  if blocked == true and opts.force_blocked ~= true then
    return false, "lane_blocked"
  end
  cmd = _trim(cmd)
  if cmd == "" then
    return Q.clear_lane(key, opts)
  end
  local qtype = _trim(opts.qtype or Q.qtype_for_lane(key))
  if qtype == "" then return false, "invalid_qtype" end

  if Q.same_lane_cmd(key, cmd, opts) then
    return true, "unchanged", Q.get_owned(key)
  end

  if key ~= "free" and opts.force_blocked ~= true then
    -- Final recheck directly before queue send so late-tick writhe blocks
    -- cannot leak staged lane payloads between commit assembly and install.
    local blocked_now = type(Q.lane_blocked) == "function" and Q.lane_blocked(key) or false
    if blocked_now == true then
      Q._staged[key] = nil
      return false, "lane_blocked"
    end
  end

  local existed = (type(Q.get_owned(key)) == "table")
  local ok = Q.addclear(qtype, cmd)
  if not ok then
    local rec = Q.get_owned(key)
    if type(rec) == "table" then
      rec.last_result = "error"
      rec.last_error = "addclear_failed"
    end
    return false, "addclear_failed"
  end

  local rec = {
    cmd = cmd,
    qtype = qtype,
    target = _trim(opts.target),
    fingerprint = Q.fingerprint(cmd, opts),
    route = _route_from_opts(opts),
    installed_at = _now(),
    source_file = _trim(opts.source_file),
    note = _trim(opts.note),
    last_result = existed and "replaced" or "installed",
    last_error = "",
  }
  Q.set_owned(key, rec)
  return true, rec.last_result, rec
end

-- Clear staged lane(s)
--  * free lane is a list -> cleared to {}
--  * eq/bal/class are cleared to nil
function Q.clear(lane)
  local targets = _clear_targets(lane)
  if #targets == 0 then return false end

  for i = 1, #targets do
    local key = targets[i]
    if key == "free" then
      Q._staged.free = {}
    else
      Q._staged[key] = nil
    end
  end

  return true
end

function Q.flush_staged()
  Q._staged = {
    free = {},
    eq = nil,
    bal = nil,
    class = nil,
  }
  return true
end

function Q.list(lane)
  local key = _lane_key(lane)
  if not key then return _snapshot() end
  if key == "free" then return _clone_free(Q._staged.free) end
  return Q._staged[key]
end

function Q.stage(lane, payload, opts)
  opts = opts or {}
  local key, staged_payload, compat = _coerce_stage_args(lane, payload)
  if not key then return false end
  local blocked = Q.lane_blocked(key)
  if blocked == true and key ~= "free" then
    Q._staged[key] = nil
    return false, "lane_blocked"
  end
  payload = staged_payload

  if compat == "swapped" then
    _debug(("stage compat swap => %s :: %s"):format(key, _trim(payload)))
  elseif compat == "inferred" then
    _debug(("stage compat infer => %s :: %s"):format(key, _trim(payload)))
  end

  if key == "free" then
    if type(payload) ~= "string" and type(payload) ~= "table" then return false end
    if opts.clear == true or opts.replace == true then
      Q._staged.free = {}
    end
    local parts = _split_free(payload)
    if #parts == 0 then return false end
    for i = 1, #parts do
      table_insert(Q._staged.free, parts[i])
    end
    return true
  end

  if type(payload) == "boolean" then return false end
  if type(payload) ~= "string" then
    if type(payload) == "number" then
      payload = tostring(payload)
    else
      return false
    end
  end
  payload = _trim(payload)
  if payload == "" then return false end
  Q._staged[key] = payload
  return true
end

-- Q.push is an alias for Q.stage (older call sites use push).
function Q.push(lane, payload, opts)
  return Q.stage(lane, payload, opts)
end

function Q.replace(lane, payload, opts)
  opts = opts or {}
  if not Q.clear(lane) then return false end
  opts.replace = true
  return Q.stage(lane, payload, opts)
end

------------------------------------------------------------
-- Public: commit and emit
------------------------------------------------------------

function Q.commit(opts)
  local payload = _commit_payload(opts)
  if not _payload_has_value(payload) then return false end

  opts = opts or {}
  local queued = {}
  local consumed = {}
  local any = false

  if type(payload.free) == "table" and #payload.free > 0 then
    local free_cmd = table_concat(payload.free, _command_sep())
    local ok, result = Q.install_lane("free", free_cmd, opts)
    if not ok then return false end
    consumed.free = payload.free
    if result ~= "unchanged" then
      queued.free = payload.free
      any = true
    end
  end

  if _lane_send_allowed("eq", payload.eq) then
    local ok, result = Q.install_lane("eq", payload.eq, opts)
    if not ok then return false end
    consumed.eq = payload.eq
    if result ~= "unchanged" then
      queued.eq = payload.eq
      any = true
    end
  end

  if _lane_send_allowed("bal", payload.bal) then
    local ok, result = Q.install_lane("bal", payload.bal, opts)
    if not ok then return false end
    consumed.bal = payload.bal
    if result ~= "unchanged" then
      queued.bal = payload.bal
      any = true
    end
  end

  if _lane_send_allowed("class", payload.class) then
    local ok, result = Q.install_lane("class", payload.class, opts)
    if not ok then return false end
    consumed.class = payload.class
    if result ~= "unchanged" then
      queued.class = payload.class
      any = true
    end
  end

  if not any then
    _clear_payload(consumed)
    return false
  end

  _clear_payload(consumed)
  if type(Q.mark_lane_dispatched) == "function" then
    if _trim(queued.eq) ~= "" then pcall(Q.mark_lane_dispatched, "eq", "queue.commit") end
    if _trim(queued.bal) ~= "" then pcall(Q.mark_lane_dispatched, "bal", "queue.commit") end
    if _trim(queued.class) ~= "" then pcall(Q.mark_lane_dispatched, "class", "queue.commit") end
  end
  _mark_payload_queued(queued)
  _mark_payload_fired(queued)
  _debug("commit queued => " .. _payload_line(queued))
  return true, queued
end

function Q.emit(payload, opts)
  if Yso and type(Yso.emit) == "function" then
    return Yso.emit(payload, opts or {})
  end

  opts = opts or {}
  if opts.solo == true then Q.clear() end

  if type(payload) == "string" then
    if not Q.stage("free", payload, opts) then return false end
  elseif type(payload) == "table" then
    if payload[1] ~= nil
       and payload.free == nil and payload.pre == nil
       and payload.eq == nil and payload.bal == nil
       and payload.class == nil and payload.ent == nil and payload.entity == nil
    then
      if not Q.stage("free", payload, opts) then return false end
    else
      if payload.free ~= nil then Q.stage("free", payload.free, opts)
      elseif payload.pre ~= nil then Q.stage("free", payload.pre, opts) end
      if payload.eq ~= nil then Q.stage("eq", payload.eq, opts) end
      if payload.bal ~= nil then Q.stage("bal", payload.bal, opts) end
      local class_cmd = payload.class or payload.ent or payload.entity
      if class_cmd ~= nil then Q.stage("class", class_cmd, opts) end
    end
  else
    return false
  end

  local ok = Q.commit(opts)
  return ok == true
end

------------------------------------------------------------
-- Raw QUEUE compatibility wrappers
--  These send QUEUE ADDCLEAR / ADDCLEARFULL directly and exist for
--  older XML-resident helpers that haven't migrated to stage/commit.
------------------------------------------------------------

function Q.addclear(qtype, payload)
  return _raw_queue("ADDCLEAR", qtype, payload)
end

function Q.addclearfull(qtype, payload)
  return _raw_queue("ADDCLEARFULL", qtype, payload)
end

function Q.addclearfull_bu(payload)
  return Q.addclearfull("bu", payload)
end

function Q.eq_clear(payload)
  return Q.addclear("eq", payload)
end

function Q.bal_clear(payload)
  return Q.addclear("bal", payload)
end

function Q.class_clear(payload)
  return Q.addclear("class", payload)
end

function Q.eqbal_clear(payload)
  return Q.addclear("eqbal", payload)
end

function Q.free(payload)
  return Q.addclear("free", payload)
end

function Q.raw(mode, qtype, payload)
  if payload ~= nil then
    return _raw_queue(mode, qtype, payload)
  end
  local body = _trim(mode or qtype)
  if body == "" then return false end
  return _send_compound(body)
end

-- Expose _mark_payload_fired as a public entry point so external modules
-- (e.g. route drivers that fire payloads through their own path) can still
-- notify Yso.locks without going through Q.commit.
function Q.mark_payload_fired(payload)
  _mark_payload_fired(payload)
end

------------------------------------------------------------
-- Startup initialisation
------------------------------------------------------------

do
  -- Deferred one tick so Yso.self and other modules finish loading before
  -- the writhe check runs.  Falls back to immediate check if tempTimer is
  -- not yet available (e.g. in a bare test environment).
  local function _init_writhe_check()
    local is_writhed = Yso and Yso.self
      and type(Yso.self.is_writhed) == "function"
      and Yso.self.is_writhed() == true
    if is_writhed then
      Q.block_lane("eq",  "writhe", { source = "queue.init", clear_owned = true, clear_staged = true })
      Q.block_lane("bal", "writhe", { source = "queue.init", clear_owned = true, clear_staged = true })
    end
  end
  if type(tempTimer) == "function" then
    tempTimer(0, _init_writhe_check)
  else
    _init_writhe_check()
  end
end

return Q
