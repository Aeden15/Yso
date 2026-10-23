-- Permanent package script. Alias only controls the shared route-loop scheduler.
Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.monk = Yso.off.monk or {}
local M = Yso.off.monk.duel or {}
Yso.off.monk.duel = M
M.key='monk_shikudo_duel'
M.name='Shikudo duel'
M.alias_owned=true
M.cfg=M.cfg or {strategy='dispatch',loop_delay=0.15,confirmation_timeout=10,hit_damage={},lock_leg='left'}
M.state=M.state or {}
local modes={dispatch=true,lock=true,blackout=true,scythe=true}
local aff_names={'anorexia','asthma','slickness','paralysis','impatience','weariness',
  'leftarm','rightarm','leftleg','rightleg','head','damagedhead','mangledhead',
  'crushedthroat','prone','addiction','clumsiness','healthleech','lethargy',
  'stuttering','stupidity','epilepsy','dizziness','confusion','blackout'}
local function now()
  local n=type(getEpoch)=='function' and tonumber(getEpoch()) or os.time()
  return n>20000000000 and n/1000 or n
end
local function who()
  local n=type(Yso.get_target)=='function' and Yso.get_target() or rawget(_G,'target')
  return tostring(n or ''):gsub('^%s+',''):gsub('%s+$','')
end
local function echo(text) if type(cecho)=='function' then cecho('<cyan>[SHDUEL]<reset> '..text..'\n') end end
local function vitals() return gmcp and gmcp.Char and gmcp.Char.Vitals or {} end
local function up(value) return value==true or tostring(value)=='1' end
local function lane_ready(lane)
  local v=vitals(); local n=v[lane]
  if n==nil then n=v[lane=='eq' and 'equilibrium' or 'balance'] end
  if not up(n) then return false end
  for _,obj in ipairs{Yso.state or {},Yso.locks or {}} do
    local f=obj[lane..'_ready']; if type(f)=='function' and f()~=true then return false end
  end
  return true
end
local function monk()
  local s=gmcp and gmcp.Char and gmcp.Char.Status or {}
  local c=Yso.classinfo and type(Yso.classinfo.get)=='function' and Yso.classinfo.get() or s.class or s.classname or Yso.class
  return tostring(c or ''):lower()=='monk'
end
local function stop(reason)
  if Yso.mode and Yso.mode.stop_route_loop then Yso.mode.stop_route_loop(M.key,reason,false) end
end
function M.init()
  M.state.loop_delay=tonumber(M.cfg.loop_delay) or 0.15
  M.state.template=M.state.template or {}
  local old=M.state.pending or M.state.cooldown
  if M.cfg.strategy=='lock' and old and old.kind=='mindlock' then
    -- Migrate pre-staged package state: a free lock request owns no EQ/BAL debt.
    M.state.mindlock_request=M.state.mindlock_request or {target=old.target,at=old.at}
    M.state.pending=nil;M.state.cooldown=nil
  end
  if not M.state.room_initialized then M.note_room_players(false);M.state.room_initialized=true end
  return true
end
function M.is_enabled() return M.state.enabled==true end
function M.is_active() return M.is_enabled() and monk() and Yso.mode and Yso.mode.is_combat() end
function M.note_room_players(live)
  local players=gmcp and gmcp.Room and gmcp.Room.Players
  if type(players)~='table' then return end
  M.state.room_players={};M.state.room_deltas={};M.state.room_snapshot_invalid=false
  if live~=false then M.state.room_live=true end
  for _,entry in pairs(players) do
    local name=type(entry)=='table' and entry.name or entry
    if type(name)=='string' then M.state.room_players[name:lower()]=true end
  end
  if M.state.room_players[who():lower()] then M.state.melee_missing=nil end
end
function M.note_room_player(name,present)
  M.state.room_players=M.state.room_players or {}
  M.state.room_deltas=M.state.room_deltas or {}
  local key=tostring(name or ''):lower()
  M.state.room_players[key]=present==true
  M.state.room_deltas[key]=true
  if key==who():lower() then M.state.melee_missing=not present and key or nil end
