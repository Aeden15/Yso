local root = arg[1] or 'Ysindrolir/'
if not root:match('[/\\]$') then root=root..'/' end
local sent, timers, toggles = {}, {}, 0
Yso={self={has_aff=function() return false end,is_prone=function() return false end}}
Legacy={Settings={Curing={status=true}}}
gmcp={Char={Vitals={charstats={'Kai: 100%'}}}}
function send(cmd) sent[#sent+1]=cmd end
function expandAlias(cmd) assert(cmd=='pp');toggles=toggles+1;Legacy.Settings.Curing.status=not Legacy.Settings.Curing.status end
function tempTimer(_,fn) timers[#timers+1]=fn;return #timers end
function killTimer(id) timers[id]=nil end
dofile(root..'Yso/Combat/deliverance_resource.lua')
local K=Yso.monk.kai
assert(K.current==100 and hadoken==100)
assert(K.on_burst==nil and Yso.monk.shikudo==nil and Yso.monk.stance==nil)
dofile(root..'Yso/Combat/deliverance_alias.lua')
assert(sent[1]=='kai deliverance' and toggles==1 and K.deliverance.state=='pending')
assert(not K.start_deliverance())
K.on_deliverance('channeling');K.on_deliverance('active');K.on_deliverance('idle')
assert(toggles==2 and Legacy.Settings.Curing.status)
Legacy.Settings.Curing.status=false
assert(K.start_deliverance());K.on_deliverance('idle');assert(toggles==2)
gmcp.Char.Vitals.charstats={'Kai: 81%'};K.apply_charstats(gmcp.Char.Vitals.charstats)
assert(select(2,K.start_deliverance())=='insufficient_kai')
K.apply_charstats({'Kai: 100%'});Legacy.Settings.Curing.status=true
assert(K.start_deliverance());local timeout=timers[#timers];assert(timeout);timeout()
assert(K.deliverance.state=='idle' and Legacy.Settings.Curing.status)
print('PASS: retained Deliverance resource, alias, confirmations, curing ownership and timeout')
