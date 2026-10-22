# Apostasy skillchart — Apostate

Source: the 14 supplied in-game AB screenshots captured **2026-10-19**,
covering the 20 abilities below. This is a partial skillset reference, kept
alongside the [Evileye skillchart](Evileye%20skillchart.md).
Structured data: [apostasy_reference.lua](apostasy_reference.lua), available as
`Yso.ref.apostate.apostasy` in the package.

**Standard demon summons require a drawn pentagram**, per the user's clarification.
This is a summoning prerequisite, not a blanket requirement on every attack or
order belonging to the ability. It is recorded separately as `summon_requires`.
**Bloodpact** is the captured setup path that creates a pentagram and selected
demon together, using fresh blood on the daegger.

Unspecified costs, durations and recovery numbers remain unknown, not zero.
Listed recovery is not a runtime readiness timer. No command sending or automatic
offense is added by these reference files.

## Ability chart

`EQ` = equilibrium; `BAL` = balance; `BH` = Baalzadeen health.
Source suffixes identify `Screenshot 2026-10-19 HHMMSS.png` in
`C:/Users/shuji/OneDrive/Pictures/Screenshots/`.

| Ability / AB ID | Syntax | Listed recovery / resource | Affliction or effect | Source |
|---|---|---|---|---|
| Daegger / 159 | `SUMMON DAEGGER`; `STAB <target>` | EQ, number unspecified; 300 mana shown without per-command allocation | Envenomed stab has a chance to deliver the relevant venom affliction; no fixed affliction. | 210141 |
| Hunt / 161 | `DAEGGER LEVITATE`; `DAEGGER HUNT <target>` | 4.00s EQ; resource unspecified | Guided attack, retries misses; higher Apostasy gives more passes. No fixed affliction supplied. | 210146 |
| Envenom / 164 | `ENVENOM DAEGGER WITH <venom>`; `WIPE <weapon>` | Recovery/resource unspecified | Prepares venom-dependent afflictions; last-on, first-off, one venom consumed per weapon hit. | 210159 |
| Baalzadeen / 166 | `SUMMON BAALZADEEN`; `BANISH BAALZADEEN` | 2.00s EQ; 0.50% life essence | Primary demon; enables its commands. No direct affliction. | 210254 |
| Horror / 174 | `DEMON HORROR <target>` | 2.00s EQ; 125 BH | Fear effect; no persistent AK fear score is assumed. | 210254 |
| Fiend / 176 | `SUMMON FIEND`; `ORDER FIEND ATTACK <target>`; `ORDER FIEND PASSIVE` | 4.00s EQ; 150 mana | Serious bleeding damage; exact bleeding amount unspecified. | 210307 |
| Scorch / 178 | `DEMON SCORCH <icewall>` | 2.50s EQ; 150 BH | Melts icewalls and withers Reclamation vines. No affliction. | 210307 |
| Fortify / 188 | `DEMON FORTIFY` | 2.00s EQ; some player health, amount unspecified | Replenishes Baalzadeen power. No target affliction. | 210333 |
| Apathy / 190 | `DEMON APATHY` | 3.00s EQ; 250 BH | Defers attack damage for ten seconds; then applies accumulated damage in one blow, reduced by 40%. | 210333 |
| Shadowstrike / 192 | `DAEGGER SHADOWSTRIKE <target>` | 4.50s EQ; resource unspecified | Adventurers: impalement-equivalent restraint and ongoing damage until writhing free. Denizens: cutting damage on impact. | 210410 |
| Beckon / 194 | `DEMON BECKON [<target>]` | 4.00s EQ; 300 BH | Draws a specific person or everybody in surrounding rooms toward your room. Forced movement, not a persistent affliction. | 210437 |
| Daemonite / 196 | `SUMMON DAEMONITE`; `ORDER DAEMONITE ATTACK <target>`; `ORDER DAEMONITE PASSIVE` | 4.00s EQ; 150 mana | Repeated balance disruption; no persistent affliction specified. | 210437 |
| Sear / 200 | `DEMON SEAR <target>`; `DEMON SEAR OFF`; `DEMON REST` | 2.00s EQ; 50 BH shown; continuing BH drain on adventurer ignitions | Adventurers: repeated ablaze, AK `aflame`. Denizens: fire damage without demon-health loss. | 210506 |
| Puncture / 202 | `DAEGGER PUNCTURE <target>` | **2.15s BAL**; resource unspecified | Delivers a venom-dependent affliction; bypasses rebounding. Shield bypass is not established. | 210537 |
| Eliminate / 204 | `DAEGGER ELIMINATE <target>` | 3.50s EQ; channel duration/resource unspecified | **Channeled instant kill**. Interrupted by being knocked over, paralysed or webbed; successful completion penetrates target defences. | 210537 |
| Nightmare / 212 | `SUMMON NIGHTMARE` | 4.00s EQ; 150 mana | **Hypersomnia → dementia → hellsight**. Cannot exist in sunlight, even with a pentagram. | 210557 |
| Bloodworms / 206 | `SUMMON BLOODWORMS` | 4.00s EQ; 500 mana | Non-deaf victims: **masochism → dizziness → mental and physical damage**. Spreads into surrounding rooms after a delay. | 210610 |
| Stain / 216 | `DEMON STAIN <target>` | 3.00s EQ; 300 BH | Temporary reduction of various attributes; exact attributes, amounts, duration and AK key unspecified. AB states no known cure besides death. | 210631 |
| Bloodpact / 319 | `DEMON BLOODPACT <target> FOR <NIGHTMARE\|FIEND\|DAEMONITE>` | Recovery/resource unspecified | Immediately creates a pentagram and selected demon; does not itself apply its afflictions. | 210631 |
| Corrupt / 224 | `DEMON CORRUPT <target> [affliction]` | 3.00s EQ; 200 BH | Lifts Evileye-applied curses at a price; resulting formula and optional argument semantics are not explained in this capture. No new `corruption` score is assumed. | 210646 |

