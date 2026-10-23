-- Enemy Deliverance is an explicit-release attack hold, independent of target pauses.
Yso = Yso or {}
Yso.Combat = Yso.Combat or {}
local D = Yso.Combat.Deliverance or {}
Yso.Combat.Deliverance = D
D.state = D.state or { active = false, failures = {} }

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end
local function announce(message)
  if type(cecho) == 'function' then
    cecho('\n<red>[Yso:DELIVERANCE]<reset> ' .. message .. '\n')
  elseif type(echo) == 'function' then echo('[Yso:DELIVERANCE] ' .. message .. '\n') end
end
function D.is_held() return D.state.active == true end
function D.blocks(opts)
  if not D.is_held() then return false end
  local kind = trim(type(opts) == 'table' and opts.kind or ''):lower()
  return kind ~= 'cure' and kind ~= 'defense' and kind ~= 'utility'
end
function D.status()
  local s = D.state
  local failures = {}; for i, failure in ipairs(s.failures or {}) do failures[i] = failure end
  return { active = s.active == true, caster = s.caster, stage = s.stage,
    at = s.at, failures = failures }
end
local function guard_queue()
  -- Older companion packages can supply their own queue implementation. Guard
  -- its public dispatch boundaries as well as the on-disk queue's native checks.
  local Q = Yso.queue
  if type(Q) ~= 'table' then return end
  D.queue_guards = D.queue_guards or {}
  for name, index in pairs({ stage = 3, install_lane = 3, commit = 1,
    add = 0, addclear = 0, addclearfull = 0, raw = 0 }) do
    local original = Q[name]
    if type(original) == 'function' and original ~= D.queue_guards[name] then
      local option_index, is_raw = index, name == 'raw'
      local wrapper = function(...)
        local opts = option_index > 0 and select(option_index, ...) or nil
        if option_index > 0 then
          if D.blocks(opts) then return false, 'enemy_deliverance' end
        elseif D.is_held() and not D.queue_non_offense then
          local command = trim(select(1, ...)):upper()
          -- Cleanup is the only unclassified raw queue operation allowed.
          if not is_raw or not command:match('^CLEARQUEUE%s+[%a!]+$') then
            return false, 'enemy_deliverance'
          end
        end
        local previous = D.queue_non_offense
        if option_index > 0 and D.is_held() then D.queue_non_offense = true end
        local function pack(...) return { n = select('#', ...), ... } end
        local result = pack(pcall(original, ...))
        D.queue_non_offense = previous
        if not result[1] then error(result[2], 0) end
        return (unpack or table.unpack)(result, 2, result.n)
      end
      D.queue_guards[name] = wrapper
      Q[name] = wrapper
    end
  end
