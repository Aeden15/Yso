-- Auto-exported from Mudlet package script: Occultism reference
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- yso_occultist_occultism_ref.lua
-- Occultist: Occultism skill reference for Achaea (Yso project)
--   • Pure data + tiny helpers, no Mudlet dependencies.
--   • Intentionally conservative: only claims specific mechanics
--     where we have AB text/screens; everything else is fuzzy/meta.
--   • Use this as a central reference table for offense logic, UI,
--     docs, etc.
--========================================================--

Yso = Yso or {}
Yso.occultist = Yso.occultist or {}

local O = {}

----------------------------------------------------------------------
-- CORE FORMAT NOTE
--  Each skill uses:
--    key        = lowercase name (no spaces)
--    name       = in-game name
--    syntax     = string or {strings}
--    target     = "enemy" | "ally" | "room" | "self" | "enemy-limb" | etc.
--    works_on   = rough AB "Works on/against" text
--    queue_flag = "eq" | "bal" | "eqbal" | "free" | "full" (planning hint)
--    bal_type   = "equilibrium" | "balance" | "eqbal"
--    eq_cost    = seconds of equilibrium (when known)
--    mana_cost / karma_cost / willpower_cost = basic resources (when known)
--    role       = { tags like "offense","limb-core","instakill","utility" }
--    summary    = short scripting-oriented description
--    tags       = arbitrary extra classification
--    requirements/effects/synergy/flags = extra structured info
----------------------------------------------------------------------

----------------------------------------------------------------------
-- AGUE
----------------------------------------------------------------------
O.ague = {
  skillset   = "Occultism",
  name       = "Ague",
  syntax     = "AGUE <target>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 2.20,
  mana_cost  = 100,
  role       = {"offense", "setup"},
  summary    = "Multi-stage cold: burns caloric, then applies shivering (eq loss over time) and can escalate to full freeze; double-freezes if two limbs require resto.",
  tags       = {"freeze", "anti-caloric", "eq-drain", "limb-synergy"},
  effects    = {
    stages = {"strip_caloric", "shivering", "full_freeze"},
  },
}

----------------------------------------------------------------------
-- AURAGLANCE
----------------------------------------------------------------------
O.auraglance = {
  skillset   = "Occultism",
  name       = "Auraglance",
  syntax     = "AURAGLANCE <target>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 1.00,
  mana_cost  = 20,
  role       = {"utility", "intel"},
  summary    = "Locate the current position of someone by sensing their aura.",
  tags       = {"locate", "tracking"},
}

----------------------------------------------------------------------
-- WARP (basic single-target damage)
----------------------------------------------------------------------
O.warp = {
  skillset   = "Occultism",
  name       = "Warp",
  syntax     = "WARP <target>",
  target     = "enemy",
  works_on   = "adventurers+denizens",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 4.00,
  mana_cost  = 80,
  role       = {"offense", "damage-core"},
  summary    = "Bread-and-butter single-target damage: warp the victim's body with lethal mutations.",
  tags       = {"damage", "pve", "single-target"},
}

----------------------------------------------------------------------
-- NIGHT
----------------------------------------------------------------------
O.night = {
  skillset   = "Occultism",
  name       = "Night",
  syntax     = "NIGHT",
  target     = "room",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility", "defense"},
  summary    = "Shroud the room in magical darkness.",
  tags       = {"darkness", "room-control"},
}

----------------------------------------------------------------------
-- SHROUD
----------------------------------------------------------------------
O.shroud = {
  skillset   = "Occultism",
  name       = "Shroud",
  syntax     = "SHROUD",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility", "defense"},
  summary    = "Conceal your subsequent actions from obvious observation.",
  tags       = {"stealth"},
}

----------------------------------------------------------------------
-- BODYWARP (two modes: self-fear + limb/lesser works)
----------------------------------------------------------------------
O.bodywarp = {
  skillset   = "Occultism",
  name       = "Bodywarp",
  syntax     = {
    "BODYWARP",
    "BODYWARP <target> <limb> [lesser occultic work]",
  },
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  variants   = {
    self_fear = {
      mode       = "self_fear",
      target     = "room",
      eq_cost    = 4.00,
      mana_cost  = 75,
      role       = {"offense", "control"},
      summary    = "Warp your form into an unspeakable horror, causing primal fear in those who can see you.",
      tags       = {"room-aoe", "fear", "vision-dependent"},
      requirements = { victim_unblind = true },
    },
    limb = {
      mode          = "limb",
      target        = "enemy-limb",
      eq_cost       = 2.60,
      mana_cost     = 50,
      willpower_cost= 2,
      role          = {"offense", "limb-core"},
      summary       = "Mutate a specific limb, dealing limb + minor HP damage; bonus damage if already broken. Can fuse in a lesser occultic work.",
      tags          = {"limb-damage", "limb-finisher"},
      lesser_works  = {"ague", "shrivel", "regress"},
    },
  },
  role       = {"offense", "limb-core", "control"},
  summary    = "Umbrella for BODYWARP modes; see .variants.self_fear and .variants.limb.",
  tags       = {"multi-mode"},
}

