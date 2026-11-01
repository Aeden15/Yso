-- Universal combat-only paralysis policy. Game cooldowns keep wall time;
-- command confirmation deadlines use confirmation_now(route_id).
Yso=Yso or {};Yso.Combat=Yso.Combat or {}
local P=Yso.Combat.Pause or {};Yso.Combat.Pause=P
P.clocks=P.clocks or {};P.handlers=P.handlers or {}
local function now()
 local t=type(getEpoch)=='function' and tonumber(getEpoch()) or os.time()
 return t>20000000000 and t/1000 or t
end
local function registry() return Yso.Combat.RouteRegistry end
local function route_id(id) return tostring(id or ''):lower() end
local function paralysis()
 if not (Yso.self and type(Yso.self.has_aff)=='function') then return nil end
 local meta=Yso.selfaff and Yso.selfaff.meta
 if meta and (meta.afflictions_ready~=true or meta.full_sync_confirmed~=true or meta.awaiting_full_sync==true) then return nil end
 local ok,has=pcall(Yso.self.has_aff,'paralysis')
 if not ok then return nil end
 return has==true
end
local function update(id)
 id=route_id(id)
 local row=P.clocks[id] or {paused_at=nil,total=0};P.clocks[id]=row
 local at,has=now(),paralysis()
 if has and not row.paused_at then row.paused_at=at
 elseif has==false and row.paused_at then row.total=row.total+math.max(0,at-row.paused_at);row.paused_at=nil end
 return row,at,has
end
function P.confirmation_now(id)
 local row,at=update(id)
 return (row.paused_at or at)-row.total
end
function P.blocked(id)
 local _,_,has=update(id)
 if has==nil then return true,'self_tracking_unavailable' end
 return has,has and 'paralysis' or nil
end
function P.blocks_emission(payload,opts)
 opts=type(opts)=='table' and opts or {}
 payload=type(payload)=='table' and payload or {}
 local kind=route_id(opts.kind)
 if kind=='cure' or kind=='defense' or kind=='utility' then return false end
 local id=route_id(opts.route or payload.route)
 local RR=registry();local entry=RR and RR.resolve and RR.resolve(id)
 local combat=entry and entry.mode=='combat'
 if entry and not combat then return false end
 if not entry then
  combat=Yso.mode and type(Yso.mode.is_combat)=='function' and Yso.mode.is_combat()==true
 end
 if not combat then return false end
 if kind~='offense' and kind~='' then return false end
 return P.blocked(id)
end
function P.discard_staged(id)
 local Q=Yso.queue
 if Q and type(Q.discard_staged_route)=='function' then
  local removed=Q.discard_staged_route(id) or {}
  if #removed>0 then
   local RR=registry();local entry=RR and RR.resolve and RR.resolve(id)
   local mod=_G
   for part in tostring(entry and entry.namespace or ''):gmatch('[^.]+') do mod=type(mod)=='table' and mod[part] or nil end
   for _,row in ipairs(removed) do
    local owned=Q.get_owned and Q.get_owned(row.lane)
    if not (owned and owned.route==id and owned.cmd==row.cmd) then
     if mod and mod.state then
      local pending=mod.state.pending
      if pending and (pending.cmd==row.cmd or pending.command==row.cmd) then mod.state.pending=nil end
      if mod.state.execute_inflight and mod.state.execute_inflight.cmd==row.cmd then mod.state.execute_inflight=nil end
     end
     local phys=Yso.alc and Yso.alc.phys
     local pending=phys and phys.state and phys.state.pending_class
     if pending and pending.route==id and pending.cmd==row.cmd and phys.clear_pending_class then
      phys.clear_pending_class('unsent_paralysis',{clear_any=true})
     end
    end
   end
   if mod and type(mod.alias_loop_on_staged_discarded)=='function' then pcall(mod.alias_loop_on_staged_discarded,removed) end
  end
  return removed
 end
 if not (Q and type(Q.get_staged_owner)=='function' and type(Q.clear)=='function') then return end
 for _,lane in ipairs({'eq','bal','class','free'}) do
  local owner=Q.get_staged_owner(lane)
  if owner and route_id(owner.route)==route_id(id) then Q.clear(lane) end
 end
end
local function lookup(ns)
 local value=_G
 for part in tostring(ns or ''):gmatch('[^.]+') do
  if type(value)~='table' then return nil end
  value=value[part]
 end
 return value
end
local function changed(_,aff)
 if aff and aff~='paralysis' then return end
 local RR=registry()
 if not (RR and type(RR.for_mode)=='function') then return end
 if Yso.hinder and Yso.hinder.state then Yso.hinder.state.snapshot=nil end
 for _,entry in ipairs(RR.for_mode('combat')) do
  local mod=lookup(entry.namespace)
  if mod and mod.state and mod.state.loop_enabled==true then
   local blocked=P.blocked(entry.id)
   if blocked then P.discard_staged(entry.id)
   elseif Yso.mode and type(Yso.mode.nudge_route_loop)=='function' then
    Yso.mode.nudge_route_loop(entry.id,'self_paralysis_cured')
   end
  end
 end
end
for _,id in pairs(P.handlers) do if type(killAnonymousEventHandler)=='function' then pcall(killAnonymousEventHandler,id) end end
P.handlers={}
if type(registerAnonymousEventHandler)=='function' then
 for _,event in ipairs({'yso.self.aff.changed','yso.self.aff.cure_confirmed'}) do
  P.handlers[event]=registerAnonymousEventHandler(event,changed)
 end
 for event,reason in pairs({sysDisconnectionEvent='disconnect',['yso.target.changed']='target_changed',['yso.target.cleared']='no_target'}) do
  local why=reason
  P.handlers[event]=registerAnonymousEventHandler(event,function()
   local RR=registry()
   if not (RR and RR.for_mode and Yso.mode and Yso.mode.stop_route_loop) then return end
   for _,entry in ipairs(RR.for_mode('combat')) do
    local mod=lookup(entry.namespace)
    if mod and mod.state and mod.state.loop_enabled then Yso.mode.stop_route_loop(entry.id,why,true) end
   end
  end)
 end
 P.handlers.synced=registerAnonymousEventHandler('yso.self.aff.synced',function() changed() end)
end
return P
