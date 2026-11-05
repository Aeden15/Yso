local root=arg[1] or 'Ysindrolir/'
local sent={}
function send(command) sent[#sent+1]=command end
function cecho() end
function getEpoch() return 100000 end
function registerAnonymousEventHandler() return 1 end
function killAnonymousEventHandler() end
function tempRegexTrigger() return 1 end
function killTrigger() end
Yso={};Legacy={};gmcp={Char={Status={name='Cached',class='Magi'},Vitals={hp='100',maxhp='100'}}}
local P=dofile(root..'Yso/Curing/serverside_policy.lua')
assert(#sent==0,'missing session service must fail closed on policy import')
P.init();P.tick('prompt',true);P.resync('manual')
assert(#sent==0,'missing service must fail closed on init, tick and resync')
Yso.session={}
P.init();P.tick('prompt',true);P.resync('manual')
assert(#sent==0,'incomplete service must fail closed without throwing')
Yso.session={is_ready=function() return false end,subscribe=function() end}
P.init();P.tick('prompt',true);P.resync('manual')
assert(#sent==0,'unauthenticated service must fail closed')
print('PASS: policy fails closed with missing, incomplete and unauthenticated session service')
