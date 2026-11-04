[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$text=[IO.File]::ReadAllText($PackagePath)
function Entry([string]$name){
 $hits=[regex]::Matches($text,'(?s)<Script\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</Script>')
 if($hits.Count -ne 1){throw ('Expected one script '+$name+'; got '+$hits.Count)}
 $hits[0]
}
# Retain the old entry's position while retiring its combined implementation.
if($text.Contains('<name>Airlord attack logic</name>')){
 if($text.Contains('<name>Airlord lock route</name>')){throw 'Both old and new Airlord lock entries exist'}
 $text=$text.Replace('<name>Airlord attack logic</name>','<name>Airlord lock route</name>')
}
foreach($entry in @(@('Airlord route runtime','Airlord lock route','before'),@('Airlord damage route','Airlord lock route','after'))){
 if(-not $text.Contains('<name>'+$entry[0]+'</name>')){
  $anchor=Entry $entry[1]
  $index=if($entry[2] -eq 'before'){$anchor.Index}else{$anchor.Index+$anchor.Length}
  $text=$text.Insert($index,'<Script isActive="yes" isFolder="no"><name>'+$entry[0]+'</name><packageName /><script></script><eventHandlerList /></Script>')
 }
}
foreach($row in @(@('Compression logic','compression.lua'),@('Airlord route runtime','route_runtime.lua'),@('Airlord lock route','lock_route.lua'),@('Airlord damage route','damage_route.lua'))){
 $entry=Entry $row[0]
 $body=[IO.File]::ReadAllText((Join-Path $root ('Airlord/'+$row[1])))
 $block=[regex]::Replace($entry.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+[Security.SecurityElement]::Escape($body)+'</script>'},1)
 $text=$text.Substring(0,$entry.Index)+$block+$text.Substring($entry.Index+$entry.Length)
}
# Updraft is now an option of the separate damage route.
$text=$text.Replace('Yso.off.airlord.lock.toggle_updraft()','Yso.off.airlord.damage.toggle_updraft()')
[xml]$validated=$text
[IO.File]::WriteAllText($PackagePath,$text,(New-Object Text.UTF8Encoding $false))
Write-Host 'Synchronized separate Airlord lock/damage routes and shared runtime.'
