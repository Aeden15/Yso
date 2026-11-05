[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Legacy V2.1.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('yso-legacy-login-'+[guid]::NewGuid())
function Assert($value,[string]$message){if(-not $value){throw $message}}
function Mask([string]$text){
 foreach($row in @(@('Script','Legacy'),@('Trigger','Login'),@('Timer','Check for Updates'))){
  $text=[regex]::Replace($text,'(?s)<'+$row[0]+'\b[^>]*>\s*<name>'+[regex]::Escape($row[1])+'</name>.*?</'+$row[0]+'>','')
 }
 return $text
}
try {
 New-Item -ItemType Directory -Path (Join-Path $scratch 'Yso/Integration') -Force | Out-Null
 $copy=Join-Path $scratch 'Legacy.xml';Copy-Item -LiteralPath $PackagePath -Destination $copy
 $before=[IO.File]::ReadAllText($copy)
 & (Join-Path $PSScriptRoot 'build_legacy_login_safety_package.ps1') -PackagePath $copy -WhatIf
 Assert ($before -ceq [IO.File]::ReadAllText($copy)) 'Legacy WhatIf changed destination'
 & (Join-Path $PSScriptRoot 'build_legacy_login_safety_package.ps1') -PackagePath $copy
 $after=[IO.File]::ReadAllText($copy)
 Assert ((Mask $before) -ceq (Mask $after)) 'Legacy builder changed unrelated bytes including Deliverance'
 & (Join-Path $PSScriptRoot 'build_legacy_login_safety_package.ps1') -PackagePath $copy
 Assert ($after -ceq [IO.File]::ReadAllText($copy)) 'Legacy builder not idempotent'
 $doc=[xml]$after
 foreach($row in @(@('Script','Legacy','legacy_load.lua'),@('Trigger','Login','legacy_login.lua'),@('Timer','Check for Updates','legacy_check_for_updates.lua'))){
  $nodes=$doc.SelectNodes('//'+$row[0]+'[name="'+$row[1]+'"]/script')
  Assert ($nodes.Count -eq 1) ('Legacy unique node: '+$row[1])
  $source=Join-Path $root ('Yso/Integration/'+$row[2]);$body=$nodes[0].InnerText
  Assert ($body.Replace("`r`n","`n") -ceq [IO.File]::ReadAllText($source).Replace("`r`n","`n")) ('Legacy source parity: '+$row[1])
  $path=Join-Path $scratch ('Yso/Integration/'+$row[2]);[IO.File]::WriteAllText($path,$body)
  & luac -p $path;Assert ($LASTEXITCODE -eq 0) ('Legacy syntax: '+$row[1])
 }
 Copy-Item -LiteralPath (Join-Path $root 'Yso/Integration/session.lua') -Destination (Join-Path $scratch 'Yso/Integration/session.lua')
 & lua (Join-Path $root 'Yso/Tests and rebuilds/test_legacy_login_safety.lua') ($scratch.Replace('\','/')+'/')
 Assert ($LASTEXITCODE -eq 0) 'Embedded Legacy login regression failed'
 Write-Host 'PASS: Legacy login WhatIf, idempotence, exact unrelated bytes, source parity, embedded syntax and session behavior'
} finally {
 $resolved=[IO.Path]::GetFullPath($scratch)
 if((Split-Path $resolved -Leaf) -notlike 'yso-legacy-login-*' -or (Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')){throw 'Unsafe scratch cleanup'}
 if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
