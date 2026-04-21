--========================================================--
-- Yso_Occultist_Affmap.lua  (DROP-IN)  [UPDATED]
-- Skill → affliction/effect map for Occultism / Tarot / Domination
-- Notes:
--   • “affs” are canonical keys you should track.
--   • AK limb state is tracked as: leftarm/rightarm/leftleg/rightleg (tiered 100/200/300),
--     NOT left_arm_broken style keys.
--========================================================--

Yso        = Yso        or {}
Yso.oc     = Yso.oc     or {}
Yso.oc.map = Yso.oc.map or {}

local M = Yso.oc.map

M.skills = M.skills or {
  occultism = {
    instill = {
      affs  = { "asthma", "clumsiness", "healthleech", "sensitivity", "slickness", "paralysis", "darkshade" },
      notes = "Selectable: INSTILL <tgt> WITH <affliction>.",
    },

    -- SHRIVEL (direct limb pressure; AK tracks limb state as leftarm/rightarm/leftleg/rightleg tiers)
    shrivel = {
      affs    = { "leftarm", "rightarm", "leftleg", "rightleg" },
      effects = { "limb_damage" },
      notes   = "SHRIVEL <left/right> <arm/leg> <tgt> (EQ). Progresses limb state; AK models limbs as tiered scores.",
    },

    whisperingmadness = {
      affs  = { "whisperingmadness" },
      notes = "Requires at least one insanity from the WHISPERINGMADNESS eligibility list.",
    },

    truename_utter = {
      affs  = { "aeon" },
      notes = "UTTER TRUENAME <tgt> applies aeon (separate source from tarot AEON).",
    },

    chaosrays = {
      affs  = { "random_ray" },
      observations = {
        { color = "red", line = "You are hit by a red ray.", confirmed_effect = "damage", damage_type = "fire", confidence = "confirmed", notes = "Confirmed seed entry from conquest logs." },
        { color = "blue", line = nil, confirmed_effect = nil, damage_type = nil, confidence = "pending", notes = "Observation hook only; effect not yet confirmed." },
        { color = "orange", line = nil, confirmed_effect = nil, damage_type = nil, confidence = "pending", notes = "Observation hook only; effect not yet confirmed." },
        { color = "yellow", line = nil, confirmed_effect = nil, damage_type = nil, confidence = "pending", notes = "Observation hook only; effect not yet confirmed." },
        { color = "green", line = nil, confirmed_effect = nil, damage_type = nil, confidence = "pending", notes = "Observation hook only; effect not yet confirmed." },
        { color = "indigo", line = nil, confirmed_effect = nil, damage_type = nil, confidence = "pending", notes = "Observation hook only; effect not yet confirmed." },
        { color = "violet", line = nil, confirmed_effect = nil, damage_type = nil, confidence = "pending", notes = "Observation hook only; effect not yet confirmed." },
      },
      notes = "Seven Rays: random ray effects to everyone in-room except caster.",
    },

    bodywarp = {
      effects = { "limb_damage" },
      notes   = "BODYWARP can optionally combine one of: ague / shrivel / regress (lesser works).",
    },

    regress = {
      effects = { "prone_target" },
      affs    = { "anorexia" },
      notes   = "REGRESS <tgt> (EQ). If target is not prone, prones them. If already prone, applies anorexia.",
    },

    compel_discord = {
      reqs  = { "healthleech", "asthma" },
      affs  = { "loneliness", "dizziness" },
      notes = "COMPEL Discord result.",
    },

    compel_entropy = {
      reqs    = { "haemophilia", "addiction" },
      effects = { "strip_speed_if_present" },
      affs    = { "aeon_if_no_speed" },
      notes   = "COMPEL Entropy result.",
    },

    compel_potential = {
      reqs    = { "frozen_or_4broken" },
      affs    = { "blackout_if_4broken" },
      effects = { "damage_if_frozen" },
      notes   = "COMPEL Potential result.",
    },

    ague = {
      affs  = { "frozen" },
      notes = "Ague is the frozen line (terminal key frozen).",
    },
  },

  tarot = {
    moon = {
      affs  = { "stupidity", "epilepsy", "confusion", "hallucinations", "claustrophobia", "agoraphobia", "masochism", "hypersomnia" },
      notes = "Moon supports directed affliction selection; offense uses Moon for specific affs.",
    },

    aeon = {
      affs  = { "aeon" },
      notes = "Tarot AEON card fling source.",
    },

    lovers = {
      affs  = { "lovers" },
      notes = "In-love state.",
    },

    ruinate_lovers = {
      affs  = { "manaleech" },
      notes = "RUINATE LOVERS <tgt> (BAL). Primary manaleech source for mana route.",
    },

    ruinate_justice = {
      effects = { "convert_affs_to_limb_progress", "frozen_if_threshold", "prone_if_both_legs_progressed" },
      affs    = { "leftarm", "rightarm", "leftleg", "rightleg" },
      notes   = "RUINATE JUSTICE <tgt> (BAL). AK/Legacy treat Justice as limb progress conversion; use AK limb keys.",
    },

    ruinate_wheel = {
      spins = {
        [1] = { affs = { "frozen" } },
        [2] = { affs = { "stuttering" } },
        [3] = { affs = { "blackout" } },
        [4] = { affs = { "UNKNOWN" } },
        [5] = { affs = { "UNKNOWN" } },
        [6] = { affs = { "UNKNOWN" } },
        [7] = { affs = { "aeon" }, effects = { "strip_speed_all" } },
      },
      notes = "Per your report: 7 spins => aeon + strips speed to all. 4–6 TBD.",
    },
  },

  domination = {
    bubonis = {
      affs      = { "asthma" },
      followups = { asthma = { "slickness" } },
      notes     = "Entity. If target already has asthma, Bubonis follow-up applies slickness.",
    },

    danaeus_storm = {
      affs  = { "clumsiness" },
      notes = "Entity. Syntax: COMMAND STORM AT <tgt>.",
    },

    nemesis_humbug = {
      affs  = { "addiction" },
      notes = "Entity. Humbug curse => addiction.",
    },

    scrag_bloodleech = {
      affs  = { "haemophilia" },
      notes = "Entity. Bloodleech => haemophilia.",
    },

    palpatar_worm = {
      affs  = { "healthleech" },
      prime = { affs = { "nausea" } },
      notes = "Entity. Worm => healthleech; primebond may add nausea.",
    },

    lycantha_hound = {
      affs  = { "weariness" },
      notes = "Entity. Hound => weariness.",
    },

    -- CRONE (Hecate) limb pressure (AK limb keys)
    hecate_crone = {
      affs    = { "leftarm", "rightarm", "leftleg", "rightleg" },
      effects = { "limb_damage" },
      notes   = "Entity. COMMAND CRONE AT <tgt> <left/right> <arm/leg>. Use with SHRIVEL for guaranteed limb progress.",
    },

    eerion_gremlin_prime = {
      affs    = { "dizziness" },
      effects = { "knock_off_balance_if_already_dizzy" },
      notes   = "Entity primebond => dizziness and can off-balance.",
    },

    pyradius_firelord = {
      converts = {
        whisperingmadness = "recklessness",
        manaleech         = "anorexia",
      },
      effects = { "healthleech_becomes_psychic_damage" },
      notes   = "Firelord conversions: manaleech -> anorexia (avoid if you do NOT want to convert manaleech).",
    },
  },
}

function M.rebuild_by_aff()
  M.by_aff = {}

  local function add(aff, src)
    if not aff or aff == "" then return end
    M.by_aff[aff] = M.by_aff[aff] or {}
    M.by_aff[aff][src] = true
  end

  for school, abilities in pairs(M.skills) do
    for key, node in pairs(abilities) do
      local src = school .. "." .. key

      if node.affs then
        for _, a in ipairs(node.affs) do add(a, src) end
      end

      if key == "ruinate_wheel" and node.spins then
        for spin, s in pairs(node.spins) do
          if s.affs then
            for _, a in ipairs(s.affs) do add(a, src .. ".spin" .. tostring(spin)) end
          end
        end
      end

      if node.converts then
        for from, to in pairs(node.converts) do
          add(to, src .. ".convert(" .. from .. ")")
        end
      end

      if node.followups and node.followups.asthma then
        for _, a in ipairs(node.followups.asthma) do
          add(a, src .. ".followup(asthma)")
        end
      end

      if node.prime and node.prime.affs then
        for _, a in ipairs(node.prime.affs) do
          add(a, src .. ".prime")
        end
      end
    end
  end
end

M.rebuild_by_aff()
--========================================================--

return M
