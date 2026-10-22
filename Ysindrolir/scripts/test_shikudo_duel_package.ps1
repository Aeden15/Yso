param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'),
  [string]$LimbPackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/limb.1.2.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$base=Join-Path ([IO.Path]::GetTempPath()) ('yso-duel-'+[guid]::NewGuid())
$files=@(($base+'.xml'),($base+'.limb.xml'),($base+'.controller.lua'),($base+'.limb.lua'),($base+'.syntax.lua'),($base+'.modes.lua'),($base+'.api.lua'),($base+'.selector.lua'))
function Assert($condition,$message){if(-not $condition){throw $message}}
function Strip([string]$text,[string]$tag,[string[]]$names){
  $alternatives=($names|ForEach-Object{[regex]::Escape($_)}) -join '|'
  [regex]::Replace($text,'(?s)<'+$tag+'\b[^>]*>\s*<name>(?:'+$alternatives+')</name>.*?</'+$tag+'>','')
}
try {
  Copy-Item -LiteralPath $PackagePath -Destination $files[0]
  Copy-Item -LiteralPath $LimbPackagePath -Destination $files[1]
  $before=[IO.File]::ReadAllText($files[0]);$limbBefore=[IO.File]::ReadAllText($files[1])
  $builder=Join-Path $PSScriptRoot 'build_shikudo_duel_package.ps1'
  & $builder -PackagePath $files[0] -LimbPackagePath $files[1]
  $after=[IO.File]::ReadAllText($files[0]);$limbAfter=[IO.File]::ReadAllText($files[1])
  [xml]$doc=$after;[xml]$ldoc=$limbAfter
  [xml]$beforeDoc=$before
  foreach($name in @('Pulse: EQ recovered','Pulse: BAL recovered','Pulse: Monk limb recovered')){
    $oldBody=[string]$beforeDoc.SelectSingleNode('//Trigger[name="'+$name+'"]').script
    $newBody=[string]$doc.SelectSingleNode('//Trigger[name="'+$name+'"]').script
    $prefix=$oldBody -replace '(?s)\r?\n-- Shikudo duel recovery adapter.*$',''
    Assert ($newBody.StartsWith($prefix)) ('Pulse/group behavior changed: '+$name)
    Assert (([regex]::Matches($newBody,'-- Shikudo duel recovery adapter')).Count -eq 1) 'Duplicate recovery adapter'
  }
  $mapping=[ordered]@{'Combo logic'='Monk/combo.lua';'Route registry'='Yso/xml/route_registry.lua';
    'Shikudo limb bridge'='Monk/shikudo_limb_bridge.lua';'Shikudo duel selector'='Monk/shikudo_duel_selector.lua';'Shikudo duel controller'='Monk/shikudo_duel.lua'}
  foreach($entry in $mapping.GetEnumerator()){
    $nodes=$doc.SelectNodes('//Script[name="'+$entry.Key+'"]')
    Assert ($nodes.Count -eq 1 -and $nodes[0].isActive -eq 'yes') ('Missing active script '+$entry.Key)
    Assert ($nodes[0].script.Trim().Replace("`r`n","`n") -ceq [IO.File]::ReadAllText((Join-Path $root $entry.Value)).Trim().Replace("`r`n","`n")) ('Source parity: '+$entry.Key)
  }
  $alias=$doc.SelectSingleNode('//Alias[name="Shikudo duel"]')
  Assert ($alias.isActive -eq 'yes' -and $alias.ParentNode.name -eq 'Shikudo') 'Wrong duel alias folder'
  foreach($name in @('','dispatch','lock','blackout','scythe','on','off','status','preview')){
    $shortcut=if($name){'shduel '+$name}else{'shduel'}
    Assert ($shortcut -cmatch $alias.regex) ('Shortcut rejected: '+$shortcut)
  }
  foreach($bad in @('shduel locks','shduel lock extra','shduelx','shduel;look')){Assert (-not ($bad -cmatch $alias.regex)) 'Invalid alias accepted'}
  $slain=$doc.SelectSingleNode('//Trigger[name="Shikudo duel target slain"]')
  Assert ('You have slain Bob, retrieving the corpse.' -cmatch $slain.regexCodeList.string[0]) 'Slain pattern rejected'
  $activity=$doc.SelectSingleNode('//Trigger[name="Shikudo local target activity"]')
  Assert ('Maldrantus takes a drink from an elegant diamond vial.' -cmatch $activity.regexCodeList.string[0]) 'Captured local activity rejected'
  Assert (-not ('(Clan): Maldrantus takes a drink from an elegant diamond vial.' -cmatch $activity.regexCodeList.string[0])) 'Chat must not establish local presence'
  $harness='local seen={}; Yso={off={monk={duel={note_local_target_activity=function(n) seen.duel=n end},group_damage={note_local_target_activity=function(n) seen.group=n end}}}}; matches={"","Maldrantus"};' + "`n" + $activity.script + "`n" + 'assert(seen.duel=="Maldrantus" and seen.group=="Maldrantus")'
  [IO.File]::WriteAllText($files[4],$harness,(New-Object Text.UTF8Encoding $false))
  & lua $files[4]
  if($LASTEXITCODE -ne 0){throw 'Packaged local-presence adapter failed'}
  $denial=$doc.SelectSingleNode('//Trigger[name="Shikudo duel target unavailable"]')
  Assert ('I do not recognise anything called that here.' -cmatch $denial.regexCodeList.string) 'Target-denial pattern rejected'
  $grace=$doc.SelectSingleNode('//Trigger[name="Shikudo duel target grace"]')
  Assert ('Maldrantus walks in Divine Grace. You may not harm him.' -cmatch $grace.regexCodeList.string) 'Captured Divine Grace refusal rejected'
  Assert ($Matches[1] -ceq 'Maldrantus') 'Grace target capture changed'
  Assert (-not ('(Clan): Maldrantus walks in Divine Grace. You may not harm him.' -cmatch $grace.regexCodeList.string)) 'Chat must not reject an action'
  $harness='local seen; Yso={off={monk={duel={note_target_grace=function(n) seen=n end}}}}; matches={"","Maldrantus"};' + "`n" + $grace.script + "`n" + 'assert(seen=="Maldrantus")'
  [IO.File]::WriteAllText($files[4],$harness,(New-Object Text.UTF8Encoding $false))
  & lua $files[4]
  if($LASTEXITCODE -ne 0){throw 'Packaged Divine Grace adapter failed'}
  $refusal=$doc.SelectSingleNode('//Trigger[name="Shikudo duel resource refusal"]')
  Assert ('You must regain balance first.' -cmatch $refusal.regexCodeList.string) 'Exact balance refusal rejected'
  Assert (-not ('Balance used: 2.0 seconds.' -cmatch $refusal.regexCodeList.string)) 'Balance usage must not reject a cast'
  Assert (-not ('(Clan): You must regain balance first.' -cmatch $refusal.regexCodeList.string)) 'Chat must not reject a cast'
  $harness='local seen; Yso={off={monk={duel={note_resource_refusal=function(n) seen=n end}}}}; matches={"","balance"};' + "`n" + $refusal.script + "`n" + 'assert(seen=="bal");matches[2]="equilibrium";' + "`n" + $refusal.script + "`n" + 'assert(seen=="eq")'
  [IO.File]::WriteAllText($files[4],$harness,(New-Object Text.UTF8Encoding $false))
  & lua $files[4]
  if($LASTEXITCODE -ne 0){throw 'Packaged resource-refusal adapter failed'}
  $impatience=$doc.SelectSingleNode('//Trigger[name="Shikudo mind impatience confirmed"]')
  Assert ('You fill the mind of Aegoth with an impatient feeling.' -cmatch $impatience.regexCodeList.string) 'Live Telepathy success rejected'
  Assert ($Matches[1] -ceq 'Aegoth') 'Telepathy recipient capture changed'
  Assert (-not ('(Clan): You fill the mind of Aegoth with an impatient feeling.' -cmatch $impatience.regexCodeList.string)) 'Chat must not confirm Impatience'
  $harness='local seen;Yso={off={monk={duel={note_impatience_success=function(n) seen=n end}}}};matches={"","Aegoth"};' + "`n" + $impatience.script + "`n" + 'assert(seen=="Aegoth")'
  [IO.File]::WriteAllText($files[4],$harness,(New-Object Text.UTF8Encoding $false))
  & lua $files[4]
  if($LASTEXITCODE -ne 0){throw 'Packaged Telepathy success adapter failed'}
  $focusStart=$doc.SelectSingleNode('//Trigger[name="Shikudo hyperfocus started"]')
  $focusHead=$doc.SelectSingleNode('//Trigger[name="Shikudo hyperfocus head"]')
  Assert ('You begin breathing deeply, sinking into a focused trance.' -cmatch $focusStart.regexCodeList.string) 'Captured focus start rejected'
  Assert ('You will now focus on bypassing attempts to deflect blows when striking the head.' -cmatch $focusHead.regexCodeList.string) 'Captured head focus rejected'
  Assert (-not ('(Clan): You will now focus on bypassing attempts to deflect blows when striking the head.' -cmatch $focusHead.regexCodeList.string)) 'Chat must not confirm focus'
  $harness='local focus="head"; Yso={off={monk={duel={note_hyperfocus=function(n) focus=n end}}}};' + "`n" + $focusStart.script + "`n" + 'assert(focus==nil);' + "`n" + $focusHead.script + "`n" + 'assert(focus=="head")'
  [IO.File]::WriteAllText($files[4],$harness,(New-Object Text.UTF8Encoding $false))
  & lua $files[4]
  if($LASTEXITCODE -ne 0){throw 'Packaged head-focus confirmations failed'}
  $capture=$ldoc.SelectSingleNode('//Trigger[name="dealt limb damage"]')
  Assert ($capture.ParentNode.name -eq 'Limb') 'Numeric capture still gated on queued banner'
  Assert ('As your blow lands with a crunch, you perceive that you have dealt 7.6% damage to D-Name''s left leg.' -cmatch $capture.regexCodeList.string[0]) 'Numeric damage pattern failed'
  Assert ($Matches.name -eq 'D-Name' -and $Matches.amount -eq '7.6') 'Numeric captures changed'
  foreach($line in @('Maldrantus parries the attack with a deft manoeuvre.','A reflection of Maldrantus blinks out of existence.')) {
    foreach($pattern in $capture.regexCodeList.string){Assert (-not ($line -cmatch $pattern)) 'Blocked attacks must not become numeric hits'}
  }
  Assert ('As your blow lands with a crunch, you perceive that you have dealt 3.9% damage to Maldrantus''s head.' -cmatch $capture.regexCodeList.string[0]) 'Captured focused head damage rejected'
  $core=$ldoc.SelectSingleNode('//Script[name="limb init"]').script
  $bridge=$doc.SelectSingleNode('//Script[name="Shikudo limb bridge"]').script
  $resetAlias=$ldoc.SelectSingleNode('//Alias[regex="^lra$"]')
  Assert ($resetAlias.script.Trim() -eq 'lb.resetCurrentTarget()') 'lra must use the current-target reset'
  $harness='Yso={monk={}};raiseEvent=function() end;cecho=function() end;tempTimer=function() return 1 end;killTimer=function() end;' + "`n" + $core + "`nlocal function bridge_init()`n" + $bridge + "`nend;bridge_init();`n" + 'lb.resetAll("Maldrantus"); matches={name="Maldrantus",limb="head",amount="3.9"};' + "`n" + $capture.script + "`n" + 'matches={name="Maldrantus",limb="right leg",amount="7.6"};' + "`n" + $capture.script + "`n" + 'Yso.monk.limbs.note_success("Maldrantus","hiraku");assert(lb.Maldrantus.hits.head==3.9 and lb.Maldrantus.hits["right leg"]==7.6);assert(Yso.monk.limbs.snapshot("Maldrantus").confidence.head=="known")'
  [IO.File]::WriteAllText($files[4],$harness,(New-Object Text.UTF8Encoding $false))
  & lua $files[4]
  if($LASTEXITCODE -ne 0){throw 'Actual packaged numeric hit accumulation failed'}
  Assert ($ldoc.SelectSingleNode('//Script[name="limb init"]').script.Trim() -ceq [IO.File]::ReadAllText((Join-Path $root 'Monk/limb_tracker.lua')).Trim()) 'Limb source parity failed'
  foreach($text in @($before,$after)){
    $stripped=Strip $text 'Script' @($mapping.Keys)
    $stripped=Strip $stripped 'Alias' @('Shikudo duel')
    $stripped=Strip $stripped 'Trigger' @('Shikudo duel target slain','Shikudo local target activity','Shikudo duel target unavailable','Shikudo duel target grace','Shikudo duel resource refusal','Shikudo mind impatience confirmed','Shikudo hyperfocus started','Shikudo hyperfocus head','Pulse: EQ recovered','Pulse: BAL recovered','Pulse: Monk limb recovered')
    if($text -ceq $before){$untouched=$stripped}else{Assert ($untouched -ceq $stripped) 'Unrelated Yso bytes changed'}
  }
  foreach($text in @($limbBefore,$limbAfter)){
    $stripped=Strip $text 'Script' @('limb init','limb management','limb prompt')
    $stripped=Strip $stripped 'Alias' @('^lr (.+)$','^lra$')
    $stripped=Strip $stripped 'Trigger' @('limb salve','dealt limb damage','Shikudo Hiraku observed','Shikudo Kuro observed','Shikudo Ruku observed')
    if($text -ceq $limbBefore){$untouched=$stripped}else{Assert ($untouched -ceq $stripped) 'Unrelated limb bytes changed'}
  }
  & $builder -PackagePath $files[0] -LimbPackagePath $files[1]
  Assert ($after -ceq [IO.File]::ReadAllText($files[0])) 'Yso rebuild not idempotent'
  Assert ($limbAfter -ceq [IO.File]::ReadAllText($files[1])) 'Limb rebuild not idempotent'
  foreach($document in @($doc,$ldoc)){
    foreach($script in $document.SelectNodes('//script')){
      if([string]::IsNullOrWhiteSpace($script.InnerText)){continue}
      [IO.File]::WriteAllText($files[4],$script.InnerText,(New-Object Text.UTF8Encoding $false))
      & luac -p $files[4]
      if($LASTEXITCODE -ne 0){throw ('Packaged Lua syntax failed: '+$script.ParentNode.name)}
    }
  }
  [IO.File]::WriteAllText($files[2],$doc.SelectSingleNode('//Script[name="Shikudo duel controller"]').script,(New-Object Text.UTF8Encoding $false))
  [IO.File]::WriteAllText($files[7],$doc.SelectSingleNode('//Script[name="Shikudo duel selector"]').script,(New-Object Text.UTF8Encoding $false))
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_shikudo_light.lua') $root $files[7]
  if($LASTEXITCODE -ne 0){throw 'Actual packaged LIGHT normalizer failed'}
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_shikudo_staged_lock.lua') $root $files[7]
  if($LASTEXITCODE -ne 0){throw 'Actual packaged staged lock planner failed'}
  [IO.File]::WriteAllText($files[3],$ldoc.SelectSingleNode('//Script[name="limb init"]').script,(New-Object Text.UTF8Encoding $false))
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_shikudo_duel_route.lua') $root $files[2]
  if($LASTEXITCODE -ne 0){throw 'Actual packaged duel controller failed lock test'}
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_shikudo_impatience_ak.lua') $files[2]
  if($LASTEXITCODE -ne 0){throw 'Actual packaged controller/AK Impatience cure replay failed'}
  [IO.File]::WriteAllText($files[5],$doc.SelectSingleNode('//Script[name="Yso modes"]').script,(New-Object Text.UTF8Encoding $false))
  [IO.File]::WriteAllText($files[6],$doc.SelectSingleNode('//Script[name="Api stuff"]').script,(New-Object Text.UTF8Encoding $false))
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_shikudo_duel_startup.lua') $root $files[5] $files[6] $files[2]
  if($LASTEXITCODE -ne 0){throw 'Actual packaged scheduler/emitter failed stale-room startup test'}
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_shikudo_limbs.lua') $root $files[3]
  if($LASTEXITCODE -ne 0){throw 'Actual packaged limb core failed'}
  $core=$ldoc.SelectSingleNode('//Script[name="limb init"]').script
  $prompt=$ldoc.SelectSingleNode('//Script[name="limb prompt"]').script
  $reset=$ldoc.SelectSingleNode('//Alias[name="^lr (.+)$"]').script
  $harness='raiseEvent=function() end; cecho=function() end; tempTimer=function() return 1 end; killTimer=function() end;' + "`n" + $core + "`n" + $prompt + "`n" + 'target="D-Name"; lb.addHit(target,"head",12); assert(lb.prompt():find("12",1,true)); matches={"lr head","head"};' + "`n" + $reset + "`n" + 'assert(lb[lb.normalizeName(target)].hits.head==0)'
  [IO.File]::WriteAllText($files[4],$harness,(New-Object Text.UTF8Encoding $false))
  & lua $files[4]
  if($LASTEXITCODE -ne 0){throw 'Legacy prompt/reset alias normalization failed'}
  Write-Host 'PASS scoped duel/limb package parity, alias patterns, exact capture, syntax, idempotence and lock replay'
} finally {foreach($path in $files){if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path}}}
