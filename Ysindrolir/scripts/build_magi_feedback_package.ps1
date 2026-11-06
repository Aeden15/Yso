# Install maintained Magi confirmations; retire only transferred AK reactions.
[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'),
  [string]$AkPackagePath=(Join-Path (Split-Path $PackagePath -Parent) 'AK.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$manifest=Get-Content -LiteralPath (Join-Path $root 'Magi/magi_feedback_triggers.json') -Raw | ConvertFrom-Json
function Encode([string]$s){$s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;')}
function Span([string]$text,[string]$tag,[string]$name){
  $pattern='(?s)<'+$tag+'\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>'
  $starts=[regex]::Matches($text,$pattern)
  if($starts.Count -ne 1){throw "Expected one $tag $name; found $($starts.Count)"}
  $start=$starts[0].Index;$depth=0
  foreach($token in [regex]::Matches($text.Substring($start),'</?'+$tag+'\b[^>]*>')){
    if($token.Value.StartsWith('</')){$depth--}else{$depth++}
    if($depth -eq 0){$length=$token.Index+$token.Length;return @{Index=$start;Length=$length;Value=$text.Substring($start,$length)}}
  }
  throw "Unclosed $tag $name"
}
function ReplaceSpan([string]$text,$span,[string]$body){$text.Substring(0,$span.Index)+$body+$text.Substring($span.Index+$span.Length)}
function SetScript([string]$text,[string]$name,[string]$body){
  $pattern='(?s)<Script\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</Script>'
  $nodes=[regex]::Matches($text,$pattern)
  $block='<Script isActive="yes" isFolder="no"><name>'+ $name+'</name><packageName /><script>'+(Encode $body)+'</script><eventHandlerList /></Script>'
  if($nodes.Count -eq 1){return ReplaceSpan $text @{Index=$nodes[0].Index;Length=$nodes[0].Length} $block}
  if($nodes.Count -ne 0){throw "Duplicate script $name"}
  $water=Span $text 'Script' 'Magi water group'
  $text.Substring(0,$water.Index)+$block+"`n"+$text.Substring($water.Index)
}
function TriggerBlock($entry,[string]$template){
  if($entry.event -notmatch '^[a-z_]+$'){throw 'Invalid feedback event'}
  $who=if($null -ne $entry.target_group){'matches['+$entry.target_group+']'}else{'nil'}
  $detail=if($null -ne $entry.detail_group){'matches['+$entry.detail_group+']'}else{'nil'}
  $script="local F = Yso and Yso.magi and Yso.magi.spell_feedback`nif F then F.handle('"+$entry.event+"', "+$who+', '+$detail+") end"
  $block=[regex]::Replace($template,'(?s)<name>.*?</name>','<name>'+$entry.name+'</name>',1)
  $encoded=Encode $script
  $block=[regex]::Replace($block,'(?s)<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+$encoded+'</script>'},1)
  $patterns=(@($entry.patterns | ForEach-Object {'<string>'+(Encode ([string]$_))+'</string>'}) -join "`n")
  $properties=(@($entry.patterns | ForEach-Object {'<integer>1</integer>'}) -join "`n")
  $block=[regex]::Replace($block,'(?s)<regexCodeList>.*?</regexCodeList>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<regexCodeList>'+$patterns+'</regexCodeList>'},1)
  [regex]::Replace($block,'(?s)<regexCodePropertyList>.*?</regexCodePropertyList>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<regexCodePropertyList>'+$properties+'</regexCodePropertyList>'},1)
}
function EditAkTrigger([string]$text,$entry,[bool]$disable){
  $scope=Span $text 'TriggerGroup' $entry.scope
  $parent=if($entry.parent -eq $entry.scope){@{Index=0;Length=$scope.Value.Length;Value=$scope.Value}}else{Span $scope.Value 'TriggerGroup' $entry.parent}
  $trigger=Span $parent.Value 'Trigger' $entry.name
  $body=$trigger.Value
  if($disable){$body=[regex]::Replace($body,'^<Trigger\b[^>]*>',[Text.RegularExpressions.MatchEvaluator]{param($m) $m.Value.Replace('isActive="yes"','isActive="no"')})}
  else{
    $list=[regex]::Match($body,'(?s)<regexCodeList>(.*?)</regexCodeList>')
    $properties=[regex]::Match($body,'(?s)<regexCodePropertyList>(.*?)</regexCodePropertyList>')
    $strings=[regex]::Matches($list.Groups[1].Value,'(?s)<string>.*?</string>')
    $ints=[regex]::Matches($properties.Groups[1].Value,'<integer>\d+</integer>')
    if($strings.Count -ne $ints.Count){throw 'Mismatched trigger patterns/properties'}
    $codes=$list.Groups[1].Value;$props=$properties.Groups[1].Value;$removed=0
    for($i=$strings.Count-1;$i -ge 0;$i--){
      $decoded=[System.Net.WebUtility]::HtmlDecode($strings[$i].Value)
      if($decoded.Contains($entry.contains)){
        $codes=$codes.Remove($strings[$i].Index,$strings[$i].Length)
        $props=$props.Remove($ints[$i].Index,$ints[$i].Length);$removed++
      }
    }
    if($removed -gt 1){throw ('Ambiguous migration: '+$entry.name)}
    $body=$body.Replace($list.Value,'<regexCodeList>'+$codes+'</regexCodeList>')
    $body=$body.Replace($properties.Value,'<regexCodePropertyList>'+$props+'</regexCodePropertyList>')
  }
  $parentBody=ReplaceSpan $parent.Value $trigger $body
  $scopeBody=ReplaceSpan $scope.Value $parent $parentBody
  ReplaceSpan $text $scope $scopeBody
}
if(-not $PSCmdlet.ShouldProcess("$PackagePath and $AkPackagePath",'Install supplied Magi coverage and retire overlapping AK reactions')){return}
$beforeY=[IO.File]::ReadAllText($PackagePath);$beforeA=[IO.File]::ReadAllText($AkPackagePath)
$y=$beforeY;$a=$beforeA
$template=(Span $y 'Trigger' 'Mfocus resonance failure').Value
$magi=Span $y 'TriggerGroup' 'Magi';$magiBody=$magi.Value
foreach($folder in @('Elementalism','Artificing','Crystalism')){
  $parent=Span $magiBody 'TriggerGroup' $folder
  $name='Magi spell feedback ('+$folder+')'
  $prefix=[regex]::Match($parent.Value,'(?s)^<TriggerGroup\b[^>]*>\s*<name>.*?</name>.*?(?=<Trigger\b|<TriggerGroup\b|</TriggerGroup>)').Value
  $prefix=$prefix.Replace('<name>'+$folder+'</name>','<name>'+$name+'</name>')
  $children=@($manifest.triggers | Where-Object folder -eq $folder | ForEach-Object {TriggerBlock $_ $template}) -join "`n"
  $group=$prefix+$children+"`n</TriggerGroup>"
  if([regex]::IsMatch($parent.Value,'<name>'+[regex]::Escape($name)+'</name>')){
    $managed=Span $parent.Value 'TriggerGroup' $name
    $parentBody=ReplaceSpan $parent.Value $managed $group
  }else{
    $end=$parent.Value.LastIndexOf('</TriggerGroup>')
    $parentBody=$parent.Value.Insert($end,$group+"`n")
  }
  $magiBody=ReplaceSpan $magiBody $parent $parentBody
}
$y=ReplaceSpan $y $magi $magiBody
$y=SetScript $y 'Magi spell feedback' ([IO.File]::ReadAllText((Join-Path $root 'Magi/magi_spell_feedback.lua')))
foreach($entry in $manifest.retire_ak){$a=EditAkTrigger $a $entry $true}
foreach($entry in $manifest.remove_ak_patterns){$a=EditAkTrigger $a $entry $false}
[xml]$validatedY=$y;[xml]$validatedA=$a
if($y -cne $beforeY){[IO.File]::WriteAllText($PackagePath,$y,[Text.UTF8Encoding]::new($false))}
if($a -cne $beforeA){[IO.File]::WriteAllText($AkPackagePath,$a,[Text.UTF8Encoding]::new($false))}
Write-Host 'Installed 37 supplied Magi trigger behaviors (39 normalized confirmations); retired overlapping AK reactions.'
