-- Auto-exported from Mudlet package script: Priestess heal
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso Priestess Module (Tarot)
--  • Auto self-heal with Priestess at low HP (GMCP).
--  • Manual heal: self or another adventurer.
--  • Uses QUEUE ADDCLEARFULL bu to override all queues.
--  • bu = balance + upright (not prone), no eq requirement.
--========================================================--

Yso = Yso or {}
Yso.queue = Yso.queue or {}   -- expected from Yso Queue module
Yso.priestess = Yso.priestess or {}
Yso._eh = Yso._eh or {}

local P = Yso.priestess

-- ---------- config + state ----------

P.cfg = P.cfg or {
  enabled   = true,   -- auto self-heal on/off
  threshold = 40,     -- HP% threshold
  gcd       = 5,      -- seconds between auto-queues
  debug     = false,
}

P._last_auto_time = P._last_auto_time or 0

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
  if P.cfg.debug then
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
        "%s<red>Priestess error: %s<reset>\n",
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
    -- 'bu' = balance + upright (not prone)
    Yso.queue.addclearfull("bu", cmd)
    return true
  end

  _info("<red>Yso.queue not loaded; cannot queue Priestess heal.")
  return false
end

-- ---------- core actions ----------

-- Self heal: FLING PRIESTESS AT ME (override queues, not prone)
function P.queue_self()
  if not _is_occultist() then
    _echo("Skipping Priestess queue: current class is not Occultist.")
    return false
  end
  local cmd = "FLING PRIESTESS AT ME"
  if _queue_addclearfull_bu(cmd) then
    _info("<green>Queued Priestess self-heal.<reset>")
    return true
  end
  return false
end

-- Heal another player: FLING PRIESTESS AT <target> (no gmcp checks)
function P.queue_target(name)
  if not _is_occultist() then
    _echo("Skipping Priestess target queue: current class is not Occultist.")
    return false
  end
  name = _trim(name or "")
  name = name:match("^(%S+)$") or name
  if name == "" then
    _info("<red>No target given for Priestess heal.<reset>")
    return
  end

  local cmd = "FLING PRIESTESS AT " .. name
  if _queue_addclearfull_bu(cmd) then
    _info(string.format("<green>Queued Priestess heal on <yellow>%s<green>.<reset>", name))
    return true
  end
  return false
end

-- ---------- auto self-heal on GMCP vitals ----------

function P.on_vitals()
  if not P.cfg.enabled then return end
  if not _is_occultist() then return end

  local hp = _hp_percent()
  if not hp then return end
  if hp <= 0 then return end       -- dead / invalid
  if hp > (P.cfg.threshold or 40) then return end

  local now = _now()
  if (now - (P._last_auto_time or 0)) < (P.cfg.gcd or 5) then
    return
  end

  P._last_auto_time = now
  _echo(string.format("Auto Priestess trigger: HP %d%% <= %d%%", hp, P.cfg.threshold or 40))
  P.queue_self()
end

-- (Re)register GMCP handler
if Yso._eh.priestess_vitals then
  killAnonymousEventHandler(Yso._eh.priestess_vitals)
end
Yso._eh.priestess_vitals = registerAnonymousEventHandler(
  "gmcp.Char.Vitals",
  _safe(P.on_vitals)
)

-- ---------- user-facing toggles ----------

function P.toggle_auto()
  P.cfg.enabled = not P.cfg.enabled
  local state = P.cfg.enabled and "ON" or "OFF"
  _info(string.format("<yellow>Auto-Priestess is now %s.<reset>", state))
end

function P.set_threshold(percent)
  percent = tonumber(percent)
  if not percent or percent <= 0 or percent > 100 then
    _info("<red>Usage: lua Yso.priestess.set_threshold(<1-100>)<reset>")
    return
  end
  P.cfg.threshold = percent
  _info(string.format("<yellow>Auto-Priestess threshold set to %d%%.<reset>", percent))
end

cecho(_tag_prefix() .. "<cyan>Yso Priestess module loaded (bu queue).<reset>\n")
--========================================================--
