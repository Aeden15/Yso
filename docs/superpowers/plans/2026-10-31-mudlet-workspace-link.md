# Mudlet Workspace Link Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for inline implementation and a final independent review.

**Goal:** Replace recurring manual XML imports with a single `ysoreload` command.
**Architecture:** A small independent permanent bridge package links AK and Yso as native Mudlet modules. Copy built workspace XMLs to profile-local module files, keeping workspace files authoritative and protected from Mudlet writeback. File watches notify only; reloads are explicit and refused while combat/hunting automation is active.
**Tech Stack:** Lua 5.1-compatible Mudlet APIs, XML and PowerShell packaging, Lua behavioral tests.
**Spec:** User accepted the preceding one-command reload proposal; automatic reloads are deferred.

## Interfaces and constraints
- Independent global `YsoWorkspaceLink`, permanent aliases `ysolink`, `ysoreload`, `ysostatus` in a standalone bridge package.
- Explicitly restricted to the Mudlet profile named `Achaea`; refuse all mutations and install no watchers in other profiles.
- Configured workspace is `C:/Users/shuji/OneDrive/Desktop/Yso systems`; load built AK.xml and Yso system.xml only, never peer Lua route files.
- `ysolink` backs up the current profile before replacing existing package installations with profile-local modules; refuse ambiguous package/module names or paths.
- `ysoreload` preflights both files before changing either; reload AK before Yso and set native module priorities accordingly. Do not resume automation automatically.
- Keep bridge handlers outside reloaded modules, avoid duplicate watchers, debounce rebuild notifications, and serialize installs/reloads with explicit acknowledgments and timeouts.
- Preserve prior profile-local module files for rollback; report partial failure rather than claim success. No module save may write into workspace files.
- Existing Desktop/GitHub workspace convention persists; sync only scoped task files and commit/push on completion as requested in this chat.

## Tasks
- [x] Behavioral tests: idle gating, preflight, isolated staging, migration backup, module order, failure handling, notifications and repeated setup.
- [x] Bridge implementation and standalone deterministic package builder; documentation and packaged alias/source verification.
- [x] Run tests, obtain independent review, fix important findings, and verify byte-stable builds.
- [x] Install/configure in the running Achaea profile; verify module paths and one-command reload, and save the linked configuration.
- Git synchronization and push: scoped files only; delivery commit and remote verification are recorded in the final response.

## Rulings
- The user selected manual one-command reloads; file watches notify without changing live combat code.
- Mudlet modules may write back to their original XML files. Profile-local staging isolates that behavior from the workspace source tree.
- Work in the Desktop editing workspace (not a Git repository); canonical GitHub clone is documented in GIT.md.
- XML parsing runs in the publisher; byte-exact local validation snapshots bind its extracted script bodies to the live input files. Native Mudlet Lua compiles all script bodies before migration/reload, avoiding Lua 5.1/5.4 incompatibilities in older AK code.
- Native module timeouts retain the busy operation and offense hold because Mudlet can defer a reload behind a profile save. Late acknowledgments reconcile that same operation; retries stay blocked. Concurrent module-writeback is detected through completion byte comparison.
- Independent review found three important defects (idle empty pending tables, weak input validation, deferred-reload timeouts). Failing reproductions preceded their fixes; asynchronous lifecycle coverage now includes a native-style 25-second deferred completion.
- Live Achaea preflight compiled all 1,421 Lua bodies and found no active routes/basher. `ysolink` completed successfully after its profile backup; independent bridge controls survived conversion of both packages to modules.
- Live `ysoreload` completed successfully. Final native verification reports both modules linked/up to date at profile-local paths, priorities 0/1, sync false/false, and passing read-only preflight. Backup: `C:/Users/shuji/.config/mudlet/profiles/Achaea/yso-workspace/backups/before-link-1793494146-1.xml`.
- Validation metadata and the exact XML snapshot are published in a single atomically replaced receipt per module, preventing a new snapshot from being paired with old script metadata during publication.
- No deferred review findings remain. A concurrent native-save fixture now verifies that changed staging bytes stop the sequence and leave offense paused rather than announce success. Source and packaged bridge suites, malformed-publisher rejection, Apostate Vivisect regressions, and 60 self-affliction checks pass.