end
function M.note_room_info() M.state.room_players={};M.state.room_deltas={};M.state.room_snapshot_invalid=true;M.state.room_live=true;M.state.melee_missing=nil end
function M.note_local_target_activity(name)
  if tostring(name or ''):lower()~=who():lower() then return false end
  M.note_room_player(name,true);return true
end
local function reach(target)
  if M.state.melee_missing==target:lower() then return false,'target_unavailable' end
  local players=M.state.room_players
  local present=players and players[target:lower()]
  -- An observed departure always wins, even if Legacy's callback runs later.
  if present==false then return false,'gmcp_departure' end
  if M.state.room_live~=true and not M.state.room_snapshot_invalid then
    local legacy=Legacy and Legacy.Room and Legacy.Room.players
    if type(legacy)=='table' then
      for name,in_room in pairs(legacy) do
        if tostring(name):lower()==target:lower() and in_room==true then return true,'legacy_room' end
      end
    end
  end
  if present~=nil then
    local delta=M.state.room_deltas and M.state.room_deltas[target:lower()]
    return present,delta and 'gmcp_delta' or (M.state.room_live and 'gmcp_live' or 'cached_gmcp')
  end
  if not players or M.state.room_snapshot_invalid then return nil,'unknown' end
  -- Concealed players can be omitted even from a fresh Room.Players list.
  -- Permit a target-bound attempt; a real departure/target-denial blocks it.
  return nil,'gmcp_unlisted'
end
function M.snapshot()
  local target=who()
  local F=Yso.monk and Yso.monk.shikudo or {}
  local L=Yso.monk and Yso.monk.mindlock
  local tracked=type(IsTargetted)=='function' and IsTargetted(target)==true
  local affs={}
  for _,name in ipairs(aff_names) do
    affs[name]=tracked and Yso.ak and type(Yso.ak.has)=='function' and Yso.ak.has(name)==true or false
  end
  local B=Yso.monk and Yso.monk.limbs
  local limbs=B and B.snapshot(target) or {ready=false,source='unavailable',hits={}}
  local scores=tracked and rawget(_G,'affstrack')
  local plan=M.state.lock_plan
  if not plan or tostring(plan.target or ''):lower()~=target:lower() then plan={target=target,stage='prepare',pressure_step=1} end
  return {target=target,tracked=tracked,locked=L and type(L.is_locked)=='function' and L.is_locked(target)==true or false,
    room_source=select(2,reach(target)),
    form=F.form,kata=tonumber(F.kata) or 0,mode=M.cfg.strategy,affs=affs,hyperfocus=M.state.hyperfocus,
    shield=Yso.shield and type(Yso.shield.up)=='function' and Yso.shield.up(target)==true or false,
    limbs=limbs.hits,limb_ready=limbs.ready,limb_source=limbs.source,limb_confidence=limbs.confidence or {},
    selected_leg=M.cfg.lock_leg=='right' and 'rightleg' or 'leftleg',
    lock_plan=plan,
    mental_blocked=M.state.mental_opening_target==target:lower(),
    head_severity=tonumber(scores and scores.score and scores.score.head) or 0,
    hit_damage=M.cfg.hit_damage,blackout_attempted=M.state.blackout_attempted==target:lower(),
    blackout_burst_done=M.state.blackout_burst_done==target:lower(),
    blackout_physical_ready=M.cfg.blackout_timing_verified==true and lane_ready('bal')}
