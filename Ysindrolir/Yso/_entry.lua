-- Yso/_entry.lua
-- Mudlet-native compatibility shim.
-- In package-first mode, route/core scripts are loaded by Mudlet script order,
-- not via require() bootstrap chains.

local _G = _G
local rawget = rawget
local type = type
local tostring = tostring
local pcall = pcall
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

-- Guard: only run init once per session.
if Yso._entry_loaded then
  return Yso
end
Yso._entry_loaded = true
Yso._entry_mode = "mudlet_native_no_require"

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

Yso._entry_boot_ok = true
Yso._entry_boot_failures = {}

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
local function _warn_integration_once(fn, detail)
  Yso._entry_integration_warnings = Yso._entry_integration_warnings or {}
  local key = tostring(fn or "unknown") .. ":" .. tostring(detail or "failure")
  if Yso._entry_integration_warnings[key] then return end
  Yso._entry_integration_warnings[key] = true
  local msg = ("[YSO] integration warning (%s): %s"):format(tostring(fn or "unknown"), tostring(detail or "failure"))
  local cecho = rawget(_G, "cecho")
  if type(cecho) == "function" then
    cecho(("<orange>%s<reset>\n"):format(msg))
  elseif type(echo) == "function" then
    echo(msg .. "\n")
  end
end

local function _call_integration(fn, ...)
  local I = Yso and Yso.Integration and Yso.Integration.mudlet or nil
  if type(I) ~= "table" then
    _warn_integration_once(fn, "module_unavailable")
    return false, "module_unavailable"
  end
  local f = I[fn]
  if type(f) ~= "function" then
    _warn_integration_once(fn, "handler_missing")
    return false, "handler_missing"
  end
  local call_ok, call_err = pcall(f, ...)
  if not call_ok then
    _warn_integration_once(fn, tostring(call_err or "handler_error"))
    return false, call_err
  end
  return true, nil
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
