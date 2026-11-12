-- Independent damage strategy; shared runtime owns delivery and cleanup.
local A=Yso.off.airlord
local M=A.make_route('damage','airlord_damage','Damage route')
local clear_staged=M.clear_staged
local function target() return type(Yso.get_target)=='function' and Yso.get_target() or '' end
local function score(aff)
  local s=affstrack and affstrack.score
  return tonumber(s and s[aff]) or 0
end
local function echo(text)
  if Yso.util and Yso.util.echo then Yso.util.echo(text)
  elseif type(cecho)=='function' then cecho('<cyan>[Yso] '..text..'<reset>\n') end
end
function M.observations(t) return {'gauge '..t,'assess '..t} end
function M.on_command(cmd,category)
  if category~='buffet' then M.state.last_setup_cmd=cmd end
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
  M.sync_updraft()
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
function M.select_command(t)
  local context = M.sync_updraft()
  local duress = ak and ak.duress or {}
  local pressure = M.compression.level() or 0
  if ak and ak.defs and ak.defs.shield then return 'manifest gale '..t,'defense_break' end
  if pressure >= 6 then return 'aero compression '..t,'execute' end
  if M.buffet_ready() then return 'manifest buffet '..t,'buffet' end

  if M.cfg.updraft_enabled and context and M.state.updraft_launched ~= context and pressure >= 4 then
    return 'manifest updraft '..t,'updraft'
  end

  local boosters = 0
  for _, attack in ipairs(A.relapse_attacks) do
    if score(attack.affliction) >= 100 then
      boosters = boosters + 1
    end
  end
  local pressure_command = 'aero pressure '..t
  if boosters >= 2 then
    return pressure_command,'pressure'
  end

  local tension = 'aero tension '..t
  local setup_command, category
  if score('tension') < 100 and M.state.last_setup_cmd ~= tension then
    setup_command, category = tension, 'tension'
  elseif boosters == 1 and pressure > 0 then
    return pressure_command,'pressure'
  else
    for _, attack in ipairs(A.relapse_attacks) do
      if score(attack.affliction) < 100 and not A.relapse_pending(attack.skill, t) then
        setup_command, category = attack.command..' '..t, 'affliction'
        break
      end
    end
  end

  if setup_command then
    if duress.asphyxiate ~= true then return 'aero asphyxiate '..t,'smoke_tracking' end
    return setup_command, category
  end
  return pressure_command,'pressure'
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
if type(registerAnonymousEventHandler)=='function' then
  if M.room_handler and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(M.room_handler) end
  M.room_handler=registerAnonymousEventHandler('gmcp.Room.Info',function() M.sync_updraft() end)
end
return M
