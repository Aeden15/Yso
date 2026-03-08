-- Auto-exported from Mudlet package script: Yso.targeting
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso.targeting (canonical combat target service)
--
-- Goal:
--   Use AK's targeting (global `target`) as canonical.
--   Yso.targeting mirrors AK and provides a stable API for Yso modules.
--
-- API:
--   Yso.set_target(name[, source])
--   Yso.get_target()
--   Yso.clear_target([reason])
--   Yso.resolve_target([arg][, opts])  opts={ set=true|false, source="manual" }
--
-- Pulse integration:
--   Wakes Yso.pulse on set/clear so offense won't fall asleep on target swap.
--========================================================--

Yso = Yso or {}
Yso.targeting = Yso.targeting or {}
local TG = Yso.targeting

if TG._svc_loaded then
  return
end
TG._svc_loaded = true

TG.cfg = TG.cfg or {
  echo = false,
  debug = false,
  mirror_yso_target = true,
  -- If true, also writes rawset(_G, "target", name). Default OFF:
  -- AK/Legacy already manage _G.target, and dual-writes can cause loops/crashes.
  mirror_global_target = false,
  import_global_target = true,
}

TG.prio = TG.prio or {
  manual  = 100,
  caller  =  90,
  module  =  80,
  ak      =  50,
  legacy  =  40,
  gmcp    =  30,
  unknown =  10,
}

TG.state = TG.state or {
  name   = "",
  source = "",
  at     = 0,
  locked      = false,
  lock_source = "",
  lock_reason = "",
}

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$",""))
end

local function _now()
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _clean(s)
  s = _trim(s)
  if s == "" then return "" end
  -- strip trailing parentheticals that sometimes sneak in ("(player)", "(an adventurer)")
  s = s:gsub("%s*%b()$", "")
  -- strip Mudlet / GMCP placeholder-ish values
  local lc = s:lower()
  if lc == "none" or lc == "nil" or lc == "null" then return "" end
  return s
end

local function _dbg(msg)
  if not TG.cfg.debug then return end
  if type(echo) == "function" then
    echo("[Yso.tgt] " .. tostring(msg) .. "\n")
  end
end

local function _wake(reason)
  if Yso and Yso.pulse and type(Yso.pulse.wake) == "function" then
    pcall(Yso.pulse.wake, tostring(reason or "target"))
  end
end

local function _sync_mirrors(name)
  -- Optional mirrors for legacy readers.
  if TG.cfg.mirror_yso_target then
    Yso.target = name
  end
  if TG.cfg.mirror_global_target then
    -- Optional: keep the legacy global 'target' string in sync.
    rawset(_G, "target", name)
  end
end

-- ---------- AK-canonical targeting bridge (lockdown) ----------
-- Goal: make AK the only *sender* of server target commands.
-- Yso.targeting becomes a mirror + API surface for modules.
TG._forwarding = TG._forwarding or false

local function _ak_set_target(name)
  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    local tgt = rawget(ak, "target")
    if type(tgt) == "table" and type(tgt.set) == "function" then
      local ok, err = pcall(tgt.set, name, { source = "yso" })
      return ok, err
    end
    if type(rawget(ak, "setTarget")) == "function" then
      local ok, err = pcall(ak.setTarget, name)
      return ok, err
    end
  end

  if type(expandAlias) == "function" then
    expandAlias("t " .. tostring(name))
    return true
  end

  -- last-resort fallback (bypasses AK features)
  if type(send) == "function" then
    send("st " .. tostring(name))
    return true
  end

  return false, "no_ak"
end

local function _ak_clear_target()
  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    local tgt = rawget(ak, "target")
    if type(tgt) == "table" and type(tgt.clear) == "function" then
      local ok, err = pcall(tgt.clear, { source = "yso" })
      return ok, err
    end
    if type(rawget(ak, "clearTarget")) == "function" then
      local ok, err = pcall(ak.clearTarget)
      return ok, err
    end
  end

  if type(expandAlias) == "function" then
    expandAlias("t clear")
    return true
  end

  -- last-resort fallback (bypasses AK features)
  if type(send) == "function" then
    send("st none")
    return true
  end

  return false, "no_ak"
