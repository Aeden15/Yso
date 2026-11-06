-- fstorm: one file. Edit SETTINGS and GIVING ORDER; the first matching rule wins.
Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.magi = Yso.off.magi or {}
local M = Yso.off.magi.firestorm or {}
Yso.off.magi.firestorm = M
M.key, M.name, M.alias_owned = 'magi_firestorm', 'Magi Firestorm', true

-- SETTINGS
M.cfg = {
  loop_delay = 0.15,
  echo = true,
  pending_s = 1.0,
  execute_hp = 25, -- Stormhammer below this percentage (same threshold as before).
  confirmed_score = 100,
  aflame_score = 200,
  firestorm_retry_s = 30, -- Minimum gap between room attempts, NOT effect duration.
}

-- GIVING ORDER: each rule is checked from top to bottom on every attack.
-- This is a priority list, not a fixed rotation. Return one full command.
function M.choose(s)
  local target = s.target
  -- 1. Shield -> Erode.
  if s.shield then
    return 'cast erode at '..target..' shield', 'defense_break', 'shielded'
  end
  -- 2. Shared finishers: Destroy/Assess first, otherwise Convergence.
  if s.special or s.special_hold then
    return s.special, 'special', s.special_reason
  end
  -- 3. Target HP below execute_hp -> Stormhammer.
  if s.hp and s.hp < M.cfg.execute_hp then
    return 'cast stormhammer at '..target, 'execute', 'hp_stormhammer'
  end
  -- 4. Scalded missing and Earth 0 -> Pebble.
  if not s.scalded and s.earth == 0 then
    return 'cast pebble at '..target, 'earth_setup', 'scalded_missing_earth0'
  end
  -- 5. Confirmed Scalded missing -> Magma. Sending never counts as Scalded.
  if not s.scalded then
    return 'cast magma at '..target, 'fire_build', 'scalded_missing'
  end
  -- Build the room spell only when its attempt interval has expired.
  if not s.room_attempt_recent then
    -- 6. Air below 3 and Earth below 2 -> Bombard.
    if s.air < 3 and s.earth < 2 then
      return 'cast bombard at '..target, 'resonance_build', 'air_earth_build'
    end
    -- 7. Air at least 3, Fire below 3, Water below 2 -> Dehydrate.
    if s.air >= 3 and s.fire < 3 and s.water < 2 then
      return 'cast dehydrate at '..target, 'resonance_build', 'fire_water_build'
    end
    -- 8. Air at least 3 and Fire below 3 -> Firelash.
    if s.air >= 3 and s.fire < 3 then
      return 'cast firelash at '..target, 'resonance_build', 'fire_only_build'
    end
    -- 9. Air or Fire below 3 -> Fulminate.
    if s.air < 3 or s.fire < 3 then
      return 'cast fulminate at '..target, 'resonance_build', 'air_fire_build'
    end
    -- 10. Major Air and Fire -> Firestorm (a room spell, no target suffix).
    return 'cast firestorm', 'firestorm', 'firestorm_ready'
  end
  -- 11. Conflagrate missing, at least two ablaze stacks, Fire >=2 -> Conflagrate.
  if not s.conflagrate and s.aflame and s.fire >= 2 then
    return 'cast conflagrate at '..target, 'fire_payoff', 'conflagrate_ready'
  end
  -- 12. Conflagrate missing and Fire at least 3 -> Fire Emanation.
  if not s.conflagrate and s.fire >= 3 then
    return 'cast emanation at '..target..' fire', 'fire_promotion', 'ablaze_setup'
  end
  -- 13. Confirmed Conflagrate and Earth at least 3 -> Earth Emanation.
  if s.conflagrate and s.earth >= 3 then
    return 'cast emanation at '..target..' earth', 'earth_promotion', 'conflag_emanate_earth'
  end
  -- 14. Fire below 3 and Water below 2 -> Dehydrate.
  if s.fire < 3 and s.water < 2 then
    return 'cast dehydrate at '..target, 'fire_build', 'fire_water_pressure'
  end
  -- 15. Air at least 3 and Fire below 3 -> Firelash.
  if s.air >= 3 and s.fire < 3 then
    return 'cast firelash at '..target, 'fire_build', 'fire_only_pressure'
  end
  -- 16. Otherwise -> Fulminate.
  return 'cast fulminate at '..target, 'fire_build', 'fulminate_pressure'
