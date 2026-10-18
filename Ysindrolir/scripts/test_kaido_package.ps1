param([string]$PackagePath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('yso-kaido-' + [guid]::NewGuid() + '.xml')
$luaScratch = $scratch + '.lua'
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$messages = [ordered]@{
  'Kai burst used' = 'You let loose an uncontrolled burst of kai energy, flushing it through your system and bolstering your reserves.'
  'Kai burst resource rejection' = 'You are already circulating too much kai energy to focus upon an uncontrolled burst.'
  'Kai burst cooldown' = 'You may not yet produce a burst of uncontrolled kai energy.'
  'Kai burst ready' = 'You may produce another burst of uncontrolled kai energy.'
  'Deliverance channeling' = 'You bow your head in prayer, press your palms together and begin to pray silently for deliverance.'
  'Deliverance up' = 'You slowly raise your head and feel your body pulse with the power of Deliverance.'
  'Deliverance down' = 'You raise your head and cease your prayers for deliverance.'
}
try {
  Copy-Item -LiteralPath $PackagePath -Destination $scratch
  $before = [IO.File]::ReadAllText($scratch)
  & (Join-Path $PSScriptRoot 'build_kai_soar_package.ps1') -PackagePath $scratch
  $after = [IO.File]::ReadAllText($scratch)
  [xml]$doc = $after
  foreach ($entry in $messages.GetEnumerator()) {
    $nodes = $doc.SelectNodes('//Trigger[name="' + $entry.Key + '"]')
    Assert ($nodes.Count -eq 1) ('Expected one trigger: ' + $entry.Key)
    $n = $nodes[0]
    Assert ($n.ParentNode.name -eq 'Kaido' -and $n.ParentNode.ParentNode.name -eq 'Monk') 'Wrong trigger folder'
    Assert ($n.isActive -eq 'yes' -and $n.isMultiline -eq 'no') 'Trigger must be active and single-line'
    Assert ([string]$n.regexCodePropertyList.integer -eq '1') 'Expected PCRE trigger'
    $pattern = [string]$n.regexCodeList.string
    Assert ($entry.Value -cmatch $pattern) ('Game message rejected: ' + $entry.Key)
    Assert (-not (('prefix ' + $entry.Value) -cmatch $pattern)) 'Pattern must be anchored'
    Assert (-not (($entry.Value + ' extra') -cmatch $pattern)) 'Pattern must reject suffixes'
    $expected = @{
      'Kai burst used' = @('on_burst','used'); 'Kai burst resource rejection' = @('on_burst','too_much_kai')
      'Kai burst cooldown' = @('on_burst','cooldown'); 'Kai burst ready' = @('on_burst','ready')
      'Deliverance channeling' = @('on_deliverance','channeling'); 'Deliverance up' = @('on_deliverance','active')
      'Deliverance down' = @('on_deliverance','idle')
    }
    $method, $state = $expected[$entry.Key]
    $harness = 'local observed; Yso = {monk = {kai = {' + $method + ' = function(s) observed = s end}}}' + "`n" + $n.script + "`n" + 'assert(observed == "' + $state + '")'
    [IO.File]::WriteAllText($luaScratch, $harness, (New-Object Text.UTF8Encoding $false))
    & lua $luaScratch
    if ($LASTEXITCODE -ne 0) { throw ('Packaged trigger dispatch failed: ' + $entry.Key) }
  }
  $alias = $doc.SelectSingleNode('//Alias[name="Deliverance"]')
  Assert ($alias.regex -eq '^delv$') 'Deliverance alias shortcut changed'
  Assert ($alias.script.Trim() -ceq [IO.File]::ReadAllText((Join-Path $root 'Monk/deliverance_alias.lua')).Trim()) 'Deliverance alias source mismatch'
  $resource = $doc.SelectSingleNode('//Script[name="Kai resource"]')
  Assert ($resource.script.Trim() -ceq [IO.File]::ReadAllText((Join-Path $root 'Monk/kai_resource.lua')).Trim()) 'Kai resource source mismatch'
  $names = @('Kai cripple') + @($messages.Keys)
  $triggerNames = ($names | ForEach-Object { [regex]::Escape($_) }) -join '|'
  $strip = '(?s)<Trigger\b[^>]*>\s*<name>(?:' + $triggerNames + ')</name>.*?</Trigger>|<Alias\b[^>]*>\s*<name>(?:Soaring|Deliverance)</name>.*?</Alias>|<Script\b[^>]*>\s*<name>Kai resource</name>.*?</Script>'
  Assert ([regex]::Replace($before,$strip,'') -ceq [regex]::Replace($after,$strip,'')) 'Builder changed unrelated bytes'
  & (Join-Path $PSScriptRoot 'build_kai_soar_package.ps1') -PackagePath $scratch
  Assert ($after -ceq [IO.File]::ReadAllText($scratch)) 'Kaido builder is not idempotent'
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_kaido.lua') $root
  if ($LASTEXITCODE -ne 0) { throw 'Kaido Lua regressions failed' }
  Write-Host 'Kaido package regressions passed'
} finally {
  foreach ($path in @($scratch, $luaScratch)) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path } }
}
