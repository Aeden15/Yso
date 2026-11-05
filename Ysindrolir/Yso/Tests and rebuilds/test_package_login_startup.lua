-- Execute every active embedded Script; no aliases or text triggers are invoked.
local scripts={}
for row in io.lines(assert(arg[1])) do local path,name=row:match('^(.-)|(.+)$');scripts[#scripts+1]={path,name} end
local sent, handlers, timers, serial = {}, {}, {}, 0
function send(s) sent[#sent+1]=s end
function sendAll(...) for _,s in ipairs({...}) do send(s) end end
function sendGMCP(s) send('GMCP:'..s) end
function registerAnonymousEventHandler(event,fn) serial=serial+1;handlers[serial]={event,fn};return serial end
function killAnonymousEventHandler(id) handlers[id]=nil end
function tempTimer(_,fn) serial=serial+1;timers[serial]=fn;return serial end
function killTimer(id) timers[id]=nil end
local function id() serial=serial+1;return serial end
for _,name in ipairs({'tempRegexTrigger','tempPromptTrigger','tempAlias','tempExactMatchTrigger'}) do _G[name]=id end
for _,name in ipairs({'killTrigger','killAlias','echo','cecho','decho','hecho','setFgColor','setBgColor','resetFormat','enableTrigger','disableTrigger','enableAlias','disableAlias','addFileWatch','removeFileWatch'}) do _G[name]=function() end end
function getMudletHomeDir() return '.' end
function getProfileName() return 'Login regression' end
function getEpoch() return 1000 end
function getNetworkLatency() return 0 end
function raiseEvent() end
function getTime() return 0 end
function isPrompt() return false end
Yso={};Legacy={};gmcp={Char={Status={name='Cached',class='Magi'},Vitals={hp='100',maxhp='100'},Items={}},Room={Info={}}}
local function fire(event)
 local snapshot={};for _,row in pairs(handlers) do if row[1]==event then snapshot[#snapshot+1]=row[2] end end
 for _,fn in ipairs(snapshot) do if type(fn)=='function' then fn(event) end end
end
for pass=1,3 do
 for _,entry in ipairs(scripts) do
  local ok,err=pcall(dofile,entry[1]);assert(ok,'startup '..entry[2]..': '..tostring(err))
 end
 fire('sysLoadEvent');fire('sysConnectionEvent');fire('sysPrompt')
 local snapshot={};for _,fn in pairs(timers) do snapshot[#snapshot+1]=fn end
 for _,fn in ipairs(snapshot) do if type(fn)=='function' then fn() end end
 assert(#sent==0,'package startup/reload/connection emitted before login: '..table.concat(sent,', '))
 fire('sysDisconnectionEvent')
end
gmcp.Char.Status={name='Tester',class='Magi'};fire('gmcp.Char.Status')
assert(Yso.session.is_ready(),'fresh status must release package startup queries')
local queries={};for _,command in ipairs(sent) do queries[command]=(queries[command] or 0)+1 end
assert(queries.eq==1 and queries.phiallist==nil and Yso.features.alchemist_offense==false,'package must discover Magi equipment but keep Alchemist suspended')
local before=#sent
for pass=1,3 do for _,entry in ipairs(scripts) do
 local ok,err=pcall(dofile,entry[1]);assert(ok,'authenticated reload '..entry[2]..': '..tostring(err))
end end
assert(#sent==before,'authenticated package reload must not repeat startup queries')
fire('sysDisconnectionEvent');fire('sysPrompt')
local snapshot={};for _,fn in pairs(timers) do snapshot[#snapshot+1]=fn end
for _,fn in ipairs(snapshot) do if type(fn)=='function' then fn() end end
assert(#sent==before,'disconnect prompt and timer callbacks must remain silent')
print('PASS: all '..#scripts..' active embedded scripts remain silent through startup, connection, timers and three reloads')
