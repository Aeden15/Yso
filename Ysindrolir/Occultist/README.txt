Yso System - Occultist Combat Automation for Achaea (Mudlet)
============================================================
Last updated: April 17, 2026


Current fixes
-------------
  Fool bash anti-spam freshness gate + hunt threshold bump (April 17, 2026):
    fool_logic.lua now fail-closes Fool in bash mode unless self-aff state is
    backed by a fresh gmcp.Char.Afflictions.List snapshot (manual + auto +
    diagnose paths), preventing off-cooldown no-aff ghost fires.
    Hunt Fool threshold is now fixed at:
      4+ current afflictions
    (previously 3+).
    tests/test_fool_basher_preempt.lua now includes stale/fresh GMCP-list
    gating coverage plus 4-aff threshold/timing checks.

  Combined reliability sweep (April 12, 2026):
    Hardened Fool timer safety paths: pending now auto-clears if tempTimer is
    unavailable, and basher-hold generation invalidation now protects against
    stale/orphan timer callbacks.
    occ_aff now clears in-flight fingerprints on emit hard-fail and guards
    delayed waiting-clear timers by fingerprint so stale callbacks cannot wipe
    newer waiting state.
    Added cross-fight reset helpers:
      Yso.queue.flush_staged()
      Yso.hinder.reset()
      Yso.entities.uninstall_hooks()
    and targeting now calls reset hooks on target swap/clear to prevent stale
    staged lanes and writhe lane-block state from leaking between fights.
    Package `Yso system.xml` now guards radianceAlert fire/banner call-sites,
    applies pre-tell string formatting single-evaluation, and includes stricter
    nested guard checks for pulse/occ helper call paths.
    New/expanded regression coverage:
      tests/test_fool_basher_preempt.lua
      tests/test_occ_aff_loop_requeue.lua
      tests/test_reliability_sweep.lua
      tests/test_package_diagnostics.lua

  Fool hunt/bash cureset gate fix (April 12, 2026):
    fool_logic.lua cureset resolution order is now:
      dev override
      Legacy.Curing.ActiveServerSet
      _G.CurrentCureset
      mode fallback
      legacy
    so bash mode no longer forces hunt when a non-hunt cureset is explicitly
    selected.
    In hunt cureset, Fool now requires all of:
      cooldown ready
      balance ready now
      4+ current afflictions
      no hard fail (paralysis/prone/webbed/both arms broken)
    The old permissive 2-aff hunt behavior was removed. Regression coverage in
    tests/test_fool_basher_preempt.lua now includes cureset precedence, hunt
    threshold/timing, and hard-fail blocking checks.

  Occultist occ_aff Sunder-template alignment (April 12, 2026):
    occ_aff now uses the same lane-table route template shape as party_aff and
    group_damage: planner payloads carry lanes + meta, include both
    lanes.entity and lanes.class, pass through Yso.route_gate.finalize, and
    emit via the shared lane adapter path.
    Route-local planner state now tracks waiting/in-flight fingerprints and
    no-send/retry reasons for consistent diagnostics with other Sunder-style
    routes, while keeping the existing affliction decision tree intact.

  Occultist aff-route stall + vitals nil-guard hotfix (April 12, 2026):
    occ_aff now keeps loop ticks continuously reevaluating (matching
    party_aff/group_damage) instead of hard-blocking on local waiting state,
    which removes staged-emit dead-time stalls and keeps fresh payload planning
    active while companion recovery suppression is in effect.
    Companion helper route-active detection now also recognizes:
      occ_aff_burst
      aff
    aliases for consistent one-shot recovery behavior.
    Legacy UI V2.0.xml UI Setup vitals-change math now guards maxhp/maxmp
    percentage arithmetic to prevent repeated gmcp.Char.Vitals nil-value errors.

  Occultist route progression + companion command consistency hotfix (April 11, 2026):
    occ_aff / party_aff / group_damage now strictly suppress loyal-kill opener
    fallback while companion recovery is pending, so loops continue evaluating
    legal EQ/BAL/class actions and do not force stale companion sends.
    Package command surfaces were aligned to loyals syntax:
      order loyals kill
      order loyals passive
    across Yso system.xml (Loyals passive/attack + clock defaults) and
    Yso offense aliases.xml (entattack/entpass).
    Legacy UI V2.0.xml UI Setup now nil-guards EP/WP percentage arithmetic to
    avoid gmcp.Char.Vitals event-handler crashes.

  Occultist companion-control unification + loop-toggle visibility (April 11, 2026):
    Added shared companion helper:
      modules/Yso/Combat/occultist/companions.lua
    Occultist route automation now uses canonical free-lane commands:
      order loyals kill <target>
      order loyals passive
    Hard-failure lines for missing loyal/entourage now route through one-shot
    `call entities` recovery with recall-pending suppression and recovery reset.
    Companion state now invalidates on tumble/starburst/astralform text hooks.
    Loop ON/OFF echoes across occ_aff / party_aff / group_damage now keep:
      [Yso:Occultist]
    in orange with uppercase HotPink wording for better visibility.

  Mind-locking alert trigger added under Miscellaneous stuff (April 11, 2026):
    `Yso system.xml` now includes trigger:
      Mind locking
    in the Miscellaneous stuff folder with regex:
      ^You feel the probing mind of (.+) touch yours\.$
    using `Alarm01.wav` and:
      Yso.radianceAlert.fire(1, who, "MIND LOCKING")

  diagnostic remediation pass (April 11, 2026):
    strict arms-unusable guard in self_aff now skips force-bound when arm-damage
    affs are active, preserving writhe-family lane blocking for true writhe
    cases while avoiding false positives.
    queue commit/install now performs a final pre-send blocked-lane recheck for
    EQ/BAL payloads to close late-tick writhe race windows.
    tree remains Yso state-only (ready true/false); policy keeps touch-tree as
    `tree_state_only` no-send and unchanged line remains informational only.
    baseline capture fallback now supports per-set warning cadence and safe
    no-alias temp handling when `table.deepcopy` is unavailable.
    no-action (stale/non-applicable in current branch): diagnostic IDs #3, #5, #10.

  serverside curing coordinator refactor (April 11, 2026):
    Yso now owns self-affliction truth and broader curing-relevant self state
    through:
      modules/Yso/Core/self_aff.lua
    New serverside curing coordination layers:
      modules/Yso/Curing/self_curedefs.lua
      modules/Yso/Curing/serverside_policy.lua
    Key behavior:
      one base cureset ("default")
      one active class overlay (phase-one: blademaster)
      top-level group override with conservative hysteresis
      8s manual intervention grace
      delta-only prio/profile writes
      emergency queue + tree policy scaffolds
    Loader/bootstrap/export pipeline now includes these modules, and parry +
    escape self-aff reads now prefer Yso-owned tracker over Legacy-first reads.

  helper-surface trim + route-localization (April 10, 2026): occ_aff now owns
  cleanse/burst/convert decision logic directly; offense_helpers now keeps only
  shared phase state helpers (set_phase/get_phase). Removed route-only
  Yso.occ exports:
    cleanse_ready
    ent_refresh
    ent_for_aff
    firelord
    phase
    burst
    pressure
    convert
  Updated regression test:
    tests/test_loyals_bootstrap_readaura.lua

  occ_aff repeat-queue fix (April 6, 2026): the duel aff route now clears
  queue lane ownership after successful sends, so repeated same-command
  pressure can requeue on later ticks instead of being treated as unchanged.
  Canonical route updated:
    modules/Yso/Combat/routes/occ_aff.lua
  Added regression test:
    tests/test_occ_aff_loop_requeue.lua

  occ_aff thin-loop refactor (audit-safe): the duel aff route now stays
  mode-controller owned while using a thin phase flow:
    open -> pressure <-> cleanse -> convert -> finish
  EQ convert logic is phase-gated, cleanse attend/truename keeps precedence,
  finish detection uses target-side enlightened state, and send wait/dedup
  remains route-local (`occ_aff.state.waiting` / `occ_aff.state.last_attack`).

  Shared helper surface for occ_aff under Yso.occ is now minimal:
    set_phase / get_phase

  Active Occultist offense is now alias-owned. The old orchestrator has been
  removed from the live offense path, and shared route-loop send memory now
  lives in:
    modules/Yso/Core/offense_state.lua

  The wake bus now retries staged queue commits before other pulse handlers
  run. This lets staged manual lane sends flush on reopen instead of sitting
  in the queue indefinitely. Live Mudlet validation confirmed that:
    cleanse
  can queue CLEANSEAURA while EQ is down and then drain correctly when EQ
  reopens.

  The stale generic package:
    Ysindrolir/mudlet packages/Devtools.xml
  has been retired. Unified class devtools now live in one XML source:
    Ysindrolir/mudlet packages/YsoDevtools.xml
  This shared XML now carries both Magi and Occultist devtools, segregated by
  class-specific command surfaces under the same package.

  The unified XML includes an Occultist Fool test surface:
    ytest fool snap
    ytest fool fire [manual|auto|diagnose] [force]
    ytest fool debug [on|off|toggle]

  Export artifacts were refreshed from the canonical source tree, including:
    modules/Yso/xml/yso_pulse_wake_bus.lua
    mudlet packages/Yso system.xml

  The first hostile loyals bootstrap in both aff-burst and party-aff now pairs
  an immediate `readaura <target>` snapshot on the same outbound line when EQ
  is available. If EQ is down, the next eligible EQ tick still handles the
  read through the normal planner path.

  `hunt` / `bash` now behave as pure mode switches when you are already in bash,
  so stable entourage state is preserved instead of forcing a fresh `ent` /
  `mask` cycle. `mbash` / `mhunt` remain the explicit manual refresh path.

  Truename persistence now validates the saved blob before calling Mudlet's
  JSON decoder, which suppresses startup spam from corrupted non-JSON files in
  the Mudlet home directory.

  Package remediation updated the Yso helper surfaces that still live under
  modules/Yso/xml:
    yso_target_tattoos.lua now reads affstrack.score for deaf/blind gating
    sightgate.lua now honors ents.slickness before falling back to bubonis
    pronecontroller.lua no longer counts self-aeon in its softscore list
  Core/api.lua also now uses wall-clock time for inhibit fallback timing when
  getEpoch is unavailable, and the rebuilt Yso system.xml now carries those
  fixes forward into the package artifact.


