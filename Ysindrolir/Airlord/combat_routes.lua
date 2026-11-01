-- Airlord pressure/Compression offense, driven by Yso's alias route scheduler.
Yso = Yso or {}; Yso.off = Yso.off or {}; Yso.off.airlord = Yso.off.airlord or {}
local A=Yso.off.airlord
local function make_route(slot,key,name)
local M = A[slot] or {}; A[slot]=M
M.key=key; M.name=name; M.alias_owned=true
M.cfg=M.cfg or {loop_delay=0.15,pending_s=2.5,gauge_s=1.05}
M.state=M.state or {enabled=false,loop_enabled=false}
M.compression=Yso.off.airlord.compression
local function now() return Yso.util.now() end
local function confirmation_now()
 local P=Yso.Combat and Yso.Combat.Pause
 return P and P.confirmation_now(M.key) or now()
end
local function target() return type(Yso.get_target)=='function' and Yso.get_target() or '' end
local function lane_ready(lane)
  local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  local value=v[lane]
  if lane=='eq' and value==nil then value=v.equilibrium end
  if lane=='bal' and value==nil then value=v.balance end
  -- Package balance helpers may be optimistic when no state helper is loaded.
  -- A confirmed GMCP spend must still block a balance attack.
  if value==false or tostring(value)=='0' then return false end
  local locks=Yso.locks
  if locks and type(locks[lane..'_ready'])=='function' then return locks[lane..'_ready']()==true end
  local state=Yso.state
  if state and type(state[lane..'_ready'])=='function' then return state[lane..'_ready']()==true end
  return value==true or tostring(value)=='1'
end
local function score(aff)
  local s=affstrack and affstrack.score
  return tonumber(s and s[aff]) or 0
end
local function echo(text)
  if Yso.util and Yso.util.echo then Yso.util.echo(text)
  elseif type(cecho)=='function' then cecho('<cyan>[Yso] '..text..'<reset>\n') end
end
function M.init() return true end
function M.is_airlord()
  local info=Yso.classinfo
  local cls
  if info and type(info.get)=='function' then
    local ok,value=pcall(info.get)
    if ok and type(value)=='string' and value~='' then cls=value end
  end
  local status=gmcp and gmcp.Char and gmcp.Char.Status or {}
  cls=cls or status.class or status.classname or Yso.class or ''
  cls=tostring(cls):lower():gsub('^%s+',''):gsub('%s+$','')
  return cls=='air elemental lord' or cls=='air elemental lady' or cls=='air elemental fae'
end
function M.is_active()
  return Yso.mode and Yso.mode.route_loop_active and Yso.mode.route_loop_active(M.key) or M.state.loop_enabled==true
end
local function clear_staged(cmd)
  local q=Yso.queue
  if not q or not cmd or type(q.list)~='function' or type(q.clear)~='function'
      or q.list('bal')~=cmd then return end
  if type(q.get_staged_owner)=='function' then
    local owner=q.get_staged_owner('bal')
    if owner and owner.route==M.key and owner.cmd==cmd then q.clear('bal') end
  else
    local hint=q._commit_hint
    if not hint or hint.route==M.key then q.clear('bal') end
  end
end
-- Room.Info uses an indoors flag; outdoor rooms can have an empty details array.
-- Require a complete room packet so missing GMCP never implies outdoors.
function M.outdoor_room()
  local r=gmcp and gmcp.Room and gmcp.Room.Info
  if type(r)~='table' or not tonumber(r.num) or type(r.name)~='string' or r.name==''
      or type(r.details)~='table' then return nil end
  if r.name:lower():find('(indoors)',1,true) then return nil end
  for _,flag in pairs(r.details) do
    if tostring(flag):lower()=='indoors' then return nil end
  end
  return tostring(r.num)
end
function M.release_updraft()
  local p=M.state.pending
  if not p or p.category~='updraft' then return end
  clear_staged(p.cmd)
  local q=Yso.queue
  local owned=q and type(q.get_owned)=='function' and q.get_owned('bal') or nil
  if owned and owned.route==M.key and owned.cmd==p.cmd and type(q.clear_lane)=='function' then
    q.clear_lane('bal')
  end
  M.state.pending=nil; M.state.staged_bal=nil
