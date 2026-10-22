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

-- return omitted: alias body uses Yso.off.magi.route_core

-- Shared opportunistic Magi finishers. Mudlet Script: Convergence logic.
-- Selection is side-effect free: reserve only after the route accepts a payload.
Yso = Yso or {}
Yso.magi = Yso.magi or {}
Yso.magi.convergence = Yso.magi.convergence or {}
local C = Yso.magi.convergence
C.cfg = C.cfg or { assess_eq_s = 2.5, assess_pending_s = 4,
  assess_retry_s = 10, hp_ttl_s = 15, cast_pending_s = 3.6 }
C.targets = C.targets or {}
C.inventory = C.inventory or {}
local COVER = { 'shyness', 'dizziness', 'stupidity', 'epilepsy' }
-- AK's entire goldenseal/plumbum bucket, not just our preferred cover.
local PLUMBUM = { 'fulminated', 'sandfever', 'dizziness', 'epilepsy',
  'impatience', 'shyness', 'stupidity', 'depression' }
local function core() return Yso.off and Yso.off.magi and Yso.off.magi.route_core end
local function key(s) return (tostring(s or ''):gsub('^%s+',''):gsub('%s+$','')):lower() end
local function now() return core().now() end
local function row(tgt)
  local k = key(tgt)
  if k == '' then return nil end
  C.targets[k] = C.targets[k] or { ticks=0, uncertain=false, attempted=false,
    converged=false, pending_until=0, assess_until=0, assess_retry_at=0 }
  return C.targets[k]
end
local function threshold() return math.max(1, tonumber(Yso.ak and Yso.ak.threshold) or 100) end
local function score(aff) return tonumber(core().score_aff(aff)) or 0 end
local function vitals() return gmcp and gmcp.Char and gmcp.Char.Vitals or {} end
local function is_magi()
  if Yso.classinfo and type(Yso.classinfo.is_magi)=='function' then
    return Yso.classinfo.is_magi() == true
  end
  return key(gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class)=='magi'
end
function C.snapshot(tgt)
  local out = {}
  for k,v in pairs(row(tgt) or {}) do out[k]=v end
  return out
end
function C.reset_target(tgt) C.targets[key(tgt)] = nil end
function C.reset()
  C.targets={}
  if type(ak)=='table' then ak.health_target=nil; ak.health_observed_at=nil end
end
function C.clear_ticks(tgt)
  local s=row(tgt); if not s then return end
  s.ticks, s.uncertain, s.attempted = 0, false, false
end
function C.note_tick(tgt)
  local s=row(tgt); if not s then return false end
  -- After an ambiguous uncovered eat, start a fresh observed lower bound.
  if s.uncertain then s.ticks=0; s.uncertain=false end
  local old=s.ticks
  s.ticks=math.min(4, old+1)
  if s.ticks~=old and type(cecho)=='function' then
    cecho(('\n<SteelBlue>[MAGI] <dark_orchid>DISSONANCE<aquamarine>: (%d/4)<reset>\n'):format(s.ticks))
  end
  return true
end
function C.before_cure(tgt, herb)
  herb=key(herb)
  if herb~='plumbum flake' and herb~='goldenseal root' then return end
  local RC=core()
  if not RC or not RC.same_target(tgt,RC.get_target()) then return end
  local s=row(tgt); if not s or s.ticks==0 then return end
  local possible=false
  local bucket=affstrack and affstrack.eaten and affstrack.eaten[herb] or PLUMBUM
  for _,aff in ipairs(bucket) do
    if key(aff)~='dissonance' then
      local n=score(aff)
      if n>=threshold() then return end -- This eat has other cover to cure.
      if n>0 then possible=true end
    end
  end
  if possible or (tonumber(ak and ak.randomaffs) or 0)>0 then
    s.uncertain=true
  else
    C.clear_ticks(tgt)
  end
end
-- Visible Enemy curing triggers record text evidence. The AK pre-cure hook
-- above is the only place that changes stacks, independent of trigger order.
function C.note_eat_line(tgt, herb)
  herb=key(herb)
  local RC=core()
  if (herb~='plumbum flake' and herb~='goldenseal root') or not RC
    or not RC.same_target(tgt,RC.get_target()) then return false end
  local s=row(tgt); if not s then return false end
  s.last_eat_herb=herb; s.last_eat_at=now()
  return true
end
function C.note_result(tgt, success)
  local s=row(tgt); if not s then return end
  s.attempted=success==true
  s.converged=success==true
  s.pending_until=0
end
-- The package handles the verified insufficient-dissonance failure. A queued
-- attempt is latched until explicit result/reset or confirmed dissonance cure;
-- it never fabricates a successful affliction from a send.
function C.note_queued(cmd,tgt)
  local s=row(tgt); if not s then return end
  local lc=key(cmd)
  if lc=='cast convergence at '..key(tgt) then
    if s.attempted then return end
    s.attempted=true; s.pending_until=now()+2.9
  elseif lc=='assess '..key(tgt) then
    if now()<s.assess_until then return end
    s.assess_until=now()+C.cfg.assess_pending_s
    s.assess_retry_at=now()+C.cfg.assess_retry_s
    C.assess_eq_until=now()+(tonumber(C.cfg.assess_eq_s) or 2.5)
  elseif lc=='cast destroy at '..key(tgt) then
    if now()<s.pending_until then return end
    s.pending_until=now()+C.cfg.cast_pending_s
  end
end
function C.note_assess(tgt, current, maximum)
  current, maximum=tonumber(current),tonumber(maximum)
  if not current or not maximum or maximum<=0 or current<0 or current>maximum then return false end
  local s=row(tgt); if not s then return false end
  s.hp=100*current/maximum; s.hp_at=now(); s.assess_until=0
  if core().same_target(tgt,core().get_target()) and type(ak)=='table' then
    ak.healthpercent=s.hp
    ak.health_target=tgt
    ak.health_observed_at=now()
  end
  return true
end
function C.hp(tgt)
  local RC=core(); if not RC or not RC.same_target(tgt,RC.get_target()) then return nil end
  local k=key(tgt)
  local s=row(tgt)
  local a=rawget(_G,'ak')
  -- AK initializes healthpercent to 100 even without an assessment. Only
  -- a named, timestamped observation is evidence; default/global HP is not.
  if a and key(a.health_target)==k and a.health_observed_at
    and now()-a.health_observed_at<=C.cfg.hp_ttl_s then
    local n=tonumber(a.healthpercent)
    if n and n>=0 and n<=100 then return n end
  end
  if s.hp and now()-(s.hp_at or 0)<=C.cfg.hp_ttl_s then return s.hp end
  return nil
