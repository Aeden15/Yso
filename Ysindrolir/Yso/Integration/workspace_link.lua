-- Independent controller: never embed this in either module it reloads.
-- Workspace XMLs are read-only inputs; Mudlet owns only profile-local copies.
YsoWorkspaceLink=YsoWorkspaceLink or {}
local R=YsoWorkspaceLink
if R.busy then return R end
R.root=R.root or 'C:/Users/shuji/OneDrive/Desktop/Yso systems'
R.handlers=R.handlers or {};R.watches=R.watches or {};R.timers=R.timers or {}
R.generation=(R.generation or 0)+1
R.sequence=R.sequence or 0
local generation=R.generation
local names={'AK','Yso system'}
local function normalize(p) return tostring(p or ''):gsub('\\','/'):gsub('/+$',''):lower() end
local function home() return getMudletHomeDir():gsub('\\','/'):gsub('/+$','')..'/yso-workspace' end
local function source(name) return R.root..'/Ysindrolir/mudlet packages/'..name..'.xml' end
local function staged(name) return home()..'/modules/'..name..'.xml' end
local function applied(name) return home()..'/modules/'..name..'.applied.xml' end
local function published(name,suffix) return R.root..'/Ysindrolir/.workspace-link-publish/'..name..suffix end
local function say(s)
 if type(cecho)=='function' then cecho('<steel_blue>[Yso workspace] <reset>'..s..'\n') end
end
local function read(path)
 local f=io.open(path,'rb');if not f then return nil end
 local s=f:read('*a');f:close();return s
end
local function write(path,data)
 local f,e=io.open(path,'wb');if not f then return false,e end
 local ok,why=f:write(data);local closed,close_error=f:close()
 if not ok or not closed then return false,why or close_error or 'write_failed' end
 return true
end
local function contains(t,name)
 if type(t)~='table' then return false end
 if t[name] then return true end
 for _,v in ipairs(t) do if v==name then return true end end
 return false
end
local function valid_xml(s)
 return type(s)=='string' and s:find('<MudletPackage[%s>]')~=nil
  and s:match('</MudletPackage>%s*$')~=nil
end
local function validation_receipt(name,bytes)
 local receipt=read(published(name,'.validated'))
 if not receipt then return nil end
 local ending=receipt:find('\n',1,true)
 if not ending or not receipt:sub(1,ending-1):match('^%d+$') then return nil end
 local length=tonumber(receipt:sub(1,ending-1))
 if length~=#bytes or receipt:sub(ending+1,ending+length)~=bytes then return nil end
 return receipt:sub(ending+length+1)
end
local function valid_lua_metadata(name,data)
 local pos=1;local compiler=loadstring or load
 while pos<=#data do
  local ending=data:find('\n',pos,true)
  if not ending then return false end
  local digits=data:sub(pos,ending-1)
  if not digits:match('^%d+$') then return false end
  local length=tonumber(digits)
  if not length or length>#data-ending then return false end
  local body=data:sub(ending+1,ending+length)
  if not compiler(body,name..':workspace preflight') then return false end
  pos=ending+length+1
 end
 return true
end
local function cancel(key)
 if R.timers[key] and type(killTimer)=='function' then pcall(killTimer,R.timers[key]) end
 R.timers[key]=nil
end
local function later(key,seconds,fn)
 cancel(key)
 R.timers[key]=tempTimer(seconds,function()
  if R.generation~=generation then return end
  R.timers[key]=nil;fn()
 end)
end
local function resolve(namespace)
 local value=_G
 for part in tostring(namespace or ''):gmatch('[^.]+') do
  if type(value)~='table' then return nil end
  value=value[part]
 end
 return value
