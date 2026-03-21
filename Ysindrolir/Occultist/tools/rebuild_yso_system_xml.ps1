param(
  [string]$XmlPath,
  [string]$MirrorRoot,
  [string]$LuaPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$builder = Join-Path $PSScriptRoot 'rebuild_yso_system_xml.lua'

if (-not $LuaPath) {
  foreach ($candidate in @('luajit', 'lua')) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) {
      $LuaPath = $cmd.Source
      break
    }
  }
}

if (-not $LuaPath) {
  throw 'No Lua interpreter found. Install lua.exe or luajit.exe, or pass -LuaPath.'
}

$args = @($builder)
if ($PSBoundParameters.ContainsKey('XmlPath')) {
  $args += $XmlPath
}
if ($PSBoundParameters.ContainsKey('MirrorRoot')) {
  $args += $MirrorRoot
}

& $LuaPath @args
exit $LASTEXITCODE
