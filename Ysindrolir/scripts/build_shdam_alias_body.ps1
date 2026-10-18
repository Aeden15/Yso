$ErrorActionPreference = 'Stop'
$monk = Join-Path (Split-Path $PSScriptRoot -Parent) 'Monk'
$source = Join-Path $monk 'shikudo_group_damage.lua'
$body = (Get-Content -LiteralPath $source -Raw -Encoding UTF8).Replace("`r`n", "`n").TrimEnd()
$sha = [Security.Cryptography.SHA256]::Create()
$revision = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($body)))).Replace('-', '').ToLowerInvariant()
$template = @'
-- ^shdam$: embedded implementation; no runtime file loading.
local revision = '__REVISION__'
local installed = Yso and Yso.off and Yso.off.monk and Yso.off.monk.group_damage
if not installed or installed._source_revision ~= revision then
  (function()
__BODY__
  end)()
  Yso.off.monk.group_damage._source_revision = revision
end
if not (Yso and Yso.util and type(Yso.util.toggle_route_alias)=='function') then
  if type(cecho)=='function' then cecho('<orange>[SHIKUDO] Route controller unavailable; check package load order.<reset>\n') end
  return
end
local ok, why = Yso.util.toggle_route_alias('monk_shikudo_group_damage', 'alias:shdam')
if ok ~= true and type(cecho)=='function' then
  cecho('<orange>[SHIKUDO] Toggle failed: '..tostring(why or 'unknown')..'<reset>\n')
end
'@
$output = $template.Replace('__REVISION__', $revision).Replace('__BODY__', $body).Replace("`r`n", "`n") + "`n"
$destination = Join-Path $monk 'shdam_alias_body.lua'
[IO.File]::WriteAllText($destination, $output, (New-Object Text.UTF8Encoding $false))
& luac -p $destination
if ($LASTEXITCODE -ne 0) { throw 'Shikudo alias compilation failed' }
Write-Host "Wrote $destination"
