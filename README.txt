Yso Systems Workspace
=====================
Last updated: April 10, 2026

This root README is now a workspace snapshot rather than a changelog.
Class-specific detail lives in the class folders.

Current fixes
-------------
  Occultism simulacrum/heartstone clean-line echo fix (April 11, 2026) --
  Yso system.xml trigger scripts "Simulacrum dusted" and "Heartstone dusted"
  now prepend a newline before cecho output so the reminder text lands on a
  clean line instead of bleeding into combat text. modules/Yso/xml/
  vitals_stones.lua now routes probe echoes through Yso.util.cecho_line()
  (with newline fallback) for the same clean-line behavior.

  Fool hunt stale-queue cancellation hardening (April 10, 2026) -- Occultist
  Fool now tracks pending self-cleanses separately from live cooldown, stamps
  cooldown only on actual self-use, and cancels stale pending Fool queues only
  when lane ownership still matches the pending Fool token. Failed CLEARQUEUE
  attempts now fail closed (pending/hold retained), and raw queue writes now
  invalidate lane ownership metadata so stale-cancel checks do not trust stale
  ownership records.
  Occultist route-placeholder cleanup (April 10, 2026) -- removed dead
  modules/Yso/Combat/routes/bash.lua auto-wrapper and replaced
  modules/Yso/Combat/routes/limb.lua + limb_prep.lua with explicit deprecated
  route stubs that expose the route contract/lifecycle hooks and fail closed
  with a clear "not implemented" warning until real limb strategies land.
  Occultist helper-surface trim + route-localization (April 10, 2026) --
  modules/Yso/Combat/routes/occ_aff.lua now owns cleanse/burst/convert decision
  flow directly instead of calling route-only Yso.occ helper wrappers.
  modules/Yso/Combat/occultist/offense_helpers.lua now keeps only shared phase
  state helpers (set_phase/get_phase) and drops route-only exports:
  cleanse_ready, ent_for_aff, burst, convert, phase, pressure, firelord,
  ent_refresh. Updated regression coverage in:
  Ysindrolir/Occultist/tests/test_loyals_bootstrap_readaura.lua.
  XML mirrors were refreshed and Yso system.xml was rebuilt.

  Softlock gate phase-flow install fix (April 10, 2026) --
  modules/Yso/Combat/occultist/softlock_gate.lua no longer emits a false
  startup warning when Off.try_kelp_bury is absent in the modern offense
  stack. The module now exposes Off.install_softlock_gate(), falls back to a
  phase wrapper (Off.phase), and supplies a compatibility try_kelp_bury shim.
  modules/Yso/xml/sightgate.lua now calls Off.install_softlock_gate() after
  SightGate loads so late-bound phase hooks attach reliably. Updated regression
  coverage in Ysindrolir/Occultist/tests/test_softlock_gate.lua. XML mirrors
  were refreshed and Yso system.xml was rebuilt.

  Route send-ack hardening + dead-code cleanup (April 8, 2026) --
  Magi focus/magi_group_damage and Occultist group_damage/party_aff/occ_aff
  no longer advance send-state directly in attack_function() when the shared
  payload-ack bus is present; they now latch from Yso.locks.note_payload()
  callbacks (with route-local fallback when no ack bus is available). Core
  queue.commit() now marks fired payloads through Yso.locks.note_payload(),
  api.lua now forwards confirmed payload callbacks to party_aff, occ_aff, and
  Magi focus, hardcoded && joins in side routes now use configured separator,
  and unreferenced helper code was deleted from group_damage/party_aff routes.

  occ_aff repeat-queue fix (April 6, 2026) -- modules/Yso/Combat/routes/occ_aff.lua
  now clears queue lane ownership after successful sends (mirrored in
  modules/Yso/xml/occ_aff.lua). This restores repeated same-command loop
  pressure (for example repeated instill healthleech) instead of being
  treated as unchanged and silently stalling. Added regression test:
  Ysindrolir/Occultist/tests/test_occ_aff_loop_requeue.lua

  occ_aff thin-loop refactor (audit-safe) -- modules/Yso/Combat/routes/occ_aff.lua
  now runs a thin phase machine (open -> pressure <-> cleanse -> convert ->
  finish) with local-only wait/dedup state, convert-path phase guards,
  target-side enlightened finish detection, and cleanse attend precedence.

  Shared Yso.occ helper surface normalized -- offense_helpers.lua now exposes
  only shared phase-state ownership helpers (set_phase/get_phase). Route-local
  cleanse/burst/convert behavior lives directly in occ_aff.

  NDB quick-who city count formatting restored -- Legacy V2.1.xml
  Legacy.NDB.qwc() city headers now print plain (N) instead of escaped
  \(N\), removing visible backslashes while preserving existing alignment
  and city-color formatting.

  Occultist duel route renamed to occ_aff -- Canonical duel route/module now
  lives at modules/Yso/Combat/routes/occ_aff.lua with XML mirror
  modules/Yso/xml/occ_aff.lua; route id/namespace are now occ_aff while
  occ_aff_burst remains a compatibility alias for existing toggles/references.

  Legacy Occultist basher ATTEND opener -- Legacy Basher V2.1.xml now uses
  gmcp.IRE.Target.Info.hpperc for denizen HP gating and auto-queues
  attend @tar + configured separator (Yso.sep / Yso.cfg.pipe_sep, fallback &&)
  + cleanseaura @tar as the first Occultist bashing action on a new denizen
  target at >=100% HP, then re-queues the same ATTEND->CLEANSEAURA denizen
  opener when that target drops below full and later returns to >=100%. Opener
  state resets on hunt-off and kill transitions.

  Occultist aff-burst route retuned -- Mana-bury pressure now prioritizes
  asthma -> paralysis/slickness hold -> healthleech -> manaleech, then applies
  disloyalty post-manaleech with anorexia as a late fallback only. Deaf-down
  pressure now pairs command chimera with an EQ filler/missing aff while
  chimera-pool mentals remain open, and abdebug screen/alias helpers were
  removed from this route.

  Domination Feed tracking added -- Yso.dom.feed now exposes feed_ready(),
  feed_active(), and feed_remaining() plus cast/ready/destroyed update
  helpers. The Domination trigger folder in Yso system.xml now cechos feed
  active, feed ready, and the destroyed entity in Domination style, and
  cooldown-line parsing (Domination feed: ...) updates state as fallback.

  Unified self-cleanse module -- Bloodboil (Magi), Fool (Occultist), and
  Tree Tattoo (universal) now share a cureset-keyed PvP configuration
  architecture. PvP is scaffolded with per-cureset thresholds but disabled
  by default until tuned.

  - Bloodboil hunt threshold lowered from 4 to 2.
  - Bloodboil PvP path: no longer hard-gates on cureset=hunt; looks up
    per-cureset thresholds with softlock override when PvP is enabled.
  - Fool hunt threshold lowered from 3 to 2.
  - Fool per-cureset PvP thresholds via Legacy.Fool.pvp.curesets table.
  - New Tree Tattoo auto-touch module (Yso.tree): 14s cooldown tracking,
    paralysis gate, cureset-keyed thresholds, auto-fires on GMCP vitals
    and cooldown-ready line.
  - Devtools: ytest sc/selfcleanse shows all three abilities. ytest tree
    and ytest fool also available.

  Magi route bug sweep (16 bugs) -- Critical: on_send_result payload format
  mismatch caused route to get stuck at freeze step. High: template.last_payload
  shape normalized. Medium: explain() no longer mutates state, queue commit
  failure now marks pending, freeze check no longer preempts postconv kill
  window, dissonance confidence properly resets on clear/reset. Low: dead code
  removed, eq_ready or-chain fixed, nil-slot guards added, gsub leaks fixed.

  Full workspace bug audit (Bugs 15-39) -- 25 new bugs found and fixed across
  canonical Lua, XML mirrors, standalone XML scripts, and Yso system.xml.
  See bug_audit_fixes.txt for the complete technical log.

  Critical fixes:
    - mudlet.lua limb-hits event handler was missing _event parameter;
      all arguments were shifted by one, breaking the entire limb bridge.
    - entourage_script.lua divided getEpoch() by 1000, producing a 1970-era
      timestamp. Entity staleness checks always saw the entourage as stale.

  High fixes:
    - api.lua Yso.pause_offense() referenced _now() outside its scope.
    - api.lua _ak_now() returned raw getEpoch() without ms normalization.
    - Magi peer loader failed to strip @ prefix from debug.getinfo source.

  Medium fixes:
    - wake_bus pcall status confused with emit return value.
    - Duel challenge name patterns used lowercase "you" (Achaea outputs "You").
    - Aeon entropy compel path was dead code (required _bal_ready after return).
    - offense_driver _now() lacked pcall; entity pool had wrong slime mapping;
      _mark() used inline clock instead of _now().
    - offense_helpers used "worms" key instead of "healthleech".
    - entity_registry target_valid override silently ignored explicit false.
    - hinder _now() clock source mismatched H.collect() clock.
    - ak_legacy_wiring _akwire_now() returned raw getEpoch().
    - magi_route_core build_snapshot ternary ignored explicit false.

  Low fixes:
    - sightgate captured Yso.queue at load time (nil if queue loads later).
    - pronecontroller chimera commands queued under eq instead of entity lane.
    - aura_parser unguarded affstrack access; empty else on cold-start.
    - yso_list_of_functions orphaned string outside any subtable.
    - magi_group_damage magma category/stage mismatch.
    - magi_vibes _now() missing ms normalization.
    - magi_focus embed dissonance fallback failed on empty last_target.

  Trivial: dead postconv call removed; magi_reference _res_now() fixed.

  XML mirrors synced with canonical sources -- all bug fixes from the canonical
  Lua modules (Bugs 3, 6, 8, 10-13 + aurum bucket + Bugs 15-39) are now
  applied to the Mudlet-facing XML mirror copies under xml/. Both canonical
  and XML surfaces match.

  Escape button separator ownership fixed -- yso_escape_button.lua no longer
  initializes global Yso.sep to ";;". It now inherits Yso.sep/Yso.cfg and
  falls back to "&&", so load order cannot override the canonical separator.
  Its _now() helper also normalizes millisecond getEpoch() values.

  Occultist offense is now alias-owned end to end. Shared send memory lives in
  offense_state.lua, and the old orchestrator is no longer part of the active
  route pipeline.

  The wake bus now retries staged queue commits on lane wakes. Manual lane
  aliases such as cleanse can queue while EQ is down and flush on reopen.

  Queue-backed live DRY sends now acknowledge Magi group-damage emits through
  the shared Yso.locks.note_payload() callback path, so route state advances
  without manual hook simulation.

  Shared [Yso] mode echoes now report only real mode/route changes, while
  class-owned loop toggles stay on [Yso:Magi] and [Yso:Occultist] without
  duplicate route-state spam.

  The stale generic package:
    Ysindrolir/mudlet packages/Devtools.xml
  has been retired. Unified class devtools now live at:
    Ysindrolir/mudlet packages/YsoDevtools.xml

  The shared XML exposes class-segregated self-cleanse testers:
    Magi      ytest bloodboil snap|fire|debug|auto
    Occultist ytest fool snap|fire|debug

  Export artifacts were refreshed from the canonical workspace sources,
  including Yso system.xml and the wake-bus/queue mirrors that feed it.

  team dam is now class-sensitive. Occultist keeps the existing team-damage
  route, while Magi uses a sibling Magi route that stays freeze-first:
    horripilation -> freeze baseline -> mixed water/fire pressure
  The Magi side still preserves mudslide / emanation water / glaciate windows,
  but now opens a fire branch from AK frozen/frostbite state into magma,
  firelash, conflagrate, and fire emanation pressure.

  Magi routes now also share a Magi-only chassis helper:
    Yso.off.magi.route_core
  and Magi combat includes a direct duel route:
    focus
  It builds four-element moderate resonance plus Dissonance pressure into
  convergence, then shifts into a soft destroy / Fulminate / burst overlay.

