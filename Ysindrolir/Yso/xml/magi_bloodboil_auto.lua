Yso = Yso or {}
Yso.magi = Yso.magi or {}
Yso.magi.elemental = Yso.magi.elemental or {}

local M = Yso.magi.elemental

M.cfg = M.cfg or {
  auto_bloodboil = true,
  min_affs_hunt = 2,
  cooldown_s = 4.0,
  queue_mode = "prepend",
  queue_type = "eq",
  command = "cast bloodboil",
  debug = false,
  min_retry_s = 0.25,
}

M.cfg.destroy = M.cfg.destroy or {
  require_conflagration = true,
  hp_threshold = 40,
  enforce_hp_gate = false,
}

M.cfg.pvp = M.cfg.pvp or {
  enabled            = false,
  min_affs_default   = 3,
  allow_lock_override = true,
  curesets = {
    depthswalker = { min_affs = 2, notes = "placeholder" },
    bard         = { min_affs = 2, notes = "placeholder" },
    monk         = { min_affs = 2, notes = "placeholder" },
    dwc          = { min_affs = 3, notes = "dual wield cutting knights" },
    dwb          = { min_affs = 3, notes = "dual wield blunt knights (future)" },
    blademaster  = { min_affs = 3, notes = "placeholder" },
    shaman       = { min_affs = 2, notes = "placeholder" },
    airlord      = { min_affs = 2, notes = "elemental air spec" },
  },
}

M.state = M.state or {
  cooldown_until = 0,
  last_attempt = 0,
}

M.state.timers = M.state.timers or {}
M.state.destroy_hp_stub_noted = M.state.destroy_hp_stub_noted or false

local function _now()
  local t = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  if t and t > 1000000000000 then t = t / 1000 end
  return t or os.time()
end

local function _debug(msg)
  if M.cfg.debug and type(cecho) == "function" then
    cecho(string.format("[Magi:Bloodboil] %s\n", tostring(msg)))
  end
end

local function _echo(msg)
  if type(cecho) == "function" then
    cecho(string.format("<SlateBlue>[Magi] <white>%s\n", tostring(msg)))
  end
end

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _status()
  return (gmcp and gmcp.Char and gmcp.Char.Status) or {}
end

