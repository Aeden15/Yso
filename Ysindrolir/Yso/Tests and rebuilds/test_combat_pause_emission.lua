local root=arg[1] or 'Ysindrolir'
local clock,paralyzed,sends=100,false,{}
getEpoch=function() return clock end;send=function(s) sends[#sends+1]=s end
tempRegexTrigger=function() return 1 end;killTrigger=function() end
cecho=function() end;tempTimer=function() return 1 end;killTimer=function() end
registerAnonymousEventHandler=function() return 1 end;killAnonymousEventHandler=function() end
gmcp={Char={Status={class='Apostate'},Vitals={bal='1',eq='1',mp='1000'}}};target='Bob'
Yso={get_target=function() return target end,mode={is_combat=function() return true end}}
dofile(root..'/Yso/xml/api_stuff.lua');dofile(root..'/Yso/Combat/route_registry.lua')
Yso.self={has_aff=function() return paralyzed end}
local P=dofile(root..'/Yso/Combat/combat_pause.lua');dofile(root..'/Yso/Core/queue.lua');local Q=Yso.queue
assert(Q.stage('bal','attack Bob',{route='apostate_truelock'}))
assert(Q.stage('eq','other Bob',{route='apostate_vivisect'}))
assert(Q.stage('free','pet Bob',{route='apostate_truelock'}))
assert(Q.stage('free','safe',{route='another_route'}))
Q.set_owned('bal',{route='apostate_truelock',cmd='already sent'})
paralyzed=true;P.discard_staged('apostate_truelock')
assert(Q.list('bal')==nil);assert(Q.list('eq')=='other Bob')
assert(#Q.list('free')==1 and Q.list('free')[1]=='safe')
assert(Q.get_owned('bal').cmd=='already sent')
-- Discarding an unsent route command releases only its matching pending record.
paralyzed=false
Yso.off={apostate={truelock={state={pending={cmd='unsent Bob'}}}}}
assert(Q.stage('bal','unsent Bob',{route='apostate_truelock'}))
assert(Q.stage('free','eat bloodroot',{route='apostate_truelock',kind='cure'}))
paralyzed=true;P.discard_staged('apostate_truelock')
assert(Yso.off.apostate.truelock.state.pending==nil)
assert(Q.list('free')[2]=='eat bloodroot')
assert(Q.get_owned('bal').cmd=='already sent')
local n=#sends
assert(not Yso.emit({bal='attack Bob'},{route='apostate_truelock',kind='offense',force=true}))
assert(not Yso.emit_now({free='pet Bob'},{route='apostate_truelock',kind='offense'}))
assert(not Q.install_lane('bal','attack Bob',{route='apostate_truelock',kind='offense'}))
assert(not Q.commit({route='apostate_truelock',kind='offense',force=true}))
assert(#sends==n)
-- A cure commit cannot flush another staged offense, even without gain cleanup.
paralyzed=false;Q.clear("all")
assert(Q.stage('bal','deadeyes Bob paralysis asthma',{route='apostate_truelock',kind='offense'}))
assert(Q.stage('free','order daemonite kill Bob',{route='apostate_truelock',kind='offense'}))
paralyzed=true;n=#sends
assert(Yso.emit_now({free='eat bloodroot'},{kind='cure'}))
for i=n+1,#sends do assert(not sends[i]:find('deadeyes',1,true) and not sends[i]:find('daemonite',1,true),'Cure flushed staged offense') end
assert(Q.list('bal')=='deadeyes Bob paralysis asthma')
assert(#Q.list('free')==1 and Q.list('free')[1]=='order daemonite kill Bob')
-- A blocked preferred lane cannot starve an allowed action on another lane.
n=#sends
assert(Yso.emit_now({eq='touch shield'},{kind='defense',prefer='bal'}))
assert(#sends>n and sends[#sends]:find('touch shield',1,true))
-- Explicit self cures and defensive utility retain their existing emitter path.
Q.clear("all");assert(Yso.emit_now({free='stand'},{route='apostate_truelock',kind='utility'}));assert(#sends>n)
paralyzed=false;assert(Yso.emit_now({bal='attack Bob'},{route='apostate_truelock',kind='offense'}))
print('PASS actual emitter and queue: forced/delayed offense gates, cures, scoped staging and dispatched ownership')
