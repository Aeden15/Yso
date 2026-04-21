Yso = Yso or {}
Yso.bal = Yso.bal or {}
Yso.alc = Yso.alc or {}
Yso.alc.phys = Yso.alc.phys or {}

Yso.bal.humour = Yso.bal.humour ~= false
Yso.bal.evaluate = Yso.bal.evaluate ~= false
Yso.bal.homunculus = Yso.bal.homunculus ~= false

local P = Yso.alc.phys

P.state = P.state or {}
P.targets = P.targets or {}
P.humours = P.humours or { "choleric", "melancholic", "phlegmatic", "sanguine" }
P.aff_to_humour = P.aff_to_humour or {
  paralysis = "sanguine",
  nausea = "choleric",
  sensitivity = "choleric",
  haemophilia = "sanguine",
}
P.humour_to_affs = P.humour_to_affs or {
  choleric = { "nausea", "sensitivity" },
  sanguine = { "haemophilia", "paralysis" },
}
P.giving_default = P.giving_default or {
  "paralysis",
  "nausea",
  "sensitivity",
  "haemophilia",
}
P.state.evaluate = P.state.evaluate or {
  target = "",
  active = false,
  requested_at = 0,
  started_at = 0,
}
P.state.corruption = P.state.corruption or {}

local function _now()
  local t = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  if t and t > 1000000000000 then
    t = t / 1000
  end
  return t or os.time()
end

local function _echo(msg)
  local text = string.format("[Yso:Alchemist] %s", tostring(msg or ""))
  if type(cecho) == "function" then
    cecho("\n<orange>" .. text .. "\n")
    return
  end
  if type(echo) == "function" then
    echo("\n" .. text .. "\n")
    return
  end
  if type(print) == "function" then
    print(text)
  end
end

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _lc(s)
  return _trim(s):lower()
end

local function _target_key(name)
  local key = _lc(name)
  return key ~= "" and key or nil
end

local function _current_target()
  if type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok and _trim(v) ~= "" then
      return _trim(v)
    end
  end
  if type(Yso.target) == "string" and _trim(Yso.target) ~= "" then
    return _trim(Yso.target)
  end
  local tgt = rawget(_G, "target")
  if type(tgt) == "string" and _trim(tgt) ~= "" then
    return _trim(tgt)
  end
  return ""
end

local function _has_aff(aff)
  aff = _lc(aff)
  if aff == "" then
    return false
  end

  local A = rawget(_G, "affstrack")
  if type(A) == "table" then
    if type(A.score) == "table" and tonumber(A.score[aff]) then
      return tonumber(A.score[aff]) >= 100
    end
    local row = A[aff]
    if type(row) == "table" and tonumber(row.score) then
      return tonumber(row.score) >= 100
    end
  end

  if Yso and Yso.tgt and type(Yso.tgt.has_aff) == "function" then
    local ok, v = pcall(Yso.tgt.has_aff, _current_target(), aff)
    if ok and v == true then
      return true
    end
  end

  return false
end

local function _humour_row(target_row, humour)
  humour = _lc(humour)
  if humour == "" then
    return nil
  end

  target_row.humours = target_row.humours or {}
  local row = target_row.humours[humour]
  if row then
    return row
  end

  row = {
    name = humour,
    inferred_count = 0,
    steady_count = nil,
    known = false,
    tempered = false,
    last_tempered_at = 0,
    last_wracked_at = 0,
    last_evaluated_at = 0,
    eval_dirty = true,
  }
  target_row.humours[humour] = row
  return row
end

local function _sync_tempered(row)
  local inferred = tonumber(row.inferred_count or 0) or 0
  local steady = tonumber(row.steady_count or 0) or 0
  row.tempered = (inferred > 0) or (steady > 0)
  return row.tempered
end

local function _target_row(name)
  local key = _target_key(name)
  if not key then
    return nil
  end

  local row = P.targets[key]
  if row then
    row.name = _trim(name)
    row.last_seen_at = _now()
    return row
  end

  row = {
    name = _trim(name),
    key = key,
    created_at = _now(),
    last_seen_at = _now(),
    last_evaluated_at = 0,
    last_wrack_at = 0,
    eval_dirty = true,
    humours = {},
    vitals = {
      health_pct = nil,
      mana_pct = nil,
      last_evaluated_at = 0,
    },
  }

  for i = 1, #P.humours do
    _humour_row(row, P.humours[i])
  end

  P.targets[key] = row
  return row
end

