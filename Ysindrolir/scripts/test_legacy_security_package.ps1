[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Legacy V2.1.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function Assert($condition,[string]$message){if(-not $condition){throw $message}}
$before=[IO.File]::ReadAllText($PackagePath)
# Never echo matching lines: the old bodies contain live-looking credentials.
Assert (-not $before.Contains('discord.com/api/webhooks')) 'Embedded webhook credentials remain in Legacy'
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('yso-legacy-security-'+[guid]::NewGuid())
try {
 [IO.Directory]::CreateDirectory($scratch) | Out-Null
 $copy=Join-Path $scratch 'Legacy.xml';[IO.File]::WriteAllText($copy,$before)
 & (Join-Path $PSScriptRoot 'build_legacy_security_package.ps1') -PackagePath $copy -WhatIf
 Assert ($before -ceq [IO.File]::ReadAllText($copy)) 'Security WhatIf changed destination'
 & (Join-Path $PSScriptRoot 'build_legacy_security_package.ps1') -PackagePath $copy
 $after=[IO.File]::ReadAllText($copy)
 & (Join-Path $PSScriptRoot 'build_legacy_security_package.ps1') -PackagePath $copy
 Assert ($after -ceq [IO.File]::ReadAllText($copy)) 'Security builder is not idempotent'
 function Mask([string]$text){
  foreach($name in @('Legacy_Install','Feedback','Download Functions')){
   $text=[regex]::Replace($text,'(?s)<Script\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</Script>','')
  }
  foreach($name in @('Update new players','L Help')){
   $text=[regex]::Replace($text,'(?s)<Alias\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</Alias>','')
  }
  $text
 }
 Assert ((Mask $before) -ceq (Mask $after)) 'Security builder changed unrelated package entries'
 $doc=[xml]$after
 foreach($body in $doc.SelectNodes('//script')){
  Assert (-not $body.InnerText.Contains('postHTTP(')) 'Legacy posting remains'
  Assert (-not ($body.InnerText -match 'http:.*api\.achaea\.com')) 'Insecure NDB endpoint remains'
 }
 $install=$doc.SelectSingleNode('//Script[name="Legacy_Install"]/script').InnerText
 Assert (-not $install.Contains('installPackage(Legacy.Vinfo.link)')) 'Upstream metadata can bypass coordinated releases'
 foreach($entry in @(@('Script','Legacy_Install'),@('Alias','L Help'))){
  $native=Join-Path $scratch ($entry[1]+'.lua')
  [IO.File]::WriteAllText($native,$doc.SelectSingleNode('//'+$entry[0]+'[name="'+$entry[1]+'"]/script').InnerText)
  & luac -p $native;Assert ($LASTEXITCODE -eq 0) ('Portable Lua syntax: '+$entry[1])
 }
 $source=[IO.File]::ReadAllText((Join-Path $root 'Yso/Integration/legacy_network.lua')).Replace("`r`n","`n")
 $start=$install.IndexOf('-- BEGIN YSO LEGACY NETWORK SAFETY')
 $finish=$install.IndexOf('-- END YSO LEGACY NETWORK SAFETY',$start)
 Assert ($start -ge 0 -and $finish -gt $start) 'Missing embedded network safety source'
 $embedded=$install.Substring($start,$finish-$start+'-- END YSO LEGACY NETWORK SAFETY'.Length).Replace("`r`n","`n")
 Assert ($embedded.Trim() -ceq $source.Trim()) 'Network safety source/package drift'
 $network=Join-Path $scratch 'network.lua';[IO.File]::WriteAllText($network,$embedded)
 & luac -p $network;Assert ($LASTEXITCODE -eq 0) 'Network safety Lua syntax failed'
 $feedback=Join-Path $scratch 'feedback.lua';[IO.File]::WriteAllText($feedback,$doc.SelectSingleNode('//Script[name="Feedback"]/script').InnerText)
 $downloads=Join-Path $scratch 'downloads.lua';[IO.File]::WriteAllText($downloads,$doc.SelectSingleNode('//Script[name="Download Functions"]/script').InnerText)
 $help=Join-Path $scratch 'help.lua';[IO.File]::WriteAllText($help,$doc.SelectSingleNode('//Alias[name="L Help"]/script').InnerText)
 $helpCheck='local output={};cecho=function(s) output[#output+1]=s end;echo=function() end;dofile(arg[1]);local text=table.concat(output);assert(text:find("feedback <msg>",1,true),"help placeholder changed");assert(text:find("Discord posting is disabled",1,true),"feedback help still advertises remote posting")'
 $helpCheck | & lua - $help
 Assert ($LASTEXITCODE -eq 0) 'Feedback help compatibility text failed'
 & lua (Join-Path $root 'Yso/Tests and rebuilds/test_legacy_network.lua') $network $feedback $downloads
 Assert ($LASTEXITCODE -eq 0) 'Legacy network behavior failed'
 Write-Host 'PASS: credential/post removal, cache-only NDB, safe callers, source parity, preservation and idempotence'
} finally {
 $resolved=[IO.Path]::GetFullPath($scratch)
 if((Split-Path $resolved -Leaf) -notlike 'yso-legacy-security-*' -or (Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')){throw 'Unsafe scratch cleanup'}
 if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
