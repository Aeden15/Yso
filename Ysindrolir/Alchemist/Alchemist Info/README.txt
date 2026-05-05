Alchemist workspace notes
=========================
Last updated: May 5, 2026

Mudlet: routes and aliases (e.g. adam, aduel) ship in Ysindrolir/mudlet packages/
Yso system.xml. Day-to-day operation is toggles/aliases in Mudlet, not repo
require() or path bootstrapping. Optional Ysindrolir/scripts/export_yso_system_xml.ps1
re-embeds split-layout Lua into the package when needed.

Queue payload update - May 1, 2026
----------------------------------
- Normal temper pressure uses one configurable class queue payload:
    temper <target> <humour>&&evaluate <target> humours&&educe <metal> <target>&&wrack/truewrack ...
- Instant-kill branches keep a separate clear-style queue verb and default to
  addclearfull for precise execution.
- The live Physiology evaluate-count trigger colourizes humour/count lines
  without changing humour state tracking.

Aurify pressure/corruption update - May 2, 2026
-----------------------------------------------
- Aurify route pressure now uses sticky weighted humour focus (minimum focus
  floor before rotation) instead of hard forcing a tiny fixed affliction set.
- BAL pressure prefers humour-form wrack/truewrack commands where legal and is
  not blocked just because EQ is unavailable.
- EQ lane is flexible and ordered:
  aurify -> educe copper -> educe salt -> vitrify -> phlogisticate ->
  situational silver/lead -> educe iron fallback.
- Educe sulphur is not treated as offensive mana-path logic in Aurify route.
- Homunculus corruption success now matches the live channeling line, lost line
  clears state, and corruption timers are token-guarded to suppress stale recast
  echoes on target/reset/route cleanup.
- Standardized corruption cechos:
  [PHYSIOLOGY:] <target> IS CORRUPTED! 45s TO GO!
  [PHYSIOLOGY:] RECAST CORRUPTION!
- Ginger/antimony lines now dirty humour intel and wake routes for fresh
  evaluate humours rather than guessing a humour decrement.

Wrack/truewrack legality update - May 2, 2026
---------------------------------------------
- Wrack legality is now slot-based:
  - explicit affliction args are legal even when the source humour is
    untempered,
  - humour-keyword args require effective temper >= 1.
- Truewrack evaluates each slot independently, so mixed legal slots are allowed
  (for example, tempered humour keyword + explicit affliction from an
  untempered pool).
- Same-payload staged tempering contributes to effective humour count during
  planning only.
- Paralysis remains special and requires effective sanguine >= 2.
- The redundant ^bleed$ user alias was removed from Yso system.xml.

Formulation policy updates
--------------------------
- Formulation alerts now use the standard colorized prefix:
  [FORMULATION:]
- fchart opens a display-only Formulation chart window using the same prefix
  style.

- Reserved permanent phial roles:
  Phial658898 -> Endorphin slot
  Phial475762 -> Enhancement slot
  third permanent phial (Months = --) -> offensive gas flex slot

- Reserved-role mismatch is reminder-only:
  no auto-empty and no auto-correction.
  Reminder format includes:
    Use EMPTY PHIAL#### when ready.

- Amalgamate helper flow is role-aware and safety-gated:
  resolve reserved role -> inspect live phiallist -> allow only when the
  reserved destination is the unique empty phial -> send AMALGAMATE <compound>
  -> refresh phiallist for reconciliation.

- Unsafe Amalgamate states are blocked:
  multiple empty phials, wrong occupied reserved slot, or stale/unknown
  phiallist state all refuse to send.

- Offensive gas flex pool default:
  Corrosive, Incendiary, Devitalisation, Intoxicant, Vaporisation,
  Phosphorous, Monoxide, Toxin, Concussive
  (Halophilic excluded)
- The fchart chart uses Vaporisation for flooded/iced room removal and does
  not add Caustic unless that skill appears in the reference later.

- Alteration/value-adjustment helpers support explicit phial IDs
  (for example: PHIAL658898 targets).

Behavior expectations
---------------------
- Alteration remains the enhancement/dilution/value-adjustment layer.
- Amalgamate remains compound-driven:
    AMALGAMATE <compound>
- Wield/throw/imbibe usage remains compound-name driven.
- fchart is lookup-only and does not touch phial crafting, permanent phial
  assignment, compound resolution, or route automation.
- Phiallist remains the live source of truth for current contents.
- Aurification execute checks are EQ-finisher priority and use
  hp <= 60 and mp <= 60.
- Reave execute checks now sit just below Aurification and require
  trusted evaluate intel, humour balance ready, all four humours
  tempered, and no channel-blocking self hinder state.

Route reset repair - April 28, 2026
-----------------------------------
- Group damage, duel, and Aurify now share reset cleanup for start/stop,
  target swap, target clear/slain, and AK reset events without disabling active
  routes.
- Humour cooldown failure now marks humour balance unavailable, clears
  pending/staged class state, and clears the server class queue.
- wrack and truewrack are BAL-lane commands in generic queue inference; educe
  iron remains EQ.
