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

local function _warn_baseline_missing_once_per_set(set)
  local P = Legacy.Curing.Prios
  P._baseline_warned_sets = type(P._baseline_warned_sets) == "table" and P._baseline_warned_sets or {}
  if P._baseline_warned_sets[set] == true then return false end
  P._baseline_warned_sets[set] = true
  return true
end

function Legacy.Curing.Prios.ApplyCapturedBaseline(set, opts)
  opts = type(opts) == "table" and opts or {}
  local warn = (opts.warn ~= false)

  local P = Legacy.Curing.Prios
  set = tostring(set or Legacy.Curing.ActiveServerSet or "legacy"):lower()

  local applied = false

  if type(P.UseBaseline) == "function" then
    local ok, res = pcall(P.UseBaseline, set)
    applied = ok and (res ~= false)
  end

  if not applied and type(Legacy.Curing.UseBaseline) == "function" then
    local ok, res = pcall(Legacy.Curing.UseBaseline, set)
    applied = ok and (res ~= false)
  end

  if not applied then
    local base = type(P.baseSets) == "table" and P.baseSets[set] or nil
    if type(base) == "table" then
      P.legacy = base

      local temp_copy = nil
      if type(table) == "table" and type(table.deepcopy) == "function" then
        local ok, tmp = pcall(table.deepcopy, base)
        if ok and type(tmp) == "table" then
          temp_copy = tmp
        end
      end
      -- Never alias temp to legacy when deepcopy is unavailable.
      P.temp = temp_copy
      applied = true
    end
  end

  local warned = false
  if not applied and warn then
    if _warn_baseline_missing_once_per_set(set) then
      warned = true
      if type(cecho) == "function" then
        cecho("\n<white>[<gold>Legacy<white>]: Baseline sync warning: could not activate baseline for cureset '" .. set .. "'.")
      end
    end
  end

  return applied, set, warned
end
