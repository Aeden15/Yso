$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('yso-release-artifacts-'+[guid]::NewGuid())
function Assert($v,[string]$message){if(-not $v){throw $message}}
try {
 [IO.Directory]::CreateDirectory((Join-Path $scratch 'scripts')) | Out-Null
 [IO.Directory]::CreateDirectory((Join-Path $scratch 'mudlet packages')) | Out-Null
 foreach($file in @('build_yso_release.ps1','yso_release_manifest.json')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $scratch 'scripts')}
 $verify=@'
param([switch]$SkipReleaseArtifacts,[string]$OutputDirectory,[string]$SystemRoot)
if(-not $SkipReleaseArtifacts){throw 'Release verification must avoid recursive artifact tests'}
if((Split-Path $SystemRoot -Leaf) -cne 'Ysindrolir'){throw 'Frozen verification must preserve the workspace-relative Ysindrolir layout'}
$triggerPath=Join-Path $SystemRoot 'Yso/Tests and rebuilds/../../Alchemist/Triggers/Alchemy/Physiology/humour_balance.lua'
if($triggerPath.Length -ge 260){throw 'Frozen Lua fixture paths exceed the Windows CRT path limit'}
if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'fail-verification')){throw 'Injected verification failure'}
if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'mutate-input')){[IO.File]::AppendAllText((Join-Path $SystemRoot 'mudlet packages/AK.xml'),' ')}
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'results.json'),'{"passed":true}')
'@
 [IO.File]::WriteAllText((Join-Path $scratch 'scripts/verify_yso.ps1'),$verify)
 $spec=Get-Content -Raw -LiteralPath (Join-Path $scratch 'scripts/yso_release_manifest.json') | ConvertFrom-Json
 foreach($p in $spec.packages){[IO.File]::WriteAllText((Join-Path $scratch ('mudlet packages/'+$p.file)),'<MudletPackage><ScriptPackage><Script><name>fixture</name><script>return true</script></Script></ScriptPackage></MudletPackage>')}
 $builder=Join-Path $scratch 'scripts/build_yso_release.ps1'
 & $builder
 $pointerPath=Join-Path $scratch 'releases/current.json'
 $pointer=[IO.File]::ReadAllText($pointerPath)
 $directory=($pointer | ConvertFrom-Json).directory
 $bundle=Join-Path $scratch ('releases/'+$directory)
 $manifest=Get-Content -Raw -LiteralPath (Join-Path $bundle 'manifest.json') | ConvertFrom-Json
 Assert ($manifest.packages.Count -eq 7) 'Release omitted a required package'
 foreach($p in $manifest.packages){
  Assert ((Get-FileHash -LiteralPath (Join-Path $bundle $p.file) -Algorithm SHA256).Hash -ieq $p.sha256) ('Release hash mismatch: '+$p.name)
  Assert (Test-Path -LiteralPath (Join-Path $bundle ($p.name+'.validated'))) ('Release receipt missing: '+$p.name)
 }
 Assert (Test-Path -LiteralPath (Join-Path $bundle 'verification/results.json')) 'Verification results were not retained'
 & $builder
 Assert ([IO.File]::ReadAllText($pointerPath) -ceq $pointer) 'Unchanged inputs produced different release pointer'
 [IO.File]::WriteAllText((Join-Path $scratch 'scripts/fail-verification'),'fail')
 $failed=$false;try{& $builder}catch{$failed=$true}
 Assert $failed 'Failed verification published a release'
 Assert ([IO.File]::ReadAllText($pointerPath) -ceq $pointer) 'Failed verification changed current release'
 Remove-Item -LiteralPath (Join-Path $scratch 'scripts/fail-verification')
 [IO.File]::WriteAllText((Join-Path $scratch 'scripts/mutate-input'),'mutate')
 $failed=$false;try{& $builder}catch{$failed=$true}
 Assert $failed 'Verifier-mutated input was published'
 Assert ([IO.File]::ReadAllText($pointerPath) -ceq $pointer) 'Verification input mutation changed current release'
 Remove-Item -LiteralPath (Join-Path $scratch 'scripts/mutate-input')
 [IO.File]::WriteAllText((Join-Path $scratch 'mudlet packages/Legacy UI V2.0.xml'),'<MudletPackage><broken></MudletPackage>')
 $failed=$false;try{& $builder}catch{$failed=$true}
 Assert $failed 'Malformed late package was published'
 Assert ([IO.File]::ReadAllText($pointerPath) -ceq $pointer) 'Malformed artifact changed current release'
 Assert (Test-Path -LiteralPath (Join-Path $bundle 'manifest.json')) 'Previous verified release was lost'
 Write-Output 'PASS release artifacts: required packages, hashes, receipts, verification, idempotence and failed-publication preservation'
} finally {
 $resolved=[IO.Path]::GetFullPath($scratch)
 if((Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') -or (Split-Path $resolved -Leaf) -notlike 'yso-release-artifacts-*'){throw 'Unsafe fixture cleanup'}
 if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
