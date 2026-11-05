[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('yso-verifier-'+[guid]::NewGuid())
$runner=Join-Path $PSScriptRoot 'verify_yso.ps1'
function Assert($ok,$message){if(-not $ok){throw $message}}
try {
  Assert (Test-Path -LiteralPath $runner) 'Single verification entrypoint is missing'
  $packageDir=Join-Path $fixture 'mudlet packages'
  [IO.Directory]::CreateDirectory($packageDir) | Out-Null
  [IO.Directory]::CreateDirectory((Join-Path $fixture 'scripts')) | Out-Null
  $manifest=@{schema_version=1;release_id='fixture';packages=@(@{id='sample';name='Sample';file='Sample.xml';required=$true;depends_on=@()})}
  [IO.File]::WriteAllText((Join-Path $fixture 'scripts/yso_release_manifest.json'),($manifest | ConvertTo-Json -Depth 8))
  $package=Join-Path $packageDir 'Sample.xml'
  [IO.File]::WriteAllText($package,'<MudletPackage><ScriptPackage><Script isActive="yes" isFolder="no"><name>Sample</name><script>return true</script></Script></ScriptPackage></MudletPackage>')
  $output=Join-Path $fixture 'results'
  & pwsh -NoProfile -File $runner -SystemRoot $fixture -Suite Static -OutputDirectory $output | Out-Null
  Assert ($LASTEXITCODE -eq 0) 'Valid source fixture did not pass unified verification'
  $report=Get-Content -Raw -LiteralPath (Join-Path $output 'results.json') | ConvertFrom-Json
  Assert ($report.failed -eq 0 -and $report.passed -gt 0) 'Machine-readable success summary missing'
  [IO.File]::WriteAllText($package,'<MudletPackage><broken></MudletPackage>')
  & pwsh -NoProfile -File $runner -SystemRoot $fixture -Suite Static -OutputDirectory $output *> $null
  Assert ($LASTEXITCODE -ne 0) 'Malformed package incorrectly passed unified verification'
  $report=Get-Content -Raw -LiteralPath (Join-Path $output 'results.json') | ConvertFrom-Json
  Assert ($report.failed -gt 0) 'Failure was not recorded'
  [IO.File]::WriteAllText($package,'<MudletPackage><ScriptPackage><Script><name>Invalid Lua</name><script>local = broken</script></Script></ScriptPackage></MudletPackage>')
  & pwsh -NoProfile -File $runner -SystemRoot $fixture -Suite Static -OutputDirectory $output *> $null
  Assert ($LASTEXITCODE -ne 0) 'Invalid embedded Lua incorrectly passed unified verification'
  $luaTests=Join-Path $fixture 'Yso/Tests and rebuilds'
  [IO.Directory]::CreateDirectory($luaTests) | Out-Null
  [IO.File]::WriteAllText((Join-Path $luaTests 'test_legacy_network.lua'),'error("must use extracted wrapper fixtures")')
  [IO.File]::WriteAllText((Join-Path $fixture 'scripts/test_legacy_security_package.ps1'),'[IO.File]::WriteAllText((Join-Path (Split-Path $PSScriptRoot -Parent) "fixture-ran"),"yes")')
  & pwsh -NoProfile -File $runner -SystemRoot $fixture -Suite Lua -OutputDirectory $output *> $null
  Assert ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath (Join-Path $fixture 'fixture-ran'))) 'Lua-only verification did not execute its fixture wrapper'
  Write-Output 'PASS unified verifier validates real artifacts, reports failures and returns nonzero'
} finally {
  $resolved=[IO.Path]::GetFullPath($fixture)
  if((Split-Path $resolved -Leaf) -notlike 'yso-verifier-*' -or (Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')){throw 'Unsafe fixture cleanup'}
  if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
