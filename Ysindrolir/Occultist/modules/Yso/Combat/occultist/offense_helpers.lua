--========================================================--
-- yso_occultist_offense.lua
-- Occultist single-target offense helper shim for Yso.
-- Automated emission authority now lives on alias-owned route modules.
--
-- Design goals:
--   * Plug into existing Yso queue / pulse architecture.
--   * Respect sightgate drop-ins.
--   * Stay conservative and readable so you can extend it.
--========================================================--

Yso       = Yso       or {}
Yso.off   = Yso.off   or {}
Yso.off.oc = Yso.off.oc or {}

local Off = Yso.off.oc

------------------------------------------------------------
-- Entity affliction map (affliction -> responsible entity)
------------------------------------------------------------

Yso.ent_affs = {
    anorexia       = "firelord",    -- *needs manaleech
    addiction      = "humbug",
    haemophilia    = "bloodleech",
    healthleech    = "worm",
    clumsiness     = "storm",
    asthma         = "bubonis",
    slickness      = "bubonis",     -- *needs asthma
    weariness      = "hound",
    paralysis      = "slime",       -- *needs asthma
    agoraphobia    = "chimera",
    confusion      = "chimera",
    claustrophobia = "chimera",
    dementia       = "chimera",
    hallucinations = "chimera",
    unravel        = "minion",
    pyradius       = "firelord",
    glaaki         = "abomination",
}

Yso.instill_affs = function()
    return {
        "paralysis", "asthma", "slickness", "clumsiness",
        "healthleech", "sensitivity", "darkshade",
    }
end

Yso.ent_cmd_for_aff = function(aff, tgt, has_aff_fn)
    aff = tostring(aff or ""):lower()
    tgt = tostring(tgt or "")
    if aff == "" or tgt == "" then return nil, nil end
    local has = type(has_aff_fn) == "function" and has_aff_fn or function() return false end

    if aff == "asthma" then
        return ("command bubonis at %s"):format(tgt), "mana_bury"
    end
    if aff == "slickness" and has(tgt, "asthma") then
        return ("command bubonis at %s"):format(tgt), "mana_bury"
    end
    if aff == "paralysis" and has(tgt, "asthma") then
        return ("command slime at %s"):format(tgt), "mana_bury"
    end
    if aff == "clumsiness" then
        return ("command storm at %s"):format(tgt), "mana_bury"
    end
    if aff == "weariness" then
        return ("command hound at %s"):format(tgt), "mana_bury"
    end
    if aff == "healthleech" then
        return ("command worm at %s"):format(tgt), "mana_bury"
    end
    if aff == "haemophilia" then
        return ("command bloodleech at %s"):format(tgt), "mana_bury"
    end
    if aff == "addiction" then
        return ("command humbug at %s"):format(tgt), "mana_bury"
    end
    if aff == "chimera_roar" then
        return ("command chimera at %s"):format(tgt), "mental_build"
    end
    return nil, nil
end

------------------------------------------------------------
-- Config / state
------------------------------------------------------------

Off.cfg = Off.cfg or {}

-- Central AEON module hook (enabled by default).
-- If your routes explicitly request AEON, they can still do so; this merely
-- provides a default integration point for the core offense tick.
if Off.cfg.use_aeon_module == nil then Off.cfg.use_aeon_module = true end
Off.cfg.ai = Off.cfg.ai or "lock"
Off.cfg.tarot = Off.cfg.tarot or "aeon"

-- Affliction score at/above this is treated as "stuck".
Off.cfg.stuck_score = Off.cfg.stuck_score or 100

-- Simple duel-mode identifier (you can switch later if you add more routes).
Off.cfg.mode = Off.cfg.mode or "duel"   -- duel | custom

-- Default EQ queue flag for eq-only payloads.
Off.qtype_eq    = Off.qtype_eq    or "eq"
Off.qtype_eqbal = Off.qtype_eqbal or "eq"

-- Stand-prepend is respected by sightgate.
if Off.cfg.prepend_stand == nil then
  Off.cfg.prepend_stand = true
end

