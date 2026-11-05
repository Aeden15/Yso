local root = arg[1] or 'Ysindrolir/'
local sent, packets, handlers, timers, serial = {}, {}, {}, {}, 0
function send(s) sent[#sent+1]=s end
function sendGMCP(s) packets[#packets+1]=s end
function registerAnonymousEventHandler(event,fn) serial=serial+1; handlers[serial]={event,fn};return serial end
function killAnonymousEventHandler(id) handlers[id]=nil end
function tempTimer(_,fn) serial=serial+1;timers[serial]=fn;return serial end
function killTimer(id) timers[id]=nil end
function tempRegexTrigger() serial=serial+1;return serial end
function tempPromptTrigger() serial=serial+1;return serial end
function killTrigger() end
local function fire(event)
 local snapshot={};for _,row in pairs(handlers) do if row[1]==event then snapshot[#snapshot+1]=row[2] end end
 for _,fn in ipairs(snapshot) do fn(event) end
end
local function count(command) local n=0;for _,s in ipairs(sent) do if s==command then n=n+1 end end;return n end
local function load() dofile(root..'Yso/Integration/session.lua');dofile(root..'Magi/magi_weapons.lua');dofile(root..'Alchemist/Core/formulation.lua') end
Yso={};gmcp={Char={Status={name='Cached',class='Magi'},Vitals={hp='100',maxhp='100'}}}
dofile(root..'Alchemist/Core/formulation.lua');fire('sysConnectionEvent')
assert(#sent==0,'TCP connect must not send phiallist into credential exchange')
load();local S=Yso.session
assert(not S.is_ready(),'cached GMCP on import must not authenticate')
fire('sysConnectionEvent');fire('sysLoadEvent')
assert(#sent==0 and #packets==0,'startup/connect/load must be silent')
gmcp.Char.Status={};gmcp.Char.Vitals={};fire('gmcp.Char.Vitals');fire('gmcp.Char.Status')
assert(not S.is_ready() and #sent==0,'incomplete fresh data must not authenticate')
gmcp.Char.Status={name='Tester',class='Magi'};fire('gmcp.Char.Status')
assert(S.is_ready() and count('eq')==1 and count('phiallist')==1 and #packets==1,'fresh status starts each discovery once')
fire('gmcp.Char.Status');fire('gmcp.Char.Vitals')
S.later('regression',0,function() send('stale callback') end)
local callbacks={};for _,fn in pairs(timers) do callbacks[#callbacks+1]=fn end
fire('sysDisconnectionEvent');for _,fn in ipairs(callbacks) do fn() end
assert(count('stale callback')==0 and not S.is_ready(),'stale callbacks cannot cross sessions')
local before=#sent
for _=1,3 do load() end
assert(#sent==before and not S.is_ready(),'reload at login never trusts cached GMCP')
fire('sysConnectionEvent');gmcp.Char.Vitals={hp='50',maxhp='100'};fire('gmcp.Char.Vitals')
assert(count('eq')==2 and count('phiallist')==2,'fresh vitals reconnect discovers exactly once')
S.later('reload',0,function() send('old reload callback') end)
callbacks={};for _,fn in pairs(timers) do callbacks[#callbacks+1]=fn end
for _=1,3 do load() end
for _,fn in ipairs(callbacks) do fn() end
fire('gmcp.Char.Status')
assert(count('old reload callback')==0 and count('eq')==2 and count('phiallist')==2,'reload cancels stale callbacks without repeating queries')
local counts={};for _,row in pairs(handlers) do counts[row[1]]=(counts[row[1]] or 0)+1 end
assert(counts.sysConnectionEvent==1 and counts.sysDisconnectionEvent==1,'shared service owns connection handlers')
send('username');send('password')
assert(sent[#sent]=='password' and sent[#sent-1]=='username','raw credential sends remain untouched')
print('PASS: shared login session, deferred discovery, reconnect, reload, handler and timer isolation')
