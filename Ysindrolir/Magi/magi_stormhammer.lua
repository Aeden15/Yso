-- Manual room-aware Stormhammer. Priority helpers load before this script.
thammer = thammer or {}
local H = thammer
local initialize = not H.initialized and H.players == nil
H.initialized = true
H.players = H.players or {}
H.handlers = H.handlers or {}
H.target_list = H.target_list == 'All' and 'All' or 'List'
local function note(s) if type(cecho)=='function' then cecho('<yellow>[Stormhammer] <reset>'..s..'\n') end end
local function name(raw) return tprio and tprio.name(raw) end
local function self_name() return name(gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.name) end
function H.set_mode(raw)
  local mode = tostring(raw or ''):lower()
  if mode~='list' and mode~='all' then note('Use shtar List or shtar All; city filters are unavailable.'); return false end
  H.target_list = mode=='all' and 'All' or 'List'
  note('Now targeting '..H.target_list..'.'); return true
end
function H.getTargets(mode)
  local result, seen = {}, {}
  if mode~='List' and mode~='All' then return result end
  local function add(raw)
    local n = name(raw)
    if n and n~=self_name() and H.players[n] and not seen[n] and #result<3 then
      result[#result+1] = n; seen[n] = true
    end
  end
  add(Yso and type(Yso.get_target)=='function' and Yso.get_target() or target)
  if mode=='List' then
    for _,n in ipairs(tprio and tprio.list or {}) do add(n) end
  else
    local sorted = {}
    for n in pairs(H.players) do sorted[#sorted+1] = n end
    table.sort(sorted)
    for _,n in ipairs(sorted) do add(n) end
  end
  return result
end
function H.cast()
  local targets = H.getTargets(H.target_list)
  if #targets==0 then note('No eligible targets in the room.'); return false end
  local W = Yso and Yso.magi and Yso.magi.weapons
  if not W or type(W.get)~='function' then note('Equipment tracker is unavailable.'); return false end
  local staff, shield = W.get('staff'), W.get('shield')
  if staff=='' or shield=='' then
    W.refresh()
    note('Staff or shield unresolved. Checking eq/ii; retry sth after the listings arrive.')
    return false
  end
  sendAll('setalias stmpvp stand/wield staff'..staff..' shield'..shield..'/cast stormhammer at '..table.concat(targets,' and '),
    'queue add free stmpvp', false)
  return true
end
local function capture_player(item)
  if type(item)~='table' then return end
  local n = name(item.name)
  local full = tostring(item.fullname or '')
  if n and n~=self_name() and not full:lower():find('the soul of',1,true) then H.players[n]=true end
end
function hammer_players(event)
  local room = gmcp and gmcp.Room
  if type(room)~='table' then return end
  if event=='gmcp.Room.Players' then
    if type(room.Players)~='table' then return end
    H.players = {}
    for _,item in ipairs(room.Players) do capture_player(item) end
  elseif event=='gmcp.Room.AddPlayer' then capture_player(room.AddPlayer)
  elseif event=='gmcp.Room.RemovePlayer' then
    local raw = room.RemovePlayer
    local n = name(type(raw)=='table' and raw.name or raw)
    if n then H.players[n]=nil end
  else return end
  if type(tprio_auto_target)=='function' then tprio_auto_target() end
end
local function bind(event,fn)
  if type(registerAnonymousEventHandler)~='function' then return end
  if H.handlers[event] and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(H.handlers[event]) end
  H.handlers[event]=registerAnonymousEventHandler(event,fn)
end
for _,event in ipairs({'gmcp.Room.Players','gmcp.Room.AddPlayer','gmcp.Room.RemovePlayer'}) do bind(event,hammer_players) end
bind('sysDisconnectionEvent', function() H.players={} end)
if initialize and gmcp and gmcp.Room and gmcp.Room.Players then hammer_players('gmcp.Room.Players') end
return H
