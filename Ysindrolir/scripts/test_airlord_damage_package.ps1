param([string]$PackagePath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('yso-airlord-damage-' + [guid]::NewGuid())
try {
  [xml]$doc = [IO.File]::ReadAllText($PackagePath)
  foreach ($entry in @(@('Compression logic', '.compression.lua'), @('Airlord attack logic', '.attack.lua'), @('Api stuff', '.api.lua'))) {
    $nodes = $doc.SelectNodes('//Script[name="' + $entry[0] + '"]')
    if ($nodes.Count -ne 1) { throw ('Expected one script: ' + $entry[0]) }
    [IO.File]::WriteAllText(($scratch + $entry[1]), [string]$nodes[0].script, (New-Object Text.UTF8Encoding $false))
  }
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_airlord_damage.lua') $scratch
  if ($LASTEXITCODE -ne 0) { throw 'Airlord damage regressions failed' }
} finally {
  foreach ($suffix in @('.compression.lua', '.attack.lua', '.api.lua')) {
    $path = $scratch + $suffix
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
  }
}
