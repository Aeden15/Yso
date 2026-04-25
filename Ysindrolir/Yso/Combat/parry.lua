-- Auto-exported from Mudlet package script: Parry Module
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso Parry Module (class-agnostic)
--   Defensive limb parrying against limb-prep classes.
--   Parries the "final limb" closest to breaking for an
--   enemy's kill condition. Special BM restore handling
--   keeps one arm delayed so rift/salve access is preserved.
--
--   PARRY is free/instant - no balance cost.
--========================================================--

Yso = Yso or {}
Yso.parry = Yso.parry or {}
local P = Yso.parry

P.cfg = P.cfg or {
  enabled            = true,
  threshold          = 100,    -- min self limb score before we consider standard parrying
  debug              = false,
  route_debounce_s   = 0.45,   -- explicit debounce for free-lane routing
  restore_override_s = 12.0,   -- safety cap if state gets desynced
}

P._current = P._current or nil
P._last_sent_at = tonumber(P._last_sent_at or 0) or 0
P._last_sent_limb = tostring(P._last_sent_limb or "")
P._restore = P._restore or {
  active = false,
  started_at = 0,
  last_cured_leg = "",
}
P._trigs = P._trigs or {}

------------------------------------------------------------
-- Kill-condition table: which limbs each class needs
------------------------------------------------------------
P.KILL_CONDITIONS = P.KILL_CONDITIONS or {
  Blademaster = {
    primary   = { "leftleg", "rightleg" },
    secondary = { "leftarm", "rightarm" },
    riftlock  = true,
  },
  Monk = {
    primary = { "leftleg", "rightleg", "head" },
  },
  Apostle = {
    primary = { "leftleg", "rightleg" },
  },
}

------------------------------------------------------------
-- Limb name conversion for the PARRY command
------------------------------------------------------------
local _LIMB_CMD = {
  leftleg  = "left leg",
  rightleg = "right leg",
  leftarm  = "left arm",
  rightarm = "right arm",
  head     = "head",
  torso    = "torso",
}
local _CMD_LIMB = {}
for limb_key, cmd_limb in pairs(_LIMB_CMD) do
  _CMD_LIMB[tostring(cmd_limb):lower()] = limb_key
end

------------------------------------------------------------
-- Internal helpers
------------------------------------------------------------

local function _p_echo(msg)
  if P.cfg.debug and type(cecho) == "function" then
    cecho(string.format("<PaleGreen>[Parry] <reset>%s\n", tostring(msg)))
  end
end

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  if type(getEpoch) == "function" then
    local ok, v = pcall(getEpoch)
    v = ok and tonumber(v) or nil
    if v then
      if v > 1e12 then v = v / 1000 end
      return v
    end
  end
  return os.time()
end

local function _self_score(limb)
  if not affstrack or type(affstrack.score) ~= "table" then return 0 end
  return tonumber(affstrack.score[limb]) or 0
end

