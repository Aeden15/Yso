[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Legacy Basher V2.1.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$text=[IO.File]::ReadAllText($PackagePath)
$doc=[xml]$text
function Escape([string]$value){[Security.SecurityElement]::Escape($value)}
function Entry([string]$tag,[string]$name){
 $pattern='(?s)<'+$tag+'\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</'+$tag+'>'
 $hits=[regex]::Matches($script:text,$pattern)
 if($hits.Count -ne 1){throw ('Expected unique '+$tag+' '+$name)}
 return $hits[0]
}
function SetBody([string]$tag,[string]$name,[string]$body){
 $hit=Entry $tag $name
 # Quotes need no escaping inside element text; retain the original Legacy style.
 $escaped=(Escape $body).Replace('&quot;','"').Replace('&apos;',"'")
 $new=[regex]::Replace($hit.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+$escaped+'</script>'},1)
 $script:text=$script:text.Substring(0,$hit.Index)+$new+$script:text.Substring($hit.Index+$hit.Length)
}
$toggle=$doc.SelectSingleNode('//Alias[name="Hunting Toggle"]').script
if(-not $toggle.Contains('-- Apostate Soulstorm toggle adapter')){
 $needle='Legacy.Settings.Basher.totalDamage = {}'
 if(-not $toggle.Contains($needle)){throw 'Missing hunting toggle insertion point'}
 $toggle=$toggle.Replace($needle,$needle+"`n"+@'
-- Apostate Soulstorm toggle adapter: arm before status events can invoke Attack.
local soulstorm=Legacy.Basher.Soulstorm
if soulstorm then
  if Legacy.Settings.Basher.status == false then soulstorm.begin() else soulstorm.stop() end
end
'@)
 SetBody Alias 'Hunting Toggle' $toggle
}
$basher=$doc.SelectSingleNode('//Script[name="Basher"]').script
if(-not $basher.Contains('-- Apostate Soulstorm attack adapter')){
 $needle='      local isDenizenTarget = _attack_is_denizen_target(targetSet)'
 if(-not $basher.Contains($needle)){throw 'Missing basher attack insertion point'}
 $basher=$basher.Replace($needle,$needle+"`n"+@'
      -- Apostate Soulstorm attack adapter: precedes rage and ordinary basher queues.
      local soulstorm=Legacy.Basher.Soulstorm
      if soulstorm and soulstorm.before_attack(targetSet,targetInfo,isDenizenTarget) then return end
'@)
 $needle='    Legacy.Settings.Basher.status = false'
 if(-not $basher.Contains($needle)){throw 'Missing basher setup insertion point'}
 $basher=$basher.Replace($needle,$needle+"`n"+'    if Legacy.Basher.Soulstorm then Legacy.Basher.Soulstorm.stop() end')
 SetBody Script 'Basher' $basher
}
$body=[IO.File]::ReadAllText((Join-Path $root 'Apostate/hunting_soulstorm.lua'))
if($text.Contains('<name>Apostate hunting Soulstorm</name>')){SetBody Script 'Apostate hunting Soulstorm' $body}
else{
 $anchor=Entry Script 'Basher'
 $escaped=(Escape $body).Replace('&quot;','"').Replace('&apos;',"'")
 $block='<Script isActive="yes" isFolder="no"><name>Apostate hunting Soulstorm</name><packageName /><script>'+$escaped+'</script><eventHandlerList /></Script>'
 $text=$text.Insert($anchor.Index,$block+"`n")
}
$triggers=@(
 @('confirmed','^You call forth an unholy tide of necromantic essence and release it, engulfing (.+) in a profane soulstorm\.$'),
 @('already active',"^Necromantic essence still profanes (.+)'s soul\.$"),
 @('faded','^([A-Za-z][^:\r\n]*) steadies as the profane aura around (?:it|him|her|them) fades\.$')
)
foreach($row in $triggers){
 $name='Apostate Soulstorm '+$row[0]
 $script='local H=Legacy and Legacy.Basher and Legacy.Basher.Soulstorm; if H then H.note("'+$row[0]+'",matches[2]) end'
 $block='<Trigger isActive="yes" isFolder="no" isTempTrigger="no" isMultiline="no" isPerlSlashGOption="no" isColorizerTrigger="no" isFilterTrigger="no" isSoundTrigger="no" isColorTrigger="no" isColorTriggerFg="no" isColorTriggerBg="no"><name>'+$name+'</name><script>'+(Escape $script)+'</script><triggerType>0</triggerType><conditonLineDelta>0</conditonLineDelta><mStayOpen>0</mStayOpen><mCommand /><packageName /><mFgColor>#ff0000</mFgColor><mBgColor>#ffff00</mBgColor><mSoundFile /><colorTriggerFgColor>#000000</colorTriggerFgColor><colorTriggerBgColor>#000000</colorTriggerBgColor><regexCodeList><string>'+(Escape $row[1])+'</string></regexCodeList><regexCodePropertyList><integer>1</integer></regexCodePropertyList></Trigger>'
 if($text.Contains('<name>'+$name+'</name>')){
  $hit=Entry Trigger $name;$text=$text.Substring(0,$hit.Index)+$block+$text.Substring($hit.Index+$hit.Length)
 }else{
  $anchor=Entry Trigger 'Mob Slain';$text=$text.Insert($anchor.Index,$block+"`n")
 }
}
[void][xml]$text
if($PSCmdlet.ShouldProcess($PackagePath,'Embed Apostate Soulstorm startup and confirmation adapters')){
 [IO.File]::WriteAllText($PackagePath,$text,[Text.UTF8Encoding]::new($false))
}
