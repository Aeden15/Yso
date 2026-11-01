[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function SetBody([string]$text,[string]$tag,[string]$name,[string]$body){
 $hits=[regex]::Matches($text,'(?s)<'+$tag+'\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</'+$tag+'>')
 if($hits.Count -ne 1){throw "Expected unique $tag $name; found $($hits.Count)"}
 $entry=$hits[0]
 $block=[regex]::Replace($entry.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+[Security.SecurityElement]::Escape($body)+'</script>'},1)
 $text.Substring(0,$entry.Index)+$block+$text.Substring($entry.Index+$entry.Length)
}
& (Join-Path $PSScriptRoot 'build_shdam_alias_body.ps1') | Out-Null
& (Join-Path $PSScriptRoot 'build_mfocus_alias_body.ps1') | Out-Null
$text=[IO.File]::ReadAllText($PackagePath)
$rows=@(
 @('Api stuff','Yso/xml/api_stuff.lua'),@('Yso modes','Yso/xml/yso_modes.lua'),
 @('Combat paralysis policy','Yso/Combat/combat_pause.lua'),
 @('Apostate Truelocks','Apostate/lock_route.lua'),
 @('Airlord attack logic','Airlord/combat_routes.lua'),
 @('Shikudo duel controller','Monk/shikudo_duel.lua'),
 @('Magi route core','Magi/magi_route_core.lua'),
 @('Alchemist physiology','Alchemist/Core/physiology.lua'),
 @('Alchemist duel route','Alchemist/Core/duel route.lua'),
 @('Alchemist aurify route','Alchemist/Aurify route.lua'),
 @('Alchemist group damage','Alchemist/Core/group damage.lua')
)
if(-not $text.Contains('<name>Combat paralysis policy</name>')){
 $anchor=[regex]::Match($text,'(?s)<Script\b[^>]*>\s*<name>Route registry</name>.*?</Script>')
 if(-not $anchor.Success){throw 'Missing Route registry anchor'}
 $text=$text.Insert($anchor.Index+$anchor.Length,'<Script isActive="yes" isFolder="no"><name>Combat paralysis policy</name><packageName /><script></script><eventHandlerList /></Script>')
}
foreach($row in $rows){
 if(-not $text.Contains('<name>'+$row[0]+'</name>')){
  if($row[0] -notlike 'Alchemist *'){throw ('Missing script '+$row[0])}
  $anchorName=if($row[0] -eq 'Alchemist physiology'){'formulation_phiallist'}else{'Alchemist physiology'}
  $anchor=[regex]::Match($text,'(?s)<Script\b[^>]*>\s*<name>'+[regex]::Escape($anchorName)+'</name>.*?</Script>')
  if(-not $anchor.Success){throw ('Missing anchor '+$anchorName)}
  $text=$text.Insert($anchor.Index+$anchor.Length,'<Script isActive="yes" isFolder="no"><name>'+$row[0]+'</name><packageName /><script></script><eventHandlerList /></Script>')
 }
 $text=SetBody $text 'Script' $row[0] ([IO.File]::ReadAllText((Join-Path $root $row[1])))}
foreach($row in @(@('Group damage','Monk/shdam_alias_body.lua'),@('mfocus','Magi/mfocus_alias_body.lua'))){
 $text=SetBody $text 'Alias' $row[0] ([IO.File]::ReadAllText((Join-Path $root $row[1])))
}
[xml]$validated=$text
[IO.File]::WriteAllText($PackagePath,$text,(New-Object Text.UTF8Encoding $false))
Write-Host 'Synchronized combat paralysis scripts and embedded aliases.'
