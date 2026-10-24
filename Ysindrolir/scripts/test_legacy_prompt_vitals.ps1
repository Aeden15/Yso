$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('yso-legacy-vitals-' + [guid]::NewGuid() + '.lua')
$failures = @()
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
local rendered = table.concat(output)
assert(rendered:find("-<red>300h", 1, true) and rendered:find("-<red>300m", 1, true), "Numeric string baselines must produce real deltas")
local failures = {}
local function check(name, fn)
  local ok, err = pcall(fn)
  if not ok then failures[#failures + 1] = name .. ": " .. tostring(err) end
end
check("missing and malformed baselines seed without false deltas", function()
  Legacy.Tester.oldHealth = nil; Legacy.Tester.oldMana = "invalid"
  output = {}
  sample({hp="5000", mp="4000", maxhp="6000", maxmp="6000"})
  assert(#output == 0 and Legacy.Tester.oldHealth == 5000 and Legacy.Tester.oldMana == 4000)
end)
check("partial samples preserve both previous and current vitals", function()
  output = {}
  sample({hp="4700"})
  sample({mp="3700"})
  sample(nil)
  sample({hp="invalid", mp="3700"})
  assert(#output == 0 and Legacy.Tester.oldHealth == 5000 and Legacy.Tester.oldMana == 4000)
  assert(Legacy.Tester.newHealth == 5000 and Legacy.Tester.newMana == 4000)
end)
for _, bleed in ipairs({false, "invalid", 0, 100, "150", 150}) do
  check("optional bleeding: " .. tostring(bleed), function()
    Legacy.Tester = {oldHealth = 5000, oldMana = 4000, Vitals = {bleed = bleed or nil}}
    output = {}
    sample({hp="4700", mp="4000", maxhp="6000", maxmp="6000"})
    local text = table.concat(output)
    assert(text:find("-<red>300h", 1, true), "Health delta must still render")
    assert((text:find("150B", 1, true) ~= nil) == (tonumber(bleed) == 150), "Only numeric bleeding above threshold renders")
    assert(Legacy.Tester.oldHealth == 4700, "Missing bleeding must not prevent baseline update")
  end)
end
check("missing profile vitals still renders health delta", function()
  Legacy.Tester = {oldHealth = 5000, oldMana = 4000}
  output = {}
  sample({hp="4700", mp="4000"})
  assert(table.concat(output):find("-<red>300h", 1, true))
  assert(Legacy.Tester.oldHealth == 4700)
end)
check("missing character profile skips until initialized", function()
  Legacy.Tester = nil
  output = {}
  sample({hp="5000", mp="4000"})
  assert(#output == 0 and Legacy.Tester == nil, "Prompt must not invent a partial character profile")
  Legacy.Tester = {Vitals = {}}
  sample({hp="5000", mp="4000"})
  assert(#output == 0 and Legacy.Tester.oldHealth == 5000 and Legacy.Tester.oldMana == 4000)
end)
assert(#failures == 0, table.concat(failures, "\n"))
print("Legacy vitals sample regressions passed")
'@
    [IO.File]::WriteAllText($scratch, $harness + "`n" + $block + "`n" + $checks, (New-Object Text.UTF8Encoding $false))
    & lua $scratch
    if ($LASTEXITCODE -ne 0) { $failures += $case[0] }
  }
  if ($failures.Count) { throw ('Vitals regressions failed: ' + ($failures -join ', ')) }
} finally { if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch } }
