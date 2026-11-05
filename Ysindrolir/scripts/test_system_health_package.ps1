[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('yso-health-'+[guid]::NewGuid())
function Assert($ok,$message){if(-not $ok){throw $message}}
function Mask([string]$text){
  foreach($type in @('Script','Alias')){$text=[regex]::Replace($text,'(?s)<'+$type+'\b[^>]*>\s*<name>Yso unified health</name>.*?</'+$type+'>','')}
  $text
}
try{
  Assert (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'build_system_health_package.ps1')) 'Health package builder missing'
  [IO.Directory]::CreateDirectory($scratch) | Out-Null
  $copy=Join-Path $scratch 'Yso.xml'
  Copy-Item -LiteralPath $PackagePath -Destination $copy
  $before=[IO.File]::ReadAllText($copy)
  & (Join-Path $PSScriptRoot 'build_system_health_package.ps1') -PackagePath $copy -WhatIf
  Assert ([IO.File]::ReadAllText($copy) -ceq $before) 'Health WhatIf changed package'
  & (Join-Path $PSScriptRoot 'build_system_health_package.ps1') -PackagePath $copy
  $after=[IO.File]::ReadAllText($copy)
  Assert ((Mask $before) -ceq (Mask $after)) 'Health builder changed unrelated content'
  & (Join-Path $PSScriptRoot 'build_system_health_package.ps1') -PackagePath $copy
  Assert ([IO.File]::ReadAllText($copy) -ceq $after) 'Health builder not idempotent'
  $doc=[xml]$after
  $body=$doc.SelectSingleNode('//Script[name="Yso unified health"]/script').InnerText
  Assert ($body -ceq [IO.File]::ReadAllText((Join-Path $root 'Yso/Integration/system_health.lua')).Replace("`r`n","`n")) 'Embedded health source drift'
  Assert ($doc.SelectNodes('//Alias[name="Yso unified health" and regex="^ysocheck$"]').Count -eq 1) 'Permanent ysocheck alias missing'
  $code='local original=dofile;local health=[======['+$body+']======];dofile=function(path) if path:match("/Integration/system_health.lua$") then return assert(load(health))() end return original(path) end;arg={};original([======['+($root.Replace('\','/')+'/Yso/Tests and rebuilds/test_system_health.lua')+']======])'
  Push-Location (Split-Path $root -Parent)
  try{$code | & lua -;Assert ($LASTEXITCODE -eq 0) 'Packaged health behavior failed'}finally{Pop-Location}
  Write-Output 'PASS packaged health behavior, aliases, source parity, preservation and idempotence'
}finally{
  $resolved=[IO.Path]::GetFullPath($scratch)
  if((Split-Path $resolved -Leaf) -notlike 'yso-health-*' -or (Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')){throw 'Unsafe health scratch cleanup'}
  if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