local function _self_has_aff(aff)
  -- Diagnostic note (#22): parry remains Yso-self-truth first by design.
  -- No additional Legacy hysteresis layer is applied here unless real divergence is observed.
  aff = tostring(aff or ""):lower()
  if aff == "" then return false end

  if Yso and Yso.selfaff and type(Yso.selfaff.normalize) == "function" then
    aff = Yso.selfaff.normalize(aff)
  end

  if Yso and Yso.self and type(Yso.self.has_aff) == "function" then
    local ok, v = pcall(Yso.self.has_aff, aff)
    if ok and v == true then return true end
  end

  if Yso and type(Yso.affs) == "table" and Yso.affs[aff] then
    return true
  end

  local g = gmcp and gmcp.Char and gmcp.Char.Afflictions
  if type(g) == "table" then
    if g[aff] == true then return true end
    local lists = { g.List, g.list, g.Afflictions, g.afflictions }
    for i = 1, #lists do
      local lst = lists[i]
      if type(lst) == "table" then
        for j = 1, #lst do
          local item = lst[j]
          local name = type(item) == "table" and item.name or item
          if tostring(name or ""):lower() == aff then
            return true
          end
        end
      end
    end
  end

  return false
end

local function _self_standing()
  if Yso and Yso.self and type(Yso.self.is_standing) == "function" then
    local ok, v = pcall(Yso.self.is_standing)
    if ok then return v == true end
  end
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  local posture = tostring(v.position or v.posture or v.pose or v.state or ""):lower()
  if posture ~= "" then
    if posture:find("stand", 1, true) then return true end
    if posture:find("prone", 1, true)
      or posture:find("supine", 1, true)
      or posture:find("kneel", 1, true)
      or posture:find("sit", 1, true)
      or posture:find("sleep", 1, true)
    then
      return false
    end
  end
  return not (_self_has_aff("prone") or _self_has_aff("sleeping") or _self_has_aff("fallen"))
end

local function _enemy_class()
  local cur_target = rawget(_G, "target")
  if Legacy and Legacy.CT and Legacy.CT.Enemies and type(cur_target) == "string" and cur_target ~= "" then
    return Legacy.CT.Enemies[cur_target]
  end
  return nil
end

local function _current_cureset()
  local prof = Yso and Yso.curing and Yso.curing._active_profile or nil
  if type(prof) == "string" and prof ~= "" then return prof:lower() end
  local cur = rawget(_G, "CurrentCureset")
  if type(cur) == "string" and cur ~= "" then return cur:lower() end
  return ""
end

local function _find_highest_unbroken(limbs)
  local best_limb, best_score = nil, -1
  for _, limb in ipairs(limbs) do
    local s = _self_score(limb)
    if s < 300 and s > best_score then
      best_limb  = limb
      best_score = s
    end
  end
  return best_limb, best_score
end

local function _bm_restore_context()
  if _current_cureset() == "blademaster" then return true end
  return _enemy_class() == "Blademaster"
end

local function _arm_candidate_for_restore()
  local la = _self_score("leftarm")
  local ra = _self_score("rightarm")
  local left_ok = la < 300
  local right_ok = ra < 300
  if not left_ok and not right_ok then return nil end
  if left_ok and not right_ok then return "leftarm", la end
  if right_ok and not left_ok then return "rightarm", ra end
  if la == ra then
    return ((math.random(2) == 1) and "leftarm" or "rightarm"), la
  end
  if la < ra then return "leftarm", la end
  return "rightarm", ra
end

local function _restore_finished()
  -- Prefer tracker truth, but keep a score-key fallback for harnesses / partial
  -- integrations that only provide damaged-leg score entries.
  local left_damaged  = _self_has_aff("damagedleftleg") or (_self_score("damagedleftleg") > 0)
  local right_damaged = _self_has_aff("damagedrightleg") or (_self_score("damagedrightleg") > 0)
  return (not left_damaged) and (not right_damaged) and _self_standing()
end

function P.note_leg_restored(aff)
  aff = tostring(aff or ""):lower()
  if aff ~= "damagedleftleg" and aff ~= "damagedrightleg" then return false end
  if not _bm_restore_context() then return false end
  P._restore = P._restore or {}
  P._restore.active = true
  P._restore.started_at = _now()
  P._restore.last_cured_leg = aff
  _p_echo("BM restore override armed via " .. aff)
  return true
end

function P.clear_restore(reason)
  if P._restore then
    P._restore.active = false
    P._restore.started_at = 0
    P._restore.last_cured_leg = ""
  end
  if reason then _p_echo("restore override cleared: " .. tostring(reason)) end
end

local function _restore_override_candidate()
  local R = P._restore or {}
  if R.active ~= true then return nil end
  if not _bm_restore_context() then
    P.clear_restore("context")
    return nil
  end
  if _restore_finished() then
    P.clear_restore("legs_clean_and_standing")
    return nil
  end
  local cap = tonumber(P.cfg.restore_override_s or 12.0) or 12.0
  if cap > 0 and (_now() - tonumber(R.started_at or 0)) > cap then
    P.clear_restore("safety_timeout")
    return nil
  end
  local limb, score = _arm_candidate_for_restore()
  if not limb then return nil end
  return limb, tonumber(score) or 0, "bm_restore_override"
end

------------------------------------------------------------
-- Core evaluation
------------------------------------------------------------

function P.evaluate()
  if not P.cfg.enabled then return nil end
  if not (Yso.toggles and Yso.toggles.parry) then return nil end

  local override_limb, override_score, override_reason = _restore_override_candidate()
  if override_limb then
    return override_limb, override_score, override_reason
  end

  local class = _enemy_class()
  if not class then return nil end

  local kc = P.KILL_CONDITIONS[class]
  if not kc then return nil end

  local candidate, candidate_score = nil, -1

  -- BM riftlock special case: if both arms being prepped,
  -- always parry the arm with higher damage to delay rift denial.
  if kc.riftlock then
    local la = _self_score("leftarm")
    local ra = _self_score("rightarm")
    if la >= P.cfg.threshold and ra >= P.cfg.threshold then
      if la >= ra and la < 300 then
        candidate, candidate_score = "leftarm", la
      elseif ra < 300 then
        candidate, candidate_score = "rightarm", ra
      end
    end
  end

  -- Check primary kill-condition limbs first, but still let the highest-score
  -- qualifying limb win overall.
  if not candidate then
    local limb, score = _find_highest_unbroken(kc.primary or {})
    if limb and score >= P.cfg.threshold and score > candidate_score then
      candidate, candidate_score = limb, score
    end
  end

  -- Secondary kill-condition limbs (if any)
  if kc.secondary then
    local limb, score = _find_highest_unbroken(kc.secondary)
    if limb and score >= P.cfg.threshold and score > candidate_score then
      candidate, candidate_score = limb, score
    end
  end

  return candidate, candidate_score, "standard"
end

function P.command_for_limb(limb)
  limb = tostring(limb or "")
  if limb == "" then return nil end
  return "parry " .. (_LIMB_CMD[limb] or limb)
end

function P.next_command(opts)
  opts = opts or {}
  local limb, score, reason = P.evaluate()
  if not limb then
    if P._current then
      _p_echo("no parry needed - clearing")
      P._current = nil
    end
    return nil, nil, score, reason
  end
  if limb == P._current then return nil, limb, score, reason end
  local now = _now()
  local debounce = tonumber(P.cfg.route_debounce_s or 0.45) or 0.45
  if debounce > 0 and P._last_sent_limb == limb and (now - tonumber(P._last_sent_at or 0)) < debounce then
    return nil, limb, score, reason
  end
  return P.command_for_limb(limb), limb, score, reason
end

function P.note_sent(limb_or_cmd)
  local input = tostring(limb_or_cmd or ""):lower()
  input = input:gsub("^parry%s+", ""):gsub("^%s+", ""):gsub("%s+$", "")
  local limb = _CMD_LIMB[input] or input:gsub("%s+", "")
  if _LIMB_CMD[limb] then
    P._current = limb
    P._last_sent_limb = limb
    P._last_sent_at = _now()
    return true
  end
  return false
end

------------------------------------------------------------
-- Send the PARRY command if needed (non-route fallback)
------------------------------------------------------------

function P.update()
  local cmd, limb, score, reason = P.next_command({ source = "prompt" })
  if not cmd then return end
  if type(send) == "function" then
    send(cmd, false)
    P.note_sent(limb)
  end
  _p_echo(string.format("%s (score: %d, class: %s, reason: %s)",
    (_LIMB_CMD[limb] or limb), score or 0, tostring(_enemy_class() or "?"), tostring(reason or "-")))
end

------------------------------------------------------------
-- Prompt-driven re-evaluation
------------------------------------------------------------

P._eh = P._eh or {}
local function _kill_ae(id)
  if id and type(killAnonymousEventHandler) == "function" then
    pcall(killAnonymousEventHandler, id)
  end
end

if type(registerAnonymousEventHandler) == "function" then
  _kill_ae(P._eh.vitals)
  P._eh.vitals = registerAnonymousEventHandler("gmcp.Char.Vitals", function()
    pcall(P.update)
  end)
end

------------------------------------------------------------
-- Runtime hooks
------------------------------------------------------------

if type(tempRegexTrigger) == "function" then
  if P._trigs.leg_restored then killTrigger(P._trigs.leg_restored) end
  P._trigs.leg_restored = tempRegexTrigger(
    [[^You have cured the (damagedleftleg|damagedrightleg) affliction\.$]],
    function()
      pcall(P.note_leg_restored, matches[2])
    end
  )
end

------------------------------------------------------------
-- Reset on mode change to bash
------------------------------------------------------------

if type(registerAnonymousEventHandler) == "function" then
  _kill_ae(P._eh.mode_changed)
  P._eh.mode_changed = registerAnonymousEventHandler("yso.mode.changed", function(_, old, new, reason)
    if new == "bash" then
      P._current = nil
      P.clear_restore("mode->bash")
      _p_echo("mode->bash: parry cleared")
    end
  end)
end

_p_echo("Yso parry module loaded")
--========================================================--
