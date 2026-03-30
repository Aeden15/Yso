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
  magi_group_damage.lua
    Provides Yso.off.magi.group_damage for the Magi team-damage loop.

  magi_reference.lua
    Provides the Yso-side Magi resonance API, Crystalism resonance state
    helpers, and AK sync helpers.

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
  Fresh-target Magi damage does not guess caloric. It always opens with
  freeze, then promotes cold setup from AK frozen/frostbite evidence until the
  target dies, swaps, or room context changes.
  Crystalism resonance notice triggers live under:
    Yso system.xml -> Yso Triggers/Magi/Crystalism
  energise resonance is separate from the mheals absorb-energy flow:
    Yso.magi.energy controls heal-burst readiness only.
    Yso.magi.crystalism.consume_energise_resonance() is for personal energise
    alias gating.
  The packaged mheals alias now requires both:
    Yso.magi.energy == true
    Yso.magi.crystalism.consume_energise_resonance() == true
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
