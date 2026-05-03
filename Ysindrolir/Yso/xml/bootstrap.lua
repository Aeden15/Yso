--========================================================--
-- Yso bootstrap
--  • Locates the workspace root and extends package.path.
--  • Exposes a small bootstrap API for route/module reloads.
--
--  YSO_ROOT / root discovery (disk require() path):
--    Set YSO_ROOT or _G.YSO_ROOT to the Ysindrolir repo root (parent of Yso/).
--    _auto_roots() order: _G.YSO_ROOT, _G.yso_root, os.getenv("YSO_ROOT"),
--    getMudletHomeDir() candidates, then USERPROFILE/Desktop heuristics and
--    local fallbacks. The Mudlet-only yso_bootstrap_loader.lua runs first in
--    packages and may dofile bootstrap via env before this module is required.
--    Windows (session):  $env:YSO_ROOT = "C:\path\to\Ysindrolir"
--    Windows (persistent):  setx YSO_ROOT "C:\path\to\Ysindrolir"
--========================================================--

_G.yso_default_package_path = _G.yso_default_package_path or package.path
if _G.yso_bootstrap_done then
  local root = rawget(_G, "Yso") or rawget(_G, "yso")
  return type(root) == "table" and root.bootstrap or true
end

local function _dir_exists(p)
  p = tostring(p or "")
  if p == "" then return false end
  if type(lfs) == "table" and type(lfs.attributes) == "function" then
    local a = lfs.attributes(p)
    return a and a.mode == "directory" or false
  end
  local ok, _, code = os.rename(p, p)
  if ok then return true end
  -- Windows returns 13 for existing directory rename permission denials.
  return tonumber(code) == 13
end

local function _file_exists(p)
  local f = io.open(tostring(p or ""), "r")
  if not f then return false end
  f:close()
  return true
end

local function _looks_like_root(p)
  p = tostring(p or ""):gsub("\\", "/"):gsub("/+$", "")
  if p == "" then return false end
  if not _dir_exists(p) then return false end
  return _file_exists(p .. "/Yso/_entry.lua")
      or _file_exists(p .. "/Yso/Core/bootstrap.lua")
      or _file_exists(p .. "/Yso/xml/bootstrap.lua")
end

local function _pick_root(...)
  local cand = { ... }
  for i = 1, #cand do
    local p = tostring(cand[i] or "")
    if _looks_like_root(p) then return p end
  end
  for i = 1, #cand do
    local p = tostring(cand[i] or "")
    if _dir_exists(p) then return p end
  end
  return tostring(cand[1] or "")
end

