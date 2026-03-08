-- Auto-exported from Mudlet package script: Curebuckets
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso_Occultist_CureBuckets.lua (DROP-IN)
-- Purpose:
--   Build an Occultist-only affliction list from Yso.oc.map (Affmap),
--   then map each affliction to AK cure buckets/actions where possible.
--
-- Why:
--   • Lets you query "what bucket cures X?"
--   • Lets you use AK stack scores like affstrack.kelpscore / ginsengscore
--     while staying scoped to Occultist-kit afflictions.
--
-- Requirements:
--   • Load AFTER:
--       - AK Opponent Tracking (affstrack tables/scores)
--       - Yso_Occultist_Affmap.lua (Yso.oc.map.skills)
--
-- Notes:
--   • AK provides:
--       - affstrack.eaten  (item -> aff list)
--       - affstrack.applied(part -> aff list)
--       - affstrack.smoked / treed / focused (aff lists)
--       - affstrack.kelpscore / ginsengscore / goldenscore / mentalscore /
--         enlightenscore / whisperscore / tramplescore
--   • This module does NOT use pyradiusscore in logic (per your request),
--     but you can still query it directly from AK if you want.
--========================================================--

Yso = Yso or {}
Yso.oc = Yso.oc or {}

local C = Yso.oc.cures or {}
Yso.oc.cures = C

C.cfg = C.cfg or {
  enabled = true,
  debug = false,
}

local function _echo(s)
  if C.cfg.debug then cecho("<gray>[Yso.oc.cures] " .. s .. "\n") end
end

local function _is_array(t)
  return type(t) == "table" and (t[1] ~= nil)
end

local function _addset(set, v)
  if v and v ~= "" then set[v] = true end
end

