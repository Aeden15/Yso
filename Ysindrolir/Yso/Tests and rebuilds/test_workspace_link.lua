-- Model Mudlet's asynchronous module lifecycle without touching a live profile.
local root=arg[1] or 'Ysindrolir'
local actual_io=io
local files,packages,modules,handlers,timers,calls,notes={},{},{},{},{},{},{}
local clock,serial=100,0
local workspace='C:/Users/shuji/OneDrive/Desktop/Yso systems'
local home='C:/Mudlet/profiles/Test'
local profile='Achaea'
getProfileName=function() return profile end
local xml='<MudletPackage version="1.001"><ScriptPackage /></MudletPackage>'
for _,name in ipairs({'AK','Yso system'}) do files[workspace..'/Ysindrolir/mudlet packages/'..name..'.xml']=xml end
local function publish()
 for _,name in ipairs({'AK','Yso system'}) do
  local body=files[workspace..'/Ysindrolir/mudlet packages/'..name..'.xml']
  files[workspace..'/Ysindrolir/.workspace-link-publish/'..name..'.validated']=#body..'\n'..body
 end
end
publish()
io={open=function(path,mode)
 if mode=='rb' then
  if not files[path] then return nil,'missing' end
  return {read=function() return files[path] end,close=function() return true end}
 end
 local text=''
 return {write=function(_,s) text=text..s;return true end,close=function() files[path]=text;return true end}
end}
lfs={attributes=function(p) return files[p] and {mode='file'} or nil end,mkdir=function() return true end}
getMudletHomeDir=function() return home end
getEpoch=function() return clock end
cecho=function(s) notes[#notes+1]=s end
getModules=function() local t={};for n in pairs(modules) do t[#t+1]=n end;return t end
getPackages=function() local t={};for n in pairs(packages) do t[#t+1]=n end;return t end
getModulePath=function(n) return modules[n] end
getModulePriority=function() return 0 end
setModulePriority=function(n,p) calls[#calls+1]='priority:'..n..':'..p end
disableModuleSync=function(n) calls[#calls+1]='nosync:'..n end
registerAnonymousEventHandler=function(e,f) serial=serial+1;handlers[serial]={event=e,fn=f};return serial end
killAnonymousEventHandler=function(id) handlers[id]=nil end
tempTimer=function(delay,f) serial=serial+1;timers[serial]={at=clock+delay,fn=f};return serial end
killTimer=function(id) timers[id]=nil end
local function fire(e,...)
 local copy={};for id,h in pairs(handlers) do copy[id]=h end
 for _,h in pairs(copy) do if h.event==e then h.fn(e,...) end end
end
local function drain()
 for _=1,100 do
  local id,at
  for i,t in pairs(timers) do if not at or t.at<at then id,at=i,t.at end end
  if not id then return end
  clock=at;local f=timers[id].fn;timers[id]=nil;f()
 end
 error('timer loop did not settle')
end
local watches={}
addFileWatch=function(p) watches[p]=(watches[p] or 0)+1;return true end
removeFileWatch=function(p) watches[p]=nil end
saveProfile=function(dir,name) calls[#calls+1]='backup';files[dir..'/'..name..'.xml']=xml;return true end
uninstallPackage=function(n) calls[#calls+1]='remove:'..n;packages[n]=nil;return true end
local fail_name
installModule=function(p)
 local name=p:match('([^/]+)%.xml$');calls[#calls+1]='install:'..name
 if name==fail_name then return nil,'fixture installation failure' end
 modules[name]=p;fire('sysInstall',name);return true
end
reloadModule=function(n)
 calls[#calls+1]='reload:'..n
 if n==fail_name then return nil,'fixture reload failure' end
 fire('sysInstall',n);return true
end
local active=false
Yso={mode={active_route_id=function() return active and 'apostate_vivisect' or '' end},
 Combat={RouteRegistry={active_ids=function() return {} end}},is_actively_fighting=function() return active end}
Yso.pause={offense={active=false}}
Yso.pause_offense=function(on,reason) Yso.pause.offense.active=on;Yso.pause.offense.reason=reason end
Yso.mode.start_route_loop=function() active=true;return true end
Legacy={Settings={Basher={status=false}}}
local rearmed=0
Yso.selfaff={_hooks_installed=true,_eh={},affs={paralysis={active=false}},install_hooks=function()
 assert(not Yso.selfaff._hooks_installed);Yso.selfaff._hooks_installed=true;rearmed=rearmed+1
end}
packages.AK=true;packages['Yso system']=true
local R=dofile(root..'/Yso/Integration/workspace_link.lua')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
profile='Other';local ok,why=R.link();eq(ok,false);eq(why,'wrong_profile');eq(#calls,0);profile='Achaea'
-- Registered routes from other classes can keep an empty pending table while idle.
Yso.off={magi={focus={state={loop_enabled=false,pending={}}}}}
Yso.Combat.RouteRegistry.active_ids=function() return {'magi_focus'} end
Yso.Combat.RouteRegistry.resolve=function() return {namespace='Yso.off.magi.focus'} end
eq(R.idle(),true)
-- Active automation must prevent backup, uninstall, staging and installs.
active=true;local ok,why=R.link();eq(ok,false);eq(why,'automation_active');eq(#calls,0);active=false
-- Preflight both source files before touching either installation.
local path=workspace..'/Ysindrolir/mudlet packages/Yso system.xml'
local good=files[path];files[path]='<MudletPackage>'
ok,why=R.link();eq(ok,false);eq(why,'invalid_xml:Yso system');eq(#calls,0);files[path]=good
files[path]='<MudletPackage><broken></MudletPackage>'
ok,why=R.link();eq(ok,false);eq(why,'unpublished_xml:Yso system');eq(#calls,0);files[path]=good
local script_path=workspace..'/Ysindrolir/.workspace-link-publish/Yso system.validated'
files[script_path]=#good..'\n'..good..'3\nend';ok,why=R.link();eq(ok,false);eq(why,'invalid_lua:Yso system');eq(#calls,0);publish()
assert(R.link());eq(R.busy,true);assert(not R.link());drain();eq(R.busy,false);eq(R.last_result,'linked')
assert(not packages.AK and not packages['Yso system'])
eq(modules.AK,home..'/yso-workspace/modules/AK.xml')
eq(modules['Yso system'],home..'/yso-workspace/modules/Yso system.xml')
local akpos,ysopos
for i,c in ipairs(calls) do if c=='install:AK' then akpos=i elseif c=='install:Yso system' then ysopos=i end end
assert(akpos<ysopos);eq(calls[1],'backup')
eq(rearmed,1)
eq(files[workspace..'/Ysindrolir/mudlet packages/AK.xml'],xml)
-- A profile-side module save must not mark the workspace as modified.
files[modules.AK]='profile-local rewrite';eq(R.status(false).changed,false)
-- Watcher only notifies, coalesces bursts, and never reloads automatically.
local before=#calls
files[path]=xml:gsub('ScriptPackage','AliasPackage')
fire('sysPathChanged',path);fire('sysPathChanged',path);drain();eq(#calls,before);eq(R.status(false).changed,true)
assert(not R.reload());publish()
assert(R.reload());drain();eq(R.last_result,'reloaded');eq(R.status(false).changed,false)
-- Re-evaluating the independent bridge replaces handlers/watches, not duplicates.
R=dofile(root..'/Yso/Integration/workspace_link.lua')
for _,n in pairs(watches) do eq(n,1) end
local count=0;for _,h in pairs(handlers) do if h.event=='sysPathChanged' then count=count+1 end end;eq(count,1)
-- Refuse to reload a module pointing outside the managed profile staging folder.
modules.AK=workspace..'/Ysindrolir/mudlet packages/AK.xml';before=#calls
ok,why=R.reload();eq(ok,false);eq(why,'unmanaged_module:AK');eq(#calls,before)
modules.AK=home..'/yso-workspace/modules/AK.xml'
-- Native reloads may complete after the timeout: quarantine, block retries and
-- route activation, retain offense pause, and reconcile the late acknowledgment.
local real_reload=reloadModule
reloadModule=function(name)
 if name~='AK' then return real_reload(name) end
 tempTimer(25,function() assert(R.busy);assert(Yso.pause.offense.active);fire('sysInstall',name) end)
 return nil
end
assert(R.reload());tempTimer(21,function()
 assert(R.busy);assert(not R.reload());assert(not Yso.mode.start_route_loop('apostate_vivisect'));assert(Yso.pause.offense.active)
end)
drain();eq(R.busy,false);eq(R.last_result,'reloaded');eq(Yso.pause.offense.active,false)
reloadModule=real_reload
-- A concurrent native save cannot be silently accepted as the new input.
reloadModule=function(name)
 tempTimer(2,function() files[modules[name]]='concurrent save';fire('sysInstall',name) end)
 return nil
end
assert(R.reload());drain();eq(R.last_result,'failed');assert(R.last_error:find('module_input_changed:AK',1,true))
assert(Yso.pause.offense.active);eq(files[workspace..'/Ysindrolir/mudlet packages/AK.xml'],xml)
reloadModule=real_reload
-- A failure must not announce success or continue to the next module.
fail_name='AK';before=#calls;assert(R.reload());drain();eq(R.busy,false)
assert(R.last_error:find('AK',1,true));for i=before+1,#calls do assert(calls[i]~='reload:Yso system') end
-- A missing migration backup must prevent package removal.
fail_name=nil;packages.AK=true;modules.AK=nil;saveProfile=function() return nil,'disk full' end
before=#calls;ok=R.link();if ok then drain() end
assert(packages.AK);for i=before+1,#calls do assert(calls[i]~='remove:AK') end
io=actual_io
print('PASS workspace link: preflight, idle gating, backup, staging, order, watcher, reload, idempotence and failures')
