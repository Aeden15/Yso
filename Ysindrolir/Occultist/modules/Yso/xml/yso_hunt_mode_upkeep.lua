-- Auto-exported from Mudlet package script: Yso_hunt_mode_upkeep
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- yso_hunt_mode_upkeep.lua (DROP-IN)
-- Bash mode upkeep + Orb Defense Controller + Bash Shielding
--
-- Key fixes:
--   • Safe default-merge into existing M.cfg / M.state so reloading won’t nil-index.
--   • Occultist-only gating: no entourage/entity/orb/pathfinder upkeep on non-Occultist classes.
--   • Bash-mode naming: Yso bash mode replaces the old hunt-mode label.
--
-- Bash shielding:
--   • If HP% <= 50 and shield not active -> touch shield + cecho:
--       <aquamarine>[CURING:] <yellow>(SHIELDING UP!)
--   • Tracks shield UP/DOWN + generalized “translucent hammer ... smashes” (any denizen)
--========================================================--

_G.Yso = _G.Yso or _G.yso or {}
_G.yso = _G.Yso
local Yso = _G.Yso

Yso.huntmode = Yso.huntmode or {}
local M = Yso.huntmode

local function _now()
  return (type(getEpoch) == "function" and getEpoch()) or os.time()
end

local function _merge(dst, src)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src or {}) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      _merge(dst[k], v)
    else
      if dst[k] == nil then dst[k] = v end
    end
  end
  return dst
end

local function _send(cmd)
  if not cmd or cmd == "" then return end
  if type(send) == "function" then
    send(cmd, false)
  elseif type(expandAlias) == "function" then
    expandAlias(cmd)
  end
end

local function _current_class()
  if type(Yso.classinfo) == "table" and type(Yso.classinfo.get) == "function" then
    local cls = Yso.classinfo.get()
    if type(cls) == "string" and cls ~= "" then return cls end
  end
  local cls = gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class
  if type(cls) == "string" and cls ~= "" then return cls end
  cls = rawget(_G, "Yso") and rawget(_G.Yso, "class") or nil
  if type(cls) == "string" and cls ~= "" then return cls end
  return ""
end

local function _is_occultist()
  return _current_class() == "Occultist"
end

local function _is_bash_mode()
  local require_bash = true
  if M.cfg then
    if M.cfg.require_bash_mode ~= nil then require_bash = (M.cfg.require_bash_mode == true)
    elseif M.cfg.require_hunt_mode ~= nil then require_bash = (M.cfg.require_hunt_mode == true) end
  end
  if not require_bash then return true end

  if Yso.mode then
    if type(Yso.mode.is_bash) == "function" then return Yso.mode.is_bash() == true end
    if type(Yso.mode.is_hunt) == "function" then return Yso.mode.is_hunt() == true end
    local s = tostring(Yso.mode.state or ""):lower()
    return s == "bash" or s == "hunt"
  end
  return false
end

local function _legacy_basher_active()
  local legacy = rawget(_G, "Legacy")
  local basher = legacy and legacy.Settings and legacy.Settings.Basher
  if type(basher) == "table" and basher.status ~= nil then
    return basher.status == true
  end
  return true
end

local function _is_active_bash_mode()
  return _is_occultist() and _is_bash_mode() and _legacy_basher_active()
end

local function _echo_yso(msg)
  if not (M.cfg and M.cfg.echo) then return end
  if type(cecho) == "function" then
    cecho("<aquamarine>[Yso] <reset>" .. tostring(msg) .. "<reset>\n")
  elseif type(echo) == "function" then
    echo("[Yso] " .. tostring(msg) .. "\n")
  end
end

local function _echo_curing_shield()
  if type(cecho) == "function" then
    cecho("<aquamarine>[CURING:] <yellow>(SHIELDING UP!)<reset>\n")
  elseif type(echo) == "function" then
    echo("[CURING:] (SHIELDING UP!)\n")
  end
end

local function _dbg(msg)
  if M.cfg and M.cfg.debug then _echo_yso("DBG: "..tostring(msg)) end
end

