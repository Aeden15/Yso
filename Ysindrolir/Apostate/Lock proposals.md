# Apostate lock proposals and daegger envenoming design

Status: lock proposals plus implemented Truelocks automation; see `Truelocks.md`.

Sources: `Ysindrolir/Information/Locks.txt`, the supplied in-game AB captures,
the three Apostate skillcharts, and the current AK score/venom/class-lock data.
Riftlock and Aeonlock are excluded. This is a proposal for achieving the locks, not a claim
that these sequences have already been verified against live curing.

## Shared approach

Use confirmed target state to choose the next missing requirement. Examples below
are tactical stages, not unconditional sequences: re-evaluate after every action,
cure, defence change and target change. Never declare a lock from commands sent.

- **Evileye:** main source of paired afflictions through Deadeyes. Sicken supplies
  manaleech first, slickness next, then damage when both are present.
- **Apostasy:** daegger venom supplies an alternative missing affliction; Nightmare,
  Daemonite, Fiend and Sear supply ongoing pressure when established. Bloodworms
  supplies masochism/dizziness only against non-deaf victims. Respect pentagram,
  sunlight and demon-health requirements.
- **Necromancy:** Chill, confirmed limb afflictions, and room control support the
  approach. They are not substitute names for missing core lock afflictions.
  Shrivel may draw salve use; Chill may strip caloric or create freezing pressure.
  Neither proves an opponent will cure in a particular order.
- **Action economy:** Deadeyes and Puncture both use balance. Choose between them
  for a balance action; do not schedule both as though they have independent
  recovery. Necromancy and many demon commands compete for equilibrium. Demon
  setup and Necromancy support must be chosen over time, not all sent at once.
- **Defences:** Curseward requires Breach handling; magical shield, rebounding and
  target availability remain separate. Puncture bypasses rebounding, not an
  assumed magical shield. The 2026-10-20 live test confirmed Breach first followed
  by an affliction eye in the same Deadeyes command.

## 1. Softlock

**Required:** asthma + anorexia + slickness.

**Proposal:** use Evileye to build asthma/anorexia while obtaining slickness from
Sicken's second stage or a gecko-coated Puncture. If manaleech and slickness are
not yet established, gecko offers direct slickness delivery instead of spending
two eyes progressing Sicken. When slickness is confirmed, `DEADEYES <target>
ASTHMA ANOREXIA` is a possible closing pair if both are missing. If only one core
affliction is missing, use the second eye for a useful pressure affliction.

**Other skillsets:** Apostasy's Nightmare/Daemonite support cure pressure and
hindrance. Use a selected Necromancy EQ action such as Chill or side-specific
Shrivel when useful; do not delay a stronger closing action simply to use all
three skillsets.

**Venom preference:** gecko for missing slickness, otherwise kalmia for asthma,
otherwise slike for anorexia. Re-evaluate rather than blindly repeat the list.

**Limit:** the opponent can still have Focus, Tree and class-specific escapes.
This is a softlock, not a confirmed hardlock.

## 2. Venomlock

**Required:** softlock core + paralysis.

**Proposal:** maintain paralysis while assembling the core. Use direct Paralysis
Evileye or curare-coated Puncture. When asthma/slickness are established, a
Paralysis/Anorexia Deadeyes pair is one possible close. Repair whichever
requirement is cured rather than restarting a fixed four-affliction sequence.

**Other skillsets:** use demon pressure and Necromancy hindrance as above.
Shrivel is not a replacement for paralysis, and limb confirmations must not be
treated as Tree prevention.

**Venom preference:** curare when paralysis is missing, then the softlock venom
preferences. Two needed evileyes may be more efficient than choosing Puncture.

**Limit:** Focus and class-specific cures can still escape this state.

## 3. Truelock / Hardlock

**Required:** venomlock core + impatience + relevant target-class cure blockers.

