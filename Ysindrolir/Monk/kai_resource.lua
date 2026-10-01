--========================================================--
-- Monk Kai resource
--  gmcp.Char.Vitals.charstats is a list of "Label: value" strings.
--  Captured: { "Bleed: 0", "Rage: 0", "Kai: 0%", "Stance: None" }
--  hadoken is the Kai percent as a number. Aliases compare it directly.
--========================================================--

Yso = Yso or {}
Yso.monk = Yso.monk or {}
Yso.monk.kai = Yso.monk.kai or {}

local K = Yso.monk.kai

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

function K.apply_charstats(list)
  if type(list) ~= "table" then return K.current end
  for _, entry in ipairs(list) do
    local label, value = _label_value(entry)
    if label == "kai" then
      local n = tonumber((value:gsub("%%", "")))
      if n then
        if n < 0 then n = 0 end
        if n > 100 then n = 100 end
        K.current = n
        _G.hadoken = n
      end
    end
  end
  local stance = Yso.monk and Yso.monk.stance
  if stance and type(stance.apply_charstats) == "function" then
    stance.apply_charstats(list)
  end
  return K.current
end

local function _on_vitals()
  local g = rawget(_G, "gmcp")
  local stats = g and g.Char and g.Char.Vitals and g.Char.Vitals.charstats
  K.apply_charstats(stats)
end

if type(registerAnonymousEventHandler) == "function" and not K._eh then
  K._eh = registerAnonymousEventHandler("gmcp.Char.Vitals", _on_vitals)
end
