-- Auto-exported from Mudlet package script: Softlock Gate
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso_Occultist_Offense_SoftlockGate.lua (DROP-IN)
-- Purpose:
--   Soft-lock FIRST, then allow the existing kelp-bury phase to run.
--
-- Gate:
--   Require: asthma == stuck AND softscore >= 2
--     softscore = (asthma + slickness + anorexia) / 100  (AK oscore)
--   i.e. asthma + (slickness or anorexia) at minimum.
--
-- Load order:
--   • AFTER Yso_Occultist_Offense.lua
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

local Off = Yso.off.oc
local Q   = Yso.queue

-- ----------------------------
-- Config (safe defaults)
-- ----------------------------
Off.cfg = Off.cfg or {}
Off.cfg.softlock_gate = Off.cfg.softlock_gate or {
  enabled = true,

  -- Slickness is usually more reliable for you; default to slickness-first.
  prefer = "slickness", -- "slickness" or "anorexia"

  -- Optional: if true, you will push for all 3 (asthma+sick+anorexia) before kelp bury.
  push_three = false,

  -- If true and asthma is already present, attempt slickness via Bubonis follow-up:
  -- in your affmap: bubonis followup(asthma) => slickness.
  slickness_via_bubonis_followup = true,

  -- If true, keep paralysis pressure during the soft-lock setup when possible.
  keep_paralysis = true,
}

Off._softlock_done = Off._softlock_done or {}

-- ----------------------------
-- Minimal helpers (self-contained)
-- ----------------------------
local function _trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end

local function _vit_eqbal()
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  local eq  = tostring(v.eq or v.equilibrium or "") == "1"
  local bal = tostring(v.bal or v.balance or "") == "1"
  return eq and bal
end

local function _upright()
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  local pos = tostring(v.position or v.pos or ""):lower()
  if pos == "" then return true end
  return not (pos:find("lying") or pos:find("prone") or pos:find("sitting") or pos:find("kneel") or pos:find("rest"))
end

local function _queue_addclear(qtype, piped)
  if not piped or piped == "" then return false end
  if Q and type(Q.addclear) == "function" then
    Q.addclear(qtype, piped)
    return true
  end
  return false
end

