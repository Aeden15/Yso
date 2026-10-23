param([ValidateSet('all','dragon','strip','firestorm','firestorm_direct')][string]$Case='all')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
[xml]$doc=[IO.File]::ReadAllText((Join-Path $root 'mudlet packages/Yso system.xml'))
$h=[Collections.Generic.List[string]]::new()
$h.Add('local root=[====['+$root.Replace('\','/')+'/]====]')
function Add-Script([string]$tag,[string]$name,[string]$variable) {
  $node=$doc.SelectSingleNode('//'+$tag+'[name="'+$name+'"]')
  if(-not $node){throw "Missing $tag $name"}
  $h.Add('local '+$variable+'=assert(load([====['+[string]$node.script+']====]))')
}
if($Case -in @('all','dragon')) {
  Add-Script Script 'Api stuff' api
  Add-Script Script 'Dragon support' dragon
  Add-Script Script 'Dragon functions' functions
  $h.Add(@'
Yso={};yso=Yso
tempRegexTrigger=function() return 1 end
registerAnonymousEventHandler=function() return 1 end
gmcp={Char={Skills={Groups={'Dragoncraft'}},Vitals={eq='1',bal='0'}}}
api(); dragon(); functions()
Yso.get_target=function() return 'Foe' end
Yso.target_is_valid=function() return true end
local sent={}
Yso.emit=function(p) sent[#sent+1]=p;return true end
assert(not Yso.dragon.manual('rend_left'),'Dragon rend sent while GMCP balance down and state absent')
Yso.locks.bal_ready=function() return true end
assert(not Yso.dragon.manual('rend_left'),'stale true helper bypassed GMCP balance down')
gmcp.Char.Vitals.bal=nil;gmcp.Char.Vitals.balance='0'
assert(not Yso.dragon.manual('rend_left'),'balance synonym did not veto stale helper')
gmcp.Char.Vitals.balance=false
assert(not Yso.dragon.manual('rend_left'),'false balance did not veto stale helper')
gmcp.Char.Vitals.balance='1';gmcp.Char.Vitals.eq='0'
assert(Yso.dragon.manual('rend_left'),'balanced rend incorrectly required EQ')
assert(#sent==1 and sent[1].bal=='rend Foe left arm curare','balanced rend command changed')
Yso.locks=nil;Yso.state=nil;gmcp.Char.Vitals.balance=nil
assert(not Yso.dragon.manual('rend_left'),'unknown readiness must fail closed')
gmcp.Char.Vitals.balance='1'
assert(Yso.dragon.manual('rend_left'),'GMCP balance synonym readiness was ignored without helpers')
print('PASS: packaged Dragon blocks down/unknown balance and preserves balance-only rend')
'@)
}
if($Case -in @('all','strip')) {
  Add-Script Alias 'Mind strip' mind
  Add-Script Alias 'Demon strip' demon
  $h.Add(@'
local sent,calls={},{}
target='Foe'
send=function(cmd) sent[#sent+1]=cmd end
Yso={class='apostate',apostate={alias=function(name) calls[#calls+1]=name end}}
local function run(class,fallback,want_mind,want_demon)
  gmcp={Char={Status={class=class},Vitals={}}};Yso.class=fallback
  sent={};calls={};mind();demon()
  assert(#sent==want_mind and #calls==want_demon,'strip class isolation failed for '..tostring(class)..' / '..tostring(fallback))
  if want_mind==1 then assert(sent[1]=='mind strip Foe') end
  if want_demon==1 then assert(calls[1]=='strip') end
end
run('Monk','apostate',1,0)
run('Apostate','monk',0,1)
run('Magi','apostate',0,0)
run(nil,'monk',1,0)
run(nil,'apostate',0,1)
run(nil,'magi',0,0)
run('', 'monk',1,0)
gmcp={Char={Status={},Vitals={class='Apostate'}}};Yso.class='monk';sent={};calls={};mind();demon()
assert(#sent==0 and #calls==1,'GMCP Vitals class must precede cached class')
print('PASS: strip aliases are exclusive to current Monk/Apostate class')
'@)
}
if($Case -in @('all','firestorm','firestorm_direct')) {
  Add-Script Trigger 'Mfocus resonance failure' failure
  $h.Add(@'
Yso={class='magi',off={magi={}},magi={},mode={is_combat=function() return true end,route_loop_active=function() return true end}}
yso=Yso
gmcp={Char={Status={class='Magi'},Vitals={eq='1'}},Room={Info={num=101}}}
target='Foe';cecho=function() end;getEpoch=function() return 10000 end
Yso.get_target=function() return target end
Yso.is_magi=function() return true end
affstrack={score={scalded=100}}
ak={magi={resonance={Air=3,Earth=2,Fire=3,Water=0}}}
dofile(root..'Magi/magi_route_core.lua')
local M=dofile(root..'Magi/Magi_firestorm.lua')
local F=dofile(root..'Magi/resonance_feedback.lua')
M.state.enabled=true;M.state.loop_enabled=true;M.init()
local function next_command()
  local p=M.attack_function({preview=true});return type(p)=='table' and p.lanes.eq or p
end
local function rejection(word,element)
  matches={'rejection',word or 'major',element or 'Fire'};failure()
end
local first={eq='cast firestorm',target='Foe',route='magi_firestorm'}
M.on_payload_sent(first)
assert(next_command()~='cast firestorm','successful room policy was not recorded')
ak.magi.resonance.Fire=1
rejection()
assert(M.state.firestorm_rooms['101']==nil,'confirmed Firestorm resonance rejection consumed room attempt forever')
assert(next_command()=='cast dehydrate at Foe','retry fabricated resonance instead of rebuilding from AK')
ak.magi.resonance.Fire=3
assert(next_command()=='cast firestorm','restored resonance did not reopen Firestorm without toggle')
local second={eq='cast firestorm',target='Foe',route='magi_firestorm'}
M.on_payload_sent(second)
M.on_send_result(first,{success=false})
assert(next_command()~='cast firestorm','stale result reopened a later dispatch')
M.on_send_result(second,{success=false})
assert(next_command()=='cast firestorm','matching failed send did not reopen room')
local third={eq='cast firestorm',target='Foe',route='magi_firestorm'}
M.on_payload_sent(third)
M.on_send_result(third,{success=true})
rejection('minor','Water')
assert(next_command()~='cast firestorm','unrelated rejection reopened room')
M.on_payload_sent({eq='cast emanation at Foe fire',target='Foe',route='magi_firestorm'})
rejection()
assert(next_command()~='cast firestorm','later spell rejection reopened Firestorm')
M.on_payload_sent({eq='cast firestorm',target='Foe',route='magi_firestorm'})
Yso.queue={_last_ack_payload={eq='cast fulminate at Foe',route='magi_duel'}}
rejection()
assert(next_command()~='cast firestorm','other route rejection reopened Firestorm')
Yso.queue=nil
M.on_payload_sent({eq='cast firestorm',target='Foe',route='magi_firestorm'})
gmcp.Room.Info.num=202;rejection()
assert(M.state.firestorm_rooms['101']==nil,'late rejection cleared current room instead of dispatched room')
print('PASS: Firestorm confirmed rejection reopens only matching outstanding dispatch and preserves AK resonance')
-- Exercise actual API dispatch, queue acknowledgement construction, locks bus,
-- and offense-core route filtering; non-EQ acks must not erase EQ history.
local queue_modes={true,false}
'@)
  if($Case -eq 'firestorm_direct'){$h.Add('queue_modes={false}')}
  $h.Add(@'
for _,with_queue in ipairs(queue_modes) do
  Yso={class='magi'};yso=Yso
  tempRegexTrigger=function() return 1 end
  killTrigger=function() end
  registerAnonymousEventHandler=function() return 1 end
  local clock=10000
  getEpoch=function() return clock end
  send=function() end
  gmcp.Char.Vitals={eq='1',bal='1'}
  dofile(root..'Yso/xml/api_stuff.lua')
  if with_queue then dofile(root..'Yso/Core/queue.lua') end
  local core=dofile(root..'Yso/Combat/offense_core.lua')
  dofile(root..'Magi/magi_route_core.lua')
  local route=dofile(root..'Magi/Magi_firestorm.lua')
  local feedback=dofile(root..'Magi/resonance_feedback.lua')
  route.state.enabled=true;route.state.loop_enabled=true
  local function emit(lane,cmd,route_id)
    clock=clock+1
    if Yso.queue then Yso.queue.clear_owned(lane) end
    assert(Yso.emit({[lane]=cmd,target='Foe',route=route_id},{route=route_id,kind='utility',commit=true}),'actual emit failed: '..lane)
  end
  for _,lane in ipairs({'free','bal','class'}) do
    emit('eq','cast firestorm','magi_firestorm')
    assert(route.state.firestorm_dispatch,'Firestorm dispatch did not reach actual locks/core bus')
    emit('eq','cast fulminate at Foe','magi_duel')
    emit(lane,'unrelated '..lane,'magi_duel')
    feedback.failure('major','Fire')
    assert(route.state.firestorm_rooms['202']==true,'other-route EQ history lost after '..lane..' ack; queue='..tostring(with_queue))
    emit('eq','cast firestorm','magi_firestorm')
    emit(lane,'unrelated '..lane,'magi_duel')
    feedback.failure('major','Air')
    assert(route.state.firestorm_rooms['202']==nil,'non-EQ-only ack invalidated Firestorm; queue='..tostring(with_queue))
    emit('eq','cast firestorm','magi_firestorm')
    emit(lane,'same-route '..lane,'magi_firestorm')
    feedback.failure('major','Air')
    assert(route.state.firestorm_rooms['202']==nil,'same-route non-EQ ack invalidated Firestorm; lane='..lane..'; queue='..tostring(with_queue))
  end
  -- Reload API with already installed minlocks, then repeat a direct dispatch.
  if not with_queue then
    local original_note_payload=Yso.locks.note_payload
    dofile(root..'Yso/xml/api_stuff.lua')
    assert(Yso.locks.note_payload==original_note_payload,'API reload replaced installed locks')
    emit('eq','cast firestorm','magi_firestorm')
    emit('eq','cast fulminate at Foe','magi_duel')
    emit('bal','unrelated bal','magi_duel')
    feedback.failure('major','Fire')
    assert(route.state.firestorm_rooms['202']==true,'API reload lost durable direct EQ history')
    local full_calls=0
    local full_note=function() full_calls=full_calls+1 end
    Yso.locks={_yso_fulllocks=true,note_payload=full_note}
    dofile(root..'Yso/xml/api_stuff.lua')
    assert(Yso.locks.note_payload==full_note,'API replaced external full locks')
    local external={eq='external full-lock EQ',route='other'}
    assert(Yso.emit(external,{commit=true,kind='utility'}))
    assert(full_calls==1 and Yso._last_eq_ack_payload==external,'direct EQ tracking depends on owned minlocks')
  end
end
print('PASS: actual queue/direct API retains last EQ through free/bal/class acks and reload')
'@)
}
$tmp=Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName()+'.lua')
try {
  [IO.File]::WriteAllText($tmp,($h -join "`n"),[Text.UTF8Encoding]::new($false))
  & lua $tmp
  if($LASTEXITCODE -ne 0){throw "Runtime rejection checks failed: $Case"}
} finally {Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue}
