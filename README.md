# Yso systems status - April 24, 2026

Supported classes are now **Magi** and **Alchemist**, plus shared/generic Yso core.

The old unsupported class stack was intentionally purged from this workspace and
from the Mudlet package XML. Its routes, aura/truename/read-aura handling,
card-based self-cleanse support, class entities, and class-specific Devtools
surfaces were removed.

Kept:

- Shared Yso core, curing, queue, route framework, target helpers, AK/Legacy
  integration, and class-neutral utility modules.
- Magi route/core/vibe/focus/group-damage support.
- Alchemist physiology/formulation/duel/group-damage support.
- A neutral `Yso.entities` API for future class-neutral pet support, including
  Alchemist homunculus integration later.

Tests and rebuilds:

- Magi, Alchemist, and shared/generic tests were moved to
  `Ysindrolir/Yso/Tests and rebuilds/`.
- Class-specific purged tests and rebuild tools were deleted rather than
  archived.

Devtools:

- Devtools entity/class-lane testing commands were intentionally removed for now.
- Remaining Devtools aliases are limited to generic lane/queue/payload helpers,
  Magi/Alchemist-safe test hooks, and generic route debug surfaces.

Package XML:

- `Ysindrolir/mudlet packages/Yso system.xml` was scrubbed so it no longer embeds
  executable support for the removed class stack.
- `Ysindrolir/mudlet packages/YsoDevtools.xml` was reduced to generic/Magi/
  Alchemist-safe commands.

## Patch Notes (May 1, 2026)

- Added plain `QUEUE ADD` support to `Yso.queue` for configurable class-combo
  sends while preserving `ADDCLEARFULL` instant-kill behavior.
- Alchemist temper pressure now folds into one class payload with
  `evaluate <target> humours`, `educe`, and `wrack/truewrack` chained after the
  initial temper command.
- The live Physiology evaluate-count trigger colourizes humour count lines while
  preserving existing state tracking.

## Patch Notes (April 24, 2026)

- Fixed module resolution in `Yso/_entry.lua` death-helper shim to load
  `Yso.Integration.mudlet` first, with a legacy fallback to `Integration.mudlet`.
  This resolves Mudlet runtime errors where `module 'Integration.mudlet' not found`
  could break trigger callbacks.

## Patch Notes (April 25, 2026)

- Restored route-loop controller loading through `Yso.Core.modes`/`Yso.xml.yso_modes`
  and added route bootstrap autoload in `Yso system.xml`.
- Gated automatic `team`/`teamroute` temp alias installation in modes (default off),
  while keeping backend party-route state and route ownership behavior intact.
- Added explicit Magi route aliases (`mdam`, `mfocus`, `mgd`) and added `mgd` to the
  route registry alias map.
- Updated bootstrap root detection for current `Ysindrolir` layout paths.
- Ensured Alchemist duel route and Magi route modules load in defined dependency order.
- Expanded `Yso.Integration.mudlet` with class-neutral target-intel handlers used by
  XML/AK trigger integrations.
- Kept `oc_isCurrentTarget` as a compatibility shim routed through
  `Yso.is_current_target`.
- Fixed malformed alias script tails in `Yso system.xml` (`adam`, `aduel`, `mdam`,
  `mfocus`, `mgd`) where a stray `else` block existed outside the `<script>` tag.
  This restores valid XML parsing and prevents route-toggle alias bodies from
  loading in a broken state.
- Fixed bootstrap missing-module autoload to explicitly include `offense_core`
  probes/loads (`Yso.Core.bootstrap` and `Yso.xml.bootstrap`), preventing states
  where route aliases run before `Yso.off.core` is present.

## Patch Notes (April 25, 2026 - Route Toggle + Stability Sweep)

- Fixed route-toggle alias handling in `Yso system.xml` (`adam`, `aduel`, `mdam`,
  `mfocus`, `mgd`) so toggle results are unwrapped correctly from `pcall` and
  failures now echo an actionable reason instead of silently no-oping.
- Removed duplicate runtime `mdam`/`mfocus`/`mgd` tempAlias registration from
  `Yso/xml/yso_modes.lua` to prevent double-fire (toggle-on then immediate off)
  when package aliases are present.
- Canonicalized mode/driver entry points:
  - `Yso/Core/modes.lua` is now a shim to `Yso/xml/yso_modes.lua`.
  - `Yso/Combat/offense_driver.lua` is now a shim to
    `Yso/xml/yso_offense_coordination.lua`.
- Removed fragile Alchemist group-damage toggle compatibility shim and cleaned
  party-route checks in `Alchemist/Core/group damage.lua`.
- Improved Alchemist physiology correctness:
  - `can_aurify` now supports configurable HP/MP thresholds and optional
    both-stat requirement.
  - `pick_temper_humour` no longer wastes a temper on hardcoded fallback when
    no desired aff is missing.
  - `build_truewrack` now emits debug reason when no legal filler humour exists.
