# Builder/source checkout line endings must not alter a maintained package.
[CmdletBinding()]
param([string[]]$BaselinePackagePaths = @((Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Legacy Basher V2.1.xml')))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('yso-hunting-newlines-' + [guid]::NewGuid())
function Newlines([string]$text, [string]$newline) { [regex]::Replace($text, '\r\n?|\n', $newline) }
try {
  New-Item -ItemType Directory -Path (Join-Path $scratch 'scripts') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $scratch 'Apostate') -Force | Out-Null
  $builder = Join-Path $scratch 'scripts/build_apostate_hunting_package.ps1'
  $helper = Join-Path $scratch 'Apostate/hunting_soulstorm.lua'
  $package = Join-Path $scratch 'package.xml'
  $builderSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'build_apostate_hunting_package.ps1'))
  $helperSource = [IO.File]::ReadAllText((Join-Path $root 'Apostate/hunting_soulstorm.lua'))
  foreach ($baselinePath in $BaselinePackagePaths) {
    $baseline = [IO.File]::ReadAllText($baselinePath)
    foreach ($builderNewline in @("`n", "`r`n")) {
      [IO.File]::WriteAllText($builder, (Newlines $builderSource $builderNewline))
      foreach ($sourceNewline in @("`n", "`r`n")) {
        [IO.File]::WriteAllText($helper, (Newlines $helperSource $sourceNewline))
        foreach ($packageNewline in @("`n", "`r`n")) {
          $expected = Newlines $baseline $packageNewline
          [IO.File]::WriteAllText($package, $expected)
          & $builder -PackagePath $package
          $actual = [IO.File]::ReadAllText($package)
          if (([xml]$actual).OuterXml -cne ([xml]$expected).OuterXml) { throw "Builder changed XML semantics for $baselinePath" }
          if ($actual -cne $expected) {
            throw "Builder changed package line endings for $baselinePath (builder CRLF=$($builderNewline.Length -eq 2), source CRLF=$($sourceNewline.Length -eq 2), package CRLF=$($packageNewline.Length -eq 2))"
          }
          # Exercise first-time insertions as well as the maintained-package path.
          $withoutAdapters = [regex]::Replace($expected, '(?s)<Script\b[^>]*>\s*<name>Apostate hunting Soulstorm</name>.*?</Script>\r?\n?', '')
          $withoutAdapters = [regex]::Replace($withoutAdapters, '(?s)<Trigger\b[^>]*>\s*<name>Apostate Soulstorm [^<]+</name>.*?</Trigger>\r?\n?', '')
          [IO.File]::WriteAllText($package, $withoutAdapters)
          & $builder -PackagePath $package
          $installed = [IO.File]::ReadAllText($package)
          if ($installed -cne (Newlines $installed $packageNewline)) { throw 'First-time adapter insertion mixed package line endings' }
          $installedDoc = [xml]$installed
          if ($null -eq $installedDoc.SelectSingleNode('//Script[name="Apostate hunting Soulstorm"]') -or $installedDoc.SelectNodes('//Trigger[starts-with(name,"Apostate Soulstorm ")]').Count -ne 3) { throw 'First-time adapter insertion omitted maintained entries' }
          & $builder -PackagePath $package
          if ([IO.File]::ReadAllText($package) -cne $installed) { throw 'First-time adapter insertion is not idempotent' }
        }
      }
    }
    Write-Output "PASS Soulstorm builder/source/package LF and CRLF matrix: $baselinePath"
  }
} finally {
  $resolved = [IO.Path]::GetFullPath($scratch)
  if ((Split-Path $resolved -Parent) -cne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') -or (Split-Path $resolved -Leaf) -notlike 'yso-hunting-newlines-*') { throw 'Unsafe scratch cleanup path' }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
