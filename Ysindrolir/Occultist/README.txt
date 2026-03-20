Yso System - Occultist Combat Automation for Achaea (Mudlet)
============================================================
Last updated: 2026-03-20


Recent READAURA Update
----------------------
Occultist READAURA tracking was tightened on 2026-03-11 so the aura snapshot
matches the defenses this class actually cares about.

Tracked READAURA fields:
  Afflictions:
    blind, deaf
  Defenses:
    cloak, speed, kola, levitation, caloric, frost, insomnia, shield

Pronoun coverage now includes:
  He / She
  They / Their / them
  Fae / Faes / faen

Important scope note:
  mounted and rebounding are not part of the Occultist READAURA snapshot.
  Legacy AK may still have generic triggers for those elsewhere, but they are
  intentionally excluded from the Occultist-specific read set.

Implementation notes:
  Yso system.xml provides fallback READAURA ingestion so AK/Yso state stays in
  sync when stock AK phrasing is too narrow.
  AK.xml now has explicit READAURA coverage for the Occultist-relevant lines
  that previously only lived inside broad Ignore buckets.
  Yso system.xml is rebuilt from the Occultist source tree.
  AK.xml is not rebuilt by the Occultist export pipeline and must be maintained
  separately when READAURA compatibility changes.


Blademaster Spar 3 Follow-up (2026-03-18)
-----------------------------------------
  [fix] occ_aff_burst: free-lane routing now asks the Parry Module for a live
        balanceless parry command and injects it into the affliction loop payload.
        This keeps Blademaster arm-parry swaps inside the route loop instead of
        waiting on prompt-only reevaluation.
  [fix] Parry Module: added a transient Blademaster restore override. When an
        actual damaged-leg restoration cure lands, parry can swap to a healthier
        arm (rerolling ties) until both legs are clean and the character is
        standing again. Explicit debounce added for loop safety.
  [fix] occ_aff_burst: loyals opener now flags the immediate follow-up READAURA
        window before the first payload is built, preventing the opener from
        spending EQ on a normal aff action before the initial aura read.
  [fix] target_intel + AK.xml: enemy herb/mineral cure tracking now treats
        hawthorn/calamine as deaf reopen and bayberry/arsenic as blind reopen.
  [fix] AK.xml: sileris shell-drop tracking is separated from slickness gain;
        the protective coating slough-off line no longer promotes slickness as
        though it were a fresh affliction gain.
  [fix] AK.xml: aura-result echo now forces a clean newline after the [phys|ment]
        display so downstream Occultist cechos do not bleed onto the same line.
  [fix] Legacy V2.1.xml: added a transient Blademaster mobility reprio ladder:
        disrupted > frozen > shivering before first leg damage, then disrupted >
        frozen > damaged leg > shivering once either leg is damaged.
  [fix] group_damage.lua: restored the local _tkey helper before worm/empress
        helpers use it, eliminating the nil global call seen during testing.


Route / Bootstrap Repair (2026-03-20)
-------------------------------------
  [fix] Bootstrap now auto-attempts the workspace `_entry` load once on package
        startup, so no-slot filesystem-managed modules such as `route_registry.lua`
        are present in live Mudlet sessions without requiring a manual
        `lua Yso.bootstrap.entry(true)` bootstrap kick.
  [fix] Live aff-route debugging was verified against the connected Mudlet/Achaea
        session after the bootstrap repair:
        `Yso.Combat.RouteRegistry.resolve('aff') -> occ_aff_burst`
        `yrdebug on aff` works
        `yrdebug off aff` works
  [fix] Devtools route-debug alias handling now treats bare `yrdebug on` /
        `yrdebug off` as usage rather than mis-parsing `on` or `off` as a route.
  [fix] Route metadata is now centralized again through `route_registry.lua`;
        duplicate fallback route tables were removed from `modes.lua` and
        `offense_driver.lua`.
  [fix] `_entry.lua` now records boot failures and emits a one-time boot warning
        summary when modules fail to load, instead of silently swallowing all
        require failures by default.
  [note] The source-side Occultist Devtools export artifact was renamed to
        `Occultist Devtools.xml` / `Occultist Devtools.mpackage` so it is no
        longer easily confused with the live import package at
        `Ysindrolir/mudlet packages/Devtools.xml`.


Architecture Overview
---------------------
Yso is a modular combat automation system for the Occultist class in Achaea,
running inside Mudlet. It handles offense routing, curing integration,
entity management, and mode switching through shared services plus route-local
automation drivers.