----------------------------------------------------------------------
-- ELDRITCHMISTS
----------------------------------------------------------------------
O.eldritchmists = {
  skillset   = "Occultism",
  name       = "Eldritchmists",
  syntax     = "ELDRITCHMISTS",
  target     = "room",
  works_on   = "room",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 4.00,
  mana_cost  = 200,
  role       = {"offense", "aoe"},
  summary    = "Call up eldritch mists that damage all other adventurers present.",
  tags       = {"room-aoe", "damage"},
}

----------------------------------------------------------------------
-- MASK
----------------------------------------------------------------------
O.mask = {
  skillset   = "Occultism",
  name       = "Mask",
  syntax     = "MASK",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility", "defense"},
  summary    = "Conceal the movements or presence of your Chaos entities.",
  tags       = {"entity", "stealth"},
}

----------------------------------------------------------------------
-- ATTEND
----------------------------------------------------------------------
O.attend = {
  skillset   = "Occultism",
  name       = "Attend",
  syntax     = "ATTEND <target>",
  target     = "ally",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 2.20,
  mana_cost  = 125,
  role       = {"support", "defense"},
  summary    = "Force your student to attend to you, curing deafness and blindness.",
  tags       = {"cure-blind", "cure-deaf", "ally-support"},
  effects    = { cures = {"blindness","deafness"} },
}

----------------------------------------------------------------------
-- ENERVATE
----------------------------------------------------------------------
O.enervate = {
  skillset   = "Occultism",
  name       = "Enervate",
  syntax     = "ENERVATE <target>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 4.00,
  mana_cost  = 50,
  role       = {"offense", "resource-pressure"},
  summary    = "Drain mana from the target into yourself; drain increases if they have manaleech or are frozen.",
  tags       = {"mana-drain", "synergy-manaleech", "synergy-freeze"},
  synergy    = {
    boosts_from = {"manaleech", "frozen"},
  },
}

----------------------------------------------------------------------
-- ENCIPHER
----------------------------------------------------------------------
O.encipher = {
  skillset   = "Occultism",
  name       = "Encipher",
  syntax     = "ENCIPHER <book/journal/etc.>",
  target     = "object",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility"},
  summary    = "Protect your writings so they cannot be easily read.",
  tags       = {"encryption"},
}

----------------------------------------------------------------------
-- QUICKEN (hunger/attrition, NOT offense)
----------------------------------------------------------------------
O.quicken = {
  skillset   = "Occultism",
  name       = "Quicken",
  syntax     = "QUICKEN <target>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 4.00,
  mana_cost  = 75,
  role       = {"utility", "attrition"},
  summary    = "Accelerate subjective time around the target so their body suddenly feels the accumulated effects (e.g. hunger).",
  tags       = {"timewarp", "hunger"},
  flags      = {
    include_in_offense = false,  -- you explicitly wanted this *out* of offense lists
  },
}

----------------------------------------------------------------------
-- ASTRALVISION
----------------------------------------------------------------------
O.astralvision = {
  skillset   = "Occultism",
  name       = "Astralvision",
  syntax     = "ASTRALVISION",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility", "intel"},
  summary    = "Extend perception through your aura for wider or deeper awareness.",
  tags       = {"sense", "vision"},
}

----------------------------------------------------------------------
-- REGRESS
----------------------------------------------------------------------
O.regress = {
  skillset   = "Occultism",
  name       = "Regress",
  syntax     = "REGRESS <target>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 2.50,
  role       = {"offense", "setup"},
  summary    = "Prones the target. If they are already prone, instead afflicts anorexia.",
  tags       = {"prone", "anorexia", "lesser-work"},
  effects    = {
    primary   = {"prone"},
    secondary = {"anorexia"},
  },
}

----------------------------------------------------------------------
-- SHRIVEL (important limb mech)
----------------------------------------------------------------------
O.shrivel = {
  skillset   = "Occultism",
  name       = "Shrivel",
  syntax     = {
    "SHRIVEL ARMS/LEGS <target>",
    "SHRIVEL LEFT/RIGHT ARM/LEG <target>",
  },
  target     = "enemy-limb",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 2.10,
  mana_cost  = 300,
  role       = {"offense", "limb-core"},
  summary    = "Destroy the marrow of a limb, rendering it useless. Core limb-offense mechanic.",
  tags       = {"limb-damage", "limb-lock", "lesser-work"},
  effects    = { limb_status = "shrivelled" },
}