local function _vitals()
  return (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
end

local function _eq_ready()
  if Yso and Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then return v == true end
  end

  local v = _vitals()
  return tostring(v.eq or v.equilibrium or "") == "1"
      or v.eq == true
      or v.equilibrium == true
end

local function _is_magi()
  if Yso and Yso.magi and Yso.magi.defs and type(Yso.magi.defs.is_magi) == "function" then
    local ok, v = pcall(Yso.magi.defs.is_magi)
    if ok then return v == true end
  end

  local s = _status()
  local cls = s.class or s.classname
  if (type(cls) ~= "string" or cls == "") and Yso and Yso.magi and Yso.magi.defs and Yso.magi.defs.state then
    cls = Yso.magi.defs.state.class_name
  end

  return tostring(cls or ""):lower() == "magi"
end

local function _current_cureset()
  local set = Legacy and Legacy.Curing and Legacy.Curing.ActiveServerSet
  if type(set) == "string" and set ~= "" then
    return set:lower()
  end

  local prof = Yso and Yso.curing and Yso.curing._active_profile
  if type(prof) == "string" and prof ~= "" then
    return prof:lower()
  end

  local cur = rawget(_G, "CurrentCureset")
  if type(cur) == "string" and cur ~= "" then
    return cur:lower()
  end

  return ""
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

local function _resolve_current_target()
  local tgt = ""

  if Yso and type(Yso.get_target) == "function" then
    local ok, res = pcall(Yso.get_target)
    if ok and type(res) == "string" then
      tgt = _trim(res)
    end
  end

  if tgt == "" and Yso and Yso.targeting and type(Yso.targeting.get) == "function" then
    local ok, res = pcall(Yso.targeting.get)
    if ok and type(res) == "string" then
      tgt = _trim(res)
    end
  end

  if tgt == "" then
    tgt = _trim(rawget(_G, "target"))
  end

  tgt = tostring(tgt or ""):gsub("%s*%b()%s*$", "")
  return _trim(tgt)
end

local function _queue_eqbal(cmd, opts)
  opts = opts or {}
  cmd = _trim(cmd)
  if cmd == "" or type(send) ~= "function" then
    return false
  end

  if tostring(opts.queue_verb or ""):lower() == "addclearfull" then
    if Yso and Yso.queue and type(Yso.queue.addclearfull) == "function" then
      return Yso.queue.addclearfull("eqbal", cmd) == true
    end
    send("queue addclearfull eqbal " .. cmd, false)
    return true
  end

  send("queue prepend eqbal " .. cmd, false)
  return true
end

local function _target_has_aff(aff)
  aff = _trim(aff):lower()
  if aff == "" then return false end

  if Yso and Yso.ak and type(Yso.ak.has) == "function" then
    local ok, has_aff = pcall(Yso.ak.has, aff)
    if ok then
      return has_aff == true
    end
  end

  local threshold = tonumber(Yso and Yso.ak and Yso.ak.threshold) or 100
  if type(affstrack) == "table" and type(affstrack.score) == "table" then
    return (tonumber(affstrack.score[aff] or 0) or 0) >= threshold
  end

  return false
end

local function _record_timer(spell, seconds)
  M.state.timers[spell] = {
    seconds = tonumber(seconds) or 0,
    armed_at = _now(),
  }
end

function M.is_ready()
  return _now() >= tonumber(M.state.cooldown_until or 0)
end

function M.set_ready(is_ready, src)
  if is_ready then
    M.state.cooldown_until = 0
  else
    M.state.cooldown_until = _now() + (tonumber(M.cfg.cooldown_s or 4.0) or 4.0)
  end

  _debug(string.format("ready=%s src=%s", tostring(is_ready), tostring(src or "?")))
  return true
end

function M.should_bloodboil()
  if M.cfg.auto_bloodboil ~= true then
    return false, "disabled"
  end

  if not _is_magi() then
    return false, "class"
  end

  if not M.is_ready() then
    return false, "cooldown"
  end

  if not _eq_ready() then
    return false, "eq"
  end

  if _has("haemophilia") then
    return false, "haemophilia"
  end

  local curset = _current_cureset()
  local count  = _aff_count()

  if curset == "hunt" then
    local min_affs = tonumber(M.cfg.min_affs_hunt or 2) or 2
    if count < min_affs then return false, "affs", count, min_affs end
    return true, "ok", count, min_affs
  end

  local pvp = M.cfg.pvp
  if not (type(pvp) == "table" and pvp.enabled == true) then
    return false, "pvp_disabled"
  end

  local entry = type(pvp.curesets) == "table" and pvp.curesets[curset] or nil
  local min_affs = (type(entry) == "table" and tonumber(entry.min_affs))
                   or tonumber(pvp.min_affs_default or 3) or 3

  local lock_ok = pvp.allow_lock_override and _has("softlocked")
  if count < min_affs and not lock_ok then
    return false, "affs_pvp", count, min_affs
  end

  return true, "ok_pvp", count, min_affs
end

local function _queue_bloodboil(source)
  local cmd = tostring(M.cfg.command or "cast bloodboil")
  local mode = tostring(M.cfg.queue_mode or "prepend")
  local qtype = tostring(M.cfg.queue_type or "eq")

  local ok = false
  if Yso and Yso.queue and type(Yso.queue.raw) == "function" then
    ok = (Yso.queue.raw(mode, qtype, cmd) == true)
  elseif type(send) == "function" then
    send(string.format("queue %s %s %s", mode, qtype, cmd), false)
    ok = true
  end

  if ok then
    M.state.last_attempt = _now()
    M.set_ready(false, "queue:" .. tostring(source or "?"))
    _debug(string.format("queued mode=%s qtype=%s src=%s", mode, qtype, tostring(source or "?")))
  end

  return ok
end

function M.try_bloodboil(source)
  local now = _now()
  local min_retry = tonumber(M.cfg.min_retry_s or 0.25) or 0.25
  if (now - tonumber(M.state.last_attempt or 0)) < min_retry then
    return false
  end

  local ok, reason = M.should_bloodboil()
  if not ok then
    _debug(string.format("skip src=%s reason=%s", tostring(source or "?"), tostring(reason or "?")))
    return false
  end

  return _queue_bloodboil(source)
end

function M.on_eq_recovered()
  return M.try_bloodboil("eq_recovered")
end

function M.on_ready_line()
  M.set_ready(true, "line:ready")
  return M.try_bloodboil("ready_line")
end

function M.get_target_hp_percent(_target_name)
  return nil
end

function M.firelash(mode)
  local arg = _trim(mode):lower()
  local target = arg

  if target == "" then
    target = _resolve_current_target()
  end

  if target == "" then
    _echo("No target set for firelash.")
    return false
  end

  local ok = _queue_eqbal("cast firelash at " .. target)
  if ok then
    _echo("Firelash queued at " .. target .. ".")
  end
  return ok
end

function M.destroy_current_target()
  local tgt = _resolve_current_target()
  if tgt == "" then
    _echo("No target set for destroy.")
    return false
  end

  if M.cfg.destroy.require_conflagration ~= false and not _target_has_aff("conflagration") then
    _echo(string.format("Destroy blocked on %s: conflagration not confirmed.", tgt))
    return false
  end

  if M.cfg.destroy.enforce_hp_gate == true then
    local hp_pct = M.get_target_hp_percent(tgt)
    if not hp_pct then
      _echo("Destroy HP gate is enabled but target HP% is not wired yet.")
      return false
    end
    if hp_pct > (tonumber(M.cfg.destroy.hp_threshold or 40) or 40) then
      _echo(string.format(
        "Destroy blocked on %s: %.1f%%%% is above the %d%%%% threshold.",
        tgt,
        hp_pct,
        tonumber(M.cfg.destroy.hp_threshold or 40) or 40
      ))
      return false
    end
  elseif M.state.destroy_hp_stub_noted ~= true then
    M.state.destroy_hp_stub_noted = true
    _echo(string.format(
      "Destroy HP gate is stubbed for now; only conflagration is checked (planned threshold: %d%%%%).",
      tonumber(M.cfg.destroy.hp_threshold or 40) or 40
    ))
  end

  local ok = _queue_eqbal("cast destroy at " .. tgt, { queue_verb = "addclearfull" })
  if ok then
    _echo("Destroy queued on " .. tgt .. ".")
  end
  return ok
end

local function _cast_timed_spell(spell, seconds)
  local secs = tonumber(seconds)
  if not secs then
    _echo(string.format("%s requires a timer between 10 and 60 seconds.", tostring(spell)))
    return false
  end

  secs = math.floor(secs)
  if secs < 10 or secs > 60 then
    _echo(string.format("%s requires a timer between 10 and 60 seconds.", tostring(spell)))
    return false
  end

  local ok = _queue_eqbal(string.format("cast %s %d", tostring(spell), secs))
  if ok then
    _record_timer(spell, secs)
    _echo(string.format("%s armed for %ds.", tostring(spell):gsub("^%l", string.upper), secs))
  end
  return ok
end

function M.cast_holocaust(seconds)
  return _cast_timed_spell("holocaust", seconds)
end

function M.cast_magmasphere(seconds)
  return _cast_timed_spell("magmasphere", seconds)
end
