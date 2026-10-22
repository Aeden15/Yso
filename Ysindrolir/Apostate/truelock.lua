-- Alias-owned controller. All affliction decisions consume confirmed AK scores.
Yso=Yso or {};Yso.off=Yso.off or {};Yso.off.apostate=Yso.off.apostate or {}
local M=Yso.off.apostate.truelock or {};Yso.off.apostate.truelock=M
M.key='apostate_truelock';M.alias_owned=true
M.state=M.state or {loop_enabled=false};M.state.loop_delay=0.15
M.cfg=M.cfg or {timeout=10,eye_balance=1.9,puncture_balance=2.15,corrupt_eq=3}
-- Migrate the old shipped order on reload, while preserving custom priorities.
if type(M.priorities)~='table'
 or table.concat(M.priorities,',')=='paralysis,impatience,asthma,slickness,anorexia,weariness,stupidity,recklessness'
 or table.concat(M.priorities,',')=='paralysis,clumsiness,addiction,asthma,slickness,impatience,anorexia,weariness,stupidity,recklessness' then
 M.priorities={'paralysis','asthma','slickness','impatience','anorexia','weariness','stupidity','recklessness','clumsiness','addiction'}
end
local baseline={'paralysis','asthma','slickness','impatience','anorexia','weariness','stupidity','recklessness','clumsiness','addiction'}
local eyes={paralysis='paralysis',impatience='impatience',asthma='asthma',slickness='sicken',
 anorexia='anorexia',weariness='weariness',stupidity='stupid',recklessness='reckless',
 voyria='plague',confusion='confusion',clumsiness='clumsy',addiction='addiction'}
local function now()
 local t=type(getEpoch)=='function' and tonumber(getEpoch()) or os.time()
 return t>20000000000 and t/1000 or t
end
local function target_name() return type(Yso.get_target)=='function' and Yso.get_target() or '' end
local function valid(n) return type(n)=='string' and n:match("^[A-Za-z][A-Za-z'%-]*$") end
local function same(a,b) return type(a)=='string' and type(b)=='string' and a:lower()==b:lower() end
local function present(v) return v==true or (tonumber(v) or 0)>=100 end
local function say(s) if cecho then cecho('<DeepPink>[Truelocks] <reset>'..s..'\n') end end
local function hold(reason)
 if M.state.reason~=reason and (reason:find('missing_',1,true) or reason:find('unsupported_',1,true)
  or reason=='class_coverage_unverified') then say(reason) end
 M.state.reason=reason;return false,reason
end
local function clear()
 local p=M.state.pending
 if p and p.kind=='contemplate' then
  local A=Yso.apostate
  A.cancelled_contemplates=A.cancelled_contemplates or {}
  local key=p.target:lower()
  A.cancelled_contemplates[key]=(A.cancelled_contemplates[key] or 0)+1
 end
 M.state.pending=nil;M.state.phase='pressure';M.state.victim=nil;M.state.reason=nil
 M.state.support_until=nil
 if ak and ak.apostate then ak.apostate.pending_daegger_wipe=nil end
end
function M.is_enabled() return M.state.loop_enabled==true end
function M.is_active()
 return M.is_enabled() and Yso.apostate and Yso.apostate.active()
  and Yso.mode and Yso.mode.is_combat()
end
function M.stop(reason)
 if Yso.mode and Yso.mode.stop_route_loop then Yso.mode.stop_route_loop(M.key,reason,false)
 else M.state.loop_enabled=false;clear() end
 return false,reason
end
function M.alias_loop_prepare_start(ctx) clear();return ctx end
function M.alias_loop_on_started() say('ON.') end
function M.alias_loop_on_stopped(ctx)
 local Q=Yso.queue
 if Q and type(Q.get_owned)=='function' then
  for _,lane in ipairs({'bal','eq','free'}) do
   local rec=Q.get_owned(lane)
   if rec and rec.route==M.key then
    if Q.clear_lane then Q.clear_lane(lane) end
    if Q.clear then Q.clear(lane) end
   end
  end
 end
 clear();say('OFF ('..tostring(ctx and ctx.reason or 'manual')..').')
end
function M.alias_loop_clear_waiting() M.state.waiting={} end
function M.alias_loop_waiting_blocks() return false end
function M.alias_loop_on_error() M.stop('route_error') end
-- Shared target-slain/external-reset coordination calls this lifecycle hook.
function M.reset_route_state(reason)
 if M.is_enabled() then return M.stop(reason or 'external_reset') end
 clear()
