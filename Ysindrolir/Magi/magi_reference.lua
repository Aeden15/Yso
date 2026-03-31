--========================================================--
-- Magi Skill Reference (Elementalism / Crystalism / Artificing)
--  • Reference-first: primarily for humans + future automation.
--  • Built from in-game AB outputs (screenshots) + Dale's notes.
--  • Keep this as a living document; add missing skills as captured.
--
-- Conventions
--  • cooldown_s is seconds of equilibrium unless otherwise stated.
--  • resource_mana is mana cost when shown.
--  • shapes = Crystalism "Required Shapes".
--  • channels = Elementalism "Required Channels".
--========================================================--

Yso = Yso or {}
Yso.ref = Yso.ref or {}
Yso.ref.magi = Yso.ref.magi or {}
Yso.magi = Yso.magi or {}
Yso.magi.crystalism = Yso.magi.crystalism or {}

local M = Yso.ref.magi
local runtime_resonance = type(Yso.magi.resonance) == "table" and Yso.magi.resonance or nil

M.meta = {
  class = "Magi",
  updated = "2026-03-29",
  notes = {
    "Resonance is a core Magi mechanic. Resonant spells build elemental resonance (air/fire/earth/water).",
    "Yso resonance keeps a lowercase state table and can sync from AK's live Magi resonance tracker.",
  },
}

--========================================================--
-- Resonance
--========================================================--
M.resonance = M.resonance or runtime_resonance or {}
if runtime_resonance and runtime_resonance ~= M.resonance then
  for k, v in pairs(runtime_resonance) do
    if M.resonance[k] == nil then
      M.resonance[k] = v
    end
  end
end
Yso.magi.resonance = M.resonance
M.resonance.levels = { none = 0, minor = 1, moderate = 2, major = 3 }
M.resonance.word_to_level = { minorly = "minor", moderately = "moderate", majorly = "major" }
M.resonance.state = M.resonance.state or { air = 0, earth = 0, fire = 0, water = 0 }
M.resonance.last_sync = M.resonance.last_sync or { source = "init", ok = false, at = 0, changed = false }

-- Example line:
--   You are now minorly resonant with the Elemental Plane of Fire.
M.resonance.single_line_pat = [[^You are now (%a+) resonant with the Elemental Plane of (%a+)%.$]]
M.resonance.dual_line_pat = [[^You are now (%a+) resonant with the Elemental Planes of (%a+) and (%a+)%.$]]

local function _res_now()
  local nowf = rawget(_G, "_now")
  if type(nowf) == "function" then
    local ok, v = pcall(nowf)
    if ok and tonumber(v) then return tonumber(v) end
  end
  return os.time()
end

local function _res_note_sync(source, ok, changed)
  M.resonance.last_sync = {
    source = tostring(source or ""),
    ok = (ok == true),
    at = _res_now(),
    changed = (changed == true),
  }
end

local function _res_norm_element(element)
  element = tostring(element or ""):lower()
  if element == "air" or element == "earth" or element == "fire" or element == "water" then
    return element
  end
  return ""
end

local function _cry_trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.resonance.clear()
  for k in pairs(M.resonance.state) do M.resonance.state[k] = 0 end
  _res_note_sync("clear", true, true)
end

function M.resonance.set(element, level)
  element = _res_norm_element(element)
  if element == "" then return false end

  local lvl = level
  if type(lvl) == "string" then
    lvl = lvl:lower()
    lvl = M.resonance.levels[lvl] or tonumber(lvl)
  end
  if type(lvl) ~= "number" then return false end
  if lvl < 0 then lvl = 0 end
  if lvl > 3 then lvl = 3 end

  local changed = (M.resonance.state[element] ~= lvl)
  M.resonance.state[element] = lvl
  _res_note_sync("set", true, changed)
  return true
end

function M.resonance.get(element)
  element = _res_norm_element(element)
  if element == "" then return 0 end
  return M.resonance.state[element] or 0
end

