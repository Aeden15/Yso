-- Integration/mudlet.lua
-- Thin trigger bridge for the workspace-backed Yso runtime.
-- Trigger handlers publish events and a small shared state surface only.
-- Deleted legacy wrapper modules are intentionally not required here.
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

-- Ensure the shared Occultist state table exists for lightweight cross-module state.
local function occ_table()
  local Y = rawget(_G, "Yso")
  if type(Y) ~= "table" then
    Y = {}
    _G.Yso = Y
  end
  Y.occ = Y.occ or {}
  return Y.occ
end

-- Legacy wrapper modules were removed from the workspace. Keep the bridge API,
-- but do not probe deleted compatibility layers on every trigger.
local function refresh_deps() end

local function tlog(etype, data)
  local Y = rawget(_G, "Yso")
  local T = type(Y) == "table" and Y.trace or nil
  if type(T) == "table" and type(T.push) == "function" then
    pcall(T.push, etype, data or {})
  end
end

-- ---------- public API ----------
function M.init(opts)
  opts = opts or {}
  M.debug = opts.debug == true
  if M.debug then dbg("Integration init (debug=true)") end
end

function M.onTargetChanged(name, source)
  refresh_deps()
  name = normWho(name) or name
  M.target = name

  -- Publish target into the shared Occultist state table for listeners.
  local O = occ_table()
  O.target = name
  O.target_ts = (type(getEpoch)=="function" and getEpoch()) or (os.time()*1000)

  emit("occultist.target.changed", name)
  emit("occ.target.set", { target = name, source = source or "unknown" })
  if M.debug then dbg("Target changed -> " .. tostring(name)) end

  tlog("target.changed", { target = name, source = source or "unknown" })
end

-- ---------- Entity lane readiness (Domination "entities") ----------
-- These are *signals* from triggers. Yso.state / Yso.pulse consume them for entity gating.
-- Typical wiring:
--   * onEntityReady(true)  when you regain entity balance / command lane
--   * onEntityReady(false) when you spend entity balance
--   * onEntitiesMissing()  when entities are missing (room change / readaura / etc)
--   * onEntitiesPresent()  when entities are available again

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
  emit("occultist.aff.gained", who, aff)
  if M.debug then dbg(("Aff gained: %s (%s)"):format(tostring(who), tostring(aff))) end
end

function M.onAffCured(who, aff)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.aff.cured", who, aff)
  if M.debug then dbg(("Aff cured: %s (%s)"):format(tostring(who), tostring(aff))) end
end

-- --- legacy limb tracking ---
function M.onLimbHit(who, limb, amount)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.limb.hit", who, limb, amount)
  if M.debug then dbg(("Limb hit: %s %s +%s"):format(tostring(who), tostring(limb), tostring(amount))) end
end

function M.onLimbBroken(who, limb)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.limb.broken", who, limb)
  if M.debug then dbg(("Limb broken: %s (%s)"):format(tostring(who), tostring(limb))) end
end

-- ---------- BODYWARP limb prep ----------
-- FIX: increment prep via onHit (old code called onPrep with nil n -> sets prep to 0).
function M.onBodywarpPrep(who, limb)
  refresh_deps()
  who = resolveWho(who)
  emit("occ.bodywarp.prep", { target = who, limb = limb })
  emit("occultist.bodywarp.prep", who, limb)
  if M.debug then dbg(("BODYWARP prep++: %s (%s)"):format(tostring(who), tostring(limb))) end

  tlog("bodywarp.prep", { target = who, limb = limb })
end

function M.onBodywarpBreak(who, limb)
  refresh_deps()
  who = resolveWho(who)
  emit("occ.bodywarp.break", { target = who, limb = limb })
  emit("occultist.bodywarp.break", who, limb)
  if M.debug then dbg(("BODYWARP BREAK: %s (%s)"):format(tostring(who), tostring(limb))) end

  tlog("bodywarp.break", { target = who, limb = limb })
end

-- ---------- Enemy curing ----------
function M.onEnemyApplyBody(who)
  refresh_deps()
  who = resolveWho(who)
  emit("occ.enemy.apply_body", { target = who })
  emit("occultist.enemy.apply_body", who)
  if M.debug then dbg(("ENEMY APPLY (body): %s"):format(tostring(who))) end
end

function M.onEnemyCureResult(who, area, step)
  refresh_deps()
  who = resolveWho(who)
  emit("occ.enemy.cure_result", { target = who, area = area, step = step })
  emit("occultist.enemy.cure_result", who, area, step)
  if M.debug then dbg(("ENEMY CURE RESULT: %s (%s/%s)"):format(tostring(who), tostring(area), tostring(step))) end
