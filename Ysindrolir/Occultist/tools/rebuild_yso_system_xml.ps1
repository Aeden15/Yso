param(
  [string]$XmlPath = 'C:\Users\shuji\OneDrive\Desktop\Yso systems\Ysindrolir\mudlet_packages\Yso system.xml',
  [string]$MirrorRoot = 'C:\Users\shuji\OneDrive\Desktop\Yso systems\Ysindrolir\Occultist\modules\Yso\xml'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
    $skipped.Add($_.Name)
  }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($XmlPath, $xml, $utf8NoBom)

[xml](Get-Content -Path $XmlPath -Raw) | Out-Null

Write-Output ("updated={0}" -f $updated.Count)
if ($updated.Count -gt 0) {
  Write-Output ("updated_files=" + ($updated -join ', '))
}
if ($skipped.Count -gt 0) {
  Write-Output ("skipped_files=" + ($skipped -join ', '))
}
