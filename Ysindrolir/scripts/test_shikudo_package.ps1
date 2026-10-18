$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$doc = [xml](Get-Content -LiteralPath (Join-Path $root 'mudlet packages/Yso system.xml') -Raw)
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('yso-shikudo-package-' + [guid]::NewGuid())
$mapping = [ordered]@{
  'Yso modes' = 'Yso/xml/yso_modes.lua'
  'Monk reference' = 'Monk/monk_reference.lua'
  'Combo logic' = 'Monk/combo.lua'
  'My Shikudo stance?' = 'Monk/shikudo_forms.lua'
  'Shikudo AI logic' = 'Monk/shikudo_ai.lua'
  'Dispatch execute logic' = 'Monk/shikudo_execute.lua'
}
try {
  foreach ($entry in $mapping.GetEnumerator()) {
    $nodes = @($doc.SelectNodes('//Script') | Where-Object { [string]$_.name -ceq $entry.Key })
    if ($nodes.Count -ne 1 -or $nodes[0].isActive -ne 'yes') { throw "Missing active script: $($entry.Key)" }
    $body = [string]$nodes[0].script
    if ($entry.Key -ne 'Yso modes') {
      $source = [IO.File]::ReadAllText((Join-Path $root $entry.Value))
      if ($body.Replace("`r`n","`n").Trim() -cne $source.Replace("`r`n","`n").Trim()) {
        throw "Package/source mismatch: $($entry.Key)"
      }
    }
    $destination = Join-Path $scratch $entry.Value
    New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
    [IO.File]::WriteAllText($destination, $body, (New-Object Text.UTF8Encoding $false))
  }
  $aliases = @($doc.SelectNodes('//Alias') | Where-Object { [string]$_.regex -ceq '^shdam$' })
  if ($aliases.Count -ne 1 -or $aliases[0].isActive -ne 'yes') { throw 'Expected exactly one active shdam alias' }
  $aliasBody = [string]$aliases[0].script
  if ($aliasBody.Replace("`r`n","`n").Trim() -cne ([IO.File]::ReadAllText((Join-Path $root 'Monk/shdam_alias_body.lua'))).Trim()) {
    throw 'shdam package/source mismatch'
  }
  [IO.File]::WriteAllText((Join-Path $scratch 'Monk/shdam_alias_body.lua'), $aliasBody, (New-Object Text.UTF8Encoding $false))
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_shikudo_route.lua') $scratch
  if ($LASTEXITCODE -ne 0) { throw 'Actual packaged Shikudo/controller regression failed' }
  Write-Host 'PASS: actual packaged Shikudo/controller and maintained-source parity'
} finally {
  $resolved = [IO.Path]::GetFullPath($scratch)
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
      (Split-Path $resolved -Leaf) -notlike 'yso-shikudo-package-*') { throw 'Unsafe scratch cleanup path' }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
