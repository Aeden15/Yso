[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$doc=[xml][IO.File]::ReadAllText($PackagePath)
$entries=$doc.SelectNodes('//Trigger[name="Caravans"]')
if($entries.Count -ne 1){throw 'Expected exactly one Caravans trigger'}
$trigger=$entries[0]
if($trigger.isActive -ne 'yes' -or $trigger.isMultiline -ne 'no' -or $trigger.isPerlSlashGOption -ne 'no'){
  throw 'Caravans must be active, single-line OR matching, and non-global'
}
if($trigger.isSoundTrigger -ne 'yes' -or $trigger.mSoundFile -cne 'C:/Windows/Media/Alarm01.wav'){
  throw 'Caravans alarm changed'
}
$patterns=@($trigger.regexCodeList.string)
$properties=@($trigger.regexCodePropertyList.integer)
if($patterns.Count -ne 2 -or $properties.Count -ne 2){throw 'Caravans needs exactly two nonblank alternatives'}
for($i=0;$i -lt $patterns.Count;$i++){
  if([string]::IsNullOrWhiteSpace($patterns[$i]) -or $properties[$i] -ne '1'){
    throw 'Caravans alternatives must be nonblank Perl regexes (type 1)'
  }
}
# These expressions use the shared literal/anchor subset of PCRE and .NET regex.
# Army suffixes are representative fixtures: the captured contract is its prefix.
$fixtures=@(
  @{Line='(Army): A caravan bearing precious cargo has departed.'; Count=1},
  @{Line='(Army): A caravan bearing supplies approaches Quartz Peak.'; Count=1},
  @{Line='The industrious bustle of workers in Quartz Peak echoes across Sapience as they prepare a caravan.'; Count=1},
  @{Line='The industrious bustle of workers in Tir Murann echoes across Sapience as they prepare a caravan.'; Count=1},
  @{Line='The industrious bustle of workers in Mhaldor echoes across Sapience as they prepare a caravan.'; Count=1},
  @{Line="The industrious bustle of workers in Aalen's eastern foothills echoes across Sapience as they prepare a caravan."; Count=1},
  @{Line='The industrious bustle of workers in  echoes across Sapience as they prepare a caravan.'; Count=0},
  @{Line='Player says, "The industrious bustle of workers in Tir Murann echoes across Sapience as they prepare a caravan."'; Count=0},
  @{Line='The industrious bustle of workers in Tir Murann echoes across Sapience as they prepare a caravan!'; Count=0},
  @{Line='The industrious bustle of workers in Tir Murann echoes across Sapience as they prepare a caravan. More text.'; Count=0},
  @{Line=''; Count=0},
  @{Line='A caravan passes by.'; Count=0},
  @{Line='Army: A caravan bearing supplies approaches.'; Count=0},
  @{Line='(Army): Player says, "A caravan bearing supplies approaches."'; Count=0},
  @{Line='Player says, "(Army): A caravan bearing supplies approaches."'; Count=0},
  @{Line='[Party] (Army): A caravan bearing supplies approaches.'; Count=0},
  @{Line='Player says, "The industrious bustle of workers in Quartz Peak echoes across Sapience as they prepare a caravan."'; Count=0},
  @{Line='The industrious bustle of workers in Quartz Peak echoes across Sapience as they prepare a caravan!'; Count=0},
  @{Line='The industrious bustle of workers in Quartz Peak echoes across Sapience as they prepare a caravan. Player says hello.'; Count=0},
  @{Line='The industrious bustle of workers in Quartz Peak echoes across Sapience as they prepare a caravanX'; Count=0}
)
foreach($fixture in $fixtures){
  $count=@($patterns | Where-Object {[regex]::IsMatch($fixture.Line,$_)}).Count
  if($count -ne $fixture.Count){throw "Expected $($fixture.Count) matches, got $count for: $($fixture.Line)"}
}
# Execute the packaged action, verifying its notification text and call count.
$lua="local calls={}\ncecho=function(text) calls[#calls+1]=text end".Replace('\n',"`n")
$lua+="`n"+$trigger.script+"`nassert(#calls==1)`n"
$lua+='assert(calls[1]=="\n<DeepPink>[ARMY] <violet_red>CARAVANS!<reset>\n")'
$lua | & lua -
if($LASTEXITCODE -ne 0){throw 'Caravans notification behavior failed'}
Write-Output "PASS: Caravans $($fixtures.Count) line fixtures, single notification, activation, and alarm"

# Rebuild a deliberately stale copy. Comparing the bytes around the owned lists
# protects unrelated entries, fresh package additions, and this trigger's action.
$original=[IO.File]::ReadAllText($PackagePath)
$blockPattern='(?s)<Trigger\b[^>]*>\s*<name>Caravans</name>.*?</Trigger>'
$block=[regex]::Match($original,$blockPattern)
$stale=$block.Value.Replace('^\(Army\): A caravan bearing','(Army): A caravan bearing')
$stale=[regex]::Replace($stale,'(<regexCodePropertyList>\s*<integer>)1','${1}2')
$stale=$stale.Replace('</regexCodeList>',"<string />`n</regexCodeList>")
$inputText=$original.Substring(0,$block.Index)+$stale+$original.Substring($block.Index+$block.Length)
function ProtectedBytes([string]$text,[bool]$bom){
  $entry=[regex]::Match($text,$blockPattern)
  $protected=[regex]::Replace($entry.Value,'(?s)<regexCode(?:Property)?List>.*?</regexCode(?:Property)?List>','[owned pattern list]')
  $result=$text.Substring(0,$entry.Index)+$protected+$text.Substring($entry.Index+$entry.Length)
  $encoder=New-Object Text.UTF8Encoding($bom,$true)
  [Convert]::ToBase64String($encoder.GetPreamble()+$encoder.GetBytes($result))
}
$temporary=[IO.Path]::GetTempFileName()
try{
  foreach($bom in @($false,$true)){
    $encoding=New-Object Text.UTF8Encoding($bom,$true)
    [IO.File]::WriteAllText($temporary,$inputText,$encoding)
    $before=ProtectedBytes $inputText $bom
    & (Join-Path $PSScriptRoot 'build_caravans_trigger.ps1') -PackagePath $temporary | Out-Null
    $after=[IO.File]::ReadAllText($temporary)
    if((ProtectedBytes $after $bom) -cne $before){throw 'Builder changed bytes outside Caravans pattern lists'}
    $bytes=[IO.File]::ReadAllBytes($temporary)
    $actualBom=$bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
    if($actualBom -ne $bom){throw 'Builder changed UTF-8 BOM'}
    $rebuilt=[xml]$after
    $rebuiltTrigger=$rebuilt.SelectSingleNode('//Trigger[name="Caravans"]')
    if(@($rebuiltTrigger.regexCodeList.string).Count -ne 2){throw 'Builder retained blank pattern'}
    if(($rebuiltTrigger.regexCodeList.string -join '|') -cne ($patterns -join '|')){throw 'Builder did not synchronize patterns'}
    if(($rebuiltTrigger.regexCodePropertyList.integer -join ',') -ne '1,1'){throw 'Builder did not synchronize pattern types'}
    $hash=(Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash
    & (Join-Path $PSScriptRoot 'build_caravans_trigger.ps1') -PackagePath $temporary | Out-Null
    if((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -cne $hash){throw 'Caravans builder is not byte-idempotent'}
  }
}finally{Remove-Item -LiteralPath $temporary -Force}
Write-Output 'PASS: Caravans builder removes stale/blank patterns, preserves unrelated bytes/BOM, and is byte-idempotent'
