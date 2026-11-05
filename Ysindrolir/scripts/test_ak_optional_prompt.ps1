$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$doc=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/AK.xml'))
$body=$doc.SelectSingleNode('//Script[name="oprompt Wys Script"]/script').InnerText
$lua=@'
local run=assert(load([======[
'@
$lua+=$body
$lua+=@'

]======]))
wsys=nil;run()
wsys={};run()
wsys={prompttags={}};ak={prompt={default='prompt'}}
run()
assert(type(wsys.prompttags.owysprompt)=='function')
target=nil;assert(wsys.prompttags.owysprompt()=='')
target='Example';promptset={'ready'}
assert(wsys.prompttags.owysprompt()=='prompt[ready<yellow>]')
print('PASS: optional Wsys prompt is safe without addon and registers correctly with addon')
'@
$lua | & lua -
if($LASTEXITCODE -ne 0){throw 'Optional AK prompt regression failed'}
