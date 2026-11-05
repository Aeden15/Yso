-- A TCP connection is not an authenticated game session.
local sent, packets, handlers = {}, {}, {}
function send(s) sent[#sent+1]=s end
function sendGMCP(s) packets[#packets+1]=s end
function registerAnonymousEventHandler(event,fn) handlers[event]=fn; return event end
function killAnonymousEventHandler(event) handlers[event]=nil end
function tempRegexTrigger() return 1 end
function tempPromptTrigger() return 2 end
function killTrigger() end
function tempTimer() return 3 end
function killTimer() end
Yso={}
-- GMCP tables can still contain the previous session's character data.
gmcp={Char={Status={name='Tester',class='Magi'},Vitals={hp='100',maxhp='100'},Items={}}}
dofile('Ysindrolir/Yso/Integration/session.lua')
local W=dofile('Ysindrolir/Magi/magi_weapons.lua')
sent={}; packets={}
handlers.sysConnectionEvent('sysConnectionEvent')
assert(#sent==0,'TCP connect must not send eq into the login/password exchange')
assert(#packets==0,'TCP connect must not request inventory before authentication')
assert(W.refresh()==false,'manual tracker refresh must wait for authentication')
assert(#sent==0 and #packets==0,'refresh must remain silent at login')
gmcp.Char.Status={}
handlers['gmcp.Char.Status']('gmcp.Char.Status')
assert(#sent==0 and #packets==0,'incomplete status must not start equipment queries')
gmcp.Char.Status={name='Tester',class='Magi'}
handlers['gmcp.Char.Status']('gmcp.Char.Status')
assert(sent[1]=='eq' and #sent==1,'fresh authenticated character status should start discovery')
assert(#packets==1,'authenticated discovery requests inventory once')
handlers['gmcp.Char.Status']('gmcp.Char.Status')
handlers['gmcp.Char.Vitals']('gmcp.Char.Vitals')
assert(#sent==1 and #packets==1,'repeated character updates must not spam discovery')
handlers.sysDisconnectionEvent('sysDisconnectionEvent')
sent={};packets={}
dofile('Ysindrolir/Magi/magi_weapons.lua')
assert(#sent==0 and #packets==0,'reload at login must not use stale GMCP to send queries')
handlers.sysConnectionEvent('sysConnectionEvent')
assert(#sent==0 and #packets==0,'reconnect remains silent until fresh character data')
handlers['gmcp.Char.Vitals']('gmcp.Char.Vitals')
assert(#sent==1 and sent[1]=='eq','fresh authenticated vitals can resume discovery')
handlers.sysDisconnectionEvent('sysDisconnectionEvent')
sent={}; packets={}
gmcp.Char.Items.List={location='room',items={}}
handlers['gmcp.Char.Items.List']('gmcp.Char.Items.List')
assert(#sent==0 and #packets==0,'room inventory does not authenticate equipment tracker')
print('PASS: login, stale GMCP, reconnect and reload emit no equipment commands before authentication')
