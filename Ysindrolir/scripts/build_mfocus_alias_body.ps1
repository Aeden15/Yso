$ErrorActionPreference = 'Stop'
$MagiDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'Magi'
$routeCore = Join-Path $MagiDir 'magi_route_core.lua'
$dissonance = Join-Path $MagiDir 'magi_dissonance.lua'
$src = Join-Path $MagiDir 'magi_focus.lua'
$dst = Join-Path $MagiDir 'mfocus_alias_body.lua'
$toggle = @'

-- ^mfocus$ alias entry: toggle focus route loop (route id magi_focus).
Yso.util = Yso.util or {}
if type(Yso.util.toggle_route_alias) ~= "function" then
  if type(cecho) == "function" then
    cecho("<orange>[YSO] route controller unavailable; check Mudlet load order.<reset>\n")
  end
  return
end
local ok, why = Yso.util.toggle_route_alias("magi_focus", "alias:mfocus")
if ok ~= true and type(cecho) == "function" then
  cecho("<SlateBlue>[YSO] mfocus toggle failed: " .. tostring(why or "unknown") .. "<reset>\n")
end
'@

$parts = @(
  ((Get-Content -LiteralPath $routeCore -Raw -Encoding UTF8).TrimEnd() -replace '(?m)^return RC\s*$', '-- return omitted: alias body uses Yso.off.magi.route_core')
  ((Get-Content -LiteralPath $dissonance -Raw -Encoding UTF8).TrimEnd() -replace '(?m)^return D\s*$', '-- return omitted: alias body uses Yso.magi.dissonance')
  ((Get-Content -LiteralPath $src -Raw -Encoding UTF8).TrimEnd() -replace '(?m)^return MF\s*$', '-- return omitted: alias body assigns Yso.off.magi.focus above')
  $toggle.TrimStart()
)

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($dst, ($parts -join "`n`n") + "`n", $utf8)
Write-Host "Wrote $dst"

$luac = Get-Command luac -ErrorAction SilentlyContinue
if (-not $luac) {
  Write-Warning 'luac not found; skipped syntax check on mfocus alias body'
} else {
  & $luac.Source -p $dst
  if ($LASTEXITCODE -ne 0) { throw "luac syntax check failed for $dst" }
  Write-Host "luac OK: $dst"
}
