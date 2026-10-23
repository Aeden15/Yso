# Synchronize only the agreed Apostate entries in AK.xml and Yso system.xml.
[CmdletBinding(SupportsShouldProcess=$true)]
param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function Escape([string]$s){[Security.SecurityElement]::Escape($s)}
function Set-Body([string]$text,[string]$type,[string]$name,[string]$body){
 $pattern='(?s)<'+$type+'\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</'+$type+'>'
 $hits=[regex]::Matches($text,$pattern)
 if($hits.Count -ne 1){throw "Expected unique $type $name"}
 $block=$hits[0].Value
 $escaped=Escape $body
 $new=[regex]::Replace($block,'(?s)<script(?:\s*/>|>.*?</script>)',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+$escaped+'</script>'},1)
 return $text.Substring(0,$hits[0].Index)+$new+$text.Substring($hits[0].Index+$block.Length)
}
function New-Script([string]$name,[string]$body){
 return '<Script isActive="yes" isFolder="no"><name>'+$name+'</name><packageName /><script>'+(Escape $body)+'</script><eventHandlerList /></Script>'
}
function New-Trigger($doc,[string]$name,[string]$body,[string[]]$patterns){
 $n=$doc.SelectSingleNode('//Trigger[name="Shrivel"]').CloneNode($true)
 $n.name=$name;$n.script=$body
 $regexList=$n.SelectSingleNode('regexCodeList');$propertyList=$n.SelectSingleNode('regexCodePropertyList')
 $regexList.RemoveAll();$propertyList.RemoveAll()
 foreach($p in $patterns){
  $s=$doc.CreateElement('string');$s.InnerText=$p;[void]$regexList.AppendChild($s)
  $v=$doc.CreateElement('integer');$v.InnerText='1';[void]$propertyList.AppendChild($v)
 }
 return $n.OuterXml
}
$akPath=Join-Path $root 'mudlet packages/AK.xml'
$ysoPath=Join-Path $root 'mudlet packages/Yso system.xml'
$akText=[IO.File]::ReadAllText($akPath);$akDoc=[xml]$akText
$oldOccultist=$akDoc.SelectSingleNode('//TriggerGroup[name="Occultist Group"]').OuterXml
$akText=Set-Body $akText Script 'Target Check' ([IO.File]::ReadAllText((Join-Path $root 'Apostate/ak_target_check.lua')))
$akSource=[IO.File]::ReadAllText((Join-Path $root 'Apostate/ak_tracking.lua'))
if($akDoc.SelectSingleNode('//Script[name="Apostate tracking"]')){
 $akText=Set-Body $akText Script 'Apostate tracking' $akSource
}else{
 $akText=$akText.Replace('</ScriptPackage>',(New-Script 'Apostate tracking' $akSource)+"`n</ScriptPackage>")
}
$akText=Set-Body $akText Trigger 'Deadeyes' 'ak.apostate.capture_eye(matches[3], matches[2])'
$akText=Set-Body $akText Trigger 'Clumsy Brick' 'ak.apostate.fail_eye()'
$akText=Set-Body $akText Trigger 'Curse Pull Dump' 'ak.apostate.commit_eyes()'
# The generic eye announcement now owns Sicken; remove its overlapping outcome inference.
$akText=Set-Body $akText Trigger 'Sicken' '-- Sicken is resolved once by Apostate tracking from the confirmed evileye batch.'
$gain=$akDoc.SelectSingleNode('//Script[name="oscore edit functions"]').script
if(-not $gain.Contains('source ~= "evileye"')){
 $old='and affstrack.score.deaf == 0 then'
 if(([regex]::Matches($gain,[regex]::Escape($old))).Count -ne 2){throw 'Unexpected AK Sensitivity writer shape'}
 $gain=$gain.Replace($old,'and affstrack.score.deaf == 0 and source ~= "evileye" then')
}
$gain=$gain.Replace('if (word == "deaf" or word == "sensitivity") then','if (word == "deaf" or word == "sensitivity") and source ~= "evileye" then')
$gain=$gain.Replace('if aff == "deaf" or aff == "sensitivity" then','if (aff == "deaf" or aff == "sensitivity") and source ~= "evileye" then')
$gain=$gain.Replace('if #affStr > 0 and not source then','if #affStr > 0 and (not source or source == "evileye") then')
if(-not $gain.Contains('ak.apostate.note_gain(aff,source)')){
 $gain=$gain.Replace('function OppGainedAff(aff,source)',"function OppGainedAff(aff,source)`n  if ak.apostate and ak.apostate.note_gain then ak.apostate.note_gain(aff,source) end")
 $gain=$gain.Replace('function OppLostAff(aff)',"function OppLostAff(aff)`n  if ak.apostate and ak.apostate.note_loss then ak.apostate.note_loss(aff) end")
}
$akText=Set-Body $akText Script 'oscore edit functions' $gain
foreach($resetEntry in @(@('Hard Reset','ak.oresetparse'),@('Soft Reset','ak.softreset'))){
 $body=$akDoc.SelectSingleNode('//Script[name="'+$resetEntry[0]+'"]').script
 if(-not $body.Contains('ak.apostate.reset_tracking()')){
  $needle='function '+$resetEntry[1]+'()'
  if(-not $body.Contains($needle)){throw ('Missing reset function: '+$resetEntry[1])}
  $body=$body.Replace($needle,$needle+"`n"+'  if ak.apostate and type(ak.apostate.reset_tracking) == "function" then ak.apostate.reset_tracking() end')
 }
 $akText=Set-Body $akText Script $resetEntry[0] $body
}
# Reset coordination is called directly; the old visual diagnostic is unnecessary.
$resetDoc=[xml]$akText
$hardReset=$resetDoc.SelectSingleNode('//Script[name="Hard Reset"]').script
$hardReset=$hardReset.Replace('  cecho("<cyan> Reset Success!\n\n")','')
$akText=Set-Body $akText Script 'Hard Reset' $hardReset
$akDoc=[xml]$akText
$eye=$akDoc.SelectSingleNode('//TriggerGroup[name="Apostate Group"]/Trigger[name="Deadeyes"]')
$eye.regexCodeList.string="^Summoning up the curse of (\w+), you stare at ([\w'-]+), giving \w+ the evil eye\.$"
# Replace the trigger block only, preserving unrelated package formatting.
$pattern='(?s)<Trigger\b[^>]*>\s*<name>Deadeyes</name>.*?</Trigger>'
$akText=[regex]::Replace($akText,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m) $eye.OuterXml},1)
$shrivelBody='ak.apostate.shrivel(matches[2], matches[3], matches[4] ~= "" and matches[4] or nil)'
$shrivelPatterns=@(
 "^You touch ([\w'-]+)'s (left|right) (arm|leg), and it shrivels away\.$",
 "^You reach out and touch ([\w'-]+)'s (left|right) (arm|leg), but you can shrivel it no further\.$",
 "^You reach out and stroke an (arm) of ([\w'-]+), and it withers away\.$",
 "^You reach out and grasp ([\w'-]+)'s (leg) in an iron grip, and it shrivels feebly\.$"
)
# All patterns share recipient, limb-kind, optional side captures. The unsided arm
# message has reversed word order, so a separate adapter keeps captures unambiguous.
$sided=New-Trigger $akDoc 'Apostate Shrivel' $shrivelBody @($shrivelPatterns[0],$shrivelPatterns[1],$shrivelPatterns[3])
$arms=New-Trigger $akDoc 'Apostate Shrivel arms' 'ak.apostate.shrivel(matches[3], matches[2])' @($shrivelPatterns[2])
$akDoc=[xml]$akText
$necro=$akDoc.SelectSingleNode('//TriggerGroup[name="Apostate Group"]/TriggerGroup[name="Necromancy"]')
if(-not $necro){
 $necro=$akDoc.SelectSingleNode('//TriggerGroup[name="Apostate Group"]').CloneNode($true)
 foreach($child in @($necro.SelectNodes('./Trigger | ./TriggerGroup'))){[void]$necro.RemoveChild($child)}
 $necro.name='Necromancy';$necro.SetAttribute('isActive','yes')
}
$newGroup=$necro.OuterXml.Replace('</TriggerGroup>',$sided+$arms+'</TriggerGroup>')
if($akDoc.SelectSingleNode('//Trigger[name="Apostate Shrivel"]')){
 $pattern='(?s)<TriggerGroup\b[^>]*>\s*<name>Necromancy</name>.*?</TriggerGroup>'
 # Rebuild only our two maintained triggers, not arbitrary additions in this folder.
 $newGroup=[regex]::Replace($necro.OuterXml,'(?s)<Trigger\b[^>]*>\s*<name>Apostate Shrivel(?: arms)?</name>.*?</Trigger>','')
 $newGroup=$newGroup.Replace('</TriggerGroup>',$sided+$arms+'</TriggerGroup>')
 $akText=[regex]::Replace($akText,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m) $newGroup},1)
}else{
 $dump=[regex]::Match($akText,'(?s)<Trigger\b[^>]*>\s*<name>Curse Pull Dump</name>.*?</Trigger>')
 if(-not $dump.Success){throw 'Cannot locate Apostate group insertion point'}
 $akText=$akText.Insert($dump.Index+$dump.Length,"`n"+$newGroup)
}
# An unsided exhausted response confirms the whole matching limb pair.
$akText=[regex]::Replace($akText,'(?s)<Trigger\b[^>]*>\s*<name>Shrivel (?:arms|legs)</name>.*?</Trigger>','')
$exhaustedDoc=[xml]$akText
$exhaustedGroup=$exhaustedDoc.SelectSingleNode('//TriggerGroup[name="Apostate Group"]/TriggerGroup[name="Necromancy"]')
$exhausted=''
foreach($limb in @('arm','leg')){
 $exhausted+=New-Trigger $exhaustedDoc ('Shrivel '+$limb+'s') ('ak.apostate.shrivel_exhausted(matches[2], "'+$limb+'")') @("^You reach out and touch ([\w'-]+)'s "+$limb+", but you can shrivel it no further\.$")
}
$groupText=$exhaustedGroup.OuterXml.Replace('</TriggerGroup>',$exhausted+'</TriggerGroup>')
$akText=[regex]::Replace($akText,'(?s)<TriggerGroup\b[^>]*>\s*<name>Necromancy</name>.*?</TriggerGroup>',[Text.RegularExpressions.MatchEvaluator]{param($m) $groupText},1)
$newAk=[xml]$akText
if($newAk.SelectSingleNode('//TriggerGroup[name="Occultist Group"]').OuterXml -cne $oldOccultist){throw 'Occultist group changed'}
# Confirmations are adapters only; the maintained Lua owns state transitions.
$adapters=@(
 @('Apostate Puncture','ak.apostate.puncture(matches[2])',@("^Your hand guided by the daemon held in its grasp, you puncture ([\w'-]+)'s skin with the daegger's tip\.$")),
 @('Apostate Corrupt accepted','local M=Yso and Yso.off and Yso.off.apostate and Yso.off.apostate.truelock; if M then M.note_corrupt("accepted",matches[2]) end',@("^You command your baalzadeen to corrupt the soul of ([\w'-]+)\.$")),
 @('Apostate Corrupt rejected','local M=Yso and Yso.off and Yso.off.apostate and Yso.off.apostate.truelock; if M then M.note_corrupt("rejected",matches[2]) end',@("^Your demon is unable to corrupt the soul of ([\w'-]+)\.$")),
 @('Apostate Corrupt retained','local M=Yso and Yso.off and Yso.off.apostate and Yso.off.apostate.truelock; if M then M.note_corrupt("retained",matches[3],matches[2]) end',@("^Your Baalzadeen informs you that the (\w+) affliction still burdens ([\w'-]+)\.$")),
 @('Apostate route prompt','local M=Yso and Yso.off and Yso.off.apostate and Yso.off.apostate.truelock; if M then M.note_prompt() end',@(''))
)
foreach($entry in $adapters){
 $akText=[regex]::Replace($akText,'(?s)<Trigger\b[^>]*>\s*<name>'+[regex]::Escape($entry[0])+'</name>.*?</Trigger>','')
 $node=[xml](New-Trigger $newAk $entry[0] $entry[1] $entry[2])
 $node.Trigger.SetAttribute('isActive','yes')
 if($entry[0] -eq 'Apostate route prompt'){$node.Trigger.regexCodePropertyList.integer='7'}
 $anchor=[regex]::Match($akText,'(?s)<Trigger\b[^>]*>\s*<name>Curse Pull Dump</name>.*?</Trigger>')
 $akText=$akText.Insert($anchor.Index+$anchor.Length,$node.OuterXml)
}
$newAk=[xml]$akText
$envenom=$newAk.SelectSingleNode('//Trigger[name="Weapon Envenomed"]').script
if(-not $envenom.Contains('note_application')){
 $envenom += "`n"+'if Yso and Yso.apostate and Yso.apostate.daegger then Yso.apostate.daegger.note_application(matches[2],matches[3]) end'
}
$akText=Set-Body $akText Trigger 'Weapon Envenomed' $envenom
$wipe=$newAk.SelectSingleNode('//Trigger[name="Venom Wipe/Reset/Gagging"]')
$wipe.script=@'
local text=matches[1] or ''
local weapon=text:match('^Being careful not to poison yourself, you wipe off all the venoms from (.+)%.$')
if text=='You carefully wipe the venoms from your claws.' then weapon='your wickedly sharp claws' end
ak.apostate.wipe(weapon)
ak.deleteFull()
'@
$wipePatterns=@('^Being careful not to poison yourself, you wipe off all the venoms from (.+)\.$','^There are no venoms on that item at present\.$','^You carefully wipe the venoms from your claws\.$','^You are already wielding ')
$wipeRegex=$wipe.SelectSingleNode('regexCodeList');$wipeProperties=$wipe.SelectSingleNode('regexCodePropertyList')
$wipeRegex.RemoveAll();$wipeProperties.RemoveAll()
foreach($p in $wipePatterns){$s=$newAk.CreateElement('string');$s.InnerText=$p;[void]$wipeRegex.AppendChild($s);$v=$newAk.CreateElement('integer');$v.InnerText='1';[void]$wipeProperties.AppendChild($v)}
$akText=[regex]::Replace($akText,'(?s)<Trigger\b[^>]*>\s*<name>Venom Wipe/Reset/Gagging</name>.*?</Trigger>',[Text.RegularExpressions.MatchEvaluator]{param($m) $wipe.OuterXml},1)
$ysoText=[IO.File]::ReadAllText($ysoPath)
$ysoDoc=[xml]$ysoText
foreach($entry in @(@('Apostate reference','Apostate/evileye_reference.lua'),@('Apostasy reference','Apostate/apostasy_reference.lua'),@('Necromancy reference','Apostate/necromancy_reference.lua'),@('Deadeye combo sorter','Apostate/deadeyes.lua'),@('Apostate utilities','Yso/xml/apostate_utilities.lua'))){
 $body=[IO.File]::ReadAllText((Join-Path $root $entry[1]))
 if($entry[0] -in @('Apostate reference','Apostasy reference','Necromancy reference') -and -not $ysoDoc.SelectSingleNode('//Script[name="'+$entry[0]+'"]')){
  $anchor=[regex]::Match($ysoText,'<Script\b[^>]*>\s*<name>Apostate utilities</name>')
  if(-not $anchor.Success){throw 'Missing Apostate utilities insertion point'}
  $ysoText=$ysoText.Insert($anchor.Index,(New-Script $entry[0] $body)+"`n")
 }else{$ysoText=Set-Body $ysoText Script $entry[0] $body}
}
foreach($entry in @(@('Apostate daegger envenom','Apostate/daegger_envenom.lua'),@('Apostate Truelocks','Apostate/truelock.lua'))){
 $body=[IO.File]::ReadAllText((Join-Path $root $entry[1]))
 if(([xml]$ysoText).SelectSingleNode('//Script[name="'+$entry[0]+'"]')){$ysoText=Set-Body $ysoText Script $entry[0] $body}
 else{
  $anchor=[regex]::Match($ysoText,'(?s)<Script\b[^>]*>\s*<name>Apostate utilities</name>.*?</Script>')
  $ysoText=$ysoText.Insert($anchor.Index+$anchor.Length,(New-Script $entry[0] $body)+"`n")
 }
}
$registry=[IO.File]::ReadAllText((Join-Path $root 'Yso/Combat/route_registry.lua'))
$ysoText=Set-Body $ysoText Script 'Route registry' $registry
$aliasBody="Yso.util.toggle_route_alias('apostate_truelock', 'tlock')"
if(([xml]$ysoText).SelectSingleNode('//Alias[name="Truelocks"]')){$ysoText=Set-Body $ysoText Alias 'Truelocks' $aliasBody}
else{
 $anchor=[regex]::Match($ysoText,'(?s)<Alias\b[^>]*>\s*<name>Tracing</name>.*?</Alias>')
 $alias='<Alias isActive="yes" isFolder="no"><name>Truelocks</name><script>'+(Escape $aliasBody)+'</script><command /><packageName /><regex>^tlock$</regex></Alias>'
 $ysoText=$ysoText.Insert($anchor.Index,$alias)
}
$ysoText=Set-Body $ysoText Trigger 'Catharsis' 'Yso.apostate.note_mana(matches[2], matches[3], matches[4])'
$cathPattern='(?s)<Trigger\b[^>]*>\s*<name>Catharsis</name>.*?</Trigger>'
$cath=[regex]::Match($ysoText,$cathPattern).Value
$cath=$cath.Replace('isActive="no"','isActive="yes"')
$regex="^([\w'-]+)'s mana stands at (\d+)/(\d+) \[\d+%\]\.$"
$cath=[regex]::Replace($cath,'(?s)<regexCodeList\s*/>|<regexCodeList>.*?</regexCodeList>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<regexCodeList><string>'+(Escape $regex)+'</string></regexCodeList>'},1)
$cath=[regex]::Replace($cath,'(?s)<regexCodePropertyList\s*/>|<regexCodePropertyList>.*?</regexCodePropertyList>','<regexCodePropertyList><integer>1</integer></regexCodePropertyList>',1)
$ysoText=[regex]::Replace($ysoText,$cathPattern,[Text.RegularExpressions.MatchEvaluator]{param($m) $cath},1)
# Keep the summon failure beside the existing Apostasy presence triggers.
$ysoText=[regex]::Replace($ysoText,'(?s)<Trigger\b[^>]*>\s*<name>Nightmare unavailable</name>.*?</Trigger>','')
$nightmareDoc=[xml]$ysoText
$template=$nightmareDoc.SelectSingleNode('//TriggerGroup[name="Apostate"]/TriggerGroup[name="Apostasy"]/Trigger[name="Banished Baalzadeen"]')
if(-not $template){throw 'Missing Apostate/Apostasy trigger insertion point'}
$nightmare=$template.CloneNode($true)
$nightmare.name='Nightmare unavailable'
$nightmare.script='yso.apostate.nightmare = false'
$nightmare.SetAttribute('isActive','yes')
$nightmare.regexCodeList.InnerXml='<string>^A nightmare may only be summoned in the slumber of night\.$</string>'
$nightmare.regexCodePropertyList.InnerXml='<integer>1</integer>'
$anchor=[regex]::Match($ysoText,'(?s)<Trigger\b[^>]*>\s*<name>Banished Baalzadeen</name>.*?</Trigger>')
if(-not $anchor.Success){throw 'Missing Banished Baalzadeen trigger text'}
$ysoText=$ysoText.Insert($anchor.Index+$anchor.Length,"`n"+$nightmare.OuterXml)
$ysoText=[regex]::Replace($ysoText,'(?s)<Trigger\b[^>]*>\s*<name>Truelocks eye rejected</name>.*?</Trigger>','')
$eyeRejected=$template.CloneNode($true)
$eyeRejected.name='Truelocks eye rejected'
$eyeRejected.script=[IO.File]::ReadAllText((Join-Path $root 'Apostate/eye_rejected.lua'))
$eyeRejected.SetAttribute('isActive','yes')
$eyeRejected.regexCodeList.InnerXml=@'
<string>^You must regain (equilibrium|balance) first\.$</string>
<string>^You cannot use the evil eye while blind\.$</string>
<string>^You try to curse ([\w'-]+), but [\w'-]+ is warded\.$</string>
<string>^You stare at ([\w'-]+), giving [\w'-]+ the evil eye, but [\w'-]+ is warded\.$</string>
'@
$eyeRejected.regexCodePropertyList.InnerXml='<integer>1</integer><integer>1</integer><integer>1</integer><integer>1</integer>'
$anchor=[regex]::Match($ysoText,'(?s)<Trigger\b[^>]*>\s*<name>Nightmare unavailable</name>.*?</Trigger>')
$ysoText=$ysoText.Insert($anchor.Index+$anchor.Length,"`n"+$eyeRejected.OuterXml)
# Taste summaries use the existing Apostasy palette and leave the rest of Taste intact.
foreach($entry in @(
 @('TRACING',"^Your Baalzadeen is tracing the movements of ([\w'-]+)\.$"),
 @('MINDREADING','^Your Baalzadeen is reading the minds of those nearby\.$'),
 @('SYPHON','^Your Baalzadeen is syphoning that which afflicts you\.$')
)){
 $name='Demon taste '+$entry[0]
 $ysoText=[regex]::Replace($ysoText,'(?s)<Trigger\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</Trigger>','')
 $taste=$template.CloneNode($true);$taste.name=$name;$taste.SetAttribute('isActive','yes')
 $taste.script='deleteLine()'+"`n"+'cecho("\n<DeepPink>[Apostasy] <violet_red>'+$entry[0]+'<reset>\n")'
 $taste.regexCodeList.InnerXml='<string>'+(Escape $entry[1])+'</string>'
 $taste.regexCodePropertyList.InnerXml='<integer>1</integer>'
 $anchor=[regex]::Match($ysoText,'(?s)<Trigger\b[^>]*>\s*<name>Banished Baalzadeen</name>.*?</Trigger>')
 $ysoText=$ysoText.Insert($anchor.Index+$anchor.Length,$taste.OuterXml)
}
[void][xml]$ysoText
if($PSCmdlet.ShouldProcess('AK.xml and Yso system.xml','Synchronize Apostate tracking, reference, Deadeyes helpers, and Catharsis')){
 [IO.File]::WriteAllText($akPath,$akText,[Text.UTF8Encoding]::new($false))
 [IO.File]::WriteAllText($ysoPath,$ysoText,[Text.UTF8Encoding]::new($false))
}
