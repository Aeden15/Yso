--========================================================--
-- Monk Kai resource
--  gmcp.Char.Vitals.charstats is a list of "Label: value" strings.
--  Tekura: { "Bleed: 0", "Rage: 0", "Kai: 0%", "Stance: None" }
--  Shikudo adds "Form: <name>" and "Kata: <number>". Both vary.
--  Hadoken() reads current GMCP Kai (0 when unavailable).
--  hadoken remains a numeric compatibility mirror.
--========================================================--

Yso = Yso or {}
Yso.monk = Yso.monk or {}
Yso.monk.kai = Yso.monk.kai or {}

local K = Yso.monk.kai

-- Server-confirmed cooldown and channel state; neither changes Kai amounts.
K.burst = K.burst or {}
K.deliverance = K.deliverance or {state = "idle"}
local D = K.deliverance

function K.on_burst(result)
  if result == "used" or result == "cooldown" then
    K.burst.ready = false
  elseif result == "ready" then
    K.burst.ready = true
  end
  K.burst.last_result = result
end

local function _curing()
  return Legacy and Legacy.Settings and Legacy.Settings.Curing
end

local function _cancel_confirmation()
  D.generation = (D.generation or 0) + 1
  if D.timer and type(killTimer) == "function" then killTimer(D.timer) end
  D.timer = nil
end

local function _restore_curing()
  local owned = D.paused_curing
  D.paused_curing = false
  local curing = _curing()
  if owned and curing and curing.status == false then expandAlias("pp") end
end

function K.on_deliverance(state)
  if state ~= "idle" and state ~= "channeling" and state ~= "active" then return end
  _cancel_confirmation()
  D.state = state
  if state == "idle" then _restore_curing() end
end

function K.start_deliverance()
  if D.state ~= "idle" then return false, "deliverance_busy" end
  if (tonumber(rawget(_G, "hadoken")) or 0) <= 81 then return false, "insufficient_kai" end
  local self = Yso.self
  if type(self) ~= "table" or type(self.has_aff) ~= "function"
      or type(self.is_prone) ~= "function" then return false, "self_state_unavailable" end
  if self.has_aff("paralysis") then return false, "paralysis" end
  if self.is_prone() then return false, "prone" end
  local curing = _curing()
  if not curing or type(curing.status) ~= "boolean"
      or type(expandAlias) ~= "function" or type(send) ~= "function"
      or type(tempTimer) ~= "function" then return false, "curing_unavailable" end

  D.state = "pending"
  D.paused_curing = curing.status == true
  _cancel_confirmation()
  local generation = D.generation
  D.timer = tempTimer(5, function()
    if D.generation == generation and D.state == "pending" then
      K.on_deliverance("idle")
    end
  end)
  -- pp is a toggle: never resume a system that was already paused.
  if D.paused_curing then expandAlias("pp") end
  send("kai deliverance")
  return true
end

K.current = tonumber(K.current) or 0
if _G.hadoken == nil then
  _G.hadoken = K.current
end

local function _label_value(entry)
  local label, value = tostring(entry or ""):match("^(.-):%s*(.*)$")
  if not label then return "", "" end
  label = label:gsub("^%s+", ""):gsub("%s+$", ""):lower()
  value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return label, value
end

local function _kai_value(list)
  if type(list) ~= "table" then return 0 end
  for _, entry in ipairs(list) do
    local label, value = _label_value(entry)
    if label == "kai" then
      local n = tonumber((value:gsub("%%$", "")))
      if n and n == n and n ~= math.huge and n ~= -math.huge then
        return math.max(0, math.min(100, n))
      end
      return 0
    end
  end
  return 0
end

function K.apply_charstats(list)
  K.current = _kai_value(list)
  _G.hadoken = K.current
  if type(list) ~= "table" then return K.current end
  local stance = Yso.monk and Yso.monk.stance
  if stance and type(stance.apply_charstats) == "function" then
    stance.apply_charstats(list)
  end
  local shikudo = Yso.monk and Yso.monk.shikudo
  if shikudo and type(shikudo.apply_charstats) == "function" then
    shikudo.apply_charstats(list)
  end
  return K.current
end

local function _on_vitals()
  local g = rawget(_G, "gmcp")
  local stats = g and g.Char and g.Char.Vitals and g.Char.Vitals.charstats
  return K.apply_charstats(stats)
end

function Hadoken()
  local g = rawget(_G, "gmcp")
  local stats = g and g.Char and g.Char.Vitals and g.Char.Vitals.charstats
  -- Reading Kai must not reapply potentially older form/kata confirmations.
  K.current = _kai_value(stats)
  _G.hadoken = K.current
  return K.current
end

if K._eh and type(killAnonymousEventHandler) == "function" then
  killAnonymousEventHandler(K._eh)
  K._eh = nil
end
if type(registerAnonymousEventHandler) == "function" and not K._eh then
  K._eh = registerAnonymousEventHandler("gmcp.Char.Vitals", _on_vitals)
end
Hadoken()
