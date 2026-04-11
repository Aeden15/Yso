XML EXPORT MIRROR — DO NOT TREAT AS CANONICAL SOURCE

Canonical hand-edited source for the Yso system now lives in the modular Lua tree.
The matching files in this xml/ directory are export mirrors/staging copies.
Edit the canonical source first, then refresh the xml mirrors before rebuilding Yso system.xml.

Canonical source locations (edit these):

  Core infrastructure:
  - modules/Yso/Core/api.lua                              -> xml/api_stuff.lua
  - modules/Yso/Core/self_aff.lua                         -> xml/yso_self_aff.lua
  - modules/Yso/Core/offense_state.lua                    -> xml/yso_offense_state.lua
  - modules/Yso/Core/wake_bus.lua                         -> xml/yso_pulse_wake_bus.lua
  - modules/Yso/Core/queue.lua                            -> xml/yso_queue.lua
  - modules/Yso/Core/bootstrap.lua                        -> xml/bootstrap.lua
  - modules/Yso/Core/modes.lua                            -> xml/yso_modes.lua
  - modules/Yso/Core/mode_autoswitch.lua                  -> xml/yso_mode_autoswitch.lua
  - modules/Yso/Core/target_intel.lua                     -> xml/yso_target_intel.lua
  - modules/Yso/Core/predict_cure.lua                     -> xml/yso_predict_cure.lua

  Combat system:
  - modules/Yso/Combat/offense_driver.lua                 -> xml/yso_offense_coordination.lua
  - modules/Yso/Combat/parry.lua                          -> xml/parry.lua
  - modules/Yso/Combat/route_interface.lua                -> xml/route_interface.lua
  - modules/Yso/Combat/route_registry.lua                 -> xml/route_registry.lua

  Combat routes:
  - modules/Yso/Combat/routes/group_damage.lua            -> xml/group_damage.lua
  - modules/Yso/Combat/routes/occ_aff.lua                 -> xml/occ_aff.lua
  - modules/Yso/Combat/routes/party_aff.lua               -> xml/party_aff.lua

  Occultist offense:
  - modules/Yso/Combat/occultist/offense_helpers.lua      -> xml/yso_occultist_offense.lua
  - modules/Yso/Combat/occultist/entity_registry.lua      -> xml/entity_registry.lua
  - modules/Yso/Combat/occultist/aeon.lua                 -> xml/yso_aeon.lua
  - modules/Yso/Combat/occultist/softlock_gate.lua        -> xml/softlock_gate.lua

  Curing:
  - modules/Yso/Curing/bash_vitals_swap.lua               -> xml/bash_vitals_swap.lua
  - modules/Yso/Curing/self_curedefs.lua                  -> xml/yso_self_curedefs.lua
  - modules/Yso/Curing/serverside_policy.lua              -> xml/yso_serverside_policy.lua

  Integration / bridges:
  - modules/Yso/Integration/ak_legacy_wiring.lua          -> xml/ak_legacy_wiring.lua

Files in xml/ not listed above remain XML-resident legacy until migrated.
See EXPORT_MANIFEST.lua for the machine-readable mapping.

Rebuild notes (2026-04-11):

  rebuild_yso_system_xml.lua only rewrites package items that actually exist in
  mudlet packages/Yso system.xml.
  It now validates the candidate XML before writing so a failed regex match
  does not corrupt the package artifact on disk.
  rebuild_yso_system_xml.ps1 is now only a compatibility wrapper that calls
  the Lua builder.

  Legacy-name package slots currently handled by the rebuild script:
  - xml/yso_ak_score_exports.lua -> package name "Yso_AK_Score_Exports.lua"
  - xml/yso_mode_autoswitch.lua  -> package name "Yso_mode_autoswitch.lua"
  - xml/yso_modes.lua            -> package name "Yso_modes.lua"
  - xml/yso_occultist_affmap.lua -> package name "Yso_Occultist_Affmap.lua"
  - xml/yso_offense_coordination.lua
      -> package name "Yso_Offense_Coordination.lua"
  - xml/softlock_gate.lua         -> package name "Softlock Gate"
  - xml/yso_queue.lua             -> package name "Yso.queue"
  - xml/yso_occultist_offense.lua -> package name "Yso.occ.offense"
  - xml/yso_targeting.lua         -> package name "Yso.targeting"
  - exported title lines are normalized for CRLF/BOM before name matching
  - xml/hunt_primebond_shieldbreak_selector.lua
      package item exists, but the stored Mudlet name is mojibake; rebuild now
      matches it by body signature instead of by <name>.

  Active files that intentionally have no dedicated script slot in
  Yso system.xml and therefore report as no-slot rather than skipped:
  - xml/party_aff.lua
  - xml/route_interface.lua
  - xml/route_registry.lua
  - xml/skillset_reference_chart.lua
  - xml/yso_aeon.lua
  - xml/yso_predict_cure.lua

  Deleted as obsolete during the 2026-03-16 audit:
  - xml/magi_convergence.lua
  - xml/magi_resonance.lua
  - xml/yso_route_registry.lua