Architecture overview
---------------------
Yso is a modular combat automation system for the Occultist class in Achaea,
running inside Mudlet. It handles offense routing, curing integration,
entity management, and mode switching through shared services plus route-local
automation drivers.

Key components:
  Offense State   - shared route-loop send memory (`last_sent`, lockouts)
  Offense Driver  - compatibility shim over the mode-owned route loop state
  Route Registry  - single source of truth for all valid routes and metadata
  Queue / Emit    - lane-aware command staging (eq, bal, class/entity, free)
  Pulse / Wake    - event bus for balance regain and timed triggers
  Curing Adapters - policy layer over Legacy serverside curing
  Mode System     - bash | combat | party (team syntax: team | teamroute; sub-routes: dam | aff)


Active routes
-------------
  oc_aff          - duel affliction loop (combat mode)
                    mana bury -> cleanseaura -> truename -> utter
  group_damage    - group/team damage loop (team dam)
                    giving spam: paralysis -> asthma -> sensitivity -> haemophilia -> healthleech
                    lane-first sends + opportunistic justice + warp/firelord healthleech conversions
                    slime follow-up is asthma-gated and timered (recast at refresh/end; clear on slime-end text hook, with timeout fallback)
  group_aff       - group/team affliction pressure (team aff)
                    loyals/readaura opener -> deaf gate (attend + chimera) -> unnamable
                    chimera + moon pressure, then cleanseaura -> speed strip -> utter truename
                    tarot-first rule: if bal is ready before entity, emit tarot-only this tick

  route_registry.lua also now carries class-scoped Magi routes such as:
    magi_focus       - Magi duel convergence route (combat mode, Magi only)
    magi_dmg         - Magi duel damage route (combat mode, Magi only)
    magi_group_damage - Magi team damage route (team dam, Magi only)

