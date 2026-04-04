# Yso

Current workspace snapshot: April 2, 2026.

## Current fixes

- **Occultist aff-burst route retuned** — Mana-bury pressure now prioritizes `asthma -> paralysis/slickness hold -> healthleech -> manaleech`, then applies `disloyalty` post-manaleech with `anorexia` as a late fallback only. Deaf-down pressure now pairs `command chimera` with an EQ filler/missing aff while chimera-pool mentals are still open, and the route no longer includes the `abdebug` screen/alias helpers.
- **Domination Feed tracking added** — `Yso.dom.feed` now exposes `feed_ready()`, `feed_active()`, and `feed_remaining()` plus cast/ready/destroyed update helpers. The Domination trigger folder in `Yso system.xml` now echoes feed active, feed ready, and the destroyed entity in Domination style, and cooldown-line parsing (`Domination feed: ...`) updates state as a fallback.
- **Unified self-cleanse module** — Bloodboil (Magi), Fool (Occultist), and Tree Tattoo (universal) now share a cureset-keyed PvP configuration architecture. PvP is scaffolded with per-cureset thresholds (depthswalker, bard, monk, dwc, dwb, blademaster, shaman, airlord) but disabled by default until tuned.
- **Bloodboil hunt threshold lowered** — `min_affs_hunt` reduced from 4 to 2 so bloodboil fires earlier during hunting.
- **Bloodboil PvP path** — `should_bloodboil()` no longer hard-gates on `cureset == "hunt"`. When PvP is enabled, it looks up per-cureset thresholds with softlock override support.
- **Fool hunt threshold lowered** — `min_affs_hunt` reduced from 3 to 2 for earlier defensive cleansing while hunting.
- **Fool per-cureset PvP thresholds** — `_min_affs_for_current_set()` now checks `Legacy.Fool.pvp.curesets[curset]` before falling back to `min_affs_default`.
- **Tree Tattoo auto-touch module** — New `Yso.tree` module: tracks 14s cooldown via game lines, gates on paralysis, resolves thresholds by cureset (hunt=1 aff, PvP configurable), auto-fires on GMCP vitals tick and cooldown-ready line. Commands: `lua Yso.tree.set_auto(true|false)`, `lua Yso.tree.status()`.
- **Devtools selfcleanse snapshot** — `ytest sc` / `ytest selfcleanse` displays all three abilities. `ytest tree` and `ytest fool` also available as standalone status checks. `ytest bb snap` now shows PvP config state.
- **Magi route bug sweep (16 bugs)** — Critical: `on_send_result` payload format mismatch in `magi_group_damage.lua` caused route to get stuck at freeze step on the primary queue path. High: `template.last_payload` shape normalized. Medium: `explain()` no longer mutates combat state, `magi_focus.lua` queue commit failure now marks pending, freeze check no longer preempts postconv kill window, `magi_dissonance.lua` confidence properly resets on clear/reset. Low: dead code removed (6 unused functions), `eq_ready()` or-chain fixed for boolean `false`, nil-slot guards added to pending helpers, gsub return-count leaks fixed in `magi_reference.lua` and `vibeds_alias_body.lua`.
- **Full workspace bug audit (Bugs 15–39)** — 25 new bugs found and fixed across canonical Lua, XML mirrors, standalone XML scripts, and `Yso system.xml`. All canonical-to-mirror pairs remain in sync. See `bug_audit_fixes.txt` for the complete technical log.
- **Critical: Limb tracking event handler fixed** — `mudlet.lua` `registerAnonymousEventHandler` for `"limb hits updated"` was missing the leading `_event` parameter, shifting all arguments by one. The entire limb bridge was broken (name received the event string, limb received the player name, amount received the limb name, real amount was dropped).
- **Critical: Entourage timestamp corrected** — `entourage_script.lua` divided `getEpoch()` by 1000, producing a 1970-era timestamp. Entity staleness checks always saw the entourage as stale. All three call sites fixed.
- **High: `api.lua` scoping and normalization** — `Yso.pause_offense()` referenced `_now()` outside its `do...end` scope (always nil, fell through to integer `os.time()`). `_ak_now()` returned raw `getEpoch()` without ms-to-seconds normalization.
- **High: Magi peer loader `@` prefix** — `_load_magi_peer()` in both `magi_group_damage.lua` and `magi_focus.lua` failed to strip the leading `@` from `debug.getinfo().source`, so `dofile` always received an invalid path.
- **Medium: Wake bus emit result** — `pcall` status was confused with the emit return value; `_did_emit` was set even when nothing was actually emitted, causing the dispatch loop to break early.
- **Medium: Duel challenge name extraction** — Patterns for `"you challenge"` and `"you accept"` used lowercase, but Achaea outputs `"You challenge"` / `"You accept"` with capital Y. Name extraction now uses `[Yy]ou`.
- **Medium: Aeon entropy dead code** — Compel entropy block required `_bal_ready()` which was guaranteed false after the tarot path returned. Now correctly gates on `_eq_ready()` alone.
- **Medium: Offense driver cleanup** — `_now()` now wraps `Yso.util.now()` with `pcall`; `sensitivity = "slime"` removed from kelp entity pool (slime applies paralysis); `_mark()` now uses `_now()` instead of inline `getEpoch()`.
- **Medium: Entity affliction key fixed** — `offense_helpers.lua` used `"worms"` as the key for the worm entity's affliction; corrected to `"healthleech"`.
- **Medium: Entity registry target override** — Lua `and`/`or` operator precedence silently ignored explicit `target_valid = false`; replaced with proper if/else.
- **Medium: Hinder clock alignment** — `_now()` now tries `Yso.util.now()` first (with pcall) to match the clock source used by `H.collect()`.
- **Medium: AK legacy wiring normalization** — `_akwire_now()` now applies `tonumber()` and the `> 20000000000` ms-to-seconds guard.
- **Medium: Magi route core ternary** — `build_snapshot` `target_valid`/`eq_ready` replaced with explicit if/else to honor explicit `false`.
- **Low: SightGate load-order fix** — `sightgate.lua` captured `Yso.queue` at load time; now resolves dynamically via `_Q()` so queue availability isn't locked to load order.
- **Low: ProneController entity lane** — Chimera commands now queue under `"class"` (entity balance) instead of `"eq"` (equilibrium). Regress commands remain on `"eq"`.
- **Low: Aura parser nil guard and cold-start** — `aura_parser.lua` now guards `affstrack` access and fills cold-start `else` branches for count=2 (score 50) and count=1 (score 33) instead of silently dropping.
- **Low: Function list orphan** — `"Yso.target_flush_send_state"` was a bare string outside any subtable in `yso_list_of_functions.lua`; moved into `misc_clear_target`.
- **Low: Magi magma category mismatch** — `magi_group_damage.lua` returned `"salve_pressure"` as the category for magma but set the stage to `"fire_build"`; category corrected to `"fire_build"`.
- **Low: Magi vibes `_now()` normalization** — `magi_vibes.lua` was the only module missing the `> 20000000000` ms-to-seconds guard.
- **Low: Magi focus dissonance fallback** — `embed dissonance` handler now properly falls back to `_target()` when `last_target` is empty string (truthy in Lua).
- **Trivial: Dead postconv call removed** — Second `_pick_postconv_action` call in `magi_focus.lua` was unreachable.
- **Trivial: `magi_reference.lua` `_res_now()`** — Replaced lookup for nonexistent global `_now` with standard `getEpoch()` + normalization.
- **XML mirrors synced with canonical sources** — all bug fixes from the canonical Lua modules (Bugs 3, 6, 8, 10–13 + aurum bucket + Bugs 15–39) are now applied to the Mudlet-facing XML mirror copies under `xml/`. Both canonical and XML surfaces match.
- **Escape button separator ownership fixed** — `yso_escape_button.lua` no longer initializes global `Yso.sep` to `";;"`; it now inherits `Yso.sep`/`Yso.cfg` and falls back to `"&&"` so load order cannot override the canonical pipe separator. Its `_now()` helper also normalizes millisecond `getEpoch()` values.
- **Fool hunt logic hardened for Occultist** — Fool now resolves cureset via a fallback chain (`ActiveServerSet` -> `CurrentCureset` -> hunt mode hint), supports tendon-severity weighting from `ak.twoh.tendons` (exact count), and exposes `fool status` / `fool auto on|off` runtime controls.
- Occultist offense is now fully alias-owned. Shared send memory lives in `offense_state.lua`, and the removed orchestrator is no longer part of the active offense path.
- Party command syntaxes were retired to avoid clashing with in-game `party ...` commands. Use `team` / `teamroute` syntax for Yso team-mode controls.
- The wake bus now retries staged queue commits on lane wakes. Manual lane aliases such as `cleanse` can stage while EQ is down and flush on reopen.
- Queue-backed live DRY sends now acknowledge Magi group-damage emits through the shared `Yso.locks.note_payload()` callback path, so route state advances without manual hook simulation.
- Shared `[Yso]` mode echoes now report only real mode/route changes, while class-owned loop toggles stay on `[Yso:Magi]` and `[Yso:Occultist]` without duplicate route-state spam.
- The stale generic `Ysindrolir/mudlet packages/Devtools.xml` package has been retired. Unified class devtools now live in `Ysindrolir/mudlet packages/YsoDevtools.xml`.
- The shared devtools XML exposes class-segregated self-cleanse testers: `ytest bloodboil snap|fire|debug|auto` for Magi, and `ytest fool snap|fire|debug` for Occultist.
- Export artifacts were refreshed from the canonical workspace sources, including `Yso system.xml` and the queue/wake-bus mirrors that feed it.
- `team dam` remains class-sensitive: Occultist keeps the existing group-damage route, while Magi now runs a freeze-first mixed route that opens with horripilation, forces an initial freeze step on fresh targets, keeps glaciate/windows on the water side, and branches into `magma` / `firelash` / `conflagrate` / fire emanation once `frozen` or `frostbite` is established.
- Magi routes now share a Magi-only chassis helper at `Yso.off.magi.route_core`, and Magi combat now includes a duel `focus` route that builds four-element moderate resonance plus Dissonance pressure into `convergence`, then overlays `destroy` / Fulminate / burst maintenance.
- AK package remediation tightened several live compatibility surfaces in `AK.xml`: classlock selection is now AK-owned instead of branching on WSys/SVO, the Pariah heartbeat callback is live again, salve/additive bookkeeping was corrected, and the known `earworm` duplicate cure-line report remains intentionally deferred until the real line is confirmed.
- Yso helper remediation fixed the non-`getEpoch()` inhibit fallback to use wall-clock time, corrected target hearing/vision gating to read `affstrack.score`, honored `ents.slickness` in SightGate, and removed self-`aeon` from the ProneController softscore list.

