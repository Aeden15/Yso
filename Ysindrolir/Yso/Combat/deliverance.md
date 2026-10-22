# Enemy Deliverance protection

When your current target begins or completes Deliverance, Yso stops all loaded
automated attack routes, cancels their timers, and clears staged attacks and
server EQ, BAL, class, and free attack queues, including tracked custom queue
types. Your target remains selected.

- `deliverance status` shows the hold and any shutdown failures.
- `deliverance release` removes only the Deliverance hold. Start your chosen
  route again explicitly afterward; previous attacks are never replayed.

Target changes, mode changes, class changes, and ordinary offense-resume actions
do not release this hold. Another player's Deliverance does not activate it.
Curing, defensive actions, and utility actions remain available. Commands already
executed by the server cannot be recalled. The hold is runtime state, not a
persisted setting across client restarts.

Elemental resonance remains owned by AK. The three Mfocus resonance triggers
no longer call retired route callbacks. They report insufficient resonance and
warn when `ak.ai()` prevents AK from updating its resonance measurements; they
do not fabricate levels or restore the old recovery route.

After source edits, run `scripts/export_yso_system_xml.ps1 -CombatSafetyOnly`.
Use `-FocusOnly` separately when changing the Focus route or its generated alias.
Run `scripts/test_combat_safety_package.ps1` to check runtime behavior, source/XML
parity, trigger adapters, AK replay, and preservation of unrelated XML content.
