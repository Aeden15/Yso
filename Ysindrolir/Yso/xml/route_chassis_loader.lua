-- Canonical copy for Mudlet script "Route chassis loader" in Yso system.xml.
-- Keep class requires in sync with Yso Bootstrap loader (yso_bootstrap_loader.lua).

Yso = Yso or {}
Yso.bootstrap = Yso.bootstrap or {}

if type(require) == "function" then
  pcall(require, "Yso.Core.bootstrap")
  pcall(require, "Yso.xml.bootstrap")
  pcall(require, "Yso.Combat.route_registry")
  pcall(require, "Yso.xml.route_registry")
  pcall(require, "Yso.Combat.route_interface")
  pcall(require, "Yso.xml.route_interface")
  pcall(require, "Yso.Core.modes")
  pcall(require, "Yso.xml.yso_modes")
  pcall(require, "Yso.Integration.mudlet")

  -- Alchemist routes
  pcall(require, "alchemist_group_damage")
  pcall(require, "alchemist_duel_route")
  pcall(require, "alchemist_aurify_route")

  -- Magi (same order as yso_bootstrap_loader.lua)
  pcall(require, "magi_route_core")
  pcall(require, "magi_reference")
  pcall(require, "magi_dissonance")
  pcall(require, "magi_vibes")
  pcall(require, "magi_focus")
  pcall(require, "magi_group_damage")
  pcall(require, "Magi_duel_dam")
end
