# Evileye skillchart — Apostate

Related: [Apostasy skillchart](Apostasy%20skillchart.md) and
[all Apostate references](Apostate%20skillcharts.md).

Source: the user's in-game AB screenshots captured **2026-10-19**, not the wiki.
Detailed captures cover 34 abilities. Truestare appears in the supplied ability
index but its detailed AB was not supplied. All captured abilities are known.

The structured companion is [evileye_reference.lua](evileye_reference.lua), exposing
`Yso.ref.apostate.evileye`. The chart describes abilities, not an offensive priority.

## Reading the chart

Unless a row says otherwise, syntax is `STARE <target> <KEYWORD>`, works against
adventurers, and lists **1.90 seconds of balance**. `A+D` means adventurers and
denizens. Listed recovery times are AB data, not a substitute for actual readiness.

The source column is the timestamp suffix of `Screenshot 2026-10-19 HHMMSS.png`
in `C:/Users/shuji/OneDrive/Pictures/Screenshots/`.

| Keyword | AB ID | Resource | AK score / outcome | Effect and exceptions | Source |
|---|---:|---|---|---|---|
| FEAR | 80 | 33 mana | Special effect | Instils fear; no persistent `fear` score is invented. | 192715 |
| DEAF | 81 | 33 mana | `deaf` | Removes hearing. | 192715 |
| IMPATIENCE | 82 | 45 mana | `impatience` | Prevents concentration on focused tasks. | 192737 |
| CLUMSY | 83 | 50 mana | `clumsiness` | Causes fumbling. | 192737 |
| VERTIGO | 84 | 50 mana | `vertigo` | Fear of heights. | 192748 |
| BLEED | 85 | 30 mana | Bleeding; amount unspecified | A+D. Not a binary `bleed` affliction score. | 192748 |
| AMNESIA | 86 | 50 mana | `amnesia` | Makes the victim forget the intended action; retain AK's expiry timer. | 192757 |
| AGORAPHOBIA | 87 | 50 mana | `agoraphobia` | Fear of open spaces. | 192757 |
| DEADEYES | 95 | Sum of both eyes | Combo wrapper | `DEADEYES <target> <first evileye> <second evileye>`; A+D; listed 2.30s balance, faster with greater skill. | 192811 |
| BREACH | 88 | 125 mana | Curseward removal | Defence break, not a gained affliction. | 192811 |
| DIZZY | 89 | 50 mana | `dizziness` | Severe dizziness. | 193026 |
| PARALYSIS | 2940 | 70 mana | `paralysis` | Prevents most actions; works-on field not shown in this capture. | 193026 |
| CLAUSTROPHOBIA | 90 | 50 mana | `claustrophobia` | Fear of enclosed spaces. | 193038 |
| PARANOIA | 91 | 50 mana | `paranoia` | Fear of other people. | 193038 |
| BLIND | 92 | 33 mana | `blind` | Removes eyesight. | 193055 |
| MASOCHISM | 93 | 50 mana | `masochism` | Victim loves and inflicts pain upon themselves. | 193055 |
| ASTHMA | 94 | 50 mana | `asthma` | Difficulty breathing. | 193105 |
| RECKLESS | 96 | 50 mana | `recklessness` | Disregard for personal wellbeing. | 193105 |
| EPILEPSY | 97 | 75 mana | `epilepsy` | Causes seizures. | 193115 |
| CONFUSION | 98 | 33 mana | `confusion` | Befuddles the mind. | 193115 |
| PEACE | 99 | 62 mana | `pacifism` | Fills the mind with peaceful thoughts. | 193129 |
| DEMENTIA | 100 | 50 mana | `dementia` | Distorts perceptions. | 193129 |
| SIGHT | 101 | 25 willpower | Self utility | `SIGHT`; self; clears blindness after concentration; 1.90s balance. Not a Deadeyes argument. | 193147 |
| SICKEN | 102 | 55 mana | `manaleech` → `slickness` → damage | Applies the first missing affliction in this order; both present means damage. Does not apply paralysis. | 193147 |
| PLAGUE | 103 | 75 mana | `voyria` | Afflicts voyria. | 193201 |
| ADDICTION | 104 | 70 mana | `addiction` | Causes addiction. | 193201 |
| COWARDICE | 105 | 150 mana | Forced movement | A+D; moves the victim randomly. Does not cancel tumble from hindered opponents. | 193216 |
| STUPID | 106 | 60 mana | `stupidity` | Causes stupidity. | 193216 |
| MANALEECH | 107 | 75 mana | `manaleech` | Saps the target's mana. | 193232 |
| SENSITIVITY | 108 | 70 mana | `sensitivity` | Increased sensitivity to pain; Evileye source bypasses AK's venom deafness substitution. | 193232 |
| VOMITING | 109 | 75 mana | `nausea` | Severe vomiting. | 193247 |
| SLEEP | 110 | 55 mana | `sleep` only on sleep confirmation | Can remove sleep defences instead; generic eye announcement does not confirm sleep. | 193247 |
| ANOREXIA | 111 | 70 mana | `anorexia` | Prevents eating. | 193256 |
| WEARINESS | 112 | 75 mana | `weariness` | Weakens the body. | 193256 |
| TRUESTARE | Not captured | Not captured | Utility, index-confirmed only | Index: cast the evileye through magical shields. Detailed syntax/cost/recovery not transcribed from the wiki. | Earlier index screenshot |

