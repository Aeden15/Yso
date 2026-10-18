--========================================================--
-- Monk Skill Reference (Tekura / Telepathy / Shikudo)
--  • Reference-first: humans and the Monk stub scripts.
--  • Built from in-game AB outputs.
--  • AB IDs 848 and 853 are defences and are not stored here.
--========================================================--

Yso = Yso or {}
Yso.ref = Yso.ref or {}
Yso.ref.monk = Yso.ref.monk or {}

local M = Yso.ref.monk

M.meta = {
  class = "Monk",
  updated = "2026-10-04",
  notes = {
    "AB IDs 848 and 853 are defences and are not part of this skill reference.",
    "Entering a tekura stance usually consumes balance. After a tekura kick or punch, a skilled practitioner can transition immediately, with a slightly slower recovery.",
    "Shikudo strikes and kicks are performed in a combination. Dispatch is the exception and is used outside a combination.",
  },
}

local function skill(row)
  row.syntax = row.syntax or {}
  row.notes = row.notes or {}
  row.afflicts = row.afflicts or {}
  row.requires = row.requires or {}
  return row
end

M.tekura = {
  horse = skill({
    name = "Horse",
    abadmin_id = 840,
    syntax = { "HRS", "LEAP <direction>" },
    works_on = "self",
    cooldown_s = 2.00,
    cooldown_lane = "balance",
    commands = {
      { cmd = "HRS", role = "stance" },
      { cmd = "LEAP", role = "utility" },
    },
    notes = {
      "First stance. Ideal for striking.",
      "Standard strikes can be used with the slam and wrench throws.",
      "Leap over obstructions in a given direction.",
    },
  }),

  combo = skill({
    name = "Combo",
    abadmin_id = 841,
    syntax = { "COMBO <target> <kick|stance> [limb] <punch1> [limb] <punch2> [limb] [JPK]" },
    works_on = "adventurers and denizens",
    cooldown_lane = "arms_and_legs",
    commands = {
      { cmd = "COMBO", role = "combo" },
    },
    notes = {
      "Limb targets may be omitted or included.",
      "A full combo is one kick and two punches.",
      "Requires balance on both arms and legs.",
      "Appending JPK attempts a jumpkick before the rest of the combo, when the combo does not already include a jumpkick.",
    },
  }),

  jab = skill({
    name = "Jab",
    abadmin_id = 842,
    syntax = { "JBP <target> <HEAD|ARMS>" },
    works_on = "adventurers",
    cooldown_s = 3.00,
    cooldown_lane = "arm",
    commands = {
      { cmd = "JBP", role = "punch" },
    },
    notes = {
      "Head: restores the target's hearing.",
      "Arms: disables the target's parry for a very short time.",
    },
  }),

  snapkick = skill({
    name = "Snapkick",
    abadmin_id = 843,
    syntax = { "SNK <target> left/right" },
    works_on = "adventurers and denizens",
    cooldown_s = 4.00,
    cooldown_lane = "leg",
    commands = {
      { cmd = "SNK", role = "kick", limb_side = "legs" },
    },
    notes = {
      "A low kick that attacks the legs.",
    },
  }),

  hook = skill({
    name = "Hook",
    abadmin_id = 844,
    syntax = { "HKP <target>" },
    works_on = "adventurers and denizens",
    cooldown_s = 4.00,
    cooldown_lane = "arm",
    commands = {
      { cmd = "HKP", role = "punch" },
    },
    notes = {
      "A punch aimed at the torso.",
    },
  }),

  eagle = skill({
    name = "Eagle",
    abadmin_id = 845,
    syntax = { "EGS", "HGK <target>" },
    works_on = "adventurers and self",
    cooldown_s = 2.00,
    cooldown_lane = "balance",
    commands = {
      { cmd = "EGS", role = "stance" },
      { cmd = "HGK", role = "kick" },
    },
    notes = {
      "Kicks and punches are faster from this stance.",
      "Highkick brings down someone above you and prones them.",
    },
  }),

  sidekick = skill({
    name = "Sidekick",
    abadmin_id = 846,
    syntax = { "SDK <target>" },
    works_on = "adventurers and denizens",
    cooldown_s = 4.00,
    cooldown_lane = "leg",
    commands = {
      { cmd = "SDK", role = "kick" },
    },
    notes = {
      "Drives the leg straight into the torso.",
    },
  }),

  uppercut = skill({
    name = "Uppercut",
    abadmin_id = 847,
    syntax = { "UCP <target>" },
    works_on = "adventurers and denizens",
    cooldown_s = 4.00,
    cooldown_lane = "arm",
    commands = {
      { cmd = "UCP", role = "punch" },
    },
    notes = {
      "Attacks the head.",
    },
  }),

  palmstrike = skill({
    name = "Palmstrike",
    abadmin_id = 849,
    syntax = { "PMP <target>" },
    works_on = "adventurers",
    cooldown_s = 3.00,
    cooldown_lane = "arm",
    commands = {
      { cmd = "PMP", role = "punch" },
    },
    afflicts = { "impatience", "stupidity" },
    notes = {
      "Delivers impatience if the target does not have it, or stupidity if they do.",
    },
  }),

  hammerfist = skill({
    name = "Hammerfist",
    abadmin_id = 850,
    syntax = { "HFP <target> left/right" },
    works_on = "adventurers and denizens",
    cooldown_s = 4.00,
    cooldown_lane = "arm",
    commands = {
      { cmd = "HFP", role = "punch", limb_side = "legs" },
    },
    notes = {
      "Brings the fist down on a leg.",
    },
  }),

  cat = skill({
    name = "Cat",
    abadmin_id = 851,
    syntax = { "CTS" },
    works_on = "self",
    cooldown_s = 2.00,
    cooldown_lane = "balance",
    commands = {
      { cmd = "CTS", role = "stance" },
    },
    notes = {
      "For facing heavy offense.",
      "Superior defence and far more blocks.",
      "Harder to attack, and your own attacks are slower.",
    },
  }),

  roundhouse = skill({
    name = "Roundhouse",
    abadmin_id = 852,
    syntax = { "RHK <target>" },
    works_on = "adventurers and denizens",
    cooldown_s = 4.00,
    cooldown_lane = "leg",
    commands = {
      { cmd = "RHK", role = "kick" },
    },
    notes = {
      "Shatters a magical shield.",
      "If the torso is damaged, the target is proned when their shield or prismatic barrier breaks.",
      "In Rat stance, roundhouse also shatters prismatic barriers.",
    },
  }),

  sweep = skill({
    name = "Sweep",
    abadmin_id = 854,
    syntax = { "SWK <target>" },
    works_on = "adventurers",
    cooldown_s = 4.50,
    cooldown_lane = "leg",
    commands = {
      { cmd = "SWK", role = "kick" },
    },
    notes = {
      "Attempts to sweep the legs out from under the opponent.",
    },
  }),

  bear = skill({
    name = "Bear",
    abadmin_id = 855,
    syntax = { "BRS" },
    works_on = "self",
    cooldown_s = 2.00,
    cooldown_lane = "balance",
    commands = {
      { cmd = "BRS", role = "stance" },
    },
    notes = {
      "Throws do more damage.",
      "Can intercept a fleeing enemy.",
      "Kicks and punches are slowed.",
    },
  }),

  slam = skill({
    name = "Slam",
    abadmin_id = 856,
    syntax = { "SLT <target>" },
    works_on = "adventurers",
    cooldown_s = 3.00,
    cooldown_lane = "balance",
    commands = {
      { cmd = "SLT", role = "throw" },
    },
    afflicts = { "scrambledbrains" },
    requires = { "prone" },
    notes = {
      "Targets the head. Prone opponents only.",
      "Scrambles the brain and removes the ability to naturally reject mental locks.",
      "Lasts longer if the head is already damaged.",
    },
  }),

  moonkick = skill({
    name = "Moonkick",
    abadmin_id = 857,
    syntax = { "MNK <target> left/right" },
    works_on = "adventurers and denizens",
    cooldown_s = 4.00,
    cooldown_lane = "leg",
    commands = {
      { cmd = "MNK", role = "kick", limb_side = "arms" },
    },
    notes = {
      "The foot travels in a crescent and attacks the arms.",
    },
  }),

  spear = skill({
    name = "Spear",
    abadmin_id = 858,
    syntax = { "SPP <target> left/right" },
    works_on = "adventurers and denizens",
    cooldown_s = 4.00,
    cooldown_lane = "arm",
    commands = {
      { cmd = "SPP", role = "punch", limb_side = "arms" },
    },
    notes = {
      "A rigid-hand punch that damages the arms.",
    },
  }),

  rat = skill({
    name = "Rat",
    abadmin_id = 859,
    syntax = { "RTS" },
    works_on = "self",
    cooldown_s = 2.00,
    cooldown_lane = "balance",
    commands = {
      { cmd = "RTS", role = "stance" },
    },
    notes = {
      "Superior accuracy against high avoidance.",
      "Blocks more often.",
      "Roundhouse kicks in this stance shatter prismatic barriers and magical shields.",
    },
  }),

  thrustkick = skill({
    name = "Thrustkick",
    abadmin_id = 860,
    syntax = { "THK <target> <direction>" },
    works_on = "adventurers",
    cooldown_s = 4.00,
    cooldown_lane = "leg",
    commands = {
      { cmd = "THK", role = "kick", needs_direction = true },
    },
    notes = {
      "Kicks the opponent away in the specified direction.",
    },
  }),

  wrench = skill({
    name = "Wrench",
    abadmin_id = 861,
    syntax = { "WRT <target> <HEAD|TORSO|LEFT ARM|RIGHT ARM>" },
    works_on = "adventurers",
    cooldown_s = 4.00,
    cooldown_lane = "balance",
    commands = {
      { cmd = "WRT", role = "throw" },
    },
    afflicts = { "epilepsy", "bruisedribs" },
    requires = { "damaged_limb" },
    notes = {
      "Only a limb that is already damaged. Does not require prone.",
      "Head: periodic epilepsy.",
      "Torso: bruised ribs. Also prones the target if both arms are broken.",
      "Either arm: yanks the target off balance and throws them to the ground.",
    },
  }),

  axe = skill({
    name = "Axe",
    abadmin_id = 862,
    syntax = { "AXK <target>" },
    works_on = "adventurers and denizens",
    cooldown_s = 6.50,
    cooldown_lane = "balance",
    commands = {
      { cmd = "AXK", role = "kick" },
    },
    afflicts = { "scrambledbrains", "blackout" },
    requires = { "prone" },
    notes = {
      "Highly inaccurate. Prone opponents only.",
      "Extremely high head damage.",
      "Brief scrambled brains. Severe blackout if the head is mangled.",
    },
  }),

  scorpion = skill({
    name = "Scorpion",
    abadmin_id = 864,
    syntax = { "SCS" },
    works_on = "self",
    cooldown_s = 2.00,
    cooldown_lane = "balance",
    commands = {
      { cmd = "SCS", role = "stance" },
    },
    notes = {
      "Sacrifices defence for offense.",
      "Punches and kicks do more damage and are as fast as possible.",
      "Blocks far less often.",
      "Does not change how quickly a target's limbs break, only how much health damage the attacks do.",
    },
  }),

  whirlwind = skill({
    name = "Whirlwind",
    abadmin_id = 865,
    syntax = { "WWK <target>" },
    works_on = "adventurers and denizens",
    cooldown_s = 4.50,
    cooldown_lane = "leg",
    commands = {
      { cmd = "WWK", role = "kick" },
    },
    afflicts = { "scrambledbrains" },
    notes = {
      "Two spinning crescent kicks aimed at the head.",
      "Briefly delivers scrambled brains.",
    },
  }),

  bladehand = skill({
    name = "Bladehand",
    abadmin_id = 866,
    syntax = { "BLP <target>" },
    works_on = "adventurers",
    cooldown_s = 3.00,
    cooldown_lane = "arm",
    commands = {
      { cmd = "BLP", role = "punch" },
    },
    afflicts = { "dizziness" },
    notes = {
      "A strike to the side of the neck that inflicts dizziness.",
    },
  }),

  pinch = skill({
    name = "Pinch",
    abadmin_id = 867,
    syntax = { "PNB", "UNBLOCK PNB" },
    works_on = "adventurers",
    cooldown_s = 1.00,
    cooldown_lane = "balance",
    resource_mana = 50,
    commands = {
      { cmd = "PNB", role = "block" },
      { cmd = "UNBLOCK PNB", role = "block" },
    },
    notes = {
      "A block that can stun an opponent who is already weakened enough.",
    },
  }),

  backbreaker = skill({
    name = "Backbreaker",
    abadmin_id = 868,
    syntax = { "BBT <target>" },
    works_on = "adventurers",
    cooldown_s = 4.00,
    cooldown_lane = "balance",
    commands = {
      { cmd = "BBT", role = "throw" },
    },
    requires = { "prone" },
    notes = {
      "Prone opponents only. Damage rises as the torso is more damaged.",
      "Four backbreakers in quick succession snap the spine and kill.",
      "Bruised ribs reduces that number to three.",
    },
  }),

  jumpkick = skill({
    name = "Jumpkick",
    abadmin_id = 869,
    syntax = { "JPK <target>" },
    works_on = "adventurers",
    cooldown_s = 4.00,
    cooldown_lane = "leg",
    commands = {
      { cmd = "JPK", role = "kick" },
    },
    notes = {
      "From an adjacent room, fly in and slam an outstretched foot into the target.",
      "Knocks the target to the floor and stuns them.",
    },
  }),

  dragon = skill({
    name = "Dragon",
    abadmin_id = 870,
    syntax = { "DRS" },
    works_on = "self",
    cooldown_s = 2.00,
    cooldown_lane = "balance",
    commands = {
      { cmd = "DRS", role = "stance" },
    },
    notes = {
      "Recover from mental equilibrium loss far more swiftly.",
      "Turn aside many blows with blocks.",
    },
  }),
}

