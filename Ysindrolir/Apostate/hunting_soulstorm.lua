-- Embedded in Legacy Basher. One opener per hunt activation; user-confirmed 40s duration.
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
function H.reset() H.stop();H.effect=nil end
function H.before_attack(id,info,is_denizen)
 if not H.pending or not apostate() or settings().status~=true then return false end
 if not is_denizen or settings().shield==true then return false end
 local ctx=current()
 if not ctx or ctx.id~=tostring(id) then return false end
 local health=tonumber((tostring((info or {}).hpperc or ''):gsub('%%','')))
 if health and health<=0 then return false end
 local effect=H.effect
 if effect and effect.expires_at and now()>=effect.expires_at then effect.active=false end
 if effect and effect.active and effect.id==ctx.id and effect.room==ctx.room then
  H.pending=false;return false
 end
 if type(B.queueAttackPackage)~='function' then return true end
 H.attempt=ctx
 local ok,queued=pcall(B.queueAttackPackage,'addclear','soulstorm '..ctx.id,true,'apostate-soulstorm-opener')
 if ok and queued==true then
  H.pending=false
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
 local effect=H.effect
 local expires_at=now()+40
 -- "Still profanes" confirms presence, not a new cast or a refreshed duration.
 if kind=='already active' and effect and effect.id==ctx.id and effect.room==ctx.room and effect.expires_at then
  expires_at=effect.expires_at
 end
 H.effect={id=ctx.id,name=name,room=ctx.room,active=true,expires_at=expires_at}
 H.pending=false;H.attempt=nil
 return true
end
-- Reimport replaces event handlers instead of multiplying reset callbacks.
if type(registerAnonymousEventHandler)=='function' then
 H.handlers=H.handlers or {}
 for event,fn in pairs({
  ['sysDisconnectionEvent']=H.reset,
  ['gmcp.Char.Status']=function() if not apostate() then H.reset() end end,
  ['gmcp.Room.Info']=function()
   if H.effect and H.effect.room~=room() then H.effect=nil end
  end,
 }) do
  if H.handlers[event] and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(H.handlers[event]) end
  H.handlers[event]=registerAnonymousEventHandler(event,fn)
 end
end
return H
