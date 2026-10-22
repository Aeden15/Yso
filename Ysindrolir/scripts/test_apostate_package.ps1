$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$doc = [xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/Yso system.xml'))
$core = $doc.SelectSingleNode('//Script[name="Apostate utilities"]')
if (-not $core) { throw 'Missing Apostate utilities script' }
$nightmare=$doc.SelectSingleNode('//TriggerGroup[name="Apostate"]/TriggerGroup[name="Apostasy"]/Trigger[name="Nightmare unavailable"]')
if(-not $nightmare -or $nightmare.isActive -ne 'yes'){throw 'Missing active Nightmare unavailable trigger in Apostate/Apostasy'}
if('A nightmare may only be summoned in the slumber of night.' -cnotmatch $nightmare.regexCodeList.string){throw 'Nightmare failure line does not match'}
$lines = [Collections.Generic.List[string]]::new()
$lines.Add(@'
local sent, events = {}, {}
Yso = {}; yso = Yso
gmcp = {Char={Status={class="Apostate"}}}
send = function(s) sent[#sent+1]=s end
cecho = function() end
deleteLine = function() end
registerAnonymousEventHandler = function(e,f) events[e]=f; return e end
killAnonymousEventHandler = function() end
Yso.get_target = function() return target end
local function check(a,b) assert(a==b, tostring(a).." ~= "..tostring(b)) end
local function clear() sent={} end
'@)
$lines.Add($doc.SelectSingleNode('//Script[name="Miscellaneous scripts"]').script)
$lines.Add($core.script)
$lines.Add('local aliases, triggers = {}, {}')
foreach ($type in @('Alias','Trigger')) {
  foreach ($n in $doc.SelectNodes('//*[name="Apostate"]//' + $type)) {
    $table = if ($type -eq 'Alias') { 'aliases' } else { 'triggers' }
    $lines.Add($table + '["' + $n.name + '"] = assert(load([====[return function() ' + $n.script + "`n" + 'end]====]))()')
  }
}
$lines.Add(@'
local A=Yso.apostate
A.nightmare=true;triggers['Nightmare unavailable']();check(A.nightmare,false)
target=nil
A.alias("sap"); check(#sent,0)
target="Bob"
A.alias("sap"); check(sent[1],"cq all"); check(sent[2],"demon sap Bob")
clear(); A.alias("beck"); check(sent[2],"demon beckon")
clear(); A.alias("beck","Alice"); check(sent[2],"demon beckon Alice")
for _,limb in ipairs({"arms","legs","left arm","right arm","left leg","right leg"}) do
  clear(); A.alias("shrivel",limb); check(sent[2],"shrivel "..limb.." Bob")
end
clear(); A.alias("shrivel","left"); check(#sent,0)
A.alias("beck","Bob;quit"); check(#sent,0)
A.alias("siphon","x"); check(#sent,0)
gmcp.Char.Status.class="Monk"; A.alias("sap"); check(#sent,0)
gmcp.Char.Status.class="Apostate"
clear(); A.trace("p","Bob","2"); check(sent[1],"demon trace Bob")
A.trace_started("Bob"); clear()
A.trace_moved("Alice","Elsewhere"); check(#sent,0)
A.trace_moved("Bob","Room one"); check(#sent,0)
A.trace_moved("Bob","Room two"); check(sent[1],"pt Bob moved to Room two")
clear(); A.trace_moved("Bob","On the clouds"); check(sent[1],"pt Bob duanathar'd")
A.trace("","Bob","2"); clear(); A.trace_moved("Bob","Somewhere"); check(#sent,0)
A.trace("p","Bob","0"); check(#sent,0)
A.trace("p","Bob","1"); clear(); A.trace_halted(); check(sent[1],"pt Tracing off")
clear(); A.trace_halted(); check(#sent,0)
A.pentagram=true; events["gmcp.Room.Info"](); check(A.pentagram,nil)
A.baalzadeen=true; A.taste=true; events.sysDisconnectionEvent()
check(A.baalzadeen,nil); check(A.taste,nil); check(A.trace_state.target,nil)
local samples = {
  {"Mana sap",nil,"demon sap Bob"}, {"Demon strip",nil,"demon strip Bob"},
  {"Soulstorm",nil,"soulstorm Bob"}, {"Icewall melt","north","demon scorch north"},
  {"Siphon toggle(affliction cures)","o","demon syphon"},
  {"Siphon toggle(affliction cures)","f","demon syphon off"},
  {"Pentagram","c","carve pentagram"}, {"Pentagram","d","dispel pentagram"},
  {"Gravehands","s","summon hands of the grave"}, {"Gravehands","b","banish hands of the grave"},
  {"Blackwind","w","blackwind"}, {"Blackwind","h","human"}, {"Blackwind","c","choke Bob"},
  {"Beckoning","","demon beckon"}, {"Beckoning","Alice","demon beckon Alice"},
  {"Shrivel","right leg","shrivel right leg Bob"},
}
for _,s in ipairs(samples) do
  clear(); matches={"",s[2]}; aliases[s[1]]()
  check(sent[1],"cq all"); check(sent[2],s[3]); check(#sent,2)
end
triggers["Pentagram present"](); check(A.pentagram,true)
triggers["Pentagram vanishes"](); check(A.pentagram,false)
triggers["Baalzadeen presence"](); check(A.baalzadeen,true)
triggers["Banished Baalzadeen"](); check(A.baalzadeen,false)
triggers["Demon taste cooldown"](); check(A.taste,false)
triggers["Demon taste ready"](); check(A.taste,true)
clear(); matches={"","p","Bob","2"}; aliases.Tracing()
matches={"","Bob"}; triggers["Demon bidding(Tracing)"]()
clear(); matches={"","Bob","Room one"}; triggers.Demontracing()
check(#sent,0); triggers.Demontracing(); check(sent[1],"pt Bob moved to Room one")
clear(); triggers["Tracing halt"](); check(sent[1],"pt Tracing off")
gmcp.Char.Status.class="Monk"; clear()
for _,s in ipairs(samples) do matches={"",s[2]}; aliases[s[1]]() end
check(#sent,0)
'@)
foreach ($n in $doc.SelectNodes('//*[name="Apostate"]//Alias | //*[name="Apostate"]//Trigger | //*[name="Apostate"]//Script')) {
  $code = $n.script.Replace(']====]', ']=====]')
  $lines.Add('assert(load([====[' + $code + ']====], "' + $n.name + '"))')
}
$lines.Add('print("PASS: Apostate utility commands, validation, tracing, lifecycle, packaged Lua syntax")')
($lines -join "`n") | & lua -
if ($LASTEXITCODE -ne 0) { throw 'Apostate Lua checks failed' }
$source = [IO.File]::ReadAllText((Join-Path $root 'Yso/xml/apostate_utilities.lua'))
if ($core.script.Trim() -cne $source.Trim()) { throw 'Apostate source/package mismatch' }
foreach ($name in @('Pentagram present','Pentagram vanishes')) {
  if ($doc.SelectSingleNode('//Trigger[name="' + $name + '"]').isActive -ne 'yes') { throw "$name is disabled" }
}
Write-Output 'PASS: XML parsing, source parity, pentagram trigger activation'
$examples = @{
  'Beckoning' = @('beck','beck Bob')
  'Shrivel' = @('shriv arms','shriv legs','shriv left arm','shriv right arm','shriv left leg','shriv right leg')
  'Tracing' = @('trace Bob','ptrace Bob 2','trace off')
}
foreach ($name in $examples.Keys) {
  $pattern = $doc.SelectSingleNode('//Alias[name="' + $name + '"]').regex
  foreach ($inputText in $examples[$name]) {
    if ($inputText -cnotmatch $pattern) { throw "Alias rejected: $inputText" }
  }
}
Write-Output 'PASS: packaged Beckoning, Shrivel, and Tracing alias patterns'
