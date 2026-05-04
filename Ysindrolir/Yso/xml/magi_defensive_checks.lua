Yso = Yso or {}
Yso.magi = Yso.magi or {}
Yso.magi.defs = Yso.magi.defs or {}

local M = Yso.magi.defs

M.cfg = M.cfg or {
  auto_reflect = false,            -- master toggle
  reflect_threshold = 40,          -- cast at/below this HP %
  reflect_command = "cast reflection at me",
  min_retry = 2.5,                 -- anti-spam gap in seconds
  echo = true,
}

M.state = M.state or {
  class_name = "",
  reflection_up = false,
  last_attempt = 0,
  vitals_eh = nil,
}

local function _now()
  return (type(getEpoch) == "function" and getEpoch()) or os.time()
end

local function _echo(msg)
  if M.cfg.echo then
    cecho(string.format("<SlateBlue>[Magi] <white>%s\n", msg))
  end
end

local function _vitals()
  return (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
end

local function _status()
  return (gmcp and gmcp.Char and gmcp.Char.Status) or {}
end

function M.get_hp_percent()
  local v = _vitals()
  local hp = tonumber(v.hp)
  local maxhp = tonumber(v.maxhp)

  if not hp or not maxhp or maxhp <= 0 then
    return nil
  end

  return (hp / maxhp) * 100
end

function M.get_class()
  local s = _status()
  local cls = s.class or s.classname or M.state.class_name or ""
  return tostring(cls)
end

function M.is_magi()
  return M.get_class():lower() == "magi"
end

function M.set_class(classname)
  M.state.class_name = tostring(classname or "")
end

function M.set_reflection_up(is_up)
  M.state.reflection_up = not not is_up
end

function M.enable()
  M.cfg.auto_reflect = true
  _echo(string.format("Auto-reflect ON at %d%%.", M.cfg.reflect_threshold))
end

function M.disable()
  M.cfg.auto_reflect = false
  _echo("Auto-reflect OFF.")
end

function M.toggle()
  M.cfg.auto_reflect = not M.cfg.auto_reflect
  _echo(string.format(
    "Auto-reflect %s at %d%%.",
    M.cfg.auto_reflect and "ON" or "OFF",
    M.cfg.reflect_threshold
  ))
end

function M.set_threshold(pct)
  pct = tonumber(pct)
  if not pct then
    _echo("Invalid threshold.")
    return
  end

  pct = math.floor(pct)
  if pct < 1 then pct = 1 end
  if pct > 95 then pct = 95 end

  M.cfg.reflect_threshold = pct
  _echo(string.format("Auto-reflect threshold set to %d%%.", pct))
end

function M.status()
  local hp_pct = M.get_hp_percent()
  _echo(string.format(
    "auto=%s threshold=%d%% reflect_up=%s class=%s hp=%s",
    tostring(M.cfg.auto_reflect),
    tonumber(M.cfg.reflect_threshold or 0),
    tostring(M.state.reflection_up),
    M.get_class(),
    hp_pct and string.format("%.1f%%", hp_pct) or "n/a"
  ))
end

function M.should_reflect()
  if not M.cfg.auto_reflect then
    return false
  end

  if not M.is_magi() then
    return false
  end

  if M.state.reflection_up then
    return false
  end

  local hp_pct = M.get_hp_percent()
  if not hp_pct then
    return false
  end

  if hp_pct > tonumber(M.cfg.reflect_threshold or 40) then
    return false
  end

  local v = _vitals()

  -- Reflection is a cast; eq gating helps prevent spam.
  -- Remove this check if you explicitly do not want eq gating.
  if tostring(v.eq or "") ~= "1" then
    return false
  end

  if (_now() - (M.state.last_attempt or 0)) < (M.cfg.min_retry or 2.5) then
    return false
  end

  return true
end

function M.try_reflect()
  if not M.should_reflect() then
    return false
  end

  M.state.last_attempt = _now()
  send(M.cfg.reflect_command)
  _echo(string.format("Casting reflection at %.1f%% HP.", M.get_hp_percent() or 0))
  return true
end

function M.on_vitals()
  M.try_reflect()
end

function M.install()
  if M.state.vitals_eh then
    killAnonymousEventHandler(M.state.vitals_eh)
    M.state.vitals_eh = nil
  end

  M.state.vitals_eh = registerAnonymousEventHandler("gmcp.Char.Vitals", "Yso.magi.defs.on_vitals")
  _echo("Auto-reflect module installed.")
end

M.install()
