param(
  [string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'),
  [string]$AkPackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/AK.xml')
)
$ErrorActionPreference='Stop'
[xml]$yso=[IO.File]::ReadAllText($PackagePath)
[xml]$ak=[IO.File]::ReadAllText($AkPackagePath)
$targeting=$yso.SelectSingleNode('//Script[name="Yso.targeting"]/script')
$alias=$ak.SelectSingleNode('//Alias[regex="^t (.+)$"]/script')
if(-not $targeting -or -not $alias){throw 'Targeting bridge entries missing'}
$h=@'
local sent, messages, ticks, resets, kills, handlers = {}, {}, 0, 0, 0, {}
function send(s) sent[#sent+1]=s end
function echo(s) messages[#messages+1]=s end
function cecho(s) messages[#messages+1]=s end
function tempRegexTrigger(_, fn) handlers[#handlers+1]=fn; return #handlers end
function tempAlias() return 1 end
function killTrigger() kills=kills+1 end
function killAlias() end
function tempTrigger() return 99 end
Yso={pause={offense={active=true,reason='manual'}},off={core={tick=function() ticks=ticks+1 end}}}
function Yso.offense_paused() return Yso.pause.offense.active end
function Yso.pause_offense(on) Yso.pause.offense.active=on end
ak={highlighttarget=true,_target_hl={raw=10,title=11},oresetparse=function() resets=resets+1 end}
local run_alias
function expandAlias(command)
  local arg=assert(command:match('^t (.+)$'),'unexpected alias forwarding')
  matches={command,arg}; run_alias()
end
'@
$h+="`nassert(load([====[`n"+$targeting.InnerText+"`n]====]))()`n"
$h+="run_alias=assert(load([====[`n"+$alias.InnerText+"`n]====]))`n"
$h+=@'
for _,clear in ipairs({'none','CLEAR','Off','nil','NULL'}) do
  target='Alice'; Yso.targeting.set('Alice','ak',{no_ak=true,force=true})
  sent={}; ticks=0; ak._target_hl={raw=10,title=11}
  matches={'t '..clear,clear}; run_alias()
  assert(target=='' and Yso.get_target()==nil,'clear alias retained a canonical target: '..clear)
  assert(#sent==1 and sent[1]=='st none','clear must send exactly st none')
  assert(ticks==0,'clear kicked offense')
  assert(ak._target_hl.raw==nil and ak._target_hl.title==nil,'clear retained highlighting')
  assert(Yso.offense_paused(),'clear resumed manual pause')
end
target='Alice'; Yso.targeting.set('Alice','ak',{no_ak=true,force=true})
sent={}; Yso.clear_target('test')
assert(#sent==1 and sent[1]=='st none' and Yso.get_target()==nil,'API clear did not use AK clear path')
target='Alice'; Yso.targeting.set('Alice','ak',{no_ak=true,force=true})
sent={}; ak._target_hl={raw=10,title=11}
Yso.is_actively_fighting=function() return false end
local before_resets=resets
handlers[Yso.targeting._trig.clear]()
assert(#sent==0 and Yso.get_target()==nil and Yso.get_target()==nil,'server clear sent or resurrected a target')
assert(ak._target_hl.raw==nil and ak._target_hl.title==nil,'server clear retained highlights')
assert(resets==before_resets+1,'server clear did not reset opponent parsing exactly once')
handlers[Yso.targeting._trig.clear]()
assert(resets==before_resets+1,'repeated server clear reset twice')
sent={}; matches={'t Bob','Bob'}; run_alias()
assert(target=='Bob' and Yso.get_target()=='Bob','normal targeting failed')
assert(#sent==1 and sent[1]=='st Bob','normal target command changed')
assert(Yso.offense_paused(),'manual target selection resumed a pause')
for _,message in ipairs(messages) do assert(not message:find('Usage: y NAME',1,true),'obsolete usage message returned') end
print('PASS: packaged AK/Yso clears, forwarding, highlighting, pause preservation and normal targeting')
'@
$h | & lua -
if($LASTEXITCODE -ne 0){throw 'Packaged targeting bridge regression failed'}