end
M.alias_loop_stop_details={no_target=true,wrong_class=true,confirmation_timeout=true}
function M.status()
 return {enabled=M.is_enabled(),phase=M.state.phase or 'pressure',reason=M.state.reason,
  target=M.state.victim,class_verified=M.state.class_verified}
end
local function ready(lane)
 local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
 local value=v[lane];if value==nil then value=v[lane=='bal' and 'balance' or 'equilibrium'] end
 if value~=true and tostring(value)~='1' then return false end
 if now()<(M.state[lane..'_until'] or 0) then return false end
 if lane=='eq' and now()<(M.state.support_until or 0) then return false end
 if Yso.locks and type(Yso.locks.ready)=='function' and not Yso.locks.ready(lane) then return false end
 return true
end
local function guarded()
 if not M.is_active() then return false,'route_inactive' end
 local n=target_name()
 if not valid(n) then return false,'no_target' end
 if M.state.victim and not same(n,M.state.victim) then return false,'target_changed' end
 if type(target)~='string' or not same(n,target) then return false,'ak_target_mismatch' end
 if type(Yso.offense_paused)=='function' and Yso.offense_paused() then return false,'pause' end
 if Yso.inhibit and type(Yso.inhibit.active)=='function' and Yso.inhibit.active() then return false,'manual_suppression' end
 local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
 if tostring(v.dead or '')=='1' then return false,'dead' end
 return true
end
local function emit(payload,kind)
 payload.target=M.state.victim;payload.route=M.key
 local sent
 if kind=='contemplate' and Yso.queue then
  -- The compatibility queue's free lane waits for EQ/BAL. This already-gated
  -- balanceless observation must be sent directly, without a readiness queue.
  sent=type(Yso.send)=='function' and Yso.send(payload.free)==true
 else
  sent=type(Yso.emit)=='function' and Yso.emit(payload,{kind='offense',route=M.key,target=M.state.victim,
   reason=M.key,commit=true})==true
 end
 if not sent then return hold('emit_blocked') end
 M.state.pending={kind=kind,at=now(),target=M.state.victim}
 M.state.reason='waiting_'..kind;return true
end
local function snapshot()
 if not (ak and affstrack and type(affstrack.score)=='table') then return nil end
 local out={};for k,v in pairs(affstrack.score) do out[k]=v end
 return out
