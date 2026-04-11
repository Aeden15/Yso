-- Auto-exported from Mudlet package script: Yso self curedefs
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso/Curing/self_curedefs.lua
-- Hand-maintained self cure metadata derived from AFFLICTION_CURES.txt.
-- Metadata only (no live state).
--========================================================--

Yso = Yso or {}
Yso.curing = Yso.curing or {}
Yso.curing.defs = Yso.curing.defs or {}

local D = Yso.curing.defs

local KNOWN_BUCKETS = {
  antimony = true,
  bellwort = true,
  bloodroot = true,
  calcite = true,
  caloric = true,
  cinnabar = true,
  clot = true,
  compose = true,
  cuprum = true,
  elm = true,
  epidermal = true,
  ferrum = true,
  ginger = true,
  ginseng = true,
  goldenseal = true,
  immunity = true,
  kelp = true,
  lobelia = true,
  magnesium = true,
  mending = true,
  pear = true,
  plumbum = true,
  pricklyash = true,
  realgar = true,
  restoration = true,
  scrub = true,
  stannum = true,
  valerian = true,
  writhe = true,
}

D.known_buckets = D.known_buckets or KNOWN_BUCKETS
D.validation_errors = D.validation_errors or {}

local function _warn(msg)
  if type(cecho) == "function" then
    cecho(string.format("<gold>[Yso:curedefs] <reset>%s\n", tostring(msg)))
  end
end

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _canon(name)
  if Yso and Yso.selfaff and type(Yso.selfaff.normalize) == "function" then
    return Yso.selfaff.normalize(name)
  end
  local s = tostring(name or ""):lower()
  s = s:gsub("[%.,;:!%?]+$", "")
  s = s:gsub("[_%-]+", " ")
  s = s:gsub("%s+", " ")
  s = _trim(s)
  s = s:gsub("%s+", "")
  return s
end

local function _norm_bucket(v)
  v = tostring(v or ""):lower():gsub("[%s%-_]+", "")
  if v == "" or v == "-" then return nil end
  return v
end