function M.resonance.sync_from_ak()
  local ak = rawget(_G, "ak")
  local row = ak and ak.magi and ak.magi.resonance or nil
  if type(row) ~= "table" then
    _res_note_sync("ak", false, false)
    return false, false
  end

  local changed = false
  local map = {
    air = "Air",
    earth = "Earth",
    fire = "Fire",
    water = "Water",
  }

  for lower, upper in pairs(map) do
    local lvl = tonumber(row[upper] or row[lower] or 0) or 0
    if lvl < 0 then lvl = 0 end
    if lvl > 3 then lvl = 3 end
    if M.resonance.state[lower] ~= lvl then changed = true end
    M.resonance.state[lower] = lvl
  end

  _res_note_sync("ak", true, changed)
  return true, changed
end

-- Parse a resonance line; returns: elements(lowercase table), level(number), level_name(string)
function M.resonance.parse_line(line)
  line = tostring(line or "")
  local w, el1, el2 = line:match(M.resonance.dual_line_pat)
  local level_name = M.resonance.word_to_level[w]
  if level_name and el1 and el2 then
    local level = M.resonance.levels[level_name] or 0
    return { _res_norm_element(el1), _res_norm_element(el2) }, level, level_name
  end

  w, el1 = line:match(M.resonance.single_line_pat)
  level_name = M.resonance.word_to_level[w]
  if not level_name or not el1 then return nil end
  local level = M.resonance.levels[level_name] or 0
  return { _res_norm_element(el1) }, level, level_name
end

function M.resonance.apply_line(line)
  local elements, level, level_name = M.resonance.parse_line(line)
  if type(elements) ~= "table" or type(level) ~= "number" then
    return false
  end

  local changed = false
  for i = 1, #elements do
    local el = _res_norm_element(elements[i])
    if el ~= "" then
      if M.resonance.state[el] ~= level then changed = true end
      M.resonance.state[el] = level
    end
  end

  _res_note_sync("parse_line", true, changed)
  return true, elements, level, level_name
end

--========================================================--
-- Crystalism resonance notices
--========================================================--
local CState = Yso.magi.crystalism
CState.state = CState.state or {
  last_skill = "",
  last_target = "",
  last_seen_at = 0,
  energise_resonating = false,
  energise_target = "",
  energise_seen_at = 0,
}

function CState.reset()
  local st = CState.state or {}
  st.last_skill = ""
  st.last_target = ""
  st.last_seen_at = 0
  st.energise_resonating = false
  st.energise_target = ""
  st.energise_seen_at = 0
  CState.state = st
  return st
end

function CState.note_resonance(skill, target)
  local st = CState.state or {}
  skill = _cry_trim(skill):lower()
  target = _cry_trim(target)
  st.last_skill = skill
  st.last_target = target
  st.last_seen_at = _res_now()
  if skill == "energise" then
    st.energise_resonating = true
    st.energise_target = target
    st.energise_seen_at = st.last_seen_at
  end
  CState.state = st
  return true
end

function CState.clear_energise_resonance()
  local st = CState.state or {}
  st.energise_resonating = false
  st.energise_target = ""
  st.energise_seen_at = 0
  CState.state = st
  return true
end

function CState.has_energise_resonance()
  local st = CState.state or {}
  return st.energise_resonating == true
end

function CState.consume_energise_resonance()
  if not CState.has_energise_resonance() then return false end
  CState.clear_energise_resonance()
  return true
end


-- Resonance stage effects (what procs at each stage)
--   Air:   minor->asthma,      moderate->sensitivity, major->healthleech
--   Earth: minor->(random limb break), moderate->(short stun + paralysis), major->cracked_ribs
--   Fire:  minor->notemper (strip/deny temperance), moderate->scalded (if already scalded -> ablaze+damage),
--          major->blisters (if already blistered -> +ablaze stack)
--   Water: minor->frostbite (if already present -> damage), moderate->stuttering (+cold dmg), major->anorexia (AK also tracked nausea+anorexia)
--
-- Structured form (for routes):
M.resonance.effects = M.resonance.effects or {
  air   = { minor={"asthma"},      moderate={"sensitivity"}, major={"healthleech"} },
  earth = { minor={"random_limb_break"}, moderate={"paralysis","stun_short"}, major={"cracked_ribs"} },
  fire  = { minor={"notemper"},    moderate={"scalded"},     major={"blisters","ablaze"} },
  water = { minor={"frostbite"},   moderate={"stuttering"},  major={"anorexia","nausea"} },
}