end

-- INPUTS AND ROUTE CHECKS
Yso.off.magi.route_core = Yso.off.magi.route_core or {}
local RC = Yso.off.magi.route_core
local RI = Yso.Combat and Yso.Combat.RouteInterface
M.state = M.state or {}
M.route_contract = {
  id=M.key,interface_version=1,shared_categories={'defense_break'},route_local_categories={'execute','firestorm'},
  capabilities={uses_eq=true,uses_bal=false,uses_entity=false,supports_burst=true,supports_bootstrap=false,needs_target=true},
  override_policy={mode='narrow_global_only',allowed={target_invalid=true,target_slain=true,route_off=true,
    pause=true,manual_suppression=true,target_swap_bootstrap=true}},
}
if RI and RI.ensure_hooks then RI.ensure_hooks(M,M.route_contract) end
local function ready() return type(RC.get_target)=='function' and type(RC.read_resonance)=='function' and type(RC.mark_pending)=='function' end
local function is_magi()
  local check=Yso.is_magi or (Yso.classinfo and Yso.classinfo.is_magi) or (Yso.magi and Yso.magi.defs and Yso.magi.defs.is_magi)
  if type(check)~='function' then return false end
  local ok,value=pcall(check)
  return ok and value==true
end
local function notify(message)
  if M.cfg.echo and type(cecho)=='function' then cecho('<cadet_blue>[Yso:Magi] <reset>'..message..'\n') end
end
local function room_key()
  local info=((rawget(_G,'gmcp') or {}).Room or {}).Info or {}
  return tostring(info.num or info.id or 'unknown')
end
function M.init()
  M.state.loop_delay=M.cfg.loop_delay
  M.state.pending=M.state.pending or {}
  M.state.firestorm_rooms=M.state.firestorm_rooms or {}
  M.state.template=M.state.template or {}
  if RI and RI.ensure_waiting_state then RI.ensure_waiting_state(M.state,M.key) end
  return true
end
function M.clear_runtime()
  M.init()
  M.state.submission,M.state.pending=nil,{}
  M.state.firestorm_dispatch=nil
  M.state.last_ack_payload=Yso._last_eq_ack_payload or (Yso.queue and Yso.queue._last_ack_payload)
  if RI and RI.clear_waiting then RI.clear_waiting(M.state,M.key) end
  return true
end
function M.is_enabled() return M.state.enabled==true end
function M.is_active()
  if not is_magi() or not (Yso.mode and Yso.mode.is_combat and Yso.mode.is_combat()) then return false end
  if Yso.mode.route_loop_active then return Yso.mode.route_loop_active(M.key)==true end
  return M.state.loop_enabled==true
end
function M.can_run(ctx)
  M.init()
  ctx=type(ctx)=='table' and ctx or {}
  if not ready() then return false,'core_unavailable' end
  if not M.is_enabled() then return false,'disabled' end
  if not M.is_active() then return false,'inactive' end
  if Yso.offense_paused and Yso.offense_paused() then
    if not ctx.preview then M.clear_runtime() end
    return false,'paused'
  end
  local target=RC.trim(ctx.target or RC.get_target())
  if target=='' then return false,'no_target' end
  if not RC.same_target(target,RC.get_target()) then return false,'target_mismatch' end
  if not RC.target_valid(target) then return false,'invalid_target' end
  if not RC.eq_ready() then return false,'eq_down' end
  return true,target
end
function M.snapshot(target)
  local r,score=RC.read_resonance(),RC.score_aff
  local defs=(rawget(_G,'ak') or {}).defs or {}
  local shield=defs.shield
  if defs.shield_by_target then shield=defs.shield_by_target[target:lower()] end
  if Yso.shield and Yso.shield.up then shield=Yso.shield.up(target:lower()) end
  local special,reason,hold=RC.special_action(target)
  local attempted=(M.state.firestorm_rooms or {})[room_key()]
  return {target=target,hp=RC.get_target_hp_percent(target),shield=shield==true,
    air=r.air,earth=r.earth,fire=r.fire,water=r.water,
    scalded=score('scalded')>=M.cfg.confirmed_score,
    conflagrate=math.max(score('conflagrate'),score('conflagration'))>=M.cfg.confirmed_score,
    aflame=score('aflame')>=M.cfg.aflame_score,
    room=room_key(),room_attempt_recent=type(attempted)=='number' and RC.now()-attempted<M.cfg.firestorm_retry_s,
    special=special,special_reason=reason,special_hold=hold}
