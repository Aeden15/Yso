Yso System - Occultist Combat Automation for Achaea (Mudlet)
============================================================
Last updated: April 2, 2026


Current fixes
-------------
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
  occ_aff_burst   - duel affliction loop (combat mode)
                    mana bury -> cleanseaura -> truename -> utter
  group_damage    - group/team damage loop (team dam)
                    healthleech + sensitivity + clumsiness + warp/firelord burst
  party_aff       - group/team affliction pressure (team aff)
                    loyals/readaura opener -> deaf gate (attend + chimera) -> unnamable
                    chimera + moon pressure, then cleanseaura -> speed strip -> utter truename
                    tarot-first rule: if bal is ready before entity, emit tarot-only this tick

  route_registry.lua also now carries class-scoped Magi routes such as:
    focus            - Magi duel convergence route (combat mode, Magi only)
    magi_group_damage - Magi team damage route (team dam, Magi only)

Mode-to-route mapping:
  combat          -> occ_aff_burst
  team dam        -> group_damage
  team aff        -> party_aff
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
          occ_aff_burst.lua         - duel aff route
          group_damage.lua          - team damage route
          party_aff.lua             - team aff route
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
  ^aff$         - toggle the duel affliction loop (occ_aff_burst)
  ^dam$         - toggle the group damage loop
  ^focus$       - toggle the Magi duel focus route when playing Magi
  ^hunt$        - switch to bash mode without a noop entourage reset
  ^bash$        - same as hunt
  ^mbash$       - switch to bash mode
  ^mhunt$       - manual bash refresh if already in bash
  ^mode (.+)$   - switch mode (bash | combat | party)
  ^team (.+)$   - team mode / route toggle (aff | dam)
  ^teamroute (.+)$ - set team route directly (aff | dam)

Notes:
  ^aff$ owns occ_aff_burst directly.
  ^team aff$ selects party_aff support pressure + chimera/tarot sequence.
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



