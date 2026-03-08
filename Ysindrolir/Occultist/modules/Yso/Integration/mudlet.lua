-- Integration/mudlet.lua (optimized)
-- Integration bridge: triggers call into here, we record state in trackers and emit events.
-- Must be require-able as: require("Integration.mudlet")

local M = {}

-- ---- cache Mudlet globals once ----
local rawget = rawget
local type = type
local tostring = tostring

local cechoFn      = rawget(_G, "cecho")
local raiseEventFn = rawget(_G, "raiseEvent")

-- ---------- helpers ----------
local function dbg(msg)
  msg = tostring(msg)
  if type(cechoFn) == "function" then
    cechoFn(("\n<cyan>[Occultist]</cyan> %s\n"):format(msg))
  else
    print("[Occultist] " .. msg)
  end
end

local function safeRequire(name)
  local ok, mod = pcall(require, name)
  if ok then return mod end
  return nil
end

local function emit(eventName, ...)
  if type(raiseEventFn) == "function" then
    raiseEventFn(eventName, ...)
  end
end

local function trim(s)
  s = tostring(s or "")
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normWho(who)
  who = trim(who)
  if who == "" then return nil end
  return who
end

local function normLoc(loc)
  loc = trim(loc):lower()
  return (loc ~= "" and loc) or nil
end

local function resolveWho(who)
  who = normWho(who)
  if not who then return M.target end
  return who
end

-- Ensure the shared Occultist state table exists (consumed by Core.state_bridge).
local function occ_table()
  local Y = rawget(_G, "Yso")
  if type(Y) ~= "table" then
    Y = {}
    _G.Yso = Y
  end
  Y.occ = Y.occ or {}
  return Y.occ
end

-- ---------- optional deps ----------
local CoreState      = safeRequire("Core.state")

local OppState       = safeRequire("OppState")
local Death          = safeRequire("Combat.death")

local AffTracker     = safeRequire("AffTracker")
local LimbTracker    = safeRequire("LimbTracker")
local OffenseCore    = safeRequire("OffenseCore")

local DefenseTracker = safeRequire("DefenseTracker")
local CureUsage      = safeRequire("CureUsage")
local LimbPressure   = safeRequire("LimbPressure")

local LimbPrep       = safeRequire("LimbPrep")
local EnemyCure      = safeRequire("EnemyCure")
local Trace          = safeRequire("Debug.trace")

-- ---- cache function refs (avoids per-call type checks) ----
local Opp_setAff        = OppState and OppState.setAff
local Opp_setFrozen     = OppState and OppState.setFrozen
local Opp_setProne      = OppState and OppState.setProne
local Opp_setFrozenScore= OppState and OppState.setFrozenScore
local Opp_clearAffs     = OppState and OppState.clearAffs

local Aff_gain          = AffTracker and AffTracker.gain
local Aff_cure          = AffTracker and AffTracker.cure
local Aff_clear         = AffTracker and AffTracker.clear

local LT_hit            = LimbTracker and LimbTracker.hit
local LT_break          = LimbTracker and LimbTracker.breakLimb
local LT_reset          = LimbTracker and LimbTracker.reset

local DT_noteTree       = DefenseTracker and DefenseTracker.noteTree
local DT_noteFocusMind  = DefenseTracker and DefenseTracker.noteFocusMind
local DT_reset          = DefenseTracker and DefenseTracker.reset

local CU_noteSip        = CureUsage and CureUsage.noteSip
local CU_noteEat        = CureUsage and CureUsage.noteEat
local CU_noteSmoke      = CureUsage and CureUsage.noteSmoke
local CU_noteSalve      = CureUsage and CureUsage.noteSalve
local CU_reset          = CureUsage and CureUsage.reset

local LP_noteDamage     = LimbPressure and LimbPressure.noteDamage
local LP_noteSalve      = LimbPressure and LimbPressure.noteSalve
local LP_noteFavourEnded= LimbPressure and LimbPressure.noteFavourEnded
local LP_resetTarget    = LimbPressure and LimbPressure.resetTarget

local LPREP_onHit       = LimbPrep and LimbPrep.onHit
local LPREP_onBreak     = LimbPrep and LimbPrep.onBreak
local LPREP_resetLimb   = LimbPrep and LimbPrep.resetLimb
local LPREP_clearBroken = LimbPrep and LimbPrep.clearBroken
local LPREP_resetTarget = LimbPrep and LimbPrep.resetTarget

