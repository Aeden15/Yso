-- Auto-exported from Mudlet package script: Prio Baselines
-- DO NOT EDIT IN XML; edit this file instead.

Legacy = Legacy or {}
Legacy.Curing = Legacy.Curing or {}
Legacy.Curing.Prios = Legacy.Curing.Prios or {}

-- Cache of baselines keyed by server-side prio set name (dwc, snb, etc).
Legacy.Curing.Prios.baseSets = Legacy.Curing.Prios.baseSets or {}
Legacy.Curing.Prios.capture  = Legacy.Curing.Prios.capture  or { active=false, set=nil, lastPrio=nil }

-- Track what we believe is active server-side.
Legacy.Curing.ActiveServerSet = Legacy.Curing.ActiveServerSet or "legacy"

-- NOTE: Legacy.Curing.SwitchServerSet is defined in cureset_baselines.lua (SSOT).

-- Point Legacy's "Reprio baseline" at the active set's stored baseline.
function Legacy.Curing.UseBaseline(set)
  set = (set or Legacy.Curing.ActiveServerSet or "legacy"):lower()
  if not Legacy.Curing.Prios.baseSets[set] then return false end
  Legacy.Curing.Prios.legacy = Legacy.Curing.Prios.baseSets[set]
  Legacy.Curing.Prios.temp   = table.deepcopy(Legacy.Curing.Prios.legacy)
  return true
end
