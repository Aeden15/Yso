-- Yso/_entry.lua
-- Single source of truth loader.
-- Loads the filesystem-exported equivalents of scripts formerly embedded in the Mudlet XML package.
-- This module is safe to require multiple times.

local _G = _G
local rawget = rawget
local type = type
local tostring = tostring
local pcall = pcall
local require = require
local echo = rawget(_G, "echo")

-- Normalize root namespace so both _G.Yso and _G.yso exist and match.
do
  local root = rawget(_G, "Yso")
  if type(root) ~= "table" then root = rawget(_G, "yso") end
  if type(root) ~= "table" then root = {} end
  _G.Yso = root
  _G.yso = root
end

local Yso = _G.Yso

local function _set_root(root)
  if type(root) ~= "string" then return false end
  root = tostring(root or ""):gsub("\\", "/"):gsub("/+$", "")
  if root == "" then return false end
  _G.YSO_ROOT = root
  _G.yso_root = root
  return true
end

local function _collect_reload_modules()
  local names = {}
  for name, _ in pairs(package.loaded or {}) do
    if name == "Yso"
      or name == "Yso._entry"
      or name == "Integration.mudlet"
      or tostring(name):match("^Yso%.")
    then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

function Yso.reload(root)
  _set_root(root)

  if Yso.queue and type(Yso.queue.clear) == "function" then
    pcall(Yso.queue.clear)
  end
  if Yso.pulse and type(Yso.pulse.stop) == "function" then
    pcall(Yso.pulse.stop)
  end

  Yso._entry_loaded = nil
  _G.yso_bootstrap_done = nil

  local names = _collect_reload_modules()
  for i = 1, #names do
    package.loaded[names[i]] = nil
  end

  local ok, mod = pcall(require, "Yso")
  if not ok then
    if type(rawget(_G, "echo")) == "function" then
      echo(("[YSO] reload failed: %s\n"):format(tostring(mod)))
    end
    return false, mod
  end

  if type(rawget(_G, "cecho")) == "function" then
    cecho(("<dark_orchid>[Yso] <reset>reloaded from %s\n"):format(tostring(_G.YSO_ROOT or _G.yso_root or "active root")))
  end

  return true, mod
end

-- Guard: only run init once per session.
if Yso._entry_loaded then
  return Yso
end
Yso._entry_loaded = true

-- Provide a lightweight time helper if missing.
if type(rawget(_G, "_now")) ~= "function" then
  ---@diagnostic disable-next-line: inject-field
  _G._now = function()
    local getEpoch = rawget(_G, "getEpoch")
    if type(getEpoch) == "function" then
      local t = tonumber(getEpoch()) or os.time()
      if t > 20000000000 then t = t / 1000 end
      return t
    end
    return os.time()
  end
end

-- Safe require wrapper.
local function safe_require(mod)
  local ok, err = pcall(require, mod)
  if ok then return true end
  -- If you want this noisy, flip Yso._entry_debug=true.
  if Yso._entry_debug and type(rawget(_G, "echo")) == "function" then
    echo(("[YSO] require failed: %s (%s)\n"):format(tostring(mod), tostring(err)))
  end
  return false
end

-- Bootstrap MUST load first: sets up package.path so all other requires resolve.
safe_require("Yso.xml.bootstrap")

-- Load exported scripts in original XML order.
safe_require("Yso.xml.api_stuff")
safe_require("Yso.xml.ak_legacy_wiring")
safe_require("Yso.xml.yso_queue")
safe_require("Yso.xml.yso_pulse_wake_bus")
safe_require("Yso.xml.yso_occultist_affmap")
safe_require("Yso.xml.group_damage")
safe_require("Yso.xml.occ_aff_burst")
safe_require("Yso.xml.yso_occultist_offense")
safe_require("Yso.xml.information")
safe_require("Yso.xml.yso_targeting")
safe_require("Yso.xml.yso_target")
safe_require("Yso.xml.yso_target_intel")
safe_require("Yso.xml.yso_target_tattoos")
safe_require("Yso.xml.softlock_gate")
safe_require("Yso.xml.curebuckets")
safe_require("Yso.xml.pronecontroller")
safe_require("Yso.xml.yso_list_of_functions")
safe_require("Yso.xml.yso_aeon")
safe_require("Yso.xml.yso_offense_coordination")
safe_require("Yso.xml.yso_orchestrator")
safe_require("Yso.xml.devil_tracker")
safe_require("Yso.xml.priestess_heal")
safe_require("Yso.xml.magician_heal")
safe_require("Yso.xml.fool_logic")
safe_require("Yso.xml.yso_travel_router")
safe_require("Yso.xml.yso_travel_universe")
safe_require("Yso.xml.entourage_script")
safe_require("Yso.xml.doppleganger_things")
safe_require("Yso.xml.vitals_stones")
safe_require("Yso.xml.yso_occultist_pacts")
safe_require("Yso.xml.occultism_reference")
safe_require("Yso.xml.tarot_reference")
safe_require("Yso.xml.skillset_reference_chart")
safe_require("Yso.xml.domination_reference")
safe_require("Yso.xml.sightgate")
safe_require("Yso.xml.yso_occ_truename_capture")
safe_require("Yso.xml.self_limb_tracking")
safe_require("Yso.xml.prio_baselines")
safe_require("Yso.xml.cureset_baselines")
safe_require("Yso.xml.yso_configs")
safe_require("Yso.xml.yso_modes")
safe_require("Yso.xml.yso_mode_autoswitch")
safe_require("Yso.xml.yso_escape_button")
safe_require("Yso.xml.yso_alert_radiance_helper")
safe_require("Yso.xml.radiance_event")
safe_require("Yso.xml.yso_hunt_mode_upkeep")
safe_require("Yso.xml.hunt_primebond_shieldbreak_selector")
safe_require("Yso.xml.occie_random_generator")
safe_require("Yso.xml.yso_ak_score_exports")
safe_require("Yso.xml.yso_predict_cure")
safe_require("Yso.xml.clock_limb_dry_test")

