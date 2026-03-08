-- Auto-exported from Mudlet package script: Fool logic
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso / Legacy Fool (Tarot) helper + AUTO + DIAG SNAPSHOT
--  • Uses Legacy.Curing.Affs for conditions
--  • Uses Yso.queue if present, else raw QUEUE commands
--  • Auto-Fool:
--      - GMCP: checks on gmcp.Char.Vitals
--      - Diagnose snapshot: checks when a queued DIAGNOSE finishes
--  • Requirements:
--      - not prone
--      - not webbed
--      - at least one arm NOT brokenleftarm/brokenrightarm
--      - AND (>= min_affs, with cureset-aware thresholds)
--      - AND local 35s cooldown (for auto/diag paths; manual alias can ignore)
--========================================================--

Legacy              = Legacy              or {}
Legacy.Curing       = Legacy.Curing       or {}
Legacy.Curing.Affs  = Legacy.Curing.Affs  or {}
Legacy.Fool         = Legacy.Fool         or {}
Legacy.Fool.debug   = Legacy.Fool.debug   or false

-- Queue behaviour + thresholds
Legacy.Fool.queue_mode        = Legacy.Fool.queue_mode        or "addclearfull"  -- add / addclear / addclearfull
Legacy.Fool.queue_type        = Legacy.Fool.queue_type        or "bal"           -- bal / eqbal / free / full / flags
Legacy.Fool.min_affs_default  = Legacy.Fool.min_affs_default  or 6               -- non-hunt curesets
Legacy.Fool.min_affs_hunt     = Legacy.Fool.min_affs_hunt     or 3               -- HUNT cureset only
Legacy.Fool.min_affs          = Legacy.Fool.min_affs          or nil             -- optional global override
Legacy.Fool.ignore_blind_deaf = (Legacy.Fool.ignore_blind_deaf ~= false)         -- true = do NOT count blind/deaf

Yso        = Yso        or {}
Yso.queue  = Yso.queue  or {}
Yso._eh    = Yso._eh    or {}
Yso._trig  = Yso._trig  or {}
Yso.fool   = Yso.fool   or {}

local F = Yso.fool

F.cfg = F.cfg or {
  enabled = true,   -- auto (GMCP + diagnose snapshot) on/off
  cd      = 35,     -- Fool class cooldown, seconds
  gcd     = 1.0,    -- min seconds between auto attempts
  debug   = false,
}

F.state = F.state or {
  last_used  = 0,     -- when we last queued Fool
  last_auto  = 0,     -- when auto/diag last attempted Fool
  await_diag = false, -- set by dv alias; cleared on diag completion
}

-- ---------- helpers ----------

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok,v = pcall(Yso.util.now)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  local t = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  if t and t > 20000000000 then t = t / 1000 end
  return t or os.time()
end

local function _is_occultist()
  if Yso and Yso.classinfo and type(Yso.classinfo.is_occultist) == "function" then
    return Yso.classinfo.is_occultist()
  end
  local cls = gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class
  if (type(cls) ~= "string" or cls == "") and type(Yso.class) == "string" then cls = Yso.class end
  return tostring(cls or "") == "Occultist"
end

local function _fool_echo(msg)
  if (F.cfg.debug or Legacy.Fool.debug) and cecho then
    cecho(string.format("<cyan>[Fool] %s\n", tostring(msg)))
  end
end

local function _Aff()
  return (Legacy and Legacy.Curing and Legacy.Curing.Affs) or {}
end

local function _has(aff)
  local A = _Aff()
  return A[aff] == true
end

local function _both_arms_broken()
  return _has("brokenleftarm") and _has("brokenrightarm")
end

-- current cureset name from Legacy (e.g. "legacy", "hunt", "group")
local function _current_cureset()
  local set = Legacy
          and Legacy.Curing
          and Legacy.Curing.ActiveServerSet
  if type(set) == "string" then
    return set:lower()
  end
  return nil
end

