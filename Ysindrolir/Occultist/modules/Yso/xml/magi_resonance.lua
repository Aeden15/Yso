-- Auto-exported from Mudlet package script: Magi Resonance (Yso)
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Magi — Resonance Tracker (Achaea)
--
-- Purpose:
--   • Track YOUR elemental resonance (air/earth/fire/water) from the
--     balanceless RESONANCE command output.
--   • Provide stable getters that other Magi modules (eg. Convergence)
--     can depend on.
--
-- Integration:
--   • If AK already tracks resonance (ak.magi.resonance), we read that.
--   • Otherwise we maintain our own tracker via regex triggers.
--
-- Notes:
--   • RESONANCE output examples:
--       "You are not resonant with the Elemental Plane of Air."
--       "You are now majorly resonant with the Elemental Plane of Fire."
--========================================================--

Yso = Yso or {}
Yso.magi = Yso.magi or {}

local M = Yso.magi
M.cfg = M.cfg or {
  debug = false,
  -- Minimum seconds between RESONANCE queries when using request_resonance().
  query_interval = 8,
}

M._res = M._res or {
  air = 0,
  earth = 0,
  fire = 0,
  water = 0,
}

M._last_query = M._last_query or 0
M._trig = M._trig or {}

local function _now()
  if type(getEpoch) == "function" then return getEpoch() end
  return os.time()
end

local function _echo(msg)
  if M.cfg and M.cfg.debug then
    cecho(string.format("<gray>[Yso:Magi] %s\n", tostring(msg)))
  end
end

local function _norm_plane(s)
  s = tostring(s or ""):lower():gsub("[%s%-]+", "")
  if s == "air" or s == "earth" or s == "fire" or s == "water" then return s end
  return nil
end

local function _rank_from_word(w)
  w = tostring(w or ""):lower()
  if w:find("minor") then return 1 end
  if w:find("moder") then return 2 end
  if w:find("major") then return 3 end
  return 0
end

-- -----------------------------
-- Public API
-- -----------------------------

-- Returns resonance rank 0..3 for a plane (air/earth/fire/water).
function M.resonance_rank(plane)
  local p = _norm_plane(plane)
  if not p then return 0 end

  -- Prefer AK if available
  local ak = rawget(_G, "ak")
  if ak and ak.magi and type(ak.magi.resonance) == "table" then
    local v = ak.magi.resonance[p]
    v = tonumber(v)
    if v then return v end
  end
  return tonumber(M._res[p]) or 0
end

-- True if ALL planes are >= min_rank.
function M.resonance_all_at_least(min_rank)
  min_rank = tonumber(min_rank) or 0
  return (M.resonance_rank("air")   >= min_rank)
     and (M.resonance_rank("earth") >= min_rank)
     and (M.resonance_rank("fire")  >= min_rank)
     and (M.resonance_rank("water") >= min_rank)
end

-- Fire a balanceless RESONANCE query at most every cfg.query_interval seconds.
-- If force=true, always sends.
function M.request_resonance(force)
  local t = _now()
  if force or (t - (M._last_query or 0)) >= (M.cfg.query_interval or 8) then
    if type(send) == "function" then send("resonance", false) end
    M._last_query = t
    _echo("sent: resonance")
    return true
  end
  return false
end

-- -----------------------------
-- Trigger wiring (fallback tracker)
-- -----------------------------

local function _safe(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then _echo("ERR: " .. tostring(err)) end
  end
end

local function _set_rank(plane, rank)
  local p = _norm_plane(plane)
  if not p then return end
  rank = tonumber(rank) or 0
  if rank < 0 then rank = 0 end
  if rank > 3 then rank = 3 end
  M._res[p] = rank
  _echo(string.format("res[%s]=%d", p, rank))
end

local function _kill(id)
  if id then
    if type(killTrigger) == "function" then killTrigger(id) end
  end
end

local function install_triggers()
  -- Only install our fallback triggers once.
  if M._trig and M._trig._installed then return end
  M._trig = M._trig or {}

  -- Not resonant
  _kill(M._trig.res0)
  M._trig.res0 = tempRegexTrigger(
    [[^You are not resonant with the Elemental Plane of (\w+)\.$]],
    _safe(function()
      local p = matches[2]
      _set_rank(p, 0)
    end)
  )

  -- Minor/Moderate/Major (with optional "now")
  _kill(M._trig.resN)
  M._trig.resN = tempRegexTrigger(
    [[^You are(?: now)? (minorly|moderately|majorly) resonant with the Elemental Plane of (\w+)\.$]],
    _safe(function()
      local word = matches[2]
      local p = matches[3]
      _set_rank(p, _rank_from_word(word))
    end)
  )

  M._trig._installed = true
end

install_triggers()

return M
