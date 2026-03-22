-- Occultist export manifest
-- Canonical source => xml mirror
return {
  -- Core infrastructure
  { source = "modules/Yso/Core/api.lua",              mirror = "modules/Yso/xml/api_stuff.lua" },
  { source = "modules/Yso/Core/offense_state.lua",    mirror = "modules/Yso/xml/yso_offense_state.lua" },
  { source = "modules/Yso/Core/wake_bus.lua",         mirror = "modules/Yso/xml/yso_pulse_wake_bus.lua" },
  { source = "modules/Yso/Core/queue.lua",            mirror = "modules/Yso/xml/yso_queue.lua" },
  { source = "modules/Yso/Core/bootstrap.lua",        mirror = "modules/Yso/xml/bootstrap.lua" },
  { source = "modules/Yso/Core/modes.lua",            mirror = "modules/Yso/xml/yso_modes.lua" },
  { source = "modules/Yso/Core/mode_autoswitch.lua",  mirror = "modules/Yso/xml/yso_mode_autoswitch.lua" },
  { source = "modules/Yso/Core/target_intel.lua",     mirror = "modules/Yso/xml/yso_target_intel.lua" },
  { source = "modules/Yso/Core/predict_cure.lua",     mirror = "modules/Yso/xml/yso_predict_cure.lua" },

  -- Combat system
  { source = "modules/Yso/Combat/offense_driver.lua",    mirror = "modules/Yso/xml/yso_offense_coordination.lua" },
  { source = "modules/Yso/Combat/parry.lua",             mirror = "modules/Yso/xml/parry.lua" },
  { source = "modules/Yso/Combat/route_interface.lua",   mirror = "modules/Yso/xml/route_interface.lua" },
  { source = "modules/Yso/Combat/route_registry.lua",    mirror = "modules/Yso/xml/route_registry.lua" },

  -- Occultist offense
  { source = "modules/Yso/Combat/routes/group_damage.lua",             mirror = "modules/Yso/xml/group_damage.lua" },
  { source = "modules/Yso/Combat/routes/occ_aff_burst.lua",            mirror = "modules/Yso/xml/occ_aff_burst.lua" },
  { source = "modules/Yso/Combat/routes/party_aff.lua",                mirror = "modules/Yso/xml/party_aff.lua" },
  { source = "modules/Yso/Combat/occultist/offense_helpers.lua",       mirror = "modules/Yso/xml/yso_occultist_offense.lua" },
  { source = "modules/Yso/Combat/occultist/entity_registry.lua",       mirror = "modules/Yso/xml/entity_registry.lua" },
  { source = "modules/Yso/Combat/occultist/domination_reference.lua",  mirror = "modules/Yso/xml/domination_reference.lua" },
  { source = "modules/Yso/Combat/occultist/aeon.lua",                  mirror = "modules/Yso/xml/yso_aeon.lua" },
  { source = "modules/Yso/Combat/occultist/softlock_gate.lua",         mirror = "modules/Yso/xml/softlock_gate.lua" },

  -- Integration / bridges
  { source = "modules/Yso/Integration/ak_legacy_wiring.lua", mirror = "modules/Yso/xml/ak_legacy_wiring.lua" },
}
