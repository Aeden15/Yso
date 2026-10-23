-- Maintained source for the Mudlet Apostate utilities script.
Yso = Yso or {}; Yso.apostate = Yso.apostate or {}
local A = Yso.apostate
A.trace_state = A.trace_state or { count = 0, interval = 2, party = false }

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function note(s)
  if type(cecho) == 'function' then cecho('<DeepPink>[Apostate] <violet_red>' .. s .. '\n') end
end
local function person(s) return s:match("^[A-Za-z][A-Za-z'%-]*$") ~= nil end
function A.active()
  local status = gmcp and gmcp.Char and gmcp.Char.Status
  local class = status and (status.class or status.classname) or Yso.class
  return trim(class):lower() == 'apostate'
end
local function enabled()
  if A.active() then return true end
  note('This alias requires Apostate class.'); return false
end
local function current_target()
  local name = type(Yso.get_target) == 'function' and Yso.get_target() or nil
  name = trim(name)
  if not person(name) then note('Set a valid target first.'); return nil end
  return name
end
local function command(cmd, clear)
  if type(send) ~= 'function' then return false end
  if clear then send('cq all', false) end
  send(cmd, false); return true
end

function A.alias(kind, arg)
  if not enabled() then return false end
  arg = trim(arg)
  local cmd
  if kind == 'beck' then
    if arg ~= '' and not person(arg) then note('Use beck [person].'); return false end
    cmd = 'demon beckon' .. (arg ~= '' and ' ' .. arg or '')
  elseif kind == 'melt' then
    if not arg:match('^[A-Za-z0-9_%-]+$') then note('Use dmelt <icewall>.'); return false end
    cmd = 'demon scorch ' .. arg
  elseif kind == 'shrivel' then
    arg = arg:lower():gsub('%s+', ' ')
    local limbs = {arms=true, legs=true, ['left arm']=true, ['right arm']=true,
      ['left leg']=true, ['right leg']=true}
    if not limbs[arg] then note('Use shriv arms|legs|left arm|right arm|left leg|right leg.'); return false end
    local target = current_target(); if not target then return false end
    cmd = 'shrivel ' .. arg .. ' ' .. target
  elseif kind == 'sap' or kind == 'strip' or kind == 'soulstorm' or (kind == 'blackwind' and arg == 'c') then
    local target = current_target(); if not target then return false end
    local verbs = {sap='demon sap', strip='demon strip', soulstorm='soulstorm', blackwind='choke'}
    cmd = verbs[kind] .. ' ' .. target
  else
    local choices = {
      siphon = {o='demon syphon', f='demon syphon off'},
      pentagram = {c='carve pentagram', d='dispel pentagram'},
      gravehands = {s='summon hands of the grave', b='banish hands of the grave'},
      blackwind = {w='blackwind', h='human'},
    }
    cmd = choices[kind] and choices[kind][arg]
    if not cmd then note('Invalid Apostate alias option.'); return false end
  end
  return command(cmd, true)
end

function A.trace(prefix, name, interval)
  if not enabled() then return false end
  name = trim(name)
  if name:lower() == 'off' then
    return command('demon trace off', false)
  end
  interval = trim(interval)
  local every = interval == '' and 2 or tonumber(interval)
  if not person(name) or not every or every < 1 or every % 1 ~= 0 then
    note('Use [p]trace <person> [positive movement count], or trace off.'); return false
  end
  local s = A.trace_state
  s.target, s.count, s.interval, s.party = name, 0, every, prefix == 'p'
  command('demon trace ' .. name, false)
  if s.party then command('pt Tracing ' .. name .. ', reporting on ' .. every .. ' movements', false) end
  return true
end
function A.trace_started(name)
  local s = A.trace_state
  name = trim(name)
  if not s.target or s.target:lower() ~= name:lower() then s.party = false end
  s.target, s.count = name, 0
end
function A.trace_moved(name, room)
  local s = A.trace_state
  if not A.active() or not s.target or trim(name):lower() ~= s.target:lower() then return end
  s.count = (s.count or 0) + 1
  if not s.party then return end
  if room == 'On the clouds' then command('pt ' .. name .. " duanathar'd", false) end
  if s.count >= s.interval then
    command('pt ' .. name .. ' moved to ' .. room, false); s.count = 0
  end
end
function A.trace_halted()
  local s = A.trace_state
  if s.party and A.active() then command('pt Tracing off', false) end
  s.target, s.count, s.party = nil, 0, false
end
function A.reset()
  A.baalzadeen, A.taste, A.pentagram = nil, nil, nil
  local s = A.trace_state
  s.target, s.count, s.party = nil, 0, false
end

-- Only a fresh Contemplate response can request Catharsis. No delayed replay.
function A.note_mana(name, current, maximum)
  -- Replies arrive in request order. Consume a cancelled route request before
  -- permitting the standalone helper to handle a later manual Contemplate.
  local key=type(name)=='string' and name:lower() or ''
  local cancelled=A.cancelled_contemplates and A.cancelled_contemplates[key] or 0
  if cancelled>0 then
    A.cancelled_contemplates[key]=cancelled-1
    return false
  end
  if not A.active() then return false end
  local victim = type(Yso.get_target) == 'function' and Yso.get_target() or nil
  if type(victim) ~= 'string' or not person(victim) or type(name) ~= 'string'
    or victim:lower() ~= name:lower() then return false end
  current, maximum = tonumber(current), tonumber(maximum)
  if not current or not maximum or maximum <= 0 or current < 0 or current > maximum
    or current ~= current or maximum ~= maximum or maximum == math.huge then return false end
  if Yso.tgt and type(Yso.tgt.set_mana_pct) == 'function' then
    Yso.tgt.set_mana_pct(victim, current * 100 / maximum)
  end
  local route = Yso.off and Yso.off.apostate and Yso.off.apostate.truelock
  if route and route.is_enabled() then return route.note_mana(name, current, maximum) end
  if current * 2 >= maximum or type(sendAll) ~= 'function' then return false end
  local now = type(getEpoch) == 'function' and tonumber(getEpoch()) or os.time()
  if now > 20000000000 then now = now / 1000 end
  if A.catharsis_sent_at and now - A.catharsis_sent_at < 4.4 then return false end
  A.catharsis_sent_at = now
  sendAll('cq all', 'demon catharsis ' .. victim)
  return true
end

-- Replace handlers on script reload instead of registering duplicate callbacks.
if type(registerAnonymousEventHandler) == 'function' then
  A.handlers = A.handlers or {}
  local events = {
    ['gmcp.Room.Info'] = function()
      local room = gmcp and gmcp.Room and gmcp.Room.Info
      local id = room and room.num
      if id == nil or A.room_id ~= id then A.pentagram = nil end
      A.room_id = id
    end,
    ['sysDisconnectionEvent'] = function() A.reset(); A.room_id = nil; A.catharsis_sent_at = nil end,
    ['gmcp.Char.Status'] = function() if not A.active() then A.reset() end end,
  }
  for event, fn in pairs(events) do
    if A.handlers[event] and type(killAnonymousEventHandler) == 'function' then
      killAnonymousEventHandler(A.handlers[event])
    end
    A.handlers[event] = registerAnonymousEventHandler(event, fn)
  end
end