local function _safe(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then _dbg("ERR: "..tostring(err)) end
  end
end

local function _priority_send(cmd)
  if not cmd or cmd == "" then return end
  if M.cfg and M.cfg.priority and M.cfg.priority.enabled and M.cfg.priority.clear_cmd then
    _send(M.cfg.priority.clear_cmd)
  end
  _send(cmd)
end

local function _queue_call(mode, qtype, cmd)
  local Q = Yso and Yso.queue
  local fn = Q and Q[mode]
  if type(fn) ~= "function" then return false end
  local ok = pcall(fn, qtype, cmd)
  return ok == true
end

local function _orb_controller()
  local dom = Yso and Yso.dom
  local orbdef = dom and dom.orbdef
  if type(orbdef) == "table" and type(orbdef.cmd) == "function" then
    return orbdef
  end
  return nil
end

local function _orb_issue(flag, priority)
  local C = M.cfg.orb or {}

  if flag == "s" then
    if _queue_call(tostring(C.queue_summon_mode or "addclear"), C.queue_summon or "free", C.summon_cmd) then
      return true
    end
  elseif flag == "d" then
    if _queue_call(tostring(C.queue_mode or "addclearfull"), C.queue_defense or "class", C.command_cmd) then
      return true
    end
  end

  local orbdef = _orb_controller()
  if orbdef then
    local ok = pcall(orbdef.cmd, flag)
    if ok then return true end
  end

  if flag == "s" then
    if priority then _priority_send(C.summon_cmd) else _send(C.summon_cmd) end
    return true
  end

  if flag == "d" then
    _priority_send(C.command_cmd)
    return true
  end

  return false
end

local function _hp_pct()
  local v = gmcp and gmcp.Char and gmcp.Char.Vitals
  if not v then return M.state.hp_pct or 1.0 end

  local hpperc = v.hpperc or v.healthperc
  if hpperc ~= nil then
    local s = tostring(hpperc):gsub("%%","")
    local p = tonumber(s)
    if p then return p / 100 end
  end

  local hp = tonumber(v.hp or v.health or 0) or 0
  local mh = tonumber(v.maxhp or v.max_health or 0) or 0
  if mh <= 0 then return M.state.hp_pct or 1.0 end
  return hp / mh
end

local function _expired_pending(since_ts, timeout)
  local n = _now()
  timeout = timeout or 8.0
  return since_ts ~= 0 and (n - since_ts) >= timeout
end

local defaults_cfg = {
  enabled = true,
  require_bash_mode = true,
  require_hunt_mode = true,
  echo = true,
  debug = false,

  priority = { enabled = true, clear_cmd = "clearqueue all" },

  ent = { enabled = true, cmd = "ent", request_gcd = 10.0, inflight_timeout = 3.5 },

  shield = {
    enabled = true,
    hp_threshold = 0.50,
    reset_threshold = 0.55,
    cmd = "touch shield",
    gcd = 10.0,
    priority = false,

    up_line   = [[^You touch the tattoo and a nearly invisible magical shield forms around you\.$]],
    down_line = [[^Your action causes the nearly invisible magical shield around you to fade away\.$]],
    smash_line = [[^(?:A|An) massive, translucent hammer rises out of (?:a|an|the) .+(?:'s|s') tattoo and smashes your magical shield\.$]],
  },

  orb = {
    enabled = true,
    hp_threshold = 0.40,

    command_cmd = "command orb",
    summon_cmd  = "summon orb",
    queue_mode = "addclearfull",
    queue_defense = "class",
    queue_summon_mode = "addclear",
    queue_summon = "free",

    command_gcd = 1.0,
    summon_gcd  = 1.0,
    pending_timeout = 8.0,

    enact_line   = [[^A ripple of power washes across your skin\.$]],
    fade_line    = [[^Abruptly, the power rippling across your skin dissipates\.$]],
    consume_line = [[^You command your chaos orb to grant you protection; it pulses once before detonating in a soundless conflagration\.$]],
    defmsg_line  = [[^Surrounded by the power of Arctar\.$]],
  },

  upkeep = {
    enabled = true,
    throttle = 10,

    hound_enabled      = true,
    pathfinder_enabled = true,

    hound_cmd      = "summon lycantha",
    pathfinder_cmd = "summon pathfinder",

    mask_enabled = true,
    mask_cmd = "mask",
    mask_on_line = [[^Calling upon your powers within, you mask the movements of your chaos entities from the world\.$]],
  },
}

local defaults_state = {
  hp_pct = 1.0,
  last_upkeep = 0,

  present = { orb = false, hound = false, pathfinder = false },

  ent = {
    synced = false,
    scanning = false,
    inflight = false,
    inflight_until = 0,
    last_request = 0,
    last_sync = 0,
    buf = {},
  },

  shield = {
    armed = false,
    active = false,
    last_try = 0,
  },

  orb = {
    defense_active = false,
    want_command_on_expire = false,
    want_command_after_summon = false,

    command_pending = false,
    summon_pending  = false,

    last_command_try = 0,
    last_summon_try  = 0,

    command_pending_since = 0,
    summon_pending_since  = 0,
  },

  mask = { active = false, last_try = 0 },
}

M.cfg = _merge(M.cfg or {}, defaults_cfg)
M.state = _merge(M.state or {}, defaults_state)
if M.cfg.require_bash_mode == nil and M.cfg.require_hunt_mode ~= nil then
  M.cfg.require_bash_mode = M.cfg.require_hunt_mode
end
if M.cfg.require_hunt_mode == nil and M.cfg.require_bash_mode ~= nil then
  M.cfg.require_hunt_mode = M.cfg.require_bash_mode
end

local function ent_tick()
  local e = M.state.ent
  if e.inflight and _now() > (e.inflight_until or 0) then
    e.inflight = false
    e.scanning = false
    e.buf = {}
    _dbg("ENT inflight timeout")
  end
end

local function ent_request()
  if not (M.cfg.enabled and M.cfg.ent.enabled) then return false end
  if not _is_active_bash_mode() then return false end

  local e = M.state.ent
  local n = _now()

  ent_tick()
  if e.scanning or e.inflight then return false end
  if (n - (e.last_request or 0)) < (M.cfg.ent.request_gcd or 10.0) then return false end

  e.last_request = n
  e.inflight = true
  e.inflight_until = n + (M.cfg.ent.inflight_timeout or 3.5)
  e.buf = {}

  _send(M.cfg.ent.cmd or "ent")
  return true
end

local function ent_finalize_from_block(block)
  local e = M.state.ent
  block = tostring(block or ""):gsub("\n+", " "):lower()

  local seen = { orb = false, hound = false, pathfinder = false }
  if block:find("chaos orb#%d+") then seen.orb = true end
  if block:find("chaos hound#%d+") then seen.hound = true end
  if block:find("pathfinder#%d+") then seen.pathfinder = true end

  M.state.present.orb = seen.orb
  M.state.present.hound = seen.hound
  M.state.present.pathfinder = seen.pathfinder

  e.synced = true
  e.scanning = false
  e.inflight = false
  e.inflight_until = 0
  e.last_sync = _now()
  e.buf = {}

  _dbg(("ENT synced: orb=%s hound=%s pathfinder=%s"):format(tostring(seen.orb), tostring(seen.hound), tostring(seen.pathfinder)))
end

local function ent_finalize_none()
  local e = M.state.ent
  M.state.present.orb = false
  M.state.present.hound = false
  M.state.present.pathfinder = false

  e.synced = true
  e.scanning = false
  e.inflight = false
  e.inflight_until = 0
  e.last_sync = _now()
  e.buf = {}

  _dbg("ENT synced: none present")
end

local function shield_on_hp_update()
  local C = M.cfg.shield
  if not (M.cfg.enabled and C.enabled) then return end
  if not _is_active_bash_mode() then return end

  local s = M.state.shield
  local n = _now()
  local hp = M.state.hp_pct or 1.0

  if hp >= (C.reset_threshold or 0.55) then
    s.armed = false
    return
  end

  if s.active then return end

  if hp <= (C.hp_threshold or 0.50) and not s.armed then
    if (n - (s.last_try or 0)) < (C.gcd or 10.0) then return end
    s.last_try = n
    s.armed = true

    _echo_curing_shield()
    if C.priority then _priority_send(C.cmd) else _send(C.cmd) end
  end
end

local function orb_mark_defense_active()
  M.state.orb.defense_active = true
end

local function orb_try_summon(priority)
  local C = M.cfg.orb
  if not (M.cfg.enabled and C.enabled) then return false end
  if not _is_active_bash_mode() then return false end

  local o = M.state.orb
  local n = _now()

  if M.state.present.orb then
    o.summon_pending = false
    o.summon_pending_since = 0
    return false
  end

  if o.summon_pending and not _expired_pending(o.summon_pending_since or 0, C.pending_timeout) then return false end
  if (n - (o.last_summon_try or 0)) < (C.summon_gcd or 1.0) then return false end

  o.last_summon_try = n
  o.summon_pending = true
  o.summon_pending_since = n

  return _orb_issue("s", priority)
end

local function orb_try_command()
  local C = M.cfg.orb
  if not (M.cfg.enabled and C.enabled) then return false end
  if not _is_active_bash_mode() then return false end

  local o = M.state.orb
  local n = _now()
  local hp = M.state.hp_pct or 1.0

  if hp > (C.hp_threshold or 0.40) then return false end
  if o.defense_active then
    o.want_command_on_expire = true
    return false
  end

  if o.command_pending and not _expired_pending(o.command_pending_since or 0, C.pending_timeout) then return false end
  if (n - (o.last_command_try or 0)) < (C.command_gcd or 1.0) then return false end

  if not M.state.present.orb then
    o.want_command_after_summon = true
    return orb_try_summon(true)
  end

  o.last_command_try = n
  o.command_pending = true
  o.command_pending_since = n

  return _orb_issue("d", true)
end

local function orb_on_defense_fade()
  local o = M.state.orb
  o.defense_active = false
  if not _is_active_bash_mode() then return end
  if (M.state.hp_pct or 1.0) <= (M.cfg.orb.hp_threshold or 0.40) then
    o.want_command_on_expire = false
    orb_try_command()
  else
    o.want_command_on_expire = false
  end
end

local function orb_on_consume()
  local o = M.state.orb
  o.command_pending = false
  o.command_pending_since = 0

  M.state.present.orb = false
  orb_mark_defense_active()

  if (M.state.hp_pct or 1.0) <= (M.cfg.orb.hp_threshold or 0.40) then
    o.want_command_on_expire = true
    o.want_command_after_summon = false
  end

  orb_try_summon(true)
end

local function orb_on_summoned()
  local o = M.state.orb
  M.state.present.orb = true
  o.summon_pending = false
  o.summon_pending_since = 0

  if o.want_command_after_summon
     and (M.state.hp_pct or 1.0) <= (M.cfg.orb.hp_threshold or 0.40)
     and not o.defense_active
  then
    o.want_command_after_summon = false
    orb_try_command()
  end
end

local function orb_on_hp_update()
  if not (M.cfg.enabled and M.cfg.orb.enabled) then return end
  if not _is_active_bash_mode() then return end

  if (M.state.hp_pct or 1.0) <= (M.cfg.orb.hp_threshold or 0.40) then
    orb_try_command()
  else
    M.state.orb.want_command_on_expire = false
    M.state.orb.want_command_after_summon = false
  end
end

local function upkeep_tick()
  if not (M.cfg.enabled and M.cfg.upkeep.enabled) then return end
  if not _is_active_bash_mode() then return end

  ent_tick()

  local n = _now()
  if (n - (M.state.last_upkeep or 0)) < (M.cfg.upkeep.throttle or 10) then return end
  M.state.last_upkeep = n

  if M.cfg.ent.enabled and not M.state.ent.synced then
    ent_request()
  end

  if M.cfg.upkeep.mask_enabled and not M.state.mask.active and (n - (M.state.mask.last_try or 0)) > 30 then
    M.state.mask.last_try = n
    _send(M.cfg.upkeep.mask_cmd)
  end

  if M.cfg.ent.enabled and not M.state.ent.synced then return end

  if not M.state.present.orb and not M.state.orb.defense_active then
    orb_try_summon(false)
  end
  if M.cfg.upkeep.hound_enabled and not M.state.present.hound then
    _send(M.cfg.upkeep.hound_cmd)
  end
  if M.cfg.upkeep.pathfinder_enabled and not M.state.present.pathfinder then
    _send(M.cfg.upkeep.pathfinder_cmd)
  end
end

local function _reset_ent_sync()
  M.state.ent.synced = false
  M.state.ent.scanning = false
  M.state.ent.inflight = false
  M.state.ent.inflight_until = 0
  M.state.ent.buf = {}
end

local function _clear_orb_pending()
  M.state.orb.command_pending = false
  M.state.orb.summon_pending = false
  M.state.orb.command_pending_since = 0
  M.state.orb.summon_pending_since = 0
  M.state.orb.want_command_on_expire = false
  M.state.orb.want_command_after_summon = false
end

local function _refresh_active_upkeep()
  if not _is_active_bash_mode() then return end
  _reset_ent_sync()
  ent_request()

  M.state.hp_pct = _hp_pct()
  shield_on_hp_update()
  orb_on_hp_update()
  upkeep_tick()
end

M._trig = M._trig or {}
local function _kill_tr(id) if id and type(killTrigger) == "function" then killTrigger(id) end end

_kill_tr(M._trig.shield_up)
M._trig.shield_up = tempRegexTrigger(M.cfg.shield.up_line, _safe(function()
  M.state.shield.active = true
end))

_kill_tr(M._trig.shield_down)
M._trig.shield_down = tempRegexTrigger(M.cfg.shield.down_line, _safe(function()
  M.state.shield.active = false
  if (M.state.hp_pct or 1.0) <= (M.cfg.shield.hp_threshold or 0.50) then
    M.state.shield.armed = false
  end
end))

_kill_tr(M._trig.shield_smash)
M._trig.shield_smash = tempRegexTrigger(M.cfg.shield.smash_line, _safe(function()
  M.state.shield.active = false
  if (M.state.hp_pct or 1.0) <= (M.cfg.shield.hp_threshold or 0.50) then
    M.state.shield.armed = false
  end
end))

_kill_tr(M._trig.ent_header)
M._trig.ent_header = tempRegexTrigger([[^The following beings are in your entourage:]], _safe(function()
  local e = M.state.ent
  if not e.inflight then return end
  e.scanning = true
  e.buf = {}
end))

_kill_tr(M._trig.ent_none)
M._trig.ent_none = tempRegexTrigger([[^There are no beings in your entourage\.$]], _safe(function()
  local e = M.state.ent
  if not e.inflight then return end
  ent_finalize_none()
end))

_kill_tr(M._trig.ent_line)
M._trig.ent_line = tempRegexTrigger([[#\d+]], _safe(function()
  local e = M.state.ent
  if not (e.inflight and e.scanning) then return end
  local ln = getCurrentLine() or ""
  if ln:find("#%d+") then
    e.buf[#e.buf + 1] = ln
    if ln:match("%.%s*$") then
      ent_finalize_from_block(table.concat(e.buf, "\n"))
    end
  end
end))

_kill_tr(M._trig.summon_orb)
M._trig.summon_orb = tempRegexTrigger([[^A swirling portal of chaos opens, spits out a chaos orb, then vanishes\.]], _safe(orb_on_summoned))

_kill_tr(M._trig.summon_hound)
M._trig.summon_hound = tempRegexTrigger([[^A swirling portal of chaos opens, spits out a chaos hound, then vanishes\.]], _safe(function()
  M.state.present.hound = true
end))

_kill_tr(M._trig.summon_pathfinder)
M._trig.summon_pathfinder = tempRegexTrigger([[^A swirling portal of chaos opens, spits out a pathfinder, then vanishes\.]], _safe(function()
  M.state.present.pathfinder = true
end))

_kill_tr(M._trig.orb_consume)
M._trig.orb_consume = tempRegexTrigger(M.cfg.orb.consume_line, _safe(orb_on_consume))

_kill_tr(M._trig.orb_enact)
M._trig.orb_enact = tempRegexTrigger(M.cfg.orb.enact_line, _safe(function()
  M.state.orb.command_pending = false
  M.state.orb.command_pending_since = 0
  orb_mark_defense_active()
end))

_kill_tr(M._trig.orb_defmsg)
M._trig.orb_defmsg = tempRegexTrigger(M.cfg.orb.defmsg_line, _safe(orb_mark_defense_active))

_kill_tr(M._trig.orb_fade)
M._trig.orb_fade = tempRegexTrigger(M.cfg.orb.fade_line, _safe(orb_on_defense_fade))

_kill_tr(M._trig.mask_on)
M._trig.mask_on = tempRegexTrigger(M.cfg.upkeep.mask_on_line, _safe(function()
  M.state.mask.active = true
end))

M._eh = M._eh or {}
local function _kill_eh(id)
  if id and type(killAnonymousEventHandler) == "function" then
    killAnonymousEventHandler(id)
  end
end

_kill_eh(M._eh.vitals)
M._eh.vitals = registerAnonymousEventHandler("gmcp.Char.Vitals", _safe(function()
  if not (M.cfg and M.cfg.enabled) then return end
  M.state.hp_pct = _hp_pct()

  shield_on_hp_update()
  orb_on_hp_update()
  upkeep_tick()
end))

local function _norm_mode_name(mode)
  mode = tostring(mode or ""):lower()
  if mode == "hunt" then return "bash" end
  return mode
end

_kill_eh(M._eh.mode_changed)
M._eh.mode_changed = registerAnonymousEventHandler("yso.mode.changed", _safe(function(_old, newMode)
  if not (M.cfg and M.cfg.enabled) then return end
  if not _is_occultist() then return end
  if _norm_mode_name(newMode) ~= "bash" then return end
  _refresh_active_upkeep()
end))

_kill_eh(M._eh.legacy_basher)
M._eh.legacy_basher = registerAnonymousEventHandler("LegacyBasherStatus", _safe(function(enabled)
  if not (M.cfg and M.cfg.enabled) then return end
  if not _is_occultist() then return end

  if enabled == true then
    M.state.last_upkeep = 0
    _refresh_active_upkeep()
    return
  end

  _reset_ent_sync()
  _clear_orb_pending()
  M.state.last_upkeep = 0
end))

_echo_yso("Bash upkeep loaded (Occultist-gated)")
--========================================================--