end

local function _should_forward_to_ak(source, opts)
  if opts and opts.no_ak then return false end
  if TG._forwarding then return false end
  source = _clean(source)
  if source == "" then source = "unknown" end
  if source == "ak" or source == "server" or source == "gmcp" then return false end
  return true
end

local function _forward_to_ak(fn, arg)
  if TG._forwarding then return false, "reentrant" end
  TG._forwarding = true
  local ok, res = pcall(fn, arg)
  TG._forwarding = false
  if not ok then return false, res end
  return true, res
end

function TG.clear(source, reason, silent, opts)
  source = _clean(source)
  if source == "" then source = "system" end

  opts = opts or {}
  if _should_forward_to_ak(source, opts) then
    _forward_to_ak(_ak_clear_target)
  end

  local old = _clean(TG.state.name)
  if old == "" then return true, "noop" end

  TG.state.name = ""
  TG.state.source = source
  TG.state.at = _now()
  TG.state.locked, TG.state.lock_source, TG.state.lock_reason = false, "", ""

  _sync_mirrors("")

  -- Phase 1 plumbing: mirror into Yso.state
  if Yso and Yso.ingest and type(Yso.ingest.target_left) == "function" then
    pcall(Yso.ingest.target_left, reason or "clear", { nowake = true })
  end

  if not silent and TG.cfg.echo and type(echo) == "function" then
    echo("[YSO] Target cleared.\n")
  end

  _wake("target:clear:" .. source)
  return true
end

function TG.set(name, source, opts)
  opts = opts or {}
  name = _clean(name)
  source = _clean(source)
  if source == "" then source = "unknown" end

  if name == "" then
    return TG.clear(source, opts.reason, opts.silent, opts)
  end

  if TG.state.locked and not opts.force then
    return false, "locked" end

  local old = _clean(TG.state.name)
  local oldsrc = _clean(TG.state.source)
  local oldp = TG.prio[oldsrc] or TG.prio.unknown
  local incp = TG.prio[source] or TG.prio.unknown

  if old ~= "" and not opts.force and incp < oldp then
    return false, "lower_priority" end

  if _should_forward_to_ak(source, opts) then
    _forward_to_ak(_ak_set_target, name)
  end

  TG.state.name = name
  TG.state.source = source
  TG.state.at = _now()

  _sync_mirrors(name)

  -- Target swap hygiene: do NOT carry staged entity actions across targets.
  -- (Prevents stale "command <ent> at <old>" from firing after a swap.)
  if old ~= "" and old:lower() ~= name:lower() then
    if Yso and Yso.queue and type(Yso.queue.clear) == "function" then
      pcall(Yso.queue.clear, "class")
    end
    if Yso and Yso.state then
      Yso.state._last_ent_cmd = nil
      Yso.state._last_ent_cmd_ts = nil
    end
  end


-- If offense automation was paused (e.g., target leapt out), auto-resume on an explicit target set.
if Yso and type(Yso.offense_paused) == "function" and Yso.offense_paused()
   and type(Yso.pause_offense) == "function"
then
  pcall(Yso.pause_offense, false, "target_set", true)
end


  -- Phase 1 plumbing: mirror into Yso.state
  if Yso and Yso.ingest and type(Yso.ingest.target_set) == "function" then
    pcall(Yso.ingest.target_set, name, source, { nowake = true })
  end

  if not opts.silent and TG.cfg.echo and type(echo) == "function" then
    echo("[YSO] Target set: " .. name .. "\n")
  end

  _wake("target:set:" .. source)
  return true
end

function TG._maybe_import_global()
  if not TG.cfg.import_global_target then return end
  local gt = rawget(_G, "target")
  if type(gt) ~= "string" then return end
  gt = _clean(gt)
  local cur = _clean(TG.state.name)
  if gt == cur then return end

  -- Mirror only (do not forward back into AK).
  -- Force=true so AK state always wins the mirror.
  TG.set(gt, "ak", { silent = true, reason = "import_global", no_ak = true, force = true })
end

function TG.get()
  TG._maybe_import_global()
  local n = _clean(TG.state.name)
  if n ~= "" then return n end

  return nil
end