end
local function basic_hold(c)
  if not monk() then return 'wrong_class' end
  if tonumber(vitals().hp)==0 then return 'dead' end
  if not c.target:match("^[%a%d_'-]+$") then return 'invalid_target' end
  if not c.tracked then return 'untracked_target' end
  local in_room,source=reach(c.target)
  if in_room==false then return 'target_not_in_room' end
  if in_room==nil and source~='gmcp_unlisted' then return 'unknown_target_reach' end
  if type(Yso.target_is_valid)=='function' and not Yso.target_is_valid(c.target) then return 'invalid_target' end
  local D=Yso.monk and Yso.monk.kai and Yso.monk.kai.deliverance
  if D and D.state and D.state~='idle' then return 'deliverance' end
  local curing=Legacy and Legacy.Settings and Legacy.Settings.Curing
  if not curing or curing.status~=true then return 'curing_paused' end
  if type(Yso.offense_paused)=='function' and Yso.offense_paused() then return 'paused' end
  local self=Yso.self
  if not self or type(self.has_aff)~='function' or type(self.is_prone)~='function' then return 'self_state_unavailable' end
  if self.is_prone() or self.has_aff('paralysis') or self.has_aff('sleep') or self.has_aff('stun') then return 'self_blocked' end
  if not (Yso.monk and Yso.monk.mindlock) then return 'no_mindlock_tracker' end
  if not (Yso.shield and type(Yso.shield.up)=='function') then return 'no_shield_tracker' end
end
function M.preview()
  local c=M.snapshot()
  local why=basic_hold(c)
  if why then return nil,why end
  local S=Yso.monk.shikudo.duel_selector
  if not S then return nil,'no_selector' end
  local a,reason=S.select(c)
  if a and a.lane=='bal' then
    local f=Yso.monk.shikudo.staff_command
    if type(f)~='function' or not f() then return nil,'no_staff' end
  end
  return a,reason
end
local function pending() return M.state.pending or M.state.cooldown end
local function each_pending(fn)
  local p=pending();if p then fn(p) end
  if M.state.mental and M.state.mental~=p then fn(M.state.mental) end
end
function M.note_recovery(limb)
  local p=pending();if not p or p.kind~='combo' then return end
  p.recovered=p.recovered or {};p.recovered[tostring(limb):lower()]=true
  if p.recovered['left arm'] and p.recovered['right arm'] and (not p.needs_legs or p.recovered.legs) then p.bal_recovered=true end
end
function M.note_full_recovery() local p=pending();if p and p.lane=='bal' then p.bal_recovered=true end end
function M.note_eq_recovery() each_pending(function(p) if p.lane=='eq' then p.eq_recovered=true end end) end
function M.note_resource_refusal(lane)
  -- A refused mental cast has no new recovery cycle. Never interpret the
  -- generic "Balance used" banner as a refusal; callers match exact denials.
  local p=M.state.mental
  if not M.is_enabled() or not p or p.target:lower()~=who():lower() or now()-p.at>2 then return false end
  p.rejected=true
  if not p.eq_down then M.state.mental=nil end
  echo(p.kind..' refused: '..tostring(lane)..' unavailable; no effect assumed')
  stop('mental_'..tostring(lane)..'_refused')
  return true
end
function M.note_vitals()
  if not monk() or tonumber(vitals().hp)==0 then
    M.state.hyperfocus=nil
    if M.is_enabled() then stop(not monk() and 'class_changed' or 'dead') end
  end
  local v=vitals()
  local bal=v.bal; if bal==nil then bal=v.balance end
  local eq=v.eq; if eq==nil then eq=v.equilibrium end
  each_pending(function(p)
    if p.lane=='bal' then
      if bal~=nil and not up(bal) then p.bal_down=true end
      if p.bal_down and up(bal) then p.bal_recovered=true end
    elseif p.lane=='eq' then
      if eq~=nil and not up(eq) then p.eq_down=true end
      if p.eq_down and up(eq) then p.eq_recovered=true end
    end
  end)
end
function M.note_aff(who,aff)
  each_pending(function(p)
    if tostring(who):lower()==p.target:lower() and p.expected==tostring(aff):lower() then p.confirmed=true end
  end)
