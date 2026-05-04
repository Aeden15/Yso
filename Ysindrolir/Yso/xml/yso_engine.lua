--========================================================--
--
-- Responsibilities:
--     (does NOT emit commands; safe during plumbing tests)
--========================================================--

Yso = Yso or {}
Yso.engine = Yso.engine or {}
Yso.state  = Yso.state  or {}

local E = Yso.engine

E.cfg = E.cfg or {
  debug = false,          -- verbose cecho logs
  keep_wake_ring = 20,    -- store last N wakes in state.meta.wake_ring
}

local function _now()
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _dbg(msg)
  if E.cfg.debug then
    cecho(string.format("<dim_grey>[Yso.engine] <reset>%s\n", tostring(msg)))
  end
end

local function _ensure()
  if Yso.state and type(Yso.state.init) == "function" then
    Yso.state.init()
  else
    Yso.state.meta = Yso.state.meta or {}
    Yso.state.meta.dirty = Yso.state.meta.dirty or {}
  end
end

function E.mark_dirty(key)
  _ensure()
  key = tostring(key or "")
  if key == "" then return end
  Yso.state.meta.dirty = Yso.state.meta.dirty or {}
  Yso.state.meta.dirty[key] = true
  Yso.state.meta.last_update = _now()
end

function E.clear_dirty()
  _ensure()
  Yso.state.meta.dirty = {}
end

function E.wake(reason, dirty_key)
  _ensure()
  reason = tostring(reason or "wake")
  if dirty_key then E.mark_dirty(dirty_key) end

  Yso.state.meta.last_wake_at = _now()
  Yso.state.meta.last_wake_reason = reason

  -- ring buffer
  Yso.state.meta.wake_ring = Yso.state.meta.wake_ring or {}
  local ring = Yso.state.meta.wake_ring
  ring[#ring+1] = { at = Yso.state.meta.last_wake_at, reason = reason }
  local keep = tonumber(E.cfg.keep_wake_ring or 20) or 20
  while #ring > keep do table.remove(ring, 1) end

  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    Yso.pulse.wake(reason)
  end

  _dbg("wake: "..reason)
end

function E.tick(reasons)
  _ensure()
  local ts = _now()

  -- Bookkeeping
  Yso.state.meta.tick_id = (tonumber(Yso.state.meta.tick_id) or 0) + 1
  Yso.state.meta.last_tick_at = ts
  Yso.state.meta.reasons = {}
  if type(reasons) == "table" then
    for _,r in ipairs(reasons) do Yso.state.meta.reasons[tostring(r)] = true end
  end

  -- Mirror pulse lane readiness into state.queue.lanes (for debug + planning)
  if Yso.pulse and Yso.pulse.state and type(Yso.pulse.state.lanes) == "table" then
    Yso.state.queue = Yso.state.queue or {}
    Yso.state.queue.lanes = Yso.state.queue.lanes or {}
    for lane, L in pairs(Yso.pulse.state.lanes) do
      Yso.state.queue.lanes[lane] = Yso.state.queue.lanes[lane] or {}
      Yso.state.queue.lanes[lane].ready = (L.ready == true)
      Yso.state.queue.lanes[lane].pending = (L.pending == true)
      if lane == "class" then
        Yso.state.queue.lanes[lane].inflight = (L.inflight == true)
      end
    end
    Yso.state.queue.last_update = ts
  end

  -- Mirror queue model if present (Yso.queue is authoritative for list parser)
  if Yso.queue and type(Yso.queue.model) == "table" then
    Yso.state.queue = Yso.state.queue or {}
    Yso.state.queue.model = Yso.state.queue.model or {}
    for k,v in pairs(Yso.queue.model) do Yso.state.queue.model[k] = v end
    Yso.state.queue.model.last_update = ts
  end

  -- Clear dirty at end of tick (Phase 1: nothing consumes it yet)
  local dirty = Yso.state.meta.dirty or {}
  local dirty_count = 0
  for _ in pairs(dirty) do dirty_count = dirty_count + 1 end
  if dirty_count > 0 then
    _dbg("tick "..Yso.state.meta.tick_id.." dirty="..dirty_count)
  end
  Yso.state.meta.dirty = {}
end

-- Register into pulse (order 0 = first)
if Yso.pulse and type(Yso.pulse.register) == "function" then
  Yso.pulse.register("engine.tick", function(reasons)
    local ok,err = pcall(E.tick, reasons)
    if not ok then _dbg("ERR tick: "..tostring(err)) end
  end, { order = 0 })
end


-- Compatibility: older modules may call Yso.offense.request_tick()
Yso.offense = Yso.offense or {}
if type(Yso.offense.request_tick) ~= "function" then
  function Yso.offense.request_tick(reason)
    E.wake("offense:"..tostring(reason or "tick"))
  end
end

_dbg("engine loaded")
--========================================================--
