-- Real targeting service; Mudlet I/O and the AK command boundary are simulated.
local here = debug.getinfo(1, 'S').source:sub(2):match('^(.*[/\\])')
local root = here .. '../../'
local failures, count = {}, 0
local function test(label, fn)
  local ok, why = pcall(fn)
  if ok then count = count + 1 else failures[#failures+1] = label .. ': ' .. tostring(why) end
end
local function boot()
  local io = {sent={}, echoes={}, staged={'attack Old'}, paused=true, resumes=0, clears=0, triggers={}, killed={}}
  target='Old'
  Yso={target='Old', state={_last_ent_cmd='attack Old',_last_ent_cmd_ts=1},
    queue={flush_staged=function() io.staged={} end},
    ingest={target_left=function() io.clears=io.clears+1 end},
    offense_paused=function() return io.paused end,
    pause_offense=function(value) io.paused=value; io.resumes=io.resumes+1 end}
  ak=nil; oc_isCurrentTarget=nil
  echo=function(s) io.echoes[#io.echoes+1]=s end
  send=function(s) io.sent[#io.sent+1]=s end
  tempRegexTrigger=function(pattern, callback)
    io.triggers[#io.triggers+1]={pattern=pattern,callback=callback}
    return #io.triggers
  end
  killTrigger=function(id) io.killed[#io.killed+1]=id end; tempAlias=nil
  -- Equivalent clear boundary until the package's actual AK alias is integrated.
  expandAlias=function(command)
    assert(command=='t clear','unexpected AK command: '..command)
    Yso.targeting.clear('ak','alias',true,{no_ak=true})
    send('st none')
  end
  dofile(root..'Yso/xml/yso_targeting.lua')
  Yso.targeting.state.name='Old'
  return io
end

for _,value in ipairs({'None',' CLEAR ','oFf','NiL','nUlL'}) do
  test('manual clear sentinel '..value,function()
    local io=boot()
    assert(Yso.set_target(value,'manual')==true,'clear was rejected')
    assert(target=='' and Yso.target=='' and Yso.get_target()==nil,'clear restored old target')
    assert(#io.sent==1 and io.sent[1]=='st none','clear sent a target name or duplicate command')
    assert(next(io.staged)==nil,'clear retained staged offense')
    assert(Yso.state._last_ent_cmd==nil and Yso.state._last_ent_cmd_ts==nil,'clear retained entity target work')
    assert(io.paused and io.resumes==0,'clear resumed offense')
  end)
end
test('missing manual argument is quiet and keeps target',function()
  local io=boot()
  for _,value in ipairs({'','   ',false}) do
    local ok,reason=Yso.set_target(value or nil)
    assert(ok==false and reason=='no_target','missing argument must return false/no_target')
  end
  assert(#io.echoes==0 and #io.sent==0 and target=='Old','missing argument caused side effects')
end)
test('clear synchronizes stale canonical target even when service is empty',function()
  local io=boot(); Yso.targeting.state.name=''
  assert(Yso.targeting.clear('server','room change',true))
  assert(target=='' and Yso.target=='' and Yso.get_target()==nil,'stale global was imported')
  assert(next(io.staged)==nil and io.clears>0,'empty clear skipped cleanup')
  assert(#io.sent==0,'server clear sent another command')
end)
test('manual targeting preserves pause until explicit resume',function()
  local io=boot()
  assert(Yso.set_target('New','manual',{no_ak=true}))
  assert(io.paused and io.resumes==0,'manual target set resumed offense')
  Yso.pause_offense(false,'explicit resume')
  assert(not io.paused,'explicit resume was blocked')
end)
test('passive import preserves pause and adopts canonical target',function()
  local io=boot(); target='New'
  assert(Yso.get_target()=='New','global target not imported')
  assert(io.paused and io.resumes==0,'passive read resumed offense')
  assert(#io.sent==0,'passive import forwarded back to AK')
end)
test('server clear clears active target without sending',function()
  local io=boot()
  assert(Yso.targeting.clear('ak','server_target_clear',true))
  assert(Yso.get_target()==nil and target=='' and #io.sent==0,'server clear failed or sent command')
end)
test('inactive paused server callback clears canonical target and AK tracking once',function()
  local io=boot(); target='Alice'; Yso.target='Alice'; Yso.targeting.state.name='Alice'
  local resets=0
  ak={_target_hl={raw=71,title=72},oresetparse=function()
    assert(target=='Alice','opponent reset lost the old canonical target')
    resets=resets+1
  end}
  Yso.is_actively_fighting=function() return false end
  local clear=assert(io.triggers[2]).callback
  clear()
  assert(target=='' and Yso.target=='' and Yso.get_target()==nil,'inactive server clear retained Alice')
  assert(#io.killed==2 and io.killed[1]==71 and io.killed[2]==72,'old AK highlights were not removed')
  assert(ak._target_hl.raw==nil and ak._target_hl.title==nil,'highlight IDs survived clear')
  assert(resets==1,'opponent reset did not run exactly once')
  clear()
  assert(resets==1 and #io.killed==2,'repeated no-op clear repeated AK cleanup')
  assert(io.paused and io.resumes==0 and #io.sent==0,'server clear resumed or sent commands')
end)
test('manual alias clear delegates AK cleanup once across reentrant bridge',function()
  local io=boot(); local resets=0
  ak={_target_hl={raw=81,title=82},oresetparse=function()
    assert(target=='Old','reset ran after canonical clear')
    resets=resets+1
  end}
  assert(Yso.set_target('none'))
  assert(resets==1 and #io.killed==2,'forwarded clear skipped or repeated AK cleanup')
  assert(#io.sent==1 and io.sent[1]=='st none','forwarded clear sent duplicate commands')
end)
test('broken AK reset cannot prevent canonical clear',function()
  local io=boot()
  ak={_target_hl={raw=91,title=92},oresetparse=function() error('broken reset') end}
  assert(Yso.targeting.clear('server','server_target_clear',true))
  assert(target=='' and Yso.get_target()==nil and next(io.staged)==nil,'reset failure prevented clear')
  assert(#io.killed==2 and #io.sent==0 and io.paused,'reset failure prevented safe cleanup')
end)
test('upgrade old loaded service and owned wrappers without losing state',function()
  local io=boot()
  local TG=Yso.targeting
  TG._svc_version=nil; TG._public_wrappers=nil
  Yso.set_target=function() return false, TG.state.name end
  TG.get=function() return 'obsolete' end
  TG.cfg.echo=true
  dofile(root..'Yso/xml/yso_targeting.lua')
  assert(TG.cfg.echo and TG.state.name=='Old' and io.paused,'upgrade discarded configuration, target or pause')
  assert(Yso.set_target('None')==true,'old owned wrapper survived upgrade')
  assert(Yso.get_target()==nil,'old service survived upgrade')
end)
test('upgrade preserves an external public wrapper',function()
  boot()
  Yso.targeting._svc_version=nil
  local external=function() return 'external' end
  Yso.set_target=external
  dofile(root..'Yso/xml/yso_targeting.lua')
  assert(Yso.set_target==external,'upgrade overwrote third-party wrapper')
end)
for _,why in ipairs(failures) do io.stderr:write('FAIL: '..why..'\n') end
assert(#failures==0,tostring(#failures)..' targeting cases failed')
print('PASS: '..count..' targeting clear/pause cases')
