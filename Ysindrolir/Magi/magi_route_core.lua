--========================================================--
-- Magi route chassis helpers
--  * Shared runtime helpers for Magi route modules.
--  * Keeps targeting, timing, pending windows, and snapshots in one place.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.magi = Yso.off.magi or {}

Yso.off.magi.route_core = Yso.off.magi.route_core or {}
local RC = Yso.off.magi.route_core

function RC.trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function RC.lc(s)
  return RC.trim(s):lower()
end

function RC.same_target(a, b)
  a = RC.lc(a)
  b = RC.lc(b)
  return a ~= "" and a == b
end

function RC.now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    if ok and tonumber(v) then return tonumber(v) end
  end
  if type(getEpoch) == "function" then
    local v = tonumber(getEpoch()) or os.time()
    if v > 20000000000 then v = v / 1000 end
    return v
  end
  return os.time()
end

function RC.get_target()
  if type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok and RC.trim(v) ~= "" then return RC.trim(v) end
  end

  local cur = rawget(_G, "target")
  if type(cur) == "string" and RC.trim(cur) ~= "" then return RC.trim(cur) end

  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    if type(ak.target) == "string" and RC.trim(ak.target) ~= "" then return RC.trim(ak.target) end
    if type(ak.tgt) == "string" and RC.trim(ak.tgt) ~= "" then return RC.trim(ak.tgt) end
  end

  return ""
end

function RC.room_id()
  local g = rawget(_G, "gmcp")
  local info = g and g.Room and g.Room.Info
  if info and info.num ~= nil then return tostring(info.num) end
  if info and info.id ~= nil then return tostring(info.id) end
  return ""
end

function RC.target_valid(tgt)
  tgt = RC.trim(tgt)
  if tgt == "" then return false end
  if type(Yso.target_is_valid) == "function" then
    local ok, v = pcall(Yso.target_is_valid, tgt)
    if ok then return v == true end
  end
  return true
end

function RC.eq_ready()
  if Yso and Yso.locks and type(Yso.locks.eq_ready) == "function" then
    local ok, v = pcall(Yso.locks.eq_ready)
    if ok then return v == true end
  end
  if Yso and Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then return v == true end
  end

  local vitals = (rawget(_G, "gmcp") or {}).Char
  vitals = vitals and vitals.Vitals or {}
  return tostring(vitals.eq or vitals.equilibrium or "") == "1"
    or vitals.eq == true
    or vitals.equilibrium == true
end

function RC.score_aff(aff)
  aff = RC.lc(aff)
  if aff == "" then return 0 end

  if Yso and Yso.oc and Yso.oc.ak and type(Yso.oc.ak.get_aff_score) == "function" then
    local ok, v = pcall(Yso.oc.ak.get_aff_score, aff)
    if ok and tonumber(v) then return tonumber(v) end
  end

  local A = rawget(_G, "affstrack")
  if type(A) == "table" and type(A.score) == "table" then
    local row = A.score[aff]
    if type(row) == "number" then
      return tonumber(row) or 0
    end
    if type(row) == "table" then
      return tonumber(row.current or row.score or row.value or 0) or 0
    end
  end

  if Yso and Yso.ak and type(Yso.ak.has) == "function" then
    local ok, v = pcall(Yso.ak.has, aff)
    if ok and v == true then return 100 end
  end

  return 0
end

function RC.has_aff(aff)
  return RC.score_aff(aff) > 0
end

function RC.read_resonance()
  local R = Yso and Yso.magi and Yso.magi.resonance or nil
  local synced = false
  local out = { air = 0, earth = 0, fire = 0, water = 0, synced = false }

  if type(R) == "table" and type(R.sync_from_ak) == "function" then
    local ok, synced_ok = pcall(R.sync_from_ak)
    if ok then synced = (synced_ok == true) end
  end

  local function _get(element)
    if type(R) == "table" and type(R.get) == "function" then
      local ok, v = pcall(R.get, element)
      if ok then return tonumber(v) or 0 end
    end
    if type(R) == "table" and type(R.state) == "table" then
      return tonumber(R.state[element] or 0) or 0
    end
    return 0
  end

  out.air = _get("air")
  out.earth = _get("earth")
  out.fire = _get("fire")
  out.water = _get("water")
  out.synced = synced
  out.air_moderate = out.air >= 2
  out.earth_moderate = out.earth >= 2
  out.fire_moderate = out.fire >= 2
  out.water_moderate = out.water >= 2
  out.air_major = out.air >= 3
  out.earth_major = out.earth >= 3
  out.fire_major = out.fire >= 3
  out.water_major = out.water >= 3
  return out
end

