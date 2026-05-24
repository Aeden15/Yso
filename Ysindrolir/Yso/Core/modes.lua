-- Canonical implementation lives in Yso/xml/yso_modes.lua.
-- Keep this shim so existing require("Yso.Core.modes") callers keep working
-- even in minimal test harnesses that do not expose Yso.xml.* on package.path.

local ok, mod = pcall(require, "Yso.xml.yso_modes")
if ok then
  return mod
end

error(mod, 2)
