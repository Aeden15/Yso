<#
.SYNOPSIS
  Sync the Yso GitHub repo with the OneDrive Desktop workspace.

.DESCRIPTION
  Mirrors files between this git clone and the "Yso systems" folder on your
  Desktop (which OneDrive keeps in sync across devices).

  Directions:
    pull  — copy Desktop workspace INTO the repo   (Desktop → Git)
    push  — copy repo content OUT to the Desktop    (Git → Desktop)

  The script auto-detects your Desktop path by checking common OneDrive
  layouts.  Override with -DesktopPath if detection fails.

.PARAMETER Direction
  "pull" or "push".

.PARAMETER DesktopPath
  Override the auto-detected "Yso systems" folder path.

.PARAMETER DryRun
  Show what would be copied without touching any files.

.EXAMPLE
  .\sync_workspace.ps1 push
  .\sync_workspace.ps1 pull -DryRun
  .\sync_workspace.ps1 push -DesktopPath "D:\MyYso"
#>

param(
  [Parameter(Mandatory)]
  [ValidateSet('pull', 'push')]
  [string]$Direction,

  [string]$DesktopPath,

  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Locate repo root (same directory as this script) ──────────────────
$RepoRoot = $PSScriptRoot
if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
  throw "Cannot find .git in $RepoRoot — run this script from the repo root."
}

# ── Auto-detect the Desktop workspace ─────────────────────────────────
function Find-DesktopWorkspace {
  $userHome = $env:USERPROFILE
  if (-not $userHome) { $userHome = $env:HOME }
  if (-not $userHome) { throw 'Cannot determine home directory.' }

  $candidates = @(
    (Join-Path $userHome 'OneDrive\Desktop\Yso systems'),
    (Join-Path $userHome 'OneDrive - Personal\Desktop\Yso systems'),
    (Join-Path $userHome 'Desktop\Yso systems'),
    (Join-Path $userHome 'OneDrive\Yso systems')
  )

  # Also check OneDrive environment variable if set.
  if ($env:OneDrive) {
    $candidates += (Join-Path $env:OneDrive 'Desktop\Yso systems')
  }
  if ($env:OneDriveConsumer) {
    $candidates += (Join-Path $env:OneDriveConsumer 'Desktop\Yso systems')
  }

  foreach ($c in $candidates) {
    if (Test-Path $c) { return $c }
  }

  return $null
}

if ($DesktopPath) {
  $Workspace = $DesktopPath
} else {
  $Workspace = Find-DesktopWorkspace
}

if (-not $Workspace -or -not (Test-Path $Workspace)) {
  throw @"
Could not find the Desktop workspace.
Expected a folder named "Yso systems" on your Desktop (or OneDrive Desktop).
Pass -DesktopPath explicitly if your folder is in a non-standard location.
"@
}

Write-Host "`n=== Yso Workspace Sync ===" -ForegroundColor Cyan
Write-Host "Repo root : $RepoRoot"
Write-Host "Desktop   : $Workspace"
Write-Host "Direction : $Direction"
if ($DryRun) { Write-Host "** DRY RUN — no files will be changed **" -ForegroundColor Yellow }
Write-Host ""

# ── Build robocopy arguments ──────────────────────────────────────────
# Shared content lives under Ysindrolir/ in the repo and the desktop.
$RepoContent   = Join-Path $RepoRoot 'Ysindrolir'
$DesktopContent = Join-Path $Workspace 'Ysindrolir'

if ($Direction -eq 'push') {
  $Source = $RepoContent
  $Dest   = $DesktopContent
  Write-Host "Copying: repo -> desktop" -ForegroundColor Green
} else {
  $Source = $DesktopContent
  $Dest   = $RepoContent
  Write-Host "Copying: desktop -> repo" -ForegroundColor Green
}

if (-not (Test-Path $Source)) {
  throw "Source path does not exist: $Source"
}

# Robocopy flags:
#   /MIR    — mirror (add + delete to match source)
#   /XD     — exclude directories
#   /XF     — exclude files
#   /NJH /NJS — suppress header/summary for cleaner output
#   /NDL    — suppress directory listing
#   /NP     — suppress progress percentage
$excludeDirs = @('.git', '.vscode', '.idea', '__pycache__', 'node_modules')
$excludeFiles = @('.env', '.env.local', '*.log', '*.tmp', '*.temp', '*.bak',
                   'Thumbs.db', 'Desktop.ini', '.DS_Store', '.luarc.json')

$roboArgs = @($Source, $Dest, '/MIR')
$roboArgs += '/XD'
$roboArgs += $excludeDirs
$roboArgs += '/XF'
$roboArgs += $excludeFiles
$roboArgs += @('/NJH', '/NJS', '/NDL', '/NP')

if ($DryRun) {
  $roboArgs += '/L'   # list-only mode
}

Write-Host ""
Write-Host "--- Files ---" -ForegroundColor DarkGray

# Robocopy returns 0-7 for various success states; 8+ means errors.
& robocopy @roboArgs
$rc = $LASTEXITCODE

# Also sync root-level docs and the sync wrapper on push.
if ($Direction -eq 'push') {
  $docFiles = @('README.md', 'README.txt', 'sync.cmd', 'sync_workspace.ps1')
  foreach ($f in $docFiles) {
    $src = Join-Path $RepoRoot $f
    $dst = Join-Path $Workspace $f
    if (Test-Path $src) {
      if ($DryRun) {
        Write-Host "  (would copy) $f" -ForegroundColor Yellow
      } else {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "  copied $f" -ForegroundColor Green
      }
    }
  }
}

# On pull, copy root-level docs back into the repo if they exist on desktop.
if ($Direction -eq 'pull') {
  $docFiles = @('README.md', 'README.txt')
  foreach ($f in $docFiles) {
    $src = Join-Path $Workspace $f
    $dst = Join-Path $RepoRoot $f
    if (Test-Path $src) {
      if ($DryRun) {
        Write-Host "  (would copy) $f" -ForegroundColor Yellow
      } else {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "  copied $f" -ForegroundColor Green
      }
    }
  }
}

Write-Host ""
if ($rc -lt 8) {
  if ($DryRun) {
    Write-Host "Dry run complete — no files were changed." -ForegroundColor Yellow
  } else {
    Write-Host "Sync complete." -ForegroundColor Green
    if ($Direction -eq 'push') {
      Write-Host "OneDrive will pick up changes automatically." -ForegroundColor DarkGray
    } else {
      Write-Host 'Review changes with "git diff", then commit when ready.' -ForegroundColor DarkGray
    }
  }
} else {
  Write-Host "Robocopy reported errors (exit code $rc)." -ForegroundColor Red
  exit 1
}
