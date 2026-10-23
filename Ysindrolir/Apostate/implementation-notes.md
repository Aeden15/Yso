# Apostate implementation — 2026-10-19

Implements the agreed Evileye reference/AK coverage, Catharsis, Deadeyes groundwork,
and Necromancy Shrivel plans from this chat.

- Reference: 34 AB entries plus an index-only Truestare record. In-game screenshots
  supersede conflicting wiki text. Paralysis works-on field was not shown.
- Tracking: existing AK scores only. Pending evileyes stay associated with their
  recipient; damage, Breach, Fear, Cowardice and Bleed do not invent affliction keys.
- Ruling: the existing common AK Asleep trigger confirms actual sleep; the generic
  evileye announcement cannot distinguish sleep from removing a sleep defence.
  No guessed defence-strip messages are added.
- Ruling: unsided Shrivel results remain target-keyed observations, never inferred
  left/right scores. No automatic Vivisect.
- No repeating Deadeyes/Contemplate loop or default offensive priorities.
- Catharsis: fresh matching report, raw mana strictly below half, requested queue
  clear, 4.4-second attempt guard. This is an attempt guard, not server readiness.
- Workspace has no Git repository at its root; changes are made in the user’s
  existing workspace, without commits or worktree setup.

Verification progress: regression checks added before the implementation and
failed on the missing Apostate tracking module. Final results are recorded below
after packaged replay and source checks.

- Review found that hard/soft AK resets clear scores in place. A regression
  reproduced a pending Asthma result restoring a score after reset. Both reset
  entrypoints now clear pending eyes and unresolved Shrivel observations first.

Completed verification:

- New tracking tests pass with the real packaged gain/cure functions and both
  hard/soft reset functions. Existing Asleep confirmation is also exercised.
- All 15 original HTML log outcomes replay successfully: 7 exact-limb results
  and 8 unresolved observations; replay also passes from the committed fixture.
- Existing Apostate utility checks, Shikudo/AK Impatience regression, and the
  26 AK echo-helper checks pass.
- Both XML packages parse; modified/new Lua compiles; four maintained module
  sources match their embedded bodies; a repeated build is byte-stable.
- Fresh review reported the reset issue above and no other concrete issues.
- Live Mudlet/server behavior has not been exercised by these local tests.
