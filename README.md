# Yso

Current workspace snapshot: March 27, 2026.

## Current fixes

- **XML mirrors synced with canonical sources** — all bug fixes from the canonical Lua modules (Bugs 3, 6, 8, 10–13 + aurum bucket) are now applied to the Mudlet-facing XML mirror copies under `xml/`. Both canonical and XML surfaces match.
- Occultist offense is now fully alias-owned. Shared send memory lives in `offense_state.lua`, and the removed orchestrator is no longer part of the active offense path.
- The wake bus now retries staged queue commits on lane wakes. Manual lane aliases such as `cleanse` can stage while EQ is down and flush on reopen.
- The stale generic `Ysindrolir/mudlet packages/Devtools.xml` package has been retired. Split devtools sources now live at `Ysindrolir/Occultist/Occultist Devtools.xml` and `Ysindrolir/Magi/MagiDevtools.xml`.
- Export artifacts were refreshed from the canonical workspace sources, including `Yso system.xml` and the queue/wake-bus mirrors that feed it.

## What is here

- Shared offense infrastructure such as the wake bus, queue, route-loop state, targeting/state helpers, and utility modules.
- Occultist combat routes including `occ_aff_burst`, `group_damage`, `party_aff`, and the shared `parry` module.
- XML mirror scripts and Mudlet package files used to keep the live package aligned with the disk workspace.
- Supporting Magi files that live in the same broader suite.

## Repository layout

- `Ysindrolir/Occultist/modules/Yso/Core`
  Canonical runtime pieces such as `offense_state.lua`, `wake_bus.lua`, `queue.lua`, `modes.lua`, and state helpers.

- `Ysindrolir/Occultist/modules/Yso/Combat`
  Combat routes, route contracts, `parry.lua`, and class-specific helpers.

- `Ysindrolir/Occultist/modules/Yso/xml`
  Mudlet-facing XML mirror scripts. Promoted modules mirror the canonical Lua source rather than serving as the preferred edit surface.

- `Ysindrolir/Occultist/EXPORT_MANIFEST.lua`
  Source-to-mirror mapping for promoted Occultist files.

- `Ysindrolir/Occultist/tools`
  Helper scripts for refreshing mirrors and rebuilding `Yso system.xml`.

- `Ysindrolir/mudlet packages`
  Mudlet package artifacts such as `Yso system.xml`, `Yso offense aliases.xml`, `AK.xml`, and `limb.1.2.xml`.

## Editing workflow

1. Edit the canonical Lua source first.
2. Refresh the XML mirrors for promoted files.
3. Rebuild the Mudlet-facing package files when export-backed files changed.
4. Test in Mudlet.
5. Commit and push the synced files.

## Syncing with OneDrive Desktop

The `Yso systems` folder on your Desktop is synced by OneDrive.  The
`sync_workspace.ps1` script in this repo mirrors files between the git
clone and that Desktop folder so changes flow in both directions.

### First-time setup

1. Clone this repo somewhere **outside** OneDrive (e.g. `C:\repos\Yso`).
   OneDrive lock-file conflicts can corrupt `.git` internals, so keep the
   clone on a plain local drive.

   ```powershell
   git clone https://github.com/Aeden15/Yso.git C:\repos\Yso
   ```

2. Make sure `Yso systems` already exists on your Desktop.  The script
   auto-detects common OneDrive Desktop paths:
   - `%USERPROFILE%\OneDrive\Desktop\Yso systems`
   - `%USERPROFILE%\Desktop\Yso systems`

   If yours is somewhere else, pass `-DesktopPath` explicitly.

### Push repo changes to the Desktop

```powershell
cd C:\repos\Yso
.\sync_workspace.ps1 push            # copies repo → Desktop
.\sync_workspace.ps1 push -DryRun    # preview without copying
```

OneDrive picks up the updated files automatically.

### Pull Desktop edits back into the repo

```powershell
cd C:\repos\Yso
.\sync_workspace.ps1 pull            # copies Desktop → repo
git diff                             # review what changed
git add -A && git commit -m "sync from desktop"
git push
```

### What gets synced

| Repo path | Desktop path |
|-----------|-------------|
| `Ysindrolir/` | `Yso systems/Ysindrolir/` |
| `README.md`, `README.txt` | `Yso systems/README.md`, `Yso systems/README.txt` |

Git-only files (`.git/`, `.gitignore`, etc.) are excluded automatically.

## Notes

- The Occultist stack is the primary active development target.
- Magi files are present, but they are a smaller secondary track right now.
- If you are debugging automation, start with the shared pipeline first: mode ownership, wake intake, queue staging, then queue commit/flush.
