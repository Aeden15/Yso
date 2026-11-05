[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$before=[IO.File]::ReadAllText($PackagePath)
$body=[IO.File]::ReadAllText((Join-Path $root 'Yso/Integration/system_health.lua')).Replace("`r`n","`n")
$escaped=[Security.SecurityElement]::Escape($body)
$script='<Script isActive="yes" isFolder="no"><name>Yso unified health</name><packageName /><script>'+$escaped+'</script><eventHandlerList /></Script>'
$alias='<Alias isActive="yes" isFolder="no"><name>Yso unified health</name><script>Yso.system.check()</script><command /><packageName /><regex>^ysocheck$</regex></Alias>'
$text=$before
foreach($entry in @(@('Script',$script,'ScriptPackage'),@('Alias',$alias,'AliasPackage'))){
  $pattern='(?s)<'+$entry[0]+'\b[^>]*>\s*<name>Yso unified health</name>.*?</'+$entry[0]+'>'
  $matches=[regex]::Matches($text,$pattern)
  if($matches.Count -gt 1){throw ('Duplicate health '+$entry[0])}
  if($matches.Count){$match=$matches[0];$text=$text.Substring(0,$match.Index)+$entry[1]+$text.Substring($match.Index+$match.Length)}
  else{
    $end='</'+$entry[2]+'>'
    $at=$text.IndexOf($end,[StringComparison]::Ordinal)
    if($at -lt 0){throw ('Missing '+$entry[2])}
    $text=$text.Insert($at,$entry[1])
  }
}
[void][xml]$text
if($text -cne $before -and $PSCmdlet.ShouldProcess($PackagePath,'Embed unified read-only health service')){
  [IO.File]::WriteAllText($PackagePath,$text,[Text.UTF8Encoding]::new($false))
}
