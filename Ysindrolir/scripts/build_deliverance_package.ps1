# Scoped Deliverance maintenance; preserve unrelated package bytes.
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
$resourceBody = Read-Lua 'Yso/Combat/deliverance_resource.lua'
$deliveranceBody = Read-Lua 'Yso/Combat/deliverance_alias.lua'
$content = Replace-Entry $content 'Script' 'Deliverance resource' {
  param($entry)
  [regex]::Replace($entry, '(?s)<script>.*?</script>', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) '<script>' + $resourceBody + '</script>' })
}
$content = Replace-Entry $content 'Alias' 'Deliverance' {
  param($entry)
  [regex]::Replace($entry, '(?s)<script>.*?</script>', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) '<script>' + $deliveranceBody + '</script>' })
}
[xml]$validated = $content
if ($PSCmdlet.ShouldProcess($PackagePath, 'Embed Deliverance sources')) {
  [System.IO.File]::WriteAllText($PackagePath, $content, (New-Object System.Text.UTF8Encoding $false))
}