# Re-embed on-disk Lua into mudlet packages/Yso system.xml (Mudlet-native workflow).
# Api stuff SSOT: Yso/xml/api_stuff.lua (Core/api.lua is a load shim only).
# Run:  cd Ysindrolir\scripts ; .\export_yso_system_xml.ps1
# Validate:  [xml](Get-Content -Raw -LiteralPath '..\mudlet packages\Yso system.xml')
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [switch]$FocusOnly, [switch]$SoarOnly, [switch]$DeliveranceOnly, [switch]$CombatSafetyOnly, [switch]$StormhammerOnly,
  [string]$PackagePath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml')
)

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
  if (-not $m.Success) {
    Write-Warning "Insert anchor not found for '$newName' after '$afterName'"
    return $content
  }
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
  return ([regex]::new($pattern)).Replace($content, '', 1)
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
  return ([regex]::new($pattern)).Replace(
    $content,
    "`n        <Script isActive=`"yes`" isFolder=`"no`">`n          <name>AK+Legacy wiring</name>",
    1
  )
}

$ScriptsDir = Split-Path -Parent $PSCommandPath
$Ysindrolir = Resolve-Path (Join-Path $ScriptsDir '..')
$YsoDir = Join-Path $Ysindrolir 'Yso'
$AlchemistDir = Join-Path $Ysindrolir 'Alchemist'
$MagiDir = Join-Path $Ysindrolir 'Magi'
$XmlPackage = [IO.Path]::GetFullPath($PackagePath)

$ScriptToSourcePath = [ordered]@{
  'AK+Legacy wiring'              = Join-Path $YsoDir 'Integration\ak_legacy_wiring.lua'
  'Api stuff'                     = Join-Path $YsoDir 'xml\api_stuff.lua'
  'Apostate utilities'            = Join-Path $YsoDir 'xml\apostate_utilities.lua'
  'Apostate reference'            = Join-Path $Ysindrolir 'Apostate\evileye_reference.lua'
  'Apostasy reference'            = Join-Path $Ysindrolir 'Apostate\apostasy_reference.lua'
  'Necromancy reference'          = Join-Path $Ysindrolir 'Apostate\necromancy_reference.lua'
  'Deadeye combo sorter'          = Join-Path $Ysindrolir 'Apostate\deadeyes.lua'
  'Apostate daegger envenom'       = Join-Path $Ysindrolir 'Apostate\daegger_envenom.lua'
  'Apostate entourage'            = Join-Path $Ysindrolir 'Apostate\entourage.lua'
  'Apostate Truelocks'             = Join-Path $Ysindrolir 'Apostate\lock_route.lua'
  'Alchemist aurify route'        = Join-Path $AlchemistDir 'Aurify route.lua'
  'Alchemist duel route'          = Join-Path $AlchemistDir 'Core\duel route.lua'
  'Alchemist group damage'        = Join-Path $AlchemistDir 'Core\group damage.lua'
  'Alchemist physiology'          = Join-Path $AlchemistDir 'Core\physiology.lua'
  'Bash Vitals Swap'              = Join-Path $YsoDir 'Curing\bash_vitals_swap.lua'
  'Cureset Baselines'             = Join-Path $YsoDir 'xml\cureset_baselines.lua'
  'Defensive checks'              = Join-Path $YsoDir 'xml\magi_defensive_checks.lua'
  'Magi route core'               = Join-Path $MagiDir 'magi_route_core.lua'
  'Magi group route retirement'   = Join-Path $MagiDir 'retire_group_damage.lua'
  'Magi weapons'                  = Join-Path $MagiDir 'magi_weapons.lua'
  'Magi shalestorm'               = Join-Path $MagiDir 'magi_shalestorm.lua'
  'Magi hellfumes'                = Join-Path $MagiDir 'magi_hellfumes.lua'
  'Magi duel dam'                 = Join-Path $MagiDir 'Magi_duel_dam.lua'
  'Magi firestorm'                = Join-Path $MagiDir 'Magi_firestorm.lua'
  'Magi water group'              = Join-Path $MagiDir 'Magi_water_group.lua'
  'Magi elemental helpers'        = Join-Path $YsoDir 'xml\magi_elemental_helpers.lua'
  'Convergence logic'             = Join-Path $MagiDir 'magi_convergence.lua'
  'formulation'                   = Join-Path $AlchemistDir 'Core\formulation.lua'
  'formulation_build'             = Join-Path $AlchemistDir 'Core\formulation_build.lua'
  'formulation_chart'             = Join-Path $AlchemistDir 'Core\formulation_chart.lua'
  'formulation_phials'            = Join-Path $AlchemistDir 'Core\formulation_phials.lua'
  'formulation_phiallist'         = Join-Path $AlchemistDir 'Triggers\Alchemy\Formulation\phiallist.lua'
  'formulation_resolve'           = Join-Path $AlchemistDir 'Core\formulation_resolve.lua'
  'hinder'                        = Join-Path $YsoDir 'Combat\hinder.lua'
  'humour_balance'                = Join-Path $AlchemistDir 'Triggers\Alchemy\Physiology\humour_balance.lua'
  'Information'                   = Join-Path $YsoDir 'xml\information.lua'
  'Offense Template'              = Join-Path $YsoDir 'xml\offense_template.lua'
  'Parry Module'                  = Join-Path $YsoDir 'Combat\parry.lua'
  'Prio Baselines'                = Join-Path $YsoDir 'xml\prio_baselines.lua'
  'Combat paralysis policy'       = Join-Path $YsoDir 'Combat\combat_pause.lua'
  'Compression logic'             = Join-Path $Ysindrolir 'Airlord\compression.lua'
  'Airlord route runtime'          = Join-Path $Ysindrolir 'Airlord\route_runtime.lua'
  'Airlord lock route'             = Join-Path $Ysindrolir 'Airlord\lock_route.lua'
  'Airlord damage route'           = Join-Path $Ysindrolir 'Airlord\damage_route.lua'
  'Route registry'                = Join-Path $YsoDir 'Combat\route_registry.lua'
  'route_gate'                    = Join-Path $YsoDir 'Combat\route_gate.lua'
  'Route chassis loader'          = Join-Path $YsoDir 'xml\route_chassis_loader.lua'
  'Offense core'                  = Join-Path $YsoDir 'Combat\offense_core.lua'
  'Tree auto'                     = Join-Path $YsoDir 'xml\magi_tree_auto.lua'
  'yso_target_tattoos.lua'        = Join-Path $YsoDir 'xml\yso_target_tattoos.lua'
  'Yso serverside policy'         = Join-Path $YsoDir 'Curing\serverside_policy.lua'
  'Yso self aff'                  = Join-Path $YsoDir 'Core\self_aff.lua'
  'Yso self curedefs'             = Join-Path $YsoDir 'Curing\self_curedefs.lua'
  'Yso.engine (event plumbing)'   = Join-Path $YsoDir 'xml\yso_engine.lua'
  'Yso.offense.request_tick'      = Join-Path $YsoDir 'xml\yso_offense_request_tick.lua'
  'Yso modes'                     = Join-Path $YsoDir 'xml\yso_modes.lua'
  'Yso party targeting'           = Join-Path $YsoDir 'xml\yso_party_targeting.lua'
  'Yso pulse'                     = Join-Path $YsoDir 'xml\yso_pulse_wake_bus.lua'
  'Yso.state wiring'              = Join-Path $YsoDir 'xml\yso_state_wiring_stub.lua'
  'Yso.target'                    = Join-Path $YsoDir 'xml\yso_target.lua'
  'Yso.targeting'                 = Join-Path $YsoDir 'xml\yso_targeting.lua'
}

$ScriptInserts = @(
  @{ Name = 'Airlord route runtime'; After = 'Compression logic'; Source = Join-Path $Ysindrolir 'Airlord\route_runtime.lua' },
  @{ Name = 'Airlord lock route'; After = 'Airlord route runtime'; Source = Join-Path $Ysindrolir 'Airlord\lock_route.lua' },
  @{ Name = 'Airlord damage route'; After = 'Airlord lock route'; Source = Join-Path $Ysindrolir 'Airlord\damage_route.lua' },
  @{ Name = 'Yso self aff';           After = 'Api stuff';                Source = Join-Path $YsoDir 'Core\self_aff.lua' },
  @{ Name = 'Yso self curedefs';      After = 'Yso self aff';             Source = Join-Path $YsoDir 'Curing\self_curedefs.lua' },
  @{ Name = 'Yso modes';             After = 'Api stuff';                Source = Join-Path $YsoDir 'xml\yso_modes.lua' },
  @{ Name = 'Yso serverside policy'; After = 'Yso modes';                Source = Join-Path $YsoDir 'Curing\serverside_policy.lua' },
  @{ Name = 'Yso party targeting';   After = 'Yso modes';                Source = Join-Path $YsoDir 'xml\yso_party_targeting.lua' },
  @{ Name = 'Yso pulse';             After = 'Yso modes';                Source = Join-Path $YsoDir 'xml\yso_pulse_wake_bus.lua' },
  @{ Name = 'Combat paralysis policy'; After = 'Route registry'; Source = Join-Path $YsoDir 'Combat\combat_pause.lua' },
  @{ Name = 'Route registry';        After = 'Yso pulse';                Source = Join-Path $YsoDir 'Combat\route_registry.lua' },
  @{ Name = 'Magi group route retirement'; After = 'Route registry'; Source = Join-Path $MagiDir 'retire_group_damage.lua' },
  @{ Name = 'Offense core';          After = 'Yso.offense.request_tick'; Source = Join-Path $YsoDir 'Combat\offense_core.lua' },
  @{ Name = 'Alchemist duel route';  After = 'Alchemist physiology';     Source = Join-Path $AlchemistDir 'Core\duel route.lua' },
  @{ Name = 'Alchemist aurify route'; After = 'Alchemist duel route';    Source = Join-Path $AlchemistDir 'Aurify route.lua' },
  @{ Name = 'Defensive checks';      After = 'Route registry';           Source = Join-Path $YsoDir 'xml\magi_defensive_checks.lua' },
  @{ Name = 'Magi route core';       After = 'Defensive checks';         Source = Join-Path $MagiDir 'magi_route_core.lua' },
  @{ Name = 'Magi weapons';          After = 'Magi route core';          Source = Join-Path $MagiDir 'magi_weapons.lua' },
  @{ Name = 'Magi shalestorm';       After = 'Magi weapons';             Source = Join-Path $MagiDir 'magi_shalestorm.lua' },
  @{ Name = 'Magi hellfumes';        After = 'Magi shalestorm';          Source = Join-Path $MagiDir 'magi_hellfumes.lua' },
  @{ Name = 'Magi duel dam';         After = 'Magi hellfumes';           Source = Join-Path $MagiDir 'Magi_duel_dam.lua' },
  @{ Name = 'Magi firestorm';        After = 'Magi duel dam';            Source = Join-Path $MagiDir 'Magi_firestorm.lua' },
  @{ Name = 'Magi water group';      After = 'Magi firestorm';           Source = Join-Path $MagiDir 'Magi_water_group.lua' },
  @{ Name = 'Magi elemental helpers'; After = 'Magi water group';        Source = Join-Path $YsoDir 'xml\magi_elemental_helpers.lua' },
  @{ Name = 'formulation';           After = 'AK+Legacy wiring';       Source = Join-Path $AlchemistDir 'Core\formulation.lua' },
  @{ Name = 'formulation_resolve';   After = 'formulation';            Source = Join-Path $AlchemistDir 'Core\formulation_resolve.lua' },
  @{ Name = 'formulation_phials';    After = 'formulation_resolve';    Source = Join-Path $AlchemistDir 'Core\formulation_phials.lua' },
  @{ Name = 'formulation_build';     After = 'formulation_phials';     Source = Join-Path $AlchemistDir 'Core\formulation_build.lua' },
  @{ Name = 'formulation_chart';     After = 'formulation_build';      Source = Join-Path $AlchemistDir 'Core\formulation_chart.lua' },
  @{ Name = 'formulation_phiallist'; After = 'formulation_chart';      Source = Join-Path $AlchemistDir 'Triggers\Alchemy\Formulation\phiallist.lua' }
)

if (-not (Test-Path -LiteralPath $XmlPackage)) {
  throw "Package XML not found: $XmlPackage"
}

$ScriptsToRemove = @('Yso Bootstrap loader', 'Yso.queue', 'Magi group damage', 'Magi focus', 'Bloodboil auto', 'Airlord attack logic')
$TriggersToRemove = @('Reflection up', 'Reflection down')
$MdamAliasSource = Join-Path $MagiDir 'mdam_retired_alias.lua'
$MfocusAliasSource = Join-Path $MagiDir 'mfocus_alias_body.lua'
$MreflectAliasSource = Join-Path $MagiDir 'mreflect_alias_body.lua'

$content = Get-Content -LiteralPath $XmlPackage -Raw -Encoding UTF8
$original = $content

if ($StormhammerOnly) {
  if ($FocusOnly -or $SoarOnly -or $DeliveranceOnly -or $CombatSafetyOnly) {
    throw 'StormhammerOnly must be run separately from other scoped exports.'
  }
  if ($PSCmdlet.ShouldProcess($XmlPackage, 'Synchronize Stormhammer and target priorities')) {
    & (Join-Path $ScriptsDir 'build_stormhammer_package.ps1') -PackagePath $XmlPackage
  }
  return
}

if ($CombatSafetyOnly) {
  if ($FocusOnly -or $SoarOnly -or $DeliveranceOnly) {
    throw 'CombatSafetyOnly must be run separately from other scoped exports.'
  }
  if ($PSCmdlet.ShouldProcess($XmlPackage, 'Synchronize Deliverance safety and resonance feedback')) {
    & (Join-Path $ScriptsDir 'build_combat_safety_package.ps1') -PackagePath $XmlPackage
  }
  return
}

# Scoped Deliverance and Airlord soar maintenance.
if ($SoarOnly -or $DeliveranceOnly) {
  if ($FocusOnly) { throw 'FocusOnly cannot be combined with SoarOnly or DeliveranceOnly.' }
  if ($PSCmdlet.ShouldProcess($XmlPackage, 'Synchronize Deliverance and soar')) {
    if ($SoarOnly) { & (Join-Path $ScriptsDir 'build_airlord_soar_package.ps1') -PackagePath $XmlPackage }
    if ($DeliveranceOnly) { & (Join-Path $ScriptsDir 'build_deliverance_package.ps1') -PackagePath $XmlPackage }
  }
  return
}

# Update Focus without replacing unrelated native scripts from older source mirrors.
if ($FocusOnly) {
  if ($PSCmdlet.ShouldProcess($XmlPackage, 'Synchronize Focus script and alias only')) {
    & (Join-Path $ScriptsDir 'build_mfocus_alias_body.ps1') | Out-Null
    $content = Set-AliasScriptByName $content 'mfocus' $MfocusAliasSource
    if (Test-ScriptBlockExists $content 'Magi focus') {
      $dissonance = (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $MagiDir 'magi_dissonance.lua')).TrimEnd()
      $dissonance = $dissonance -replace '(?m)^return D\s*$', '-- return omitted: native Focus shares Yso.magi.dissonance'
      $focus = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $MagiDir 'magi_focus.lua')
      $escaped = ConvertTo-MudletXmlScriptText ($dissonance + "`n`n" + $focus)
      $pattern = '(?s)(<Script isActive="yes" isFolder="no">\s*<name>Magi focus</name>\s*(?:<packageName\s*/>|<packageName>[^<]*</packageName>)\s*<script>)(.*?)(</script>)'
      $match = [regex]::Match($content, $pattern)
      if (-not $match.Success) { throw 'Cannot locate native Magi focus script body' }
      $content = $content.Substring(0, $match.Index) + $match.Groups[1].Value + $escaped + $match.Groups[3].Value + $content.Substring($match.Index + $match.Length)
    }
    $document = New-Object System.Xml.XmlDocument
    try { $document.LoadXml($content) } catch { throw $_.Exception.InnerException.Message }
    if ($content -cne $original) {
      [System.IO.File]::WriteAllText($XmlPackage, $content, (New-Object System.Text.UTF8Encoding $false))
    }
    Write-Host 'Synchronized Focus script and alias; unrelated package content preserved.'
  }
  return
}

# A full refresh includes the final scoped builders. Keep every package mutation
# on a sibling file until all stages have succeeded and their XML is validated.
$destination = $XmlPackage
$stagedPackage = $null
try {
if (-not $WhatIfPreference) {
  $stagedPackage = Join-Path (Split-Path $destination -Parent) ('.yso-export-' + [guid]::NewGuid() + '.xml')
  [IO.File]::Copy($destination, $stagedPackage)
  $XmlPackage = $stagedPackage
}

foreach ($rm in $ScriptsToRemove) {
  if ($PSCmdlet.ShouldProcess($rm, 'Remove script from package XML')) {
    $content = Remove-ScriptByName $content $rm
  }
}

if ($PSCmdlet.ShouldProcess($XmlPackage, 'Remove orphan Yso.targeting block')) {
  $content = Remove-OrphanTargetingBlock $content
}

if ($PSCmdlet.ShouldProcess('alupdraft', 'Move optional Updraft to the separate Airlord damage route')) {
  $content = $content.Replace('Yso.off.airlord.lock.toggle_updraft()', 'Yso.off.airlord.damage.toggle_updraft()')
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

if ($PSCmdlet.ShouldProcess('Targeting', 'Remove y targeting alias')) {
  $content = Remove-AliasByName $content 'Targeting'
}

if ($PSCmdlet.ShouldProcess('mdam', 'Replace mdam alias script body')) {
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
    $document = New-Object System.Xml.XmlDocument
    $document.LoadXml($content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($XmlPackage, $content, $utf8NoBom)
  }
  Write-Host "Updated $XmlPackage"
} else {
  Write-Host "No changes."
}

Write-Host "Done. Manifest entries: $($ScriptToSourcePath.Count). Inserts: $($ScriptInserts.Count)."

# Keep the maintained combat entries synchronized after a legacy full refresh too.
if ($PSCmdlet.ShouldProcess($XmlPackage, 'Synchronize Deliverance and Airlord soar entries')) {
  & (Join-Path $ScriptsDir 'build_airlord_soar_package.ps1') -PackagePath $XmlPackage
  & (Join-Path $ScriptsDir 'build_deliverance_package.ps1') -PackagePath $XmlPackage
}

if ($PSCmdlet.ShouldProcess($XmlPackage, 'Synchronize maintained Stormhammer and target priorities')) {
  & (Join-Path $ScriptsDir 'build_stormhammer_package.ps1') -PackagePath $XmlPackage
}

if ($PSCmdlet.ShouldProcess($XmlPackage, 'Synchronize login safety')) {
  & (Join-Path $ScriptsDir 'build_login_safety_package.ps1') -PackagePath $XmlPackage
}

if ($null -ne $stagedPackage) {
  $document = New-Object System.Xml.XmlDocument
  $document.Load($stagedPackage)
  if ([IO.File]::ReadAllText($stagedPackage) -cne $original -and
      $PSCmdlet.ShouldProcess($destination, 'Publish validated full package export')) {
    [IO.File]::Replace($stagedPackage, $destination, [System.Management.Automation.Language.NullString]::Value)
  }
}
} finally {
  if ($null -ne $stagedPackage -and [IO.File]::Exists($stagedPackage)) {
    [IO.File]::Delete($stagedPackage)
  }
}
