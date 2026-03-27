-- Auto-exported from Mudlet package script: Hunt — Primebond Shieldbreak Selector
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- yso_hunt_primebond_selector.lua (DROP-IN)
--  • On entering bash OR combat mode: query PRIMEBOND once and cache bonds
--  • Exposes Legacy.Settings.Basher.hasLycantha for denizen shieldbreak selection
--========================================================--

Yso = Yso or {}
yso = yso or Yso

Yso.primebond = Yso.primebond or { bonds = {}, last_scan = 0, scanning = false }
local P = Yso.primebond

local function _now() return (type(getEpoch) == "function" and getEpoch()) or os.time() end
local function _norm_mode(m)
  m = tostring(m or ""):lower()
  if m == "hunt" or m == "pve" then return "bash" end
  return m
end

local function _set_has_lycantha(v)
  if Legacy and Legacy.Settings and Legacy.Settings.Basher then
    Legacy.Settings.Basher.hasLycantha = (v == true)
  end
end

local function _is_occultist()
  if Yso and Yso.classinfo and type(Yso.classinfo.is_occultist) == "function" then
    return Yso.classinfo.is_occultist()
  end
  return gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class == "Occultist"
end

local function _reset()
  P.bonds = {}
  P.scanning = true
  P.last_scan = _now()
  _set_has_lycantha(false)
end

function P.request()
  if not _is_occultist() then return end

  local now = _now()
  if P.scanning then return end
  if (now - (P.last_scan or 0)) < 3 then return end

  _reset()
  send("PRIMEBOND")
end

local function _record_bond(raw)
  raw = tostring(raw or "")
  local base = raw:match("^%s*([^,]+)") or raw
  base = (base:gsub("%s+$", ""))
  if base == "" then return end

  local key = base:lower()
  P.bonds[key] = true
  if key == "lycantha" then _set_has_lycantha(true) end
end

P._trig = P._trig or {}
if P._trig.bond_line then killTrigger(P._trig.bond_line) end
P._trig.bond_line = tempRegexTrigger(
  [[^You have forged a bond with (.+)\.$]],
  function() _record_bond(matches[2]) end
)

if P._trig.no_bonds then killTrigger(P._trig.no_bonds) end
P._trig.no_bonds = tempRegexTrigger(
  [[^You have not forged any bonds\.$]],
  function() P.scanning = false end
)

if P._trig.scan_timeout then killTrigger(P._trig.scan_timeout) end
P._trig.scan_timeout = tempRegexTrigger(
  [[^\s*$]],
  function()
    if P.scanning and (_now() - (P.last_scan or 0)) > 0.25 then
      P.scanning = false
    end
  end
)

P._eh = P._eh or {}
if P._eh.mode_changed then killAnonymousEventHandler(P._eh.mode_changed) end
P._eh.mode_changed = registerAnonymousEventHandler("yso.mode.changed", function(_old, new, _reason)
  local m = _norm_mode(new)
  if m == "bash" or m == "combat" then
    P.request()
  end
end)

if Legacy and Legacy.Settings and Legacy.Settings.Basher and Legacy.Settings.Basher.hasLycantha == nil then
  Legacy.Settings.Basher.hasLycantha = false
end
