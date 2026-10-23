# Shikudo route sources

`shikudo_forms.lua` owns confirmed form/kata state and the shared
`Yso.monk.shikudo.staff_command()` resolver. Every future Shikudo route must call
that resolver at emission time: it reads the current global `shikstaff`, accepts
only `staff` followed by an item number, and returns a wield command. An empty
configuration uses the confirmed inventory willow-staff fallback; an invalid
configuration holds instead of choosing another weapon. Never copy an item ID
into a route or cache the resolver result across attacks.

`shikudo_ai.lua` selects damage-route options from confirmed state. `combo.lua`
validates Shikudo options against `monk_reference.lua` without sending or changing
tracking. Other routes can share both interfaces. Read target afflictions only
after validating that AK tracks that target. Sending a command never establishes
afflictions, a successful transition, or kata gains.

`shikudo_group_damage.lua` contains the full `shdam` controller adapter, including
mind-lock opening, ranged fallback, Dispatch, and physical recovery gating. Run
`scripts/build_shdam_alias_body.ps1` to regenerate `shdam_alias_body.lua` before
export. The package loads reference, form tracker, combo helper and AI before the
alias can activate. Repeated alias invocation toggles the existing route.

After a confirmation timeout, offense stops. An explicit `shdam` restart clears
the expired request and still waits for current balance/equilibrium readiness.
Ordinary rapid off/on retains recovery protection and cannot duplicate attacks.

Run `scripts/export_yso_system_xml.ps1 -ShikudoOnly -KaiSoarOnly` for the scoped
package refresh, then `scripts/test_shikudo_package.ps1`,
`scripts/test_kai_soar_package.ps1`, and `scripts/test_combat_export.ps1`.

The 24-action Rain and 12-action other-form limits are conservative route policy,
not verified game stumble limits. Tykonos is exempt. The installed damage route
advances Rain after six confirmed actions or a confirmed selected-leg injury/prone
state, with the five-action minimum retained for transitions. The current Dispatch
policy requires confirmed prone and crushedthroat; it retains the installed user
policy without adding a head gate.

## Shikudo duel and staged lock test

`shikudo_duel_selector.lua` selects commands without side effects;
`shikudo_duel.lua` owns recovery, pauses, emission, and the `shduel` control API.
The selectable strategies are `dispatch`, `lock`, `blackout`, and `scythe`.
The duel Dispatch policy adds confirmed head and leg injuries; it does not
change `shdam`. `combo.lua` accepts LIGHT immediately after a staff strike,
for example `ruku light torso`; kicks cannot be LIGHT.

Build with `scripts/export_yso_system_xml.ps1 -ShikudoDuelOnly`. This updates
`Yso system.xml` and `limb.1.2.xml`; replace both installed packages in Mudlet.
It also connects duel recovery to the existing EQ, full BAL and Monk limb
recovery triggers, while preserving their existing pulse/group behavior.

For the first live test, use a willing sparring partner, select that opponent
with your normal target alias, and ensure the Monk/staff/AK setup is active:

```text
shduel lock
shduel preview
shduel status
shduel on
```

Selecting `lock` does not start offense. Preview and status do not send attacks.
While testing, use `shduel status` to see form, kata, phase, stage, next
action/hold, missing preparation requirements, limb confidence, mindlock state,
and separate physical/EQ waits; `shduel off` stops the loop. Preview/status also
show per-strike LIGHT decisions and projected totals. An action confirmation
timeout stops the route and requires an explicit restart. Recovery debt survives
off/on and target changes. No affliction, form, kata or hit is established just
by sending. Limb preparation and Oak pressure have live-log evidence; the
complete closing lock sequence remains unverified in live play.

Lock starts from ready Rain (adopting it when needed), confirms head Hyperfocus,
then prepares both arms and the selected leg from actual known limb baselines.
Once each is actually one hit from breaking, it transitions inline to Oak.
Three bounded Oak pressure combos precede normal arm release and its inline
Willow transition; neither mindlock nor Impatience gates arm release. Actual arm
injuries then permit Sweep + Flashheel on the selected leg. Confirmed leg injury
and prone permit Hiraku LIGHT + Hiru LIGHT, applying anorexia last. Stage changes
require actual recovery and, for transitions, the destination-form confirmation.

After the anorexia action recovers, the `harden` stage checks current AK evidence.
Confirmed anorexia/asthma/slickness/paralysis plus mindlock permit Mind Impatience
in the current form, without a Rain detour. Missing prerequisites reassess setup.
Only confirmed anorexia/asthma/slickness/paralysis/Impatience earns the `maintain`
stage and hardlock label; weariness additionally earns the truelock label. Loss
of Impatience returns to hardening while the four prerequisites remain present.
Failed or cured closure attempts reassess actual preparation; they do not
blindly repeat anorexia. Dispatch, blackout, scythe, hunt and group selections
retain their existing policies.

Curing paused by `pp`, Deliverance, self paralysis/prone, unavailable recovery,
uninitialized room presence and an untracked target all hold offense.

Lock mode establishes `hyperfocus head` before pressure, using the captured
head-focus message as confirmation and waiting for actual BAL recovery. Each
activation reconfirms it; sending alone never establishes focus. The captured
breathing message invalidates the stored limb when focus is changed manually.
Confirmed focus is also supplied to limb projections for the reference's
half-damage multiplier on focused staff strikes. Other modes do not enable
focus automatically. Status includes the confirmed focus limb.