end
function R.idle()
 if type(getProfileName)~='function' or getProfileName()~='Achaea' then return false,'wrong_profile' end
 if type(Yso)~='table' or type(Yso.mode)~='table' then return false,'yso_unavailable' end
 if type(Yso.is_actively_fighting)=='function' and Yso.is_actively_fighting() then return false,'automation_active' end
 if type(Yso.mode.active_route_id)=='function' then
  local id=Yso.mode.active_route_id()
  if id and id~='' and id~='none' then return false,'automation_active' end
 end
 local RR=Yso.Combat and Yso.Combat.RouteRegistry
 if not (RR and type(RR.active_ids)=='function') then return false,'route_registry_unavailable' end
 for _,id in ipairs(RR.active_ids()) do
  local entry=RR.resolve and RR.resolve(id)
  local route=entry and resolve(entry.namespace)
  if type(route)=='table' and type(route.state)=='table' then
   local pending=route.state.pending
   local waiting=(type(pending)=='table' and next(pending)~=nil)
    or (pending~=nil and pending~=false and type(pending)~='table')
   if route.state.loop_enabled==true or waiting then return false,'automation_active' end
  end
 end
 if Legacy and Legacy.Settings and Legacy.Settings.Basher and Legacy.Settings.Basher.status==true then
  return false,'automation_active'
 end
 local Q=Yso.queue
 if Q then
  for _,lane in ipairs({'bal','eq','class','free'}) do
   local p=type(Q.list)=='function' and Q.list(lane)
   if (type(p)=='string' and p~='') or (type(p)=='table' and next(p)~=nil) then return false,'commands_staged' end
   if type(Q.get_owned)=='function' and Q.get_owned(lane) then return false,'commands_queued' end
  end
 end
 return true
end
local function preflight(link)
 local ok,why=R.idle();if not ok then return nil,why end
 for _,api in ipairs({'getPackages','getModules','getModulePath','installModule','reloadModule',
  'setModulePriority','disableModuleSync','tempTimer','registerAnonymousEventHandler'}) do
  if type(_G[api])~='function' then return nil,'missing_api:'..api end
 end
 if link and (type(saveProfile)~='function' or type(uninstallPackage)~='function') then return nil,'migration_api_unavailable' end
 local jobs={}
 for i,name in ipairs(names) do
  local bytes=read(source(name))
  if not valid_xml(bytes) then return nil,'invalid_xml:'..name end
  -- The publisher uses a real XML parser. Byte-exact snapshots bind its
  -- extracted Lua metadata to these inputs, including malformed mid-save edits.
  local metadata=validation_receipt(name,bytes)
  if metadata==nil then return nil,'unpublished_xml:'..name end
  if not valid_lua_metadata(name,metadata) then return nil,'invalid_lua:'..name end
  local mod=contains(getModules(),name)
  local pkg=contains(getPackages(),name)
  if mod and pkg then return nil,'ambiguous_install:'..name end
  if mod and normalize(getModulePath(name))~=normalize(staged(name)) then return nil,'unmanaged_module:'..name end
  if not link and not mod then return nil,'not_linked:'..name end
  jobs[i]={name=name,bytes=bytes,was_module=mod,was_package=pkg,
   previous=read(staged(name)),priority=i-1}
 end
 return jobs
end
local function guard_routes()
 local M=Yso and Yso.mode
 if not M or type(M.start_route_loop)~='function' or M.start_route_loop==R.guarded_start then return end
 local original=M.start_route_loop
 R.guarded_start=function(...)
  if R.busy then return false,'workspace_reload' end
  return original(...)
 end
 M.start_route_loop=R.guarded_start
end
local function hold_offense()
 Yso.pause=Yso.pause or {};Yso.pause.offense=Yso.pause.offense or {}
 R.previous_pause={active=Yso.pause.offense.active==true,reason=Yso.pause.offense.reason}
 Yso.pause.offense.active=true;Yso.pause.offense.reason='workspace_reload'
 guard_routes()
