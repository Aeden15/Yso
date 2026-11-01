# Vivisect route

Import the updated `Yso system.xml` and `AK.xml` packages together. `vivi` toggles
the independent `apostate_vivisect` route through the permanent **Vivisect route**
alias (`^vivi$`) beside **Truelocks** in **Apostasy**; `tlock` retains its existing finisher.
Starting either route stops the other and transfers daemonite ownership.

Mount your steed manually (`vault gargoyle` for the supplied stone gargoyle).
Ordinary Riding `trample` requires a prone target; provide the knockdown manually
or through external support. The route waits for AK's `prone` score at 100.

Pressure shares Truelocks' actual selector: paralysis and hearing, impatience and
asthma with optional mental/kelp padding, then manaleech, slickness and anorexia.
Manaleech is a direct eye; Sicken supplies slickness once manaleech is confirmed.
Disfigure supplies disloyalty. Confusion must then be confirmed before limb work.
Missing pressure requirements are repaired before Trample or Vivisect.

After each settled Trample prompt the route replans from current AK scores. Only
`leftarm`, `rightarm`, `leftleg`, and `rightleg` individually at least 100 (or true)
permit `vivisect <target>`. The summed `tramplescore` is not an execute gate.
If one or more limbs are cured, the route Tramples again once prone and balance
permit. There is no Chill/frozen requirement and no wait for a RESTORE command.

Vivisect costs 300 mana and requires equilibrium. Once dispatched, the route waits
for observed equilibrium expenditure and recovery, then stops the attempt and
returns the daemonite passive. This completion reason confirms an attempt, not a
kill. Missing confirmations time out conservatively instead of repeating an
uncertain execute. Staged but undispatched commands are discarded and replanned.

Yso must have a full self-affliction synchronization before this route acts. Your
paralysis pauses the loop without toggling it off. Two permanent triggers directly
under `Yso Triggers/Curing` verify these exact lines through the canonical tracker:

- Gain: `A prickly stinging overcomes your body, fading away into numbness.`
- Cure: `Your muscles unlock; you are no longer paralysed.`

They override the GMCP freshness guard for explicit text observations. GMCP
remains connected for gain, removal and full-list reconciliation. No temporary
paralysis triggers are registered. After the cure, the next scheduler tick resumes.

AK's Riding Trample patterns accept any mount description with the existing
breaks/crushes/pulverises/smashes sentence formats, plus the existing bloody-pulp
confirmation. Only confirmed outcomes update the current target's limb state.

Rebuild with `scripts/build_apostate_package.ps1`. Verify with
`scripts/test_apostate_vivisect.ps1` plus the existing three Apostate suites.
