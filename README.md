# Yso

Current workspace snapshot: April 17, 2026.

## Current fixes

- **Fool bash anti-spam freshness gate + hunt threshold bump (April 17, 2026)** — `fool_logic.lua` now fail-closes Fool in bash mode unless self-aff state is backed by a fresh `gmcp.Char.Afflictions.List` snapshot (manual + auto + diagnose paths), preventing off-cooldown no-aff ghost fires. Hunt threshold is now fixed at `4+` current afflictions (was `3+`). Regression coverage was expanded in `test_fool_basher_preempt.lua` for stale/fresh GMCP-list gating and 4-aff hunt threshold/timing behavior.
- **Magi/Occultist route compatibility hotfix (April 15, 2026)** — Restored `focus` route-loop compatibility in `Magi/magi_focus.lua` by accepting both `magi_focus` and `focus` loop ids and reporting route key `focus` in explain output; restored dry-run queue acknowledgement state updates in `Magi/magi_group_damage.lua` when ack bus hooks are present but no live callback fires; and fixed `occ_aff` explain queue-owned filtering to accept compatibility route aliases (`oc_aff`/`occ_aff`/`aff`) so class-lane plan display clears immediately after ack lane clear. Ran full regression sweep (`luac`, 17/17 Lua tests, XML parse), refreshed XML mirrors, and rebuilt `Yso system.xml`.
- **`occ_aff` phase bootstrap regression fix (April 13, 2026)** — `modules/Yso/Combat/routes/occ_aff.lua` now limits loyals opener bootstrap gating to the `open` phase. Pressure/cleanse/convert/finish planning no longer short-circuits behind opener staging, restoring expected EQ/BAL/class payload generation and convert->finish transition behavior (`test_loyals_bootstrap_readaura.lua`). XML mirrors were refreshed and `Yso system.xml` was rebuilt.
- **Fool hunt/bash cureset gate fix (April 12, 2026)** — `fool_logic.lua` now resolves curesets in this order: dev override -> `Legacy.Curing.ActiveServerSet` -> `_G.CurrentCureset` -> mode fallback -> `legacy`, so bash mode no longer overrides explicit non-hunt curesets. In `hunt`, Fool is now a strict live gate (cooldown ready, balance ready now, 4+ current affs, and no `paralysis`/`prone`/`webbed`/both-arms-broken hard fail). The old permissive 2-aff hunt behavior was removed, and `test_fool_basher_preempt.lua` now covers hunt threshold/timing/hard-fail regressions plus cureset precedence.
- **Occultist direct-call loop-state compatibility fix (April 12, 2026)** — `occ_aff.can_run()` now enforces enabled/active route-loop state only when a route-loop manager is present (or explicitly requested), so direct `build_payload()`/`attack_function()` calls keep working in standalone/test contexts. This resolves the regression surfaced in `test_loyals_bootstrap_readaura.lua` and `test_occ_aff_loop_requeue.lua`. XML mirrors were refreshed and `Yso system.xml` was rebuilt.
- **Occultist `occ_aff` Sunder-template alignment (April 12, 2026)** — Converted `occ_aff` attack flow to the lane-table Sunder route shape used by `party_aff`/`group_damage`: route payloads now carry `lanes` + `meta`, include dual `entity`/`class` keys, pass through `Yso.route_gate.finalize(...)`, and emit via the same commit-ready lane adapter path. Added route-local in-flight/debug/template state (`waiting/main_lane/fingerprint`, `in_flight`, last no-send/retry reason) while keeping existing affliction decision logic intact.
- **Occultist aff-route stall + vitals nil-guard hotfix (April 12, 2026)** — `occ_aff` now mirrors party/group loop behavior by keeping route ticks continuously reevaluating (no hard wait-block gate on local waiting state), which prevents staged-emit dead-time stalls and keeps EQ/BAL/class planning responsive while companion recovery is pending. Companion route-active detection now also recognizes `occ_aff_burst`/`aff` aliases for recovery handling consistency. `Legacy UI V2.0.xml` `UI Setup` vitals-change math now safely guards `maxhp`/`maxmp` percentage calculations to stop repeated `gmcp.Char.Vitals` arithmetic-on-nil runtime errors.

