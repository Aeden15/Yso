-- Auto-exported from Mudlet package script: Orb Defense timer
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Orb Defense timer
--  • Tracks Domination orb defense duration and warnings.
--  • Queues summon/defense through Yso.queue when available.
--========================================================--

Yso = Yso or {}
Yso.dom = Yso.dom or {}
Yso.dom.orbdef = Yso.dom.orbdef or {}

local O = Yso.dom.orbdef

O.cfg = O.cfg or {
  duration   = 35,
  warn_at    = {10, 5, 1},

  gag_lines  = true,
  echo       = true,

  prefix     = "<HotPink>[Domination] ",
  up_color   = "<dodger_blue>",
  warn_color = "<gold>",
  down_color = "<OrangeRed>",

  autolearn      = false,
  autolearn_min  = 10,
  autolearn_max  = 180,
  soft_expire_echo = false,

  cmd_summon  = "summon orb",
  cmd_defense = "command orb",

  queue_mode        = "addclearfull",
  queue_defense     = "class",
  queue_summon_mode = "addclear",
  queue_summon      = "free",
}

O.state = O.state or {
  up         = false,
  started_at = nil,
  expires_at = 0,
  timers     = {},
  src        = "",
}

local function _now()
  if type(getEpoch) == "function" then return getEpoch() end
  return os.time()
end

local function _safe_kill_timer(id)
  if not id then return end
  pcall(function() killTimer(id) end)
end

local function _kill_all()
  if not O.state.timers then O.state.timers = {}; return end
  for _, id in ipairs(O.state.timers) do _safe_kill_timer(id) end
  O.state.timers = {}
end

local function _echo(color, msg)
  if not O.cfg.echo then return end
  cecho(string.format("%s%s%s\n", O.cfg.prefix or "", color or "", msg or ""))
end

local function _send_cmd(cmd)
  cmd = tostring(cmd or "")
  if cmd == "" then return false end
  if type(send) == "function" then
    send(cmd, false)
    return true
  end
  if type(expandAlias) == "function" then
    expandAlias(cmd)
    return true
  end
  return false
end

local function _q(mode, qtype, cmd)
  mode  = tostring(mode  or "addclear"):lower()
  qtype = tostring(qtype or "free")
  cmd   = tostring(cmd   or "")
  if cmd == "" then return false end
  local verb = "ADDCLEAR"
  if mode == "addclearfull" then
    verb = "ADDCLEARFULL"
  elseif mode == "add" then
    verb = "ADD"
  elseif mode == "prepend" then
    verb = "PREPEND"
  elseif mode == "insert" then
    verb = "INSERT"
  elseif mode == "replace" then
    verb = "REPLACE"
  end
  _send_cmd(("QUEUE %s %s %s"):format(verb, qtype, cmd))
  return true
end

local function _schedule(duration)
  duration = tonumber(duration) or O.cfg.duration or 35

  for _, t in ipairs(O.cfg.warn_at or {}) do
    t = tonumber(t)
    if t and t > 0 and t < duration then
      local id = tempTimer(duration - t, function()
        if not O.state.up then return end
        local left = math.floor(O.remaining() + 0.5)
        _echo(O.cfg.warn_color, ("Orb defense: %ds remaining."):format(left))
      end)
      table.insert(O.state.timers, id)
    end
  end

  local id = tempTimer(duration + 0.15, function()
    if not O.state.up then return end
    if O.cfg.soft_expire_echo then
      _echo(O.cfg.warn_color, "Orb defense predicted end reached (awaiting dissipate/remove).")
    end
  end)
  table.insert(O.state.timers, id)
end

function O.remaining()
  if not O.state.up then return 0 end
  local left = (O.state.expires_at or 0) - _now()
  return (left > 0) and left or 0
end

function O.start(duration, src)
  duration = tonumber(duration) or O.cfg.duration or 35
  src = src or "start"

  _kill_all()

  local now = _now()
  O.state.up = true
  O.state.started_at = now
  O.state.expires_at = now + duration
  O.state.src = src

  Yso.defs = Yso.defs or {}
  Yso.defs.orb_defense = true

  _echo(O.cfg.up_color, "ORB DEFENSE UP!")

  _schedule(duration)
end

function O.stop(msg, src)
  src = src or "stop"

  if not O.state.up then
    _kill_all()
    O.state.started_at = nil
    O.state.expires_at = 0
    O.state.src = ""
    Yso.defs = Yso.defs or {}
    Yso.defs.orb_defense = nil
    return
  end

  local now = _now()
  local observed = (O.state.started_at and (now - O.state.started_at)) or 0

  if O.cfg.autolearn
     and observed >= (O.cfg.autolearn_min or 10)
     and observed <= (O.cfg.autolearn_max or 180)
  then
    O.cfg.duration = math.floor(observed + 0.5)
  end

  _kill_all()

  O.state.up = false
  O.state.started_at = nil
  O.state.expires_at = 0
  O.state.src = ""

  Yso.defs = Yso.defs or {}
  Yso.defs.orb_defense = nil

  _echo(O.cfg.down_color, msg or "ORB DEFENSE DISSIPATED.")
end

function O.on_up(duration_override)
  if O.cfg.gag_lines then pcall(deleteLine) end
  O.start(duration_override, "text_up")
end

function O.on_down()
  if O.cfg.gag_lines then pcall(deleteLine) end
  O.stop("ORB DEFENSE DISSIPATED.", "text_down")
end

local function _norm(s)
  return tostring(s or ""):gsub("%s+", "_"):lower()
end

function O.on_gmcp_add(def)
  local name = _norm(def and (def.name or def.id) or def)
  if name == "arctar" or name == "orb_defense" or name == "orbdefense" then
    O.start(tonumber(def and def.duration) or nil, "gmcp_add")
  end
end

function O.on_gmcp_remove(def)
  local name = _norm(def and (def.name or def.id) or def)
  if name == "arctar" or name == "orb_defense" or name == "orbdefense" then
    O.stop("ORB DEFENSE DISSIPATED.", "gmcp_remove")
  end
end

function O.cmd(flag)
  flag = tostring(flag or ""):lower()

  if flag == "s" then
    _q(O.cfg.queue_summon_mode or "addclear", O.cfg.queue_summon, O.cfg.cmd_summon)

  elseif flag == "d" then
    _q(O.cfg.queue_mode, O.cfg.queue_defense, O.cfg.cmd_defense)

  elseif flag == "r" or flag == "t" then
    local left = math.floor(O.remaining() + 0.5)
    _echo(O.cfg.warn_color, ("Orb defense remaining: %ds"):format(left))
  else
    _echo(O.cfg.warn_color, "Usage: orbs (summon), orbd (defense), orbr (remaining)")
  end
end
