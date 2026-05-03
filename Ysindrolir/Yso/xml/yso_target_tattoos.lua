--========================================================--
-- yso_target_tattoos.lua (DROP-IN)
--  • Tracks target Mindseye as a sticky defense (no duration).
--  • Tracks Tree-of-life touch as a passive uncertainty marker.
--  • Manual clear: alias msclear [name] (defined in AliasPackage).
--  • Clear-on-starburst is handled by Coordination module.
--========================================================--

Yso = Yso or {}
Yso.tgt = Yso.tgt or {}
local T = Yso.tgt

local function _now()
  return (type(getEpoch) == "function" and getEpoch()) or os.time()
end

local function _trim(s)
  return tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")
end

-- Prefer intel module record if available; else fall back to a simple table.
local function _rec(name)
  name = _trim(name)
  if name == "" then return nil end
  if type(T.get) == "function" then
    return T.get(name)
  end
  T._tat = T._tat or {}
  local k = name:lower()
  T._tat[k] = T._tat[k] or { defs = {}, meta = {} }
  return T._tat[k]
end

function T.set_mindseye(name, val, silent)
  local r = _rec(name); if not r then return false end
  r.defs = r.defs or {}
  r.defs.mindseye = (val == true)

  if not silent then
    if val == true then
      cecho(string.format("<yellow>[DEFENSE] <reset>Mindseye noted on %s.\n", _trim(name)))
    else
      cecho(string.format("<yellow>[DEFENSE] <reset>Mindseye cleared on %s.\n", _trim(name)))
    end
  end
  return true
end

function T.has_mindseye(name)
  local r = _rec(name); if not r then return false end
  return (r.defs and r.defs.mindseye) == true
end

function T.note_tree_touch(name)
  local r = _rec(name); if not r then return false end
  r.meta = r.meta or {}
  r.meta.last_tree_touch = _now()
  return true
end

-- “Can hear/see” helpers: mindseye overrides deaf/blind gating.
local function _score_from_affstrack(aff)
  if type(affstrack) ~= "table" then return 0 end
  local scores = affstrack.score
  if type(scores) ~= "table" then return 0 end
  return tonumber(scores[aff] or 0) or 0
end

function T.can_hear(name)
  if T.has_mindseye(name) then return true end
  local deaf = _score_from_affstrack("deaf")
  return deaf <= 0
end

function T.can_see(name)
  if T.has_mindseye(name) then return true end
  local blind = _score_from_affstrack("blind")
  return blind <= 0
end
