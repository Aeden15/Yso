-- Lock decisions are separate from delivery; AK owns confirmed target state.
Yso=Yso or {};Yso.off=Yso.off or {};Yso.off.apostate=Yso.off.apostate or {}
local M=Yso.off.apostate.truelock or {};Yso.off.apostate.truelock=M
M.key='apostate_truelock';M.alias_owned=true
M.state=M.state or {};M.state.loop_delay=0.15
M.Affliction_giving={
 'paralysis','undeaf','impatience','asthma','manaleech','slickness','anorexia','disloyalty',
}
M.Padding_mental_afflictions={
 'stupidity','confusion','dizziness','dementia',
}
M.undeaf_delivery='evileye' -- Optional: 'prefarar' uses Puncture when available.
local eyes={undeaf='sensitivity',slickness='sicken',stupidity='stupid',dizziness='dizzy'}
local function present(value) return value==true or (tonumber(value) or 0)>=100 end
local function same(a,b) return type(a)=='string' and type(b)=='string' and a:lower()==b:lower() end
local function valid(name) return type(name)=='string' and name:match("^[A-Za-z][A-Za-z'%-]*$") end
local function victim() return type(Yso.get_target)=='function' and Yso.get_target() or '' end
local function now()
 local t=type(getEpoch)=='function' and tonumber(getEpoch()) or os.time()
 return t>20000000000 and t/1000 or t
end