Key components:
  Orchestrator    - proposal/arbitration layer kept for shared services and
                    compatibility with proposal-driven routes
  Offense Driver  - policy/route state machine (manual | auto); resolves mode to route
  Route Registry  - single source of truth for all valid routes and their metadata
  Queue / Emit    - lane-aware command staging (eq, bal, class/entity, free)
  Pulse / Wake    - event bus for balance regain and timed triggers
  Curing Adapters - policy layer over Legacy serverside curing (priority/profile control)
  Mode System     - bash | combat | party (with party sub-routes: dam | aff)


Active Routes
-------------
  occ_aff_burst   - Duel affliction loop (combat mode)
                    mana bury -> cleanseaura -> truename -> utter
  group_damage    - Group/party damage loop (party dam)
                    healthleech + sensitivity + clumsiness + warp/firelord burst
  party_aff       - Group/party affliction pressure (party aff)
                    kelp bury + mental build + entity coordination

Mode-to-route mapping:
  combat          -> occ_aff_burst
  party dam       -> group_damage
  party aff       -> party_aff
  bash            -> Legacy bashing (not a Yso route)

Inactive legacy route stubs:
  lock, limb, limb_prep, finisher, bash, clock
  These files remain on disk as legacy placeholders and compatibility stubs, but they are not part of the active route set.


File Layout
-----------
  Ysindrolir/Occultist/
    modules/Yso/
      _entry.lua                    - disk-workspace loader (loads canonical modules + XML legacy in order)
      Core/
        api.lua                     - CANONICAL: core Yso API surface + curing + emit
        orchestrator.lua            - CANONICAL: single-authority offense orchestrator
        wake_bus.lua                - CANONICAL: pulse/wake event dispatcher
        queue.lua                   - CANONICAL: command queue with lane isolation
        modes.lua                   - CANONICAL: mode system (bash/combat/party)
        mode_autoswitch.lua         - CANONICAL: automatic mode transitions
        bootstrap.lua               - CANONICAL: bootstrap / package.path setup
        target_intel.lua            - CANONICAL: per-target state + mana/aff helpers
        predict_cure.lua            - CANONICAL: enemy cure prediction service
        Template.lua                - route template reference
      Combat/
        offense_driver.lua          - CANONICAL: route/policy state machine
        parry.lua                   - CANONICAL: class-agnostic parry evaluator
        route_interface.lua         - CANONICAL: shared route contract (defense_break, anti_tumble)
        route_registry.lua          - CANONICAL: route metadata registry
        routes/
          occ_aff_burst.lua         - CANONICAL: duel aff burst route
          group_damage.lua          - CANONICAL: party damage route
          party_aff.lua             - CANONICAL: party affliction route
        occultist/
          aeon.lua                  - CANONICAL: AEON speed-strip module
          domination_reference.lua  - CANONICAL: Domination entity reference data
          entity_registry.lua       - CANONICAL: entity selector/state tracker
          offense_helpers.lua       - CANONICAL: shared Occultist offense utilities
          softlock_gate.lua         - CANONICAL: softlock-first wrapper for kelp bury
      Integration/
        mudlet.lua                  - Mudlet trigger bridge
        ak_legacy_wiring.lua        - CANONICAL: curing + AK adapter wiring to Legacy
      xml/
        *.lua                       - export mirrors + remaining XML-resident legacy scripts
        README_EXPORT_ONLY.txt      - documents mirror vs canonical distinction
    EXPORT_MANIFEST.lua             - canonical source -> xml mirror mapping (22 entries)
  Ysindrolir/
    mudlet packages/                - sibling package folder used by Mudlet imports
      Yso system.xml                - bundled Mudlet XML package
      AK.xml                        - Legacy AK package with local compatibility patches


Canonical vs Generated Files
----------------------------
22 files are now canonical (edit these, then refresh mirrors):
  Core:     api, orchestrator, wake_bus, queue, bootstrap, modes, mode_autoswitch, target_intel, predict_cure
  Combat:   offense_driver, parry, route_interface, route_registry
  Routes:   occ_aff_burst, group_damage, party_aff
  Occultist: aeon, domination_reference, entity_registry, offense_helpers, softlock_gate
  Integration: ak_legacy_wiring

See EXPORT_MANIFEST.lua for the full canonical -> xml mirror mapping.

Remaining XML-resident legacy (not yet promoted):
  yso_list_of_functions, yso_target, yso_target_tattoos, curebuckets,
  pronecontroller, yso_configs, yso_escape_button, prio_baselines,
  cureset_baselines, fool_logic, priestess_heal, magician_heal,
  devil_tracker, entourage_script, and several reference/utility scripts.
  These are loaded from xml/ and work correctly but are not yet in the
  canonical promotion pipeline.


