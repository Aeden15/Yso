-- Auto-exported from Mudlet package script: Domination reference
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- yso_occ_domination_ref.lua
--  Occultist Domination: entity / utility reference
--  • Pure data (no sends/aliases)
--  • Dameron + Glaaki currently treated as balanceless
--  • bal_type: "ent" = entity, "eq" = equilibrium, "bal" = standard balance
--========================================================--

Yso      = Yso      or {}
Yso.occ  = Yso.occ  or {}
Yso.occ.dom = Yso.occ.dom or {}

local D = Yso.occ.dom

----------------------------------------------------------------------
-- SKYRAX — DERVISH
--  COMMAND DERVISH AT <target>  (2.10s entity balance, 50 mana)
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- RIXIL — SYCOPHANT
--  COMMAND SYCOPHANT AT <target>  (2.00s entity balance, 50 mana)
----------------------------------------------------------------------
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
  primebond = {
    summary = "Sycophant drains enemy mana; more if shivering, even more if frozen.",
  },
}

----------------------------------------------------------------------
-- SCRAG — BLOODLEECH
--  COMMAND BLOODLEECH AT <target>  (2.20s entity balance, 50 mana)
----------------------------------------------------------------------
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
  primebond = {
    summary = "Leech periodically causes bleeding; bleed is increased if blood is thinned.",
  },
}

----------------------------------------------------------------------
-- PYRADIUS — FIRELORD
--  COMMAND FIRELORD AT <target> <affliction> (3.00s entity, 50 mana)
----------------------------------------------------------------------
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
  converts  = {
    whisperingmadness = "recklessness",
    manaleech         = "anorexia",
    healthleech       = "psychic_damage", -- does not cure the leech
  },
  tags      = {"aff-conversion","room-aoe","ablaze"},
  primebond = {
    summary = "Firelords strike those in and near your room with fire, setting them ablaze.",
  },
}

----------------------------------------------------------------------
-- GOLGOTHA
--  SUMMON GOLGOTHA  (2.40s equilibrium)
----------------------------------------------------------------------
D.golgotha = {
  -- helpfile shows only SUMMON; no ABADMIN ID in your snippet
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

----------------------------------------------------------------------
-- DAMERON — MINION (UNRAVEL helper)
--  COMMAND MINION AT <target>  (treated as balanceless for now)
----------------------------------------------------------------------
D.dameron = {
  id        = 989,
  name      = "Dameron",
  title     = "Minion",
  syntax    = "COMMAND MINION AT <target>",
  works_on  = "adventurers",

  -- UNTIL CONFIRMED: treat as balanceless
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

----------------------------------------------------------------------
-- WORM — GLUTTON WORM
--  COMMAND WORM AT <target>  (3.10s entity, 50 mana)
----------------------------------------------------------------------
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
  roles     = {"offense","dot","affliction"},
  summary   = "Infests the victim with maggots that periodically leech health.",
  affs      = {"healthleech"},
  primebond = {
    summary = "Worm burrows into the belly, periodically leeching health and inflicting nausea.",
    affs    = {"nausea"},
  },
  tags      = {"healthleech","damage-over-time"},
}

----------------------------------------------------------------------
-- NIN'KHARSAG — SLIME LORD
--  COMMAND SLIME AT <target>  (2.60s entity, 50 mana)
----------------------------------------------------------------------
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
  affs_conditional = {
    asthma = {"paralysis"},
  },
  primebond = {
    summary = "Slime periodically damages the target; damage increases if they have healthleech.",
    tags    = {"periodic-damage","healthleech-synergy"},
  },
}