-- Conditions control eligibility; the editable lists control giving order.
function M.select(scores)
 local opening=not present(scores.asthma) or not present(scores.impatience)
 local needs_manaleech=not present(scores.manaleech)
 local eligible={paralysis=true,undeaf=true}
 if opening then eligible.impatience=true;eligible.asthma=true
 elseif needs_manaleech then eligible.manaleech=true
 else eligible.slickness=true;eligible.anorexia=true end
 local out,seen={},{}
 local function add(aff)
  -- AK's deaf=100 means deafness has been stripped; no new score is invented.
  local score=aff=='undeaf' and scores.deaf or scores[aff]
  if #out<2 and not seen[aff] and not present(score) then
   out[#out+1]=aff;seen[aff]=true
  end
 end
 for _,aff in ipairs(M.Affliction_giving) do if eligible[aff] then add(aff) end end
 if not opening and needs_manaleech then
  for _,aff in ipairs(M.Padding_mental_afflictions) do add(aff) end
 end
 return out
end
function M.eye_command(name,picks,curseward)
 if #picks==0 then return nil end
 local first=eyes[picks[1]] or picks[1]
 if curseward then return 'deadeyes '..name..' breach '..first end
 if picks[2] then return 'deadeyes '..name..' '..first..' '..(eyes[picks[2]] or picks[2]) end
 return 'stare '..name..' '..first
end

local function note(text)
 if type(cecho)=='function' then cecho('<DeepPink>[Truelocks] <reset>'..text..'\n') end
end
function M.is_enabled() return M.state.loop_enabled==true end
function M.is_active()
 return M.is_enabled() and Yso.apostate and Yso.apostate.active()
  and Yso.mode and Yso.mode.is_combat()
end
function M.stop(reason)
 if Yso.mode and Yso.mode.stop_route_loop then Yso.mode.stop_route_loop(M.key,reason,false)
 else M.state.loop_enabled=false;M.alias_loop_on_stopped({reason=reason}) end
 return false
end
function M.alias_loop_prepare_start(ctx)
 M.state.pending=nil;M.state.victim=nil;M.state.reason=nil
 M.state.commands={}
 M.state.bal_until=nil;M.state.eq_until=nil;M.state.startup_error=nil
 return ctx
end
function M.alias_loop_on_started()
 if M.state.creatures_ordered and M.state.victim then return end
 local name=victim()
 if not valid(name) then M.state.startup_error='no_target';return end
 if not (Yso.apostate and Yso.apostate.active()) then M.state.startup_error='wrong_class';return end
 if not same(name,target) then M.state.startup_error='ak_target_mismatch';return end
 local entourage=Yso.apostate.entourage
 if not entourage then M.state.startup_error='entourage_unavailable';return end
 M.state.victim=name;M.state.creatures_ordered=true
 if not entourage.attack(name) then M.state.startup_error='creature_orders_failed' end
 note('ON.')
end
function M.alias_loop_on_stopped(ctx)
 if M.state.creatures_ordered then
  local entourage=Yso.apostate and Yso.apostate.entourage
  if entourage and entourage.passive() then M.state.creatures_ordered=nil
  else note('Unable to send entourage passive order.') end
 end
 -- Older profiles may still have route-owned compatibility queue entries.
 local Q=Yso.queue
 if Q and type(Q.get_owned)=='function' then
  for _,lane in ipairs({'bal','eq','free'}) do
   local command=M.state.commands and M.state.commands[lane]
   if command and type(Q.list)=='function' and Q.list(lane)==command and Q.clear then Q.clear(lane) end
   local owned=Q.get_owned(lane)
   if owned and owned.route==M.key then
    if Q.clear_lane then pcall(Q.clear_lane,lane) end
   end
  end
 end
 M.state.pending=nil;M.state.victim=nil;M.state.reason=nil
 if ak and ak.apostate then ak.apostate.pending_daegger_wipe=nil end
 note('OFF ('..tostring(ctx and ctx.reason or 'manual')..').')
end
function M.alias_loop_clear_waiting() M.state.waiting={} end
function M.alias_loop_waiting_blocks() return false end
function M.alias_loop_on_error() M.stop('route_error') end
function M.reset_route_state(reason) if M.is_enabled() then M.stop(reason or 'external_reset') end end
function M.status() return {enabled=M.is_enabled(),target=M.state.victim,reason=M.state.reason} end
local function ready(lane)
 local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
 local value=v[lane];if value==nil then value=v[lane=='bal' and 'balance' or 'equilibrium'] end
 return (value==true or tostring(value)=='1') and now()>=(M.state[lane..'_until'] or 0)
  and not (Yso.locks and type(Yso.locks.ready)=='function' and not Yso.locks.ready(lane))
end
local function hold(reason) M.state.reason=reason;return false,reason end
function M.note_pressure(kind,name,delivered)
 local p=M.state.pending
 if not p or kind~=p.action or not same(name,p.target) or not same(name,victim()) then return end
 if kind=='puncture' and delivered~=true then return M.stop('venom_delivery_unconfirmed') end
 p.confirmed=true
end
function M.note_eye_rejected(reason,name)
 local p=M.state.pending
 if not M.is_enabled() or not p or p.action~='eyes' or not same(p.target,victim()) or (name and not same(name,p.target)) then return false end
 if reason=='blind' then return M.stop('eyes_blind') end
 if reason~='equilibrium' and reason~='balance' and reason~='curseward' then return false end
 if reason=='curseward' then ak.defs=ak.defs or {};ak.defs.curseward=true end
 p.rejected=reason;return true
end
function M.note_prompt()
 local p=M.state.pending;if not p then return end
 if not same(p.target,victim()) then return M.stop('target_changed') end
 if p.rejected or (p.confirmed and (not p.breach or (ak.defs and ak.defs.curseward==false))) then M.state.pending=nil end
end
function M.attack_function()
 if M.state.startup_error then return M.stop(M.state.startup_error) end
 if not M.is_active() then return hold('route_inactive') end
 local name=victim()
 if not valid(name) then return M.stop('no_target') end
 if M.state.victim and not same(name,M.state.victim) then return M.stop('target_changed') end
 if not same(name,target) then return hold('ak_target_mismatch') end
 if type(Yso.offense_paused)=='function' and Yso.offense_paused() then return hold('pause') end
 if Yso.inhibit and type(Yso.inhibit.active)=='function' and Yso.inhibit.active() then return hold('manual_suppression') end
 local vitals=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
 if tostring(vitals.dead or '')=='1' then return hold('dead') end
 M.state.victim=name
 local pending=M.state.pending
 if pending then
  if now()-pending.at>=10 then return M.stop('confirmation_timeout') end
  return hold('waiting_'..pending.action)
 end
 if not (ak and affstrack and type(affstrack.score)=='table') then return hold('tracking_unavailable') end
 local scores=affstrack.score
 local picks=M.select(scores)
 local lane,cmd,cost,breach='bal',nil,0,ak.defs and ak.defs.curseward
 local action='eyes'
 if #picks>0 then
  -- Curseward is eye shielding. Magical shield does not block Truestare eyes.
  if not ready('bal') then return hold('balance') end
  local D=Yso.apostate.daegger
  if picks[1]=='undeaf' and M.undeaf_delivery=='prefarar' and not (ak.defs and ak.defs.shield)
   and D and D.available('prefarar') then
   local commands=D.build_attack('puncture',name,'prefarar')
   if not commands then return hold('prefarar_unavailable') end
   cmd=table.concat(commands,Yso.sep or (Yso.cfg and Yso.cfg.cmd_sep) or '&&')
   action='puncture';breach=false
  else
   cmd=M.eye_command(name,picks,breach)
   local keys=breach and {'breach',eyes[picks[1]] or picks[1]} or picks
   local R=Yso.ref and Yso.ref.apostate and Yso.ref.apostate.evileye
   for _,key in ipairs(keys) do
    local ref=R and R.skills[eyes[key] or key]
    if not ref then return hold('unsupported_eye:'..key) end
    cost=cost+(ref.resource_mana or 0)
   end
  end
 else
  if not (present(scores.paralysis) and present(scores.impatience) and present(scores.asthma)
   and present(scores.manaleech) and present(scores.slickness) and present(scores.anorexia)) then return hold('no_eligible_eye') end
  local enabled=false
  for _,aff in ipairs(M.Affliction_giving) do if aff=='disloyalty' then enabled=true end end
  if not enabled or present(scores.disloyalty) then return hold('lock_complete') end
  if ak.defs and ak.defs.shield then return hold('shield') end
  lane='eq';cmd='disfigure '..name
 end
 if (lane=='eq' or action=='eyes') and not ready('eq') then return hold('equilibrium') end
 local mana=tonumber(vitals.mp or vitals.mana)
 if mana and mana<cost then return hold('mana') end
 local payload={target=name,route=M.key};payload[lane]=cmd
 -- Record before emission: a throwing sender can leave a staged queue entry.
 M.state.commands=M.state.commands or {};M.state.commands[lane]=cmd
 if action=='puncture' and ak.apostate then ak.apostate.pending_daegger_wipe=true end
 if type(Yso.emit)~='function' or Yso.emit(payload,{kind='offense',route=M.key,target=name,reason=M.key,commit=true})~=true then
  if action=='puncture' and ak.apostate then ak.apostate.pending_daegger_wipe=nil end
  return hold('emit_blocked')
 end
 M.state[lane..'_until']=now()+(lane=='eq' and 3 or (action=='puncture' and 2.15 or 1.9))
 if lane=='bal' then M.state.pending={target=name,at=now(),breach=breach,action=action} end
 M.state.reason=lane=='bal' and ('waiting_'..action) or 'disfigure'
 return true
end
if type(registerAnonymousEventHandler)=='function' then
 M.handlers=M.handlers or {}
 local events={
  ['yso.target.changed']=function() if M.is_enabled() then M.stop('target_changed') end end,
  ['yso.target.cleared']=function() if M.is_enabled() then M.stop('no_target') end end,
  ['sysDisconnectionEvent']=function() if M.is_enabled() then M.stop('disconnect') end end,
  ['gmcp.Char.Status']=function() if M.is_enabled() and not Yso.apostate.active() then M.stop('wrong_class') end end,
 }
 for event,fn in pairs(events) do
  if M.handlers[event] and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(M.handlers[event]) end
  M.handlers[event]=registerAnonymousEventHandler(event,fn)
 end
end
return M
