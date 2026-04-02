-- Auto-exported from Mudlet package script: ProneController
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso_Occultist_ProneController.lua (DROP-IN)
-- Purpose:
--   Provide a small controller that decides how to open a PRONE window
--   (for anorexia via REGRESS) using:
--     • COMMAND CHIMERA AT <t>  (entity balance)
--     • REGRESS <t>            (equilibrium)
--   with deaf-aware handling:
--     • If target is DEAF, chimera roar cures deafness instead of stunning/proning.
--
-- Design:
--   • Does NOT patch your offense by default.
--   • You can:
--       (A) call it explicitly from your offense phase logic, or
--       (B) enable autohook to make it pre-check inside Off.attack_eqonly().
--
-- Requirements:
--   • AK Opponent Tracking (affstrack.score.* including prone/deaf/anorexia)
--   • Yso.off.oc exists if you want autohook
--
-- Notes:
--   • We do NOT use pyradius score/formula here.
--   • We treat "stuck" as score >= 100 (AK convention).
--========================================================--

Yso = Yso or {}
Yso.oc = Yso.oc or {}
Yso.oc.prone = Yso.oc.prone or {}

local P = Yso.oc.prone

P.cfg = P.cfg or {
  enabled = true,
  debug = false,

  autohook = false,          -- keep false until you're ready
  stuck_score = 100,
  gcd = 0.6,

  -- Softlock-ish trigger (matches your intent: "softscore >= 2 and asthma=100")
  softscore_threshold = 2,
  softscore_affs = { "asthma", "anorexia", "slickness", "impatience" },

  -- Actions allowed:
  use_chimera = true,
  use_regress = true,

  -- Availability checks (only used if fields exist; otherwise assumed true)
  require_entity_ready = true,   -- if Yso.occ.entity_ready exists
  require_chimera_ready = false, -- if Yso.occ.chimera_ready exists (you said you track it)
}

local function _echo(s)
  if P.cfg.debug then cecho("<gray>[Yso.oc.prone] " .. s .. "\n") end
end

local function _now()
  return (type(getEpoch)=="function" and getEpoch()) or os.time()
end

local function _gcd_ok()
  P._last = P._last or 0
  return (_now() - P._last) >= (P.cfg.gcd or 0.6)
end

local function _mark()
  P._last = _now()
end

local function _aff()
  return (rawget(_G,"affstrack") and affstrack.score) or {}
end

local function _score(key, aff)
  aff = aff or _aff()
  local v = aff[key]
  v = tonumber(v or 0) or 0
  return v
end

local function _stuck(key, aff)
  return _score(key, aff) >= (P.cfg.stuck_score or 100)
end

local function _eq_ready()
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  local eq = v.equilibrium
  if eq == true then return true end
  return tostring(eq or "") == "1"
end


local function _entity_ready()
  if not P.cfg.require_entity_ready then return true end
  -- Prefer SSOT timed readiness (prevents deadlocks after "disregards your order" or missed ready lines).
  if Yso and Yso.state and type(Yso.state.ent_ready) == "function" then
    local ok, v = pcall(Yso.state.ent_ready)
    if ok and v == true then return true end
  end
  -- Fallback to legacy occ flag if present.
  if Yso.occ and Yso.occ.entity_ready ~= nil then return Yso.occ.entity_ready == true end
  return true
end

local function _chimera_ready()
  if not P.cfg.require_chimera_ready then return true end
  if Yso.occ and Yso.occ.chimera_ready ~= nil then return Yso.occ.chimera_ready == true end
  return true
end

local function _send_eq_clear(cmds)
  if type(cmds) == "string" then cmds = {cmds} end
  if type(cmds) ~= "table" or #cmds == 0 then return false end

  local qtype = "eq"
  if Yso.off and Yso.off.oc and Yso.off.oc.qtype_eq then qtype = Yso.off.oc.qtype_eq end

  local joined = table.concat(cmds, (Yso and Yso.sep) or "&&")

  if Yso.queue and type(Yso.queue.addclear) == "function" then
    Yso.queue.addclear(qtype, joined)
  else
    if type(send)=="function" then send(joined) end
  end
  return true
