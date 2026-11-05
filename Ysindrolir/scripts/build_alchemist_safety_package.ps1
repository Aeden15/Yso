[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$text=[IO.File]::ReadAllText($PackagePath)
function Escape([string]$value){[Security.SecurityElement]::Escape($value)}
function Set-Body([string]$kind,[string]$name,[string]$body){
 $pattern='(?s)<'+$kind+'\b[^>]*>\s*<name>'+[regex]::Escape((Escape $name))+'</name>.*?</'+$kind+'>'
 $found=[regex]::Matches($script:text,$pattern)
 if($found.Count -ne 1){throw ('Expected one '+$kind+' '+$name+'; found '+$found.Count)}
 $entry=$found[0]
 $replacement=[regex]::Replace($entry.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+(Escape $body)+'</script>'},1)
 $script:text=$script:text.Substring(0,$entry.Index)+$replacement+$script:text.Substring($entry.Index+$entry.Length)
}
foreach($pair in @(
 @('Api stuff','Yso/xml/api_stuff.lua'),@('Yso modes','Yso/xml/yso_modes.lua'),
 @('Route registry','Yso/Combat/route_registry.lua'),@('Alchemist physiology','Alchemist/Core/physiology.lua'),
 @('Alchemist duel route','Alchemist/Core/duel route.lua'),@('Alchemist group damage','Alchemist/Core/group damage.lua'),
 @('Alchemist aurify route','Alchemist/Aurify route.lua'),@('formulation','Alchemist/Core/formulation.lua'),
 @('formulation_build','Alchemist/Core/formulation_build.lua'),@('formulation_phials','Alchemist/Core/formulation_phials.lua'))){
 Set-Body 'Script' $pair[0] ([IO.File]::ReadAllText((Join-Path $root $pair[1])).Replace("`r`n","`n"))
}
$guard=@'
-- Alchemist offense suspension: retained for future explicit reactivation.
if not (Yso and Yso.features and Yso.features.alchemist_offense == true) then
  if type(cecho) == 'function' then cecho('<orange>[Yso] Alchemist offense is temporarily suspended.<reset>\n') end
  return false, 'alchemist_offense_suspended'
end
'@
# Keep self-curing, buffs, crafting and homunculus utility aliases usable.
$offensive=@('adam','aduel','lead','lead (named)','Bash','Displacement','copper','silver','Silver (named)',
 'Phlogisticate','Vitrify','Aurify','Temper','Wrack','Truewrack','Inundation','Reave-Timed death',
 'Evaluate (name)','Evaluate humor','Homunculus attack','Homunculus shriek','Corruption',
 'cor','incen','devit','intox','vap','phos','mono','tox','conc',
 'tcor <arg>','tinc <arg>','tdev <arg>','tint <arg>','tvap <arg>','tphos <arg>','tmono <arg>','ttox <arg>','tconc <arg>')
$doc=[xml]$text
foreach($name in $offensive){
 $nodes=$doc.SelectNodes('//Alias[name="'+$name+'"]')
 if($nodes.Count -ne 1){throw ('Expected one Alchemist offensive alias '+$name)}
 $body=$nodes[0].SelectSingleNode('script').InnerText.Replace("`r`n","`n")
 if(-not $body.Contains('-- Alchemist offense suspension:')){Set-Body 'Alias' $name ($guard+"`n"+$body)}
}
$aliasRelease=@'
-- Release quarantine for class aliases; ordinary typed game commands are untouched.
local controller = rawget(_G, 'YsoWorkspaceLink')
if type(controller) == 'table' and (controller.busy == true or controller.restart_required == true) then
  return false, controller.busy == true and 'workspace_reload' or 'restart_required'
end
'@
$doc=[xml]$text
foreach($node in $doc.SelectNodes('//Alias')){
 $ancestor=$node.ParentNode;$isAlchemy=$false
 while($ancestor){
  $nameNode=$ancestor.SelectSingleNode('name')
  if($nameNode -and $nameNode.InnerText -ceq 'Alchemy'){$isAlchemy=$true;break}
  $ancestor=$ancestor.ParentNode
 }
 if(-not $isAlchemy){continue}
 $body=$node.SelectSingleNode('script').InnerText.Replace("`r`n","`n")
 if(-not $body.StartsWith('-- Release quarantine for class aliases;')){
  Set-Body 'Alias' $node.SelectSingleNode('name').InnerText ($aliasRelease+"`n"+$body)
 }
}
$null=[xml]$text
if($PSCmdlet.ShouldProcess($PackagePath,'Embed Alchemist suspension and safe diagnostics')){
 [IO.File]::WriteAllText($PackagePath,$text,[Text.UTF8Encoding]::new($false))
}