- Removed unreachable `"aduel"` branch from duel-route active-id guard in
  `Alchemist/Core/duel route.lua`.
- Hardened parry runtime:
  - Deduplicates anonymous event handlers on reload.
  - Uses explicit command-to-limb reverse mapping in `note_sent`.
- Hardened `Yso/Combat/targeting.lua` wrapper to fail loudly if
  `Yso.targeting` is unavailable instead of returning the whole Yso root.
- Added reserved-phial policy validation hook on phiallist updates and session
  reconnect in `Alchemist/Core/formulation.lua`.
- Clarified intent in formulation build helper naming/comment
  (`_upper_words` -> `_upper`).
- Documented bootstrap’s username-specific fallback paths as local workspace
  fallbacks in `Yso/Core/bootstrap.lua`.

## Patch Notes (April 25, 2026 - Bootstrap Loader Ordering)

- Added a new Core script entry in `Ysindrolir/mudlet packages/Yso system.xml`
  named `Yso Bootstrap loader`, placed directly above `Route chassis loader`.
- `Yso Bootstrap loader` now discovers and runs bootstrap via `dofile` before
  the require-based route chassis loader, so `package.path` is initialized
  early in inline XML script contexts.
- Extended the loader's post-bootstrap require chain to explicitly include both
  Alchemist and Magi route modules:
  - `alchemist_group_damage`, `alchemist_duel_route`
  - `magi_route_core`, `magi_reference`, `magi_dissonance`,
    `magi_group_damage`, `magi_focus`, `Magi_duel_dam`
- Added boot status echo output that confirms route controller availability and
  both Alchemist/Magi route tables after bootstrap.

## Patch Notes (May 1, 2026 - Instant-Kill Queue Priority)

- Added `queue_verb = "addclearfull"` support to `Yso.queue` commits so route
  execute windows can clear all queued work before installing the finisher.
- Updated Alchemist Aurify/Reave and Magi Destroy execute paths to request
  `QUEUE ADDCLEARFULL`, with execute payloads dropping bootstrap sidecars once
  the kill window is selected.
- Refreshed the XML mirror/package copies for the affected queue and Alchemist
  scripts, and updated focused regression coverage for clearfull behavior.

## Patch Notes (April 25, 2026 - Diagnostic XML Resync)

- Synced `Ysindrolir/Yso/Core/queue.lua` into both:
  - `Ysindrolir/Yso/xml/yso_queue.lua`
  - `Ysindrolir/mudlet packages/Yso system.xml` -> script `Yso.queue`
- Re-exported updated scripts into `Ysindrolir/mudlet packages/Yso system.xml`:
  - `Yso.targeting` from `Ysindrolir/Yso/xml/yso_targeting.lua`
  - `Parry Module` from `Ysindrolir/Yso/Combat/parry.lua`
  - `Yso Bootstrap loader` from `Ysindrolir/Yso/xml/yso_bootstrap_loader.lua`
- Added a fresh diagnostic run report at `Yso_diagnostic_report.txt` with:
  - all targeted drift checks passing,
  - `luac` parse clean on all `Ysindrolir` Lua files,
  - and all tests in `Ysindrolir/Yso/Tests and rebuilds/` passing.

## Patch Notes (April 25, 2026 - Diagnostic Report Correction)

- Corrected `Yso_diagnostic_report.txt` to remove stale false emergency text.
- Verified current on-disk state is healthy:
  - `Yso system.xml` is well-formed and complete (not truncated),
  - `AK.xml` contains zero null-byte corruption,
  - both files end with valid `</MudletPackage>` closing tags.

## Patch Notes (April 25, 2026 - XML Empty-Tag Normalization)

- Normalized whitespace-only empty tags in `Ysindrolir/mudlet packages/Yso system.xml`
  back to truly empty tags to avoid Mudlet command-field spacing side effects:
  - `<mCommand>   </mCommand>` -> `<mCommand></mCommand>`
  - `<command>    </command>` -> `<command></command>`
  - `<packageName>...</packageName>` empty blocks compacted
  - `<script>...</script>` empty blocks compacted

## Patch Notes (April 26, 2026 - Alchemist Lane Payload Rework)

- Reworked Alchemist routes to use lane-combo payload builders (`free/eq/class/bal`)
  with explicit `direct_order` output for non-queue mode.
- Updated `Alchemist/Core/group damage.lua`, `Alchemist/Core/duel route.lua`, and
  `Alchemist/Aurify route.lua` to a shared lifecycle contract surface:
  `start/stop/is_active/build_payload/attack_function/evaluate/explain` and alias-loop hooks.
- Added real Aurify route wiring:
  - new loader shim `Alchemist/alchemist_aurify_route.lua`
  - new route id `alchemist_aurify_route`
  - new alias `bleed`
- Updated route registries (`Yso/Combat/route_registry.lua` and XML mirror),
  bootstrap module loading, and `_entry.lua` requires for the new Aurify route.
