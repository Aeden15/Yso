# Updates only maintained Water and shared resonance-feedback script bodies.
[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if(-not $PSCmdlet.ShouldProcess($PackagePath,'Synchronize Water route and resonance feedback only')){return}
$before=[IO.File]::ReadAllText($PackagePath)
$text=$before
foreach($entry in @(@('Magi water group','Magi/Magi_water_group.lua'),@('Magi resonance feedback','Magi/resonance_feedback.lua'))){
  $pattern='(?s)<Script\b[^>]*>\s*<name>'+[regex]::Escape($entry[0])+'</name>.*?</Script>'
  $nodes=[regex]::Matches($text,$pattern)
  if($nodes.Count -ne 1){throw ('Expected exactly one native script '+$entry[0])}
  $node=$nodes[0]
  $body=[IO.File]::ReadAllText((Join-Path $root $entry[1])).Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;')
  if($node.Value.Contains('&quot;')){$body=$body.Replace('"','&quot;')}
  if($node.Value.Contains('&apos;')){$body=$body.Replace("'",'&apos;')}
  $block=[regex]::Replace($node.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{
    param($match)
    '<script>'+$body+'</script>'
  },1)
  $text=$text.Substring(0,$node.Index)+$block+$text.Substring($node.Index+$node.Length)
}
[xml]$validated=$text
if($text -cne $before){[IO.File]::WriteAllText($PackagePath,$text,[Text.UTF8Encoding]::new($false))}
Write-Host 'Synchronized Water route and resonance feedback; unrelated entries preserved.'
