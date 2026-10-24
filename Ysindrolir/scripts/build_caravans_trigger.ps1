[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
if(-not $PSCmdlet.ShouldProcess($PackagePath,'Synchronize only Caravans match alternatives')){return}
$bytes=[IO.File]::ReadAllBytes($PackagePath)
$hasBom=$bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
$encoding=New-Object Text.UTF8Encoding($hasBom,$true)
$text=[IO.File]::ReadAllText($PackagePath,$encoding)
$entries=[regex]::Matches($text,'(?s)<Trigger\b[^>]*>\s*<name>Caravans</name>.*?</Trigger>')
if($entries.Count -ne 1){throw 'Expected exactly one Caravans trigger'}
$entry=$entries[0]
$block=$entry.Value
$newline=if($block.Contains("`r`n")){"`r`n"}else{"`n"}
# Mudlet single-line trigger rows are OR alternatives. Type 1 is Perl regex.
$patterns=@('^\(Army\): A caravan bearing','^The industrious bustle of workers in Quartz Peak echoes across Sapience as they prepare a caravan\.$')
foreach($list in @('regexCodeList','regexCodePropertyList')){
  $matches=[regex]::Matches($block,'(?m)^(?<indent>[\t ]*)<'+$list+'>[\s\S]*?</'+$list+'>')
  if($matches.Count -ne 1){throw "Expected exactly one $list in Caravans"}
  $match=$matches[0]
  $indent=$match.Groups['indent'].Value
  $rows=if($list -eq 'regexCodeList'){
    @($patterns | ForEach-Object {$indent+"`t<string>"+$_+'</string>'})
  }else{@($indent+"`t<integer>1</integer>",$indent+"`t<integer>1</integer>")}
  $replacement=$indent+'<'+$list+'>'+$newline+($rows -join $newline)+$newline+$indent+'</'+$list+'>'
  $block=$block.Substring(0,$match.Index)+$replacement+$block.Substring($match.Index+$match.Length)
}
$updated=$text.Substring(0,$entry.Index)+$block+$text.Substring($entry.Index+$entry.Length)
[xml]$validated=$updated
if($updated -cne $text){[IO.File]::WriteAllText($PackagePath,$updated,$encoding)}
Write-Output 'Synchronized only Caravans match alternatives.'
