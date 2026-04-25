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

local function _record_failure(mod, err)
  local failures = Yso._entry_failures or {}
  failures[#failures + 1] = {
    module = tostring(mod or ""),
    error = tostring(err or ""),
  }
  Yso._entry_failures = failures
end

local function _try_require(mod)
  local ok, res = pcall(require, mod)
  if ok then return true, res end
  return false, res
end

-- Guard: only run init once per session.
if Yso._entry_loaded then
  return Yso
end
Yso._entry_loaded = true
Yso._entry_failures = {}

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
  local ok, err = _try_require(mod)
  if ok then return true end
  _record_failure(mod, err)
  -- If you want this noisy, flip Yso._entry_debug=true.
  if Yso._entry_debug and type(rawget(_G, "echo")) == "function" then
    echo(("[YSO] require failed: %s (%s)\n"):format(tostring(mod), tostring(err)))
  end
  return false
end

local function safe_require_any(...)
  local tried = {}
  local errs = {}
  for i = 1, select("#", ...) do
    local mod = select(i, ...)
    if type(mod) == "string" and mod ~= "" then
      tried[#tried + 1] = mod
      local ok, err = _try_require(mod)
      if ok then return true end
      errs[#errs + 1] = { module = mod, error = err }
    end
  end
  for i = 1, #errs do
    _record_failure(errs[i].module, errs[i].error)
  end
  if Yso._entry_debug and #tried > 1 and type(rawget(_G, "echo")) == "function" then
    echo(("[YSO] require group failed: %s\n"):format(table.concat(tried, ", ")))
  end
  return false
end

-- Load canonical modules first, then remaining XML-resident legacy scripts.
safe_require_any("Yso.Core.api", "Yso.xml.api_stuff")
safe_require("Yso.Core.self_aff")
safe_require("Yso.Curing.self_curedefs")
safe_require("Yso.Curing.serverside_policy")
safe_require_any("Yso.Core.offense_state", "Yso.xml.yso_offense_state")
safe_require_any("Yso.Integration.ak_legacy_wiring", "Yso.xml.ak_legacy_wiring")
safe_require("Yso.Integration.mudlet")
safe_require("Yso.Core.queue")
safe_require("Yso.Core.wake_bus")
safe_require_any("Yso.Combat.route_registry", "Yso.xml.route_registry")
safe_require("Yso.Combat.offense_core")
safe_require("Yso.Combat.route_interface")
safe_require("Yso.Combat.hinder")
safe_require("Yso.Combat.entities")
safe_require("Yso.Combat.route_gate")
safe_require("Yso.Combat.parry")
safe_require("Yso.Combat.offense_driver")
safe_require("Yso.Curing.blademaster_curing")
safe_require("Yso.Curing.bash_vitals_swap")
safe_require("Yso.xml.information")
safe_require("Yso.xml.yso_targeting")
safe_require("Yso.xml.yso_target")
safe_require("Yso.Core.target_intel")
safe_require("Yso.xml.yso_target_tattoos")
safe_require("Yso.xml.curebuckets")
safe_require("Yso.xml.prio_baselines")
safe_require("Yso.xml.cureset_baselines")
safe_require_any("Yso.Core.modes", "Yso.xml.yso_modes")
safe_require_any("Yso.Core.mode_autoswitch", "Yso.xml.yso_mode_autoswitch")
safe_require("Yso.xml.yso_ak_score_exports")
safe_require_any("Yso.Core.predict_cure", "Yso.xml.yso_predict_cure")
safe_require_any("Yso.Core.bootstrap", "Yso.xml.bootstrap")

-- Sibling class folders (Magi, Alchemist, etc.) live beside the Yso tree.
-- Add them to package.path so require() can find them.
do
  local broot = Yso.bootstrap and Yso.bootstrap.root or ""
  if type(broot) == "string" and broot ~= "" then
    local magi_pat = broot .. "/Magi/?.lua"
    if not package.path:find(magi_pat, 1, true) then
      package.path = magi_pat .. ";" .. package.path
    end
    local alchemist_pat = broot .. "/Alchemist/?.lua"
    if not package.path:find(alchemist_pat, 1, true) then
      package.path = alchemist_pat .. ";" .. package.path
    end
  end
end

safe_require("alchemist_group_damage")
safe_require("alchemist_duel_route")
safe_require("magi_route_core")
safe_require("magi_reference")
safe_require("magi_dissonance")
safe_require("magi_group_damage")
safe_require("magi_focus")
safe_require("Magi_duel_dam")

local function _report_boot_status()
  local failures = Yso._entry_failures or {}
  local count = #failures
  Yso._entry_boot_ok = (count == 0)
  Yso._entry_boot_failures = failures

  if type(Yso.bootstrap) == "table" then
    Yso.bootstrap.entry_autoloaded = (count == 0)
    Yso.bootstrap.entry_autoload_error = (count == 0)
      and nil
      or ("_entry completed with %d load failure(s)"):format(count)
  end

  if count == 0 or Yso._entry_boot_reported then return end
  Yso._entry_boot_reported = true

  local names = {}
  local limit = math.min(count, 5)
  for i = 1, limit do
    names[#names + 1] = failures[i].module
  end
  local more = (count > limit) and ", ..." or ""
  local msg = ("[YSO] boot warnings: %d module(s) failed to load: %s%s"):format(
    count,
    table.concat(names, ", "),
    more
  )
  local cecho = rawget(_G, "cecho")
  if type(cecho) == "function" then
    cecho(("<orange>%s<reset>\n"):format(msg))
  elseif type(echo) == "function" then
    echo(msg .. "\n")
  end
end

_report_boot_status()

-- Back-compat shims expected by some triggers.

-- oc_isCurrentTarget(who): compatibility shim through Yso.is_current_target.
if type(rawget(_G, "oc_isCurrentTarget")) ~= "function" then
  ---@diagnostic disable-next-line: inject-field
  _G.oc_isCurrentTarget = function(who)
    if type(Yso.is_current_target) ~= "function" then return false end
    local ok, v = pcall(Yso.is_current_target, who)
    return ok and v == true
  end
end

-- Death helpers: route trigger calls to Integration.mudlet if present.
local function _call_integration(fn, ...)
  local ok, I = pcall(require, "Yso.Integration.mudlet")
  if (not ok or type(I) ~= "table") then
    -- Legacy fallback for older package.path layouts.
    ok, I = pcall(require, "Integration.mudlet")
  end
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
