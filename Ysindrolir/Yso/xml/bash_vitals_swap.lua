-- Auto-exported from Mudlet package script: Bash Vitals Swap
-- Yso/Curing/bash_vitals_swap.lua
-- Bash/hunt-only dynamic sip+moss threshold manager.

Yso = Yso or {}
Yso.curing = Yso.curing or {}
Yso.curing.bash_vitals_swap = Yso.curing.bash_vitals_swap or {}

Legacy = Legacy or {}

local B = Yso.curing.bash_vitals_swap

B.cfg = B.cfg or {
  enabled = true,
  restore_on_exit = true,

  enter = {
    hp_at_or_above = 85,
    mp_below = 50,
  },

  leave = {
    mp_at_or_above = 80,
  },

  normal = {
    priority = "health",
    sipHealth = 85,
    sipMana = 65,
    mossHealth = 80,
    mossMana = 60,
  },

  mana_recovery = {
    priority = "mana",
    sipHealth = 60,
    sipMana = 80,
    mossHealth = 50,
    mossMana = 70,
  },
}

B.state = B.state or {
  active_scope = false,
  mode = "normal",
  saved = nil,
  last_reason = "init",
}

B._eh = B._eh or {}

local function _num(v)
  return tonumber(v)
end

local function _norm(s)
  return tostring(s or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function _pct(cur, max)
  cur = _num(cur) or 0
  max = _num(max) or 0
  if max <= 0 then return nil end
  return math.floor((cur / max) * 100)
end

local function _echo(msg)
  if Legacy and type(Legacy.echo) == "function" then
    Legacy.echo("<cyan>[Yso:BashCure]<white> " .. tostring(msg))
  elseif type(cecho) == "function" then
    cecho("\n<cyan>[Yso:BashCure]<white> " .. tostring(msg))
  end
end

local function _send(cmd)
  cmd = tostring(cmd or "")
  if cmd == "" then return false end
  if type(send) == "function" then
    send(cmd, false)
    return true
  end
  return false
end

local function _settings()
  Legacy.Settings = Legacy.Settings or {}
  Legacy.Settings.Curing = Legacy.Settings.Curing or {}
  Legacy.Settings.Curing.SS = Legacy.Settings.Curing.SS or {}
  Legacy.Settings.Curing.SS.Settings = Legacy.Settings.Curing.SS.Settings or {}
  return Legacy.Settings.Curing.SS.Settings
end

local function _active_serverset()
  if Legacy and Legacy.Curing and type(Legacy.Curing.ActiveServerSet) == "string" then
    return _norm(Legacy.Curing.ActiveServerSet)
  end
  return ""
end

local function _is_bash_mode()
  local mode = Yso and Yso.mode
  if type(mode) ~= "table" then return false end

  if type(mode.is_bash) == "function" then
    local ok, v = pcall(mode.is_bash)
    if ok and v == true then return true end
  end

  if type(mode.is_hunt) == "function" then
    local ok, v = pcall(mode.is_hunt)
    if ok and v == true then return true end
  end

  local state = _norm(mode.state)
  return state == "bash" or state == "hunt"
end

local function _scope_active()
  if B.cfg.enabled ~= true then return false end
  return _is_bash_mode() or _active_serverset() == "hunt"
end

local function _vitals_pct()
  local v = gmcp and gmcp.Char and gmcp.Char.Vitals
  if type(v) ~= "table" then return nil, nil end
  return _pct(v.hp, v.maxhp), _pct(v.mp, v.maxmp)
end

local function _snapshot_current()
  local st = _settings()
  return {
    priority = _norm(st.sipPrio ~= nil and st.sipPrio or "Health"),
    sipHealth = _num(st.sipHealth) or B.cfg.normal.sipHealth,
    sipMana = _num(st.sipMana) or B.cfg.normal.sipMana,
    mossHealth = _num(st.mossHealth) or B.cfg.normal.mossHealth,
    mossMana = _num(st.mossMana) or B.cfg.normal.mossMana,
  }
end

local function _same_profile(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  return _norm(a.priority) == _norm(b.priority)
    and _num(a.sipHealth) == _num(b.sipHealth)
    and _num(a.sipMana) == _num(b.sipMana)
    and _num(a.mossHealth) == _num(b.mossHealth)
    and _num(a.mossMana) == _num(b.mossMana)
end

local function _cache_profile(profile)
  local st = _settings()
  st.sipPrio = (_norm(profile.priority) == "mana") and "Mana" or "Health"
  st.sipHealth = _num(profile.sipHealth)
  st.sipMana = _num(profile.sipMana)
  st.mossHealth = _num(profile.mossHealth)
  st.mossMana = _num(profile.mossMana)
end

local function _apply_profile(profile, label)
  if type(profile) ~= "table" then return false end

  local current = _snapshot_current()
  if _same_profile(current, profile) then
    B.state.mode = (_norm(profile.priority) == "mana") and "mana_recovery" or "normal"
    return false
  end

  _send(("curing priority %s"):format(string.upper(_norm(profile.priority))))
  _send(("curing siphealth %d"):format(profile.sipHealth))
  _send(("curing sipmana %d"):format(profile.sipMana))
  _send(("curing mosshealth %d"):format(profile.mossHealth))
  _send(("curing mossmana %d"):format(profile.mossMana))

  _cache_profile(profile)
  B.state.mode = (_norm(profile.priority) == "mana") and "mana_recovery" or "normal"

  if label and label ~= "" then
    _echo("Applied " .. tostring(label))
  end
  return true
end

local function _enter_scope(reason)
  if B.state.active_scope == true then return end
  B.state.active_scope = true
  B.state.last_reason = tostring(reason or "enter")
  B.state.saved = _snapshot_current()
end

local function _leave_scope(reason)
  if B.state.active_scope ~= true then return end
  B.state.active_scope = false
  B.state.last_reason = tostring(reason or "leave")

  if B.cfg.restore_on_exit == true and type(B.state.saved) == "table" then
    _apply_profile(B.state.saved, "pre-scope curing")
  end

  B.state.saved = nil
  B.state.mode = "normal"
end

function B.refresh(reason)
  reason = tostring(reason or "refresh")

  local active = _scope_active()
  if active then
    _enter_scope(reason)
  else
    _leave_scope(reason)
    return false
  end

  local hp, mp = _vitals_pct()
  if not hp or not mp then return false end

  if B.state.mode == "mana_recovery" then
    if mp >= (tonumber(B.cfg.leave.mp_at_or_above) or 80) then
      _apply_profile(B.cfg.normal, "normal bash curing")
    else
      _apply_profile(B.cfg.mana_recovery, "mana recovery")
    end
    return true
  end

  if hp >= (tonumber(B.cfg.enter.hp_at_or_above) or 85)
     and mp < (tonumber(B.cfg.enter.mp_below) or 50) then
    _apply_profile(B.cfg.mana_recovery, "mana recovery")
  else
    _apply_profile(B.cfg.normal, "normal bash curing")
  end

  return true
end

function B.status()
  local hp, mp = _vitals_pct()
  _echo(string.format(
    "scope=%s mode=%s set=%s hp=%s mp=%s",
    tostring(B.state.active_scope == true),
    tostring(B.state.mode),
    tostring(_active_serverset()),
    tostring(hp or "?"),
    tostring(mp or "?")
  ))
end

if B._eh.vitals then killAnonymousEventHandler(B._eh.vitals) end
B._eh.vitals = registerAnonymousEventHandler("gmcp.Char.Vitals", function()
  B.refresh("gmcp:vitals")
end)

if B._eh.mode_changed then killAnonymousEventHandler(B._eh.mode_changed) end
B._eh.mode_changed = registerAnonymousEventHandler("yso.mode.changed", function(_, _old, new, why)
  B.refresh("mode:" .. tostring(new or why or "changed"))
end)

if B._eh.basher_status then killAnonymousEventHandler(B._eh.basher_status) end
B._eh.basher_status = registerAnonymousEventHandler("LegacyBasherStatus", function(_, active)
  B.refresh("basher:" .. tostring(active))
end)

B.refresh("load")

return B