A target-bound Divine Grace rejection stops the duel route with
`target_divine_grace`. A recently rejected action that spent no balance leaves
no recovery wait on explicit restart; observed recovery debt is retained.

When imported during a session, the controller uses Legacy's maintained player
map if the cached GMCP startup snapshot has not yet been refreshed. Fresh GMCP
snapshots, departures and room changes remain authoritative. Status includes
the room-data source, scheduled-timer flag, tick count and raw BAL/EQ values.
EQ/BAL and emitter holds are reported instead of failing silently; repeating
`shduel on` shows status and re-arms a missing timer without bypassing recovery.

Room.Players can omit a physically reachable opponent (as captured in the
Maldrantus test log). Omission means unlisted, not a confirmed departure. Both
routes permit a target-bound physical attempt after a usable room snapshot;
actual departure/target-denial prevents further attempts. Observed local drink,
eat, and room-emote lines restore positive current-target presence. Room changes
still invalidate prior presence until new room evidence arrives.

In staged lock mode, MIND LOCK is free: it spends neither BAL nor EQ and can be
requested while Hyperfocus balance recovers. Physical preparation can begin
before lock succeeds. Formation duration is variable; an outstanding request
is not duplicated, and the mindlock tracker's pending target prevents a timed
retry while formation remains pending. Mind Impatience is withheld during
preparation, Oak setup and the physical close. Once the observed closing window
exists, it takes a fully recovered opening and spends real EQ. It waits for
actual EQ recovery and requires a physical action between mental attempts,
including when the effect is cured before EQ returns.
An exact resource refusal stops the route and discards unspent mental recovery
debt. Timeout diagnostics identify the action, target, lane and observed recovery.
The exact named Mind Impatience success line feeds AK's normal gained-affliction
handler. Existing AK cure observations remove it; neither a send nor a local
pending record counts as proof that Impatience remains present.
Sends do not establish either effect. Other duel modes and
the group route retain their existing mindlock confirmation handshake. Rebuild
a group-controller change with `-ShikudoOnly -ShikudoDuelOnly` so its embedded
alias is regenerated alongside the duel controller.

The limb core keeps `lb[target].hits` compatibility and validates numeric damage.
The `lra` command resolves the same current target as the duel controller. It reports
the named target and all six known zero baselines, or a visible failure when
no valid target exists. This is a manual reset command, not a toggle; use it
only to declare a genuinely fresh baseline. It does not remove intentional
LIGHT protection from head affliction strikes.
The limb core captures explicit percentage output without requiring a queued banner.
Generic salves and tracking expiry mark totals uncertain for automatic breaks;
they do not prove a particular injury was healed. Known successful Shikudo
effect messages are diagnostic only and do not invent numerical damage.
Use `lra` only with a genuinely fresh, undamaged opponent to establish the
zero-damage baseline. Unknown or uncertain limbs permit eligible LIGHT pressure
and report missing data; the route never invents zeroes or advances an intended
break from a projection alone. Measured reference hit values are
configurable through `Yso.off.monk.duel.cfg.hit_damage`.

Lock combos now choose LIGHT separately for each strike. Both arms and the
selected leg (`Yso.off.monk.duel.cfg.lock_leg = 'left'` by default, or `'right'`)
may take normal preparation damage while the projected total stays below 100%.
Only limbs explicitly selected for the staged arm/leg release may cross 100%.
Head, torso and other off-setup limbs stay protected. Each hit accounts for
earlier hits in the combo; an unsafe kick is omitted because kicks cannot use
LIGHT. Projections choose safe strikes; only actual numeric hit reports update
tracked damage and establish one-hit preparation.

Confidence is per limb: a numeric hit is a damage delta, not proof every
other limb started at zero. Establish a genuinely fresh zero baseline with
`lra`, or reset an individual known-recovered limb with `lr <limb>`. Do not
reset merely to make the route's numbers usable during an ongoing fight.
Old stored global calibration is not treated as per-limb baseline evidence.
Unknown/uncertain limbs use eligible LIGHT pressure and do not perform intended
breaks; a salve on one area leaves confidence in unrelated limbs intact.
Configured skill damage overrides are normal, unmodified percentages.
Hyperfocus is applied once to projected staff damage. Captured game percentages
are already effective and enter the tracker unchanged. Only actual numeric
hit reports accumulate damage; sends/parries/reflections do not.

Blackout's hidden-burst timing is unverified and disabled by default at that
stage (`awaiting_blackout_timing`). Only set
`Yso.off.monk.duel.cfg.blackout_timing_verified = true` after actual timing
tests show a physical follow-up can land legally within the window. The route
still requires real EQ/BAL recovery and falls back to lock pressure if the
confirmed window closes; it does not send consecutive mental commands together.

Regression checks: `scripts/test_shikudo_duel_package.ps1` runs source/package
parity, complete embedded Lua syntax, rebuild idempotence, real-controller lock
replay, and packaged limb compatibility checks. Also run
`Yso/Tests and rebuilds/test_shikudo_duel.lua`, `test_shikudo_duel_route.lua`,
and `test_shikudo_limbs.lua` with the `Ysindrolir` root argument. The staged
selector/controller regressions are `test_shikudo_staged_lock.lua` and
`test_shikudo_staged_controller.lua` in the same test directory. The existing
`test_shikudo_duel.lua` entry point remains available for the stable duel checks.
