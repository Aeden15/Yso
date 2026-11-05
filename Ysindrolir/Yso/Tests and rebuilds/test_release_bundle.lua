-- Full installs are simulated: no live connection or profile is touched.
local root=arg[1] or 'Ysindrolir'
local original_io=io
local source=assert(io.open(root..'/Yso/Integration/release_bundle.lua','rb'))
local body=source:read('*a');source:close()
local controller_file=assert(io.open(root..'/Yso/Integration/workspace_link.lua','rb'))
local controller_body=controller_file:read('*a');controller_file:close()
assert(load(body))()
local B=assert(YsoRelease,'release library missing')
assert(B.sha256('')=='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
assert(B.sha256('abc')=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
assert(B.sha256(string.rep('a',1000000))=='cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0')
local files,modules,packages,timers,handlers,calls={},{},{},{},{},{}
local serial,clock,connected=0,0,false
local workspace='C:/workspace';local home='C:/profile/yso-workspace'
local manifest={schema_version=1,release_id='test.1',packages={}}
local ids={'legacy','ak','limb','yso','basher','ui','controller'}
local names={'Legacy V2.1','AK','limb.1.2','Yso system','Legacy Basher V2.1','Legacy UI V2.0','Yso Workspace Link'}
local xml='<MudletPackage><ScriptPackage /></MudletPackage>'
for i,id in ipairs(ids) do
 manifest.packages[i]={id=id,name=names[i],file=names[i]..'.xml',required=true,sha256=B.sha256(xml),lua_sha256=B.sha256(''),lua_chunks=0,restart_required=i~=2 and i~=4,hot_reload=i==2 or i==4,depends_on=i>1 and {ids[i-1]} or {}}
 files[workspace..'/Ysindrolir/releases/test-bundle/'..names[i]..'.xml']=xml
 files[workspace..'/Ysindrolir/releases/test-bundle/'..names[i]..'.validated']=#xml..'\n'..xml
end
files[workspace..'/Ysindrolir/releases/current.json']='pointer'
files[workspace..'/Ysindrolir/releases/test-bundle/manifest.json']='manifest'
local manifests={manifest=manifest}
yajl={to_value=function(s) if s=='pointer' then return {directory='test-bundle'} elseif manifests[s] then return manifests[s] elseif s=='installed' then return manifest end error('bad JSON') end,to_string=function() return 'installed' end}
io={open=function(path,mode)
 if mode=='rb' then if files[path]==nil then return nil end;return {read=function() return files[path] end,close=function() return true end} end
 local s='';return {write=function(_,v) s=s..v;return true end,close=function() files[path]=s;return true end}
end}
lfs={mkdir=function() return true end}
getMudletHomeDir=function() return 'C:/profile' end
getProfileName=function() return 'Achaea' end
getConnectionInfo=function() return 'example',23,connected end
cecho=function() end
getModules=function() local t={};for k in pairs(modules) do t[#t+1]=k end;return t end
getPackages=function() local t={};for k in pairs(packages) do t[#t+1]=k end;return t end
getModulePath=function(n) return modules[n] end
tempTimer=function(delay,fn) serial=serial+1;timers[serial]={at=clock+delay,fn=fn};return serial end
killTimer=function(id) timers[id]=nil end
registerAnonymousEventHandler=function(event,fn) serial=serial+1;handlers[serial]={event=event,fn=fn};return serial end
killAnonymousEventHandler=function(id) handlers[id]=nil end
local function fire(event,...)
 local copy={};for id,h in pairs(handlers) do copy[id]=h end
 for _,h in pairs(copy) do if h.event==event then h.fn(event,...) end end
end
local function drain()
 for _=1,200 do local id,at;for k,t in pairs(timers) do if not at or t.at<at then id,at=k,t.at end end
  if not id then return end;clock=at;local fn=timers[id].fn;timers[id]=nil;fn()
 end;error('timer loop')
end
saveProfile=function(dir,name) calls[#calls+1]='backup';files[dir..'/'..name..'.xml']=xml;return true end
uninstallPackage=function(n)
 calls[#calls+1]='remove:'..n;packages[n]=nil
 if n=='Yso Workspace Link' then handlers={} end -- old native script owner disappears
 return true
end
setModulePriority=function() end;disableModuleSync=function() end
local failed,late,mutate
installModule=function(path)
 local name=path:match('([^/]+)%.xml$');calls[#calls+1]='install:'..name
 if name==failed then return false,'fixture_failed' end
 modules[name]=path
 if name=='Yso Workspace Link' then assert(load(controller_body))() end
 if name==late then tempTimer(25,function() fire('sysInstall',name) end) else fire('sysInstall',name) end
 if mutate then files[path]='concurrent save' end
 return true
end
reloadModule=function(name) return installModule(modules[name]) end
Yso=nil;Legacy=nil
local R={root=workspace,handlers={},timers={},generation=1}
YsoWorkspaceLink=R
B.bind(R)
local hot_ok,hot_reason=R.validate_hot_reload({{name='AK',bytes=xml},{name='Yso system',bytes=xml}})
assert(not hot_ok and hot_reason=='coordinated_install_required','unproven legacy peers must require full installation')
connected=true;local ok,why=R.install();assert(not ok and why=='connected');assert(#calls==0)
connected=false;local connection=getConnectionInfo;getConnectionInfo=nil
ok,why=R.install();assert(not ok and why=='connection_state_unknown');assert(#calls==0);getConnectionInfo=connection
local path=workspace..'/Ysindrolir/releases/test-bundle/AK.xml'
files[path]=xml..' ';ok,why=R.install();assert(not ok and why=='hash_mismatch:AK');assert(#calls==0);files[path]=xml
files[workspace..'/Ysindrolir/releases/test-bundle/AK.validated']=#xml..'\n'..xml..'3\nend'
ok,why=R.install();assert(not ok and why=='invalid_receipt:AK');assert(#calls==0)
manifest.packages[2].lua_sha256=B.sha256('3\nend');manifest.packages[2].lua_chunks=1
ok,why=R.install();assert(not ok and why=='invalid_lua:AK');assert(#calls==0)
files[workspace..'/Ysindrolir/releases/test-bundle/AK.validated']=#xml..'\n'..xml
manifest.packages[2].lua_sha256=B.sha256('');manifest.packages[2].lua_chunks=0
-- Cold bootstrap has no Yso globals, but still backs up before installation.
packages['Yso Workspace Link']=true
assert(R.install());assert(R.busy);drain();assert(not R.busy and R.restart_required)
assert(calls[1]=='backup');assert(R.last_result=='installed_restart_required')
local installed_calls={};for _,call in ipairs(calls) do if call:match('^install:') then installed_calls[#installed_calls+1]=call end end
for i,n in ipairs(names) do assert(installed_calls[i]=='install:'..n);assert(modules[n]==home..'/modules/'..n..'.xml') end
assert(Yso.pause.offense.active and Yso.pause.offense.reason=='release_restart_required')
local status=R.release_status();assert(status.restart_required and status.id=='test.1' and #status.packages==7)
-- A controller reimport in this Lua session is not a profile restart.
B.bind(R);assert(R.restart_required)
-- Simulate a fresh Lua state after restart: installed snapshots must all match.
local fresh={root=workspace,handlers={},timers={},generation=1};B.bind(fresh)
YsoWorkspaceLink=fresh
assert(not fresh.restart_required and fresh.release_status().consistent)
files[home..'/modules/AK.xml']='bad';assert(not fresh.release_status().consistent)
files[home..'/modules/AK.xml']=xml
-- Matching a mutable applied snapshot is insufficient: actual bytes must hash
-- to the installed manifest, so profile-side rewrite cannot disguise drift.
files[home..'/modules/AK.xml']='rewritten';files[home..'/modules/AK.applied.xml']='rewritten'
assert(not fresh.release_status().consistent)
files[home..'/modules/AK.xml']=xml;files[home..'/modules/AK.applied.xml']=xml
local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local changed_xml='<MudletPackage><AliasPackage /></MudletPackage>'
local manifest2=copy(manifest);manifest2.release_id='test.2';manifest2.packages[2].sha256=B.sha256(changed_xml)
manifests.manifest2=manifest2
local manifest_path=workspace..'/Ysindrolir/releases/test-bundle/manifest.json'
files[manifest_path]='manifest2'
assert(fresh.validate_hot_reload({{name='AK',bytes=changed_xml},{name='Yso system',bytes=xml}}))
files[home..'/modules/AK.xml']=changed_xml;files[home..'/modules/AK.applied.xml']=changed_xml
assert(fresh.commit_hot_release());assert(fresh.release_status().id=='test.2' and fresh.release_status().consistent)
local manifest3=copy(manifest2);manifest3.release_id='test.3';manifest3.packages[6].sha256=B.sha256(changed_xml)
manifests.manifest3=manifest3;files[manifest_path]='manifest3'
ok,why=fresh.validate_hot_reload({{name='AK',bytes=changed_xml},{name='Yso system',bytes=xml}})
assert(not ok and why=='full_install_required:Legacy UI V2.0')
files[manifest_path]='manifest'
-- Backup failure performs no package removal or module installation.
local original_backup=saveProfile;saveProfile=function() return false,'disk full' end
local before=#calls;ok=fresh.install();if ok then drain() end
assert(fresh.last_result=='failed');assert(#calls==before);saveProfile=original_backup
-- Partial failure stops the batch and never describes a rollback as complete.
failed='AK';before=#calls;assert(fresh.install());drain();assert(fresh.last_result=='failed')
assert(fresh.last_error:find('AK',1,true));for i=before+1,#calls do assert(calls[i]~='install:limb.1.2') end
failed=nil
-- Native install timeout retains quarantine; a late acknowledgement can settle.
late='AK';assert(fresh.install());tempTimer(21,function() assert(fresh.busy and fresh.restart_required);assert(not fresh.install()) end);drain()
assert(fresh.last_result=='installed_restart_required');late=nil
-- Reconnection between jobs prevents subsequent changes; never disconnects it.
before=#calls;assert(fresh.install());tempTimer(0.01,function() connected=true end);drain();connected=false
assert(fresh.last_result=='failed');assert(fresh.last_error=='connected')
-- A restart after a failed first-ever install remains quarantined.
files[home..'/release-installed.json']=nil
files[home..'/release-pending.json']='manifest'
local incomplete={root=workspace,handlers={},timers={},generation=1};B.bind(incomplete)
assert(incomplete.restart_required and not incomplete.release_status().consistent)
-- A reused release label cannot hide a different pending package set.
files[home..'/release-installed.json']='manifest'
local same_id=copy(manifest);same_id.packages[2].sha256=B.sha256('different')
manifests.same_id=same_id;files[home..'/release-pending.json']='same_id'
local mismatched={root=workspace,handlers={},timers={},generation=1};B.bind(mismatched)
assert(mismatched.restart_required)
files[home..'/release-pending.json']='corrupt JSON'
local corrupt={root=workspace,handlers={},timers={},generation=1};B.bind(corrupt)
assert(corrupt.restart_required)
io=original_io
-- Exercise the Lua 5.1-compatible arithmetic path without a bit library.
local saved_load=load;local saved_bit,saved_bit32=bit,bit32
bit=nil;bit32=nil
load=function(s,...) if s:find('a ~ b',1,true) then return nil,'native bits unavailable' end;return saved_load(s,...) end
dofile(root..'/Yso/Integration/release_bundle.lua')
assert(YsoRelease.sha256('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')=='248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1')
load=saved_load;bit=saved_bit;bit32=saved_bit32
print('PASS release bundle: SHA256, offline gating, immutable artifacts, bootstrap, backups, order, restart, mixed releases and failures')
