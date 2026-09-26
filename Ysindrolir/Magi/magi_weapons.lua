--========================================================--
-- magi_weapons.lua
--  * In-session staff/shield item ids (vary per character).
--  * Set from Lua: Yso.magi.weapons.set("staff", "32501")
--  * No aliases, no persist, no hardcoded ids.
--========================================================--

Yso = Yso or {}
Yso.magi = Yso.magi or {}
Yso.magi.weapons = Yso.magi.weapons or {}

local W = Yso.magi.weapons
W.ids = W.ids or { staff = "", shield = "" }

local KINDS = { staff = true, shield = true }

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _kind(kind)
  return _trim(kind):lower()
end

local function _id_digits(id)
  id = _trim(id)
  if id == "" then return "" end
  local digits = id:match("(%d+)$") or id:match("(%d+)")
  return digits or ""
end

function W.set(kind, id)
  kind = _kind(kind)
  if not KINDS[kind] then return false end
  W.ids = W.ids or { staff = "", shield = "" }
  W.ids[kind] = _id_digits(id)
  return true
end

function W.get(kind)
  kind = _kind(kind)
  if not KINDS[kind] then return "" end
  W.ids = W.ids or { staff = "", shield = "" }
  return _trim(W.ids[kind] or "")
end

function W.wield_cmd(kind)
  kind = _kind(kind)
  local id = W.get(kind)
  if id == "" then return nil end
  return "wield " .. kind .. id
end

function W.send_wields()
  local sent = false
  for _, kind in ipairs({ "shield", "staff" }) do
    local cmd = W.wield_cmd(kind)
    if cmd then
      if type(Yso.send) == "function" then
        pcall(Yso.send, cmd)
      elseif type(send) == "function" then
        pcall(send, cmd, false)
      end
      sent = true
    end
  end
  return sent
end

return W