Documentation map
-----------------
  Ysindrolir/Occultist/README.txt
    Occultist architecture, routes, aliases, export notes, and current status.

  Ysindrolir/Magi/README.txt
    Magi-specific notes, helper files, and current package status.

  Ysindrolir/Occultist/modules/Yso/xml/README_EXPORT_ONLY.txt
    Canonical-vs-exported file notes for the Occultist package.

Workspace layout
----------------
  Ysindrolir/Occultist/
    Canonical Occultist source, route logic, integration modules,
    and export inputs for Yso.

  Ysindrolir/Magi/
    Magi-specific helpers and class-local package notes.

  Ysindrolir/mudlet packages/
    Exported Mudlet packages, including:
      Yso system.xml
      AK.xml
      Yso offense aliases.xml
      limb.1.2.xml

Notes
-----
  Yso system.xml is rebuilt from the Occultist source tree.
  Magi team damage now resets fresh targets through:
    horripilation -> freeze baseline -> branch reconsideration
  and then mixes water-side and fire-side salve pressure from AK frozen,
  frostbite, scalded, aflame, and conflagrate state plus Yso resonance.
  Magi focus now stays in the same route/debug family, uses live resonance
  plus Magi-local Dissonance tracking, reopens freeze if frozen or frostbite
  drops, revisits bombard when its outputs or Air/Earth progress are missing,
  and casts convergence immediately once all four elements are moderate and
  Dissonance reaches stage 4.
  AK scalded handling in this workspace now assumes 20s instead of 17s for the
  current Magi paths.
  The packaged Djinn present trigger now immediately sets:
    Yso.elemental_lev_ready = true
  so levitate readiness matches the live summoned-elemental state.
  Crystalism resonance notices now echo from the Magi trigger folder, and
  energise also exposes a separate consumable state helper for personal aliases
  without reusing the heal-burst Yso.magi.energy flag.
  AK.xml package remediation now keeps classlock resolution inside AK instead
  of branching on old WSys/SVO ownership, restores the live Pariah heartbeat
  callback, and corrects several salve/additive bookkeeping bugs. The reported
  earworm duplicate tree-cure line remains intentionally unchanged until the
  real cure text is confirmed from logs.
  Yso helper remediation now uses wall-clock inhibit fallback timing when
  getEpoch is unavailable, reads target deaf/blind state from affstrack.score,
  honors ents.slickness in SightGate, and no longer counts self-aeon in the
  ProneController softscore list.
  AK.xml is maintained separately and may also carry compatibility patches.
  Root-level docs should stay class-agnostic now that this workspace supports
  more than one class.

