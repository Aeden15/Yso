# Yso audit corrections and manual Bloodboil

Approved in conversation: implement the verified audit findings, preserve unrelated
Desktop/GitHub differences, retain all offense pauses until explicit resume, and
deliver on main. Bloodboil is manual-only through the user's boi alias.

## Corrections

- Clear targets consistently through AK and Yso, including inactive server clears;
  remove stale highlights/opponent state and obsolete y-alias validation text.
- Preserve pauses on manual target selection and passive imports. Upgrade an
  already-loaded targeting service without replacing external wrappers.
- Remove automatic Bloodboil decisions, cooldown/EQ gating and trigger callbacks;
  preserve the manual alias, initialization and server-ready/cooldown feedback.
- Fix case-insensitive script deletion caused by the regex overload; stage and
  validate complete exports before atomic publication. Support PackagePath.
- Read actual GMCP balance when shared helpers are unavailable; Dragon explicitly
  rejects known balance-down state before trusting helpers.
- Reopen a rejected Firestorm room attempt only for its outstanding dispatch.
- Isolate strip aliases by Monk/Apostate class.
- Preserve destination newline style in Soulstorm package rebuilds so LF and
  CRLF checkouts produce stable, repeatable output.

## Verification and delivery

Each correction has an observed failing regression followed by a passing one.
Run shared/class Lua tests with the required roots and module paths; supply the
Mudlet yajl diagnostic interface for standalone Alchemist tests without writing
diagnostic files. Validate real embedded AK/Yso interaction and class actions,
package syntax, source parity, full/scoped export idempotence and rollback.

Synchronize only reviewed files and affected XML nodes to the canonical checkout;
preserve unrelated Shikudo controller differences. Review the combined change,
commit and push main, then verify remote HEAD and a clean working tree.

## Limits

Live server timing and Mudlet import behavior require an in-client check. Existing
legacy Lua-version string-escape warnings and stale exporter mapping/documentation
observations are not treated as proven runtime defects or deleted in this change.
