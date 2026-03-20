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
  "Yso.Integration.ak_legacy_wiring",
  "Yso.Core.queue",
  "Yso.Core.wake_bus",
  "Yso.Combat.route_registry",
  "Yso.Combat.route_interface",
  "Yso.Combat.parry",
  "Yso.Combat.offense_driver",
  "Yso.Core.orchestrator",
  "Yso.Combat.occultist.entity_registry",
  "Yso.xml.yso_occultist_affmap",
  "Yso.Combat.occultist.aeon",
  "Yso.Combat.routes.group_damage",
  "Yso.Combat.routes.occ_aff_burst",
  "Yso.Combat.routes.party_aff",
  "Yso.Combat.occultist.offense_helpers",
  "Yso.Core.target_intel",
  "Yso.xml.yso_target_tattoos",
  "Yso.Combat.occultist.softlock_gate",
  "Yso.xml.curebuckets",
  "Yso.xml.yso_list_of_functions",
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
  return (((_G.Yso or {}).off or {}).oc or {}).occ_aff_burst
end

Yso.bootstrap.require = _bootstrap_require
Yso.bootstrap.entry = _bootstrap_entry
Yso.bootstrap.occ_aff_burst = _bootstrap_occ_aff

local function _bootstrap_auto_entry()
  if rawget(_G, "yso_bootstrap_entry_attempted") then return end
  _G.yso_bootstrap_entry_attempted = true
  local _, ok, err = _bootstrap_entry(false)
  Yso.bootstrap.entry_autoloaded = (ok == true)
  Yso.bootstrap.entry_autoload_error = ok and nil or err
end

Yso.bootstrap.auto_entry = _bootstrap_auto_entry
_bootstrap_auto_entry()

return Yso.bootstrap
