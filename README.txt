Yso systems status - April 24, 2026

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

Patch Notes (April 25, 2026 - Diagnostic XML Resync):
- Synced Ysindrolir/Yso/Core/queue.lua into both:
  - Ysindrolir/Yso/xml/yso_queue.lua
  - Ysindrolir/mudlet packages/Yso system.xml -> script "Yso.queue"
- Re-exported updated scripts into Ysindrolir/mudlet packages/Yso system.xml:
  - Yso.targeting from Ysindrolir/Yso/xml/yso_targeting.lua
  - Parry Module from Ysindrolir/Yso/Combat/parry.lua
  - Yso Bootstrap loader from Ysindrolir/Yso/xml/yso_bootstrap_loader.lua
- Added a fresh diagnostic run report at Yso_diagnostic_report.txt with:
  - all targeted drift checks passing,
  - luac parse clean on all Ysindrolir Lua files,
  - and all tests in Ysindrolir/Yso/Tests and rebuilds/ passing.

Patch Notes (April 25, 2026 - Diagnostic Report Correction):
- Corrected Yso_diagnostic_report.txt to remove stale false emergency text.
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
