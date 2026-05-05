--========================================================--
-- Yso.state wiring (DEPRECATED)
--
-- NOTE:
--   GMCP Char.Vitals plumbing is now centralized in:
--
-- This stub remains only to kill any legacy handler IDs.
--========================================================--

Yso = Yso or {}
Yso._eh = Yso._eh or {}

if Yso._eh.vitals then
  pcall(killAnonymousEventHandler, Yso._eh.vitals)
  Yso._eh.vitals = nil
end
