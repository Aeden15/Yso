# Truelocks

Import the updated **AK.xml** and **Yso system.xml** packages from `mudlet packages/`.
Set your target and use **`tlock`** to start or stop. The active alias is named
**Truelocks**, with pattern `^tlock$`. It calls the existing Yso route scheduler
for `apostate_truelock`; loading the package leaves the route off.

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

The default giving order is paralysis, asthma, slickness, impatience, anorexia,
weariness, stupidity, recklessness, clumsiness and addiction, plus AK's
target-class requirements. Clumsiness uses the `clumsy` eye syntax; addiction
uses `addiction`. Reloading upgrades the old shipped priority order but preserves
deliberately customized priorities. Both new afflictions remain required even
with a custom priority list. Two useful eyes
use Deadeyes; one uses Stare. Sicken progresses through confirmed manaleech to
slickness. Missing requirements that cannot be supplied are reported as holds.
Unknown target class does not count as a verified complete class lock.

During pressure, the route uses available equilibrium for support in this order:

1. `disfigure <target>` when asthma and manaleech are confirmed and disloyalty
   is missing.
2. `shrivel left leg <target>` when frozen and either slickness or anorexia are
   confirmed, but neither leg is confirmed crippled. One afflicted leg is enough:
   the route never pursues the other leg. It can reapply after both are clear.
3. `chill <target>` when either slickness or anorexia is confirmed and frozen
   is missing.

These conditions use AK scores of at least 100 (or true), including the existing
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
Catharsis ends the route. Rejection or a ten-second confirmation timeout stops
it; `tlock` can explicitly restart it after inspection.
An outstanding Contemplate reply from a stopped route is discarded, so it cannot
reach the standalone Catharsis helper. If that reply never arrives, the next
same-target Contemplate reply is conservatively discarded instead.

Configuration in Mudlet Lua:

```lua
-- Your confirmed purchases seed availability; notechis starts unavailable.
Yso.apostate.daegger.stock.notechis = 200 -- set only after obtaining it
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