**Proposal:** establish impatience before the closing core pair to deny Focus,
maintain paralysis for Tree denial, and sustain asthma/anorexia/slickness. Use
Deadeyes for missing pairs, with gecko/curare/kalmia/slike venom delivery as an
alternative balance action. Sicken's manaleech pressure also complements the
separate Catharsis threat.

**Other skillsets:** Nightmare supplies mental pressure. A chosen Chill/Shrivel
EQ action may disrupt recovery while the core is assembled. Neither alone proves
class-specific escape prevention.

**Class blockers:** consult AK's `ak.classlockresolve()` and `classlock` data as
the current system's recommendation, not as independent proof of game mechanics.
Examples include weariness, stupidity, voyria, recklessness and confusion. Prefer
direct evileyes or confirmed venom equivalents where available. Requirements such
as prone or selarnia need an explicit confirmed delivery source; do not invent one.
Unknown target class means the core can be reported, but complete class-proof
hardlock is unverified.

**Venom preference:** first repair a missing core requirement; then a supported
missing class blocker (e.g. vernalius/weariness, aconite/stupidity,
voyria/voyria, eurypteria/recklessness). Impatience itself is supplied by Evileye,
not an invented venom mapping.

## 4. Focuslock

**Required:** venomlock core, with multiple Focus-curable mental afflictions in
place of relying on impatience.

**Proposal:** preserve paralysis/asthma/anorexia/slickness and apply mental
afflictions verified in AK's `focused` cure pool. Examples available to Evileye
include stupidity, confusion, epilepsy, dizziness, paranoia and dementia.
Prioritize missing core requirements, then rebuild the mental pool after Focus.
Do not equate all mental-looking afflictions with Focus-curable afflictions.

**Other skillsets:** Nightmare's dementia contributes an appropriate mental
affliction when that stage actually lands. Bloodworms' dizziness may contribute
against a non-deaf victim. Necromancy hindrance can support pressure between
balance actions.

**Venom preference:** repair the core first; otherwise aconite/stupidity or
larkspur/dizziness when missing. Do not select impatience as the defining
mechanism of this profile; confirmed impatience would strengthen/change the state.

**Limit:** this is probabilistic Focus dilution, not a guaranteed cure block. No
fixed mental count guarantees it, and equal Focus selection probabilities have
not been established by the provided evidence.

## 5. Salvelock

**Required by Locks.txt:** both arms at level 2 or higher + slickness + asthma.

**Proposal:** document this as a conditional/assisted path. Once both level-2
arm states are independently confirmed, Apostate can sustain asthma through
Evileye/kalmia and slickness through staged Sicken/gecko. Demon pressure and
Necromancy hindrance can support maintenance.

**Missing prerequisite:** the supplied Shrivel/Leprosy captures establish withered
limbs, not progression to level-2 arm damage. Repeating Shrivel, stacking epteth,
or reading two 100-point arm scores must not be presented as producing this state.
An external or newly demonstrated level-2 damage source is required before this
becomes a standalone executable profile. AK's numeric limb tiers exist, but their
presence does not supply the attack that causes them.

**Venom preference after prerequisites:** gecko/slickness, then kalmia/asthma.
Vardrax/addiction is only optional supporting pressure from the lock notes; this
proposal does not create a riftlock route.

## 6. Sleeplock

**Required by Locks.txt:** rapid repeated sleep delivery to overcome Insomnia
and the instant-wake defence, then sustain actual sleep.

**Proposal:** use Sleep Evileye and delphinium-coated daegger attacks as alternate
delivery sources. Nightmare's hypersomnia is supporting pressure, not proof that
either defence has been removed. Once sleep is confirmed, maintain it while
assembling additional core lock afflictions as opportunities permit.

**Other skillsets:** Nightmare helps the sleep-oriented pressure. Necromancy
hindrance/room control supports retention, but adds no documented extra sleep
delivery. All three skillsets need not appear inside the short sleep burst.

**Venom preference:** delphinium while the selected goal is sleep preparation
or maintenance; switch to a missing core affliction only when the controller
deliberately changes its goal.

