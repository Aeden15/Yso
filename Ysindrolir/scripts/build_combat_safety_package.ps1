[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function Escape([string]$value){[Security.SecurityElement]::Escape($value)}
function Entry([string]$text,[string]$tag,[string]$name){
  $pattern='(?s)<'+$tag+'\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</'+$tag+'>'
  $found=[regex]::Matches($text,$pattern)
  if($found.Count -ne 1){throw "Expected exactly one $tag $name; found $($found.Count)"}
  $found[0]
}
function SetBody([string]$text,[string]$tag,[string]$name,[string]$body){
  $entry=Entry $text $tag $name
  $block=[regex]::Replace($entry.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+(Escape $body)+'</script>'},1)
  $text.Substring(0,$entry.Index)+$block+$text.Substring($entry.Index+$entry.Length)
}
function Script([string]$text,[string]$name,[string]$relative,[string]$after){
  $body=[IO.File]::ReadAllText((Join-Path $root $relative))
  if($text.Contains('<name>'+$name+'</name>')){return (SetBody $text 'Script' $name $body)}
  $anchor=Entry $text 'Script' $after
  $block='<Script isActive="yes" isFolder="no"><name>'+$name+'</name><packageName /><script>'+(Escape $body)+'</script><eventHandlerList /></Script>'
  $text.Insert($anchor.Index+$anchor.Length,$block)
}
function SetPattern([string]$text,[string]$name,[string]$pattern){
  $entry=Entry $text 'Trigger' $name
  $block=[regex]::Replace($entry.Value,'(?s)<regexCodeList>.*?</regexCodeList>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<regexCodeList><string>'+(Escape $pattern)+'</string></regexCodeList>'},1)
  $text.Substring(0,$entry.Index)+$block+$text.Substring($entry.Index+$entry.Length)
}
if(-not $PSCmdlet.ShouldProcess($PackagePath,'Synchronize Deliverance safety, resonance feedback and Magi aliases')){return}
& (Join-Path $PSScriptRoot 'build_mfocus_alias_body.ps1') | Out-Null
$text=[IO.File]::ReadAllText($PackagePath)
$text=Script $text 'Api stuff' 'Yso/xml/api_stuff.lua' ''
$text=Script $text 'Yso modes' 'Yso/xml/yso_modes.lua' ''
$text=Script $text 'Route registry' 'Yso/Combat/route_registry.lua' ''
$text=Script $text 'Magi group route retirement' 'Magi/retire_group_damage.lua' 'Route registry'
$text=Script $text 'Magi duel dam' 'Magi/Magi_duel_dam.lua' ''
$text=Script $text 'Enemy Deliverance safety' 'Yso/Combat/deliverance.lua' 'Api stuff'
$text=Script $text 'Magi resonance feedback' 'Magi/resonance_feedback.lua' 'Enemy Deliverance safety'
$text=SetBody $text 'Alias' 'mdam' ([IO.File]::ReadAllText((Join-Path $root 'Magi/mdam_retired_alias.lua')))
$text=SetBody $text 'Alias' 'mfocus' ([IO.File]::ReadAllText((Join-Path $root 'Magi/mfocus_alias_body.lua')))
$text=SetBody $text 'Trigger' 'Enemy Deliverance' @'
local D = Yso and Yso.Combat and Yso.Combat.Deliverance
if D and type(D.observe) == "function" then D.observe(matches[2], "channeling") end
'@
$text=SetBody $text 'Trigger' 'Enemy Deliverance stage 2' @'
local D = Yso and Yso.Combat and Yso.Combat.Deliverance
if D and type(D.observe) == "function" then D.observe(matches[2], "active") end
'@
$text=SetPattern $text 'Enemy Deliverance' '^([\w''-]+) bows (?:his|her|their|faes|faen) head in silent prayer\.$'
$text=SetPattern $text 'Enemy Deliverance stage 2' '^([\w''-]+) slowly raises (?:his|her|their|faes|faen)\s+head and you see (?:his|her|their|faes|faen) eyes glowing bright white\.$'
foreach($name in @('Mfocus resonance feedback','Mfocus resonance depleted')){
  $text=SetBody $text 'Trigger' $name @'
-- AK owns resonance levels; never call the retired route-local callbacks.
local F = Yso and Yso.magi and Yso.magi.resonance_feedback
if F and type(F.notice) == "function" then F.notice() end
'@
}
$text=SetBody $text 'Trigger' 'Mfocus resonance failure' @'
local F = Yso and Yso.magi and Yso.magi.resonance_feedback
if F and type(F.failure) == "function" then F.failure(matches[2], matches[3]) end
'@
$aliasBody=@'
local D = Yso and Yso.Combat and Yso.Combat.Deliverance
if D and type(D.command) == "function" then D.command(matches[2]) end
'@
if($text.Contains('<name>Deliverance safety</name>')){
  $text=SetBody $text 'Alias' 'Deliverance safety' $aliasBody
} else {
  $anchor=Entry $text 'Alias' 'Deliverance'
  $block='<Alias isActive="yes" isFolder="no"><name>Deliverance safety</name><script>'+(Escape $aliasBody)+'</script><command /><packageName /><regex>^deliverance (status|release)$</regex></Alias>'
  $text=$text.Insert($anchor.Index+$anchor.Length,$block)
}
[xml]$validated=$text
[IO.File]::WriteAllText($PackagePath,$text,(New-Object Text.UTF8Encoding $false))
