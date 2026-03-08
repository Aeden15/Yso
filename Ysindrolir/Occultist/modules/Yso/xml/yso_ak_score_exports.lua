--========================================================--
-- Yso_AK_Score_Exports.lua (DROP-IN)
--
-- Purpose:
--   Provide a stable Yso-facing API for AK tracking primitives used by the
--   Occultist offense modules (scores + lists).
--
-- Notes:
--   • Read-only: this does NOT modify AK core logic.
--   • Designed so offense logic can reference Yso.oc.ak.* instead of reaching
--     directly into affstrack.* scattered across code.
--========================================================--

Yso       = Yso       or {}
Yso.oc    = Yso.oc    or {}
Yso.oc.ak = Yso.oc.ak or {}

local B = Yso.oc.ak
B.scores = B.scores or {}
B.lists  = B.lists  or {}

local function _A()
  local A = rawget(_G, "affstrack")
  return (type(A) == "table") and A or nil
end

local function _score(field)
  local A = _A()
  if not A then return 0 end
  return tonumber(A[field] or 0) or 0
end

-- ---- Score getters (AK computes these) ----
function B.scores.kelp()      return _score("kelpscore") end
function B.scores.ginseng()   return _score("ginsengscore") end
function B.scores.golden()    return _score("goldenscore") end
function B.scores.mental()    return _score("mentalscore") end
function B.scores.enlighten() return _score("enlightenscore") end
function B.scores.whisper()   return _score("whisperscore") end
function B.scores.trample()   return _score("tramplescore") end

function B.get_aff_score(aff)
  aff = tostring(aff or ""):lower()
  if aff == "" then return 0 end

  local A = _A()
  if not (A and type(A.score) == "table") then return 0 end

  local row = A.score[aff]
  if type(row) == "number" then
    return tonumber(row) or 0
  end
  if type(row) == "table" then
    return tonumber(row.current or row.score or row.value or 0) or 0
  end

  local alt = A[aff]
  if type(alt) == "table" then
    return tonumber(alt.current or alt.score or alt.value or 0) or 0
  end

  return tonumber(row or 0) or 0
end
-- ---- Lists used by scoreup() (AK owns canonical copy) ----
function B.refresh_lists_from_AK()
  local A = _A()
  if not A then return end
  B.lists.enlightenlist = A.enlightenlist or B.lists.enlightenlist or {}
  B.lists.whisperlist   = A.whisperlist   or B.lists.whisperlist   or {}
  B.lists.mentallist    = A.mentallist    or B.lists.mentallist    or {}
  B.lists.physicallist  = A.physicallist  or B.lists.physicallist  or {}
end

B.refresh_lists_from_AK()

--========================================================--