end
function C.capture_target_info(info)
  if type(info)~='table' then return end
  local name=info.name or info.target
  local hp_text=tostring(info.hpperc or ''):gsub('%%','')
  local hp=tonumber(hp_text)
  if key(name)=='' or not hp or hp<0 or hp>100 then return end
  local s=row(name); s.hp=hp; s.hp_at=now(); s.assess_until=0
end
function C.capture_items(data,kind)
  if type(data)~='table' or data.location~='inv' then return end
  if kind=='List' then
    C.inventory={}
    for _,item in ipairs(data.items or {}) do C.inventory[tostring(item.id)]=item end
  elseif data.item then
    C.inventory[tostring(data.item.id)]=kind=='Remove' and nil or data.item
    if kind=='Remove' then C.inventory[tostring(data.item.id)]=nil end
  end
end
function C.staff_ready()
  local W=Yso.magi.weapons
  local id=W and type(W.get)=='function' and W.get('staff') or tostring(rawget(_G,'magistaff') or ''):match('^staff(%d+)$')
  for _,item in pairs(C.inventory) do
    local attrs=tostring(item.attrib or '')
    local name=key(item.name)
    if (attrs:find('l',1,true) or attrs:find('r',1,true))
      and ((id and id~='' and tostring(item.id)==tostring(id))
        or name:find('elemental staff',1,true)) then return true end
  end
  return false
end
function C.channels_ready(required)
  -- Optional adapter for installations that already track channel changes.
  if type(C.channel_check)=='function' then return C.channel_check(required)==true end
  local text=''
  for _,stat in pairs(vitals().charstats or {}) do
    local value=tostring(stat):match('^[Cc]hannels:%s*(.*)$')
    if value then text=key(value); break end
  end
  for _,el in ipairs(required) do
    if not text:find('%f[%a]'..el..'%f[%A]') then return false end
  end
  return true
end
local function ready(tgt)
  local RC=core()
  if not RC or not is_magi() or not RC.same_target(tgt,RC.get_target()) or not RC.target_valid(tgt) then return false end
  if type(Yso.offense_paused)=='function' and Yso.offense_paused() then return false end
  return RC.eq_ready()
end
function C.command(tgt)
  local RC=core(); tgt=tgt or (RC and RC.get_target())
  if not ready(tgt) then return nil,'not_ready' end
  local s=row(tgt)
  if now()<s.pending_until or now()<s.assess_until or now()<(C.assess_eq_until or 0) then
    return nil,'special_pending'
  end
  if s.attempted or s.converged then return nil,'convergence_attempted' end
  if s.uncertain or s.ticks<4 then return nil,'dissonance_below_four_ticks' end
  if score('fulminated')<threshold() then return nil,'fulminated_missing' end
  local n=0
  for _,aff in ipairs(COVER) do if score(aff)>=threshold() then n=n+1 end end
  if n<3 then return nil,'needs_three_other_cover_afflictions' end
  n=0
  for _,aff in ipairs(PLUMBUM) do if score(aff)>=threshold() then n=n+1 end end
  if n<2 then return nil,'dissonance_exposed' end
  local r=RC.read_resonance()
  for _,el in ipairs({'air','earth','fire','water'}) do
    if (tonumber(r[el]) or 0)<2 then return nil,el..'_below_moderate' end
  end
  if not C.channels_ready({'air','earth','fire','water'}) then return nil,'channels_unconfirmed' end
  if (tonumber(vitals().mp) or 0)<300 then return nil,'insufficient_mana' end
  return 'cast convergence at '..tgt,'convergence_ready'
end
Converge=C.command
function C.destroy_command(tgt)
  if not ready(tgt) then return nil,'not_ready' end
  local s=row(tgt)
  if now()<s.pending_until or now()<s.assess_until or now()<(C.assess_eq_until or 0) then
    return nil,'special_pending',true
  end
  if score('conflagrate')<threshold() or score('aflame')<200 then return nil,'destroy_afflictions_missing' end
  if not C.staff_ready() then return nil,'elemental_staff_unconfirmed' end
  if not C.channels_ready({'fire'}) then return nil,'fire_channel_unconfirmed' end
  local hp=C.hp(tgt)
  if hp==nil then
    if now()<s.assess_retry_at then return nil,'assess_backoff' end
    if (tonumber(vitals().mp) or 0)<50 then return nil,'assess_mana' end
    return 'assess '..tgt,'assess_unknown_hp'
  end
  if hp>40 then return nil,'hp_above_destroy_threshold' end
  return 'cast destroy at '..tgt,'destroy_ready'
end
function C.select(tgt)
  local cmd,why,hold=C.destroy_command(tgt)
  if cmd or hold then return cmd,why,hold end
  return C.command(tgt)
end

-- Native item events keep wield state current across List/Add/Update/Remove.
local items=gmcp and gmcp.Char and gmcp.Char.Items
if items and items.List then C.capture_items(items.List,'List') end
C.handlers=C.handlers or {}
if type(registerAnonymousEventHandler)=='function' then
  for _,kind in ipairs({'List','Add','Update','Remove'}) do
    if C.handlers[kind] and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(C.handlers[kind]) end
    C.handlers[kind]=registerAnonymousEventHandler('gmcp.Char.Items.'..kind,function()
      local g=gmcp and gmcp.Char and gmcp.Char.Items
      C.capture_items(g and g[kind],kind)
    end)
  end
  if C.handlers.target_info and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(C.handlers.target_info) end
  C.handlers.target_info=registerAnonymousEventHandler('gmcp.IRE.Target.Info',function()
    C.capture_target_info(gmcp and gmcp.IRE and gmcp.IRE.Target and gmcp.IRE.Target.Info)
  end)
end
-- return omitted: shared convergence helper

--========================================================--
-- magi_group_damage.lua
--  * Group damage route for Magi (tests + export mirror).
--  * Mudlet-primary copy lives in ^mdam$ alias (Magi/mdam_alias_body.lua; includes route_core).
--  * Strategy:
--      - STAFF CAST HORRIPILATION while waterbonds are missing.
--      - CAST FREEZE as the default baseline until freeze-side pressure exists.
--      - Keep the existing mudslide / water-emanation / glaciate water line.
--      - Once frozen or frostbite is established on the current target, branch
--        into fire pressure without abandoning the water side.
--      - Use MAGMA / FIRELASH / CONFLAGRATE / EMANATION FIRE conditionally.
--  * Alias-controlled loop ownership lives in Yso.mode.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.magi = Yso.off.magi or {}

