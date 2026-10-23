-- Embedded in Legacy Basher. One opener per selected denizen; 40s effect duration.
-- Keep the installer outside Legacy: table.load restores data but not functions.
LegacyBasher_SoulstormHandlers=LegacyBasher_SoulstormHandlers or {}
local handlers=LegacyBasher_SoulstormHandlers
function LegacyBasher_InstallSoulstorm()
Legacy=Legacy or {};Legacy.Basher=Legacy.Basher or {}
local B=Legacy.Basher
B.Soulstorm=B.Soulstorm or {}
local H=B.Soulstorm
local function now()
 local value=type(getEpoch)=='function' and tonumber(getEpoch()) or os.time()
 return value>20000000000 and value/1000 or value
end
local function settings() return Legacy.Settings and Legacy.Settings.Basher or {} end
local function apostate()
 local status=gmcp and gmcp.Char and gmcp.Char.Status
 return status and tostring(status.class or ''):lower()=='apostate'
end
local function room()
 return tostring(gmcp and gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.num or '')
end
local function normalize(name)
 return tostring(name or ''):lower():gsub('^%s+',''):gsub('%s+$','')
end
local function current()
 local target=gmcp and gmcp.IRE and gmcp.IRE.Target or {}
 local id=tostring(target.Set or '')
 local info=target.Info or {}
 if not id:match("^[A-Za-z0-9][A-Za-z0-9_'%-]*$") then return nil end
 local npc=tostring(info.npc):lower()
 if npc=='false' or npc=='0' then return nil end
 local kind=tostring(info.type or ''):lower()
 if npc~='true' and npc~='1' and kind~='npc' and kind~='denizen' and not id:match('^%d+$') then return nil end
 local name=normalize(info.short_desc)
 if name=='' then name=normalize(info.name) end
 if name=='' then name=normalize(settings().desc) end
 return {id=id,name=name,room=room(),info=info}
end
function H.begin()
 H.pending=apostate() and true or false
 H.attempt=nil
end
function H.stop() H.pending=false;H.attempt=nil end
function H.reset() H.stop();H.effect=nil;H.targets={} end
local function key(id,room_id) return tostring(room_id or room())..':'..tostring(id) end
function H.forget(id,room_id)
 id=tostring(id or '')
 local where=tostring(room_id or room())
 if H.targets then H.targets[key(id,where)]=nil end
 if H.effect and H.effect.id==id and H.effect.room==where then H.effect=nil end
 if H.attempt and H.attempt.id==id and H.attempt.room==where then H.attempt=nil end
end
function H.before_attack(id,info,is_denizen)
 if not H.pending or not apostate() or settings().status~=true then return false end
 if not is_denizen or settings().shield==true then return false end
 local ctx=current()
 if not ctx or ctx.id~=tostring(id) then return false end
 -- Wait for the server to confirm Legacy's newly selected target.
 if tostring(settings().currentTar or '')~=ctx.id then return true end
 if info and info.id and tostring(info.id)~=ctx.id then return true end
 local health=tonumber((tostring((info or {}).hpperc or ''):gsub('%%','')))
 if health and health<=0 then return true end
 local effect=H.effect
 if effect and effect.expires_at and now()>=effect.expires_at then effect.active=false end
 H.targets=H.targets or {}
 if H.targets[key(ctx.id,ctx.room)] then return false end
 if type(B.queueAttackPackage)~='function' then return true end
 H.attempt=ctx
 local ok,queued=pcall(B.queueAttackPackage,'addclear','soulstorm '..ctx.id,true,'apostate-soulstorm-opener')
 if ok and queued==true then
  H.targets[key(ctx.id,ctx.room)]=ctx
  settings().queued=true
  sendCount=(tonumber(sendCount) or 0)+1
 elseif not ok then
  -- A partial queue send must not be retried indefinitely or leave an attack behind.
  settings().status=false;H.stop()
  if type(send)=='function' then pcall(send,'cq freestand') end
  if type(raiseEvent)=='function' then pcall(raiseEvent,'LegacyBasherStatus',false) end
  if type(Legacy.echo)=='function' then Legacy.echo('<red>Soulstorm opener could not be queued; hunting stopped.') end
 else H.attempt=nil end
 return true
end
function H.note(kind,name)
 if not apostate() then return false end
 name=normalize(name)
 if name=='' then return false end
 if kind=='faded' then
  local effect=H.effect
  if not effect or effect.name~=name then return false end
  effect.active=false;return true
 end
 if kind~='confirmed' and kind~='already active' then return false end
 local ctx=current()
 if not ctx or ctx.name~=name then return false end
 local attempt=H.attempt
 if attempt and (attempt.id~=ctx.id or attempt.room~=ctx.room or (attempt.name~='' and attempt.name~=name)) then return false end
 H.targets=H.targets or {}
 if settings().status==true and not attempt and not H.targets[key(ctx.id,ctx.room)] then return false end
 local effect=H.effect
 local expires_at=now()+40
 -- "Still profanes" confirms presence, not a new cast or a refreshed duration.
 if kind=='already active' and effect and effect.id==ctx.id and effect.room==ctx.room and effect.expires_at then
  expires_at=effect.expires_at
 end
 H.effect={id=ctx.id,name=name,room=ctx.room,active=true,expires_at=expires_at}
 H.targets[key(ctx.id,ctx.room)]=ctx
 H.attempt=nil
 return true
end
-- Reimport replaces event handlers instead of multiplying reset callbacks.
H.reset()
local tracked_room=room()
if type(registerAnonymousEventHandler)=='function' then
 -- Saved IDs belong to another runtime; never use them to unregister handlers.
 H.handlers=nil
 for event,fn in pairs({
  ['sysDisconnectionEvent']=H.reset,
  ['gmcp.Char.Status']=function() if not apostate() then H.reset() end end,
  ['gmcp.Room.Info']=function()
   if tracked_room~=room() then
    H.reset();tracked_room=room()
    if settings().status==true then H.begin() end
   end
  end,
 }) do
  if handlers[event] and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(handlers[event]) end
  handlers[event]=registerAnonymousEventHandler(event,fn)
 end
end
return H
end
return LegacyBasher_InstallSoulstorm()