-- helper
function M.resonance.stage_affs(element, stage)
  element = tostring(element or ""):lower()
  stage   = tostring(stage   or ""):lower()
  local e = M.resonance.effects[element]
  return (e and e[stage]) or {}
end

--========================================================--
-- Elementalism
--========================================================--
M.elementalism = {
  -- Spell lists (names only; add details as captured)
  lists = {
    higher_order = {
      "Hypothermia",
      "Shalestorm",
      "Firestorm",
      "Glaciate",
      "Conflagrate",
      "Emanation",
      "Purity",
      "Convergence",
    },
    resonant = {
      "Gust",
      "Firelash",
      "Freeze",
      "Geyser",
      "Dehydrate",
      "Fulminate",
      "Bombard",
      "Mudslide",
      "Meteorite",
      "Magma",
      "Transfix",
    },
  },

  -- Captured ABs
  bloodboil = {
    name = "Bloodboil",
    abadmin_id = 717,
    syntax = "CAST BLOODBOIL",
    channels = { "fire", "water" },
    works_on = "self",
    cooldown_s = 4.00,
    resource_mana = 75,
    notes = {
      "Cures you of an affliction (random).",
      "If you have haemophilia, bloodboil will not work.",
      "If majorly resonant with Fire AND Water, you have a chance to cure a second affliction.",
    },
  },

  reflection = {
    name = "Reflection",
    abadmin_id = 703,
    syntax = "CAST REFLECTION AT ME/<target>",
    channels = { "air", "fire" },
    works_on = "adventurers and self",
    cooldown_s = 3.00,
    resource_mana = 50,
    notes = {
      "Creates a magical reflection that will absorb one attack before being destroyed.",
      "You may only have one reflection at a time.",
    },
  },

  stonefist = {
    name = "Stonefist",
    abadmin_id = 706,
    syntax = "CAST STONEFIST / RELAX STONEFIST",
    channels = { "earth" },
    works_on = "self",
    cooldown_s = 4.00,
    resource_mana = 60,
    notes = {
      "Coats your fists in elemental earth; improves grip against attempts to pull your staff from your grasp.",
    },
  },

  stoneskin = {
    name = "Stoneskin",
    abadmin_id = 707,
    syntax = "CAST STONESKIN",
    channels = { "earth" },
    works_on = "self",
    cooldown_s = 2.00,
    resource_mana = 75,
    notes = {
      "Coats your body in stone; provides protection against physical attacks.",
    },
  },

  chargeshield = {
    name = "Chargeshield",
    abadmin_id = 714,
    syntax = "CAST CHARGESHIELD AT ME/<target>",
    channels = { "air", "earth" },
    works_on = "adventurers and self",
    cooldown_s = 4.00,
    resource_mana = 200,
    notes = {
      "Defensive spell providing protection from electric attacks.",
      "Also reduces the equilibrium penalty caused by the confusion affliction.",
    },
  },

  diamondskin = {
    name = "Diamondskin",
    abadmin_id = 734,
    syntax = "CAST DIAMONDSKIN",
    channels = { "earth", "fire", "water" },
    works_on = "self",
    cooldown_s = 2.00,
    resource_mana = 175,
    notes = {
      "Greatly increases resistance to cutting damage; modestly increases resistance to blunt damage.",
    },
  },

  conflagrate = {
    name = "Conflagrate",
    abadmin_id = 2217,
    syntax = "CAST CONFLAGRATE AT <target>",
    channels = { "fire" },
    works_on = "adventurers",
    cooldown_s = 2.35,
    resource_mana = 150,
    notes = {
      "Higher order fire spell: periodic damage until extinguished.",
      "Requires target has 2+ stacks of the ablaze affliction.",
      "Extinguish by removing all traces of ablaze from the target.",
    },
  },

  emanation = {
    name = "Emanation",
    abadmin_id = 3148,
    syntax = "CAST EMANATION AT <target> <AIR|EARTH|FIRE|WATER>",
    channels = { "air", "earth", "fire", "water" },
    works_on = "adventurers",
    cooldown_s = 2.40,
    resource_mana = 100,
    notes = {
      "Higher order spell: requires you are majorly resonant with the chosen Elemental Plane.",
      "Unleashes accumulated power in a single strike; clears your resonance for that Plane.",
      "AIR: paralysis + dizziness + short stun.",
      "EARTH: torso calcified; additionally slays outright if target has serious internal trauma.",
      "FIRE: applies 2 stacks of ablaze.",
      "WATER: applies a level of freeze (or strips insulation defence) and disrupts.",
    },
  },

  firewall = {
    name = "Firewall",
    abadmin_id = 721,
    syntax = "CAST FIREWALL <direction>",
    channels = { "fire" },
    works_on = "room",
    cooldown_s = 3.00,
    resource_mana = 100,
    notes = { "Creates walls of burning flame." },
  },

  fog = {
    name = "Fog",
    abadmin_id = 722,
    syntax = "CAST FOG",
    channels = { "air", "water" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 250,
    notes = { "Fills surroundings with elemental fog." },
  },

  hellfumes = {
    name = "Hellfumes",
    abadmin_id = 724,
    syntax = "CAST HELLFUMES",
    channels = { "air", "earth" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 200,
    notes = { "Creates a noxious cloud in your location, choking those around you." },
  },

  flood = {
    name = "Flood",
    abadmin_id = 726,
    syntax = "CAST FLOOD",
    channels = { "water" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 250,
    notes = { "Floods the room you stand in." },
  },

  hailstorm = {
    name = "Hailstorm",
    abadmin_id = 740,
    syntax = "CAST HAILSTORM",
    channels = { "air", "water" },
    works_on = "room",
    cooldown_s = 3.50,
    resource_mana = 500,
    notes = { "Rains hailstones down upon all your enemies in your location." },
  },

  icewall = {
    name = "Icewall",
    abadmin_id = 729,
    syntax = "CAST ICEWALL <direction>",
    channels = { "water" },
    works_on = "room",
    cooldown_s = 3.00,
    resource_mana = 100,
    notes = { "Creates a wall of elemental ice, blocking passage." },
  },
}

--========================================================--
-- Crystalism (Vibrations)
--========================================================--
M.crystalism = {
  -- NOTE: In addition to these embeds, Magi have a "vibration type" system
  -- (vibes) such as harmony/grounding/heat/reverberation/etc. Track that
  -- separately if you build automation around it.

  adduction = {
    name = "Adduction",
    abadmin_id = 3109,
    syntax = "EMBED ADDUCTION <crystal> AT <target> / RECALL ADDUCTION / RETRACT ADDUCTION",
    shapes = { "disc", "polyhedron" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Creates a magnetic field that draws in and holds those in your location, causing them to take longer to enter/leave.",
    },
  },

  silence = {
    name = "Silence",
    abadmin_id = 1119,
    syntax = "EMBED SILENCE <crystal> AT <target> / RECALL SILENCE / RETRACT SILENCE",
    shapes = { "egg" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Wrenches sound from the area; can prevent shouts and other loud noises from being made.",
    },
  },

  focus = {
    name = "Focus",
    abadmin_id = 965,
    syntax = "VIBES FOCUS",
    shapes = { "egg", "disc" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 100,
    notes = {
      "Magnifies the impact of your crystal vibrations. While active, your vibrations will apply more powerfully.",
    },
  },

  dissipate = {
    name = "Dissipate",
    abadmin_id = 1132,
    syntax = "EMBED DISSIPATE <crystal> AT <target> / RECALL DISSIPATE / RETRACT DISSIPATE",
    shapes = { "sphere" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Leaches energetic vibration; in the room it disrupts magical shielding and can crack the bones of those affected.",
    },
  },

  palpitation = {
    name = "Palpitation",
    abadmin_id = 960,
    syntax = "VIBES PALPITATION",
    shapes = { "sphere" },
    works_on = "room",
    cooldown_s = 3.00,
    resource_mana = 100,
    notes = { "Improves the rhythm of your heartbeat, increasing regeneration." },
  },

  tremors = {
    name = "Tremors",
    abadmin_id = 1339,
    syntax = "EMBED TREMORS <crystal> AT <target> / RECALL TREMORS / RETRACT TREMORS",
    shapes = { "disc" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Causes the ground to shake violently, knocking those in your location off balance.",
    },
  },

  creeps = {
    name = "Creeps",
    abadmin_id = 1148,
    syntax = "EMBED CREEPS <crystal> AT <target> / RECALL CREEPS / RETRACT CREEPS",
    shapes = { "polyhedron" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Increases the frequency of vibrations over time, causing a creeping sense of dread and paralysis in those affected.",
    },
  },

  oscillate = {
    name = "Oscillate",
    abadmin_id = 1150,
    syntax = "EMBED OSCILLATE <crystal> AT <target> / RECALL OSCILLATE / RETRACT OSCILLATE",
    shapes = { "polyhedron" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Disrupts breathing and inner ear balance, increasing respiratory distress and dizziness in those affected.",
    },
  },

  disorientation = {
    name = "Disorientation",
    abadmin_id = 984,
    syntax = "VIBES DISORIENTATION",
    shapes = { "polyhedron" },
    works_on = "room",
    cooldown_s = 3.00,
    resource_mana = 100,
    notes = {
      "Confuses the senses, making you more difficult to track and weakening the sensory information of others.",
    },
  },

  energise = {
    name = "Energise",
    abadmin_id = 3087,
    syntax = "EMBED ENERGISE <crystal> AT <target> / RECALL ENERGISE / RETRACT ENERGISE",
    shapes = { "egg" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = { "Energises the air with electric vibrations, increasing damage dealt to those in your location." },
  },

  stridulation = {
    name = "Stridulation",
    abadmin_id = 1319,
    syntax = "EMBED STRIDULATION <crystal> AT <target> / RECALL STRIDULATION / RETRACT STRIDULATION",
    shapes = { "egg", "polyhedron" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Creates a shrill screech in the area, disrupting concentration and increasing the chance enemies are afflicted with stupidity.",
    },
  },

  revelation = {
    name = "Revelation",
    syntax = "EMBED REVELATION",
    shapes = { "cube", "diamond" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Causes concealed adventurers in your location to be revealed.",
    },
  },

  gravity = {
    name = "Gravity",
    abadmin_id = 980,
    syntax = "VIBES GRAVITY",
    shapes = { "disc" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 100,
    notes = {
      "Creates an aura of gravity, increasing the equilibrium cost of certain actions by those affected.",
    },
  },

  forest = {
    name = "Forest",
    abadmin_id = 1104,
    syntax = "EMBED FOREST <crystal> AT <target> / RECALL FOREST / RETRACT FOREST",
    shapes = { "polyhedron" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Causes plantlife to rise and entangle, making movement sluggish and hindering escape.",
    },
  },

  dissonance = {
    name = "Dissonance",
    abadmin_id = 1141,
    syntax = "EMBED DISSONANCE <crystal> AT <target> / RECALL DISSONANCE / RETRACT DISSONANCE",
    shapes = { "sphere" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Disrupts natural rhythms and can cause stun and additional spiritual damage over time.",
    },
  },

  plague = {
    name = "Plague",
    abadmin_id = 1101,
    syntax = "EMBED PLAGUE <crystal> AT <target> / RECALL PLAGUE / RETRACT PLAGUE",
    shapes = { "sphere" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Binds virulent vibrations to the air, causing a lingering plague and weakening those in the area.",
    },
  },

  lullaby = {
    name = "Lullaby",
    abadmin_id = 1133,
    syntax = "EMBED LULLABY <crystal> AT <target> / RECALL LULLABY / RETRACT LULLABY",
    shapes = { "egg", "disc" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Creates soporific vibrations that can put those in your location to sleep.",
    },
  },

  retardation = {
    name = "Retardation",
    abadmin_id = 777,
    syntax = "EMBED RETARDATION",
    shapes = { "disc" },
    works_on = "room",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Slows time in the location, giving the aeon effect to everyone in the room, including you.",
      "Will disable any crystalline vibrations in the room with passive effects.",
      "Also affects weapons or projectiles thrown from outside of the vibration's effect.",
    },
  },

  cataclysm = {
    name = "Cataclysm",
    abadmin_id = 778,
    syntax = "EMBED CATACLYSM / IMBUE",
    shapes = { "cylinder", "cube", "diamond", "disc", "egg", "pentagon", "polyhedron", "pyramid", "spiral", "sphere", "torus" },
    works_on = "adventurers",
    cooldown_s = 4.00,
    resource_mana = 300,
    notes = {
      "Two magi must each spin all eleven crystals before one can EMBED the vibration.",
      "A second magi with transcendent Crystalism must IMBUE the vibration with power to complete it.",
      "Functions outdoors only.",
      "After completion, STAFFCAST, FREEZE, or TRANSFIX in Elementalism can be cast through the cataclysm within a five-room radius or line of sight.",
    },
  },
}

--========================================================--
-- Artificing (staff, crystals, elementals)
--========================================================--
M.artificing = {
  staff = {
    name = "Staff",
    abadmin_id = 2040,
    syntax = "ARTIFICE STAFF",
    works_on = "self",
    notes = {
      "Creates a workshop construct staff, used for Artificing crystal attachment.",
      "If you already have a staff, this ability will offer to empower it instead.",
    },
  },

  -- Artificing crystals (attachable to staff)
  crystals = {
    scintilla = {
      name = "Scintilla",
      abadmin_id = 2041,
      syntax = "ARTIFICE SCINTILLA",
      notes = {
        "Creates a scintilla crystal which can be refined and attached to your staff.",
        "Refine: ELEMENTAL REFINE <CRYSTAL> (requires a cut diamond)",
        "Attach: ELEMENTAL ATTACH <CRYSTAL> / Detach: ELEMENTAL DETACH <CRYSTAL>",
      },
    },
    horripilation = {
      name = "Horripilation",
      abadmin_id = 2042,
      syntax = "ARTIFICE HORRIPILATION",
      notes = {
        "Creates a horripilation crystal which can be refined and attached to your staff.",
        "Refine: ELEMENTAL REFINE <CRYSTAL> (requires a cut diamond)",
        "Attach: ELEMENTAL ATTACH <CRYSTAL> / Detach: ELEMENTAL DETACH <CRYSTAL>",
      },
    },
    lightning = {
      name = "Lightning",
      abadmin_id = 2043,
      syntax = "ARTIFICE LIGHTNING",
      notes = {
        "Creates a lightning crystal (refine/attach/detach as above).",
      },
    },
    glacial = {
      name = "Glacial",
      abadmin_id = 2044,
      syntax = "ARTIFICE GLACIAL",
      notes = { "Creates a glacial crystal (refine/attach/detach as above)." },
    },
    shock = {
      name = "Shock",
      abadmin_id = 2045,
      syntax = "ARTIFICE SHOCK",
      notes = { "Creates a shock crystal (refine/attach/detach as above)." },
    },
    immolation = {
      name = "Immolation",
      abadmin_id = 2046,
      syntax = "ARTIFICE IMMOLATION",
      notes = { "Creates an immolation crystal (refine/attach/detach as above)." },
    },
    rapidity = {
      name = "Rapidity",
      abadmin_id = 2047,
      syntax = "ARTIFICE RAPIDITY",
      notes = { "Creates a rapidity crystal (refine/attach/detach as above)." },
    },
  },

  treaties = {
    name = "Treaties",
    abadmin_id = 2048,
    syntax = "ARTIFICE TREATIES",
    notes = {
      "Grants you treaties related to the Elemental Planes.",
      "Treatises allow: ELEMENTAL SUMMON <elemental> (requires a treaty) and ELEMENTAL DISMISS <elemental>.",
      "Elements: air, earth, fire, water.",
    },
  },

  elementals = {
    name = "Elementals",
    abadmin_id = 2049,
    syntax = "ELEMENTAL SUMMON <elemental> / ELEMENTAL DISMISS <elemental>",
    notes = {
      "Summon/dismiss Elementals after obtaining the appropriate treaty.",
    },
  },

  -- Individual elementals (AB entries)
  waterweird = {
    name = "Waterweird",
    abadmin_id = 2050,
    syntax = "ELEMENTAL SPRAY <target>",
    required_reagents = { "a cube of elemental ice" },
    works_on = "adventurers",
    cooldown_s = 2.40,
    resource_mana = 100,
    notes = { "Unleashes a spray of elemental water and ice to damage a target." },
  },

  djinn = {
    name = "Djinn",
    abadmin_id = 2051,
    syntax = "ELEMENTAL MAELSTROM",
    required_reagents = { "a sphere of elemental air" },
    works_on = "room",
    cooldown_s = 3.00,
    resource_mana = 250,
    notes = { "Creates a violent maelstrom of air in your location." },
  },

  sandling = {
    name = "Sandling",
    abadmin_id = 2052,
    syntax = "ELEMENTAL ENTOMB <target> / ELEMENTAL RELEASE <target>",
    required_reagents = { "a block of unworked stone" },
    works_on = "adventurers",
    cooldown_s = 3.60,
    resource_mana = 200,
    notes = {
      "Entombs a target in earth, preventing them from acting for a short time.",
      "Release ends entomb early.",
    },
  },

  efreeti = {
    name = "Efreeti",
    abadmin_id = 2053,
    syntax = "ELEMENTAL INFERNO <target>",
    required_reagents = { "a shard of elemental fire" },
    works_on = "adventurers",
    cooldown_s = 3.60,
    resource_mana = 150,
    notes = { "Calls down a raging inferno upon the target." },
  },

  stoneback = {
    name = "Stoneback",
    abadmin_id = 2054,
    syntax = "ELEMENTAL BULWARK <ME|target>",
    required_reagents = { "a block of unworked stone" },
    works_on = "adventurers and self",
    cooldown_s = 3.60,
    notes = { "Raises a magical shield for yourself or another." },
  },

  breath = {
    name = "Breath",
    abadmin_id = 2056,
    syntax = "ELEMENTAL BREATHMELD <target|STOP>",
    required_reagents = { "a pinch of diamond dust" },
    cooldown_s = 1.00,
    notes = {
      "Links to the target's breath: when they breathe heavily (moving while burdened or laboured breathing), you may teleport to their new location.",
      "Travel is blocked by monolith sigils or if the elemental is slain.",
      "Breathmeld can be performed once every 2 minutes; effect lasts 1 minute on a given target.",
      "STOP aborts the breathmeld but does not clear cooldown.",
    },
  },

  mistfiend = {
    name = "Mistfiend",
    abadmin_id = 2057,
    syntax = "ELEMENTAL CONDENSE / ELEMENTAL FOGBANK",
    required_reagents = { "a cube of elemental ice" },
    cooldown_s = 4.20,
    resource_mana = 300,
    notes = {
      "FOGBANK: disperses magically flooded nearby locations into fog in those rooms.",
      "CONDENSE: turns magical fog into water to flood rooms instead.",
      "May only act once every minute.",
    },
  },

  ashbeast = {
    name = "Ashbeast",
    abadmin_id = 2058,
    syntax = "ELEMENTAL SURGE",
    required_reagents = { "a small supply of charcoals" },
    works_on = "adventurers",
    cooldown_s = 3.60,
    notes = {
      "Surges heat of its flames, annihilating hated-water constructs in your location.",
      "Destroys: icewalls, flood, and frozen ground.",
    },
  },
}

-- convenience getter
function M.get(skillset, key)
  local s = (type(skillset)=="string") and skillset:lower() or skillset
  local k = (type(key)=="string") and key:lower() or key
  if not s or not k then return nil end
  if s == "elementalism" then return M.elementalism[k]
  elseif s == "crystalism" then return M.crystalism[k]
  elseif s == "artificing" then return M.artificing[k]
  end
  return nil
end

--========================================================--
return M
