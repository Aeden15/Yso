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
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$occultistDir = Split-Path -Parent $PSScriptRoot
$ysindrolirDir = Split-Path -Parent $occultistDir

$xmlToValidate = if ($PSBoundParameters.ContainsKey('XmlPath')) {
  $XmlPath
} else {
  Join-Path $ysindrolirDir 'mudlet packages\Yso system.xml'
}

$xmlToValidate = [System.IO.Path]::GetFullPath($xmlToValidate)
if (-not (Test-Path -LiteralPath $xmlToValidate)) {
  throw "XML validation target does not exist: $xmlToValidate"
}

try {
  $settings = New-Object System.Xml.XmlReaderSettings
  $settings.DtdProcessing = [System.Xml.DtdProcessing]::Parse
  $reader = [System.Xml.XmlReader]::Create($xmlToValidate, $settings)
  while ($reader.Read()) { }
  $reader.Close()
}
catch {
  throw "XML validation failed for '$xmlToValidate': $($_.Exception.Message)"
}

exit 0
