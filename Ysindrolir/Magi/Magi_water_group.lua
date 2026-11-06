-- gwater: one file. Edit SETTINGS and GIVING ORDER; the first matching rule wins.
Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.magi = Yso.off.magi or {}
local M = Yso.off.magi.water_group or {}
Yso.off.magi.water_group = M
M.key, M.name, M.alias_owned = 'magi_water_group', 'Magi Water Group', true

-- SETTINGS
M.cfg = {
  loop_delay = 0.15,
  echo = true,
  pending_s = 1.0,
  execute_hp = 20,
  confirmed_score = 100,
  shivering_score = 200, -- AK cold ladder: 100 includes stripped insulation.
  frozen_score = 300,
  allow_hypothermia = (Yso.magi and Yso.magi.spell_feedback and
    Yso.magi.spell_feedback.hypothermia_tracking == true) or false,
}

-- GIVING ORDER: each line below is checked from top to bottom on every attack.
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
  -- 3. Target HP at or below execute_hp -> Stormhammer.
  if s.hp and s.hp <= M.cfg.execute_hp then
    return 'cast stormhammer at '..target, 'execute', 'hp_stormhammer'
  end
  -- 4. Fully frozen + Hypothermia + Water/Air at least 2 -> Glaciate.
  if s.frozen and s.hypothermia and s.water >= 2 and s.air >= 2 then
    return 'cast glaciate at '..target, 'glaciate_burst', 'glaciate_ready'
  end
  -- 5. At least shivering and Waterbonds missing -> staff cast Horripilation.
  if (s.shivering or s.frozen) and not s.waterbonds then
    return 'staff cast horripilation at '..target, 'waterbonds_setup', 'waterbonds_missing_cold'
  end
  -- 6. Scalded missing and Earth 0 -> Pebble.
  if not s.scalded and s.earth == 0 then
    return 'cast pebble at '..target, 'earth_setup', 'scalded_missing_earth0'
  end
  -- 7. Fully frozen, Hypothermia missing, Water/Air at least 2 -> Hypothermia.
  if M.cfg.allow_hypothermia and s.frozen and not s.hypothermia and s.water >= 2 and s.air >= 2 then
    return 'cast hypothermia at '..target, 'freeze_setup', 'hypothermia_missing'
  end
  -- 8. Water below 2 -> Dehydrate.
  if s.water < 2 then
    return 'cast dehydrate at '..target, 'resonance_build', 'build_water'
  end
  -- 9. Shivering + nausea without weariness -> Dehydrate; otherwise Freeze.
  if s.shivering then
    if s.nausea and not s.weariness then
      return 'cast dehydrate at '..target, 'freeze_setup', 'shiver_nausea'
    end
    return 'cast freeze at '..target, 'freeze_setup', 'shivering'
  end
  -- 10. Air below 2 -> Bombard if Earth is below 2; otherwise Fulminate.
  if s.air < 2 then
    if s.earth < 2 then
      return 'cast bombard at '..target, 'resonance_build', 'build_air_earth'
    end
    return 'cast fulminate at '..target, 'resonance_build', 'build_air_fire'
  end
  -- 11. Not fully frozen -> Freeze.
  if not s.frozen then
    return 'cast freeze at '..target, 'freeze_setup', 'build_cold'
  end
  -- 12. Earth at least 3 -> Earth Emanation.
  if s.earth >= 3 then
    return 'cast emanation at '..target..' earth', 'earth_promotion', 'earth_major'
  end
  -- 13. Water at least 3 -> Water Emanation.
  if s.water >= 3 then
    return 'cast emanation at '..target..' water', 'water_promotion', 'water_major'
  end
  -- 14. Slickness missing -> Mudslide.
  if not s.slickness then
    return 'cast mudslide at '..target, 'salve_pressure', 'slickness_missing'
  end
  -- 15. Fire below 2 -> Fulminate.
  if s.fire < 2 then
    return 'cast fulminate at '..target, 'kelp_pressure', 'build_fire'
  end
  -- 16. Otherwise -> Dehydrate.
  return 'cast dehydrate at '..target, 'disrupt_setup', 'water_pressure'
end