end
function R.status(echo)
 local rows,changed={},false
 for _,name in ipairs(names) do
  local linked=type(getModulePath)=='function' and normalize(getModulePath(name))==normalize(staged(name))
  local bytes=read(source(name));local different=bytes~=read(applied(name))
  rows[#rows+1]={name=name,linked=linked,changed=different,source=source(name),module=staged(name)}
  changed=changed or different
 end
 local result={busy=R.busy==true,changed=changed,modules=rows,last_error=R.last_error}
 if echo~=false then
  for _,row in ipairs(rows) do say(row.name..': '..(row.linked and 'linked' or 'not linked')..', '..(row.changed and 'workspace update pending' or 'up to date')) end
  if R.busy then say('Update in progress.') end
  if R.last_error then say('Last update failed: '..R.last_error) end
 end
 return result
end
local function fail(reason)
 cancel('operation');cancel('timeout')
 local job=R.current
 -- Restore only the failed module's on-disk input. Successfully reloaded peers
 -- stay current; never claim an atomic rollback of live Lua globals.
 if job and job.was_module and job.previous then write(staged(job.name),job.previous) end
 R.busy=false;R.current=nil;R.last_error=tostring(reason);R.last_result='failed'
 say('Update stopped: '..R.last_error..'. A partial update is possible; automation stays stopped.')
 say('Offense remains paused; correct the update before resuming.')
 if R.backup_path then say('Profile backup: '..R.backup_path) end
end
local next_job
local function rearm_runtime()
 -- A full package-to-module conversion may remove native-owned anonymous
 -- handlers while leaving Lua globals and their install-once flags alive.
 for _,module in pairs({selfaff=Yso and Yso.selfaff,policy=Yso and Yso.curing and Yso.curing.policy}) do
  if type(module)=='table' and type(module.install_hooks)=='function' then
   for _,id in pairs(module._eh or {}) do
    if type(killAnonymousEventHandler)=='function' then pcall(killAnonymousEventHandler,id) end
   end
   module._eh={};module._hooks_installed=false;module.install_hooks()
  end
 end
end
local function finish_job(job)
 if not R.busy or R.current~=job or not job.ack then return end
 local ok,why=R.idle();if not ok then fail(why);return end
 if normalize(getModulePath(job.name))~=normalize(staged(job.name)) then fail('module_path_mismatch:'..job.name);return end
 if read(staged(job.name))~=job.bytes then fail('module_input_changed:'..job.name);return end
 local configured,err=pcall(function()
  setModulePriority(job.name,job.priority)
  disableModuleSync(job.name)
  if job.name=='Yso system' then rearm_runtime() end
 end)
 if not configured then fail(job.name..':'..tostring(err));return end
 local saved,e=write(applied(job.name),job.bytes)
 if not saved then fail(job.name..':snapshot:'..tostring(e));return end
 cancel('timeout');R.current=nil
 later('operation',0.1,next_job)
end
next_job=function()
 if not R.busy then return end
 local ok,why=R.idle();if not ok then fail(why);return end
 R.index=R.index+1
 local job=R.jobs[R.index]
 if not job then
  R.busy=false;R.last_result=R.action=='link' and 'linked' or 'reloaded';R.last_error=nil
  if R.previous_pause and Yso.pause and Yso.pause.offense and Yso.pause.offense.reason=='workspace_reload' then
   Yso.pause.offense.active=R.previous_pause.active;Yso.pause.offense.reason=R.previous_pause.reason or ''
  end
  say('AK and Yso '..R.last_result..' from the workspace. Combat automation remains stopped.')
  return
 end
 R.current=job
 if job.previous then
  local saved,e=write(home()..'/modules/'..job.name..'.previous.xml',job.previous)
  if not saved then fail(job.name..':previous_copy:'..tostring(e));return end
 end
 local saved,e=write(staged(job.name),job.bytes)
 if not saved then fail(job.name..':stage:'..tostring(e));return end
 later('timeout',20,function()
  -- Native deferred reloads cannot be cancelled by killing a Lua timer.
  -- Keep the operation, route guard and offense hold until its late ack arrives.
  R.last_error='waiting_for_native_module:'..job.name;R.last_result='waiting'
  say('Still waiting for '..job.name..'. Reload retries and offense remain blocked; use ysostatus. Restart the profile if no completion arrives.')
 end)
 local called,result,err=pcall(function()
  if job.was_package then
   uninstallPackage(job.name)
   if contains(getPackages(),job.name) then return false,'package_removal_failed' end
  end
  if job.was_module then return reloadModule(job.name) end
  return installModule(staged(job.name))
 end)
 if not called or result==false or (result==nil and err~=nil) then
  fail(job.name..':'..tostring(called and err or result));return
 end
 -- Completion comes from sysInstall, including native module reloads. Its
 -- callback schedules the next step rather than nesting another install.
end
local function start(action)
 if R.busy then return false,'busy' end
 local jobs,why=preflight(action=='link')
 if not jobs then say('Update held: '..why);return false,why end
 if not (lfs and type(lfs.mkdir)=='function') then return false,'filesystem_api_unavailable' end
 for _,dir in ipairs({home(),home()..'/modules',home()..'/backups'}) do pcall(lfs.mkdir,dir) end
 R.busy=true;R.jobs=jobs;R.index=0;R.current=nil;R.action=action;R.last_error=nil
 hold_offense()
 if action~='link' then later('operation',0,next_job);return true end
 -- Verify a complete backup before the first existing package is removed.
 R.sequence=R.sequence+1
 local filename='before-link-'..tostring(os.time())..'-'..R.sequence
 R.backup_path=home()..'/backups/'..filename..'.xml'
 local called,result,err=pcall(saveProfile,home()..'/backups',filename)
 if not called or result==false or (result==nil and err~=nil) then fail('profile_backup_failed');return false,'profile_backup_failed' end
 local attempts=0
 local function await_backup()
  if not R.busy then return end
  attempts=attempts+1
  if valid_xml(read(R.backup_path)) then later('operation',0.2,next_job)
  elseif attempts>=50 then fail('profile_backup_timeout')
  else later('operation',0.2,await_backup) end
 end
 later('operation',0.2,await_backup)
 return true
end
function R.link() return start('link') end
function R.reload() return start('reload') end
function R.check()
 local jobs,why=preflight(true)
 return jobs~=nil,why
end

-- Reinstallation replaces the controller's own hooks; linked modules do not own them.
for _,id in pairs(R.handlers) do if type(killAnonymousEventHandler)=='function' then pcall(killAnonymousEventHandler,id) end end
R.handlers={}
for path in pairs(R.watches) do if type(removeFileWatch)=='function' then pcall(removeFileWatch,path) end end
R.watches={}
for key in pairs(R.timers) do cancel(key) end
if type(getProfileName)~='function' or getProfileName()~='Achaea' then
 say('Disabled here: this workspace link belongs to the Achaea profile.')
 return R
end
if type(registerAnonymousEventHandler)=='function' then
 R.handlers.install=registerAnonymousEventHandler('sysInstall',function(_,name,errors)
  local job=R.current
  if not (R.busy and job and job.name==name) then return end
  guard_routes()
  if type(errors)=='string' and errors~='' then fail(name..':'..errors);return end
  job.ack=true;later('operation',0.1,function() finish_job(job) end)
 end)
 R.handlers.changed=registerAnonymousEventHandler('sysPathChanged',function(_,path)
  local relevant=normalize(path)==normalize(R.root..'/Ysindrolir/mudlet packages')
  for _,name in ipairs(names) do relevant=relevant or normalize(path)==normalize(source(name)) end
  if not relevant then return end
  later('watch',0.75,function()
   -- Atomic file replacement can remove an individual watch; re-arm it.
   if type(addFileWatch)=='function' then
    for _,name in ipairs(names) do
     local p=source(name)
     if type(removeFileWatch)=='function' then pcall(removeFileWatch,p) end
     local ok=pcall(addFileWatch,p);if ok then R.watches[p]=true end
    end
   end
   if R.status(false).changed then say('Built workspace XML changed. Run ysoreload when automation is stopped (ysolink for first setup).') end
  end)
 end)
end
if type(addFileWatch)=='function' then
 for _,path in ipairs({source('AK'),source('Yso system'),R.root..'/Ysindrolir/mudlet packages'}) do
  local ok=pcall(addFileWatch,path);if ok then R.watches[path]=true end
 end
end
return R
