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

-- Pet orders have no BAL/EQ cost and must stay outside spell queue/pending gates.
-- Keep this state on the reused core so reloading the Focus alias does not spam.
RC.entourage = RC.entourage or {}
local function entourage_dispatch(command)
  if Yso.net and Yso.net.cfg and Yso.net.cfg.dry_run == true then return false end
  if type(Yso.send) == "function" then
    local ok, result = pcall(Yso.send, command)
    return ok and result == true
  end
  if type(send) ~= "function" then return false end
  local ok, result = pcall(send, command, false)
  return ok and result ~= false
end

function RC.entourage_sync(route, target, is_magi, preview)
  if preview or not is_magi then return false end
  if not route.is_enabled() or not route.is_active() then return false end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return false end
  target = RC.trim(target)
  if not target:match("^[A-Za-z][A-Za-z'%-]*$") or not RC.target_valid(target) then return false end
  if Yso.net and Yso.net.cfg and Yso.net.cfg.dry_run == true then return false end
  local E = RC.entourage
  if E.owner == route and RC.same_target(E.target, target) then return true end
  -- Dispatch may throw after transmitting; still allow stop cleanup in that case.
  E.owner, E.needs_passive, E.target = route, true, nil
  if not entourage_dispatch("order entourage kill " .. target) then return false end
  E.target = target
  return true
end

function RC.entourage_passive(route)
  local E = RC.entourage
  if E.owner ~= route or not E.needs_passive then return true end
  if not entourage_dispatch("order entourage passive") then return false end
  E.owner, E.target, E.needs_passive = nil, nil, false
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
  local C = Yso.magi and Yso.magi.convergence
  if C and type(C.note_queued) == "function" then C.note_queued(cmd, tgt) end
end

-- Remove obsolete automatic-purge state and functions when reloading a reused core.
RC.bloodboil = nil
RC.bloodboil_note_cast = nil
RC.bloodboil_note_ready = nil
RC.bloodboil_note_eq_recovered = nil
RC.bloodboil_command = nil
RC.with_bloodboil = nil

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
-- Magi dissonance tracker
--  * Lightweight local inference for the Focus route.
--  * Tracks estimated stage, confidence, and last evidence by target.
--========================================================--

Yso = Yso or {}
Yso.magi = Yso.magi or {}
Yso.magi.dissonance = Yso.magi.dissonance or {}

local D = Yso.magi.dissonance

D.state = D.state or {
  by_target = {},
}

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _lc(s)
  return _trim(s):lower()
end

local function _now()
  local RC = Yso and Yso.off and Yso.off.magi and Yso.off.magi.route_core or nil
  if type(RC) == "table" and type(RC.now) == "function" then
    return RC.now()
  end
  if type(getEpoch) == "function" then
    local v = tonumber(getEpoch()) or os.time()
    if v > 20000000000 then v = v / 1000 end
    return v
  end
  return os.time()
end

local CONF_RANK = {
  low = 1,
  medium = 2,
  high = 3,
}

local function _merge_conf(cur, new)
  cur = _lc(cur)
  new = _lc(new)
  if new ~= "" and not CONF_RANK[new] and type(cecho) == "function" then
    cecho(string.format("<yellow>[Magi:Dissonance] <reset>Unknown confidence level '%s'; keeping current value.\n", tostring(new)))
  end
  if CONF_RANK[new] and CONF_RANK[new] > (CONF_RANK[cur] or 0) then
    return new
  end
  return (CONF_RANK[cur] and cur) or "low"
end

local function _slot(target, create)
  target = _lc(target)
  if target == "" then return nil end
  local row = D.state.by_target[target]
  if row or create == false then return row end
  row = {
    target = target,
    stage = 0,
    confidence = "low",
    last_evidence = "",
    updated_at = 0,
  }
  D.state.by_target[target] = row
  return row
end

local function _copy(row, target)
  row = row or {}
  return {
    target = _trim(target or row.target or ""),
    stage = tonumber(row.stage or 0) or 0,
    confidence = _lc(row.confidence or "low"),
    last_evidence = tostring(row.last_evidence or ""),
    updated_at = tonumber(row.updated_at or 0) or 0,
  }
end

function D.reset()
  D.state.by_target = {}
  return true
end

function D.reset_target(target)
  target = _lc(target)
  if target ~= "" then
    D.state.by_target[target] = nil
  end
  return true
end

function D.note(target, token, opts)
  local row = _slot(target, true)
  if not row then return false end

  token = _lc(token)
  opts = type(opts) == "table" and opts or {}

  local stage = tonumber(opts.stage)
  local confidence = _lc(opts.confidence or "")
  local evidence = tostring(opts.evidence or token)

  if token == "route_send" or token == "send" or token == "embed" then
    stage = math.min(4, math.max(row.stage or 0, (row.stage or 0) + 1))
    confidence = (confidence ~= "" and confidence) or "low"
  elseif token == "resonance" then
    stage = math.max(row.stage or 0, math.max(tonumber(opts.min_stage or 1) or 1, 1))
    confidence = (confidence ~= "" and confidence) or "medium"
  elseif token == "tracked" then
    stage = math.max(row.stage or 0, tonumber(opts.stage or 1) or 1)
    confidence = (confidence ~= "" and confidence) or "medium"
  elseif token == "clear" or token == "reset" then
    stage = 0
    confidence = (confidence ~= "" and confidence) or "low"
    row.stage = 0
    row.confidence = confidence
    row.last_evidence = evidence
    row.updated_at = _now()
    return true, _copy(row)
  end

  if stage ~= nil then
    if stage < 0 then stage = 0 end
    if stage > 4 then stage = 4 end
    row.stage = stage
  end
  row.confidence = _merge_conf(row.confidence, confidence ~= "" and confidence or row.confidence)
  row.last_evidence = evidence
  row.updated_at = _now()
  return true, _copy(row)
end

function D.snapshot(target)
  target = _trim(target)
  if target == "" then
    return _copy(nil, target)
  end
  return _copy(_slot(target, false), target)
end

-- return omitted: alias body uses Yso.magi.dissonance

--========================================================--
-- magi_focus.lua
--  * Duel affliction / convergence route for Magi.
--  * Mudlet-primary copy lives in ^mfocus$ alias (Magi/mfocus_alias_body.lua; includes route_core + dissonance).
--  * Keeps route-local priorities local while sharing chassis helpers.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.magi = Yso.off.magi or {}
Yso.magi = Yso.magi or {}

Yso.off.magi.focus = Yso.off.magi.focus or {}
local MF = Yso.off.magi.focus
MF.alias_owned = true

Yso.off.magi.route_core = Yso.off.magi.route_core or {}
local RC = Yso.off.magi.route_core

Yso.magi.dissonance = Yso.magi.dissonance or {}
local Dissonance = Yso.magi.dissonance

local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil

local PENDING_SLOTS = {
  "hellfumes",
  "pebble",       -- Conditional earth seed; confirmation comes from resonance feedback.
  "horripilation", --gives waterbonds
  "dehydrate",     -- Nausea/weariness; existing weariness gives burning, otherwise existing nausea gives freeze. Never both stacks.
  "mudslide",      -- Slickness against a frozen target.
  "lightning",     -- Stupidity with both Shock and Lightning staff crystals fitted.
  "emanation",     -- Spends major resonance for the selected element.
  "freeze",        --strips insulation defence, otherwise it will give shivering, then freeze state.
  "bombard",       --gives clumsiness
  "fulminate",     --class mechanic. Gives fulmianted affliction. If they already have fulminated, then it gives epilepsy. If they already have epilepsy, then it gives paralysis.
  "firelash",
  "magma",
  "dissonance",
  "convergence",
  "destroy",
}

