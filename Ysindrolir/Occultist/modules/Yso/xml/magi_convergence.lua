-- Auto-exported from Mudlet package script: Magi Convergence (Yso)
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Magi — Convergence (Elementalism)
--
-- Spell:
--   CAST CONVERGENCE AT <target>
--   • Requires: target has reached 4th stage of dissonance
--   • Requires: at least MODERATE resonance in ALL planes
--   • Uses: EQUILIBRIUM
--
-- This module:
--   • Provides gating helpers and a command builder.
--   • Does NOT automatically fire; routes/orchestrator can call
--     Yso.magi.try_convergence(<target>).
--
-- Dissonance stage tracking:
--   • We do NOT assume AK has an authoritative stage signal.
--   • You (or AK triggers) should set it via:
--       Yso.magi.set_dissonance_stage(<target>, <0..4>)
--========================================================--

Yso = Yso or {}
Yso.magi = Yso.magi or {}

local M = Yso.magi

-- Ensure resonance tracker is loaded.
pcall(function() require("Yso.xml.magi_resonance") end)

M.cfg = M.cfg or {}
M.cfg.convergence = M.cfg.convergence or {
  enabled = true,
  -- Convergence requires "moderate" resonance to all planes at minimum.
  min_res_rank = 2,
  -- Convergence requires target to be at (or beyond) stage 4.
  min_dissonance_stage = 4,
  -- Safety cooldown per target (seconds). Prevents pointless re-casts.
  min_interval = 12,
}

M._cd = M._cd or {}
M._cd.convergence = M._cd.convergence or {}
M._tgt = M._tgt or {}
M._tgt.dissonance_stage = M._tgt.dissonance_stage or {}

local function _now()
  if type(getEpoch) == "function" then return getEpoch() end
  return os.time()
end

local function _echo(msg)
  if M.cfg and M.cfg.debug then
    cecho(string.format("<gray>[Yso:Magi] %s\n", tostring(msg)))
  end
end

local function _eq_ready()
  -- Prefer Yso accessor if present
  if Yso.me and type(Yso.me.eq_ready) == "function" then
    local ok, res = pcall(Yso.me.eq_ready)
    if ok and type(res) == "boolean" then return res end
  end

  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  local eq = v.equilibrium
  if eq == nil then eq = v.eq end
  if eq == true then return true end
  return tostring(eq or "") == "1"
end

-- -----------------------------
-- Dissonance stage API
-- -----------------------------

function M.set_dissonance_stage(target, stage)
  target = tostring(target or "")
  if target == "" then return end
  stage = tonumber(stage) or 0
  if stage < 0 then stage = 0 end
  if stage > 4 then stage = 4 end
  M._tgt.dissonance_stage[target] = stage
  _echo(string.format("disson[%s]=%d", target, stage))
end

function M.get_dissonance_stage(target)
  target = tostring(target or "")
  if target == "" then return 0 end

  -- 1) Explicitly set by a trigger or another module.
  local explicit = tonumber(M._tgt.dissonance_stage[target])
  if explicit then return explicit end

  -- 2) Attempt to infer from AK affstrack.score if available.
  --    Common pattern: 4 stages -> 25/50/75/100 score.
  if affstrack and type(affstrack) == "table" and type(affstrack.score) == "table" then
    -- Direct stage keys (most reliable if present)
    local keymap = {
      { 4, "dissonance4" }, { 4, "dissonance_4" },
      { 3, "dissonance3" }, { 3, "dissonance_3" },
      { 2, "dissonance2" }, { 2, "dissonance_2" },
      { 1, "dissonance1" }, { 1, "dissonance_1" },
    }
    for _, row in ipairs(keymap) do
      local stage, key = row[1], row[2]
      local sc = affstrack.score[key]
      if type(sc) == "number" and sc >= 100 then return stage end
    end

    -- Base dissonance score -> stage inference.
    local sc = affstrack.score.dissonance
    if type(sc) == "number" then
      local stage = math.floor((sc + 24.999) / 25) -- 0..4 (approx)
      if stage < 0 then stage = 0 end
      if stage > 4 then stage = 4 end
      return stage
    end
  end

  return 0
end

-- -----------------------------
-- Gating + command builder
-- -----------------------------

function M.can_convergence(target)
  if not (M.cfg and M.cfg.convergence and M.cfg.convergence.enabled) then
    return false, "disabled"
  end
  target = tostring(target or "")
  if target == "" then return false, "no_target" end

  -- EQ gate
  if not _eq_ready() then return false, "no_eq" end

  -- Resonance gate
  local min_res = tonumber(M.cfg.convergence.min_res_rank) or 2
  if not (M.resonance_all_at_least and M.resonance_all_at_least(min_res)) then
    -- Refresh our resonance snapshot (balanceless) so the next pulse has fresh data.
    if M.request_resonance then pcall(M.request_resonance, false) end
    return false, "resonance_low"
  end

  -- Dissonance stage gate
  local min_stage = tonumber(M.cfg.convergence.min_dissonance_stage) or 4
  local stage = M.get_dissonance_stage(target)
  if stage < min_stage then
    return false, "dissonance_low"
  end

  -- Safety interval
  local t = _now()
  local last = tonumber(M._cd.convergence[target]) or 0
  local min_iv = tonumber(M.cfg.convergence.min_interval) or 12
  if (t - last) < min_iv then
    return false, "cooldown"
  end

  return true
end

-- Returns the command string or nil.
function M.try_convergence(target)
  local ok, why = M.can_convergence(target)
  if not ok then return nil, why end

  target = tostring(target)
  M._cd.convergence[target] = _now()
  return ("cast convergence at %s"):format(target)
end

return M
