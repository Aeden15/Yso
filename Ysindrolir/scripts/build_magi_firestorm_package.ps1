# Update only the maintained Firestorm native script body.
[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if(-not $PSCmdlet.ShouldProcess($PackagePath,'Synchronize Firestorm route only')){return}
$before=[IO.File]::ReadAllText($PackagePath)
$nodes=[regex]::Matches($before,'(?s)<Script\b[^>]*>\s*<name>Magi firestorm</name>.*?</Script>')
if($nodes.Count -ne 1){throw 'Expected exactly one native Magi firestorm script'}
$node=$nodes[0]
$body=[IO.File]::ReadAllText((Join-Path $root 'Magi/Magi_firestorm.lua')).Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;')
if($node.Value.Contains('&quot;')){$body=$body.Replace('"','&quot;')}
if($node.Value.Contains('&apos;')){$body=$body.Replace("'",'&apos;')}
$block=[regex]::Replace($node.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($match) '<script>'+$body+'</script>'},1)
$text=$before.Substring(0,$node.Index)+$block+$before.Substring($node.Index+$node.Length)
[xml]$validated=$text
if($text -cne $before){[IO.File]::WriteAllText($PackagePath,$text,[Text.UTF8Encoding]::new($false))}
Write-Host 'Synchronized Firestorm route; unrelated entries preserved.'