local function _queue_eqbal_clear(...)
  local cmds = {}
  for i = 1, select("#", ...) do
    local c = select(i, ...)
    c = _trim(c)
    if c ~= "" then cmds[#cmds+1] = c end
  end
  if #cmds == 0 then return false end

  if Off.cfg and Off.cfg.prepend_stand and not _upright() then
    table.insert(cmds, 1, "stand")
  end

  local qtype = Off.qtype_eqbal or "eq"
  return _queue_addclear(qtype, table.concat(cmds, (Yso and Yso.sep) or "&&"))
end

local function _score(aff, afftbl)
  if Off.score then return Off.score(aff, afftbl) end
  local s = (afftbl and afftbl[aff]) or (affstrack and affstrack.score and affstrack.score[aff]) or 0
  return tonumber(s) or 0
end

local function _stuck(aff, afftbl)
  local stuck = Off.cfg.stuck_score or 100
  return _score(aff, afftbl) >= stuck
end

local function _softscore(afftbl)
  -- Prefer AK global softscore if it exists (computed in ak.scoreup/oscore),
  -- otherwise compute from aff presence (same formula).
  if type(_G.softscore) == "number" then return _G.softscore end
  local stuck = Off.cfg.stuck_score or 100
  local n = 0
  if _score("asthma", afftbl)   >= stuck then n = n + 1 end
  if _score("slickness", afftbl)>= stuck then n = n + 1 end
  if _score("anorexia", afftbl) >= stuck then n = n + 1 end
  return n
end

local function _softlock_ready(t, afftbl)
  if not _stuck("asthma", afftbl) then return false end
  local ss = _softscore(afftbl)
  local need = (Off.cfg.softlock_gate and Off.cfg.softlock_gate.push_three) and 3 or 2
  return ss >= need
end

-- ----------------------------
-- Soft-lock setup routine
-- ----------------------------
function Off.try_softlock_setup(t, afftbl)
  local cfg = Off.cfg.softlock_gate or {}
  if cfg.enabled == false then return false end
  if not _vit_eqbal() then return false end
  t = _trim(t)
  if t == "" then return false end

  local stuck = Off.cfg.stuck_score or 100

  local asthma   = _score("asthma", afftbl)
  local slick    = _score("slickness", afftbl)
  local anorexia = _score("anorexia", afftbl)

  -- Reset / track per-target completion
  if asthma < stuck then Off._softlock_done[t] = false end
  if Off._softlock_done[t] == true and not _softlock_ready(t, afftbl) then
    Off._softlock_done[t] = false
  end
  if _softlock_ready(t, afftbl) then
    Off._softlock_done[t] = true
    return false
  end

  -- Choose your “apply” method:
  local ent_asthma = (((Off.cfg.kelp_bury or {}).entities or {}).asthma) or "bubonis"

  -- Build commands: keep it simple and deterministic.
  -- One instill per cycle: if we need anorexia specifically, instill anorexia; otherwise keep paralysis pressure.
  local instill_cmd = nil
  if cfg.keep_paralysis then instill_cmd = ("instill %s with paralysis"):format(t) end

  -- 1) Ensure asthma first (required for your gate AND for Bubonis slickness follow-up).
  if asthma < stuck then
    return _queue_eqbal_clear(
      instill_cmd or ("instill %s with paralysis"):format(t),
      ("command %s at %s"):format(ent_asthma, t)
    )
  end

  -- 2) Prefer slickness (your stated reliability preference)
  if slick < stuck and (cfg.prefer == "slickness") then
    if cfg.slickness_via_bubonis_followup then
      return _queue_eqbal_clear(
        instill_cmd or ("instill %s with paralysis"):format(t),
        ("command %s at %s"):format(ent_asthma, t) -- asthma already present => bubonis follow-up slickness (per your affmap)
      )
    end
    return _queue_eqbal_clear(
      instill_cmd or ("instill %s with paralysis"):format(t),
      ("instill %s with slickness"):format(t)
    )
  end

  -- 3) If slickness is handled (or prefer anorexia), fill anorexia if needed.
  local need_three = cfg.push_three == true
  local need_second = (not need_three) and (_softscore(afftbl) < 2) -- asthma already present => missing either slickness or anorexia
  if (anorexia < stuck) and (need_three or need_second or cfg.prefer == "anorexia") then
    -- Instill anorexia takes priority over paralysis for this cycle (single-instll reality).
    return _queue_eqbal_clear(
      ("instill %s with anorexia"):format(t)
    )
  end

  -- 4) If we get here, we’re missing slickness but prefer anorexia (or slickness method is disabled).
  if slick < stuck then
    if cfg.slickness_via_bubonis_followup then
      return _queue_eqbal_clear(
        instill_cmd or ("instill %s with paralysis"):format(t),
        ("command %s at %s"):format(ent_asthma, t)
      )
    end
    return _queue_eqbal_clear(
      instill_cmd or ("instill %s with paralysis"):format(t),
      ("instill %s with slickness"):format(t)
    )
  end

  -- Fallback: keep paralysis pressure rather than doing nothing.
  if instill_cmd then
    return _queue_eqbal_clear(instill_cmd)
  end
  return false
end

-- ----------------------------
-- Wrap kelp-bury: soft-lock runs first, then original kelp-bury.
-- ----------------------------
if not Off._softlock_gate_wrapped and type(Off.try_kelp_bury) == "function" then
  Off._softlock_gate_wrapped = true
  Off._try_kelp_bury_orig = Off._try_kelp_bury_orig or Off.try_kelp_bury

  Off.try_kelp_bury = function(t, afftbl)
    local cfg = Off.cfg.softlock_gate or {}
    if cfg.enabled ~= false then
      if not _softlock_ready(t, afftbl) then
        -- Run soft-lock setup instead of entering kelp-bury.
        return Off.try_softlock_setup(t, afftbl) == true
      end
    end
    return Off._try_kelp_bury_orig(t, afftbl)
  end
end

--========================================================--
