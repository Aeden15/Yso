param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('magi-entourage-' + [guid]::NewGuid())
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Normalize([string]$text) { $text.Trim().Replace("`r`n", "`n") }
function Mask([string]$text) {
  foreach ($entry in @(@('Script','Magi route core'),@('Script','Magi duel dam'),@('Script','Magi firestorm'),@('Script','Magi water group'),@('Script','Magi focus'),@('Alias','mfocus'))) {
    $text = [regex]::Replace($text, '(?s)<' + $entry[0] + '\b[^>]*>\s*<name>' + [regex]::Escape($entry[1]) + '</name>.*?</' + $entry[0] + '>', '')
  }
  $text
}
New-Item -ItemType Directory -Path (Join-Path $scratch 'Magi') -Force | Out-Null
try {
  $copy = Join-Path $scratch 'package.xml'
  Copy-Item -LiteralPath $PackagePath -Destination $copy
  $before = [IO.File]::ReadAllText($copy)
  & (Join-Path $PSScriptRoot 'build_magi_entourage_package.ps1') -PackagePath $copy
  $after = [IO.File]::ReadAllText($copy)
  Assert ((Mask $before) -ceq (Mask $after)) 'Unrelated package content changed'
  & (Join-Path $PSScriptRoot 'build_magi_entourage_package.ps1') -PackagePath $copy
  Assert ($after -ceq [IO.File]::ReadAllText($copy)) 'Builder is not idempotent'
  [xml]$doc = $after
  foreach ($entry in @(@('Magi route core','magi_route_core.lua'),@('Magi duel dam','Magi_duel_dam.lua'),@('Magi firestorm','Magi_firestorm.lua'),@('Magi water group','Magi_water_group.lua'))) {
    $nodes = $doc.SelectNodes('//Script[name="' + $entry[0] + '"]/script')
    Assert ($nodes.Count -eq 1) ('Missing/duplicate ' + $entry[0])
    Assert ((Normalize $nodes[0].InnerText) -ceq (Normalize ([IO.File]::ReadAllText((Join-Path $root ('Magi/' + $entry[1])))))) ('Source parity failed: ' + $entry[0])
    [IO.File]::WriteAllText((Join-Path $scratch ('Magi/' + $entry[1])), $nodes[0].InnerText)
  }
  $alias = $doc.SelectSingleNode('//Alias[name="mfocus"]/script').InnerText
  Assert ((Normalize $alias) -ceq (Normalize ([IO.File]::ReadAllText((Join-Path $root 'Magi/mfocus_alias_body.lua'))))) 'Focus alias parity failed'
  $native = $doc.SelectSingleNode('//Script[name="Magi focus"]/script')
  $focus = if ($null -ne $native) { $native.InnerText } else { $alias }
  [IO.File]::WriteAllText((Join-Path $scratch 'Magi/magi_focus.lua'), $focus)
  Copy-Item -LiteralPath (Join-Path $root 'Magi/magi_dissonance.lua') -Destination (Join-Path $scratch 'Magi/magi_dissonance.lua')
  foreach ($node in $doc.SelectNodes('//Script[name="Magi route core" or name="Magi duel dam" or name="Magi firestorm" or name="Magi water group" or name="Magi focus"]/script | //Alias[name="mfocus"]/script')) {
    $check = Join-Path $scratch 'syntax.lua'
    [IO.File]::WriteAllText($check, $node.InnerText)
    & luac -p $check
    Assert ($LASTEXITCODE -eq 0) ('Invalid embedded Lua: ' + $node.ParentNode.name)
  }
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_magi_entourage.lua') ($scratch.Replace('\','/') + '/') $root
  Assert ($LASTEXITCODE -eq 0) 'Packaged entourage behavioral checks failed'
  Write-Host 'PASS: scoped package build, parity, idempotence, embedded Lua syntax and packaged entourage behavior'
} finally {
  $resolved = [IO.Path]::GetFullPath($scratch)
  $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  if ((Split-Path $resolved -Parent) -ne $parent -or (Split-Path $resolved -Leaf) -notlike 'magi-entourage-*') { throw 'Unexpected scratch directory' }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
