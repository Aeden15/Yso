Magi workspace notes
====================
Last updated: March 31, 2026

This folder is the class-specific home for Magi work.

Current fixes
-------------
  The old shared package:
    Ysindrolir/mudlet packages/Devtools.xml
  has been retired.

  Unified class devtools now live in one XML source:
    ../mudlet packages/YsoDevtools.xml

  This XML now contains both Magi and Occultist devtools, kept segregated by
  class-specific command surfaces inside the same package.

  Magi aliases and triggers in Yso system.xml were corrected for the current
  Elementalism / Crystalism helpers.

  The unified devtools XML includes a Bloodboil test surface:
    ytest bloodboil snap
    ytest bloodboil fire [secs] [force]
    ytest bloodboil debug [on|off|toggle]
    ytest bloodboil auto [on|off|toggle]

  The Magi team-damage route now stays inside the same dam path while mixing
  water and fire pressure. It opens with horripilation when waterbonds is
  missing, forces one freeze-baseline decision on fresh targets, preserves
  mudslide / glaciate / water-emanation windows, and only then opens magma,
  firelash, conflagrate, and fire-emanation pressure from AK frozen/frostbite.

  Live DRY EQ emits for the Magi team-damage loop now advance through the
  shared Yso.locks.note_payload() acknowledgement path, so the route no longer
  needs manual on_payload_sent() simulation to progress after horripilation,
  freeze, magma, or later fire-side casts.

  Shared [Yso] mode echoes now stay on real mode/route changes only. Magi loop
  toggles remain class-owned and echo as [Yso:Magi] Group damage loop ON/OFF.

  Current AK scalded handling for the Magi-side route assumes 20s instead of
  the previous 17s.

  Magi offense routes now share a Magi-only chassis helper:
    Yso.off.magi.route_core
  This keeps target resolution, pending windows, repeat suppression,
  resonance reads, and explain scaffolding aligned without flattening
  route-local brains together.

  Magi combat now also includes a duel affliction / convergence route:
    Yso.off.magi.focus
  The route key and debug key are both:
    focus
  It opens through horripilation / freeze, revisits bombard when needed,
  swaps Fulminate continuation in on kelp pressure, drives Dissonance toward
  stage 4 with live Magi-local tracking, then casts convergence immediately
  once all four resonances are moderate.

Current Magi helpers
--------------------
  magi_group_damage.lua
    Provides Yso.off.magi.group_damage for the Magi team-damage loop.

  magi_focus.lua
    Provides Yso.off.magi.focus for the Magi duel convergence route.

  magi_route_core.lua
    Provides the shared Magi route chassis/runtime helpers.

  magi_dissonance.lua
    Provides Magi-local Dissonance stage/confidence/evidence tracking.

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
    tremors
    heat
    dissipate
    reverberation
    adduction
    palpitation

Notes
-----
  Fresh-target Magi damage does not carry old-target branch assumptions. It
  resets through:
    horripilation -> freeze baseline -> branch reconsideration
  and only then mixes fire-side pressure from AK frozen/frostbite/scalded/
  aflame/conflagrate state.
  Magi focus lives in the same route family and debug surface:
    yrdebug on focus
    yrshow focus
    yrshow focus full
  Focus uses live Yso.magi.resonance state, observes Crystalism focus without
  auto-casting it, and exposes Dissonance stage/confidence/last evidence in
  the shared YsoDevtools package rather than inventing a fixed timer.
  Focus freeze gating now treats water resonance as the hard pre-gate:
    when water is below moderate, freeze reopen remains mandatory.
    when water is already moderate, missing frozen/frostbite no longer
    blocks resonance pivots (bombard -> fire progress -> dissonance push).
    if pivots are temporarily blocked, focus falls back to maintenance freeze.
  Crystalism resonance notice triggers live under:
    Yso system.xml -> Yso Triggers/Magi/Crystalism
  energise resonance is separate from the mheals absorb-energy flow:
    Yso.magi.energy controls heal-burst readiness only.
    Yso.magi.crystalism.consume_energise_resonance() is for personal energise
    alias gating.
  The packaged mheals alias now requires both:
    Yso.magi.energy == true
    Yso.magi.crystalism.consume_energise_resonance() == true
  The package also bootstraps the Crystalism energise helper inline so the
  alias does not depend on magi_reference.lua load order.
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
  The packaged Djinn present trigger now sets elemental_lev_ready true
  immediately on summon.

  Exact summon text is still needed before adding active-state triggers for:
    sandling
    ashbeast