----------------------------------------------------------------------
-- READAURA
----------------------------------------------------------------------
O.readaura = {
  skillset   = "Occultism",
  name       = "Readaura",
  syntax     = "READAURA <target>",
  target     = "enemy",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility", "intel"},
  summary    = "Read another's aura to gain hidden information (defences, state, etc.).",
  tags       = {"scan", "intel"},
}

----------------------------------------------------------------------
-- KARMA
----------------------------------------------------------------------
O.karma = {
  skillset   = "Occultism",
  name       = "Karma",
  syntax     = "KARMA",
  target     = "self",
  queue_flag = "free",
  bal_type   = "none",
  role       = {"utility"},
  summary    = "Check your accumulated karmic power.",
  tags       = {"resource-check"},
}

----------------------------------------------------------------------
-- HEARTSTONE
----------------------------------------------------------------------
O.heartstone = {
  skillset   = "Occultism",
  name       = "Heartstone",
  syntax     = "HEARTSTONE",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"defense", "resource"},
  summary    = "Create/maintain a figurine tied to your heart to aid mana recovery.",
  tags       = {"mana", "figurine"},
}

----------------------------------------------------------------------
-- SIMULACRUM
----------------------------------------------------------------------
O.simulacrum = {
  skillset   = "Occultism",
  name       = "Simulacrum",
  syntax     = "SIMULACRUM",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"defense"},
  summary    = "Create a figurine copy of yourself that absorbs damage.",
  tags       = {"damage-absorb"},
}

----------------------------------------------------------------------
-- ENTITIES
----------------------------------------------------------------------
O.entities = {
  skillset   = "Occultism",
  name       = "Entities",
  syntax     = "ENTITIES",
  target     = "self",
  queue_flag = "free",
  bal_type   = "none",
  role       = {"utility"},
  summary    = "Sense the locations/status of Chaos entities.",
  tags       = {"entity", "tracking"},
}

----------------------------------------------------------------------
-- TIMEWARP
----------------------------------------------------------------------
O.timewarp = {
  skillset   = "Occultism",
  name       = "Timewarp",
  syntax     = "TIMEWARP <location/room>",
  target     = "room",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility","control"},
  summary    = "Warp time in a location, particularly affecting vibes or persistent effects there.",
  tags       = {"room-control","time"},
}

----------------------------------------------------------------------
-- DISTORTAURA
----------------------------------------------------------------------
O.distortaura = {
  skillset   = "Occultism",
  name       = "Distortaura",
  syntax     = "DISTORTAURA",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"defense"},
  summary    = "Twist your aura to mitigate/deflect incoming physical damage.",
  tags       = {"damage-reduction"},
}

----------------------------------------------------------------------
-- PINCHAURA
----------------------------------------------------------------------
O.pinchaura = {
  skillset   = "Occultism",
  name       = "Pinchaura",
  syntax     = "PINCHAURA <target>",
  target     = "enemy",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility","support"},
  summary    = "Fine-tune another's aura in a precise way (buff/debuff toggle style).",
  tags       = {"aura"},
}

----------------------------------------------------------------------
-- IMPART
----------------------------------------------------------------------
O.impart = {
  skillset   = "Occultism",
  name       = "Impart",
  syntax     = "IMPART <target>",
  target     = "ally",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility","teaching"},
  summary    = "Impart your knowledge of Occultism (including karma teachings).",
  tags       = {"teaching"},
}

----------------------------------------------------------------------
-- TRANSCENDENCE
----------------------------------------------------------------------
O.transcendence = {
  skillset   = "Occultism",
  name       = "Transcendence",
  syntax     = "TRANSCENDENCE",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"movement","utility"},
  summary    = "Open a gateway to the Plane of Chaos.",
  tags       = {"plane-travel"},
}

----------------------------------------------------------------------
-- UNNAMABLE (room insanities)
----------------------------------------------------------------------
O.unnamable = {
  skillset   = "Occultism",
  name       = "Unnamable",
  syntax     = {"UNNAMABLE SPEAK","UNNAMABLE VISION"},
  target     = "room",
  works_on   = "room",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 3.20,
  karma_cost = 1,
  role       = {"offense","room-control"},
  summary    = "Speak/vision of the Unnamable afflicting all non-Occultists in the room with assorted insanities (no duplicates).",
  tags       = {"room-aoe","insanity"},
}

