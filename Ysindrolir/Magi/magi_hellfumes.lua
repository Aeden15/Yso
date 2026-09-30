--========================================================--
-- magi_hellfumes.lua
--  * Magi-wide hellfumes room flag. Readable from any Magi route.
--  * Set from live Elementalism triggers, not from a successful send.
--========================================================--

Yso = Yso or {}
Yso.magi = Yso.magi or {}
Yso.magi.hellfumes = Yso.magi.hellfumes or {}

local S = Yso.magi.hellfumes

-- Unseen stays nil; only set_up/set_down coerce the flag.
if S.active ~= true and S.active ~= false then
  S.active = nil
end
S.room_id = tostring(S.room_id or "")
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

local function _room_id()
  local g = rawget(_G, "gmcp")
  local info = g and g.Room and g.Room.Info
  if info and info.num ~= nil then return tostring(info.num) end
  if info and info.id ~= nil then return tostring(info.id) end
  return ""
end

function S.set_up()
  S.active = true
  S.room_id = _room_id()
  S.at = _now()
  S.reason = "cast"
  return true
end

function S.set_down(reason)
  S.active = false
  S.room_id = ""
  S.at = _now()
  S.reason = tostring(reason or "down")
  return true
end

function S.is_up()
  if S.active ~= true then return false end
  local current = _room_id()
  local stamped = tostring(S.room_id or "")
  if current == "" or stamped == "" then return true end
  return current == stamped
end

return S
