--========================================================--
-- Magi - Mass vibe embed helper
--
-- Smart behavior:
--   - `run_missing()` checks room VIBES and embeds only missing targets.
--   - XML alias `^vibed$` is the canonical entrypoint.
--========================================================--

Yso = Yso or {}
Yso.magi = Yso.magi or {}

local M = Yso.magi
M.vibes = M.vibes or {}
local V = M.vibes

local function _now()
  if type(getEpoch) == "function" then
    local v = tonumber(getEpoch()) or os.time()
    if v > 20000000000 then v = v / 1000 end
    return v
  end
  return os.time()
end

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _lc(s)
  return _trim(s):lower()
end

local function _strip_ansi(s)
  s = tostring(s or "")
  s = s:gsub("\27%[[%d;]*[A-Za-z]", "")
  return s
end

local function _echo(msg, color, always)
  if type(cecho) ~= "function" then return end
  if color then
    cecho(string.format("%s[Yso:Magi:Vibes] %s<reset>\n", tostring(color), tostring(msg)))
  elseif always == true then
    cecho(string.format("<white>[Yso:Magi:Vibes] %s<reset>\n", tostring(msg)))
  elseif V.cfg and V.cfg.debug then
    cecho(string.format("<gray>[Yso:Magi:Vibes] %s<reset>\n", tostring(msg)))
  end
end

V._targets = V._targets or {
  { key = "reverberation", cmd = "embed reverberation" },
  { key = "creeps", cmd = "embed creeps" },
  { key = "oscillate", cmd = "embed oscillate" },
  { key = "disorientation", cmd = "embed disorientation" },
  { key = "energise", cmd = "embed energise" },
  { key = "forest", cmd = "embed forest" },
  { key = "dissonance", cmd = "embed dissonance" },
  { key = "plague", cmd = "embed plague" },
  { key = "lullaby", cmd = "embed lullaby" },
  { key = "revelation", cmd = "embed revelation" },
  { key = "tremors", cmd = "embed tremors" },
  { key = "heat", cmd = "embed heat" },
  { key = "harmony", cmd = "embed harmony healing" },
  { key = "gravity", cmd = "embed gravity" },
  { key = "dissipate", cmd = "embed dissipate" },
  { key = "adduction", cmd = "embed adduction" },
  { key = "palpitation", cmd = "embed palpitation" },
}