local EC_applyBody      = EnemyCure and EnemyCure.noteApplyBody
local EC_cureResult     = EnemyCure and EnemyCure.noteCureResult
local EC_reset          = EnemyCure and EnemyCure.reset

local Death_onRub       = Death and Death.on_rub_sent
local Death_onSniff     = Death and Death.on_sniff
local Death_setCharges  = Death and Death.set_charges

local _last_refresh = 0
local function _now()
  local f = rawget(_G, "_now")
  if type(f) == "function" then return tonumber(f()) or os.time() end
  local getEpoch = rawget(_G, "getEpoch")
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function refresh_deps(force)
  local t = _now()
  if not force and (t - _last_refresh) < 1.0 then return end
  _last_refresh = t

  OppState       = OppState       or safeRequire("OppState")
  Death          = Death          or safeRequire("Combat.death")
  AffTracker     = AffTracker     or safeRequire("AffTracker")
  LimbTracker    = LimbTracker    or safeRequire("LimbTracker")
  OffenseCore    = OffenseCore    or safeRequire("OffenseCore")
  DefenseTracker = DefenseTracker or safeRequire("DefenseTracker")
  CureUsage      = CureUsage      or safeRequire("CureUsage")
  LimbPressure   = LimbPressure   or safeRequire("LimbPressure")
  LimbPrep       = LimbPrep       or safeRequire("LimbPrep")
  EnemyCure      = EnemyCure      or safeRequire("EnemyCure")
  Trace          = Trace          or safeRequire("Debug.trace")

  Opp_setAff         = OppState and OppState.setAff
  Opp_setFrozen      = OppState and OppState.setFrozen
  Opp_setProne       = OppState and OppState.setProne
  Opp_setFrozenScore = OppState and OppState.setFrozenScore
  Opp_clearAffs      = OppState and OppState.clearAffs

  Aff_gain  = AffTracker and AffTracker.gain
  Aff_cure  = AffTracker and AffTracker.cure
  Aff_clear = AffTracker and AffTracker.clear

  LT_hit   = LimbTracker and LimbTracker.hit
  LT_break = LimbTracker and LimbTracker.breakLimb
  LT_reset = LimbTracker and LimbTracker.reset

  DT_noteTree      = DefenseTracker and DefenseTracker.noteTree
  DT_noteFocusMind = DefenseTracker and DefenseTracker.noteFocusMind
  DT_reset         = DefenseTracker and DefenseTracker.reset

  CU_noteSip   = CureUsage and CureUsage.noteSip
  CU_noteEat   = CureUsage and CureUsage.noteEat
  CU_noteSmoke = CureUsage and CureUsage.noteSmoke
  CU_noteSalve = CureUsage and CureUsage.noteSalve
  CU_reset     = CureUsage and CureUsage.reset

  LP_noteDamage      = LimbPressure and LimbPressure.noteDamage
  LP_noteSalve       = LimbPressure and LimbPressure.noteSalve
  LP_noteFavourEnded = LimbPressure and LimbPressure.noteFavourEnded
  LP_resetTarget     = LimbPressure and LimbPressure.resetTarget

  LPREP_onHit       = LimbPrep and LimbPrep.onHit
  LPREP_onBreak     = LimbPrep and LimbPrep.onBreak
  LPREP_resetLimb   = LimbPrep and LimbPrep.resetLimb
  LPREP_clearBroken = LimbPrep and LimbPrep.clearBroken
  LPREP_resetTarget = LimbPrep and LimbPrep.resetTarget

  EC_applyBody  = EnemyCure and EnemyCure.noteApplyBody
  EC_cureResult = EnemyCure and EnemyCure.noteCureResult
  EC_reset      = EnemyCure and EnemyCure.reset

  Death_onRub      = Death and Death.on_rub_sent
  Death_onSniff    = Death and Death.on_sniff
  Death_setCharges = Death and Death.set_charges
end

local function tlog(etype, data)
  refresh_deps()
  if Trace and type(Trace.log) == "function" then
    Trace.log(etype, data)
  end
end

