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