----------------------------------------------------------------------
-- DEVOLVE
----------------------------------------------------------------------
O.devolve = {
  skillset   = "Occultism",
  name       = "Devolve",
  syntax     = "DEVOLVE <target>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 3.00,
  role       = {"offense","insanity"},
  summary    = "Curse target so their appearance devolves, giving disloyalty and shyness.",
  tags       = {"insanity","disloyalty","shyness"},
  effects    = { affs = {"disloyalty","shyness"} },
}

----------------------------------------------------------------------
-- CLEANSEAURA (filler defence stripper)
----------------------------------------------------------------------
O.cleanseaura = {
  skillset   = "Occultism",
  name       = "Cleanseaura",
  syntax     = "CLEANSEAURA <target>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 4.00,
  karma_cost = 1,
  role       = {"utility","def-strip"},
  summary    = "At <=40% mana, strip a natural aura defence from the target. Filler strip, not core offense.",
  tags       = {"def-strip","aura","filler"},
  requirements = { target_mana_pct_max = 40 },
}

----------------------------------------------------------------------
-- TENTACLES
----------------------------------------------------------------------
O.tentacles = {
  skillset   = "Occultism",
  name       = "Tentacles",
  syntax     = "TENTACLES",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"offense","control"},
  summary    = "Grow occult tentacles to extend your reach or attacks.",
  tags       = {"melee-boost","control"},
}

----------------------------------------------------------------------
-- CHAOSRAYS (room AoE damage)
----------------------------------------------------------------------
O.chaosrays = {
  skillset   = "Occultism",
  name       = "Chaosrays",
  syntax     = "CHAOSRAYS",
  target     = "room",
  works_on   = "room",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 4.00,
  karma_cost = 2,
  role       = {"offense","aoe"},
  summary    = "Transmute karma into Seven Rays that blast everyone in the room except you with random rays of chaos.",
  tags       = {"room-aoe","damage"},
}

----------------------------------------------------------------------
-- INTERLINK
----------------------------------------------------------------------
O.interlink = {
  skillset   = "Occultism",
  name       = "Interlink",
  syntax     = "INTERLINK <target/location>",
  target     = "room",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility","control"},
  summary    = "Bind targets/locations together under your will, for later warping effects.",
  tags       = {"room-control"},
}

----------------------------------------------------------------------
-- INSTILL (aff-core)
----------------------------------------------------------------------
O.instill = {
  skillset   = "Occultism",
  name       = "Instill",
  syntax     = "INSTILL <target> WITH <affliction>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 2.50,
  mana_cost  = 50,
  role       = {"offense","aff-core"},
  summary    = "Instill target's aura with a chosen affliction (asthma, clumsiness, healthleech, sensitivity, slickness, paralysis, darkshade) plus light HP/mana damage.",
  tags       = {"targeted-aff","aura"},
  options    = {
    "asthma","clumsiness","healthleech",
    "sensitivity","slickness","paralysis","darkshade",
  },
}

----------------------------------------------------------------------
-- WHISPERINGMADNESS (insanity curse)
----------------------------------------------------------------------
O.whisperingmadness = {
  skillset   = "Occultism",
  name       = "Whisperingmadness",
  syntax     = "WHISPERINGMADNESS <target>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 2.30,
  mana_cost  = 200,
  role       = {"offense","insanity","kill-setup"},
  summary    = "If target already has at least one qualifying insanity, afflicts them with Whispering Madness, greatly slowing their focus recovery.",
  tags       = {"insanity","focus-slow","enlighten-setup"},
  effects    = { affs = {"whispering_madness"} },
}

----------------------------------------------------------------------
-- DEVILMARK
----------------------------------------------------------------------
O.devilmark = {
  skillset   = "Occultism",
  name       = "Devilmark",
  syntax     = "DEVILMARK <target>",
  target     = "enemy",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"offense","setup","buff"},
  summary    = "Place the Devil's Mark, enabling advanced effects and greater power against the victim.",
  tags       = {"mark"},
}

----------------------------------------------------------------------
-- TRUENAME (Aeon strike, gate to Unravel)
----------------------------------------------------------------------
O.truename = {
  skillset   = "Occultism",
  name       = "Truename",
  syntax     = {
    "TRUENAME CORPSE",
    "TRUENAMES",
    "TRUENAMES FORGET <target>",
    "UTTER TRUENAME <target>",
  },
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 4.00,
  karma_cost = 1,
  role       = {"offense","kill-setup"},
  summary    = "Learn an individual's truename from their corpse, then utter it in front of them to deal body/mind damage and afflict Aeon, consuming that truename.",
  tags       = {"aeon","damage","truename"},
  requirements = {
    requires_entity_balance = true,
  },
  effects    = { affs_on_utter = {"aeon"} },
}

