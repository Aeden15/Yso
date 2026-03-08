-- Auto-exported from Mudlet package script: Skillset reference chart
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- yso_occultist_skillset_ref.lua
--  Occultist skillset reference for Achaea (Yso project)
--   • Consolidated reference tables:
--       - Occultism (skills)
--       - Tarot (cards)
--       - Domination (entities / utilities)
--   • Pure data + tiny helpers. No aliases, triggers, timers, or GMCP.
--   • Spelling note: entity is "doppleganger" (per project convention).
--========================================================--

Yso = Yso or {}
Yso.occultist = Yso.occultist or {}

-- Keep compatibility with existing modules that use Yso.occ.*
Yso.occ = Yso.occ or {}
Yso.occ.dom = Yso.occ.dom or {}

-- -------------------------------------------------------------------
-- tiny helpers (reference-only)
-- -------------------------------------------------------------------
local function _lc(s) return (type(s) == "string" and s:lower()) or tostring(s or ""):lower() end

local function _list_has(list, wanted)
  if type(list) ~= "table" or wanted == nil then return false end
  for i = 1, #list do
    if list[i] == wanted then return true end
  end
  return false
end

local function _sorted_keys_by_role(tbl, role, role_field)
  local out = {}
  role = tostring(role or "")
  for k, v in pairs(tbl or {}) do
    local roles = v and v[role_field or "role"]
    if type(roles) == "table" then
      for i = 1, #roles do
        if roles[i] == role then
          out[#out+1] = k
          break
        end
      end
    end
  end
  table.sort(out)
  return out
end

--========================================================--
-- Occultism (skills)
--========================================================--
local O = {}

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
  effects    = { stages = {"strip_caloric", "shivering", "full_freeze"} },
}

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
      mode           = "limb",
      target         = "enemy-limb",
      eq_cost        = 2.60,
      mana_cost      = 50,
      willpower_cost = 2,
      role           = {"offense", "limb-core"},
      summary        = "Mutate a specific limb, dealing limb + minor HP damage; bonus damage if already broken. Can fuse in a lesser occultic work.",
      tags           = {"limb-damage", "limb-finisher"},
      lesser_works   = {"ague", "shrivel", "regress"},
    },
  },
  role       = {"offense", "limb-core", "control"},
  summary    = "Umbrella for BODYWARP modes; see .variants.self_fear and .variants.limb.",
  tags       = {"multi-mode"},
}

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

O.attend = {
  title = "Attend",
  id = 953,

  syntax = "ATTEND <target>",
  target = "ally/enemy",
  works_on = "adventurers+denizens",

  bal_type = "eq",
  bal_cost = 2.20,
  queue_flag = "eq",
  mana_cost = 125,

  roles = {"support", "utility", "offense(pve)"},
  tags  = {"cures", "psychic-damage"},

  summary = "Forces your target to attend to their studies. On adventurers, cures deafness and blindness. Against denizens, lashes their minds with karmic energy for psychic damage (only deals damage to denizens at 100% health or higher).",

  cures = {"deafness", "blindness"},
}


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
  synergy    = { boosts_from = {"manaleech", "frozen"} },
}

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
  flags      = { include_in_offense = false },
}

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
  effects    = { primary = {"prone"}, secondary = {"anorexia"} },
}

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

O.timewarp = {
  skillset   = "Occultism",
  name       = "Timewarp",
  syntax     = "TIMEWARP <location/room>",
  target     = "room",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility", "control"},
  summary    = "Warp time in a location, particularly affecting vibes or persistent effects there.",
  tags       = {"room-control", "time"},
}

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

O.pinchaura = {
  title = "Pinchaura",
  id = 966,

  syntax = "PINCHAURA <target> <defence>",
  target = "enemy",
  works_on = "adventurers",

  bal_type = "eq",
  bal_cost = 4.00,
  queue_flag = "eq",
  karma_cost = 0.50, -- percent

  roles = {"utility", "offense"},
  tags  = {"defence-strip"},

  summary = "Surgically alters an individual's aura, removing one defence (cloak, speed, caloric, frost, levitation, insomnia, kola).",
  removes_defences = {"cloak","speed","caloric","frost","levitation","insomnia","kola"},
}


O.impart = {
  skillset   = "Occultism",
  name       = "Impart",
  syntax     = "IMPART <target>",
  target     = "ally",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility", "teaching"},
  summary    = "Impart your knowledge of Occultism (including karma teachings).",
  tags       = {"teaching"},
}

O.transcendence = {
  skillset   = "Occultism",
  name       = "Transcendence",
  syntax     = "TRANSCENDENCE",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"movement", "utility"},
  summary    = "Open a gateway to the Plane of Chaos.",
  tags       = {"plane-travel"},
}

O.unnamable = {
  skillset   = "Occultism",
  name       = "Unnamable",
  syntax     = {"UNNAMABLE SPEAK", "UNNAMABLE VISION"},
  target     = "room",
  works_on   = "room",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 3.20,
  karma_cost = 1,
  role       = {"offense", "room-control"},
  summary    = "Speak/vision of the Unnamable afflicting all non-Occultists in the room with assorted insanities (no duplicates).",
  tags       = {"room-aoe", "insanity"},
}