M.telepathy = {
  scythe = skill({
    name = "Scythe",
    abadmin_id = 941,
    syntax = { "MIND SCYTHE" },
    works_on = "adventurers",
    cooldown_s = 4.00,
    cooldown_lane = "equilibrium",
    resource_mana = 50,
    commands = {
      { cmd = "MIND SCYTHE", role = "finish" },
    },
    afflicts = {},
    requires = { "mangledhead" },
    mental_pool = { "stupidity", "impatience", "dizziness", "epilepsy", "confusion" },
    mental_pool_min = 2,
    notes = {
      "No target argument.",
      "Requires a mangled head and at least two of stupidity, impatience, dizziness, epilepsy, or confusion.",
    },
  }),
}

M.shikudo = {
  combo = skill({
    name = "Combo",
    abadmin_id = 2486,
    syntax = { "COMBO <target> <attack1> [limb] [attack2] [limb] [attack3] [limb] [TRANSITION <form>]" },
    commands = {
      { cmd = "COMBO", role = "combo" },
    },
    notes = {
      "No more than three attacks, only one of which may be a kick.",
      "Example: COMBO GATTAN'BAHAR DART HEAD LIVESTRIKE FLASHHEEL LEFT.",
    },
  }),

  tykonos = skill({
    name = "Tykonos",
    abadmin_id = 2487,
    syntax = { "ADOPT TYKONOS FORM" },
    commands = {
      { cmd = "ADOPT TYKONOS FORM", role = "form" },
    },
    transitions = { "Willows Shaken by the Wind" },
    attacks = { "THRUST", "SWEEP", "RISINGKICK" },
    notes = {
      "Primarily a defensive form. Damage is diverted more easily.",
      "Transitions: Willows Shaken by the Wind.",
      "Attacks: THRUST, SWEEP, RISINGKICK.",
    },
  }),

  thrust = skill({
    name = "Thrust",
    abadmin_id = 2488,
    syntax = { "THRUST <limb>" },
    commands = {
      { cmd = "THRUST", role = "strike" },
    },
    notes = {
      "The most basic strike. A thrust to a limb with the staff.",
      "Must be performed in a combination, along with other Shikudo strikes and kicks. See AB SHIKUDO COMBO.",
    },
  }),

  willow = skill({
    name = "Willow",
    abadmin_id = 2491,
    syntax = { "ADOPT WILLOW FORM" },
    form_name = "Willows Shaken by the Wind",
    commands = {
      { cmd = "ADOPT WILLOW FORM", role = "form" },
    },
    transitions = { "Willows in Rain Storm" },
    attacks = { "DART", "SWEEP", "HIRU", "FLASHHEEL", "HIRAKU" },
    notes = {
      "Form name: Willows Shaken by the Wind. A speed form.",
      "Strikes and kicks are faster than normal.",
      "While wielding a staff, you may knock arrows out of the air.",
      "Transitions: Willows in Rain Storm.",
      "Attacks: DART, SWEEP, HIRU, FLASHHEEL, HIRAKU.",
    },
  }),

  dart = skill({
    name = "Dart",
    abadmin_id = 2492,
    syntax = { "DART <limb>" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "DART", role = "strike" },
    },
    notes = {
      "Sacrifices damage for a swift thrust to a limb.",
      "Must be performed in a combination, along with other Shikudo strikes and kicks. See AB SHIKUDO COMBO.",
    },
  }),

  kata = skill({
    name = "Kata",
    abadmin_id = 2493,
    syntax = { "TRANSITION TO <form> FORM" },
    commands = {
      { cmd = "TRANSITION TO", role = "kata" },
    },
    notes = {
      "Each strike or kick becomes part of the kata chain.",
      "A chain of at least 5 actions may TRANSITION TO THE <form> FORM and enter that form immediately.",
      "Transitioning resets the kata chain.",
      "Only a form listed as a valid transition, and only a form you have studied.",
      "Staying in one form too long raises the chance of stumbling. Stumbling resets the kata and drops you into Tykonos.",
      "Tykonos is exempt and can hold a kata chain indefinitely. It has fewer viable strikes and kicks.",
    },
  }),

  flashheel = skill({
    name = "Flashheel",
    abadmin_id = 2494,
    syntax = { "FLASHHEEL <LEFT|RIGHT>" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "FLASHHEEL", role = "kick" },
    },
    notes = {
      "Targets a knee and can break that limb in one blow.",
      "Must be performed in a combination, along with other Shikudo strikes and kicks. See AB SHIKUDO COMBO.",
    },
  }),

  sweep = skill({
    name = "Sweep",
    abadmin_id = 2495,
    syntax = { "SWEEP" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "SWEEP", role = "strike" },
    },
    notes = {
      "Sweeps someone off their feet with the staff.",
      "Consumes both arm balances, so it may not be combined with other strikes. It may be combined with a kick.",
      "Must be performed in a combination, along with other Shikudo strikes and kicks. See AB SHIKUDO COMBO.",
    },
  }),

  hiraku = skill({
    name = "Hiraku",
    abadmin_id = 2496,
    syntax = { "HIRAKU" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "HIRAKU", role = "strike" },
    },
    afflicts = { "anorexia", "stuttering" },
    notes = {
      "A strike to the face with the staff.",
      "Anorexia and stuttering. Stuns for a short time if the target is prone.",
    },
  }),

  rain = skill({
    name = "Rain",
    abadmin_id = 2497,
    syntax = { "ADOPT RAIN FORM" },
    form_name = "Willows in Rain Storm",
    commands = {
      { cmd = "ADOPT RAIN FORM", role = "form" },
    },
    transitions = { "Tykonos", "Live Oak" },
    attacks = { "RUKU", "KURO", "HIRU", "FRONTKICK" },
    notes = {
      "Form name: Willows in Rain Storm. An offensive form built on repeated strikes.",
      "Kata chains may be twice the normal length before stumbling, and damage rises as the chain grows.",
      "Equilibrium recovery is significantly increased.",
      "Transitions: Tykonos, Live Oak.",
      "Attacks: RUKU, KURO, HIRU, FRONTKICK.",
    },
  }),

  hiru = skill({
    name = "Hiru",
    abadmin_id = 2498,
    syntax = { "HIRU" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "HIRU", role = "strike" },
    },
    afflicts = { "dizziness", "confusion" },
    notes = {
      "A blow to the head with the staff.",
      "Dizziness. If the target is prone, it may also afflict confusion.",
    },
  }),

  ruku = skill({
    name = "Ruku",
    abadmin_id = 2499,
    syntax = { "RUKU <TORSO|LEFT|RIGHT>" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "RUKU", role = "strike" },
    },
    afflicts = { "clumsiness", "healthleech", "slickness" },
    notes = {
      "Arms: clumsiness, or healthleech if clumsiness is already present.",
      "Torso: slickness.",
    },
  }),

  frontkick = skill({
    name = "Frontkick",
    abadmin_id = 2500,
    syntax = { "FRONTKICK <LEFT|RIGHT>" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "FRONTKICK", role = "kick" },
    },
    notes = {
      "A straight kick at either arm, aimed at the nerve clusters below the shoulder.",
      "Prone the target if it connects.",
      "Must be performed in a combination, along with other Shikudo strikes and kicks. See AB SHIKUDO COMBO.",
    },
  }),

  kuro = skill({
    name = "Kuro",
    abadmin_id = 2501,
    syntax = { "KURO <LEFT|RIGHT>" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "KURO", role = "strike" },
    },
    afflicts = { "weariness", "lethargy" },
    notes = {
      "Targets the muscles of a leg.",
      "Weariness, or lethargy if weariness is already present.",
    },
  }),

  oak = skill({
    name = "Oak",
    abadmin_id = 2502,
    syntax = { "ADOPT OAK FORM" },
    form_name = "Live Oak",
    commands = {
      { cmd = "ADOPT OAK FORM", role = "form" },
    },
    transitions = { "Willows Shaken by the Wind", "Gaital" },
    attacks = { "LIVESTRIKE", "NERVESTRIKE", "RUKU", "RISINGKICK", "KURO" },
    notes = {
      "Form name: Live Oak. Strikes and kicks do increased damage.",
      "Transitions: Willows Shaken by the Wind, Gaital.",
      "Attacks: LIVESTRIKE, NERVESTRIKE, RUKU, RISINGKICK, KURO.",
    },
  }),

  livestrike = skill({
    name = "Livestrike",
    abadmin_id = 2503,
    syntax = { "LIVESTRIKE" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "LIVESTRIKE", role = "strike" },
    },
    afflicts = { "asthma" },
    notes = {
      "A thrust at the solar plexus that delivers asthma.",
      "Must be performed in a combination, along with other Shikudo strikes and kicks. See AB SHIKUDO COMBO.",
    },
  }),

  risingkick = skill({
    name = "Risingkick",
    abadmin_id = 2504,
    syntax = { "RISINGKICK <HEAD|TORSO>" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "RISINGKICK", role = "kick" },
    },
    notes = {
      "A high kick at the head or torso.",
      "Head of a prone opponent: a short stun.",
      "Torso of someone suffering internal trauma: a short stun.",
    },
  }),

  nervestrike = skill({
    name = "Nervestrike",
    abadmin_id = 2505,
    syntax = { "NERVESTRIKE" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "NERVESTRIKE", role = "strike" },
    },
    afflicts = { "paralysis" },
    notes = {
      "A strike to the side of the neck that delivers paralysis.",
      "Must be performed in a combination, along with other Shikudo strikes and kicks. See AB SHIKUDO COMBO.",
    },
  }),

  gaital = skill({
    name = "Gaital",
    abadmin_id = 2506,
    syntax = { "ADOPT GAITAL FORM" },
    commands = {
      { cmd = "ADOPT GAITAL FORM", role = "form" },
    },
    transitions = { "Willows in Rain Storm", "Unrelenting Storm" },
    attacks = { "NEEDLE", "SPINKICK", "SWEEP", "RUKU", "FLASHHEEL", "KURO", "JINZUKU", "DAWNKICK" },
    notes = {
      "Attacks slide through attempts to parry them.",
      "Transitions: Willows in Rain Storm, Unrelenting Storm.",
      "Attacks: NEEDLE, SPINKICK, SWEEP, RUKU, FLASHHEEL, KURO, JINZUKU, DAWNKICK.",
    },
  }),

  attrition = skill({
    name = "Attrition",
    abadmin_id = 2507,
    commands = {},
    notes = {
      "No standalone command. Append LIGHT after a staff strike inside a combination.",
      "That attack deals no limb damage. Health damage and any affliction are still delivered.",
      "Does not apply to kicks.",
      "Examples: THRUST LIGHT HEAD, NERVESTRIKE LIGHT.",
    },
  }),

  needle = skill({
    name = "Needle",
    abadmin_id = 2508,
    syntax = { "NEEDLE" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "NEEDLE", role = "strike" },
    },
    notes = {
      "A thrust to the throat that crushes the windpipe.",
      "Must be performed in a combination, along with other Shikudo strikes and kicks. See AB SHIKUDO COMBO.",
    },
  }),

  spinkick = skill({
    name = "Spinkick",
    abadmin_id = 2509,
    syntax = { "SPINKICK" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "SPINKICK", role = "kick" },
    },
    notes = {
      "Torso if the target is standing. Head if the target is prone.",
      "A head hit deals significantly more damage.",
      "If the target is prone with a damaged head, the kick immediately mangles the head.",
    },
  }),

  maelstrom = skill({
    name = "Maelstrom",
    abadmin_id = 2510,
    syntax = { "ADOPT MAELSTROM FORM" },
    form_name = "Unrelenting Storm",
    commands = {
      { cmd = "ADOPT MAELSTROM FORM", role = "form" },
    },
    transitions = { "Live Oak" },
    attacks = { "RUKU", "RISINGKICK", "SWEEP", "CRESCENT", "LIVESTRIKE", "JINZUKU" },
    notes = {
      "Form name: the Unrelenting Storm.",
      "While in a kai trance, strikes and kicks that deal damage generate kai. Parried or blocked hits do not.",
      "More kai raises resistance to damage.",
      "Transitions: Live Oak.",
      "Attacks: RUKU, RISINGKICK, SWEEP, CRESCENT, LIVESTRIKE, JINZUKU.",
    },
  }),

  hyperfocus = skill({
    name = "Hyperfocus",
    abadmin_id = 2511,
    syntax = { "HYPERFOCUS <limb|NONE>" },
    commands = {
      { cmd = "HYPERFOCUS", role = "utility" },
    },
    notes = {
      "Strikes against the chosen limb bypass parry.",
      "A strike on that limb deals half as much limb damage.",
    },
  }),

  crescent = skill({
    name = "Crescent",
    abadmin_id = 2512,
    syntax = { "CRESCENT" },
    works_on = "adventurers",
    commands = {
      { cmd = "CRESCENT", role = "kick" },
    },
    requires = { "prone" },
    notes = {
      "Prone foe only.",
      "At half health or less, the kai-enhanced kick slays them. Otherwise they dodge and recovery time is greatly increased.",
      "Launching the kick immediately flows into Tykonos.",
    },
  }),

  dispatch = skill({
    name = "Dispatch",
    abadmin_id = 2513,
    syntax = { "DISPATCH|INCAPACITATE <target> [form]" },
    works_on = "adventurers",
    commands = {
      { cmd = "DISPATCH", role = "finish" },
      { cmd = "INCAPACITATE", role = "finish" },
    },
    requires = { "prone", "damaged_head", "damaged_windpipe" },
    notes = {
      "Used outside a combination, in any form.",
      "The foe must be prone with a damaged head and windpipe.",
      "DISPATCH kills. INCAPACITATE stuns for a great length of time.",
      "An optional form is entered on a successful dispatch, ignoring transition limits.",
    },
  }),

  jinzuku = skill({
    name = "Jinzuku",
    abadmin_id = 2515,
    syntax = { "JINZUKU" },
    works_on = "adventurers and denizens",
    commands = {
      { cmd = "JINZUKU", role = "strike" },
    },
    afflicts = { "addiction" },
    notes = {
      "A strike to the kidneys. Addiction to the consumption of curatives.",
      "Must be performed in a combination, along with other Shikudo strikes and kicks. See AB SHIKUDO COMBO.",
    },
  }),

  dawnkick = skill({
    name = "Dawnkick",
    abadmin_id = 2846,
    syntax = { "DAWNKICK" },
    commands = {
      { cmd = "DAWNKICK", role = "kick" },
    },
    afflicts = { "epilepsy" },
    notes = {
      "A head kick against a standing or prone foe.",
      "Epilepsy lands shortly after the kick.",
      "If the target is prone, epilepsy is delivered again a short time later, and the damage is higher.",
    },
  }),
}

