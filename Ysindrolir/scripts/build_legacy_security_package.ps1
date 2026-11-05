[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Legacy V2.1.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$text=[IO.File]::ReadAllText($PackagePath)
function Set-Body([string]$inputText,[string]$tag,[string]$name,[scriptblock]$transform){
 $pattern='(?s)<'+$tag+'\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</'+$tag+'>'
 $found=[regex]::Matches($inputText,$pattern)
 if($found.Count -ne 1){throw "Expected one $tag $name; found $($found.Count)"}
 $entry=$found[0];$node=[xml]$entry.Value
 $body=& $transform $node.DocumentElement.SelectSingleNode('script').InnerText
 $block=[regex]::Replace($entry.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+[Security.SecurityElement]::Escape($body)+'</script>'},1)
 $inputText.Substring(0,$entry.Index)+$block+$inputText.Substring($entry.Index+$entry.Length)
}
function Replace-Section([string]$body,[string]$start,[string]$end,[string]$replacement){
 $first=$body.IndexOf($start);$last=if($first -ge 0){$body.IndexOf($end,$first)}else{-1}
 if($first -lt 0 -or $last -le $first){throw ('Legacy security section anchor missing: '+$start+' / '+$end)}
 $body.Substring(0,$first)+$replacement+"`n"+$body.Substring($last)
}
$network=[IO.File]::ReadAllText((Join-Path $root 'Yso/Integration/legacy_network.lua')).TrimEnd()
$text=Set-Body $text 'Script' 'Legacy_Install' {
 param($body)
 # Remove the complete old function, including both embedded destinations.
 if($body.Contains('  function Legacy.Ideas(msg)')){
  $body=Replace-Section $body '  function Legacy.Ideas(msg)' '  Legacy.panic = function(msg)' "  -- Ideas is provided by the local-only network safety block below."
 }
 if($body.Contains('-- BEGIN YSO LEGACY NETWORK SAFETY')){
  $body=Replace-Section $body '-- BEGIN YSO LEGACY NETWORK SAFETY' 'function Legacy.Settings.NDB.formatting(name)' ($network+"`n")
 }else{
  $body=Replace-Section $body '  function Legacy.NDB.read_json_file(path)' 'function Legacy.Settings.NDB.formatting(name)' ($network+"`n")
 }
 # An old in-flight metadata download must not offer an upstream install link.
 $versionStart='  if filename:find("Legacy_Version_Info.lua", 1, true) then'
 $versionEnd='  if filename:find("Legacy_Extras.lua", 1, true) then'
 if($body.Contains($versionStart)){
  $body=Replace-Section $body $versionStart $versionEnd "  -- Managed releases own Legacy versions; downloaded upstream metadata is ignored.`n"
 }
 # Lua 5.1 silently drops these unsupported escapes; express the same text
 # literally so native scripts also compile in the supported Lua 5.4 verifier.
 $body=[regex]::Replace($body,'(?<!\\)\\([()])','$1')
 # Normalize only re-embedded code-line whitespace; preserve long-string data.
 $body=[regex]::Replace($body,'(?m)(^\s*\["north"\]\s*=\s*"n",)[ \t]+$','$1')
 $body=[regex]::Replace($body,'(?m)(^[^\r\n]*--capture the number from the aff word)[ \t]+$','$1')
 $body=[regex]::Replace($body,'(?m)(^\s*"(?:Poisonresist|Xporb)",)[ \t]+$','$1')
 [regex]::Replace($body,'(?m)(^registerAnonymousEventHandler\("sysDownloadDone", "downloaded_file"\))[ \t]+$','$1')
}
$text=Set-Body $text 'Script' 'Feedback' {
@'
function Feedback(message)
  if Legacy and Legacy.Network and type(Legacy.Network.local_feedback)=='function' then
    return Legacy.Network.local_feedback('Feedback', message)
  end
  if type(cecho)=='function' then cecho('\n[Legacy] Feedback posting is disabled. Reports stay local.\n') end
  return false, 'posting_disabled'
end
'@
}
$text=Set-Body $text 'Script' 'Download Functions' {
@'
-- Coordinated Yso releases own managed package versions; no upstream downloads.
function Legacy_Downloads()
  Legacy=Legacy or {}
  Legacy.Vinfo={Version='',msg='',link=''}
  Legacy.Extras=Legacy.Extras or {}
  Legacy.managed_updates=true
  return false, 'managed_release'
end
registerAnonymousEventHandler('CheckForUpdates', 'Legacy_Downloads')
registerAnonymousEventHandler('LegacyLoaded', 'Legacy_Downloads')
function Download(kind)
  downloadmsg=nil
  if Legacy and Legacy.Network and type(Legacy.Network.local_feedback)=='function' then
    return Legacy.Network.local_feedback('Installation reporting')
  end
  return false, 'posting_disabled'
end
'@
}
$text=Set-Body $text 'Alias' 'Update new players' {
@'
if Legacy and Legacy.NDB and type(Legacy.NDB.refresh_cache)=='function' then
  Legacy.NDB.refresh_cache()
elseif type(cecho)=='function' then
  cecho('\n[Legacy] NDB cache services are unavailable; run ysocheck.\n')
end
'@
}
$text=Set-Body $text 'Alias' 'L Help' {
 param($body)
 $body=[regex]::Replace($body,'(?<!\\)\\([<>])','$1')
 $body=$body.Replace('Provide feedback to the Legacy team','Feedback stays local; Discord posting is disabled')
 $body.Replace('Update NDB with current people','Load cached NDB records (network refresh disabled)')
}
$null=[xml]$text
if($text.Contains('discord.com/api/webhooks') -or $text.Contains('postHTTP(')){throw 'Legacy still contains external posting code'}
if($text -match 'http:.*api\.achaea\.com'){throw 'Legacy still contains insecure character endpoints'}
if($PSCmdlet.ShouldProcess($PackagePath,'Remove embedded credentials and use cache-only Legacy networking')){
 [IO.File]::WriteAllText($PackagePath,$text,[Text.UTF8Encoding]::new($false))
}
