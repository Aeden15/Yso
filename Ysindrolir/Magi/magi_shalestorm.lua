--========================================================--
-- magi_shalestorm.lua
--  * Magi-wide shalestorm flag. Readable from any Magi route.
--  * Set from live Elementalism triggers, not from a successful send.
--========================================================--

Yso = Yso or {}
Yso.magi = Yso.magi or {}
Yso.magi.shalestorm = Yso.magi.shalestorm or {}

local S = Yso.magi.shalestorm

S.active = S.active == true
S.target = tostring(S.target or "")
S.at = tonumber(S.at or 0) or 0
S.reason = tostring(S.reason or "")

local function _now()
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _lc(s)
  return _trim(s):lower()
end

function S.set_up(target)
  S.active = true
  S.target = _trim(target)
  S.at = _now()
  S.reason = "cast"
  return true
end

function S.set_down(reason)
  S.active = false
  S.target = ""
  S.at = _now()
  S.reason = tostring(reason or "down")
  return true
end

function S.is_up(target)
  if S.active ~= true then return false end
  target = _trim(target)
  if target == "" then return true end
  return _lc(S.target) == _lc(target)
end

return S
