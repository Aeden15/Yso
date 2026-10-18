$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('yso-legacy-vitals-' + [guid]::NewGuid() + '.lua')
try {
  foreach ($case in @(@('Legacy V2.1.xml','Trigger','Legacy Prompt'), @('Legacy UI V2.0.xml','Script','UI Setup'))) {
    [xml]$doc = [IO.File]::ReadAllText((Join-Path $root ('mudlet packages/' + $case[0])))
    $body = $doc.SelectSingleNode(('//' + $case[1] + '[name="' + $case[2] + '"]')).script
    $start = $body.IndexOf('  if Legacy.Settings.Prompt.vitalsChange == true then')
    $stop = $body.IndexOf('  if Legacy.Settings.Curing.affPrompt', $start)
    if ($start -lt 0 -or $stop -lt 0) { throw 'Vitals block not found' }
    $block = $body.Substring($start, $stop - $start)
    $harness = @'
local output = {}
cecho = function(s) output[#output + 1] = s end
Prompt = {cecho = function(_, s) cecho(s) end}
Legacy = {Settings = {Prompt = {vitalsChange = true, healthLost = function() return "" end}}}
gmcp = {Char = {Status = {name = "Tester"}, Vitals = {}}}
Legacy.Tester = {Vitals = {bleed = 0}}
local function sample(v)
  gmcp.Char.Vitals = v
'@
    $checks = @'
end
sample({hp="5000", mp="4000", maxhp="6000", maxmp="6000"})
assert(#output == 0, "First sample must seed baseline without a false delta")
assert(Legacy.Tester.oldHealth == 5000 and Legacy.Tester.oldMana == 4000)
sample({hp="4700", mp="4200", maxhp="6000", maxmp="6000"})
assert(#output > 0, "Valid subsequent delta must still render")
local count = #output
sample({mp="4100", maxhp="6000", maxmp="6000"})
assert(#output == count and Legacy.Tester.oldHealth == 4700, "Partial sample must not corrupt baseline")
sample({hp="bad", mp="bad"})
sample({hp="4500", mp="4000", maxhp="0", maxmp="invalid"})
assert(Legacy.Tester.oldHealth == 4500 and Legacy.Tester.oldMana == 4000)
Legacy.Tester.oldHealth = "4500"; Legacy.Tester.oldMana = "4000"
sample({hp="4200", mp="3700", maxhp="6000", maxmp="6000"})
print("Legacy vitals sample regressions passed")
'@
    [IO.File]::WriteAllText($scratch, $harness + "`n" + $block + "`n" + $checks, (New-Object Text.UTF8Encoding $false))
    & lua $scratch
    if ($LASTEXITCODE -ne 0) { throw ($case[0] + ' vitals regressions failed') }
  }
} finally { if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch } }
