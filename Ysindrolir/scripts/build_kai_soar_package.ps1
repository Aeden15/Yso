# Patch only the two named entries; preserve every other package byte.
[CmdletBinding(SupportsShouldProcess = $true)]
param([string]$PackagePath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$content = [System.IO.File]::ReadAllText($PackagePath)
$newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
function Escape-Xml([string]$text) { [System.Security.SecurityElement]::Escape($text) }
function Read-Lua([string]$relative) {
  $body = [System.IO.File]::ReadAllText((Join-Path $root $relative)).TrimEnd()
  Escape-Xml (($body -replace "`r?`n", $newline))
}
function Replace-Entry([string]$text, [string]$tag, [string]$name, [scriptblock]$update) {
  $pattern = '(?s)<' + $tag + '\b[^>]*>\s*<name>' + [regex]::Escape($name) + '</name>.*?</' + $tag + '>'
  $entries = [regex]::Matches($text, $pattern)
  if ($entries.Count -ne 1) { throw "Expected exactly one $tag named $name; found $($entries.Count)" }
  $entry = $entries[0]
  $replacement = & $update $entry.Value
  $text.Substring(0, $entry.Index) + $replacement + $text.Substring($entry.Index + $entry.Length)
}
$kaiBody = Read-Lua 'Monk/kai_cripple_trigger.lua'
$soarBody = Read-Lua 'Airlord/soar_alias.lua'
$content = Replace-Entry $content 'Trigger' 'Kai cripple' {
  param($entry)
  $entry = $entry -replace 'isActive="(?:yes|no)"', 'isActive="yes"'
  $entry = $entry -replace 'isMultiline="(?:yes|no)"', 'isMultiline="yes"'
  $entry = [regex]::Replace($entry, '(?s)<script>.*?</script>', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) '<script>' + $kaiBody + '</script>' })
  $entry = $entry -replace '<conditonLineDelta>\d+</conditonLineDelta>', '<conditonLineDelta>1</conditonLineDelta>'
  $patternOne = '^You thrust your palms forward and a stream of blue light crackles forth to strike out at ([\w''-]+)\.$'
  $patternTwo = '^Snapping sounds echo through the air as your crippled victim sinks to the floor\.$'
  $entry = [regex]::Replace($entry, '(?s)<regexCodeList\s*/>|<regexCodeList>.*?</regexCodeList>', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) '<regexCodeList><string>' + (Escape-Xml $patternOne) + '</string><string>' + (Escape-Xml $patternTwo) + '</string></regexCodeList>' })
  $entry -replace '(?s)<regexCodePropertyList\s*/>|<regexCodePropertyList>.*?</regexCodePropertyList>', '<regexCodePropertyList><integer>1</integer><integer>1</integer></regexCodePropertyList>'
}
$content = Replace-Entry $content 'Alias' 'Soaring' {
  param($entry)
  $entry = [regex]::Replace($entry, '(?s)<script>.*?</script>', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) '<script>' + $soarBody + '</script>' })
  $entry -replace '(?s)<regex>.*?</regex>', '<regex>^soa([lhs])$</regex>'
}
[xml]$validated = $content
if ($PSCmdlet.ShouldProcess($PackagePath, 'Embed Kai cripple and soar sources')) {
  [System.IO.File]::WriteAllText($PackagePath, $content, (New-Object System.Text.UTF8Encoding $false))
}
