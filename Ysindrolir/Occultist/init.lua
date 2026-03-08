--========================================================--
-- Yso/init.lua (disk-workspace bootstrap)
--  • This workspace zip is intended for editing in VS Code.
--  • Runtime package is Yso_FIXED.mpackage (Mudlet import).
--  • Default command separator uses Mudlet command separator style (&&).
--========================================================--
Yso = Yso or {}
Yso.cfg = Yso.cfg or {}
Yso.cfg.pipe_sep = Yso.cfg.pipe_sep or "&&"
Yso.cfg.cmd_sep  = Yso.cfg.cmd_sep  or Yso.cfg.pipe_sep or "&&"
return Yso
