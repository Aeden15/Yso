-- Exercise the real packaged AK gain/cure implementations. Only Mudlet UI,
-- timers, and unrelated AK side effects are stubbed; affliction mutations and
-- cure-bucket contents come from AK.xml, queried through Yso's live adapter.
local source=debug.getinfo(1,'S').source:gsub('^@','')
local root=(source:match('^(.*)[/\\][^/\\]+$') or '.')..'/../..'
local function read(path)
  local f=assert(io.open(path,'rb'));local body=f:read('*a');f:close();return body
end
local xml=read(root..'/mudlet packages/AK.xml')
local function unescape(s)
  return (s:gsub('&lt;','<'):gsub('&gt;','>'):gsub('&quot;','"'):gsub('&apos;',"'"):gsub('&amp;','&'))
end
local function ak_script(name)
  local start=assert(xml:find('<name>'..name..'</name>',1,true),'Missing AK script '..name)
  local body=assert(xml:find('<script>',start,true))+#'<script>'
  return unescape(xml:sub(body,assert(xml:find('</script>',body,true))-1))
end
local env=setmetatable({},{__index=_G})
env._G=env
local function run(body,name)
  if _VERSION=='Lua 5.1' then
    local fn=assert(loadstring(body,name));setfenv(fn,env);return fn()
  end
  return assert(load(body,name,'t',env))()
end
local function noop() end
string.title=string.title or function(s) return (s:gsub('^%l',string.upper)) end
table.contains=table.contains or function(t,value)
  for _,item in ipairs(t) do if item==value then return true end end;return false
end
env.target='Aegoth'
env.IsTargetted=function(name) return name:lower()==env.target:lower() end
local events={}
env.raiseEvent=function(name,...) events[#events+1]={name,...} end
env.cecho=noop
env.ak={defs={},cure={},occie={aura={mental=0,physical=0,parsereduct=noop}},
  AddedAffReset=noop,scoreup=noop,echogain=noop,echolost=noop,
  handlePyramides=noop,ResetConfirmAff=noop,echoForPossibleCures=noop,AfflictionCured=noop,
  errorallowance=1,eatsbetweenaffs=0,randomaffs=0}
local buckets={}
for _,item in ipairs{'plumbum flake','goldenseal root'} do
  local literal=assert(xml:match('%["'..item..'"%]%s*=%s*({[^}]+})'),'Missing real AK '..item..' bucket')
  buckets[item]=run('return '..unescape(literal),'AK '..item..' bucket')
end
local scores={anorexia=0,deaf=0}
for _,bucket in pairs(buckets) do for _,aff in ipairs(bucket) do scores[aff]=0 end end
env.affstrack={score=scores,eaten=buckets,venoms={},mentallist={},physicallist={}}
env.ocured={conversion={['plumbum flake']='goldenseal',['goldenseal root']='goldenseal'}}
run(ak_script('oscore edit functions'),'AK gain/loss functions')
run(ak_script('oeaten'),'AK actual herb cure implementation')
env.Yso={get_target=function() return env.target end}
run(read(root..'/Yso/Integration/ak_legacy_wiring.lua'),'Yso live AK adapter')
local M=run(read(arg[1] or root..'/Monk/shikudo_duel.lua'),'Shikudo controller')
assert(not env.Yso.ak.has('impatience'))
assert(M.note_impatience_success('Aegoth'))
assert(scores.impatience==100 and env.Yso.ak.has('impatience'),'Actual success must populate AK live score')
assert(events[1][1]=='AK got aff','Use actual AK gain event')
local count=#events
assert(M.note_impatience_success('Aegoth') and #events==count,'Repeated recognition is idempotent')
env.ak.cure.ate('plumbum flake',false)
assert(scores.impatience==0 and not env.Yso.ak.has('impatience'),'Actual plumbum cure must remove impatience')
assert(not M.note_impatience_success('Someoneelse') and scores.impatience==0,'Wrong recipient must not populate current target')
env.IsTargetted=function() return false end
assert(not M.note_impatience_success('Aegoth') and scores.impatience==0,'Untracked target must not mutate AK')
env.IsTargetted=function(name) return name:lower()==env.target:lower() end
assert(M.note_impatience_success('Aegoth'))
env.ak.cure.ate('goldenseal root',false)
assert(not env.Yso.ak.has('impatience'),'Actual goldenseal cure must also clear confirmed success')
env.OppGainedAff=nil
assert(not M.note_impatience_success('Aegoth'),'Missing AK backend must not create a local sticky affliction')
print('PASS Shikudo Impatience actual AK success, duplicate, target guards, plumbum/goldenseal cure')
