-- Canonical implementation lives in Yso/xml/yso_modes.lua.
-- Keep this shim so existing require("Yso.Core.modes") callers keep working
-- even in minimal test harnesses that do not expose Yso.xml.* on package.path.

local ok, mod = pcall(require, "Yso.xml.yso_modes")
if ok then
  return mod
end

local info = debug.getinfo(1, "S")
local source = info and info.source or ""
if source:sub(1, 1) == "@" then
  local dir = source:sub(2):match("^(.*)[/\\][^/\\]+$") or "."
  local xml_dir = dir:gsub("[/\\]Core$", "/xml")
  local rel = xml_dir .. "/yso_modes.lua"
  local ok_file, file_mod = pcall(dofile, rel)
  if ok_file then
    return file_mod
  end
end

error(mod, 2)
