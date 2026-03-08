-- Auto-exported from Mudlet package script: Magician heal
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso Magician Module (Tarot)
--  • Auto mana-heal with Magician using GMCP.
--  • Condition: mana < mp_threshold AND hp > hp_min.
--  • Default: mp_threshold = 35%, hp_min = 75%.
--  • Uses QUEUE ADDCLEARFULL bu:
--       - overrides all queues
--       - requires BAL + UPRIGHT (not prone)
--========================================================--

Yso = Yso or {}
Yso.queue    = Yso.queue or {}
Yso.magician = Yso.magician or {}
Yso._eh      = Yso._eh or {}

local M = Yso.magician

-- ---------- config + state ----------

M.cfg = M.cfg or {
  enabled      = true,   -- auto mana-heal on/off
  mp_threshold = 35,     -- if mana % <= this
  hp_min       = 75,     -- AND hp % >= this
  gcd          = 5,      -- seconds between auto-queues
  debug        = false,
}

M._last_auto_time = M._last_auto_time or 0

-- ---------- tiny helpers ----------

local function _now()
  if type(getEpoch) == "function" then return getEpoch() end
  return os.time()
end

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _vitals()
  return (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
end

local function _hp_percent()
  local v = _vitals()
  local hp    = tonumber(v.hp) or 0
  local maxhp = tonumber(v.maxhp) or 0
  if maxhp <= 0 then return nil end
  return math.floor((hp / maxhp) * 100 + 0.5)
end

local function _mp_percent()
  local v = _vitals()
  local mp    = tonumber(v.mp) or 0
  local maxmp = tonumber(v.maxmp) or 0
  if maxmp <= 0 then return nil end
  return math.floor((mp / maxmp) * 100 + 0.5)
end

-- class-tag prefix like [OCCULTIST]:
local function _current_class()
  local cls

  if gmcp and gmcp.Char then
    if gmcp.Char.Status and gmcp.Char.Status.class then
      cls = gmcp.Char.Status.class
    elseif gmcp.Char.Vitals and gmcp.Char.Vitals.class then
      cls = gmcp.Char.Vitals.class
    end
  end

  if not cls or cls == "" then
    cls = Yso.class or "Unknown"
  end

  return tostring(cls):upper()
end

local function _tag_prefix()
  local cls = _current_class()
  return string.format("<DarkOrchid>[%s]:<reset> ", cls)
end

local function _is_occultist()
  if Yso and Yso.classinfo and type(Yso.classinfo.is_occultist) == "function" then
    return Yso.classinfo.is_occultist()
  end
  return _current_class() == "OCCULTIST"
end

local function _echo(msg)
  if M.cfg.debug then
    cecho(_tag_prefix() .. "<cyan>" .. msg .. "<reset>\n")
  end
end

local function _info(msg)
  cecho(_tag_prefix() .. msg .. "<reset>\n")
end

local function _safe(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then
      cecho(string.format(
        "%s<red>Magician error: %s<reset>\n",
        _tag_prefix(), tostring(err)
      ))
    end
  end
end

-- queue helper: override everything, require BAL + UPRIGHT
local function _queue_addclearfull_bu(cmd)
  cmd = _trim(cmd or "")
  if cmd == "" then return false end

  if Yso.queue and type(Yso.queue.addclearfull) == "function" then
    Yso.queue.addclearfull("bu", cmd)
    return true
  end

  _info("<red>Yso.queue not loaded; cannot queue Magician.")
  return false
end

-- ---------- core actions ----------

-- Self mana heal: FLING MAGICIAN AT ME
function M.queue_self()
  if not _is_occultist() then
    _echo("Skipping Magician queue: current class is not Occultist.")
    return false
  end
  local cmd = "FLING MAGICIAN AT ME"
  if _queue_addclearfull_bu(cmd) then
    _info("<green>Queued Magician mana-heal.<reset>")
    return true
  end
  return false
end

-- Optional: Magician at someone else (no gmcp checks)
function M.queue_target(name)
  if not _is_occultist() then
    _echo("Skipping Magician target queue: current class is not Occultist.")
    return false
  end
  name = _trim(name or "")
  name = name:match("^(%S+)$") or name
  if name == "" then
    _info("<red>No target given for Magician.<reset>")
    return
  end

  local cmd = "FLING MAGICIAN AT " .. name
  if _queue_addclearfull_bu(cmd) then
    _info(string.format("<green>Queued Magician on <yellow>%s<green>.<reset>", name))
    return true
  end
  return false
end

-- ---------- auto mana-heal on GMCP vitals ----------

function M.on_vitals()
  if not M.cfg.enabled then return end
  if not _is_occultist() then return end

  local hp = _hp_percent()
  local mp = _mp_percent()
  if not hp or not mp then return end
  if hp <= 0 then return end        -- dead / invalid

  -- Condition: mp < threshold AND hp > hp_min
  if mp > (M.cfg.mp_threshold or 35) then return end
  if hp < (M.cfg.hp_min or 75) then return end

  local now = _now()
  if (now - (M._last_auto_time or 0)) < (M.cfg.gcd or 5) then
    return
  end

  M._last_auto_time = now
  _echo(string.format(
    "Auto Magician trigger: HP %d%% >= %d%% and MP %d%% <= %d%%",
    hp, M.cfg.hp_min or 75, mp, M.cfg.mp_threshold or 35
  ))
  M.queue_self()
end

-- (Re)register GMCP handler
if Yso._eh.magician_vitals then
  killAnonymousEventHandler(Yso._eh.magician_vitals)
end
Yso._eh.magician_vitals = registerAnonymousEventHandler(
  "gmcp.Char.Vitals",
  _safe(M.on_vitals)
)

-- ---------- user-facing toggles ----------

function M.toggle_auto()
  M.cfg.enabled = not M.cfg.enabled
  local state = M.cfg.enabled and "ON" or "OFF"
  _info(string.format("<yellow>Auto-Magician is now %s.<reset>", state))
end

function M.set_mp_threshold(percent)
  percent = tonumber(percent)
  if not percent or percent <= 0 or percent > 100 then
    _info("<red>Usage: lua Yso.magician.set_mp_threshold(<1-100>)<reset>")
    return
  end
  M.cfg.mp_threshold = percent
  _info(string.format("<yellow>Magician mp threshold set to %d%%.<reset>", percent))
end

function M.set_hp_min(percent)
  percent = tonumber(percent)
  if not percent or percent <= 0 or percent > 100 then
    _info("<red>Usage: lua Yso.magician.set_hp_min(<1-100>)<reset>")
    return
  end
  M.cfg.hp_min = percent
  _info(string.format("<yellow>Magician hp minimum set to %d%%.<reset>", percent))
end

cecho(_tag_prefix() .. "<cyan>Yso Magician module loaded (bu queue).<reset>\n")
--========================================================--
