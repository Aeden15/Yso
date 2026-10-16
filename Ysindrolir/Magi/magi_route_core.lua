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

  -- Yso.targeting subsystem (checked before global fallbacks so the routing
  -- system agrees with whatever Magi_duel_dam.lua and other alias files see).
  if type(Yso.targeting) == "table" then
    if type(Yso.targeting.get) == "function" then
      local ok, v = pcall(Yso.targeting.get)
      if ok and RC.trim(v) ~= "" then return RC.trim(v) end
    elseif type(Yso.targeting.get_target) == "function" then
      local ok, v = pcall(Yso.targeting.get_target)
      if ok and RC.trim(v) ~= "" then return RC.trim(v) end
    elseif type(Yso.targeting.target) == "string" then
      local v = RC.trim(Yso.targeting.target)
      if v ~= "" then return v end
    end
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
  -- Reserve EQ immediately after a purge submission, before GMCP catches up.
  if RC.bloodboil and RC.now() < (RC.bloodboil.pending_until or 0) then return false end
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
  local eq_val = vitals.eq
  if eq_val == nil then eq_val = vitals.equilibrium end
  if eq_val == nil then eq_val = "" end
  return tostring(eq_val) == "1" or eq_val == true
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

function RC.get_target_hp_percent(_target_name)
  local C = Yso.magi and Yso.magi.convergence
  if C and type(C.hp) == "function" then
    return C.hp(_target_name or RC.get_target())
  end
  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    local pct = tonumber(ak.healthpercent)
    if pct then return pct end
    local cur = tonumber(ak.currenthealth)
    local maxhp = tonumber(ak.maxhealth)
    if cur and maxhp and maxhp > 0 then
      return (cur / maxhp) * 100
    end
  end

  local gmcp = rawget(_G, "gmcp")
  local info = gmcp and gmcp.IRE and gmcp.IRE.Target and gmcp.IRE.Target.Info
  if type(info) == "table" then
    local raw = info.hpperc
    if raw ~= nil and tostring(raw) ~= "-1" then
      local hp_text = tostring(raw):gsub("%%", "")
      local n = tonumber(hp_text)
      if n then return n end
    end
  end

  local assess = tonumber(Yso and Yso.magi_assess)
  if assess then return assess end
  return nil
end

Yso.magi = Yso.magi or {}
Yso.magi.elemental = Yso.magi.elemental or {}
Yso.magi.elemental.get_target_hp_percent = RC.get_target_hp_percent

function RC.read_resonance()
  local R = Yso and Yso.magi and Yso.magi.resonance or nil
  local ak = rawget(_G, "ak")
  local live = ak and ak.magi and ak.magi.resonance or nil
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
    -- AK's package triggers are available even when the optional skill
    -- reference/runtime helper is not installed.
    if type(live) == "table" then
      local upper = element:sub(1, 1):upper() .. element:sub(2)
      return tonumber(live[upper] or live[element] or 0) or 0
    end
    return 0
  end

  out.air = _get("air")
  out.earth = _get("earth")
  out.fire = _get("fire")
  out.water = _get("water")
  out.synced = synced or (type(R) ~= "table" and type(live) == "table")
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
  slot = tostring(slot or "")
  if slot == "" then return nil end
  RC.ensure_pending(state, { slot })
  return state.pending[slot]
end

function RC.clear_pending(state, slot)
  local row = RC.pending_slot(state, slot)
  if not row then return nil end
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
  if not row then return nil end
  row.target = RC.trim(target)
  row.until_t = RC.now() + (tonumber(duration) or 0)
  return row
end

