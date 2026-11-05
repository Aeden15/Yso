[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Legacy Basher V2.1.xml'))
$ErrorActionPreference='Stop'
$text=[IO.File]::ReadAllText($PackagePath)
$doc=[xml]$text
$body=$doc.SelectSingleNode('//Script[name="Basher"]/script').InnerText
$guard=@'
    -- Alchemist offense suspension also applies to raw Legacy hunting sends.
    local status = gmcp and gmcp.Char and gmcp.Char.Status or {}
    if tostring(status.class or ''):lower() == 'alchemist'
        and not (Yso and Yso.features and Yso.features.alchemist_offense == true) then
      if Legacy.Settings and Legacy.Settings.Basher then
        Legacy.Settings.Basher.status = false
        Legacy.Settings.Basher.queued = false
      end
      return false, 'alchemist_offense_suspended'
    end
'@
$releaseGuard=@'
    -- Release quarantine is independent of class, pause, and force settings.
    local controller = rawget(_G, 'YsoWorkspaceLink')
    if type(controller) == 'table' and (controller.busy == true or controller.restart_required == true) then
      if Legacy.Settings and Legacy.Settings.Basher then
        Legacy.Settings.Basher.status = false
        Legacy.Settings.Basher.queued = false
      end
      return false, controller.busy == true and 'workspace_reload' or 'restart_required'
    end
'@
foreach($signature in @('  function Legacy.Basher.queueAttackPackage(mode, cmd, requeue_basher, reason)','  function Legacy.Basher.Attack()')){
 $needle=$signature+"`n"
 if(-not $body.Contains($needle)){throw ('Missing expected Basher entrypoint '+$signature)}
 $body=$body.Replace($needle+$guard+"`n",$needle)
 if(-not $body.Contains($needle+$releaseGuard)){$body=$body.Replace($needle,$needle+$releaseGuard+"`n"+$guard+"`n")}
}
$rage='  function Legacy.Settings.Basher.Rage()'+"`n"
if(-not $body.Contains($rage)){throw 'Missing Basher Battlerage entrypoint'}
if(-not $body.Contains($rage+$releaseGuard)){$body=$body.Replace($rage,$rage+$releaseGuard+"`n")}
function SetBody([string]$tag,[string]$name,[string]$value){
 $pattern='(?s)<'+$tag+'\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</'+$tag+'>'
 $matches=[regex]::Matches($script:text,$pattern)
 if($matches.Count -ne 1){throw ('Expected unique '+$tag+' '+$name)}
 $hit=$matches[0]
 $escaped=[Security.SecurityElement]::Escape($value).Replace('&quot;','"').Replace('&apos;',"'")
 $new=[regex]::Replace($hit.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+$escaped+'</script>'},1)
 $script:text=$script:text.Substring(0,$hit.Index)+$new+$script:text.Substring($hit.Index+$hit.Length)
}
SetBody 'Script' 'Basher' $body
$toggle=$doc.SelectSingleNode('//Alias[name="Hunting Toggle"]/script').InnerText
$toggleGuard=$guard.TrimStart()
if(-not ($toggle.StartsWith('-- Alchemist offense suspension') -or $toggle.StartsWith('-- Release quarantine'))){$toggle=$toggleGuard+"`n"+$toggle}
if(-not $toggle.StartsWith('-- Release quarantine')){$toggle=$releaseGuard.TrimStart()+"`n"+$toggle}
SetBody 'Alias' 'Hunting Toggle' $toggle
$null=[xml]$text
if($PSCmdlet.ShouldProcess($PackagePath,'Suspend Alchemist offense in Legacy hunting')){[IO.File]::WriteAllText($PackagePath,$text,[Text.UTF8Encoding]::new($false))}
