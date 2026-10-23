[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'),
  [string]$LimbPackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/limb.1.2.xml')
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function Escape([string]$value) { [Security.SecurityElement]::Escape($value) }
function Body([string]$path) { Escape ([IO.File]::ReadAllText((Join-Path $root $path)).TrimEnd()) }
function Entry([string]$text,[string]$tag,[string]$name) {
  $pattern='(?s)<'+$tag+'\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</'+$tag+'>'
  $found=[regex]::Matches($text,$pattern)
  if($found.Count -ne 1){throw "Expected exactly one $tag $name; found $($found.Count)"}
  $found[0]
}
function Replace([string]$text,[string]$tag,[string]$name,[string]$replacement) {
  $m=Entry $text $tag $name
  $text.Substring(0,$m.Index)+$replacement+$text.Substring($m.Index+$m.Length)
}
function SetBody([string]$text,[string]$tag,[string]$name,[string]$body) {
  $m=Entry $text $tag $name
  $value=[regex]::Replace($m.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+$body+'</script>'})
  Replace $text $tag $name $value
}
function UpsertScript([string]$text,[string]$name,[string]$path,[string]$after) {
  $body=Body $path
  if($text.Contains('<name>'+$name+'</name>')){return (SetBody $text 'Script' $name $body)}
  $block='<Script isActive="yes" isFolder="no"><name>'+$name+'</name><packageName /><script>'+$body+'</script><eventHandlerList /></Script>'
  $anchor=Entry $text 'Script' $after
  Replace $text 'Script' $after ($anchor.Value+$block)
}
function Trigger([string]$name,[string]$body,[string[]]$patterns) {
  $codes=($patterns|ForEach-Object{'<string>'+(Escape $_)+'</string>'}) -join ''
  $types=($patterns|ForEach-Object{'<integer>1</integer>'}) -join ''
  '<Trigger isActive="yes" isFolder="no" isTempTrigger="no" isMultiline="no" isPerlSlashGOption="no" isColorizerTrigger="no" isFilterTrigger="no" isSoundTrigger="no" isColorTrigger="no" isColorTriggerFg="no" isColorTriggerBg="no"><name>'+$name+'</name><script>'+(Escape $body)+'</script><triggerType>0</triggerType><conditonLineDelta>0</conditonLineDelta><mStayOpen>0</mStayOpen><mCommand /><packageName /><mFgColor>#ff0000</mFgColor><mBgColor>#ffff00</mBgColor><mSoundFile /><colorTriggerFgColor>#000000</colorTriggerFgColor><colorTriggerBgColor>#000000</colorTriggerBgColor><regexCodeList>'+$codes+'</regexCodeList><regexCodePropertyList>'+$types+'</regexCodePropertyList></Trigger>'
}
$text=[IO.File]::ReadAllText($PackagePath)
foreach($lane in @('eq','bal')){
  $text=$text.Replace('handle_line_event("line:'+$lane+'_blocked", { gag = true, echo = true })',
    'handle_line_event("line:'+$lane+'_blocked", { gag = true, echo = false })')
}
$text=SetBody $text 'Script' 'Combo logic' (Body 'Monk/combo.lua')
$text=SetBody $text 'Script' 'Route registry' (Body 'Yso/xml/route_registry.lua')
$text=UpsertScript $text 'Shikudo limb bridge' 'Monk/shikudo_limb_bridge.lua' 'Dispatch execute logic'
$text=UpsertScript $text 'Shikudo duel selector' 'Monk/shikudo_duel_selector.lua' 'Shikudo limb bridge'
$text=UpsertScript $text 'Shikudo duel controller' 'Monk/shikudo_duel.lua' 'Shikudo duel selector'
$pulseDocument=New-Object Xml.XmlDocument;$pulseDocument.LoadXml($text)
foreach($row in @(@('Pulse: EQ recovered','note_eq_recovery()'),@('Pulse: BAL recovered','note_full_recovery()'),@('Pulse: Monk limb recovered','note_recovery(matches[2])'))) {
  $node=$pulseDocument.SelectSingleNode('//Trigger[name="'+$row[0]+'"]')
  $prefix=([string]$node.script) -replace '(?s)\r?\n-- Shikudo duel recovery adapter.*$',''
  $body=$prefix + "`n-- Shikudo duel recovery adapter`n" + 'local D=Yso and Yso.off and Yso.off.monk and Yso.off.monk.duel; if D then D.'+$row[1]+' end'
  $text=SetBody $text 'Trigger' $row[0] (Escape $body)
}
$aliasBody='if Yso and Yso.off and Yso.off.monk and Yso.off.monk.duel then Yso.off.monk.duel.alias(matches[2] or "") end'
if($text.Contains('<name>Shikudo duel</name>')) {
  $text=SetBody $text 'Alias' 'Shikudo duel' (Escape $aliasBody)
} else {
  $alias='<Alias isActive="yes" isFolder="no"><name>Shikudo duel</name><script>'+(Escape $aliasBody)+'</script><command /><packageName /><regex>^shduel(?: (dispatch|lock|blackout|scythe|on|off|status|preview))?$</regex></Alias>'
  $anchor=Entry $text 'Alias' 'Group damage'
  $text=Replace $text 'Alias' 'Group damage' ($anchor.Value+$alias)
}
$body='local M=Yso and Yso.off and Yso.off.monk and Yso.off.monk.duel; if M then M.note_slain(matches[2]) end'
$block=Trigger 'Shikudo duel target slain' $body @('^You have slain ([\w''-]+)(?:, retrieving the corpse)?\.$','^([\w''-]+) has been slain by .+\.$')
if($text.Contains('<name>Shikudo duel target slain</name>')) {
  $text=Replace $text 'Trigger' 'Shikudo duel target slain' $block
} else {
  $anchor=Entry $text 'Trigger' 'Group damage target slain'
  $text=Replace $text 'Trigger' 'Group damage target slain' ($anchor.Value+$block)
}
$activity='local R=Yso and Yso.off and Yso.off.monk; if R then for _,M in pairs({R.duel or {},R.group_damage or {}}) do if type(M.note_local_target_activity)=="function" then M.note_local_target_activity(matches[2]) end end end'
$activityBlock=Trigger 'Shikudo local target activity' $activity @('^([\w''-]+) takes a drink from .+\.$','^([\w''-]+) eats .+\.$','^([\w''-]+) struts proudly about the room\.$')
$unavailable='local D=Yso and Yso.off and Yso.off.monk and Yso.off.monk.duel; if D and type(D.note_target_unavailable)=="function" then D.note_target_unavailable() end'
$denialBlock=Trigger 'Shikudo duel target unavailable' $unavailable @('^I do not recognise anything called that here\.$')
$grace='local D=Yso and Yso.off and Yso.off.monk and Yso.off.monk.duel; if D and type(D.note_target_grace)=="function" then D.note_target_grace(matches[2]) end'
$graceBlock=Trigger 'Shikudo duel target grace' $grace @('^([\w''-]+) walks in Divine Grace\. You may not harm (?:him|her|them)\.$')
$refusal='local D=Yso and Yso.off and Yso.off.monk and Yso.off.monk.duel; if D and type(D.note_resource_refusal)=="function" then D.note_resource_refusal(matches[2]=="balance" and "bal" or "eq") end'
$refusalBlock=Trigger 'Shikudo duel resource refusal' $refusal @('^You must regain (balance|equilibrium) first\.$')
$impatience='local D=Yso and Yso.off and Yso.off.monk and Yso.off.monk.duel; if D and type(D.note_impatience_success)=="function" then D.note_impatience_success(matches[2]) end'
$impatienceBlock=Trigger 'Shikudo mind impatience confirmed' $impatience @('^You fill the mind of ([\w''-]+) with an impatient feeling\.$')
$focusStart='local D=Yso and Yso.off and Yso.off.monk and Yso.off.monk.duel; if D and type(D.note_hyperfocus)=="function" then D.note_hyperfocus(nil) end'
$focusHead='local D=Yso and Yso.off and Yso.off.monk and Yso.off.monk.duel; if D and type(D.note_hyperfocus)=="function" then D.note_hyperfocus("head") end'
$focusStartBlock=Trigger 'Shikudo hyperfocus started' $focusStart @('^You begin breathing deeply, sinking into a focused trance\.$')
$focusHeadBlock=Trigger 'Shikudo hyperfocus head' $focusHead @('^You will now focus on bypassing attempts to deflect blows when striking the head\.$')
foreach($row in @(@('Shikudo local target activity',$activityBlock),@('Shikudo duel target unavailable',$denialBlock),@('Shikudo duel target grace',$graceBlock),@('Shikudo duel resource refusal',$refusalBlock),@('Shikudo mind impatience confirmed',$impatienceBlock),@('Shikudo hyperfocus started',$focusStartBlock),@('Shikudo hyperfocus head',$focusHeadBlock))) {
  if($text.Contains('<name>'+$row[0]+'</name>')){$text=Replace $text 'Trigger' $row[0] $row[1]}
  else{$anchor=Entry $text 'Trigger' 'Group damage target unavailable';$text=Replace $text 'Trigger' 'Group damage target unavailable' ($anchor.Value+$row[1])}
}
$limb=[IO.File]::ReadAllText($LimbPackagePath)
$limb=SetBody $limb 'Script' 'limb init' (Body 'Monk/limb_tracker.lua')
$limb=SetBody $limb 'Alias' '^lra$' 'lb.resetCurrentTarget()'
$limb=SetBody $limb 'Script' 'limb management' '-- Maintained methods are embedded in limb init from Monk/limb_tracker.lua.'
$limbDocument=New-Object Xml.XmlDocument;$limbDocument.LoadXml($limb)
foreach($row in @(@('Script','limb prompt'),@('Alias','^lr (.+)$'))) {
  $node=$limbDocument.SelectSingleNode('//'+$row[0]+'[name="'+$row[1]+'"]')
  $normalized=([string]$node.script).Replace('lb[target]','lb[lb.normalizeName(target)]')
  $limb=SetBody $limb $row[0] $row[1] (Escape $normalized)
}
$limb=SetBody $limb 'Trigger' 'limb salve' 'lb.salve(matches[2], matches[3])'
# Explicit numeric damage is sufficient evidence; do not gate it on a queued-command banner.
$capture=Entry $limb 'Trigger' 'dealt limb damage'
$limb=Replace $limb 'Trigger' 'dealt limb damage' ''
$captureBody='lb.addHit(matches.name, matches.limb, tonumber(matches.amount))'
$captureNew=Trigger 'dealt limb damage' $captureBody @(
  '^As your blow lands with a crunch, you perceive that you have dealt (?<amount>[0-9]+(?:\.[0-9]+)?)% damage to (?<name>[\w''-]+)''s (?<limb>.+)\.$',
  '^As you carve into (?<name>[\w''-]+), you perceive that you have dealt (?<amount>[0-9]+(?:\.[0-9]+)?)% damage to (?:his|her) (?<limb>.+)\.$'
)
$init=Entry $limb 'Trigger' 'init limb target'
$limb=Replace $limb 'Trigger' 'init limb target' ($init.Value+$captureNew)
$successes=@(
  @('Shikudo Hiraku observed','hiraku','^The staff smashes into the face of ([\w''-]+) with a sickening crunch\.$'),
  @('Shikudo Kuro observed','kuro','^The staff cracks across the [\w''-]+ thigh of ([\w''-]+)\.$'),
  @('Shikudo Ruku observed','ruku','^([\w''-]+) staggers as the staff cracks across [\w''-]+ ribs, sweat breaking out upon [\w''-]+ forehead\.$')
)
foreach($row in $successes) {
  $script='local B=Yso and Yso.monk and Yso.monk.limbs; if B then B.note_success(matches[2],"'+$row[1]+'") end'
  $block=Trigger $row[0] $script @($row[2])
  if($limb.Contains('<name>'+$row[0]+'</name>')){$limb=Replace $limb 'Trigger' $row[0] $block}
  else {$anchor=Entry $limb 'Trigger' 'limb salve';$limb=Replace $limb 'Trigger' 'limb salve' ($anchor.Value+$block)}
}
$document=New-Object Xml.XmlDocument;$document.LoadXml($text)
$document.LoadXml($limb)
if($PSCmdlet.ShouldProcess($PackagePath,'Embed Shikudo duel scripts, registry, combo and alias')) {
  [IO.File]::WriteAllText($PackagePath,$text,(New-Object Text.UTF8Encoding $false))
}
if($PSCmdlet.ShouldProcess($LimbPackagePath,'Embed validated limb core and independent damage capture')) {
  [IO.File]::WriteAllText($LimbPackagePath,$limb,(New-Object Text.UTF8Encoding $false))
}
