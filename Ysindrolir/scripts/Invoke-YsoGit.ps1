# Run git in the canonical Yso GitHub clone after syncing Ysindrolir from this workspace.
# Usage (from anywhere):
#   .\Ysindrolir\scripts\Invoke-YsoGit.ps1 status
#   .\Ysindrolir\scripts\Invoke-YsoGit.ps1 add Ysindrolir/Magi/magi_focus.lua
#   .\Ysindrolir\scripts\Invoke-YsoGit.ps1 commit -m "message"
#   .\Ysindrolir\scripts\Invoke-YsoGit.ps1 push origin main
[CmdletBinding()]
param(
  [switch]$DryRun,
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

if ($null -eq $GitArgs -or $GitArgs.Count -eq 0) {
  $GitArgs = @('status')
}

function Sync-YsindrolirToCanonical {
  & (Join-Path $ScriptsDir 'Sync-YsoWorkspace.ps1') -SourceDirectory $YsindrolirHere -TargetDirectory $YsindrolirThere -WhatIf:$DryRun
  foreach ($relative in @('README.md','README.txt','GIT.md','sync_workspace.ps1')) {
    $from=Join-Path $WorkspaceRoot $relative
    if (Test-Path -LiteralPath $from) {
      Copy-Item -LiteralPath $from -Destination (Join-Path $CanonicalGitRoot $relative) -Force -WhatIf:$DryRun
    }
  }
}

Sync-YsindrolirToCanonical
if ($DryRun) {
  Write-Host 'Dry run complete; no files changed and no git command executed.'
  return
}
Write-Host "Synced Ysindrolir -> $YsindrolirThere"

& git -C $CanonicalGitRoot @GitArgs
exit $LASTEXITCODE
