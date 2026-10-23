param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$taskTemp = Join-Path ([IO.Path]::GetTempPath()) ('magi-pebble-' + [guid]::NewGuid())
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Normalize([string]$body) { $body.Trim().Replace("`r`n", "`n") }
function Mask([string]$text) {
  foreach ($entry in @(@('Script','Magi firestorm'), @('Script','Magi water group'), @('Script','Magi focus'), @('Alias','mfocus'))) {
    $pattern = '(?s)<' + $entry[0] + '\b[^>]*>\s*<name>' + [regex]::Escape($entry[1]) + '</name>.*?</' + $entry[0] + '>'
    $text = [regex]::Replace($text, $pattern, '')
  }
  $text
}
New-Item -ItemType Directory -Path $taskTemp | Out-Null
try {
  $copy = Join-Path $taskTemp 'package.xml'
  Copy-Item -LiteralPath $PackagePath -Destination $copy
  $before = [IO.File]::ReadAllText($copy)
  & (Join-Path $PSScriptRoot 'build_magi_pebble_package.ps1') -PackagePath $copy
  $after = [IO.File]::ReadAllText($copy)
  Assert ((Mask $before) -ceq (Mask $after)) 'Pebble builder changed unrelated package content'
  & (Join-Path $PSScriptRoot 'build_magi_pebble_package.ps1') -PackagePath $copy
  Assert ($after -ceq [IO.File]::ReadAllText($copy)) 'Pebble builder is not idempotent'
  [xml]$doc = $after
  foreach ($entry in @(@('Magi firestorm','Magi/Magi_firestorm.lua'), @('Magi water group','Magi/Magi_water_group.lua'))) {
    $nodes = $doc.SelectNodes('//Script[name="' + $entry[0] + '"]')
    Assert ($nodes.Count -eq 1) ('Expected one ' + $entry[0])
    Assert ((Normalize $nodes[0].script) -ceq (Normalize ([IO.File]::ReadAllText((Join-Path $root $entry[1]))))) ('Source mismatch: ' + $entry[0])
  }
  $alias = $doc.SelectSingleNode('//Alias[name="mfocus"]/script')
  Assert ($null -ne $alias) 'Focus alias missing'
  Assert ((Normalize $alias.InnerText) -ceq (Normalize ([IO.File]::ReadAllText((Join-Path $root 'Magi/mfocus_alias_body.lua'))))) 'Focus alias differs from generated source'
  $native = $doc.SelectSingleNode('//Script[name="Magi focus"]/script')
  if ($null -ne $native) {
    $focus = [IO.File]::ReadAllText((Join-Path $root 'Magi/magi_focus.lua'))
    Assert ($native.InnerText.Contains($focus)) 'Native Focus does not contain maintained source'
  }
  $luac = Get-Command luac -ErrorAction Stop
  $i = 0
  foreach ($node in $doc.SelectNodes('//Script[name="Magi firestorm" or name="Magi water group" or name="Magi focus"]/script | //Alias[name="mfocus"]/script')) {
    $luaPath = Join-Path $taskTemp ((++$i).ToString() + '.lua')
    [IO.File]::WriteAllText($luaPath, $node.InnerText, (New-Object Text.UTF8Encoding $false))
    & $luac.Source -p $luaPath
    Assert ($LASTEXITCODE -eq 0) ('Invalid embedded Lua: ' + $node.ParentNode.name)
  }
  Write-Host 'PASS: scoped Magi Pebble package build, source parity, idempotence and embedded Lua syntax'
} finally {
  $resolvedTemp = (Resolve-Path -LiteralPath $taskTemp).Path
  $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  if ((Split-Path $resolvedTemp -Parent) -ne $expectedParent -or (Split-Path $resolvedTemp -Leaf) -notlike 'magi-pebble-*') {
    throw 'Refusing to remove an unexpected test directory'
  }
  Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
}