end
function M.note_impatience_success(name)
  -- The server names the recipient; feed AK so its ordinary cure tracking
  -- remains authoritative. A local pending flag is not an affliction cache.
  if tostring(name or ''):lower()~=who():lower()
    or type(IsTargetted)~='function' or IsTargetted(name)~=true then return false end
  if not (Yso.ak and type(Yso.ak.has)=='function' and Yso.ak.has('impatience')==true) then
    if type(OppGainedAff)~='function' then return false end
    OppGainedAff('impatience')
  end
  M.note_aff(name,'impatience')
  return true
end
function M.note_hyperfocus(limb)
  -- Only the supplied head confirmation establishes the chosen limb. The
  -- preceding breathing message invalidates it for manual focus changes.
  M.state.hyperfocus=limb=='head' and 'head' or nil
  local p=pending()
  if limb=='head' and p and p.kind=='hyperfocus' then p.focus_confirmed=true end
end
function M.note_slain(name)
  if tostring(name or ''):lower()==who():lower() then stop('target_slain') end
end
function M.note_target_unavailable()
  local p=pending()
  if M.cfg.strategy=='lock' then
    local mental=M.state.mental
    if M.is_enabled() and mental and mental.target:lower()==who():lower() and now()-mental.at<=2 then
      mental.rejected=true
      if not mental.eq_down then M.state.mental=nil end
      M.state.melee_missing=who():lower();stop('mental_target_unavailable');return true
    end
    local r=M.state.mindlock_request
    if M.is_enabled() and r and r.target:lower()==who():lower() and now()-r.at<=2 then
      M.state.mindlock_request=nil;M.state.melee_missing=who():lower()
      if p and p.target:lower()==who():lower() then p.rejected=true;if not p.bal_down then M.state.pending=nil;M.state.cooldown=nil end end
      stop('target_unavailable');return true
    end
  end
  if not M.is_enabled() or not p or p.target:lower()~=who():lower() or now()-p.at>2 then return false end
  if p.kind=='combo' or p.kind=='dispatch' then
    M.state.melee_missing=p.target:lower();M.state.pending=nil
    if not p.bal_down then M.state.cooldown=nil end
  elseif p.lane=='eq' then
    stop('mental_target_unavailable')
    if not p.eq_down then M.state.cooldown=nil end
  end
  return true
end
function M.note_target_grace(name)
  if M.cfg.strategy=='lock' then
    if not M.is_enabled() or tostring(name or ''):lower()~=who():lower() then return false end
    local matched=false
    local r=M.state.mindlock_request
    if r and r.target:lower()==who():lower() and now()-r.at<=2 then M.state.mindlock_request=nil;matched=true end
    each_pending(function(p)
      if p.target:lower()==who():lower() and now()-p.at<=2 and p.kind~='adopt' and p.kind~='transition' and p.kind~='hyperfocus' then
        matched=true;p.rejected=true
        if p.lane=='bal' and not p.bal_down then M.state.pending=nil;M.state.cooldown=nil end
        if p.lane=='eq' and not p.eq_down then M.state.mental=nil end
      end
    end)
    if matched then stop('target_divine_grace') end
    return matched
  end
  local p=pending()
  if not M.is_enabled() or not p or now()-p.at>2
      or p.kind=='adopt' or p.kind=='transition' or p.kind=='hyperfocus'
      or tostring(name or ''):lower()~=p.target:lower() or p.target:lower()~=who():lower() then return false end
  -- A refusal cannot produce action confirmation. Preserve any real recovery
  -- debt, but do not wait for an EQ/BAL cycle that the rejected send never used.
  M.state.pending=nil
  p.rejected=true
  if not p.bal_down and not p.eq_down then M.state.cooldown=nil end
  stop('target_divine_grace')
  return true
