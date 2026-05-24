# Yso systems status — May 23, 2026

Supported classes are **Magi** and **Alchemist**, plus shared Yso core. Older class stacks were removed from this workspace and from the Mudlet package; do not treat removed classes as active automation paths.

## Mudlet workflow (package-first)

- **Canonical runtime:** Install/import the package under `Ysindrolir/mudlet packages/`, especially **`Yso system.xml`** (and `.mpackage` exports when you use them). Combat behavior comes from the embedded scripts and Mudlet’s script **load order**, not from ad-hoc filesystem loading.
- **Globals, not route `require`:** Later scripts assume **preloaded global tables** (`Yso`, route registries, class helpers, and so on). Do not activate routes via runtime **`require(...)`** / **`pcall(require, ...)`**, and do not add **`YSO_ROOT`**, **`package.path`**, or repo-root probing for route loading. Bootstrap loaders were removed; **`Route chassis loader`** only documents the **`Yso.load_order_contract`** tier order.
- **API surface:** **`Ysindrolir/Yso/xml/api_stuff.lua`** is the single source of truth for `Yso.emit`, curing helpers, and related APIs (Mudlet script **Api stuff**). **`Ysindrolir/Yso/Core/api.lua`** is a thin load shim only.
- **Command emission:** **`Yso.queue` was removed.** Routes and helpers send through **`Yso.emit`** / **`Yso.emit_now`** (and direct **`send`** where appropriate). There is no client-side queue layer.
- **Operating:** Use the package **aliases** and toggles in Mudlet (for example Magi **`mdam`** for group damage, **`mfocus`** for focus/duel convergence, **`magi_dmg`** for duel lock, **`mreflect`** to cast reflection; Alchemist **`adam`**, **`aduel`**). Combat mode plus per-route toggles drive the offense loops.
- **Repo vs package:** Lua under `Ysindrolir/Yso/`, `Ysindrolir/Magi/`, and `Ysindrolir/Alchemist/` is the git-side source tree. When editing split-layout sources, sync back into the package with the scripts below.

### Export and Magi alias build

From `Ysindrolir/scripts/`:

1. **Magi alias bodies:** `.\build_mdam_alias_body.ps1` (route_core + group_damage + toggle) and `.\build_mfocus_alias_body.ps1` (route_core + dissonance + focus + toggle).
2. **Full package refresh:** `.\export_yso_system_xml.ps1` re-embeds scripts, rebuilds **mdam** / **mfocus** / **mreflect** alias bodies, removes retired scripts (**Yso Bootstrap loader**, **Yso.queue**, **Magi group damage**, **Magi focus**), removes duplicate **mgd**, and drops Reflection up/down triggers.

Magi **group damage** lives in **`^mdam$`** (`magi_group_damage`). Magi **focus** lives in **`^mfocus$`** (`magi_focus`). Shared chassis script: **Magi route core**. **`magi_dmg`** remains duel damage. **`mgd`** removed (use **`mdam`**). **`mreflect`** is cast-only (not auto-reflect).

Kept in tree:

- Shared Yso core, curing, route framework, target helpers, AK/Legacy integration, and class-neutral utilities.
- Magi route core script, alias-embedded group damage (`mdam`) and focus (`mfocus`), duel damage route, vibes helper, and cast reflection alias.
- Alchemist physiology/formulation/duel/group-damage/Aurify support.
- A neutral `Yso.entities` API for future class-neutral pet support (including Alchemist homunculus integration later).

Tests and rebuilds:

- Magi, Alchemist, and shared tests live in `Ysindrolir/Yso/Tests and rebuilds/`.
- Purged-class tests and tools were deleted rather than archived.

Optional **`Yso.net.cfg.dry_run`** (defaults off) can suppress live sends when testing payload plumbing locally.

## Patch notes (recent)

### May 24, 2026

- **`mdam`** / **`mfocus`** alias bodies now embed Magi route modules at build time (including route_core and dissonance for focus) with no runtime peer-`dofile` loading.
- Added package script **Magi route core** and removed package script **Magi focus**.
- Removed duplicate alias **`mgd`** and route-registry alias mapping for `mgd`.
- **`mreflect`** is now a simple cast alias (`send`) and Reflection up/down triggers were removed.
- Slimmed **Defensive checks** to class/HP helpers (`set_class`, `is_magi`, `get_hp_percent`) and removed auto-reflect loop wiring.

### May 23, 2026

- Removed bootstrap/path-loader layer (`Core/bootstrap.lua`, `xml/bootstrap.lua`, **Yso Bootstrap loader**); **`Route chassis loader`** retains **`load_order_contract`** only.
- Removed **`Yso.queue`** entirely; routes use **`Yso.emit`** / **`Yso.send`** directly. Queue test/scripts deleted.
- **`api_stuff.lua`** is API SSOT; export embeds it as **Api stuff**; **`Core/api.lua`** is a shim.
- Magi group damage moved into **`^mdam$`** alias (`Magi/mdam_alias_body.lua` + `Magi/magi_group_damage.lua`); standalone **Magi group damage** package script removed.
- Added **`build_mdam_alias_body.ps1`**; **`export_yso_system_xml.ps1`** updated (**ScriptsToRemove**, no queue/bootstrap entries).

### May 3, 2026

- Expanded optional `Ysindrolir/scripts/export_yso_system_xml.ps1` coverage so additional shared scripts can be re-embedded into `Yso system.xml` when maintaining the split layout; on-disk mirrors under `Ysindrolir/Yso/xml/` remain development aids, not the live load mechanism in Mudlet.

### May 2, 2026

- Fixed Alchemist duel-route evaluate gating so dirty humour intel fails closed with `evaluate_not_ready` when evaluate balance is unavailable.
- Revalidated workspace checks: Lua syntax, XML parse, and full `Ysindrolir/Yso/Tests and rebuilds` suite.
- Alchemist wrack slot legality, bleed alias cleanup, and related regression tests (see Alchemist/Magi notes).

### May 1, 2026

- Plain `QUEUE ADD` support in route payloads for configurable class-combo sends while preserving `ADDCLEARFULL` instant-kill behavior.
- Alchemist temper pressure folds into one class payload with `evaluate <target> humours`, `educe`, and `wrack/truewrack` after the initial temper command.
- Live Physiology evaluate-count trigger colourizes humour count lines without breaking state tracking.
- Instant-kill queue priority: `queue_verb = "addclearfull"` on commits; Aurify/Reave and Magi Destroy execute paths request `QUEUE ADDCLEARFULL`.

### April 28, 2026

- Alchemist route reset repair, humour-balance failure handling, BAL-lane inference for `wrack`/`truewrack`, target-slain/AK reset hooks, baseline capture noise reduction.
- Reset cleanup output tightening: structural resets avoid live `CLEARQUEUE` spam; humour-cooldown failure path still recovers class queue when needed.

### April 27, 2026

- Alchemist evaluate-normal handling, hard evaluate gates on group/duel routes, pending temper confirmation recovery, route lifecycle hooks, homunculus corrupt parser fix (synced to package XML).

### April 26, 2026

- Alchemist lane-combo payloads (`free/eq/class/bal`), Aurify route wiring (`alchemist_aurify_route`), shieldbreak as EQ slot, staged humour / inundate support, queue class-lane readiness, expanded route tests.

---

Older granular patch history referred to legacy loader/bootstrap experiments; **current loading is Mudlet package script order only** (see [Mudlet workflow](#mudlet-workflow-package-first) above).
