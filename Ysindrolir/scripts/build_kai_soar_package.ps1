# Scoped Kai/soar maintenance; preserve unrelated package bytes.
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
$resourceBody = Read-Lua 'Monk/kai_resource.lua'
$deliveranceBody = Read-Lua 'Monk/deliverance_alias.lua'
$content = Replace-Entry $content 'Script' 'Kai resource' {
  param($entry)
  [regex]::Replace($entry, '(?s)<script>.*?</script>', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) '<script>' + $resourceBody + '</script>' })
}
$content = Replace-Entry $content 'Alias' 'Deliverance' {
  param($entry)
  $entry = $entry -replace 'isActive="(?:yes|no)"', 'isActive="yes"'
  [regex]::Replace($entry, '(?s)<script>.*?</script>', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) '<script>' + $deliveranceBody + '</script>' })
}
$triggers = @(
  @('Kai burst used', 'You let loose an uncontrolled burst of kai energy, flushing it through your system and bolstering your reserves.', 'on_burst', 'used'),
  @('Kai burst resource rejection', 'You are already circulating too much kai energy to focus upon an uncontrolled burst.', 'on_burst', 'too_much_kai'),
  @('Kai burst cooldown', 'You may not yet produce a burst of uncontrolled kai energy.', 'on_burst', 'cooldown'),
  @('Kai burst ready', 'You may produce another burst of uncontrolled kai energy.', 'on_burst', 'ready'),
  @('Deliverance channeling', 'You bow your head in prayer, press your palms together and begin to pray silently for deliverance.', 'on_deliverance', 'channeling'),
  @('Deliverance up', 'You slowly raise your head and feel your body pulse with the power of Deliverance.', 'on_deliverance', 'active'),
  @('Deliverance down', 'You raise your head and cease your prayers for deliverance.', 'on_deliverance', 'idle')
)
$blocks = ''
foreach ($trigger in $triggers) {
  $name = $trigger[0]
  $pattern = '(?s)<Trigger\b[^>]*>\s*<name>' + [regex]::Escape($name) + '</name>.*?</Trigger>'
  $content = [regex]::Replace($content, $pattern, '')
  # Literal punctuation is escaped; these are complete server lines (visual wraps
  # do not split Mudlet's logical trigger line).
  $message = Escape-Xml ('^' + $trigger[1].Replace('.', '\.') + '$')
  $body = 'if Yso and Yso.monk and Yso.monk.kai then Yso.monk.kai.' + $trigger[2] + '("' + $trigger[3] + '") end'
  $block = @"
<Trigger isActive="yes" isFolder="no" isTempTrigger="no" isMultiline="no" isPerlSlashGOption="no" isColorizerTrigger="no" isFilterTrigger="no" isSoundTrigger="no" isColorTrigger="no" isColorTriggerFg="no" isColorTriggerBg="no">
                            <name>$name</name>
                            <script>$body</script>
                            <triggerType>0</triggerType><conditonLineDelta>0</conditonLineDelta><mStayOpen>0</mStayOpen>
                            <mCommand /><packageName /><mFgColor>#ff0000</mFgColor><mBgColor>#ffff00</mBgColor><mSoundFile />
                            <colorTriggerFgColor>#000000</colorTriggerFgColor><colorTriggerBgColor>#000000</colorTriggerBgColor>
                            <regexCodeList><string>$message</string></regexCodeList>
                            <regexCodePropertyList><integer>1</integer></regexCodePropertyList>
                        </Trigger>
"@
  $blocks += ($block -replace "`r?`n", $newline)
}
$content = Replace-Entry $content 'Trigger' 'Kai cripple' { param($entry) $entry + $blocks }
[xml]$validated = $content
if ($PSCmdlet.ShouldProcess($PackagePath, 'Embed Kai states, Deliverance, Kai cripple and soar sources')) {
  [System.IO.File]::WriteAllText($PackagePath, $content, (New-Object System.Text.UTF8Encoding $false))
}
