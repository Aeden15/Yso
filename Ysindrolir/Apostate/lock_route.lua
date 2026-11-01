-- Lock decisions are separate from delivery; AK owns confirmed target state.
Yso=Yso or {};Yso.off=Yso.off or {};Yso.off.apostate=Yso.off.apostate or {}
-- Both finishers share pressure/delivery code, but never state or ownership.
function Yso.off.apostate.create_lock_route(kind)
local vivisect=kind=='vivisect'
local slot=vivisect and 'vivisect' or 'truelock'
local M=Yso.off.apostate[slot] or {};Yso.off.apostate[slot]=M
M.key=vivisect and 'apostate_vivisect' or 'apostate_truelock';M.alias_owned=true
M.state=M.state or {};M.state.loop_delay=0.15
M.Affliction_giving={
 'paralysis','undeaf','impatience','asthma','masochism','manaleech','slickness','anorexia','disloyalty',
}
M.Padding_mental_afflictions={
 'stupidity','confusion','dizziness','dementia',
}
M.Padding_kelp_afflictions={
 'clumsiness','weariness','sensitivity',
}
M.undeaf_delivery='evileye' -- Optional: 'prefarar' uses Puncture when available.
if vivisect then M.Affliction_giving[#M.Affliction_giving+1]='confusion' end
-- Captured live output, 2026-10-26. Both lines are required: the command's
-- acceptance does not establish which curse the Baalzadeen actually retained.
local corrupt_success_pattern=[[^You command your baalzadeen to corrupt the soul of ([\w'-]+)\.$]]
local corrupt_retained_pattern=[[^Your Baalzadeen informs you that the ([a-z]+) affliction still burdens ([\w'-]+)\.$]]
function M.configure_corrupt_confirmation(pattern,retained_pattern)
 if M.corrupt_trigger and type(killTrigger)=='function' then killTrigger(M.corrupt_trigger) end
 if M.corrupt_retained_trigger and type(killTrigger)=='function' then killTrigger(M.corrupt_retained_trigger) end
 M.corrupt_trigger=nil;M.corrupt_retained_trigger=nil
 M.Corrupt_success_pattern=pattern;M.Corrupt_retained_pattern=retained_pattern
 if type(pattern)~='string' or pattern=='' or type(retained_pattern)~='string'
  or retained_pattern=='' or type(tempRegexTrigger)~='function' then return false end
 local ok,id=pcall(tempRegexTrigger,pattern,function()
  M.note_corrupt_started(matches[2])
 end)
 if not ok or not tonumber(id) or tonumber(id)<=0 then return false end
 M.corrupt_trigger=id
 local retained_ok,retained_id=pcall(tempRegexTrigger,retained_pattern,function()
  M.note_corrupt(matches[3],matches[2])
 end)
 if retained_ok and tonumber(retained_id) and tonumber(retained_id)>0 then
  M.corrupt_retained_trigger=retained_id;return true
 end
 if type(killTrigger)=='function' then killTrigger(M.corrupt_trigger) end
 M.corrupt_trigger=nil
 return false
end
local eyes={undeaf='sensitivity',clumsiness='clumsy',slickness='sicken',stupidity='stupid',dizziness='dizzy'}
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
 if opening then eligible.impatience=true;eligible.asthma=true;eligible.masochism=true
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
 -- Core eyes claim slots before padding, including Masochism.
 for _,aff in ipairs(M.Affliction_giving) do
  if eligible[aff] and aff~='masochism' then add(aff) end
 end
 if opening and #out==1 and out[1]=='asthma' then
  for _,aff in ipairs(M.Padding_kelp_afflictions) do add(aff) end
 end
 if opening then
  for _,aff in ipairs(M.Affliction_giving) do
   if aff=='masochism' then add(aff) end
  end
 end
 -- Retain mental padding for Impatience/Manaleech and exhausted kelp padding.
 if (opening and #out==1 and (out[1]=='asthma' or out[1]=='impatience'))
  or (not opening and needs_manaleech) then
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
 if type(cecho)=='function' then cecho('<DeepPink>['..(vivisect and 'Vivisect' or 'Truelocks')..'] <reset>'..text..'\n') end
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
 local other=Yso.off.apostate[vivisect and 'truelock' or 'vivisect']
 if other and other.is_enabled() then other.stop('route_changed') end
 M.state.pending=nil;M.state.victim=nil;M.state.reason=nil
 M.state.finisher=nil
 M.state.confirmation_warning=nil
 M.state.quarantine_warning=nil
 M.state.commands={}
 M.state.bal_until=nil;M.state.eq_until=nil;M.state.startup_error=nil
 M.state.paralysis_paused=nil
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
  else note('Unable to send daemonite passive order.') end
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
 local pending=M.state.pending
 if pending and pending.action=='contemplate' and Yso.apostate then
  local A=Yso.apostate;local key=pending.target:lower()
  A.cancelled_contemplates=A.cancelled_contemplates or {}
  A.cancelled_contemplates[key]=(A.cancelled_contemplates[key] or 0)+1
 elseif pending and pending.action=='corrupt' and Yso.apostate then
  local A=Yso.apostate;local key=pending.target:lower()
  A.cancelled_corrupts=A.cancelled_corrupts or {}
  A.cancelled_corrupts[key]=(A.cancelled_corrupts[key] or 0)+1
 end
 M.state.pending=nil;M.state.finisher=nil;M.state.victim=nil;M.state.reason=nil
 if ak and ak.apostate then ak.apostate.pending_daegger_wipe=nil end
 note('OFF ('..tostring(ctx and ctx.reason or 'manual')..').')
end
function M.alias_loop_clear_waiting() M.state.waiting={} end
function M.alias_loop_waiting_blocks() return false end
function M.alias_loop_on_error() M.stop('route_error') end
function M.reset_route_state(reason) if M.is_enabled() then M.stop(reason or 'external_reset') end end
function M.status() return {enabled=M.is_enabled(),target=M.state.victim,reason=M.state.reason} end
-- Explicit reconciliation only: use while stopped after verifying the cancelled
-- commands cannot still reply. New requests never silently consume old replies.
function M.clear_cancelled_finishers(name)
 if M.is_enabled() or not valid(name) then return false end
 local A=Yso.apostate
 if not A then return false end
 local key=name:lower()
 if A.cancelled_corrupts then A.cancelled_corrupts[key]=nil end
 if A.cancelled_contemplates then A.cancelled_contemplates[key]=nil end
 return true
end
local function ready(lane)
 local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
 local value=v[lane];if value==nil then value=v[lane=='bal' and 'balance' or 'equilibrium'] end
 return (value==true or tostring(value)=='1') and now()>=(M.state[lane..'_until'] or 0)
  and not (Yso.locks and type(Yso.locks.ready)=='function' and not Yso.locks.ready(lane))
end
local function hold(reason) M.state.reason=reason;return false,reason end
-- Server confirmations, never command sends, settle Corrupt's curse conversion.
function M.note_corrupt_started(name)
 local p=M.state.pending
 if not M.is_active() or not p or p.action~='corrupt'
  or not same(name,p.target) or not same(name,victim()) or not same(name,target) then return false end
 if now()-p.at>=10 then return M.stop('confirmation_timeout') end
 p.accepted=true
 return true
end
function M.note_corrupt(name,retained)
 local A=Yso.apostate
 local key=type(name)=='string' and name:lower() or ''
 local cancelled=A and A.cancelled_corrupts and A.cancelled_corrupts[key] or 0
 if cancelled>0 then A.cancelled_corrupts[key]=cancelled-1;return false end
 local p=M.state.pending
 if not M.is_active() or not p or p.action~='corrupt' or not p.accepted
  or type(retained)~='string' or retained==''
  or not same(name,p.target) or not same(name,victim()) or not same(name,target) then return false end
 if now()-p.at>=10 then return M.stop('confirmation_timeout') end
 local A=ak and ak.apostate
 if not (A and type(A.consume_corrupt)=='function' and A.consume_corrupt(name,retained)) then
  return M.stop('corrupt_tracking_unavailable')
 end
 M.state.pending=nil
 if retained~='anorexia' then
  note('Corrupt retained '..retained..' instead of anorexia; stopping the finisher.')
  return M.stop('corrupt_retained_mismatch')
 end
 M.state.finisher={phase='contemplate',at=now()}
 return true
end
function M.note_mana(name,current,maximum)
 local p=M.state.pending
 if not M.is_active() or not p or p.action~='contemplate'
  or not same(name,p.target) or not same(name,victim()) or not same(name,target) then return false end
 if now()-p.at>=10 then return M.stop('confirmation_timeout') end
 current,maximum=tonumber(current),tonumber(maximum)
 if not current or not maximum or maximum<=0 or current<0 or current>maximum
  or current~=current or maximum~=maximum or maximum==math.huge then return false end
 M.state.pending=nil
 M.state.finisher={phase=current*2<maximum and 'catharsis' or 'sap',at=now()}
 return true
end
local function emit_finisher(name,action)
 local A=Yso.apostate or {};local key=name:lower()
 if action=='corrupt' or action=='contemplate' then
  local blocked
  if A.cancelled_corrupts and (A.cancelled_corrupts[key] or 0)>0 then blocked='corrupt'
  elseif A.cancelled_contemplates and (A.cancelled_contemplates[key] or 0)>0 then blocked='contemplate' end
  if blocked then
   if not M.state.quarantine_warning then
    note('Finisher held: an earlier '..blocked..' reply remains unresolved. Stop and reconcile before retrying.')
    M.state.quarantine_warning=true
   end
   return hold('waiting_cancelled_'..blocked)
  end
 end
 if action=='corrupt' and not (M.corrupt_trigger and M.corrupt_retained_trigger) then
  if not M.state.confirmation_warning then
   note('Lock sealed; Corrupt awaits a verified success trigger.')
   M.state.confirmation_warning=true
  end
  return hold('corrupt_confirmation_unconfigured')
 end
 local lane=action=='contemplate' and 'free' or 'eq'
 if action=='contemplate' then
  -- Scheduling policy waits for balance; Contemplate itself spends neither lane.
  if not ready('bal') then return hold('balance') end
 elseif not ready('eq') then return hold('equilibrium') end
 local cmd=action=='contemplate' and ('contemplate '..name) or ('demon '..action..' '..name)
 if action=='corrupt' then cmd=cmd..' anorexia' end
 local payload={target=name,route=M.key};payload[lane]=cmd
 M.state.commands=M.state.commands or {};M.state.commands[lane]=cmd
 if action=='contemplate' then
  -- Send immediately: a balanceless query must not linger in the server queue.
  local sender=Yso.send or send
  if type(sender)~='function' then return hold('emit_blocked') end
  local ok,result=pcall(sender,cmd,false)
  if not ok or result==false or (sender==Yso.send and result~=true) then return hold('emit_blocked') end
 else
  local Q=Yso.queue
  local previous=Q and type(Q.get_owned)=='function' and Q.get_owned('eq')
  local function discard_staged()
   if Q and type(Q.list)=='function' and Q.list('eq')==cmd and Q.clear then Q.clear('eq') end
  end
  if type(Yso.emit)~='function' or Yso.emit(payload,{kind='offense',route=M.key,target=name,
   reason=M.key,commit=true})~=true then discard_staged();return hold('emit_blocked') end
  -- The canonical emitter may report a staged wake as success. Require actual
  -- ownership of a freshly dispatched EQ command before advancing the phase.
  if Q and type(Q.get_owned)=='function' then
   local owned=Q.get_owned('eq')
   if not owned or owned==previous or owned.route~=M.key or owned.cmd~=cmd then
    discard_staged()
    return hold('emit_blocked')
   end
  end
 end
 if action=='corrupt' or action=='contemplate' or action=='catharsis' then
  M.state.pending={target=name,at=now(),action=action}
 end
 if lane=='eq' then
  M.state.eq_until=now()+({corrupt=3,sap=2.75,catharsis=4.4})[action]
 end
 M.state.reason='waiting_'..action
 if action=='sap' then M.state.finisher=nil;M.state.reason='rebuild_lock' end
 return true
end
function M.note_pressure(kind,name,delivered)
 local p=M.state.pending
 if not p or kind~=p.action or not same(name,p.target) or not same(name,victim()) then return end
 if kind=='puncture' and delivered~=true then return M.stop('venom_delivery_unconfirmed') end
 p.confirmed=true
end
function M.note_eye_rejected(reason,name)
 local p=M.state.pending
 if not M.is_enabled() or not p or (p.action~='eyes' and not vivisect) or not same(p.target,victim()) or (name and not same(name,p.target)) then return false end
 if p.action~='eyes' and reason~='equilibrium' and reason~='balance' then return false end
 if reason=='blind' then return M.stop('eyes_blind') end
 if reason~='equilibrium' and reason~='balance' and reason~='curseward' then return false end
 if reason=='curseward' then ak.defs=ak.defs or {};ak.defs.curseward=true end
 p.rejected=reason;return true
end
local function release_confirmed_owner(p)
 -- A confirmed/rejected command no longer needs client deduplication. Keep
 -- server queues intact and never release a replacement owned by another send.
 local Q=Yso.queue
 if vivisect and p.owned and Q and type(Q.get_owned)=='function'
  and Q.get_owned(p.lane)==p.owned and type(Q.clear_owned)=='function' then
  Q.clear_owned(p.lane)
 end
end
function M.note_prompt()
 local p=M.state.pending;if not p then return end
 if not same(p.target,victim()) then return M.stop('target_changed') end
 if p.action=='catharsis' or p.action=='vivisect' then
  if vivisect and p.rejected then release_confirmed_owner(p);M.state.pending=nil;return end
  local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  local eq=v.eq;if eq==nil then eq=v.equilibrium end
  if eq==false or tostring(eq)=='0' then p.spent=true end
  return
 end
 if p.action=='trample' then
  local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  local bal=v.bal;if bal==nil then bal=v.balance end
  if bal==false or tostring(bal)=='0' then p.confirmed=true end
 end
 if vivisect and p.action=='disfigure' then
  local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  local eq=v.eq;if eq==nil then eq=v.equilibrium end
  if present(affstrack and affstrack.score and affstrack.score.disloyalty)
   or eq==false or tostring(eq)=='0' then p.confirmed=true end
 end
 if p.rejected or (p.confirmed and (not p.breach or (ak.defs and ak.defs.curseward==false))) then
  release_confirmed_owner(p);M.state.pending=nil
 end
end
function M.attack_function()
 if M.state.startup_error then return M.stop(M.state.startup_error) end
 if not M.is_active() then return hold('route_inactive') end
 local other=Yso.off.apostate[vivisect and 'truelock' or 'vivisect']
 if other and other.is_enabled() then return hold('other_route_active') end
 local name=victim()
 if not valid(name) then return M.stop('no_target') end
 if M.state.victim and not same(name,M.state.victim) then return M.stop('target_changed') end
 if not same(name,target) then return hold('ak_target_mismatch') end
 if type(Yso.offense_paused)=='function' and Yso.offense_paused() then return hold('pause') end
 if Yso.inhibit and type(Yso.inhibit.active)=='function' and Yso.inhibit.active() then return hold('manual_suppression') end
 local vitals=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
 if tostring(vitals.dead or '')=='1' then return M.stop('dead') end
 M.state.victim=name
 if vivisect then
  local meta=Yso.selfaff and Yso.selfaff.meta
  if not (Yso.self and type(Yso.self.has_aff)=='function' and meta
   and meta.afflictions_ready==true and meta.full_sync_confirmed==true
   and meta.awaiting_full_sync~=true) then return hold('self_tracking_unavailable') end
  if Yso.self.has_aff('paralysis') then M.state.paralysis_paused=true;return hold('paralysis') end
  if M.state.paralysis_paused then
   -- Queued attacks may wait on the server's !p gate throughout the pause.
   -- Resume their confirmation window instead of timing out or resending.
   if M.state.pending then M.state.pending.at=now() end
   M.state.paralysis_paused=nil
  end
 end
 local pending=M.state.pending
 if pending then
  if pending.action=='catharsis' or pending.action=='vivisect' then
   M.note_prompt()
   if pending.rejected then M.state.pending=nil;return hold('replan') end
   if pending.spent and ready('eq') then return M.stop(vivisect and 'vivisect_attempt_complete' or 'catharsis_complete') end
  end
  if now()-pending.at>=10 then return M.stop('confirmation_timeout') end
  return hold('waiting_'..pending.action)
 end
 if Yso.self and type(Yso.self.has_aff)=='function' and Yso.self.has_aff('paralysis') then return hold('paralysis') end
 if not (ak and affstrack and type(affstrack.score)=='table') then return hold('tracking_unavailable') end
 local finisher=M.state.finisher
 if finisher then
  if now()-finisher.at>=10 then return M.stop('finisher_timeout') end
  return emit_finisher(name,finisher.phase)
 end
 local scores=affstrack.score
 local picks=M.select(scores)
 if vivisect and #picks==0 and present(scores.disloyalty) and not present(scores.confusion) then picks={'confusion'} end
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
  if not enabled then return hold('lock_complete') end
  if ak.defs and ak.defs.shield then return hold('shield') end
  if not present(scores.disloyalty) then lane='eq';cmd='disfigure '..name
  elseif not vivisect then return emit_finisher(name,'corrupt')
  else
   local all=true
   for _,limb in ipairs({'leftarm','rightarm','leftleg','rightleg'}) do
    if not present(scores[limb]) then all=false end
   end
   if all then lane='eq';cmd='vivisect '..name;action='vivisect';cost=300
   else
    if not present(scores.prone) then return hold('waiting_prone') end
    if not ready('bal') then return hold('balance') end
    cmd='trample';action='trample'
   end
  end
 end
 if (lane=='eq' or action=='eyes') and not ready('eq') then return hold('equilibrium') end
 local mana=tonumber(vitals.mp or vitals.mana)
 if mana and mana<cost then return hold('mana') end
 local payload={target=name,route=M.key};payload[lane]=cmd
 -- Record before emission: a throwing sender can leave a staged queue entry.
 M.state.commands=M.state.commands or {};M.state.commands[lane]=cmd
 local Q=Yso.queue
 local previous=Q and type(Q.get_owned)=='function' and Q.get_owned(lane)
 local function discard_staged()
  if Q and type(Q.list)=='function' and Q.list(lane)==cmd and Q.clear then Q.clear(lane) end
 end
 if action=='puncture' and ak.apostate then ak.apostate.pending_daegger_wipe=true end
 if type(Yso.emit)~='function' or Yso.emit(payload,{kind='offense',route=M.key,target=name,reason=M.key,commit=true})~=true then
  if action=='puncture' and ak.apostate then ak.apostate.pending_daegger_wipe=nil end
  if vivisect then discard_staged() end
  return hold('emit_blocked')
 end
 if vivisect and Q and type(Q.get_owned)=='function' then
  local owned=Q.get_owned(lane)
  if not owned or owned==previous or owned.route~=M.key or owned.cmd~=cmd then
   discard_staged();return hold('emit_blocked')
  end
 end
 M.state[lane..'_until']=now()+(action=='vivisect' and 4 or (action=='trample' and 4 or (lane=='eq' and 3 or (action=='puncture' and 2.15 or 1.9))))
 if lane=='bal' or vivisect then
  M.state.pending={target=name,at=now(),breach=action=='eyes' and breach or false,
   action=action=='eyes' and lane=='eq' and 'disfigure' or action,lane=lane,
   owned=Q and type(Q.get_owned)=='function' and Q.get_owned(lane) or nil}
 end
 M.state.reason=lane=='bal' and ('waiting_'..action) or 'disfigure'
 return true
end
if type(registerAnonymousEventHandler)=='function' then
 M.handlers=M.handlers or {}
 local events={
  ['yso.target.changed']=function() if M.is_enabled() then M.stop('target_changed') end end,
  ['yso.target.cleared']=function() if M.is_enabled() then M.stop('no_target') end end,
  ['sysDisconnectionEvent']=function()
   if M.is_enabled() then M.stop('disconnect') end
   if Yso.apostate then Yso.apostate.cancelled_corrupts={};Yso.apostate.cancelled_contemplates={} end
  end,
  ['gmcp.Char.Status']=function() if M.is_enabled() and not Yso.apostate.active() then M.stop('wrong_class') end end,
 }
 for event,fn in pairs(events) do
  if M.handlers[event] and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(M.handlers[event]) end
  M.handlers[event]=registerAnonymousEventHandler(event,fn)
 end
end
if not vivisect then M.configure_corrupt_confirmation(corrupt_success_pattern,corrupt_retained_pattern) end
return M
end
function Yso.off.apostate.active_route()
 local V=Yso.off.apostate.vivisect
 if V and V.is_enabled() then return V end
 return Yso.off.apostate.truelock
end
return Yso.off.apostate.create_lock_route('truelock')
