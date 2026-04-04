--========================================================--
-- Magi dissonance tracker
--  * Lightweight local inference for the Focus route.
--  * Tracks estimated stage, confidence, and last evidence by target.
--========================================================--

Yso = Yso or {}
Yso.magi = Yso.magi or {}
Yso.magi.dissonance = Yso.magi.dissonance or {}

local D = Yso.magi.dissonance

D.state = D.state or {
  by_target = {},
}

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _lc(s)
  return _trim(s):lower()
end

local function _now()
  local RC = Yso and Yso.off and Yso.off.magi and Yso.off.magi.route_core or nil
  if type(RC) == "table" and type(RC.now) == "function" then
    return RC.now()
  end
  if type(getEpoch) == "function" then
    local v = tonumber(getEpoch()) or os.time()
    if v > 20000000000 then v = v / 1000 end
    return v
  end
  return os.time()
end

local CONF_RANK = {
  low = 1,
  medium = 2,
  high = 3,
}

local function _merge_conf(cur, new)
  cur = _lc(cur)
  new = _lc(new)
  if CONF_RANK[new] and CONF_RANK[new] > (CONF_RANK[cur] or 0) then
    return new
  end
  return (CONF_RANK[cur] and cur) or "low"
end

local function _slot(target, create)
  target = _lc(target)
  if target == "" then return nil end
  local row = D.state.by_target[target]
  if row or create == false then return row end
  row = {
    target = target,
    stage = 0,
    confidence = "low",
    last_evidence = "",
    updated_at = 0,
  }
  D.state.by_target[target] = row
  return row
end

local function _copy(row, target)
  row = row or {}
  return {
    target = _trim(target or row.target or ""),
    stage = tonumber(row.stage or 0) or 0,
    confidence = _lc(row.confidence or "low"),
    last_evidence = tostring(row.last_evidence or ""),
    updated_at = tonumber(row.updated_at or 0) or 0,
  }
end

function D.reset()
  D.state.by_target = {}
  return true
end

function D.reset_target(target)
  target = _lc(target)
  if target ~= "" then
    D.state.by_target[target] = nil
  end
  return true
end

function D.note(target, token, opts)
  local row = _slot(target, true)
  if not row then return false end

  token = _lc(token)
  opts = type(opts) == "table" and opts or {}

  local stage = tonumber(opts.stage)
  local confidence = _lc(opts.confidence or "")
  local evidence = tostring(opts.evidence or token)

  if token == "route_send" or token == "send" or token == "embed" then
    stage = math.min(4, math.max(row.stage or 0, (row.stage or 0) + 1))
    confidence = (confidence ~= "" and confidence) or "low"
  elseif token == "resonance" then
    stage = math.max(row.stage or 0, math.max(tonumber(opts.min_stage or 1) or 1, 1))
    confidence = (confidence ~= "" and confidence) or "medium"
  elseif token == "tracked" then
    stage = math.max(row.stage or 0, tonumber(opts.stage or 1) or 1)
    confidence = (confidence ~= "" and confidence) or "medium"
  elseif token == "clear" or token == "reset" then
    stage = 0
    confidence = (confidence ~= "" and confidence) or "low"
    row.stage = 0
    row.confidence = confidence
    row.last_evidence = evidence
    row.updated_at = _now()
    return true, _copy(row)
  end

  if stage ~= nil then
    if stage < 0 then stage = 0 end
    if stage > 4 then stage = 4 end
    row.stage = stage
  end
  row.confidence = _merge_conf(row.confidence, confidence ~= "" and confidence or row.confidence)
  row.last_evidence = evidence
  row.updated_at = _now()
  return true, _copy(row)
end

function D.snapshot(target)
  target = _trim(target)
  if target == "" then
    return _copy(nil, target)
  end
  return _copy(_slot(target, false), target)
end

return D