Curing Integration
------------------
Yso acts as a policy layer over Legacy serverside curing. It does not bypass
Legacy for cure delivery. The curing adapter layer (ak_legacy_wiring.lua)
provides real implementations for:

  game_curing_on / game_curing_off  - toggle serverside curing
  raise_aff / lower_aff             - adjust affliction cure priority
  set_aff_prio                      - set specific priority number
  use_profile                       - switch curingset profile
  emergency(tag)                    - panic handlers:
    lockpanic   - raises paralysis=1, asthma=2
    damagepanic - raises mana=1, health=2
    focuslock   - raises stupidity=1, anorexia=2
    reset       - reloads default priority profile

Mode: serverside (default) or manual.
Serverside mode sends priority/profile commands only.
AK (affstrack) integration mirrors enemy aff tracking through Yso.ak.

Aliases
-------
  ^aff$         - toggle the Sunder-style Occultist duel affliction loop (occ_aff_burst)
  ^dam$         - toggle the Sunder-style group damage loop
    burst        - removed
  ^mbash$       - switch to bash mode
  ^mode (.+)$   - switch mode (bash | combat | party)
  ^par (.+)$    - set party sub-route (aff | dam)
  Notes:
    ^aff$ owns occ_aff_burst directly.
    ^par aff$ selects party_aff support pressure only and does not invoke occ_aff_burst.


Automation Notes (2026-03-17)
-----------------------------
  aff, dam, and party aff are alias-owned loops driven by the shared
  Yso.mode route-loop controller.
  aff toggles occ_aff_burst; dam/gd toggle group_damage; party aff toggles
  party_aff.
  occ_aff_burst is duel-only behind ^aff$; party aff remains a separate support
  route behind ^par aff$.
  Route files now expose payload/reasoning hooks to the controller rather than
  owning their own public start/stop/toggle timer wrapper layer.
  Loop payloads now emit through Yso.queue.emit and the lock-aware readiness layer
  instead of raw route-local sends, so entity lane spends are tracked locally.
  Combined payloads wait on every spent lane (EQ/BAL/entity/free as applicable)
  before reopening, which prevents EQ-only reopen spam when entity balance is
  still cooling down. Mode or route invalidation hard-stops the loop and kills
  its timer.
  propose() returns empty when the route's loop is active so the orchestrator
  does not double-send.

Bug Fixes (2026-03-16)
----------------------
  [fix] occ_aff_burst + party_aff: switched route-local sends to Yso.queue.emit
        so entity commands spend the same local lane state as orchestrated sends.
  [fix] occ_aff_burst + party_aff: wait gating now tracks all spent lanes in a
        payload, preventing resend loops when EQ recovers before entity balance.
  [fix] occ_aff_burst: duel aff routing is isolated from party route selection.
        ^aff$ owns occ_aff_burst and ^par aff$ stays on party_aff support pressure.
  [fix] occ_aff_burst: removed the Blademaster-specific READAURA forcing.
        Once loyals are hostile on the target, the route rechecks READAURA on the
        normal 8s cadence.
  [fix] occ_aff_burst: alias-owned sends now stamp route-local tags into
        Orchestrator.last_sent so _recent_sent-based throttles, including the
        8-second READAURA requery, work in loop mode.
  [sync] XML mirror files were refreshed and mudlet packages/Yso system.xml was
        rebuilt after these route changes.

Export Audit (2026-03-16)
-------------------------
  [fix] rebuild_yso_system_xml.ps1 now distinguishes between three cases:
        legacy-name package items, active no-slot mirrors, and true skips.
  [fix] rebuild_yso_system_xml.ps1 now validates the rebuilt XML in memory
        before writing so a bad replacement cannot leave Yso system.xml
        half-corrupted on disk.
  [fix] Legacy package-name mismatches now rebuild correctly for:
        softlock_gate.lua -> "Softlock Gate"
        yso_occultist_offense.lua -> "Yso.occ.offense"
        hunt_primebond_shieldbreak_selector.lua -> matched by body signature
        because the stored package name is mojibake.
  [note] Active Occultist files that currently have no dedicated script slot in
         Yso system.xml remain filesystem/runtime-managed:
         party_aff.lua, route_interface.lua, route_registry.lua,
         skillset_reference_chart.lua, yso_aeon.lua, yso_predict_cure.lua.
  [del] Deleted obsolete XML-only files from the Occultist tree:
        magi_convergence.lua, magi_resonance.lua, yso_route_registry.lua.
  [doc] README_EXPORT_ONLY.txt now records the package-name drift and no-slot set
        so future rebuilds are easier to audit.