local function _tolist(set)
  local out = {}
  for k in pairs(set or {}) do out[#out+1] = k end
  table.sort(out)
  return out
end

local function _set_has(set, v) return set and v and set[v] == true end

-- ---------- Pull Occultist-only aff list from Affmap ----------
local function collect_occultist_affs()
  local out = {}
  local Map = Yso.oc and Yso.oc.map

  if not (Map and Map.skills) then
    return out -- empty set
  end

  local function add_aff(a) _addset(out, a) end

  for school, abilities in pairs(Map.skills) do
    if type(abilities) == "table" then
      for abil, node in pairs(abilities) do
        if type(node) == "table" then
          if _is_array(node.affs) then
            for _, a in ipairs(node.affs) do add_aff(a) end
          end
          if type(node.followups) == "table" then
            for _, lst in pairs(node.followups) do
              if _is_array(lst) then
                for _, a in ipairs(lst) do add_aff(a) end
              end
            end
          end
          if type(node.converts) == "table" then
            for _, to in pairs(node.converts) do add_aff(to) end
          end
          if type(node.prime) == "table" and _is_array(node.prime.affs) then
            for _, a in ipairs(node.prime.affs) do add_aff(a) end
          end
          if type(node.spins) == "table" then
            for _, spin in pairs(node.spins) do
              if type(spin) == "table" and _is_array(spin.affs) then
                for _, a in ipairs(spin.affs) do add_aff(a) end
              end
            end
          end
        end
      end
    end
  end

  return out
end

-- ---------- Invert AK mappings into per-aff buckets ----------
local ITEM_BUCKET = {
  ["piece of kelp"]        = "kelp",
  ["aurum flake"]          = "kelp",

  ["ginseng root"]         = "ginseng",
  ["ferrum flake"]         = "ginseng",

  ["goldenseal root"]      = "goldenseal",
  ["plumbum flake"]        = "goldenseal",

  ["prickly ash bark"]     = "pricklyash",
  ["stannum flake"]        = "pricklyash",

  ["lobelia seed"]         = "lobelia",
  ["argentum flake"]       = "lobelia",

  ["bellwort flower"]      = "bellwort",
  ["cuprum flake"]         = "bellwort",

  ["hawthorn berry"]       = "hawthorn",
  ["calamine crystal"]     = "hawthorn",

  ["bayberry bark"]        = "bayberry",
  ["arsenic pellet"]       = "bayberry",
}

-- Smoke herb specificity is not fully expressed in AK’s smoked list; for Occultist-kit
-- affs, we provide a conservative “best-known” map (you can edit freely).
local SMOKE_HERB_BY_AFF = {
  aeon      = "elm",
  deadening = "elm",

  manaleech = "valerian",
  hellsight = "valerian",
  slickness = "valerian",
}

local function build_from_ak(occ_affs_set)
  local A = rawget(_G, "affstrack")
  if type(A) ~= "table" then
    _echo("AK affstrack not found; building Occultist list only (no bucket mapping yet).")
    return {
      by_aff = {},
      by_bucket = { eat = {}, smoke = {}, focus = {}, tree = {}, apply = {} },
      occ_affs = occ_affs_set or {},
      ak = nil,
    }
  end

  local eaten = A.eaten or {}
  local applied = A.applied or {}
  local smoked = A.smoked or {}
  local focused = A.focused or {}
  local treed = A.treed or {}

  -- Convert smoked/focused/treed arrays into sets
  local smoked_set, focused_set, treed_set = {}, {}, {}
  if _is_array(smoked) then for _,a in ipairs(smoked) do smoked_set[a]=true end end
  if _is_array(focused) then for _,a in ipairs(focused) do focused_set[a]=true end end
  if _is_array(treed) then for _,a in ipairs(treed) do treed_set[a]=true end end

  local by_aff = {}
  local by_bucket = { eat = {}, smoke = {}, focus = {}, tree = {}, apply = {} }

  local function ensure_aff(aff)
    by_aff[aff] = by_aff[aff] or {
      eat = { buckets = {}, items = {} },
      smoke = { ok = false, herb = nil },
      focus = false,
      tree  = false,
      apply = { parts = {} },
    }
    return by_aff[aff]
  end

  local function push_bucket(map, bucket, aff)
    if not bucket or bucket == "" then return end
    map[bucket] = map[bucket] or {}
    map[bucket][aff] = true
  end

  -- EATEN: invert item->affs into aff->items + bucket(s)
  for item, affs in pairs(eaten) do
    if _is_array(affs) then
      local bucket = ITEM_BUCKET[item]
      for _, aff in ipairs(affs) do
        if _set_has(occ_affs_set, aff) then
          local e = ensure_aff(aff)
          e.eat.items[item] = true
          if bucket then
            e.eat.buckets[bucket] = true
            push_bucket(by_bucket.eat, bucket, aff)
          end
        end
      end
    end
  end

  -- SMOKED/FOCUSED/TREED flags (AK lists)
  for aff in pairs(occ_affs_set or {}) do
    local e = ensure_aff(aff)

    if smoked_set[aff] then
      e.smoke.ok = true
      e.smoke.herb = SMOKE_HERB_BY_AFF[aff] -- may be nil; that’s fine
      by_bucket.smoke[aff] = true
    end

    if focused_set[aff] then
      e.focus = true
      by_bucket.focus[aff] = true
    end

    if treed_set[aff] then
      e.tree = true
      by_bucket.tree[aff] = true
    end
  end

  -- APPLIED: part -> aff list
  for part, affs in pairs(applied) do
    if _is_array(affs) then
      for _, aff in ipairs(affs) do
        if _set_has(occ_affs_set, aff) then
          local e = ensure_aff(aff)
          e.apply.parts[part] = true
          by_bucket.apply[part] = by_bucket.apply[part] or {}
          by_bucket.apply[part][aff] = true
        end
      end
    end
  end

  return {
    by_aff = by_aff,
    by_bucket = by_bucket,
    occ_affs = occ_affs_set or {},
    ak = A,
  }
end

-- ---------- Public API ----------
function C.rebuild()
  if not C.cfg.enabled then return end

  local occ_affs_set = collect_occultist_affs()
  C._occ_affs = occ_affs_set

  local pack = build_from_ak(occ_affs_set)
  C.by_aff = pack.by_aff
  C.by_bucket = pack.by_bucket
  C.ak = pack.ak

  _echo(("rebuilt: %d occultist affs; ak=%s"):format(
    (function() local n=0; for _ in pairs(occ_affs_set) do n=n+1 end; return n end)(),
    (C.ak and "yes" or "no")
  ))
end

-- Query: which buckets/actions cure this aff?
function C.get(aff)
  return (C.by_aff and C.by_aff[aff]) or nil
end

-- Query: Occultist-only affs that belong to a given EAT bucket (kelp/ginseng/...)
function C.affs_in_eat_bucket(bucket)
  local s = C.by_bucket and C.by_bucket.eat and C.by_bucket.eat[bucket]
  return _tolist(s)
end

-- Query: AK stack score wrappers (only the ones AK defines; no pyradius use here)
function C.bucket_score(name)
  local A = C.ak or rawget(_G, "affstrack")
  if type(A) ~= "table" then return 0 end

  if name == "kelp" then return tonumber(A.kelpscore or 0) or 0 end
  if name == "ginseng" then return tonumber(A.ginsengscore or 0) or 0 end
  if name == "goldenseal" then return tonumber(A.goldenscore or 0) or 0 end
  if name == "mental" then return tonumber(A.mentalscore or 0) or 0 end
  if name == "enlighten" then return tonumber(A.enlightenscore or 0) or 0 end
  if name == "whisper" then return tonumber(A.whisperscore or 0) or 0 end
  if name == "trample" then return tonumber(A.tramplescore or 0) or 0 end

  return 0
end

-- Convenience: count how many Occultist-kit affs are currently in a bucket (via AK score)
-- Example use: if Yso.oc.cures.bucket_score("kelp") >= 4 then ...
function C.kelp_score() return C.bucket_score("kelp") end
function C.ginseng_score() return C.bucket_score("ginseng") end
function C.golden_score() return C.bucket_score("goldenseal") end

-- Debug dump (prints a compact per-aff summary)
function C.dump()
  if not C.by_aff then cecho("[Yso.oc.cures] no data\n"); return end
  local keys = {}
  for aff in pairs(C.by_aff) do keys[#keys+1]=aff end
  table.sort(keys)
  for _, aff in ipairs(keys) do
    local e = C.by_aff[aff]
    local eatb = _tolist(e.eat.buckets)
    local smoke = e.smoke.ok and ("smoke"..(e.smoke.herb and (":"..e.smoke.herb) or "")) or ""
    local focus = e.focus and "focus" or ""
    local tree = e.tree and "tree" or ""
    local parts = _tolist(e.apply.parts)
    cecho(string.format("<gray>[cures] %-18s  eat={%s}  %s %s %s  apply_parts={%s}\n",
      aff,
      table.concat(eatb, ","),
      smoke, focus, tree,
      table.concat(parts, ",")
    ))
  end
end

-- Build now; if Affmap/AK aren’t loaded yet, you can call Yso.oc.cures.rebuild() later.
C.rebuild()
--========================================================--
