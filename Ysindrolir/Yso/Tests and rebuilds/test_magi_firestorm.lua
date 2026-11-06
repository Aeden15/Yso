-- Firestorm behavior: actual route/core/interface, fake Mudlet clock and transport.
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
local root=arg[1] or here..'../../'
local route_file=arg[2] or root..'Magi/Magi_firestorm.lua'
local F,RC,now,target,sent,emit_ok,synchronous,paused,eq
local passed,failed=0,0
local function reset()
  now,target,sent,emit_ok,synchronous,paused,eq=10000,'Foe',{},true,false,false,true
  function getEpoch() return now end
  function cecho() end
  _G.target=target
  gmcp={Char={Status={class='Magi'},Vitals={eq='1'}},Room={Info={num=101}}}
  affstrack={score={scalded=100}}
  ak={healthpercent=100,defs={},magi={resonance={Water=0,Earth=1,Fire=0,Air=0}}}
  Yso={off={magi={}},magi={},get_target=function() return target end,
    is_magi=function() return true end,target_is_valid=function() return true end,
    offense_paused=function() return paused end,state={eq_ready=function() return eq end},
    mode={is_combat=function() return true end,route_loop_active=function() return true end},
    locks={note_payload=function() end},queue={commit=function() end}}
  yso=Yso
  dofile(root..'Yso/Combat/route_interface.lua')
  RC=dofile(root..'Magi/magi_route_core.lua')
  F=dofile(route_file)
  F.state={enabled=true,loop_enabled=true}
  Yso.emit=function(payload,opts)
    if not emit_ok then return false end
    payload.route=opts.route;sent[#sent+1]=payload
    if synchronous then Yso._last_eq_ack_payload=payload;F.on_payload_sent(payload) end
    return true
  end
end
local function ack(payload) Yso._last_eq_ack_payload=payload;return F.on_payload_sent(payload) end
local function want(command)
  local p,why=F.attack_function({preview=true})
  assert(type(p)=='table' and p.lanes.eq==command,'expected '..command..', got '..tostring(type(p)=='table' and p.lanes.eq or why))
end
local function room_ready() ak.magi.resonance.Air,ak.magi.resonance.Fire=3,3 end
local function room_attempt()
  room_ready();assert(F.attack_function());assert(ack(sent[#sent]))
end
local function test(name,body)
  reset();local ok,err=pcall(body)
  if ok then passed=passed+1 else failed=failed+1;print('FAIL '..name..': '..tostring(err)) end
end

test('shield, finishers and execute preserve priority',function()
  ak.defs.shield=true;ak.healthpercent=10
  RC.special_action=function() return 'cast destroy at Foe','destroy',false end
  want('cast erode at Foe shield');ak.defs.shield=false
  want('cast destroy at Foe');RC.special_action=function() return nil,'hold',true end
  local ok,why=F.attack_function();assert(not ok and why=='hold')
  RC.special_action=function() end;want('cast stormhammer at Foe')
  ak.healthpercent=25;want('cast bombard at Foe')
end)
test('Scalded must be confirmed; sending Magma does not advance setup',function()
  for _,score in ipairs({0,1,50,99}) do affstrack.score.scalded=score;want('cast magma at Foe') end
  assert(F.attack_function());assert(ack(sent[1]))
  assert(affstrack.score.scalded==99)
  now=now+1.1;want('cast magma at Foe')
  affstrack.score.scalded=100;want('cast bombard at Foe')
end)
test('failed Magma clears its pending send immediately',function()
  affstrack.score.scalded=0;assert(F.attack_function());ack(sent[1])
  F.on_send_result(sent[1],{success=false});want('cast magma at Foe')
  assert(affstrack.score.scalded==0)
end)
test('partial Conflagrate does not hide a ready payoff',function()
  room_attempt();ak.magi.resonance.Fire=2;affstrack.score.aflame=200
  for _,score in ipairs({0,1,50,99}) do affstrack.score.conflagrate=score;want('cast conflagrate at Foe') end
  affstrack.score.conflagrate=100;want('cast dehydrate at Foe')
end)
test('all spell submissions are reserved before delayed ack',function()
  local cases={
    function() ak.defs.shield=true end,
    function() ak.healthpercent=10 end,
    function() affstrack.score.scalded=0 end,
    function() end,
    function() ak.magi.resonance.Earth=2 end,
    function() ak.magi.resonance.Air=3 end,
    function() ak.magi.resonance.Air=3;ak.magi.resonance.Water=2 end,
    room_ready,
  }
  for _,setup in ipairs(cases) do
    reset();setup();assert(F.attack_function())
    local ok,why=F.attack_function()
    assert(not ok and tostring(why):find('pending',1,true) and #sent==1,'duplicate '..sent[1].eq)
    ack(sent[1]);if sent[1].eq~='cast firestorm' then assert(not F.attack_function() and #sent==1,'duplicate after ack') end
  end
end)
test('timeout and rejected emission permit bounded retries',function()
  emit_ok=false;assert(not F.attack_function());emit_ok=true;assert(F.attack_function())
  now=now+1.1;assert(F.attack_function() and #sent==2)
end)
test('synchronous ack leaves no phantom waiting',function()
  synchronous=true;assert(F.attack_function())
  assert(not F.alias_loop_waiting_blocks() and not F.state.waiting.queue)
  assert(not F.attack_function() and #sent==1)
end)
test('old and foreign ack cannot resolve newer submission',function()
  assert(F.attack_function());local old=sent[1]
  now=now+1.1;assert(F.attack_function());local current=sent[2]
  assert(not F.on_payload_sent(old));assert(F.alias_loop_waiting_blocks())
  assert(not F.on_payload_sent({eq=current.eq,target='Other',route=F.key}))
  assert(not F.on_payload_sent({eq=current.eq,target='Foe',route='magi_water_group'}))
  assert(ack(current));F.on_send_result(old,{success=false})
  assert(not F.attack_function(),'old rejection released newer send')
end)
test('preview and explain do not mutate runtime',function()
  assert(F.attack_function());local sub=F.state.submission
  local waiting=F.state.waiting.queue;local reason=F.state.template.last_reason
  now=now+40
  F.attack_function({preview=true});F.explain()
  assert(F.state.submission==sub and F.state.waiting.queue==waiting and F.state.template.last_reason==reason and #sent==1)
end)
test('explain shows the actual next command and evidence',function()
  local s=F.explain()
  assert(s.command=='cast bombard at Foe' and s.scalded==true and s.air==0 and type(s.reason)=='string')
end)
test('foreign target, pause and EQ down cannot send',function()
  ak.healthpercent=10
  local ok,why=F.attack_function({target='Other'});assert(not ok and why=='target_mismatch')
  paused=true;assert(not F.attack_function());paused=false;eq=false;assert(not F.attack_function())
  assert(#sent==0)
end)
test('missing core safely holds and later recovers',function()
  Yso.off.magi.route_core={};F=dofile(route_file);F.state.enabled,F.state.loop_enabled=true,true
  local ok,why=F.attack_function();assert(not ok and why=='core_unavailable')
  RC=dofile(root..'Magi/magi_route_core.lua');want('cast bombard at Foe')
end)
test('room retry is bounded and preserves target-independent cadence',function()
  room_attempt();now=now+1.1
  want('cast emanation at Foe fire')
  target='Other';want('cast emanation at Other fire')
  now=now+F.cfg.firestorm_retry_s;want('cast firestorm')
  assert(ak.magi.resonance.Air==3 and ak.magi.resonance.Fire==3,'attempt changed resonance')
end)
test('unknown room cannot mark an arbitrary permanent room',function()
  gmcp.Room=nil;room_attempt()
  gmcp.Room={Info={num=202}};now=now+1.1;want('cast firestorm')
end)
test('room changes and confirmed end reopen the correct room',function()
  room_attempt();now=now+1.1;gmcp.Room.Info.num=202;want('cast firestorm')
  gmcp.Room.Info.num=101;want('cast emanation at Foe fire')
  F.on_firestorm_ended(101);want('cast firestorm')
end)
test('room rejection uses actual dispatch identity and room',function()
  room_attempt();local old=sent[1]
  gmcp.Room.Info.num=202
  assert(F.on_resonance_failure(3,'air'))
  gmcp.Room.Info.num=101;want('cast firestorm')
  assert(F.attack_function());ack(sent[2]);F.on_send_result(old,{success=false})
  now=now+1.1;want('cast emanation at Foe fire')
  Yso._last_eq_ack_payload={eq='cast fulminate at Foe',route='magi_duel'}
  assert(not F.on_resonance_failure(3,'fire'))
  want('cast emanation at Foe fire')
end)
test('non-EQ acknowledgements do not invalidate room rejection',function()
  room_attempt();F.on_payload_sent({bal='other',target='Foe',route=F.key})
  assert(F.on_resonance_failure(3,'fire'));want('cast firestorm')
end)
test('stop, pause, target swap and reload clear transient sends',function()
  for _,hook in ipairs({'on_pause','on_target_swap','alias_loop_on_stopped'}) do
    reset();assert(F.attack_function());F[hook]({silent=true})
    assert(not F.state.submission and not F.state.waiting.queue)
    assert(F.attack_function())
  end
  F=dofile(route_file);assert(not F.state.submission and not F.state.waiting.queue)
end)
test('observed pause clears an outstanding wait',function()
  assert(F.attack_function());paused=true;assert(not F.alias_loop_waiting_blocks())
  paused=false;assert(F.attack_function())
end)
test('post-room promotions and pressure retain order',function()
  room_attempt();now=now+1.1
  want('cast emanation at Foe fire')
  affstrack.score.conflagrate=100;ak.magi.resonance.Earth=3
  want('cast emanation at Foe earth')
  ak.magi.resonance.Earth=2;ak.magi.resonance.Fire=1
  want('cast dehydrate at Foe')
  ak.magi.resonance.Water=2;want('cast firelash at Foe')
  ak.magi.resonance.Air=1;want('cast fulminate at Foe')
end)
test('all resonance combinations choose a legal single EQ command',function()
  for air=0,3 do for earth=0,3 do for fire=0,3 do for water=0,3 do
    ak.magi.resonance={Air=air,Earth=earth,Fire=fire,Water=water}
    local p=F.attack_function({preview=true})
    assert(type(p)=='table' and p.lanes.eq:match('^cast ') and not p.lanes.eq:find('|',1,true))
    if p.lanes.eq=='cast firestorm' then assert(air==3 and fire==3) end
  end end end end
end)
test('actual queue/API acknowledgement resolves inside emission',function()
  function tempRegexTrigger() return 1 end
  function registerAnonymousEventHandler() return 1 end
  function send() return true end
  Yso.class,Yso.locks,Yso.queue='magi',nil,nil
  dofile(root..'Yso/xml/api_stuff.lua');dofile(root..'Yso/Core/queue.lua')
  local core=dofile(root..'Yso/Combat/offense_core.lua');core.register(F.key,F)
  assert(F.attack_function());assert(F.state.submission.acknowledged)
  assert(not F.alias_loop_waiting_blocks() and not F.state.waiting.queue)
end)
test('foreign explicit targets cannot receive entourage orders',function()
  local orders={};Yso.send=function(command) orders[#orders+1]=command;return true end
  assert(not F.attack_function({target='Other'}))
  assert(#orders==0,'ordered pets against a rejected target')
end)
test('replaying a consumed ACK cannot mark a different room',function()
  room_attempt();local old=sent[1];gmcp.Room.Info.num=303
  assert(not F.on_payload_sent(old),'accepted already consumed ACK')
  assert(F.state.firestorm_rooms['303']==nil)
end)
test('previous attempt ACK during retry cannot settle or reject the retry',function()
  room_attempt();local old=sent[1];F.on_send_result(old,{success=false})
  Yso.emit=function(payload,opts)
    payload.route=opts.route;sent[#sent+1]=payload
    assert(not F.on_payload_sent(old),'accepted previous ACK during emit')
    F.on_send_result(old,{success=false})
    assert(F.state.submission,'old failure cleared retry reservation')
    return true
  end
  assert(F.attack_function());assert(F.alias_loop_waiting_blocks())
  assert(ack(sent[2]));assert(not F.alias_loop_waiting_blocks())
end)
test('lifecycle cleanup retires dispatch but preserves room cadence',function()
  for _,hook in ipairs({'on_pause','on_target_swap'}) do
    reset();room_attempt();local old=sent[1];local attempted=F.state.firestorm_rooms['101']
    F[hook]();assert(not F.on_resonance_failure(3,'fire'),'rejection survived '..hook)
    assert(F.state.firestorm_rooms['101']==attempted,'lost room cadence on '..hook)
    gmcp.Room.Info.num=303;assert(not F.on_payload_sent(old))
    assert(F.state.firestorm_rooms['303']==nil)
  end
end)
test('stop cannot be undone by replaying its last canonical ACK',function()
  room_attempt();local old=sent[1];F.alias_loop_on_stopped({silent=true})
  gmcp.Room.Info.num=303;assert(not F.on_payload_sent(old))
  assert(F.state.firestorm_rooms['303']==nil and not F.state.firestorm_dispatch)
end)
test('actual direct API keeps canonical ACK instead of synthetic fallback',function()
  function tempRegexTrigger() return 1 end
  function registerAnonymousEventHandler() return 1 end
  function send() return true end
  Yso.class,Yso.locks,Yso.queue='magi',nil,nil
  dofile(root..'Yso/xml/api_stuff.lua')
  local core=dofile(root..'Yso/Combat/offense_core.lua');core.register(F.key,F)
  room_ready();assert(F.attack_function())
  local actual=Yso._last_eq_ack_payload
  assert(F.state.submission.ack_payload==actual,'fallback overwrote real ACK')
  F.on_send_result(actual,{success=false})
  assert(F.state.firestorm_rooms['101']==nil and not F.state.submission)
end)
test('fresh canonical manual room cast supersedes unrelated route submission',function()
  for _,phase in ipairs({'unacknowledged','acknowledged','expired'}) do
    reset();assert(F.attack_function())
    if phase~='unacknowledged' then ack(sent[1]) end
    if phase=='expired' then now=now+2 end
    local manual={eq='cast firestorm',target='Foe',route=F.key}
    assert(ack(manual),'ignored fresh manual dispatch during '..phase)
    assert(type(F.state.firestorm_rooms['101'])=='number')
    assert(not F.state.submission,'manual action left older reservation alive')
    F.on_send_result(sent[1],{success=false})
    assert(F.state.firestorm_rooms['101']~=nil,'older rejection cleared manual room cast')
  end
end)
test('route does not add per-cast equipment commands',function()
  local wields=0;Yso.magi.weapons={send_wields=function() wields=wields+1 end}
  assert(F.attack_function());assert(wields==0,'added unsolicited wield sends')
end)
print(string.format('Firestorm: %d passed, %d failed',passed,failed))
if failed>0 then os.exit(1) end
