param([string]$LogPath='C:\Users\shuji\Downloads\g7p9YZ88.html')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$y=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/Yso system.xml'))
$a=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/AK.xml'))
$alias=$y.SelectSingleNode('//Alias[name="Truelocks"]')
if(-not $alias -or $alias.regex -cne '^tlock$' -or $alias.GetAttribute('isActive') -ne 'yes'){throw 'Missing active Truelocks alias'}
$pairs=@(
 @('Apostate/evileye_reference.lua','Apostate reference',$y),
 @('Apostate/necromancy_reference.lua','Necromancy reference',$y),
 @('Apostate/deadeyes.lua','Deadeye combo sorter',$y),
 @('Yso/xml/apostate_utilities.lua','Apostate utilities',$y),
 @('Apostate/daegger_envenom.lua','Apostate daegger envenom',$y),
 @('Apostate/truelock.lua','Apostate Truelocks',$y),
 @('Apostate/ak_tracking.lua','Apostate tracking',$a),
 @('Apostate/ak_target_check.lua','Target Check',$a),
 @('Yso/Combat/route_registry.lua','Route registry',$y),
 @('Yso/xml/yso_modes.lua','Yso modes',$y)
)
$lua=[Collections.Generic.List[string]]::new()
$lua.Add('local original=dofile;local embedded={}');$luaRoot=$root.Replace('\','/')
foreach($p in $pairs){
 $node=$p[2].SelectSingleNode('//Script[name="'+$p[1]+'"]')
 if(-not $node){throw ('Missing script '+$p[1])}
 $source=[IO.File]::ReadAllText((Join-Path $root $p[0]))
 if($p[1] -ne 'Yso modes' -and $node.script.Replace("`r`n","`n") -cne $source.Replace("`r`n","`n")){throw ('Source/package drift: '+$p[1])}
 $lua.Add('embedded[ [==['+$luaRoot+'/'+$p[0]+']==] ]=[====['+$node.script+']====]')
}
$lua.Add('dofile=function(p) if embedded[p] then return assert(load(embedded[p],p))() end return original(p) end')
$lua.Add('TruelocksAlias=assert(load([====['+$alias.script+']====]))')
$lua.Add('TruelocksTargetCheck=assert(load([====['+$a.SelectSingleNode('//Script[name="Target Check"]').script+']====]))')
$wardDown=$a.SelectSingleNode('//Trigger[name="CurseWard Down"]')
if(-not $wardDown){throw 'Missing Curseward removal adapter'}
$lua.Add('TruelocksWardResponses={}')
foreach($fixture in @(@('shattered',"Saibel's curseward shatters!",'Saibel'),@('no_effect',"Your attempt to breach Saibel's curseward has no effect.",'Saibel'),@('mixed_no_effect',"Your attempt to breach Maldrantus's curseward has no effect.",'Maldrantus'),@('mixed_shattered',"Maldrantus's curseward shatters!",'Maldrantus'))){
 $matched=$false
 foreach($pattern in $wardDown.regexCodeList.string){if($fixture[1] -match $pattern -and $Matches[1] -ceq $fixture[2]){$matched=$true}}
 if(-not $matched){throw ('Curseward fixture did not match target: '+$fixture[0])}
 $lua.Add('TruelocksWardResponses.'+$fixture[0]+'=function() local prior=matches;matches={[1]=[==['+$fixture[1]+']==],[2]=[==['+$fixture[2]+']==]};assert(load([====['+$wardDown.script+']====]))();matches=prior end')
}
$lua.Add('arg={[1]=[==['+$luaRoot+']==]};original([==['+$luaRoot+'/Apostate/test_truelock.lua]==])')
$eyeRejection=$y.SelectSingleNode('//TriggerGroup[name="Apostate"]/TriggerGroup[name="Apostasy"]/Trigger[name="Truelocks eye rejected"]')
if(-not $eyeRejection -or $eyeRejection.isActive -ne 'yes'){throw 'Missing active eye-rejection adapter in Apostate/Apostasy'}
$eyeRejectionSource=[IO.File]::ReadAllText((Join-Path $root 'Apostate/eye_rejected.lua'))
if($eyeRejection.script.Trim() -cne $eyeRejectionSource.Trim()){throw 'Eye-rejection adapter source/package drift'}
$rejectionLua=[Collections.Generic.List[string]]::new()
$rejectionLua.Add('TruelocksEyeRejections={}')
foreach($fixture in @(
 @('equilibrium','You must regain equilibrium first.'),
 @('balance','You must regain balance first.'),
 @('blind','You cannot use the evil eye while blind.'),
 @('curseward','You try to curse Saibel, but she is warded.'),
 @('curseward_stare','You stare at Saibel, giving her the evil eye, but she is warded.')
)){
 $matched=$false;$capture='nil'
 foreach($pattern in $eyeRejection.regexCodeList.string){
  if($fixture[1] -cmatch $pattern){
   $matched=$true
   if($Matches.ContainsKey(1)){$capture='[==['+$Matches[1]+']==]'}
   break
  }
 }
 if(-not $matched){throw ('Eye rejection fixture did not match: '+$fixture[0])}
 $rejectionLua.Add('TruelocksEyeRejections.'+$fixture[0]+'=function() local prior=matches;matches={[1]=[==['+$fixture[1]+']==],[2]='+$capture+'};assert(load([====['+$eyeRejection.script+']====]))();matches=prior end')
}
foreach($line in @('Equilibrium used: 3.00 seconds.','Balance used: 1.90 seconds.','(Party): You must regain equilibrium first.')){
 foreach($pattern in $eyeRejection.regexCodeList.string){if($line -cmatch $pattern){throw 'Eye rejection adapter accepted a success/chat line'}}
}
$lua.Insert($lua.Count-1,($rejectionLua -join "`n"))
$code=$lua -join "`n"
$code | & 'C:\Program Files\Lua\5.4.8\lua.exe' -
if($LASTEXITCODE -ne 0){throw 'Embedded Truelocks behavioral tests failed'}
$puncture=$a.SelectSingleNode('//Trigger[name="Apostate Puncture"]')
if(-not $puncture){throw 'Missing Puncture confirmation adapter'}
if(Test-Path -LiteralPath $LogPath){
 $plain=[Net.WebUtility]::HtmlDecode([regex]::Replace([IO.File]::ReadAllText($LogPath),'<[^>]+>',''))
 $hits=@($plain -split '\r?\n' | Where-Object {$_ -match $puncture.regexCodeList.string})
 if($hits.Count -ne 4){throw ('Expected four captured Punctures, found '+$hits.Count)}
 Write-Output 'PASS four Puncture success messages from supplied combat log'
}
Write-Output 'PASS active alias, embedded source parity, route integration'
& 'C:\Program Files\Lua\5.4.8\lua.exe' (Join-Path $root 'Apostate/test_truelock_padding.lua') $root
if($LASTEXITCODE -ne 0){throw 'Staged padding tests failed'}
& 'C:\Program Files\Lua\5.4.8\lua.exe' (Join-Path $root 'Apostate/test_truelock_emission.lua') $root
if($LASTEXITCODE -ne 0){throw 'Real emitter integration failed'}
