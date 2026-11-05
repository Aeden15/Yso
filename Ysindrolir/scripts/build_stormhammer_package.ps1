[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$text=[IO.File]::ReadAllText($PackagePath)
function Encode([string]$s){$s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;')}
function FindBlock([string]$s,[string]$tag,[string]$name){
  $pattern='<'+$tag+'\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>'
  $starts=[regex]::Matches($s,$pattern)
  if($starts.Count -eq 0){return $null}
  if($starts.Count -ne 1){throw "Ambiguous $tag $name"}
  $start=$starts[0].Index; $depth=0
  foreach($m in [regex]::Matches($s.Substring($start),'</?'+$tag+'\b[^>]*>')){
    if($m.Value.StartsWith('</')){$depth--}else{$depth++}
    if($depth -eq 0){return @{Index=$start;Length=$m.Index+$m.Length;Value=$s.Substring($start,$m.Index+$m.Length)}}
  }
  throw "Unclosed $tag $name"
}
function ReplaceBlock([string]$s,$block,[string]$new){$s.Substring(0,$block.Index)+$new+$s.Substring($block.Index+$block.Length)}
function SetBody([string]$s,[string]$tag,[string]$name,[string]$body){
  $block=FindBlock $s $tag $name
  if(-not $block){throw "Missing $tag $name"}
  $new=[regex]::Replace($block.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+(Encode $body)+'</script>'},1)
  ReplaceBlock $s $block $new
}
function UpsertAfter([string]$s,[string]$tag,[string]$name,[string]$body,[string]$anchorTag,[string]$anchorName){
  $existing=FindBlock $s $tag $name
  if($existing){return (ReplaceBlock $s $existing $body)}
  $anchor=FindBlock $s $anchorTag $anchorName
  if(-not $anchor){throw "Missing anchor $anchorName"}
  $at=$anchor.Index+$anchor.Length
  $s.Insert($at,"`r`n"+$body)
}
function AddChild([string]$s,[string]$tag,[string]$parent,[string]$childTag,[string]$childName,[string]$child){
  $block=FindBlock $s $tag $parent
  if(-not $block){throw "Missing parent $parent"}
  $existing=FindBlock $block.Value $childTag $childName
  if($existing){$new=ReplaceBlock $block.Value $existing $child}
  else{$at=$block.Value.LastIndexOf('</'+$tag+'>');$new=$block.Value.Insert($at,"`r`n"+$child+"`r`n")}
  ReplaceBlock $s $block $new
}
function Script([string]$name,[string]$source){
  '<Script isActive="yes" isFolder="no"><name>'+ $name +'</name><packageName /><script>'+(Encode ([IO.File]::ReadAllText((Join-Path $root $source))))+'</script><eventHandlerList /></Script>'
}
function Alias([string]$name,[string]$regex,[string]$body){
  '<Alias isActive="yes" isFolder="no"><name>'+(Encode $name)+'</name><script>'+(Encode $body)+'</script><command /><packageName /><regex>'+(Encode $regex)+'</regex></Alias>'
}
if(-not $PSCmdlet.ShouldProcess($PackagePath,'Merge repaired Stormhammer, target priorities, equipment discovery and Transfixed')){return}

# Import only native entries; external package ownership must not survive merging.
$imports=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/Target things.xml'))
$priorityAliases=$imports.SelectSingleNode('//AliasGroup[name="Target Priority"]')
$priorityAliases.name='Target priorities'
$bodies=@{
  'Target Group'='tprio.reset(); tprio.addGroup(matches[2])'
  'Enemy Prio'='if #tprio.list == 0 then tprio.print(); return end; send("unenemy all"); for _,n in ipairs(tprio.list) do send("enemy " .. n) end'
  'Targets announce'='tprio.pt()'
  'Target First'='tprio.current = 0; tprio.next()'
  'Target Next'='tprio.next()'
  'Target Last'='tprio.previous()'
  'Partycalling'='partyReporting = not partyReporting; cecho("<yellow>[Yso] Party reporting " .. (partyReporting and "enabled" or "disabled") .. ".\n")'
}
foreach($alias in $priorityAliases.SelectNodes('.//Alias')){$alias.script=$bodies[[string]$alias.name]}
$text=AddChild $text 'AliasGroup' 'Yso Aliases' 'AliasGroup' 'Target priorities' $priorityAliases.OuterXml

$stormAliases=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/stormhammer aliases.xml'))
$group=$stormAliases.SelectSingleNode('//AliasGroup[name="StawmHamma"]')
$group.name='Stormhammer'
$group.SelectSingleNode('Alias[name="Target Switcher"]').script='thammer.set_mode(matches[2])'
$text=AddChild $text 'AliasGroup' 'Elementalism' 'AliasGroup' 'Stormhammer' $group.OuterXml
$text=AddChild $text 'AliasGroup' 'Elementalism' 'Alias' 'Transfixed' (Alias 'Transfixed' '^tfix$' 'sendAll("cq all", "cast transfix " ..target)')

$triggers=$imports.SelectSingleNode('//TriggerGroup[name="Targeting Triggers"]')
$triggers.name='Yso target priorities'
foreach($owner in $triggers.SelectNodes('.//packageName|./packageName')){$owner.InnerText=''}
$text=AddChild $text 'TriggerGroup' 'Yso Triggers' 'TriggerGroup' 'Yso target priorities' $triggers.OuterXml

$text=UpsertAfter $text 'Script' 'Yso target priority' (Script 'Yso target priority' 'Yso/xml/yso_target_priority.lua') 'Script' 'Yso party targeting'
$text=SetBody $text 'Script' 'Magi weapons' ([IO.File]::ReadAllText((Join-Path $root 'Magi/magi_weapons.lua')))
$text=UpsertAfter $text 'Script' 'Stormhammer' (Script 'Stormhammer' 'Magi/magi_stormhammer.lua') 'Script' 'Magi weapons'
$misc=FindBlock $text 'Script' 'Miscellaneous scripts'
$doc=[xml]$misc.Value
$body=$doc.SelectSingleNode('/Script/script').InnerText
$body=[regex]::Replace($body,'(?m)^magistaff\s*=.*$','magistaff = magistaff or "" -- populated by Magi weapons inventory discovery')
if($body -notmatch '(?m)^magishield\s*='){$body=$body.Replace('magistaff = magistaff or "" -- populated by Magi weapons inventory discovery','magistaff = magistaff or "" -- populated by Magi weapons inventory discovery'+"`n"+'magishield = magishield or "" -- populated by Magi weapons inventory discovery')}
$text=SetBody $text 'Script' 'Miscellaneous scripts' $body
[xml]$validated=$text
if($text -cne [IO.File]::ReadAllText($PackagePath)){[IO.File]::WriteAllText($PackagePath,$text,[Text.UTF8Encoding]::new($false))}
Write-Output 'PASS: synchronized Stormhammer, target priorities, dynamic equipment and Transfixed in Yso'
