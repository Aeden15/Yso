param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference = 'Stop'
[xml]$doc = [IO.File]::ReadAllText($PackagePath)
if ($doc.SelectSingleNode('//Trigger[name="Bloodboil: EQ recovered"]')) { throw 'Obsolete Bloodboil EQ trigger remains' }
if ($doc.SelectSingleNode('//Script[name="Bloodboil auto"]')) { throw 'Obsolete Bloodboil automation remains' }
function Body([string]$kind, [string]$name) {
  $nodes = $doc.SelectNodes('//' + $kind + '[name="' + $name + '"]')
  if ($nodes.Count -ne 1) { throw "Expected one $kind $name" }
  [string]$nodes[0].script
}
$alias = Body 'Alias' 'boil'
$ready = Body 'Trigger' 'Bloodboil ready'
$cast = Body 'Trigger' 'Bloodboil cast'
$castPatterns = @($doc.SelectSingleNode('//Trigger[name="Bloodboil cast"]').regexCodeList.string)
foreach ($line in @('You summon spirits of fire to burn off that which afflicts you.','You have not recovered enough to boil your blood again as of yet.')) {
  if (-not @($castPatterns | Where-Object { $line -cmatch $_ }).Count) { throw "Manual cooldown trigger misses: $line" }
}
foreach ($body in @($alias,$ready,$cast)) {
  if ($body -match 'route_core|bloodboil_note_|with_bloodboil') { throw 'Manual Bloodboil still calls the old route automation' }
}
if ($doc.SelectSingleNode('//Alias[name="boil"]/regex').InnerText -cne '^boi$') { throw 'Manual boi alias was changed' }
$harness = @'
local sent, messages = {}, {}
function send(s) sent[#sent+1]=s end
function cecho(s) messages[#messages+1]=s end
yso={}; Yso=yso
local function obsolete() error('Old Bloodboil callback executed') end
Yso.off={magi={route_core={bloodboil_note_cast=obsolete,bloodboil_note_ready=obsolete}}}
'@
$harness += "`nassert(load([====[`n" + (Body 'Script' 'Miscellaneous scripts') + "`n]====]))()`n"
$harness += "local alias=assert(load([====[`n" + $alias + "`n]====]))`n"
$harness += "local ready=assert(load([====[`n" + $ready + "`n]====]))`n"
$harness += "local cast=assert(load([====[`n" + $cast + "`n]====]))`n"
$harness += @'
ready(); assert(yso.magi.bloodboil==true,'ready flag not set')
assert(messages[#messages]:find('BLOODBOIL READY!',1,true),'ready feedback missing')
alias(); assert(#sent==1 and sent[1]=='cq all&&cast bloodboil','manual cast changed')
cast(); assert(yso.magi.bloodboil==false,'cast/cooldown flag not cleared')
assert(messages[#messages]:find('BLOODBOIL ON CD!',1,true),'cooldown feedback missing')
alias(); assert(#sent==1,'cooldown alias sent a cast')
assert(messages[#messages]:find('BLOODBOIL NOT READY!',1,true),'not-ready feedback missing')
ready(); alias(); assert(#sent==2,'ready alias did not recover')
print('PASS: manual boi alias, ready/cooldown feedback, and no old Bloodboil callbacks')
'@
$harness | & lua -
if ($LASTEXITCODE -ne 0) { throw 'Manual Bloodboil behavior failed' }
