-- Auto-exported from Mudlet package script: Bootstrap
-- DO NOT EDIT IN XML; edit this file instead.

_G.yso_default_package_path = _G.yso_default_package_path or package.path
if _G.yso_bootstrap_done then return end

-- Prefer standalone workspace first, then fall back to older layouts.
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

-- Try to locate an exported Yso filesystem root dynamically.
local function _auto_roots()
  local out = {}
  -- Allow user override
  if type(_G.YSO_ROOT) == "string" and _G.YSO_ROOT ~= "" then out[#out+1] = _G.YSO_ROOT end
  if type(_G.yso_root) == "string" and _G.yso_root ~= "" then out[#out+1] = _G.yso_root end

  -- Mudlet home dir
  if type(getMudletHomeDir) == "function" then
    local mhome = tostring(getMudletHomeDir() or ""):gsub("\\","/"):gsub("/+$","")
    if mhome ~= "" then
      out[#out+1] = mhome .. "/Yso/modules"
      out[#out+1] = mhome .. "/Achaea/Yso/modules"
      out[#out+1] = mhome .. "/modules/Yso" -- some layouts
    end
  end

  return out
end

local _auto = _auto_roots()
local root = _pick_root(
  _auto[1], _auto[2], _auto[3],
  "C:/Yso/modules",
  "C:/Achaea/Yso/modules",
  "D:/Yso/modules",
  "D:/Achaea/Yso/modules"
)

root = tostring(root):gsub("\\","/"):gsub("/+$","")

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
end
-- Lua 5.1 / Mudlet compatibility: add package.searchpath if missing (Lua 5.2+ feature)
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
