[CmdletBinding()]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$doc=[xml][IO.File]::ReadAllText($PackagePath)
$alias=$doc.SelectSingleNode('//Alias[name="Horrify(fear denizen)"]')
if(-not $alias -or $alias.isActive -ne 'yes'){throw 'Missing active Horrify alias'}
if($alias.regex -cne '^hor$'){throw 'Horrify must use ^hor$'}
$lua=@'
local sent,echoes={},{}
send=function(s) sent[#sent+1]=s end
cecho=function(s) echoes[#echoes+1]=s end
local function eq(actual,expected,label)
 assert(actual==expected,(label or '')..': '..tostring(actual)..' ~= '..tostring(expected))
end
local function reset(class,rage)
 sent={};echoes={};target='214001'
 gmcp={Char={Status={class=class},Vitals={charstats={'Bleed: 0','Rage: '..rage,'Essence: 83%'}}}}
end
'@
$lua+="`nlocal horrify=assert(load([====[return function()`n"+$alias.script+"`nend]====]))()`n"
$lua+=@'
reset('Apostate',0);horrify();eq(#sent,0,'zero rage')
reset('Apostate',28);horrify();eq(#sent,0,'below threshold')
reset('Apostate',29);horrify();eq(sent[1],'stare 214001 horrify','exact threshold');eq(#sent,1)
reset('APOSTATE',35);horrify();eq(sent[1],'stare 214001 horrify','case insensitive class')
reset('Monk',100);horrify();eq(#sent,0,'class guard')
reset(nil,100);horrify();eq(#sent,0,'unknown class')
gmcp=nil;sent={};horrify();eq(#sent,0,'missing GMCP')
reset('Apostate',100);gmcp.Char.Vitals=nil;horrify();eq(#sent,0,'missing vitals')
reset('Apostate',100);gmcp.Char.Vitals.charstats={'Bleed: 0','Essence: 83%'};horrify();eq(#sent,0,'missing rage')
reset('Apostate',100);target=nil;horrify();eq(#sent,0,'no target')
reset('Apostate',100);target='   ';horrify();eq(#sent,0,'blank target')
reset('Apostate',100);target=' 214001 ';horrify();eq(sent[1],'stare 214001 horrify','trimmed target')
reset('Apostate',29);target='StalePlayer';gmcp.IRE={Target={Set='214002'}}
horrify();eq(sent[1],'stare 214002 horrify','server hunting target overrides stale player target')
reset('Apostate',29);gmcp.IRE={Target={Set=''}}
horrify();eq(sent[1],'stare 214001 horrify','empty GMCP target falls back')
reset('Apostate',29);gmcp.IRE={Target={Set=214003}}
horrify();eq(sent[1],'stare 214003 horrify','numeric GMCP target')
print('PASS: Horrify packaged alias class/rage guards, threshold, target selection, and command')
'@
$lua | & lua -
if($LASTEXITCODE -ne 0){throw 'Horrify Lua behavior checks failed'}
Write-Output 'PASS: Horrify alias XML, activation, and exact pattern'
