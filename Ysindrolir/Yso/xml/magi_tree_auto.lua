Yso = Yso or {}
Yso.tree = Yso.tree or {}
Yso._trig = Yso._trig or {}
Yso._eh = Yso._eh or {}

local T = Yso.tree

T.cfg = T.cfg or {
  enabled = true,
  min_affs_hunt = 1,
  unchanged_cooldown_s = 4.0,
  debug = false,
}

T.cfg.pvp = T.cfg.pvp or {
  enabled = false,
  min_affs_default = 2,
  allow_lock_override = true,
  curesets = {
    depthswalker = { min_affs = 1, notes = "placeholder" },
    bard         = { min_affs = 1, notes = "placeholder" },
    monk         = { min_affs = 1, notes = "placeholder" },
    dwc          = { min_affs = 2, notes = "dual wield cutting knights" },
    dwb          = { min_affs = 2, notes = "dual wield blunt knights (future)" },
    blademaster  = { min_affs = 2, notes = "placeholder" },
    shaman       = { min_affs = 1, notes = "placeholder" },
    airlord      = { min_affs = 1, notes = "elemental air spec" },
  },
}

T.state = T.state or {
  ready = true,
  last_touch = 0,
  cooldown_until = 0,
  last_event = "",
}

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    if ok and tonumber(v) then return tonumber(v) end
  end
  local t = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  if t and t > 20000000000 then t = t / 1000 end
  return t or os.time()
end

local function _cooldown_seconds()
  local v = tonumber(T.cfg.unchanged_cooldown_s or 4.0) or 4.0
  if v < 0.25 then v = 0.25 end
  return v
end

local function _debug(msg)
  if T.cfg.debug and type(cecho) == "function" then
    cecho(string.format("<green>[Tree] <white>%s\n", tostring(msg)))
  end
end

local function _echo(msg)
  if type(cecho) == "function" then
    cecho(string.format("<green>[Tree] <white>%s\n", tostring(msg)))
  end
end

local function _Aff()
  return (Legacy and Legacy.Curing and Legacy.Curing.Affs) or {}
end

local function _has(aff)
  return _Aff()[aff] == true
end

local function _aff_count()
  local A = _Aff()
  local n = 0
  for k, v in pairs(A) do
    if v == true and k ~= "softlocked" and k ~= "truelocked" then
      n = n + 1
    end
  end
  return n
end

local function _norm_cureset(v)
  v = tostring(v or ""):lower()
  v = v:gsub("^%s+", ""):gsub("%s+$", "")
  if v == "bash" or v == "bashing" or v == "hunt" or v == "hunting" or v == "pve" then
    return "hunt"
  end
  return v
end

local function _current_cureset()
  local set = Legacy and Legacy.Curing and Legacy.Curing.ActiveServerSet
  if type(set) == "string" and set ~= "" then return _norm_cureset(set) end
  local cur = rawget(_G, "CurrentCureset")
  if type(cur) == "string" and cur ~= "" then return _norm_cureset(cur) end
  return ""
end

local function _mode_implies_hunt()
  local mode = Yso and Yso.mode or nil
  if type(mode) ~= "table" then return false end

  if type(mode.is_bash) == "function" then
    local ok, v = pcall(mode.is_bash)
    if ok and v == true then return true end
  end
  if type(mode.is_hunt) == "function" then
    local ok, v = pcall(mode.is_hunt)
    if ok and v == true then return true end
  end

  return (_norm_cureset(rawget(mode, "state")) == "hunt")
end

local function _auto_tree_disabled_context()
  if _mode_implies_hunt() then
    return true, "mode_hunt_bash"
  end
  if _current_cureset() == "hunt" then
    return true, "cureset_hunt"
  end
  return false, ""
end

local function _start_cooldown(source, seconds)
  local now = _now()
  local wait = tonumber(seconds) or _cooldown_seconds()
  if wait < 0 then wait = 0 end
  T.state.ready = false
  T.state.last_touch = now
  T.state.cooldown_until = now + wait
  T.state.last_event = tostring(source or "cooldown")
end

local function _release_failsafe(now)
  now = tonumber(now) or _now()
  if T.state.ready == true then return false end
  local due = tonumber(T.state.cooldown_until or 0) or 0
  if due <= 0 or now < due then return false end
  T.state.ready = true
  T.state.cooldown_until = 0
  T.state.last_event = "failsafe_ready"
  _debug("tree ready via failsafe timeout")
  return true
end

