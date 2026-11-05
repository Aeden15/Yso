# Yso maintenance audit — November 4, 2026

This review covered the source/export structure, bundled Mudlet packages, login and reload lifecycle, retained class routes, shared combat gates, and workspace synchronization. Results are local code/test evidence; live authentication and combat were not exercised. The screenshot shows an incorrect-password response but cannot identify which command reached that prompt.

## Confirmed findings addressed

1. **Pre-authentication command emission.** Alchemist formulation sent `phiallist` from TCP connection; curing policy requested `curingset list` and `curing priority list` during package initialization. Shared `Yso.session` readiness now requires fresh character evidence and gates these queries plus Magi equipment discovery. Missing readiness fails closed. User credential sends are untouched.
2. **Legacy callbacks crossing sessions.** Text-login startup scheduled look, settings loading, and curing commands without a disconnect boundary. These actions now use shared readiness and session-generation timers. Its game keepalive is gated too; its existing download behavior remains unchanged.
3. **Monk/build coupling.** Removed 40 source/tool/test files plus Monk runtime folders and class-specific handling in bundled packages. Airlord soar has its own builder; Deliverance has its own builder and minimal retained resource state. All eight original Deliverance entry bodies are pinned by SHA-256 regression fixtures. `Yso.monk.kai` remains deliberately for these preserved callers. Generic limb/affliction support and the venom named monkshood remain.
4. **Deleted files surviving synchronization.** Replaced timestamp-only copying and unrestricted mirroring with content comparison plus explicit retirements. Paths are bounded to the destination; modified retired files block synchronization before copies. Unlisted destination content survives. Local receipts/environment/editor files are excluded.
5. **Inconsistent capability documentation.** Root documentation and the workspace rule now identify Magi, Alchemist, Apostate, Airlord, Dragon manual helpers, and the Deliverance exception consistently. Current operating instructions distinguish source rebuilds, receipt publication, Git delivery, and applying packages in Mudlet.

## Verification and its boundaries

Regression evidence and command outputs are recorded under `.superpowers/login-monk-maintenance/` in this editing workspace.

Final local results:

- **31/31 package regression wrappers pass**, including full/scoped exports, login, retained class routes, combat gates, sync, and Deliverance preservation. The full-export suite was rerun successfully with its new system-temp default after the OneDrive lock.
- **45/45 standalone Lua suites pass** with the documented test-only module path and `yajl` fixture. Package-extracted Airlord/startup fixtures run through their wrappers.
- **10 package XML files parse.** Of 67 changed/new embedded bodies compared with the canonical copy, 66 compile locally; Legacy_Install has a baseline-matching invalid-escape incompatibility with the local compiler and remains an explicit native-validation limit.
- **60 active Yso scripts receive startup/reload behavioral checks; 107 external package scripts receive startup-hook inspection.** The embedded Legacy login paths receive separate behavioral checks.
- AK/Yso local receipts were regenerated and verified byte-for-byte against the current built XMLs. Workspace-link and retirement checks pass after publication.

The targeted startup harness executes active Yso package scripts and their startup/connect/prompt/timer paths, repeated unauthenticated reloads, fresh authentication, and authenticated reloads. Separate Legacy tests cover its exact embedded startup bodies. Other bundled packages were inspected for startup/connection hooks; this is not execution of every game-trigger permutation.

Essential Legacy settings loading and curing restoration retain their remaining delay through an authenticated reload. Old closures stay invalid, and disconnect discards the pending work. Review reproduced the lost-completion failure before this repair; regression verifies eventual settings loading and curing restoration exactly once.

Full/scoped export checks operate on disposable copies and verify source parity, idempotence, unrelated-content preservation, destination isolation, late-failure atomicity, removal persistence, and Deliverance preservation. Existing combat tests exercise route shutdown, paralysis, target clearing, forced/delayed emission, and retained class behavior.

Full-export test copies now default to the system temporary directory. A run in the OneDrive tree encountered a replacement-file lock; the test location change avoids that external lock without weakening exporter atomicity checks.

Local CLI tests use Lua 5.4 with Mudlet mocks. Some older bundled scripts contain escape sequences rejected by that compiler, so whole-package native execution remains a Mudlet validation step. Standalone legacy-source tests also require a module search path and a test-only `yajl` serialization stub; this does not validate serialization or external log output.

The sync fixture runs on PowerShell 7 and Windows PowerShell 5.1, which `sync.cmd` launches. Initial sandbox runs explicitly skipped real junction creation; subsequent canonical-clone verification on the host exercised and passed the real junction protection on both engines. Windows PowerShell 5.1 fixture cleanup uses nonrecursive directory-link deletion. The implementation checks redirecting link properties and allows ordinary OneDrive cloud reparse points. An actual OneDrive-source dry run completed without destination writes.

## Next enhancements, in priority order

### 1. Validate delivery in the real profile

Apply rebuilt AK/Yso through the workspace link while automation is stopped; separately import changed Legacy, Legacy UI/Basher, and limb packages. Restart the Achaea profile to remove old globals/anonymous handlers. Confirm cold login, disconnect during startup, reload during startup, settings loading, curing restoration, and normal retained-class behavior. Use no credential contents in diagnostics. Acceptance: no automatic gameplay command during credential prompts, normal startup once after authentication, and no automatic route restart.

### 2. Remove hard-coded development logging from physiology

`Alchemist/Core/physiology.lua` contains four agent-log blocks writing to an absolute Desktop path. `pcall(yajl.to_string, payload)` evaluates `yajl.to_string` before entering `pcall`, so standalone tests without Mudlet's `yajl` fail before normal evaluate handling. Replace these blocks with an optional, guarded logger in a separate change. Acceptance: evaluation succeeds with logging disabled and without `yajl`, and no absolute-path logging occurs by default. This pre-existing issue was reported rather than bundled into the authorized fixes.

### 3. Provide one supported regression entrypoint

The suite mixes direct Lua tests, package-extracted fixtures, PowerShell wrappers, and Mudlet-provided globals. Add one runner that supplies the required fixture dependencies, declares supported runtime versions, records passes/failures/skips, and runs in CI. Acceptance: one command reproduces the documented checks on a clean machine without a live profile or source mutation.

### 4. Extend native reload observability

The workspace bridge reports module state; a small read-only health view could also report session readiness, active route, pending startup work, and registered-handler counts. Use this to validate all retained modules over repeated native reloads. Acceptance: handler/timer counts stabilize, missing prerequisites are visible, and diagnostics contain no passwords or raw credential input.

## Delivery notes

Implementation verification ran in the Desktop editing workspace. Git synchronization, commits, and pushes are separate delivery steps; consult the canonical repository history for their status. Live package installation remains a separate step. The retirement manifest uses pre-removal hashes; Monk source hashes recovered from the canonical copy intentionally refuse deletion if the destination differs. Review conflicts rather than overriding the guard.

Historical documents and previous `.superpowers/` snapshots remain historical evidence. They are outside the delivered source tree, are not runtime loaders, and are not copied by workspace sync. Current builders use only maintained source paths; the retirement regression rejects builder references to removed Monk sources.