M.stances = {
  dragon = { name = "Dragon", command = "DRS", key = "dragon" },
  scorpion = { name = "Scorpion", command = "SCS", key = "scorpion" },
  rat = { name = "Rat", command = "RTS", key = "rat" },
  bear = { name = "Bear", command = "BRS", key = "bear" },
  cat = { name = "Cat", command = "CTS", key = "cat" },
  eagle = { name = "Eagle", command = "EGS", key = "eagle" },
  horse = { name = "Horse", command = "HRS", key = "horse" },
}

-- Shatter is available in every form and occupies one staff strike.
-- Reference: https://wiki.achaea.com/Shikudo (AB SHIKUDO SHATTER).
M.shikudo.shatter = skill({
  name = 'Shatter', syntax = {'SHATTER'},
  commands = {{cmd='SHATTER', role='strike'}},
  works_on = 'adventurers and denizens',
  notes = {'Breaks a magical shield; usable in every Shikudo form.'},
})
local limb_options = {
  thrust = {head=true, torso=true, ['left arm']=true, ['right arm']=true, ['left leg']=true, ['right leg']=true},
  dart = {head=true, torso=true, ['left arm']=true, ['right arm']=true, ['left leg']=true, ['right leg']=true},
  ruku = {left=true, right=true, torso=true},
  kuro = {left=true, right=true}, frontkick = {left=true, right=true},
  flashheel = {left=true, right=true}, risingkick = {head=true, torso=true},
}
for key, options in pairs(limb_options) do M.shikudo[key].limb_options = options end

