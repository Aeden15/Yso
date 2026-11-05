# Copy source bytes and apply only explicitly retired, unmodified files.
# Never mirror: unrelated destination files belong to the destination owner.
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory)][string]$SourceDirectory,
  [Parameter(Mandatory)][string]$TargetDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$sourceRoot=[IO.Path]::GetFullPath($SourceDirectory).TrimEnd('\','/')
$targetRoot=[IO.Path]::GetFullPath($TargetDirectory).TrimEnd('\','/')
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw 'Sync source directory is missing' }
foreach($path in @($sourceRoot,$targetRoot)) {
  if ($path -eq [IO.Path]::GetPathRoot($path).TrimEnd('\','/')) { throw 'Sync roots cannot be filesystem roots' }
}
if ($sourceRoot.Equals($targetRoot,[StringComparison]::OrdinalIgnoreCase) -or
    $sourceRoot.StartsWith($targetRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
    $targetRoot.StartsWith($sourceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Sync roots must not overlap' }
$excludedDirs=@('.git','.cursor','.codex','.agents','.vscode','.idea','node_modules','__pycache__','.workspace-link-publish','.verification','releases')
$excludedFiles=@('.env','.env.local','*.log','*.tmp','*.temp','*.bak','Thumbs.db','Desktop.ini','.DS_Store','.luarc.json')
function IsExcluded([string]$relative) {
  $parts=$relative -split '[/\\]'
  foreach($part in $parts) { if ($part -in $excludedDirs) { return $true } }
  foreach($pattern in $excludedFiles) { if ($parts[-1] -like $pattern) { return $true } }
  return $false
}
function SafePath([string]$root,[string]$relative) {
  if ([string]::IsNullOrWhiteSpace($relative) -or [IO.Path]::IsPathRooted($relative) -or $relative -match ':' -or
      @($relative -split '[/\\]' | Where-Object { $_ -in @('','.','..') }).Count -or (IsExcluded $relative)) { throw ('Unsafe sync path: '+$relative) }
  $resolved=[IO.Path]::GetFullPath((Join-Path $root $relative))
  if (-not $resolved.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw ('Path escapes sync root: '+$relative) }
  return $resolved
}
function NoLinks([string]$path) {
  # Inspect existing ancestors, including the declared root, before writes/deletes.
  $current=$path
  while ($current) {
    if (Test-Path -LiteralPath $current) {
      $item=Get-Item -LiteralPath $current -Force
      # OneDrive uses reparse points for ordinary cloud files/directories. Only
      # redirecting links escape the declared roots; do not reject cloud tags.
      foreach ($propertyName in @('LinkType','LinkTarget','Target')) {
        $property=$item.PSObject.Properties[$propertyName]
        if ($null -ne $property -and $property.Value) { throw ('Refusing linked sync path: '+$current) }
      }
    }
    $parent=Split-Path $current -Parent
    if ($parent -eq $current) { break }
    $current=$parent
  }
}
NoLinks $sourceRoot
NoLinks $targetRoot
$deletions=[Collections.Generic.List[object]]::new()
$manifest=Join-Path $sourceRoot 'scripts/retired-files.json'
if (Test-Path -LiteralPath $manifest) {
  NoLinks $manifest
  $data=Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
  $seen=@{}
  foreach($entry in $data.files) {
    $relative=[string]$entry.path
    $from=SafePath $sourceRoot $relative
    $to=SafePath $targetRoot $relative
    if ($seen.ContainsKey($relative)) { throw ('Duplicate retirement path: '+$relative) }
    $seen[$relative]=$true
    if ([string]$entry.sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw ('Invalid retirement hash: '+$relative) }
    if (Test-Path -LiteralPath $from) { throw ('Retired source still exists: '+$relative) }
    NoLinks $to
    if (Test-Path -LiteralPath $to) {
      if (-not (Test-Path -LiteralPath $to -PathType Leaf)) { throw ('Retirement target is not a file: '+$relative) }
      if ((Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash -ine $entry.sha256) { throw ('Refusing modified retired file: '+$relative) }
      $deletions.Add([pscustomobject]@{Path=$to;Relative=$relative;Hash=$entry.sha256})
    }
  }
}
# Preflight the entire copy set before making any changes. Enumerate one directory
# at a time so excluded trees and junctions are never traversed.
$copies=[Collections.Generic.List[object]]::new()
$pending=[Collections.Generic.Queue[string]]::new()
$pending.Enqueue($sourceRoot)
while($pending.Count) {
  $directory=$pending.Dequeue()
  foreach($item in Get-ChildItem -LiteralPath $directory -Force) {
    $relative=$item.FullName.Substring($sourceRoot.Length+1)
    if (IsExcluded $relative) { continue }
    NoLinks $item.FullName
    if ($item.PSIsContainer) { $pending.Enqueue($item.FullName);continue }
    $to=SafePath $targetRoot $relative
    NoLinks $to
    if (Test-Path -LiteralPath $to -PathType Container) { throw ('Copy target is a directory: '+$relative) }
    $hash=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    if (-not (Test-Path -LiteralPath $to) -or (Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash -cne $hash) {
      $copies.Add([pscustomobject]@{Source=$item.FullName;Path=$to;Relative=$relative;Hash=$hash})
    }
  }
}
foreach($copy in $copies) {
  if ($PSCmdlet.ShouldProcess($copy.Path,'Copy workspace content')) {
    NoLinks $copy.Path
    [IO.Directory]::CreateDirectory((Split-Path $copy.Path -Parent)) | Out-Null
    Copy-Item -LiteralPath $copy.Source -Destination $copy.Path -Force
    if ((Get-FileHash -LiteralPath $copy.Path -Algorithm SHA256).Hash -cne $copy.Hash) { throw ('Source changed while syncing: '+$copy.Relative) }
    [pscustomobject]@{Action='copy';Path=$copy.Relative}
  }
}
foreach($entry in $deletions) {
  if ($PSCmdlet.ShouldProcess($entry.Path,'Delete explicitly retired file')) {
    NoLinks $entry.Path
    if ((Get-FileHash -LiteralPath $entry.Path -Algorithm SHA256).Hash -ine $entry.Hash) { throw ('Refusing modified retired file: '+$entry.Relative) }
    Remove-Item -LiteralPath $entry.Path -Force
    [pscustomobject]@{Action='retire';Path=$entry.Relative}
    $parent=Split-Path $entry.Path -Parent
    while ($parent.StartsWith($targetRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
      if (@(Get-ChildItem -LiteralPath $parent -Force).Count) { break }
      NoLinks $parent
      Remove-Item -LiteralPath $parent -Force
      $parent=Split-Path $parent -Parent
    }
  }
}
