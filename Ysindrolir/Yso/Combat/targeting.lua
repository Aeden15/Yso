-- Wrapper: expose Yso.targeting when the targeting subsystem is loaded.
local Yso = require("Yso")
if type(Yso.targeting) ~= "table" then
  error("Yso.Combat.targeting: Yso.targeting not loaded yet", 2)
end
return Yso.targeting