end

-- SENDING: reserve before emit; an acknowledgement confirms dispatch, not spell success.
local function last_ack() return Yso._last_eq_ack_payload or (Yso.queue and Yso.queue._last_ack_payload) end
local function flight(target,preview)
  local sub=M.state.submission
  if sub and (not RC.same_target(sub.target,target) or RC.now()>=sub.until_t) then
    if not preview then M.clear_runtime() end
    return nil
  end
  return sub
end
function M.attack_function(arg)
  local ctx=type(arg)=='table' and arg or {}
  if ready() then
    local target=RC.get_target()
    if not ctx.target or RC.same_target(ctx.target,target) then RC.entourage_sync(M,target,is_magi(),ctx.preview) end
  end
  local ok,target=M.can_run(ctx)
  if not ok then return false,target end
  local sub=flight(target,ctx.preview)
  if sub and not sub.acknowledged then return false,sub.slot..'_pending' end
  local command,category,reason=M.choose(M.snapshot(target))
  if not ctx.preview then M.state.template.last_reason,M.state.template.last_target=reason,target end
  if not command then return false,reason end
  local slot=command:match('^cast%s+(%S+)') or 'eq'
  local pending=M.state.pending[slot]
  if pending and RC.same_target(pending.target,target) and RC.now()<pending.until_t then
    if not ctx.preview then M.state.template.last_reason=slot..'_pending' end
    return false,slot..'_pending'
  end
  local payload={target=target,eq=command,lanes={eq=command},meta={main_lane='eq',main_category=category,main_reason=reason}}
  if ctx.preview then return payload end
  sub={cmd=command,target=target,slot=slot,until_t=RC.now()+M.cfg.pending_s,emitting=true,previous_eq_ack=last_ack()}
  M.state.submission=sub
  if RI and RI.mark_waiting then RI.mark_waiting(M.state,M.key,payload,{main_lane='eq'}) end
  local opts={route=M.key,target=target,kind='offense',commit=true,reason=M.key..':'..category}
  local sent,detail,ack
  if RI and RI.emit_route_payload then sent,detail,ack=RI.emit_route_payload(M.key,payload,opts)
  elseif type(Yso.emit)=='function' then sent=Yso.emit(payload,opts);ack=payload end
  sub.emitting,sub.payload=false,ack
  if sent~=true then M.clear_runtime();return false,detail or 'emit_failed' end
  RC.mark_pending(M.state,slot,target,M.cfg.pending_s)
  RC.note_special_queued(command,target)
  local bus=Yso.locks and Yso.locks.note_payload and Yso.queue and Yso.queue.commit
  if not sub.acknowledged and (not bus or (Yso.net and Yso.net.cfg and Yso.net.cfg.dry_run)) then M.on_payload_sent(ack or payload) end
  M.state.last_cmd,M.state.last_category,M.state.last_target=command,category,target
  return true,command
end
function M.on_payload_sent(payload)
  M.init()
  if not ready() or type(payload)~='table' then return false end
  if RI and RI.payload_has_any_route and RI.payload_has_any_route(payload) and not RI.payload_has_route(payload,M.key) then return false end
  local lanes=payload.lanes or payload
  local command=lanes.eq or payload.eq
  if not command and not payload.lanes and not (payload.bal or payload.free or payload.class or payload.ent or payload.entity) then command=payload.cmd end
  command=RC.trim(command)
  if command=='' then return false end
  local sub,latest=M.state.submission,last_ack()
  if payload==M.state.last_ack_payload or (sub and payload==sub.previous_eq_ack) then return false end
  local target=RC.trim(payload.target or RC.get_target())
  local matched=sub and not sub.acknowledged and command==sub.cmd and RC.same_target(target,sub.target)
    and (payload==sub.payload or payload==latest)
  -- Direct/manual API dispatches also reach this hook through the canonical ACK bus.
  if not matched and payload~=latest then return false end
  if matched then
    sub.acknowledged,sub.ack_payload,sub.until_t=true,payload,RC.now()+M.cfg.pending_s
    RC.mark_pending(M.state,sub.slot,target,M.cfg.pending_s)
    if RI and RI.clear_waiting then RI.clear_waiting(M.state,M.key) end
  elseif sub then M.clear_runtime() end
  M.state.last_ack_payload=payload
  M.state.firestorm_dispatch=nil
  if command=='cast firestorm' then
    local room=room_key()
    M.state.firestorm_rooms[room]=RC.now()
    M.state.firestorm_dispatch={payload=payload,room=room,eq_ack=latest}
  end
  return true