local RAW = {
  { canon = "ablaze", action = "apply", herb = "mending", alchemy = "mending", bucket = "mending", aliases = { "Ablaze" } },
  { canon = "addiction", action = "eat", herb = "ginseng", alchemy = "ferrum", bucket = "ginseng", aliases = { "Addiction" } },
  { canon = "aeon", action = "smoke", herb = "elm", alchemy = "cinnabar", bucket = "elm", aliases = { "Aeon" } },
  { canon = "agoraphobia", action = "eat", herb = "lobelia", alchemy = "argentum", bucket = "lobelia", aliases = { "Agoraphobia" } },
  { canon = "anorexia", action = "apply", herb = "epidermal", alchemy = "epidermal", bucket = "epidermal", aliases = { "Anorexia" } },
  { canon = "asthma", action = "eat", herb = "kelp", alchemy = "aurum", bucket = "kelp", aliases = { "Asthma" } },
  { canon = "bleeding", action = "clot", herb = nil, alchemy = nil, bucket = "clot", aliases = { "Bleeding" } },
  { canon = "blind", action = "apply", herb = "epidermal", alchemy = "epidermal", bucket = "epidermal", aliases = { "Blindness", "blindness" } },
  { canon = "claustrophobia", action = "eat", herb = "lobelia", alchemy = "argentum", bucket = "lobelia", aliases = { "Claustrophobia" } },
  { canon = "clumsiness", action = "eat", herb = "kelp", alchemy = "aurum", bucket = "kelp", aliases = { "Clumsiness" } },
  { canon = "concussion", action = "apply", herb = "restoration", alchemy = "restoration", bucket = "restoration", aliases = { "Concussion" } },
  { canon = "confusion", action = "eat", herb = "pricklyash", alchemy = "stannum", bucket = "pricklyash", aliases = { "Confusion", "Prickly Ash" } },
  { canon = "crippledlimb", action = "apply", herb = "mending", alchemy = "mending", bucket = "mending", aliases = { "Crippled limb" } },
  { canon = "damagedlimb", action = "apply", herb = "restoration", alchemy = "restoration", bucket = "restoration", aliases = { "Damaged limb" } },
  { canon = "darkshade", action = "eat", herb = "ginseng", alchemy = "ferrum", bucket = "ginseng", aliases = { "Darkshade" } },
  { canon = "deadening", action = "smoke", herb = "elm", alchemy = "cinnabar", bucket = "elm", aliases = { "Deadening" } },
  { canon = "deaf", action = "apply", herb = "epidermal", alchemy = "epidermal", bucket = "epidermal", aliases = { "Deafness", "deafness" } },
  { canon = "dementia", action = "eat", herb = "pricklyash", alchemy = "stannum", bucket = "pricklyash", aliases = { "Dementia" } },
  { canon = "disfigurement", action = "smoke", herb = "valerian", alchemy = "realgar", bucket = "valerian", aliases = { "Disfigurement" } },
  { canon = "dissonance", action = "eat", herb = "goldenseal", alchemy = "plumbum", bucket = "goldenseal", aliases = { "Dissonance" } },
  { canon = "dizziness", action = "eat", herb = "goldenseal", alchemy = "plumbum", bucket = "goldenseal", aliases = { "Dizziness" } },
  { canon = "drowning", action = "eat", herb = "pear", alchemy = "calcite", bucket = "pear", aliases = { "Drowning" } },
  { canon = "entangled", action = "writhe", herb = nil, alchemy = nil, bucket = "writhe", aliases = { "Entangled" }, family = "writhe" },
  { canon = "epilepsy", action = "eat", herb = "goldenseal", alchemy = "plumbum", bucket = "goldenseal", aliases = { "Epilepsy" } },
  { canon = "fear", action = "compose", herb = nil, alchemy = nil, bucket = "compose", aliases = { "Fear" } },
  { canon = "freezing", action = "apply", herb = "caloric", alchemy = "caloric", bucket = "caloric", aliases = { "Freezing" } },
  { canon = "generosity", action = "eat", herb = "bellwort", alchemy = "cuprum", bucket = "bellwort", aliases = { "Generosity" } },
  { canon = "hallucinations", action = "eat", herb = "pricklyash", alchemy = "stannum", bucket = "pricklyash", aliases = { "Hallucinations" } },
  { canon = "haemophilia", action = "eat", herb = "ginseng", alchemy = "ferrum", bucket = "ginseng", aliases = { "Haemophilia" } },
  { canon = "healthleech", action = "eat", herb = "kelp", alchemy = "aurum", bucket = "kelp", aliases = { "Health Leech" } },
  { canon = "hellsight", action = "smoke", herb = "valerian", alchemy = "realgar", bucket = "valerian", aliases = { "Hellsight" } },
  { canon = "hypochondria", action = "eat", herb = "kelp", alchemy = "aurum", bucket = "kelp", aliases = { "Hypochondria" } },
  { canon = "hypersomnia", action = "eat", herb = "pricklyash", alchemy = "stannum", bucket = "pricklyash", aliases = { "Hypersomnia" } },
  { canon = "impatience", action = "eat", herb = "goldenseal", alchemy = "plumbum", bucket = "goldenseal", aliases = { "Impatience" } },
  { canon = "indifference", action = "eat", herb = "bellwort", alchemy = "cuprum", bucket = "bellwort", aliases = { "Indifference" } },
  { canon = "internaltrauma", action = "apply", herb = "restoration", alchemy = "restoration", bucket = "restoration", aliases = { "Internal Trauma" } },
  { canon = "justice", action = "eat", herb = "bellwort", alchemy = "cuprum", bucket = "bellwort", aliases = { "Justice" } },
  { canon = "lethargy", action = "eat", herb = "ginseng", alchemy = "ferrum", bucket = "ginseng", aliases = { "Lethargy" } },
  { canon = "loneliness", action = "eat", herb = "lobelia", alchemy = "argentum", bucket = "lobelia", aliases = { "Loneliness" } },
  { canon = "loverseffect", action = "eat", herb = "bellwort", alchemy = "cuprum", bucket = "bellwort", aliases = { "Lover's Effect" } },
  { canon = "masochism", action = "eat", herb = "lobelia", alchemy = "argentum", bucket = "lobelia", aliases = { "Masochism" } },
  { canon = "manaleech", action = "smoke", herb = "valerian", alchemy = "realgar", bucket = "valerian", aliases = { "Mana Leech" } },
  { canon = "mangledlimb", action = "apply", herb = "restoration", alchemy = "restoration", bucket = "restoration", aliases = { "Mangled limb" } },
  { canon = "nausea", action = "eat", herb = "ginseng", alchemy = "ferrum", bucket = "ginseng", aliases = { "Nausea" } },
  { canon = "pacifism", action = "eat", herb = "bellwort", alchemy = "cuprum", bucket = "bellwort", aliases = { "Pacifism" } },
  { canon = "paralysis", action = "eat", herb = "bloodroot", alchemy = "magnesium", bucket = "bloodroot", aliases = { "Paralysis" } },
  { canon = "paranoia", action = "eat", herb = "pricklyash", alchemy = "stannum", bucket = "pricklyash", aliases = { "Paranoia" } },
  { canon = "peace", action = "eat", herb = "bellwort", alchemy = "cuprum", bucket = "bellwort", aliases = { "Peace" } },
  { canon = "recklessness", action = "eat", herb = "lobelia", alchemy = "argentum", bucket = "lobelia", aliases = { "Recklessness" } },
  { canon = "scytherus", action = "eat", herb = "ginseng", alchemy = "ferrum", bucket = "ginseng", aliases = { "Scytherus" } },
  { canon = "sensitivity", action = "eat", herb = "kelp", alchemy = "aurum", bucket = "kelp", aliases = { "Sensitivity", "prefarar" } },
  { canon = "shyness", action = "eat", herb = "goldenseal", alchemy = "plumbum", bucket = "goldenseal", aliases = { "Shyness" } },
  { canon = "slickness", action = "smoke", herb = "valerian", alchemy = "realgar", bucket = "valerian", aliases = { "Slickness" }, family = "dual", alternatives = {
    { action = "eat", herb = "bloodroot", alchemy = "magnesium", bucket = "bloodroot" },
  } },
  { canon = "stinky", action = "scrub", herb = nil, alchemy = nil, bucket = "scrub", aliases = { "Stinky" } },
  { canon = "stupidity", action = "eat", herb = "goldenseal", alchemy = "plumbum", bucket = "goldenseal", aliases = { "Stupidity" } },
  { canon = "stuttering", action = "apply", herb = "epidermal", alchemy = "epidermal", bucket = "epidermal", aliases = { "Stuttering" } },
  { canon = "temperedhumours", action = "eat", herb = "ginger", alchemy = "antimony", bucket = "ginger", aliases = { "Tempered Humours" } },
  { canon = "transfixed", action = "writhe", herb = nil, alchemy = nil, bucket = "writhe", aliases = { "Transfixed" }, family = "writhe" },
  { canon = "vertigo", action = "eat", herb = "lobelia", alchemy = "argentum", bucket = "lobelia", aliases = { "Vertigo" } },
  { canon = "voyria", action = "sip", herb = "immunity", alchemy = "immunity", bucket = "immunity", aliases = { "Voyria" } },
  { canon = "weariness", action = "eat", herb = "kelp", alchemy = "aurum", bucket = "kelp", aliases = { "Weariness" } },
  { canon = "webbed", action = "writhe", herb = nil, alchemy = nil, bucket = "writhe", aliases = { "Webbed" }, family = "writhe" },
}

