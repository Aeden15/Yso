# Re-embed on-disk Lua into mudlet packages/Yso system.xml (Mudlet-native workflow).
# Api stuff SSOT: Yso/xml/api_stuff.lua (Core/api.lua is a load shim only).
# Run:  cd Ysindrolir\scripts ; .\export_yso_system_xml.ps1
# Validate:  [xml](Get-Content -Raw -LiteralPath '..\mudlet packages\Yso system.xml')
[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-MudletXmlScriptText([string]$text) {
  if ($null -eq $text) { return '' }
  $t = $text.Replace('&', '&amp;')
  $t = $t.Replace('<', '&lt;')
  return $t.Replace('>', '&gt;')
}

function New-MudletScriptBlock([string]$mudletName, [string]$escapedBody) {
  return @"
        <Script isActive="yes" isFolder="no">
          <name>$mudletName</name>
          <packageName></packageName>
          <script>$escapedBody</script>
          <eventHandlerList />
        </Script>
"@
}

function Test-ScriptBlockExists([string]$content, [string]$mudletName) {
  $nameRe = [regex]::Escape($mudletName)
  return [regex]::IsMatch($content, '(?s)<Script isActive="yes" isFolder="no">\s*<name>' + $nameRe + '</name>')
}

function Add-ScriptAfter([string]$content, [string]$afterName, [string]$newName, [string]$srcPath) {
  if (Test-ScriptBlockExists $content $newName) { return $content }
  if (-not (Test-Path -LiteralPath $srcPath)) {
    Write-Warning "Cannot insert '$newName': missing source $srcPath"
    return $content
  }
  $lua = Get-Content -LiteralPath $srcPath -Raw -Encoding UTF8
  $escaped = ConvertTo-MudletXmlScriptText $lua
  $block = New-MudletScriptBlock $newName $escaped
  $nameRe = [regex]::Escape($afterName)
  $pattern = '(?s)(<Script isActive="yes" isFolder="no">\s*<name>' + $nameRe + '</name>.*?</Script>)'
  $m = [regex]::Match($content, $pattern)
  if (-not $m.Success) { throw "Insert anchor not found for '$newName' after '$afterName'" }
  return $content.Substring(0, $m.Index + $m.Length) + $block + $content.Substring($m.Index + $m.Length)
}

function Set-AliasScriptByName([string]$content, [string]$aliasName, [string]$srcPath) {
  if (-not (Test-Path -LiteralPath $srcPath)) {
    Write-Warning "Cannot update alias '$aliasName': missing source $srcPath"
    return $content
  }
  $escaped = ConvertTo-MudletXmlScriptText (Get-Content -LiteralPath $srcPath -Raw -Encoding UTF8)
  $needle = '<name>' + $aliasName + '</name>'
  $nameIdx = $content.IndexOf($needle)
  if ($nameIdx -lt 0) { throw "Alias script block not found for name: $aliasName" }
  $openIdx = $content.IndexOf('<script>', $nameIdx)
  if ($openIdx -lt 0) { throw "Alias script open not found for name: $aliasName" }
  $bodyStart = $openIdx + '<script>'.Length
  $closeIdx = $content.IndexOf('</script>', $bodyStart)
  if ($closeIdx -lt 0) { throw "Alias script close not found for name: $aliasName" }
  return $content.Substring(0, $bodyStart) + $escaped + $content.Substring($closeIdx)
}

function Remove-ScriptByName([string]$content, [string]$mudletName) {
  $nameRe = [regex]::Escape($mudletName)
  $pattern = '(?s)\s*<Script isActive="yes" isFolder="no">\s*<name>' + $nameRe + '</name>.*?</Script>'
  if (-not [regex]::IsMatch($content, $pattern)) { return $content }
  return [regex]::Replace($content, $pattern, '', 1)
}

function Remove-AliasByName([string]$content, [string]$aliasName) {
  $needle = '<name>' + $aliasName + '</name>'
  $nameIdx = $content.IndexOf($needle)
  if ($nameIdx -lt 0) { return $content }
  $blockStart = $content.LastIndexOf('<Alias ', $nameIdx)
  if ($blockStart -lt 0) { return $content }
  $blockEnd = $content.IndexOf('</Alias>', $nameIdx)
  if ($blockEnd -lt 0) { return $content }
  $blockEnd += '</Alias>'.Length
  return $content.Remove($blockStart, $blockEnd - $blockStart)
}

function Remove-TriggerByName([string]$content, [string]$triggerName) {
  $needle = '<name>' + $triggerName + '</name>'
  $nameIdx = $content.IndexOf($needle)
  if ($nameIdx -lt 0) { return $content }
  $blockStart = $content.LastIndexOf('<Trigger ', $nameIdx)
  if ($blockStart -lt 0) { return $content }
  $blockEnd = $content.IndexOf('</Trigger>', $nameIdx)
  if ($blockEnd -lt 0) { return $content }
  $blockEnd += '</Trigger>'.Length
  return $content.Remove($blockStart, $blockEnd - $blockStart)
}

function Remove-OrphanTargetingBlock([string]$content) {
  $pattern = '(?s)\r?\n        <script>-- Auto-exported from Mudlet package script: Yso\.targeting\r?\n.*?\r?\n</script>\r?\n        <eventHandlerList />\r?\n        <Script isActive="yes" isFolder="no">\r?\n          <name>AK\+Legacy wiring</name>'
  if (-not [regex]::IsMatch($content, $pattern)) { return $content }
  return [regex]::Replace(
    $content,
    $pattern,
    "`n        <Script isActive=`"yes`" isFolder=`"no`">`n          <name>AK+Legacy wiring</name>",
    1
  )
}

$ScriptsDir = Split-Path -Parent $PSCommandPath
$Ysindrolir = Resolve-Path (Join-Path $ScriptsDir '..')
$YsoDir = Join-Path $Ysindrolir 'Yso'
$AlchemistDir = Join-Path $Ysindrolir 'Alchemist'
$MagiDir = Join-Path $Ysindrolir 'Magi'
$XmlPackage = Join-Path $Ysindrolir 'mudlet packages\Yso system.xml'

$ScriptToSourcePath = [ordered]@{
  'AK+Legacy wiring'              = Join-Path $YsoDir 'Integration\ak_legacy_wiring.lua'
  'Api stuff'                     = Join-Path $YsoDir 'xml\api_stuff.lua'
  'Alchemist aurify route'        = Join-Path $AlchemistDir 'Aurify route.lua'
  'Alchemist duel route'          = Join-Path $AlchemistDir 'Core\duel route.lua'
  'Alchemist group damage'        = Join-Path $AlchemistDir 'Core\group damage.lua'
  'Alchemist physiology'          = Join-Path $AlchemistDir 'Core\physiology.lua'
  'Bash Vitals Swap'              = Join-Path $YsoDir 'Curing\bash_vitals_swap.lua'
  'Bloodboil auto'                = Join-Path $YsoDir 'xml\magi_bloodboil_auto.lua'
  'Cureset Baselines'             = Join-Path $YsoDir 'xml\cureset_baselines.lua'
  'Defensive checks'              = Join-Path $YsoDir 'xml\magi_defensive_checks.lua'
  'Magi route core'               = Join-Path $MagiDir 'magi_route_core.lua'
  'Magi duel dam'                 = Join-Path $MagiDir 'Magi_duel_dam.lua'
  'formulation'                   = Join-Path $AlchemistDir 'Core\formulation.lua'
  'formulation_build'             = Join-Path $AlchemistDir 'Core\formulation_build.lua'
  'formulation_chart'             = Join-Path $AlchemistDir 'Core\formulation_chart.lua'
  'formulation_phials'            = Join-Path $AlchemistDir 'Core\formulation_phials.lua'
  'formulation_resolve'           = Join-Path $AlchemistDir 'Core\formulation_resolve.lua'
  'hinder'                        = Join-Path $YsoDir 'Combat\hinder.lua'
  'humour_balance'                = Join-Path $AlchemistDir 'Triggers\Alchemy\Physiology\humour_balance.lua'
  'Information'                   = Join-Path $YsoDir 'xml\information.lua'
  'Offense Template'              = Join-Path $YsoDir 'xml\offense_template.lua'
  'Parry Module'                  = Join-Path $YsoDir 'Combat\parry.lua'
  'Prio Baselines'                = Join-Path $YsoDir 'xml\prio_baselines.lua'
  'Radiance event'                = Join-Path $YsoDir 'xml\radiance_event.lua'
  'Route registry'                = Join-Path $YsoDir 'Combat\route_registry.lua'
  'route_gate'                    = Join-Path $YsoDir 'Combat\route_gate.lua'
  'Route chassis loader'          = Join-Path $YsoDir 'xml\route_chassis_loader.lua'
  'Offense core'                  = Join-Path $YsoDir 'Combat\offense_core.lua'
  'Tree auto'                     = Join-Path $YsoDir 'xml\magi_tree_auto.lua'
  'yso_target_tattoos.lua'        = Join-Path $YsoDir 'xml\yso_target_tattoos.lua'
  'Yso_Alert_Radiance helper'     = Join-Path $YsoDir 'xml\yso_alert_radiance_helper.lua'
  'Yso serverside policy'         = Join-Path $YsoDir 'Curing\serverside_policy.lua'
  'Yso self aff'                  = Join-Path $YsoDir 'Core\self_aff.lua'
  'Yso self curedefs'             = Join-Path $YsoDir 'Curing\self_curedefs.lua'
  'Yso.engine (event plumbing)'   = Join-Path $YsoDir 'xml\yso_engine.lua'
  'Yso.offense.request_tick'      = Join-Path $YsoDir 'xml\yso_offense_request_tick.lua'
  'Yso modes'                     = Join-Path $YsoDir 'xml\yso_modes.lua'
  'Yso pulse'                     = Join-Path $YsoDir 'xml\yso_pulse_wake_bus.lua'
  'Yso.state wiring'              = Join-Path $YsoDir 'xml\yso_state_wiring_stub.lua'
  'Yso.target'                    = Join-Path $YsoDir 'xml\yso_target.lua'
  'Yso.targeting'                 = Join-Path $YsoDir 'xml\yso_targeting.lua'
}

$ScriptInserts = @(
  @{ Name = 'Yso modes';             After = 'Api stuff';              Source = Join-Path $YsoDir 'xml\yso_modes.lua' },
  @{ Name = 'Yso pulse';             After = 'Yso modes';              Source = Join-Path $YsoDir 'xml\yso_pulse_wake_bus.lua' },
  @{ Name = 'Route registry';        After = 'Yso pulse';              Source = Join-Path $YsoDir 'Combat\route_registry.lua' },
  @{ Name = 'Offense core';          After = 'Yso.offense.request_tick'; Source = Join-Path $YsoDir 'Combat\offense_core.lua' },
  @{ Name = 'Alchemist duel route';  After = 'Alchemist physiology';   Source = Join-Path $AlchemistDir 'Core\duel route.lua' },
  @{ Name = 'Alchemist aurify route'; After = 'Alchemist duel route';  Source = Join-Path $AlchemistDir 'Aurify route.lua' },
  @{ Name = 'Magi route core';       After = 'Defensive checks';       Source = Join-Path $MagiDir 'magi_route_core.lua' },
  @{ Name = 'Magi duel dam';         After = 'Magi route core';        Source = Join-Path $MagiDir 'Magi_duel_dam.lua' }
)

if (-not (Test-Path -LiteralPath $XmlPackage)) {
  throw "Package XML not found: $XmlPackage"
}

$ScriptsToRemove = @('Yso Bootstrap loader', 'Yso.queue', 'Magi group damage', 'Magi focus')
$TriggersToRemove = @('Reflection up', 'Reflection down')
$MdamAliasSource = Join-Path $MagiDir 'mdam_alias_body.lua'
$MfocusAliasSource = Join-Path $MagiDir 'mfocus_alias_body.lua'
$MreflectAliasSource = Join-Path $MagiDir 'mreflect_alias_body.lua'

$content = Get-Content -LiteralPath $XmlPackage -Raw -Encoding UTF8
$original = $content

foreach ($rm in $ScriptsToRemove) {
  if ($PSCmdlet.ShouldProcess($rm, 'Remove script from package XML')) {
    $content = Remove-ScriptByName $content $rm
  }
}

if ($PSCmdlet.ShouldProcess($XmlPackage, 'Remove orphan Yso.targeting block')) {
  $content = Remove-OrphanTargetingBlock $content
}

foreach ($ins in $ScriptInserts) {
  if ($PSCmdlet.ShouldProcess($ins.Name, "Insert after $($ins.After)")) {
    $content = Add-ScriptAfter $content $ins.After $ins.Name $ins.Source
  }
}

foreach ($entry in $ScriptToSourcePath.GetEnumerator()) {
  $mudletName = [string]$entry.Key
  $srcPath = [string]$entry.Value
  if (-not (Test-Path -LiteralPath $srcPath)) {
    Write-Warning "Skipping '$mudletName' because source is missing: $srcPath"
    continue
  }
  if (-not (Test-ScriptBlockExists $content $mudletName)) {
    Write-Warning "No Script block in XML for '$mudletName' (add to ScriptInserts or create manually)"
    continue
  }
  $lua = Get-Content -LiteralPath $srcPath -Raw -Encoding UTF8
  $escaped = ConvertTo-MudletXmlScriptText $lua
  $nameRe = [regex]::Escape($mudletName)
  $pattern = '(?s)(<Script isActive="yes" isFolder="no">\s*<name>' + $nameRe + '</name>\s*(?:<packageName\s*/>|<packageName>[^<]*</packageName>)\s*<script>)(.*?)(</script>)'
  $m = [regex]::Match($content, $pattern)
  if (-not $m.Success) {
    throw "No Script block matched in XML for name: $mudletName"
  }
  $repl = $m.Groups[1].Value + $escaped + $m.Groups[3].Value
  if ($PSCmdlet.ShouldProcess($mudletName, 'Replace embedded script body')) {
    $content = $content.Substring(0, $m.Index) + $repl + $content.Substring($m.Index + $m.Length)
  }
}

foreach ($tr in $TriggersToRemove) {
  if ($PSCmdlet.ShouldProcess($tr, 'Remove trigger from package XML')) {
    $content = Remove-TriggerByName $content $tr
  }
}

if ($PSCmdlet.ShouldProcess('mgd', 'Remove duplicate mgd alias')) {
  $content = Remove-AliasByName $content 'mgd'
}

if ($PSCmdlet.ShouldProcess('mdam', 'Replace mdam alias script body')) {
  & (Join-Path $ScriptsDir 'build_mdam_alias_body.ps1') | Out-Null
  $content = Set-AliasScriptByName $content 'mdam' $MdamAliasSource
}

if ($PSCmdlet.ShouldProcess('mfocus', 'Replace mfocus alias script body')) {
  & (Join-Path $ScriptsDir 'build_mfocus_alias_body.ps1') | Out-Null
  $content = Set-AliasScriptByName $content 'mfocus' $MfocusAliasSource
}

if ($PSCmdlet.ShouldProcess('Reflection', 'Replace mreflect alias script body')) {
  $content = Set-AliasScriptByName $content 'Reflection' $MreflectAliasSource
  $content = $content.Replace('<regex>^mreflect(?:\s+(on|off|status|\d+))?$</regex>', '<regex>^mreflect(?:\s+(.+))?$</regex>')
}

if ($content -ne $original) {
  if ($PSCmdlet.ShouldProcess($XmlPackage, 'Write updated Yso system.xml')) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($XmlPackage, $content, $utf8NoBom)
  }
  Write-Host "Updated $XmlPackage"
} else {
  Write-Host "No changes."
}

Write-Host "Done. Manifest entries: $($ScriptToSourcePath.Count). Inserts: $($ScriptInserts.Count)."
