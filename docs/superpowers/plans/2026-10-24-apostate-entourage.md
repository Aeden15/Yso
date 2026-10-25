# Shared Apostate entourage implementation plan

**Goal:** Give Apostate routes two simple calls for commanding an existing whole entourage, and include the confirmed undeaf behavior.

**Approved behavior:** `Yso.apostate.entourage.attack(target)` sends `order entourage kill <target>`; `passive()` sends `order entourage passive`. Direct balanceless sends, no summoning or pentagram handling, no individual Bloodworms orders. Suppress duplicate successful orders; failed attempts remain eligible for retry and cleanup.

## Tasks

- [x] Add failing helper and route lifecycle tests.
- [x] Implement Apostate/entourage.lua and replace the lock route's creature loop with shared calls.
- [x] Embed the helper before the lock route and update export/test mappings while preserving the fresh XML's unrelated content.
- [x] Verify helper, route, utility, AK tracking, build idempotence, and source/XML parity.
- [x] Sync affected files to the canonical clone named by GIT.md; commit and push origin/main.

## Decisions

- User explicitly included the undeaf conversation during implementation: priority immediately after paralysis, before impatience/asthma; Evileye Sensitivity is preferred, with optional Prefarar delivery.
- A failed sender may have partially transmitted an attack: remember that passive cleanup may be required, but only cache a target after a successful send.
- Existing route automatic stops remain responsible for calling the helper. No new timers or presence tracking are introduced.

## Undeaf details and verification

- The editable giving list now includes undeaf. This is a selection label mapped to AK deaf, never a new score. AK deaf=100 means hearing, deaf=0 means deafness is still up.
- The source setting M.undeaf_delivery defaults to evileye. Setting it to prefarar permits Puncture when undeaf is the first missing choice and stock is available; missing stock or shield falls back to Sensitivity eyes. Puncture takes BAL and waits for its confirmed application.
- Sensitivity from any source strips deafness first, then applies sensitivity on a later hit. The confirmed batch writer and Corrupt provenance now reflect that sequence, including multiple Sensitivity eyes in one batch.
- RED confirmed for absent entourage helper, the new undeaf giving priority, incorrect Evileye Sensitivity outcome, failed Puncture delivery handling, and uncertain entourage target caches. Each regression passed after its corresponding fix.
- Embedded helper/route tests, AK tracking and 15 Shrivel fixtures, Apostate utility/package checks, Legacy prompt, caravan, Kaido and combat safety checks pass. Repeated scoped build is byte-stable. Independent final review reported no actionable findings.

- Late user addition: caravan preparation detection now captures any nonempty area name, including Tir Murann and Quartz Peak, with anchored Perl regex. Twenty positive/negative fixtures pass; action/alarm, unrelated bytes, BOM and repeat-build stability are preserved.
