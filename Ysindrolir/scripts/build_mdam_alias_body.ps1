$ErrorActionPreference = 'Stop'
$MagiDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'Magi'
$routeCore = Join-Path $MagiDir 'magi_route_core.lua'
$src = Join-Path $MagiDir 'magi_group_damage.lua'
$dst = Join-Path $MagiDir 'mdam_alias_body.lua'
$toggle = @'

-- ^mdam$ alias entry: toggle group-damage loop (route id magi_group_damage).
Yso.util = Yso.util or {}
if type(Yso.util.toggle_route_alias) ~= "function" then
  if type(cecho) == "function" then
    cecho("<orange>[YSO] route controller unavailable; check Mudlet load order.<reset>\n")
  end
  return
end
local ok, why = Yso.util.toggle_route_alias("magi_group_damage", "alias:mdam")
if ok ~= true and type(cecho) == "function" then
  cecho("<SlateBlue>[YSO] mdam toggle failed: " .. tostring(why or "unknown") .. "<reset>\n")
end
'@

$parts = @(
  (Get-Content -LiteralPath $routeCore -Raw).TrimEnd()
  ((Get-Content -LiteralPath $src -Raw).TrimEnd() -replace '(?m)^return MGD\s*$', '-- return omitted: alias body assigns Yso.off.magi.group_damage above')
  $toggle.TrimStart()
)

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($dst, ($parts -join "`n`n") + "`n", $utf8)
Write-Host "Wrote $dst"
