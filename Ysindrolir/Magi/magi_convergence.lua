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
return C
