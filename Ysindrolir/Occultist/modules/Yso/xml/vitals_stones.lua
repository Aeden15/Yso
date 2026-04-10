-- Auto-exported from Mudlet package script: Vitals stones
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso_ProbeObjects.lua  (FULL DROP-IN)
--  • Handles "probe simulacrum" + "probe heartstone" output
--  • Aliases: pprobe [sim|heart|both], plus psim / phs
--  • Probing is BALANCELESS: "both" fires back-to-back (optional tiny delay)
--  • Echo: HotPink remaining % (10000 max assumed)
--========================================================--

Yso = Yso or {}
Yso.probe = Yso.probe or {}
Yso.probe.cfg = Yso.probe.cfg or {
  max_simulacrum = 10000,
  max_heartstone = 10000,
  both_delay     = 0.0,  -- seconds; set to 0 for immediate, 0.05 if you want spacing
}

-- -------- helpers --------
local function _pct(n, d)
  if not d or d <= 0 then return 0 end
  local p = math.floor((n / d) * 100)
  if p < 0 then p = 0 end
  if p > 100 then p = 100 end
  return p
end

local function _pct_color(p)
  if p >= 75 then return "<green>"
  elseif p >= 50 then return "<yellow>"
  elseif p >= 25 then return "<orange>"
  else return "<red>" end
end

local function _echo_probe(tag, pct)
  cecho(string.format("<HotPink>[%s] %s%d%%<reset>\n", tag, _pct_color(pct), pct))
end

-- -------- senders --------
function Yso.probe.simulacrum()
  send("probe simulacrum")
end

function Yso.probe.heartstone()
  send("probe heartstone")
end

function Yso.probe.both()
  Yso.probe.simulacrum()
  local d = tonumber(Yso.probe.cfg.both_delay) or 0
  if d > 0 then
    tempTimer(d, function() Yso.probe.heartstone() end)
  else
    Yso.probe.heartstone()
  end
end

-- -------- triggers (probe output parsing) --------
Yso.probe._trig = Yso.probe._trig or {}

-- Simulacrum: "Your simulacrum is at 10000 health."
if Yso.probe._trig.simulacrum then killTrigger(Yso.probe._trig.simulacrum) end
Yso.probe._trig.simulacrum = tempRegexTrigger(
  [[^Your simulacrum is at (\d+)\s+health\.]],
  function()
    if not matches or not matches[2] then return end
    local cur = tonumber(matches[2]) or 0
    local max = tonumber(Yso.probe.cfg.max_simulacrum) or 10000
    _echo_probe("Simulacrum", _pct(cur, max))
  end
)

-- Heartstone: "Your heartstone stores 10000 mana."
if Yso.probe._trig.heartstone then killTrigger(Yso.probe._trig.heartstone) end
Yso.probe._trig.heartstone = tempRegexTrigger(
  [[^Your heartstone stores (\d+)\s+mana\.]],
  function()
    if not matches or not matches[2] then return end
    local cur = tonumber(matches[2]) or 0
    local max = tonumber(Yso.probe.cfg.max_heartstone) or 10000
    _echo_probe("Heartstone", _pct(cur, max))
  end
)

-- -------- aliases --------
Yso.probe._alias = Yso.probe._alias or {}

-- pprobe            -> both
-- pprobe sim        -> simulacrum
-- pprobe heart      -> heartstone
-- pprobe both       -> both
if Yso.probe._alias.pprobe then killAlias(Yso.probe._alias.pprobe) end
Yso.probe._alias.pprobe = tempAlias([[^pprobe(?:\s+(sim|heart|both))?$]], function()
  local which = (matches[2] or ""):lower()
  if which == "" or which == "both" then
    Yso.probe.both()
  elseif which == "sim" then
    Yso.probe.simulacrum()
  elseif which == "heart" then
    Yso.probe.heartstone()
  else
    cecho("<gray>Usage: pprobe [sim|heart|both]\n")
  end
end)

-- Optional fast shorthands
if Yso.probe._alias.psim then killAlias(Yso.probe._alias.psim) end
Yso.probe._alias.psim = tempAlias([[^psim$]], function() Yso.probe.simulacrum() end)

if Yso.probe._alias.phs then killAlias(Yso.probe._alias.phs) end
Yso.probe._alias.phs = tempAlias([[^phs$]], function() Yso.probe.heartstone() end)

cecho("<gray>[Yso] ProbeObjects loaded: triggers + aliases (pprobe/psim/phs)\n")
--========================================================--
