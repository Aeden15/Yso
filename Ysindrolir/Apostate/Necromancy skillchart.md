# Necromancy skillchart — Apostate

Source: the ten supplied in-game AB screenshots captured **2026-10-19**.
Coverage: **14 detailed entries plus a partial Essence entry**, not the entire
skillset. Missing fields remain unspecified, not zero. Structured companion:
[necromancy_reference.lua](necromancy_reference.lua), exposed in the package as
`Yso.ref.apostate.necromancy`.

Related: [Evileye](Evileye%20skillchart.md), [Apostasy](Apostasy%20skillchart.md),
and [all Apostate references](Apostate%20skillcharts.md).

`EQ` = equilibrium; `BAL` = balance; `LE` = life essence percentage. Listed recovery
is AB data, not runtime readiness or a channel duration. Multi-command entries
retain the displayed costs without inventing a separate cost for every command.
Source suffixes identify `Screenshot 2026-10-19 HHMMSS.png` in
`C:/Users/shuji/OneDrive/Pictures/Screenshots/`.

## Ability chart

| Ability / AB ID | Syntax | Listed recovery / resource | Affliction or effect | Source |
|---|---|---|---|---|
| Chill / 115 | `CHILL <target>`; `CHILL <direction>` | 2.20s EQ; 100 mana | Target: caloric removal → shivering → frozen. Direction: destroys a firewall blocking that exit. | 211530 |
| Decay / 117 | `DECAY <target>` | 4.00s EQ; 80 mana | Magical damage against adventurers and denizens; no fixed affliction specified. | 211530 |
| Screech / 120 | `SCREECH` | 4.00s EQ; 70 mana | Room-wide forced movement of those who can hear; no persistent affliction specified. | 211549 |
| Shrivel / 129 | `SHRIVEL <arms/legs> <target>`; `SHRIVEL <left/right> <arm/leg> <target>` | 2.10s EQ; 300 mana | Disables affected limbs. Existing AK keys: `leftarm`, `rightarm`, `leftleg`, `rightleg`; not all four from one cast. | 211549 |
| Essence / ID not captured | `ESSENCE` | Not captured | Reports current life essence. Only syntax and this description are visible. | 211644 |
| Sapience / 132 | `SAPIENCE` | 3.50s EQ; 1.50% LE | Converts life essence to mana; amount restored unspecified. | 211644 |
| Vigour / 133 | `VIGOUR` | 3.50s EQ; 1.50% LE | Converts life essence to health; amount restored unspecified. | 211644 |
| Soulstorm / 142 | `SOULSTORM <target>` | 4.00s EQ; 1% LE listed; reduced unspecified costs against denizens | Adventurers: attempts morph removal. Denizens: 10% extra damage from the specific attacks below. | 211732 |
| Disfigure / 140 | `DISFIGURE <target>` | 3.00s EQ; resource unspecified | `disloyalty`, matching the existing AK confirmation trigger. | 211745 |
| Leprosy / 146 | `LEPROSY` | 4.50s EQ; 3.50% LE and 500 mana | Random limbs shrivel on others in the room, **friend or foe**. Exact limb keys require confirmation. | 211801 |
| Soulspear / 152 | `EVOKE SOULSPEAR FROM <target corpse>`; `THROW SOULSPEAR AT <target> <direction>` | **6.00s BAL**; 2.50% LE | Ranged shield/prismatic-barrier removal; otherwise creates Gravehands at the target location. | 211805 |
| Transverse / 153 | `TRANSVERSE <target>` | 3.00s EQ; 2% LE and 500 mana | Travel from a Gravehands room; destination requirements determine instant versus delayed travel. | 211820 |
| Blackwind / 154 | `BLACKWIND`; `HUMAN`; `CHOKE <target>`; `SURGE <direction>` | 4.00s EQ; 5% LE and 500 mana; ongoing willpower drain | Form and movement abilities. Surge is channeled; it bypasses closed but not locked doors. | 211824 |
| Desecration / 156 | `DESECRATE <rite>` | **4.00s BAL**; 3.50% LE and 500 mana | Removes a devotional rite from the room. When its creator is present, removal delays and prevents other actions. | 211849 |
| Vivisect / 157 | `VIVISECT <target>` | 4.00s EQ; 300 mana | Instant kill when all four target limbs are withered; successful completion defeats starburst resurrection. | 211849 |

## Conditional outcomes and requirements

- **Chill:** nullifies caloric if present. Without caloric, causes shivering;
  chilling a shivering target freezes them completely. Shivering regularly causes
  equilibrium loss. AK has a `frozen` score, but this AB does not establish its
  numeric stage encoding or a separate `shivering` score.
- **Shrivel:** retain the existing side-specific confirmation and unresolved
  unsided observations. See [the detailed Shrivel reference](Necromancy%20Shrivel%20reference.md)
  for captured messages. These are limb-affliction scores, not percentage damage.
- **Leprosy:** the four limb keys enumerate possible outcomes, not a guaranteed
  number of affected limbs or sides. Do not assign them based on a command send.
- **Soulstorm:** attempts to return a metamorphosised adventurer to mortal form.
  Against denizens, the 10% damage increase applies specifically to Necromancy
  **Decay and Taint**, Evileye **Bleed**, and weapon-based **Weaponmastery attacks
  performed by an Infernal**. EQ/essence costs are greatly reduced against
  denizens, but exact reduced costs and effect duration are not given.
- **Soulspear:** requires an adventurer corpse **above level 30**. Higher corpse
  level increases its power. Throwing targets somebody outside your room but
  within line of sight. It shatters shields/prismatic barriers or, if neither is
  present, creates hands of the grave at the destination. No Curseward removal
  is inferred.
- **Transverse:** Gravehands must be present at origin. With Gravehands also at
  destination, travel is instant. Without destination Gravehands, the target
  must practise Necromancy and travel is delayed. No delay length is supplied.
- **Blackwind:** heavily restricts both freedom and vulnerability to harm while
  rapidly draining willpower. Choke is usable in the form; Human reverts it.
  Surge channels through closed doors, never locked doors. No named persistent
  Choke affliction or numeric channel/drain duration is supplied.
- **Desecration:** the AB's person who laid the rite must be present to trigger
  the action-restricting delay. Do not interpret the listed 4.00s balance as its
  delay duration.
- **Vivisect:** the AB defines the victim's helpless condition as **all four
  limbs withered**. No separate prone requirement is added. Its successful kill
  prevents starburst resurrection. This capture establishes neither a channel
  duration nor a channel classification; it is kept separate from Apostasy's
  explicitly channeled Eliminate.

Chill, Shrivel, Disfigure, Soulspear, Transverse, Blackwind and Vivisect list
adventurers. Decay and Soulstorm list adventurers and denizens. Screech, Leprosy
and Desecration list room. Essence, Sapience and Vigour have no captured
works-on field; the latter two explicitly describe recovery of your own resources.

## Package integration

The maintained builder embeds this reference as **Necromancy reference**.
It sends no commands, adds no handlers or aliases, and changes no AK tracking.
Run `Ysindrolir/scripts/build_apostate_package.ps1`, then the existing Apostate
tracking and utility checks. Automatic Vivisect and offensive coordination remain
outside this reference addition.
