-- Magi_duel_dam.lua
-- Thin-alias route module for the Magi duel damage route.
-- Intended toggle:
--   ^mdam$  ->  Yso.off.core.toggle("magi_dmg")
--
-- The route logic below preserves the same priority/order that was planned
-- for the Magi damage alias body, while living in an external file so it
-- remains easy to edit.

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.magi = Yso.off.magi or {}

local M = Yso.off.magi.dmg or {}
Yso.off.magi.dmg = M

M.key = "magi_dmg"
M.name = "Magi Duel Damage"

local function _trim(s)
  s = tostring(s or "")
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function _vitals()
  return (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
end

local function _eq_ready()
  local v = _vitals()
  return tostring(v.eq or v.equilibrium or "") == "1"
end

local function _target()
  if Yso and type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    v = ok and _trim(v) or ""
    if v ~= "" then return v end
  end

  if Yso and Yso.targeting then
    if type(Yso.targeting.get) == "function" then
      local ok, v = pcall(Yso.targeting.get)
      v = ok and _trim(v) or ""
      if v ~= "" then return v end
    elseif type(Yso.targeting.get_target) == "function" then
      local ok, v = pcall(Yso.targeting.get_target)
      v = ok and _trim(v) or ""
      if v ~= "" then return v end
    elseif type(Yso.targeting.target) == "string" then
      local v = _trim(Yso.targeting.target)
      if v ~= "" then return v end
    end
  end

  return _trim(rawget(_G, "target") or "")
end

local function _score(name)
  local score = (_G.affstrack and affstrack.score) or {}
  return tonumber(score[name] or 0) or 0
end

local function _assess()
  return tonumber(Yso.magi_assess or 999) or 999
end

local function _shielded(tgt)
  tgt = string.lower(_trim(tgt))

  if Yso and Yso.shield and type(Yso.shield.up) == "function" and tgt ~= "" then
    local ok, v = pcall(Yso.shield.up, tgt)
    if ok then return v == true end
  end

  if ak and ak.defs then
    if type(ak.defs.shield_by_target) == "table" and tgt ~= "" then
      return ak.defs.shield_by_target[tgt] == true
    end
    return ak.defs.shield == true
  end

  return false
end

function M.can_run(reason)
  local cls = tostring((gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class) or Yso.class or "")
  if cls:lower() ~= "magi" then return false, "wrong_class" end
  if not _eq_ready() then return false end
  if _target() == "" then return false end
  return true
end

function M.build(reason)
  local tgt = _target()
  if tgt == "" then return nil end

  local assess = _assess()

  -- Shield handling
  if _shielded(tgt) then
    return "cast erode " .. tgt .. " maintain"

  -- Instant kills
  elseif _score("conflagrate") >= 100 and assess <= 40 then
    return "cast destroy at " .. tgt

  elseif assess <= 25 or (assess <= 30 and _score("sensitivity") >= 100) then
    return "cast stormhammer at " .. tgt

  -- Debuff timer setup
  elseif _score("scalded") < 100 then
    return "cast magma " .. tgt

  elseif _score("scalded") >= 100 and _score("waterbonds") < 100 then
    return "staff cast horripilation at " .. tgt

  -- Affliction pressure
  elseif _score("clumsiness") < 100 then
    return "cast bombard " .. tgt

  elseif _score("clumsiness") >= 100 and _score("slickness") < 100 then
    return "cast mudslide " .. tgt

  elseif _score("nausea") < 100 and _score("weariness") < 100 then
    return "cast dehydrate " .. tgt

  else
    local fulm_score =
      _score("clumsiness") +
      _score("weariness") +
      _score("slickness") +
      _score("nausea") +
      _score("sensitivity")

    if fulm_score > 200 then
      return "cast fulminate " .. tgt
    end

    local earth_res = tonumber((((ak or {}).magi or {}).resonance or {})["Earth"] or 0) or 0
    if earth_res == 2 then
      return "cast shalestorm at " .. tgt
    end
  end

  return nil
end

function M.after_send(cmd, reason)
  M.last_cmd = cmd
  M.last_reason = tostring(reason or "")
  M.last_target = _target()
end

function M.on_start()
  return M.on(true)
end

function M.on_stop()
  return M.off()
end

-- Optional convenience wrappers if you want to test this route directly
-- before/offside of the centralized offense core. Once Yso.off.core exists,
-- prefer the central lifecycle and keep ^mdam$ thin.
function M.tick(reason)
  if not M.can_run(reason) then return false end
  local cmd = M.build(reason)
  if not cmd or cmd == "" then return false end
  send(cmd)
  M.after_send(cmd, reason)
  return true
end

function M.on()
  M.enabled = true
  return true
end

function M.off()
  M.enabled = false
  return true
end

function M.toggle()
  M.enabled = not M.enabled
  return M.enabled
end

if Yso.off.core and type(Yso.off.core.register) == "function" then
  pcall(Yso.off.core.register, M.key, M)
end

return M