Off.state = Off.state or {
  enabled = false,
  mode    = Off.cfg.mode,
  ai      = Off.cfg.ai,      -- future expansion hook
  tarot   = Off.cfg.tarot,   -- future expansion hook
}

------------------------------------------------------------
-- Small helpers
------------------------------------------------------------

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$",""))
end

local function _lc(s) return _trim(s):lower() end

local function _vitals()
  return (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
end

local function _eq_ready()
  if Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then return v == true end
  end
  local v = _vitals()
  local eq = v.eq or v.equilibrium
  return eq == true or tostring(eq or "") == "1"
end

local function _ent_ready()
  if Yso.state and type(Yso.state.ent_ready) == "function" then
    local ok, v = pcall(Yso.state.ent_ready)
    if ok then return v == true end
  end
  return true
end

local function _current_target()
  if type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok and _trim(v) ~= "" then return _trim(v) end
  end
  local cur = rawget(_G, "target")
  if type(cur) == "string" and _trim(cur) ~= "" then return _trim(cur) end
  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    if type(ak.target) == "string" and _trim(ak.target) ~= "" then return _trim(ak.target) end
    if type(ak.tgt) == "string" and _trim(ak.tgt) ~= "" then return _trim(ak.tgt) end
  end
  return ""
end

local function _target_is_valid(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return false end
  if type(Yso.target_is_valid) == "function" then
    local ok, v = pcall(Yso.target_is_valid, tgt)
    if ok then return v == true end
  end
  return true
end

local function _aff_scores()
  if type(affstrack) == "table" and type(affstrack.score) == "table" then
    return affstrack.score
  end
  return {}
end

local function _aff_score(aff, scores)
  aff = _lc(aff)
  if aff == "" then return 0 end

  -- Prefer AK score export when available.
  if Yso.oc and Yso.oc.ak and type(Yso.oc.ak.get_aff_score) == "function" then
    local ok, v = pcall(Yso.oc.ak.get_aff_score, aff)
    if ok then
      local n = tonumber(v)
      if n then return n end
    end
  end

  local v = scores and scores[aff]
  if type(v) == "table" then
    if type(v.current) == "number" then
      v = v.current
    elseif type(v.score) == "number" then
      v = v.score
    else
      v = 0
    end
  end
  v = tonumber(v or 0) or 0
  return v
end

local function _aff_stuck(aff, scores)
  local stuck = Off.cfg.stuck_score or 100
  return _aff_score(aff, scores) >= stuck
end

local function _emit(payload, opts)
  opts = opts or {}
  opts.reason = opts.reason or "occ_offense"

  if Yso.emit and type(Yso.emit) == "function" then
    return Yso.emit(payload, opts) == true
  end

  local Q = Yso.queue
  if Q and type(Q.emit) == "function" then
    local ok = pcall(Q.emit, payload)
    return ok == true
  end
  return false
end

local function _maybe_shieldbreak(tgt)
  if not (Yso.off and Yso.off.util and type(Yso.off.util.maybe_shieldbreak) == "function") then
    return nil
  end
  local ok, cmd = pcall(Yso.off.util.maybe_shieldbreak, tgt)
  cmd = ok and _trim(cmd) or ""
  return (cmd ~= "") and cmd or nil
end

------------------------------------------------------------
-- Public toggles / getters
------------------------------------------------------------

local function _echo(msg)
  if type(cecho) == "function" then
    cecho(string.format("<orange>[Yso:Occ] %s\n", tostring(msg)))
  elseif type(echo) == "function" then
    echo(string.format("[Yso:Occ] %s\n", tostring(msg)))
  end
end

if type(Off.set_mode) ~= "function" then
  function Off.set_mode(mode)
    mode = _lc(mode)
    if mode == "" then return Off.state.mode end
    Off.state.mode = mode
    Off.cfg.mode = mode
    _echo("Offense mode set to "..mode)
    return mode
  end
end

if type(Off.get_mode) ~= "function" then
  function Off.get_mode()
    return Off.state.mode or Off.cfg.mode or "duel"
  end
end

if type(Off.set_ai) ~= "function" then
  function Off.set_ai(ai)
    ai = _lc(ai)
    if ai == "" then return Off.get_ai() end

    if ai == "on" or ai == "yes" or ai == "true" or ai == "1" then
      Off.on()
      return Off.get_ai()
    end
    if ai == "off" or ai == "no" or ai == "false" or ai == "0" then
      Off.off()
      return Off.get_ai()
    end

    Off.state.ai = ai
    Off.cfg.ai = ai
    _echo("AI profile set to "..ai)
    return ai
  end
end

if type(Off.get_ai) ~= "function" then
  function Off.get_ai()
    return Off.state.ai or Off.cfg.ai or "lock"
  end
end

if type(Off.set_tarot) ~= "function" then
  function Off.set_tarot(tarot)
    tarot = _lc(tarot)
    if tarot == "" then return Off.get_tarot() end
    Off.state.tarot = tarot
    Off.cfg.tarot = tarot
    _echo("Tarot focus set to "..tarot)
    return tarot
  end
end

if type(Off.get_tarot) ~= "function" then
  function Off.get_tarot()
    return Off.state.tarot or Off.cfg.tarot or "aeon"
  end
end

if type(Off.on) ~= "function" then
  function Off.on()
    Off.state.enabled = true
    Yso.off.oc.enabled = true
    _echo("Occultist offense ON.")
    if Yso.pulse and type(Yso.pulse.wake) == "function" then
      Yso.pulse.wake("oc:on")
    end
  end
end

if type(Off.off) ~= "function" then
  function Off.off()
    Off.state.enabled = false
    Yso.off.oc.enabled = false
    _echo("Occultist offense OFF.")
  end
end

if type(Off.toggle) ~= "function" then
  function Off.toggle(on)
    if on == nil then
      if Off.state.enabled then Off.off() else Off.on() end
    elseif on == true then
      Off.on()
    else
      Off.off()
    end
  end
end

------------------------------------------------------------
-- Target helpers
------------------------------------------------------------

function Off.set_target(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return false end

  if type(Yso.set_target) == "function" then
    local ok, res = pcall(Yso.set_target, tgt, "offense", { keep_class_queue = true, keep_rawsend = true })
    if ok and res ~= false then return true end
  end

  if type(expandAlias) == "function" then
    expandAlias("t " .. tgt)
    return true
  end

  return false
end

function Off.resolve_target()
  local t = _current_target()
  if t == "" then return "" end
  if not _target_is_valid(t) then return "" end
  return t
end

------------------------------------------------------------
-- Simple EQ-only attack helper
------------------------------------------------------------

function Off.attack_eqonly()
  local tgt = Off.resolve_target()
  if tgt == "" or not _eq_ready() then return false end
  local scores = _aff_scores()

  local cmd = _maybe_shieldbreak(tgt)
  if not cmd then
    if not _aff_stuck("healthleech", scores) then
      cmd = string.format("instill %s with healthleech", tgt)
    elseif not _aff_stuck("sensitivity", scores) then
      cmd = string.format("instill %s with sensitivity", tgt)
    elseif not _aff_stuck("paralysis", scores) then
      cmd = string.format("instill %s with paralysis", tgt)
    else
      cmd = string.format("warp %s", tgt)
    end
  end

  return _emit({ eq = cmd }, { reason = "oc_attack_eqonly" })
end

------------------------------------------------------------
-- Main offense tick (pulse-driven)
------------------------------------------------------------

local function _build_eq_cmd(tgt, scores, phase)
  -- Keep pressure using healthleech/sensitivity/paralysis.
  if not _aff_stuck("healthleech", scores) then
    return string.format("instill %s with healthleech", tgt)
  end
  if not _aff_stuck("sensitivity", scores) then
    return string.format("instill %s with sensitivity", tgt)
  end
  if not _aff_stuck("paralysis", scores) then
    return string.format("instill %s with paralysis", tgt)
  end

  -- If we can utter truename, prefer that over raw damage.
  if Yso.occ and Yso.occ.truebook and type(Yso.occ.truebook.can_utter) == "function" then
    local ok, can = pcall(Yso.occ.truebook.can_utter, tgt)
    if ok and can then
      return string.format("utter truename %s", tgt)
    end
  end

  -- Default fallback: WARP damage.
  return string.format("warp %s", tgt)
end

local function _build_entity_cmd(tgt, scores, phase)
  if not _ent_ready() then return nil end
  if not (Off.sg_pick_missing_aff and Off.sg_entity_cmd_for_aff) then
    return nil
  end

  local aff = Off.sg_pick_missing_aff(phase, tgt, scores)
  if not aff or aff == "" then return nil end
  local cmd = Off.sg_entity_cmd_for_aff(aff, tgt)
  cmd = _trim(cmd)
  if cmd == "" then return nil end
  return cmd
end

function Off.tick(reasons)
  -- Deprecated automated path: retained only for manual/helper compatibility.
  if not (reasons == "manual" or (type(reasons) == "table" and reasons._manual_helper == true)) then return false end

  if not (Off.state and Off.state.enabled == true) then return false end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return false end

  local tgt = Off.resolve_target()
  if tgt == "" then return false end

  -- Shieldbreak (Gremlin) is EQ-lane and must pre-empt all other offense (including entity pressure).
  if _eq_ready() then
    local sb = _maybe_shieldbreak(tgt)
    if sb and sb ~= "" then
      _emit({ eq = sb }, { reason = "shieldbreak", solo = true, wake_lane = "eq" })
      return
    end
  end

  local scores = _aff_scores()

  -- Optional sight-gate (only runs when you have an explicit need_sight flag).
  if type(Off.queue_attend_if_needed) == "function" then
    local ok, handled = pcall(Off.queue_attend_if_needed, tgt, scores, "tick")
    if ok and handled then return end
  end

  -- Phase detection from sightgate.lua, if present.
  local phase = "UNRAVEL"
  if type(Off.phase) == "function" then
    local ok, p = pcall(Off.phase, tgt, scores)
    if ok and type(p) == "string" and p ~= "" then
      phase = p
    end
  end

  -- Central AEON module (opportunistic): if it emitted a step, stop this tick.
  if Off.cfg.use_aeon_module == true and Yso.occ and Yso.occ.aeon and type(Yso.occ.aeon.tick) == "function" then
    -- Default behaviour: when tarot focus is AEON, keep AEON requested.
    if type(Off.get_tarot) == "function" and tostring(Off.get_tarot()):lower() == "aeon" then
      if type(Yso.occ.aeon.request) == "function" then
        pcall(Yso.occ.aeon.request, tgt, { finisher = false })
      end
    end

    local ok, did = pcall(Yso.occ.aeon.tick, tgt, reasons)
    if ok and did == true then
      return
    end
  end

  -- Build lane payload.
  local payload = {}

  if _eq_ready() then
    payload.eq = _build_eq_cmd(tgt, scores, phase)
  end

  local ent_cmd = _build_entity_cmd(tgt, scores, phase)
  if ent_cmd then
    payload.class = ent_cmd
  end

  if not payload.eq and not payload.class then
    return false
  end

  -- Freestyle/as_available: emit ONLY the lane that woke this tick when possible.
  local wakes = {}
  if type(reasons) == "table" then
    for _,r in ipairs(reasons) do
      r = tostring(r or "")
      if r == "lane:eq" then wakes.eq = true end
      if r == "lane:bal" then wakes.bal = true end
      if r == "lane:class" then wakes.class = true end
    end
  end

  local p2 = {}
  local lane = nil
  if wakes.class and payload.class then
    p2.class = payload.class; lane = "class"
  elseif wakes.eq and payload.eq then
    p2.eq = payload.eq; lane = "eq"
  else
    -- No explicit wake: prefer ENTITY pressure if available, otherwise EQ.
    if payload.class then p2.class = payload.class; lane = "class"
    elseif payload.eq then p2.eq = payload.eq; lane = "eq" end
  end

  if p2.eq or p2.class then
    _emit(p2, { reason = "occ_offense", wake_lane = lane })
  end
end

------------------------------------------------------------
-- Pulse registration
------------------------------------------------------------

local function _ensure_pulse()
  if Yso and Yso.pulse and Yso.pulse.state and Yso.pulse.state.reg and Yso.pulse.state.reg["occultist_offense"] then
    Yso.pulse.state.reg["occultist_offense"].enabled = false
  end
  return false
end

_ensure_pulse()

------------------------------------------------------------
-- Shared thin-loop helper surface (occ_aff + compatibility)
------------------------------------------------------------

Yso.occ = Yso.occ or {}
Yso.occ._phase = Yso.occ._phase or {}

local function _phase_now()
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

local function _occ_target_key(tgt)
  return _lc(tgt)
end

local function _occ_has_aff(tgt, aff)
  tgt = _trim(tgt)
  aff = _lc(aff)
  if tgt == "" or aff == "" then return false end

  if Yso.tgt and type(Yso.tgt.has_aff) == "function" then
    local ok, v = pcall(Yso.tgt.has_aff, tgt, aff)
    if ok then return v == true end
  end

  if Yso.state and type(Yso.state.tgt_has_aff) == "function" then
    local ok, v = pcall(Yso.state.tgt_has_aff, tgt, aff)
    if ok then return v == true end
  end

  return false
end

local function _occ_target_mana_pct(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return nil end

  if Yso.tgt and type(Yso.tgt.get_mana_pct) == "function" then
    local ok, v = pcall(Yso.tgt.get_mana_pct, tgt)
    v = ok and tonumber(v) or nil
    if v then return v end
  end

  if Yso.occ and type(Yso.occ.aura_get) == "function" then
    local ok, v = pcall(Yso.occ.aura_get, tgt, "mana_pct")
    v = ok and tonumber(v) or nil
    if v then return v end
  end

  if Yso.occ and type(Yso.occ.mana_pct) == "table" then
    return tonumber(Yso.occ.mana_pct[_occ_target_key(tgt)] or Yso.occ.mana_pct[tgt]) or nil
  end

  return nil
end

local function _occ_mental_score()
  if Yso.oc and Yso.oc.ak and Yso.oc.ak.scores and type(Yso.oc.ak.scores.mental) == "function" then
    local ok, v = pcall(Yso.oc.ak.scores.mental)
    if ok then
      local n = tonumber(v)
      if n then return n end
    end
  end
  if type(affstrack) == "table" and type(affstrack.mentalscore) == "number" then
    return tonumber(affstrack.mentalscore) or 0
  end
  return 0
end

local function _occ_target_enlightened(tgt)
  return _occ_has_aff(tgt, "enlightened")
end

local function _occ_firelord_aff_from_skillchart(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return nil end

  local dom = nil
  if Yso.occ and type(Yso.occ.getDom) == "function" then
    local ok, v = pcall(Yso.occ.getDom, "pyradius")
    if ok and type(v) == "table" then dom = v end
  end
  local converts = (dom and type(dom.converts) == "table") and dom.converts or {}

  local function choose(src, dest)
    src = _lc(src)
    dest = _lc(dest)
    if src == "" or dest == "" then return nil end
    if _occ_has_aff(tgt, src) and not _occ_has_aff(tgt, dest) then
      return dest
    end
    return nil
  end

  local wm_dest = _lc(converts.whisperingmadness or converts.whispering_madness or "recklessness")
  local ml_dest = _lc(converts.manaleech or "anorexia")
  local hl_dest = _lc(converts.healthleech or "psychic_damage")

  return choose("whisperingmadness", wm_dest)
      or choose("whispering_madness", wm_dest)
      or choose("manaleech", ml_dest)
      or choose("healthleech", hl_dest)
      or nil
end

function Yso.occ.set_phase(tgt, phase, reason)
  tgt = _trim(tgt)
  phase = _lc(phase)
  if tgt == "" or phase == "" then return false end
  Yso.occ._phase[_occ_target_key(tgt)] = {
    phase = phase,
    reason = tostring(reason or ""),
    since = _phase_now(),
  }
  return true
end

function Yso.occ.get_phase(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return "open" end
  local p = Yso.occ._phase[_occ_target_key(tgt)]
  if type(p) == "table" then
    local v = _lc(p.phase)
    if v ~= "" then return v end
  end
  return "open"
end

function Yso.occ.phase(tgt)
  return Yso.occ.get_phase(tgt)
end

function Yso.occ.cleanse_ready(tgt)
  local mana = _occ_target_mana_pct(tgt)
  local cap = 40
  if Yso.off and Yso.off.oc and Yso.off.oc.occ_aff and Yso.off.oc.occ_aff.cfg then
    cap = tonumber(Yso.off.oc.occ_aff.cfg.mana_burst_pct or cap) or cap
  end
  if mana ~= nil and mana <= cap then return true end

  if Yso.occ and type(Yso.occ.aura_need_attend) == "function" then
    local ok, v = pcall(Yso.occ.aura_need_attend, tgt)
    if ok and v == true then return true end
  end

  return false
end

function Yso.occ.ent_for_aff(tgt, aff)
  tgt = _trim(tgt)
  aff = _lc(aff)
  if tgt == "" or aff == "" then return nil end

  if type(Yso.ent_cmd_for_aff) == "function" then
    local ok, cmd = pcall(Yso.ent_cmd_for_aff, aff, tgt, function(_, a)
      return _occ_has_aff(tgt, a)
    end)
    if ok and _trim(cmd) ~= "" then
      return _trim(cmd)
    end
  end

  if aff == "chimera_roar" then
    return ("command chimera at %s"):format(tgt)
  end

  if aff == "anorexia" or aff == "recklessness" or aff == "psychic_damage" then
    return ("command firelord at %s %s"):format(tgt, aff)
  end

  return nil
end

function Yso.occ.burst(tgt, ctx)
  ctx = type(ctx) == "table" and ctx or {}
  local eq_cmd = _lc(ctx.eq_cmd or "")
  if eq_cmd:match("^attend%s+") then return true end
  if eq_cmd:match("^cleanseaura%s+") then return true end
  if eq_cmd:match("^utter%s+truename%s+") then return true end

  if Yso.occ.cleanse_ready(tgt) ~= true then return false end

  if Yso.occ and Yso.occ.truebook and type(Yso.occ.truebook.can_utter) == "function" then
    local ok, v = pcall(Yso.occ.truebook.can_utter, tgt)
    if ok and v == true then return true end
  end

  if Yso.occ and type(Yso.occ.aura_need_attend) == "function" then
    local ok, v = pcall(Yso.occ.aura_need_attend, tgt)
    if ok and v == true then return true end
  end

  return false
end

function Yso.occ.pressure(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return nil end

  if not _occ_has_aff(tgt, "healthleech") then
    return ("instill %s with healthleech"):format(tgt)
  end
  if not _occ_has_aff(tgt, "sensitivity") then
    return ("instill %s with sensitivity"):format(tgt)
  end
  if not _occ_has_aff(tgt, "paralysis") then
    return ("instill %s with paralysis"):format(tgt)
  end
  if not _occ_has_aff(tgt, "clumsiness") then
    return ("instill %s with clumsiness"):format(tgt)
  end
  if not (_occ_has_aff(tgt, "whisperingmadness") or _occ_has_aff(tgt, "whispering_madness")) then
    return ("whisperingmadness %s"):format(tgt)
  end
  return ("devolve %s"):format(tgt)
end

function Yso.occ.convert(tgt, ctx)
  tgt = _trim(tgt)
  if tgt == "" then return nil end
  ctx = type(ctx) == "table" and ctx or {}

  local phase = _lc(ctx.phase or Yso.occ.get_phase(tgt))
  if phase ~= "convert" and phase ~= "finish" then
    return nil
  end

  local has_wm = _occ_has_aff(tgt, "whisperingmadness") or _occ_has_aff(tgt, "whispering_madness")
  local enlightened = _occ_target_enlightened(tgt)
  local enlighten_target = tonumber(ctx.enlighten_target or 5) or 5
  local unravel_mentals = tonumber(ctx.unravel_mentals or 4) or 4
  local mental_score = _occ_mental_score()

  if not has_wm then
    return ("whisperingmadness %s"):format(tgt)
  end

  if not enlightened then
    if mental_score >= enlighten_target then
      return ("enlighten %s"):format(tgt)
    end
    if Yso.occ and type(Yso.occ.readaura_is_ready) == "function" then
      local ok, ready = pcall(Yso.occ.readaura_is_ready)
      if ok and ready == true then
        return ("readaura %s"):format(tgt)
      end
    end
    return ("whisperingmadness %s"):format(tgt)
  end

  if mental_score >= unravel_mentals then
    return ("unravel %s"):format(tgt)
  end

  if Yso.occ and type(Yso.occ.readaura_is_ready) == "function" then
    local ok, ready = pcall(Yso.occ.readaura_is_ready)
    if ok and ready == true then
      return ("readaura %s"):format(tgt)
    end
  end

  return ("unravel %s"):format(tgt)
end

function Yso.occ.firelord(tgt, ctx)
  tgt = _trim(tgt)
  if tgt == "" then return nil end
  ctx = type(ctx) == "table" and ctx or {}
  local phase = _lc(ctx.phase or Yso.occ.get_phase(tgt))

  if phase ~= "convert" and phase ~= "finish" then
    return nil
  end

  local aff = _occ_firelord_aff_from_skillchart(tgt)
  if _trim(aff) == "" then return nil end

  local ER = Yso.off and Yso.off.oc and Yso.off.oc.entity_registry or nil
  if ER and type(ER.rank) == "function" then
    local ranked = nil
    local ok, r = pcall(ER.rank, {
      target = tgt,
      category = "convert_support",
      firelord_aff = aff,
      phase = phase,
      has_aff = function(a) return _occ_has_aff(tgt, a) end,
      route_state = { healthleech = _occ_has_aff(tgt, "healthleech") },
      need = {},
    })
    if ok and type(r) == "table" then ranked = r end
    if type(ranked) == "table" and ranked[1] and _trim(ranked[1].cmd) ~= "" then
      return _trim(ranked[1].cmd)
    end
  end

  return ("command firelord at %s %s"):format(tgt, aff)
end

function Yso.occ.ent_refresh(tgt, ctx)
  tgt = _trim(tgt)
  if tgt == "" then return nil end
  ctx = type(ctx) == "table" and ctx or {}

  local phase = _lc(ctx.phase or Yso.occ.get_phase(tgt))
  local ER = Yso.off and Yso.off.oc and Yso.off.oc.entity_registry or nil
  if not (ER and type(ER.rank) == "function") then return nil end

  local need = {
    healthleech = not _occ_has_aff(tgt, "healthleech"),
    clumsiness = not _occ_has_aff(tgt, "clumsiness"),
  }

  local category = "fallback_support"
  if phase == "open" or phase == "pressure" or phase == "cleanse" then
    category = (need.healthleech or need.clumsiness) and "required_core_refresh" or "fallback_support"
  end

  local ranked = nil
  local ok, r = pcall(ER.rank, {
    target = tgt,
    category = category,
    phase = phase,
    eq_ready = _eq_ready(),
    has_aff = function(a) return _occ_has_aff(tgt, a) end,
    route_state = {
      asthma = _occ_has_aff(tgt, "asthma"),
      paralysis = _occ_has_aff(tgt, "paralysis"),
      addiction = _occ_has_aff(tgt, "addiction"),
      healthleech = _occ_has_aff(tgt, "healthleech"),
    },
    need = need,
  })
  if ok and type(r) == "table" then ranked = r end
  if type(ranked) ~= "table" then return nil end

  for i = 1, #ranked do
    local pick = ranked[i]
    local ent = _lc(pick and pick.entity)
    local cmd = _trim(pick and pick.cmd)
    if cmd ~= "" then
      if ent == "firelord" then
        if phase == "convert" or phase == "finish" then
          return cmd
        end
      else
        return cmd
      end
    end
  end

  return nil
end

--========================================================--

