# Simple Airlord Lock Implementation Plan

**Goal:** Put the approved basic AK decisions in a short, complete lock route; preserve automatic Yso delivery and a separate damage route.

**Architecture:** Lock and damage are independent package scripts. Shared Airlord runtime owns balance, observations, pending submissions, queue cleanup, and feedback dispatch. Gauge/Compression remains target-scoped and fresh. Lock keeps Tension-first and relapse-aware booster selection; optional Updraft belongs to damage.

**Authorization:** The chat approved the simplified AK/Yso logic and explicitly requested workspace/XML updates, commit, and push. Work in the requested Desktop edit workspace and commit only this task's files in the canonical clean `main` clone named in GIT.md.

## Implementation
- [x] Add package-level regressions proving lock loads without damage, AK selection, fresh Compression, submission suppression, pause, target/stop cleanup, and separate damage behavior. Run against the old package and observe the isolation failure.
- [x] Extract shared runtime and Compression sources; create short lock and independent damage modules. Retire the combined source and migrate package entries without runtime file loading. Preserve current aliases; route optional Updraft to damage.
- [x] Update scoped build/export/test mappings and workspace documentation. Verify source parity, load order, rebuild idempotence, native Lua syntax, all Airlord regressions, shared combat pause, and export safety. Publish workspace-link validation snapshots.
- [x] Obtain an independent code review, resolve material findings, and synchronize only affected files to the canonical clone. Delivery: commit, push `origin main`, and verify the remote commit after validation.

## Review Focus
- Paused confirmation clocks must not expire while paralysis holds offense.
- An accepted submission is not proof of execution; Compression retries require fresh Gauge information.
- Reset must clear only route-owned commands and invalidate target-specific observations.
- Loading either route alone must not create or require the other route.
- Builders must preserve unrelated package nodes and native load order.

## Verification
Run `test_airlord_lock_package.ps1`, `test_airlord_damage_package.ps1`, `test_combat_pause_package.ps1`, `test_full_export_safety.ps1`, and relevant combat/targeting/workspace-link regressions. Record failures and distinguish environment limitations from product regressions. No live-game verification is implied.

## Results
Lock: 33 checks passed. Existing damage: 25 checks plus independent loading/Updraft passed. Source parity, Lua syntax, native load order, scoped rebuild/migration, shared combat pause, combat safety, targeting, workspace link, scoped export, and full export regression checks passed. Independent review findings were fixed and re-reviewed with no material issues remaining. Workspace-link snapshots were published.

Ruling: preserve unrelated Desktop Stormhammer/targeting edits by building an Airlord-only canonical XML and exporter patch. Add a test-only ScratchRoot parameter after OneDrive XML replacement failures; the complete canonical export suite passes outside OneDrive. No exporter runtime workaround or unrelated source change was introduced.