local function _auto_roots()
  local out = {}
  if type(_G.YSO_ROOT) == "string" and _G.YSO_ROOT ~= "" then out[#out+1] = _G.YSO_ROOT end
  if type(_G.yso_root) == "string" and _G.yso_root ~= "" then out[#out+1] = _G.yso_root end
  do
    local er = os.getenv("YSO_ROOT")
    if type(er) == "string" and er ~= "" then out[#out+1] = er end
  end

  if type(getMudletHomeDir) == "function" then
    local mhome = tostring(getMudletHomeDir() or ""):gsub("\\", "/"):gsub("/+$", "")
    if mhome ~= "" then
      out[#out+1] = mhome .. "/Yso/modules"
      out[#out+1] = mhome .. "/Achaea/Yso/modules"
      out[#out+1] = mhome .. "/modules/Yso"
    end
  end

  local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
  home = tostring(home or ""):gsub("\\", "/"):gsub("/+$", "")
  if home ~= "" then
    local extra = {
      home .. "/Desktop/Yso systems/Ysindrolir",
      home .. "/OneDrive/Desktop/Yso systems/Ysindrolir",
      home .. "/Desktop/Yso systems/Ysindrolir/modules",
      home .. "/OneDrive/Desktop/Yso systems/Ysindrolir/modules",
      home .. "/Desktop/Yso systems/Ysindrolir/Yso",
      home .. "/OneDrive/Desktop/Yso systems/Ysindrolir/Yso",
    }
    for i = 1, #extra do out[#out+1] = extra[i] end
  end

  return out
end

local _auto = _auto_roots()
local root = _pick_root(
  _auto[1], _auto[2], _auto[3], _auto[4], _auto[5], _auto[6], _auto[7],
  _auto[8], _auto[9], _auto[10], _auto[11], _auto[12], _auto[13],
  -- Local fallback paths for this workspace; keep these updated when the
  -- workspace is relocated or shared across machines.
  "C:/Users/shuji/OneDrive/Desktop/Yso systems/Ysindrolir",
  "C:/Users/shuji/Desktop/Yso systems/Ysindrolir",
  "C:/Yso/modules",
  "C:/Achaea/Yso/modules",
  "D:/Yso/modules",
  "D:/Achaea/Yso/modules"
)

root = tostring(root):gsub("\\", "/"):gsub("/+$", "")

do
  local function _pp(pat)
    if pat and pat ~= "" and not package.path:find(pat, 1, true) then
      package.path = pat .. ";" .. package.path
    end
  end
  _pp(root .. "/?.lua")
  _pp(root .. "/?/init.lua")
  _pp(root .. "/Yso/?.lua")
  _pp(root .. "/Yso/?/init.lua")

  _pp(root .. "/Magi/?.lua")
  _pp(root .. "/Alchemist/?.lua")
end

if not package.searchpath then
  function package.searchpath(name, path, sep, rep)
    sep = sep or "."
    rep = rep or "/"
    local pname = name:gsub("%" .. sep, rep)

    for template in tostring(path):gmatch("[^;]+") do
      local filename = template:gsub("%?", pname)
      local f = io.open(filename, "r")
      if f then
        f:close()
        return filename
      end
    end

    return nil, "module '" .. tostring(name) .. "' not found in path"
  end
end

_G.yso_bootstrap_done = true

Yso = rawget(_G, "Yso") or rawget(_G, "yso") or {}
_G.Yso = Yso
_G.yso = Yso
Yso.bootstrap = Yso.bootstrap or {}
Yso.bootstrap.root = root
Yso.bootstrap.core_order = Yso.bootstrap.core_order or {
  "Yso.Core.api",
  "Yso.Core.self_aff",
  "Yso.Curing.self_curedefs",
  "Yso.Curing.serverside_policy",
  "Yso.Core.offense_state",
  "Yso.Integration.ak_legacy_wiring",
  "Yso.Core.queue",
  "Yso.Core.wake_bus",
  "Yso.Combat.route_registry",
  "Yso.Combat.offense_core",
  "Yso.Combat.route_interface",
  "Yso.Combat.hinder",
  "Yso.Combat.entities",
  "Yso.Combat.route_gate",
  "Yso.Combat.parry",
  "Yso.Combat.offense_driver",
  "Yso.Core.target_intel",
  "Yso.xml.yso_target_tattoos",
  "Yso.xml.curebuckets",
  "Yso.Core.predict_cure",
  "Yso.Core.modes",
}

local function _bootstrap_require(mod, reload)
  if type(mod) ~= "string" or mod == "" then return nil, false, "bad module" end
  if reload == true then package.loaded[mod] = nil end
  local ok, res = pcall(require, mod)
  if ok then return res, true end
  return nil, false, res
end

local function _bootstrap_entry(reload)
  local mod, ok = _bootstrap_require("Yso", reload)
  if ok then return mod, true end
  return _bootstrap_require("Yso._entry", reload)
end

local function _bootstrap_require_any(mods, reload)
  local last_err = nil
  for i = 1, #(mods or {}) do
    local _, ok, err = _bootstrap_require(mods[i], reload)
    if ok then return true, mods[i] end
    last_err = err
  end
  return false, nil, last_err
end

Yso.bootstrap.package_missing_order = Yso.bootstrap.package_missing_order or {
  {
    name = "self_aff",
    modules = { "Yso.Core.self_aff", "Yso.xml.yso_self_aff" },
    probe = function()
      return type((((_G.Yso or {}).selfaff or {})).has_aff) == "function"
    end,
  },
  {
    name = "self_curedefs",
    modules = { "Yso.Curing.self_curedefs", "Yso.xml.yso_self_curedefs" },
    probe = function()
      return type(((((_G.Yso or {}).curing or {}).defs or {})).get) == "function"
    end,
  },
  {
    name = "serverside_policy",
    modules = { "Yso.Curing.serverside_policy", "Yso.xml.yso_serverside_policy" },
    probe = function()
      return type(((((_G.Yso or {}).curing or {}).policy or {})).tick) == "function"
    end,
  },
  {
    name = "route_registry",
    modules = { "Yso.Combat.route_registry", "Yso.xml.route_registry" },
    probe = function()
      return type((((_G.Yso or {}).Combat or {}).RouteRegistry)) == "table"
    end,
  },
  {
    name = "offense_core",
    modules = { "Yso.Combat.offense_core", "Yso.xml.yso_offense_coordination" },
    probe = function()
      return type((((_G.Yso or {}).off or {}).core)) == "table"
    end,
  },
  {
    name = "modes",
    modules = { "Yso.Core.modes", "Yso.xml.yso_modes" },
    probe = function()
      local mode = ((_G.Yso or {}).mode or {})
      return type(mode.toggle_route_loop) == "function"
         and type(mode.start_route_loop) == "function"
         and type(mode.stop_route_loop) == "function"
    end,
  },
  {
    name = "route_interface",
    modules = { "Yso.Combat.route_interface" },
    probe = function()
      return type((((_G.Yso or {}).Combat or {}).RouteInterface)) == "table"
    end,
  },
  {
    name = "predict_cure",
    modules = { "Yso.Core.predict_cure", "Yso.xml.yso_predict_cure" },
    probe = function()
      return type((((_G.Yso or {}).predict or {}).cure)) == "table"
    end,
  },
  {
    name = "targeting",
    modules = { "Yso.xml.yso_targeting", "Yso.xml.yso_target" },
    probe = function()
      local targeting = ((_G.Yso or {}).targeting or {})
      return type(targeting.get) == "function"
         and (type(targeting.set) == "function" or type(targeting.set_target) == "function")
    end,
  },
}

local function _bootstrap_package_runtime_seeded()
  return type(Yso) == "table" and (
    type(Yso.off) == "table" or
    type(Yso.queue) == "table" or
    type(Yso.mode) == "table"
  )
end

local function _bootstrap_load_missing(reload)
  local loaded = {}
  local failed = {}
  local items = Yso.bootstrap.package_missing_order or {}

  for i = 1, #items do
    local item = items[i]
    local probe = type(item.probe) == "function" and item.probe() == true
    if not probe then
      local ok, _, err = _bootstrap_require_any(item.modules, reload)
      local now_ok = type(item.probe) == "function" and item.probe() == true
      if ok and now_ok then
        loaded[#loaded + 1] = tostring(item.name or item.modules[1] or ("slot_" .. i))
      else
        failed[#failed + 1] = {
          name = tostring(item.name or item.modules[1] or ("slot_" .. i)),
          error = tostring(err or "load failed"),
        }
      end
    end
  end

  Yso.bootstrap.missing_autoloaded = loaded
  Yso.bootstrap.missing_autoload_failures = failed
  return (#failed == 0), loaded, failed
end

Yso.bootstrap.require = _bootstrap_require
Yso.bootstrap.entry = _bootstrap_entry

local function _bootstrap_finish_autoload()
  if _bootstrap_package_runtime_seeded() then
    local ok, _, failed = _bootstrap_load_missing(false)
    Yso.bootstrap.entry_autoloaded = (ok == true)
    if ok then
      Yso.bootstrap.entry_autoload_error = nil
    else
      local names = {}
      for i = 1, #failed do names[#names + 1] = failed[i].name end
      Yso.bootstrap.entry_autoload_error = "missing-module autoload failed: " .. table.concat(names, ", ")
    end
    return
  end

  local _, ok, err = _bootstrap_entry(false)
  Yso.bootstrap.entry_autoloaded = (ok == true)
  Yso.bootstrap.entry_autoload_error = ok and nil or err
end

local function _bootstrap_auto_entry()
  if rawget(_G, "yso_bootstrap_entry_attempted") then return end
  _G.yso_bootstrap_entry_attempted = true
  if type(tempTimer) == "function" then
    tempTimer(0, function()
      local ok, err = pcall(_bootstrap_finish_autoload)
      if not ok then
        Yso.bootstrap.entry_autoloaded = false
        Yso.bootstrap.entry_autoload_error = err
      end
    end)
    return
  end

  local ok, err = pcall(_bootstrap_finish_autoload)
  if not ok then
    Yso.bootstrap.entry_autoloaded = false
    Yso.bootstrap.entry_autoload_error = err
  end
end

Yso.bootstrap.auto_entry = _bootstrap_auto_entry
_bootstrap_auto_entry()

return Yso.bootstrap
