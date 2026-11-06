param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'),[string]$AkPackagePath=(Join-Path (Split-Path $PackagePath -Parent) 'AK.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$manifest=Get-Content -Raw -LiteralPath (Join-Path $root 'Magi/magi_feedback_triggers.json') | ConvertFrom-Json
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('magi-feedback-'+[guid]::NewGuid())
function Assert($ok,[string]$message){if(-not $ok){throw $message}}
function Key($node){
  $parts=@();$p=$node
  while($p -and $p.NodeType -eq 'Element'){$name=$p.SelectSingleNode('./name');if($name){$parts=@($name.InnerText)+$parts};$p=$p.ParentNode}
  return $node.LocalName+':'+($parts -join '/')
}
New-Item -ItemType Directory -Path $scratch | Out-Null
try{
  $yPath=Join-Path $scratch 'Yso system.xml';$aPath=Join-Path $scratch 'AK.xml'
  Copy-Item -LiteralPath $PackagePath -Destination $yPath
  Copy-Item -LiteralPath $AkPackagePath -Destination $aPath
  [xml]$oldY=[IO.File]::ReadAllText($yPath);[xml]$oldA=[IO.File]::ReadAllText($aPath)
  & (Join-Path $PSScriptRoot 'build_magi_feedback_package.ps1') -PackagePath $yPath -AkPackagePath $aPath
  $firstY=[IO.File]::ReadAllText($yPath);$firstA=[IO.File]::ReadAllText($aPath)
  & (Join-Path $PSScriptRoot 'build_magi_feedback_package.ps1') -PackagePath $yPath -AkPackagePath $aPath
  Assert ($firstY -ceq [IO.File]::ReadAllText($yPath)) 'Yso feedback build is not idempotent'
  Assert ($firstA -ceq [IO.File]::ReadAllText($aPath)) 'AK feedback migration is not idempotent'
  [xml]$y=$firstY;[xml]$a=$firstA
  Assert (@($manifest.triggers.source_name | Sort-Object -Unique).Count -eq 37) 'Not all 37 source triggers accounted for'
  foreach($entry in $manifest.triggers){
    $nodes=$y.SelectNodes('//Trigger[name="'+$entry.name+'"]')
    Assert ($nodes.Count -eq 1 -and $nodes[0].GetAttribute('isActive') -eq 'yes') ('Missing/duplicate/inactive '+$entry.name)
    Assert ([string]$nodes[0].ParentNode.ParentNode.name -eq $entry.folder) ('Wrong Magi folder: '+$entry.name)
    Assert ((@($nodes[0].regexCodeList.string) -join "`n") -ceq ($entry.patterns -join "`n")) ('Pattern drift: '+$entry.name)
    Assert (-not ([string]$nodes[0].script -match 'targetting|send\(|raiseEvent|vitals|f"')) ('Foreign action: '+$entry.name)
  }
  foreach($entry in $manifest.retire_ak){
    $group=$a.SelectSingleNode('//TriggerGroup[name="'+$entry.scope+'"]')
    $parent=if($entry.parent -eq $entry.scope){$group}else{$group.SelectSingleNode('.//TriggerGroup[name="'+$entry.parent+'"]')}
    Assert ($parent.SelectSingleNode('./Trigger[name="'+$entry.name+'"]').GetAttribute('isActive') -eq 'no') ('AK duplicate still enabled: '+$entry.name)
  }
  $changed=@{};foreach($entry in @($manifest.retire_ak)+@($manifest.remove_ak_patterns)){
    foreach($node in $oldA.SelectNodes('//Trigger[name="'+$entry.name+'"]')){
      if((Key $node).Contains('/'+$entry.scope+'/')){$changed[(Key $node)]=$true}
    }
  }
  foreach($pair in @(@($oldY,$y),@($oldA,$a))){
    $index=@{};$positions=@{}
    foreach($node in $pair[1].SelectNodes('//Trigger|//Script|//Alias')){
      $key=Key $node
      if(-not $index.ContainsKey($key)){$index[$key]=[Collections.Generic.List[string]]::new()}
      $index[$key].Add($node.OuterXml)
    }
    foreach($node in $pair[0].SelectNodes('//Trigger|//Script|//Alias')){
      $key=Key $node
      if($changed.ContainsKey($key) -or $key -match 'Magi spell feedback|Magi feedback '){continue}
      $position=if($positions.ContainsKey($key)){$positions[$key]}else{0}
      Assert ($index.ContainsKey($key) -and $index[$key].Count -gt $position -and $index[$key][$position] -ceq $node.OuterXml) ('Unrelated native node changed: '+$key)
      $positions[$key]=$position+1
    }
  }
  $prone=$a.SelectSingleNode('//TriggerGroup[name="Obviously(i)"]/Trigger[name="Prone"]')
  $shield=$a.SelectSingleNode('//TriggerGroup[name="Shielded"]/Trigger[name="Shield Down"]')
  Assert (@($prone.regexCodeList.string).Count -eq 33) 'Shared Prone alternatives were lost'
  Assert (@($shield.regexCodeList.string).Count -eq 40) 'Shared shield alternatives were lost'
  $deep=$a.SelectSingleNode('//TriggerGroup[name="Magi Group"]//Trigger[name="Deepfreeze"]')
  Assert (@($deep.regexCodeList.string).Count -eq 2) 'Named third-person Deepfreeze coverage was lost'
  $helper=$y.SelectSingleNode('//Script[name="Magi spell feedback"]/script').InnerText
  Assert ($helper.Trim().Replace("`r`n","`n") -ceq [IO.File]::ReadAllText((Join-Path $root 'Magi/magi_spell_feedback.lua')).Trim().Replace("`r`n","`n")) 'Feedback source/native drift'
  $helperPath=Join-Path $scratch 'feedback.lua';[IO.File]::WriteAllText($helperPath,$helper,[Text.UTF8Encoding]::new($false))
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_magi_feedback.lua') ($root.Replace('\','/')+'/') $helperPath
  Assert ($LASTEXITCODE -eq 0) 'Embedded feedback behaviors failed'
  Assert ($firstY.IndexOf('<name>Magi spell feedback</name>') -lt $firstY.IndexOf('<name>Magi water group</name>')) 'Feedback must load before Water defaults are selected'
  & (Join-Path $PSScriptRoot 'test_magi_feedback_tracking.ps1') -PackagePath $yPath -AkPackagePath $aPath
  # Prove the cross-package ownership test rejects a reintroduced double writer.
  $duplicate=$a.SelectSingleNode('//TriggerGroup[name="Magi Group"]//Trigger[name="Frozen"]')
  $duplicate.SetAttribute('isActive','yes')
  [IO.File]::WriteAllText($aPath,$a.OuterXml,[Text.UTF8Encoding]::new($false))
  $mutationLog=Join-Path $scratch 'duplicate-check.log'
  & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'test_magi_feedback_tracking.ps1') -PackagePath $yPath -AkPackagePath $aPath *> $mutationLog
  Assert ($LASTEXITCODE -ne 0 -and [IO.File]::ReadAllText($mutationLog).Contains('found 2')) 'Ownership regression failed to detect duplicate Freeze tracking'
  [IO.File]::WriteAllText($aPath,$firstA,[Text.UTF8Encoding]::new($false))
  Write-Host 'PASS: 37 supplied triggers, scoped paired migration, duplicate retirement, mixed-handler preservation and embedded behavior'
}finally{
  $resolved=(Resolve-Path -LiteralPath $scratch).Path
  if((Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') -or (Split-Path $resolved -Leaf) -notlike 'magi-feedback-*'){throw 'Unexpected fixture cleanup path'}
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
