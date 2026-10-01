--========================================================--
-- Monk stance
--  Stance words from charstats: None, Dragon, Horse, and the
--  other Tekura stance names on Yso.ref.monk.stances.
--  GMCP is the source of truth. Enter and leave lines are not parsed.
--========================================================--

Yso = Yso or {}
Yso.monk = Yso.monk or {}
Yso.monk.stance = Yso.monk.stance or {}

local S = Yso.monk.stance

S.current = S.current
S.word = S.word or "none"

local function _ref()
  local ref = Yso.ref and Yso.ref.monk
  if type(ref) ~= "table" then return nil end
  return ref
end

function S.set(word)
  word = tostring(word or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if word == "" or word == "none" then
    S.word = "none"
    S.current = nil
    return nil
  end
  local ref = _ref()
  local row = ref and type(ref.stance_by_word) == "function" and ref.stance_by_word(word) or nil
  if not row and ref and type(ref.stances) == "table" then
    row = ref.stances[word]
  end
  if not row then
    S.word = word
    S.current = nil
    return nil
  end
  S.word = row.key or word
  S.current = row
  return row
end

function S.apply_charstats(list)
  if type(list) ~= "table" then return S.current end
  for _, entry in ipairs(list) do
    local label, value = tostring(entry or ""):match("^(.-):%s*(.*)$")
    if label and label:gsub("^%s+", ""):gsub("%s+$", ""):lower() == "stance" then
      value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
      return S.set(value)
    end
  end
  return S.current
end

local function _on_vitals()
  local g = rawget(_G, "gmcp")
  local stats = g and g.Char and g.Char.Vitals and g.Char.Vitals.charstats
  S.apply_charstats(stats)
end

if type(registerAnonymousEventHandler) == "function" and not S._eh then
  S._eh = registerAnonymousEventHandler("gmcp.Char.Vitals", _on_vitals)
end