-- Observed limb damage per successful hit, in percentage points (not health damage).
-- These are measurements against Maldrantus, not universal damage guarantees.
M.shikudo_limb_meta = {
  source = "https://ada-young.com/pastebin/Tf3FuEVJa",
  prone_spinkick_source = "User-supplied Needle/Spinkick screenshot: 27.3% head damage",
  target = "Maldrantus",
  modifiers = {
    light = { strike_limb_multiplier = 0 },
    hyperfocus = { focused_strike_limb_multiplier = 0.5 },
  },
  notes = {
    "Prefer confirmed game damage messages over predictions; blocked hits add no damage.",
    "Affliction scores, limb injury states, and accumulated limb damage are separate values.",
  },
}

local shikudo_damage = {
  thrust = { pct = 12.1, targeting = "chosen_limb" },
  risingkick = { pct = 7.6, targeting = "head_or_torso" },
  dart = { pct = 6.1, targeting = "chosen_limb", observed_limbs = { "head" } },
  hiru = { pct = 7.9, limb = "head" },
  flashheel = { pct = 7.6, limb_by_side = { left = "leftleg", right = "rightleg" } },
  hiraku = { pct = 7.9, limb = "head" },
  kuro = { pct = 7.6, limb_by_side = { left = "leftleg", right = "rightleg" } },
  ruku = { pct = 7.6, limb_by_choice = { left = "leftarm", right = "rightarm", torso = "torso" } },
  frontkick = { pct = 7.6, limb_by_side = { left = "leftarm", right = "rightarm" } },
  livestrike = { pct = 11.2, limb = "torso" },
  nervestrike = { pct = 11.2, limb = "head" },
  needle = { pct = 12.2, limb = "head" },
  spinkick = { variants = {
    standing = { pct = 9.1, limb = "torso" },
    prone = { pct = 27.3, limb = "head" },
  } },
  jinzuku = { pct = 7.6, limb = "torso" },
  dawnkick = { variants = {
    standing = { pct = 8.1, limb = "head" },
    -- TODO: Measure Dawnkick's limb damage percentage against a prone target.
    -- Keep pct absent until measured; do not reuse the standing 8.1% value.
    prone = { limb = "head", measured = false },
  } },
}
for key, damage in pairs(shikudo_damage) do
  M.shikudo[key].limb_damage = damage