- **Occultist route progression + companion command consistency hotfix (April 11, 2026)** — `occ_aff`, `party_aff`, and `group_damage` now strictly suppress loyal kill opener fallback while companion recovery is pending, so loops keep evaluating legal EQ/BAL/class actions without re-sending stale companion orders. Package alias/script surfaces were aligned to `order loyals kill/passive` (including `Yso system.xml` `Loyals passive/attack` and clock defaults, plus `Yso offense aliases.xml` entattack/entpass), and `Legacy UI V2.0.xml` `UI Setup` vitals math now nil-guards EP/WP percentage arithmetic to prevent `gmcp.Char.Vitals` error spam.
- **Occultist companion-control unification + loop-toggle visibility (April 11, 2026)** — Added shared companion helper at `modules/Yso/Combat/occultist/companions.lua` and wired Occultist combat routes to canonical free-lane commands (`order loyals kill <target>`, `order loyals passive`) instead of entourage kill automation. Companion hard-failure lines now trigger one-shot `call entities` recovery with suppression while pending, plus recovery invalidation hooks for tumble/starburst/astralform. Route toggles now keep `<orange>[Yso:Occultist]` prefix with uppercase `<HotPink>` ON/OFF wording for clearer visibility.
- **Mind-locking alert trigger added under Miscellaneous stuff (April 11, 2026)** — `Yso system.xml` now includes `Mind locking` in the `Miscellaneous stuff` trigger folder with regex `^You feel the probing mind of (.+) touch yours\\.$`, `Alarm01.wav` sound, and `Yso.radianceAlert.fire(1, who, "MIND LOCKING")` scripting.
- **Serverside curing writhe/tree interlink hardening (April 11, 2026)** — Yso now treats writhe-family hindrances as first-class EQ/BAL blockers through the self-aff truth path, clears stale blocked lane intent instead of leaving queued actions armed, and re-evaluates fresh payloads after unblock. `queue.lua` now supports lane block/unblock state (`block_lane`, `unblock_lane`, `lane_blocked`) with optional owned-queue clearing, `hinder.lua` consumes dynamic writhe-family affs, and `serverside_policy.lua` now unifies tree state ownership (including exact “glows faintly … leaving you unchanged” suppression until tree-ready is restored) while suppressing tree emergency queue sends during writhe or unchanged-wait states.
- **Tree state-only coordination (April 11, 2026)** — Yso now tracks tree as a single canonical boolean (`ready=true/false`) and does not orchestrate `touch tree` sends. Serverside policy reads tree state for diagnostics only, `touch tree` emergency queue attempts are denied with `tree_state_only`, and package-side `Tree auto` behavior is reduced to line-based state updates (`You touch...` => false, `You may utilise...` => true).
- **Occultism simulacrum/heartstone clean-line echo fix (April 11, 2026)** — `Yso system.xml` triggers `Simulacrum dusted` and `Heartstone dusted` now prepend a newline before their `cecho` notices so they print on a clean line instead of bleeding onto combat text. `modules/Yso/xml/vitals_stones.lua` now routes probe echoes through `Yso.util.cecho_line(...)` (with newline fallback) for the same clean-line behavior.
- **Fool hunt stale-queue cancellation hardening (April 10, 2026)** — Occultist Fool now tracks pending self-cleanses separately from live cooldown, stamps cooldown only on actual self-use, and cancels stale pending Fool queues only when lane ownership still matches the pending Fool token. Failed `CLEARQUEUE` attempts now fail closed (pending/hold state is retained), and raw queue writes invalidate lane ownership metadata so stale-cancel checks do not trust outdated ownership records.
- **Occultist route-placeholder cleanup (April 10, 2026)** — removed dead `modules/Yso/Combat/routes/bash.lua` auto-wrapper and replaced `modules/Yso/Combat/routes/limb.lua` + `limb_prep.lua` with explicit deprecated route stubs that expose lifecycle hooks/route contract and fail closed with a clear "not implemented" warning until real limb strategies are implemented.
- **Occultist helper-surface trim + route-localization (April 10, 2026)** — `modules/Yso/Combat/routes/occ_aff.lua` now owns its cleanse/burst/convert decision logic directly instead of delegating through `Yso.occ.*` helper wrappers. `offense_helpers.lua` now keeps only shared phase state helpers (`set_phase/get_phase`) and removes route-only exports (`cleanse_ready`, `ent_for_aff`, `burst`, `convert`, `phase`, `pressure`, `firelord`, `ent_refresh`). Regression tests were updated (`test_loyals_bootstrap_readaura.lua`), XML mirrors were refreshed, and `Yso system.xml` was rebuilt.
- **Softlock gate phase-flow install fix (April 10, 2026)** — `modules/Yso/Combat/occultist/softlock_gate.lua` no longer emits a false startup warning when `Off.try_kelp_bury` is absent in the modern offense stack. It now installs through `Off.install_softlock_gate()` with phase-wrapper fallback (`Off.phase`) and compatibility `try_kelp_bury` shim behavior. `modules/Yso/xml/sightgate.lua` now calls `Off.install_softlock_gate()` after SightGate loads so late-bound phase hooks attach reliably. Softlock gate regression tests were updated (`tests/test_softlock_gate.lua`), XML mirrors were refreshed, and `Yso system.xml` was rebuilt.
- **`occ_aff` convert-phase routing regression fixed (April 10, 2026)** — `modules/Yso/Combat/routes/occ_aff.lua` now delegates convert/finish EQ selection through `Yso.occ.convert(...)` (with local fallback) and prevents the generic readaura fallback from pre-empting convert/finish phases. This restores convert-path helper execution expected by regression tests (`test_loyals_bootstrap_readaura.lua`) while preserving readaura behavior in non-convert phases. XML mirrors were refreshed and `Yso system.xml` was rebuilt after the patch.
- **Route send-ack hardening + dead-code cleanup (April 8, 2026)** — Magi `focus`/`magi_group_damage` and Occultist `group_damage`/`party_aff`/`occ_aff` no longer advance send-state directly inside `attack_function()` when the shared payload-ack bus is available; they now latch through `Yso.locks.note_payload()` callbacks (with local fallback when the ack bus is absent). `queue.commit()` now marks payloads as fired via `Yso.locks.note_payload()`, `api.lua` now forwards confirmed payload callbacks to `party_aff`, `occ_aff`, and Magi `focus`, and hardcoded `&&` joins in Occultist side routes were normalized to the configured command separator. Removed unreferenced helpers from `group_damage.lua` and `party_aff.lua`.
- **Occultist aff-loop loyals/pacing hotfix (April 7, 2026)** — `occ_aff.lua` now exposes `A.S.loyals_hostile(...)` compatibility checks, updates hostile state through `Yso.set_loyals_attack`, sends configured passive command on loop-off when loyals are active, and blocks loop ticks while local waiting is active to reduce repeated re-queue spam.
- **`occ_aff` repeat-queue fix (April 6, 2026)** — Fixed duel-route requeue stalls by clearing lane ownership after successful `occ_aff` sends in `modules/Yso/Combat/routes/occ_aff.lua` (mirrored to `modules/Yso/xml/occ_aff.lua`). This restores repeated same-command loop pressure (for example repeated `instill ... with healthleech`) instead of getting suppressed as unchanged. Added regression test: `Ysindrolir/Occultist/tests/test_occ_aff_loop_requeue.lua`.
- **Bug-check run fixes (April 6, 2026)** — Fixed `occ_aff` local waiting semantics in `modules/Yso/Combat/routes/occ_aff.lua` (route-local wait gate + timer clear) and fixed Magi `freeze_step_done` reporting in `Magi/magi_group_damage.lua` by sourcing explain state from effective route state. All 10 Lua tests now pass; mirrors and `Yso system.xml` were rebuilt/synced.
- **`occ_aff` thin-loop refactor (audit-safe)** — `modules/Yso/Combat/routes/occ_aff.lua` now runs a thin, phase-driven loop (`open -> pressure <-> cleanse -> convert -> finish`) with strict local wait/dedup state, guarded convert EQ path, target-side enlightened finish detection, and cleanse attend precedence over pressure fillers.
- **Shared `Yso.occ.*` phase state helpers normalized** — helper exports were reduced to shared phase-state ownership (`set_phase/get_phase`), while route-specific behavior now lives directly in `occ_aff`.
- **NDB quick-who city count formatting restored** — `Legacy V2.1.xml` `Legacy.NDB.qwc()` city headers now print count parentheses as plain `(N)` instead of escaped `\(N\)`, removing visible backslashes from quick-who output while preserving existing alignment and color logic.
- **Occultist duel route renamed to `occ_aff`** — canonical duel route/module now lives at `modules/Yso/Combat/routes/occ_aff.lua` with XML mirror `modules/Yso/xml/occ_aff.lua`; route id/namespace are now `occ_aff` while `occ_aff_burst` remains a compatibility alias for existing toggles and references.
- **Legacy Occultist basher ATTEND opener** — `Legacy Basher V2.1.xml` now tracks denizen target health from `gmcp.IRE.Target.Info.hpperc` and auto-queues `attend @tar` + configured separator (`Yso.sep` / `Yso.cfg.pipe_sep`, fallback `&&`) + `cleanseaura @tar` as the first Occultist bashing action on a new denizen target at `>=100%` HP, then re-queues the same ATTEND->CLEANSEAURA denizen opener when that target drops below full and later returns to `>=100%`; opener state resets on hunt-off and kill transitions.
- **Legacy party target-follow disabled** — `Legacy V2.1.xml` no longer auto-follows `(Party): ... "Target: ..."` lines via the `Party Target Follow` trigger. Target-call authority is now expected to come from the dedicated `Target caller.xml` package.
- **Occultist aff-burst route retuned** — Mana-bury pressure now prioritizes `asthma -> paralysis/slickness hold -> healthleech -> manaleech`, then applies `disloyalty` post-manaleech with `anorexia` as a late fallback only. Deaf-down pressure now pairs `command chimera` with an EQ filler/missing aff while chimera-pool mentals are still open, and the route no longer includes the `abdebug` screen/alias helpers.
- **Domination Feed tracking added** — `Yso.dom.feed` now exposes `feed_ready()`, `feed_active()`, and `feed_remaining()` plus cast/ready/destroyed update helpers. The Domination trigger folder in `Yso system.xml` now echoes feed active, feed ready, and the destroyed entity in Domination style, and cooldown-line parsing (`Domination feed: ...`) updates state as a fallback.
- **Unified self-cleanse module** — Bloodboil (Magi) and Fool (Occultist) share the cureset-keyed PvP configuration architecture. Tree is now state-tracking only and execution is left to Achaea serverside curing.
- **Bloodboil hunt threshold lowered** — `min_affs_hunt` reduced from 4 to 2 so bloodboil fires earlier during hunting.
- **Bloodboil PvP path** — `should_bloodboil()` no longer hard-gates on `cureset == "hunt"`. When PvP is enabled, it looks up per-cureset thresholds with softlock override support.
- **Fool hunt threshold lowered** — `min_affs_hunt` reduced from 3 to 2 for earlier defensive cleansing while hunting.
- **Fool per-cureset PvP thresholds** — `_min_affs_for_current_set()` now checks `Legacy.Fool.pvp.curesets[curset]` before falling back to `min_affs_default`.
- **Tree state tracker module** — `Yso.tree` now tracks readiness from game lines only (`touch` -> false, `may utilise` -> true), and no longer sends tree commands. Command `lua Yso.tree.status()` reports state; `lua Yso.tree.set_auto(...)` is retained as a compatibility no-op notice.
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
- Occultist combat routes including `occ_aff` (legacy alias: `occ_aff_burst`), `group_damage`, `party_aff`, and the shared `parry` module.
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
- **April 16 bug-check sync** — Fixed one export-manifest mirror drift pair (`occ_aff` source -> xml mirror) and rebuilt `mudlet packages/Yso system.xml`; post-sync syntax/tests/XML validation all pass.