**Unverified delivery detail:** do not assume `DEADEYES <target> SLEEP SLEEP` is
legal or that three uses across ordinary balance recovery are fast enough.
Puncture and Deadeyes share balance. Test double-Sleep legality, actual defence
strip messages and burst timing before claiming a reliable standalone sleeplock.
Only a real sleep confirmation sets AK's sleep state.

## Daegger envenoming script design

### Agreed behavior

Automatic preparation immediately before a venom-delivering daegger attack:

```text
WIPE DAEGGER
ENVENOM DAEGGER WITH <selected venom>
<the selected daegger attack>
```

Always wipe, even if the existing coating appears correct. Wipe and envenom are
balanceless on this build (user confirmation). There is no separate balance wait
or coating timer. Repeating a venom does not skip the wipe. Wiping clears the
whole coating stack; subsequent delivery therefore need not depend on old LIFO
layers. A rejected wipe/envenom must not be recorded as successful preparation.

The preparation cannot make an attack legal through an existing defence, missing
weapon, missing venom, lack of attack balance or unavailable target.

### Initial interface

Maintain the source in `Apostate/daegger_envenom.lua`, package-loaded under
`Yso.apostate.daegger` with the other Apostate helpers.

- `select_venom(profile, snapshot)` returns a supported missing affliction and its
  venom, or a reason no venom was selected. It reads AK-compatible data without
  changing scores. Profile-specific preferences are stated above.
- `build_attack(action, target, venom)` validates inputs and returns the ordered
  wipe/envenom/attack command list. Initial venom-delivery actions are `stab` and
  `puncture`, using `STAB <target>` and `DAEGGER PUNCTURE <target>` respectively.
- `emit_attack(action, target, profile)` performs automatic selection/preparation
  for an offense caller and sends the ordered command list through Yso's shared
  command path. There is no automatic attack loop or independent periodic coater.
- Future Apostate offense routes call this helper for their daegger attacks.
  This groundwork does not silently intercept every raw Mudlet `send()` command.

Hunt, Shadowstrike and Eliminate are not silently treated as verified venom
delivery. Their channeling, repeated attacks and blood setup have different
semantics; add them only when appropriate delivery behavior is confirmed.

### State and integration rules

- Reuse AK's venom names and `currentvenoms` confirmation state. Keep weapon
  coating state separate from target affliction state and pending command intent.
- Never credit a venom affliction on wiping, envenoming, sending, missing, being
  blocked, or hitting the wrong person. Confirmation handling must match the
  actual attack and whether venom was delivered.
- AK already has generic envenom and weapon-hit bookkeeping, but the inspected
  package contains no explicit daegger Puncture delivery adapter. Validate a real
  Puncture log before claiming full delivery/consumption tracking. Do not invent
  its success/failure text. The existing wipe handler must not clear unrelated
  weapons simply because this helper prepares the daegger.
- Clear pending preparation on target changes, disconnects, class changes and
  resets. Keep confirmed coating observations distinct from pending requests.
- Honor Apostate class, shared target, offense pause and caller lifecycle gates.
  An idle helper sends nothing. It must not issue background commands during
  Eliminate or interfere with a reserved Catharsis/Vivisect commitment.
- No default attack route is enabled, no general queue is cleared by a background
  preparation step, and no unsupported lock prerequisite is manufactured.

### Verification before activation

- Every built attack starts with exactly one wipe, then envenom, then attack;
  same-venom repetition still wipes. No command is emitted on validation failure.
- Check profile choices against confirmed core afflictions and class blockers;
  confirm Sicken's stages are not mistaken for direct slickness.
- Verify no double-booking of balance between Puncture and Deadeyes.
- Verify no score gain or coating consumption on mere send, misses, blocks,
  preparation failures, wrong targets or stale pending commands.
- Test resets, class/target changes, pause, absent AK and unavailable shared sender.
- Keep salvelock conditional and sleeplock timing explicitly unverified; exclude Aeonlock.
- Verify Lua syntax, source/package parity and stable rebuilds; replay captured
  coating/delivery messages before enabling outcome-sensitive automation.