-- Back-compat shims expected by some triggers.

-- oc_isCurrentTarget(who): prefer Yso.targeting service if present, else compare to global `target`.
if type(rawget(_G, "oc_isCurrentTarget")) ~= "function" then
  ---@diagnostic disable-next-line: inject-field
  _G.oc_isCurrentTarget = function(who)
    who = tostring(who or ""):gsub("^%s+",""):gsub("%s+$","")
    if who == "" then return false end

    local cur = nil

    -- Prefer Yso targeting service.
    if Yso and Yso.targeting and type(Yso.targeting.get) == "function" then
      local ok, v = pcall(Yso.targeting.get)
      if ok then cur = v end
    end

    -- Fall back to Yso helpers / state.
    if type(cur) ~= "string" or cur == "" then
      if type(Yso.get_target) == "function" then
        local ok, v = pcall(Yso.get_target); if ok then cur = v end
      elseif type(Yso.target) == "string" then
        cur = Yso.target
      elseif Yso.state and type(Yso.state.target) == "string" then
        cur = Yso.state.target
      end
    end

    -- Fall back to AK target if present.
    if type(cur) ~= "string" or cur == "" then
      local ak = rawget(_G, "ak")
      if type(ak) == "table" then
        if type(ak.target) == "string" then cur = ak.target
        elseif type(ak.tgt) == "string" then cur = ak.tgt end
      end
    end

    -- GMCP target fallback.
    if type(cur) ~= "string" or cur == "" then
      local g = rawget(_G, "gmcp")
      local t = g and g.Char and (g.Char.Target or g.Char.target)
      if t and type(t.name) == "string" then cur = t.name end
    end

    -- Legacy global `target` fallback.
    if type(cur) ~= "string" or cur == "" then
      cur = rawget(_G, "target")
    end

    if type(cur) ~= "string" or cur == "" then return false end
    return cur:lower() == who:lower()
  end
end

-- Death helpers: route trigger calls to Integration.mudlet if present.
local function _call_integration(fn, ...)
  local ok, I = pcall(require, "Integration.mudlet")
  if not ok or type(I) ~= "table" then return false end
  local f = I[fn]
  if type(f) ~= "function" then return false end
  pcall(f, ...)
  return true
end

if type(rawget(_G, "oc_death_channel_end")) ~= "function" then
  ---@diagnostic disable-next-line: inject-field
  _G.oc_death_channel_end = function() _call_integration("onDeathChannelEnd") end
end
if type(rawget(_G, "oc_death_fling_fail")) ~= "function" then
  ---@diagnostic disable-next-line: inject-field
  _G.oc_death_fling_fail = function() _call_integration("onDeathFlingFail") end
end
if type(rawget(_G, "oc_death_fling_success")) ~= "function" then
  ---@diagnostic disable-next-line: inject-field
  _G.oc_death_fling_success = function(who) _call_integration("onDeathFlingSuccess", who) end
end
if type(rawget(_G, "oc_death_rub")) ~= "function" then
  ---@diagnostic disable-next-line: inject-field
  _G.oc_death_rub = function(who) _call_integration("onDeathRub", who) end
end
if type(rawget(_G, "oc_death_sniff")) ~= "function" then
  ---@diagnostic disable-next-line: inject-field
  _G.oc_death_sniff = function(who, n) _call_integration("onDeathSniff", who, n) end
end

return Yso

