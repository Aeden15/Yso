Alchemist workspace notes
=========================
Last updated: April 22, 2026

Formulation policy updates
--------------------------
- Formulation alerts now use the standard colorized prefix:
  [FORMULATION:]

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

- Alteration/value-adjustment helpers support explicit phial IDs
  (for example: PHIAL658898 targets).

Behavior expectations
---------------------
- Alteration remains the enhancement/dilution/value-adjustment layer.
- Amalgamate remains compound-driven:
    AMALGAMATE <compound>
- Wield/throw/imbibe usage remains compound-name driven.
- Phiallist remains the live source of truth for current contents.
- Aurification execute checks are EQ-finisher priority and use
  hp <= 60 and mp <= 60.
