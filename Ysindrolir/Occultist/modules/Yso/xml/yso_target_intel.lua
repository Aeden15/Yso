--========================================================--
-- yso_target_intel.lua  (DROP-IN)
-- Purpose:
--   * Central per-target state: mana%, tracked affs, inferred cures, lock flags
--   * Safe to run without Legacy/AK present (they merely call into it)
-- Notes:
--   * Do NOT use a table key named `true` (reserved keyword). This module
--     returns lock flags as: softlock/truelock (and soft/hard aliases).
--========================================================--

Yso     = Yso     or {}
Yso.tgt = Yso.tgt or {}
local T = Yso.tgt

-- ---------- tiny helpers ----------
local function _now()
  return (type(getEpoch) == "function" and getEpoch()) or os.time()
end

local function _key(name)
  name = tostring(name or ""):gsub("^%s+",""):gsub("%s+$","")
  return (name ~= "" and name:lower()) or nil
end

local function _norm(s)
  s = tostring(s or "")
  s = s:gsub("[%.,;:!%?]+$", "")   -- strip trailing punctuation
       :gsub("[%s%-]+","_")        -- collapse spaces/dashes
       :lower()
  return (s ~= "" and s) or nil
end

-- ---------- per-target record ----------
T.state = T.state or {}

function T.get(name)
  local k = _key(name); if not k then return nil end
  local r = T.state[k]
  if not r then
    r = {
      name      = name,
      last_seen = _now(),
      mana_pct  = nil,
      affs      = {},   -- map: aff -> true
      defs      = {},   -- optional: defense flags
      meta      = {},   -- freeform (timestamps, counters, etc.)
    }
    T.state[k] = r
  else
    r.last_seen = _now()
    r.name = name or r.name
  end
  return r
end

function T.drop(name)
  local k = _key(name); if not k then return end
  T.state[k] = nil
end

-- ---------- mana feed ----------
function T.set_mana_pct(name, pct)
  local r = T.get(name); if not r then return end
  pct = tonumber(pct); if not pct then return end
  if pct < 0 then pct = 0 end
  if pct > 100 then pct = 100 end
  r.mana_pct = pct
end

function T.get_mana_pct(name)
  local r = T.get(name)
  return r and r.mana_pct or nil
end

-- ---------- aff tracking helpers ----------
function T.aff_gain(name, aff)
  local r = T.get(name); if not r then return end
  aff = _norm(aff); if not aff then return end
  r.affs[aff] = true
end

function T.aff_cure(name, aff)
  local r = T.get(name); if not r then return end
  aff = _norm(aff); if not aff then return end
  r.affs[aff] = nil
end

function T.has_aff(name, aff)
  local r = T.get(name); if not r then return false end
  aff = _norm(aff); if not aff then return false end
  return r.affs[aff] == true
end

-- ---------- lock evaluation (from Curing Swaps / Legacy) ----------
-- softlock: impatience+asthma+slickness+anorexia and NOT paralysis
-- truelock: impatience+asthma+slickness+anorexia and paralysis
function T.lock_status(name)
  local r = T.get(name)

  -- stable return shape
  local res = { soft = false, hard = false, softlock = false, truelock = false }
  if not r then return res end

  local A = r.affs or {}
  local base = (A.impatience and A.asthma and A.slickness and A.anorexia) and true or false

  local soft = base and not A.paralysis
  local hard = base and (A.paralysis == true)

  res.soft = soft
  res.softlock = soft
  res.hard = hard
  res.truelock = hard
  return res
end

-- ---------- cure inference buckets (from Legacy V2.1 CuringSwaps snippet) ----------
T.cure_map = T.cure_map or {
  kelp       = {"asthma","clumsiness","hypochondria","sensitivity","weariness","healthleech","parasite","rebbies"},
  bloodroot  = {"pyramides","paralysis","slickness"},
  magnesium  = {"pyramides","paralysis","slickness"},
  ginseng    = {"addiction","darkshade","haemophilia","lethargy","nausea","scytherus","flushings"},
  goldenseal = {"dizziness","epilepsy","impatience","shyness","stupidity","depression","shadowmadness","mycalium","sandfever","horror"},
  lobelia    = {"agoraphobia","guilt","spiritburn","tenderskin","claustrophobia","loneliness","masochism","recklessness","vertigo"},
  ash        = {"confusion","dementia","hallucinations","hypersomnia","paranoia"},
  bellwort   = {"retribution","timeloop","peace","justice","lovers"},
  hawthorn   = {"deaf","deafness"},
  calamine   = {"deaf","deafness"},
  bayberry   = {"blind","blindness"},
  arsenic    = {"blind","blindness"},
}

-- Call this when you see: "<target> eats <herb>."
function T.note_target_herb(name, herb)
  local r = T.get(name); if not r then return end
  herb = _norm(herb); if not herb then return end

  local bucket = T.cure_map[herb]
  if not bucket then return end

  -- Remove any tracked affs that are in that bucket.
  for _, aff in ipairs(bucket) do
    if r.affs[aff] then r.affs[aff] = nil end
  end

  r.meta.last_herb = herb
  r.meta.last_herb_at = _now()
end

-- ---------- optional: bridge AK -> Yso.tgt without requiring edits ----------
-- If AK calls Yso.occ.set_target_mana_pct(), keep that working, but also mirror into Yso.tgt.
Yso.occ = Yso.occ or {}

-- prevent double-wrapping on script reload
if not Yso.occ._yso_tgt_mana_wrapped then
  Yso.occ._yso_tgt_mana_wrapped = true
  local prev = Yso.occ.set_target_mana_pct

  Yso.occ.set_target_mana_pct = function(name, pct)
    if type(prev) == "function" then pcall(prev, name, pct) end
    T.set_mana_pct(name, pct)
  end
end
--========================================================--