MF.route_contract = MF.route_contract or {
  id = "magi_focus",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "opener_setup",
    "freeze_reopen",
    "resonance_progress",
    "fulminate_branch",
    "dissonance_push",
    "convergence_now",
    "postconv_finish",
    "maintenance",
    "lock_pressure",
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
  local categories = MF.route_contract.route_local_categories
  local found = false
  for _, category in ipairs(categories) do
    if category == "lock_pressure" then found = true end
  end
  if not found then categories[#categories + 1] = "lock_pressure" end
  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(MF, MF.route_contract)
  end
end

MF.cfg = MF.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,
  same_target_repeat_s = 0.75,
  hellfumes_pending_s = 1.00,
  pebble_pending_s = 1.00,
  horripilation_pending_s = 1.00,
  dehydrate_pending_s = 1.00,
  mudslide_pending_s = 1.00,
  lightning_pending_s = 1.00,
  emanation_pending_s = 2.40,
  shock_lightning_enabled = true,
  freeze_pending_s = 1.00,
  bombard_pending_s = 1.00,
  fulminate_pending_s = 1.00,
  firelash_pending_s = 1.00,
  magma_pending_s = 1.00,
  dissonance_pending_s = 4.00,
  convergence_pending_s = 1.00,
  destroy_pending_s = 1.00,
  destroy_hp_threshold = 40,
  destroy_require_conflagration = true,
  destroy_enforce_hp_gate = false,
}

MF.state = MF.state or {
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
  pending = {},
  route = {
    target = "",
    room_id = "",
    phase = "reset",
    subphase = "reset",
    bucket = "reset",
    postconv = false,
    last_reset_reason = "init",
  },
  waiting = { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" },
  in_flight = { fingerprint = "", target = "", route = "magi_focus", at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" },
}

local function _trim(s) return RC.trim(s) end
local function _lc(s) return RC.lc(s) end
local function _same_target(a, b) return RC.same_target(a, b) end
local function _now() return RC.now() end

local function _echo(msg)
  if MF.cfg.echo ~= true then return end
  if type(cecho) == "function" then
    cecho(string.format("<cadet_blue>[Yso:Magi] <reset>%s\n", tostring(msg)))
  elseif type(echo) == "function" then
    echo(string.format("[Yso:Magi] %s\n", tostring(msg)))
  end
end

local function _current_class()
  local C = Yso and Yso.classinfo or nil
  if type(C) == "table" then
    if type(C.get) == "function" then
      local ok, v = pcall(C.get)
      if ok and type(v) == "string" and _trim(v) ~= "" then return v end
    end
    if type(C.current_class) == "function" then
      local ok, v = pcall(C.current_class)
      if ok and type(v) == "string" and _trim(v) ~= "" then return v end
    end
  end

  local gmcp = rawget(_G, "gmcp")
  local cls = gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class or nil
  if type(cls) == "string" and _trim(cls) ~= "" then return cls end
  if type(Yso.class) == "string" and _trim(Yso.class) ~= "" then return Yso.class end
  return ""
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

  return _lc(_current_class()) == "magi"
end

local function _target() return RC.get_target() end
local function _room_id() return RC.room_id() end
local function _tgt_valid(tgt) return RC.target_valid(tgt) end
local function _eq_ready() return RC.eq_ready() end
local function _score_positive(aff) return RC.has_aff(aff) end

local function _kelpscore()
  local A = rawget(_G, "affstrack")
  if type(A) == "table" and tonumber(A.kelpscore) then
    return tonumber(A.kelpscore) or 0
  end
  return 0
end

local function _combat_focus_context_active()
  return _is_magi() and Yso and Yso.mode and type(Yso.mode.is_combat) == "function" and Yso.mode.is_combat() == true
end

local function _route_is_active()
  if not _combat_focus_context_active() then return false end
  if Yso and Yso.mode and type(Yso.mode.route_loop_active) == "function" then
    if Yso.mode.route_loop_active("magi_focus") == true then return true end
    if Yso.mode.route_loop_active("focus") == true then return true end
    return false
  end
  return MF.state and MF.state.loop_enabled == true
end

local function _set_loop_enabled(on)
  local enabled = (on == true)
  MF.state.enabled = enabled
  MF.state.loop_enabled = enabled
  MF.cfg.enabled = enabled
end

local function _pending_slot(name) return RC.pending_slot(MF.state, name) end
local function _clear_pending(name) return RC.clear_pending(MF.state, name) end
local function _clear_pending_all() return RC.clear_pending_all(MF.state, PENDING_SLOTS) end
local function _mark_pending(name, tgt, seconds) return RC.mark_pending(MF.state, name, tgt, seconds) end
local function _pending_active(name, tgt) return RC.pending_active(MF.state, name, tgt) end

local function _spell_guard(slot_name, tgt, cmd)
  return RC.guard_spell({
    state = MF.state,
    cfg = MF.cfg,
    slot = slot_name,
    target = tgt,
    cmd = cmd,
    target_valid = _tgt_valid(tgt),
    eq_ready = _eq_ready(),
  })
end

local function _route_slot()
  MF.state.route = MF.state.route or {
    target = "",
    room_id = "",
    phase = "reset",
    subphase = "reset",
    bucket = "reset",
    postconv = false,
    last_reset_reason = "init",
  }
  return MF.state.route
end

local function _reset_route(reason)
  local route = _route_slot()
  route.target = ""
  route.room_id = ""
  route.phase = "reset"
  route.subphase = "reset"
  route.bucket = "reset"
  route.postconv = false
  route.opening_dehydrate_done = false
  route.last_reset_reason = tostring(reason or "")
  return route
end

local function _ensure_context(tgt)
  local room = _room_id()
  local route = _route_slot()
  local room_changed = route.room_id ~= "" and room ~= "" and route.room_id ~= room
  local target_changed = route.target ~= "" and tgt ~= "" and not _same_target(route.target, tgt)

  if room_changed then
    route = _reset_route("room_change")
    _clear_pending_all()
  elseif target_changed then
    route = _reset_route("target_change")
    _clear_pending_all()
  end

  route.target = _trim(tgt or "")
  route.room_id = room
  return route
end

local function _set_route_stage(tgt, phase, subphase, bucket)
  local route = _ensure_context(tgt)
  route.phase = tostring(phase or "")
  route.subphase = tostring(subphase or "")
  route.bucket = tostring(bucket or "")
  return route
end

local function _set_postconv(tgt, on)
  local route = _ensure_context(tgt)
  route.postconv = (on == true)
  if route.postconv == true and route.phase ~= "postconv" then
    route.phase = "postconv"
  end
  return route
end

local function _freeze_package_intact(st)
  return (st.frozen == true and st.frostbite == true) or st.pending.freeze == true
end

local function _focus_armed()
  local crystal = Yso and Yso.magi and Yso.magi.crystalism or nil
  if type(crystal) == "table" and type(crystal.has_focus) == "function" then
    local ok, v = pcall(crystal.has_focus)
    if ok then return v == true end
  end
  return false
end

local function _hellfumes_up()
  local H = Yso and Yso.magi and Yso.magi.hellfumes
  if type(H) ~= "table" then return false end
  if type(H.is_up) == "function" then
    local ok, v = pcall(H.is_up)
    if ok then return v == true end
  end
  return H.active == true
end

local function _fulm_stage_from_state(st)
  if st.paralysis == true then return 3 end
  if st.epilepsy == true then return 2 end
  if st.fulminated == true or st.pending.fulminate == true then return 1 end
  return 0
end

local function _fulm_reason(st)
  if st.epilepsy ~= true and st.fulminated == true then return "epilepsy_missing" end
  if st.paralysis ~= true and st.epilepsy == true then return "paralysis_missing" end
  if st.fulm_stage <= 0 then return "fulminate_seed" end
  if st.fulm_stage == 1 then return "epilepsy_missing" end
  if st.fulm_stage == 2 then return "paralysis_missing" end
  return "fulminate_live"
end

local function _destroy_aff_present(st)
  return st.conflagrate == true or st.conflagration == true
end

local function _target_hp_percent()
  if Yso and Yso.magi and Yso.magi.elemental and type(Yso.magi.elemental.get_target_hp_percent) == "function" then
    local ok, v = pcall(Yso.magi.elemental.get_target_hp_percent)
    if ok and tonumber(v) then return tonumber(v) end
  end
  return nil
end

local function _destroy_window()
  if MF.cfg.destroy_enforce_hp_gate == true then
    local hp = _target_hp_percent()
    if hp == nil then return false, "hp_unknown", "unknown" end
    if hp > (tonumber(MF.cfg.destroy_hp_threshold or 40) or 40) then
      return false, "hp_window_closed", string.format("%.1f>%d", hp, tonumber(MF.cfg.destroy_hp_threshold or 40) or 40)
    end
    return true, "", string.format("%.1f<=%d", hp, tonumber(MF.cfg.destroy_hp_threshold or 40) or 40)
  end
  return true, "", "stubbed"
end

local function _conv_missing(res)
  local out = {}
  if tonumber(res.air or 0) < 2 then out[#out + 1] = "air" end
  if tonumber(res.earth or 0) < 2 then out[#out + 1] = "earth" end
  if tonumber(res.fire or 0) < 2 then out[#out + 1] = "fire" end
  if tonumber(res.water or 0) < 2 then out[#out + 1] = "water" end
  return out
end

local function _next_conv_gate(st)
  if #st.conv_missing > 0 then return "moderate:" .. table.concat(st.conv_missing, "/") end
  if st.dissonance_stage < 4 then return "dissonance:" .. tostring(st.dissonance_stage) end
  return "ready"
end

local function _conv_blocker(st)
  if st.lock_ready ~= true then
    if #st.lock_missing_core > 0 then return "lock_missing:" .. table.concat(st.lock_missing_core, "/") end
    return "lock_mentals:" .. tostring(st.mental_count) .. "/2"
  end
  if #st.conv_missing > 0 then
    return "missing_moderate:" .. table.concat(st.conv_missing, "/")
  end
  if st.dissonance_stage < 4 then
    return "dissonance_stage_" .. tostring(st.dissonance_stage)
  end
  return ""
end

local function _choose_threshold_rule(st)
  if st.postconv == true then return "postconv_overlay" end
  if st.fulminate_need == true then
    return "kelp_pressure_established"
  end
  if st.bombard_need == true then
    return st.bombard_reason
  end
  if tonumber(st.res.fire or 0) < 2 then
    return "fire_moderate_missing"
  end
  if st.dissonance_stage < 4 then
    return "dissonance_stage_" .. tostring(st.dissonance_stage)
  end
  return "maintenance"
end

local function _snapshot(tgt)
  local base = RC.build_snapshot({
    state = MF.state,
    target = tgt,
    affs = {
      "waterbonds",
      "nausea",
      "weariness",
      "frozen",
      "frostbite",
      "clumsiness",
      "asthma",
      "fulminated",
      "epilepsy",
      "paralysis",
      "dissonance",
      "conflagrate",
      "conflagration",
      "scalded",
      "slickness",
      "anorexia",
      "dizziness",
      "stupidity",
      "ablaze",
    },
    pending_slots = PENDING_SLOTS,
  })
  local route = _ensure_context(tgt)
  local dis = Dissonance.snapshot(tgt)

  if tonumber(base.raw.dissonance or 0) > 0 and tonumber(dis.stage or 0) < 1 then
    Dissonance.note(tgt, "tracked", { stage = 1, confidence = "medium", evidence = "ak_dissonance" })
    dis = Dissonance.snapshot(tgt)
  end

  local st = {
    target = base.target,
    room_id = base.room_id,
    target_valid = base.target_valid,
    eq_ready = base.eq_ready,
    waterbonds = base.waterbonds == true or base.pending.horripilation == true,
    frozen = base.frozen == true,
    frostbite = base.frostbite == true,
    clumsiness = base.clumsiness == true or base.pending.bombard == true,
    -- Bombard directly inflicts clumsiness, not asthma; asthma comes from Air
    -- resonance procs, so only trust the actual aff state here.
    asthma = base.asthma == true,
    fulminated = base.fulminated == true,
    epilepsy = base.epilepsy == true,
    paralysis = base.paralysis == true,
    dissonance = base.dissonance == true,
    conflagrate = base.conflagrate == true,
    conflagration = base.conflagration == true,
    scalded = base.scalded == true or base.pending.magma == true,
    slickness = base.slickness == true,
    anorexia = base.anorexia == true,
    dizziness = base.dizziness == true,
    stupidity = base.stupidity == true,
    nausea = base.nausea == true,
    weariness = base.weariness == true,
    ablaze = base.ablaze == true,
    kelpscore = _kelpscore(),
    res = {
      air = tonumber(base.res.air or 0) or 0,
      earth = tonumber(base.res.earth or 0) or 0,
      fire = tonumber(base.res.fire or 0) or 0,
      water = tonumber(base.res.water or 0) or 0,
      synced = base.res.synced == true,
    },
    pending = base.pending,
    raw = base.raw,
    hellfumes = _hellfumes_up() or base.pending.hellfumes == true,
    route = {
      target = route.target,
      room_id = route.room_id,
      phase = route.phase,
      subphase = route.subphase,
      bucket = route.bucket,
      postconv = route.postconv == true,
      opening_dehydrate_done = route.opening_dehydrate_done == true,
      last_reset_reason = route.last_reset_reason,
    },
    focus_punish_armed = _focus_armed(),
    dissonance_stage = tonumber(dis.stage or 0) or 0,
    dissonance_confidence = tostring(dis.confidence or "low"),
    dissonance_last_evidence = tostring(dis.last_evidence or ""),
  }

  -- Shared snapshot booleans include uncertain scores. Lock gates require confirmation.
  for _, aff in ipairs({ "asthma", "slickness", "paralysis", "anorexia", "epilepsy", "stupidity", "dizziness" }) do
    st[aff] = tonumber(st.raw[aff] or 0) >= 100
  end
  st.fulm_stage = _fulm_stage_from_state(st)
  st.pebble_needed = tonumber(st.raw.scalded or 0) < 100 and st.res.earth == 0
  st.epilepsy_live = st.epilepsy == true
  st.para_conversion_ready = st.fulm_stage == 2
  st.lock_missing_core = {}
  for _, aff in ipairs({ "asthma", "slickness", "paralysis", "anorexia" }) do
    if st[aff] ~= true then st.lock_missing_core[#st.lock_missing_core + 1] = aff end
  end
  st.mental_count = 0
  for _, aff in ipairs({ "epilepsy", "stupidity", "dizziness" }) do
    if st[aff] == true then st.mental_count = st.mental_count + 1 end
  end
  st.lock_ready = #st.lock_missing_core == 0 and st.mental_count >= 2
  st.conv_missing = _conv_missing(st.res)
  st.conv_ready = st.lock_ready and (#st.conv_missing == 0) and st.dissonance_stage >= 4
  st.conv_blocker = _conv_blocker(st)
  st.next_gate = _next_conv_gate(st)
  st.postconv = st.route.postconv == true
  st.freeze_package_intact = _freeze_package_intact(st)
  st.freeze_missing = st.freeze_package_intact ~= true
  st.water_moderate_ready = tonumber(st.res.water or 0) >= 2
  st.freeze_requires_water_refresh = st.freeze_missing == true and st.water_moderate_ready ~= true

  st.bombard_reason = ""
  if st.clumsiness ~= true then
    st.bombard_reason = "clumsiness_missing"
  elseif st.asthma ~= true then
    st.bombard_reason = "asthma_missing"
  elseif st.res.air < 2 and st.res.earth < 2 then
    st.bombard_reason = "air_earth_moderate_missing"
  elseif st.res.air < 2 then
    st.bombard_reason = "air_moderate_missing"
  elseif st.res.earth < 2 then
    st.bombard_reason = "earth_moderate_missing"
  end
  st.bombard_need = st.bombard_reason ~= ""
  st.fulminate_need = st.paralysis ~= true or (st.mental_count < 2 and st.epilepsy ~= true)
  st.threshold_rule = _choose_threshold_rule(st)

  local hp_open, hp_blocker, hp_window = _destroy_window()
  st.destroy_ready = st.postconv == true and _destroy_aff_present(st) and hp_open == true
  st.destroy_blocker = ""
  if st.postconv ~= true then
    st.destroy_blocker = "postconv_required"
  elseif MF.cfg.destroy_require_conflagration ~= false and not _destroy_aff_present(st) then
    st.destroy_blocker = "conflagration_missing"
  elseif hp_open ~= true then
    st.destroy_blocker = hp_blocker
  end
  st.destroy_hp_window = hp_window
  return st
end

local function _can_staffcast_horripilation(tgt)
  local cmd = ("staff cast horripilation %s"):format(tgt)
  local ok, why = _spell_guard("horripilation", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_hellfumes(tgt)
  local cmd = "cast hellfumes"
  local ok, why = _spell_guard("hellfumes", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_pebble(tgt)
  local cmd = ("cast pebble at %s"):format(tgt)
  local ok, why = _spell_guard("pebble", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_freeze(tgt)
  local cmd = ("cast freeze at %s"):format(tgt)
  local ok, why = _spell_guard("freeze", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_bombard(tgt)
  local cmd = ("cast bombard at %s"):format(tgt)
  local ok, why = _spell_guard("bombard", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_fulminate(tgt)
  local cmd = ("cast fulminate at %s"):format(tgt)
  local ok, why = _spell_guard("fulminate", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_firelash(tgt)
  local cmd = ("cast firelash at %s"):format(tgt)
  local ok, why = _spell_guard("firelash", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_magma(tgt)
  local cmd = ("cast magma at %s"):format(tgt)
  local ok, why = _spell_guard("magma", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_convergence(tgt)
  local cmd = ("cast convergence at %s"):format(tgt)
  local ok, why = _spell_guard("convergence", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_destroy(tgt)
  local cmd = ("cast destroy at %s"):format(tgt)
  local ok, why = _spell_guard("destroy", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_or_embed_dissonance_builder(tgt)
  local cmd = "embed dissonance"
  local ok, why = _spell_guard("dissonance", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_dehydrate(tgt)
  local cmd = ("cast dehydrate at %s"):format(tgt)
  local ok, why = _spell_guard("dehydrate", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_mudslide(tgt)
  local cmd = ("cast mudslide at %s"):format(tgt)
  local ok, why = _spell_guard("mudslide", tgt, cmd)
  return ok, why, cmd
end

local function _can_staffcast_lightning(tgt)
  local cmd = ("staff cast lightning at %s"):format(tgt)
  local ok, why = _spell_guard("lightning", tgt, cmd)
  return ok, why, cmd
end

local function _can_cast_emanation(tgt, element)
  local cmd = ("cast emanation at %s %s"):format(tgt, element)
  local ok, why = _spell_guard("emanation", tgt, cmd)
  return ok, why, cmd
end

local function _choice(cmd, category, decision, reason, phase, subphase, bucket)
  return {
    cmd = cmd,
    category = category,
    decision = decision,
    reason = reason,
    phase = phase,
    subphase = subphase,
    bucket = bucket,
  }
end

local function _reject(rejects, decision, reason)
  rejects[#rejects + 1] = {
    decision = tostring(decision or ""),
    reason = tostring(reason or ""),
  }
end

local function _pick_bombard_revisit(st, rejects)
  if st.bombard_need ~= true then
    _reject(rejects, "bombard_revisit", "not_needed")
    return nil
  end
  local ok, why, cmd = _can_cast_bombard(st.target)
  if ok then
    return _choice(cmd, "resonance_progress", "bombard_revisit", st.bombard_reason, "progress", "bombard", "resonance_progress")
  end
  _reject(rejects, "bombard_revisit", why ~= "" and why or st.bombard_reason)
  return nil
end

local function _pick_fulminate_branch(st, rejects)
  if st.fulminate_need ~= true then
    _reject(rejects, "fulminate_continue", "not_needed")
    return nil
  end
  local ok, why, cmd = _can_cast_fulminate(st.target)
  if ok then
    return _choice(cmd, "fulminate_branch", "fulminate_continue", _fulm_reason(st), "progress", "fulminate", "fulminate_branch")
  end
  _reject(rejects, "fulminate_continue", why ~= "" and why or _fulm_reason(st))
  return nil
end

local function _pick_fire_progress(st, rejects)
  if tonumber(st.res.fire or 0) >= 2 then
    _reject(rejects, "fire_progress", "fire_moderate_ready")
    return nil
  end

  if st.scalded ~= true or tonumber(st.res.earth or 0) < 2 then
    local ok_magma, why_magma, cmd_magma = _can_cast_magma(st.target)
    if ok_magma then
      local why = (tonumber(st.res.earth or 0) < 2) and "fire_earth_progress" or "fire_progress_scalded"
      return _choice(cmd_magma, "resonance_progress", "fire_progress", why, "progress", "fire", "resonance_progress")
    end
    _reject(rejects, "fire_progress_magma", why_magma ~= "" and why_magma or "magma_blocked")
  end

  local ok, why, cmd = _can_cast_firelash(st.target)
  if ok then
    return _choice(cmd, "resonance_progress", "fire_progress", "fire_moderate_missing", "progress", "fire", "resonance_progress")
  end
  _reject(rejects, "fire_progress_firelash", why ~= "" and why or "firelash_blocked")
  return nil
end

local function _pick_dissonance_push(st, rejects)
  if st.dissonance_stage >= 4 then
    _reject(rejects, "dissonance_push", "stage_4")
    return nil
  end
  local ok, why, cmd = _can_cast_or_embed_dissonance_builder(st.target)
  if ok then
    return _choice(cmd, "dissonance_push", "dissonance_push", "dissonance_stage_" .. tostring(st.dissonance_stage), "gate", "dissonance", "dissonance_push")
  end
  _reject(rejects, "dissonance_push", why ~= "" and why or ("dissonance_stage_" .. tostring(st.dissonance_stage)))
  return nil
end

local function _pick_lock_pressure(st, rejects)
  local phase = st.postconv and "postconv" or "lock"
  local function attempt(builder, decision, reason, ...)
    local ok, why, cmd = builder(st.target, ...)
    if ok then
      return _choice(cmd, "lock_pressure", decision, reason, phase, decision, "lock_pressure")
    end
    _reject(rejects, decision, why ~= "" and why or reason)
    return nil
  end

  if not st.asthma then
    local choice = attempt(_can_cast_bombard, "lock_asthma", "asthma_missing")
    if choice then return choice end
  end
  if not st.slickness then
    local choice
    if not st.frozen then
      choice = attempt(_can_cast_freeze, "lock_freeze", "slickness_needs_frozen")
    else
      choice = attempt(_can_cast_mudslide, "lock_slickness", "slickness_missing")
    end
    if choice then return choice end
  end
  if not st.paralysis then
    local choice = attempt(_can_cast_fulminate, "lock_paralysis", _fulm_reason(st))
    if choice then return choice end
  end
  if not st.anorexia then
    -- Water resonance enables the passive proc; the proc message confirms anorexia.
    local choice = attempt(_can_cast_freeze, "lock_anorexia", "anorexia_missing")
    if choice then return choice end
  end
  if st.mental_count < 2 then
    if not st.epilepsy then
      local choice = attempt(_can_cast_fulminate, "lock_epilepsy", "epilepsy_missing")
      if choice then return choice end
    end
    if not st.stupidity and MF.cfg.shock_lightning_enabled ~= false then
      local choice = attempt(_can_staffcast_lightning, "lock_stupidity", "stupidity_missing")
      if choice then return choice end
    end
    if not st.dizziness then
      local choice
      if st.res.air >= 3 then
        choice = attempt(_can_cast_emanation, "lock_dizziness", "dizziness_missing", "air")
      else
        choice = attempt(_can_cast_bombard, "lock_air_build", "dizziness_needs_major_air")
      end
      if choice then return choice end
    end
  end
  return nil
end

local function _pick_resonance_fallback(st, rejects)
  local phase = st.postconv and "postconv" or "maintenance"
  for _, element in ipairs({ "earth", "fire", "water", "air" }) do
    if st.res[element] >= 3 then
      local ok, why, cmd = _can_cast_emanation(st.target, element)
      if ok then
        return _choice(cmd, "maintenance", "emanation_dump", "major_" .. element, phase, element, "maintenance")
      end
      _reject(rejects, "emanation_dump", why)
      return nil, why
    end
  end
  local ok, why, cmd = _can_cast_dehydrate(st.target)
  if ok then
    return _choice(cmd, "maintenance", "dehydrate_fallback", "no_major_resonance", phase, "dehydrate", "maintenance")
  end
  _reject(rejects, "dehydrate_fallback", why)
  return nil, why
end

local function _pick_postconv_action(st, rejects)
  if st.postconv ~= true then
    _reject(rejects, "postconv_action", "postconv_false")
    return nil
  end

  if st.destroy_ready == true then
    local ok, why, cmd = _can_cast_destroy(st.target)
    if ok then
      return _choice(cmd, "postconv_finish", "destroy_now", "destroy_ready", "postconv", "destroy", "postconv_finish")
    end
    _reject(rejects, "destroy_now", why ~= "" and why or "destroy_ready")
  else
    _reject(rejects, "destroy_now", st.destroy_blocker)
  end

  local lock = _pick_lock_pressure(st, rejects)
  if lock then return lock end

  if st.fulminate_need == true then
    local ok, why, cmd = _can_cast_fulminate(st.target)
    if ok then
      return _choice(cmd, "postconv_finish", "fulminate_continue", _fulm_reason(st), "postconv", "fulminate", "postconv_finish")
    end
    _reject(rejects, "postconv_fulminate", why ~= "" and why or _fulm_reason(st))
  end

  if st.scalded ~= true then
    local ok_magma, why_magma, cmd_magma = _can_cast_magma(st.target)
    if ok_magma then
      return _choice(cmd_magma, "postconv_finish", "burst_pressure", "postconv_magma_pressure", "postconv", "burst", "postconv_finish")
    end
    _reject(rejects, "postconv_magma", why_magma ~= "" and why_magma or "magma_blocked")
  end

  local fallback, fallback_blocker = _pick_resonance_fallback(st, rejects)
  if fallback then return fallback end
  if fallback_blocker then return nil end

  if st.freeze_missing == true then
    local ok, why, cmd = _can_cast_freeze(st.target)
    if ok then
      return _choice(cmd, "maintenance", "maintenance_refresh", "freeze_package_incomplete", "postconv", "maintenance", "maintenance")
    end
    _reject(rejects, "postconv_freeze", why ~= "" and why or "freeze_package_incomplete")
  end

  if st.bombard_need == true then
    local ok, why, cmd = _can_cast_bombard(st.target)
    if ok then
      return _choice(cmd, "maintenance", "maintenance_refresh", st.bombard_reason, "postconv", "maintenance", "maintenance")
    end
    _reject(rejects, "postconv_bombard", why ~= "" and why or st.bombard_reason)
  end

  return nil
end

local function _select_command(tgt)
  local st = _snapshot(tgt)
  local rejects = {}

  if st.target_valid ~= true then
    _set_route_stage(tgt, "hold", "invalid_target", "maintenance")
    return nil, st, rejects, "invalid_target"
  end

  if st.hellfumes ~= true then
    local ok, why, cmd = _can_cast_hellfumes(tgt)
    _set_route_stage(tgt, ok and "opener" or "hold", "hellfumes", "opener_setup")
    if ok then
      return _choice(cmd, "opener_setup", "hellfumes_open", "hellfumes_missing", "opener", "hellfumes", "opener_setup"), st, rejects, ""
    end
    _reject(rejects, "hellfumes_open", why ~= "" and why or "hellfumes_missing")
    return nil, st, rejects, why ~= "" and why or "hellfumes_missing"
  end

  if st.pebble_needed == true and st.postconv ~= true then
    local ok, why, cmd = _can_cast_pebble(tgt)
    _set_route_stage(tgt, ok and "opener" or "hold", "pebble", "opener_setup")
    if ok then
      return _choice(cmd, "opener_setup", "pebble_seed", "scalded_unconfirmed_earth_absent", "opener", "pebble", "opener_setup"), st, rejects, ""
    end
    _reject(rejects, "pebble_seed", why)
    return nil, st, rejects, why
  end

  if st.route.opening_dehydrate_done ~= true then
    local ok, why, cmd = _can_cast_dehydrate(tgt)
    _set_route_stage(tgt, ok and "opener" or "hold", "dehydrate", "opener_setup")
    if ok then
      return _choice(cmd, "opener_setup", "dehydrate_open", "opening_dehydrate", "opener", "dehydrate", "opener_setup"), st, rejects, ""
    end
    _reject(rejects, "dehydrate_open", why)
    return nil, st, rejects, why
  end

  if st.waterbonds ~= true then
    local ok, why, cmd = _can_staffcast_horripilation(tgt)
    _set_route_stage(tgt, ok and "opener" or "hold", "horripilation", "opener_setup")
    if ok then
      return _choice(cmd, "opener_setup", "horripilation_open", "waterbonds_missing", "opener", "horripilation", "opener_setup"), st, rejects, ""
    end
    _reject(rejects, "horripilation_open", why ~= "" and why or "waterbonds_missing")
    return nil, st, rejects, why ~= "" and why or "waterbonds_missing"
  end

  if st.freeze_missing == true and st.postconv ~= true then
    if st.freeze_requires_water_refresh == true then
      local ok, why, cmd = _can_cast_freeze(tgt)
      _set_route_stage(tgt, ok and "opener" or "hold", "freeze", "freeze_reopen")
      if ok then
        return _choice(cmd, "freeze_reopen", "freeze_reopen", "water_moderate_missing", "opener", "freeze", "freeze_reopen"), st, rejects, ""
      end
      _reject(rejects, "freeze_reopen", why ~= "" and why or "water_moderate_missing")
      return nil, st, rejects, why ~= "" and why or "water_moderate_missing"
    end
    _reject(rejects, "freeze_reopen", "deferred_for_resonance_pivot")
  end

  if st.postconv == true then
    local postconv = _pick_postconv_action(st, rejects)
    if postconv then
      _set_route_stage(tgt, postconv.phase, postconv.subphase, postconv.bucket)
      return postconv, st, rejects, ""
    end
    _set_route_stage(tgt, "hold", "postconv", "postconv_finish")
    return nil, st, rejects, "postconv_no_legal_action"
  end

  local lock = _pick_lock_pressure(st, rejects)
  if lock then
    _set_route_stage(tgt, lock.phase, lock.subphase, lock.bucket)
    return lock, st, rejects, ""
  end

  local bombard = _pick_bombard_revisit(st, rejects)
  if bombard then
    _set_route_stage(tgt, bombard.phase, bombard.subphase, bombard.bucket)
    return bombard, st, rejects, ""
  end

  local fulm = _pick_fulminate_branch(st, rejects)
  if fulm then
    _set_route_stage(tgt, fulm.phase, fulm.subphase, fulm.bucket)
    return fulm, st, rejects, ""
  end

  local fire = _pick_fire_progress(st, rejects)
  if fire then
    _set_route_stage(tgt, fire.phase, fire.subphase, fire.bucket)
    return fire, st, rejects, ""
  end

  local diss = _pick_dissonance_push(st, rejects)
  if diss then
    _set_route_stage(tgt, diss.phase, diss.subphase, diss.bucket)
    return diss, st, rejects, ""
  end

  if st.conv_ready == true then
    local ok, why, cmd = _can_cast_convergence(tgt)
    _set_route_stage(tgt, ok and "gate" or "hold", "convergence", "convergence_now")
    if ok then
      return _choice(cmd, "convergence_now", "convergence_now", "all_gates_satisfied", "gate", "convergence", "convergence_now"), st, rejects, ""
    end
    _reject(rejects, "convergence_now", why ~= "" and why or "all_gates_satisfied")
    return nil, st, rejects, why ~= "" and why or "all_gates_satisfied"
  end
  _reject(rejects, "convergence_now", st.conv_blocker)

  if st.freeze_missing == true then
    local ok, why, cmd = _can_cast_freeze(tgt)
    if ok then
      _set_route_stage(tgt, "maintenance", "freeze", "maintenance")
      return _choice(cmd, "maintenance", "maintenance_refresh", "freeze_package_incomplete", "maintenance", "freeze", "maintenance"), st, rejects, ""
    end
    _reject(rejects, "maintenance_freeze", why ~= "" and why or "freeze_package_incomplete")
  end

  local fallback, why = _pick_resonance_fallback(st, rejects)
  if fallback then
    _set_route_stage(tgt, fallback.phase, fallback.subphase, fallback.bucket)
    return fallback, st, rejects, ""
  end
  _set_route_stage(tgt, "hold", "idle", "maintenance")
  return nil, st, rejects, why or "no_legal_action"
end

local function _is_destroy_cmd(cmd)
  return _lc(cmd):match("^cast%s+destroy%s+at%s+") ~= nil
end

local function _apply_execute_opts(opts, payload)
  local cmd = type(payload) == "table" and _trim(payload.eq) or ""
  if _is_destroy_cmd(cmd) then
    opts.queue_verb = "addclearfull"
    opts.clearfull_lane = "eq"
  end
  return opts
end

local function _clear_eq_queue()
end

local function _emit_payload(payload, category)
  local opts = {
    reason = "magi_focus:" .. tostring(category or "attack"),
    kind = "offense",
    commit = true,
    route = "magi_focus",
    target = _trim(type(payload) == "table" and payload.target or ""),
  }
  _apply_execute_opts(opts, payload)

  if RI and type(RI.emit_route_payload) == "function" then
    return RI.emit_route_payload("magi_focus", {
      target = opts.target,
      lanes = { eq = payload and payload.eq },
      meta = {
        route = "magi_focus",
        main_lane = "eq",
        main_category = tostring(category or ""),
      },
    }, opts)
  end

  if type(Yso.emit) == "function" then
    return Yso.emit(payload, opts) == true
  end

  return false
end

local function _payload_each_eq(payload, fn)
  if type(payload) ~= "table" or type(fn) ~= "function" then return end
  local row = payload.eq
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
  return _trim(_lc(cmd):match(pat) or "")
end

local function _attack_opts(arg)
  if type(arg) == "table" and (arg.preview ~= nil or arg.ctx ~= nil) then
    return arg.ctx, (arg.preview == true)
  end
  return arg, false
end

local function _update_explain(tgt, st, choice, rejects, blocker)
  local route = _route_slot()
  MF.state.explain = RC.build_explain({
    route = "focus",
    target = tgt,
    active = MF.is_active and MF.is_active() or false,
    route_enabled = MF.is_enabled and MF.is_enabled() or false,
    debug = MF.state and MF.state.debug == true or false,
    postconv = st and st.postconv == true or false,
    opening_dehydrate_done = st and st.route.opening_dehydrate_done == true or false,
    lock = st and {
      ready = st.lock_ready,
      missing_core = st.lock_missing_core,
      mental_count = st.mental_count,
      mental_required = 2,
      epilepsy = st.epilepsy,
      stupidity = st.stupidity,
      dizziness = st.dizziness,
    } or {},
    emanation_element = choice and choice.cmd:match("^cast emanation at .+ (%a+)$") or "",
    stage = route.phase or "",
    phase = route.phase or "",
    subphase = route.subphase or "",
    bucket = route.bucket or "",
    decision = choice and choice.decision or "",
    reason = choice and choice.reason or "",
    blocker = blocker or "",
    planned = { eq = choice and choice.cmd or "" },
    threshold_rule = st and st.threshold_rule or "",
    resonance = st and {
      air = st.res.air,
      earth = st.res.earth,
      fire = st.res.fire,
      water = st.res.water,
      missing_moderate = table.concat(st.conv_missing or {}, "/"),
      water_moderate_ready = st.water_moderate_ready == true,
    } or {},
    freeze = st and {
      freeze_missing = st.freeze_missing == true,
      freeze_package_intact = st.freeze_package_intact == true,
      water_refresh_required = st.freeze_requires_water_refresh == true,
    } or {},
    dissonance = st and {
      stage = st.dissonance_stage,
      confidence = st.dissonance_confidence,
      last_evidence = st.dissonance_last_evidence,
    } or {},
    pressure = st and { kelpscore = st.kelpscore, threshold_rule = st.threshold_rule } or {},
    fulminate = st and {
      focus_punish_armed = st.focus_punish_armed == true,
      epilepsy_live = st.epilepsy_live == true,
      para_conversion_ready = st.para_conversion_ready == true,
    } or {},
    convergence = st and {
      conv_ready = st.conv_ready == true,
      conv_blocker = st.conv_blocker,
      next_gate = st.next_gate,
    } or {},
    destroy = st and {
      destroy_ready = st.destroy_ready == true,
      destroy_blocker = st.destroy_blocker,
      conflagration = _destroy_aff_present(st),
      hp_window = st.destroy_hp_window,
    } or {},
    rejects = rejects or {},
    state = st or {},
    last_cmd = MF.state and MF.state.last_cmd or "",
    last_sent_cmd = MF.state and MF.state.last_sent_cmd or "",
    pending = MF.state and MF.state.pending or {},
  })
end

local function _clear_runtime_state(reason)
  RC.reset_runtime_state(MF.state, reason)
end

function MF.init()
  MF.cfg = MF.cfg or {}
  -- Backfill settings for an already-loaded route when the alias is refreshed.
  if MF.cfg.shock_lightning_enabled == nil then MF.cfg.shock_lightning_enabled = true end
  for key, value in pairs({ pebble_pending_s = 1.00, dehydrate_pending_s = 1.00, mudslide_pending_s = 1.00,
      lightning_pending_s = 1.00, emanation_pending_s = 2.40 }) do
    if MF.cfg[key] == nil then MF.cfg[key] = value end
  end
  MF.state = MF.state or {}
  MF.state.template = MF.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  RC.ensure_pending(MF.state, PENDING_SLOTS)
  if RI and type(RI.ensure_waiting_state) == "function" then
    RI.ensure_waiting_state(MF.state, "magi_focus")
  end
  _route_slot()
  MF.state.loop_delay = tonumber(MF.state.loop_delay or MF.cfg.loop_delay or 0.15) or 0.15
  MF.state.busy = (MF.state.busy == true)
  _set_loop_enabled((MF.state.loop_enabled == true) or (MF.state.enabled == true))
  return true
end

function MF.reset(reason)
  MF.init()
  _clear_pending_all()
  _reset_route(reason or "manual")
  _clear_runtime_state(reason or "manual")
  if RI and type(RI.clear_waiting) == "function" then
    RI.clear_waiting(MF.state, "magi_focus")
  end
  Dissonance.reset()
  return true
end

function MF.is_enabled()
  return MF.state and MF.state.enabled == true
end

function MF.is_active()
  return _route_is_active()
end

function MF.can_run(ctx)
  MF.init()
  if not MF.is_enabled() then return false, "disabled" end
  if not MF.is_active() then return false, "inactive" end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return false, "paused" end

  local tgt = _trim((ctx and ctx.target) or _target())
  if tgt == "" then
    _reset_route("no_target")
    return false, "no_target"
  end
  if not _is_magi() then return false, "wrong_class" end
  if not _tgt_valid(tgt) then
    _reset_route("invalid_target")
    return false, "invalid_target"
  end
  _ensure_context(tgt)
  return true, tgt
end

function MF.attack_function(arg)
  local ctx, preview = _attack_opts(arg)
  MF.init()
  if type(RC.entourage_sync) == "function" then
    RC.entourage_sync(MF, (ctx and ctx.target) or _target(), _is_magi(), preview)
  end
  local ok, info = MF.can_run(ctx)
  if not ok then
    if preview then return nil, info end
    return false, info
  end

  local tgt = info
  if MF.state.last_target ~= "" and not _same_target(MF.state.last_target, tgt) then
    _clear_pending_all()
    _reset_route("target_swap")
    _clear_runtime_state("target_swap")
    Dissonance.reset()
  end
  MF.state.last_target = tgt

  local choice, st, rejects, blocker = _select_command(tgt)
  MF.state.template.last_reason = blocker
  MF.state.template.last_target = tgt
  _update_explain(tgt, st, choice, rejects, blocker)

  if not choice or _trim(choice.cmd) == "" then
    MF.state.template.last_payload = nil
    if preview then return nil, blocker end
    return false, blocker
  end

  local payload = {
    route = "magi_focus",
    target = tgt,
    lanes = { eq = choice.cmd },
    meta = {
      main_lane = "eq",
      main_category = choice.category,
      main_reason = choice.reason,
      decision = choice.decision,
      state = st,
      rejects = rejects,
      explain = MF.state.explain,
    },
  }

  MF.state.template.last_payload = payload

  if preview then return payload end

  local queued_payload = { eq = choice.cmd, target = tgt }
  local sent, emit_detail, ack_payload = _emit_payload(queued_payload, choice.category)
  if sent ~= true then return false, emit_detail or "emit_failed" end
  if choice.decision == "pebble_seed" then
    -- Submission may precede the sent acknowledgement; bound duplicate retries now.
    _mark_pending("pebble", tgt, MF.cfg.pebble_pending_s)
  end
  if RI and type(RI.mark_waiting) == "function" then
    RI.mark_waiting(MF.state, "magi_focus", ack_payload or queued_payload, {
      cmd = _trim(choice.cmd),
      target = tgt,
      main_lane = "eq",
    })
  end
  local has_ack_bus = Yso and Yso.locks and type(Yso.locks.note_payload) == "function"
  if not has_ack_bus and type(MF.on_payload_queued) == "function" then
    pcall(MF.on_payload_queued, ack_payload or queued_payload)
  end

  MF.state.last_cmd = choice.cmd
  MF.state.last_category = choice.category
  return true, choice.cmd, payload
end

function MF.build_payload(ctx)
  return MF.attack_function({ ctx = ctx, preview = true })
end

function MF.build(reason)
  local ctx = type(reason) == "table" and reason or { reason = tostring(reason or "") }
  return MF.build_payload(ctx)
end

function MF.evaluate(ctx)
  local payload, why = MF.build_payload(ctx)
  if not payload then return { ok = false, reason = why } end
  return { ok = true, payload = payload }
end

function MF.explain()
  MF.init()
  local ex = type(MF.state.explain) == "table" and MF.state.explain or {}
  local tgt = _target()
  local st = _snapshot(tgt)
  local route = _route_slot()
  ex.route = "focus"
  ex.enabled = MF.is_enabled()
  ex.route_enabled = MF.is_enabled()
  ex.active = MF.is_active()
  ex.target = tgt
  ex.last_reason = MF.state and MF.state.template and MF.state.template.last_reason or ""
  ex.last_disable_reason = MF.state and MF.state.template and MF.state.template.last_disable_reason or ""
  ex.last_cmd = MF.state and MF.state.last_cmd or ""
  ex.last_sent_cmd = MF.state and MF.state.last_sent_cmd or ""
  ex.stage = route.phase or ex.stage or ""
  ex.phase = route.phase or ex.phase or ""
  ex.subphase = route.subphase or ex.subphase or ""
  ex.bucket = route.bucket or ex.bucket or ""
  ex.postconv = route.postconv == true
  ex.decision = ex.decision or (MF.state and MF.state.last_category or "")
  ex.state = st
  ex.pending = MF.state and MF.state.pending or {}
  return ex
end

function MF.status()
  return MF.explain()
end

function MF.on_payload_queued(payload)
  _payload_each_eq(payload, function(cmd)
    cmd = _trim(cmd)
    if cmd == "" then return end

    local lc = _lc(cmd)
    MF.state.last_sent_cmd = cmd
    MF.state.last_sent_at = _now()

    if lc:match("^cast%s+hellfumes$") then
      local hell_tgt = _trim(_target())
      MF.state.last_sent_target = hell_tgt
      MF.state.last_sent_category = "opener_setup"
      _mark_pending("hellfumes", hell_tgt, MF.cfg.hellfumes_pending_s)
      _ensure_context(hell_tgt).opening_dehydrate_done = false
      _set_route_stage(hell_tgt, "opener", "hellfumes", "opener_setup")
      return
    end

    local pebble_tgt = _capture_target(lc, "^cast%s+pebble%s+at%s+(.+)$")
    if pebble_tgt ~= "" then
      MF.state.last_sent_target = pebble_tgt
      MF.state.last_sent_category = "opener_setup"
      _mark_pending("pebble", pebble_tgt, MF.cfg.pebble_pending_s)
      _set_route_stage(pebble_tgt, "opener", "pebble", "opener_setup")
      return
    end

    local dehydrate_tgt = _capture_target(lc, "^cast%s+dehydrate%s+at%s+(.+)$")
    if dehydrate_tgt ~= "" then
      local route = _ensure_context(dehydrate_tgt)
      local opening = route.opening_dehydrate_done ~= true
      route.opening_dehydrate_done = true
      MF.state.last_sent_target = dehydrate_tgt
      MF.state.last_sent_category = opening and "opener_setup" or "maintenance"
      _mark_pending("dehydrate", dehydrate_tgt, MF.cfg.dehydrate_pending_s)
      _set_route_stage(dehydrate_tgt, opening and "opener" or (route.postconv and "postconv" or "maintenance"),
        "dehydrate", MF.state.last_sent_category)
      return
    end

    local mudslide_tgt = _capture_target(lc, "^cast%s+mudslide%s+at%s+(.+)$")
    local lightning_tgt = _capture_target(lc, "^staff%s+cast%s+lightning%s+at%s+(.+)$")
    local emanation_tgt, element = lc:match("^cast%s+emanation%s+at%s+(.+)%s+(%a+)$")
    local slot, aff_tgt
    if mudslide_tgt ~= "" then slot, aff_tgt = "mudslide", mudslide_tgt
    elseif lightning_tgt ~= "" then slot, aff_tgt = "lightning", lightning_tgt
    elseif emanation_tgt and ({ air = true, earth = true, fire = true, water = true })[element] then
      slot, aff_tgt = "emanation", _trim(emanation_tgt)
    end
    if slot then
      local route = _ensure_context(aff_tgt)
      MF.state.last_sent_target = aff_tgt
      MF.state.last_sent_category = slot == "emanation" and "maintenance" or "lock_pressure"
      _mark_pending(slot, aff_tgt, MF.cfg[slot .. "_pending_s"])
      _set_route_stage(aff_tgt, route.postconv and "postconv" or "lock", element or slot, MF.state.last_sent_category)
      return
    end

    local horr_tgt = _capture_target(lc, "^staff%s+cast%s+horripilation%s+(.+)$")
    if horr_tgt ~= "" then
      MF.state.last_sent_target = horr_tgt
      MF.state.last_sent_category = "opener_setup"
      _mark_pending("horripilation", horr_tgt, MF.cfg.horripilation_pending_s)
      _set_route_stage(horr_tgt, "opener", "horripilation", "opener_setup")
      return
    end

    local freeze_tgt = _capture_target(lc, "^cast%s+freeze%s+at%s+(.+)$")
    if freeze_tgt ~= "" then
      MF.state.last_sent_target = freeze_tgt
      MF.state.last_sent_category = "freeze_reopen"
      _mark_pending("freeze", freeze_tgt, MF.cfg.freeze_pending_s)
      _set_route_stage(freeze_tgt, "opener", "freeze", "freeze_reopen")
      return
    end

    local bombard_tgt = _capture_target(lc, "^cast%s+bombard%s+at%s+(.+)$")
    if bombard_tgt ~= "" then
      MF.state.last_sent_target = bombard_tgt
      MF.state.last_sent_category = "resonance_progress"
      _mark_pending("bombard", bombard_tgt, MF.cfg.bombard_pending_s)
      _set_route_stage(bombard_tgt, "progress", "bombard", "resonance_progress")
      return
    end

    local fulm_tgt = _capture_target(lc, "^cast%s+fulminate%s+at%s+(.+)$")
    if fulm_tgt ~= "" then
      MF.state.last_sent_target = fulm_tgt
      MF.state.last_sent_category = "fulminate_branch"
      _mark_pending("fulminate", fulm_tgt, MF.cfg.fulminate_pending_s)
      _set_route_stage(fulm_tgt, "progress", "fulminate", "fulminate_branch")
      return
    end

    local firelash_tgt = _capture_target(lc, "^cast%s+firelash%s+at%s+(.+)$")
    if firelash_tgt ~= "" then
      MF.state.last_sent_target = firelash_tgt
      MF.state.last_sent_category = "resonance_progress"
      _mark_pending("firelash", firelash_tgt, MF.cfg.firelash_pending_s)
      _set_route_stage(firelash_tgt, "progress", "fire", "resonance_progress")
      return
    end

    local magma_tgt = _capture_target(lc, "^cast%s+magma%s+at%s+(.+)$")
    if magma_tgt ~= "" then
      MF.state.last_sent_target = magma_tgt
      MF.state.last_sent_category = "resonance_progress"
      _mark_pending("magma", magma_tgt, MF.cfg.magma_pending_s)
      _set_route_stage(magma_tgt, "progress", "fire", "resonance_progress")
      return
    end

    if lc == "embed dissonance" then
      local raw_tgt = MF.state.template and MF.state.template.last_target or ""
      local diss_tgt = _trim(raw_tgt)
      if diss_tgt == "" then diss_tgt = _trim(_target()) end
      if diss_tgt ~= "" then
        MF.state.last_sent_target = diss_tgt
        MF.state.last_sent_category = "dissonance_push"
        _mark_pending("dissonance", diss_tgt, MF.cfg.dissonance_pending_s)
        Dissonance.note(diss_tgt, "route_send", { confidence = "medium", evidence = "embed_dissonance" })
        _set_route_stage(diss_tgt, "gate", "dissonance", "dissonance_push")
      end
      return
    end

    local conv_tgt = _capture_target(lc, "^cast%s+convergence%s+at%s+(.+)$")
    if conv_tgt ~= "" then
      MF.state.last_sent_target = conv_tgt
      MF.state.last_sent_category = "convergence_now"
      _mark_pending("convergence", conv_tgt, MF.cfg.convergence_pending_s)
      _set_postconv(conv_tgt, true)
      _set_route_stage(conv_tgt, "postconv", "convergence", "postconv_finish")
      return
    end

    local destroy_tgt = _capture_target(lc, "^cast%s+destroy%s+at%s+(.+)$")
    if destroy_tgt ~= "" then
      MF.state.last_sent_target = destroy_tgt
      MF.state.last_sent_category = "postconv_finish"
      _mark_pending("destroy", destroy_tgt, MF.cfg.destroy_pending_s)
      _set_route_stage(destroy_tgt, "postconv", "destroy", "postconv_finish")
      return
    end
  end)
end

function MF.on_payload_sent(payload)
  if RI and type(RI.payload_has_any_route) == "function" and RI.payload_has_any_route(payload)
    and not RI.payload_has_route(payload, "magi_focus")
  then
    return false
  end
  if RI and type(RI.clear_waiting_on_ack) == "function" then
    RI.clear_waiting_on_ack(MF.state, "magi_focus", payload, { require_route = false })
  end
  return MF.on_payload_queued(payload)
end

function MF.on_payload_fired(payload)
  payload = payload or {}
  MF.state.last_fired_cmd = _trim(payload.eq or payload.cmd or "")
  MF.state.last_fired_at = _now()
end

function MF.on_enter(ctx)
  MF.init()
  return true
end

function MF.on_exit(ctx)
  if type(RC.entourage_passive) == "function" then RC.entourage_passive(MF) end
  if Yso and Yso.mode and type(Yso.mode.stop_route_loop) == "function" then
    Yso.mode.stop_route_loop("magi_focus", "exit", true)
  end
  MF.reset("exit")
  _clear_eq_queue()
  return true
end

function MF.on_target_swap(old_target, new_target)
  if not _same_target(old_target, new_target) then
    _clear_pending_all()
    _reset_route("target_swap")
    _clear_eq_queue()
    _clear_runtime_state("target_swap")
    Dissonance.reset()
    if MF.state.loop_enabled == true then
      MF.schedule_loop(0)
    end
  end
  return true
end

function MF.on_pause(ctx)
  return true
end

function MF.on_resume(ctx)
  if MF.state and MF.state.loop_enabled == true then
    MF.schedule_loop(0)
  end
  return true
end

function MF.on_manual_success(ctx)
  if MF.state and MF.state.loop_enabled == true then
    MF.schedule_loop(MF.state.loop_delay)
  end
  return true
end

function MF.on_send_result(payload, ctx)
  MF.on_payload_fired(payload)
  return true
end

function MF.schedule_loop(delay)
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    return Yso.mode.schedule_route_loop("magi_focus", delay)
  end
  return false
end

MF.alias_loop_stop_details = MF.alias_loop_stop_details or {
  inactive = true,
  disabled = true,
  no_target = true,
  invalid_target = true,
  wrong_class = true,
}

function MF.alias_loop_prepare_start(ctx)
  MF.init()
  return ctx or {}
end

function MF.alias_loop_on_started(ctx)
  MF.init()
  if type(RC.entourage_sync) == "function" then
    RC.entourage_sync(MF, _target(), _is_magi())
  end
  _clear_pending_all()
  _reset_route("loop_start")
  _clear_eq_queue()
  _clear_runtime_state("loop_start")
  Dissonance.reset()
  _echo("Focus loop ON.")
  local tgt = _target()
  if tgt == "" then
    _echo("No target yet; holding.")
  elseif not _tgt_valid(tgt) then
    _echo(string.format("%s is not in room; holding.", tgt))
  end
end

function MF.alias_loop_on_stopped(ctx)
  MF.init()
  if type(RC.entourage_passive) == "function" then RC.entourage_passive(MF) end
  ctx = ctx or {}
  local reason = tostring(ctx.reason or "manual")
  _clear_pending_all()
  _reset_route(reason)
  _clear_eq_queue()
  _clear_runtime_state(reason)
  Dissonance.reset()
  MF.state.template.last_disable_reason = reason
  if ctx.silent ~= true then
    _echo(string.format("Focus loop OFF (%s).", reason))
  end
end

function MF.alias_loop_waiting_blocks()
  return false
end

function MF.alias_loop_clear_waiting()
  if RI and type(RI.clear_waiting) == "function" then
    return RI.clear_waiting(MF.state, "magi_focus")
  end
  return true
end

function MF.alias_loop_on_error(err)
  _echo("Magi focus loop error: " .. tostring(err))
end

if Yso and Yso.off and Yso.off.core and type(Yso.off.core.register) == "function" then
  pcall(Yso.off.core.register, "magi_focus", MF)
  pcall(Yso.off.core.register, "focus", MF)
end

-- return omitted: alias body assigns Yso.off.magi.focus above

-- ^mfocus$ alias entry: toggle focus route loop (route id magi_focus).
Yso.util = Yso.util or {}
if type(Yso.util.toggle_route_alias) ~= "function" then
  if type(cecho) == "function" then
    cecho("<orange>[YSO] route controller unavailable; check Mudlet load order.<reset>\n")
  end
  return
end
local ok, why = Yso.util.toggle_route_alias("magi_focus", "alias:mfocus")
if ok ~= true and type(cecho) == "function" then
  cecho("<SlateBlue>[YSO] mfocus toggle failed: " .. tostring(why or "unknown") .. "<reset>\n")
end
