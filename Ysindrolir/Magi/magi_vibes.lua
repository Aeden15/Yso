--========================================================--
-- Magi - Mass vibe embed helper
--
-- Purpose:
--   - Drive a `vibeds`-style alias from one function call.
--   - Sequentially send a room-vibration embed list on a fixed EQ cadence.
--   - Keep the command list and delay configurable in one place.
--
-- Default timing:
--   - Standard embed recovery is 4.00s.
--   - Current artifact-adjusted recovery is 3.40s, which is the default here.
--
-- Suggested Mudlet alias body:
--   Yso.magi.vibes.run()
--
-- Optional helpers:
--   Yso.magi.vibes.stop()
--   Yso.magi.vibes.set_delay(3.40)
--   Yso.magi.vibes.run({ "embed creeps", "embed oscillate" })
--
-- Default sequence:
--   Matches the current live vibeds room-state target, including the
--   expanded tail after revelation.
--========================================================--

Yso = Yso or {}
Yso.magi = Yso.magi or {}

local M = Yso.magi
M.vibes = M.vibes or {}

local V = M.vibes

V.cfg = V.cfg or {
  debug = false,
  eq_delay = 3.40,
  start_delay = 0.00,
  require_magi = true,
  default_commands = {
    "embed creeps",
    "embed oscillate",
    "embed disorientation",
    "embed energise",
    "embed forest",
    "embed dissonance",
    "embed plague",
    "embed lullaby",
    "embed revelation",
    "embed tremors",
    "embed heat",
    "embed dissipate",
    "embed reverberation",
    "embed adduction",
    "embed palpitation",
  },
}

V.state = V.state or {
  running = false,
  timers = {},
  started_at = 0,
}

local function _now()
  if type(getEpoch) == "function" then
    local v = tonumber(getEpoch()) or os.time()
    if v > 20000000000 then v = v / 1000 end
    return v
  end
  return os.time()
end

local function _echo(msg, color)
  if type(cecho) == "function" then
    if color then
      cecho(string.format("%s[Yso:Magi:Vibes] %s<reset>\n", tostring(color), tostring(msg)))
      return
    end
    if V.cfg and V.cfg.debug then
      cecho(string.format("<gray>[Yso:Magi:Vibes] %s<reset>\n", tostring(msg)))
    end
  end
end

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _kill_timer(id)
  if not id then return end
  if type(killTimer) == "function" then
    pcall(killTimer, id)
  end
end

local function _clear_timers()
  if type(V.state.timers) ~= "table" then
    V.state.timers = {}
    return
  end
  for _, id in ipairs(V.state.timers) do
    _kill_timer(id)
  end
  V.state.timers = {}
end

local function _copy_commands(list)
  local out = {}
  for _, cmd in ipairs(list or {}) do
    cmd = _trim(cmd)
    if cmd ~= "" then
      out[#out + 1] = cmd
    end
  end
  return out
end

local function _resolve_commands(list)
  if type(list) == "table" and #list > 0 then
    return _copy_commands(list)
  end
  return _copy_commands(V.cfg.default_commands or {})
end

local function _current_class()
  if Yso and Yso.classinfo and type(Yso.classinfo.current_class) == "function" then
    local ok, cls = pcall(Yso.classinfo.current_class)
    if ok and type(cls) == "string" and cls ~= "" then return cls end
  end

  local g = rawget(_G, "gmcp")
  local cls = g and g.Char and g.Char.Status and g.Char.Status.class or nil
  if type(cls) == "string" and cls ~= "" then return cls end

  if type(Yso.class) == "string" and Yso.class ~= "" then return Yso.class end
  return ""
end

local function _is_magi()
  if Yso and Yso.classinfo and type(Yso.classinfo.is_magi) == "function" then
    local ok, res = pcall(Yso.classinfo.is_magi)
    if ok then return res == true end
  end
  return _current_class():lower() == "magi"
end

local function _send_cmd(cmd)
  if type(send) == "function" then
    send(cmd, false)
    return true
  end
  return false
end

local function _schedule(delay, fn)
  if type(tempTimer) ~= "function" then
    return nil, "no_tempTimer"
  end
  local ok, timer_id = pcall(tempTimer, delay, fn)
  if ok then return timer_id end
  return nil, timer_id
end

function V.is_running()
  return V.state.running == true
end

function V.stop()
  _clear_timers()
  V.state.running = false
  _echo("stopped")
  return true
end

function V.set_delay(seconds)
  seconds = tonumber(seconds)
  if not seconds or seconds <= 0 then return false end
  V.cfg.eq_delay = seconds
  _echo(string.format("eq_delay=%.2f", seconds))
  return true
end

function V.run(commands, opts)
  opts = type(opts) == "table" and opts or {}

  if opts.require_magi ~= false and V.cfg.require_magi ~= false and not _is_magi() then
    _echo("skipping run: current class is not Magi", "<red>")
    return false, "wrong_class"
  end

  local list = _resolve_commands(commands)
  if #list == 0 then
    return false, "no_commands"
  end

  local eq_delay = tonumber(opts.eq_delay) or tonumber(V.cfg.eq_delay) or 3.40
  if eq_delay <= 0 then eq_delay = 3.40 end

  local start_delay = tonumber(opts.start_delay)
  if start_delay == nil then
    start_delay = tonumber(V.cfg.start_delay) or 0
  end
  if start_delay < 0 then start_delay = 0 end

  V.stop()
  V.state.running = true
  V.state.started_at = _now()

  local function dispatch(idx)
    if V.state.running ~= true then return end

    local cmd = list[idx]
    if not cmd then
      V.state.running = false
      _clear_timers()
      _echo("complete")
      return
    end

    if not _send_cmd(cmd) then
      V.state.running = false
      _clear_timers()
      _echo("send() unavailable", "<red>")
      return
    end

    _echo(string.format("sent[%d/%d]: %s", idx, #list, cmd))

    if idx >= #list then
      V.state.running = false
      _clear_timers()
      return
    end

    local next_id = _schedule(eq_delay, function()
      dispatch(idx + 1)
    end)

    if next_id then
      V.state.timers[#V.state.timers + 1] = next_id
      return
    end

    V.state.running = false
    _clear_timers()
    _echo("tempTimer unavailable", "<red>")
  end

  local first_delay = start_delay
  if first_delay <= 0 then
    dispatch(1)
    return true
  end

  local first_id = _schedule(first_delay, function()
    dispatch(1)
  end)

  if not first_id then
    V.state.running = false
    _clear_timers()
    _echo("tempTimer unavailable", "<red>")
    return false, "no_tempTimer"
  end

  V.state.timers[#V.state.timers + 1] = first_id
  return true
end

return V
