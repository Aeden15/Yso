--========================================================--
-- Yso cure buckets
--  * Shared class-agnostic herb/mineral bucket helpers.
--========================================================--

Yso = Yso or {}
Yso.curebuckets = Yso.curebuckets or {}

local C = Yso.curebuckets

C.map = C.map or {
  kelp = { "asthma", "clumsiness", "hypochondria", "sensitivity", "weariness", "healthleech", "parasite", "rebbies" },
  bloodroot = { "pyramides", "paralysis", "slickness" },
  magnesium = { "pyramides", "paralysis", "slickness" },
  ginseng = { "addiction", "darkshade", "haemophilia", "lethargy", "nausea", "scytherus", "flushings" },
  goldenseal = { "dizziness", "epilepsy", "impatience", "shyness", "stupidity", "depression", "shadowmadness", "mycalium", "sandfever", "horror" },
  lobelia = { "agoraphobia", "guilt", "spiritburn", "tenderskin", "claustrophobia", "loneliness", "masochism", "recklessness", "vertigo" },
  ash = { "confusion", "dementia", "hallucinations", "hypersomnia", "paranoia" },
  bellwort = { "retribution", "timeloop", "peace", "justice", "lovers" },
  hawthorn = { "deaf", "deafness" },
  calamine = { "deaf", "deafness" },
  bayberry = { "blind", "blindness" },
  arsenic = { "blind", "blindness" },
}

local function _norm(s)
  s = tostring(s or ""):lower()
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

local function _copy(list)
  local out = {}
  for i = 1, #(list or {}) do out[i] = list[i] end
  return out
end

function C.list(bucket)
  return _copy(C.map[_norm(bucket)] or {})
end

function C.contains(bucket, aff)
  aff = _norm(aff)
  for _, item in ipairs(C.map[_norm(bucket)] or {}) do
    if _norm(item) == aff then return true end
  end
  return false
end

function C.bucket_for(aff)
  aff = _norm(aff)
  if aff == "" then return nil end
  for bucket, list in pairs(C.map) do
    for _, item in ipairs(list) do
      if _norm(item) == aff then return bucket end
    end
  end
  return nil
end

return C