O.devolve = {
  skillset   = "Occultism",
  name       = "Devolve",
  syntax     = "DEVOLVE <target>",
  target     = "enemy",
  works_on   = "adventurers",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  eq_cost    = 3.00,
  role       = {"offense", "insanity"},
  summary    = "Curse target so their appearance devolves, giving disloyalty and shyness.",
  tags       = {"insanity", "disloyalty", "shyness"},
  effects    = { affs = {"disloyalty", "shyness"} },
}

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
  role       = {"utility", "def-strip"},
  summary    = "At <=40% mana, strip a natural aura defence from the target. Filler strip, not core offense.",
  tags       = {"def-strip", "aura", "filler"},
  requirements = { target_mana_pct_max = 40 },
}

O.tentacles = {
  skillset   = "Occultism",
  name       = "Tentacles",
  syntax     = "TENTACLES",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"offense", "control"},
  summary    = "Grow occult tentacles to extend your reach or attacks.",
  tags       = {"melee-boost", "control"},
}

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
  role       = {"offense", "aoe"},
  summary    = "Transmute karma into Seven Rays that blast everyone in the room except you with random rays of chaos.",
  tags       = {"room-aoe", "damage"},
}

O.interlink = {
  skillset   = "Occultism",
  name       = "Interlink",
  syntax     = "INTERLINK <target/location>",
  target     = "room",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility", "control"},
  summary    = "Bind targets/locations together under your will, for later warping effects.",
  tags       = {"room-control"},
}

O.instill = {
  title = "Instill",
  id = 975,

  syntax = "INSTILL <target> WITH <affliction>",
  target = "enemy",
  works_on = "adventurers",

  bal_type = "eq",
  bal_cost = 2.50,
  queue_flag = "eq",
  mana_cost = 50,

  roles = {"offense", "setup"},
  tags  = {"aura", "options"},

  summary = "Instills a target's aura with a chosen affliction (asthma, clumsiness, healthleech, sensitivity, slickness, paralysis, darkshade). Also does a small amount of health and mana damage (influence is stronger if you possess a truename derived by the power of the Imperator).",
  options = { "asthma","clumsiness","healthleech","sensitivity","slickness","paralysis","darkshade" },
}


O.whisperingmadness = {
  title = "Whisperingmadness",
  id = 976,

  syntax = "WHISPERINGMADNESS <target>",
  target = "enemy",
  works_on = "adventurers",

  bal_type = "eq",
  bal_cost = 2.30,
  queue_flag = "eq",
  mana_cost = 200,

  roles = {"offense", "setup"},
  tags  = {"insanity-gated", "focus-slow"},

  summary = "If the target already has at least one qualifying insanity, afflicts whispering madness, causing their attempts to focus their mind to take far longer to recover from.",

  requires_any_insanity = {
    "dementia","stupidity","confusion","hypersomnia","paranoia","hallucinations",
    "impatience","addiction","agoraphobia","lovers","loneliness","recklessness","masochism"
  },

  affs = { primary = {"whispering_madness"} },
}


O.devilmark = {
  skillset   = "Occultism",
  name       = "Devilmark",
  syntax     = "DEVILMARK <target>",
  target     = "enemy",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"offense", "setup", "buff"},
  summary    = "Place the Devil's Mark, enabling advanced effects and greater power against the victim.",
  tags       = {"mark"},
}

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
  role       = {"offense", "kill-setup"},
  summary    = "Learn an individual's truename from their corpse, then utter it in front of them to deal body/mind damage and afflict Aeon, consuming that truename.",
  tags       = {"aeon", "damage", "truename"},
  requirements = { requires_entity_balance = true },
  effects    = { affs_on_utter = {"aeon"} },
}

O.astralform = {
  skillset   = "Occultism",
  name       = "Astralform",
  syntax     = "ASTRALFORM",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"defense", "escape", "movement"},
  summary    = "Transform into a being of pure energy for movement/defensive benefits.",
  tags       = {"form", "movement"},
}

O.enlighten = {
  title = "Enlighten",
  id = 980,

  syntax = "ENLIGHTEN <target>",
  target = "enemy",
  works_on = "adventurers",

  bal_type = "eq",
  bal_cost = 4.00,
  queue_flag = "eq",
  karma_cost = 2.00, -- percent

  roles = {"setup"},
  tags  = {"unravel-prereq"},

  summary = "Reveals occult mysteries to a non-initiate, making their insanities permanent until death. Requires sufficient openness of mind: 6 of the listed insanities (drops to 5 if they suffer whispering madness).",

  requires_count = {
    n = 6,
    n_if_has = { whispering_madness = 5 },
    from = {
      "claustrophobia","agoraphobia","lovers","dementia","epilepsy","hallucinations",
      "confusion","stupidity","paranoia","vertigo","shyness","addiction","recklessness","masochism"
    }
  },
}