end

-- Your intended "softscore": count of these affs stuck at 100.
function P.softscore(aff)
  aff = aff or _aff()
  local n = 0
  for _, a in ipairs(P.cfg.softscore_affs or {}) do
    if _stuck(a, aff) then n = n + 1 end
  end
  return n
end

-- Should we try to set up anorexia via prone window?
function P.want_anorexia(aff)
  aff = aff or _aff()
  if not _stuck("asthma", aff) then return false end
  if _stuck("anorexia", aff) then return false end
  return P.softscore(aff) >= (P.cfg.softscore_threshold or 2)
end

-- Core decision:
--   1) If target already prone: REGRESS to apply anorexia (if EQ ready)
--   2) Else:
--        - If target NOT deaf: COMMAND CHIMERA AT <t> to stun/prone (entity ready/optional chimera ready)
--        - If target deaf: COMMAND CHIMERA AT <t> to strip deafness first (no prone), then next pass can prone
--        - If chimera not available: REGRESS to force prone (no anorexia yet), then regress again while prone
function P.step(t, aff)
  if not (P.cfg.enabled and t and t ~= "") then return false end
  aff = aff or _aff()

  if not _gcd_ok() then return false end

  local stuck = P.cfg.stuck_score or 100
  local prone = _score("prone", aff)
  local deaf  = _score("deaf", aff)
  if Yso and Yso.tgt and type(Yso.tgt.has_mindseye)=="function" and Yso.tgt.has_mindseye(t) then deaf = 0 end
  local anore = _score("anorexia", aff)

  -- 1) Already prone: regress applies anorexia (per your helpfile)
  if prone >= stuck then
    if P.cfg.use_regress and _eq_ready() and anore < stuck then
      _echo("target prone -> regress for anorexia")
      _mark()
      return _send_eq_clear(("regress %s"):format(t))
    end
    return false
  end

  -- 2) Not prone: try chimera path first if allowed
  if P.cfg.use_chimera and _entity_ready() and _chimera_ready() then
    -- If target is deaf, chimera roar cures deafness (setup step).
    if deaf >= stuck then
      _echo("target deaf -> command chimera to strip deafness (setup)")
      _mark()
      return _send_eq_clear(("command chimera at %s"):format(t))
    end

    -- Not deaf: chimera command should stun/prone
    _echo("target not deaf -> command chimera for stun/prone window")
    _mark()
    return _send_eq_clear(("command chimera at %s"):format(t))
  end

  -- 3) Fallback: regress to force prone (setup); next tick can regress again for anorexia
  if P.cfg.use_regress and _eq_ready() then
    _echo("fallback -> regress to force prone (setup)")
    _mark()
    return _send_eq_clear(("regress %s"):format(t))
  end

  return false
end

-- Optional autohook into your Occultist offense (Off.attack_eqonly)
function P.try_hook()
  if not P.cfg.autohook then return false end
  if not (Yso.off and Yso.off.oc and type(Yso.off.oc.attack_eqonly) == "function") then return false end
  if Yso.off.oc._pronecontroller_wrapped then return true end

  local Off = Yso.off.oc
  local _orig = Off.attack_eqonly

  Off.attack_eqonly = function(...)
    if P.cfg.enabled then
      local t = (Off.resolve_target and Off.resolve_target()) or (Yso.target or "")
      local aff = _aff()
      if t and t ~= "" and P.want_anorexia(aff) then
        if P.step(t, aff) then return true end
      end
    end
    return _orig(...)
  end

  Off._pronecontroller_wrapped = true
  _echo("autohook installed into Off.attack_eqonly()")
  return true
end

-- Attempt hook if enabled
P.try_hook()

--========================================================--
