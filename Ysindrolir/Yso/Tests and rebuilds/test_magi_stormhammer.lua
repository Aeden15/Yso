-- Run from workspace root: lua "Ysindrolir/Yso/Tests and rebuilds/test_magi_stormhammer.lua"
local root = 'Ysindrolir/'
local sent, notes, gmcp_sent, handlers, triggers = {}, {}, {}, {}, {}
function send(s) sent[#sent+1]=s end
function sendAll(...) for _,s in ipairs({...}) do if type(s)=='string' then send(s) end end end
function cecho(s) notes[#notes+1]=s end
echo=cecho
function sendGMCP(s) gmcp_sent[#gmcp_sent+1]=s end
function registerAnonymousEventHandler(e,fn) handlers[e]=fn; return e end
function killAnonymousEventHandler(e) handlers[e]=nil end
function tempRegexTrigger(pattern,fn) triggers[pattern]=fn; return pattern end
function tempPromptTrigger(fn) triggers.prompt=fn; return 'prompt' end
function killTrigger(id) triggers[id]=nil end
function tempTimer(_,fn) return fn end
function killTimer() end
local function eq(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function item(id,name,attrib) return {id=tostring(id),name=name,attrib=attrib or ''} end
Yso={magi={},targeting={state={locked=false}}}
local locked=false
function Yso.set_target(name,source)
  if locked then return false,'locked' end
  target=name; Yso.target=name; return true
end
function Yso.get_target() return target end
gmcp={Char={Status={name='Tester'},Items={}}}
magistaff='staff276791' -- legacy fixed value must not defeat live discovery
local W=dofile(root..'Magi/magi_weapons.lua')
assert(type(W.capture_items)=='function','weapon registry must discover inventory')
assert(triggers.prompt,'text fallback needs a native Mudlet prompt trigger')
W.capture_items({location='inv',items={item(71,'an elemental staff'),item(72,'an elemental staff','L')}},'List')
eq(W.get('staff'),'72','native right-hand L flag')
W.capture_items({location='inv',items={item(60009,'an elemental staff','L'),item(221004,'a cavalry shield','l'),item(477520,'a tower shield')}},'List')
eq(W.get('staff'),'60009','staff from inventory'); eq(magistaff,'staff60009')
eq(W.get('shield'),'221004','prefer wielded shield'); eq(magishield,'shield221004')
W.capture_items({location='room',items={item(999,'an elemental staff','r')}},'List')
eq(W.get('staff'),'60009','ignore room items')
W.capture_items({location='inv',item=221004},'Remove')
eq(W.get('shield'),'477520','replacement shield')
W.capture_items({location='inv',item=item(60009,'an elemental staff')},'Remove')
eq(W.get('staff'),'','removed staff invalidated'); eq(magistaff,'')
W.capture_items({location='inv',item=item(60010,'an elemental staff')},'Add')
eq(W.get('staff'),'60010','new item ID')
W.capture_items({location='inv',items={item(1,'an elemental staff'),item(2,'an elemental staff'),item(3,'a shield')}},'List')
eq(W.get('staff'),'','ambiguous staff')
eq(W.set('staff','staff2'),true); eq(W.get('staff'),'2','explicit registry selection')
W.capture_items({location='inv',item=item(1,'an elemental staff','L')},'Update')
eq(W.get('staff'),'1','wield change takes priority')
-- Explicit test readiness replaces the retired tracker-local auth flag.
W.clear_session(); Yso.session={is_ready=function() return true end}; sent={}
W.refresh()
eq(sent[1],'eq','text equipment refresh')
W.capture_line('You are holding:')
W.capture_line('Wielded:')
W.capture_line('  Left hand: shield221004    a solid Theran cavalry shield')
W.capture_line('  Right hand: staff60009     an elemental staff')
W.finish_listing()
eq(W.get('staff'),'60009','eq parsing'); eq(W.get('shield'),'221004')
W.clear_session(); W.authenticated=true; W.refresh(); W.capture_line('You are holding:'); W.finish_listing()
assert(table.concat(sent,';'):find('ii staff',1,true),'missing staff requests filtered inventory')
W.capture_line('You are holding:'); W.capture_line('Wielded:')
W.capture_line('  Right hand: staff60011    an elemental staff'); W.finish_listing()
W.capture_line('You are holding:'); W.capture_line('Wielded:')
W.capture_line('  Left hand: shield221004    a solid Theran cavalry shield')
W.capture_line('Misc:'); W.capture_line('  shield477520    a solid Theran tower shield'); W.finish_listing()
eq(magistaff,'staff60011'); eq(magishield,'shield221004','ii two-shield preference')
W.clear_session(); W.capture_line('  Right hand: staff99999 an elemental staff')
eq(W.get('staff'),'','unrelated text outside listing ignored')
W.capture_items({location='inv',items={item(60011,'an elemental staff','L'),item(221004,'a shield','l')}},'List')
local before=count(handlers)
dofile(root..'Magi/magi_weapons.lua'); eq(count(handlers),before,'reload handlers unique')

dofile(root..'Yso/xml/yso_target_priority.lua')
dofile(root..'Magi/magi_stormhammer.lua')
local function room(names)
  gmcp.Room={Players={}}
  for _,name in ipairs(names) do gmcp.Room.Players[#gmcp.Room.Players+1]={name=name,fullname=name} end
  hammer_players('gmcp.Room.Players')
end
tprio.reset(); sent={}; target='Absent'; tprio.next(); tprio.previous(); eq(#sent,0,'empty navigation')
tprio.addGroup('bob, alice Bob CAROL'); eq(table.concat(tprio.list,','),'Bob,Alice,Carol','normalize deduplicate')
room({'Alice','Bob','Carol','Dave','Tester'}); eq(target,'Bob','automatic priority target')
eq(table.concat(thammer.getTargets('List'),','),'Bob,Alice,Carol','list order')
eq(table.concat(thammer.getTargets('All'),','),'Bob,Alice,Carol','All distinct and ordered')
target='Dave'; eq(table.concat(thammer.getTargets('All'),','),'Dave,Alice,Bob','All alphabetical fill')
eq(#thammer.getTargets('Cyrene'),0,'unsupported mode safe')
eq(thammer.set_mode('aLL'),true); eq(thammer.target_list,'All')
eq(thammer.set_mode('Cyrene'),false); eq(thammer.target_list,'All')
locked=true; target='Absent'; room({'Alice','Bob'}); eq(target,'Absent','lock respected')
locked=false; hammer_players('gmcp.Room.Players'); eq(target,'Bob')
gmcp.Room.RemovePlayer='Bob'; hammer_players('gmcp.Room.RemovePlayer'); eq(target,'Alice','departure retarget')
gmcp.Room.AddPlayer={name='Ghost',fullname='The soul of Ghost'}; hammer_players('gmcp.Room.AddPlayer')
eq(thammer.players.Ghost,nil,'soul excluded'); eq(thammer.players.Tester,nil,'self excluded')
gmcp.Room.AddPlayer={name='Odd'}; hammer_players('gmcp.Room.AddPlayer'); eq(thammer.players.Odd,true,'missing fullname safe')
gmcp.Room=nil; hammer_players('gmcp.Room.AddPlayer')
target='Alice'; room({'Alice','Bob','Carol'}); thammer.target_list='List'; sent={}
thammer.cast()
eq(sent[1],'setalias stmpvp stand/wield staff60011 shield221004/cast stormhammer at Alice and Bob and Carol','cast payload')
eq(sent[2],'queue add free stmpvp','queue command'); eq(#sent,2)
room({}); sent={}; thammer.cast(); eq(#sent,0,'no targets no send')
room({'Alice'}); W.clear_session(); sent={}; thammer.cast()
for _,s in ipairs(sent) do assert(not s:find('stmpvp',1,true),'unresolved gear cannot queue attack') end
sent={}; tprio.pt(); eq(sent[1],'pt Priority Targets: Bob, Alice, Carol.','announcement format')
tprio.remove('bob'); eq(table.concat(tprio.list,','),'Alice,Carol')
target='Alice'; tprio.current=0; tprio.next(); eq(target,'Alice'); tprio.next(); eq(target,'Carol')
tprio.previous(); eq(target,'Alice')
before=count(handlers); dofile(root..'Magi/magi_stormhammer.lua'); eq(count(handlers),before,'room handlers unique')
gmcp.Char.Items.List={location='inv',items={item(42,'an elemental staff','L'),item(43,'a shield','l')}}
W.capture_items(gmcp.Char.Items.List,'List')
W.capture_items({location='inv',item=42},'Remove')
dofile(root..'Magi/magi_weapons.lua')
eq(W.get('staff'),'','reload must not resurrect removed item from cached List')
gmcp.Room={Players={{name='Bob',fullname='Bob'}}}; target='Bob'
hammer_players('gmcp.Room.Players')
gmcp.Room.RemovePlayer='Bob'; hammer_players('gmcp.Room.RemovePlayer')
dofile(root..'Magi/magi_stormhammer.lua')
eq(thammer.players.Bob,nil,'reload must not resurrect departed player from cached Players')
W.clear_session()
handlers.sysDataSendRequest('sysDataSendRequest','eq')
handlers.sysDataSendRequest('sysDataSendRequest','ii staff')
W.capture_line('You are holding:'); W.capture_line('Wielded:')
W.capture_line('Left hand: shield2 a shield'); W.finish_listing()
W.capture_line('You are holding:'); W.capture_line('Misc:')
W.capture_line('staff1 an elemental staff'); W.finish_listing()
eq(W.get('staff'),'1','overlapping eq and ii responses correlated'); eq(W.get('shield'),'2')
handlers.sysDataSendRequest('sysDataSendRequest','ii staff')
handlers.sysDataSendRequest('sysDataSendRequest','ii staff')
W.capture_line('You are holding:'); W.capture_line('Misc:'); W.capture_line('staff5 an elemental staff'); W.finish_listing()
W.capture_line('You are holding:'); W.capture_line('Misc:'); W.capture_line('staff6 an elemental staff'); W.finish_listing()
eq(W.get('staff'),'6','repeated identical requests correlated')
print('PASS: Stormhammer equipment discovery, text fallback, targeting, events and exact command behavior')