O.unravel = {
  title = "Unravel",
  id = 981,

  syntax = "UNRAVEL MIND OF <target>",
  target = "enemy",
  works_on = "adventurers",

  bal_type = "eq",
  bal_cost = 5.00,
  queue_flag = "eq",
  mana_cost = 500,

  roles = {"finisher"},
  tags  = {"instakill", "enlighten-prereq"},

  summary = "After enlightening a non-initiate, completely unravels their mind, slaying them instantly and releasing a karmic aura that buffs your own karma.",

  requires = {"enlightened_target", "non_initiate"},
}


O.compel = {
  title = "Compel",
  id = 3109,

  syntax = "COMPEL <target> <compulsion>",
  target = "enemy",
  works_on = "adventurers",

  -- Uses its own internal cooldown; requires both balance and equilibrium but consumes neither.
  bal_type = "special",
  queue_flag = "free",

  roles = {"offense", "setup"},
  tags  = {"truename", "enlighten-followup"},

  summary = "After acquiring a true name (via Glaaki) and properly preparing the target, compels a revelation that manifests as specific affliction packages.",

  compulsions = {
    discord = {
      requires = {"healthleech", "asthma"},
      gives = {"loneliness", "dizziness"},
      notes = "Deals a great strain to the mind.",
    },
    entropy = {
      requires = {"haemophilia", "addiction"},
      gives = {"aeon"},
      strips_defences = {"speed"},
      notes = "If the target has speed up, it is removed; if they do not, they are struck with aeon.",
    },
    potential = {
      requires = {"all_limbs_broken_or_frozen"},
      gives = {"blackout"},
      notes = "If limbs are broken: short-lived blackout. If frozen: deals damage.",
    },
  },
}


O.transmogrify = {
  skillset   = "Occultism",
  name       = "Transmogrify",
  syntax     = "TRANSMOGRIFY",
  target     = "self",
  queue_flag = "eq",
  bal_type   = "equilibrium",
  role       = {"utility", "transformation", "endgame"},
  summary    = "Reincarnate/reshape yourself as a Chaos Lord.",
  tags       = {"form", "endgame"},
}

-- Attach Occultism reference
Yso.occultist.occultism = O

function Yso.occultist.getOccultismSkill(key)
  if not key then return nil end
  return O[_lc(key)]
end

function Yso.occultist.isOccultismOffense(key)
  local s = Yso.occultist.getOccultismSkill(key)
  if not s then return false end
  if type(s.role) ~= "table" or not _list_has(s.role, "offense") then return false end
  if s.flags and s.flags.include_in_offense == false then return false end
  return true
end

function Yso.occultist.listOccultismByRole(role)
  return _sorted_keys_by_role(O, role, "role")
end

--========================================================--
-- Tarot (cards)
--========================================================--
local T = {}

T.sun = {
  skillset   = "Tarot",
  name       = "Sun",
  syntax     = "FLING SUN AT GROUND",
  target     = "room",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"defense","utility","self-cleanse"},
  summary    = "Create a light globe that illuminates the room and periodically cures your afflictions while you remain there.",
  tags       = {"room-object","periodic-cure","light"},
}

T.emperor = {
  skillset   = "Tarot",
  name       = "Emperor",
  syntax     = "FLING EMPEROR AT <target>",
  target     = "ally",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"utility","movement","support"},
  summary    = "Forces other adventurers to recognise your leadership and follow you.",
  tags       = {"follow","group-move"},
}

T.magician = {
  skillset   = "Tarot",
  name       = "Magician",
  syntax     = "FLING MAGICIAN AT <target>",
  target     = "ally",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"support","resource"},
  summary    = "Replenishes the target's mana.",
  tags       = {"mana-heal"},
}

T.priestess = {
  skillset   = "Tarot",
  name       = "Priestess",
  syntax     = "FLING PRIESTESS AT <target>",
  target     = "ally",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"support","healing"},
  summary    = "Heals some of the target's health.",
  tags       = {"hp-heal"},
}

T.fool = {
  skillset   = "Tarot",
  name       = "Fool",
  syntax     = "FLING FOOL AT <target>",
  target     = "self_or_ally",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"defense","self-cleanse"},
  summary    = "Cures three afflictions from the target; has a 35s internal cooldown.",
  tags       = {"cleanse","panic-button"},
  cooldowns  = { special = 35.0 },
}

T.empress = {
  skillset   = "Tarot",
  name       = "Empress",
  syntax     = {"FLING EMPRESS AT <target>", "SNIFF EMPRESS <target>"},
  target     = "ally_or_enemy",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"utility","movement","support"},
  summary    = "Summon someone on your allies list to you; Lust extends this to continent-wide summons.",
  tags       = {"summon","lust-synergy"},
}

T.lovers = {
  skillset   = "Tarot",
  name       = "Lovers",
  syntax     = "FLING LOVERS AT <target>",
  target     = "enemy",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"defense","offense","ruinable"},
  summary    = "Target falls in love and is reluctant to harm you; ruinated version inflicts manaleech.",
  tags       = {"pacify","manaleech","ruination"},
}

T.hangedman = {
  skillset   = "Tarot",
  name       = "Hangedman",
  syntax     = "FLING HANGEDMAN AT <target>",
  target     = "enemy",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"offense","control"},
  summary    = "Entangles the foe in ropes; you cannot command entities while off balance from this fling.",
  tags       = {"entangle","entity-block"},
  flags      = { blocks_entities_while_offbalance = true },
}

