-- Native package library; loaded before the independent workspace controller.
-- It reads release data, never loads executable Lua from filesystem paths.
YsoRelease=YsoRelease or {}
local B=YsoRelease
B.version=1
local MOD=4294967296
local native=bit32 or bit
local xor,band,rshift,ror
if native and native.bxor and native.band and native.rshift then
 xor=function(a,b) return native.bxor(a,b)%MOD end
 band=function(a,b) return native.band(a,b)%MOD end
 rshift=function(a,n) return native.rshift(a,n)%MOD end
 ror=function(a,n) return (rshift(a,n)+(a%2^n)*2^(32-n))%MOD end
else
 local compiler=loadstring or load
 local ok,chunk=pcall(compiler,'return function(a,b) return (a ~ b) & 0xffffffff end, function(a,b) return a & b end, function(a,n) return a >> n end')
 if ok and chunk then xor,band,rshift=chunk() end
 if not xor then
  local small={};for a=0,15 do small[a]={};for b=0,15 do
   local aa,bb,v,p=a,b,0,1;for _=1,4 do if aa%2~=bb%2 then v=v+p end;aa=math.floor(aa/2);bb=math.floor(bb/2);p=p*2 end;small[a][b]=v
  end end
  xor=function(a,b) local v,p=0,1;for _=1,8 do v=v+small[a%16][b%16]*p;a=math.floor(a/16);b=math.floor(b/16);p=p*16 end;return v end
  band=function(a,b) return (a+b-xor(a,b))/2 end
  rshift=function(a,n) return math.floor(a/2^n) end
 end
 ror=function(a,n) return (rshift(a,n)+(a%2^n)*2^(32-n))%MOD end
end
local K={1116352408,1899447441,3049323471,3921009573,961987163,1508970993,2453635748,2870763221,
3624381080,310598401,607225278,1426881987,1925078388,2162078206,2614888103,3248222580,
3835390401,4022224774,264347078,604807628,770255983,1249150122,1555081692,1996064986,
2554220882,2821834349,2952996808,3210313671,3336571891,3584528711,113926993,338241895,
666307205,773529912,1294757372,1396182291,1695183700,1986661051,2177026350,2456956037,
2730485921,2820302411,3259730800,3345764771,3516065817,3600352804,4094571909,275423344,
430227734,506948616,659060556,883997877,958139571,1322822218,1537002063,1747873779,
1955562222,2024104815,2227730452,2361852424,2428436474,2756734187,3204031479,3329325298}
local function word(n) return string.char(rshift(n,24)%256,rshift(n,16)%256,rshift(n,8)%256,n%256) end
function B.sha256(s)
 local length=#s
 s=s..'\128'..string.rep('\0',(55-length)%64)..word(math.floor(length/536870912))..word((length*8)%MOD)
 local H={1779033703,3144134277,1013904242,2773480762,1359893119,2600822924,528734635,1541459225}
 for at=1,#s,64 do
  local w={};for j=0,15 do local a,b,c,d=s:byte(at+j*4,at+j*4+3);w[j+1]=((a*256+b)*256+c)*256+d end
  for j=17,64 do local a,b=w[j-15],w[j-2]
   local sa=xor(xor(ror(a,7),ror(a,18)),rshift(a,3));local sb=xor(xor(ror(b,17),ror(b,19)),rshift(b,10))
   w[j]=(w[j-16]+sa+w[j-7]+sb)%MOD
  end
  local a,b,c,d,e,f,g,h=H[1],H[2],H[3],H[4],H[5],H[6],H[7],H[8]
  for j=1,64 do
   local s1=xor(xor(ror(e,6),ror(e,11)),ror(e,25));local ch=xor(band(e,f),band(MOD-1-e,g))
   local t1=(h+s1+ch+K[j]+w[j])%MOD
   local s0=xor(xor(ror(a,2),ror(a,13)),ror(a,22));local maj=xor(xor(band(a,b),band(a,c)),band(b,c))
   h=g;g=f;f=e;e=(d+t1)%MOD;d=c;c=b;b=a;a=(t1+s0+maj)%MOD
  end
  local v={a,b,c,d,e,f,g,h};for j=1,8 do H[j]=(H[j]+v[j])%MOD end
 end
 local result={};for j=1,8 do result[j]=string.format('%08x',H[j]) end;return table.concat(result)