-- ---------- public API ----------
function M.init(opts)
  refresh_deps()
  opts = opts or {}
  M.debug = opts.debug == true
  if M.debug then dbg("Integration init (debug=true)") end
end

function M.onTargetChanged(name, source)
  refresh_deps()
  name = normWho(name) or name
  M.target = name

  -- Publish target into shared occ table for Core.state_bridge fallback.
  local O = occ_table()
  O.target = name
  O.target_ts = (type(getEpoch)=="function" and getEpoch()) or (os.time()*1000)

  emit("occultist.target.changed", name)
  emit("occ.target.set", { target = name, source = source or "unknown" })
  if M.debug then dbg("Target changed -> " .. tostring(name)) end

  tlog("target.changed", { target = name, source = source or "unknown" })
end

-- ---------- Entity lane readiness (Domination "entities") ----------
-- These are *signals* from triggers. Core.state_bridge reads them to gate entity usage.
-- Typical wiring:
--   • onEntityReady(true)  when you regain entity balance / command lane
--   • onEntityReady(false) when you spend entity balance
--   • onEntitiesMissing()  when entities are missing (room change / readaura / etc)
--   • onEntitiesPresent()  when entities are available again

function M.onEntityReady(isReady)
  refresh_deps()
  local O = occ_table()
  O.entity_ready = (isReady == true)

  -- Keep SSOT entity lane (Yso.state/Yso.locks) in sync when triggers call Integration directly.
  if _G.Yso and _G.Yso.pulse and type(_G.Yso.pulse.set_ready) == "function" then
    pcall(_G.Yso.pulse.set_ready, "entity", O.entity_ready, "Integration.onEntityReady")
  elseif _G.Yso and _G.Yso.state and type(_G.Yso.state.set_ent_ready) == "function" then
    pcall(_G.Yso.state.set_ent_ready, O.entity_ready, "Integration.onEntityReady")
  end

  emit("occ.entity.ready", { ready = O.entity_ready })
  emit("occultist.entity.ready", O.entity_ready)
  if M.debug then dbg("ENTITY ready -> " .. tostring(O.entity_ready)) end

  tlog("entity.ready", { ready = O.entity_ready })
end

function M.onEntitiesMissing()
  refresh_deps()
  local O = occ_table()
  O.entities_missing = true
  O.entities_missing_ts = (type(getEpoch)=="function" and getEpoch()) or (os.time()*1000)
  emit("occ.entity.missing", { missing = true, ts = O.entities_missing_ts })
  emit("occultist.entity.missing", true)
  if M.debug then dbg("ENTITIES missing") end

  tlog("entities.missing", { missing = true, ts = O.entities_missing_ts })
end

function M.onEntitiesPresent()
  refresh_deps()
  local O = occ_table()
  O.entities_missing = false
  O.entities_missing_ts = (type(getEpoch)=="function" and getEpoch()) or (os.time()*1000)
  emit("occ.entity.missing", { missing = false, ts = O.entities_missing_ts })
  emit("occultist.entity.missing", false)
  if M.debug then dbg("ENTITIES present") end

  tlog("entities.missing", { missing = false, ts = O.entities_missing_ts })
end

function M.onTargetSet(name, source)
  refresh_deps()
  return M.onTargetChanged(name, source)
end

-- --- aff tracking ---
function M.onAffGained(who, aff)
  refresh_deps()
  who = resolveWho(who)
  if Aff_gain then Aff_gain(who, aff) end
  if Opp_setAff then Opp_setAff(who, aff, true) end
  emit("occultist.aff.gained", who, aff)
  if M.debug then dbg(("Aff gained: %s (%s)"):format(tostring(who), tostring(aff))) end
end

function M.onAffCured(who, aff)
  refresh_deps()
  who = resolveWho(who)
  if Aff_cure then Aff_cure(who, aff) end
  if Opp_setAff then Opp_setAff(who, aff, false) end
  emit("occultist.aff.cured", who, aff)
  if M.debug then dbg(("Aff cured: %s (%s)"):format(tostring(who), tostring(aff))) end
end

-- --- legacy limb tracking ---
function M.onLimbHit(who, limb, amount)
  refresh_deps()
  who = resolveWho(who)
  if LT_hit then LT_hit(limb, amount) end
  emit("occultist.limb.hit", who, limb, amount)
  if M.debug then dbg(("Limb hit: %s %s +%s"):format(tostring(who), tostring(limb), tostring(amount))) end
