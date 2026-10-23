[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

function SetBody([string]$text, [string]$tag, [string]$name, [string]$body) {
  $pattern = '(?s)<' + $tag + '\b[^>]*>\s*<name>' + [regex]::Escape($name) + '</name>.*?</' + $tag + '>'
  $entries = [regex]::Matches($text, $pattern)
  if ($entries.Count -ne 1) { throw "Expected exactly one $tag $name; found $($entries.Count)" }
  $entry = $entries[0]
  # Mudlet exports and older builders use different quote escaping. Preserve
  # the entry's existing style so rebuilding Focus does not rewrite its chassis.
  $encoded = $body.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
  if ($entry.Value.Contains('&quot;')) { $encoded = $encoded.Replace('"', '&quot;') }
  if ($entry.Value.Contains('&apos;')) { $encoded = $encoded.Replace("'", '&apos;') }
  $block = [regex]::Replace($entry.Value, '(?s)<script\s*/>|<script>.*?</script>', [Text.RegularExpressions.MatchEvaluator]{
    param($match)
    '<script>' + $encoded + '</script>'
  }, 1)
  $text.Substring(0, $entry.Index) + $block + $text.Substring($entry.Index + $entry.Length)
}

if (-not $PSCmdlet.ShouldProcess($PackagePath, 'Synchronize Pebble changes in Water, Firestorm and Focus only')) { return }
& (Join-Path $PSScriptRoot 'build_mfocus_alias_body.ps1') | Out-Null
$text = [IO.File]::ReadAllText($PackagePath)
foreach ($entry in @(@('Magi firestorm','Magi/Magi_firestorm.lua'), @('Magi water group','Magi/Magi_water_group.lua'))) {
  $text = SetBody $text 'Script' $entry[0] ([IO.File]::ReadAllText((Join-Path $root $entry[1])))
}
$text = SetBody $text 'Alias' 'mfocus' ([IO.File]::ReadAllText((Join-Path $root 'Magi/mfocus_alias_body.lua')))
# Some installed packages also preload Focus as a native script.
if ([regex]::IsMatch($text, '(?s)<Script\b[^>]*>\s*<name>Magi focus</name>')) {
  $dissonance = [IO.File]::ReadAllText((Join-Path $root 'Magi/magi_dissonance.lua')).TrimEnd()
  $dissonance = $dissonance -replace '(?m)^return D\s*$', '-- return omitted: native Focus shares Yso.magi.dissonance'
  $focus = [IO.File]::ReadAllText((Join-Path $root 'Magi/magi_focus.lua'))
  $text = SetBody $text 'Script' 'Magi focus' ($dissonance + "`n`n" + $focus)
}
[xml]$validated = $text
if ($text -cne [IO.File]::ReadAllText($PackagePath)) {
  [IO.File]::WriteAllText($PackagePath, $text, (New-Object Text.UTF8Encoding $false))
}
Write-Host 'Synchronized Water, Firestorm and Focus; unrelated package entries preserved.'
