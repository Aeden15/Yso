$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$doc = [xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/Yso system.xml'))
$group = $doc.SelectSingleNode('//AliasPackage//AliasGroup[name="Dragonform"]')
$aliases = $group.SelectNodes('.//Alias')
if ($aliases.Count -ne 9) { throw 'Expected nine Dragonform aliases' }
if ($group.SelectSingleNode('AliasGroup[name="Limb rend"]').isActive -cne 'no') {
  throw 'Limb rend must remain disabled'
}
$lines = [Collections.Generic.List[string]]::new()
$lines.Add(@'
local sent, calls = {}, 0
local victim = 'Bob'
Yso = {get_target=function() return victim end, target_is_valid=function(t) return t=='Bob' end}
sendAll = function(...)
  calls = calls + 1
  for _,s in ipairs({...}) do sent[#sent+1]=s end
end
local aliases = {}
'@)
$lines.Add(($doc.SelectSingleNode('//Script[name="Dragon support"]').script -replace '\s*return D\s*$', ''))
foreach ($alias in $aliases) {
  if ($alias.script -cnotmatch 'sendAll\("cq all",') { throw ('Missing direct override: ' + $alias.name) }
  $lines.Add('aliases["' + $alias.name + '"] = assert(load([====[return function() ' + $alias.script + "`nend]====]))()")
}
$lines.Add(@'
-- Any use of the automation path fails this test, even with readiness available.
Yso.dragon.manual=function() error('manual helper must not run') end
Yso.dragon.emit=function() error('emitter must not run') end
dragon_att={new=function() error('attack builder must not run') end}
local samples={
 {'Glide(Flying)', {'','north','2'}, 'glide north 2'},
 {'Leap', {'','south'}, 'leap south'},
 {'Breath blast', {''}, 'blast Bob', true},
 {'Left  arm', {''}, 'rend Bob left arm curare', true},
 {'Breathstorm', {''}, 'breathstorm'},
 {'Breath stream', {'','fire'}, 'breathstream Bob fire', true},
 {'Tailsweep', {''}, 'tailsweep'},
 {'Attack', {''}, 'dragoncurse Bob sensitivity 1', true, 'rend Bob curare'},
 {'roar', {''}, 'dragonroar Bob', true},
}
local function run(s)
 sent={};calls=0;matches=s[2];aliases[s[1]]()
end
for _,ready in ipairs({false,true}) do
 gmcp={Char={Skills={Groups={}},Vitals={bal=ready,eq=ready}}}
 Legacy={Curing={Affs={paralysis=true,prone=true}}}
 Yso.dragon.state.breath=ready
 victim='Bob'
 for _,s in ipairs(samples) do
  run(s)
  assert(calls==1,s[1]..': expected one sendAll call')
  assert(sent[1]=='cq all',s[1]..': queue clear must come first')
  assert(sent[2]==s[3],s[1]..': wrong command')
  assert(sent[3]==s[5],s[1]..': wrong follow-up command')
  assert(#sent==(s[5] and 3 or 2),s[1]..': unexpected extra sends')
 end
end
for _,invalid in ipairs({'','Alice',false}) do
 victim=invalid
 for _,s in ipairs(samples) do
  if s[4] then run(s);assert(calls==0,s[1]..': invalid target cleared queue or sent') end
 end
end
victim=nil
for _,s in ipairs(samples) do
 if s[4] then run(s);assert(calls==0,s[1]..': missing target cleared queue or sent') end
end
print('PASS: nine Dragonform overrides, command order, readiness bypass, invalid targets, Lua syntax')
'@)
($lines -join "`n") | & lua -
if ($LASTEXITCODE -ne 0) { throw 'Dragonform alias checks failed' }