## Requirements and target types

- Standard summoning actions for Daegger, Baalzadeen, Fiend, Daemonite, Nightmare,
  and Bloodworms carry the user-specified drawn-pentagram requirement.
- Shadowstrike requires the daegger to have been levitated.
- Envenom requires the selected venom in a vial in inventory. Its next delivered
  affliction depends on the last venom applied; existing AK venom names remain
  the mapping source. Do not credit an affliction just from envenoming or sending.
- Bloodpact requires **fresh blood from the selected target** on the daegger,
  supplied briefly by a Hunt or Puncture hit. No numeric freshness timeout was
  provided. It creates the pentagram rather than requiring a prior one.
- Hunt power depends on intelligence, hit chance on Weaponry, and passes on
  Apostasy. Daegger stab strength/accuracy and, to a lesser extent, speed depend
  on Apostasy.
- Scorch takes one cast against vines if their reclaimer is outside the area,
  two if in the area but not the room, and three if in the room.
- Daegger, Hunt, Horror, Fiend, Daemonite, Puncture, Eliminate, Nightmare, Stain,
  Bloodpact and Corrupt list adventurers. Shadowstrike and Sear list adventurers
  and denizens; Beckon lists adventurers and room; Bloodworms lists room.
  Other works-on fields were not supplied and remain unspecified.

## Affliction and tracking notes

- Nightmare's three named outcomes use AK's existing `hypersomnia`, `dementia`,
  and `hellsight` names. Bloodworms uses `masochism` then `dizziness`; deafness
  prevents the described effect. Do not treat the damage stage as another affliction.
- Sear already has an Apostate AK trigger using `ak.flameon("notadditive")`
  and the `aflame` score. Its adventurer outcome is distinct from denizen damage.
- Shadowstrike's impalement is a status: AK has `affstrack.impale` outside its
  numeric affliction scores. This reference does not invent its success messages.
- Fiend's bleeding and Daemonite's balance disruption are effects, not new binary
  affliction keys. Horror is a fear effect; Stain is an attribute debuff.
- A successful Corrupt lifts Evileye curses. This reference does not predict the
  unspecified conversion or modify tracked afflictions on send. Do not confuse
  this command with unrelated abilities that happen to use a `corruption` score.
- Eliminate is a channel with an instant-kill outcome, not an immediate cast or
  gained affliction. **3.50s is listed EQ recovery, not a verified channel time.**
  This update adds no Eliminate alias, channel timer, or automatic execution.

Rebuild the maintained package entries with
`Ysindrolir/scripts/build_apostate_package.ps1`. Existing Evileye and Necromancy
tracking behavior is unchanged by adding this reference.
