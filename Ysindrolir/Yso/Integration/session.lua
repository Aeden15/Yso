-- Shared readiness for automatic game queries. Never infer login from cached GMCP.
Yso = Yso or {}
Yso.session = Yso.session or {}
local S = Yso.session
S.ready = S.installed == true and S.ready == true
S.installed = true
S.handlers = S.handlers or {}
S.consumers = S.consumers or {}
S.completed = S.completed or {}
S.timers = S.timers or {}
local pending = S.pending or {}
S.pending = {}
local function now()
  local value = type(getEpoch)=='function' and tonumber(getEpoch()) or os.time()
  value = value or os.time()
  return value > 1000000000000 and value / 1000 or value
end
S.generation = (S.generation or 0) + 1
for _, id in pairs(S.handlers) do
  if type(killAnonymousEventHandler) == 'function' then killAnonymousEventHandler(id) end
end
for _, id in pairs(S.timers) do
  if type(killTimer) == 'function' then killTimer(id) end
end
S.handlers = {}; S.timers = {}
function S.is_ready() return S.ready == true end
local function run(key, consumer)
  if S.ready and not S.completed[key] then
    S.completed[key] = true
    consumer.ready()
  end
end
function S.subscribe(key, ready, reset)
  S.consumers[key] = {ready=ready, reset=reset}
  run(key, S.consumers[key])
end
function S.invalidate()
  S.ready = false
  S.generation = S.generation + 1
  S.completed = {}
  for _, id in pairs(S.timers) do if type(killTimer) == 'function' then killTimer(id) end end
  S.timers = {}; S.pending = {}
  for _, consumer in pairs(S.consumers) do if consumer.reset then consumer.reset() end end
end
function S.later(key, delay, callback, survive_reload)
  if not S.ready or type(tempTimer) ~= 'function' then return false end
  if S.timers[key] and type(killTimer) == 'function' then killTimer(S.timers[key]) end
  local generation, token = S.generation, {}
  S.timer_tokens = S.timer_tokens or {}
  S.timer_tokens[key] = token
  S.pending[key] = survive_reload and {due=now()+delay, callback=callback} or nil
  S.timers[key] = tempTimer(delay, function()
    if not S.ready or S.generation ~= generation or S.timer_tokens[key] ~= token then return end
    S.timers[key] = nil
    S.timer_tokens[key] = nil
    S.pending[key] = nil
    callback()
  end)
  return S.timers[key]
end
local function evidence(event)
  if S.ready then return end
  local char = gmcp and gmcp.Char
  if type(char) ~= 'table' then return end
  -- Inspect only the payload associated with this fresh event.
  local valid = false
  if event == 'gmcp.Char.Status' then
    local status = char.Status
    valid = type(status) == 'table' and type(status.name) == 'string' and status.name:match('%S')
      and type(status.class) == 'string' and status.class:match('%S')
  elseif event == 'gmcp.Char.Vitals' then
    local vitals = char.Vitals
    valid = type(vitals) == 'table' and tonumber(vitals.hp) ~= nil and (tonumber(vitals.maxhp) or 0) > 0
  end
  if not valid then return end
  S.ready = true
  for key, consumer in pairs(S.consumers) do run(key, consumer) end
end
if type(registerAnonymousEventHandler) == 'function' then
  for _, event in ipairs({'sysConnectionEvent', 'sysDisconnectionEvent'}) do
    S.handlers[event] = registerAnonymousEventHandler(event, S.invalidate)
  end
  for _, event in ipairs({'gmcp.Char.Status', 'gmcp.Char.Vitals'}) do
    S.handlers[event] = registerAnonymousEventHandler(event, evidence)
  end
end
-- Essential completion work survives an authenticated reload, preserving its
-- deadline. Old closures remain invalid; disconnect discards these descriptors.
if S.ready then
  for key, job in pairs(pending) do
    S.later(key, math.max(0, job.due-now()), job.callback, true)
  end
end
return S
