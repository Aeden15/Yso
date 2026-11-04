$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$package=Join-Path $root 'mudlet packages/Yso system.xml'
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('yso-combat-pause-'+[guid]::NewGuid())
$copy=$scratch+'.xml';$luaFile=$scratch+'.lua'
$mapping=@(
 @('Combat paralysis policy','Yso/Combat/combat_pause.lua'),@('Api stuff','Yso/xml/api_stuff.lua'),@('Yso modes','Yso/xml/yso_modes.lua'),
 @('Apostate Truelocks','Apostate/lock_route.lua'),@('Airlord route runtime','Airlord/route_runtime.lua'),
 @('Airlord lock route','Airlord/lock_route.lua'),@('Airlord damage route','Airlord/damage_route.lua'),
 @('Compression logic','Airlord/compression.lua'),
 @('Shikudo duel controller','Monk/shikudo_duel.lua'),@('Magi route core','Magi/magi_route_core.lua'),
 @('Alchemist physiology','Alchemist/Core/physiology.lua'),@('Alchemist duel route','Alchemist/Core/duel route.lua'),
 @('Alchemist aurify route','Alchemist/Aurify route.lua'),@('Alchemist group damage','Alchemist/Core/group damage.lua')
)
try{
 Copy-Item -LiteralPath $package -Destination $copy
 $before=[IO.File]::ReadAllText($copy)
 & (Join-Path $PSScriptRoot 'build_combat_pause_package.ps1') -PackagePath $copy | Out-Null
 if([IO.File]::ReadAllText($copy) -cne $before){throw 'Rebuild changed current package'}
 [xml]$doc=$before
 foreach($row in $mapping){
  $body=$doc.SelectSingleNode('//Script[name="'+$row[0]+'"]//script').InnerText
  if($body.Replace("`r`n","`n") -cne [IO.File]::ReadAllText((Join-Path $root $row[1])).Replace("`r`n","`n")){throw ('Source parity: '+$row[0])}
  [IO.File]::WriteAllText($luaFile,$body)
  & luac -p $luaFile;if($LASTEXITCODE -ne 0){throw ('Syntax: '+$row[0])}
 }
 foreach($row in @(@('Group damage','Monk/shdam_alias_body.lua'),@('mfocus','Magi/mfocus_alias_body.lua'))){
  if($doc.SelectSingleNode('//Alias[name="'+$row[0]+'"]//script').InnerText.Replace("`r`n","`n") -cne [IO.File]::ReadAllText((Join-Path $root $row[1])).Replace("`r`n","`n")){throw ('Alias parity: '+$row[0])}
 }
 foreach($row in @(@('Yso/Combat/route_interface.lua','Yso/xml/route_interface.lua'),@('Yso/Core/queue.lua','Yso/xml/yso_queue.lua'))){
  if([IO.File]::ReadAllText((Join-Path $root $row[0])) -cne [IO.File]::ReadAllText((Join-Path $root $row[1]))){throw 'Source mirror drift'}
 }
 foreach($test in @('test_combat_pause.lua','test_combat_pause_adapters.lua','test_combat_pause_emission.lua')){
  & lua (Join-Path $root ('Yso/Tests and rebuilds/'+$test)) $root
  if($LASTEXITCODE -ne 0){throw $test}
 }
 Write-Host 'PASS combat pause package: native syntax, source/mirror/alias parity, stable rebuild and shared regression suites'
}finally{
 foreach($file in @($copy,$luaFile)){if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file}}
}