end

-- AK canonical names. Rules describe possible delivery; they do not update AK scores.
-- Read AK's confirmed gains/cures when selecting attacks, rather than applying every
-- affliction listed on a skill. Conditions refer to target state before this hit.
M.shikudo.hiru.affliction_rules = {
  { afflicts = { "dizziness" } },
  { afflicts = { "confusion" }, when = { prone = true }, possible = true,
    confirmed_by = "User testing of Hiru against a prone target" },
}
M.shikudo.hiraku.affliction_rules = {
  { afflicts = { "anorexia", "stuttering" } },
}
M.shikudo.ruku.affliction_rules = {
  { afflicts = { "clumsiness" }, when = { limb_group = "arms", absent_affliction = "clumsiness" } },
  { afflicts = { "healthleech" }, when = { limb_group = "arms", present_affliction = "clumsiness" } },
  { afflicts = { "slickness" }, when = { limb = "torso" } },
}
M.shikudo.kuro.affliction_rules = {
  { afflicts = { "weariness" }, when = { absent_affliction = "weariness" } },
  { afflicts = { "lethargy" }, when = { present_affliction = "weariness" } },
}
-- Existing AK kata bonuses are unverified against current skill output. Do not
-- promote them to confirmed delivery rules: Ruku kata >= 9 gives both arm affs;
-- Kuro kata >= 11 gives both weariness and lethargy in the installed package code.
M.shikudo.livestrike.affliction_rules = { { afflicts = { "asthma" } } }
M.shikudo.nervestrike.affliction_rules = { { afflicts = { "paralysis" } } }
M.shikudo.needle.afflicts = { "crushedthroat" }
M.shikudo.needle.affliction_rules = { { afflicts = { "crushedthroat" } } }
M.shikudo.jinzuku.affliction_rules = { { afflicts = { "addiction" } } }
M.shikudo.dawnkick.affliction_rules = {
  { afflicts = { "epilepsy" }, timing = "delayed" },
  { afflicts = { "epilepsy" }, timing = "delayed_repeat", when = { prone = true } },
}
M.shikudo.frontkick.afflicts = { "prone" }
M.shikudo.frontkick.affliction_rules = { { afflicts = { "prone" } } }
M.shikudo.sweep.afflicts = { "prone" }
M.shikudo.sweep.affliction_rules = { { afflicts = { "prone" } } }
M.shikudo.flashheel.affliction_rules = {
  { afflict_by_side = { left = "leftleg", right = "rightleg" }, effect = "leg_break" },
}
-- Stuns and injury severity need dedicated state handling, not invented AK aff names.
M.shikudo.hiraku.effect_rules = { { effect = "short_stun", when = { prone = true } } }
M.shikudo.risingkick.effect_rules = {
  { effect = "short_stun", when = { limb = "head", prone = true } },
  { effect = "short_stun", when = { limb = "torso", internal_trauma = true } },
}
M.shikudo.spinkick.effect_rules = {
  { effect = "mangle_head", when = { prone = true, damaged_head = true } },
}

M.by_cmd = {}

local function index_skillset(set)
  for key, row in pairs(set) do
    for _, spec in ipairs(row.commands or {}) do
      local cmd = tostring(spec.cmd or ""):lower()
      -- Tekura and Shikudo both use COMBO. Keep the first registration.
      if cmd ~= "" and M.by_cmd[cmd] == nil then
        M.by_cmd[cmd] = {
          cmd = cmd,
          role = spec.role,
          limb_side = spec.limb_side,
          needs_direction = spec.needs_direction == true,
          skill_key = key,
          skill = row,
        }
      end
    end
  end
end

index_skillset(M.tekura)
index_skillset(M.telepathy)
index_skillset(M.shikudo)

function M.lookup(token)
  token = tostring(token or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if token == "" then return nil end
  return M.by_cmd[token]
end

function M.stance_by_word(word)
  word = tostring(word or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if word == "" or word == "none" then return nil end
  return M.stances[word]
end
