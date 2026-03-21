--========================================================--
-- Yso/Core/queue.lua
--  * Canonical lane-aware queue implementation.
--  * Mirrors to modules/Yso/xml/yso_queue.lua -> package slot "Yso.queue".
--  * Keeps staged lane commits for modern offense code and raw QUEUE wrappers
--    for older XML-resident helpers that still expect addclear/addclearfull.
--========================================================--

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

local Q = Yso.queue

Q.cfg = Q.cfg or {
  debug = false,
  legacy_autocommit = false,
}

Q._staged = Q._staged or {
  free = {},
  eq = nil,
  bal = nil,
  class = nil,
}

Q._impl_version = "2026-03-21.1"

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    if ok and tonumber(v) then return tonumber(v) end
  end
  local t = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  if t and t > 1e12 then t = t / 1000 end
  return t or os.time()
end

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

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

local function _infer_lane_from_payload(payload)
  if type(payload) ~= "string" then return nil end

  local cmd = _trim(payload):lower()
  if cmd == "" then return nil end

  if cmd == "stand"
     or cmd == "diag"
     or cmd == "diagnose"
     or cmd:match("^writhe%s+")
     or cmd:match("^contemplate%s+")
     or cmd:match("^order%s+")
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
  then
    return "bal"
  end

  return "eq"
end

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
  token = _trim(token):lower()
  if token == "" then return { "free", "eq", "bal", "class" } end
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
  elseif lane == "class" and Yso and Yso.state and type(Yso.state.ent_ready) == "function" then
    local ok, res = pcall(Yso.state.ent_ready)
    if ok and res ~= nil then return res == true end
  end

  return true
end

local function _mark_payload_sent(payload)
  if Yso and Yso.locks then
    if type(Yso.locks.note_payload) == "function" then
      pcall(Yso.locks.note_payload, payload)
    elseif type(Yso.locks.note_send) == "function" then
      if _trim(payload.eq) ~= "" then pcall(Yso.locks.note_send, "eq") end
      if _trim(payload.bal) ~= "" then pcall(Yso.locks.note_send, "bal") end
      if _trim(payload.class) ~= "" then pcall(Yso.locks.note_send, "class") end
    end
  end

  if Yso and Yso.trace and type(Yso.trace.push) == "function" then
    local lanes = {}
    if type(payload.free) == "table" and #payload.free > 0 then lanes[#lanes + 1] = "free" end
    if _trim(payload.eq) ~= "" then lanes[#lanes + 1] = "eq" end
    if _trim(payload.bal) ~= "" then lanes[#lanes + 1] = "bal" end
    if _trim(payload.class) ~= "" then lanes[#lanes + 1] = "class" end
    pcall(Yso.trace.push, "queue.commit", {
      ts = _now(),
      lanes = table_concat(lanes, ","),
      cmd = _payload_line(payload),
    })
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

  if wake == "eq" or wake == "bal" or wake == "class" then
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

function Q.push(lane, payload, opts)
  return Q.stage(lane, payload, opts)
end

function Q.replace(lane, payload, opts)
  opts = opts or {}
  if not Q.clear(lane) then return false end
  opts.replace = true
  return Q.stage(lane, payload, opts)
end

function Q.commit(opts)
  local payload = _commit_payload(opts)
  if not _payload_has_value(payload) then return false end

  local body = _payload_line(payload)
  if body == "" then return false end

  local sent = _send_compound(body)
  if not sent then return false end

  _clear_payload(payload)
  _mark_payload_sent(payload)
  _debug("commit => " .. body)
  return true, payload
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

-- Raw QUEUE compatibility wrappers for older XML-resident helpers.
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

return Q
