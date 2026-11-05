[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$doc=[xml][IO.File]::ReadAllText($PackagePath)
function Body([string]$kind,[string]$name){
  $nodes=$doc.SelectNodes('//'+$kind+'[name="'+$name+'"]')
  if($nodes.Count -ne 1){throw ('Expected one '+$kind+' '+$name)}
  $nodes[0].SelectSingleNode('script').InnerText
}
$code=@'
local sent,messages={},{}
send=function(command) sent[#sent+1]=command end
cecho=function(message) messages[#messages+1]=message end
local elementals={}
'@
foreach($row in @(@('Waterweird','waterweird'),@('Mistfiend','mistfiend'),@('Stoneback','stoneback'))){
  $code+="`n"+'elementals[#elementals+1]={name="'+$row[0]+'",id="'+$row[1]+'",present=assert(load([====['+(Body 'Trigger' ($row[0]+' present'))+']====])),absent=assert(load([====['+(Body 'Trigger' ($row[0]+' not present'))+']====]))}'
}
foreach($row in @(@('djinn_present','Trigger','Djinn present'),@('djinn_absent','Trigger','Djinn not present'),@('ready','Trigger','Levitate ready'),@('cooldown','Trigger','Levitate cooldown'),@('levitate','Alias','Levitate'))){
  $code+="`n"+'local '+$row[0]+'=assert(load([====['+(Body $row[1] $row[2])+']====]))'
}
$code+="`n"+@'
for _,elemental in ipairs(elementals) do
  for _,seed in ipairs({true,false,'unset'}) do
    local initial=seed;if seed=='unset' then initial=nil end
    Yso={elemental='djinn',elemental_lev_ready=initial}
    elemental.present()
    assert(Yso.elemental==elemental.id,'presence tracking changed for '..elemental.name)
    assert(Yso.elemental_lev_ready==initial,elemental.name..' presence changed djinn levitation readiness')
    assert(messages[#messages]:find(elemental.name..' summoned!',1,true),'summon feedback changed')
    elemental.absent()
    assert(Yso.elemental==false,'departure tracking changed for '..elemental.name)
    assert(Yso.elemental_lev_ready==initial,elemental.name..' departure changed djinn levitation readiness')
    assert(messages[#messages]:find(elemental.name..' faded!',1,true),'departure feedback changed')
  end
end
Yso={elemental=false,elemental_lev_ready=false}
djinn_present();assert(Yso.elemental=='djinn' and Yso.elemental_lev_ready==true)
levitate();assert(#sent==1 and sent[1]=='queue prepend eqbal elemental levitate')
cooldown();assert(Yso.elemental_lev_ready==false);levitate();assert(#sent==1)
ready();assert(Yso.elemental_lev_ready==true);levitate();assert(#sent==2)
djinn_absent();assert(Yso.elemental==false and Yso.elemental_lev_ready==false)
levitate();assert(#sent==2,'absent djinn cast levitate')
for _,other in ipairs({'waterweird','mistfiend','stoneback','other_elemental',false}) do
  Yso={elemental=other,elemental_lev_ready=true}
  levitate();assert(#sent==2,'non-djinn cast levitate using stale readiness')
end
print('PASS djinn-only levitation lifecycle, unaffected other elementals, and stale-readiness alias gate')
'@
$code | & lua -
if($LASTEXITCODE -ne 0){throw 'Packaged Magi elemental levitation behavior failed'}
$keepers=@('Djinn present','Djinn not present','Levitate ready','Levitate cooldown')
foreach($node in $doc.SelectNodes('//Trigger[script]')){
  if($node.SelectSingleNode('script').InnerText.Contains('elemental_lev_ready') -and $node.SelectSingleNode('name').InnerText -notin $keepers){
    throw ('Non-djinn trigger retains levitation state: '+$node.SelectSingleNode('name').InnerText)
  }
}
