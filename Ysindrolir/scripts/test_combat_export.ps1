$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$exporter = Join-Path $PSScriptRoot 'export_yso_system_xml.ps1'
$package = Join-Path $root 'mudlet packages/Yso system.xml'
$before = (Get-FileHash -LiteralPath $package).Hash
& $exporter -SoarOnly -DeliveranceOnly -WhatIf
if ((Get-FileHash -LiteralPath $package).Hash -ne $before) { throw 'WhatIf changed the package' }
Write-Host 'PASS: scoped export WhatIf preserves package'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('yso-combat-export-' + [guid]::NewGuid())
try {
  foreach ($folder in @('scripts','Yso/Combat','Airlord','mudlet packages')) {
    New-Item -ItemType Directory -Path (Join-Path $scratch $folder) -Force | Out-Null
  }
  foreach ($name in @('export_yso_system_xml.ps1','build_deliverance_package.ps1','build_airlord_soar_package.ps1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $scratch 'scripts')
  }
  Copy-Item -Path (Join-Path $root 'Yso/Combat/deliverance*.lua') -Destination (Join-Path $scratch 'Yso/Combat')
  Copy-Item -LiteralPath (Join-Path $root 'Airlord/soar_alias.lua') -Destination (Join-Path $scratch 'Airlord')
  $copy = Join-Path $scratch 'mudlet packages/Yso system.xml'
  Copy-Item -LiteralPath $package -Destination $copy
  $fixtureAi = Join-Path $scratch 'Yso/Combat/deliverance_resource.lua'
  [IO.File]::AppendAllText($fixtureAi, "`n-- scoped export regression fixture`n")
  & (Join-Path $scratch 'scripts/export_yso_system_xml.ps1') -SoarOnly -DeliveranceOnly
  $after = [IO.File]::ReadAllText($copy)
  $doc = [xml]$after
  if ([string]$doc.SelectSingleNode("//Script[name='Deliverance resource']").script -cne [IO.File]::ReadAllText($fixtureAi).TrimEnd()) {
    throw 'Scoped export did not synchronize AI source'
  }
  $originalDoc = [xml][IO.File]::ReadAllText($package)
  $updatedScripts = @('Deliverance resource')
  foreach ($node in $originalDoc.SelectNodes('//Script|//Alias|//Trigger')) {
    $name = [string]$node.name
    if (($node.LocalName -eq 'Script' -and $name -in $updatedScripts) -or
        ($node.LocalName -eq 'Alias' -and $name -in @('Deliverance','Soaring')) -or
        ($false)) { continue }
    $candidates = @($doc.SelectNodes('//' + $node.LocalName) | Where-Object { [string]$_.name -ceq $name })
    if ($candidates.Count -eq 1 -and $candidates[0].OuterXml -cne $node.OuterXml) {
      throw "Scoped export modified unrelated entry: $name"
    }
  }
  & (Join-Path $scratch 'scripts/export_yso_system_xml.ps1') -SoarOnly -DeliveranceOnly
  if ([IO.File]::ReadAllText($copy) -cne $after) { throw 'Scoped export is not idempotent' }
  Write-Host 'PASS: scoped export source parity, unrelated entries preserved, idempotence'
} finally {
  $resolved = [IO.Path]::GetFullPath($scratch)
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
      (Split-Path $resolved -Leaf) -notlike 'yso-combat-export-*') { throw 'Unsafe scratch cleanup path' }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