----------------------------------------------------------------------
-- ISTRIA — PATHFINDER
--  ORDER PATHFINDER HOME  (3.00s equilibrium)
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- MARDUK — SOULMASTER
--  ORDER SOULMASTER POSSESS <target> ; ORDER <target> <command>
--  (3.00s equilibrium)
----------------------------------------------------------------------
D.marduk = {
  id        = 993,
  name      = "Marduk",
  title     = "Soulmaster",
  syntax    = {
    "ORDER SOULMASTER POSSESS <target>",
    "ORDER <target> <command>",
  },
  works_on  = "adventurers",
  bal_type  = "eq",
  bal_cost  = 3.00,
  queue_flag = "eq",
  roles     = {"control","utility"},
  summary   = "Soulmaster possesses a victim's mind, allowing remote ORDER <target> <command> actions.",
  tags      = {"possession","remote-order"},
  notes     = {
    "Possession takes a few seconds.",
    "Commands via the soulmaster are limited by an internal cooldown.",
  },
}

----------------------------------------------------------------------
-- NEMESIS — HUMBUG
--  COMMAND HUMBUG AT <target>  (2.20s entity, 50 mana)
----------------------------------------------------------------------
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
  primebond = {
    summary = "Humbug drains health, and if the target has addiction, also drains mana and extra health.",
    tags    = {"hp-drain","mana-drain","addiction-synergy"},
  },
}

----------------------------------------------------------------------
-- BUUL — CHIMERA
--  COMMAND CHIMERA AT <target> ; MOUNT CHIMERA ; SPUR CHIMERA SKYWARD
--  (2.50s entity, 50 mana)
----------------------------------------------------------------------
D.buul = {
  id        = 995,
  name      = "Buul",
  title     = "Chimera",
  syntax    = {
    "COMMAND CHIMERA AT <target>",
    "MOUNT CHIMERA",
    "SPUR CHIMERA SKYWARD",
  },
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 2.50,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"offense","control","mount"},
  summary   = "Chimera delivers a mind affliction; primebond grants periodic roar/headbutt/breath effects.",
  tags      = {"prone","deaf","sleep","mount"},
  primebond = {
    summary = "Heads periodically act: roar (cures deafness or stuns/knocks prone), headbutt (prone), breath (sleep).",
    tags    = {"stun","prone","sleep"},
  },
}

----------------------------------------------------------------------
-- CADMUS — BUBONIS
--  COMMAND BUBONIS AT <target>  (2.20s entity, 50 mana)
----------------------------------------------------------------------
D.cadmus = {
  id        = 996,
  name      = "Cadmus",
  title     = "Bubonis",
  syntax    = "COMMAND BUBONIS AT <target>",
  works_on  = "adventurers",
  bal_type  = "ent",
  bal_cost  = 2.20,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"offense","affliction"},
  summary   = "Torments the victim's lungs; base effect gives asthma and can stack further torment.",
  affs      = {"asthma"},
  primebond = {
    summary = "Bubonis periodically acts of its own will, inflicting mind maladies.",
    tags    = {"mental-affs"},
  },
}


----------------------------------------------------------------------
-- LYCANTHA — HOUND
--  COMMAND HOUND AT <target>  (2.20s entity balance, 50 mana)
----------------------------------------------------------------------
D.lycantha = {
  id        = 1000,
  name      = "Lycantha",
  title     = "Hound",
  syntax    = {
    "SUMMON LYCANTHA",
    "COMMAND HOUND AT <target>",
    "ORDER HOUND KILL <target>",
  },
  works_on  = "adventurers+denizens",
  bal_type  = "ent",
  bal_cost  = 2.20,
  queue_flag = "ent",
  mana_cost = 50,
  roles     = {"offense","pressure"},
  summary   = "Commands a chaos hound to serve you; when commanded at an adventurer it inspires weariness. Against denizens it rends flesh for damage.",
  affs      = {"weariness"},
  tags      = {"weariness","entity","hound"},
}