T.tower = {
  skillset   = "Tarot",
  name       = "Tower",
  syntax     = "FLING TOWER AT GROUND",
  target     = "room",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"utility","room-control"},
  summary    = "Summons a crumbling tower that makes it difficult to leave via some exits.",
  tags       = {"terrain","exit-block"},
}

T.wheel = {
  skillset   = "Tarot",
  name       = "Wheel",
  syntax     = "FLING WHEEL AT GROUND",
  target     = "room",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"offense","utility","ruinable","room-control"},
  summary    = "Wheel of Fortune permanent room effect; ruinated Wheel of Chaos rotates then lashes out with chaotic rays.",
  tags       = {"room-aoe","chaos","ruination"},
  ruination  = {
    syntax         = "RUINATE WHEEL AT GROUND <1-7>",
    rays           = { first = "freeze", second = "stuttering", third = "strip_speed_or_give_aeon" },
    indiscriminate = true,
  },
}

T.justice = {
  skillset   = "Tarot",
  name       = "Justice",
  syntax     = "FLING JUSTICE AT <target>",
  target     = "enemy",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"offense","limb-core","ruinable"},
  summary    = "Ruinated Justice converts specific afflictions into broken limbs; four+ conversions freeze and both-broken-legs prones.",
  tags       = {"aff-to-limb","freeze","prone"},
  effects    = {
    converts_affs_to_broken_limbs = {
      "paralysis","sensitivity","healthleech",
      "haemophilia","weariness","asthma","clumsiness",
    },
  },
}

T.star = {
  skillset   = "Tarot",
  name       = "Star",
  syntax     = "FLING STAR AT <target>",
  target     = "enemy",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"offense","damage"},
  summary    = "Calls a meteor down on a target within 3 rooms LOS; both must be outdoors.",
  tags       = {"meteor","ranged"},
  requirements = { los_range_max = 3, you_outdoors = true, target_outdoors = true },
}

T.aeon = {
  skillset   = "Tarot",
  name       = "Aeon",
  syntax     = "FLING AEON AT <target>",
  target     = "enemy",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.70,
  role       = {"offense","lock"},
  summary    = "Afflicts the curse of Aeon (heavy time-slow). You cannot command entities while off balance from this fling.",
  tags       = {"aeon","entity-block"},
  effects    = { affs = {"aeon"} },
  flags      = { blocks_entities_while_offbalance = true },
}

T.lust = {
  skillset   = "Tarot",
  name       = "Lust",
  syntax     = "FLING LUST AT <target>",
  target     = "enemy",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"utility","setup"},
  summary    = "Target lusts for you and considers you an ally, enabling long-range Empress summons.",
  tags       = {"mark","empress-synergy"},
}

T.moon = {
  skillset   = "Tarot",
  name       = "Moon",
  syntax     = "FLING MOON AT <target> [affliction]",
  target     = "enemy",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"offense","aff-core"},
  summary    = "Inflicts a mental affliction from the Moon list; random & hidden if unspecified, known but faster-cure if specified.",
  tags       = {"mental-affs"},
  extra_info = { specified_aff_bal_cost = 2.10 },
  options    = {
    "stupidity","masochism","hallucinations",
    "hypersomnia","confusion","epilepsy",
    "claustrophobia","agoraphobia",
  },
}

T.death = {
  skillset   = "Tarot",
  name       = "Death",
  syntax     = {"RUB DEATH ON <target>", "SNIFF DEATH", "FLING DEATH AT <target>"},
  target     = "enemy",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"offense","finisher"},
  summary    = "Rub to build attunement charges on a target, then fling to call Death and attempt an instant-kill style freeze/shiver.",
  tags       = {"execute","freeze","shivering"},
  variants   = {
    rub = {
      uses              = "equilibrium",
      eq_cost           = 3.20,
      charges_needed    = 7,
      extra_charge_states = {"stun","aeon","entangled","shivering","paralysis"},
    },
    fling = { uses = "balance", bal_cost = 3.00 },
  },
}


T.ruinate = {
  skillset   = "Tarot",
  name       = "Ruinate",
  syntax     = "RUINATE <card> AT <target>",
  target     = "enemy_or_card",
  queue_flag = "bal",
  bal_type   = "balance",
  role       = {"utility","meta"},
  summary    = "Twists certain major arcana to their opposite face, activating their ruinated behaviour.",
  tags       = {"ruination"},
  ruinate_targets = {"lovers","justice","creator","wheel"},
}

Yso.occultist.tarot = T

function Yso.occultist.getTarot(key)
  if not key then return nil end
  return T[_lc(key)]
end

function Yso.occultist.isTarotOffense(key)
  local c = Yso.occultist.getTarot(key)
  if not c or type(c.role) ~= "table" then return false end
  local offensive = _list_has(c.role, "offense") or _list_has(c.role, "finisher")
  if not offensive then return false end
  if c.flags and c.flags.include_in_offense == false then return false end
  return true
end

function Yso.occultist.listTarotByRole(role)
  return _sorted_keys_by_role(T, role, "role")
end

