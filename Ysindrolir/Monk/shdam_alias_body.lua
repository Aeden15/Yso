-- ^shdam$: embedded implementation; no runtime file loading.
local revision = 'a9790ada4ef361523068f1050d557364279b6acd9fd5ef4fdf89785faafa090c'
local installed = Yso and Yso.off and Yso.off.monk and Yso.off.monk.group_damage
if not installed or installed._source_revision ~= revision then
  (function()
-- Embedded in ^shdam$ at build time. Uses the package route-loop controller.
Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.monk = Yso.off.monk or {}
local M = Yso.off.monk.group_damage or {}
Yso.off.monk.group_damage = M
M.key = 'monk_shikudo_group_damage'
M.name = 'Shikudo group damage'
M.alias_owned = true
M.cfg = M.cfg or {leg='left', loop_delay=0.15, confirmation_timeout=10}
M.state = M.state or {}

local function trim(value)
  return tostring(value or ''):gsub('^%s+',''):gsub('%s+$','')
end
local function now()
  local value = type(getEpoch)=='function' and tonumber(getEpoch()) or os.time()
  if value > 20000000000 then value=value/1000 end
  return value
end
local function echo_status(text)
  if type(cecho)=='function' then cecho('<cyan>[SHIKUDO] <reset>'..text..'\n') end
end
local function form_tracker()
  return Yso.monk and Yso.monk.shikudo
end
local function current_target()
  if type(Yso.get_target)=='function' then return trim(Yso.get_target()) end
  return trim(rawget(_G,'target'))
end
local function monk()
  local class = Yso.classinfo and type(Yso.classinfo.get)=='function' and Yso.classinfo.get()
  local status = gmcp and gmcp.Char and gmcp.Char.Status
  class = class or (status and (status.class or status.classname)) or Yso.class
  return trim(class):lower()=='monk'
end
local function ready_value(value)
  return value==true or tostring(value)=='1'
end
local function eq_ready()
  local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  local eq=v.eq
  if eq==nil then eq=v.equilibrium end
  if not ready_value(eq) then return false end
  if Yso.state and type(Yso.state.eq_ready)=='function' and not Yso.state.eq_ready() then return false end
  if Yso.locks and type(Yso.locks.eq_ready)=='function' and not Yso.locks.eq_ready() then return false end
  return true
end
local function ready()
  local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  local bal=v.bal
  if bal==nil then bal=v.balance end
  if not ready_value(bal) or not eq_ready() then return false end
  if Yso.state and type(Yso.state.bal_ready)=='function' and not Yso.state.bal_ready() then return false end
  if Yso.locks and type(Yso.locks.bal_ready)=='function' and not Yso.locks.bal_ready() then return false end
  return true
end
local function mindlock()
  return Yso.monk and Yso.monk.mindlock
end
local function mental_kind(kind)
  return kind=='mindlock' or kind=='mind_crush' or kind=='kai_choke'
end

-- Room presence is melee reach, not proof of mental reach or line of sight.
function M.note_room_players()
  local list=gmcp and gmcp.Room and gmcp.Room.Players
  if type(list)~='table' then return end
  M.state.room_players={}
  M.state.room_snapshot_invalid=false
  for _,entry in pairs(list) do
    local name=type(entry)=='table' and entry.name or entry
    if type(name)=='string' then M.state.room_players[trim(name):lower()]=true end
  end
  if M.state.room_players[current_target():lower()] then M.state.melee_missing=nil end
end
function M.target_in_room(tgt)
  tgt=trim(tgt):lower()
  if M.state.melee_missing==tgt then return false end
  if M.state.room_snapshot_invalid then return nil end
  if type(M.state.room_players)=='table' then return M.state.room_players[tgt]==true end
  local players=Legacy and Legacy.Room and Legacy.Room.players
  if type(players)=='table' then
    for name,present in pairs(players) do if trim(name):lower()==tgt then return present==true end end
    return false
  end
  return nil
end
local function has_aff(tgt, aff)
  -- AK's current-target predicate prevents old target scores being reused.
  if type(IsTargetted)~='function' or not IsTargetted(tgt) then return false end
  if Yso.ak and type(Yso.ak.has)=='function' then return Yso.ak.has(aff)==true end
  return false
end

function M.init()
  M.state.loop_delay=tonumber(M.cfg.loop_delay) or 0.15
  M.state.template=M.state.template or {}
  if not M.state.room_initialized then
    if not M.state.room_snapshot_invalid then M.note_room_players() end
    M.state.room_initialized=true
  end
  if not M.status_alias and type(tempAlias)=='function' then
    M.status_alias=tempAlias('^shstatus$',function()
      local s=M.status()
      echo_status('Status: '..(s.enabled and 'ON' or 'OFF')..', target='..s.target
        ..', form='..s.form..', kata='..tostring(s.kata)..', BAL='..tostring(s.bal)
        ..', EQ='..tostring(s.eq)..', execute='..s.dispatch_reason
        ..', mindlock='..s.mindlock..', reach='..s.reach
        ..', hold='..tostring(s.hold_reason or 'none')..'.')
    end)
  end
  return true
end
function M.is_enabled() return M.state.enabled==true end
function M.is_active()
  return monk() and Yso.mode and Yso.mode.is_combat() and M.state.loop_enabled==true
end

-- Shared AI and combo validation are also available to future Shikudo routes.
function M.select(ctx)
  local F = form_tracker()
  local A = F and F.ai
  local C = Yso.monk and Yso.monk.combo
  if not A or type(A.select) ~= 'function' then return nil,'no_ai' end
  if not C or type(C.build_shikudo) ~= 'function' then return nil,'no_combo_builder' end
  if not trim(ctx.target):match("^[%a%d_'-]+$") then return nil,'invalid_target' end
  ctx.leg = M.cfg.leg
  local opts, why = A.select(ctx)
  if not opts then return nil,why end
  if opts.command then return opts.command,opts.kind end
  local cmd, reason = C.build_shikudo(ctx.target,opts)
  return cmd,cmd and opts.kind or reason
end
function M.note_recovery(limb)
  local p=M.state.pending or M.state.cooldown
  if not p then return end
  p.recovered[trim(limb):lower()]=true
end
function M.note_full_recovery()
  local p=M.state.pending or M.state.cooldown
  if p then p.full_recovery=true end
end
function M.note_eq_recovery()
  local p=M.state.pending or M.state.cooldown
  if p and mental_kind(p.kind) then p.eq_recovered=true end
end
function M.note_vitals()
  local p=M.state.pending or M.state.cooldown
  if not p then return end
  local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  local bal=v.bal
  if bal==nil then bal=v.balance end
  if bal~=nil and not ready_value(bal) then p.saw_down=true end
  if p.saw_down and ready_value(bal) then p.full_recovery=true end
  local eq=v.eq
  if eq==nil then eq=v.equilibrium end
  if eq~=nil and not ready_value(eq) then p.saw_eq_down=true end
  if p.saw_eq_down and ready_value(eq) then p.eq_recovered=true end
end
-- Clear the decision on stop, but physical recovery survives rapid off/on.
function M.alias_loop_clear_waiting() M.state.pending=nil; return true end
local function pending_blocks()
  local p=M.state.pending or M.state.cooldown
  if not p then return false end
  -- Also observe snapshots when a caller ticks between GMCP handler callbacks.
  M.note_vitals()
  local F=form_tracker()
  local L=mindlock()
  local confirmed=M.state.pending==nil or p.kind=='combo' or p.kind=='dispatch'
    or p.kind=='mind_crush' or p.kind=='kai_choke'
    or (p.kind=='mindlock' and ((L and L.is_locked(p.target))
      or trim(p.target):lower()~=current_target():lower()))
    or (not mental_kind(p.kind) and F and F.form and F.form~=p.form)
  -- Adoption spends general balance, not the three attack limb balances.
  -- Adoption needs confirmed full balance recovery; a stale ready snapshot
  -- cannot release its cooldown after a rapid off/on. Transitions are instant.
  local recovered=p.kind=='transition' or p.full_recovery or
    (p.kind=='combo' and p.recovered['left arm'] and p.recovered['right arm'] and p.recovered.legs)
  local lane_ready=ready()
  if mental_kind(p.kind) then recovered=p.eq_recovered; lane_ready=eq_ready() end
  if confirmed and recovered and lane_ready then
    M.state.pending=nil; M.state.cooldown=nil; return false
  end
  if now()-p.at>=(tonumber(M.cfg.confirmation_timeout) or 10) then
    Yso.mode.stop_route_loop(M.key,'confirmation_timeout',false)
  end
  return true
end

-- Read-only snapshot: querying status never releases pending work or stops a loop.
function M.status()
  local F=form_tracker()
  local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  local bal,eq=v.bal,v.eq
  if bal==nil then bal=v.balance end
  if eq==nil then eq=v.equilibrium end
  if bal==nil then bal='missing' end
  if eq==nil then eq='missing' end
  local tgt=current_target()
  local L=mindlock()
  local locked=L and type(L.is_locked)=='function' and L.is_locked(tgt)==true
  local in_room=M.target_in_room(tgt)
  local E=F and F.execute
  local eligible,reason=false,'no_execute_helper'
  if E and type(E.can_dispatch)=='function' then eligible,reason=E.can_dispatch(tgt) end
  local hold
  if not M.is_enabled() then hold='disabled'
  elseif not M.is_active() then hold='inactive'
  elseif type(Yso.offense_paused)=='function' and Yso.offense_paused() then hold='paused'
  elseif M.state.pending or M.state.cooldown then hold='awaiting_recovery'
  elseif not ((not locked or in_room==false) and eq_ready() or ready()) then hold='balance_down'
  elseif tgt=='' then hold='no_target'
  else hold=M.state.hold_reason end
  return {enabled=M.is_enabled(),target=tgt,form=tostring(F and F.form or 'none'),
    kata=tonumber(F and F.kata) or 0,bal=bal,eq=eq,dispatch_ready=eligible,
    dispatch_reason=reason,hold_reason=hold,mindlock=locked and 'locked' or 'unlocked',
    reach=in_room==true and 'melee' or (in_room==false and 'ranged_fallback' or 'unknown')}
end

function M.can_run()
  M.init()
  if not M.is_enabled() then return false,'disabled' end
  if not M.is_active() then return false,'inactive' end
  if type(Yso.offense_paused)=='function' and Yso.offense_paused() then return false,'paused' end
  if pending_blocks() then return false,'awaiting_recovery' end
  local tgt=current_target()
  if tgt=='' then return false,'no_target' end
  if not tgt:match('^[%a%d_\'-]+$') then return false,'invalid_target' end
  local L=mindlock()
  if not L or type(L.is_locked)~='function' then return false,'no_mindlock_tracker' end
  local in_room=M.target_in_room(tgt)
  if in_room~=false and type(Yso.target_is_valid)=='function' and not Yso.target_is_valid(tgt) then return false,'invalid_target' end
  if not L.is_locked(tgt) or in_room==false then
    if not eq_ready() then return false,'equilibrium_down' end
  else
    if not ready() then return false,'balance_down' end
    if not (Yso.shield and type(Yso.shield.up)=='function') then return false,'no_shield_tracker' end
  end
  return true,tgt,in_room
end

local function emit_action(cmd,kind,tgt,lane,form)
  if type(Yso.emit)~='function' then return false,'no_emitter' end
  if Yso.queue then return false,'legacy_queue_present' end
  local payload={target=tgt,route=M.key}
  payload[lane]=cmd
  if Yso.emit(payload,{kind='offense',reason=M.key,route=M.key,target=tgt,commit=true})~=true then return false,'emit_failed' end
  M.state.pending={at=now(),target=tgt,form=form,kind=kind,recovered={}}
  M.state.cooldown=M.state.pending
  M.state.last_cmd=cmd
  M.state.template.last_reason=kind
  return true,cmd
end

-- Generic target errors are meaningful only during a recent route request.
function M.note_target_unavailable()
  local p=M.state.pending
  if not M.is_active() or not p or trim(p.target):lower()~=current_target():lower() then return false end
  if now()-p.at>(tonumber(M.cfg.target_response_window) or 2) then return false end
  if p.kind=='combo' or p.kind=='dispatch' then
    M.note_vitals()
    M.state.melee_missing=current_target():lower()
    M.state.pending=nil
    if not p.saw_down then M.state.cooldown=nil end
    M.state.template.last_reason='physical_target_unavailable'
    if Yso.mode.nudge_route_loop then Yso.mode.nudge_route_loop(M.key,'physical_target_unavailable') end
    return true
  elseif mental_kind(p.kind) then
    M.note_vitals()
    if not p.saw_eq_down then M.state.cooldown=nil end
    Yso.mode.stop_route_loop(M.key,'mental_target_unavailable',false)
    return true
  end
  return false
end

function M.attack_function()
  local ok,tgt,in_room=M.can_run()
  if not ok then
    M.state.template.last_reason=tgt
    if M.state.hold_reason~=tgt then
      M.state.hold_reason=tgt; M.state.hold_since=now()
    end
    if M.state.loop_enabled and now()-M.state.hold_since>=5 and M.state.reported_hold~=tgt then
      M.state.reported_hold=tgt
      local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
      echo_status('Holding: '..tostring(tgt)..' (target='..current_target()
        ..', form='..tostring(form_tracker() and form_tracker().form or 'none')
        ..', BAL='..tostring(v.bal or v.balance or 'missing')
        ..', EQ='..tostring(v.eq or v.equilibrium or 'missing')..').')
    end
    return false,tgt
  end
  M.state.hold_reason=nil
  -- Opening offense: one request, then wait for confirmed lock and EQ recovery.
  if not mindlock().is_locked(tgt) then
    return emit_action('mind lock '..tgt,'mindlock',tgt,'eq')
  end

  local cmd,kind
  if in_room==false then
    -- Ranged fallback only; normal physical damage retains priority in room.
    local kai = type(Hadoken)=='function' and Hadoken() or rawget(_G,'hadoken')
    if (tonumber(kai) or 0)>=10 then
      cmd,kind='kai choke '..tgt,'kai_choke'
    else
      cmd,kind='mind crush '..tgt,'mind_crush'
    end
    return emit_action(cmd,kind,tgt,'eq')
  end
  local F=form_tracker()
  if not F or type(F.staff_command)~='function' then return false,'no_form_tracker' end
  -- Text confirmations update F.form immediately; don't reapply stale GMCP here.
  local form=F.form
  -- AK tracks leg breaks as leftleg/rightleg, not invented injury names.
  local injury=has_aff(tgt,M.cfg.leg=='right' and 'rightleg' or 'leftleg')
  local ctx={target=tgt,form=form,kata=F.kata,prone=has_aff(tgt,'prone'),leg_ready=injury,
    affs={paralysis=has_aff(tgt,'paralysis'),anorexia=has_aff(tgt,'anorexia'),stuttering=has_aff(tgt,'stuttering')}}
  -- 1. Shield check and shield handling.
  ctx.shield=Yso.shield.up(tgt)==true
  if ctx.shield then
    cmd,kind=M.select(ctx)
    if not cmd then return false,kind end
  end
  -- 2. Execute scripts, after the shield branch.
  if not ctx.shield then
    local E=F.execute
    if not E or type(E.can_dispatch)~='function' then return false,'no_execute_helper' end
    if E.can_dispatch(tgt)==true then cmd,kind='dispatch '..tgt,'dispatch' end
  end
  -- 3. Normal damage and form progression.
  if not cmd then cmd,kind=M.select(ctx) end
  if not cmd then return false,kind end
  local wield=F.staff_command()
  if not wield then return false,'no_staff' end
  local sent,detail=emit_action(wield..'&&'..cmd,kind,tgt,'bal',form)
  if sent then M.state.last_cmd=cmd end
  return sent,sent and cmd or detail
end
M.alias_loop_stop_details={inactive=true,disabled=true,invalid_target=true,no_mindlock_tracker=true,no_shield_tracker=true,no_form_tracker=true,no_execute_helper=true,no_staff=true,no_emitter=true,legacy_queue_present=true,unknown_form=true}
function M.alias_loop_on_started()
  M.alias_loop_clear_waiting()
  -- A watchdog stop requires an explicit restart. Drop its expired decision
  -- then; can_run still requires current BAL/EQ readiness before any retry.
  -- Ordinary rapid off/on retains physical recovery protection.
  if M.state.retry_after_timeout then
    M.state.cooldown=nil
    M.state.retry_after_timeout=nil
  end
  M.state.hold_reason=nil; M.state.reported_hold=nil
  M.state.melee_missing=nil
  echo_status('Group damage ON. Use shdam again to stop.')
end
function M.alias_loop_on_stopped(ctx)
  M.alias_loop_clear_waiting()
  if ctx and ctx.reason=='confirmation_timeout' then M.state.retry_after_timeout=true end
  if not ctx or not ctx.silent then echo_status('Group damage OFF ('..tostring(ctx and ctx.reason or 'manual')..').') end
end
function M.alias_loop_on_error(err)
  echo_status('Group damage error: '..tostring(err))
  Yso.mode.stop_route_loop(M.key,'error',true)
end
function M.note_slain(name)
  if trim(name):lower()==current_target():lower() then
    Yso.mode.stop_route_loop(M.key,'target_slain',false)
  end
end
if type(registerAnonymousEventHandler)=='function' then
  M.handlers=M.handlers or {}
  local callbacks={
    ['gmcp.Char.Vitals']=M.note_vitals,
    ['gmcp.Room.Players']=function() M.note_room_players(); Yso.mode.nudge_route_loop(M.key,'room_players') end,
    ['gmcp.Room.AddPlayer']=function()
      local entry=gmcp and gmcp.Room and gmcp.Room.AddPlayer
      local name=type(entry)=='table' and entry.name or entry
      if type(name)=='string' and M.state.room_players then
        M.state.room_players[trim(name):lower()]=true
        if trim(name):lower()==current_target():lower() then M.state.melee_missing=nil end
      end
      Yso.mode.nudge_route_loop(M.key,'room_add_player')
    end,
    ['gmcp.Room.RemovePlayer']=function()
      local entry=gmcp and gmcp.Room and gmcp.Room.RemovePlayer
      local name=type(entry)=='table' and entry.name or entry
      if type(name)=='string' and M.state.room_players then M.state.room_players[trim(name):lower()]=nil end
      Yso.mode.nudge_route_loop(M.key,'room_remove_player')
    end,
    ['gmcp.Room.Info']=function() M.state.room_players=nil; M.state.room_snapshot_invalid=true; M.state.melee_missing=nil end,
    sysDisconnectionEvent=function()
      Yso.mode.stop_route_loop(M.key,'disconnect',true)
      M.state.cooldown=nil
      M.state.room_players=nil; M.state.room_initialized=nil
      M.state.room_snapshot_invalid=true
    end,
  }
  for event,fn in pairs(callbacks) do
    if M.handlers[event] and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(M.handlers[event]) end
    M.handlers[event]=registerAnonymousEventHandler(event,fn)
  end
end
M.init()
return M
  end)()
  Yso.off.monk.group_damage._source_revision = revision
end
if not (Yso and Yso.util and type(Yso.util.toggle_route_alias)=='function') then
  if type(cecho)=='function' then cecho('<orange>[SHIKUDO] Route controller unavailable; check package load order.<reset>\n') end
  return
end
local ok, why = Yso.util.toggle_route_alias('monk_shikudo_group_damage', 'alias:shdam')
if ok ~= true and type(cecho)=='function' then
  cecho('<orange>[SHIKUDO] Toggle failed: '..tostring(why or 'unknown')..'<reset>\n')
end
