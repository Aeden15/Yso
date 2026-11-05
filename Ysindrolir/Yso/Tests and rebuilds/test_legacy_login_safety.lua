local root=arg[1] or 'Ysindrolir/'
local sent,timers,handlers,serial={},{},{},0
local loads=0
local clock,delays=100,{}
function getEpoch() return clock end
function send(s) sent[#sent+1]=s end
function sendAll(...) for _,s in ipairs({...}) do send(s) end end
function sendGMCP(s) sent[#sent+1]='GMCP:'..s end
function tempTimer(delay,fn) serial=serial+1;timers[serial]=fn;delays[serial]=delay;return serial end
function killTimer(id) timers[id]=nil end
function registerAnonymousEventHandler(event,fn) serial=serial+1;handlers[serial]={event,fn};return serial end
function killAnonymousEventHandler(id) handlers[id]=nil end
function enableTimer() end
function disableTrigger() end
function Defup() end
function Legacy_Downloads() end
function cecho() end
function getMudletHomeDir() return '.' end
function io.exists() return true end
function table.load() loads=loads+1 end
lfs={mkdir=function() end}
function Legacy_EnsureState() end
Yso={};Legacy={};gmcp={Char={Status={name='Cached',class='Magi'},Vitals={hp='100',maxhp='100'}},Room={}}
local function fire(event)
 local snapshot={};for _,row in pairs(handlers) do if row[1]==event then snapshot[#snapshot+1]=row[2] end end
 for _,fn in ipairs(snapshot) do if type(fn)=='string' then assert(load('return '..fn))()(event) else fn(event) end end
end
function raiseEvent(event) fire(event) end
local function run(fn) if type(fn)=='string' then assert(load(fn))() else fn() end end
local function login() dofile(root..'Yso/Integration/legacy_login.lua') end
dofile(root..'Yso/Integration/legacy_load.lua')
login();fire('LoggedIn');dofile(root..'Yso/Integration/legacy_check_for_updates.lua')
assert(#sent==0,'missing service must keep Legacy login, loader and update keepalive silent')
dofile(root..'Yso/Integration/session.lua');fire('sysConnectionEvent');login()
assert(#sent==0,'cached status and login trigger must defer until fresh authentication')
gmcp.Char.Status={name='Tester',class='Magi'};fire('gmcp.Char.Status')
assert(#sent>0,'fresh authentication releases deferred Legacy startup')
local old={};for _,fn in pairs(timers) do old[#old+1]=fn end
local before=#sent
fire('sysDisconnectionEvent');fire('sysConnectionEvent')
for _,fn in ipairs(old) do run(fn) end
assert(#sent==before,'old Legacy login timers cannot send or raise LoggedIn across reconnect')
login();fire('gmcp.Char.Status')
old={};for _,fn in pairs(timers) do old[#old+1]=fn end
before=#sent
clock=clock+2
dofile(root..'Yso/Integration/session.lua');dofile(root..'Yso/Integration/legacy_load.lua')
assert(delays[Yso.session.timers['legacy.login.loaded']]==2 and delays[Yso.session.timers['legacy.login.curing']]==6,'durable completions preserve their remaining delays')
for _,fn in ipairs(old) do run(fn) end
assert(#sent==before,'service reload invalidates old Legacy login callbacks')
local pending={};for _,fn in pairs(timers) do pending[#pending+1]=fn end
for _,fn in ipairs(pending) do run(fn) end
for _,fn in ipairs(pending) do run(fn) end
local restored=0;for _,command in ipairs(sent) do if command=='queue add freestand curing on' then restored=restored+1 end end
assert(restored==1 and loads==1,'same-session reload must complete curing restore and LoggedIn settings load exactly once')
local n=0;for _,row in pairs(handlers) do if row[1]=='LoggedIn' then n=n+1 end end
assert(n==1,'Legacy LoggedIn registration remains unique on reload')
print('PASS: Legacy missing service, deferred login, stale reconnect/reload timers and unique LoggedIn handler')
