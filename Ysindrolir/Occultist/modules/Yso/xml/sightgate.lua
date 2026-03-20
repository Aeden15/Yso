-- Auto-exported from Mudlet package script: SightGate
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso_Occultist_Phase_SightGate.lua (DROP-IN)
-- Purpose:
--   • Add Off.phase() (softlock -> kelp build -> post-bury/unravel)
--   • Add explicit "need sight" gate:
--       ATTEND <t> && <phase filler entity command>
--     ONLY when you request sight (Unnamable Vision / Heretic Witness).
--   • Prevent Off.ensure_chimera_ready() from auto-attending for blind/deaf.
--   • Phase-gate Yso.oc.prone (if present): only run during SOFTLOCK_SETUP.
--
-- Separator: ";;" (Achaea server-side queue batch)
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}
Yso.occ = Yso.occ or {}
Yso.oc  = Yso.oc  or {}

local Off = Yso.off.oc
local Q   = Yso.queue

Off.sg = Off.sg or {}
local SG = Off.sg

SG.cfg = SG.cfg or {
  enabled = true,
  debug = false,

  stuck_score = 100,

  -- “softscore >= 2 AND asthma = 100” gate (your requirement)
  softscore_affs = { "asthma", "slickness", "anorexia" },
  softscore_needed = 2,

  -- Sight request TTL (seconds). Keep short: it’s a “do it now” intent flag.
  sight_ttl = 2.0,

  -- If Off.cfg.prepend_stand exists, respect it. Otherwise: do not force stand.
  respect_prepend_stand = true,
}

local function _echo(s)
  if SG.cfg.debug then cecho("<gray>[Yso:Occ:SG] " .. s .. "\n") end
end

local function _now()
  if type(getEpoch) == "function" then return getEpoch() end
  return os.time()
end

local function _have_eq()
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  local eq = v.equilibrium
  if eq == true then return true end
  return tostring(eq or "") == "1"
end

local function _upright()
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  local pos = tostring(v.position or v.pos or ""):lower()
  if pos:find("stand") then return true end
  if pos:find("sit") then return false end
  if pos:find("kneel") then return false end
  if pos:find("prone") then return false end
  -- If unknown, assume upright (avoid forcing stand spam).
  return true
end

local function _prepend_stand_if_needed(cmds)
  if not (SG.cfg.respect_prepend_stand and Off.cfg and Off.cfg.prepend_stand) then return cmds end
  if _upright() then return cmds end
  if type(cmds) ~= "table" or #cmds == 0 then return cmds end
  local first = tostring(cmds[1] or ""):lower():gsub("^%s+","")
  if first:match("^stand%s*$") or first:match("^stand&&") then return cmds end
  table.insert(cmds, 1, "stand")
  return cmds
end

