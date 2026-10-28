param(
  [string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Legacy UI V2.0.xml'),
  [string]$LegacyPackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Legacy V2.1.xml')
)
$ErrorActionPreference = 'Stop'
[xml]$doc = [IO.File]::ReadAllText($PackagePath)
$nodes = $doc.SelectNodes('//Script[name="Legacy AK Display"]/script')
if ($nodes.Count -ne 1) { throw 'Expected one Legacy AK Display script' }
$body = $nodes[0].InnerText
[xml]$core = [IO.File]::ReadAllText($LegacyPackagePath)
$init = $core.SelectSingleNode('//Script[name="Legacy_Install"]/script').InnerText
$start = $init.IndexOf('--SETTINGS')
$stop = $init.IndexOf('Legacy.Settings.Curing = Legacy.Settings.Curing or {}', $start)
if ($start -lt 0 -or $stop -lt 0) { throw 'Legacy prompt settings initialization block missing' }
$settings = $init.Substring($start, $stop - $start)
$promptAlias = $core.SelectSingleNode('//Alias[name="Prompt Toggle"]/script').InnerText
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('legacy-ak-display-' + [guid]::NewGuid() + '.lua')
$harness = @'
local source = __DISPLAY_SOURCE__
local settings_source = __INIT_SETTINGS__
local prompt_alias_source = __PROMPT_ALIAS__
local pass, fail = 0, 0
local function check(name, fn)
  local ok, detail = pcall(fn)
  if ok then pass=pass+1; print('PASS: '..name)
  else fail=fail+1; print('FAIL: '..name..' - '..tostring(detail)) end
end
local function fresh(opts)
  opts = opts or {}
  local env = setmetatable({}, {__index=_G})
  env._G=env
  local serial, handlers, timers, containers = 0, {}, {}, 0
  local methods = {}
  function methods:setStyleSheet() end
  function methods:clear() self.text=''; self.clears=(self.clears or 0)+1 end
  function methods:cecho(s) self.text=(self.text or '')..s end
  function methods:echo(s) self:cecho(s) end
  function methods:hide() self.hidden=true end
  function methods:show() self.hidden=false end
  function methods:raise() end
  local function constructor(kind)
    return {new=function(_, spec, parent)
      if kind=='container' then containers=containers+1 end
      local obj=setmetatable({name=spec.name,text='',parent=parent}, {__index=methods})
      return obj
    end}
  end
  env.Adjustable={Container=constructor('container')}
  env.Geyser={Label=constructor('label'),MiniConsole=constructor('console')}
  env.Legacy={UI={borderColor='grey'},Settings={usePrompt=true,Basher={status=false},NDB={Config={ashtan={color='purple'}}}},NDB={db={Foe={city='Ashtan'}}}}
  env.ak={maxhealth=1000,currenthealth=750,maxmana=1000,currentmana=500,defs={shield=true}}
  env.affstrack={score={asthma=100,paralysis='50',zero=0,negative=-1,bad='bad'}}
  env.target='Foe'
  env.Yso={}
  env.yso=env.Yso
  env.cecho=function() end
  env.echo=function() end
  if opts.initial_fake then
    env.Legacy.UI.AK={name='Aff Tracking',Console={name='Aff Console'},TargetConsole={name='Target Console'}}
  end
  function env.registerAnonymousEventHandler(event, callback)
    serial=serial+1; handlers[serial]={event=event,callback=callback}; return serial
  end
  function env.killAnonymousEventHandler(id) handlers[id]=nil end
  function env.tempTimer(_,callback) serial=serial+1; timers[serial]=callback; return serial end
  function env.killTimer(id) timers[id]=nil end
  local function resolve(callback)
    if type(callback)=='function' then return callback end
    local fn=env
    for part in tostring(callback):gmatch('[^.]+') do fn=fn[part] end
    return fn
  end
  function env.raiseEvent(event)
    local snapshot={}
    for _,entry in pairs(handlers) do if entry.event==event then snapshot[#snapshot+1]=entry.callback end end
    for _,callback in ipairs(snapshot) do assert(resolve(callback), 'missing callback '..tostring(callback))(event) end
  end
  local ctx={env=env}
  function ctx.load() assert(load(source, 'Legacy AK Display', 't', env))() end
  function ctx.draw() assert(env.Legacy_AK_Draw, 'Legacy_AK_Draw missing')() end
  function ctx.emit(event) env.raiseEvent(event) end
  function ctx.render()
    local ui=env.Legacy and env.Legacy.UI and env.Legacy.UI.AK
    return ui and ui.TargetConsole and ui.Console and ((ui.TargetConsole.text or '')..'\n'..(ui.Console.text or '')) or ''
  end
  function ctx.contains(s) assert(ctx.render():find(s,1,true), 'missing '..s..' in '..ctx.render()) end
  function ctx.empty()
    local ui=env.Legacy and env.Legacy.UI and env.Legacy.UI.AK
    assert(ui and ui.Console and ui.TargetConsole, 'display missing')
    assert(ui.Console.text=='' and ui.TargetConsole.text=='', 'stale display content: '..ctx.render())
  end
  function ctx.count(event) local n=0 for _,h in pairs(handlers) do if h.event==event then n=n+1 end end return n end
  function ctx.timer_count() local n=0 for _ in pairs(timers) do n=n+1 end return n end
  function ctx.containers() return containers end
  function ctx.retry()
    local snapshot=timers; timers={}
    for _,callback in pairs(snapshot) do
      if type(callback)=='string' then assert(load(callback,'retry','t',env))() else callback() end
    end
  end
  ctx.load()
  if not opts.no_draw then ctx.emit('LegacyLoaded') end
  return ctx
end
function string:title() return self:gsub('^%l', string.upper) end
function table.contains(t, value) for _,v in pairs(t) do if v==value then return true end end return false end

check('known target retains city colour and positive scores',function()
  local c=fresh(); c.emit('LPrompt')
  c.contains('<purple>Foe'); c.contains('Asthma 100'); c.contains('Paralysis 50')
  assert(not c.render():find('Zero',1,true),'zero score rendered')
end)
check('unknown NDB target still renders tracked afflictions',function()
  local c=fresh(); c.env.Legacy.NDB.db={}; c.emit('LPrompt'); c.contains('Foe'); c.contains('Asthma 100')
end)
check('missing NDB still renders tracked afflictions',function()
  local c=fresh(); c.env.Legacy.NDB=nil; c.emit('LPrompt'); c.contains('Foe'); c.contains('Asthma 100')
end)
check('Yso target resolves without global target',function()
  local c=fresh(); c.env.target=nil; c.env.Yso.get_target=function() return 'Canonical' end
  c.emit('LPrompt'); c.contains('Canonical'); c.contains('Asthma 100')
end)
check('Yso target takes precedence over stale global target',function()
  local c=fresh(); c.env.Yso.get_target=function() return 'Canonical' end
  c.emit('LPrompt'); c.contains('Canonical'); assert(not c.render():find('Foe',1,true),'global target won')
end)
check('successful empty Yso target clears stale global display',function()
  local c=fresh(); c.emit('LPrompt'); c.env.Yso.get_target=function() return '' end
  c.emit('LPrompt'); c.empty()
end)
check('failed Yso resolver falls back to Legacy global target',function()
  local c=fresh(); c.env.Yso.get_target=function() error('not initialized') end
  c.emit('LPrompt'); c.contains('Foe'); c.contains('Asthma 100')
end)
for _,empty in ipairs({'nil','','none','None'}) do
  check('cleared target '..empty..' clears stale display',function()
    local c=fresh(); c.emit('LPrompt'); c.env.target=empty=='nil' and nil or empty
    -- Lua and/or cannot represent the nil branch here.
    if empty=='nil' then c.env.target=nil end
    c.emit('LPrompt'); c.empty()
  end)
end
check('bashing clears stale combat display',function()
  local c=fresh(); c.emit('LPrompt'); c.env.Legacy.Settings.Basher.status=true; c.emit('LPrompt'); c.empty()
end)
check('AK unavailable clears stale combat display',function()
  local c=fresh(); c.emit('LPrompt'); c.env.ak=nil; c.emit('LPrompt'); c.empty()
end)
check('redraw preserves live container and one prompt update',function()
  local c=fresh(); local old=c.env.Legacy.UI.AK; local count=c.containers()
  c.draw(); c.draw(); assert(c.env.Legacy.UI.AK==old,'container replaced'); assert(c.containers()==count,'extra container created')
  assert(c.count('LPrompt')==1,'duplicate prompt handler')
  local before=old.Console.clears or 0; c.emit('LPrompt')
  assert(old.Console.clears==before+1,'one prompt should clear once')
end)
check('late AK initialization recovers through one retry',function()
  local c=fresh({no_draw=true}); c.env.ak=nil; c.draw(); c.draw()
  assert(c.timer_count()==1,'expected one retry timer')
  c.env.ak={}; c.retry(); c.emit('LPrompt'); c.contains('Asthma 100'); assert(c.timer_count()==0,'retry remains after recovery')
end)
check('late Legacy initialization recovers through one retry',function()
  local c=fresh({no_draw=true}); local saved=c.env.Legacy; c.env.Legacy=nil; c.draw(); c.draw()
  assert(c.timer_count()==1,'expected one retry timer')
  c.env.Legacy=saved; c.retry(); c.emit('LPrompt'); c.contains('Asthma 100')
end)
check('script reload keeps one prompt and load handler',function()
  local c=fresh(); c.load(); c.load(); c.emit('LegacyLoaded')
  assert(c.count('LPrompt')==1,'duplicate prompt handlers'); assert(c.count('LegacyLoaded')==1,'duplicate load handlers')
  c.emit('LPrompt'); c.contains('Asthma 100')
end)
check('serialized GUI tables rebuild on settings reload',function()
  local c=fresh(); local fake={name='Aff Tracking',Console={name='Aff Console'},TargetConsole={name='Target Console'}}
  c.env.Legacy.UI.AK=fake
  c.emit('LegacyLoaded'); assert(c.env.Legacy.UI.AK~=fake,'serialized GUI tables retained')
  c.emit('LPrompt'); c.contains('Asthma 100'); assert(c.count('LPrompt')==1,'duplicate prompt handler after reload')
end)
check('initial serialized GUI tables rebuild without a trusted owner',function()
  local c=fresh({initial_fake=true}); c.emit('LPrompt'); c.contains('Asthma 100')
  assert(c.containers()==1,'initial GUI tables were reused without constructing a live container')
end)
for _,case in ipairs({{name='default',want=true},{name='saved-on',saved=true,want=true},{name='saved-off',saved=false,want=false}}) do
  check('prompt initialization synchronizes '..case.name..' setting and lprompt toggles consistently',function()
    local enabled=nil
    local e={Legacy={Settings={usePrompt=case.saved}},send=function() end}
    e.enableTrigger=function(name) assert(name=='Legacy Prompt'); enabled=true end
    e.disableTrigger=function(name) assert(name=='Legacy Prompt'); enabled=false end
    setmetatable(e,{__index=_G})
    assert(load(settings_source,'LInit prompt settings','t',e))()
    assert(e.Legacy.Settings.usePrompt==case.want,'saved setting not preserved')
    assert(enabled==case.want,'saved prompt setting and actual trigger disagree')
    local toggle=assert(load(prompt_alias_source,'lprompt alias','t',e))
    toggle(); assert(enabled==not case.want,'first toggle did not change trigger state')
    assert(e.Legacy.Settings.usePrompt==enabled,'toggle setting and trigger disagree')
    toggle(); assert(enabled==case.want,'second toggle did not restore trigger state')
    assert(e.Legacy.Settings.usePrompt==enabled,'restored setting and trigger disagree')
  end)
end
print(pass..' passed, '..fail..' failed')
if fail>0 then os.exit(1) end
'@
$harness = $harness.Replace('__DISPLAY_SOURCE__', '[====[' + $body + ']====]')
$harness = $harness.Replace('__INIT_SETTINGS__', '[====[' + $settings + ']====]')
$harness = $harness.Replace('__PROMPT_ALIAS__', '[====[' + $promptAlias + ']====]')
try {
  [IO.File]::WriteAllText($scratch, $harness, (New-Object Text.UTF8Encoding $false))
  & lua $scratch
  if ($LASTEXITCODE -ne 0) { throw 'Legacy AK display regressions failed' }
} finally {
  if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch }
}