end
local function requirements()
 local list,seen={},{}
 local function add(k) if not seen[k] then seen[k]=true;list[#list+1]=k end end
 for _,k in ipairs(M.priorities) do add(k) end
 for _,k in ipairs(baseline) do add(k) end
 if type(ak.classlockresolve)~='function' then return nil end
 local extra=ak.classlockresolve()
 if type(extra)~='table' then return nil end
 for _,k in ipairs(extra) do add(k) end
 local cls=type(ak.classlockresolveclass)=='function' and ak.classlockresolveclass(M.state.victim) or ''
 M.state.class_verified=type(cls)=='string' and cls~='' and cls~='unknown'
 return list
end
function M.note_pressure(kind,name,delivered)
 local p=M.state.pending
 if not p or p.kind~='pressure' or not same(name,p.target) or not same(name,target_name()) then return end
 if p.action=='eyes' and kind=='eyes' then p.confirmed=true end
 if p.action=='puncture' and kind=='puncture' then
  if delivered then p.confirmed=true elseif not p.confirmed then p.no_coating=true end
 end
end
function M.note_eye_rejected(reason,name)
 local p=M.state.pending
 if not M.is_enabled() or not p or p.kind~='pressure' or p.action~='eyes'
  or not same(p.target,target_name()) or (name and not same(name,p.target)) then return false end
 if reason=='blind' then return M.stop('eyes_blind') end
 if reason~='equilibrium' and reason~='balance' and reason~='curseward' then return false end
 if reason=='curseward' then ak.defs=ak.defs or {};ak.defs.curseward=true end
 -- Settle at the prompt so any eye that did land in a partial batch still
 -- reaches AK's normal confirmation path. The next tick replans from scores.
 p.rejected=reason;return true
end
function M.note_corrupt(kind,name,aff)
 local p=M.state.pending
 if not M.is_enabled() or not p or p.kind~='corrupt' or not same(name,p.target) then return end
 if kind=='accepted' then p.accepted=true
 elseif kind=='rejected' then p.rejected=true
 elseif kind=='retained' and aff=='paralysis' then p.retained=true end
end
function M.note_prompt()
 local p=M.state.pending;if not p then return end
 if not same(p.target,target_name()) then return M.stop('target_changed') end
 if p.kind=='pressure' and p.rejected then
  M.state.pending=nil;M.state.reason='retry_'..p.rejected;return
 end
 if p.no_coating and not p.confirmed then return M.stop('venom_delivery_unconfirmed') end
 if p.kind=='pressure' and p.confirmed then
  -- An eye announcement confirms the batch, not Curseward removal. AK owns
  -- ward state and credits only the affliction eyes that actually landed.
  if not p.breach or (ak.defs and ak.defs.curseward==false) then M.state.pending=nil end
  return
 end
 if p.kind~='corrupt' then return end
 if p.rejected then return M.stop('corrupt_rejected') end
 if not p.accepted then return end
 if not (ak and ak.apostate and ak.apostate.consume_corrupt) then return M.stop('tracking_unavailable') end
 ak.apostate.consume_corrupt(p.target,p.retained and 'paralysis' or nil)
 M.state.pending=nil;M.state.phase='contemplate'
end
function M.note_mana(name,current,maximum)
 if not M.is_enabled() then return false end
 local p=M.state.pending
 if not p or p.kind~='contemplate' or not same(p.target,name) or not same(name,target_name()) then return false end
 local ok=guarded()
 if not ok then M.state.pending=nil;M.stop('mana_response_cancelled');return false end
 M.state.pending=nil
 if current*2>=maximum then M.state.phase='pressure';return true end
 if not p.final or not ready('eq') then M.state.phase='catharsis_ready';return true end
 if type(sendAll)~='function' then M.stop('sender_unavailable');return false end
 -- A fresh, solicited response and every route gate were checked above.
 sendAll('cq all','demon catharsis '..name)
 Yso.apostate.catharsis_sent_at=now()
 M.stop('catharsis_sent');return true
end
local function pressure_attack()
 local ok,why=guarded()
 if not ok then
  if why=='target_changed' or why=='no_target' then return M.stop(why) end
  return hold(why)
 end
 M.state.victim=M.state.victim or target_name()
 local p=M.state.pending
 if p then
  if now()-p.at>=M.cfg.timeout then return M.stop('confirmation_timeout') end
  return hold('waiting_'..p.kind)
 end
 local phase=M.state.phase or 'pressure'
 if phase=='contemplate' or phase=='catharsis_ready' then
  local final=phase=='catharsis_ready'
  if final and not ready('eq') then return hold('equilibrium') end
  if emit({free='contemplate '..M.state.victim},'contemplate') then
   M.state.pending.final=final;return true
  end
  return false
 end
 local scores=snapshot();if not scores then return hold('tracking_unavailable') end
 local list=requirements();if not list then return hold('class_requirements_unavailable') end
 local missing={};for _,aff in ipairs(list) do if not present(scores[aff]) then missing[#missing+1]=aff end end
 if #missing==0 then
  if not M.state.class_verified then return hold('class_coverage_unverified') end
  if not ready('eq') then return hold('equilibrium') end
  if emit({eq='demon corrupt '..M.state.victim..' paralysis'},'corrupt') then
   M.state.eq_until=now()+M.cfg.corrupt_eq;return true
  end
  return false
 end
 if ak.defs and ak.defs.shield then return hold('shield') end
 if not ready('bal') then return hold('balance') end
 local picks,seen={},{}
 local breach=ak.defs and ak.defs.curseward
 for _,aff in ipairs(missing) do
  local eye=eyes[aff]
  if eye and not seen[eye] and #picks<2 then seen[eye]=true;picks[#picks+1]=eye end
 end
 if #picks>0 then
  -- Curseward matters only when actually delivering an Evileye. Do not spend
  -- a Breach before a venom-only blocker or a non-Evileye finisher.
  if breach then picks={'breach',picks[1]} end
  -- Eyes spend BAL but the server also requires EQ readiness. In particular,
  -- do not submit Breach during the EQ recovery from Disfigure/Chill/Shrivel.
  if not ready('eq') then return hold('equilibrium') end
  local R=Yso.ref and Yso.ref.apostate and Yso.ref.apostate.evileye
  local cost=0
  for _,key in ipairs(picks) do
   local skill=R and R.skills[key]
   if not skill then return hold('reference_unavailable') end
   cost=cost+(skill.resource_mana or 0)
  end
  local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  local mana=tonumber(v.mp or v.mana)
  if mana and mana<cost then return hold('mana') end
  local cmd=#picks==2 and ('deadeyes '..M.state.victim..' '..picks[1]..' '..picks[2])
   or ('stare '..M.state.victim..' '..picks[1])
  if emit({bal=cmd},'pressure') then
   M.state.pending.action='eyes';M.state.pending.breach=breach
   M.state.pending.mana_cost=cost;M.state.pending.mana_before=mana
   M.state.bal_until=now()+M.cfg.eye_balance;return true,nil,cost
  end
  return false
 end
 local D=Yso.apostate.daegger
 if not D then return hold('venom_helper_unavailable') end
 local venom=D.venom_for(missing[1])
 if not venom then return hold('unsupported_affliction:'..missing[1]) end
 if not D.available(venom) then return hold('missing_venom:'..venom) end
 local sent=D.emit_attack('puncture',M.state.victim,{missing[1]},scores)
 if not sent then return hold('emit_blocked') end
 M.state.pending={kind='pressure',action='puncture',target=M.state.victim,at=now()}
 M.state.bal_until=now()+M.cfg.puncture_balance;return true
end
local function support_attack(spent_mana)
 -- Support uses EQ independently of the pending BAL confirmation. Finisher
 -- phases and a complete lock always keep priority over extra cure pressure.
 if not guarded() or M.state.phase~='pressure' then return false end
 local p=M.state.pending
 if p and p.kind~='pressure' then return false end
 if ak.defs and ak.defs.shield then return false end
 if not ready('eq') then return false end
 local scores=snapshot();if not scores then return false end
 local list=requirements();if not list then return false end
 local complete=true
 for _,aff in ipairs(list) do if not present(scores[aff]) then complete=false;break end end
 if complete then return false end
 local skill,arg
 if present(scores.asthma) and present(scores.manaleech) and not present(scores.disloyalty) then
  skill='disfigure'
 elseif present(scores.slickness) or present(scores.anorexia) then
  if present(scores.frozen) then
   -- A single crippled leg supplies the requested padding. Never chase both.
   if not present(scores.leftleg) and not present(scores.rightleg) then skill='shrivel';arg='left leg ' end
  else skill='chill' end
 end
 if not skill then return false end
 local R=Yso.ref and Yso.ref.apostate and Yso.ref.apostate.necromancy
 local ref=R and R.skills and R.skills[skill]
 if not ref then return false end
 local v=gmcp and gmcp.Char and gmcp.Char.Vitals or {}
 local mana=tonumber(v.mp or v.mana)
 -- Keep the known BAL spend reserved on subsequent ticks until the mana
 -- report changes or its pressure confirmation settles the pending batch.
 if p and p.mana_before==mana then spent_mana=math.max(spent_mana or 0,p.mana_cost or 0) end
 if mana and ref.resource_mana and mana-(spent_mana or 0)<ref.resource_mana then return false end
 local payload={eq=skill..' '..(arg or '')..M.state.victim,target=M.state.victim,route=M.key}
 local sent=type(Yso.emit)=='function' and Yso.emit(payload,{kind='offense',route=M.key,
  target=M.state.victim,reason=M.key..':support',commit=true})==true
 if sent then M.state.support_until=now()+ref.cooldown_s end
 return sent
end
function M.attack_function()
 local sent,detail,spent_mana=pressure_attack()
 -- pressure_attack may already have stopped the loop. Do not return a stop
 -- detail that asks the scheduler to run the same cleanup and OFF echo again.
 if not M.is_enabled() then return sent end
 if support_attack(spent_mana) then return true end
 return sent,detail
end
if type(registerAnonymousEventHandler)=='function' then
 M.handlers=M.handlers or {}
 local handlers={
  ['yso.target.changed']=function() if M.is_enabled() then M.stop('target_changed') end end,
  ['yso.target.cleared']=function() if M.is_enabled() then M.stop('no_target') end end,
  ['sysDisconnectionEvent']=function() if M.is_enabled() then M.stop('disconnect') end end,
  ['gmcp.Char.Status']=function() if M.is_enabled() and not Yso.apostate.active() then M.stop('wrong_class') end end,
 }
 for event,fn in pairs(handlers) do
  if M.handlers[event] and killAnonymousEventHandler then killAnonymousEventHandler(M.handlers[event]) end
  M.handlers[event]=registerAnonymousEventHandler(event,fn)
 end
end
return M
