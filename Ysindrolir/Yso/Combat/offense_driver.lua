-- Canonical driver and coordination logic lives in Yso/xml/yso_offense_coordination.lua.
-- Keep this shim so existing require("Yso.Combat.offense_driver") callers keep
-- working even when the test harness package.path does not expose Yso.xml.*.

local ok, mod = pcall(require, "Yso.xml.yso_offense_coordination")
if ok then
  return mod
end

local info = debug.getinfo(1, "S")
local source = info and info.source or ""
if source:sub(1, 1) == "@" then
  local dir = source:sub(2):match("^(.*)[/\\][^/\\]+$") or "."
  local xml_dir = dir:gsub("[/\\]Combat$", "/xml")
  local rel = xml_dir .. "/yso_offense_coordination.lua"
  local ok_file, file_mod = pcall(dofile, rel)
  if ok_file then
    return file_mod
  end
end

error(mod, 2)