--========================================================--
-- Domination (entities / utilities)
--========================================================--
local D = Yso.occ.dom

D.skyrax = {
  id        = 983,
  name      = "Skyrax",
  title     = "Dervish",
  syntax    = "COMMAND DERVISH AT <target>",
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 2.10,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"utility","position"},
  summary   = "Whirling dervish that knocks a target out of skies or trees.",
  tags      = {"anti-fly","anti-tree","knockdown"},
}

D.rixil = {
  id        = 984,
  name      = "Rixil",
  title     = "Sycophant",
  syntax    = "COMMAND SYCOPHANT AT <target>",
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 2.00,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"offense","mana","utility"},
  summary   = "Increases time to FOCUS; primebond adds strong mana drain, boosted on shivering/frozen targets.",
  tags      = {"focus-slow","mana-drain"},
  primebond = { summary = "Sycophant drains enemy mana; more if shivering, even more if frozen." },
}

D.scrag = {
  id        = 987,
  name      = "Scrag",
  title     = "Bloodleech",
  syntax    = "COMMAND BLOODLEECH AT <target>",
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 2.20,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"offense","affliction","bleed"},
  summary   = "Thins the victim's blood, afflicting haemophilia.",
  affs      = {"haemophilia"},
  tags      = {"bleed","prep"},
  primebond = { summary = "Leech periodically causes bleeding; bleed is increased if blood is thinned." },
}

D.pyradius = {
  id        = 988,
  name      = "Pyradius",
  title     = "Firelord",
  syntax    = "COMMAND FIRELORD AT <target> <affliction>",
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 3.00,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"offense","aff-convert","aoe"},
  summary   = "Converts specific afflictions (WM, manaleech, healthleech) into others, then supports with fiery room damage when primebonded.",
  converts  = { whisperingmadness = "recklessness", manaleech = "anorexia", healthleech = "psychic_damage" },
  tags      = {"aff-conversion","room-aoe","ablaze"},
  primebond = { summary = "Firelords strike those in and near your room with fire, setting them ablaze." },
}

D.golgotha = {
  name      = "Golgotha",
  title     = "Golgotha",
  syntax    = "SUMMON GOLGOTHA",
  works_on  = "self",
  bal_type  = "eq",
  bal_cost  = 2.40,
  queue_flag = "eq",
  roles     = {"defense","entity-support"},
  summary   = "Pact that protects your chaotic servants from magical banishment while you share their location.",
  tags      = {"anti-banish","entity-protection"},
}

D.dameron = {
  id        = 989,
  name      = "Dameron",
  title     = "Minion",
  syntax    = "COMMAND MINION AT <target>",
  works_on  = "adventurers",
  bal_type  = nil,
  bal_cost  = nil,
  queue_flag = nil,
  mana_cost = 50,
  roles     = {"execute","offense"},
  summary   = "Infernal minion that unravels the mind of an Enlightened target, instantly killing them.",
  tags      = {"insta","enlighten-required"},
  notes     = {
    "Target must be Enlightened (same condition as UNRAVEL).",
    "Presence of Dameron also protects your other entities from banishment.",
  },
}

D.worm = {
  id        = 990,
  name      = "Worm",
  title     = "Glutton Worm",
  syntax    = "COMMAND WORM AT <target>",
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 3.10,
  queue_flag = "ent",
  mana_cost = 50,
  -- Duration notes (observed from live logs):
  --  • One successful command applies a ~20s infestation.
  --  • Healthleech is applied on the chewing/tick message:
  --      "Many somethings writhe beneath the skin of <target>, and the sickening sound of chewing can be heard."
  duration_s = 20,
  tick_count_observed = 2,
  notes     = {
    "Treat as one cast per ~20s per target; do not re-command worm every entity balance.",
    "Healthleech is delivered on tick(s) (chewing/maggots message), not necessarily immediately on command.",
    "Primebond adds nausea on ticks.",
  },
  roles     = {"offense","dot","affliction"},
  summary   = "Infests the victim with maggots that periodically leech health.",
  affs      = {"healthleech"},
  primebond = { summary = "Worm burrows into the belly, periodically leeching health and inflicting nausea.", affs = {"nausea"} },
  tags      = {"healthleech","damage-over-time"},
}

D.ninkharsag = {
  id        = 991,
  name      = "Nin'kharsag",
  title     = "Slime Lord",
  syntax    = "COMMAND SLIME AT <target>",
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 2.60,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"offense","lock-support"},
  summary   = "Slime slows the target's next tree tattoo; if they have asthma, they are paralysed.",
  tags      = {"tree-slow","conditional-paralysis"},
  affs_conditional = { asthma = {"paralysis"} },
  primebond = { summary = "Slime periodically damages the target; damage increases if they have healthleech.", tags = {"periodic-damage","healthleech-synergy"} },
}

D.istria = {
  id        = 992,
  name      = "Istria",
  title     = "Pathfinder",
  syntax    = "ORDER PATHFINDER HOME",
  works_on  = "self",
  bal_type  = "eq",
  bal_cost  = 3.00,
  queue_flag = "eq",
  roles     = {"movement","utility"},
  summary   = "Returns you to the room where the Pathfinder entity was originally summoned.",
  tags      = {"pathfinder","home-return"},
}

