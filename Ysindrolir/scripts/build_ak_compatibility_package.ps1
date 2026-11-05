[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/AK.xml'))
$ErrorActionPreference='Stop'
$before=[IO.File]::ReadAllText($PackagePath)
$text=$before
foreach($name in @('Transcendence','Transcendance fading')){
  $pattern='(?s)<Trigger\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</Trigger>'
  $matches=[regex]::Matches($text,$pattern)
  if($matches.Count -ne 1){throw ('Expected one AK trigger '+$name)}
  $entry=$matches[0]
  $block=$entry.Value.Replace('\%','%')
  $text=$text.Substring(0,$entry.Index)+$block+$text.Substring($entry.Index+$entry.Length)
}
[void][xml]$text
if($text -cne $before -and $PSCmdlet.ShouldProcess($PackagePath,'Normalize legacy percent string escapes')){
  [IO.File]::WriteAllText($PackagePath,$text,[Text.UTF8Encoding]::new($false))
}
