-- Canonical driver and coordination logic lives in Yso/xml/yso_offense_coordination.lua.
-- Keep this shim so existing require("Yso.Combat.offense_driver") callers keep
-- working even when the test harness package.path does not expose Yso.xml.*.

local ok, mod = pcall(require, "Yso.xml.yso_offense_coordination")
if ok then
  return mod
end

error(mod, 2)