function T.should_tree()
  if T.cfg.enabled ~= true then return false, "disabled" end

  local disabled, disabled_reason = _auto_tree_disabled_context()
  if disabled then
    return false, "hunt_bash_disabled:" .. tostring(disabled_reason or "")
  end

  local now = _now()
  _release_failsafe(now)

  if not T.state.ready then
    return false, "cooldown"
  end
  if _has("paralysis") then return false, "paralysis" end

  local curset = _current_cureset()
  local count = _aff_count()

  if curset == "hunt" then
    local min_affs = tonumber(T.cfg.min_affs_hunt or 1) or 1
    if count < min_affs then return false, "affs", count, min_affs end
    return true, "ok", count, min_affs
  end

  local pvp = T.cfg.pvp
  if not (type(pvp) == "table" and pvp.enabled == true) then
    return false, "pvp_disabled"
  end

  local entry = type(pvp.curesets) == "table" and pvp.curesets[curset] or nil
  local min_affs = (type(entry) == "table" and tonumber(entry.min_affs))
                   or tonumber(pvp.min_affs_default or 2) or 2

  local lock_ok = pvp.allow_lock_override and _has("softlocked")
  if count < min_affs and not lock_ok then
    return false, "affs_pvp", count, min_affs
  end

  return true, "ok_pvp", count, min_affs
end

function T.try_tree(source)
  local ok, reason, count, min_affs = T.should_tree()
  if not ok then
    _debug(string.format("skip src=%s reason=%s", tostring(source or "?"), tostring(reason or "?")))
    return false, reason
  end

  if type(send) == "function" then
    send("touch tree", false)
    _start_cooldown("send:" .. tostring(source or "?"), _cooldown_seconds())
    _debug(string.format("touching tree src=%s affs=%d/%d", tostring(source or "?"), count or 0, min_affs or 0))
    return true, reason
  end

  return false, "send_unavailable"
end

function T.on_touched()
  _start_cooldown("line:touched", _cooldown_seconds())
  _debug("tree touched, cooldown started")
end

function T.on_unchanged()
  _start_cooldown("line:unchanged", _cooldown_seconds())
  _debug("tree unchanged, cooldown started")
end

function T.on_ready()
  T.state.ready = true
  T.state.cooldown_until = 0
  T.state.last_event = "line:ready"
  _debug("tree ready")
  local disabled = _auto_tree_disabled_context()
  if disabled then
    _debug("skip src=ready_line reason=hunt_bash_disabled")
    return
  end
  T.try_tree("ready_line")
end

function T.on_vitals()
  if not T.cfg.enabled then return end
  local disabled = _auto_tree_disabled_context()
  if disabled then return end
  _release_failsafe(_now())
  if not T.state.ready then return end
  T.try_tree("vitals")
end

function T.set_auto(v)
  local on = nil
  local t = type(v)
  if t == "boolean" then on = v
  elseif t == "number" then on = (v ~= 0)
  elseif t == "string" then
    local s = tostring(v):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if s == "on" or s == "1" or s == "true" then on = true
    elseif s == "off" or s == "0" or s == "false" then on = false end
  end
  if on == nil then _echo("Usage: lua Yso.tree.set_auto(true|false)"); return end
  T.cfg.enabled = on
  _echo("Auto tree is now " .. (on and "ON." or "OFF."))
end

function T.status()
  local ok, reason, count, min_affs = T.should_tree()
  local curset = _current_cureset()
  local now = _now()
  local cd_remain = math.max(0, (tonumber(T.state.cooldown_until or 0) or 0) - now)
  _echo(string.format(
    "auto=%s ready=%s cureset=%s affs=%d min=%d reason=%s para=%s cd=%.1fs",
    T.cfg.enabled and "on" or "off",
    T.state.ready and "Y" or "N",
    curset ~= "" and curset or "?",
    count or _aff_count(),
    min_affs or 0,
    tostring(reason or (ok and "ok" or "?")),
    _has("paralysis") and "Y" or "N",
    cd_remain
  ))
end

local function _safe(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok and T.cfg.debug then
      _echo("ERROR: " .. tostring(err))
    end
  end
end

if Yso._trig.tree_touched then killTrigger(Yso._trig.tree_touched) end
Yso._trig.tree_touched = tempRegexTrigger(
  [[^You touch the tree of life tattoo\.$]],
  _safe(function() T.on_touched() end)
)

if Yso._trig.tree_ready then killTrigger(Yso._trig.tree_ready) end
Yso._trig.tree_ready = tempRegexTrigger(
  [[^You may utilise the tree tattoo again\.]],
  _safe(function() T.on_ready() end)
)

if Yso._trig.tree_unchanged then killTrigger(Yso._trig.tree_unchanged) end
Yso._trig.tree_unchanged = tempRegexTrigger(
  [[^Your tree of life tattoo glows faintly for a moment then fades, leaving you unchanged\.$]],
  _safe(function() T.on_unchanged() end)
)

if Yso._eh.tree_vitals then pcall(killAnonymousEventHandler, Yso._eh.tree_vitals) end
Yso._eh.tree_vitals = registerAnonymousEventHandler("gmcp.Char.Vitals", function()
  T.on_vitals()
end)