-- Aff count, optionally ignoring blind/deaf
local function _aff_count()
  local A = _Aff()
  local n = 0
  local ignore_bd = Legacy.Fool.ignore_blind_deaf

  for k, v in pairs(A) do
    if v == true and k ~= "softlocked" and k ~= "truelocked" then
      if ignore_bd then
        local kk = tostring(k):lower()
        if kk ~= "blind" and kk ~= "blindness"
           and kk ~= "deaf" and kk ~= "deafness" then
          n = n + 1
        end
      else
        n = n + 1
      end
    end
  end
  return n
end

-- Lock detector (still used for non-hunt curesets)
local function _is_lock_state()
  local A = _Aff()

  if A.softlocked or A.truelocked then
    return true
  end

  local core = _has("impatience")
           and _has("asthma")
           and _has("slickness")
           and _has("anorexia")

  if not core then
    return false
  end

  local soft_lock  = core and not _has("paralysis")
  local true_lock  = core and _has("paralysis")
  local aeon_lock  = core and _has("aeon")

  return soft_lock or true_lock or aeon_lock
end

-- Resolve min_affs and whether "lock" is allowed to override the threshold
-- • HUNT cureset: min_affs_hunt, lock does NOT override (pure threshold)
-- • Other curesets: min_affs_default, lock CAN override (for PvP)
-- • Global Legacy.Fool.min_affs override (if set) always uses lock override.
local function _min_affs_for_current_set()
  -- explicit global override wins
  if Legacy.Fool.min_affs ~= nil then
    local v = tonumber(Legacy.Fool.min_affs)
    if v and v >= 1 then
      return v, true  -- allow lock override in this case
    end
  end

  local cur = _current_cureset() or "legacy"
  if cur == "hunt" then
    local v = tonumber(Legacy.Fool.min_affs_hunt or 3) or 3
    if v < 1 then v = 1 end
    return v, false  -- NO lock override in hunt
  else
    local v = tonumber(Legacy.Fool.min_affs_default or 6) or 6
    if v < 1 then v = 1 end
    return v, true   -- lock override allowed
  end
end

-- Queue helper
local function _queue_fool()
  if not _is_occultist() then
    _fool_echo("Not using Fool: current class is not Occultist.")
    return false
  end
  local mode  = tostring(Legacy.Fool.queue_mode or "addclearfull")
  local qtype = tostring(Legacy.Fool.queue_type or "bal")
  local cmd   = "fling fool at me"

  -- mark cooldown at queue time
  F.state.last_used = _now()

  if Yso.queue and type(Yso.queue.addclearfull) == "function"
     and mode:lower() == "addclearfull" then
    -- Yso queue helper path
    Yso.queue.addclearfull(qtype, cmd)
  else
    -- raw queue path
    send(string.format("queue %s %s %s", mode, qtype, cmd))
  end

  _fool_echo(string.format("Queued Fool via %s %s.", mode, qtype))
end

--========================================================--
--  Public helper: Legacy.FoolSelfCleanse(source)
--  • Used by:
--      - auto driver (GMCP)
--      - diagnose snapshot hook
--      - your ^fool$ alias (manual panic button)
--  • Returns true if Fool was queued.
--========================================================--
function Legacy.FoolSelfCleanse(source)
  if not (Legacy and Legacy.Curing and Legacy.Curing.Affs) then
    return false
  end

  -- Mechanical gates
  if _has("prone") then
    _fool_echo("Not using Fool: prone.")
    return false
  end

  if _has("webbed") then
    _fool_echo("Not using Fool: webbed.")
    return false
  end

  if _both_arms_broken() then
    _fool_echo("Not using Fool: both arms broken.")
    return false
  end

  -- Severity gates (cureset aware)
  local count                  = _aff_count()
  local is_locked              = _is_lock_state()
  local min_affs, allow_lock   = _min_affs_for_current_set()
  local curset                 = _current_cureset() or "?"

  local lock_ok = allow_lock and is_locked

  if count < min_affs and not lock_ok then
    _fool_echo(string.format(
      "Not using Fool: cureset=%s, affs=%d (< %d), allow_lock=%s, lock=%s.",
      curset, count, min_affs, tostring(allow_lock), tostring(is_locked)
    ))
    return false
  end

  _fool_echo(string.format(
    "Using Fool (source=%s, cureset=%s, affs=%d, min=%d, allow_lock=%s, lock=%s).",
    tostring(source or "?"), curset, count, min_affs,
    tostring(allow_lock), tostring(is_locked)
  ))

  local queued = _queue_fool()
  return queued == true
