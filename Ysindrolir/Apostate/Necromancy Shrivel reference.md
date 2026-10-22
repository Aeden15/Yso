# Necromancy: Shrivel

See also the [Necromancy skillchart](Necromancy%20skillchart.md) for the wider
skillset, including Leprosy's random limb effects and Vivisect's requirements.

Source: supplied in-game `AB SHRIVEL` screenshot; captured 2026-10-19.

- **Class / skillset:** Apostate / Necromancy
- **ABADMIN ID:** 129
- **Syntax:** `SHRIVEL <arms/legs> <target>` or
  `SHRIVEL <left/right> <arm/leg> <target>`
- **Works against:** adventurers
- **Listed recovery:** 2.10 seconds of equilibrium
- **Resource:** 300 mana
- **Effect:** destroys the marrow of the affected limb, rendering it useless.

AK's new `Apostate Group / Necromancy` folder handles the four existing score
keys: `leftarm`, `rightarm`, `leftleg`, `rightleg`. These are affliction scores,
not percentage limb damage. It does not enable the Occultist folder.

## Captured responses

The original `MFplMY9.html` log contains 15 responses, represented by these forms:

```text
You touch Beltsa's left leg, and it shrivels away.
You reach out and touch Beltsa's left arm, but you can shrivel it no further.
You reach out and stroke an arm of Beltsa, and it withers away.
You reach out and grasp Beltsa's leg in an iron grip, and it shrivels feebly.
```

Seven responses identify a side; both side-specific forms confirm that limb's
existing score at 100. AK's normal cure/reset handling can clear it.

Eight responses omit a side (four arm and four leg responses). They are kept in
`ak.apostate.shrivel_unresolved[lowercase_target]` with arm/leg observation counts,
last kind, and timestamp. These are historical observations, not current limb
status. They never assign left or right, never imply successive casts hit
different limbs, and never establish Vivisect readiness. Target changes,
disconnects and class updates clear the observations.

Only responses for the current target are accepted. A repeated confirmation of
an already-confirmed limb does not add another gain. No automatic Vivisect is
implemented. Occultist's original Shrivel trigger remains unchanged.

The stripped response fixture is in `fixtures/shrivel_responses.txt`; it excludes
unrelated chat and other content from the original HTML log.