end
local expected={
 {'legacy','Legacy V2.1'},{'ak','AK'},{'limb','limb.1.2'},{'yso','Yso system'},
 {'basher','Legacy Basher V2.1'},{'ui','Legacy UI V2.0'},{'controller','Yso Workspace Link'},
}
local function read(path)
 local f=io.open(path,'rb');if not f then return nil end;local s=f:read('*a');f:close();return s
end
local function write(path,s)
 local f,why=io.open(path,'wb');if not f then return false,why end
 local ok,e=f:write(s);local closed,ce=f:close();if not ok or not closed then return false,e or ce or 'write_failed' end;return true
end
local function decode(s)
 if type(s)~='string' or not (yajl and type(yajl.to_value)=='function') then return nil end
 local ok,v=pcall(yajl.to_value,s);if ok and type(v)=='table' then return v end
end
local function encode(v)
 if not (yajl and type(yajl.to_string)=='function') then return nil end
 local ok,s=pcall(yajl.to_string,v);if ok and type(s)=='string' then return s end
end
local function contains(t,n)
 if type(t)~='table' then return false end;if t[n] then return true end
 for _,v in ipairs(t) do if v==n then return true end end;return false
end
local function valid_xml(s) return type(s)=='string' and s:find('<MudletPackage[%s>]') and s:match('</MudletPackage>%s*$')~=nil end
local function validate_manifest(m)
 if type(m)~='table' or m.schema_version~=1 or type(m.release_id)~='string' or not m.release_id:match('^[%w._-]+$') or type(m.packages)~='table' or #m.packages~=#expected then return false,'invalid_release_manifest' end
 local seen={}
 for i,spec in ipairs(expected) do local p=m.packages[i]
  if type(p)~='table' or p.id~=spec[1] or p.name~=spec[2] or p.file~=spec[2]..'.xml' or p.required~=true
   or type(p.sha256)~='string' or #p.sha256~=64 or not p.sha256:match('^[a-fA-F0-9]+$')
   or type(p.lua_sha256)~='string' or #p.lua_sha256~=64 or not p.lua_sha256:match('^[a-fA-F0-9]+$')
   or type(p.lua_chunks)~='number' or p.lua_chunks<0 or p.lua_chunks%1~=0
   or type(p.depends_on)~='table' then return false,'invalid_release_package:'..spec[1] end
  for _,dependency in ipairs(p.depends_on) do if not seen[dependency] then return false,'dependency_order:'..p.id end end
  seen[p.id]=true
 end
 return true
end
local function current(R)
 local base=R.root..'/Ysindrolir/releases'
 local pointer=decode(read(base..'/current.json'))
 if not pointer or type(pointer.directory)~='string' or not pointer.directory:match('^[%w_-][%w._-]*$') or pointer.directory:find('..',1,true) then return nil,'release_not_published' end
 local dir=base..'/'..pointer.directory
 local text=read(dir..'/manifest.json');local m=decode(text)
 local ok,why=validate_manifest(m);if not ok then return nil,why end
 return m,dir,text
