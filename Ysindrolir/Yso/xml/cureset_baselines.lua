-- Auto-exported from Mudlet package script: Cureset Baselines
-- DO NOT EDIT IN XML; edit this file instead.

Legacy = Legacy or {}
Legacy.Curing = Legacy.Curing or {}
Legacy.Curing.Prios = Legacy.Curing.Prios or {}

Legacy.Curing.ActiveServerSet = Legacy.Curing.ActiveServerSet or "legacy"
Legacy.Curing.Prios.baseSets  = Legacy.Curing.Prios.baseSets  or {}
Legacy.Curing.Prios.capture   = Legacy.Curing.Prios.capture   or { active=false, set=nil, lastPrio=nil }

function Legacy.Curing.Prios.UseBaseline(set)
  set = (set or Legacy.Curing.ActiveServerSet or "legacy"):lower()
  local base = Legacy.Curing.Prios.baseSets[set]
  if not base then return false end

  -- This is what Reprio() uses as “default”
  Legacy.Curing.Prios.legacy = base
  return true
end

function Legacy.Curing.SwitchServerSet(set)
  set = (set or "legacy"):lower()
  local changed = (Legacy.Curing.ActiveServerSet ~= set)

  if changed then
    Legacy.Curing.ActiveServerSet = set
    send("curingset switch " .. set)
  end

  -- If we don't have a baseline cached for this set, pull it once.
  if not Legacy.Curing.Prios.baseSets[set] then
    tempTimer(0.2, function() send("curing priority list") end)
  else
    -- Apply baseline only when transitioning, or if legacy baseline isn't already pointing at this base set.
    if changed or Legacy.Curing.Prios.legacy ~= Legacy.Curing.Prios.baseSets[set] then
      Legacy.Curing.Prios.UseBaseline(set)
    end
  end
end