D.marduk = {
  id        = 993,
  name      = "Marduk",
  title     = "Soulmaster",
  syntax    = {"ORDER SOULMASTER POSSESS <target>", "ORDER <target> <command>"},
  works_on  = "adventurers",
  bal_type  = "eq",
  bal_cost  = 3.00,
  queue_flag = "eq",
  roles     = {"control","utility"},
  summary   = "Soulmaster possesses a victim's mind, allowing remote ORDER <target> <command> actions.",
  tags      = {"possession","remote-order"},
  notes     = { "Possession takes a few seconds.", "Commands via the soulmaster are limited by an internal cooldown." },
}

D.eerion = {
  title = "Eerion",
  name = "Gremlin",
  id = 985,

  syntax = "COMMAND GREMLIN AT <target>",
  target = "enemy",
  works_on = "adventurers+denizens",

  bal_type = "eq",
  bal_cost = 2.75,
  queue_flag = "eq",
  mana_cost = 50,

  roles = {"entities", "utility", "offense"},
  tags  = {"shieldbreak"},

  summary = "Commands a foul gremlin to shatter the magical shields surrounding your target. If your target labours under whispering madness, you recover faster from this ability.",

  primebond = {
    summary = "Passive: when primebonded, the gremlin will race around the legs of your target, inspiring dizziness; if they are already dizzy, it will knock them off balance.",
    tags = {"passive"},
  },
}


D.nemesis = {
  id        = 994,
  name      = "Nemesis",
  title     = "Humbug",
  syntax    = "COMMAND HUMBUG AT <target>",
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 2.20,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"offense","affliction"},
  summary   = "Inspires an insatiable addiction in the target.",
  affs      = {"addiction"},
  primebond = { summary = "Humbug drains health, and if the target has addiction, also drains mana and extra health.", tags = {"hp-drain","mana-drain","addiction-synergy"} },
}

D.lycantha = {
  id        = 1000,
  name      = "Lycantha",
  title     = "Hound",
  syntax    = {"SUMMON LYCANTHA", "COMMAND HOUND AT <target>", "ORDER HOUND KILL <target>"},
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 2.20,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"offense","pressure"},
  summary   = "Calls the chaos hound's bite to wear down a target; base effect is weariness, plus ongoing kill pressure.",
  affs      = {"weariness"},
  tags      = {"weariness","entity","hound"},
}

D.buul = {
  id        = 995,
  name      = "Buul",
  title     = "Chimera",
  syntax    = {"COMMAND CHIMERA AT <target>", "MOUNT CHIMERA", "SPUR CHIMERA SKYWARD"},
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 2.50,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"offense","control","mount"},
  summary   = "Chimera delivers a mind affliction; primebond grants periodic roar/headbutt/breath effects.",
  tags      = {"prone","deaf","sleep","mount"},
  primebond = { summary = "Heads periodically act: roar (cures deafness or stuns/knocks prone), headbutt (prone), breath (sleep).", tags = {"stun","prone","sleep"} },
}

D.cadmus = {
  title = "Cadmus",
  name = "Bubonis",
  id = 996,

  syntax = "COMMAND BUBONIS AT <target>",
  target = "enemy",
  works_on = "adventurers",

  bal_type = "entity",
  bal_cost = 2.20,
  queue_flag = "ent",
  mana_cost = 50,

  roles = {"entities", "offense"},
  tags  = {"asthma", "slickness-conditional"},

  summary = "Commands the plague lord's bubonis to strike your foe, giving asthma; if they already have asthma, it instead inflicts slickness.",

  affs = { primary = {"asthma"} },
  affs_conditional = {
    ["if_target_has_asthma"] = {"slickness"},
  },

  primebond = {
    summary = "Passive: when primebonded, the bubonis will act of its own will, inflicting maladies of the mind.",
    tags = {"passive"},
  },
}


D.piridon = {
  id        = 997,
  name      = "Piridon",
  title     = "Doppleganger",
  syntax    = "ORDER DOPPLEGANGER CHANNEL <ab>|CLOAK|EXITS|LOOK|MOVE|RETURN|SEEK <who>",
  works_on  = "adventurers+room",
  bal_type  = "eq",
  bal_cost  = nil,
  queue_flag = "eq",
  roles     = {"utility","projection","offense-support"},
  summary   = "Summons a doppleganger that can channel certain Occultism abilities and scout remotely.",
  tags      = {"channel","scout","proxy-cast"},
  channel_abilities = { "Ague","Devolution","Eldritchmists","Quicken","Shrivel","Timewarp","Warp" },
}

D.danaeus = {
  id        = 998,
  name      = "Danaeus",
  title     = "Chaos Storm",
  syntax    = "COMMAND STORM AT <target>",
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 2.20,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"offense","utility"},
  summary   = "Storm afflicts the target with clumsiness; primebond periodically reports the target's location.",
  affs      = {"clumsiness"},
  primebond = { summary = "Storm periodically tells you where the target is (local area, not scry-blocked).", tags = {"tracking","scry"} },
}

