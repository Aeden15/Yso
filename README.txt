Yso systems status - May 2, 2026

Supported classes are now Magi and Alchemist, plus shared/generic Yso core.

The old unsupported class stack was intentionally purged from this workspace and
from the Mudlet package XML. Its routes, aura/truename/read-aura handling,
card-based self-cleanse support, class entities, and class-specific Devtools
surfaces were removed.

Kept:
- Shared Yso core, curing, queue, route framework, target helpers, AK/Legacy
  integration, and class-neutral utility modules.
- Magi route/core/vibe/focus/group-damage support.
- Alchemist physiology/formulation/duel/group-damage support.
- A neutral Yso.entities API for future class-neutral pet support, including
  Alchemist homunculus integration later.

Tests and rebuilds:
- Magi, Alchemist, and shared/generic tests were moved to:
  Ysindrolir/Yso/Tests and rebuilds/
- Class-specific purged tests and rebuild tools were deleted rather than
  archived.

Devtools:
- Devtools entity/class-lane testing commands were intentionally removed for
  now.
- Remaining Devtools aliases are limited to generic lane/queue/payload helpers,
  Magi/Alchemist-safe test hooks, and generic route debug surfaces.

Package XML:
- Ysindrolir/mudlet packages/Yso system.xml was scrubbed so it no longer embeds
  executable support for the removed class stack.
- Ysindrolir/mudlet packages/YsoDevtools.xml was reduced to generic/Magi/
  Alchemist-safe commands.

Expected state:
- Magi and Alchemist remain functional.
- Shared Yso infrastructure remains intact.
- No active Lua or XML executable code should depend on the purged class stack.

Patch Notes (April 24, 2026):
- Fixed module resolution in Yso/_entry.lua death-helper shim to load
  Yso.Integration.mudlet first, with a legacy fallback to Integration.mudlet.
  This resolves Mudlet runtime errors where module 'Integration.mudlet' not found
  could break trigger callbacks.

Patch Notes (April 25, 2026):
- Restored route-loop controller loading through Yso.Core.modes/Yso.xml.yso_modes
  and added route bootstrap autoload in Yso system.xml.
- Gated automatic team/teamroute temp alias installation in modes (default off),
  while keeping backend party-route state and route ownership behavior intact.
- Added explicit Magi route aliases (mdam, mfocus, mgd) and added mgd to the
  route registry alias map.
- Updated bootstrap root detection for current Ysindrolir layout paths.
- Ensured Alchemist duel route and Magi route modules load in dependency order.
- Expanded Yso.Integration.mudlet with class-neutral target-intel handlers used by
  XML/AK trigger integrations.
- Kept oc_isCurrentTarget as a compatibility shim through Yso.is_current_target.

Patch Notes (April 25, 2026 - Route Toggle + Stability Sweep):
- Fixed route-toggle alias handling in Yso system.xml (adam, aduel, mdam,
  mfocus, mgd) so toggle results are unwrapped correctly from pcall and
  failures now echo a reason instead of silently no-oping.
- Removed duplicate runtime mdam/mfocus/mgd tempAlias registration from
  Yso/xml/yso_modes.lua to prevent double-fire when package aliases are present.
- Canonicalized mode/driver entry points:
  - Yso/Core/modes.lua now shims to Yso/xml/yso_modes.lua.
  - Yso/Combat/offense_driver.lua now shims to Yso/xml/yso_offense_coordination.lua.
- Removed fragile Alchemist group-damage toggle compatibility shim and cleaned
  party-route checks in Alchemist/Core/group damage.lua.
- Improved Alchemist physiology correctness:
  - can_aurify now supports configurable HP/MP thresholds and optional
    both-stat requirement.
  - pick_temper_humour no longer wastes a temper fallback when no desired aff is missing.
  - build_truewrack now logs debug context when no legal filler humour exists.
- Removed unreachable "aduel" branch from duel-route active-id guard in
  Alchemist/Core/duel route.lua.
- Hardened parry runtime:
  - Deduplicates anonymous event handlers on reload.
  - Uses explicit command-to-limb reverse mapping in note_sent.
- Hardened Yso/Combat/targeting.lua wrapper to error when Yso.targeting is not
  loaded, instead of returning the root Yso table.
- Added reserved-phial policy validation hook on phiallist updates and session
  reconnect in Alchemist/Core/formulation.lua.
- Clarified intent in formulation build helper naming/comment
  (_upper_words -> _upper).
- Documented bootstrap username-specific fallback paths as local workspace
  fallbacks in Yso/Core/bootstrap.lua.

Patch Notes (April 25, 2026 - Bootstrap Loader Ordering):
- Added a new Core script entry in Ysindrolir/mudlet packages/Yso system.xml
  named "Yso Bootstrap loader", placed directly above "Route chassis loader".
- Yso Bootstrap loader now discovers and runs bootstrap via dofile before the
  require-based route chassis loader, so package.path is initialized early in
  inline XML script contexts.