## Curseward is separate from magical shield

Track it using AK's existing `ak.defs.curseward`. The captured Breach log
(`193004`) supplies these exact lines, with Saibel replaced by `<target>` here:

- `A shimmering curseward appears around <target>.` — Curseward present.
- `<target>'s curseward shatters!` — Curseward removed.
- `Your attempt to breach <target>'s curseward has no effect.` — existing AK
  interprets this as Curseward absent; no gained affliction.
- `Summoning up the curse of breach, you stare at <target>, giving her the evil eye.`
  is an invocation announcement, not proof of a gained affliction or a ward break.

The old log's `[AK] Gained: Breach` is a tracker defect; the new handler excludes
Breach from affliction batches. AK already handles the ward up/down messages.
The live test on 2026-10-20 confirmed `deadeyes Maldrantus breach impatience`:
Curseward shattered before impatience landed. Put Breach first so the second
eye can deliver its affliction in the same balance action.

## Tracking and helper contract

- `ak.apostate.capture_eye(name, keyword)` records recipient-bound pending results;
  prompt confirmation commits through `OppGainedAff(..., 'evileye')`.
- `ak.apostate.fail_eye()` removes the last announced slot, including special
  non-affliction slots. Sending a command never marks an affliction.
- The generic Sicken handler owns its outcome once. The old overlapping
  doubles-over inference is disabled in favor of that handler.
- The existing common `Asleep` trigger confirms actual sleep. No guessed
  insomnia-stripping message has been added.
- Target changes, disconnects and class updates clear pending observations.
  AK hard and soft resets explicitly clear pending eyes and unresolved Shrivel
  observations before changing scores. Existing cures and Amnesia expiry remain.
- `Yso.apostate.deadeyes.build(target, first, second)` returns command text or
  `nil, reason`. It does not send. `select(priorities, afflictions)` returns two
  keywords or `nil, nil, reason`; snapshots are caller supplied and never mutated.
- Priorities are empty by default. Entries may be keywords or
  `{keyword=..., affliction=..., eligible=function(snapshot, skill) ... end}`.
  The general selector chooses missing tracked afflictions, skips duplicates,
  and projects Sicken's outcome. It does not choose defence breaks or damage.
- Contemplate is balanceless on this build. Catharsis uses only a fresh report
  matching the current target and raw mana strictly below half. It sends the
  requested `cq all` then `demon catharsis <target>`, with a 4.4-second attempt
  suppression window. No automatic Contemplate or Deadeyes loop is installed.

## Verification

From the workspace root, run:

```powershell
.\Ysindrolir\scripts\build_apostate_package.ps1
.\Ysindrolir\scripts\test_apostate_tracking.ps1
.\Ysindrolir\scripts\test_apostate_package.ps1
```

The builder updates only maintained Apostate entries and the source-specific AK
Sensitivity handling. It preserves the Occultist folder. The tracking test also
accepts `-LogPath 'C:\Users\shuji\Downloads\MFplMY9.html'` for the original Shrivel log.