Yso.off.magi.group_damage = Yso.off.magi.group_damage or {}
local MGD = Yso.off.magi.group_damage
-- NOTE: do NOT alias Yso.off.magi.dmg here — that namespace is owned by
-- Magi_duel_dam.lua (magi_dmg route). Aliasing it here caused both routes
-- to share the same module table, making magi_dmg inherit MGD.is_active()
-- which checks group-damage context and immediately kills the duel loop.
MGD.alias_owned = true

Yso.off.magi.route_core = Yso.off.magi.route_core or {}
local RC = Yso.off.magi.route_core

local trim, lc, same_target, now = RC.trim, RC.lc, RC.same_target, RC.now

local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil

local PENDING_SLOTS = {
  "horripilation",
  "freeze",
  "mudslide",
  "emanation_water",
  "magma",
  "firelash",
  "conflagrate",
  "emanation_fire",
  "glaciate",
}

MGD.route_contract = MGD.route_contract or {
  id = "magi_group_damage",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "opener_setup",
    "freeze_setup",
    "salve_pressure",
    "disrupt_setup",
    "glaciate_burst",
    "fire_build",
    "fire_payoff",
    "fire_promotion",
  },
  capabilities = {
    uses_eq = true,
    uses_bal = false,
    uses_entity = false,
    supports_burst = true,
    supports_bootstrap = false,
    needs_target = true,
    shares_defense_break = false,
    shares_anti_tumble = false,
  },
  override_policy = {
    mode = "narrow_global_only",
    allowed = {
      target_invalid = true,
      target_slain = true,
      route_off = true,
      pause = true,
      manual_suppression = true,
      target_swap_bootstrap = true,
    },
  },
  lifecycle = {
    on_enter = true,
    on_exit = true,
    on_target_swap = true,
    on_pause = true,
    on_resume = true,
    on_manual_success = true,
    on_send_result = true,
    evaluate = true,
    explain = true,
  },
}

do
  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(MGD, MGD.route_contract)
  end
end

MGD.cfg = MGD.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,
  same_target_repeat_s = 0.75,
  horripilation_pending_s = 1.00,
  freeze_pending_s = 1.00,
  mudslide_pending_s = 0.80,
  water_emanation_pending_s = 2.60,
  magma_pending_s = 1.00,
  firelash_pending_s = 1.00,
  conflagrate_pending_s = 1.00,
  fire_emanation_pending_s = 2.60,
  glaciate_pending_s = 1.00,
}