-- INPUTS AND ROUTE CHECKS
Yso.off.magi.route_core = Yso.off.magi.route_core or {}
local RC = Yso.off.magi.route_core
local RI = Yso.Combat and Yso.Combat.RouteInterface
M.state = M.state or {}
M.route_contract = {
  id=M.key, interface_version=1, shared_categories={'defense_break'}, route_local_categories={'execute','water_group'},
  capabilities={uses_eq=true,uses_bal=false,uses_entity=false,supports_burst=true,supports_bootstrap=false,needs_target=true},
  override_policy={mode='narrow_global_only',allowed={target_invalid=true,target_slain=true,route_off=true,
    pause=true,manual_suppression=true,target_swap_bootstrap=true}},
}
if RI and RI.ensure_hooks then RI.ensure_hooks(M,M.route_contract) end
local function ready() return type(RC.get_target)=='function' and type(RC.mark_pending)=='function' end
local function is_magi()
  local check=Yso.is_magi or (Yso.classinfo and Yso.classinfo.is_magi) or (Yso.magi and Yso.magi.defs and Yso.magi.defs.is_magi)
  if type(check)~='function' then return false end
  local ok,value=pcall(check)
  return ok and value==true
end
local function notify(message)
  if M.cfg.echo and type(cecho)=='function' then cecho('<cadet_blue>[Yso:Magi] <reset>'..message..'\n') end
end
function M.init()
  M.state.loop_delay=M.cfg.loop_delay
  M.state.pending=M.state.pending or {}
  M.state.template=M.state.template or {}
  if RI and RI.ensure_waiting_state then RI.ensure_waiting_state(M.state,M.key) end
  return true
end
function M.clear_runtime()
  M.init()
  M.state.submission,M.state.pending=nil,{}
  M.state.last_sent_cmd,M.state.last_sent_target,M.state.last_sent_at='','',0
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
  local cold=score('frozen')
  local defs=(rawget(_G,'ak') or {}).defs or {}
  local shield=defs.shield
  if defs.shield_by_target then shield=defs.shield_by_target[target:lower()] end
  if Yso.shield and Yso.shield.up then shield=Yso.shield.up(target:lower()) end
  local special,reason,hold=RC.special_action(target)
  return {target=target,hp=RC.get_target_hp_percent(target),shield=shield==true,
    air=r.air,earth=r.earth,fire=r.fire,water=r.water,
    frozen=cold>=M.cfg.frozen_score,shivering=cold>=M.cfg.shivering_score and cold<M.cfg.frozen_score,
    waterbonds=score('waterbonds')>=M.cfg.confirmed_score,
    hypothermia=score('hypothermia')>=M.cfg.confirmed_score,nausea=score('nausea')>=M.cfg.confirmed_score,
    weariness=score('weariness')>=M.cfg.confirmed_score,slickness=score('slickness')>=M.cfg.confirmed_score,
    scalded=score('scalded')>=M.cfg.confirmed_score,special=special,special_reason=reason,special_hold=hold}
end

-- SENDING: one reservation covers the send-to-ack gap; spell windows prevent repeats.
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
  if ready() then RC.entourage_sync(M,ctx.target or RC.get_target(),is_magi(),ctx.preview) end
  local ok,target=M.can_run(ctx)
  if not ok then return false,target end
  local sub=flight(target,ctx.preview)
  if sub and not sub.acknowledged then
    local reason=sub.slot..'_pending'
    if not ctx.preview then M.state.template.last_reason=reason end
    return false,reason
  end
  local command,category,reason=M.choose(M.snapshot(target))
  if not ctx.preview then M.state.template.last_reason,M.state.template.last_target=reason,target end
  if not command then return false,reason end
  local slot=command:match('^cast%s+(%S+)') or command:match('^staff%s+cast%s+(%S+)') or 'eq'
  local pending=M.state.pending[slot]
  if pending and RC.same_target(pending.target,target) and RC.now()<pending.until_t then
    if not ctx.preview then M.state.template.last_reason=slot..'_pending' end
    return false,slot..'_pending'
  end
  local payload={target=target,eq=command,lanes={eq=command},meta={main_lane='eq',main_category=category,main_reason=reason}}
  if ctx.preview then return payload end
  if Yso.magi and Yso.magi.weapons and Yso.magi.weapons.send_wields then Yso.magi.weapons.send_wields() end
  sub={cmd=command,target=target,slot=slot,until_t=RC.now()+M.cfg.pending_s,emitting=true,previous_eq_ack=last_ack()}
  M.state.submission=sub -- Reserve before emit: acknowledgements may be synchronous.
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
  if not bus or (Yso.net and Yso.net.cfg and Yso.net.cfg.dry_run) then M.on_payload_sent(ack or payload) end
  M.state.last_cmd,M.state.last_category,M.state.last_target=command,category,target
  return true,command
