-- DO NOT EDIT IN XML; edit this file instead.

Yso = Yso or {}
Yso.hinder = Yso.hinder or {}

local H = Yso.hinder

local function _now()
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

H.cfg = H.cfg or {}
H.state = H.state or { snapshot = nil }

local ALL_AFFS = {
  "paralysis",
  "clumsiness",
  "webbed",
  "entangled",
  "prone",
  "fallen",
  "sleeping",
  "transfixed",
  "impaled",
}

local EQ_BAL_AFFS = {
  "webbed",
  "entangled",
  "prone",
  "fallen",
  "sleeping",
  "transfixed",
  "impaled",
}

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _clone(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for k, v in pairs(value) do
    out[_clone(k, seen)] = _clone(v, seen)
  end
  return out
end

local function _append_unique(list, value)
  value = _trim(value)
  if value == "" then return end
  for i = 1, #list do
    if list[i] == value then return end
  end
  list[#list + 1] = value
end

local function _command_sep()
  local sep = _trim((Yso and (Yso.sep or (Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep)))) or "&&")
  if sep == "" then sep = "&&" end
  return sep
end

local function _join_parts(parts)
  local cmds = {}
  for i = 1, #(parts or {}) do
    local cmd = _trim(parts[i] and parts[i].cmd)
    if cmd ~= "" then cmds[#cmds + 1] = cmd end
  end
  return table.concat(cmds, _command_sep())
end

local function _free_parts(payload)
  local meta = type(payload) == "table" and payload.meta or nil
  local parts = meta and meta.free_parts or nil
  return (type(parts) == "table") and parts or nil
end

function H.collect(ctx)
  local snapshot = {
    at = (Yso and Yso.util and type(Yso.util.now) == "function" and Yso.util.now()) or os.time(),
    eq_bal_blockers = {},
    entity_blockers = {},
    all_offense_blocked = false,
  }

  for i = 1, #ALL_AFFS do
    local aff = ALL_AFFS[i]
    snapshot[aff] = (Yso and Yso.self and type(Yso.self.has_aff) == "function")
      and Yso.self.has_aff(aff) == true
      or false
  end

  if snapshot.paralysis == true then
    snapshot.all_offense_blocked = true
    _append_unique(snapshot.eq_bal_blockers, "paralysis")
    _append_unique(snapshot.entity_blockers, "paralysis")
  end
  if snapshot.clumsiness == true then
    _append_unique(snapshot.entity_blockers, "clumsiness")
  end
  for i = 1, #EQ_BAL_AFFS do
    local aff = EQ_BAL_AFFS[i]
    if snapshot[aff] == true then
      _append_unique(snapshot.eq_bal_blockers, aff)
    end
  end

  H.state.snapshot = snapshot
  return snapshot
end

function H.collected(ctx)
  local snap = H.state.snapshot
  if type(snap) ~= "table" then return H.collect(ctx) end
  local age = (_now() - (snap.at or 0))
  if age > 0.15 then return H.collect(ctx) end
  return snap
end

function H.classify(snapshot, payload, ctx)
  snapshot = type(snapshot) == "table" and snapshot or H.collected(ctx)
  local decision = {
    reevaluate = false,
    all_offense_blocked = snapshot.all_offense_blocked == true,
    blocked_lanes = { free = {}, eq = {}, bal = {}, entity = {} },
    blocked_reasons = {},
    offensive_free_parts = {},
  }

  local function block(lane, reason)
    _append_unique(decision.blocked_lanes[lane], reason)
    _append_unique(decision.blocked_reasons, reason)
    decision.reevaluate = true
  end

  if snapshot.paralysis == true then
    block("eq", "paralysis")
    block("bal", "paralysis")
    block("entity", "paralysis")
  end
  if snapshot.clumsiness == true then
    block("entity", "clumsiness")
  end
  for i = 1, #(snapshot.eq_bal_blockers or {}) do
    local reason = snapshot.eq_bal_blockers[i]
    block("eq", reason)
    block("bal", reason)
  end

  local parts = _free_parts(payload)
  if type(parts) == "table" then
    for i = 1, #parts do
      local part = parts[i]
      if type(part) == "table" and part.offense == true and _trim(part.cmd) ~= "" then
        decision.offensive_free_parts[#decision.offensive_free_parts + 1] = _trim(part.cmd)
      end
    end
  end
  if snapshot.paralysis == true and #decision.offensive_free_parts > 0 then
    block("free", "paralysis")
  end

  return decision
end

function H.apply(payload, decision, ctx)
  local out = _clone(payload)
  out.lanes = type(out.lanes) == "table" and out.lanes or {}
  out.meta = type(out.meta) == "table" and out.meta or {}

  local blocked = type(decision) == "table" and decision.blocked_lanes or {}
  if type(blocked.eq) == "table" and #blocked.eq > 0 then out.lanes.eq = nil end
  if type(blocked.bal) == "table" and #blocked.bal > 0 then out.lanes.bal = nil end
  if type(blocked.entity) == "table" and #blocked.entity > 0 then
    out.lanes.entity = nil
    out.lanes.class = nil
  end

  local parts = _free_parts(out)
  if type(parts) == "table" and type(blocked.free) == "table" and #blocked.free > 0 then
    local kept = {}
    for i = 1, #parts do
      local part = parts[i]
      if type(part) == "table" and part.offense ~= true then
        kept[#kept + 1] = _clone(part)
      end
    end
    out.meta.free_parts = kept
    out.lanes.free = _join_parts(kept)
    if _trim(out.lanes.free) == "" then
      out.lanes.free = nil
    end
  end

  return out
end

return H
