[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('yso-login-'+[guid]::NewGuid())
function Assert($condition,[string]$message){if(-not $condition){throw $message}}
try {
 New-Item -ItemType Directory -Path $scratch | Out-Null
 $copy=Join-Path $scratch 'package.xml';Copy-Item -LiteralPath $PackagePath -Destination $copy
 $before=[IO.File]::ReadAllText($copy)
 & (Join-Path $PSScriptRoot 'build_login_safety_package.ps1') -PackagePath $copy -WhatIf
 Assert ($before -ceq [IO.File]::ReadAllText($copy)) 'WhatIf changed destination'
 & (Join-Path $PSScriptRoot 'build_login_safety_package.ps1') -PackagePath $copy
 $first=[IO.File]::ReadAllText($copy)
 & (Join-Path $PSScriptRoot 'build_login_safety_package.ps1') -PackagePath $copy
 Assert ($first -ceq [IO.File]::ReadAllText($copy)) 'Login builder is not idempotent'
 function Mask([string]$value){
  foreach($name in @('Yso session readiness','Magi weapons','formulation','Yso serverside policy')){
   $value=[regex]::Replace($value,'(?s)<Script\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</Script>','')
  }
  return $value
 }
 Assert ((Mask $before) -ceq (Mask $first)) 'Login builder changed unrelated content, including Deliverance'
 $doc=[xml]$first
 Assert ($doc.SelectSingleNode('//ScriptPackage/Script[1]/name').InnerText -eq 'Yso session readiness') 'Session must precede consumers'
 foreach($pair in @(@('Yso session readiness','Yso/Integration/session.lua'),@('Magi weapons','Magi/magi_weapons.lua'),@('formulation','Alchemist/Core/formulation.lua'),@('Yso serverside policy','Yso/Curing/serverside_policy.lua'))){
  $node=$doc.SelectSingleNode('//Script[name="'+$pair[0]+'"]/script')
  Assert ($node.InnerText.Replace("`r`n","`n") -ceq [IO.File]::ReadAllText((Join-Path $root $pair[1])).Replace("`r`n","`n")) ('Source parity: '+$pair[0])
 }
 $manifest=New-Object Collections.Generic.List[string]
 $index=0
 foreach($node in $doc.SelectNodes('//Script[script]')){
  $active=$true;$ancestor=$node
  while($ancestor -and $ancestor.Name -ne 'ScriptPackage') {if($ancestor.HasAttribute('isActive') -and $ancestor.GetAttribute('isActive') -eq 'no'){$active=$false};$ancestor=$ancestor.ParentNode}
  if(-not $active){continue}
  $path=Join-Path $scratch ('script-'+$index+'.lua');$index++
  [IO.File]::WriteAllText($path,$node.script)
  & luac -p $path;Assert ($LASTEXITCODE -eq 0) ('Embedded syntax: '+$node.name)
  $manifest.Add($path.Replace('\','/')+'|'+$node.name)
 }
 $list=Join-Path $scratch 'manifest.txt';[IO.File]::WriteAllLines($list,$manifest)
 Push-Location (Split-Path $root -Parent)
 try {
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_policy_login_safety.lua');Assert ($LASTEXITCODE -eq 0) 'Policy missing-session behavior'
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_session_login_safety.lua');Assert ($LASTEXITCODE -eq 0) 'Session source behavior'
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_magi_login_safety.lua');Assert ($LASTEXITCODE -eq 0) 'Magi login regression'
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_package_login_startup.lua') $list;Assert ($LASTEXITCODE -eq 0) 'Package startup/reload regression'
 } finally {Pop-Location}
 Write-Host ('PASS: login builder idempotence, source parity, syntax and '+$index+' active startup scripts')
} finally {
 $resolved=[IO.Path]::GetFullPath($scratch)
 if((Split-Path $resolved -Leaf) -notlike 'yso-login-*' -or (Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')){throw 'Unsafe scratch cleanup'}
 if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
