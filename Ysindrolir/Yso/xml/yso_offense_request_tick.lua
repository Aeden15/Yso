--========================================================--
--========================================================--

Yso = Yso or {}
Yso.offense = Yso.offense or {}
Yso.state = Yso.state or {}

local function _now()
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _append_reason(old, new)
  old = tostring(old or "")
  new = tostring(new or "")
  if new == "" then return old end
  if old == "" then return new end
  -- keep it short-ish
  if #old > 160 then return old end
  return old .. "|" .. new
end

-- Provide tick stub if not present yet (Step 4 will replace)
Yso.offense.tick = Yso.offense.tick or function(_reason) end

function Yso.offense.request_tick(reason)
  Yso.state.init()
  local meta = Yso.state.meta
  reason = tostring(reason or "")

  meta.pending_reason = _append_reason(meta.pending_reason, reason)

  if meta.pending_tick then
    return false -- already scheduled
  end

  meta.pending_tick = true

  -- Coalesce to next engine cycle (0-delay timer)
  tempTimer(0, function()
    -- Clear pending BEFORE running tick (so tick can re-request safely)
    Yso.state.init()
    local m = Yso.state.meta
    m.pending_tick = false

    local r = m.pending_reason
    m.pending_reason = ""
    m.last_tick = _now()

    -- Run offense evaluation
    if type(Yso.offense.tick) == "function" then
      pcall(Yso.offense.tick, r)
    end
  end)

  return true
end

--========================================================--