## What is here

- Shared offense infrastructure such as the wake bus, queue, route-loop state, targeting/state helpers, and utility modules.
- Occultist combat routes including `occ_aff_burst`, `group_damage`, `party_aff`, and the shared `parry` module.
- XML mirror scripts and Mudlet package files used to keep the live package aligned with the disk workspace.
- Supporting Magi files that live in the same broader suite.
- Magi-only route helpers and duel-route state such as `magi_route_core.lua`, `magi_dissonance.lua`, and `magi_focus.lua`.

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
- Magi combat also now has a direct `focus` route toggle that stays in the existing route family/debug flow, uses live Magi resonance plus Magi-local Dissonance tracking, reopens `freeze` when `frozen` or `frostbite` drops, revisits `bombard`, and converts immediately into `convergence` once all four elements are moderate and Dissonance reaches stage 4.
- AK scalded handling in this workspace now assumes 20s instead of 17s for the current Magi paths.
- The packaged `Djinn present` trigger now immediately marks `Yso.elemental_lev_ready = true` so levitate readiness matches the live summoned elemental state.
- Crystalism resonance notices now echo in the package `Yso Triggers -> Magi -> Crystalism` folder, and `energise` also exposes a separate consumable Crystalism state for personal aliases without reusing the heal-burst `Yso.magi.energy` flag.
- The packaged `mheals` alias now requires both `Yso.magi.energy` and `Yso.magi.crystalism.consume_energise_resonance()` before it queues `absorb energy`.
- The package bootstraps the Crystalism energise helper inline in the trigger/alias path so `mheals` does not depend on `magi_reference.lua` load order.
- If you are debugging automation, start with the shared pipeline first: mode ownership, wake intake, queue staging, then queue commit/flush.
- **Fool basher preemption** — Eligible Fool uses now clear Legacy basher `freestand` work before queueing and temporarily suppress fresh basher attack-package requeues until the Fool self-use line or a timeout. The prone gate still blocks Fool before any queue clearing, and debug/status output reports the prone reason and basher-hold state.