- Shieldbreak is now an EQ slot (`educe copper <target>`) that can still include
  legal class/bal follow-up in the same payload.
- Added Alchemist staged humour helpers and inundate math/state support in
  `Alchemist/Core/physiology.lua`, including `clear_all_humours` on inundate send/success.
- Updated queue class-lane readiness in both canonical and XML queue modules so
  Alchemist class lane checks humour/class readiness before generic entity readiness.
- Added inundate success parsing to physiology trigger handling and preserved the
  existing humour-ready line handling.
- Expanded/rewrote Alchemist route tests and added
  `Ysindrolir/Yso/Tests and rebuilds/test_alchemist_aurify_route.lua`.

## Patch Notes (April 27, 2026 - Alchemist Evaluate/Target-Swap Stall Recovery)

- Fixed Alchemist evaluate-normal handling so
  `"His/Her/Their/... humours are all at normal levels."` is treated as a
  full trusted evaluate result:
  - all four humours set to `0`,
  - evaluate marked complete/clean,
  - staged evaluate commands cleared,
  - affected route loops nudged immediately.
- Added hard evaluate gates in both Alchemist routes:
  - `Alchemist/Core/group damage.lua`
  - `Alchemist/Core/duel route.lua`
  Routes now hold with explicit reasons (`evaluate_pending`,
  `evaluate_not_ready`) instead of falling through into humour-dependent plans.
- Added shared pending class-action recovery in
  `Alchemist/Core/physiology.lua` for temper confirmation tracking:
  - send-time temper creates short-lived pending state,
  - humour counts increment only on confirmed temper success line,
  - missing confirmation clears pending with timeout recovery
    (`temper_sent_no_confirm_timeout`) and loop wake.
- Added route lifecycle hooks for both Alchemist routes:
  `on_target_swap`, `on_manual_success`, `on_send_result`, plus hold/explain
  updates (`temper_pending`, `target_swap_clear`, `route_inactive`, etc.).
- Target swap now clears stale staged/pending state and resets per-target
  homunculus attack guards so the new target can re-bootstrap cleanly.
- Updated physiology trigger script
  (`Alchemist/Triggers/Alchemy/Physiology/humour_balance.lua`) to wire
  evaluate-normal to physiology finalize helpers and wake routes on key state
  transitions.
- Added/expanded regression tests:
  - `Yso/Tests and rebuilds/test_alchemist_group_damage.lua`
  - `Yso/Tests and rebuilds/test_alchemist_duel_route.lua`

## Patch Notes (April 27, 2026 - Alchemist Homunculus Corrupt Parser Fix)

- Fixed invalid Lua pattern usage in
  `Alchemist/Triggers/Alchemy/Physiology/humour_balance.lua` for homunculus
  corrupt target parsing.
- Replaced the broken fallback match with valid Lua possessive-target patterns
  so lines like `Target's body, corrupting ...` and `Target' body, corrupting ...`
  parse the correct target instead of silently falling back to current target.
- Synced the same parser update into embedded
  `Ysindrolir/mudlet packages/Yso system.xml` to keep package/runtime parity.
- Added regression coverage in
  `Ysindrolir/Yso/Tests and rebuilds/test_alchemist_group_damage.lua` for
  possessive homunculus-corrupt line handling.
- Left `Legacy V2.1.xml` empty `Dor` script container unchanged on purpose in
  this pass (documented observation only, no structural cleanup).

## Patch Notes (April 28, 2026 - Alchemist Route Reset Repair)

- Added shared reset/cleanup hooks across Alchemist group damage, duel, and
  Aurify routes so start/stop, target swap, target clear/slain, and AK reset
  events clear stale route-local state without forcibly disabling active routes.
- Added the missing humour-balance failure trigger and made the failure line
  actively mark humour balance unavailable, clear pending/staged class state,
  and clear the server class queue.
- Corrected generic queue lane inference so `wrack` and `truewrack` stage on
  BAL while `educe iron` remains EQ.
- Added target-slain and AK `Reset Success!` bridge triggers in `Yso system.xml`,
  plus a direct AK reset hook in `AK.xml` for reliable cleanup when AK prints
  its reset confirmation.
- Baseline capture now skips override curesets `group`, `hunt`, and `burst`
  with one non-warning info echo instead of repeated Legacy warning spam.

## Patch Notes (April 28, 2026 - Reset Cleanup Output Tightening)

- Removed live server `CLEARQUEUE` sends from Alchemist structural reset paths
  used by target swap, target clear/slain, route start reset, and AK reset.
- Reset cleanup still clears Yso staged/owned queue state, lane dispatch
  debounce, pending class state, evaluate state, and route-local homunculus
  guards.
- Kept the humour-cooldown failure handler's class `CLEARQUEUE` because that
  is an actual failed class-action recovery path rather than a structural reset.
- Guarded AK's `HomunGerminated` trigger so it no longer errors when `wsys`
  is not loaded.