function RC.pending_active(state, slot, target)
  local row = RC.pending_slot(state, slot)
  if not row then return false end
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
  local tv = opts.target_valid
  if tv == nil then tv = RC.target_valid(target) end
  local eq = opts.eq_ready
  if eq == nil then eq = RC.eq_ready() end
  local out = {
    target = target,
    room_id = tostring(opts.room_id or RC.room_id() or ""),
    target_valid = tv,
    eq_ready = eq,
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

-- Optional shared finishers are resolved at call time (native load order).
function RC.special_action(tgt)
  local C = Yso.magi and Yso.magi.convergence
  if C and type(C.select) == "function" then return C.select(tgt) end
  return nil, "special_helper_unavailable"
end

function RC.note_special_queued(cmd, tgt)
  if RC.lc(cmd) == "cast bloodboil" then
    RC.bloodboil.pending_until = RC.now() + 4
    return
  end
  local C = Yso.magi and Yso.magi.convergence
  if C and type(C.note_queued) == "function" then C.note_queued(cmd, tgt) end
end

-- Self-purge state is shared by every Magi route and survives route/core reloads.
-- Submission is not proof of a cast: only the success trigger starts cooldown.
RC.bloodboil = RC.bloodboil or { cooling = false, pending_until = 0 }
local bloodboil_affs = {
  "stupidity", "dizziness", "weariness", "recklessness",
  "anorexia", "impatience", "slickness", "asthma",
}
function RC.bloodboil_note_cast()
  RC.bloodboil.cooling = true
  RC.bloodboil.pending_until = RC.now() + 4
end
function RC.bloodboil_note_ready()
  RC.bloodboil.cooling = false
end
function RC.bloodboil_note_eq_recovered()
  RC.bloodboil.pending_until = 0
end
function RC.bloodboil_command()
  local g = rawget(_G, "gmcp")
  local status = g and g.Char and g.Char.Status
  if not status or RC.lc(status.class or status.classname) ~= "magi" then return nil, "wrong_class" end
  if Yso.mode and type(Yso.mode.is_combat) == "function" and not Yso.mode.is_combat() then return nil, "not_combat" end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return nil, "paused" end
  if RC.bloodboil.cooling then return nil, "bloodboil_cooldown" end
  if not RC.eq_ready() then return nil, "eq_down" end
  local tracker = Yso.curing and Yso.curing.afflictions
  if tracker then
    if type(tracker.is_complete) ~= "function" or not tracker.is_complete() then
      return nil, "self_afflictions_incomplete"
    end
    if type(tracker.sync_legacy) == "function" then
      if not tracker.sync_legacy() then return nil, "self_afflictions_unknown" end
    elseif type(tracker.snapshot) ~= "function" or not tracker.snapshot() then
      return nil, "self_afflictions_unknown"
    end
  end
  -- This is Legacy's SELF table, never RC.has_aff/affstrack (enemy evidence).
  local Aff = Legacy and Legacy.Curing and Legacy.Curing.Affs
  if type(Aff) ~= "table" then return nil, "self_afflictions_unknown" end
  if Aff.haemophilia then return nil, "haemophilia" end
  local count = 0
  for _,aff in ipairs(bloodboil_affs) do if Aff[aff] == true then count = count + 1 end end
  if count < 2 then return nil, "below_two_afflictions" end
  local vitals = g.Char.Vitals or {}
  if (tonumber(vitals.mp) or 0) < 75 then return nil, "insufficient_mana" end
  local channels = ""
  for _,stat in pairs(vitals.charstats or {}) do
    local value = tostring(stat):match("^[Cc]hannels:%s*(.*)$")
    if value then channels = value:lower(); break end
  end
  for _,element in ipairs({"fire", "water"}) do
    if not channels:find("%f[%a]" .. element .. "%f[%A]") then return nil, "channels_unconfirmed" end
  end
  return "cast bloodboil", "bloodboil_self_purge"
end
function RC.with_bloodboil(cmd)
  -- Only an actual selected finisher wins; Assess and preparatory spells do not.
  local spell = RC.lc(cmd):match("^cast%s+(%S+)")
  if spell == "destroy" or spell == "convergence" or spell == "stormhammer" or spell == "glaciate" then return cmd end
  local purge, reason = RC.bloodboil_command()
  if purge then return purge, reason end
  return cmd
end

return RC
