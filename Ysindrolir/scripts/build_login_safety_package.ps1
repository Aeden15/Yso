[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function Escape([string]$value){[Security.SecurityElement]::Escape($value)}
function Body([string]$text,[string]$name,[string]$relative){
 $pattern='(?s)<Script\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</Script>'
 $found=[regex]::Matches($text,$pattern)
 if($found.Count -ne 1){throw "Expected exactly one Script $name; found $($found.Count)"}
 $body=[IO.File]::ReadAllText((Join-Path $root $relative))
 $entry=$found[0]
 $block=[regex]::Replace($entry.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+(Escape $body)+'</script>'},1)
 return $text.Substring(0,$entry.Index)+$block+$text.Substring($entry.Index+$entry.Length)
}
if(-not $PSCmdlet.ShouldProcess($PackagePath,'Embed shared session readiness and login-safe consumers')){return}
$text=[IO.File]::ReadAllText($PackagePath)
# Put the service before every consumer, regardless of package folder order.
$text=[regex]::Replace($text,'(?s)<Script\b[^>]*>\s*<name>Yso session readiness</name>.*?</Script>','')
$anchor=[regex]::Match($text,'<ScriptPackage>')
if(-not $anchor.Success){throw 'Missing ScriptPackage'}
$service=[IO.File]::ReadAllText((Join-Path $root 'Yso/Integration/session.lua'))
$block='<Script isActive="yes" isFolder="no"><name>Yso session readiness</name><packageName /><script>'+(Escape $service)+'</script><eventHandlerList /></Script>'
$text=$text.Insert($anchor.Index+$anchor.Length,$block)
$text=Body $text 'Magi weapons' 'Magi/magi_weapons.lua'
$text=Body $text 'formulation' 'Alchemist/Core/formulation.lua'
$text=Body $text 'Yso serverside policy' 'Yso/Curing/serverside_policy.lua'
$null=[xml]$text
[IO.File]::WriteAllText($PackagePath,$text,(New-Object Text.UTF8Encoding $false))
