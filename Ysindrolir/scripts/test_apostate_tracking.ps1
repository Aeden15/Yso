param([string]$LogPath)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$ak=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/AK.xml'))
$yso=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/Yso system.xml'))
$tracking=$ak.SelectSingleNode('//Script[name="Apostate tracking"]')
if(-not $tracking){throw 'Missing Apostate tracking script'}
$shrivel=$ak.SelectSingleNode('//TriggerGroup[name="Apostate Group"]/TriggerGroup[name="Necromancy"]/Trigger[name="Apostate Shrivel"]')
if(-not $shrivel){throw 'Missing Apostate Necromancy Shrivel trigger'}
$h=[Collections.Generic.List[string]]::new()
$h.Add(@'
local now=100
getEpoch=function() return now end
local handlers={}
registerAnonymousEventHandler=function(e,f) handlers[e]=f;return e end
killAnonymousEventHandler=function() end
local active={}
enableTrigger=function(n) active[n]=true end
disableTrigger=function(n) active[n]=false end
enableKey=function() end;disableKey=function() end;cecho=function() end
target="Beltsa";gmcp={Char={Status={class="Apostate"}}}
ak={ai=function() return false end,defs={},occie={aura={mental=0,physical=0}},
 AddedAffReset=function() end,scoreup=function() end,echogain=function() end,echolost=function() end,
 defaultstack=function() end,getRace=function() return 'Human' end}
raiseEvent=function() end
affstrack={score={},mentallist={},physicallist={},venoms={}}
table.contains=function(t,x) for _,v in pairs(t) do if v==x then return true end end return false end
string.title=function(s) return s end
IsTargetted=function(n) return n and target and n:lower()==target:lower() end
local gained={}
OppGainedAff=function(a,source) for k in a:gmatch('%S+') do affstrack.score[k]=100;gained[#gained+1]={k,source} end end
local function reset()
 affstrack.score={};gained={}
 for _,k in ipairs({'deaf','impatience','clumsiness','vertigo','amnesia','agoraphobia','dizziness','paralysis',
 'claustrophobia','paranoia','blind','masochism','asthma','recklessness','epilepsy','confusion','pacifism',
 'dementia','manaleech','slickness','voyria','addiction','stupidity','sensitivity','nausea','sleep','anorexia',
 'weariness','leftarm','rightarm','leftleg','rightleg'}) do affstrack.score[k]=0 end
end
local function check(x,y) assert(x==y,tostring(x)..' ~= '..tostring(y)) end
reset()
'@)
$h.Add('assert(load([====['+$tracking.script+']====]))()')
$h.Add($ak.SelectSingleNode('//Script[name="oclass"]').script)
$h.Add(@'
ak.classenable();check(active['Apostate Group'],true);check(active['Occultist Group'],false)
local A=ak.apostate
for curse,aff in pairs(A.evileye_map) do
 reset();A.clear_pending(); A.capture_eye("Beltsa",curse); A.commit_eyes()
 check(affstrack.score[aff],100); check(gained[1][2],'evileye')
end
reset();A.capture_eye('Other','asthma');A.commit_eyes();check(#gained,0)
A.capture_eye('Beltsa','asthma');target='Other';A.commit_eyes();check(#gained,0);target='Beltsa'
reset(); A.capture_eye('Beltsa','sicken');A.commit_eyes();check(affstrack.score.manaleech,100)
A.capture_eye('Beltsa','sicken');A.commit_eyes();check(affstrack.score.slickness,100)
local count=#gained;A.capture_eye('Beltsa','sicken');A.commit_eyes();check(#gained,count)
reset();A.capture_eye('Beltsa','sicken');A.capture_eye('Beltsa','sicken');A.commit_eyes()
check(affstrack.score.manaleech,100);check(affstrack.score.slickness,100)
reset();A.capture_eye('Beltsa','asthma');A.capture_eye('Beltsa','anorexia');A.fail_eye();A.commit_eyes()
check(affstrack.score.asthma,100);check(affstrack.score.anorexia,0)
reset();for _,k in ipairs({'breach','sleep','fear','cowardice','bleed','sight','truestare','unknown'}) do
 A.capture_eye('Beltsa',k)
end;A.commit_eyes();check(#gained,0)
reset();A.shrivel('Beltsa','left','arm');check(affstrack.score.leftarm,100)
A.shrivel('Beltsa','left','arm');check(#gained,1)
A.shrivel('Other','right','arm');check(affstrack.score.rightarm,0)
A.shrivel('Beltsa','right','torso');check(#gained,1)
A.shrivel('Beltsa','arm');check(affstrack.score.rightarm,0)
check(A.shrivel_unresolved.beltsa.arms,1)
A.shrivel('Beltsa','leg');check(A.shrivel_unresolved.beltsa.legs,1)
check(affstrack.score.leftleg,0);check(affstrack.score.rightleg,0)
reset();A.capture_eye('Beltsa','asthma');handlers['yso.target.changed']();A.commit_eyes();check(#gained,0)
gmcp.Char.Status.class='Occultist';ak.classenable()
check(active['Apostate Group'],false);check(active['Occultist Group'],true)
gmcp.Char.Status.class='Apostate'
'@)
$h.Add($ak.SelectSingleNode('//Script[name="Hard Reset"]').script)
$h.Add($ak.SelectSingleNode('//Script[name="Soft Reset"]').script)
$h.Add(@'
disableTimer=function() end;killTimer=function() end
for _,key in ipairs({'magi','bard','pariah','dragon','bals','timers','druid','pervasion','shaman','track','duress'}) do
 ak[key]=ak[key] or {}
end
ak.psion={unweaving={},KillSecondaryTick=function() end}
ak.alchemist={humour={}};ak.limbs={limb_table_check=function() end}
ak.resetbacktrack=function() end;ak.classlockadd=function() end
ak.stack='test'
for _,method in ipairs({'oresetparse','softreset'}) do
 reset();A.capture_eye('Beltsa','asthma');A.shrivel('Beltsa','arm')
 ak[method]();A.commit_eyes()
 check(affstrack.score.asthma,0);check(A.shrivel_unresolved.beltsa,nil)
end
'@)
# Exercise the real AK score writer, including source-scoped Sensitivity and cure handling.
$h.Add($ak.SelectSingleNode('//Script[name="oscore edit functions"]').script)
$h.Add(@'
tempTimer=function() return 1 end;killTimer=function() end
ApK=function() end
reset();OppGainedAff('sensitivity','evileye');check(affstrack.score.sensitivity,100);check(affstrack.score.deaf,0)
reset();OppGainedAff('sensitivity');check(affstrack.score.deaf,100);check(affstrack.score.sensitivity,0)
for curse,aff in pairs(A.evileye_map) do
 reset();A.clear_pending();A.capture_eye('Beltsa',curse);A.commit_eyes()
 check(affstrack.score[aff],100);OppLostAff(aff);check(affstrack.score[aff],0)
end
reset();A.capture_eye('Beltsa','sicken');A.commit_eyes();OppLostAff('manaleech')
A.capture_eye('Beltsa','sicken');A.commit_eyes();check(affstrack.score.manaleech,100)
reset();A.shrivel('Beltsa','right','leg');check(affstrack.score.rightleg,100)
OppLostAff('rightleg');check(affstrack.score.rightleg,0)
-- Corrupt must not erase an affliction that was cured and re-applied elsewhere.
reset();A.reset_tracking();A.capture_eye('Beltsa','asthma');A.capture_eye('Beltsa','paralysis');A.commit_eyes()
OppLostAff('asthma');OppGainedAff('asthma')
A.consume_corrupt('Beltsa','paralysis');check(affstrack.score.asthma,100);check(affstrack.score.paralysis,100)
A.capture_eye('Beltsa','anorexia');A.commit_eyes();A.consume_corrupt('Beltsa',nil)
check(affstrack.score.anorexia,0);check(affstrack.score.paralysis,0);check(affstrack.score.asthma,100)
'@)
$h.Add('reset();matches={"","Beltsa"}')
$h.Add($ak.SelectSingleNode('//TriggerGroup[name="Obviously(i)"]/Trigger[name="Asleep"]').script)
$h.Add('check(affstrack.score.sleep,100);OppLostAff("sleep");check(affstrack.score.sleep,0)')
$h.Add('assert(load([====['+$yso.SelectSingleNode('//Script[name="Apostate reference"]').script+']====]))()')
$h.Add('assert(load([====['+$yso.SelectSingleNode('//Script[name="Deadeye combo sorter"]').script+']====]))()')
$h.Add('assert(load([====['+$yso.SelectSingleNode('//Script[name="Apostate utilities"]').script+']====]))()')
$h.Add(@'
local R=Yso.ref.apostate.evileye
local n=0;for _ in pairs(R.skills) do n=n+1 end;check(n,35)
check(R.skills.paralysis.abadmin_id,2940);check(R.skills.sicken.outcomes[1],'manaleech')
for curse,aff in pairs(A.evileye_map) do check(R.skills[curse].affliction,aff) end
local D=Yso.apostate.deadeyes
check(D.build('Beltsa','asthma','impatience'),'deadeyes Beltsa asthma impatience')
check(D.build('Beltsa;quit','asthma','impatience'),nil)
check(D.build('Beltsa','sight','asthma'),nil)
local f,s=D.select({'asthma','impatience','anorexia'},{asthma=100})
check(f,'impatience');check(s,'anorexia')
f,s=D.select({'sicken','manaleech','asthma'},{});check(f,'sicken');check(s,'asthma')
check(D.select({},{}),nil)
local sent={};sendAll=function(...) sent[#sent+1]={...} end
Yso.get_target=function() return target end
local C=Yso.apostate
check(C.note_mana('Beltsa',50,100),false);check(#sent,0)
check(C.note_mana('Other',49,100),false);check(#sent,0)
check(C.note_mana('Beltsa',1,0),false);check(#sent,0)
check(C.note_mana('Beltsa',499,1000),true);check(sent[1][1],'cq all');check(sent[1][2],'demon catharsis Beltsa')
check(C.note_mana('Beltsa',499,1000),false);check(#sent,1)
now=105;check(C.note_mana('Beltsa',499,1000),true);check(#sent,2)
gmcp.Char.Status.class='Monk';now=110;check(C.note_mana('Beltsa',1,100),false);check(#sent,2)
print('PASS: AK mappings, conditional effects, recipient isolation, failure batches, Shrivel, class gating, reference, Deadeyes, Catharsis')
'@)
($h -join "`n") | & lua -
if($LASTEXITCODE -ne 0){throw 'Apostate tracking Lua checks failed'}
if(-not $LogPath){$LogPath=Join-Path $root 'Apostate/fixtures/shrivel_responses.txt'}
if($LogPath){
 $html=[IO.File]::ReadAllText($LogPath)
 $plain=[Net.WebUtility]::HtmlDecode([regex]::Replace($html,'<[^>]+>',''))
 $outcomes=@(($plain -split '\r?\n') | Where-Object {$_ -match '^You (touch|reach out)' -and $_ -match 'shrivel|withers'})
 $matched=0;$sided=0
 $replay=[Collections.Generic.List[string]]::new()
 $replay.Add(@'
target='Beltsa';ak={ai=function() return false end};affstrack={score={}}
disableTrigger=function() end;enableTrigger=function() end
OppGainedAff=function(k) affstrack.score[k]=100 end
local function reset() affstrack.score={leftarm=0,rightarm=0,leftleg=0,rightleg=0} end
'@)
 $replay.Add('assert(load([====['+$tracking.script+']====]))()')
 $nodes=$ak.SelectNodes('//TriggerGroup[name="Apostate Group"]/TriggerGroup[name="Necromancy"]/Trigger')
 foreach($line in $outcomes){
  $found=$false
  foreach($node in $nodes){
   foreach($pattern in $node.regexCodeList.string){if($line -cmatch $pattern){
    $found=$true;$sideSpecific=$Matches.Count -ge 4
    if($sideSpecific){$sided++}
    $values=@();for($i=0;$i -lt $Matches.Count;$i++){$values+='[====['+$Matches[$i]+']====]'}
    $replay.Add('reset();matches={'+($values -join ',')+'}')
    $replay.Add('assert(load([====['+$node.script+']====]))()')
    if($sideSpecific){$key=$Matches[2]+$Matches[3];$replay.Add('assert(affstrack.score["'+$key+'"]==100)')}
    else{$replay.Add('for _,v in pairs(affstrack.score) do assert(v==0) end')}
    break
   }}
   if($found){break}
  }
  if(-not $found){throw "Missed Shrivel response: $line"};$matched++
 }
 if($matched -ne 15 -or $sided -ne 7){throw "Unexpected replay coverage: $matched total / $sided sided"}
 $replay.Add('assert(ak.apostate.shrivel_unresolved.beltsa.arms==4);assert(ak.apostate.shrivel_unresolved.beltsa.legs==4)')
 ($replay -join "`n") | & lua -
 if($LASTEXITCODE -ne 0){throw 'Shrivel packaged adapter replay failed'}
 Write-Output "PASS: all $matched log responses matched ($sided side-specific; 8 unresolved)"
}
foreach($document in @($ak,$yso)){
 foreach($node in $document.SelectNodes('//Script[name="Apostate tracking"] | //Script[name="Apostate reference"] | //Script[name="Apostasy reference"] | //Script[name="Necromancy reference"] | //Script[name="Deadeye combo sorter"] | //TriggerGroup[name="Apostate Group"]//Trigger | //Trigger[name="Catharsis"]')){
  ('assert(load([====['+$node.script+']====]))') | & lua -
  if($LASTEXITCODE -ne 0){throw "Invalid packaged Lua: $($node.name)"}
 }
}
Write-Output 'PASS: both XML packages parse; modified/new packaged Lua compiles'
$cath=$yso.SelectSingleNode('//Trigger[name="Catharsis"]')
if($cath.isActive -ne 'yes'){throw 'Catharsis trigger is disabled'}
if("Beltsa's mana stands at 499/1000 [49%]." -cnotmatch $cath.regexCodeList.string){throw 'Catharsis does not match captured report format'}
if('(Party): Beltsa''s mana stands at 1/100 [1%].' -cmatch $cath.regexCodeList.string){throw 'Catharsis accepts chat text'}
foreach($entry in @(@($ak,'Apostate tracking','Apostate/ak_tracking.lua'),@($yso,'Apostate reference','Apostate/evileye_reference.lua'),@($yso,'Apostasy reference','Apostate/apostasy_reference.lua'),@($yso,'Necromancy reference','Apostate/necromancy_reference.lua'),@($yso,'Deadeye combo sorter','Apostate/deadeyes.lua'),@($yso,'Apostate utilities','Yso/xml/apostate_utilities.lua'))){
 if($entry[0].SelectSingleNode('//Script[name="'+$entry[1]+'"]').script.Trim() -cne [IO.File]::ReadAllText((Join-Path $root $entry[2])).Trim()){
  throw ('Source/package mismatch: '+$entry[1])
 }
}
Write-Output 'PASS: Catharsis activation/report pattern and all six source/package mappings'