MGD.state = MGD.state or {
  enabled = false,
  loop_enabled = false,
  timer_id = nil,
  busy = false,
  last_target = "",
  last_cmd = "",
  last_category = "",
  last_sent_cmd = "",
  last_sent_target = "",
  last_sent_category = "",
  last_sent_at = 0,
  explain = {},
  template = { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" },
  pending = {
    horripilation = { target = "", until_t = 0 },
    freeze = { target = "", until_t = 0 },
    mudslide = { target = "", until_t = 0 },
    emanation_water = { target = "", until_t = 0 },
    magma = { target = "", until_t = 0 },
    firelash = { target = "", until_t = 0 },
    conflagrate = { target = "", until_t = 0 },
    emanation_fire = { target = "", until_t = 0 },
    glaciate = { target = "", until_t = 0 },
  },
  cold = {
    target = "",
    room_id = "",
    phase = "reset",
    seen_frostbite = false,
    seen_frozen = false,
    progressed_at = 0,
    reason = "init",
  },
  route = {
    target = "",
    room_id = "",
    freeze_step_done = false,
    branch_stage = "reset",
    last_reset_reason = "init",
  },
  waiting = { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" },
  in_flight = { fingerprint = "", target = "", route = "magi_group_damage", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" },
}

local function _echo(msg)
  if MGD.cfg.echo ~= true then return end
  if type(cecho) == "function" then
    cecho(string.format("<cadet_blue>[Yso:Magi] <reset>%s\n", tostring(msg)))
  elseif type(echo) == "function" then
    echo(string.format("[Yso:Magi] %s\n", tostring(msg)))
  end
end

local function _is_magi()
  if type(Yso.is_magi) == "function" then
    local ok, v = pcall(Yso.is_magi)
    if ok then return v == true end
  end
  local C = Yso and Yso.classinfo or nil
  if type(C) == "table" and type(C.is_magi) == "function" then
    local ok, v = pcall(C.is_magi)
    if ok then return v == true end
  end
  local gmcp = rawget(_G, "gmcp")
  local cls = gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class or nil
  if type(cls) == "string" and trim(cls) ~= "" then return lc(cls) == "magi" end
  if type(Yso.class) == "string" and trim(Yso.class) ~= "" then return lc(Yso.class) == "magi" end
  return false
end

--- Group damage runs whenever Magi is in combat mode (same as other combat routes).
local function _group_damage_context_ok()
  if not _is_magi() then return false end
  local Mo = Yso and Yso.mode
  if not Mo then return false end
  if type(Mo.is_combat) == "function" then
    local ok, v = pcall(Mo.is_combat)
    if ok and v ~= true then return false end
  end
  return true
end

local function _route_is_active()
  if not _group_damage_context_ok() then return false end
  if Yso and Yso.mode and type(Yso.mode.route_loop_active) == "function" then
    return Yso.mode.route_loop_active("magi_group_damage") == true
  end
  return MGD.state and MGD.state.loop_enabled == true
end

local function _set_loop_enabled(on)
  local enabled = (on == true)
  MGD.state.enabled = enabled
  MGD.state.loop_enabled = enabled
  -- Do NOT set MGD.loop_enabled on the module table directly — only MGD.state
  -- is authoritative. Setting a module-level copy caused stale reads after a
  -- state reset that didn't touch the module-level field.
  MGD.cfg.enabled = enabled
  MGD.state.loop_delay = tonumber(MGD.state.loop_delay or MGD.cfg.loop_delay or 0.15) or 0.15
  return enabled
end

local function _cold_slot()
  MGD.state.cold = MGD.state.cold or {
    target = "",
    room_id = "",
    phase = "reset",
    seen_frostbite = false,
    seen_frozen = false,
    progressed_at = 0,
    reason = "init",
  }
  return MGD.state.cold
end

local function _reset_cold(reason)
  local cold = _cold_slot()
  cold.target = ""
  cold.room_id = ""
  cold.phase = "reset"
  cold.seen_frostbite = false
  cold.seen_frozen = false
  cold.progressed_at = 0
  cold.reason = tostring(reason or "")
  return cold
end

local function _route_slot()
  MGD.state.route = MGD.state.route or {
    target = "",
    room_id = "",
    freeze_step_done = false,
    branch_stage = "reset",
    last_reset_reason = "init",
  }
  return MGD.state.route
end

local function _reset_route(reason)
  local route = _route_slot()
  route.target = ""
  route.room_id = ""
  route.freeze_step_done = false
  route.branch_stage = "reset"
  route.last_reset_reason = tostring(reason or "")
  return route
end

local function _ensure_context(tgt)
  local room = RC.room_id()
  local cold = _cold_slot()
  local route = _route_slot()

  local room_changed = false
  if cold.room_id ~= "" and room ~= "" and cold.room_id ~= room then room_changed = true end
  if route.room_id ~= "" and room ~= "" and route.room_id ~= room then room_changed = true end

  local target_changed = false
  if cold.target ~= "" and tgt ~= "" and not same_target(cold.target, tgt) then target_changed = true end
  if route.target ~= "" and tgt ~= "" and not same_target(route.target, tgt) then target_changed = true end

  if room_changed then
    cold = _reset_cold("room_change")
    route = _reset_route("room_change")
  elseif target_changed then
    cold = _reset_cold("target_change")
    route = _reset_route("target_change")
  end

  cold.target = trim(tgt or "")
  cold.room_id = room
  route.target = trim(tgt or "")
  route.room_id = room
  return cold, route
end

local function _set_branch_stage(tgt, stage)
  local _, route = _ensure_context(tgt)
  route.branch_stage = tostring(stage or "")
  return route
end

local function _refresh_cold_state(tgt, frozen, frostbite)
  local cold = _ensure_context(tgt)
  if frostbite == true then cold.seen_frostbite = true end
  if frozen == true then cold.seen_frozen = true end

  if (cold.seen_frozen or cold.seen_frostbite) and tonumber(cold.progressed_at or 0) <= 0 then
    cold.progressed_at = now()
  end
  if cold.seen_frozen or cold.seen_frostbite then
    cold.phase = "progressed"
  else
    cold.phase = "freeze_baseline"
  end
  return cold
end

local function _spell_guard(slot_name, tgt, cmd)
  return RC.guard_spell({
    state = MGD.state,
    cfg = MGD.cfg,
    slot = slot_name,
    target = tgt,
    cmd = cmd,
    target_valid = RC.target_valid(tgt),
    eq_ready = RC.eq_ready(),
  })
end

local function _freeze_stable()
  return RC.has_aff("frozen") or RC.has_aff("frostbite")
end

local function _has_conflagrate()
  return RC.has_aff("conflagrate")
end

-- AK tracks ablaze stacks under the key "aflame"; "ablaze" is the in-game name.
local function _has_ablaze()
  return RC.has_aff("aflame")
end

local function _aflame_ready_for_conflagrate()
  return RC.score_aff("aflame") >= 200
end

local function _can_cast_horripilation(tgt)
  local cmd = ("staff cast horripilation %s"):format(tgt)
  local ok, why = _spell_guard("horripilation", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_freeze(tgt)
  local cmd = ("cast freeze at %s"):format(tgt)
  local ok, why = _spell_guard("freeze", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_mudslide(tgt)
  local cmd = ("cast mudslide at %s"):format(tgt)
  local ok, why = _spell_guard("mudslide", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_glaciate(tgt)
  local cmd = ("cast glaciate at %s"):format(tgt)
  if not RC.has_aff("frozen") then return false, "frozen_required", cmd end
  local ok, why = _spell_guard("glaciate", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_magma(tgt)
  local cmd = ("cast magma at %s"):format(tgt)
  local ok, why = _spell_guard("magma", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_firelash(tgt)
  local cmd = ("cast firelash at %s"):format(tgt)
  local ok, why = _spell_guard("firelash", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_conflagrate(tgt)
  local cmd = ("cast conflagrate at %s"):format(tgt)
  -- Two-stage check gives better diagnostics:
  --   "ablaze_required"  = no ablaze stacks at all (aflame score = 0)
  --   "aflame_not_ready" = ablaze started but fewer than 2 stacks (score < 200)
  if not _has_ablaze() then return false, "ablaze_required", cmd end
  if not _aflame_ready_for_conflagrate() then return false, "aflame_not_ready", cmd end
  local ok, why = _spell_guard("conflagrate", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_water_emanation(tgt)
  local res = RC.read_resonance()
  local cmd = ("cast emanation at %s water"):format(tgt)
  if res.water_major ~= true then return false, "water_not_major", cmd end
  local ok, why = _spell_guard("emanation_water", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_fire_emanation(tgt)
  local res = RC.read_resonance()
  local cmd = ("cast emanation at %s fire"):format(tgt)
  if res.fire_major ~= true then return false, "fire_not_major", cmd end
  if not _has_conflagrate() then return false, "conflagrate_required", cmd end
  if not _freeze_stable() then return false, "freeze_stable_required", cmd end
  local ok, why = _spell_guard("emanation_fire", tgt, cmd)
  return ok, why, cmd
end

local function _effective_state(tgt)
  local base = RC.build_snapshot({
    state = MGD.state,
    target = tgt,
    affs = {
      "waterbonds",
      "frozen",
      "frostbite",
      "slickness",
      "disrupt",
      "scalded",
      "conflagrate",
      "aflame",
    },
    pending_slots = PENDING_SLOTS,
  })
  local frozen = base.frozen == true
  local frostbite = base.frostbite == true
  local slick_actual = base.slickness == true
  local disrupt_actual = base.disrupt == true
  local waterbonds_actual = base.waterbonds == true
  local scalded_actual = base.scalded == true
  local conflagrate = base.conflagrate == true
  local ablaze = _has_ablaze()
  local aflame = tonumber(base.raw.aflame or 0) or 0
  local water_res = tonumber(base.res.water or 0) or 0
  local fire_res = tonumber(base.res.fire or 0) or 0
  local water_major = base.res.water_major == true
  local fire_major = base.res.fire_major == true
  local cold = _refresh_cold_state(tgt, frozen, frostbite)
  local _, route = _ensure_context(tgt)

  local slickness = slick_actual or RC.pending_active(MGD.state,"mudslide", tgt)
  local disrupt = disrupt_actual or RC.pending_active(MGD.state,"emanation_water", tgt)
  local waterbonds = waterbonds_actual or RC.pending_active(MGD.state,"horripilation", tgt)
  local scalded = scalded_actual or RC.pending_active(MGD.state,"magma", tgt)
  local fire_branch_eligible = (route.freeze_step_done == true) and _freeze_stable()

  return {
    target = trim(tgt or ""),
    target_valid = RC.target_valid(tgt),
    waterbonds = waterbonds,
    waterbonds_actual = waterbonds_actual,
    frozen = frozen,
    frostbite = frostbite,
    freeze_stable = _freeze_stable(),
    slickness = slickness,
    slickness_actual = slick_actual,
    disrupt = disrupt,
    disrupt_actual = disrupt_actual,
    scalded = scalded,
    scalded_actual = scalded_actual,
    conflagrate = conflagrate,
    ablaze = ablaze,
    aflame = aflame,
    aflame_ready = aflame >= 200,
    water_res = water_res,
    water_res_major = water_major,
    fire_res = fire_res,
    fire_res_major = fire_major,
    resonance_synced = base.res.synced == true,
    freeze_step_done = (route.freeze_step_done == true),
    fire_branch_eligible = fire_branch_eligible,
    route = {
      target = route.target,
      room_id = route.room_id,
      freeze_step_done = route.freeze_step_done,
      branch_stage = route.branch_stage,
      last_reset_reason = route.last_reset_reason,
    },
    cold = {
      target = cold.target,
      room_id = cold.room_id,
      phase = cold.phase,
      seen_frostbite = cold.seen_frostbite,
      seen_frozen = cold.seen_frozen,
      progressed_at = cold.progressed_at,
      reason = cold.reason,
    },
    pending = {
      horripilation = RC.pending_active(MGD.state,"horripilation", tgt),
      freeze = RC.pending_active(MGD.state,"freeze", tgt),
      mudslide = RC.pending_active(MGD.state,"mudslide", tgt),
      emanation_water = RC.pending_active(MGD.state,"emanation_water", tgt),
      magma = RC.pending_active(MGD.state,"magma", tgt),
      firelash = RC.pending_active(MGD.state,"firelash", tgt),
      conflagrate = RC.pending_active(MGD.state,"conflagrate", tgt),
      emanation_fire = RC.pending_active(MGD.state,"emanation_fire", tgt),
      glaciate = RC.pending_active(MGD.state,"glaciate", tgt),
    },
    raw = {
      waterbonds = tonumber(base.raw.waterbonds or 0) or 0,
      frozen = tonumber(base.raw.frozen or 0) or 0,
      frostbite = tonumber(base.raw.frostbite or 0) or 0,
      slickness = tonumber(base.raw.slickness or 0) or 0,
      disrupt = tonumber(base.raw.disrupt or 0) or 0,
      scalded = tonumber(base.raw.scalded or 0) or 0,
      conflagrate = tonumber(base.raw.conflagrate or 0) or 0,
      aflame = aflame,
      water_res = water_res,
      fire_res = fire_res,
    },
  }
end

local function _should_mudslide(st)
  return st.frozen == true and st.slickness ~= true
end

local function _should_water_emanation(st)
  return st.frozen == true and st.slickness == true and st.disrupt ~= true and st.water_res_major == true
end

local function _should_glaciate(st, tgt)
  if st.frozen ~= true then return false end
  if st.slickness ~= true then return false end
  if st.disrupt ~= true and st.water_res_major == true then return false end
  if same_target(MGD.state.last_sent_target or "", tgt) and MGD.state.last_sent_category == "glaciate_burst" then
    return false
  end
  return true
end

local function _should_fire_emanation(st)
  return st.conflagrate == true
    and st.freeze_stable == true
    and st.fire_res_major == true
end

local function _select_command(tgt)
  local st = _effective_state(tgt)

  if not st.target_valid then
    _set_branch_stage(tgt, "invalid_target")
    return nil, nil, st, "invalid_target"
  end

  local special, reason, hold = RC.special_action(tgt)
  if special or hold then return special, "special", st, reason end

  if not st.waterbonds then
    local ok, why, cmd = _can_cast_horripilation(tgt)
    _set_branch_stage(tgt, ok and "opener_setup" or "opener_wait")
    if ok then
      return cmd, "opener_setup", st, "waterbonds_missing"
    end
    return nil, nil, st, why ~= "" and why or "waterbonds_missing"
  end

  if st.freeze_step_done ~= true then
    local ok, why, cmd = _can_cast_freeze(tgt)
    _set_branch_stage(tgt, ok and "freeze_setup" or "freeze_wait")
    if ok then
      return cmd, "freeze_setup", st, "freeze_step_gate"
    end
    return nil, nil, st, why ~= "" and why or "freeze_step_gate"
  end

  if _should_mudslide(st) then
    local ok, why, cmd = _can_cast_mudslide(tgt)
    _set_branch_stage(tgt, ok and "salve_pressure" or "mudslide_wait")
    if ok then
      return cmd, "salve_pressure", st, "mudslide_window"
    end
    return nil, nil, st, why ~= "" and why or "mudslide_window"
  end

  do
    local ok, _, cmd = _can_cast_glaciate(tgt)
    if ok and _should_glaciate(st, tgt) then
      _set_branch_stage(tgt, "glaciate_burst")
      return cmd, "glaciate_burst", st, "glaciate_window"
    end
  end

  if st.freeze_stable ~= true then
    local ok, why, cmd = _can_cast_freeze(tgt)
    _set_branch_stage(tgt, ok and "freeze_setup" or "freeze_wait")
    if ok then
      return cmd, "freeze_setup", st, "freeze_baseline"
    end
    return nil, nil, st, why ~= "" and why or "freeze_baseline"
  end

  if _should_water_emanation(st) then
    local ok, _, cmd = _can_cast_water_emanation(tgt)
    if ok then
      _set_branch_stage(tgt, "disrupt_setup")
      return cmd, "disrupt_setup", st, "water_emanation_setup"
    end
  end

  if st.fire_branch_eligible == true and st.conflagrate ~= true and st.aflame_ready == true and st.ablaze == true then
    local ok, _, cmd = _can_cast_conflagrate(tgt)
    if ok then
      _set_branch_stage(tgt, "fire_payoff")
      return cmd, "fire_payoff", st, "conflagrate_ready"
    end
  end

  if st.fire_branch_eligible == true and _should_fire_emanation(st) then
    local ok, _, cmd = _can_cast_fire_emanation(tgt)
    if ok then
      _set_branch_stage(tgt, "fire_promotion")
      return cmd, "fire_promotion", st, "fire_emanation_promote"
    end
  end

  if st.fire_branch_eligible == true and st.scalded ~= true then
    local ok, _, cmd = _can_cast_magma(tgt)
    if ok then
      _set_branch_stage(tgt, "fire_build")
      return cmd, "fire_build", st, "scalded_missing"
    end
  end

  if st.fire_branch_eligible == true and st.conflagrate ~= true then
    local ok, _, cmd = _can_cast_firelash(tgt)
    if ok then
      _set_branch_stage(tgt, "fire_build")
      return cmd, "fire_build", st, "firelash_builder"
    end
  end

  do
    local ok, _, cmd = _can_cast_glaciate(tgt)
    if ok and st.frozen == true then
      _set_branch_stage(tgt, "glaciate_burst")
      return cmd, "glaciate_burst", st, "glaciate_fallback"
    end
  end

  if st.fire_branch_eligible == true then
    local ok, _, cmd = _can_cast_firelash(tgt)
    if ok then
      _set_branch_stage(tgt, "fire_build")
      return cmd, "fire_build", st, "maintain_fire_pressure"
    end
  end

  do
    local ok, why, cmd = _can_cast_freeze(tgt)
    if ok then
      _set_branch_stage(tgt, "freeze_setup")
      return cmd, "freeze_setup", st, "freeze_refresh"
    end
    _set_branch_stage(tgt, "hold")
    return nil, nil, st, why ~= "" and why or "no_legal_action"
  end
end

local function _emit_payload(payload, category)
  local target = trim(type(payload) == "table" and payload.target or "")
  local opts = {
    reason = "magi_group_damage:" .. tostring(category or "attack"),
    kind = "offense",
    commit = true,
    require_commit = payload.eq == "cast bloodboil",
    repeat_command = payload.eq == "cast bloodboil",
    route = "magi_group_damage",
    target = target,
  }

  if RI and type(RI.emit_route_payload) == "function" then
    return RI.emit_route_payload("magi_group_damage", {
      target = target,
      lanes = { eq = payload and payload.eq },
      meta = {
        route = "magi_group_damage",
        main_lane = "eq",
        main_category = tostring(category or ""),
      },
    }, opts)
  end

  if type(Yso.emit) == "function" then
    return Yso.emit(payload, opts) == true, nil, nil
  end

  local cmd = type(payload) == "table" and (payload.eq or (type(payload.lanes) == "table" and payload.lanes.eq)) or nil
  if type(cmd) == "string" and cmd ~= "" and type(send) == "function" then
    local ok = pcall(send, cmd)
    return ok == true, nil, nil
  end

  return false, "emit_unavailable", nil
end

local function _payload_each_eq(payload, fn)
  if type(payload) ~= "table" or type(fn) ~= "function" then return end
  local row = payload.eq or (type(payload.lanes) == "table" and payload.lanes.eq)
  if type(row) == "string" then
    fn(row)
    return
  end
  if type(row) == "table" then
    for i = 1, #row do
      if type(row[i]) == "string" then fn(row[i]) end
    end
  end
end

local function _capture_target(cmd, pat)
  return trim(lc(cmd):match(pat) or "")
end

local function _attack_opts(arg)
  if type(arg) == "table" and (arg.preview ~= nil or arg.ctx ~= nil) then
    return arg.ctx, (arg.preview == true)
  end
  return arg, false
end

local function _update_explain(tgt, st, category, reason, planned_cmd)
  MGD.state.explain = RC.build_explain({
    route = "magi_group_damage",
    target = tgt,
    decision = category or "",
    reason = reason or "",
    planned = { eq = planned_cmd or "" },
    branch_stage = (_route_slot().branch_stage or (st and st.route and st.route.branch_stage) or ""),
    freeze_step_done = st and st.freeze_step_done == true or false,
    fire_branch_eligible = st and st.fire_branch_eligible == true or false,
    state = st or {},
    last_cmd = MGD.state and MGD.state.last_cmd or "",
    last_sent_cmd = MGD.state and MGD.state.last_sent_cmd or "",
    pending = MGD.state and MGD.state.pending or {},
    route_enabled = MGD.is_enabled and MGD.is_enabled() or false,
    active = MGD.is_active and MGD.is_active() or false,
  })
end

local function _clear_runtime_state(reason)
  RC.reset_runtime_state(MGD.state, reason)
end

function MGD.init()
  MGD.cfg = MGD.cfg or {}
  MGD.state = MGD.state or {}
  MGD.state.template = MGD.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  RC.ensure_pending(MGD.state, PENDING_SLOTS)
  if RI and type(RI.ensure_waiting_state) == "function" then
    RI.ensure_waiting_state(MGD.state, "magi_group_damage")
  end
  _cold_slot()
  _route_slot()
  MGD.state.loop_delay = tonumber(MGD.state.loop_delay or MGD.cfg.loop_delay or 0.15) or 0.15
  MGD.state.busy = (MGD.state.busy == true)
  _set_loop_enabled((MGD.state.loop_enabled == true) or (MGD.state.enabled == true))
  return true
end

function MGD.reset(reason)
  MGD.init()
  RC.clear_pending_all(MGD.state, PENDING_SLOTS)
  _reset_cold(reason or "manual")
  _reset_route(reason or "manual")
  _clear_runtime_state(reason or "manual")
  if RI and type(RI.clear_waiting) == "function" then
    RI.clear_waiting(MGD.state, "magi_group_damage")
  end
  return true
end

function MGD.is_enabled()
  return MGD.state and MGD.state.enabled == true
end

function MGD.is_active()
  return _route_is_active()
end

function MGD.can_run(ctx)
  MGD.init()
  if not MGD.is_enabled() then return false, "disabled" end
  if not MGD.is_active() then return false, "inactive" end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return false, "paused" end

  local tgt = trim((ctx and ctx.target) or RC.get_target())
  if tgt == "" then
    _reset_cold("no_target")
    _reset_route("no_target")
    return false, "no_target"
  end
  if not _is_magi() then return false, "wrong_class" end
  if not RC.target_valid(tgt) then
    _reset_cold("invalid_target")
    _reset_route("invalid_target")
    return false, "invalid_target"
  end
  _ensure_context(tgt)
  return true, tgt
end

function MGD.attack_function(arg)
  local ctx, preview = _attack_opts(arg)
  local ok, info = MGD.can_run(ctx)
  if not ok then
    if preview then return nil, info end
    return false, info
  end

  local tgt = info
  if MGD.state.last_target ~= "" and not same_target(MGD.state.last_target, tgt) then
    RC.clear_pending_all(MGD.state, PENDING_SLOTS)
  end
  MGD.state.last_target = tgt

  local cmd, category, st, reason = _select_command(tgt)
  if not (category == "special" and not cmd) and RC.eq_ready() then
    local selected, purge_reason = RC.with_bloodboil(cmd)
    cmd = selected
    if purge_reason then category, reason = "self_purge", purge_reason end
  end
  MGD.state.template.last_reason = reason
  MGD.state.template.last_target = tgt
  _update_explain(tgt, st, category, reason, cmd)

  if not cmd or cmd == "" then
    MGD.state.template.last_payload = nil
    if preview then return nil, reason end
    return false, reason
  end

  local payload = {
    route = "magi_group_damage",
    target = tgt,
    lanes = { eq = cmd },
    meta = {
      main_lane = "eq",
      main_category = category,
      main_reason = reason,
      state = st,
      explain = MGD.state.explain,
    },
  }

  MGD.state.template.last_payload = { eq = cmd, meta = payload.meta }

  if preview then return payload end

  local queued_payload = { eq = cmd, target = tgt }
  local sent, emit_detail, ack_payload = _emit_payload(queued_payload, category)
  if sent ~= true then return false, emit_detail or "emit_failed" end
  RC.note_special_queued(cmd, tgt)
  if RI and type(RI.mark_waiting) == "function" then
    RI.mark_waiting(MGD.state, "magi_group_damage", ack_payload or queued_payload, {
      cmd = trim(cmd),
      target = tgt,
      main_lane = "eq",
    })
  end
  local has_ack_bus = Yso and Yso.locks and type(Yso.locks.note_payload) == "function"
  local dry_run = (Yso and Yso.net and Yso.net.cfg and Yso.net.cfg.dry_run == true)
  local queue_live = Yso and Yso.queue and type(Yso.queue.commit) == "function"
  if (not has_ack_bus or dry_run or not queue_live) and type(MGD.on_payload_queued) == "function" then
    pcall(MGD.on_payload_queued, ack_payload or queued_payload)
  end

  MGD.state.last_cmd = cmd
  MGD.state.last_category = category
  return true, cmd, payload
end

function MGD.build_payload(ctx)
  return MGD.attack_function({ ctx = ctx, preview = true })
end

function MGD.build(reason)
  local ctx = type(reason) == "table" and reason or { reason = tostring(reason or "") }
  return MGD.build_payload(ctx)
end

function MGD.evaluate(ctx)
  local payload, why = MGD.build_payload(ctx)
  if not payload then return { ok = false, reason = why } end
  return { ok = true, payload = payload }
end

function MGD.explain()
  MGD.init()
  local ex = type(MGD.state.explain) == "table" and MGD.state.explain or {}
  local tgt = RC.get_target()
  local st = _effective_state(tgt)
  ex.route = "magi_group_damage"
  ex.enabled = MGD.is_enabled()
  ex.route_enabled = MGD.is_enabled()
  ex.active = MGD.is_active()
  ex.target = tgt
  ex.last_reason = MGD.state and MGD.state.template and MGD.state.template.last_reason or ""
  ex.last_disable_reason = MGD.state and MGD.state.template and MGD.state.template.last_disable_reason or ""
  ex.last_cmd = MGD.state and MGD.state.last_cmd or ""
  ex.last_sent_cmd = MGD.state and MGD.state.last_sent_cmd or ""
  ex.decision = ex.decision or (MGD.state and MGD.state.last_category or "")
  ex.branch_stage = (st.route and st.route.branch_stage) or ex.branch_stage or ""
  ex.freeze_step_done = st.freeze_step_done == true
  ex.fire_branch_eligible = st.fire_branch_eligible == true
  ex.state = st
  ex.pending = MGD.state and MGD.state.pending or {}
  return ex
end

function MGD.status()
  return MGD.explain()
end

function MGD.on_payload_queued(payload)
  _payload_each_eq(payload, function(cmd)
    cmd = trim(cmd)
    if cmd == "" then return end

    local cmd_lc = lc(cmd)
    MGD.state.last_sent_cmd = cmd
    MGD.state.last_sent_at = now()

    local horr_tgt = _capture_target(cmd_lc, "^staff%s+cast%s+horripilation%s+(.+)$")
    if horr_tgt ~= "" then
      MGD.state.last_sent_target = horr_tgt
      MGD.state.last_sent_category = "opener_setup"
      RC.mark_pending(MGD.state,"horripilation", horr_tgt, MGD.cfg.horripilation_pending_s)
      _set_branch_stage(horr_tgt, "opener_setup")
      return
    end

    local freeze_tgt = _capture_target(cmd_lc, "^cast%s+freeze%s+at%s+(.+)$")
    if freeze_tgt ~= "" then
      local _, route = _ensure_context(freeze_tgt)
      route.freeze_step_done = true
      route.branch_stage = "freeze_setup"
      MGD.state.last_sent_target = freeze_tgt
      MGD.state.last_sent_category = "freeze_setup"
      RC.mark_pending(MGD.state,"freeze", freeze_tgt, MGD.cfg.freeze_pending_s)
      return
    end

    local mud_tgt = _capture_target(cmd_lc, "^cast%s+mudslide%s+at%s+(.+)$")
    if mud_tgt ~= "" then
      MGD.state.last_sent_target = mud_tgt
      MGD.state.last_sent_category = "salve_pressure"
      RC.mark_pending(MGD.state,"mudslide", mud_tgt, MGD.cfg.mudslide_pending_s)
      _set_branch_stage(mud_tgt, "salve_pressure")
      return
    end

    local ema_water_tgt = _capture_target(cmd_lc, "^cast%s+emanation%s+at%s+(.+)%s+water$")
    if ema_water_tgt ~= "" then
      MGD.state.last_sent_target = ema_water_tgt
      MGD.state.last_sent_category = "disrupt_setup"
      RC.mark_pending(MGD.state,"emanation_water", ema_water_tgt, MGD.cfg.water_emanation_pending_s)
      _set_branch_stage(ema_water_tgt, "disrupt_setup")
      return
    end

    local magma_tgt = _capture_target(cmd_lc, "^cast%s+magma%s+at%s+(.+)$")
    if magma_tgt ~= "" then
      MGD.state.last_sent_target = magma_tgt
      MGD.state.last_sent_category = "salve_pressure"
      RC.mark_pending(MGD.state,"magma", magma_tgt, MGD.cfg.magma_pending_s)
      _set_branch_stage(magma_tgt, "fire_build")
      return
    end

    local firelash_tgt = _capture_target(cmd_lc, "^cast%s+firelash%s+at%s+(.+)$")
    if firelash_tgt ~= "" then
      MGD.state.last_sent_target = firelash_tgt
      MGD.state.last_sent_category = "fire_build"
      RC.mark_pending(MGD.state,"firelash", firelash_tgt, MGD.cfg.firelash_pending_s)
      _set_branch_stage(firelash_tgt, "fire_build")
      return
    end

    local conflagrate_tgt = _capture_target(cmd_lc, "^cast%s+conflagrate%s+at%s+(.+)$")
    if conflagrate_tgt ~= "" then
      MGD.state.last_sent_target = conflagrate_tgt
      MGD.state.last_sent_category = "fire_payoff"
      RC.mark_pending(MGD.state,"conflagrate", conflagrate_tgt, MGD.cfg.conflagrate_pending_s)
      _set_branch_stage(conflagrate_tgt, "fire_payoff")
      return
    end

    local ema_fire_tgt = _capture_target(cmd_lc, "^cast%s+emanation%s+at%s+(.+)%s+fire$")
    if ema_fire_tgt ~= "" then
      MGD.state.last_sent_target = ema_fire_tgt
      MGD.state.last_sent_category = "fire_promotion"
      RC.mark_pending(MGD.state,"emanation_fire", ema_fire_tgt, MGD.cfg.fire_emanation_pending_s)
      _set_branch_stage(ema_fire_tgt, "fire_promotion")
      return
    end

    local glaciate_tgt = _capture_target(cmd_lc, "^cast%s+glaciate%s+at%s+(.+)$")
    if glaciate_tgt ~= "" then
      MGD.state.last_sent_target = glaciate_tgt
      MGD.state.last_sent_category = "glaciate_burst"
      RC.mark_pending(MGD.state,"glaciate", glaciate_tgt, MGD.cfg.glaciate_pending_s)
      _set_branch_stage(glaciate_tgt, "glaciate_burst")
      return
    end
  end)
end

function MGD.on_payload_sent(payload)
  if RI and type(RI.payload_has_any_route) == "function" and RI.payload_has_any_route(payload)
    and not RI.payload_has_route(payload, "magi_group_damage")
  then
    return false
  end
  if RI and type(RI.clear_waiting_on_ack) == "function" then
    RI.clear_waiting_on_ack(MGD.state, "magi_group_damage", payload, { require_route = false })
  end
  return MGD.on_payload_queued(payload)
end

function MGD.on_payload_fired(payload)
  payload = payload or {}
  MGD.state.last_fired_cmd = trim(payload.eq or payload.cmd or "")
  MGD.state.last_fired_at = now()
end

function MGD.on_enter(ctx)
  MGD.init()
  return true
end

function MGD.on_exit(ctx)
  if Yso and Yso.mode and type(Yso.mode.stop_route_loop) == "function" then
    Yso.mode.stop_route_loop("magi_group_damage", "exit", true)
  end
  MGD.reset("exit")
  return true
end

function MGD.on_target_swap(old_target, new_target)
  if not same_target(old_target, new_target) then
    RC.clear_pending_all(MGD.state, PENDING_SLOTS)
    _reset_cold("target_swap")
    _reset_route("target_swap")
    _clear_runtime_state("target_swap")
    if MGD.state.loop_enabled == true then
      MGD.schedule_loop(0)
    end
  end
  return true
end

function MGD.on_pause(ctx)
  return true
end

function MGD.on_resume(ctx)
  if MGD.state and MGD.state.loop_enabled == true then
    MGD.schedule_loop(0)
  end
  return true
end

function MGD.on_manual_success(ctx)
  if MGD.state and MGD.state.loop_enabled == true then
    MGD.schedule_loop(MGD.state.loop_delay)
  end
  return true
end

function MGD.on_send_result(payload, ctx)
  MGD.on_payload_fired(payload)
  return true
end

function MGD.schedule_loop(delay)
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    return Yso.mode.schedule_route_loop("magi_group_damage", delay)
  end
  return false
end

MGD.alias_loop_stop_details = MGD.alias_loop_stop_details or {
  inactive = true,
  disabled = true,
  no_target = true,
  invalid_target = true,
  wrong_class = true,
}

function MGD.alias_loop_prepare_start(ctx)
  MGD.init()
  return ctx or {}
end

function MGD.alias_loop_on_started(ctx)
  RC.clear_pending_all(MGD.state, PENDING_SLOTS)
  _reset_cold("loop_start")
  _reset_route("loop_start")
  _clear_runtime_state("loop_start")
  _echo("Group damage loop ON.")
  local tgt = RC.get_target()
  if tgt == "" then
    _echo("No target yet; holding.")
  elseif not RC.target_valid(tgt) then
    _echo(string.format("%s is not in room; holding.", tgt))
  end
end

function MGD.alias_loop_on_stopped(ctx)
  MGD.init()
  ctx = ctx or {}
  local reason = tostring(ctx.reason or "manual")
  RC.clear_pending_all(MGD.state, PENDING_SLOTS)
  _reset_cold(reason)
  _reset_route(reason)
  _clear_runtime_state(reason)
  MGD.state.template.last_disable_reason = reason
  if ctx.silent ~= true then
    _echo(string.format("Group damage loop OFF (%s).", reason))
  end
end

function MGD.alias_loop_waiting_blocks()
  return false
end

function MGD.alias_loop_clear_waiting()
  if RI and type(RI.clear_waiting) == "function" then
    return RI.clear_waiting(MGD.state, "magi_group_damage")
  end
  return true
end

function MGD.alias_loop_on_error(err)
  _echo("Magi team damage loop error: " .. tostring(err))
end

if Yso and Yso.off and Yso.off.core and type(Yso.off.core.register) == "function" then
  pcall(Yso.off.core.register, "magi_group_damage", MGD)
end

-- return omitted: alias body assigns Yso.off.magi.group_damage above

-- ^mdam$ alias entry: toggle group-damage loop (route id magi_group_damage).
Yso.util = Yso.util or {}
if type(Yso.util.toggle_route_alias) ~= "function" then
  if type(cecho) == "function" then
    cecho("<orange>[YSO] route controller unavailable; check Mudlet load order.<reset>\n")
  end
  return
end
local ok, why = Yso.util.toggle_route_alias("magi_group_damage", "alias:mdam")
if ok ~= true and type(cecho) == "function" then
  cecho("<SlateBlue>[YSO] mdam toggle failed: " .. tostring(why or "unknown") .. "<reset>\n")
end