end
M.on_payload_queued=M.on_payload_sent
function M.on_send_result(payload,ctx)
  if not (type(ctx)=='table' and ctx.success==false) then return true end
  local sub,dispatch=M.state.submission,M.state.firestorm_dispatch
  if dispatch and payload==dispatch.payload then
    M.state.firestorm_rooms[dispatch.room]=nil
    M.state.firestorm_dispatch=nil
    if ready() then RC.clear_pending(M.state,'firestorm') end
  end
  if sub and (payload==sub.payload or payload==sub.ack_payload) then M.clear_runtime() end
  return true
end
function M.on_resonance_failure(required,element)
  local dispatch=M.state.firestorm_dispatch
  if not dispatch or required~=3 or (element~='air' and element~='fire') then return false end
  local latest=last_ack()
  if latest and latest~=dispatch.eq_ack and latest~=dispatch.payload then
    local lanes=latest.lanes or latest
    if RC.trim(lanes.eq or latest.eq)~='' then M.state.firestorm_dispatch=nil;return false end
  end
  return M.on_send_result(dispatch.payload,{success=false})
end
function M.on_firestorm_ended(room)
  M.init()
  M.state.firestorm_rooms[tostring(room or room_key())]=nil
  return true
end

-- LOOP LIFECYCLE
M.alias_loop_stop_details={inactive=true,disabled=true,no_target=true,invalid_target=true,wrong_class=true,core_unavailable=true}
function M.alias_loop_prepare_start(ctx) M.clear_runtime();return ctx or {} end
function M.alias_loop_on_started()
  M.clear_runtime();M.state.firestorm_rooms,M.state.firestorm_dispatch={},nil
  if ready() then RC.entourage_sync(M,RC.get_target(),is_magi()) end
  notify('Firestorm loop ON.')
end
function M.alias_loop_on_stopped(ctx)
  M.clear_runtime();M.state.firestorm_rooms,M.state.firestorm_dispatch={},nil
  if RC.entourage_passive then RC.entourage_passive(M) end
  ctx=ctx or {};M.state.template.last_disable_reason=ctx.reason or 'manual'
  if not ctx.silent then notify('Firestorm loop OFF ('..M.state.template.last_disable_reason..').') end
end
function M.alias_loop_waiting_blocks()
  if not ready() then return false end
  if Yso.offense_paused and Yso.offense_paused() then M.clear_runtime();return false end
  local sub=flight(RC.get_target())
  return sub~=nil and not sub.acknowledged
end
M.alias_loop_clear_waiting=M.clear_runtime
M.on_target_swap=M.clear_runtime
M.on_pause=M.clear_runtime
function M.alias_loop_on_error(err) notify('Firestorm loop error: '..tostring(err)) end
function M.on_exit()
  M.alias_loop_on_stopped({silent=true,reason='exit'})
  if Yso.mode and Yso.mode.stop_route_loop then Yso.mode.stop_route_loop(M.key,'exit',true) end
  return true
end
function M.evaluate(ctx) return M.attack_function({preview=true,target=type(ctx)=='table' and ctx.target or nil}) end
function M.explain()
  if not ready() then return {reason='core_unavailable'} end
  local s=M.snapshot(RC.get_target());s.command,s.category,s.reason=M.choose(s)
  return s
end
M.clear_runtime();M.state.firestorm_rooms,M.state.firestorm_dispatch={},nil
if Yso.off.core and Yso.off.core.register then Yso.off.core.register(M.key,M) end
return M