end
local function attempt(label, fn, ...)
  if type(fn) ~= 'function' then return false end
  local ok, result, detail = pcall(fn, ...)
  if not ok or result == false then
    D.state.failures[#D.state.failures + 1] = label .. ': ' .. tostring(detail or result)
    return false
  end
  return true
end
local function lookup(namespace)
  local current = _G
  for part in tostring(namespace or ''):gmatch('[^.]+') do
    if type(current) ~= 'table' then return nil end
    current = current[part]
  end
  return current
end
local function stop_routes()
  local seen, routes = {}, {}
  local function add(id, route)
    if type(route) ~= 'table' or seen[route] then return end
    seen[route] = true; routes[#routes + 1] = { id = id, route = route }
  end
  local registry = Yso.Combat.RouteRegistry
  if registry and type(registry.active_ids) == 'function' and type(registry.resolve) == 'function' then
    for _, id in ipairs(registry.active_ids()) do
      local entry = registry.resolve(id)
      if entry then add(id, lookup(entry.namespace)) end
    end
  end
  local core = Yso.off and Yso.off.core
  for id, route in pairs(core and core.routes or {}) do add(id, route) end
  local fallback = Yso.util and Yso.util._route_alias_fallback
  for id, row in pairs(fallback and fallback.loops or {}) do
    add(id, row.route)
    if row.timer_id then
      attempt(tostring(id) .. ' fallback timer', killTimer, row.timer_id)
      row.timer_id = nil
    end
    -- Its callback checks row identity before attacking. Invalidate that token
    -- too, so a callback already queued by Mudlet stays harmless after release.
    fallback.loops[id] = nil
  end
  -- Some package controllers are not in the static registry (including older imports).
  local visited = {}
  local function scan(node, depth)
    if type(node) ~= 'table' or visited[node] or depth > 5 then return end
    visited[node] = true
    if type(node.attack_function) == 'function' or type(node.build_payload) == 'function'
      or node.alias_owned == true then
      add(node.key or node.route_contract and node.route_contract.id, node)
      return
    end
    for _, child in pairs(node) do if type(child) == 'table' then scan(child, depth + 1) end end
  end
  scan(Yso.off, 0)
  scan(Yso.dragon, 0)
  for _, item in ipairs(routes) do
    local route, id = item.route, item.id
    local modes = Yso.mode
    local registered = id and registry and registry.resolve and registry.resolve(id)
    if registered and modes and type(modes.stop_route_loop) == 'function' then
      attempt(tostring(id) .. ' scheduler', modes.stop_route_loop, id, 'enemy_deliverance', true)
    else
      local stop = route.on_stop or route.stop or route.off
      attempt(tostring(id or 'unlisted') .. ' stop', stop, 'enemy_deliverance')
    end
    -- Enforce cleanup even if a controller's stop hook failed or is incomplete.
    route.enabled = false
    if type(route.cfg) == 'table' then route.cfg.enabled = false end
    local state = route.state
    if type(state) == 'table' then
      for _, key in ipairs({ 'timer_id', 'loop_timer', 'timer' }) do
        if state[key] ~= nil then
          attempt(tostring(id or 'unlisted') .. ' timer', killTimer, state[key])
          state[key] = nil
        end
      end
      state.enabled, state.loop_enabled, state.busy = false, false, false
      state.pending, state.waiting, state.in_flight = {}, {}, {}
      state.cooldown, state.mindlock_request, state.lock_plan = nil, nil, nil
      state.last_cmd, state.last_sent_cmd = '', ''
      state.template = state.template or {}
      state.template.last_disable_reason = 'enemy_deliverance'
    end
  end
  if core and core.state then core.state.active = '' end
  if Yso.mode and Yso.mode.route_loop then
    Yso.mode.route_loop.active = ''
    Yso.mode.route_loop.nudges = {}
  end
end
local function clear_attacks()
  local Q = Yso.queue
  if Q then
    attempt('staged attacks', Q.clear, 'all')
    Q._commit_hint = nil
  end
  local defaults = { eq = 'e!p!w!t', bal = 'b!p!w!t', class = 'c!p!w!t', free = 'eb!w!p!t' }
  for _, lane in ipairs({ 'eq', 'bal', 'class', 'free' }) do
    if Q and type(Q.clear_lane) == 'function' then
      local owned = type(Q.get_owned) == 'function' and Q.get_owned(lane) or nil
      local default = type(Q.qtype_for_lane) == 'function' and Q.qtype_for_lane(lane) or defaults[lane]
      if owned and trim(owned.qtype) ~= '' and owned.qtype ~= default then
        attempt(lane .. ' custom server queue', Q.clear_lane, lane, { qtype = owned.qtype })
      end
      attempt(lane .. ' server queue', Q.clear_lane, lane)
    elseif type(send) == 'function' then
      attempt(lane .. ' server queue', send, 'CLEARQUEUE ' .. defaults[lane], false)
    else
      D.state.failures[#D.state.failures + 1] = lane .. ' server queue: no sender available'
    end
  end
end
function D.observe(name, stage)
  name = trim(name)
  if stage ~= 'channeling' and stage ~= 'active' then return false end
  local target = type(Yso.get_target) == 'function' and Yso.get_target() or rawget(_G, 'target')
  if name == '' or name:lower() ~= trim(target):lower() then return false end
  local s = D.state
  local fresh = not D.is_held()
  local advance = s.stage ~= 'active' and stage == 'active'
  if fresh then
    s.active, s.caster, s.stage, s.at, s.failures = true, name, stage,
      type(getEpoch) == 'function' and getEpoch() or os.time(), {}
    -- Latch before callbacks/queue clears: a queued wake must already be blocked.
    guard_queue()
    stop_routes()
    clear_attacks()
  elseif advance then s.stage = 'active' end
  if fresh or advance then
    announce(s.caster .. ' Deliverance ' .. s.stage .. '. Automated attacks STOPPED. '
      .. 'Use deliverance status; deliverance release to unlock, then start a route explicitly.')
    if #s.failures > 0 then announce('Shutdown issues: ' .. table.concat(s.failures, '; ')) end
  end
  return true
end
function D.release()
  D.state.active = false
  announce('Hold released. Routes remain OFF; other pauses are unchanged.')
  return true
end
function D.command(command)
  if command == 'release' then return D.release() end
  local s = D.status()
  announce(s.active and (s.caster .. ' ' .. s.stage .. '; attack hold active. Use deliverance release.')
    or 'No Deliverance hold. Routes are not automatically restarted.')
  if #s.failures > 0 then announce('Shutdown issues: ' .. table.concat(s.failures, '; ')) end
  return s
end
return D
