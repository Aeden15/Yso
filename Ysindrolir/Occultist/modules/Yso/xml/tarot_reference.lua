-- Auto-exported from Mudlet package script: Tarot reference
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- yso_occultist_tarot_ref.lua (no aliases)
--  Occultist: Tarot reference data for Yso core
--========================================================--

Yso = Yso or {}
Yso.occultist = Yso.occultist or {}

local T = {}

----------------------------------------------------------------------
-- SUN
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- EMPEROR
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- MAGICIAN
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- PRIESTESS
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- FOOL
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- EMPRESS
----------------------------------------------------------------------
T.empress = {
  skillset   = "Tarot",
  name       = "Empress",
  syntax     = {
    "FLING EMPRESS AT <target>",
    "SNIFF EMPRESS <target>",
  },
  target     = "ally_or_enemy",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,
  role       = {"utility","movement","support"},
  summary    = "Summon someone on your allies list to you; Lust extends this to continent-wide summons.",
  tags       = {"summon","lust-synergy"},
}

----------------------------------------------------------------------
-- LOVERS
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- HANGEDMAN
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- TOWER
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- WHEEL
----------------------------------------------------------------------
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
    rays           = {
      first  = "freeze",
      second = "stuttering",
      third  = "strip_speed_or_give_aeon",
    },
    indiscriminate = true, -- hits everyone except you
  },
}

----------------------------------------------------------------------
-- JUSTICE
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- STAR
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- AEON
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- LUST
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- MOON
----------------------------------------------------------------------
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
  extra_info = { specified_aff_bal_cost = 2.10 }, -- at transcendent
  options    = {
    "stupidity","masochism","hallucinations",
    "hypersomnia","confusion","epilepsy",
    "claustrophobia","agoraphobia",
  },
}

----------------------------------------------------------------------
-- DEATH
----------------------------------------------------------------------
T.death = {
  skillset   = "Tarot",
  name       = "Death",
  syntax     = {
    "RUB DEATH ON <target>",
    "SNIFF DEATH",
    "FLING DEATH AT <target>",
  },
  target     = "enemy",
  queue_flag = "bal",
  bal_type   = "balance",
  bal_cost   = 3.00,   -- fling
  role       = {"offense","finisher"},
  summary    = "Rub to build attunement charges on a target, then fling to call Death and attempt an instant-kill style freeze/shiver.",
  tags       = {"execute","freeze","shivering"},
  variants   = {
    rub = {
      uses       = "equilibrium",
      eq_cost    = 3.20,
      charges_needed = 7,
      extra_charge_states = {"stun","aeon","entangled","shivering","paralysis"},
    },
    fling = {
      uses      = "balance",
      bal_cost  = 3.00,
    },
  },
}

----------------------------------------------------------------------
-- HERETIC
----------------------------------------------------------------------
T.heretic = {
  skillset   = "Tarot",
  name       = "Heretic",
  syntax     = {
    "RUINATE HERETIC AT <target>",
    "ORDER <target> WITNESS <vision>",
  },
  target     = "enemy",
  queue_flag = "bal",
  bal_type   = "balance",
  role       = {"offense","control","insanity"},
  summary    = "Non-transient ruinated image; lets you command a victim to WITNESS a vision so long as they are not blind.",
  tags       = {"vision","insanity","heretic"},
}

----------------------------------------------------------------------
-- RUINATE
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- Attach table + simple helpers
----------------------------------------------------------------------

Yso.occultist.tarot = T

-- Return card table by simple key (e.g. "moon", "aeon", "death").
function Yso.occultist.getTarot(key)
  if not key then return nil end
  key = string.lower(key)
  return T[key]
end

-- Treat cards tagged with "offense" or "finisher" as offensive.
function Yso.occultist.isTarotOffense(key)
  local c = Yso.occultist.getTarot(key)
  if not c or not c.role then return false end
  local offensive = false
  for _,r in ipairs(c.role) do
    if r == "offense" or r == "finisher" then
      offensive = true
      break
    end
  end
  if not offensive then return false end
  if c.flags and c.flags.include_in_offense == false then
    return false
  end
  return true
end

-- Return sorted list of card keys that have a given role.
function Yso.occultist.listTarotByRole(role)
  local out = {}
  for k,v in pairs(T) do
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

if cecho then
  cecho("<green>[Yso] Loaded Occultist/Tarot reference (v1, "..tostring(#Yso.occultist.listTarotByRole("offense")).." offense cards).\n")
end

--========================================================--
-- end yso_occultist_tarot_ref.lua
--========================================================--