end

-- ---------- cooldown helpers for auto/diag paths ----------

local function _cooldown_ready()
  local cd   = tonumber(F.cfg.cd or 35) or 35
  local last = tonumber(F.state.last_used or 0) or 0
  return (_now() - last) >= cd
end

local function _gcd_ready()
  local gcd  = tonumber(F.cfg.gcd or 1) or 1
  local last = tonumber(F.state.last_auto or 0) or 0
  return (_now() - last) >= gcd
end

local function _safe(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then
      _fool_echo("ERROR: "..tostring(err))
    end
  end
end

--========================================================--
--  Auto driver #1: GMCP vitals tick
--========================================================--
function F.on_vitals()
  if not F.cfg.enabled then return end
  if not _is_occultist() then return end
  if not _cooldown_ready() then return end
  if not _gcd_ready() then return end

  -- quick check: any affs at all?
  local A = _Aff()
  local has_any = false
  for _, v in pairs(A) do
    if v == true then has_any = true; break end
  end
  if not has_any then return end

  F.state.last_auto = _now()
  local used = Legacy.FoolSelfCleanse("auto")
  if used then
    _fool_echo("Auto-Fool fired from GMCP.")
  end
end

--========================================================--
--  Auto driver #2: Diagnose snapshot
--========================================================--

-- Called from your dv alias
function F.mark_diag_pending()
  F.state.await_diag = true
  _fool_echo("Marked: next EQ used line is from DIAGNOSE.")
end

-- Trigger: when equilibrium is used, and a diagnose is pending
if Yso._trig.fool_eq then
  killTrigger(Yso._trig.fool_eq)
end
Yso._trig.fool_eq = tempRegexTrigger(
  [[^Equilibrium used:\s+([0-9.]+)s\.]],
  _safe(function()
    if not F.state.await_diag then
      return
    end
    -- This EQ-used belongs to the queued DIAGNOSE.
    F.state.await_diag = false

    if not F.cfg.enabled then return end
    if not _cooldown_ready() then
      _fool_echo("Diag snapshot seen, but Fool cooldown not ready.")
      return
    end

    F.state.last_auto = _now()
    local used = Legacy.FoolSelfCleanse("diagnose")
    if used then
      _fool_echo("Fool fired on diagnose snapshot.")
    else
      _fool_echo("Diagnose snapshot: conditions failed, Fool not used.")
    end
  end)
)

--========================================================--
--  User-facing toggles
--========================================================--
function F.toggle_auto()
  F.cfg.enabled = not F.cfg.enabled
  local state = F.cfg.enabled and "ON" or "OFF"
  cecho(string.format("<cyan>[Fool] Auto-Fool is now %s.\n", state))
end

function F.set_cd(seconds)
  local s = tonumber(seconds)
  if not s or s < 0 then
    cecho("<cyan>[Fool] Usage: lua Yso.fool.set_cd(<seconds>)\n")
    return
  end
  F.cfg.cd = s
  cecho(string.format("<cyan>[Fool] Cooldown set to %.1fs.\n", s))
end

function F.set_min_affs(n)
  local v = tonumber(n)
  if not v or v < 1 then
    cecho("<cyan>[Fool] Usage: lua Yso.fool.set_min_affs(<count>=1+)\n")
    return
  end
  Legacy.Fool.min_affs = v
  cecho(string.format("<cyan>[Fool] Global min_affs override now %d.\n", v))
end

--========================================================--
--  Register GMCP handler
--========================================================--
if Yso._eh.fool_vitals then
  killAnonymousEventHandler(Yso._eh.fool_vitals)
end
Yso._eh.fool_vitals = registerAnonymousEventHandler(
  "gmcp.Char.Vitals",
  _safe(F.on_vitals)
)

_fool_echo("Yso Fool auto module loaded (GMCP+diagnose hooks active).")
--========================================================--