end

function M.onLimbBroken(who, limb)
  refresh_deps()
  who = resolveWho(who)
  if LT_break then LT_break(limb) end
  emit("occultist.limb.broken", who, limb)
  if M.debug then dbg(("Limb broken: %s (%s)"):format(tostring(who), tostring(limb))) end
end

-- ---------- BODYWARP limb prep ----------
-- FIX: increment prep via onHit (old code called onPrep with nil n -> sets prep to 0).
function M.onBodywarpPrep(who, limb)
  refresh_deps()
  who = resolveWho(who)
  if LPREP_onHit then
    LPREP_onHit(who, limb)
  end
  emit("occ.bodywarp.prep", { target = who, limb = limb })
  emit("occultist.bodywarp.prep", who, limb)
  if M.debug then dbg(("BODYWARP prep++: %s (%s)"):format(tostring(who), tostring(limb))) end

  tlog("bodywarp.prep", { target = who, limb = limb })
end

function M.onBodywarpBreak(who, limb)
  refresh_deps()
  who = resolveWho(who)
  if LPREP_onBreak then LPREP_onBreak(who, limb) end
  emit("occ.bodywarp.break", { target = who, limb = limb })
  emit("occultist.bodywarp.break", who, limb)
  if M.debug then dbg(("BODYWARP BREAK: %s (%s)"):format(tostring(who), tostring(limb))) end

  tlog("bodywarp.break", { target = who, limb = limb })
end

-- ---------- Enemy curing ----------
function M.onEnemyApplyBody(who)
  refresh_deps()
  who = resolveWho(who)
  if EC_applyBody then EC_applyBody(who) end
  emit("occ.enemy.apply_body", { target = who })
  emit("occultist.enemy.apply_body", who)
  if M.debug then dbg(("ENEMY APPLY (body): %s"):format(tostring(who))) end
end

function M.onEnemyCureResult(who, area, step)
  refresh_deps()
  who = resolveWho(who)
  local res
  if EC_cureResult then res = EC_cureResult(who, area, step) end
  emit("occ.enemy.cure_result", res or { target = who, area = area, step = step })
  emit("occultist.enemy.cure_result", who, area, step)
  if M.debug then dbg(("ENEMY CURE RESULT: %s (%s/%s)"):format(tostring(who), tostring(area), tostring(step))) end
end

-- ---------- Frozen score ----------
function M.onFrozenScore(who, score)
  refresh_deps()
  who = resolveWho(who)
  if Opp_setFrozenScore then Opp_setFrozenScore(who, score) end
  emit("occ.aff.frozen_score", { target = who, score = tonumber(score) or 0 })
  emit("occultist.aff.frozen_score", who, score)
  if M.debug then dbg(("FROZEN score: %s -> %s"):format(tostring(who), tostring(score))) end
end

function M.onResetTargetState()
  refresh_deps()
  local who = M.target
  if Aff_clear then Aff_clear(who) end
  if LT_reset then LT_reset() end
  if DT_reset then DT_reset(who) end
  if CU_reset then CU_reset(who) end
  if LP_resetTarget then LP_resetTarget(who) end
  if LPREP_resetTarget then LPREP_resetTarget(who) end
  if EC_reset then EC_reset(who) end
  if Opp_clearAffs then Opp_clearAffs(who) end

  emit("occultist.target.reset")
  emit("occ.target.reset", { target = who })
  if M.debug then dbg("Target state reset") end
end

-- ---------- Death (Tarot) tracking ----------
function M.onDeathRub(who)
  refresh_deps()
  who = resolveWho(who)
  if Death_onRub then Death_onRub(who) end
  emit("occultist.death.rub", who)
  if M.debug then dbg(("Death rub sent: %s"):format(tostring(who))) end
end

function M.onDeathSniff(who, count)
  refresh_deps()
  who = resolveWho(who)
  if Death_onSniff then Death_onSniff(who, count) end
  emit("occultist.death.sniff", who, count)
  if M.debug then dbg(("Death sniff: %s -> %s"):format(tostring(who), tostring(count))) end
end

function M.onDeathRubSent(who)
  refresh_deps()
  return M.onDeathRub(who)
end