Cleanup (2026-03-13)
--------------------
  [fix] occ_aff_burst: _choose_main_lane picked ONE of EQ/BAL per tick and
        discarded the other. Now sends all available lanes piped together
        (Sunder-style multi-lane payload).
  [fix] occ_aff_burst: _ensure_runtime called from init() on every 0.15s tick;
        moved to one-time call in start_loop() only.
  [del] occ_aff_burst: removed CS.plan_limb stub (limb route leftover),
        AB.loop_enabled legacy compat field, _driver_state() (never called),
        AB._ensure_registered / AB._ensure_runtime debug shims,
        _eq_lane_score / _bal_lane_score / _choose_main_lane (replaced by
        direct multi-lane payload construction).
  [sync] XML mirror (occ_aff_burst.lua) synced after all changes.

Bug Fixes (2026-03-13)
----------------------
  [fix] yso_target: _set_target_via_ak was missing _dispatch_target_set(name) call;
        non-AK target sets (source="offense", "manual", etc.) always silently failed.
        Added the missing dispatch call to match the working _clear_target_via_ak pattern.
  [fix] occ_aff_burst + group_damage: stop_loop unconditionally reset D.state.policy
        to "manual" even when another route had already claimed the auto policy via its
        own start_loop. Now only resets policy if the stopping route still owns it.
  [fix] occ_aff_burst: removed dead Yso.room_has_player references (never defined;
        Yso.target_is_valid already delegates to Yso.room.has via GMCP).
  [fix] occ_aff_burst + group_damage: propose() now returns empty when the route's
        Sunder-style loop is active, preventing the orchestrator from double-firing
        commands alongside the timer-driven loop.
  [fix] Deleted orphan Yso/target.lua wrapper (never loaded by _entry.lua).


Completed Architecture Work (2026-03-11)
----------------------------------------
Phase 1 - Route Matrix Completion:
  [done] Created route registry (single source of truth for all routes)
  [done] Implemented real party_aff route as orchestrator proposal module
  [done] Wired party aff mode to real route in driver + mode system
  [done] Classified 6 deprecated placeholder routes as inactive stubs outside the active route set
  [done] All modes resolve to real implementations

Phase 2 - Curing/Legacy Integration:
  [done] Wired curing adapters to real Legacy/game commands
  [done] Implemented emergency handlers (lockpanic, damagepanic, focuslock, reset)
  [done] Replaced "adapter not yet wired" stubs with working defaults
  [done] AK affstrack integration wired
  [done] Added real curing status/debug inspection:
         Yso.curing.status() - shows mode, game curing, curingset, adapter status, AK bridge, Legacy Prio/Deprio
         Yso.curing.snapshot() - returns machine-readable state table

Phase 3 - Canonical Source Promotion:
  [done] Promoted 10 still-active high-value XML-only modules to canonical Lua:
         api_stuff -> Core/api.lua
         yso_queue -> Core/queue.lua
         yso_modes -> Core/modes.lua
         yso_mode_autoswitch -> Core/mode_autoswitch.lua
         bootstrap -> Core/bootstrap.lua
         yso_target_intel -> Core/target_intel.lua
         yso_predict_cure -> Core/predict_cure.lua
         yso_aeon -> Combat/occultist/aeon.lua
         softlock_gate -> Combat/occultist/softlock_gate.lua
         ak_legacy_wiring -> Integration/ak_legacy_wiring.lua
  [done] Expanded EXPORT_MANIFEST from 9 to 22 entries
  [done] Deleted Yso.Core.targeting; AK-only targeting now lives on AK plus the yso_target bridge
  [done] Updated _entry.lua load order to prefer canonical runtime modules
  [done] Updated README_EXPORT_ONLY.txt with full promotion map

Cleanup (2026-03-11):
  [done] Isolated the active route set from the legacy wrapper/stub files.
  [note] Compatibility wrappers and deprecated route stubs still exist in the committed tree as part of the current hybrid runtime.
  [done] Deleted 5 temporary PowerShell patch scripts (tmp_patch_*.ps1)
  [done] Deleted clock_limb_dry_test.lua and removed the remaining driver-side Yso.occ.clock references
  [done] Deleted 3 .bak backup files
  [done] Removed dead _get_clock() function from driver + XML mirror
  [done] Cleaned remaining clock-route refs from occ_aff_burst, yso_list_of_functions, and offense coordination
  [done] Split root docs into workspace + class-specific README files
