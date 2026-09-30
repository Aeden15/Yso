Yso = Yso or {}
Yso.magi = Yso.magi or {}
Yso.magi.elemental = Yso.magi.elemental or {}

local M = Yso.magi.elemental

M.cfg = M.cfg or {}
M.cfg.destroy = M.cfg.destroy or {
  require_conflagration = true,
  hp_threshold = 40,
  enforce_hp_gate = false,
}

M.state = M.state or {}
M.state.timers = M.state.timers or {}
M.state.destroy_hp_stub_noted = M.state.destroy_hp_stub_noted or false

local function _now()
  local t = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  if t and t > 1000000000000 then t = t / 1000 end
  return t or os.time()
end

local function _echo(msg)
  if type(cecho) == "function" then
    cecho(string.format("<SlateBlue>[Magi] <white>%s\n", tostring(msg)))
  end
end

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
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

function M.get_target_hp_percent(_target_name)
  local RC = Yso and Yso.off and Yso.off.magi and Yso.off.magi.route_core
  if type(RC) == "table" and type(RC.get_target_hp_percent) == "function" then
    local ok, v = pcall(RC.get_target_hp_percent, _target_name)
    if ok and tonumber(v) then return tonumber(v) end
  end
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
