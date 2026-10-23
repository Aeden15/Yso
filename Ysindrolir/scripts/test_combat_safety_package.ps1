param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$base=Join-Path ([IO.Path]::GetTempPath()) ('yso-safety-'+[guid]::NewGuid())
function Assert($condition,[string]$message){if(-not $condition){throw $message}}
function Normalize([string]$text){$text.Trim().Replace("`r`n","`n")}
function Mask([string]$text){
  foreach($spec in @(
    @('Script','Api stuff'),@('Script','Yso modes'),@('Script','Enemy Deliverance safety'),
    @('Script','Magi resonance feedback'),@('Script','Route registry'),@('Script','Magi group route retirement'),@('Script','Magi duel dam'),@('Trigger','Enemy Deliverance'),
    @('Trigger','Enemy Deliverance stage 2'),@('Trigger','Mfocus resonance depleted'),
    @('Trigger','Mfocus resonance feedback'),@('Trigger','Mfocus resonance failure'),
    @('Alias','Deliverance safety'),@('Alias','mdam'),@('Alias','mfocus'))){
    $pattern='(?s)<'+$spec[0]+'\b[^>]*>\s*<name>'+[regex]::Escape($spec[1])+'</name>.*?</'+$spec[0]+'>'
    $text=[regex]::Replace($text,$pattern,'')
  }
  $text
}
New-Item -ItemType Directory -Force $base | Out-Null
try {
  $copy=Join-Path $base 'package.xml'
  Copy-Item -LiteralPath $PackagePath -Destination $copy
  $before=[IO.File]::ReadAllText($copy)
  & (Join-Path $PSScriptRoot 'build_combat_safety_package.ps1') -PackagePath $copy
  $after=[IO.File]::ReadAllText($copy)
  Assert ((Mask $before) -ceq (Mask $after)) 'Builder modified unrelated package content'
  & (Join-Path $PSScriptRoot 'build_combat_safety_package.ps1') -PackagePath $copy
  Assert ($after -ceq [IO.File]::ReadAllText($copy)) 'Builder is not idempotent'
  [xml]$doc=$after
  foreach($row in @(@('Api stuff','Yso/xml/api_stuff.lua'),@('Yso modes','Yso/xml/yso_modes.lua'),
    @('Enemy Deliverance safety','Yso/Combat/deliverance.lua'),@('Magi resonance feedback','Magi/resonance_feedback.lua'),
    @('Route registry','Yso/Combat/route_registry.lua'),@('Magi group route retirement','Magi/retire_group_damage.lua'),@('Magi weapons','Magi/magi_weapons.lua'),
    @('Magi duel dam','Magi/Magi_duel_dam.lua'),@('Magi firestorm','Magi/Magi_firestorm.lua'),
    @('Magi water group','Magi/Magi_water_group.lua'),@('Magi elemental helpers','Yso/xml/magi_elemental_helpers.lua'),
    @('Yso serverside policy','Yso/Curing/serverside_policy.lua'),@('Yso self aff','Yso/Core/self_aff.lua'),
    @('Yso pulse','Yso/xml/yso_pulse_wake_bus.lua'),@('Convergence logic','Magi/magi_convergence.lua'),
    @('Apostate Truelocks','Apostate/truelock.lua'))){
    $nodes=$doc.SelectNodes('//Script[name="'+$row[0]+'"]')
    Assert ($nodes.Count -eq 1 -and $nodes[0].isActive -eq 'yes') ('Missing active script '+$row[0])
    Assert ((Normalize $nodes[0].script) -ceq (Normalize ([IO.File]::ReadAllText((Join-Path $root $row[1]))))) ('Source/XML mismatch '+$row[0])
    $dest=Join-Path $base $row[1]
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    [IO.File]::WriteAllText($dest,[string]$nodes[0].script,(New-Object Text.UTF8Encoding $false))
    & luac -p $dest
    if($LASTEXITCODE -ne 0){throw ('Lua syntax: '+$row[0])}
  }
  $first=$doc.SelectSingleNode('//Trigger[name="Enemy Deliverance"]')
  foreach($row in @(@('mfocus','Magi/mfocus_alias_body.lua'),@('mdam','Magi/mdam_retired_alias.lua'))){
    $node=$doc.SelectSingleNode('//Alias[name="'+$row[0]+'"]')
    Assert ((Normalize $node.script) -ceq (Normalize ([IO.File]::ReadAllText((Join-Path $root $row[1]))))) ('Generated alias drift '+$row[0])
    $dest=Join-Path $base ($row[0]+'.lua');[IO.File]::WriteAllText($dest,[string]$node.script)
    & luac -p $dest; if($LASTEXITCODE -ne 0){throw ('Alias syntax '+$row[0])}
  }
  foreach($pair in @(@('Yso/Combat/route_registry.lua','Yso/xml/route_registry.lua'),
    @('Yso/Core/self_aff.lua','Yso/xml/yso_self_aff.lua'),
    @('Yso/Core/wake_bus.lua','Yso/xml/yso_pulse_wake_bus.lua'),
    @('Yso/Curing/serverside_policy.lua','Yso/xml/yso_serverside_policy.lua'))){
    Assert ((Normalize ([IO.File]::ReadAllText((Join-Path $root $pair[0])))) -ceq (Normalize ([IO.File]::ReadAllText((Join-Path $root $pair[1]))))) ('Runtime mirror drift '+$pair[0])
  }
  $second=$doc.SelectSingleNode('//Trigger[name="Enemy Deliverance stage 2"]')
  foreach($line in @('Foe bows his head in silent prayer.',"O'Foe bows their head in silent prayer.",'Some-Foe bows faen head in silent prayer.')){
    Assert ($line -cmatch $first.regexCodeList.string) ('Stage one missed: '+$line)
  }
  foreach($line in @('Foe slowly raises his head and you see his eyes glowing bright white.',
    'Foe slowly raises her  head and you see her eyes glowing bright white.')){
    Assert ($line -cmatch $second.regexCodeList.string) ('Stage two missed: '+$line)
  }
  Assert (-not ('Foe bows his head in silent prayer!' -cmatch $first.regexCodeList.string)) 'Stage one punctuation too broad'
  Assert (-not ('(Party): Foe bows his head in silent prayer.' -cmatch $first.regexCodeList.string)) 'Chat matched Deliverance'
  $alias=$doc.SelectSingleNode('//Alias[name="Deliverance safety"]')
  foreach($command in @('deliverance status','deliverance release')){Assert ($command -cmatch $alias.regex) 'Safety alias rejected'}
  Assert (-not ('deliverance release extra' -cmatch $alias.regex)) 'Safety alias accepted trailing commands'
  # Execute the actual packaged adapters, not just their source text.
  $harness='local seen={}; Yso={Combat={Deliverance={observe=function(n,s) seen[#seen+1]=n..":"..s end,command=function(c) seen[#seen+1]=c end}}}; matches={"","Foe"};'+"`n"+$first.script+"`n"+$second.script+"`n"+'matches={"","status"};'+"`n"+$alias.script+"`n"+'assert(table.concat(seen,",")=="Foe:channeling,Foe:active,status")'
  $adapter=Join-Path $base 'adapters.lua'; [IO.File]::WriteAllText($adapter,$harness)
  & lua $adapter; if($LASTEXITCODE -ne 0){throw 'Packaged Deliverance adapters failed'}
  $harness='Yso={}; matches={"","majorly","Air","Earth"};'+"`n"
  foreach($name in @('Mfocus resonance feedback','Mfocus resonance depleted','Mfocus resonance failure')){
    $harness+=[string]$doc.SelectSingleNode('//Trigger[name="'+$name+'"]').script+"`n"
  }
  [IO.File]::WriteAllText($adapter,$harness)
  & lua $adapter; if($LASTEXITCODE -ne 0){throw 'Resonance triggers fail without optional modules'}
  foreach($relative in @('Yso/Core/queue.lua','Yso/Core/api.lua','Yso/Combat/offense_core.lua','Yso/xml/route_registry.lua',
    'Yso/xml/yso_targeting.lua','Magi/magi_reference.lua','Magi/magi_route_core.lua')){
    $dest=Join-Path $base $relative; New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $dest
  }
  # Targeting is package-native too: exercise its actual target-set auto-resume path.
  $target=$doc.SelectSingleNode('//Script[name="Yso.targeting"]')
  [IO.File]::WriteAllText((Join-Path $base 'Yso/xml/yso_targeting.lua'),[string]$target.script)
  $registry=$doc.SelectSingleNode('//Script[name="Route registry"]')
  [IO.File]::WriteAllText((Join-Path $base 'Yso/xml/route_registry.lua'),[string]$registry.script)
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_deliverance.lua') (Join-Path $base 'Yso/Combat/deliverance.lua') ($base+'/')
  if($LASTEXITCODE -ne 0){throw 'Packaged Deliverance runtime failed'}
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_resonance_feedback.lua') (Join-Path $base 'Magi/resonance_feedback.lua')
  if($LASTEXITCODE -ne 0){throw 'Packaged resonance runtime failed'}
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_magi_group_routes.lua') ($base+'/')
  if($LASTEXITCODE -ne 0){throw 'Packaged group-route retirement failed'}
  $retiredAlias=$doc.SelectSingleNode('//Alias[name="mdam"]')
  $harness='local message=""; cecho=function(s) message=message..s end; Yso={emit=function() error("retired alias attacked") end};'+"`n"+$retiredAlias.script+"`n"+'assert(message:find("gwater",1,true) and message:find("fstorm",1,true))'
  [IO.File]::WriteAllText($adapter,$harness)
  & lua $adapter; if($LASTEXITCODE -ne 0){throw 'Retired alias did not explain replacement routes'}
  # Replay AK's actual six positive adapters and depletion adapter. AK alone
  # mutates measurements; the Yso route reader must see precisely those values.
  [xml]$akDoc=[IO.File]::ReadAllText((Join-Path $root 'mudlet packages/AK.xml'))
  $harness='local guarded=false; ak={ai=function() return guarded end,magi={resonance={Air=0,Earth=0,Fire=0,Water=0}},scoreup=function() end}; Yso={magi={}}; target="Foe";'+"`n"
  $harness+='dofile([['+(Join-Path $root 'Magi/magi_reference.lua')+']]); dofile([['+(Join-Path $root 'Magi/magi_route_core.lua')+']]); local R=Yso.off.magi.route_core;'+"`n"
  foreach($row in @(@('Minor 2',1,'Air','Earth'),@('Moderate 2',2,'Air','Earth'),@('Major 2',3,'Air','Earth'),
    @('Minor 1',1,'Fire',''),@('Moderate 1',2,'Fire',''),@('Major 1',3,'Fire',''),@('Resonance 0',0,'Fire',''))){
    $node=$akDoc.SelectSingleNode('//Trigger[name="'+$row[0]+'"]')
    Assert ($null -ne $node) ('AK adapter missing '+$row[0])
    $harness+='matches={"","'+$row[2]+'","'+$row[3]+'"};'+"`n"+[string]$node.script+"`n"
    $harness+='assert(R.read_resonance().'+$row[2].ToLower()+'=='+$row[1]+');'+"`n"
    if($row[3]){$harness+='assert(R.read_resonance().'+$row[3].ToLower()+'=='+$row[1]+');'+"`n"}
  }
  $node=$akDoc.SelectSingleNode('//Trigger[name="Major 1"]')
  $harness+='guarded=true; matches={"","Water"};'+"`n"+[string]$node.script+"`n"+'assert(R.read_resonance().water==0)'
  [IO.File]::WriteAllText($adapter,$harness)
  & lua $adapter; if($LASTEXITCODE -ne 0){throw 'Actual AK resonance replay failed'}
  Write-Host 'PASS: safety package parity, patterns, adapters, runtime, preservation and idempotence'
} finally {if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}}