Mode-to-route mapping:
  combat          -> oc_aff
  team dam        -> group_damage
  team aff        -> group_aff
  bash            -> Legacy bashing (not a Yso route)

Inactive legacy route stubs:
  lock, limb, limb_prep, finisher, bash, clock
  These remain on disk as placeholders or compatibility stubs, but they are
  not part of the active route set.


File layout
-----------
  Ysindrolir/Occultist/
    modules/Yso/
      _entry.lua                    - disk-workspace loader
      Core/
        api.lua                     - canonical core API + emit helpers
        offense_state.lua           - canonical shared alias-loop send memory
        wake_bus.lua                - canonical pulse/wake dispatcher
        queue.lua                   - canonical lane-aware command queue
        modes.lua                   - canonical mode + route-loop ownership
        mode_autoswitch.lua         - canonical automatic mode transitions
        bootstrap.lua               - canonical bootstrap / package.path setup
        target_intel.lua            - canonical per-target state helpers
        predict_cure.lua            - canonical enemy cure prediction
      Combat/
        offense_driver.lua          - compatibility shim over mode state
        parry.lua                   - class-agnostic parry evaluator
        route_interface.lua         - shared route contract
        route_registry.lua          - route metadata registry
        routes/
          occ_aff.lua               - duel aff route
          group_damage.lua          - team damage route
          party_aff.lua             - team aff route (key: group_aff)
        occultist/
          aeon.lua                  - AEON speed-strip module
          domination_reference.lua  - Domination entity reference data
          entity_registry.lua       - entity selector/state tracker
          offense_helpers.lua       - shared Occultist offense utilities
          softlock_gate.lua         - softlock-first wrapper for kelp bury
      Integration/
        ak_legacy_wiring.lua        - curing + AK adapter wiring
      xml/
        *.lua                       - export mirrors + remaining XML-resident scripts
        README_EXPORT_ONLY.txt      - mirror vs canonical notes
    EXPORT_MANIFEST.lua             - canonical source -> xml mirror mapping
  Ysindrolir/
    mudlet packages/
      Yso system.xml                - bundled Mudlet XML package
      AK.xml                        - Legacy AK package with local compatibility patches
      Yso offense aliases.xml       - offense alias package
      limb.1.2.xml                  - limb support package