function Yso.giving(list)
  local out = {}
  if type(list) ~= "table" then
    return out
  end
  for i = 1, #list do
    local aff = _lc(list[i])
    if aff ~= "" then
      out[#out + 1] = aff
    end
  end
  P.giving_default = out
  return out
end

function Yso.alc.set_humour_ready(ready, source)
  Yso.bal.humour = ready and true or false
  P.state.last_humour_source = source or "unknown"
  P.state.last_humour_change = _now()
  return Yso.bal.humour
end

function Yso.alc.humour_ready()
  return Yso.bal.humour ~= false
end

function Yso.alc.set_evaluate_ready(ready, source)
  Yso.bal.evaluate = ready and true or false
  P.state.last_evaluate_source = source or "unknown"
  P.state.last_evaluate_change = _now()
  return Yso.bal.evaluate
end

function Yso.alc.evaluate_ready()
  return Yso.bal.evaluate ~= false
end

function Yso.alc.set_homunculus_ready(ready, source)
  Yso.bal.homunculus = ready and true or false
  P.state.last_homunculus_source = source or "unknown"
  P.state.last_homunculus_change = _now()
  return Yso.bal.homunculus
end

function Yso.alc.homunculus_ready()
  return Yso.bal.homunculus ~= false
end

function P.now()
  return _now()
end

function P.target(name)
  return _target_row(name)
end

function P.current_target()
  return _current_target()
end

function P.humour(name, humour)
  local target_row = _target_row(name)
  if not target_row then
    return nil
  end
  return _humour_row(target_row, humour)
end

function P.mark_all_eval_dirty(name, source)
  local target_row = _target_row(name)
  if not target_row then
    return false
  end

  target_row.eval_dirty = true
  target_row.last_dirty_source = tostring(source or "manual")
  target_row.last_dirty_at = _now()

  for i = 1, #P.humours do
    local row = _humour_row(target_row, P.humours[i])
    row.eval_dirty = true
    row.known = false
  end

  return true
end

function P.note_evaluate_request(name, source)
  local target_row = _target_row(name)
  if not target_row then
    return false
  end

  P.state.evaluate.target = target_row.name
  P.state.evaluate.requested_at = _now()
  P.state.evaluate.request_source = tostring(source or "route")
  return true
end

function P.begin_evaluate(name)
  local target_row = _target_row(name)
  if not target_row then
    return false
  end

  local now = _now()
  P.state.evaluate.target = target_row.name
  P.state.evaluate.active = true
  P.state.evaluate.started_at = now
  target_row.last_evaluated_at = now
  return true
end

function P.active_evaluate_target()
  local name = _trim(P.state.evaluate and P.state.evaluate.target or "")
  return name
end

function P.resolve_evaluate_target(default_target)
  local target = _trim(default_target)
  if target ~= "" then
    return target
  end

  target = _trim(P.state.evaluate and P.state.evaluate.target or "")
  if target ~= "" then
    return target
  end

  return _current_target()
end

function P.finish_evaluate(name)
  local target = P.resolve_evaluate_target(name)
  local target_row = _target_row(target)
  if not target_row then
    return false
  end

  P.state.evaluate.active = false
  target_row.last_evaluated_at = _now()
  return true
end

function P.note_steady_count(name, humour, count)
  local target_row = _target_row(name)
  local row = target_row and _humour_row(target_row, humour) or nil
  if not row then
    return false
  end

  local now = _now()
  row.steady_count = tonumber(count) or 0
  row.known = true
  row.eval_dirty = false
  row.last_evaluated_at = now
  target_row.last_evaluated_at = now
  target_row.eval_dirty = false
  _sync_tempered(row)
  return true
end

function P.note_all_normal(name)
  local target_row = _target_row(name)
  if not target_row then
    return false
  end

  local now = _now()
  target_row.eval_dirty = false
  target_row.last_evaluated_at = now
  for i = 1, #P.humours do
    local row = _humour_row(target_row, P.humours[i])
    row.steady_count = 0
    row.known = true
    row.eval_dirty = false
    row.last_evaluated_at = now
    _sync_tempered(row)
  end
  return true
end

function P.note_evaluate_vitals(name, health_pct, mana_pct)
  local target_row = _target_row(name)
  if not target_row then
    return false
  end

  local now = _now()
  if tonumber(health_pct) then
    target_row.vitals.health_pct = math.max(0, math.min(100, tonumber(health_pct)))
  end
  if tonumber(mana_pct) then
    target_row.vitals.mana_pct = math.max(0, math.min(100, tonumber(mana_pct)))
  end
  target_row.vitals.last_evaluated_at = now
  target_row.last_evaluated_at = now
  return true
end

function P.note_temper_success(name, humour)
  local target_row = _target_row(name)
  local row = target_row and _humour_row(target_row, humour) or nil
  if not row then
    return false
  end

  local now = _now()
  row.inferred_count = math.min(8, (tonumber(row.inferred_count or 0) or 0) + 1)
  row.last_tempered_at = now
  _sync_tempered(row)
  return true
end

function P.note_wrack_success(name, humour_one, humour_two)
  local target_row = _target_row(name)
  if not target_row then
    return false
  end

  local now = _now()
  target_row.last_wrack_at = now
  for _, humour in ipairs({ humour_one, humour_two }) do
    local row = _humour_row(target_row, humour)
    if row then
      row.last_wracked_at = now
    end
  end
  return true
end

function P.note_corrupt_success(name, seconds)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end
  if target == "" then
    return false
  end

  local now = _now()
  local duration = tonumber(seconds) or 45
  local key = _target_key(target)
  P.state.corruption[key] = {
    target = target,
    applied_at = now,
    expected_expires_at = now + duration,
  }
  return true
end

function P.clear_corruption(name, source)
  local key = _target_key(name)
  if not key then
    return false
  end
  P.state.corruption[key] = nil
  P.state.last_corruption_clear = {
    target = name,
    source = tostring(source or "manual"),
    at = _now(),
  }
  return true
end

function P.corruption_active(name)
  local key = _target_key(name)
  if not key then
    return false
  end
  local row = P.state.corruption[key]
  if type(row) ~= "table" then
    return false
  end
  if tonumber(row.expected_expires_at or 0) <= _now() then
    P.state.corruption[key] = nil
    return false
  end
  return true
end

function P.count(name, humour, prefer_steady)
  local row = P.humour(name, humour)
  if not row then
    return 0
  end

  local steady = tonumber(row.steady_count)
  local inferred = tonumber(row.inferred_count or 0) or 0
  if prefer_steady == true then
    return steady or 0
  end
  if steady ~= nil then
    return math.max(steady, inferred)
  end
  return inferred
end

function P.steady_count(name, humour)
  return P.count(name, humour, true)
end

function P.target_needs_evaluate(name)
  local target_row = _target_row(name)
  if not target_row then
    return false
  end

  if target_row.eval_dirty == true then
    return true
  end

  for i = 1, #P.humours do
    local row = _humour_row(target_row, P.humours[i])
    if row.eval_dirty == true or row.known ~= true then
      return true
    end
  end

  return false
end

function P.health_pct(name)
  local target_row = _target_row(name)
  return target_row and target_row.vitals and target_row.vitals.health_pct or nil
end

function P.mana_pct(name)
  local target_row = _target_row(name)
  return target_row and target_row.vitals and target_row.vitals.mana_pct or nil
end

function P.can_aurify(name)
  local hp = tonumber(P.health_pct(name))
  local mp = tonumber(P.mana_pct(name))
  return hp ~= nil and mp ~= nil and hp < 60 and mp < 60
end

function P.iron_aff_count(name, giving)
  local list = type(giving) == "table" and giving or P.giving_default
  local count = 0
  for i = 1, #list do
    if _has_aff(list[i]) then
      count = count + 1
    end
  end
  return count
end

function P.pick_missing_aff(name, giving)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end
  local list = type(giving) == "table" and giving or P.giving_default

  local steady_sanguine = tonumber(P.steady_count(target, "sanguine") or 0) or 0
  for i = 1, #list do
    local aff = _lc(list[i])
    if aff ~= "" and not _has_aff(aff) then
      if aff ~= "paralysis" or steady_sanguine >= 2 then
        return aff
      end
    end
  end
  return nil
end

function P.pick_filler_humour(name, forced_aff)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end

  local preferred = P.aff_to_humour[_lc(forced_aff or "")]
  local options = { "choleric", "sanguine" }
  local best_humour, best_count = nil, -1

  for i = 1, #options do
    local humour = options[i]
    if humour ~= preferred then
      local count = tonumber(P.count(target, humour) or 0) or 0
      if count > best_count then
        best_humour = humour
        best_count = count
      end
    end
  end

  if best_humour then
    return best_humour
  end
  return preferred or "choleric"
end

function P.pick_temper_humour(name, giving)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end

  local list = type(giving) == "table" and giving or P.giving_default
  local steady_sanguine = tonumber(P.steady_count(target, "sanguine") or 0) or 0
  if not _has_aff("paralysis") and steady_sanguine < 2 then
    return "sanguine"
  end

  local best_humour = nil
  local best_missing = -1
  local best_count = math.huge

  for humour, affs in pairs(P.humour_to_affs) do
    local missing = 0
    for i = 1, #affs do
      local aff = affs[i]
      local allowed = true
      if aff == "paralysis" and steady_sanguine < 2 then
        allowed = false
      end
      if allowed and not _has_aff(aff) then
        missing = missing + 1
      end
    end

    if missing > 0 then
      local count = tonumber(P.count(target, humour) or 0) or 0
      if missing > best_missing or (missing == best_missing and count < best_count) then
        best_humour = humour
        best_missing = missing
        best_count = count
      end
    end
  end

  if best_humour then
    return best_humour
  end

  local first = P.pick_missing_aff(target, list)
  return P.aff_to_humour[_lc(first or "")] or "choleric"
end

function P.build_truewrack(name, giving)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end

  local forced = P.pick_missing_aff(target, giving)
  if not forced then
    return nil
  end

  local filler = P.pick_filler_humour(target, forced)
  if filler == nil or filler == "" then
    return nil
  end

  return string.format("truewrack %s %s %s", target, filler, forced), filler, forced
end

function P.build_wrack_fallback(name)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end
  if target == "" then
    return nil
  end

  local humour = P.pick_temper_humour(target)
  if humour == nil or humour == "" then
    humour = "choleric"
  end
  return string.format("wrack %s %s", target, humour), humour
end
