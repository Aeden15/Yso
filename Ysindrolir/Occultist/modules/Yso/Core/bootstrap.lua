--========================================================--
-- Yso bootstrap
--  • Locates the workspace root and extends package.path.
--  • Exposes a small bootstrap API for route/module reloads.
--========================================================--

_G.yso_default_package_path = _G.yso_default_package_path or package.path
if _G.yso_bootstrap_done then
  local root = rawget(_G, "Yso") or rawget(_G, "yso")
  return type(root) == "table" and root.bootstrap or true
end

local function _pick_root(...)
  local cand = { ... }
  for i = 1, #cand do
    local p = tostring(cand[i] or "")
    if p ~= "" and type(lfs) == "table" and type(lfs.attributes) == "function" then
      local a = lfs.attributes(p)
      if a and a.mode == "directory" then return p end
    end
  end
  return tostring(cand[1] or "")
end

local function _auto_roots()
  local out = {}
  if type(_G.YSO_ROOT) == "string" and _G.YSO_ROOT ~= "" then out[#out+1] = _G.YSO_ROOT end
  if type(_G.yso_root) == "string" and _G.yso_root ~= "" then out[#out+1] = _G.yso_root end

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
      home .. "/Desktop/Yso systems/Ysindrolir/Occultist/modules",
      home .. "/Desktop/Yso systems/Ysindrolir/modules",
      home .. "/OneDrive/Desktop/Yso systems/Ysindrolir/Occultist/modules",
      home .. "/OneDrive/Desktop/Yso systems/Ysindrolir/modules",
    }
    for i = 1, #extra do out[#out+1] = extra[i] end
  end

  return out
end

local _auto = _auto_roots()
local root = _pick_root(
  _auto[1], _auto[2], _auto[3], _auto[4], _auto[5], _auto[6], _auto[7],
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

  local sibling = root:gsub("/Occultist/modules$", "")
  if sibling ~= root then
    _pp(sibling .. "/Magi/?.lua")
  end
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
  "Yso.Combat.route_interface",
  "Yso.Combat.hinder",
  "Yso.Combat.entities",
  "Yso.Combat.route_gate",
  "Yso.Combat.parry",
  "Yso.Combat.offense_driver",
  "Yso.Combat.occultist.entity_registry",
  "Yso.Combat.occultist.companions",
  "Yso.xml.yso_occultist_affmap",
  "Yso.Combat.occultist.aeon",
  "Yso.Combat.routes.group_damage",
  "Yso.Combat.routes.occ_aff",
  "Yso.Combat.routes.party_aff",
  "Yso.Combat.occultist.offense_helpers",
  "Yso.Core.target_intel",
  "Yso.xml.yso_target_tattoos",
  "Yso.Combat.occultist.softlock_gate",
  "Yso.xml.curebuckets",
  "Yso.Core.predict_cure",
  "Yso.Core.modes",
  "Yso.Core.mode_autoswitch",
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

local function _bootstrap_occ_aff(reload)
  _bootstrap_entry(reload)
  local order = Yso.bootstrap.core_order or {}
  for i = 1, #order do _bootstrap_require(order[i], reload) end
  local OC = ((_G.Yso or {}).off or {}).oc or {}
  return OC.occ_aff or OC.occ_aff_burst
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
    name = "route_interface",
    modules = { "Yso.Combat.route_interface" },
    probe = function()
      return type((((_G.Yso or {}).Combat or {}).RouteInterface)) == "table"
    end,
  },
  {
    name = "occultist_companions",
    modules = { "Yso.Combat.occultist.companions", "Yso.xml.yso_occultist_companions" },
    probe = function()
      return type((((_G.Yso or {}).occ or {}).companions)) == "table"
    end,
  },
  {
    name = "aeon",
    modules = { "Yso.Combat.occultist.aeon", "Yso.xml.yso_aeon" },
    probe = function()
      return type((((_G.Yso or {}).occ or {}).aeon)) == "table"
    end,
  },
  {
    name = "party_aff",
    modules = { "Yso.Combat.routes.party_aff" },
    probe = function()
      return type((((_G.Yso or {}).off or {}).oc or {}).party_aff) == "table"
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
  {
    name = "primebond_selector",
    modules = { "Yso.xml.hunt.shieldbreak" },
    probe = function()
      return type((((_G.Yso or {}).primebond or {}).request)) == "function"
    end,
  },
  {
    name = "skillset_reference_chart",
    modules = { "Yso.xml.skillset_reference_chart" },
    probe = function()
      return type((((_G.Yso or {}).occultist or {}).build_affcap)) == "function"
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
Yso.bootstrap.occ_aff = _bootstrap_occ_aff
Yso.bootstrap.occ_aff_burst = _bootstrap_occ_aff

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
