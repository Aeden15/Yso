# Yso source audit — 2026-10-17

The `Ysindrolir/Yso` folder is still used. It contains package-export sources, shared services, compatibility modules, development mirrors, and the regression suite. The installed Mudlet package executes embedded Lua in script order; it does not automatically execute every `.lua` file in this folder.

## Removed files

Only these three retired bootstrap files were removed:

- `Yso/Core/bootstrap.lua`
- `Yso/xml/bootstrap.lua`
- `Yso/xml/yso_bootstrap_loader.lua`

The first two were copies of the retired filesystem loader: root probing, `package.path` mutation, and dynamic module autoloading. Their references to one another formed a disconnected loader component. No remaining source, test, build mapping, or package script invokes either file. The third was a retired package loader shim with a hard-coded debug log. No package embeds its body, and the exporter explicitly removes the old `Yso Bootstrap loader` slot.

Evidence was checked across all XML packages, exporter source mappings and insertion lists, source-module strings, `require`/`dofile`/`loadfile` calls, test path construction, script tooling, and documentation. The package contains no filesystem loader calls. The README and workspace rule explicitly retire bootstrap/path probing. No deletion was based solely on a missing runtime script name.

Before deletion, byte-identical backups were verified with SHA-256 under the workspace-only `.superpowers/shikudo-cleanup/removed-backup/`. The workspace-only `removed-files.json` records repository-relative deletion paths. These backups are not delivery sources and must not be committed.

## Retained sources and support

- `xml/`: retained package source mappings and development mirrors, including API, targeting, modes, pulse, offense, priority baselines, and class-neutral helpers. The exporter names its authoritative inputs explicitly; the directory is not a blanket runtime loader.
- `Combat/`, `Curing/`, and `Integration/`: retained implementations referenced by the exporter, test harnesses, or compatibility module paths. These include route registry/interface/gates, offense, parry, AK wiring, and curing services.
- `Core/`: retained direct test dependencies and compatibility modules. In particular, `Core/queue.lua` is loaded by `test_queue_writhe_block.lua`, and `test_wake_route_contract.lua`; optional queue consumers remain in the package. It cannot be deleted just because the package no longer installs a standalone `Yso.queue` script.
- `Tests and rebuilds/`: retained the entire shared, class, and integration regression suite.
- Root-level modules, `_entry.lua`, `init.lua`, and `Yso.lua`: retained disk/test compatibility entrypoints and namespace wrappers. For example, `Combat/offense_core.lua` still has a compatibility reference to `Yso._entry`.
- `Debug/`: retained optional diagnostics; no claim that they are part of the default installed runtime.

## Uncertain or inactive files preserved

`Curing/blademaster_curing.lua` has no discovered consumer or matching embedded body. It was preserved because it is a defensive snapshot helper rather than a route and its intended optional use cannot be established safely from this cleanup. Blademaster curing overlays and tests elsewhere remain referenced and were retained.

`Core/Template.lua` is a commented automation template, not live route code. It remains as a development aid. Namespace wrappers and unmapped XML mirrors are likewise preserved; lack of an exporter mapping does not prove a compatibility module or development mirror is disposable.

The following inspected mirror pairs match after newline normalization: route registry, route interface, route gate, parry, AK wiring, and serverside policy. `Core/queue.lua` and `xml/yso_queue.lua` differ only by one explanatory comment in lane inference; their executable logic matches. No runtime reconciliation is needed for that comment difference.

## Validation and synchronization

All existing package XMLs parsed during the audit. None contains an exact embedded body of a removed file; no remaining executable references point to their paths or module names. Shared source and tests remain present. The implementation's full regression run should be completed before delivery.

The canonical Git sync helper currently copies with `robocopy /E /XO`, which does not propagate deletions. Delivery must explicitly remove the three repository-relative paths from the canonical clone after reviewing its status, then verify workspace/source/package synchronization before committing. Do not use an unrestricted mirror operation against the clone.
