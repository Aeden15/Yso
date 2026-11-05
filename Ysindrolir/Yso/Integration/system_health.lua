-- Read-only system diagnostics. Loading this service never queries the game.
Yso = Yso or {}
Yso.system = Yso.system or {}
local S = Yso.system
S.version = 1
local expected = {'Legacy V2.1', 'AK', 'limb.1.2', 'Yso system',
  'Legacy Basher V2.1', 'Legacy UI V2.0', 'Yso Workspace Link'}

local function call(fn, ...)
  if type(fn) ~= 'function' then return false, 'unavailable' end
  return pcall(fn, ...)
end
local function resolve(path)
  local value = _G
  for part in tostring(path or ''):gmatch('[^.]+') do
    if type(value) ~= 'table' then return nil end
    value = value[part]
  end
  return value
end
local function contains(list, name)
  if type(list) ~= 'table' then return false end
  if list[name] then return true end
  for _, value in ipairs(list) do if value == name then return true end end
  return false
end
local function count(t)
  local n = 0
  for _ in pairs(type(t) == 'table' and t or {}) do n = n + 1 end
  return n
end
local function text(value)
  if type(value) ~= 'string' and type(value) ~= 'number' then return '' end
  return tostring(value):gsub('[<>\r\n]', '')
end

function S.check(opts)
  opts = type(opts) == 'table' and opts or {}
  local scope = opts.scope or 'runtime'
  local report = {ok = true, scope = scope, checks = {}, counts = {pass=0,warn=0,blocked=0,disabled=0}}
  local function add(id, status, detail, recovery)
    report.checks[#report.checks+1] = {id=id, status=status,
      detail=tostring(detail or ''), recovery=tostring(recovery or '')}
    report.counts[status] = (report.counts[status] or 0) + 1
    if status == 'blocked' then report.ok = false end
  end
  if scope ~= 'runtime' and scope ~= 'install' then
    add('scope', 'blocked', 'Unknown check scope', 'Use runtime or install.')
    return report
  end
  for _, name in ipairs({'send','registerAnonymousEventHandler','getPackages','getModules'}) do
    local available = type(_G[name]) == 'function'
    add('api.'..name, available and 'pass' or 'blocked',
      available and 'Available' or 'Required Mudlet API unavailable', 'Use a supported Mudlet profile.')
  end
  local ready, authenticated = call(Yso.session and Yso.session.is_ready)
  if scope == 'runtime' then
    add('session', ready and authenticated == true and 'pass' or 'blocked',
      ready and authenticated == true and 'Fresh character session confirmed' or 'Not authenticated or session service unavailable',
      'Log in normally and wait for fresh character GMCP; do not start offense yet.')
  else
    add('session', 'disabled', 'Authentication is not required for offline installation')
  end
  local okp, packages = call(getPackages)
  local okm, modules = call(getModules)
  for _, name in ipairs(expected) do
    local pkg = okp and contains(packages, name)
    local mod = okm and contains(modules, name)
    local status = pkg and mod and 'blocked' or (pkg or mod) and 'pass' or scope == 'install' and 'warn' or 'blocked'
    add('package.'..name, status, pkg and mod and 'Both package and module installed' or
      (pkg or mod) and 'Installed' or 'Not installed', 'Apply the coordinated bundle while disconnected, then restart the profile.')
  end
  if scope == 'runtime' then
    local ak_ready=type(ak)=='table' and type(affstrack)=='table' and type(affstrack.score)=='table'
    add('dependency.ak', ak_ready and 'pass' or 'blocked',
      ak_ready and 'AK namespace and opponent scores available' or 'AK namespace or opponent scores missing', 'Check AK installation and script errors.')
    add('dependency.legacy', type(Legacy) == 'table' and type(Legacy.Curing) == 'table' and 'pass' or 'blocked',
      'Legacy curing integration', 'Check Legacy installation, initialization and saved settings.')
  end
  local suspended = not (Yso.features and Yso.features.alchemist_offense == true)
  add('feature.alchemist_offense', suspended and 'disabled' or 'pass',
    suspended and 'Alchemist offense intentionally suspended; shared tracking and curing remain available' or 'Alchemist offense explicitly enabled')
  local bridge_ok, bridge = call(YsoWorkspaceLink and YsoWorkspaceLink.status, false)
  if not bridge_ok or type(bridge) ~= 'table' then
    add('release', scope == 'install' and 'warn' or 'blocked', 'Release status unavailable', 'Install the bundled workspace controller and inspect ysostatus.')
  else
    local release = type(bridge.release) == 'table' and bridge.release or {}
    local restart = bridge.restart_required == true or release.restart_required == true
    local proof = release.consistent == true and type(release.id)=='string' and release.id~=''
    local checked = {}
    for _, row in ipairs(type(release.packages)=='table' and release.packages or {}) do
      if type(row)~='table' or type(row.name)~='string' or checked[row.name] or row.installed~=true or row.consistent~=true then proof=false
      else checked[row.name]=true end
    end
    for _, name in ipairs(expected) do if not checked[name] then proof=false end end
    add('release', bridge.busy and 'blocked' or bridge.last_error and 'blocked' or not proof and (scope=='install' and 'warn' or 'blocked') or 'pass',
      bridge.busy and 'Update in progress' or bridge.last_error and ('Update failed: '..text(bridge.last_error)) or not proof and 'Installed packages do not prove a complete consistent release' or
      'Release '..text(release.id or 'unversioned'), 'Inspect ysostatus and complete release recovery before resuming.')
    add('release.restart', restart and scope == 'runtime' and 'blocked' or restart and 'warn' or 'pass',
      restart and 'Profile restart required' or 'No restart requirement reported', 'Restart the profile after the full update.')
    if bridge.changed then add('release.pending','warn','Workspace changes have not been applied','Verify and apply the intended release.') end
    for _, row in ipairs(release.packages or {}) do
      if row.ok == false or row.match == false or row.installed == false or row.consistent == false then
        add('release.package.'..text(row.id or row.name),'blocked','Package release mismatch: '..text(row.name or row.id),'Apply one complete release; do not mix package versions.')
      end
    end
    for _, conflict in ipairs(release.conflicts or {}) do
      add('release.conflict.'..text(type(conflict)=='table' and conflict.name or conflict),'warn',
        'Overlapping optional package detected','Review before installing overlapping targeting or Stormhammer packages.')
    end
  end
  if scope == 'runtime' then
    local C = Yso.curing or {}
    local good, policy = call(C.policy and C.policy.status)
    if good and type(policy) == 'table' then
      local current=policy.current_set
      if type(current)~='string' or current=='' then current=Legacy and Legacy.Curing and Legacy.Curing.ActiveServerSet end
      local known=policy.set_untrusted==false and type(current)=='string' and current~=''
      add('curing', known and 'pass' or 'blocked',
        policy.set_untrusted and 'Server curing state is untrusted: '..text(policy.set_untrusted_reason) or
        known and 'Active curing set: '..text(current) or 'Server curing state is unknown', 'Confirm the server curingset and resynchronize curing.')
    else
      add('curing','blocked','Curing policy diagnostics unavailable','Check Yso and Legacy curing initialization.')
    end
    local paused = Yso.pause and Yso.pause.offense
    add('offense.pause', paused and paused.active and 'warn' or 'pass',
      paused and paused.active and ('Offense paused: '..text(paused.reason)) or 'No manual offense pause reported')
    local registry = Yso.Combat and Yso.Combat.RouteRegistry
    local ids_ok, ids = call(registry and registry.active_ids)
    if not ids_ok or type(ids) ~= 'table' then
      add('routes','blocked','Route registry unavailable','Check script load order and package consistency.')
    else
      local active = ''
      local active_ok, selected = call(Yso.mode and Yso.mode.active_route_id)
      if active_ok then active = selected or '' end
      for _, id in ipairs(ids) do
        local resolved, entry = call(registry.resolve, id)
        local route = resolved and type(entry)=='table' and resolve(entry.namespace)
        if type(route) ~= 'table' then
          add('route.'..id,'blocked','Registered route implementation missing','Rebuild and apply matching route packages.')
        elseif active == id or route.state and route.state.loop_enabled == true then
          -- Existing explain() methods may initialize planners, reset a target,
          -- or clear pending confirmations. Read their last recorded state only.
          local state = route.state or {}
          local why = type(state.explain)=='table' and state.explain or {}
          local detail = type(why)=='table' and (why.reason or why.blocker or why.hold_reason or why.phase) or nil
          detail = detail or state.last_hold_reason or state.reason or state.template and state.template.last_reason
          if not detail or detail == '' then detail = 'Active; detailed route explanation unavailable' end
          add('route.'..id,'warn',detail,'Inspect the reported blocker and route confirmation state.')
          if state.pending or state.waiting and (state.waiting.reason or '') ~= '' then
            add('route.pending.'..id,'warn','Route has pending confirmation work','Wait for confirmation; stop the route before applying updates.')
          end
        end
      end
    end
    for _, lane in ipairs({'eq','bal','class','free'}) do
      local q = Yso.queue
      if q then
        local staged_ok, staged = call(q.list, lane)
        local owned_ok, owned = call(q.get_owned, lane)
        if staged_ok and (type(staged)=='string' and staged~='' or type(staged)=='table' and next(staged)) or owned_ok and owned then
          add('queue.'..lane,'warn','Commands staged or owned on '..lane,'Stop automation and drain or clear owned commands before an update.')
        end
      end
    end
    local class = gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class or Yso.class
    if tostring(class or ''):lower() == 'magi' then
      local ids = Yso.magi and Yso.magi.weapons and Yso.magi.weapons.ids or {}
      add('equipment.magi', tostring(ids.staff or '')~='' and 'pass' or 'warn',
        tostring(ids.staff or '')~='' and 'Staff discovered' or 'Staff has not been discovered', 'Request equipment discovery after authentication and verify the staff.')
    end
    local ndb_ok, ndb = call(Legacy and Legacy.NDB and Legacy.NDB.network_status)
    add('ndb.refresh', ndb_ok and type(ndb)=='table' and ndb.refresh_enabled == true and 'pass' or 'warn',
      ndb_ok and type(ndb)=='table' and ndb.mode == 'cache_only' and 'NDB uses cached records; secure refresh unavailable' or 'Secure character refresh is unavailable',
      'Use cached or in-game character information; insecure HTTP refresh is disabled.')
    local D = Yso.apostate and Yso.apostate.daegger
    if D and type(D.stock)=='table' then
      local assumed = 0
      for _, value in pairs(D.stock) do if value == true then assumed = assumed+1 end end
      add('supplies.apostate', assumed > 0 and 'warn' or 'pass', assumed > 0 and 'Some venom availability is configured rather than measured' or 'Venom availability has no optimistic boolean defaults', 'Confirm actual venom stock before enabling offense.')
    end
    local F = Yso.alc and Yso.alc.form
    if not suspended and F then
      add('supplies.alchemist', count(F.phials)>0 and 'pass' or 'warn', count(F.phials)>0 and 'Phial inventory available' or 'Phial inventory unknown', 'Refresh phial inventory after obtaining Alchemist access.')
    end
    local handlers = count(Yso.session and Yso.session.handlers)
    local timers = count(Yso.session and Yso.session.timers)
    add('startup.pending', timers>0 and 'warn' or 'pass', tostring(timers)..' session timers; '..tostring(handlers)..' session handlers', 'Allow startup to finish; repeated checks can reveal accumulating work.')
  end
  if opts.echo ~= false and type(cecho) == 'function' then
    cecho('<steel_blue>[Yso check] <reset>'..(report.ok and 'No blocking checks' or 'Action required')..'\n')
    for _, row in ipairs(report.checks) do
      cecho('  '..row.status:upper()..' '..text(row.id)..': '..text(row.detail)..'\n')
      if row.status == 'blocked' and row.recovery ~= '' then cecho('    '..text(row.recovery)..'\n') end
    end
  end
  return report
end
return S
