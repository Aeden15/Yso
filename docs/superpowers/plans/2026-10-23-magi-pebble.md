# Magi Pebble Implementation Plan

Approved design: the October 23, 2026 conversation plan and subsequent correction
that gwater and Firestorm are the damage routes. Do not restore retired routes.

## Goal and constraints

Add Pebble, Destabilise and Overload to the existing reference. Track confirmed
Pebble limb breaks through AK. Experiment with Pebble in gwater, fstorm and
mfocus when Scalded score is below 100 and Earth resonance equals zero.
No automatic Destabilise/Overload use and no optimistic resonance/limb updates.

## Tasks

- [x] Reference and AK: document supplied ability data; add named-limb hit
  tracking, target/AI guards, preserve higher injury scores and independent
  resonance procs; test real gain/cure pathways.
- [x] Group routes: choose Pebble after shield/special/Stormhammer and before
  ordinary setup; support pending suppression and retry; test condition matrix,
  priority, acknowledgement and confirmed-feedback progression.
- [x] Focus: choose Pebble after Hellfumes and before Dehydrate/Horripilation;
  preserve finishers and existing guards; test lifecycle and priorities.
- [x] Packages: regenerate Focus alias and update only affected native entries;
  verify source parity, unrelated-content preservation and idempotence.
- [x] Review all tasks, run affected regressions, and synchronize scoped changes
  to the canonical GitHub checkout. Delivery is a commit and push of the current
  branch after final verification.

## Workspace integration

Desktop is the editing workspace; the canonical GitHub checkout is identified
in GIT.md. Both package XMLs already differed before this task. Preserve those
Desktop changes while transferring only task-owned nodes to the canonical XMLs.
Import updated AK.xml and Yso system.xml for live testing. Automated checks do
not substitute for a live Mudlet opening-sequence check.
