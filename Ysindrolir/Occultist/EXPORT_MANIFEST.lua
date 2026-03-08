-- Occultist export manifest
-- Canonical source => xml mirror
return {
  { source = "modules/Yso/Core/orchestrator.lua", mirror = "modules/Yso/xml/yso_orchestrator.lua" },
  { source = "modules/Yso/Core/wake_bus.lua", mirror = "modules/Yso/xml/yso_pulse_wake_bus.lua" },
  { source = "modules/Yso/Combat/route_interface.lua", mirror = "modules/Yso/xml/route_interface.lua" },
  { source = "modules/Yso/Combat/offense_driver.lua", mirror = "modules/Yso/xml/yso_offense_coordination.lua" },
  { source = "modules/Yso/Combat/occultist/entity_registry.lua", mirror = "modules/Yso/xml/entity_registry.lua" },
  { source = "modules/Yso/Combat/occultist/domination_reference.lua", mirror = "modules/Yso/xml/domination_reference.lua" },
  { source = "modules/Yso/Combat/routes/group_damage.lua", mirror = "modules/Yso/xml/group_damage.lua" },
  { source = "modules/Yso/Combat/routes/occ_aff_burst.lua", mirror = "modules/Yso/xml/occ_aff_burst.lua" },
  { source = "modules/Yso/Combat/occultist/offense_helpers.lua", mirror = "modules/Yso/xml/yso_occultist_offense.lua" },
}
