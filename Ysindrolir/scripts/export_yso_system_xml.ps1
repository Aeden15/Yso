# Re-embeds known Mudlet Script bodies in mudlet packages/Yso system.xml from on-disk Lua.
# Manifest: Mudlet script name -> Yso/ (or Alchemist/) source path; edit the hashtable below to add pairs.
# Run:  cd Ysindrolir\scripts ; .\export_yso_system_xml.ps1
# Validate:  [xml](Get-Content -Raw -LiteralPath '..\mudlet packages\Yso system.xml')
# Dry-run:   .\export_yso_system_xml.ps1 -WhatIf
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

$ScriptsDir = Split-Path -Parent $PSCommandPath
$Ysindrolir = Resolve-Path (Join-Path $ScriptsDir '..')
$YsoDir = Join-Path $Ysindrolir 'Yso'
$AlchemistDir = Join-Path $Ysindrolir 'Alchemist'
$XmlPackage = Join-Path $Ysindrolir 'mudlet packages\Yso system.xml'

# Mudlet <name> -> source file (Ysindrolir-relative paths resolved above).
$ScriptToSourcePath = [ordered]@{
  'AK+Legacy wiring'           = Join-Path $YsoDir 'Integration\ak_legacy_wiring.lua'
  'Yso.queue'                   = Join-Path $YsoDir 'Core\queue.lua'
  'Yso.targeting'               = Join-Path $YsoDir 'xml\yso_targeting.lua'
  'Yso.target'                  = Join-Path $YsoDir 'xml\yso_target.lua'
  'yso_target_tattoos.lua'      = Join-Path $YsoDir 'xml\yso_target_tattoos.lua'
  'Parry Module'                = Join-Path $YsoDir 'Combat\parry.lua'
  'Yso Bootstrap loader'        = Join-Path $YsoDir 'xml\yso_bootstrap_loader.lua'
  'Prio Baselines'              = Join-Path $YsoDir 'xml\prio_baselines.lua'
  'Cureset Baselines'           = Join-Path $YsoDir 'xml\cureset_baselines.lua'
  'Yso_Alert_Radiance helper'   = Join-Path $YsoDir 'xml\yso_alert_radiance_helper.lua'
  'Radiance event'              = Join-Path $YsoDir 'xml\radiance_event.lua'
  'Information'                 = Join-Path $YsoDir 'xml\information.lua'
  'Alchemist physiology'        = Join-Path $AlchemistDir 'Core\physiology.lua'
  'humour_balance'              = Join-Path $AlchemistDir 'Triggers\Alchemy\Physiology\humour_balance.lua'
  'formulation'                 = Join-Path $AlchemistDir 'Core\formulation.lua'
  'formulation_phials'          = Join-Path $AlchemistDir 'Core\formulation_phials.lua'
  'formulation_resolve'         = Join-Path $AlchemistDir 'Core\formulation_resolve.lua'
  'formulation_build'           = Join-Path $AlchemistDir 'Core\formulation_build.lua'
  'formulation_chart'           = Join-Path $AlchemistDir 'Core\formulation_chart.lua'
}

if (-not (Test-Path -LiteralPath $XmlPackage)) {
  throw "Package XML not found: $XmlPackage"
}

$content = Get-Content -LiteralPath $XmlPackage -Raw -Encoding UTF8
$original = $content

foreach ($entry in $ScriptToSourcePath.GetEnumerator()) {
  $mudletName = [string]$entry.Key
  $srcPath = [string]$entry.Value
  if (-not (Test-Path -LiteralPath $srcPath)) {
    throw "Source missing for '$mudletName': $srcPath"
  }
  $lua = Get-Content -LiteralPath $srcPath -Raw -Encoding UTF8
  $escaped = ConvertTo-MudletXmlScriptText $lua
  $nameRe = [regex]::Escape($mudletName)
  $pattern = '(?s)(<Script isActive="yes" isFolder="no">\s*<name>' + $nameRe + '</name>\s*<packageName>[^<]*</packageName>\s*<script>)(.*?)(</script>)'
  $m = [regex]::Match($content, $pattern)
  if (-not $m.Success) {
    throw "No Script block matched in XML for name: $mudletName"
  }
  $repl = $m.Groups[1].Value + $escaped + $m.Groups[3].Value
  if ($PSCmdlet.ShouldProcess($mudletName, 'Replace embedded script body')) {
    $content = $content.Substring(0, $m.Index) + $repl + $content.Substring($m.Index + $m.Length)
  }
}

if ($content -ne $original) {
  if ($PSCmdlet.ShouldProcess($XmlPackage, 'Write updated Yso system.xml')) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($XmlPackage, $content, $utf8NoBom)
  }
}

Write-Host "Done. Manifest entries: $($ScriptToSourcePath.Count). Package: $XmlPackage"