end

-- ---------- Frozen score ----------
function M.onFrozenScore(who, score)
  refresh_deps()
  who = resolveWho(who)
  emit("occ.aff.frozen_score", { target = who, score = tonumber(score) or 0 })
  emit("occultist.aff.frozen_score", who, score)
  if M.debug then dbg(("FROZEN score: %s -> %s"):format(tostring(who), tostring(score))) end
end

function M.onResetTargetState()
  refresh_deps()
  local who = M.target
  emit("occultist.target.reset")
  emit("occ.target.reset", { target = who })
  if M.debug then dbg("Target state reset") end
end

-- ---------- Death (Tarot) tracking ----------
function M.onDeathRub(who)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.death.rub", who)
  if M.debug then dbg(("Death rub sent: %s"):format(tostring(who))) end
end

function M.onDeathSniff(who, count)
  refresh_deps()
  who = resolveWho(who)
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
  emit("occultist.defense.tree.used", who)
  if M.debug then dbg(("TREE used by %s"):format(tostring(who))) end
end

function M.onTargetFocusMind(who)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.defense.focusmind.used", who)
  if M.debug then dbg(("FOCUS used by %s"):format(tostring(who))) end
end

function M.onTargetSip(who, what)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.cure.sip", who, what)
  if M.debug then dbg(("SIP by %s: %s"):format(tostring(who), tostring(what))) end
end

function M.onTargetEat(who, what)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.cure.eat", who, what)
  if M.debug then dbg(("EAT by %s: %s"):format(tostring(who), tostring(what))) end
end

function M.onTargetSmoke(who, what)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.cure.smoke", who, what)
  if M.debug then dbg(("SMOKE by %s: %s"):format(tostring(who), tostring(what))) end
end

function M.onLimbDamage(who, limb, pct)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.limb.pressure.hit", who, limb, pct)
  if M.debug then dbg(("LIMB %s +%s%% (%s)"):format(tostring(who), tostring(pct), tostring(limb))) end

  tlog("limb.damage", { target = who, limb = limb, delta = tonumber(pct) or pct })
end

function M.onEnemySalve(who, loc)
  refresh_deps()
  who = resolveWho(who)
  loc = normLoc(loc) or loc
  emit("occ.enemy.cure.cycle", { target = who, area = loc, step = "unknown" })
  emit("occultist.limb.salve.applied", who, loc)
  if M.debug then dbg(("SALVE by %s on %s"):format(tostring(who), tostring(loc))) end
end

function M.onCeasesToFavour(who, limb)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.limb.favour.ended", who, limb)
  if M.debug then dbg(("FAVOUR ENDED: %s (%s)"):format(tostring(who), tostring(limb))) end
end

function M.onOppFrozenGained(who)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.opp.frozen.gained", who)
  if M.debug then dbg(("FROZEN gained by %s"):format(tostring(who))) end

  tlog("opp.frozen", { target = who, value = true })
end

function M.onOppProneGained(who)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.opp.prone.gained", who)
  if M.debug then dbg(("PRONE gained by %s"):format(tostring(who))) end

  tlog("opp.prone", { target = who, value = true })
end

function M.onOppProneCured(who)
  refresh_deps()
  who = resolveWho(who)
  emit("occultist.opp.prone.cured", who)
  if M.debug then dbg(("PRONE cured by %s"):format(tostring(who))) end

  tlog("opp.prone", { target = who, value = false })
end

-- tickOffense is a no-op: the Orchestrator now owns all automated offense ticking.
function M.tickOffense()
  return nil
end


-- ---------- limb.1.2 bridge (event: "limb hits updated") ----------
-- limb.1.2 emits: raiseEvent("limb hits updated", name, limb, amount)
-- where limb is e.g. "left leg" and amount is the delta percent.
-- We translate this into generic limb/bodywarp events for listeners that care.
M._eh = M._eh or {}

local function _kill_eh(id)
  if id and type(killAnonymousEventHandler) == "function" then
    pcall(killAnonymousEventHandler, id)
  end
end

local function _register_limb_hits_updated()
  if type(registerAnonymousEventHandler) ~= "function" then return end

  _kill_eh(M._eh.limb_hits_updated)
  M._eh.limb_hits_updated = registerAnonymousEventHandler("limb hits updated", function(name, limb, amount)
    if type(name) ~= "string" then return end
    limb = tostring(limb or "")
    if limb == "" or limb:lower() == "all" then return end

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
