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
