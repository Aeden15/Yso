param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'),
  [string]$AkPackagePath=(Join-Path (Split-Path $PackagePath -Parent) 'AK.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
[xml]$y=[IO.File]::ReadAllText($PackagePath)
[xml]$a=[IO.File]::ReadAllText($AkPackagePath)
$helper=$y.SelectSingleNode('//Script[name="Magi spell feedback"]/script')
if(-not $helper){throw 'Installed Magi spell feedback is missing'}
$h=[Collections.Generic.List[string]]::new()
$h.Add('local root=[====['+$root.Replace('\','/')+'/]====]')
$h.Add(@'
local target,ai,clock,timers,gains='Foe',false,10000,{},0
function getEpoch() return clock end
function tempTimer(_,fn) timers[#timers+1]=fn;return #timers end
function killTimer() end
function cecho() end
function raiseEvent() end
function IsTargetted(who) return who==target end
table.contains=function(t,x) for _,v in pairs(t) do if v==x then return true end end return false end
string.title=function(s) return s end
Yso={off={magi={}},get_target=function() return target end,target_is_valid=function() return true end}
dofile(root..'Magi/magi_route_core.lua')
ak={ai=function() return ai end,defs={},magi={resonance={Water=3,Air=3,Earth=3,Fire=3}},
  occie={aura={mental=0,physical=0}},scoreup=function() end,AddedAffReset=function() gains=gains+1 end,
  echogain=function() end,echolost=function() end}
affstrack={score={},mentallist={},physicallist={},venoms={}}
local function reset()
  target,ai,timers,gains='Foe',false,{},0
  affstrack.score={frozen=200,aflame=0,hypothermia=0,nausea=0,weariness=0,fulminated=0,
    epilepsy=0,paralysis=0,scalded=0,blisters=0,conflagrate=0,disrupt=0,stuttering=0,
    leftarm=0,rightarm=0,leftleg=0,rightleg=0,prone=0,calcifiedhead=0,blind=100}
  ak.magi.resonance={Water=3,Air=3,Earth=3,Fire=3}
end
local function check(ok,label) assert(ok,label) end
'@)
$h.Add($a.SelectSingleNode('//Script[name="oscore edit functions"]').script)
$h.Add('local T=assert(load([====['+$helper.InnerText+']====]))()')
# Compile the real flame helper as well, preserving its stack cap behavior.
$flame=$a.SelectNodes('//Script') | Where-Object { [string]$_.script -match 'function ak.flameon\(' } | Select-Object -First 1
$h.Add([string]$flame.script)
$all=@($y.SelectNodes('//Trigger'))+@($a.SelectNodes('//Trigger'))
$a.SelectSingleNode('//TriggerGroup[name="Magi Group"]').SetAttribute('isActive','yes')
function Dispatch([string]$line){
  $hits=@()
  foreach($node in $all){
    if($node.GetAttribute('isActive') -ne 'yes'){continue}
    $ancestor=$node.ParentNode;$enabled=$true
    while($ancestor -and $ancestor.NodeType -eq 'Element'){
      if($ancestor.Attributes['isActive'] -and $ancestor.GetAttribute('isActive') -eq 'no'){$enabled=$false;break}
      $ancestor=$ancestor.ParentNode
    }
    if(-not $enabled -or $node.GetAttribute('isMultiline') -eq 'yes'){continue}
    $body=[string]$node.script
    if($body -notmatch 'spell_feedback|OppGainedAff|ak\.flameon'){continue}
    $patterns=@($node.regexCodeList.string);$properties=@($node.regexCodePropertyList.integer)
    for($i=0;$i -lt $patterns.Count;$i++){
      if([int]$properties[$i] -ne 1){continue}
      try{$match=[regex]::Match($line,[string]$patterns[$i])}catch{continue}
      if($match.Success){$hits+=@{Node=$node;Match=$match};break}
    }
  }
  if($hits.Count -ne 1){throw ('Expected one state-writing confirmation for: '+$line+'; found '+$hits.Count+': '+(($hits | ForEach-Object {[string]$_.Node.name}) -join ', '))}
  $hit=$hits[0]
  $groups=@($hit.Match.Groups | ForEach-Object {'[====['+$_.Value+']====]'})
  $h.Add('matches={'+($groups -join ',')+'};assert(load([====['+[string]$hit.Node.script+']====]))()')
}
function Case([string]$line,[string]$assertion){$h.Add('reset()');Dispatch $line;$h.Add('check('+ $assertion +',[====['+$line+']====])')}
Case 'You blast Foe with an icy stream of water, and he begins to shiver uncontrollably.' 'affstrack.score.hypothermia==100 and affstrack.score.frozen==200'
$h.Add('OppLostAff("hypothermia");check(affstrack.score.hypothermia==0,"existing AK cure path")')
Case 'Ally blasts Foe with an icy stream of water, and he begins to shake and shiver uncontrollably.' 'affstrack.score.hypothermia==100'
Case 'You blast Other with an icy stream of water, and he begins to shiver uncontrollably.' 'affstrack.score.hypothermia==0'
$h.Add('reset();ai=true')
Dispatch 'You blast Foe with an icy stream of water, and he begins to shiver uncontrollably.'
$h.Add('check(affstrack.score.hypothermia==0,"AI guard")')
Case 'You raise a hand towards Foe and blast him with cold, frigid air.' 'affstrack.score.frozen==300'
Case 'You raise a hand towards Other and blast him with cold, frigid air.' 'affstrack.score.frozen==200'
Case 'Weaving the elements of fire and water, you attempt to rip the excess water from the body of Foe.' 'affstrack.score.nausea==0 and affstrack.score.weariness==0'
Case 'The skin of Foe begins to dry and crack as he grows pale.' 'affstrack.score.nausea==100 and affstrack.score.weariness==100'
Case 'You rip the heat from Foe.' 'affstrack.score.frozen==300 and affstrack.score.nausea==100 and affstrack.score.weariness==100'
Case "You fan the heat of Foe's body into consuming flame." 'affstrack.score.aflame==100 and affstrack.score.frozen==200'
Case 'You form a lash of fire, and send it to scorch the flesh of Foe.' 'affstrack.score.aflame==100'
Case 'Flames ignite all over the body of Foe, fanned to intensity in an instant.' 'affstrack.score.aflame==100'
Case 'The might of elemental Water surging through your body, you make the slightest flick with your staff, and the hand of Sllshya descends as a freezing deluge to smash Foe.' 'affstrack.score.frozen==300 and affstrack.score.disrupt==100 and affstrack.score.stuttering==0 and ak.magi.resonance.Water==0'
Case 'The might of elemental Earth thrumming within your bones, you point your staff at Foe and an intangible wave of power strikes forth to smite him.' 'ak.magi.resonance.Earth==0 and affstrack.score.calcifiedhead==0 and T.observed.foe.calcifiedtorso_at~=nil'
Case 'You bend your will upon Foe, and command that he burn.' 'affstrack.score.conflagrate==100 and affstrack.score.aflame==200'
Case 'Ally lifts a hand towards Foe and in an instant raging flames manifest to devour his victim.' 'affstrack.score.conflagrate==100 and affstrack.score.aflame==200'
Case 'You bend your will upon Foe, attempting to rouse a conflagration to consume him, but to no avail.' 'affstrack.score.conflagrate==0 and affstrack.score.aflame==0'
Case 'The conflagration about Foe continues to rage, searing flesh from bone.' 'affstrack.score.aflame==100 and ak.healthpercent==nil'
Case 'You hear two loud snaps and see Foe fall to the ground.' 'affstrack.score.leftleg==100 and affstrack.score.rightleg==100 and affstrack.score.prone==100'
Case 'The incandescent might of Elemental Fire filling you, you command Foe to burn from within.' 'affstrack.score.blisters==100'
$h.Add('for _,callback in ipairs(timers) do check(type(callback)=="function","unsafe old blisters timer still used") end')
$h.Add('reset();ak.defs.shield=true')
Dispatch 'You cast a spell of erosion at Foe.'
$h.Add('check(ak.defs.shield==true,"erosion attempt predicted shield removal")')
Dispatch 'His shield defence is eroded away.'
$h.Add('check(ak.defs.shield==false,"named bounded erosion result")')
$h.Add('print("PASS: cross-package response ownership, actual AK gains/cures, current Hypothermia and guarded outcomes")')
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('magi-feedback-tracking-'+[guid]::NewGuid()+'.lua')
try{
  [IO.File]::WriteAllText($tmp,($h -join "`n"),[Text.UTF8Encoding]::new($false))
  & lua $tmp
  if($LASTEXITCODE -ne 0){throw 'Magi feedback/AK integration failed'}
}finally{Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue}
