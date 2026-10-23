$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$ak = [xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/AK.xml'))
$pebble = $ak.SelectSingleNode('//Trigger[name="Pebble"]')
if (-not $pebble) { throw 'Confirmed Pebble hit has no tracking trigger' }
$earth = $ak.SelectSingleNode('//Trigger[name="Earth 1"]')
$h = [Collections.Generic.List[string]]::new()
$h.Add(@'
local ai = false
local gains, updates = 0, 0
target = 'Harkon'
ak = {ai=function() return ai end, defs={}, occie={aura={mental=0,physical=0}},
  AddedAffReset=function() gains=gains+1 end, scoreup=function() updates=updates+1 end,
  echogain=function() end, echolost=function() end}
affstrack = {score={},mentallist={},physicallist={},venoms={}}
table.contains=function(t,x) for _,v in pairs(t) do if v==x then return true end end return false end
string.title=function(s) return s end
raiseEvent=function() end
IsTargetted=function(n) return n==target end
local function reset()
  gains=0;updates=0;ai=false
  affstrack.score={leftarm=0,rightarm=0,leftleg=0,rightleg=0}
end
local function check(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
'@)
$h.Add($ak.SelectSingleNode('//Script[name="oscore edit functions"]').script)
$h.Add('local pebble=assert(load([====['+$pebble.script+']====]))')
$h.Add('local earth=assert(load([====['+$earth.script+']====]))')
function Add-Hit([string]$line,[string]$fn='pebble') {
  $node = if ($fn -eq 'earth') {$earth} else {$pebble}
  $m = [regex]::Match($line,[string]$node.regexCodeList.string)
  if (-not $m.Success) {throw "Confirmed hit did not match: $line"}
  $groups = foreach($g in $m.Groups) { '[====['+$g.Value+']====]' }
  $h.Add('matches={'+($groups -join ',')+'};'+$fn+'()')
}
foreach($fixture in @(@('left','arm','leftarm'),@('right','arm','rightarm'),@('left','leg','leftleg'),@('right','leg','rightleg'))) {
  $h.Add('reset()')
  Add-Hit ('You weave earth into a pebble and send it hurtling into the '+$fixture[0]+' '+$fixture[1]+' of Harkon with bone-breaking force.')
  $h.Add('check(affstrack.score.'+$fixture[2]+',100,"confirmed '+$fixture[2]+'");check(gains,1)')
}
$h.Add('reset()')
Add-Hit 'You weave earth into a pebble and send it hurtling into the right leg of Harkon with bone-breaking '
$h.Add('check(affstrack.score.rightleg,100,"wrapped prefix");check(gains,1)')
Add-Hit 'You weave earth into a pebble and send it hurtling into the right leg of Harkon with bone-breaking force.'
$h.Add('check(gains,1,"repeat confirmation");affstrack.score.rightleg=300')
Add-Hit 'You weave earth into a pebble and send it hurtling into the right leg of Harkon with bone-breaking force.'
$h.Add('check(affstrack.score.rightleg,300,"preserve higher break");check(gains,1)')
$h.Add('reset();affstrack.score.rightleg=50')
Add-Hit 'You weave earth into a pebble and send it hurtling into the right leg of Harkon with bone-breaking force.'
$h.Add('check(affstrack.score.rightleg,100,"confirm partial score");check(gains,1)')
$h.Add('reset()')
Add-Hit 'You weave earth into a pebble and send it hurtling into the right leg of Other with bone-breaking force.'
$h.Add('check(affstrack.score.rightleg,0,"other victim");check(gains,0);check(updates,0);ai=true')
Add-Hit 'You weave earth into a pebble and send it hurtling into the right leg of Harkon with bone-breaking force.'
$h.Add('check(affstrack.score.rightleg,0,"AI guard");check(gains,0);check(updates,0);reset()')
Add-Hit 'You weave earth into a pebble and send it hurtling into the right leg of Harkon with bone-breaking force.'
Add-Hit 'A loud crack emanates from the left arm of Harkon.' 'earth'
$h.Add('check(affstrack.score.rightleg,100);check(affstrack.score.leftarm,100,"independent earth proc");OppLostAff("rightleg");check(affstrack.score.rightleg,0,"existing cure path");check(affstrack.score.leftarm,100)')
foreach($bad in @('CAST PEBBLE AT Harkon','(Party): You weave earth into a pebble and send it hurtling into the right leg of Harkon with bone-breaking force.','force.')) {
  if ($bad -cmatch [string]$pebble.regexCodeList.string) {throw "False hit: $bad"}
}
$h.Add('print("PASS: Magi Pebble four limbs, wrapping, guards, score preservation, independent proc and cure")')
$tmp = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName()+'.lua')
try {
  [IO.File]::WriteAllText($tmp,($h -join "`n"),[Text.UTF8Encoding]::new($false))
  & lua $tmp
  if($LASTEXITCODE -ne 0) {throw 'Pebble tracking Lua checks failed'}
} finally {Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue}