end
local function metadata(bytes,receipt,name,spec)
 if type(receipt)~='string' then return false,'unpublished_xml:'..name end
 local ending=receipt:find('\n',1,true);if not ending then return false,'invalid_receipt:'..name end
 local n=tonumber(receipt:sub(1,ending-1));if n~=#bytes or receipt:sub(ending+1,ending+n)~=bytes then return false,'invalid_receipt:'..name end
 local pos=ending+n+1;local compiler=loadstring or load;local count=0
 if B.sha256(receipt:sub(pos))~=spec.lua_sha256:lower() then return false,'invalid_receipt:'..name end
 while pos<=#receipt do
  ending=receipt:find('\n',pos,true);if not ending then return false,'invalid_receipt:'..name end
  local digits=receipt:sub(pos,ending-1);if not digits:match('^%d+$') then return false,'invalid_receipt:'..name end
  n=tonumber(digits);if n>#receipt-ending then return false,'invalid_receipt:'..name end
  if not compiler(receipt:sub(ending+1,ending+n),name..':release preflight') then return false,'invalid_lua:'..name end
  count=count+1
  pos=ending+n+1
 end
 if count~=spec.lua_chunks then return false,'invalid_receipt:'..name end
 return true
end
local function connection()
 if type(getConnectionInfo)~='function' then return nil end
 local ok,_,_,connected=pcall(getConnectionInfo)
 if ok and type(connected)=='boolean' then return connected end
end
local digest_cache={}
local function digest(path,bytes)
 if not bytes then return nil end
 local cached=digest_cache[path]
 if not cached or cached.bytes~=bytes then cached={bytes=bytes,sha256=B.sha256(bytes)};digest_cache[path]=cached end
 return cached.sha256
