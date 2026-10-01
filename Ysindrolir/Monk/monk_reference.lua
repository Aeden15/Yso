--========================================================--
-- Monk Skill Reference (Tekura / Telepathy)
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
  updated = "2026-10-01",
  notes = {
    "AB IDs 848 and 853 are defences and are not part of this skill reference.",
    "Entering a tekura stance usually consumes balance. After a tekura kick or punch, a skilled practitioner can transition immediately, with a slightly slower recovery.",
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

M.stances = {
  dragon = { name = "Dragon", command = "DRS", key = "dragon" },
  scorpion = { name = "Scorpion", command = "SCS", key = "scorpion" },
  rat = { name = "Rat", command = "RTS", key = "rat" },
  bear = { name = "Bear", command = "BRS", key = "bear" },
  cat = { name = "Cat", command = "CTS", key = "cat" },
  eagle = { name = "Eagle", command = "EGS", key = "eagle" },
  horse = { name = "Horse", command = "HRS", key = "horse" },
}

M.by_cmd = {}

local function index_skillset(set)
  for key, row in pairs(set) do
    for _, spec in ipairs(row.commands or {}) do
      local cmd = tostring(spec.cmd or ""):lower()
      if cmd ~= "" then
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
