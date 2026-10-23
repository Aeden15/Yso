Magi workspace notes
====================
Last updated: October 23, 2026

This folder is the class-specific home for Magi work. Live behavior is defined by
the installed Mudlet package (Ysindrolir/mudlet packages/Yso system.xml): use
aliases such as mdam, mfocus, fstorm, gwater, mreflect and the package trigger/script order. Repo Lua
here is the editable source; Ysindrolir/scripts/export_yso_system_xml.ps1 is
optional for re-embedding into the XML when maintaining split files — not part
of ordinary in-Mudlet play.

Current fixes
-------------
  Bloodboil is manual-only through boi. Its ready/cast triggers maintain
  yso.magi.bloodboil and display readiness/cooldown feedback. The old automatic
  self-purge selection, shared cooldown state, and Bloodboil EQ lock are removed.
  The existing alias command and server feedback patterns are preserved.

  Confirmed Firestorm resonance/send rejections reopen the matching outstanding
  room attempt. Later EQ actions invalidate rejection correlation; AK resonance
  remains authoritative.

  Pebble experiment (gwater, fstorm, mfocus): when AK Scalded is below 100 and
  Earth resonance is zero, cast Pebble before normal setup. Shield handling,
  special actions and execution retain priority; Focus still opens Hellfumes
  first and preserves its post-Convergence finishers. Pending sends suppress
  duplicates; resonance and limb breaks advance only from game feedback.

  AK.xml now confirms Pebble's named broken limb, independently of Earth
  resonance's separate crack message. Import both updated AK.xml and
  Yso system.xml into Mudlet. The skill reference adds Pebble, Destabilise's
  room effects and current balance requirements, and Overload. Automatic
  Destabilise/Overload use remains deferred.

  For this scoped rebuild, run scripts/build_magi_pebble_package.ps1 from
  Ysindrolir. It updates Water, Firestorm, and the Focus alias/native script
  without replacing unrelated package entries. Validation:
    scripts/test_magi_pebble_package.ps1
    scripts/test_magi_pebble_tracking.ps1
    lua "Yso/Tests and rebuilds/test_magi_group_pebble.lua"
    lua "Yso/Tests and rebuilds/test_magi_focus.lua"

  Magi aliases and triggers in Yso system.xml were corrected for the current
  Elementalism / Crystalism helpers.

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
  magi_convergence.lua mirrors the package's shared finisher helper. The
  generated mfocus alias includes it, so rebuilding the alias retains
  confirmed assessment, staff/channel gates, and shared finisher state.
  This keeps target resolution, pending windows, repeat suppression,
  resonance reads, and explain scaffolding aligned without flattening
  route-local brains together.

  Magi combat now also includes a duel affliction / convergence route:
    Yso.off.magi.focus
  The route key and debug key are both:
    magi_focus
  Legacy alias compatibility still maps:
    focus -> magi_focus
  It opens with hellfumes when needed, then dehydrate before horripilation /
  freeze. It pursues asthma, slickness, paralysis, and anorexia, plus any two
  of epilepsy, stupidity, and dizziness. Convergence requires those afflictions
  confirmed at AK score 100+, all four resonances moderate, and Dissonance 4.
  Staff Lightning pursues stupidity with Shock + Lightning fitted; disable via
  Yso.off.magi.focus.cfg.shock_lightning_enabled = false if unavailable.
  The late fallback dumps major resonance Earth / Fire / Water / Air through
  emanation; with no major resonance it casts dehydrate. Pending casts never
  count as confirmed lock afflictions. After convergence, Destroy stays first,
  followed by lock maintenance and damage pressure.

Current Magi helpers
--------------------
  The old generic Magi group-damage route is retired. Use gwater for Group Water
  or fstorm for Firestorm. mdam only displays this replacement notice.

  magi_focus.lua
    Mirror for tests/export; Mudlet-primary copy lives in ^mfocus$ alias body.

  Magi_duel_dam.lua
    Provides Yso.off.magi.dmg for the Magi duel damage route (key: magi_dmg).

  Magi_firestorm.lua / Magi_water_group.lua
    Package scripts for ^fstorm$ (magi_firestorm) and ^gwater$ (magi_water_group).
    Thin aliases toggle those loops. Staff/shield ids: Yso.magi.weapons.set.
    Shalestorm is a Magi-wide flag on Yso.magi.shalestorm.
    Hellfumes is a Magi-wide room flag on Yso.magi.hellfumes (Elementalism up/down lines).
    magi_dmg recasts hellfumes after shield/execute; magi_focus follows it with dehydrate.

  magi_route_core.lua
    Provides the shared Magi route chassis/runtime helpers.

  mfocus_alias_body.lua
    Built Focus alias body used for package embedding by export_yso_system_xml.ps1.
    For Focus-only changes, run scripts/export_yso_system_xml.ps1 -FocusOnly.
    This synchronizes the Focus alias and existing native Focus script without
    replacing unrelated embedded runtime logic from older source mirrors.

  magi_dissonance.lua
    Provides Magi-local Dissonance stage/confidence/evidence tracking.

  magi_reference.lua
    Provides the Yso-side Magi resonance API, Crystalism resonance state
    helpers, and AK sync helpers.

  magi_vibes.lua
    Provides Yso.magi.vibes.run() for the vibeds alias flow.

  vibeds_alias_body.lua
    Paste-ready alias body for the vibes helper.

Notes
-----
  Group damage alias is mdam only; duplicate mgd was removed.
  Reflection helper is now cast-only via mreflect (no auto-reflect toggle/state).

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
  Magi focus uses live Yso.magi.resonance state, observes Crystalism focus without
  auto-casting it, and keeps Dissonance stage/confidence/last evidence on the
  route object for Lua inspection (see magi_focus.lua / explain hooks).
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
  here rather than inside class-specific trees.

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
