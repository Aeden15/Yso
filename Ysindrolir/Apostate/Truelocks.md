# Truelocks

Import the updated **AK.xml** and **Yso system.xml** packages from `mudlet packages/`.
Set your target and use **`tlock`** to start or stop. The active alias is named
**Truelocks**, with pattern `^tlock$`. It calls the existing Yso route scheduler
for `apostate_truelock`; loading the package leaves the route off.

Activation orders Bloodworms, Daemonite and Nightmare to kill the validated
current target, once each in one command batch. Manual and automatic shutdowns
order all three passive once. Orders are balanceless and direct, independent of
the route's pressure confirmation slot. Failed startup sends stop the route;
invalid target/class activations issue no kill orders. The target is captured at
activation, so a change before the first pressure tick stops the previous attack.

Establish your Baalzadeen before using the Corrupt finisher. Known magical
shield holds pressure until cleared; the route does not assume that Puncture
bypasses a shield. Curseward is handled automatically: Breach occupies the
first Deadeyes slot, followed by the highest-priority missing affliction eye.
Curseward only affects Evileye: when no useful affliction eye remains, a venom
attack can proceed without Breach. Disfigure, Chill, Shrivel and Corrupt are
not held by Curseward.
The combined mana cost and balance gates apply. Pressure resumes after AK
confirms both the eye batch and Curseward removal; Breach never earns an
affliction score. A failed second eye remains eligible for the next attack.
Reapplied Curseward is handled again on the next pressure action.
AK's target comparison ignores capitalization while retaining abbreviated target
prefixes, so a typed target such as `MAldrantus` matches game responses naming
`Maldrantus`. Import the updated AK package as well as Yso for this correction.

Paralysis is the first missing affliction given, paired with the next useful eye
when possible. If cured during any padding stage, it is reapplied before further
padding. It must also be confirmed at 100 before the closing Corrupt request.

Pressure then builds impatience plus two distinct Goldenseal/Plumbum afflictions,
then asthma plus two distinct Kelp/Aurum afflictions. These six conditions accept
AK scores of at least 50. Plumbum padding is dizziness, epilepsy, shyness or
stupidity; Aurum padding is clumsiness, sensitivity or weariness. Existing
qualifying padding is retained; missing slots are chosen randomly each replan.
Shyness uses Digitalis through the daegger only when stock is marked available;
otherwise missing padding is selected from the available eyes. Existing shyness
still counts. Digitalis defaults unavailable, and reimport removes the older
unverified `true` default while preserving measured doses. Other padding has an
Evileye source.

With both padded pools established, use Manaleech plus a missing padding eye.
If every padding eye is already confirmed, use Manaleech alone. Sicken is then
eligible only with confirmed manaleech and missing slickness; pair it with
Anorexia when both are missing. Class-specific and custom additional requirements
are still required before the finisher. Earlier stages are repaired if their scores fall
below the threshold. Two useful eyes use Deadeyes; one uses Stare.
Old shipped priorities migrate to paralysis, impatience, asthma, manaleech,
slickness, anorexia. Custom requirements remain, but cannot bypass Paralysis or stage gates.
The old mandatory weariness/stupidity/recklessness/clumsiness/addiction list is
replaced by the pool requirements and AK's target-class requirements.
Corrupt still requires every core/class requirement at 100, plus both padding
pools at 50 or higher. Uncertain core afflictions are reconfirmed before Corrupt.
Missing requirements that cannot be supplied are reported as holds.
Unknown target class does not count as a verified complete class lock.

During pressure, the route uses available equilibrium for support in this order:

1. `disfigure <target>` when asthma and manaleech are confirmed and disloyalty
   is missing.
2. `shrivel left leg <target>` when frozen and either slickness or anorexia are
   confirmed, but neither leg is confirmed crippled. One afflicted leg is enough:
   the route never pursues the other leg. It can reapply after both are clear.
3. `chill <target>` when either slickness or anorexia is confirmed and frozen
   is missing.

These EQ support conditions use AK scores of at least 100 (or true), including the existing
frozen score convention. They do not infer freezing stages or award afflictions
on send. Support respects target, pause, shield, mana and equilibrium gates,
with recovery guards of 3s for Disfigure, 2.1s for Shrivel and 2.2s for Chill.
Eye attacks spend balance but also wait for equilibrium readiness; Puncture
remains balance-only. Explicit EQ/BAL or warded rejection responses settle at
the prompt and replan, so rejected attacks do not wait for a hit confirmation.
A blindness rejection stops with `eyes_blind`; resolve blindness or enable
Truestare before restarting. A complete lock and the
Corrupt/Contemplate/Catharsis sequence take priority over support.

Available venom can supply a missing class blocker through Puncture. Every such
attack sends `wipe daegger`, `envenom daegger with <venom>`, then
`daegger puncture <target>`. Preparation is balanceless. Only a confirmed coating
and hit can award its AK affliction; one hit consumes one coating.

After a confirmed complete lock, the route requests `demon corrupt <target>
paralysis`. It settles acceptance/rejection/retention at the prompt, invalidates
confirmed own Evileye curses consumed by Corrupt, and Contemplates. Below half
mana, it waits for equilibrium and obtains a fresh Contemplate report before
sending `cq all` and `demon catharsis <target>`. At or above half it rebuilds.
Catharsis sender exceptions stop the route and return the creatures to passive,
including when a batch may have been partially sent.
Catharsis ends the route. Rejection or a ten-second confirmation timeout stops
it; `tlock` can explicitly restart it after inspection.
An outstanding Contemplate reply from a stopped route is discarded, so it cannot
reach the standalone Catharsis helper. If that reply never arrives, the next
same-target Contemplate reply is conservatively discarded instead.

Configuration in Mudlet Lua:

```lua
-- Your confirmed purchases seed availability; notechis starts unavailable.
Yso.apostate.daegger.stock.notechis = 200 -- set only after obtaining it
Yso.apostate.daegger.stock.digitalis = 200 -- enable Shyness padding after obtaining it
Yso.apostate.daegger.stock.gecko = false -- unavailable / exhausted
-- Numeric doses decrease on confirmed application. true means available,
-- without a measured dose count; update those flags when stock runs out.
display(Yso.off.apostate.truelock.status())
```

Magi's haemophilia requirement will hold without notechis unless AK already
confirms haemophilia. Prone requirements hold for manual/support delivery;
the route does not invent an Apostate prone source. Aeonlock and Riftlock are
excluded. Summons, other lock routes, and channeled instant kills are not started
by this alias.

Maintained sources: `truelock.lua`, `daegger_envenom.lua`, and `ak_tracking.lua`.
Rebuild with `scripts/build_apostate_package.ps1`; verify with
`scripts/test_apostate_truelock.ps1`, `scripts/test_apostate_tracking.ps1`, and
`scripts/test_apostate_package.ps1`. These tests run locally without issuing game
commands. Live combat validation in Mudlet is still required.

Demon Taste replaces the three known passive reports with TRACING, MINDREADING,
or SYPHON in the Apostasy palette. Each summary starts on a fresh line and resets
the colour before ending its line.
