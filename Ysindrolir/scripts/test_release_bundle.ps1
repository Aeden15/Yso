$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
& lua (Join-Path $root 'Yso/Tests and rebuilds/test_release_bundle.lua') $root.Replace('\','/')
if($LASTEXITCODE -ne 0){throw 'Release runtime regressions failed'}
