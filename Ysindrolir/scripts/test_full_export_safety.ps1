# Real full-export regressions. All builders and source writes stay in a disposable copy.
[CmdletBinding()]
param([ValidateSet('Full','Failure','PackagePath','Scoped','All')][string]$Case = 'All')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
# Use the writable workspace volume: Windows sandbox temp storage rejects atomic
# replacement of existing files, whereas the package's actual volume supports it.
$scratch = Join-Path $root ('.tmp-yso-full-export-' + [guid]::NewGuid())
function Assert([bool]$condition, [string]$message) { if (-not $condition) { throw $message } }
function XmlSource([string]$path) { [IO.File]::ReadAllText($path).Replace("`r`n", "`n").Replace("`r", "`n") }
try {
  New-Item -ItemType Directory -Path $scratch | Out-Null
  foreach ($folder in @('scripts','Yso','Alchemist','Apostate','Magi','Monk','Airlord','mudlet packages')) {
    Copy-Item -LiteralPath (Join-Path $root $folder) -Destination $scratch -Recurse
  }
  $exporter = Join-Path $scratch 'scripts/export_yso_system_xml.ps1'
  $package = Join-Path $scratch 'mudlet packages/Yso system.xml'
  $before = [IO.File]::ReadAllText($package)
  $beforeHash = (Get-FileHash -LiteralPath $package).Hash
  if ($Case -in @('Full','All')) {
    # Removing Script nodes must distinguish </Script> from their </script> children.
    try { & $exporter } catch { throw "Full export must succeed with native Magi focus present: $($_.Exception.Message)" }
    $after = [IO.File]::ReadAllText($package)
    $doc = [xml]$after
    Assert ($null -eq $doc.SelectSingleNode("//Script[name='Magi focus']")) 'Full export did not retire the native focus script'
    foreach ($pair in @(@('Magi route core','Magi/magi_route_core.lua'), @('Magi water group','Magi/Magi_water_group.lua'), @('Shikudo AI logic','Monk/shikudo_ai.lua'))) {
      Assert ([string]$doc.SelectSingleNode("//Script[name='$($pair[0])']").script -ceq (XmlSource (Join-Path $scratch $pair[1]))) "Source parity failed: $($pair[0])"
    }
    Assert ([string]$doc.SelectSingleNode("//Alias[name='mfocus']").script -ceq (XmlSource (Join-Path $scratch 'Magi/mfocus_alias_body.lua'))) 'Focus alias does not contain the built modern implementation'
    Assert ([string]$doc.SelectSingleNode("//Alias[name='Reflection']").script -ceq (XmlSource (Join-Path $scratch 'Magi/mreflect_alias_body.lua'))) 'Reflection alias source parity failed'
    & $exporter
    Assert ([IO.File]::ReadAllText($package) -ceq $after) 'Full export is not idempotent'
    Write-Host 'PASS: full export, Magi native retirement and aliases, source parity, idempotence'
  }
  if ($Case -in @('Failure','All')) {
    [IO.File]::WriteAllText($package, $before)
    # This source is read during the final nested scoped pass, after the legacy refresh.
    [IO.File]::AppendAllText((Join-Path $scratch 'Monk/shikudo_ai.lua'), ([string][char]0))
    $failed = $false
    try { & $exporter } catch { $failed = $true }
    Assert $failed 'Invalid late-stage XML source must reject the export'
    Assert ((Get-FileHash -LiteralPath $package).Hash -eq $beforeHash) 'Failed full export changed destination bytes'
    Assert (@(Get-ChildItem -LiteralPath (Split-Path $package -Parent) -Filter '.yso-export-*.xml' -Force).Count -eq 0) 'Failed export left a staged package behind'
    Write-Host 'PASS: late validation failure preserves original destination bytes'
  }
  if ($Case -in @('PackagePath','Scoped','All')) {
    # Restore sources after the injected failure, and use a nondefault destination.
    Copy-Item -LiteralPath (Join-Path $root 'Monk/shikudo_ai.lua') -Destination (Join-Path $scratch 'Monk/shikudo_ai.lua')
    [IO.File]::WriteAllText($package, $before)
    $custom = Join-Path $scratch 'custom.xml'
    [IO.File]::WriteAllText($custom, $before)
    & $exporter -PackagePath $custom -WhatIf
    Assert ([IO.File]::ReadAllText($custom) -ceq $before) 'WhatIf changed custom destination'
    if ($Case -in @('PackagePath','All')) { & $exporter -PackagePath $custom }
    if ($Case -in @('Scoped','All')) {
      [IO.File]::WriteAllText($custom, $before)
      & $exporter -PackagePath $custom -FocusOnly
      $focusDoc = [xml][IO.File]::ReadAllText($custom)
      Assert ($null -ne $focusDoc.SelectSingleNode("//Script[name='Magi focus']")) 'FocusOnly unexpectedly retired the native focus script'
      & $exporter -PackagePath $custom -ShikudoOnly -KaiSoarOnly
      & $exporter -PackagePath $custom -CombatSafetyOnly
      & $exporter -PackagePath $custom -ShikudoDuelOnly
    }
    $null = [xml][IO.File]::ReadAllText($custom)
    Assert ([IO.File]::ReadAllText($custom) -cne $before) 'Custom destination was not updated'
    Assert ([IO.File]::ReadAllText($package) -ceq $before) 'Custom destination export changed default package'
    Write-Host 'PASS: PackagePath, WhatIf and scoped destination isolation'
  }
} finally {
  $resolved = [IO.Path]::GetFullPath($scratch)
  $expectedParent = [IO.Path]::GetFullPath($root)
  if ((Split-Path $resolved -Parent) -cne $expectedParent -or (Split-Path $resolved -Leaf) -notlike '.tmp-yso-full-export-*') { throw 'Unsafe scratch cleanup path' }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
