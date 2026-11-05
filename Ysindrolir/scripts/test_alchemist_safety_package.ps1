[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$doc=[xml][IO.File]::ReadAllText($PackagePath)
function Assert($condition,[string]$message){if(-not $condition){throw $message}}
$api=$doc.SelectSingleNode('//Script[name="Api stuff"]/script').InnerText
Assert ($api.Contains('Yso.alchemist_offense')) 'Embedded API is missing Alchemist offense suspension'
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('yso-alchemist-'+[guid]::NewGuid())
try {
 [IO.Directory]::CreateDirectory($scratch) | Out-Null
 $copy=Join-Path $scratch 'package.xml';Copy-Item -LiteralPath $PackagePath -Destination $copy
 $before=[IO.File]::ReadAllText($copy)
 & (Join-Path $PSScriptRoot 'build_alchemist_safety_package.ps1') -PackagePath $copy
 $first=[IO.File]::ReadAllText($copy)
 & (Join-Path $PSScriptRoot 'build_alchemist_safety_package.ps1') -PackagePath $copy
 Assert ($first -ceq [IO.File]::ReadAllText($copy)) 'Alchemist builder is not idempotent'
 Assert ($first -ceq $before) 'Committed package has Alchemist source/alias drift'
 $harness=@'
Yso={features={alchemist_offense=false}};sent={};send=function(c) sent[#sent+1]=c end;sendAll=send;cecho=function() end;target='Foe';matches={'','phlegmatic','sanguine'}
'@
 foreach($name in @('adam','aduel','Bash','copper','Aurify','Temper','Wrack','Truewrack','Inundation','Reave-Timed death','Homunculus attack','Homunculus shriek','Corruption','cor','tcor <arg>')){
  $nodes=$doc.SelectNodes('//Alias[name="'+$name+'"]')
  Assert ($nodes.Count -eq 1) ('Missing unique offensive alias '+$name)
  $body=$nodes[0].SelectSingleNode('script').InnerText
  $harness+="`nassert(load([====["+$body+"]====]))();assert(#sent==0,'offensive alias emitted: "+$name+"')`n"
 }
 $salt=$doc.SelectSingleNode('//Alias[name="salt"]/script').InnerText
 $harness+="`nYsoWorkspaceLink={restart_required=true};assert(load([====["+$salt+"]====]))();assert(#sent==0,'Salt macro bypassed release hold');YsoWorkspaceLink=nil`n"
 $harness+="`nassert(load([====["+$salt+"]====]))();assert(sent[1]=='educe salt' and #sent==1)`n"
 $harness | & lua -
 Assert ($LASTEXITCODE -eq 0) 'Packaged offensive alias suspension failed'
 $embedded=$doc.SelectSingleNode('//Script[name="Alchemist physiology"]/script').InnerText
 Assert (-not $embedded.Contains('debug-f528bd') -and -not $embedded.Contains('yajl.to_string')) 'Embedded physiology retains external debug logging'
 & lua (Join-Path $root 'Yso/Tests and rebuilds/test_alchemist_suspension.lua') ($root.Replace('\','/'))
 Assert ($LASTEXITCODE -eq 0) 'Alchemist source suspension regression failed'
 Write-Output 'PASS: Alchemist embedded parity, scoped idempotence, offensive aliases and suspension behavior'
}finally{
 $resolved=[IO.Path]::GetFullPath($scratch)
 if((Split-Path $resolved -Leaf) -notlike 'yso-alchemist-*' -or (Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')){throw 'Unsafe Alchemist scratch path'}
 if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
