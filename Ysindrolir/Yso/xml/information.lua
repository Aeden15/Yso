-- Auto-exported from Mudlet package script: Information
-- DO NOT EDIT IN XML; edit this file instead.

--[[
============================================================
Yso / Achaea Curing Overview
============================================================

1. LAYERS & RESPONSIBILITIES
----------------------------

This project treats curing as a stack of four layers:

  • Achaea game server
      - Owns all actual curing actions: SIP, EAT, SMOKE, APPLY, FOCUS, TREE, etc.
      - Owns serverside curing priorities and curingsets.

  • Legacy
      - Purely a serverside-curing controller.
      - Talks to the game using CURING commands to move afflictions and defences up/down the in-game priority ladder.
      - Does NOT implement its own clientside curing; it manipulates serverside.

  • AK1 + AK Tracker
      - Purely PVP opponent tracking.
      - Tracks enemy afflictions and curing behaviour.
      - Used by offense/strategy logic, not by self-curing logic.

  • Yso (this project)
      - Client-side “brain” and API layer.
      - Makes decisions about curing modes, priority swaps, and emergency behaviour.
      - Talks to Legacy + the game using CURING commands, but does not bypass Legacy’s design.
      - For Achaea, we DO NOT use snd() at all: Yso is the only namespace.


2. SERVER CURING BASICS (GAME SYNTAX)
-------------------------------------

Yso assumes Achaea’s built-in curing and healing system is available and that Legacy is configured around it.

Core game commands Yso/Legacy will rely on:

  • Turning curing on/off
      CURING ON
      CURING OFF

  • Using the server healing actions
      SIP <elixir name or vial#>
      EAT <plant/mineral>
      SMOKE <plant> FROM PIPE
      APPLY <salve name or vial#> [TO <body part>]

    These are normally driven by the server’s own curing engine; Yso should not spam these directly when in “serverside mode” (see §4).

  • Managing priorities (afflictions & defences)
      CURING PRIORITY <affliction> <number or OFF>
      CURING PRIORITY DEFENCE <defence> <number or OFF>
      CURING PRIORITY <...mass-setting / list / reset subcommands...>

    Legacy uses these CURING PRIORITY commands as its low-level interface to serverside curing. Yso will call Legacy helpers rather than spamming raw CURING PRIORITY lines directly.

  • Curingsets / profiles
      (Exact syntax is game-side; e.g. CURING SET, CURING LOAD, etc.)
      Legacy may expose its own aliases/macros on top of these; Yso treats those as a black box and only requests “switch to set X” via Legacy wrappers, not by micromanaging each curingset command itself.


3. WHAT LEGACY DOES VS WHAT YSO DOES
------------------------------------

Legacy:
  • Owns all logic for “what does a given priority number mean?”
  • Maintains mapping of afflictions -> priority level for herb, salve, pipe, elixir, focus, tree, etc.
  • Sends CURING PRIORITY commands to the server efficiently (delta-based changes, batching, respecting server rate limits).
  • May provide aliases like:
        LPRIOUP <affliction>
        LPRIODOWN <affliction>
        LSET <profile>
    (Names here are examples; use whatever Legacy actually defines.)

Yso:
  • Does NOT re-implement curing.
  • Reads:
      - Our own afflictions (via GMCP/text and Yso.affs).
      - Enemy afflictions (via AK Tracker).
      - State flags (class, mode, hp%, mana%, etc.).
  • Decides:
      - When to ask Legacy to move certain afflictions up/down in prio.
      - When to request curingset swaps (e.g. “lock defence set vs damage set”).
      - When to request emergency things like “prioritise asthma/aeon/etc. above all else”.
  • Sends:
      - Only higher-level “intent” to Legacy, e.g.:
            Yso.curing.raise("paralysis")
            Yso.curing.lower("sensitivity")
            Yso.curing.use_set("anti_lock")
        Internally, those functions translate into the appropriate CURING PRIORITY / curingset commands that Legacy expects.

Conceptually:

  GAME SERVER  ←  Legacy (CURING PRIORITY, SET, etc.)
                      ↑
                      Yso (decisions / policy)
                      ↑
                   AK Tracker (enemy affs)


4. YSO CURING MODES
-------------------

Yso should operate with an explicit curing mode flag:

  • Yso.cure_mode = "serverside"   (default)
      - Yso assumes the game’s serverside curing is ON.
      - Legacy is allowed to control priorities.
      - Yso DOES NOT send raw curing actions (sip/eat/smoke/apply) on its own.
      - Yso only:
          • asks Legacy to adjust prios/sets;
          • optionally toggles CURING ON/OFF if needed;
          • may send non-standard cures like TREE/FOCUS if you explicitly choose to have Yso do so.

  • Yso.cure_mode = "manual"
      - Optional/testing mode.
      - In this mode, Yso is allowed to send raw curing actions (SIP/EAT/SMOKE/APPLY) directly.
      - In this project, manual mode is considered secondary; the primary architecture is serverside+Legacy.

Suggested user aliases:

  • ^yc on / ^yc off
      - Enables/disables Yso’s overlay logic (without turning game curing off).
  • ^yc mode serverside
  • ^yc mode manual
      - Swaps Yso.cure_mode and prints a status line.
  • ^yc status
      - Echoes:
          - current Yso.cure_mode,
          - whether CURING is ON/OFF,
          - which Legacy profile/set is active,
          - whether AK Tracker is loaded.


5. AK TRACKER IN THIS STACK
---------------------------

AK Tracker and AK1 are used purely for opponent tracking:

  • AK Tracker tracks enemy afflictions and likely curing responses.
  • Yso can read those tables to inform offense and strategy.
  • Yso does NOT use AK Tracker to drive self-curing decisions directly; all self-curing remains a function of:
      - Our own aff tables (Yso.affs),
      - Legacy’s priority configuration,
      - Yso’s own high-level policies.

Example policy usage:
  • If AK Tracker says enemy is a lock-heavy class:
        - Yso may ask Legacy to raise aeon/anorexia/asthma priorities.
  • If AK Tracker sees they’re damage-focused:
        - Yso may swap to a more “hp-heavy” priority profile via Legacy.

But in all cases, AK Tracker never sends curing commands and does not alter our own aff priorities by itself.


6. YSO NAMING CONVENTIONS (Achaea Project)
------------------------------------------

For Achaea, we standardise around the Yso namespace:

  • Aff tracking:
      Yso.affs[affliction_name] = true/false

  • Curing configuration:
      Yso.cure_mode              -- "serverside" or "manual"
      Yso.curing                 -- subtable/module for all curing-related helpers

  • Curing API (examples):
      Yso.curing.raise_aff(aff)        -- ask Legacy to move aff up
      Yso.curing.lower_aff(aff)        -- ask Legacy to move aff down
      Yso.curing.set_aff_prio(aff, n)  -- explicit priority set
      Yso.curing.use_profile(name)     -- switch Legacy/serverside profile
      Yso.curing.emergency(tag)        -- e.g. 'lockpanic', 'damagepanic'

  • Status / debug:
      Yso.curing.status()  -- print current curing mode, profile, summary
      Yso.curing.debug     -- toggle for verbose echoes


7. DESIGN RULES (FOR FUTURE MODULES)
------------------------------------

To keep the Achaea/Yso stack clean and consistent:

  1) Do NOT use snd() anywhere for Achaea.
     - All Achaea logic lives under Yso, Legacy, AK1/AK Tracker, or simple local helpers.

  2) In “serverside” mode, do NOT have Yso send raw SIP/EAT/SMOKE/APPLY lines.
     - If you need special curing behaviour, implement it via Legacy priority changes or curingset swaps first.

  3) Treat Legacy as the single source of truth for how priorities map to behaviour.
     - If Yso needs a different curing behaviour, it should request a new Legacy profile or priority arrangement, not hardcode its own.

  4) Keep AK Tracker strictly opponent-facing.
     - If a function is about our own afflictions or curing, it belongs in Yso (or Legacy).
     - If a function is about enemy afflictions, it belongs in AK Tracker, with Yso merely consuming it.

  5) Document any new curing-related commands or expectations here.
     - When adding new helpers (e.g. TREE timing logic, mass prio swaps, “fitness/dragon/kaido” hooks),
       update this helpfile so future changes are aware of the division of responsibility.]]