end
function B.bind(R)
 local function home() return getMudletHomeDir():gsub('\\','/'):gsub('/+$','')..'/yso-workspace' end
 local function say(s) if type(cecho)=='function' then cecho('<steel_blue>[Yso release] <reset>'..s..'\n') end end
 local function hold(reason)
  Yso=Yso or {};Yso.pause=Yso.pause or {};Yso.pause.offense=Yso.pause.offense or {}
  Yso.pause.offense.active=true;Yso.pause.offense.reason=reason
  local M=Yso.mode
  if M and type(M.start_route_loop)=='function' and M.start_route_loop~=R.release_guard then
   local original=M.start_route_loop;R.release_guard=function(...)
    if R.busy or R.restart_required then return false,'release_restart_required' end;return original(...)
   end;M.start_route_loop=R.release_guard
  end
 end
 local function later(key,delay,fn)
  local id=R.timers[key];if id and type(killTimer)=='function' then killTimer(id) end
  local generation=R.generation
  R.timers[key]=tempTimer(delay,function() if generation~=R.generation then return end;R.timers[key]=nil;fn() end)
 end
 local function fail(why)
  for _,key in ipairs({'bundle_operation','bundle_timeout'}) do if R.timers[key] and type(killTimer)=='function' then killTimer(R.timers[key]) end;R.timers[key]=nil end
  local job=R.bundle_current
  if job and job.previous then write(home()..'/modules/'..job.name..'.xml',job.previous) end
  R.busy=false;R.bundle_current=nil;R.last_result='failed';R.last_error=tostring(why);R.restart_required=true
  hold('release_restart_required')
  say('Installation stopped: '..R.last_error..'. A partial update is possible. Restart only after recovery; automation remains blocked.')
  if R.backup_path then say('Profile backup: '..R.backup_path) end
 end
 function R.release_status()
  local m,why=current(R)
  local installed=decode(read(home()..'/release-installed.json'))
  local rows,consistent={},installed~=nil
  if installed then local valid=validate_manifest(installed);consistent=valid end
  if installed and consistent then
   for _,p in ipairs(installed.packages) do
    local path=home()..'/modules/'..p.name..'.xml'
    local present=type(getModules)=='function' and contains(getModules(),p.name)
    local managed=present and type(getModulePath)=='function' and tostring(getModulePath(p.name) or ''):gsub('\\','/')==path
    local bytes=read(path)
    local exact=bytes~=nil and bytes==read(home()..'/modules/'..p.name..'.applied.xml')
    local expected_hash=digest(path,bytes)==p.sha256:lower()
    local okay=managed and exact and expected_hash
    rows[#rows+1]={id=p.id,name=p.name,sha256=p.sha256,installed=present,consistent=okay}
    consistent=consistent and okay
   end
  end
  local conflicts={}
  for _,n in ipairs({'stormhammer aliases','stormhammer script','Target things'}) do
   if (type(getPackages)=='function' and contains(getPackages(),n)) or (type(getModules)=='function' and contains(getModules(),n)) then conflicts[#conflicts+1]=n end
  end
  return {id=installed and installed.release_id or nil,available_id=m and m.release_id or nil,
   available=m~=nil,reason=not m and why or nil,consistent=consistent,packages=rows,conflicts=conflicts,
   restart_required=R.restart_required==true}
 end
 function R.validate_hot_reload(jobs)
  local installed=decode(read(home()..'/release-installed.json'))
  if not installed then return false,'coordinated_install_required' end
  if R.restart_required or not R.release_status().consistent then return false,'release_restart_required' end
  local m,why,text=current(R);if not m then return false,why end
  local submitted={};for _,job in ipairs(jobs) do submitted[job.name]=job.bytes end
  for i,p in ipairs(installed.packages) do
   local next=m.packages[i]
   if p.id=='ak' or p.id=='yso' then
    if not submitted[p.name] or B.sha256(submitted[p.name])~=next.sha256:lower() then return false,'release_not_published:'..p.name end
   elseif p.sha256:lower()~=next.sha256:lower() then return false,'full_install_required:'..p.name end
  end
  R.pending_hot_manifest=m;R.pending_hot_text=text
  return true
 end
 function R.commit_hot_release()
  if not R.pending_hot_manifest then return true end
  for _,p in ipairs(R.pending_hot_manifest.packages) do
   local path=home()..'/modules/'..p.name..'.xml'
   local bytes=read(path)
   if digest(path,bytes)~=p.sha256:lower() or bytes~=read(home()..'/modules/'..p.name..'.applied.xml') then return false,'release_snapshot_mismatch:'..p.name end
  end
  local okay,why=write(home()..'/release-installed.json',R.pending_hot_text)
  if not okay then return false,'installed_manifest:'..tostring(why) end
  R.pending_hot_manifest=nil;R.pending_hot_text=nil;return true
 end
 local function offline()
  if type(getProfileName)~='function' or getProfileName()~='Achaea' then return false,'wrong_profile' end
  local connected=connection();if connected==nil then return false,'connection_state_unknown' end
  if connected then return false,'connected' end
  return true
 end
 local function preflight()
  local ok,why=offline();if not ok then return nil,why end
  if Yso and type(Yso.mode)=='table' and type(R.idle)=='function' then
   local idle,reason=R.idle();if not idle then return nil,reason end
  end
  if Legacy and Legacy.Settings and Legacy.Settings.Basher and Legacy.Settings.Basher.status==true then return nil,'automation_active' end
  for _,name in ipairs({'getPackages','getModules','getModulePath','installModule','reloadModule','uninstallPackage','setModulePriority','disableModuleSync','saveProfile','registerAnonymousEventHandler','tempTimer'}) do
   if type(_G[name])~='function' then return nil,'missing_api:'..name end
  end
  if not (lfs and type(lfs.mkdir)=='function') then return nil,'filesystem_api_unavailable' end
  local m,dir,text=current(R);if not m then return nil,dir end
  if not encode(m) then return nil,'serialization_unavailable' end
  local jobs={}
  for i,p in ipairs(m.packages) do
   local bytes=read(dir..'/'..p.file)
   if not valid_xml(bytes) then return nil,'invalid_xml:'..p.name end
   if B.sha256(bytes)~=p.sha256:lower() then return nil,'hash_mismatch:'..p.name end
   local valid,reason=metadata(bytes,read(dir..'/'..p.name..'.validated'),p.name,p);if not valid then return nil,reason end
   local mod=contains(getModules(),p.name);local pkg=contains(getPackages(),p.name)
   if mod and pkg then return nil,'ambiguous_install:'..p.name end
   local path=home()..'/modules/'..p.name..'.xml'
   if mod and tostring(getModulePath(p.name) or ''):gsub('\\','/')~=path then return nil,'unmanaged_module:'..p.name end
   jobs[i]={id=p.id,name=p.name,bytes=bytes,sha256=p.sha256:lower(),was_module=mod,was_package=pkg,previous=read(path),priority=i-1}
  end
  return {jobs=jobs,manifest=m,text=text}
 end
 local next_job
 local function finish(job)
  if not R.busy or R.bundle_current~=job or not job.ack then return end
  local ok,why=offline();if not ok then fail(why);return end
  local path=home()..'/modules/'..job.name..'.xml'
  if tostring(getModulePath(job.name) or ''):gsub('\\','/')~=path or read(path)~=job.bytes then fail('module_input_changed:'..job.name);return end
  local configured,err=pcall(function() setModulePriority(job.name,job.priority);disableModuleSync(job.name) end)
  if not configured then fail('module_configuration:'..tostring(err));return end
  local saved,e=write(home()..'/modules/'..job.name..'.applied.xml',job.bytes);if not saved then fail('snapshot:'..tostring(e));return end
  saved,e=write(home()..'/modules/'..job.name..'.sha256',job.sha256);if not saved then fail('snapshot_hash:'..tostring(e));return end
  if R.timers.bundle_timeout and type(killTimer)=='function' then killTimer(R.timers.bundle_timeout) end;R.timers.bundle_timeout=nil
  R.bundle_current=nil;later('bundle_operation',0.1,next_job)
 end
 next_job=function()
  if not R.busy then return end
  local okay,reason=offline();if not okay then fail(reason);return end
  R.bundle_index=R.bundle_index+1;local job=R.bundle_jobs[R.bundle_index]
  if not job then
   local saved,e=write(home()..'/release-installed.json',R.bundle_manifest_text)
   if not saved then fail('installed_manifest:'..tostring(e));return end
   R.busy=false;R.bundle_current=nil;R.last_result='installed_restart_required';R.last_error=nil
   hold('release_restart_required');say('Coordinated release installed. Restart this profile before connecting or resuming automation.');return
  end
  R.bundle_current=job;hold('release_restart_required')
  local okay,e=write(home()..'/modules/'..job.name..'.xml',job.bytes);if not okay then fail('stage:'..tostring(e));return end
  later('bundle_timeout',20,function() R.last_result='waiting';R.last_error='waiting_for_native_module:'..job.name;say('Waiting for '..job.name..'. Updates and automation remain blocked; restart only after recovery.') end)
  local called,result,err=pcall(function()
   if job.was_package then uninstallPackage(job.name);if contains(getPackages(),job.name) then return false,'package_removal_failed' end end
   if job.was_module then return reloadModule(job.name) end
   return installModule(home()..'/modules/'..job.name..'.xml')
  end)
  if not called or result==false or (result==nil and err~=nil) then fail(job.name..':'..tostring(called and err or result)) end
 end
 function R.install()
  if R.busy then return false,'busy' end
  local bundle,why=preflight();if not bundle then say('Installation held: '..tostring(why));return false,why end
  for _,dir in ipairs({home(),home()..'/modules',home()..'/backups'}) do local ok,e=lfs.mkdir(dir);if not ok and not (lfs.attributes and lfs.attributes(dir,'mode')=='directory') then
   -- mkdir may return nil for an existing directory. A file read is not a valid substitute.
   if type(lfs.attributes)=='function' then return false,'directory_unavailable:'..tostring(e) end
  end end
  R.sequence=(R.sequence or 0)+1;local filename='before-release-'..os.time()..'-'..R.sequence
  R.bundle_backup_dir=home()..'/backups/'..filename
  local made,e=lfs.mkdir(R.bundle_backup_dir);if not made and type(lfs.attributes)=='function' and lfs.attributes(R.bundle_backup_dir,'mode')~='directory' then return false,'backup_directory:'..tostring(e) end
  R.backup_path=R.bundle_backup_dir..'/profile.xml'
  R.busy=true;R.action='install';R.restart_required=true;R.bundle_jobs=bundle.jobs;R.bundle_index=0
  R.bundle_manifest_text=bundle.text;R.last_error=nil;hold('release_restart_required')
  local ok,result,err=pcall(saveProfile,R.bundle_backup_dir,'profile')
  if not ok or result==false or (result==nil and err~=nil) then fail('profile_backup_failed');return false,'profile_backup_failed' end
  local attempts=0
  local function await_backup()
   if not R.busy then return end
   local valid,why=offline();if not valid then fail(why);return end
   attempts=attempts+1
   if valid_xml(read(R.backup_path)) then
    -- Complete all managed-file backups before replacing the first package.
    for _,job in ipairs(R.bundle_jobs) do
     if job.previous then
      local saved,e=write(R.bundle_backup_dir..'/'..job.name..'.xml',job.previous)
      if not saved or read(R.bundle_backup_dir..'/'..job.name..'.xml')~=job.previous then fail('managed_backup:'..tostring(e or job.name));return end
     end
    end
    local saved,e=write(home()..'/release-pending.json',R.bundle_manifest_text)
    if not saved then fail('pending_manifest:'..tostring(e));return end
    later('bundle_operation',0.1,next_job)
   elseif attempts>=50 then fail('profile_backup_timeout') else later('bundle_operation',0.2,await_backup) end
  end
  later('bundle_operation',0.1,await_backup);return true
 end
 function R.check_release() local bundle,why=preflight();return bundle~=nil,why end
 -- Self-updates remove the old native owner's handlers. Re-arm this callback
 -- from the replacement controller while its operation state is still live.
 if type(registerAnonymousEventHandler)=='function' then
  if R.handlers.bundle_install and type(killAnonymousEventHandler)=='function' then pcall(killAnonymousEventHandler,R.handlers.bundle_install) end
  R.handlers.bundle_install=registerAnonymousEventHandler('sysInstall',function(_,name,errors)
   local job=R.bundle_current;if not (R.busy and R.action=='install' and job and job.name==name) then return end
   hold('release_restart_required')
   if type(errors)=='string' and errors~='' then fail(name..':'..errors);return end
   job.ack=true;later('bundle_operation',0.1,function() finish(job) end)
  end)
 end
 if R.restart_required==nil then
  local installed_text=read(home()..'/release-installed.json')
  local pending_text=read(home()..'/release-pending.json')
  local installed=decode(installed_text)
  local pending=decode(pending_text)
  local consistent=R.release_status().consistent
  R.restart_required=(pending~=nil or installed~=nil) and not consistent or false
  if (installed_text and installed_text~='' and not installed) or (pending_text and pending_text~='' and not pending) then R.restart_required=true end
  if pending then
   local valid=validate_manifest(pending)
   local installed_valid=installed and validate_manifest(installed)
   if not valid or not installed_valid or pending.release_id~=installed.release_id then R.restart_required=true
   elseif #pending.packages~=#installed.packages then R.restart_required=true
   else
    for i,p in ipairs(pending.packages) do
     local other=installed.packages[i]
     if p.id~=other.id or p.sha256:lower()~=other.sha256:lower() then R.restart_required=true end
    end
   end
  end
  if pending and not R.restart_required then
   local saved=write(home()..'/release-pending.json','')
   if not saved then R.restart_required=true end
  end
 end
 if R.restart_required then hold('release_restart_required') end
 return R
end
return B