-- Compatibility target predicate used by legacy trigger scripts.
local function _target_key(name)
  return _clean(name):lower()
end

function TG.is_current(name)
  local who = _target_key(name)
  if who == "" then return false end
  local cur = _target_key(TG.get())
  return (cur ~= "" and who == cur)
end

if type(rawget(_G, "oc_isCurrentTarget")) ~= "function" then
  function oc_isCurrentTarget(name)
    if Yso and Yso.targeting and type(Yso.targeting.is_current) == "function" then
      return Yso.targeting.is_current(name)
    end
    return false
  end
end

function TG.lock(source, reason)
  TG.state.locked = true
  TG.state.lock_source = _clean(source)
  TG.state.lock_reason = _trim(reason)
  return true
end

function TG.unlock()
  TG.state.locked, TG.state.lock_source, TG.state.lock_reason = false, "", ""
  return true
end

-- Public wrappers (avoid clobbering if already defined)
if type(Yso.get_target) ~= "function" then
  function Yso.get_target() return TG.get() end
end

if type(Yso.set_target) ~= "function" then
  function Yso.set_target(who, source)
    who = _clean(who)
    if who == "" then
      if type(echo) == "function" then echo("[YSO] No target supplied. Usage: y NAME\n") end
      return false
    end
    return TG.set(who, source or "manual")
  end
end

if type(Yso.clear_target) ~= "function" then
  function Yso.clear_target(reason) return TG.clear("system", reason) end
end

if type(Yso.resolve_target) ~= "function" then
  function Yso.resolve_target(arg, opts)
    opts = opts or {}
    local a = _clean(arg)
    if a ~= "" then
      if opts.set then pcall(Yso.set_target, a, opts.source or "manual") end
      return a
    end
    return TG.get()
  end
end

Yso.ak = Yso.ak or {}
if type(Yso.ak.target) ~= "function" then
  function Yso.ak.target(arg) return Yso.resolve_target(arg, { set = false }) end
end


-- ---------- optional: server target line hooks (event-driven wake) ----------
TG._trig = TG._trig or {}
local function _killtrig(id) if id then pcall(killTrigger, id) end end
_killtrig(TG._trig.set); _killtrig(TG._trig.clear)

-- Common Achaea lines (harmless if your client never sees these exact strings)
TG._trig.set = tempRegexTrigger([[^You are now targeting ([\w'\-]+)\.$]], function()
  if TG and TG.set then TG.set(matches[2], "ak", { silent = true, reason = "server_target" }) end
end)

TG._trig.clear = tempRegexTrigger([[^You (?:stop|are no longer) targeting anyone\.$]], function()
  -- Achaea clears server-side target on room moves. Only mirror that into Yso.targeting
  -- while the offense driver is actively fighting (AUTO).
  if type(Yso.is_actively_fighting) == "function" and not Yso.is_actively_fighting() then return end
  if TG and TG.clear then TG.clear("ak", "server_target_clear", true) end
end)


-- ---------- ytarget / ytgt (convenience aliases) ----------
-- These are safe even if you primarily target via AK; they just call Yso.targeting.
TG._alias = TG._alias or {}
local function _killalias(id) if id then pcall(killAlias, id) end end
_killalias(TG._alias.ytarget); _killalias(TG._alias.ytgt)

if type(tempAlias) == "function" then
  local function _yt(arg)
    arg = tostring(arg or ""):gsub("^%s+",""):gsub("%s+$","")
    if arg == "" then
      local cur = (TG.get and TG.get()) or ""
      if type(echo) == "function" then
        echo(("[YSO] Target: %s\n"):format(cur ~= "" and cur or "(none)"))
      end
      return
    end

    local lc = arg:lower()
    if lc == "clear" or lc == "none" or lc == "off" then
      if TG.clear then TG.clear("manual", "alias:ytarget") end
      return
    end

    if TG.set then TG.set(arg, "manual") end
  end

  TG._alias.ytarget = tempAlias([[^ytarget(?:\s+(.+))?$]], function() _yt(matches[2]) end)
  TG._alias.ytgt    = tempAlias([[^ytgt(?:\s+(.+))?$]],    function() _yt(matches[2]) end)
end
