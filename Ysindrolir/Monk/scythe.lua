--========================================================--
-- Monk scythe
--  MIND SCYTHE has no target argument.
--  Gate: mangled head (affstrack.score.head >= 200) and at least
--  two of stupidity, impatience, dizziness, epilepsy, confusion.
--========================================================--

Yso = Yso or {}
Yso.monk = Yso.monk or {}
Yso.monk.scythe = Yso.monk.scythe or {}

local S = Yso.monk.scythe

local FALLBACK_POOL = { "stupidity", "impatience", "dizziness", "epilepsy", "confusion" }

local function _entry()
  local ref = Yso.ref and Yso.ref.monk
  local row = ref and ref.telepathy and ref.telepathy.scythe
  if type(row) == "table" then return row end
  return nil
end

local function _pool()
  local row = _entry()
  local pool = row and row.mental_pool
  if type(pool) == "table" and #pool > 0 then return pool end
  return FALLBACK_POOL
end

local function _min_count()
  local row = _entry()
  return tonumber(row and row.mental_pool_min) or 2
end

local function _resolve_target(target)
  target = tostring(target or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if target ~= "" then return target end
  if Yso and type(Yso.get_target) == "function" then
    local ok, who = pcall(Yso.get_target)
    if ok then
      who = tostring(who or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if who ~= "" then return who end
    end
  end
  local g = rawget(_G, "target")
  if type(g) == "string" and g ~= "" then return g end
  return ""
end

local function _has_aff(name)
  if Yso and Yso.ak and type(Yso.ak.has) == "function" then
    local ok, v = pcall(Yso.ak.has, name)
    if ok and v == true then return true end
    if ok then return false end
  end
  local scores = rawget(_G, "affstrack")
  scores = scores and scores.score
  if type(scores) ~= "table" then return false end
  return (tonumber(scores[name]) or 0) >= 100
end

local function _mangled_head()
  local scores = rawget(_G, "affstrack")
  scores = scores and scores.score
  if type(scores) ~= "table" then return false end
  return (tonumber(scores.head) or 0) >= 200
end

function S.ready(target)
  if _resolve_target(target) == "" then return false end
  if not _mangled_head() then return false end
  local seen = {}
  local count = 0
  for _, name in ipairs(_pool()) do
    name = tostring(name or ""):lower()
    if name ~= "" and not seen[name] and _has_aff(name) then
      seen[name] = true
      count = count + 1
    end
  end
  return count >= _min_count()
end

function S.execute(target)
  if not S.ready(target) then return false end
  if type(send) ~= "function" then return false end
  send("mind scythe")
  return true
end