function RC.ensure_pending(state, slots)
  state.pending = state.pending or {}
  if type(slots) ~= "table" then return state.pending end
  for i = 1, #slots do
    local name = tostring(slots[i] or "")
    if name ~= "" then
      state.pending[name] = state.pending[name] or { target = "", until_t = 0 }
    end
  end
  return state.pending
end

function RC.pending_slot(state, slot)
  RC.ensure_pending(state, { slot })
  return state.pending[tostring(slot or "")]
end

function RC.clear_pending(state, slot)
  local row = RC.pending_slot(state, slot)
  row.target = ""
  row.until_t = 0
  return row
end

function RC.clear_pending_all(state, slots)
  if type(slots) ~= "table" then return true end
  for i = 1, #slots do
    RC.clear_pending(state, slots[i])
  end
  return true
end

function RC.mark_pending(state, slot, target, duration)
  local row = RC.pending_slot(state, slot)
  row.target = RC.trim(target)
  row.until_t = RC.now() + (tonumber(duration) or 0)
  return row
end

function RC.pending_active(state, slot, target)
  local row = RC.pending_slot(state, slot)
  return RC.same_target(row.target, target) and RC.now() < (tonumber(row.until_t) or 0)
end

function RC.same_target_repeat(state, cmd, target, repeat_s)
  state = type(state) == "table" and state or {}
  if not RC.same_target(state.last_sent_target or "", target) then return false end
  if RC.lc(state.last_sent_cmd or "") ~= RC.lc(cmd or "") then return false end
  local dt = RC.now() - (tonumber(state.last_sent_at) or 0)
  return dt >= 0 and dt < (tonumber(repeat_s) or 0.75)
end

function RC.guard_spell(opts)
  opts = type(opts) == "table" and opts or {}
  local state = type(opts.state) == "table" and opts.state or {}
  local target = RC.trim(opts.target)
  local slot = tostring(opts.slot or "")
  local cmd = tostring(opts.cmd or "")

  if target == "" then return false, "no_target" end

  local target_valid = opts.target_valid
  if target_valid == nil then target_valid = RC.target_valid(target) end
  if target_valid ~= true then return false, "invalid_target" end

  if opts.eq_required ~= false then
    local eq_ready = opts.eq_ready
    if eq_ready == nil then eq_ready = RC.eq_ready() end
    if eq_ready ~= true then return false, "eq_down" end
  end

  if slot ~= "" and RC.pending_active(state, slot, target) then
    return false, slot .. "_pending"
  end

  if RC.same_target_repeat(state, cmd, target, opts.repeat_s or (opts.cfg and opts.cfg.same_target_repeat_s) or 0.75) then
    return false, (slot ~= "" and (slot .. "_repeat") or "repeat")
  end

  return true, ""
end

function RC.build_snapshot(opts)
  opts = type(opts) == "table" and opts or {}
  local target = RC.trim(opts.target or RC.get_target())
  local out = {
    target = target,
    room_id = tostring(opts.room_id or RC.room_id() or ""),
    target_valid = (opts.target_valid ~= nil) and (opts.target_valid == true) or RC.target_valid(target),
    eq_ready = (opts.eq_ready ~= nil) and (opts.eq_ready == true) or RC.eq_ready(),
    raw = {},
    pending = {},
    res = RC.read_resonance(),
  }

  local affs = type(opts.affs) == "table" and opts.affs or {}
  for i = 1, #affs do
    local aff = tostring(affs[i] or "")
    if aff ~= "" then
      out.raw[aff] = RC.score_aff(aff)
      out[aff] = out.raw[aff] > 0
    end
  end

  local pending_slots = type(opts.pending_slots) == "table" and opts.pending_slots or {}
  for i = 1, #pending_slots do
    local slot = tostring(pending_slots[i] or "")
    if slot ~= "" then
      out.pending[slot] = RC.pending_active(opts.state or {}, slot, target)
    end
  end

  if type(opts.extend) == "function" then
    opts.extend(out)
  end

  return out
end

function RC.build_explain(base)
  local out = {}
  if type(base) == "table" then
    for k, v in pairs(base) do
      out[k] = v
    end
  end
  out.generated_at = RC.now()
  return out
end

function RC.reset_runtime_state(state, reason)
  state = type(state) == "table" and state or {}
  reason = tostring(reason or "manual")
  state.busy = false
  state.last_target = ""
  state.last_cmd = ""
  state.last_category = ""
  state.last_sent_cmd = ""
  state.last_sent_target = ""
  state.last_sent_category = ""
  state.last_sent_at = 0
  state.explain = {}
  state.template = state.template or {}
  state.template.last_reason = reason
  state.template.last_payload = nil
  state.template.last_target = ""
  return state
end

return RC
