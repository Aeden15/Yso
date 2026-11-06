# Exercise the actual AK cold ladder and bond confirmations against native gwater.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
[xml]$akXml=[IO.File]::ReadAllText((Join-Path $root 'mudlet packages/AK.xml'))
[xml]$ysoXml=[IO.File]::ReadAllText((Join-Path $root 'mudlet packages/Yso system.xml'))
$gain=$akXml.SelectSingleNode('//Trigger[name="Horripilation Bond"]')
$fade=$akXml.SelectSingleNode('//Trigger[name="Waterbond Faded"]')
$h=[Collections.Generic.List[string]]::new()
$h.Add('local root=[====['+$root.Replace('\','/')+'/]====]')
$h.Add(@'
local ai=false
target='Foe'
function getEpoch() return 10000 end
function cecho() end
function raiseEvent() end
function IsTargetted(name) return name==target end
table.contains=function(t,x) for _,v in pairs(t) do if v==x then return true end end return false end
string.title=function(s) return s end
Yso={off={magi={}},get_target=function() return target end,is_magi=function() return true end,
 state={eq_ready=function() return true end},
 mode={is_combat=function() return true end,route_loop_active=function() return true end}}
ak={ai=function() return ai end,healthpercent=100,defs={},magi={resonance={Water=2,Air=2,Earth=1,Fire=1}},
 occie={aura={mental=0,physical=0}},scoreup=function() end,AddedAffReset=function() end,
 echogain=function() end,echolost=function() end}
affstrack={score={frozen=0,waterbonds=0,scalded=100,hypothermia=0,nausea=0,weariness=0,slickness=0},
 mentallist={},physicallist={},venoms={}}
dofile(root..'Magi/magi_route_core.lua')
'@)
$h.Add([string]$akXml.SelectSingleNode('//Script[name="oscore edit functions"]').script)
$h.Add('local W=assert(load([====['+$ysoXml.SelectSingleNode('//Script[name="Magi water group"]/script').InnerText+']====]))()')
$h.Add('local gained=assert(load([====['+[string]$gain.script+']====]))')
$h.Add('local faded=assert(load([====['+[string]$fade.script+']====]))')
$h.Add(@'
W.state.enabled,W.state.loop_enabled=true,true
local function want(command)
 local p,reason=W.attack_function({preview=true})
 assert(type(p)=='table' and p.lanes.eq==command,'expected '..command..', got '..tostring(type(p)=='table' and p.lanes.eq or reason))
end
want('cast freeze at Foe')
OppGainedAff('insulationstrip')
assert(affstrack.score.frozen==100);want('cast freeze at Foe')
OppGainedAff('frozen')
assert(affstrack.score.frozen==200);want('staff cast horripilation at Foe')
OppGainedAff('frozen')
assert(affstrack.score.frozen==300);want('staff cast horripilation at Foe')
OppGainedAff('frozen');assert(affstrack.score.frozen==300)
'@)
function AddResponse($node,[string]$line,[string]$call){
  $match=[regex]::Match($line,[string]$node.regexCodeList.string)
  if(-not $match.Success){throw ('Existing AK response did not match: '+$line)}
  $groups=@($match.Groups | ForEach-Object {'[====['+$_.Value+']====]'})
  $h.Add('matches={'+($groups -join ',')+'};'+$call+'()')
}
AddResponse $gain 'Even as the wave of cold dissipates, you retain control over the fluid and send it spinning through the air to bind Foe in a watery web.' 'gained'
$h.Add('assert(affstrack.score.waterbonds==100);want("cast mudslide at Foe")')
AddResponse $fade 'The tendrils of water that bound Foe splash to the ground as the power sustaining them fades.' 'faded'
$h.Add('assert(affstrack.score.waterbonds==0);want("staff cast horripilation at Foe")')
AddResponse $gain 'Even as the wave of cold dissipates, you retain control over the fluid and send it spinning through the air to bind Other in a watery web.' 'gained'
$h.Add('assert(affstrack.score.waterbonds==0);ai=true')
AddResponse $gain 'Even as the wave of cold dissipates, you retain control over the fluid and send it spinning through the air to bind Foe in a watery web.' 'gained'
$h.Add('assert(affstrack.score.waterbonds==0);ai=false;OppLostAff("frozen");assert(affstrack.score.frozen==0);want("cast freeze at Foe")')
$h.Add('print("PASS: actual AK 0/100/200/300 cold stages, Waterbonds gain/fade, target/AI guards and native Horripilation rule")')
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('magi-water-cold-'+[guid]::NewGuid()+'.lua')
try{
 [IO.File]::WriteAllText($tmp,($h -join "`n"),[Text.UTF8Encoding]::new($false))
 & lua $tmp
 if($LASTEXITCODE -ne 0){throw 'AK cold-state/Waterbonds route integration failed'}
}finally{Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue}
