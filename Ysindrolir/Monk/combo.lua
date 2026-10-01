--========================================================--
-- Monk combo
--  Caller passes the kick and two punches. This builds the
--  COMBO string and does not send it.
--  left/right is filled only for strikes whose syntax takes it.
--========================================================--

Yso = Yso or {}
Yso.monk = Yso.monk or {}
Yso.monk.combo = Yso.monk.combo or {}

local C = Yso.monk.combo

local LIMB_KEYS = {
  legs = { "leftleg", "rightleg" },
  arms = { "leftarm", "rightarm" },
}

local function _lookup(token)
  local ref = Yso.ref and Yso.ref.monk
  if not ref or type(ref.lookup) ~= "function" then return nil end
  return ref.lookup(token)
end

local function _score(key)
  local scores = rawget(_G, "affstrack")
  scores = scores and scores.score
  if type(scores) ~= "table" then return 0 end
  return tonumber(scores[key]) or 0
end

local function _side(limb_side, override)
  if type(override) == "string" and override ~= "" then
    local side = override:lower()
    if side == "left" or side == "right" then return side end
  end
  local keys = LIMB_KEYS[limb_side]
  if not keys then return nil end
  local best_key, best_score
  for _, key in ipairs(keys) do
    local score = _score(key)
    if score > 0 and score < 200 and (not best_score or score > best_score) then
      best_key = key
      best_score = score
    end
  end
  if not best_key then return "left" end
  if best_key:find("right", 1, true) then return "right" end
  return "left"
end

local function _piece(token, opts)
  local row = _lookup(token)
  if not row then return nil, "unknown_strike" end
  local parts = { row.cmd }
  if row.needs_direction and type(opts.direction) == "string" and opts.direction ~= "" then
    parts[#parts + 1] = tostring(opts.direction):lower()
  end
  if row.limb_side then
    local overrides = type(opts.limbs) == "table" and opts.limbs or {}
    local key = tostring(token or ""):lower()
    parts[#parts + 1] = _side(row.limb_side, overrides[row.cmd] or overrides[key])
  end
  return parts, row
end

local function _append(out, parts)
  for i = 1, #parts do
    out[#out + 1] = parts[i]
  end
end

function C.build(target, opts)
  opts = type(opts) == "table" and opts or {}
  target = tostring(target or opts.target or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if target == "" then return nil, "no_target" end

  local kick_parts, kick = _piece(opts.kick, opts)
  if not kick_parts then return nil, kick or "bad_kick" end
  if kick.role ~= "kick" and kick.role ~= "stance" then
    return nil, "kick_required"
  end

  local p1_parts, p1 = _piece(opts.punch1, opts)
  if not p1_parts then return nil, p1 or "bad_punch1" end
  if p1.role ~= "punch" then return nil, "punch1_required" end

  local p2_parts, p2 = _piece(opts.punch2, opts)
  if not p2_parts then return nil, p2 or "bad_punch2" end
  if p2.role ~= "punch" then return nil, "punch2_required" end

  local out = { "combo", target }
  _append(out, kick_parts)
  _append(out, p1_parts)
  _append(out, p2_parts)

  local already_jpk = kick.cmd == "jpk" or p1.cmd == "jpk" or p2.cmd == "jpk"
  if opts.jpk == true and not already_jpk then
    out[#out + 1] = "jpk"
  end

  return table.concat(out, " ")
end