end
function M.sync_updraft()
  local room=M.outdoor_room()
  local context=room and target():lower()..':'..room or nil
  if M.state.updraft_context~=context then
    M.release_updraft()
    M.state.updraft_context=context; M.state.updraft_launched=nil
  end
  local pressure=M.compression.level() or 0
  if not M.cfg.updraft_enabled or not room or pressure<4 or pressure>=6
      or (ak and ak.defs and ak.defs.shield) then
    M.release_updraft()
  end
  return context
end
function M.toggle_updraft()
  M.cfg.updraft_enabled=not M.cfg.updraft_enabled
  for _,route in ipairs({A.lock,A.damage}) do
    route.cfg.updraft_enabled=M.cfg.updraft_enabled
    route.sync_updraft()
  end
  echo('Airlord optional Updraft '..(M.cfg.updraft_enabled and 'ON.' or 'OFF.'))
  return M.cfg.updraft_enabled
end
function M.note_updraft(who)
  if type(who)~='string' or who:lower()~=target():lower() then return false end
  local context=M.sync_updraft()
  if not context then return false end
  M.state.updraft_launched=context
  M.note_success(who)
  return true
end
function M.note_landed(who)
  if type(who)~='string' or who:lower()~=target():lower() then return false end
  M.state.updraft_launched=nil
  return true
