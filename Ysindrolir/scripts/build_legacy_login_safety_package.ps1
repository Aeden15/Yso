[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Legacy V2.1.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if(-not $PSCmdlet.ShouldProcess($PackagePath,'Synchronize session-guarded Legacy login callbacks')){return}
$text=[IO.File]::ReadAllText($PackagePath)
foreach($row in @(@('Script','Legacy','legacy_load.lua'),@('Trigger','Login','legacy_login.lua'),@('Timer','Check for Updates','legacy_check_for_updates.lua'))){
 $pattern='(?s)<'+$row[0]+'\b[^>]*>\s*<name>'+[regex]::Escape($row[1])+'</name>.*?</'+$row[0]+'>'
 $found=[regex]::Matches($text,$pattern)
 if($found.Count -ne 1){throw "Expected one $($row[0]) $($row[1]); found $($found.Count)"}
 $entry=$found[0]
 $body=[IO.File]::ReadAllText((Join-Path $root ('Yso/Integration/'+$row[2])))
 $block=[regex]::Replace($entry.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+[Security.SecurityElement]::Escape($body)+'</script>'},1)
 $text=$text.Substring(0,$entry.Index)+$block+$text.Substring($entry.Index+$entry.Length)
}
$null=[xml]$text
[IO.File]::WriteAllText($PackagePath,$text,(New-Object Text.UTF8Encoding $false))
