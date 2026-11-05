[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('yso-sync-test-' + [guid]::NewGuid().ToString('N'))
$sourceRoot = Join-Path $fixture 'source'
$targetRoot = Join-Path $fixture 'target'
$sync = Join-Path $PSScriptRoot 'Sync-YsoWorkspace.ps1'
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Put($root, $relative, $text) {
  $path = Join-Path $root $relative
  [IO.Directory]::CreateDirectory((Split-Path $path -Parent)) | Out-Null
  [IO.File]::WriteAllText($path, $text)
}
function Manifest($entries) {
  Put $sourceRoot 'scripts/retired-files.json' (@{files=@($entries)} | ConvertTo-Json -Depth 4)
}
try {
  Put $sourceRoot 'Core/kept.lua' 'new'
  Put $targetRoot 'Core/kept.lua' 'old'
  # Source content is authoritative even when its timestamp is older.
  (Get-Item -LiteralPath (Join-Path $sourceRoot 'Core/kept.lua')).LastWriteTimeUtc = [datetime]'2020-01-01'
  Put $targetRoot 'Monk/retired.lua' 'retired'
  Put $targetRoot 'custom.lua' 'user custom'
  Put $sourceRoot '.workspace-link-publish/private.validated' 'local only'
  $oldHash = (Get-FileHash -LiteralPath (Join-Path $targetRoot 'Monk/retired.lua')).Hash
  Manifest @(@{path='Monk/retired.lua';sha256=$oldHash})
  & $sync -SourceDirectory $sourceRoot -TargetDirectory $targetRoot -WhatIf | Out-Null
  Assert ([IO.File]::ReadAllText((Join-Path $targetRoot 'Core/kept.lua')) -ceq 'old') 'WhatIf copied a file'
  Assert (Test-Path -LiteralPath (Join-Path $targetRoot 'Monk/retired.lua')) 'WhatIf deleted a file'
  & $sync -SourceDirectory $sourceRoot -TargetDirectory $targetRoot | Out-Null
  Assert ([IO.File]::ReadAllText((Join-Path $targetRoot 'Core/kept.lua')) -ceq 'new') 'Older source bytes were skipped'
  Assert (-not (Test-Path -LiteralPath (Join-Path $targetRoot 'Monk/retired.lua'))) 'Retired file survived'
  Assert (-not (Test-Path -LiteralPath (Join-Path $targetRoot 'Monk'))) 'Empty retired folder survived'
  Assert (Test-Path -LiteralPath (Join-Path $targetRoot 'custom.lua')) 'Unlisted destination file was removed'
  Assert (-not (Test-Path -LiteralPath (Join-Path $targetRoot '.workspace-link-publish'))) 'Local receipts were copied'
  Assert (@(& $sync -SourceDirectory $sourceRoot -TargetDirectory $targetRoot).Count -eq 0) 'Second sync was not idempotent'

  Put $targetRoot 'Monk/retired.lua' 'local modification'
  Put $sourceRoot 'Core/kept.lua' 'must not copy on conflict'
  $rejected=$false
  try { & $sync -SourceDirectory $sourceRoot -TargetDirectory $targetRoot | Out-Null } catch { $rejected=$_.Exception.Message -match 'modified retired file' }
  Assert $rejected 'Modified retired destination was not protected'
  Assert ([IO.File]::ReadAllText((Join-Path $targetRoot 'Core/kept.lua')) -ceq 'new') 'Conflict detection happened after copying'
  foreach($unsafe in @('../escape.lua','C:/escape.lua','Core/../escape.lua','scripts:escape.lua','.git/config','/escape.lua')) {
    Manifest @(@{path=$unsafe;sha256=$oldHash})
    $rejected=$false
    try { & $sync -SourceDirectory $sourceRoot -TargetDirectory $targetRoot -WhatIf | Out-Null } catch { $rejected=$true }
    Assert $rejected ('Accepted unsafe retirement path '+$unsafe)
  }
  Manifest @()
  $rejected=$false
  try { & $sync -SourceDirectory $sourceRoot -TargetDirectory (Join-Path $sourceRoot 'nested') | Out-Null } catch { $rejected=$true }
  Assert $rejected 'Accepted overlapping roots'
  # OneDrive cloud placeholders are reparse points without link targets. Actual
  # junctions/symlinks must still be refused so retirement cannot escape target.
  $outside=Join-Path $fixture 'outside'
  [IO.Directory]::CreateDirectory($outside) | Out-Null
  Put $outside 'kept.lua' 'outside'
  $junction=Join-Path $targetRoot 'CoreLink'
  $junctionAvailable=$true
  try { New-Item -ItemType Junction -Path $junction -Target $outside -ErrorAction Stop | Out-Null } catch { $junctionAvailable=$false }
  if ($junctionAvailable) { try {
    Put $sourceRoot 'CoreLink/kept.lua' 'attempted overwrite'
    $rejected=$false
    try { & $sync -SourceDirectory $sourceRoot -TargetDirectory $targetRoot | Out-Null } catch { $rejected=$_.Exception.Message -match 'linked sync path' }
    Assert $rejected 'Accepted junction destination'
    Assert ([IO.File]::ReadAllText((Join-Path $outside 'kept.lua')) -ceq 'outside') 'Escaped through junction'
  } finally {
    $resolvedJunction=[IO.Path]::GetFullPath($junction)
    if ((Split-Path $resolvedJunction -Parent) -cne [IO.Path]::GetFullPath($targetRoot)) { throw 'Unsafe junction cleanup path' }
    # Windows PowerShell 5.1 Remove-Item can throw on junctions. This removes
    # only the directory link; recursive deletion is deliberately disabled.
    [IO.Directory]::Delete($resolvedJunction, $false)
  } }
  else { Write-Output 'SKIP real junction fixture: this Windows sandbox denies junction creation' }
  foreach($wrapper in @((Join-Path $PSScriptRoot 'Invoke-YsoGit.ps1'),(Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'sync_workspace.ps1'))) {
    $text=[IO.File]::ReadAllText($wrapper)
    Assert ($text -match 'Sync-YsoWorkspace.ps1') ('Wrapper bypasses shared safe sync: '+$wrapper)
    Assert ($text -notmatch '/MIR') ('Unrestricted mirror remains: '+$wrapper)
  }
  # sync.cmd launches Windows PowerShell 5.1; exercise it as well when this
  # suite was started in PowerShell 7. A 5.1 run does not recurse.
  if ($PSVersionTable.PSVersion.Major -ge 6 -and (Get-Command powershell.exe -ErrorAction SilentlyContinue)) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
    Assert ($LASTEXITCODE -eq 0) 'Windows PowerShell compatibility failed'
  }
  Write-Output 'PASS workspace sync: dry-run, hashes, explicit retirement, modified-file protection, path boundaries, idempotence and wrappers'
} finally {
  $resolved=[IO.Path]::GetFullPath($fixture)
  if ((Split-Path $resolved -Parent) -cne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') -or (Split-Path $resolved -Leaf) -notlike 'yso-sync-test-*') { throw 'Unsafe sync fixture cleanup path' }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