function M.onDeathFlingSuccess(who)
  refresh_deps()
  who = resolveWho(who)
  if Death_setCharges then Death_setCharges(who, 0) end
  emit("occultist.death.fling.success", who)
  if M.debug then dbg(("Death fling SUCCESS: %s"):format(tostring(who))) end
end

function M.onDeathFlingFail(who)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.death.fling.fail", who)
  if M.debug then dbg(("Death fling FAIL: %s"):format(tostring(who))) end
end

function M.onDeathChannelEnd(who)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.death.channel.end", who)
  if M.debug then dbg(("Death channel end: %s"):format(tostring(who))) end
end

-- ---------- PvP opponent tracking hooks ----------
function M.onTargetTree(who)
  refresh_deps()
  who = resolveWho(who)
  if DT_noteTree then DT_noteTree(who) end
  emit("occultist.defense.tree.used", who)
  if M.debug then dbg(("TREE used by %s"):format(tostring(who))) end
end

function M.onTargetFocusMind(who)
  refresh_deps()
  who = resolveWho(who)
  if DT_noteFocusMind then DT_noteFocusMind(who) end
  emit("occultist.defense.focusmind.used", who)
  if M.debug then dbg(("FOCUS used by %s"):format(tostring(who))) end
end

function M.onTargetSip(who, what)
  refresh_deps()
  who = resolveWho(who)
  if CU_noteSip then CU_noteSip(who, what) end
  emit("occultist.cure.sip", who, what)
  if M.debug then dbg(("SIP by %s: %s"):format(tostring(who), tostring(what))) end
end

function M.onTargetEat(who, what)
  refresh_deps()
  who = resolveWho(who)
  if CU_noteEat then CU_noteEat(who, what) end
  emit("occultist.cure.eat", who, what)
  if M.debug then dbg(("EAT by %s: %s"):format(tostring(who), tostring(what))) end
end

function M.onTargetSmoke(who, what)
  refresh_deps()
  who = resolveWho(who)
  if CU_noteSmoke then CU_noteSmoke(who, what) end
  emit("occultist.cure.smoke", who, what)
  if M.debug then dbg(("SMOKE by %s: %s"):format(tostring(who), tostring(what))) end
end

function M.onLimbDamage(who, limb, pct)
  refresh_deps()
  who = resolveWho(who)
  if LP_noteDamage then LP_noteDamage(who, limb, pct) end

  if LPREP_onHit then
    local res = LPREP_onHit(who, limb)
    if res and res.action == "prep" then
      emit("occ.bodywarp.prep", who, res.limb or limb, res.prep, res.hits, pct)
    elseif res and res.action == "break" then
      emit("occ.bodywarp.break", who, res.limb or limb, pct)
    end
  end

  emit("occultist.limb.pressure.hit", who, limb, pct)
  if M.debug then dbg(("LIMB %s +%s%% (%s)"):format(tostring(who), tostring(pct), tostring(limb))) end

  tlog("limb.damage", { target = who, limb = limb, delta = tonumber(pct) or pct })
end

function M.onEnemySalve(who, loc)
  refresh_deps()
  who = resolveWho(who)
  loc = normLoc(loc) or loc

  if CU_noteSalve then CU_noteSalve(who, loc) end
  if LP_noteSalve then LP_noteSalve(who, loc) end

  if EC_cureResult then
    local info = EC_cureResult(who, loc, "unknown")
    emit("occ.enemy.cure.cycle", info)
  end

  emit("occultist.limb.salve.applied", who, loc)
  if M.debug then dbg(("SALVE by %s on %s"):format(tostring(who), tostring(loc))) end

  if loc == "skin" and Opp_setFrozen then
    Opp_setFrozen(who, false)
  end
end

function M.onCeasesToFavour(who, limb)
  refresh_deps()
  who = resolveWho(who)
  if LP_noteFavourEnded then LP_noteFavourEnded(who, limb) end
  if LPREP_resetLimb then
    LPREP_resetLimb(who, limb)
  elseif LPREP_clearBroken then
    LPREP_clearBroken(who, limb)
  end
  emit("occultist.limb.favour.ended", who, limb)
  if M.debug then dbg(("FAVOUR ENDED: %s (%s)"):format(tostring(who), tostring(limb))) end
end

