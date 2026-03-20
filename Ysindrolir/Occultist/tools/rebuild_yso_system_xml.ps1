param(
  [string]$XmlPath = 'C:\Users\shuji\OneDrive\Desktop\Yso systems\Ysindrolir\mudlet packages\Yso system.xml',
  [string]$MirrorRoot = 'C:\Users\shuji\OneDrive\Desktop\Yso systems\Ysindrolir\Occultist\modules\Yso\xml'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$legacyNameMap = @{
  'softlock_gate.lua' = @('Softlock Gate')
  'yso_occultist_offense.lua' = @('Yso.occ.offense')
}

$bodySignatureMap = @{
  'hunt_primebond_shieldbreak_selector.lua' = 'yso_hunt_primebond_selector\.lua \(DROP-IN\)'
}

$expectedNoSlot = @(
  'party_aff.lua',
  'route_interface.lua',
  'route_registry.lua',
  'skillset_reference_chart.lua',
  'yso_aeon.lua',
  'yso_predict_cure.lua'
)

function Get-ScriptTitle {
  param([string]$Path)
  $first = Get-Content -Path $Path -TotalCount 1
  if ($first -match '^-- Auto-exported from Mudlet package script: (.+)$') {
    return $matches[1].Trim()
  }
  return $null
}

$xml = Get-Content -Path $XmlPath -Raw
$updated = New-Object System.Collections.Generic.List[string]
$noSlot = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]

Get-ChildItem -Path $MirrorRoot -Filter *.lua -File | Sort-Object Name | ForEach-Object {
  $path = $_.FullName
  $body = Get-Content -Path $path -Raw
  $escapedBody = [System.Security.SecurityElement]::Escape($body)

  $candidateNames = New-Object System.Collections.Generic.List[string]
  $candidateNames.Add($_.Name)
  $title = Get-ScriptTitle -Path $path
  if (-not [string]::IsNullOrWhiteSpace($title) -and -not $candidateNames.Contains($title)) {
    $candidateNames.Add($title)
  }
  foreach ($legacyName in @($legacyNameMap[$_.Name])) {
    if (-not [string]::IsNullOrWhiteSpace($legacyName) -and -not $candidateNames.Contains($legacyName)) {
      $candidateNames.Add($legacyName)
    }
  }

  $matched = $false
  foreach ($candidate in $candidateNames) {
    $escapedName = [regex]::Escape($candidate)
    $pattern = "(<name>$escapedName</name>\s*<packageName\s*/?>\s*<script>)(.*?)(</script>)"
    $options = [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    $regex = [regex]::new($pattern, $options)
    if (-not $regex.IsMatch($xml)) {
      continue
    }

    $xml = $regex.Replace($xml, {
      param($m)
      return $m.Groups[1].Value + $escapedBody + $m.Groups[3].Value
    }, 1)
    $updated.Add($_.Name + ' -> ' + $candidate)
    $matched = $true
    break
  }

  if (-not $matched) {
    $bodySignature = $bodySignatureMap[$_.Name]
    if (-not [string]::IsNullOrWhiteSpace($bodySignature)) {
      $sigPattern = "(<name>[^<]+</name>\s*<packageName\s*/?>\s*<script>)(?:(?!</script>)[\s\S])*?$bodySignature(?:(?!</script>)[\s\S])*(</script>)"
      $options = [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
      $regex = [regex]::new($sigPattern, $options)
      if ($regex.IsMatch($xml)) {
        $xml = $regex.Replace($xml, {
          param($m)
          return $m.Groups[1].Value + $escapedBody + $m.Groups[2].Value
        }, 1)
        $updated.Add($_.Name + ' -> body_signature')
        $matched = $true
      }
    }
  }

  if (-not $matched) {
    if ($expectedNoSlot -contains $_.Name) {
      $noSlot.Add($_.Name)
    } else {
      $skipped.Add($_.Name)
    }
  }
}

$validationDoc = New-Object System.Xml.XmlDocument
$validationDoc.LoadXml($xml)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($XmlPath, $xml, $utf8NoBom)

[xml](Get-Content -Path $XmlPath -Raw) | Out-Null

Write-Output ("updated={0}" -f $updated.Count)
if ($updated.Count -gt 0) {
  Write-Output ("updated_files=" + ($updated -join ', '))
}
if ($noSlot.Count -gt 0) {
  Write-Output ("no_slot_files=" + ($noSlot -join ', '))
}
if ($skipped.Count -gt 0) {
  Write-Output ("skipped_files=" + ($skipped -join ', '))
}
