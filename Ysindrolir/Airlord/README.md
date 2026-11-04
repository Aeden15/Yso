# Airlord routes

`lock_route.lua` contains the basic AK lock decisions in one place. `alock`
still toggles `Yso.off.airlord.lock` through Yso's scheduler and uses its shared
target. The order is shield break, fresh confirmed Compression, missing Tension,
Pressure when boosters permit, then missing deadening/manaleech/disloyalty.
Asphyxiate establishes smoke tracking before setup; active relapses avoid
redundant affliction applications. Tension remains first and consecutive
immediate reapplications are interleaved with another attack.

`damage_route.lua` independently owns `aidam`, Buffet weaving, balanceless Assess,
and optional Updraft. `alupdraft` now toggles Updraft for damage only; the simple
lock has no Updraft behavior.

`route_runtime.lua` supplies both routes with Yso balance/pause checks, Gauge
cadence, submission deduplication, confirmation timing, target/stop cleanup, and
feedback dispatch. This plumbing stays outside the readable lock decisions.
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
