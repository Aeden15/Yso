--========================================================--
-- Yso offense shared state
--  • Route-loop shared send memory for alias-owned offense.
--  • Tracks recent tags and lockouts for alias-owned routes.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.state = Yso.off.state or {}

local S = Yso.off.state

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    if ok and tonumber(v) then return tonumber(v) end
  end
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

S.last_sent = S.last_sent or {}
S.lockouts = S.lockouts or {}

function S.recent(tag, within_s)
  tag = _trim(tag)
  if tag == "" then return false end
  local row = S.last_sent[tag]
  if type(row) ~= "table" then return false end
  local within = tonumber(within_s or 0) or 0
  return (_now() - tonumber(row.at or 0)) <= within
end

function S.note(tag, cmd, opts)
  tag = _trim(tag)
  cmd = _trim(cmd)
  if tag == "" or cmd == "" then return false end

  opts = type(opts) == "table" and opts or {}
  local at = tonumber(opts.at or _now()) or _now()
  local hold = tonumber(opts.lockout or opts.hold or 0) or 0

  S.last_sent[tag] = {
    cmd = cmd,
    state_sig = tostring(opts.state_sig or "route_local"),
    at = at,
  }

  if hold > 0 then
    S.lockouts[tag] = at + hold
  else
    S.lockouts[tag] = nil
  end
  return true
end

function S.locked(tag)
  tag = _trim(tag)
  if tag == "" then return false, 0 end
  local exp = tonumber(S.lockouts[tag] or 0) or 0
  local now = _now()
  if exp <= now then
    S.lockouts[tag] = nil
    return false, 0
  end
  return true, (exp - now)
end

function S.clear(tag)
  tag = _trim(tag)
  if tag == "" then
    S.last_sent = {}
    S.lockouts = {}
    return true
  end
  S.last_sent[tag] = nil
  S.lockouts[tag] = nil
  return true
end

function S.prune(now)
  now = tonumber(now or _now()) or _now()
  for tag, exp in pairs(S.lockouts) do
    if tonumber(exp or 0) <= now then
      S.lockouts[tag] = nil
    end
  end
  return true
end

return S