D.tarotlink = {
  id        = 1001,
  name      = "Tarotlink",
  title     = "Tarotlink",
  syntax    = "ORDER DOPPLEGANGER CHANNEL FLING <tarot card> [target]",
  works_on  = "adventurers",
  bal_type  = "bal",
  bal_cost  = 3.00,
  queue_flag = "bal",
  roles     = {"utility","offense-support"},
  summary   = "Allows your doppleganger to fling certain tarot cards remotely using your deck.",
  tags      = {"tarot","proxy-cast"},
  notes     = { "Not all tarot cards are valid via Tarotlink (e.g. Death and Hermit are excluded)." },
}

D.hecate = {
  id        = 1002,
  name      = "Hecate",
  title     = "Crone",
  syntax    = "COMMAND CRONE AT <target> <LEFT|RIGHT ARM|LEG>",
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 3.00,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"offense","limb"},
  summary   = "Withers the specified limb of your victim; primebond makes the crone periodically wither limbs on her own.",
  tags      = {"limb-wither","prep"},
  primebond = { summary = "Crone will wither limbs of her own accord (not always the optimal choice)." },
}

D.glaaki = {
  id        = 2342,
  name      = "Glaaki",
  title     = "Abomination",
  syntax    = "SUMMON GLAAKI ; COMMAND ABOMINATION AT <target>",
  works_on  = "adventurers",
  bal_type  = nil,
  bal_cost  = nil,
  queue_flag = nil,
  roles     = {"setup","truename","high-tier"},
  summary   = "Summons an abomination; when used on a sufficiently vulnerable aura, reveals the target's truename.",
  tags      = {"truename","cleanseaura-synergy"},
  notes     = {
    "Aura must be made 'sufficiently vulnerable', e.g. via Cleanseaura (target mana ≤ 40%).",
    "Truenames obtained this way are shorter-lived than standard TRUENAME gains.",
    "Intended to feed into Enlighten + Unravel kill routes when no corpse truename is available.",
  },
}

function Yso.occ.getDom(key)
  if not key then return nil end
  return D[_lc(key)]
end

function Yso.occ.getDomById(id)
  if not id then return nil end
  for _, v in pairs(D) do
    if v and v.id == id then return v end
  end
  return nil
end

function Yso.occ.listDomByRole(role)
  return _sorted_keys_by_role(D, role, "roles")
end

--========================================================--
-- Affliction capability index (derived from reference tables)
--  • This answers: "Which lane can actually GIVE aff X?"
--  • Data is pulled from explicit fields only:
--      options / affs / effects.affs / affs_conditional / primebond.affs
--  • Lanes are normalized to: eq | bal | ent
--========================================================--
Yso.occultist.affcap = Yso.occultist.affcap or {}
local AC = Yso.occultist.affcap

local function _lane_norm(x)
  x = tostring(x or ""):lower()
  if x == "equilibrium" then return "eq" end
  if x == "balance" then return "bal" end
  if x == "entity" then return "ent" end
  return x
end

local function _aff_norm(a)
  a = tostring(a or "")
  a = a:gsub("[%.,;:!%?]+$", "")
       :gsub("[%s%-]+","_")
       :lower()
  return (a ~= "" and a) or nil
end

