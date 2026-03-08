--========================================================--
-- Auto-fixed wrapper
--  • Prevents self-require recursion from corrupted generator output.
--  • Ensures disk-workspace loader runs, then returns the requested namespace (best-effort).
--========================================================--

local Yso = require("Yso")
local v = Yso.state
return v or Yso