Canonical vs generated files
----------------------------
Promoted canonical files are edited under:
  modules/Yso/Core
  modules/Yso/Combat
  modules/Yso/Integration

Mirror files under:
  modules/Yso/xml
are generated from the canonical source tree and should be refreshed after
editing promoted modules.

Primary generated package artifact:
  mudlet packages/Yso system.xml


Curing integration
------------------
Yso acts as a policy layer over Legacy serverside curing. It does not bypass
Legacy for cure delivery. The curing adapter layer provides implementations for:

  game_curing_on / game_curing_off  - toggle serverside curing
  raise_aff / lower_aff             - adjust affliction cure priority
  set_aff_prio                      - set a specific priority number
  use_profile                       - switch curingset profile
  emergency(tag)                    - panic handlers

Mode:
  serverside (default) or manual

AK integration mirrors enemy aff tracking through Yso.ak.


Aliases
-------
  ^aff$         - toggle the duel affliction loop (oc_aff)
  ^dam$         - toggle the group damage loop
  ^focus$       - toggle the Magi duel focus route (magi_focus) when playing Magi
  ^mdam$        - toggle the Magi duel damage route (magi_dmg) when playing Magi
  ^hunt$        - switch to bash mode without a noop entourage reset
  ^bash$        - same as hunt
  ^mbash$       - switch to bash mode
  ^mhunt$       - manual bash refresh if already in bash
  ^mode (.+)$   - switch mode (bash | combat | party)
  ^team (.+)$   - team mode / route toggle (aff | dam)
  ^teamroute (.+)$ - set team route directly (aff | dam)

Notes:
  ^aff$ owns oc_aff directly (legacy aliases `occ_aff` / `occ_aff_burst` resolve).
  ^team aff$ selects group_aff support pressure + chimera/tarot sequence.
  cleanse queues CLEANSEAURA through the shared queue path instead of bypassing
  lane staging.


Working notes
-------------
  Edit canonical Lua first, then refresh mirrors, then rebuild packages.
  For queue/debug issues, start by checking:
    route-loop ownership
    wake reasons
    staged queue state
    queue commit / lane reopen behavior

  The live generic Devtools package has been retired from mudlet packages.
  Use the unified shared XML instead:
    ../mudlet packages/YsoDevtools.xml
  That XML now contains both Magi and Occultist devtools. Enable its
  top-level alias group in Mudlet before using the class-specific helpers.
  Fool now hard-preempts Legacy basher freestand work only after it passes
  its mechanical gates. If Fool is prone, it reports that reason and leaves
  the basher queue untouched. When eligible, it clears freestand, queues
  Fool, and suppresses new basher attack-package requeues until the Fool
  self-use line or a timeout releases the hold.
