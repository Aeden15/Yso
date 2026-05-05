# Yso systems status — May 5, 2026

Supported classes are **Magi** and **Alchemist**, plus shared Yso core. Older class stacks were removed from this workspace and from the Mudlet package; do not treat removed classes as active automation paths.

## Mudlet workflow (package-first)

- **Canonical runtime:** Install/import the package under `Ysindrolir/mudlet packages/`, especially **`Yso system.xml`** (and `.mpackage` exports when you use them). Combat behavior comes from the embedded scripts and Mudlet’s script **load order**, not from ad-hoc filesystem loading.
- **Globals, not route `require`:** Later scripts assume **preloaded global tables** (`Yso`, route registries, class helpers, and so on). Do not activate routes via runtime **`require(...)`** / **`pcall(require, ...)`**, and do not add **`YSO_ROOT`**, **`package.path`**, or repo-root probing for route loading.
- **Operating:** Use the package **aliases** and toggles in Mudlet (for example Magi `mdam`, `mfocus`, `mgd`; Alchemist `adam`, `aduel`). Combat mode plus per-route toggles drive the offense loops; adjust behavior through the installed package’s triggers and aliases.
- **Repo vs package:** Lua under `Ysindrolir/Yso/` and `Ysindrolir/Alchemist/` is the git-side source tree. **`Ysindrolir/scripts/export_yso_system_xml.ps1`** is **optional** maintenance tooling to re-embed scripts into `Yso system.xml` when you work from a split layout — not a mandatory step for day-to-day play if you maintain scripts inside Mudlet.

Kept in tree:

- Shared Yso core, curing, queue, route framework, target helpers, AK/Legacy integration, and class-neutral utilities.
- Magi route/core/vibe/focus/group-damage support.
- Alchemist physiology/formulation/duel/group-damage/Aurify support.
- A neutral `Yso.entities` API for future class-neutral pet support (including Alchemist homunculus integration later).

Tests and rebuilds:

- Magi, Alchemist, and shared tests live in `Ysindrolir/Yso/Tests and rebuilds/`.
- Purged-class tests and tools were deleted rather than archived.

Optional **`Yso.net.cfg.dry_run`** (defaults off) can suppress live sends when testing payload plumbing locally.

## Patch notes (recent)

### May 3, 2026

- Expanded optional `Ysindrolir/scripts/export_yso_system_xml.ps1` coverage so additional shared scripts can be re-embedded into `Yso system.xml` when maintaining the split layout; on-disk mirrors under `Ysindrolir/Yso/xml/` remain development aids, not the live load mechanism in Mudlet.

### May 2, 2026

- Fixed Alchemist duel-route evaluate gating so dirty humour intel fails closed with `evaluate_not_ready` when evaluate balance is unavailable.
- Revalidated workspace checks: Lua syntax, XML parse, and full `Ysindrolir/Yso/Tests and rebuilds` suite.
- Alchemist wrack slot legality, bleed alias cleanup, and related regression tests (see Alchemist/Magi notes).

### May 1, 2026

- Plain `QUEUE ADD` support in `Yso.queue` for configurable class-combo sends while preserving `ADDCLEARFULL` instant-kill behavior.
- Alchemist temper pressure folds into one class payload with `evaluate <target> humours`, `educe`, and `wrack/truewrack` after the initial temper command.
- Live Physiology evaluate-count trigger colourizes humour count lines without breaking state tracking.
- Instant-kill queue priority: `queue_verb = "addclearfull"` on commits; Aurify/Reave and Magi Destroy execute paths request `QUEUE ADDCLEARFULL`.

### April 28, 2026

- Alchemist route reset repair, humour-balance failure handling, queue lane inference for `wrack`/`truewrack`, target-slain/AK reset hooks, baseline capture noise reduction.
- Reset cleanup output tightening: structural resets avoid live `CLEARQUEUE` spam; humour-cooldown failure path still recovers class queue when needed.

### April 27, 2026

- Alchemist evaluate-normal handling, hard evaluate gates on group/duel routes, pending temper confirmation recovery, route lifecycle hooks, homunculus corrupt parser fix (synced to package XML).

### April 26, 2026

- Alchemist lane-combo payloads (`free/eq/class/bal`), Aurify route wiring (`alchemist_aurify_route`), shieldbreak as EQ slot, staged humour / inundate support, queue class-lane readiness, expanded route tests.

---

Older granular patch history referred to legacy loader/bootstrap experiments; **current loading is Mudlet package script order only** (see [Mudlet workflow](#mudlet-workflow-package-first) above).
