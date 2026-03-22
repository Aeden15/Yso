Magi workspace notes
====================
Last updated: March 21, 2026

This folder is the class-specific home for Magi work.

Current fixes
-------------
  The old shared package:
    Ysindrolir/mudlet packages/Devtools.xml
  has been retired.

  The split Magi-side debug package now lives here as:
    MagiDevtools.xml
    MagiDevtools.mpackage

  This file set is currently the Magi-side home for debug tooling while the
  Occultist-side copy remains at:
    ../Occultist/Occultist Devtools.xml

  No broader Magi combat automation changes were made in this pass.

Current Magi helpers
--------------------
  magi_vibes.lua
    Provides Yso.magi.vibes.run() for the vibeds alias flow.

  vibeds_alias_body.lua
    Paste-ready alias body for the vibes helper.

Default vibes notes
-------------------
  Default embed cadence is 3.40s.
  Default command list matches the current alias mockup:
    creeps
    oscillate
    disorientation
    energise
    forest
    dissonance
    plague
    lullaby

Notes
-----
  Future Magi-only offense, defense, resonance, or debug helpers should live
  here rather than inside the Occultist tree.