local function _queue_eq_addclear(cmds)
  if type(cmds) ~= "table" then return false end
  local out = {}
  for i = 1, #cmds do
    local c = tostring(cmds[i] or ""):gsub("^%s+",""):gsub("%s+$","")
    if c ~= "" then out[#out+1] = c end
  end
  if #out == 0 then return false end

  out = _prepend_stand_if_needed(out)

  local qtype = (Off.qtype_eq or "eq")
  local piped = table.concat(out, (Yso and Yso.sep) or ";;")

  if Q and type(Q.addclear) == "function" then
    Q.addclear(qtype, piped)
  else
    return false
  end
  return true
end

--========================
-- Phase detection
--========================
function Off.softscore(aff)
  aff = aff or ((affstrack and affstrack.score) or {})
  local stuck = (SG.cfg.stuck_score or (Off.cfg and Off.cfg.stuck_score) or 100)
  local n = 0
  local list = SG.cfg.softscore_affs or {}
  for i = 1, #list do
    if Off.score and Off.score(list[i], aff) >= stuck then
      n = n + 1
    end
  end
  return n
end

function Off.phase(t, aff)
  t = t or (Off.resolve_target and Off.resolve_target()) or (Off.target) or ""
  aff = aff or ((affstrack and affstrack.score) or {})

  local stuck = (SG.cfg.stuck_score or (Off.cfg and Off.cfg.stuck_score) or 100)

  local asthma_stuck = (Off.score and Off.score("asthma", aff) or 0) >= stuck
  local soft = Off.softscore(aff)
  local soft_ok = asthma_stuck and (soft >= (SG.cfg.softscore_needed or 2))

  if not soft_ok then
    return "SOFTLOCK_SETUP"
  end

  -- If you are using the kelp bury builder, treat “not done yet” as KELP_BUILD
  if Off.cfg and Off.cfg.kelp_bury and Off.cfg.kelp_bury.enabled then
    if Off._bury_done and t ~= "" and not Off._bury_done[t] then
      return "KELP_BUILD"
    end
  end

  -- Post-bury: WM/enlighten/unravel track
  return "UNRAVEL"
end

--========================
-- Explicit “need sight” intent flag
--========================
Off._need_sight = Off._need_sight or {}

function Off.request_sight(t, reason, ttl)
  t = t or (Off.resolve_target and Off.resolve_target()) or (Off.target) or ""
  if t == "" then return false end
  ttl = tonumber(ttl) or SG.cfg.sight_ttl or 2.0
  Off._need_sight[t] = { until_ts = _now() + ttl, reason = tostring(reason or "") }
  _echo(("request_sight(%s) ttl=%.2f reason=%s"):format(t, ttl, tostring(reason or "")))
  return true
end

function Off.need_sight(t)
  t = t or (Off.resolve_target and Off.resolve_target()) or (Off.target) or ""
  if t == "" then return false end
  local row = Off._need_sight[t]
  if not row then return false end
  if (_now() <= (row.until_ts or 0)) then return true end
  Off._need_sight[t] = nil
  return false
end

function Off.clear_sight(t)
  t = t or (Off.resolve_target and Off.resolve_target()) or (Off.target) or ""
  if t == "" then return false end
  Off._need_sight[t] = nil
  return true
end

--========================
-- Phase filler selection (entity-balance commands)
--========================
function Off.sg_pick_missing_aff(phase, t, aff)
  aff = aff or ((affstrack and affstrack.score) or {})
  local stuck = (SG.cfg.stuck_score or (Off.cfg and Off.cfg.stuck_score) or 100)

  local function missing(a)
    return (Off.score and Off.score(a, aff) or 0) < stuck
  end

  if phase == "SOFTLOCK_SETUP" then
    if missing("asthma") then return "asthma" end
    if missing("slickness") then return "slickness" end
    -- anorexia is handled by your prone/anorexia controller; do not force here.
    return nil
  end

  if phase == "KELP_BUILD" then
    if missing("asthma") then return "asthma" end
    if missing("clumsiness") then return "clumsiness" end
    if missing("healthleech") then return "healthleech" end
    if missing("sensitivity") then return "sensitivity" end
    return nil
  end

  -- UNRAVEL phase:
  -- Keep it conservative: only top-up missing kelp/core layers; otherwise no filler.
  if missing("asthma") then return "asthma" end
  if missing("healthleech") then return "healthleech" end
  if missing("clumsiness") then return "clumsiness" end
  if missing("sensitivity") then return "sensitivity" end
  return nil
end

function Off.sg_entity_cmd_for_aff(aff, t)
  if not aff or aff == "" or not t or t == "" then return nil end
  local cfg = (Off.cfg and Off.cfg.kelp_bury) or {}
  local ents = cfg.entities or {}

  local ent
  if aff == "asthma" then ent = ents.asthma or "bubonis"
  elseif aff == "slickness" then ent = ents.asthma or "bubonis"      -- assumes your bubonis route/followups
  elseif aff == "clumsiness" then ent = ents.clumsiness or "storm"
  elseif aff == "healthleech" then ent = ents.healthleech or "worm"
  elseif aff == "paralysis" then ent = cfg.paralysis_followup or "slime"
  else
    return nil
  end

  return ("command %s at %s"):format(ent, t)
end

--========================
-- Sight-gated ATTEND runner
--========================
function Off.queue_attend_if_needed(t, aff, reason)
  if not (SG.cfg.enabled and SG.cfg.enabled ~= false) then return false end

  t = t or (Off.resolve_target and Off.resolve_target()) or (Off.target) or ""
  if t == "" then return false end

  -- Only if you explicitly requested sight
  if not Off.need_sight(t) then return false end

  if not _have_eq() then return false end

  aff = aff or ((affstrack and affstrack.score) or {})
  local stuck = (SG.cfg.stuck_score or (Off.cfg and Off.cfg.stuck_score) or 100)

  -- Only attend if the target is actually blind (your “last resort” requirement)
  if (Off.score and Off.score("blind", aff) or 0) < stuck then
    return false
  end

  local phase = Off.phase(t, aff)
  local want  = Off.sg_pick_missing_aff(phase, t, aff)
  local fill  = Off.sg_entity_cmd_for_aff(want, t)

  local cmds = { ("attend %s"):format(t) }
  if fill and fill ~= "" then cmds[#cmds+1] = fill end

  _echo(("ATTEND gate: t=%s phase=%s filler_aff=%s"):format(t, phase, tostring(want)))
  return _queue_eq_addclear(cmds)
end

--========================
-- Wrap ensure_chimera_ready: stop auto-attend for blind/deaf
-- Keep READAURA behavior intact.
--========================
if Off.ensure_chimera_ready and not Off._sg_wrapped_ensure_chimera_ready then
  local _orig = Off.ensure_chimera_ready

  Off.ensure_chimera_ready = function(t, aff)
    -- Preserve original gating (WM>=stuck, not enlightened, have_eq, etc.)
    -- by calling the original in "readaura-only" mode:
    -- If aura missing, original will queue READAURA and return true.
    -- If aura indicates blind/deaf, original would ATTEND; we block that here.

    t = t or (Off.resolve_target and Off.resolve_target()) or (Off.target) or ""
    if t == "" then return false end
    aff = aff or ((affstrack and affstrack.score) or {})

    -- If we explicitly need sight right now, run the ATTEND gate (blind-only).
    if Off.queue_attend_if_needed(t, aff, "ensure_chimera_ready") then
      return true
    end

    -- Otherwise: allow READAURA behavior, but DO NOT ATTEND automatically.
    -- We replicate the original decision boundary:
    local need = (Yso.occ.aura_need_attend and Yso.occ.aura_need_attend(t)) or nil
    if need == nil then
      -- no aura data -> let original do its normal READAURA queue if applicable
      return _orig(t, aff)
    end

    -- aura says blind/deaf present -> previously would ATTEND; now: do nothing
    return false
  end

  Off._sg_wrapped_ensure_chimera_ready = true
  _echo("Wrapped Off.ensure_chimera_ready(): READAURA kept; auto-ATTEND disabled.")
end

--========================
-- Phase-gate your prone controller (if present)
--========================
do
  local P = (Yso.oc and Yso.oc.prone)
  if type(P) == "table" and type(P.want_anorexia) == "function" and not P._sg_phase_wrapped then
    local _orig_want = P.want_anorexia
    P.want_anorexia = function(aff)
      local t = (Off.resolve_target and Off.resolve_target()) or (Off.target) or ""
      if t ~= "" and Off.phase(t, aff) ~= "SOFTLOCK_SETUP" then
        return false
      end
      return _orig_want(aff)
    end
    P._sg_phase_wrapped = true
    _echo("Phase-gated Yso.oc.prone.want_anorexia() to SOFTLOCK_SETUP.")
  end
end

--========================================================--
-- Usage (intent flag):
--   Before UNNAMABLE VISION or HERETIC WITNESS, call:
--       Yso.off.oc.request_sight(nil, "unnamable_vision")
--   Then, on your next EQ cycle, the offense will only ATTEND if target is blind,
--   and will append a phase-based entity filler.
--========================================================--