end
local function timed_out(p)
  echo('Timeout: '..(p.command or p.kind)..' target='..p.target..' lane='..p.lane..
    ' down='..tostring(p[p.lane..'_down']==true)..
    ' recovered='..tostring(p[p.lane..'_recovered']==true)..
    ' ready='..tostring(lane_ready(p.lane)))
  stop('confirmation_timeout')
end
local function waiting()
  local p=pending(); if not p then return false end
  M.note_vitals()
  local F=Yso.monk.shikudo
  local recovered
  if p.lane=='eq' then recovered=p.eq_recovered else recovered=p.bal_recovered end
  local confirmed=true
  -- Form confirmations acknowledge adoption/transition without requiring a
  -- BAL drop; the current lane readiness gate below still applies.
  if p.rejected then confirmed=true
  elseif p.kind=='transition' or p.kind=='adopt' then confirmed=F.form==p.destination;recovered=confirmed
  elseif p.kind=='hyperfocus' then confirmed=p.focus_confirmed==true
  elseif p.kind=='combo' and p.destination then confirmed=F.form==p.destination
  elseif p.kind=='mindlock' then
    confirmed=M.snapshot().locked or who():lower()~=p.target:lower()
    recovered=confirmed
  elseif p.expected then confirmed=p.confirmed or M.snapshot().affs[p.expected] or who():lower()~=p.target:lower() end
  if recovered and confirmed and lane_ready(p.lane) then
    if p.next_lock_plan and p.target:lower()==who():lower() and M.cfg.strategy=='lock' then
      M.state.lock_plan={target=p.target,stage=p.next_lock_plan.stage,pressure_step=p.next_lock_plan.pressure_step}
    end
    M.state.pending=nil; M.state.cooldown=nil; return false
  end
  if now()-p.at>=(tonumber(M.cfg.confirmation_timeout) or 10) then timed_out(p) end
  return true
end
local function waiting_mental()
  local p=M.state.mental;if not p then return false end
  M.note_vitals()
  -- Resource completion frees the slot; only AK observations establish effects.
  if p.eq_recovered and lane_ready('eq') then M.state.mental=nil;return false end
  if now()-p.at>=(tonumber(M.cfg.confirmation_timeout) or 10) then timed_out(p) end
  return true
