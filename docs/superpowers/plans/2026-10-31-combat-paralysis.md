# Shared Combat Paralysis Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans with TDD and one independent final review.

**Goal:** Every registered combat route pauses while self-paralysed and resumes only if still enabled, with no paralysis-induced confirmation timeout.
**Architecture:** Shared combat pause/confirmation-clock module, enforced by scheduler and emission APIs; narrow adapters for existing command confirmation state. Canonical self-affliction gain/loss events drive pause transitions and cure nudges. Existing package-native load order and Achaea workspace-link publication remain.
**Tech Stack:** Lua 5.1-compatible Mudlet modules, PowerShell/XML builders and source/embedded regression tests.
**Spec:** Approved plan in this chat; combat routes only. Hunting and Legacy Basher are excluded.

## Constraints
- Preserve manual stops, target/class invalidation, death/disconnect, suppression and genuine game cooldown/effect expiry.
- Block offensive startup orders, waiting checks and attack callbacks while paralysed; allow cure/defense/utility emissions.
- Keep dispatched commands owned/pending and process real confirmations; remove only route-owned unsent staging. Never fabricate hits, restart disabled loops, or duplicate executes.
- Pause only confirmation clocks; no global clock overrides or arbitrary timestamp rewriting.
- New registered combat routes inherit scheduling/emission guards and use the shared clock for confirmation deadlines.
- Desktop is the editing workspace, not a git repo. Commit/push scoped files in the canonical clone documented by GIT.md.

## Tasks
- [x] Add failing shared-policy, registry/scheduler, emission, pending-clock and cancellation tests including a future-route fixture.
- [x] Implement shared gate/clock, scheduler lifecycle and cue event handling; adapt current route confirmation logic and direct emit paths.
- [x] Synchronize canonical/mirror/embedded sources and aliases through a scoped combat-pause builder; document the route contract.
- [x] Run relevant route suites and package checks, independent review, fix important findings, verify stable rebuilds and publish workspace-link inputs.
- [x] Verify Achaea reload while idle and prepare scoped canonical-clone synchronization.
- Integration completion condition: commit and push the reviewed changes, then confirm remote HEAD equality and a clean canonical clone.

## Execution ledger
Ruling: implement inline in Desktop and commit through the clean canonical clone; no git worktree exists in the user-designated editing folder.
Ruling: existing Magi effect-duration and spell-repeat windows retain wall-time semantics. Migrate actual command-confirmation deadlines only, not all fields called pending.

Ruling: the native XML lacked all four maintained Alchemist scripts despite active registry entries. Embed the existing physiology and three route sources so the shared behavior is available in the shipped package; no Alchemist strategy changes.
Ruling: queue ownership metadata remains in the optional legacy queue sources, not a new native queue script. Real emitter paths are guarded centrally; custom staging gets a documented discard hook.

Verification: all three shared combat-pause suites pass, including every registered combat route and a future fixture, actual route confirmation clocks, forced emission, staged ownership, mixed cure/offense commits, and terminal stops. Source/mirror/alias parity, Lua syntax and stable package rebuild pass. Existing Apostate, Monk, Airlord, Magi and safety package suites pass. Shared wake contract: 24 checks; self-affliction tracking: 60 checks. Alchemist duel/aurify/group suites pass 53/36/125 checks with a logging-only yajl stub in the CLI harness.
Review: independent reviewer found mixed cure-commit offense leakage and preferred-lane starvation in the optional queue. Both reproduced RED, fixed, verified GREEN and independently rechecked; no remaining findings.
Live verification: Achaea ysoreload succeeded. AK and Yso system report linked/up to date; shared pause table loaded, 13 registered combat routes, Alchemist physiology loaded, idle=true. No live combat was started.

Final clone verification: shared package suite, Vivisect package suite and combat safety package suite pass from the canonical clone; origin/main matches the pre-change HEAD. Semantic XML comparison confirms only the intended 11 script bodies and two aliases changed/appeared.