----------------------------------------------------------------------
-- ASTRALFORM
----------------------------------------------------------------------
O.astralform = {
  skillset   = "Occultism",
  name       = "Astralform",
  syntax     = "ASTRALFORM",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"defense","escape","movement"},
  summary    = "Transform into a being of pure energy for movement/defensive benefits.",
  tags       = {"form","movement"},
}

----------------------------------------------------------------------
-- ENLIGHTEN (pre-kill)
----------------------------------------------------------------------
O.enlighten = {
  skillset   = "Occultism",
  name       = "Enlighten",
  syntax     = "ENLIGHTEN <target>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 4.00,
  karma_cost = 2,
  role       = {"offense","kill-setup"},
  summary    = "If the target has enough qualifying insanities, reveal the occult mysteries to them, making those insanities permanent until death (non-initiate only). Requirement drops by 1 if they have Whispering Madness.",
  tags       = {"insanity","permanent","unravel-setup"},
  requirements = {
    base_required  = 6,
    required_with_whisperingmadness = 5,
  },
}

----------------------------------------------------------------------
-- UNRAVEL (instakill)
----------------------------------------------------------------------
O.unravel = {
  skillset   = "Occultism",
  name       = "Unravel",
  syntax     = "UNRAVEL MIND OF <target>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 5.00,
  mana_cost  = 500,
  role       = {"offense","instakill"},
  summary    = "After properly Enlightening a non-initiate, unravel their mind to kill them instantly and release a powerful karmic aura.",
  tags       = {"instakill","mindkill"},
  requirements = {
    must_be_enlightened = true,
    non_initiate_only   = true,
  },
}

----------------------------------------------------------------------
-- COMPEL (special, non-consuming eq/bal)
----------------------------------------------------------------------
O.compel = {
  skillset   = "Occultism",
  name       = "Compel",
  syntax     = "COMPEL <target> <compulsion>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eqbal",  -- needs both, consumes neither
  bal_type   = "eqbal",
  role       = {"offense","special"},
  summary    = "For a prepared 'student', force contemplation of a mystery, firing one of several compulsion effects. Requires eq+bal but consumes neither; uses its own internal cooldown.",
  tags       = {"compulsion","special-cd"},
  flags      = {
    requires_balance     = true,
    requires_equilibrium = true,
    consumes_balance     = false,
    consumes_equilibrium = false,
    internal_cooldown    = true,
  },
}

----------------------------------------------------------------------
-- TRANSMOGRIFY
----------------------------------------------------------------------
O.transmogrify = {
  skillset   = "Occultism",
  name       = "Transmogrify",
  syntax     = "TRANSMOGRIFY",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility","transformation","endgame"},
  summary    = "Reincarnate/reshape yourself as a Chaos Lord.",
  tags       = {"form","endgame"},
}

----------------------------------------------------------------------
-- FINALIZE TABLE + HELPERS
----------------------------------------------------------------------

Yso.occultist.occultism = O

-- Return a skill table by (case-insensitive) key.
function Yso.occultist.getOccultismSkill(name)
  if not name then return nil end
  name = string.lower(name)
  return O[name]
end

-- Check if a given Occultism skill should be treated as part of
-- *normal* offense (honours flags like include_in_offense=false).
function Yso.occultist.isOccultismOffense(name)
  local s = Yso.occultist.getOccultismSkill(name)
  if not s then return false end
  local roles = s.role or {}
  local hasOffense = false
  for _,r in ipairs(roles) do
    if r == "offense" then
      hasOffense = true
      break
    end
  end
  if not hasOffense then return false end
  if s.flags and s.flags.include_in_offense == false then
    return false
  end
  return true
end

-- List all Occultism skills containing the given role tag.
function Yso.occultist.listOccultismByRole(role)
  local out = {}
  for k,v in pairs(O) do
    if v.role then
      for _,r in ipairs(v.role) do
        if r == role then
          table.insert(out, k)
          break
        end
      end
    end
  end
  table.sort(out)
  return out
end

-- Optional debug echo (comment out if you don’t like chatter)
if cecho then
  cecho("<green>[Yso] Loaded Occultist/Occultism reference ("..
        tostring(#Yso.occultist.listOccultismByRole("offense"))..
        " offense-tagged skills).\n")
end

--========================================================--
-- End of yso_occultist_occultism_ref.lua
--========================================================--
