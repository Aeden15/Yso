# Combat paralysis contract

Every route registered with `mode = "combat"` inherits the shared scheduler gate. Paralysis keeps the route enabled, defers offensive startup, and skips waiting/attack callbacks. A canonical self-affliction cure nudges enabled loops to re-evaluate current target state. Manual stops, target changes, death, disconnect and class invalidation remain stops. Hunting and Legacy Basher are outside this policy.

Use `Yso.emit` / `Yso.emit_now` with `kind = "offense"` and the route id for every offensive payload, including free entity orders. Forced sends still obey the gate. Explicit cure, defense and utility payloads retain their existing paths. A direct sender must call `Yso.Combat.Pause.blocks_emission(payload, opts)` first.

Store command confirmation timestamps with `Yso.Combat.Pause.confirmation_now(route_id)` (or `RouteInterface.confirmation_now`). Compare against that same clock. It excludes self-paralysis time while retaining the remaining timeout budget. Game cooldowns, effect durations, observations and target affliction expiry use wall time.

Real confirmation handlers continue to run during a pause. Keep dispatched command ownership until real feedback resolves it. Optional legacy queue staging records route ownership; paralysis discards only that route's unsent offensive entries. Matching pending command records are released for replanning. Custom pending structures can implement `alias_loop_on_staged_discarded(removed)`; do not clear unrelated or already dispatched work. Interrupted channels must re-evaluate confirmed state instead of assuming completion.

The native package loads `Combat paralysis policy` after `Route registry`. `build_combat_pause_package.ps1` embeds the maintained sources and regenerates the Focus alias. Deliverance maintenance is separate in `build_deliverance_package.ps1`, and Airlord soar uses `build_airlord_soar_package.ps1`. The optional legacy queue and route-interface source mirrors remain compatible; the queue is not reintroduced into the native XML.

Run the three `test_combat_pause*.lua` suites plus the affected package suites after changing the shared contract. The registry suite includes a future combat route with no local paralysis checks.

Publish validated XMLs with `scripts/publish_workspace_link.ps1`. The Achaea profile's existing Workspace Link loads the resulting package on `ysoreload` while automation is idle.