function M.onOppFrozenGained(who)
  refresh_deps()
  who = resolveWho(who)
  if Opp_setFrozen then Opp_setFrozen(who, true) end
  emit("occultist.opp.frozen.gained", who)
  if M.debug then dbg(("FROZEN gained by %s"):format(tostring(who))) end

  tlog("opp.frozen", { target = who, value = true })
end

function M.onOppProneGained(who)
  refresh_deps()
  who = resolveWho(who)
  if Opp_setProne then Opp_setProne(who, true) end
  emit("occultist.opp.prone.gained", who)
  if M.debug then dbg(("PRONE gained by %s"):format(tostring(who))) end

  tlog("opp.prone", { target = who, value = true })
end

function M.onOppProneCured(who)
  refresh_deps()
  who = resolveWho(who)
  if Opp_setProne then Opp_setProne(who, false) end
  if LPREP_clearBroken then
    LPREP_clearBroken(who, "left_leg")
    LPREP_clearBroken(who, "right_leg")
  end
  emit("occultist.opp.prone.cured", who)
  if M.debug then dbg(("PRONE cured by %s"):format(tostring(who))) end

  tlog("opp.prone", { target = who, value = false })
end

-- --- offense tick convenience ---
local CombatOffense = safeRequire("Combat.offense_core")

function M.tickOffense()
  refresh_deps()
  if not CombatOffense then
    CombatOffense = safeRequire("Combat.offense_core")
  end
  if CombatOffense and type(CombatOffense.tick) == "function" then
    return CombatOffense.tick()
  end

  if not OffenseCore then
    OffenseCore = safeRequire("OffenseCore")
  end
  if OffenseCore and type(OffenseCore.tick) == "function" then
    return OffenseCore.tick()
  end
  if OffenseCore and type(OffenseCore.execute) == "function" then
    return OffenseCore.execute()
  end

  if M.debug then dbg("tickOffense(): no offense core available.") end
  return nil
end


-- ---------- limb.1.2 bridge (event: "limb hits updated") ----------
-- limb.1.2 emits: raiseEvent("limb hits updated", name, limb, amount)
-- where limb is e.g. "left leg" and amount is the delta percent.
-- We translate this into LimbPressure + LimbPrep updates *only* when the Occultist offense
-- is actively operating on that target.
M._eh = M._eh or {}

local function _kill_eh(id)
  if id and type(killAnonymousEventHandler) == "function" then
    pcall(killAnonymousEventHandler, id)
  end
end

local function _same_tgt(a, b)
  a = tostring(a or ""):lower()
  b = tostring(b or ""):lower()
  return a ~= "" and a == b
end

local function _register_limb_hits_updated()
  if type(registerAnonymousEventHandler) ~= "function" then return end

  _kill_eh(M._eh.limb_hits_updated)
  M._eh.limb_hits_updated = registerAnonymousEventHandler("limb hits updated", function(name, limb, amount)
    if type(name) ~= "string" then return end
    limb = tostring(limb or "")
    if limb == "" or limb:lower() == "all" then return end

    -- Gate: only when our offense is enabled and this is our active target.
    if CoreState then
      if CoreState.enabled == false then return end
      if CoreState.target and not _same_tgt(name, CoreState.target) then return end
      local r = CoreState.route
      if r and r ~= "limb_prep" and r ~= "limb" and r ~= "lock" then
        return
      end
    end

    -- Try to read running total from limb.1.2 (lb[name].hits[limb]).
    local total
    local lb = rawget(_G, "lb")
    if type(lb) == "table" and type(lb[name]) == "table" and type(lb[name].hits) == "table" then
      total = lb[name].hits[limb] or lb[name].hits[limb:lower()] or lb[name].hits[limb:lower():gsub("_", " ")]
    end

    -- If the total is 100%+ we treat as broken confirmation.
    if total and tonumber(total) and tonumber(total) >= 100 then
      M.onBodywarpBreak(name, limb)
      return
    end

    local delta = tonumber(amount) or 0
    if delta > 0 then
      -- count this as a prep hit and also feed percent pressure
      M.onLimbDamage(name, limb, delta)
    else
      -- delta unknown: still count as a prep hit
      M.onBodywarpPrep(name, limb)
    end
  end)
end

_register_limb_hits_updated()

return M
