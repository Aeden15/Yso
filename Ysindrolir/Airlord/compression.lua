-- Gauge observations belong to Yso's current target; no separate target selector.
Yso = Yso or {}; Yso.off = Yso.off or {}; Yso.off.airlord = Yso.off.airlord or {}
local C = {}; Yso.off.airlord.compression = C
C.state = {}
C.fresh_s = 3
local function now() return Yso.util.now() end
local function current(who)
  local t=type(Yso.get_target)=='function' and Yso.get_target() or ''
  return type(who)=='string' and type(t)=='string' and t~='' and who:lower()==t:lower()
end
function C.clear() C.state={} end
function C.observe(who,level)
  level=tonumber(level)
  if not current(who) or not level or level<0 then return false end
  C.state={who=who,level=level,at=now()}
  for _,route in pairs({Yso.off.airlord.lock,Yso.off.airlord.damage}) do
    if level<6 then route.release_execute() end
    if route.sync_updraft then route.sync_updraft() end
    if route.sync_buffet then route.sync_buffet() end
  end
  C.wake(); return true
end
local gauge_levels={
  ['at normal levels']=0,
  ['slightly elevated']=1,
  ['elevated']=2,
  ['moderately elevated']=3,
  ['severely elevated']=4,
  ['extremely elevated']=5,
  ['terminally elevated']=6,
}
function C.observe_description(who,description)
  local level=gauge_levels[description]
  if level==nil then return false end
  return C.observe(who,level)
end
function C.invalidate(who)
  if not current(who) then return false end
  C.clear()
  for _,route in pairs({Yso.off.airlord.lock,Yso.off.airlord.damage}) do
    route.release_execute()
    if route.sync_updraft then route.sync_updraft() end
    if route.sync_buffet then route.sync_buffet() end
  end
  C.wake(); return true
end
function C.level()
  local s=C.state
  if current(s.who) and now()-s.at<=C.fresh_s then return s.level end
end
function C.ready()
  return (C.level() or 0)>=6
end
function C.wake()
  if Yso.mode and type(Yso.mode.nudge_route_loop)=='function' then
    Yso.mode.nudge_route_loop('airlord_lock','pressure_observation')
    Yso.mode.nudge_route_loop('airlord_damage','pressure_observation')
  end
end
return C