end
local function missing_lock_affs(c)
  local missing={}
  for _,name in ipairs{'anorexia','asthma','slickness','paralysis','impatience','weariness'} do
    if not c.affs[name] then missing[#missing+1]=name end
  end
  return missing
end
function M.status()
  local c=M.snapshot(); local action,why=M.preview()
  local hold=basic_hold(c)
  if not hold and (pending() or M.state.mental) then hold='awaiting_recovery' end
  if not hold and not lane_ready('eq') then hold='equilibrium_down' end
  if not hold and action and action.lane=='bal' and not lane_ready('bal') then hold='balance_down' end
  return {enabled=M.is_enabled(),strategy=M.cfg.strategy,target=c.target,form=c.form or 'none',kata=c.kata,
    phase=action and action.phase or M.state.phase,stage=action and action.lock_stage or c.lock_plan.stage,
    requirements=action and action.requirements,missing_affs=missing_lock_affs(c),
    mindlock=c.locked and 'confirmed' or (M.state.mindlock_request and 'forming' or 'absent'),
    physical_wait=pending()~=nil,mental_wait=M.state.mental~=nil,
    lock_level=Yso.monk.shikudo.duel_selector.lock_level(c),
    hold_reason=hold or why,limb_source=c.limb_source,
    limbs=c.limbs,limb_ready=c.limb_ready,limb_confidence=c.limb_confidence,
    light_decisions=action and action.light_decisions or {},projected_limbs=action and action.projected_limbs,
    next_command=action and action.command,last_command=M.state.last_command,
    room_source=c.room_source,timer_scheduled=M.state.timer_id~=nil,ticks=tonumber(M.state.ticks) or 0,
    gmcp_eq=vitals().eq or vitals().equilibrium,gmcp_bal=vitals().bal or vitals().balance,hyperfocus=c.hyperfocus}
end
local function hold(reason)
  if M.state.hold_reason~=reason then echo('Holding: '..tostring(reason)) end
  M.state.hold_reason=reason
  M.state.template.last_reason=reason
  return false,reason
end
local function record(a,target)
  local expected=a.command:match('^mind (impatience)') or a.command:match('^mind (blackout)')
  if a.command:match('^mind batter') then expected='stupidity' end
  local p={at=now(),target=target,lane=a.lane,kind=a.kind,command=a.command,expected=expected,
    next_lock_plan=a.next_lock_plan,
    destination=a.kind=='adopt' and a.command:match('^adopt (%a+)') or a.opts and a.opts.destination}
  if a.opts and a.opts.attacks then
    for _,piece in ipairs(a.opts.attacks) do
      local key=piece:match('^(%a+)')
      if Yso.ref.monk.shikudo[key].commands[1].role=='kick' then p.needs_legs=true end
    end
  end
  return p
end
local function free_lock_command(c)
  local r=M.state.mindlock_request
  if c.locked or (r and r.target:lower()~=c.target:lower()) then M.state.mindlock_request=nil;r=nil end
  if c.locked or c.hyperfocus~='head' or not c.form or c.form=='none' then return nil end
  local L=Yso.monk.mindlock
  if L.locked_target and tostring(L.locked_target):lower()~=c.target:lower() then return nil end
  local forming=tostring(L.pending_target or ''):lower()==c.target:lower()
  if not r and forming then r={target=c.target,at=now()};M.state.mindlock_request=r end
  if r and not forming and now()-r.at>=(tonumber(M.cfg.confirmation_timeout) or 10) then M.state.mindlock_request=nil;r=nil end
  if not r then return 'mind lock '..c.target end
end
local function lock_tick()
  local physical_busy=waiting()
  local mental_busy=waiting_mental()
  if not M.is_active() then return false,'inactive' end
  local c=M.snapshot();local why=basic_hold(c)
  if why then return hold(why) end
  local a,reason=M.preview()
  if not a then return hold(reason) end
  local payload={target=c.target,route=M.key}
  local free=free_lock_command(c);payload.free=free
  local physical,mental
  if not physical_busy and not mental_busy and lane_ready('eq') and lane_ready('bal') then
    -- The selector owns closing-window timing. A selected EQ action must never
    -- be wrapped in wield/COMBO or committed as physical recovery debt.
    if a.lane=='eq' then
      mental=a;payload.eq=a.command
    else
      physical=a
      local wield=Yso.monk.shikudo.staff_command()
      if not wield then return hold('no_staff') end
      payload.bal=wield..'&&'..a.command
    end
  end
  if not payload.free and not payload.bal and not payload.eq then
    if not lane_ready('eq') then return hold('equilibrium_down') end
    if physical_busy or mental_busy then return hold('awaiting_recovery') end
    return hold('balance_down')
  end
  if type(Yso.emit)~='function' or Yso.queue then return hold('no_emitter') end
  if Yso.emit(payload,{kind='offense',route=M.key,reason=physical and physical.phase or mental and mental.phase or 'mindlock',target=c.target,commit=true})~=true then return hold('emit_failed') end
  if free then M.state.mindlock_request={target=c.target,at=now()} end
  if physical then
    local p=record(physical,c.target);M.state.pending=p;M.state.cooldown=p
    M.state.mental_opening_target=nil
    M.state.phase=physical.phase;M.state.last_command=physical.command
  end
  if mental then
    M.state.mental=record(mental,c.target)
    M.state.phase=mental.phase;M.state.last_command=mental.command
    -- Even a rapidly cured/unconfirmed effect cannot monopolize recovered
    -- openings: one physical action must separate mental support attempts.
    M.state.mental_opening_target=c.target:lower()
  end
  M.state.hold_reason=nil
  M.state.template.last_reason=physical and physical.phase or mental and mental.phase or 'mindlock'
  return true,physical and physical.command or mental and mental.command or free
end
function M.attack_function()
  M.init()
  M.state.ticks=(tonumber(M.state.ticks) or 0)+1
  if not monk() or tonumber(vitals().hp)==0 then stop(not monk() and 'class_changed' or 'dead');return false,'inactive' end
  if not M.is_active() then return false,'inactive' end
  if M.cfg.strategy=='lock' then return lock_tick() end
  if waiting_mental() then return false,'awaiting_recovery' end
  if waiting() then return false,'awaiting_recovery' end
  local a,why=M.preview()
  if not a then return hold(why) end
  if not lane_ready('eq') then return hold('equilibrium_down') end
  if a.lane=='bal' and not lane_ready('bal') then return hold('balance_down') end
  if type(Yso.emit)~='function' or Yso.queue then return hold('no_emitter') end
  local target=who();local command=a.command
  if a.lane=='bal' then
    local F=Yso.monk.shikudo
    local wield=type(F.staff_command)=='function' and F.staff_command()
    if not wield then return hold('no_staff') end
    command=wield..'&&'..command
  end
  local payload={target=target,route=M.key,[a.lane]=command}
  if Yso.emit(payload,{kind='offense',route=M.key,reason=a.phase,target=target,commit=true})~=true then return hold('emit_failed') end
  local p=record(a,target)
  M.state.pending=p;M.state.cooldown=p;M.state.phase=a.phase;M.state.last_command=a.command;M.state.hold_reason=nil
  if a.phase=='blackout_start' or a.phase=='blackout_burst' then M.state.blackout_attempted=target:lower() end
  if a.phase=='blackout_burst' then M.state.blackout_burst_done=target:lower() end
  M.state.template.last_reason=a.phase
  return true,a.command
end
function M.alias_loop_clear_waiting() M.state.pending=nil end
function M.alias_loop_on_started()
  -- Re-establish focus each activation so changes made while stopped cannot
  -- leave a stale parry-bypass assumption in the next duel.
  M.state.hyperfocus=nil
  if M.state.retry_after_timeout then M.state.cooldown=nil;M.state.retry_after_timeout=nil end
  echo('ON ('..M.cfg.strategy..'). Use shduel off to stop.')
  local s=M.status()
  if s.hold_reason then echo('Holding: '..s.hold_reason..' (room='..s.room_source..').') end
end
function M.alias_loop_on_stopped(ctx)
  if ctx and ctx.reason=='confirmation_timeout' then M.state.retry_after_timeout=true end
  if ctx and ctx.reason=='target_slain' then return end
  echo('OFF ('..tostring(ctx and ctx.reason or 'manual')..').')
end
function M.alias_loop_on_error(err) stop('error');echo(tostring(err)) end
M.alias_loop_stop_details={invalid_target=true,no_emitter=true,unknown_strategy=true}
function M.alias(command)
  command=tostring(command or ''):lower()
  if modes[command] then
    if M.cfg.strategy~=command then M.state.lock_plan=nil;M.state.mindlock_request=nil end
    M.cfg.strategy=command;M.state.blackout_attempted=nil;M.state.blackout_burst_done=nil;echo('Strategy: '..command..'.');return true
  end
  if command=='status' then
    local s=M.status()
    echo((s.enabled and 'ON' or 'OFF')..' '..s.strategy..' target='..s.target..' form='..s.form..' kata='..s.kata
      ..' phase='..tostring(s.phase)..' hold='..tostring(s.hold_reason or 'none')..' limb='..s.limb_source)
    if M.cfg.strategy=='lock' then
      echo('stage='..s.stage..' lock='..s.lock_level..' mindlock='..s.mindlock..' physical_wait='..tostring(s.physical_wait)..' EQ_wait='..tostring(s.mental_wait))
      echo('Missing lock afflictions: '..(#s.missing_affs>0 and table.concat(s.missing_affs,', ') or 'none'))
      echo('Planned disable: both arms + '..(s.requirements and s.requirements.leg or 'selected leg'))
      for _,reason in ipairs(s.requirements and s.requirements.missing or {}) do echo('Setup: '..reason) end
    end
    echo('room='..s.room_source..' timer='..tostring(s.timer_scheduled)..' ticks='..s.ticks
      ..' BAL='..tostring(s.gmcp_bal)..' EQ='..tostring(s.gmcp_eq)..' hyperfocus='..tostring(s.hyperfocus or 'unconfirmed'))
    for _,name in ipairs{'head','leftarm','rightarm','leftleg','rightleg'} do
      echo(name..'='..tostring(s.limbs[name] or 'unknown')..' ('..tostring(s.limb_confidence[name] or 'unknown')..')')
    end
    if s.next_command then echo('Next candidate: '..s.next_command) end
    for _,reason in ipairs(s.light_decisions) do echo(reason) end
    return true
  end
  if command=='preview' then
    local a,why=M.preview();echo(a and (a.phase..': '..a.command) or ('Holding: '..tostring(why)))
    for _,reason in ipairs(a and a.light_decisions or {}) do echo(reason) end
    if a and a.lock_stage then
      echo('stage='..a.lock_stage..' lock='..Yso.monk.shikudo.duel_selector.lock_level(M.snapshot()))
      local missing=missing_lock_affs(M.snapshot())
      echo('Missing lock afflictions: '..(#missing>0 and table.concat(missing,', ') or 'none'))
      echo('Planned disable: both arms + '..a.requirements.leg)
      for _,reason in ipairs(a.requirements and a.requirements.missing or {}) do echo('Setup: '..reason) end
    end
    return true
  end
  if not Yso.mode then return false end
  if command=='on' then
    if M.is_enabled() then
      if not M.state.timer_id and not M.state.busy then Yso.mode.schedule_route_loop(M.key,0) end
      return M.alias('status')
    end
    return Yso.mode.start_route_loop(M.key,'alias:shduel')
  end
  if command=='off' then return Yso.mode.stop_route_loop(M.key,'manual',false) end
  if command=='' then return Yso.util.toggle_route_alias(M.key,'alias:shduel') end
  echo('Use shduel [dispatch|lock|blackout|scythe|on|off|status|preview].');return false
end
if type(registerAnonymousEventHandler)=='function' then
  M.handlers=M.handlers or {}
  local events={['gmcp.Char.Vitals']=M.note_vitals,['gmcp.Char.Status']=M.note_vitals,
    ['gmcp.Room.Players']=M.note_room_players,['gmcp.Room.Info']=M.note_room_info,
    ['gmcp.Room.AddPlayer']=function()
      local e=gmcp and gmcp.Room and gmcp.Room.AddPlayer
      M.note_room_player(type(e)=='table' and e.name or e,true)
    end,
    ['gmcp.Room.RemovePlayer']=function()
      local e=gmcp and gmcp.Room and gmcp.Room.RemovePlayer
      M.note_room_player(type(e)=='table' and e.name or e,false)
    end,
    ['sysDisconnectionEvent']=function() stop('disconnect');M.state.cooldown=nil;M.state.mental=nil;M.state.mindlock_request=nil;M.state.lock_plan=nil;M.state.hyperfocus=nil;M.note_room_info() end,
    ['yso.target.changed']=function() M.state.blackout_attempted=nil;M.state.blackout_burst_done=nil end,
    ['yso.target.cleared']=function() if M.state.loop_enabled then stop('target_cleared') end end,
    ['yso.target.aff.gained']=function(_,name,aff) M.note_aff(name,aff) end}
  for event,fn in pairs(events) do
    if M.handlers[event] and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(M.handlers[event]) end
    M.handlers[event]=registerAnonymousEventHandler(event,fn)
  end
end
M.init()
return M