- Extended the loader's post-bootstrap require chain to include both Alchemist
  and Magi route modules:
  - alchemist_group_damage, alchemist_duel_route
  - magi_route_core, magi_reference, magi_dissonance, magi_group_damage,
    magi_focus, Magi_duel_dam
- Added boot status echo output that confirms route controller availability and
  both Alchemist/Magi route tables after bootstrap.

Patch Notes (May 1, 2026 - Instant-Kill Queue Priority):
- Added queue_verb = "addclearfull" support to Yso.queue commits so route
  execute windows can clear all queued work before installing the finisher.
- Updated Alchemist Aurify/Reave and Magi Destroy execute paths to request
  QUEUE ADDCLEARFULL, with execute payloads dropping bootstrap sidecars once
  the kill window is selected.
- Refreshed the XML mirror/package copies for the affected queue and Alchemist
  scripts, and updated focused regression coverage for clearfull behavior.

Patch Notes (May 2, 2026 - Duel Evaluate Gate Bug Check):
- Fixed Alchemist duel-route evaluate gating so dirty humour intel now fails
  closed with evaluate_not_ready when evaluate balance is unavailable.
- Revalidated workspace checks: Lua syntax pass, XML parse pass, and full
  Ysindrolir/Yso/Tests and rebuilds suite pass.
- Re-exported package script embeddings with
  Ysindrolir/scripts/export_yso_system_xml.ps1 and confirmed
  Ysindrolir/mudlet packages/Yso system.xml parse pass.

Patch Notes (May 2, 2026 - Wrack/Truewrack Slot Legality + Bleed Alias Removal):
- Updated shared Alchemist physiology wrack legality so explicit affliction args
  are legal even when their source humour is untempered.
- Humour keyword wrack args now require effective temper count >= 1 (including
  staged same-payload temper planning).
- Paralysis remains special and requires effective sanguine >= 2.
- Truewrack now validates each argument slot independently and supports mixed
  legal slots (for example, tempered humour keyword + explicit affliction).
- Updated Aurify wrack-pressure selection to use slot-legal arguments and avoid
  duplicate same-humour truewrack args when a mixed legal option exists.
- Removed the redundant ^bleed$ alias from Ysindrolir/mudlet packages/
  Yso system.xml and removed the matching bleed route registration shortcut.
- Added regression coverage in:
  - Ysindrolir/Yso/Tests and rebuilds/test_alchemist_group_damage.lua
  - Ysindrolir/Yso/Tests and rebuilds/test_alchemist_duel_route.lua
  - Ysindrolir/Yso/Tests and rebuilds/test_alchemist_aurify_route.lua

Patch Notes (April 25, 2026 - Diagnostic XML Resync):
- Synced Ysindrolir/Yso/Core/queue.lua into both:
  - Ysindrolir/Yso/xml/yso_queue.lua
  - Ysindrolir/mudlet packages/Yso system.xml -> script "Yso.queue"
- Re-exported updated scripts into Ysindrolir/mudlet packages/Yso system.xml:
  - Yso.targeting from Ysindrolir/Yso/xml/yso_targeting.lua
  - Parry Module from Ysindrolir/Yso/Combat/parry.lua
  - Yso Bootstrap loader from Ysindrolir/Yso/xml/yso_bootstrap_loader.lua
- Repeatable re-embed: Ysindrolir/scripts/export_yso_system_xml.ps1 (see comments in that script).

Patch Notes (April 25, 2026 - Diagnostic Report Correction):
- Verified current on-disk state is healthy:
  - Yso system.xml is well-formed and complete (not truncated),
  - AK.xml contains zero null-byte corruption,
  - both files end with valid </MudletPackage> closing tags.

Patch Notes (April 25, 2026 - XML Empty-Tag Normalization):
- Normalized whitespace-only empty tags in Ysindrolir/mudlet packages/Yso system.xml
  back to truly empty tags to avoid Mudlet command-field spacing side effects:
  - <mCommand>   </mCommand> -> <mCommand></mCommand>
  - <command>    </command> -> <command></command>
  - empty packageName blocks compacted
  - empty script blocks compacted

Patch Notes (April 28, 2026 - Alchemist Route Reset Repair):
- Added shared reset/cleanup hooks across Alchemist group damage, duel, and
  Aurify routes so start/stop, target swap, target clear/slain, and AK reset
  events clear stale route-local state without forcibly disabling active routes.
- Added the missing humour-balance failure trigger and made the failure line
  actively mark humour balance unavailable, clear pending/staged class state,
  and clear the server class queue.
- Corrected generic queue lane inference so wrack and truewrack stage on BAL
  while educe iron remains EQ.
- Added target-slain and AK Reset Success bridge triggers in Yso system.xml,
  plus a direct AK reset hook in AK.xml for reliable cleanup when AK prints
  its reset confirmation.
- Baseline capture now skips override curesets group, hunt, and burst with one
  non-warning info echo instead of repeated Legacy warning spam.