local function _ac_add(aff, src)
  aff = _aff_norm(aff)
  if not aff then return end
  src = src or {}
  src.aff = aff
  AC.by_aff = AC.by_aff or {}
  AC.by_aff[aff] = AC.by_aff[aff] or {}
  AC.by_aff[aff][#AC.by_aff[aff] + 1] = src

  local lane = _lane_norm(src.lane or src.queue_flag or src.bal_type)
  if lane and lane ~= "" then
    AC.by_lane = AC.by_lane or {}
    AC.by_lane[lane] = AC.by_lane[lane] or {}
    AC.by_lane[lane][aff] = true
  end
end

local function _collect_affs(entry)
  local out = {}

  local function mark(a, meta)
    a = _aff_norm(a)
    if not a then return end
    out[a] = meta or true
  end

  -- INSTILL-style options
  if type(entry.options) == "table" then
    for i = 1, #entry.options do mark(entry.options[i], { kind = "option" }) end
  end

  local function add_affs_tbl(t, kind)
    if type(t) ~= "table" then return end
    if #t > 0 then
      for i = 1, #t do mark(t[i], { kind = kind }) end
    else
      for k, v in pairs(t) do
        if type(v) == "string" then
          mark(v, { kind = kind, bucket = tostring(k) })
        elseif type(v) == "table" then
          for i = 1, #v do mark(v[i], { kind = kind, bucket = tostring(k) }) end
        end
      end
    end
  end

  add_affs_tbl(entry.affs, "affs")
  if entry.effects and type(entry.effects) == "table" then
    add_affs_tbl(entry.effects.affs, "effects")
  end

  -- Conditional affs (documented)
  if type(entry.affs_conditional) == "table" then
    for cond, vals in pairs(entry.affs_conditional) do
      if type(vals) == "string" then
        mark(vals, { kind = "conditional", cond = tostring(cond) })
      elseif type(vals) == "table" then
        for i = 1, #vals do mark(vals[i], { kind = "conditional", cond = tostring(cond) }) end
      end
    end
  end

  -- Primebond passive affs (only if explicitly listed)
  if entry.primebond and type(entry.primebond) == "table" then
    add_affs_tbl(entry.primebond.affs, "primebond")
  end

  return out
end

local function _syntax_short(syn)
  if type(syn) == "string" then return syn end
  if type(syn) == "table" then return syn[1] end
  return nil
end

local function _index_table(tbl, default_skillset)
  if type(tbl) ~= "table" then return end
  for key, entry in pairs(tbl) do
    if type(entry) == "table" then
      local lane = _lane_norm(entry.queue_flag or entry.bal_type)
      local affs = _collect_affs(entry)
      for aff, meta in pairs(affs) do
        local src = {
          lane     = lane,
          skillset = entry.skillset or default_skillset,
          key      = tostring(key),
          name     = entry.name or entry.title or tostring(key),
          syntax   = _syntax_short(entry.syntax),
          kind     = (type(meta) == "table" and meta.kind) or nil,
          cond     = (type(meta) == "table" and meta.cond) or nil,
          bucket   = (type(meta) == "table" and meta.bucket) or nil,
        }
        _ac_add(aff, src)
      end
    end
  end
end

function Yso.occultist.build_affcap(force)
  if AC.by_aff and force ~= true then return AC.by_aff end
  AC.by_aff = {}
  AC.by_lane = {}

  -- Locals O/T/D are defined in this file. If they are missing, fail safely.
  _index_table(O, "Occultism")
  _index_table(T, "Tarot")
  _index_table(D, "Domination")

  return AC.by_aff
end

function Yso.occultist.aff_sources(aff)
  Yso.occultist.build_affcap()
  aff = _aff_norm(aff)
  return (aff and AC.by_aff and AC.by_aff[aff]) or {}
end

function Yso.occultist.aff_lanes(aff)
  local src = Yso.occultist.aff_sources(aff)
  local out = {}
  for i = 1, #src do
    local lane = _lane_norm(src[i].lane)
    if lane and lane ~= "" then out[lane] = true end
  end
  return out
end

function Yso.occultist.affs_by_lane(lane)
  Yso.occultist.build_affcap()
  lane = _lane_norm(lane)
  local t = (lane and AC.by_lane and AC.by_lane[lane]) or {}
  local out = {}
  for a, _ in pairs(t) do out[#out+1] = a end
  table.sort(out)
  return out
end

-- Prebuild once so oca ff inspection is instant.
Yso.occultist.build_affcap(false)

-- Optional load chatter (safe no-op if cecho is absent)
if type(cecho) == "function" then
  local occ_off = #Yso.occultist.listOccultismByRole("offense")
  local tar_off = #Yso.occultist.listTarotByRole("offense")
  local dom_cnt = 0; for _ in pairs(D) do dom_cnt = dom_cnt + 1 end

  cecho(string.format("<green>[Yso] Skillset references loaded: Occultism(offense=%d), Tarot(offense=%d), Domination(entities=%d).\n",
    occ_off, tar_off, dom_cnt))
end

--========================================================--
-- end yso_occultist_skillset_ref.lua
--========================================================--


-- -------------------------------------------------------------------
-- Magi — Resonance stage effects (reference for routing/planning)
--  These are the *proc* effects granted when you are resonant with an
--  Elemental Plane and cast resonant spells. Some stages have
--  conditional behaviour (e.g. Fire: scalded -> ablaze; blistered -> ablaze).
--  Keep this table synced with in-game HELP/SKILLCHART and AK triggers.
-- -------------------------------------------------------------------
Yso.magi = Yso.magi or {}
Yso.magi.resonance = Yso.magi.resonance or {}

-- Canonical keys (aff names) used by AK/Yso where possible.
-- NOTE: Some entries are "effects" rather than clean affs (e.g. random limb break).
Yso.magi.resonance.effects = Yso.magi.resonance.effects or {
  air = {
    minor    = { "asthma" },
    moderate = { "sensitivity" },
    major    = { "healthleech" },
  },
  earth = {
    -- Minor: breaks a random *unbroken* limb (represented as an effect tag).
    minor    = { "random_limb_break" },
    -- Moderate: short stun + paralysis (stun often not tracked as an aff).
    moderate = { "paralysis", "stun_short" },
    major    = { "cracked_ribs" },
  },
  fire = {
    -- Minor: strips temperance and applies a "no temperance" effect.
    minor    = { "notemper" },
    -- Moderate: scalded; if already scalded, tends to push into ablaze + damage.
    moderate = { "scalded" },
    -- Major: blistered; if already blistered, adds a stack of ablaze.
    major    = { "blisters", "ablaze" },
  },
  water = {
    -- Minor: frostbite; if already present, does extra cold damage.
    minor    = { "frostbite" },
    moderate = { "stuttering" },
    -- Major: anorexia (AK historically also treated this as nausea+anorexia).
    major    = { "anorexia", "nausea" },
  },
}

function Yso.magi.resonance.stage_affs(element, stage)
  element = tostring(element or ""):lower()
  stage   = tostring(stage   or ""):lower()
  local e = Yso.magi.resonance.effects[element]
  return (e and e[stage]) or {}
end