Syncing with OneDrive Desktop
-----------------------------
  The "Yso systems" folder on your Desktop is synced by OneDrive.
  sync_workspace.ps1 mirrors files between the git clone and that
  Desktop folder so changes flow in both directions.

  First-time setup:
    1. Clone the repo OUTSIDE OneDrive (e.g. C:\repos\Yso).
       OneDrive lock-file conflicts can corrupt .git internals.

         git clone https://github.com/Aeden15/Yso.git C:\repos\Yso

    2. Make sure "Yso systems" exists on your Desktop.  The script
       auto-detects common OneDrive Desktop paths such as:
         %USERPROFILE%\OneDrive\Desktop\Yso systems
         %USERPROFILE%\Desktop\Yso systems
       Pass -DesktopPath explicitly if yours differs.

  Push repo changes to the Desktop:
    cd C:\repos\Yso
    .\sync.cmd push            # repo -> Desktop
    .\sync.cmd push -DryRun    # preview only

  Pull Desktop edits back into the repo:
    cd C:\repos\Yso
    .\sync.cmd pull            # Desktop -> repo
    git diff                   # review
    git add -A && git commit -m "sync from desktop"
    git push

  Execution policy note:
    If calling sync_workspace.ps1 directly gives a "running scripts is
    disabled" error, use sync.cmd instead — it passes -ExecutionPolicy
    Bypass automatically.  Or unlock .ps1 scripts for your user once:

      Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

  sync.cmd now prefers PowerShell 7 (pwsh) when it is installed and falls back
  to Windows PowerShell otherwise. The script text is ASCII-safe so either
  shell can parse it cleanly.

  What gets synced:
    Repo  Ysindrolir/         <->  Desktop  Yso systems/Ysindrolir/
    Repo  README.md/.txt      <->  Desktop  Yso systems/README.md/.txt

  Git-only files (.git/, .gitignore, etc.) are excluded automatically.
  - Fool basher preemption: eligible Fool uses clear Legacy basher
    freestand work before queueing and suppress fresh basher attack-package
    requeues until the Fool self-use line or a timeout. Prone still blocks Fool
    before any queue clearing and remains visible in debug/status output.