end
function M.reset()
  local q=Yso.queue
  if q then
    local pending=M.state.pending
    clear_staged(M.state.staged_bal or (pending and pending.cmd))
    local hint=q._commit_hint
    if (not hint or hint.route==M.key) and type(q.list)=='function' and type(q.clear)=='function' then
      if q._staged and type(q._staged.free)=='table' then
        local keep={}
        for _,cmd in ipairs(q._staged.free) do
          local observed=tostring(M.state.observation_target or '')
          if cmd~='gauge '..observed and not (slot=='damage' and cmd=='assess '..observed) then keep[#keep+1]=cmd end
        end
        q._staged.free=keep
      end
    end
    local owned=type(q.get_owned)=='function' and q.get_owned('bal') or nil
    if type(owned)=='table' and owned.route==M.key and type(q.clear_lane)=='function' then q.clear_lane('bal') end
  end
  M.state.pending=nil; M.state.gauge_at=nil; M.state.observation_target=nil
  M.state.staged_bal=nil
  M.state.execute_inflight=nil
  M.state.last_cmd=nil
  M.state.last_setup_cmd=nil
  M.state.hold_reason=nil
  M.state.updraft_context=nil; M.state.updraft_launched=nil
  M.compression.clear()
end
function M.on_target_swap() M.reset(); return true end
M.on_target_change=M.on_target_swap
M.on_target_slain=M.on_target_swap
M.on_target_cleared=M.on_target_swap
M.on_reset=M.on_target_swap
M.on_pause=M.on_target_swap
M.reset_route_state=M.reset
function M.can_run()
  if not M.state.enabled or not M.state.loop_enabled then return false,'disabled' end
  if Yso.offense_paused and Yso.offense_paused() then return false,'paused' end
  if not M.is_airlord() then return false,'wrong_class' end
  local t=target()
  if type(t)~='string' or t=='' then return false,'no_target' end
  local valid=Yso.target_is_valid or Yso.is_current_target
  if type(valid)=='function' and not valid(t) then return false,'invalid_target' end
  return true,t
end
function M.select_command(t)
  local context=M.sync_updraft()
  local d=ak and ak.duress or {}
  if ak and ak.defs and ak.defs.shield then return 'manifest gale '..t,'defense_break' end
  if M.compression.ready() then return 'aero compression '..t,'execute' end
  -- Weave Buffet with setup/Pressure instead of letting eligibility monopolize BAL.
  if slot=='damage' and M.buffet_ready() and M.state.last_cmd~='manifest buffet '..t then
    return 'manifest buffet '..t,'buffet'
  end
  if M.cfg.updraft_enabled and context and M.state.updraft_launched~=context
      and (M.compression.level() or 0)>=4 then
    return 'manifest updraft '..t,'updraft'
  end
  -- Tension adds pressure and another smoke cure, but is not a Pressure booster.
  -- Interleave after an immediately cured Tension so setup/Pressure progresses.
  -- Buffet must not erase the previous setup step when Tension is cured quickly.
  local last_setup=slot=='damage' and M.state.last_setup_cmd or M.state.last_cmd
  if score('tension')<100 and last_setup~='aero tension '..t then
    if d.asphyxiate~=true then return 'aero asphyxiate '..t,'smoke_tracking' end
    return 'aero tension '..t,'tension'
  end
  -- Confirmed afflictions, not fractional score sums, enable efficient pressure.
  local count=0
  for _,a in ipairs({'deadening','manaleech','disloyalty'}) do if score(a)>=100 then count=count+1 end end
  -- Once pressure is established, one confirmed booster is enough to keep
  -- building. Ambiguous smoking must not restart a full setup cycle at level 3.
  if count>=2 or (count>=1 and (M.compression.level() or 0)>0) then
    return 'aero pressure '..t,'pressure'
  end
  if d.asphyxiate~=true then return 'aero asphyxiate '..t,'smoke_tracking' end
  for _,row in ipairs({{'deadening','stranglerelapse','aero strangle '},
      {'manaleech','zephyrrelapse','manifest zephyr '},{'disloyalty','scourrelapse','aero scour '}}) do
    if score(row[1])<100 and d[row[2]]~=true then return row[3]..t,'affliction' end
  end
  return 'aero pressure '..t,'pressure'
end
function M.buffet_ready()
  if (M.compression.level() or 0)<=2 then return false end
  local count=0
  for _,aff in ipairs({'disloyalty','tension','manaleech','deadening'}) do
    if score(aff)>=100 then count=count+1 end
  end
  return count>=2
end
function M.sync_buffet()
  local p=M.state.pending
  if not p or p.category~='buffet' then return end
  if M.buffet_ready() and not (ak and ak.defs and ak.defs.shield)
      and not M.compression.ready() then return end
  clear_staged(p.cmd)
  local q=Yso.queue
  local owned=q and type(q.get_owned)=='function' and q.get_owned('bal') or nil
  if owned and owned.route==M.key and owned.cmd==p.cmd and type(q.clear_lane)=='function' then
    q.clear_lane('bal')
  end
  M.state.pending=nil; M.state.staged_bal=nil
end
function M.attack_function()
  local pause=Yso.Combat and Yso.Combat.Pause
  if pause then local blocked,reason=pause.blocked(M.key);if blocked then return false,reason end end
  local ok,t=M.can_run()
  if not ok then
    if t=='paused' or t=='wrong_class' or t=='no_target' or t=='invalid_target' then
      if M.state.hold_reason~=t then
        M.reset()
        echo(M.name..' holding ('..t..').')
      end
      M.state.hold_reason=t
    end
    return false,t
  end
  M.state.hold_reason=nil
  if M.state.observation_target and M.state.observation_target~=t then M.reset() end
  M.state.observation_target=t
  M.sync_updraft()
  M.sync_buffet()
  -- Gauge is free; this damage build's balanceless Assess shares its cadence.
  -- Both observations are sent together without waiting for EQ/BAL.
  if not M.state.gauge_at or now()-M.state.gauge_at>=M.cfg.gauge_s then
    local observations=slot=='damage' and {'gauge '..t,'assess '..t} or 'gauge '..t
    if Yso.emit({free=observations,target=t,route=M.key},{kind='offense',reason='airlord:gauge',target=t,route=M.key,commit=true,wake_lane='free',free_immediate=true}) then
      M.state.gauge_at=now()
    end
  end
  if not lane_ready('bal') then
    local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
    local actual=v.bal
    if actual==nil then actual=v.balance end
    if M.state.pending and (actual==nil or actual==false or tostring(actual)=='0') then
      M.state.pending.saw_down=true
    end
    if M.state.execute_inflight and (actual==false or tostring(actual)=='0') then
      M.state.execute_inflight.saw_down=true
    end
    return false,'bal_down'
  end
  local flight=M.state.execute_inflight
  if flight then
    if ak and ak.defs and ak.defs.shield then
      M.release_execute() -- Shield feedback blocks the execute; break it next.
    elseif flight.saw_down then
      if not flight.regained_at then flight.regained_at=now() end
      local observation=M.compression.state
      if M.compression.ready() and observation.at>flight.regained_at then
        M.release_execute() -- BAL completed and a new Gauge still shows eligibility.
      else return false,'execute_waiting_gauge' end
    elseif confirmation_now()-flight.confirmation_at>=M.cfg.pending_s then
      -- emit() also accepts staged commands. Neither staging nor dispatch
      -- proves execution; an unacknowledged submission has a bounded lifetime.
      if M.compression.ready() and M.compression.state.at>flight.at then
        M.release_execute()
      else return false,'execute_waiting_gauge' end
    else return false,'execute_inflight' end
  end
  local cmd,category=M.select_command(t)
  local p=M.state.pending
  if p and p.saw_down then M.state.pending=nil; p=nil end
  if p and confirmation_now()<p.until_at then
    -- A new confirmed execute or shield may supersede a setup attack once.
    if p.category==category or (category~='execute' and category~='defense_break') then return false,'pending' end
  end
  local payload={bal=cmd,target=t,route=M.key,category=category}
  local opts={kind='offense',reason='airlord:'..category,target=t,route=M.key,commit=true,wake_lane='bal',repeat_command=true}
  if not Yso.emit(payload,opts) then return false,'emit_failed' end
  local q=Yso.queue
  M.state.staged_bal=q and type(q.list)=='function' and q.list('bal')==cmd and cmd or nil
  M.state.pending={cmd=cmd,category=category,until_at=confirmation_now()+M.cfg.pending_s}
  if category=='execute' then M.state.execute_inflight={at=now(),confirmation_at=confirmation_now(),cmd=cmd,status='submitted'} end
  M.state.last_cmd=cmd
  if category~='buffet' then M.state.last_setup_cmd=cmd end
  return true,cmd
end
function M.release_execute()
  local flight=M.state.execute_inflight
  if flight then
    local q=Yso.queue
    if q then
      clear_staged(flight.cmd)
      local owned=type(q.get_owned)=='function' and q.get_owned('bal') or nil
      if type(owned)=='table' and owned.route==M.key and owned.cmd==flight.cmd
          and type(q.clear_lane)=='function' then q.clear_lane('bal') end
    end
    M.state.pending=nil; M.state.staged_bal=nil
  end
  M.state.execute_inflight=nil
end
function M.note_execute(who)
  if type(who)~='string' or who:lower()~=target():lower() then return false end
  local flight=M.state.execute_inflight
  if flight then
    flight.status='executed'; flight.saw_down=true
    M.note_success(who)
  end
  return true
end
function M.reject_pending()
  if not M.is_active() or not M.state.pending then return false end
  M.release_execute(); M.state.pending=nil
  return true
end
function M.on_send_result(payload)
  if type(payload)=='table' and payload.route==M.key and payload.success==false then
    M.release_execute(); M.state.pending=nil
  end
end
function M.note_success(who)
  if who and who:lower()~=target():lower() then return false end
  if M.state.pending then M.state.pending.acknowledged=true end
  return true
end
function M.alias_loop_on_started() M.reset(); echo(M.name..' ON.') end
function M.alias_loop_on_stopped(ctx)
  M.reset()
  if not ctx or not ctx.silent then echo(M.name..' OFF ('..tostring(ctx and ctx.reason or 'manual')..').') end
end
function M.alias_loop_clear_waiting() M.reset(); return true end
function M.alias_loop_waiting_blocks() return false end
-- Match the route-loop hold behavior: transient context blocks attacks, not the toggle.
M.alias_loop_stop_details={disabled=true}
function M.alias_loop_on_error(err) echo('Airlord error: '..tostring(err)) end
function M.on_exit()
  if Yso.mode and Yso.mode.stop_route_loop then Yso.mode.stop_route_loop(M.key,'exit',true) end
  M.reset(); return true
end
if Yso.off.core and Yso.off.core.register then Yso.off.core.register(M.key,M) end
if type(registerAnonymousEventHandler)=='function' then
  if M.room_handler and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(M.room_handler) end
  M.room_handler=registerAnonymousEventHandler('gmcp.Room.Info',function() M.sync_updraft() end)
end
return M
end
local lock=make_route('lock','airlord_lock','Airlord lock')
local damage=make_route('damage','airlord_damage','Damage route')
damage.cfg.updraft_enabled=lock.cfg.updraft_enabled==true
-- Feedback follows the active route; inactive state cannot acknowledge its work.
function A.feedback(method,...)
  for _,route in ipairs({A.lock,A.damage}) do
    if route.is_active() and type(route[method])=='function' then route[method](...) end
  end
end
return lock
