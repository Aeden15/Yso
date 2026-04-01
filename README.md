# Yso

Current workspace snapshot: March 29, 2026.

## Current fixes

- **XML mirrors synced with canonical sources** — all bug fixes from the canonical Lua modules (Bugs 3, 6, 8, 10–13 + aurum bucket) are now applied to the Mudlet-facing XML mirror copies under `xml/`. Both canonical and XML surfaces match.
- **Escape button separator ownership fixed** — `yso_escape_button.lua` no longer initializes global `Yso.sep` to `";;"`; it now inherits `Yso.sep`/`Yso.cfg` and falls back to `"&&"` so load order cannot override the canonical pipe separator. Its `_now()` helper also normalizes millisecond `getEpoch()` values.
- **Fool hunt logic hardened for Occultist** — Fool now resolves cureset via a fallback chain (`ActiveServerSet` -> `CurrentCureset` -> hunt mode hint), supports tendon-severity weighting from `ak.twoh.tendons` (exact count), and exposes `fool status` / `fool auto on|off` runtime controls.
- Occultist offense is now fully alias-owned. Shared send memory lives in `offense_state.lua`, and the removed orchestrator is no longer part of the active offense path.
- Party command syntaxes were retired to avoid clashing with in-game `party ...` commands. Use `team` / `teamroute` syntax for Yso team-mode controls.
- The wake bus now retries staged queue commits on lane wakes. Manual lane aliases such as `cleanse` can stage while EQ is down and flush on reopen.
- Queue-backed live DRY sends now acknowledge Magi group-damage emits through the shared `Yso.locks.note_payload()` callback path, so route state advances without manual hook simulation.
- Shared `[Yso]` mode echoes now report only real mode/route changes, while class-owned loop toggles stay on `[Yso:Magi]` and `[Yso:Occultist]` without duplicate route-state spam.
- The stale generic `Ysindrolir/mudlet packages/Devtools.xml` package has been retired. Class-local devtools now live at `Ysindrolir/Occultist/Occultist Devtools.mpackage` and `Ysindrolir/Magi/MagiDevtools.xml`.
- Split devtools now expose class-local self-cleanse testers: `ytest bloodboil snap|fire|debug|auto` for Magi, and `ytest fool snap|fire|debug` for Occultist.
- Export artifacts were refreshed from the canonical workspace sources, including `Yso system.xml` and the queue/wake-bus mirrors that feed it.
- `team dam` remains class-sensitive: Occultist keeps the existing group-damage route, while Magi now runs a freeze-first mixed route that opens with horripilation, forces an initial freeze step on fresh targets, keeps glaciate/windows on the water side, and branches into `magma` / `firelash` / `conflagrate` / fire emanation once `frozen` or `frostbite` is established.

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
.\sync.cmd push            # copies repo → Desktop
.\sync.cmd push -DryRun    # preview without copying
```

OneDrive picks up the updated files automatically.

### Pull Desktop edits back into the repo

```powershell
cd C:\repos\Yso
.\sync.cmd pull            # copies Desktop → repo
git diff                   # review what changed
git add -A && git commit -m "sync from desktop"
git push
```

### Execution policy note

If you call `.\sync_workspace.ps1` directly and get a **"running scripts is
disabled"** error, use `sync.cmd` instead — it passes `-ExecutionPolicy Bypass`
automatically.  Alternatively, you can unlock `.ps1` scripts for your user once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

`sync.cmd` now prefers PowerShell 7 (`pwsh`) when it is installed and falls
back to Windows PowerShell otherwise. The script text is ASCII-safe so either
shell can parse it cleanly.

### What gets synced

| Repo path | Desktop path |
|-----------|-------------|
| `Ysindrolir/` | `Yso systems/Ysindrolir/` |
| `README.md`, `README.txt` | `Yso systems/README.md`, `Yso systems/README.txt` |

Git-only files (`.git/`, `.gitignore`, etc.) are excluded automatically.

## Notes

- The Occultist stack is the primary active development target.
- Magi files are present, but they are a smaller secondary track right now.
- Magi team damage now resets fresh targets through `horripilation -> freeze baseline -> branch reconsideration`, keeps `glaciate` gated on live `frozen`, and uses AK `scalded` / `aflame` / `conflagrate` state plus Yso fire-water resonance to mix salve pressure once `frozen` or `frostbite` is established.
- AK scalded handling in this workspace now assumes 20s instead of 17s for the current Magi paths.
- The packaged `Djinn present` trigger now immediately marks `Yso.elemental_lev_ready = true` so levitate readiness matches the live summoned elemental state.
- Crystalism resonance notices now echo in the package `Yso Triggers -> Magi -> Crystalism` folder, and `energise` also exposes a separate consumable Crystalism state for personal aliases without reusing the heal-burst `Yso.magi.energy` flag.
- The packaged `mheals` alias now requires both `Yso.magi.energy` and `Yso.magi.crystalism.consume_energise_resonance()` before it queues `absorb energy`.
- The package bootstraps the Crystalism energise helper inline in the trigger/alias path so `mheals` does not depend on `magi_reference.lua` load order.
- If you are debugging automation, start with the shared pipeline first: mode ownership, wake intake, queue staging, then queue commit/flush.
