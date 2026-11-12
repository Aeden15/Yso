# Airlord routes

`lock_route.lua` contains the basic AK lock decisions in one place. `alock`
still toggles `Yso.off.airlord.lock` through Yso's scheduler and uses its shared
target. The order is shield break, fresh confirmed Compression, then Pressure
when boosters overlap or one more level can open Compression. Otherwise the
route establishes missing Strangle, Zephyr, or Scour afflictions before falling
back to Tension and Pressure. Asphyxiate establishes smoke tracking before a
selected smoke attack.

`damage_route.lua` independently owns `aidam`, successive Buffets, balanceless
Assess, and optional Updraft. Buffet repeats while fresh pressure is at least
three and two of disloyalty, tension, manaleech, and deadening are confirmed.
When eligibility drops, the route clears its queued Buffet and resumes setup.
`alupdraft` toggles Updraft for the damage route.

`route_runtime.lua` supplies both routes with Yso balance/pause checks, Gauge
cadence, submission deduplication, confirmation timing, target/stop cleanup, and
feedback dispatch. Both routes use the AK target-aware relapse query when
available. AK's seven-second timeout expires missing feedback, while game
messages determine when ticks actually land.
`compression.lua` tracks only current-target Gauge observations, expires them
after three seconds, and permits Compression at pressure six. Loading a route
does not create its sibling. Reloading clears prior owned work and old strategy
hooks before replacing them.

The native package order is Compression logic, Airlord route runtime, Airlord
lock route, then Airlord damage route. The former combined Airlord attack logic
entry and `combat_routes.lua` have been retired. There are no runtime file loads.

Rebuild with `scripts/build_airlord_package.ps1`; it changes only these four
embedded scripts and the Updraft alias. Full export and the combat-pause builder
also maintain this layout. Run `scripts/test_airlord_lock_package.ps1`,
`scripts/test_airlord_damage_package.ps1`, and the combat-pause/export regressions.
After rebuilding, run `scripts/publish_workspace_link.ps1`. Apply the built XML
in Mudlet with `ysoreload` while automation is stopped. Automated checks do not
replace live-game verification.
