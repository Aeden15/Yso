param([string]$PackagePath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('yso-kai-soar-' + [guid]::NewGuid() + '.xml')
function Assert($condition, $message) { if (-not $condition) { throw $message } }
try {
  Copy-Item -LiteralPath $PackagePath -Destination $scratch
  $before = [System.IO.File]::ReadAllText($scratch)
  $builder = Join-Path $PSScriptRoot 'build_kai_soar_package.ps1'
  & $builder -PackagePath $scratch
  $after = [System.IO.File]::ReadAllText($scratch)
  [xml]$doc = $after
  $kai = $doc.SelectSingleNode('//Trigger[name="Kai cripple"]')
  Assert ($kai.script.Trim() -ceq ([System.IO.File]::ReadAllText((Join-Path $root 'Monk/kai_cripple_trigger.lua')).Trim())) 'Packaged Kai script differs from maintained source'
  Assert ($kai.isActive -eq 'yes' -and $kai.isMultiline -eq 'yes') 'Kai must be active and multiline'
  Assert ($kai.conditonLineDelta -eq '1') 'Kai must match consecutive lines'
  Assert ($kai.regexCodeList.string.Count -eq 2) 'Kai must use two confirmation patterns'
  Assert (($kai.regexCodePropertyList.integer -join ',') -eq '1,1') 'Kai patterns must use PCRE'
  $line = 'You thrust your palms forward and a stream of blue light crackles forth to strike out at Trendric.'
  Assert ($line -match $kai.regexCodeList.string[0]) 'Victim pattern must match supplied output'
  Assert ($Matches[1] -eq 'Trendric') 'Victim capture incorrect'
  Assert ('Snapping sounds echo through the air as your crippled victim sinks to the floor.' -match $kai.regexCodeList.string[1]) 'Success pattern must match supplied output'
  Assert (-not ('Snapping sounds echo through the air.' -match $kai.regexCodeList.string[1])) 'Incomplete success must not match'
  $soar = $doc.SelectSingleNode('//Alias[name="Soaring"]')
  Assert ($soar.script.Trim() -ceq ([System.IO.File]::ReadAllText((Join-Path $root 'Airlord/soar_alias.lua')).Trim())) 'Packaged soar script differs from maintained source'
  Assert ($soar.regex -eq '^soa([lhs])$') 'Soar shortcuts incorrect'
  foreach ($suffix in @('l','h','s')) { Assert (('soa' + $suffix) -match $soar.regex) 'Supported shortcut rejected' }
  foreach ($bad in @('soax','soahs','soa','xsoah')) { Assert (-not ($bad -match $soar.regex)) 'Unsupported shortcut accepted' }
  # The shared builder now also maintains self-Deliverance and Kai resource
  # feedback. Enemy Deliverance safety remains outside its allowed changes.
  $strip = '(?s)<Trigger\b[^>]*>\s*<name>(?:Kai cripple|Kai burst used|Kai burst resource rejection|Kai burst cooldown|Kai burst ready|Deliverance channeling|Deliverance up|Deliverance down)</name>.*?</Trigger>|<Alias\b[^>]*>\s*<name>(?:Soaring|Deliverance)</name>.*?</Alias>|<Script\b[^>]*>\s*<name>Kai resource</name>.*?</Script>'
  Assert (([regex]::Replace($before,$strip,'')) -ceq ([regex]::Replace($after,$strip,''))) 'Builder modified unrelated XML'
  & $builder -PackagePath $scratch
  Assert ($after -ceq [System.IO.File]::ReadAllText($scratch)) 'Builder is not idempotent'
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_kai_soar.lua') $root
  if ($LASTEXITCODE -ne 0) { throw 'Kai/soar Lua regression tests failed' }
  Write-Host 'Kai/soar package tests passed'
} finally {
  if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch }
}
