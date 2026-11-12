param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('yso-airlord-lock-'+[guid]::NewGuid())
try {
 [xml]$doc=[IO.File]::ReadAllText($PackagePath)
 $names=@('Compression logic','Airlord route runtime','Airlord lock route','Airlord damage route')
 $sources=@('compression.lua','route_runtime.lua','lock_route.lua','damage_route.lua')
 $allNames=@($doc.SelectNodes('//Script') | ForEach-Object {[string]$_.name})
 $previous=-1
 for($i=0;$i -lt $names.Count;$i++){
  $nodes=$doc.SelectNodes('//Script[name="'+$names[$i]+'"]')
  if($nodes.Count -ne 1 -or $nodes[0].isActive -ne 'yes'){throw ('Missing unique active script '+$names[$i])}
  $index=[array]::IndexOf($allNames,$names[$i])
  if($index -le $previous){throw 'Invalid Airlord script load order'}
  $previous=$index
  $source=[IO.File]::ReadAllText((Join-Path $root ('Airlord/'+$sources[$i])))
  if(([string]$nodes[0].script).Replace("`r`n","`n") -cne $source.Replace("`r`n","`n")){throw ('Source parity: '+$names[$i])}
  [IO.File]::WriteAllText(($scratch+'.syntax.lua'),[string]$nodes[0].script)
  & luac -p ($scratch+'.syntax.lua')
  if($LASTEXITCODE -ne 0){throw ('Lua syntax: '+$names[$i])}
 }
 if($doc.SelectSingleNode('//Script[name="Airlord attack logic"]')){throw 'Combined Airlord script still present'}
 if($doc.SelectSingleNode('//Alias[name="alupdraft"]/script').InnerText -ne 'Yso.off.airlord.damage.toggle_updraft()'){throw 'Updraft alias must select damage'}
 foreach($entry in @(@('Compression logic','.compression.lua'),@('Airlord route runtime','.runtime.lua'),@('Airlord lock route','.lock.lua'))){
  $node=$doc.SelectSingleNode('//Script[name="'+$entry[0]+'"]')
  if(-not $node -and $entry[0] -eq 'Airlord route runtime'){continue}
  if(-not $node -and $entry[0] -eq 'Airlord lock route'){$node=$doc.SelectSingleNode('//Script[name="Airlord attack logic"]')}
  if(-not $node){throw ('Missing '+$entry[0])}
  [IO.File]::WriteAllText(($scratch+$entry[1]),[string]$node.script,(New-Object Text.UTF8Encoding $false))
 }
 [xml]$akDoc=[IO.File]::ReadAllText((Join-Path $root 'mudlet packages/AK.xml'))
 $triggerNames=[ordered]@{
  strangle='Strangle'; strangle_continues='Strangle relapse 2'; strangle_reapplies='Strangle relapse'
  scour='Scour'; scour_continues='Scour relapse 2'; scour_reapplies='Scour relapse'
  zephyr='Zephyr'; zephyr_continues='Zephyr relapse 2'; zephyr_blackout='Zephyr relapse 3'; zephyr_reapplies='Zephyr relapse'
 }
 $tracker=$akDoc.SelectSingleNode('//Script[name="Airlord relapse tracking"]/script')
 if($tracker){[IO.File]::WriteAllText(($scratch+'.tracker.lua'),$tracker.InnerText)}
 foreach($key in $triggerNames.Keys){
  $triggers=$akDoc.SelectNodes('//Trigger[name="'+$triggerNames[$key]+'"]/script')
  if($triggers.Count -ne 1){throw ('Expected a unique AK trigger: '+$triggerNames[$key])}
  [IO.File]::WriteAllText(($scratch+'.'+$key+'.lua'),$triggers[0].InnerText)
 }
 $cure=$doc.SelectSingleNode('//Trigger[name="Airlord feedback pressure cure"]')
 $curePatterns=$cure.SelectNodes('regexCodeList/string') | ForEach-Object {$_.InnerText}
 if(($curePatterns -join ' ') -notmatch 'prickly pear' -or ($curePatterns -join ' ') -notmatch 'calcite mote'){
  throw 'Pressure cure trigger must cover pear and calcite'
 }
 [IO.File]::WriteAllText(($scratch+'.pressure_cure.lua'),$cure.SelectSingleNode('script').InnerText)
 & lua (Join-Path $root 'Yso/Tests and rebuilds/test_airlord_relapses.lua') $scratch
 if($LASTEXITCODE -ne 0){throw 'Airlord AK relapse regressions failed'}
 if($akDoc.SelectSingleNode('//Script[name="Hard Reset"]/script').InnerText -notmatch 'ak\.duress\.reset_relapses\(\)'){
  throw 'AK Hard Reset must clear Airlord relapse timers'
 }
 & lua (Join-Path $root 'Yso/Tests and rebuilds/test_airlord_lock.lua') $scratch
 if($LASTEXITCODE -ne 0){throw 'Airlord lock regressions failed'}
 $copy=$scratch+'.xml'
 $before=[IO.File]::ReadAllText($PackagePath)
 [IO.File]::WriteAllText($copy,$before)
 & (Join-Path $PSScriptRoot 'build_airlord_package.ps1') -PackagePath $copy | Out-Null
 if([IO.File]::ReadAllText($copy) -cne $before){throw 'Scoped Airlord rebuild changed the package'}
 # Exercise upgrading a package that still uses the legacy combined entry.
 $legacy=$before.Replace('<name>Airlord lock route</name>','<name>Airlord attack logic</name>')
 foreach($name in @('Airlord route runtime','Airlord damage route')){
  $legacy=[regex]::Replace($legacy,'(?s)<Script\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</Script>','')
 }
 $legacy=$legacy.Replace('Yso.off.airlord.damage.toggle_updraft()','Yso.off.airlord.lock.toggle_updraft()')
 [IO.File]::WriteAllText($copy,$legacy)
 & (Join-Path $PSScriptRoot 'build_airlord_package.ps1') -PackagePath $copy | Out-Null
 if([IO.File]::ReadAllText($copy) -cne $before){throw 'Legacy migration did not restore the scoped package exactly'}
 Write-Host 'PASS Airlord source parity, native syntax, load order, stable rebuild and legacy migration'
} finally {
 foreach($file in @((Get-ChildItem -LiteralPath (Split-Path $scratch -Parent) -Filter ((Split-Path $scratch -Leaf)+"*.lua")))){Remove-Item -LiteralPath $file.FullName}
 $copy=$scratch+'.xml'
 if(Test-Path -LiteralPath $copy){Remove-Item -LiteralPath $copy}
}