local function _default_commands_from_targets()
  local out = {}
  for i = 1, #V._targets do
    out[#out + 1] = V._targets[i].cmd
  end
  return out
end

V.cfg = V.cfg or {}
V.cfg.debug = V.cfg.debug == true
V.cfg.eq_delay = tonumber(V.cfg.eq_delay) or 3.40
V.cfg.start_delay = tonumber(V.cfg.start_delay) or 0.00
V.cfg.require_magi = (V.cfg.require_magi ~= false)
V.cfg.install_aliases = false -- XML aliases are canonical.
V.cfg.check_before_embed = (V.cfg.check_before_embed ~= false)
V.cfg.scan_timeout = tonumber(V.cfg.scan_timeout) or 2.50
V.cfg.scan_prompt_defer = tonumber(V.cfg.scan_prompt_defer) or 0.05
V.cfg.fallback_full_on_scan_fail = (V.cfg.fallback_full_on_scan_fail ~= false)
V.cfg.vibes_list_eq_cost = tonumber(V.cfg.vibes_list_eq_cost) or 0.85
V.cfg.eq_wait_timeout = tonumber(V.cfg.eq_wait_timeout) or 5.00
V.cfg.eq_wait_poll = tonumber(V.cfg.eq_wait_poll) or 0.10
V.cfg.default_commands = _default_commands_from_targets()

V.state = V.state or {}
V.state.running = (V.state.running == true)
V.state.timers = type(V.state.timers) == "table" and V.state.timers or {}
V.state.started_at = tonumber(V.state.started_at) or 0
V.state.scan = type(V.state.scan) == "table" and V.state.scan or nil
V.state.eq_wait = type(V.state.eq_wait) == "table" and V.state.eq_wait or nil
V._alias = type(V._alias) == "table" and V._alias or {}

V._lookup = {}
for i = 1, #V._targets do
  V._lookup[V._targets[i].key] = V._targets[i]
end

if V._alias.embed and type(killAlias) == "function" then
  pcall(killAlias, V._alias.embed)
  V._alias.embed = nil
end

local function _kill_timer(id)
  if id and type(killTimer) == "function" then pcall(killTimer, id) end
end

local function _kill_trigger(id)
  if id and type(killTrigger) == "function" then pcall(killTrigger, id) end
end

local function _kill_eh(id)
  if id and type(killAnonymousEventHandler) == "function" then pcall(killAnonymousEventHandler, id) end
end

local function _schedule(delay, fn)
  if type(tempTimer) ~= "function" then return nil end
  local ok, tid = pcall(tempTimer, delay, fn)
  if ok then return tid end
  return nil
end

local function _clear_timers()
  for _, id in ipairs(V.state.timers) do _kill_timer(id) end
  V.state.timers = {}
end

local function _copy_commands(list)
  local out = {}
  for _, cmd in ipairs(list or {}) do
    cmd = _trim(cmd)
    if cmd ~= "" then out[#out + 1] = cmd end
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
  if type(send) ~= "function" then return false end
  send(cmd, false)
  return true
end

function V.eq_ready()
  local v = (rawget(_G, "gmcp") or {}).Char
  v = v and v.Vitals or {}
  local eq = v.eq
  if eq == nil then eq = v.equilibrium end
  return tostring(eq or "") == "1" or eq == true
end

function V._teardown_scan()
  local sc = V.state.scan
  if type(sc) ~= "table" then
    V.state.scan = nil
    return
  end
  _kill_trigger(sc.line_trigger)
  _kill_eh(sc.prompt_eh)
  _kill_timer(sc.timeout_timer)
  _kill_timer(sc.defer_timer)
  V.state.scan = nil
end

function V._teardown_eq_wait()
  local ew = V.state.eq_wait
  if type(ew) ~= "table" then
    V.state.eq_wait = nil
    return
  end
  _kill_timer(ew.poll_timer)
  _kill_timer(ew.timeout_timer)
  _kill_trigger(ew.recovery_trigger)
  _kill_eh(ew.vitals_eh)
  V.state.eq_wait = nil
end

function V.stop()
  _clear_timers()
  V._teardown_scan()
  V._teardown_eq_wait()
  V.state.running = false
  _echo("stopped", nil, true)
  return true
end

function V.set_delay(seconds)
  seconds = tonumber(seconds)
  if not seconds or seconds <= 0 then return false end
  V.cfg.eq_delay = seconds
  _echo(string.format("eq_delay=%.2f", seconds), nil, true)
  return true
end

function V.wait_eq_then(fn, opts)
  opts = type(opts) == "table" and opts or {}
  if type(fn) ~= "function" then return false, "no_fn" end
  V._teardown_eq_wait()
  if V.eq_ready() then
    fn()
    return true
  end

  _echo("waiting for equilibrium…", nil, true)
  local ew = { started_at = _now(), cb = fn }
  V.state.eq_wait = ew
  local timeout = tonumber(opts.timeout) or V.cfg.eq_wait_timeout
  local poll = tonumber(opts.poll) or V.cfg.eq_wait_poll

  local function _on_timeout()
    if V.state.eq_wait ~= ew then return end
    V._teardown_eq_wait()
    if type(opts.on_timeout) == "function" then pcall(opts.on_timeout) end
  end

  local function _fire_if_ready()
    if V.state.eq_wait ~= ew then return false end
    if not V.eq_ready() then return false end
    local cb = ew.cb
    V._teardown_eq_wait()
    if cb then pcall(cb) end
    return true
  end

  local function _poll_loop()
    if _fire_if_ready() then return end
    if (_now() - ew.started_at) >= timeout then
      _on_timeout()
      return
    end
    ew.poll_timer = _schedule(poll, _poll_loop)
  end

  if type(tempRegexTrigger) == "function" then
    ew.recovery_trigger = tempRegexTrigger([[^You have recovered equilibrium\.?$]], function()
      _schedule(0.03, _fire_if_ready)
    end)
  end
  if type(registerAnonymousEventHandler) == "function" then
    ew.vitals_eh = registerAnonymousEventHandler("gmcp.Char.Vitals", _fire_if_ready)
  end
  ew.timeout_timer = _schedule(timeout, _on_timeout)
  ew.poll_timer = _schedule(poll, _poll_loop)
  return true
end

function V.note_line(line)
  local sc = V.state.scan
  if type(sc) ~= "table" or sc.active ~= true then return false end
  line = _strip_ansi(line)
  local lc = _lc(line)
  if lc == "" then return false end

  if lc:find("the following vibrations reside here", 1, true) then return true end
  if lc:match("^vibration") and lc:find("owner", 1, true) and lc:find("timer", 1, true) then
    sc.in_table = true
    return true
  end
  if lc:match("^equilibrium used:") then
    sc.saw_footer = true
    _kill_timer(sc.defer_timer)
    sc.defer_timer = _schedule(V.cfg.scan_prompt_defer, function()
      if V.state.scan == sc and sc.active == true then
        V.finish_scan("footer")
      end
    end)
    return true
  end
  if line:match("^%-+$") then return true end
  if not sc.in_table then return false end

  local token = line:match("^%s*([%a][%a']*)")
  if not token then return false end
  local key = _lc(token)
  if V._lookup[key] then
    sc.present[key] = true
    return true
  end
  return false
end

function V.begin_scan(on_done)
  V._teardown_scan()
  local sc = {
    active = true,
    present = {},
    in_table = false,
    on_done = on_done,
  }
  V.state.scan = sc

  if type(tempRegexTrigger) == "function" then
    sc.line_trigger = tempRegexTrigger([[^.+$]], function()
      if type(getCurrentLine) == "function" then
        V.note_line(getCurrentLine())
      end
    end)
  end
  if type(registerAnonymousEventHandler) == "function" then
    sc.prompt_eh = registerAnonymousEventHandler("sysPrompt", function()
      if V.state.scan ~= sc then return end
      _kill_timer(sc.defer_timer)
      sc.defer_timer = _schedule(V.cfg.scan_prompt_defer, function()
        V.finish_scan("prompt")
      end)
    end)
  end
  sc.timeout_timer = _schedule(V.cfg.scan_timeout, function()
    if V.state.scan ~= sc then return end
    sc.scan_failed = "timeout"
    V.finish_scan("timeout")
  end)
  return true
end

function V.finish_scan(reason)
  local sc = V.state.scan
  if type(sc) ~= "table" or sc.active ~= true then return false end
  sc.active = false

  local present_count = 0
  for _, t in ipairs(V._targets) do
    if sc.present[t.key] == true then present_count = present_count + 1 end
  end
  local missing = {}
  for _, t in ipairs(V._targets) do
    if sc.present[t.key] ~= true then missing[#missing + 1] = t.cmd end
  end
  local cb = sc.on_done
  local failed = sc.scan_failed
  V._teardown_scan()

  if type(cb) == "function" then
    pcall(cb, {
      reason = reason,
      failed = failed,
      present_count = present_count,
      missing_commands = missing,
    })
  end
  return true
end

function V.run(commands, opts)
  opts = type(opts) == "table" and opts or {}
  if opts.require_magi ~= false and V.cfg.require_magi ~= false and not _is_magi() then
    _echo("skipping run: current class is not Magi", "<red>")
    return false, "wrong_class"
  end

  local list = _resolve_commands(commands)
  if #list == 0 then return false, "no_commands" end
  local eq_delay = tonumber(opts.eq_delay) or V.cfg.eq_delay
  if eq_delay <= 0 then eq_delay = 3.40 end
  local start_delay = tonumber(opts.start_delay)
  if start_delay == nil then start_delay = V.cfg.start_delay end
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
      _echo("complete", nil, true)
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
      _echo("complete", nil, true)
      return
    end
    local tid = _schedule(eq_delay, function() dispatch(idx + 1) end)
    if tid then
      V.state.timers[#V.state.timers + 1] = tid
      return
    end
    V.state.running = false
    _clear_timers()
    _echo("tempTimer unavailable", "<red>")
  end

  if start_delay <= 0 then
    dispatch(1)
    return true
  end
  local first = _schedule(start_delay, function() dispatch(1) end)
  if not first then
    V.state.running = false
    _clear_timers()
    return false, "no_tempTimer"
  end
  V.state.timers[#V.state.timers + 1] = first
  return true
end

function V.run_missing(opts)
  opts = type(opts) == "table" and opts or {}
  local now = _now()
  V.state._run_missing_lock_until = tonumber(V.state._run_missing_lock_until or 0) or 0
  if now < V.state._run_missing_lock_until then
    return false, "dedup_locked"
  end
  V.state._run_missing_lock_until = now + 0.40

  if opts.require_magi ~= false and V.cfg.require_magi ~= false and not _is_magi() then
    _echo("skipping run: current class is not Magi", "<red>")
    return false, "wrong_class"
  end

  V.stop()
  _echo("checking room (VIBES)…", nil, true)

  local function _after_scan(result)
    result = type(result) == "table" and result or {}
    if result.failed then
      _echo("scan failed; fallback full embed list", "<red>", true)
      if V.cfg.fallback_full_on_scan_fail ~= false then
        V.wait_eq_then(function()
          V.run(nil, opts)
        end, {
          on_timeout = function() _echo("eq wait timed out before fallback", "<red>") end,
        })
      end
      return
    end

    local missing = result.missing_commands or {}
    if #missing == 0 then
      _echo(string.format("all target vibrations present (%d/%d)", tonumber(result.present_count) or 0, #V._targets), nil, true)
      return
    end
    _echo(string.format("present: %d/%d; embedding %d", tonumber(result.present_count) or 0, #V._targets, #missing), nil, true)
    V.wait_eq_then(function()
      V.run(missing, opts)
    end, {
      on_timeout = function() _echo("eq wait timed out before embed", "<red>") end,
    })
  end

  V.wait_eq_then(function()
    V.begin_scan(_after_scan)
    if not _send_cmd("vibes") then
      if V.state.scan then
        V.state.scan.scan_failed = "no_send"
        V.finish_scan("no_send")
      end
      return
    end
  end, {
    on_timeout = function()
      _echo("eq wait timed out before VIBES", "<red>")
      if V.cfg.fallback_full_on_scan_fail ~= false then
        V.run(nil, opts)
      end
    end,
  })
  return true
end

-- Keep tempAlias support for manual use, but disabled by default.
local function _kill_vibes_alias(id)
  if id then pcall(killAlias, id) end
end

function V.install_aliases()
  if V.cfg and V.cfg.install_aliases == false then return false end
  if type(tempAlias) ~= "function" then return false end
  _kill_vibes_alias(V._alias.embed)
  V._alias.embed = tempAlias([[^vibed$]], function()
    pcall(V.run_missing)
  end)
  return true
end

V.install_aliases()

return V
