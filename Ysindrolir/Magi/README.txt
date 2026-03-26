Magi workspace notes
====================
Last updated: March 26, 2026

This folder is the class-specific home for Magi work.

Current fixes
-------------
  The old shared package:
    Ysindrolir/mudlet packages/Devtools.xml
  has been retired.

  The split Magi-side debug package now lives here as:
    MagiDevtools.xml

  This file set is currently the Magi-side home for debug tooling while the
  Occultist-side copy remains at:
    ../Occultist/Occultist Devtools.xml

  Magi aliases and triggers in Yso system.xml were corrected for the current
  Elementalism / Crystalism helpers.

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
    revelation

Notes
-----
  Future Magi-only offense, defense, resonance, or debug helpers should live
  here rather than inside the Occultist tree.

Current Magi follow-up
----------------------
  The local skill reference chart was corrected against live helpfile output for:
    retardation
    cataclysm
    revelation

  The shared Yso package now keeps elemental tracking as:
    Yso.elemental            current summoned elemental or false
    Yso.elemental_lev_ready  Djinn levitate readiness boolean

  Exact summon text is still needed before adding active-state triggers for:
    sandling
    ashbeast
