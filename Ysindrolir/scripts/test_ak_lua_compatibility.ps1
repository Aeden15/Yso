$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$doc=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/AK.xml'))
foreach($name in @('Transcendence','Transcendance fading')){
  $body=$doc.SelectSingleNode("//Trigger[name='$name']/script").InnerText
  $harness='matches={"full","20"};deleteLine=function() end;ak={psion={}};local message;cecho=function(s) message=s end;'+"`n"+$body+"`n"+'assert(ak.psion.transcend==20 and message:find("20% Transcendance",1,true),"legacy string behavior changed")'
  $harness | & lua -
  if($LASTEXITCODE -ne 0){throw ('Legacy escape compatibility failed: '+$name)}
  # Lua 5.1 discarded the unrecognized backslash; the pattern must remain a literal percent.
  if($body.Contains('\%')){throw 'Unknown string escape remains'}
}
Write-Output 'PASS AK legacy strings compile with equivalent Lua 5.1 pattern values'
