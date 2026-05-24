# Run git in the canonical Yso GitHub clone after syncing Ysindrolir from this workspace.
# Usage (from anywhere):
#   .\Ysindrolir\scripts\Invoke-YsoGit.ps1 status
#   .\Ysindrolir\scripts\Invoke-YsoGit.ps1 add Ysindrolir/Magi/magi_focus.lua
#   .\Ysindrolir\scripts\Invoke-YsoGit.ps1 commit -m "message"
#   .\Ysindrolir\scripts\Invoke-YsoGit.ps1 push origin main
[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$GitArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$CanonicalGitRoot = 'C:\Users\shuji\OneDrive\Documents\GitHub\Yso'

if (-not (Test-Path -LiteralPath (Join-Path $CanonicalGitRoot '.git'))) {
  throw "Canonical Yso git root not found: $CanonicalGitRoot"
}

$ScriptsDir = Split-Path -Parent $PSCommandPath
$YsindrolirHere = Split-Path $ScriptsDir -Parent
$WorkspaceRoot = Split-Path $YsindrolirHere -Parent
$YsindrolirThere = Join-Path $CanonicalGitRoot 'Ysindrolir'

if (-not (Test-Path -LiteralPath $YsindrolirHere)) {
  throw "Ysindrolir folder missing in workspace: $YsindrolirHere"
}

if ($GitArgs.Count -eq 0) {
  $GitArgs = @('status')
}

function Sync-YsindrolirToCanonical {
  if (-not (Test-Path -LiteralPath $YsindrolirThere)) {
    New-Item -ItemType Directory -Path $YsindrolirThere -Force | Out-Null
  }

  $robocopy = Get-Command robocopy -ErrorAction SilentlyContinue
  if ($robocopy) {
    # /E recurse, /XO skip older dest files, exclude VCS metadata
    $null = & robocopy $YsindrolirHere $YsindrolirThere /E /XO /R:1 /W:1 /NFL /NDL /NJH /NJS `
      /XD '.git' 'node_modules' '.cursor'
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
    return
  }

  Get-ChildItem -LiteralPath $YsindrolirHere -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($YsindrolirHere.Length).TrimStart('\')
    if ($rel -match '(^|[\\/])\.git([\\/]|$)') { return }
    $target = Join-Path $YsindrolirThere $rel
    $targetDir = Split-Path $target -Parent
    if (-not (Test-Path -LiteralPath $targetDir)) {
      New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $target) -or $_.LastWriteTimeUtc -gt (Get-Item -LiteralPath $target).LastWriteTimeUtc) {
      Copy-Item -LiteralPath $_.FullName -Destination $target -Force
    }
  }
}

Sync-YsindrolirToCanonical
Write-Host "Synced Ysindrolir -> $YsindrolirThere"

& git -C $CanonicalGitRoot @GitArgs
exit $LASTEXITCODE
