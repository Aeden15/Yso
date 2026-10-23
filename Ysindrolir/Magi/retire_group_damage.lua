-- Import-time migration: the former generic route is replaced by gwater/fstorm.
Yso=Yso or {};Yso.off=Yso.off or {};Yso.off.magi=Yso.off.magi or {}
local id='magi_group_damage'
local old=Yso.off.magi.group_damage
local function cancel(row)
  if type(row)~='table' then return end
  if row.timer_id and type(killTimer)=='function' then pcall(killTimer,row.timer_id) end
  row.timer_id=nil
end
local fallback=Yso.util and Yso.util._route_alias_fallback
for key,row in pairs(fallback and fallback.loops or {}) do
  if key==id or (old and row.route==old) then cancel(row);fallback.loops[key]=nil end
end
if type(old)=='table' then
  old.enabled=false
  if old.cfg then old.cfg.enabled=false end
  if old.state then
    cancel(old.state)
    old.state.enabled=false;old.state.loop_enabled=false;old.state.busy=false
  end
  if type(old.alias_loop_on_stopped)=='function' then
    pcall(old.alias_loop_on_stopped,{reason='route_retired',silent=true})
  end
  if old.state then old.state.pending={};old.state.waiting={};old.state.in_flight={} end
end
Yso.off.magi.group_damage=nil
local Q=Yso.queue
if Q then
  if type(Q.get_owned)=='function' then
    for _,lane in ipairs({'eq','bal','class','free'}) do
      local owned=Q.get_owned(lane)
      if owned and owned.route==id then
        if type(Q.clear_lane)=='function' then pcall(Q.clear_lane,lane,{qtype=owned.qtype}) end
        local staged=type(Q.get_staged_owner)=='function' and Q.get_staged_owner(lane) or nil
        if staged and staged.route==id and type(Q.clear)=='function' then pcall(Q.clear,lane) end
      end
    end
  end
  if Q._commit_hint and Q._commit_hint.route==id then
    if type(Q.clear)=='function' then pcall(Q.clear,'all') end
    Q._commit_hint=nil
  end
end
local core=Yso.off.core
if core then
  if core.routes then core.routes[id]=nil end
  if core.state and core.state.active==id then core.state.active='' end
end
local loop=Yso.mode and Yso.mode.route_loop
if loop then
  if loop.active==id then loop.active='' end
  if loop.nudges then loop.nudges[id]=nil end
end
