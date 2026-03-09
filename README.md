# Yso

Yso is a personal Achaea Lua workspace focused on combat-first automation, with the current build centered on the Occultist stack and its shared orchestration pipeline.

This repository tracks the editable source directly instead of storing the project as a zip snapshot.

## What is here

- Shared offense infrastructure such as the wake bus, orchestrator, queue, state helpers, and utility modules
- Occultist combat routes including `occ_aff_burst` and `group_damage`
- XML mirror scripts and Mudlet package files used to keep the live package aligned with the disk workspace
- Supporting Magi files that live in the same broader suite

## Repository layout

- `Ysindrolir/Occultist/modules/Yso/Core`  
  Shared runtime pieces such as `orchestrator.lua`, `wake_bus.lua`, `queue.lua`, and state helpers.

- `Ysindrolir/Occultist/modules/Yso/Combat`  
  Combat routes, offense driver state, route contracts, and class-specific helpers.

- `Ysindrolir/Occultist/modules/Yso/xml`  
  Mudlet-facing XML mirror scripts. For promoted modules, these are export mirrors rather than the preferred editing surface.

- `Ysindrolir/Occultist/EXPORT_MANIFEST.lua`  
  Source-to-mirror mapping for the promoted Occultist files.

- `Ysindrolir/Occultist/tools`  
  Helper scripts for keeping mirrors and exports in sync.

- `Ysindrolir/mudlet_packages`  
  Mudlet package artifacts such as `Yso system.xml`, `Yso offense aliases.xml`, and `Devtools.mpackage`.

## Current combat focus

- `occ_aff_burst` is the duel/combat-mode Occultist affliction burst route.
- `group_damage` is the party-damage route.
- The shared wake -> orchestrator -> queue path is the central automation pipeline.
- `^aff$` is intended to toggle the Occultist affliction burst automation.

## Editing workflow

1. Edit the canonical Lua source first, especially under `modules/Yso/Core` and `modules/Yso/Combat`.
2. Sync the XML mirrors for promoted files.
3. Rebuild or refresh the Mudlet-facing package files if needed.
4. Test in Mudlet.
5. Commit and push from GitHub Desktop to create a checkpoint.

## Notes

- This project is actively evolving, so some modules are more stable than others.
- The Occultist stack is the main focus right now; Magi content is present but not the primary active development target.
- If you are debugging automation, start with the shared pipeline before blaming a route: wake intake, orchestrator selection, queue staging, then commit.