D.by_aff = D.by_aff or {}
D.by_bucket = D.by_bucket or {}
D.alias_to_canon = D.alias_to_canon or {}

local function _index_row(row)
  local canon = _canon(row.canon)
  if canon == "" then return end

  local copy = {
    canon = canon,
    action = (function()
      local a = _trim(row.action)
      if a == "" then return nil end
      return a:lower()
    end)(),
    herb = row.herb and _norm_bucket(row.herb) or nil,
    alchemy = row.alchemy and _norm_bucket(row.alchemy) or nil,
    bucket = _norm_bucket(row.bucket or row.herb or row.alchemy),
    aliases = {},
    family = row.family,
    alternatives = {},
  }

  if type(row.aliases) == "table" then
    for i = 1, #row.aliases do
      local a = _canon(row.aliases[i])
      if a ~= "" then
        copy.aliases[#copy.aliases + 1] = a
      end
    end
  end

  if type(row.alternatives) == "table" then
    for i = 1, #row.alternatives do
      local alt = row.alternatives[i]
      if type(alt) == "table" then
        copy.alternatives[#copy.alternatives + 1] = {
          action = (alt.action and _trim(alt.action) ~= "") and tostring(alt.action):lower() or nil,
          herb = alt.herb and _norm_bucket(alt.herb) or nil,
          alchemy = alt.alchemy and _norm_bucket(alt.alchemy) or nil,
          bucket = _norm_bucket(alt.bucket or alt.herb or alt.alchemy),
        }
      end
    end
  end

  if copy.bucket and not D.known_buckets[copy.bucket] then
    D.validation_errors[#D.validation_errors + 1] =
      string.format("invalid bucket '%s' for %s", tostring(copy.bucket), canon)
  end

  for i = 1, #copy.alternatives do
    local alt = copy.alternatives[i]
    if alt.bucket and not D.known_buckets[alt.bucket] then
      D.validation_errors[#D.validation_errors + 1] =
        string.format("invalid alt bucket '%s' for %s", tostring(alt.bucket), canon)
    end
  end

  D.by_aff[canon] = copy
  D.alias_to_canon[canon] = canon
  for i = 1, #copy.aliases do
    D.alias_to_canon[copy.aliases[i]] = canon
  end

  if copy.bucket then
    D.by_bucket[copy.bucket] = D.by_bucket[copy.bucket] or {}
    D.by_bucket[copy.bucket][canon] = true
  end
end

function D.rebuild()
  D.by_aff = {}
  D.by_bucket = {}
  D.alias_to_canon = {}
  D.validation_errors = {}
  for i = 1, #RAW do
    _index_row(RAW[i])
  end
  if #D.validation_errors > 0 then
    _warn("bucket validation found " .. tostring(#D.validation_errors) .. " issue(s)")
  end
end

function D.validate()
  return (#(D.validation_errors or {})) == 0, D.validation_errors or {}
end

function D.canon(name)
  local c = _canon(name)
  if c == "" then return "" end
  return D.alias_to_canon[c] or c
end

function D.get(name)
  local c = D.canon(name)
  if c == "" then return nil end
  return D.by_aff[c]
end

function D.bucket_for(name)
  local row = D.get(name)
  return row and row.bucket or nil
end

function D.action_for(name)
  local row = D.get(name)
  return row and row.action or nil
end

function D.affs_in_bucket(bucket)
  local key = _norm_bucket(bucket)
  local set = key and D.by_bucket[key] or nil
  local out = {}
  if type(set) == "table" then
    for aff in pairs(set) do
      out[#out + 1] = aff
    end
    table.sort(out)
  end
  return out
end

D.rebuild()

return D