----------------------------------------------------------------------
-- PIRIDON — DOPPLEGANGER
--  ORDER DOPPLEGANGER CHANNEL <ab>|CLOAK|EXITS|LOOK|MOVE|RETURN|SEEK <who>
--  Cooldown: equilibrium (no explicit seconds)
----------------------------------------------------------------------
D.piridon = {
  id        = 997,
  name      = "Piridon",
  title     = "Doppleganger",
  syntax    = "ORDER DOPPLEGANGER CHANNEL <ab>|CLOAK|EXITS|LOOK|MOVE|RETURN|SEEK <who>",
  works_on  = "adventurers+room",
  bal_type  = "eq",
  bal_cost  = nil,  -- helpfile just says 'Equilibrium'
  queue_flag = "eq",
  roles     = {"utility","projection","offense-support"},
  summary   = "Summons a doppleganger that can channel certain Occultism abilities and scout remotely.",
  tags      = {"channel","scout","proxy-cast"},
  channel_abilities = {
    "Ague","Devolution","Eldritchmists",
    "Quicken","Shrivel","Timewarp","Warp",
  },
}

----------------------------------------------------------------------
-- DANAEUS — CHAOS STORM
--  COMMAND STORM AT <target>  (2.20s entity, 50 mana)
----------------------------------------------------------------------
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
  primebond = {
    summary = "Storm periodically tells you where the target is (local area, not scry-blocked).",
    tags    = {"tracking","scry"},
  },
}

----------------------------------------------------------------------
-- TAROTLINK
--  ORDER DOPPLEGANGER CHANNEL FLING <tarot card> [target]
--  (3.00s balance)
----------------------------------------------------------------------
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
  notes     = {
    "Not all tarot cards are valid via Tarotlink (e.g. Death and Hermit are excluded).",
  },
}

----------------------------------------------------------------------
-- HECATE — CRONE
--  COMMAND CRONE AT <target> <LEFT|RIGHT ARM|LEG>  (3.00s entity, 50 mana)
----------------------------------------------------------------------
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
  primebond = {
    summary = "Crone will wither limbs of her own accord (not always the optimal choice).",
  },
}

----------------------------------------------------------------------
-- GLAAKI — ABOMINATION / TRUENAME
--  SUMMON GLAAKI ; COMMAND ABOMINATION AT <target>
--  (treated as balanceless for now)
----------------------------------------------------------------------
D.glaaki = {
  id        = 2342,
  name      = "Glaaki",
  title     = "Abomination",
  syntax    = "SUMMON GLAAKI ; COMMAND ABOMINATION AT <target>",
  works_on  = "adventurers",

  -- UNTIL CONFIRMED: treat as balanceless
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

--==================================================================--
-- Helper accessors
--==================================================================--

--- Get Domination entry by short key (e.g. "scrag", "worm", "glaaki").
function Yso.occ.getDom(key)
  if not key then return nil end
  key = key:lower()
  return D[key]
end

--- Get Domination entry by ABADMIN id.
function Yso.occ.getDomById(id)
  if not id then return nil end
  for _, v in pairs(D) do
    if v.id == id then return v end
  end
  return nil
end

--- List all Domination entities, optionally filtered by role.
function Yso.occ.listDomByRole(role)
  local out = {}
  for k, v in pairs(D) do
    if not role then
      table.insert(out, k)
    elseif v.roles then
      for _, r in ipairs(v.roles) do
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


--- Get Domination entry by canonical route-entity key (e.g. "worm", "storm", "slime").
function Yso.occ.getDomByEntity(entity)
  if not entity then return nil end
  local map = {
    worm = "worm",
    storm = "danaeus",
    slime = "ninkharsag",
    sycophant = "rixil",
    humbug = "nemesis",
    firelord = "pyradius",
  }
  local key = tostring(entity or ""):lower()
  return Yso.occ.getDom(map[key] or key)
end

--- Get a best-effort lowercase pact/bond name for an entity.
function Yso.occ.getDomBondName(entity)
  local d = Yso.occ.getDomByEntity(entity)
  return d and tostring(d.name or entity or ""):lower() or tostring(entity or ""):lower()
end

do
  local count = 0
  for _ in pairs(D) do count = count + 1 end
  if cecho then
    cecho(string.format(
      "<green>[Yso] Occultist Domination reference loaded (%d entities).\n",
      count
    ))
  end
end

--========================================================--
-- end yso_occ_domination_ref.lua
--========================================================--
