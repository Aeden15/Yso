# Yso

Yso is a personal Achaea Lua workspace focused on combat-first automation, with the current build centered on the Occultist stack and its shared route-loop pipeline.

This repository tracks the editable source directly instead of storing the project as a zip snapshot. The workspace Lua tree is the canonical source of truth; Mudlet XML packages are deployment artifacts generated from it, not the preferred editing surface.

## What is here

- Shared offense infrastructure such as the wake bus, queue, route-loop state, state helpers, and utility modules
- Occultist combat routes including `occ_aff_burst`, `group_damage`, `party_aff`, and the shared `parry` module
- XML mirror scripts and Mudlet package files used to keep the live package aligned with the disk workspace
- Supporting Magi files that live in the same broader suite
- A parked `MagiDevtools` package mirror for future Magi-specific debug work

## Repository layout

- `Ysindrolir/Occultist/modules/Yso/Core`
  Shared runtime pieces such as `offense_state.lua`, `wake_bus.lua`, `queue.lua`, and state helpers.

- `Ysindrolir/Occultist/modules/Yso/Combat`
  Combat routes, offense driver state, route contracts, `parry.lua`, and class-specific helpers.

- `Ysindrolir/Occultist/modules/Yso/xml`
  Mudlet-facing XML mirror scripts. For promoted modules, these are export mirrors rather than the preferred editing surface.

- `Ysindrolir/Occultist/EXPORT_MANIFEST.lua`
  Source-to-mirror mapping for the promoted Occultist files.

- `Ysindrolir/Occultist/tools`
  Helper scripts for keeping mirrors and exports in sync.

- `Ysindrolir/mudlet packages`
  Mudlet package artifacts such as `Yso system.xml`, `Yso offense aliases.xml`, and the live `Devtools.xml` export. The parked source-side mirror now lives at `Ysindrolir/Magi/MagiDevtools.xml`.

## Current combat focus

- `occ_aff_burst` is the duel/combat-mode Occultist affliction burst route.
- `group_damage` is the party-damage route.
- `party_aff` is the party-affliction support route.
- Alias-owned route loops plus the shared wake/queue path are the central automation pipeline.
- `parry.lua` is part of the canonical runtime, not just an exported package mirror.
- `^aff$` is intended to toggle the Occultist affliction burst automation.

## Editing workflow

1. Edit the canonical Lua source first, especially under `modules/Yso/Core` and `modules/Yso/Combat`.
2. Sync the XML mirrors for promoted files.
3. Rebuild or refresh the Mudlet-facing package files if needed.
4. Test in Mudlet.
5. Commit and push from the same working folder you edit and test in.

## Workspace note

- The active Desktop workspace is intended to be the primary git working copy.
- Cursor, Mudlet-facing exports, and git commands should all point at that same folder.
- A second out-of-band clone can be kept as a fallback copy, but day-to-day work should not rely on manually syncing changes into a separate repo before commit.

## Notes

- This project is actively evolving, so some modules are more stable than others.
- The Occultist stack is the main focus right now; Magi content is present but not the primary active development target.
- The current runtime model is workspace-backed rather than standalone-package-first; `Yso system.xml` may still depend on filesystem-managed modules.
- If you are debugging automation, start with the shared pipeline before blaming a route: mode/route-loop ownership, wake intake, queue staging, then commit.