end
function M.on_payload_sent(payload)
  M.init()
  if type(payload)~='table' then return false end
  if RI and RI.payload_has_any_route and RI.payload_has_any_route(payload) and not RI.payload_has_route(payload,M.key) then return false end
  local lanes=payload.lanes or payload
  local command=lanes.eq or payload.eq
  if not command and not payload.lanes and not (payload.bal or payload.free or payload.class or payload.ent or payload.entity) then command=payload.cmd end
  local sub=M.state.submission
  local target=RC.trim(payload.target or RC.get_target())
  if not sub or RC.trim(command)~=sub.cmd or not RC.same_target(target,sub.target) then return false end
  local latest=last_ack()
  if not sub.emitting and payload~=sub.payload and (payload~=latest or latest==sub.previous_eq_ack) then return false end
  sub.acknowledged,sub.ack_payload,sub.until_t,sub.eq_ack=true,payload,RC.now()+M.cfg.pending_s,latest
  RC.mark_pending(M.state,sub.slot,target,M.cfg.pending_s)
  if RI and RI.clear_waiting then RI.clear_waiting(M.state,M.key) end
  return true
end
M.on_payload_queued=M.on_payload_sent
function M.on_send_result(payload,ctx)
  local sub=M.state.submission
  if not sub or type(payload)~='table' then return false end
  if ctx and ctx.success==false and (payload==sub.payload or payload==sub.ack_payload) then M.clear_runtime() end
  return true
end
function M.on_resonance_failure(required,element)
  if not ready() then return false end
  local sub=flight(RC.get_target())
  if not sub or not sub.acknowledged or last_ack()~=sub.eq_ack then return false end
  local plane=sub.cmd:match('^cast emanation at %S+ (%a+)$')
  if (plane==element and required==3) or ((sub.slot=='glaciate' or sub.slot=='hypothermia') and required==2 and (element=='air' or element=='water')) then return M.clear_runtime() end
  return false
end

-- LOOP LIFECYCLE
M.alias_loop_stop_details={inactive=true,disabled=true,no_target=true,invalid_target=true,wrong_class=true,core_unavailable=true}
function M.alias_loop_prepare_start(ctx) M.clear_runtime();return ctx or {} end
function M.alias_loop_on_started()
  M.clear_runtime()
  if ready() then RC.entourage_sync(M,RC.get_target(),is_magi()) end
  notify('Water group loop ON.')
end
function M.alias_loop_on_stopped(ctx)
  M.clear_runtime()
  if RC.entourage_passive then RC.entourage_passive(M) end
  ctx=ctx or {}
  M.state.template.last_disable_reason=ctx.reason or 'manual'
  if not ctx.silent then notify('Water group loop OFF ('..M.state.template.last_disable_reason..').') end
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
function M.alias_loop_on_error(err) notify('Water group loop error: '..tostring(err)) end
function M.on_exit()
  M.clear_runtime()
  if RC.entourage_passive then RC.entourage_passive(M) end
  if Yso.mode and Yso.mode.stop_route_loop then Yso.mode.stop_route_loop(M.key,'exit',true) end
  return true
end
function M.evaluate(ctx) return M.attack_function({preview=true,target=type(ctx)=='table' and ctx.target or nil}) end
function M.explain()
  if not ready() then return {reason='core_unavailable'} end
  local s=M.snapshot(RC.get_target())
  s.command,s.category,s.reason=M.choose(s)
  s.allow_hypothermia=M.cfg.allow_hypothermia
  return s
end
M.clear_runtime()
if Yso.off.core and Yso.off.core.register then Yso.off.core.register(M.key,M) end
return M
