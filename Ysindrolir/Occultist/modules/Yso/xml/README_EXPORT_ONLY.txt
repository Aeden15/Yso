XML EXPORT MIRROR — DO NOT TREAT AS CANONICAL SOURCE

Canonical hand-edited source for the promoted Occultist combat stack now lives in the modular Lua tree:
- modules/Yso/Core/orchestrator.lua
- modules/Yso/Core/wake_bus.lua
- modules/Yso/Combat/offense_driver.lua
- modules/Yso/Combat/occultist/domination_reference.lua
- modules/Yso/Combat/occultist/entity_registry.lua
- modules/Yso/Combat/occultist/offense_helpers.lua
- modules/Yso/Combat/routes/group_damage.lua
- modules/Yso/Combat/routes/occ_aff_burst.lua

The matching files in this xml/ directory are export mirrors/staging copies for Mudlet package refresh.
Edit the modular source first, then refresh the xml mirrors before rebuilding Yso system.xml.

Files not yet promoted remain legacy xml-resident until migrated.
