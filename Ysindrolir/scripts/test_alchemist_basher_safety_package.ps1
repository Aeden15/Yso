[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Legacy Basher V2.1.xml'))
$ErrorActionPreference='Stop'
$doc=[xml][IO.File]::ReadAllText($PackagePath)
$body=$doc.SelectSingleNode('//Script[name="Basher"]/script').InnerText
$start=$body.IndexOf('  function Legacy.Basher.queueAttackPackage(')
$finish=$body.IndexOf('  function Legacy.Settings.Basher.failsafes()', $start)
if($start -lt 0 -or $finish -lt 0){throw 'Missing Basher attack package function'}
$function=$body.Substring($start,$finish-$start)
$code=@'
Legacy={Settings={Basher={status=true}},Basher={}};Yso={features={alchemist_offense=false}}
gmcp={Char={Status={class='Alchemist'}}};local sent={};send=function(c) sent[#sent+1]=c end
_fool_basher_hold_active=function() return false end
'@
$code+="`n"+$function+"`n"+@'
local ok,why=Legacy.Basher.queueAttackPackage('add','educe iron Foe',true,'test')
assert(ok==false and why=='alchemist_offense_suspended','Alchemist Legacy hunting bypassed suspension')
assert(#sent==0,'Alchemist Legacy hunting sent raw commands')
gmcp.Char.Status.class='Magi'
assert(Legacy.Basher.queueAttackPackage('add','cast staffcast Foe',true,'test'))
assert(#sent==2,'Other classes lost the original hunting path')
for _,hold in ipairs({'busy','restart_required'}) do
  YsoWorkspaceLink={busy=false,restart_required=false};YsoWorkspaceLink[hold]=true
  local before=#sent
  assert(not Legacy.Basher.queueAttackPackage('add','cast fulminate Foe',true,'test'),'Magi Legacy hunting bypassed release '..hold)
  assert(#sent==before,'Magi Legacy hunting sent while release-held')
end
YsoWorkspaceLink=nil
gmcp.Char.Status.class='Alchemist';Yso.features.alchemist_offense=true
assert(Legacy.Basher.queueAttackPackage('add','educe iron Foe',false,'test'))
assert(#sent==3,'Explicit future Alchemist activation did not restore hunting')
'@
$code | & lua -
if($LASTEXITCODE -ne 0){throw 'Packaged Alchemist Basher suspension failed'}
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('yso-alc-basher-'+[guid]::NewGuid()+'.xml')
try{
 Copy-Item -LiteralPath $PackagePath -Destination $scratch
 & (Join-Path $PSScriptRoot 'build_alchemist_basher_safety_package.ps1') -PackagePath $scratch
 $first=[IO.File]::ReadAllText($scratch)
 & (Join-Path $PSScriptRoot 'build_alchemist_basher_safety_package.ps1') -PackagePath $scratch
 if($first -cne [IO.File]::ReadAllText($scratch)){throw 'Alchemist Basher builder is not idempotent'}
 if($first -cne [IO.File]::ReadAllText($PackagePath)){throw 'Alchemist Basher package drift'}
 # Git's Windows checkout may use CRLF for the builder while XML bodies are
 # normalized to LF by XmlDocument. Exercise both inputs independently.
 $matrixRoot=Join-Path ([IO.Path]::GetTempPath()) ('yso-alc-basher-newlines-'+[guid]::NewGuid())
 [IO.Directory]::CreateDirectory($matrixRoot) | Out-Null
 try {
  $source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'build_alchemist_basher_safety_package.ps1'))
  $package=[IO.File]::ReadAllText($PackagePath)
  foreach($builderNewline in @("`r`n","`n")){
   foreach($packageNewline in @("`n","`r`n")){
    $builder=Join-Path $matrixRoot 'builder.ps1'
    $fixture=Join-Path $matrixRoot 'package.xml'
    [IO.File]::WriteAllText($builder,[regex]::Replace($source,'\r\n?|\n',$builderNewline),[Text.UTF8Encoding]::new($false))
    $expected=[regex]::Replace($package,'\r\n?|\n',$packageNewline)
    [IO.File]::WriteAllText($fixture,$expected,[Text.UTF8Encoding]::new($false))
    & $builder -PackagePath $fixture
    $built=[IO.File]::ReadAllText($fixture)
    & $builder -PackagePath $fixture
    if($built -cne [IO.File]::ReadAllText($fixture)){throw 'Alchemist Basher builder is not idempotent across LF/CRLF checkout encodings'}
    if($built -cne $expected){throw 'Alchemist Basher builder changed a current LF/CRLF package'}
   }
  }
  Write-Output 'PASS: Basher builder LF/CRLF checkout and package newline matrix preserves exact bytes and idempotence'
 }finally{
  Remove-Item -LiteralPath (Join-Path $matrixRoot 'builder.ps1'),(Join-Path $matrixRoot 'package.xml') -Force -ErrorAction SilentlyContinue
  if(Test-Path -LiteralPath $matrixRoot){Remove-Item -LiteralPath $matrixRoot -Force}
 }
 Write-Output 'PASS: Alchemist Legacy hunting suspension, other-class behavior, future enable and builder parity'
}finally{if(Test-Path -LiteralPath $scratch){Remove-Item -LiteralPath $scratch -Force}}
