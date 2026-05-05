--========================================================--
-- yso_modes.lua (DROP-IN)
-- Purpose:
--   * Central "mode of play" switch for Yso
--   * Modes: "bash" (hunt) and "combat" only
--   * All combat routes (duel, group, aurify, focus, …) run when mode is combat
--   * Non-destructive: only flips optional toggles if present
--
-- API:
--   Yso.mode.set("bash"|"combat"[, reason])
--   Yso.mode.toggle([reason])                 -- toggles bash <-> combat
--   Yso.mode.is_bash() / is_hunt() / is_combat()
--   raiseEvent("yso.mode.changed", old, new, reason) on mode change
--
-- Runtime aliases (tempAlias, auto-registered if available):
--   ^hunt$    -> switch to bash mode without forcing a huntmode reset on noop
--   ^mbash$   -> if already in bash, force a huntmode refresh/reset
--
-- Back-compat:
--   * "hunt" normalizes to "bash"
--   * is_hunt() remains available and maps to bash mode
--========================================================--

-- Normalize namespace so both _G.Yso and _G.yso point to the same table.
_G.Yso = _G.Yso or _G.yso or {}
_G.yso = _G.Yso

Yso = _G.Yso
Yso.mode = Yso.mode or {}

local M = Yso.mode

local function _now()
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _norm(s)
  s = tostring(s or ""):lower()
  s = s:gsub("^%s+",""):gsub("%s+$","")
  if s == "pvp" then s = "combat" end
  if s == "pve" or s == "hunt" or s == "hunting" or s == "bashing" then s = "bash" end
  return s
end

local function _echo(msg)
  if not (M.cfg and M.cfg.echo) then return end
  if type(cecho) == "function" then
    cecho("<aquamarine>[Yso] <reset>" .. tostring(msg) .. "<reset>" .. string.char(10))
  elseif type(echo) == "function" then
    echo("[Yso] " .. tostring(msg) .. string.char(10))
  end
end

M.cfg = M.cfg or {
  default = "combat",
  echo = true,
  install_mode_aliases = true,
}

M.profile = M.profile or {
  bash = {
    toggles = {
      offense  = false,
      affcall  = false,
      debug    = false,
      travel   = true,
      autoloot = true,
    },
  },
  combat = {
    toggles = {
      offense  = true,
      affcall  = true,
      debug    = true,
      travel   = false,
      autoloot = false,
      parry    = true,
    },
  },
}

if not M.profile.bash and M.profile.hunt then M.profile.bash = M.profile.hunt end
if not M.profile.hunt and M.profile.bash then M.profile.hunt = M.profile.bash end

M.state = M.state or _norm(M.cfg.default or "combat")
M.state = _norm(M.state)
M.last_change = M.last_change or _now()
M.last_reason = M.last_reason or "init"

M.route_loop = M.route_loop or {
  active = "",
  last_change = _now(),
  last_reason = "init",
  activating_id = "",
  nudges = {},
  nudge_dedupe_s = 0.05,
}

local function _route_norm(r)
  r = _norm(r)
  if r == "dmg" then r = "dam" end
  return r
end

local function _route_registry()
  local RR = Yso and Yso.Combat and Yso.Combat.RouteRegistry or nil
  if RR and type(RR.resolve) == "function" then return RR end
  return nil
end

local function _route_module(entry)
  local ns = type(entry) == "table" and tostring(entry.namespace or "") or ""
  if ns == "" then return nil end
  local cur = _G
  for part in ns:gmatch("[^%.]+") do
    if type(cur) ~= "table" then return nil end
    cur = cur[part]
  end
  return type(cur) == "table" and cur or nil
end

local function _ensure_route_module(entry)
  local mod = _route_module(entry)
  if mod then return mod end
  return _route_module(entry)
end

local function _route_entries()
  local RR = _route_registry()
  if not (RR and type(RR.active_ids) == "function" and type(RR.resolve) == "function") then
    return {}
  end
  local out = {}
  local ids = RR.active_ids()
  for i = 1, #ids do
    local entry = RR.resolve(ids[i])
    if entry then out[#out + 1] = entry end
  end
  return out
end

local function _stop_all_route_loops(reason, silent)
  local RR = _route_registry()
  if not RR or type(RR.active_ids) ~= "function" then return end
  local ids = RR.active_ids()
  for i = 1, #ids do
    local id = ids[i]
    if id and id ~= "" and type(M.stop_route_loop) == "function" then
      pcall(M.stop_route_loop, id, reason or "stop_all", silent == true)
    end
  end
end

function M.is_bash()   return M.state == "bash" end
function M.is_hunt()   return M.is_bash() end
function M.is_combat() return M.state == "combat" end

local function _loop_state(mod)
  if type(mod) ~= "table" then return nil end
  mod.cfg = mod.cfg or {}
  mod.state = mod.state or {}
  mod.state.loop_delay = tonumber(mod.state.loop_delay or mod.cfg.loop_delay or 0.15) or 0.15
  mod.state.busy = (mod.state.busy == true)
  mod.state.waiting = mod.state.waiting or { queue = nil, main_lane = nil, lanes = nil, at = 0 }
  mod.state.last_attack = mod.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil }
  return mod.state
end

local function _loop_set_enabled(mod, on)
  local state = _loop_state(mod)
  if not state then return false end
  local enabled = (on == true)
  state.enabled = enabled
  state.loop_enabled = enabled
  if type(mod.cfg) == "table" then
    mod.cfg.enabled = enabled
  end
  return enabled
end

local function _loop_clear_waiting(mod)
  if type(mod) ~= "table" then return false end
  if type(mod.alias_loop_clear_waiting) == "function" then
    pcall(mod.alias_loop_clear_waiting)
  end
  local state = _loop_state(mod)
  local wait = state and state.waiting or nil
  if type(wait) == "table" then
    wait.queue = nil
    wait.main_lane = nil
    wait.lanes = nil
    wait.at = 0
  end
  return true
end

local function _loop_kill_timer(mod)
  local state = type(mod) == "table" and mod.state or nil
  if state and state.timer_id then
    pcall(killTimer, state.timer_id)
    state.timer_id = nil
  end
  return true
end

local function _set_active_loop(entry, reason)
  M.route_loop = M.route_loop or {}
  M.route_loop.active = type(entry) == "table" and tostring(entry.id or "") or ""
  M.route_loop.last_change = _now()
  M.route_loop.last_reason = tostring(reason or "route_loop")
  return M.route_loop.active
end

local function _loop_activate(entry, reason)
  if type(entry) ~= "table" then return false end

  M.route_loop = M.route_loop or {}
  local prior_activating = _norm(M.route_loop.activating_id or "")
  M.route_loop.activating_id = _norm(entry.id or "")

  local mode = _norm(entry.mode or "")
  if mode ~= "" and type(M.set) == "function" then
    if mode == "bash" or mode == "combat" then
      pcall(M.set, mode, reason)
    end
  end

  M.route_loop.activating_id = prior_activating
  _set_active_loop(entry, reason)
  return true
end

local function _loop_release(entry)
  if type(entry) ~= "table" then return false end

  local route_id = _norm(entry.id or "")
  if _norm(M.route_loop and M.route_loop.active or "") == route_id then
    _set_active_loop(nil, "loop_release")
  end

  return true
end

local function _stop_other_loops(active_id)
  local entries = _route_entries()
  for i = 1, #entries do
    local entry = entries[i]
    if _norm(entry.id or "") ~= _norm(active_id or "") then
      local mod = _ensure_route_module(entry)
      if type(mod) == "table"
        and mod.alias_owned == true
        and mod.state
        and mod.state.loop_enabled == true
        and type(mod.stop) == "function" then
        pcall(mod.stop)
      end
    end
  end
end

local function _loop_entry(name)
  local RR = _route_registry()
  if RR and type(RR.resolve) == "function" then
    return RR.resolve(name)
  end
  return nil
end

local function _loop_stop_details(mod)
  if type(mod) == "table" and type(mod.alias_loop_stop_details) == "table" then
    return mod.alias_loop_stop_details
  end
  return {
    inactive = true,
    disabled = true,
    policy = true,
  }
end

function M.route_loop_entry(name)
  return _loop_entry(name)
end

function M.active_route_id()
  return _norm(M.route_loop and M.route_loop.active or "")
end

function M.route_loop_active(name)
  local entry = _loop_entry(name)
  if not entry then return false end
  local mod = _route_module(entry)
  return type(mod) == "table"
     and type(mod.state) == "table"
     and mod.state.loop_enabled == true
end

function M.schedule_route_loop(name, delay)
  local entry = _loop_entry(name)
  if not entry then return false end
  local mod = _ensure_route_module(entry)
  if type(mod) ~= "table" then return false end

  local state = _loop_state(mod)
  _loop_kill_timer(mod)
  if state.loop_enabled ~= true then return false end

  delay = tonumber(delay)
  if delay == nil then
    delay = tonumber(state.loop_delay or (mod.cfg and mod.cfg.loop_delay) or 0.15) or 0.15
  end
  if delay < 0 then delay = 0 end
  if type(tempTimer) ~= "function" then return false end

  state.timer_id = tempTimer(delay, function()
    if mod.state then mod.state.timer_id = nil end
    if Yso and Yso.mode and type(Yso.mode.tick_route_loop) == "function" then
      Yso.mode.tick_route_loop(entry.id)
    end
  end)

  return state.timer_id ~= nil
end

function M.nudge_route_loop(name, reason)
  local target = _norm(name)
  if target == "" then
    target = _norm(M.active_route_id and M.active_route_id() or "")
  end
  if target == "" then return false, "inactive" end

  local entry = _loop_entry(target)
  if not entry then return false, "unknown_route" end
  local mod = _ensure_route_module(entry)
  if type(mod) ~= "table" then return false, "module_unavailable" end

  local state = _loop_state(mod)
  if state.loop_enabled ~= true then return false, "route_disabled" end
  if state.busy == true then return false, "busy" end

  M.route_loop = M.route_loop or {}
  M.route_loop.nudges = M.route_loop.nudges or {}
  local dedupe_s = tonumber(M.route_loop.nudge_dedupe_s or 0.05) or 0.05
  if dedupe_s < 0 then dedupe_s = 0 end

  local key = _norm(entry.id or target)
  local now = _now()
  local last = tonumber(M.route_loop.nudges[key] or 0) or 0
  if dedupe_s > 0 and (now - last) < dedupe_s then
    return false, "deduped"
  end

  M.route_loop.nudges[key] = now
  return M.schedule_route_loop(entry.id, 0)
end

function M.start_route_loop(name, reason)
  local entry = _loop_entry(name)
  if not entry then
    _echo(("Route <yellow>%s<reset> is not registered."):format(tostring(name)))
    return false
  end

  local mod = _ensure_route_module(entry)
  if type(mod) ~= "table" then
    _echo(("Route module <yellow>%s<reset> is unavailable."):format(tostring(entry.id or name)))
    return false
  end

  if type(mod.init) == "function" then
    pcall(mod.init)
  end
  local state = _loop_state(mod)
  if state and state.loop_enabled == true then
    return true
  end

  _stop_other_loops(entry.id)

  local ctx = {
    entry = entry,
    reason = tostring(reason or "alias"),
  }
  if type(mod.alias_loop_prepare_start) == "function" then
    local ok, res = pcall(mod.alias_loop_prepare_start, ctx)
    if ok and type(res) == "table" then
      for k, v in pairs(res) do
        ctx[k] = v
      end
    end
  end

  _loop_activate(entry, ctx.reason)
  _loop_set_enabled(mod, true)
  mod.state.busy = false
  _loop_clear_waiting(mod)
  mod.state.template = mod.state.template or {}
  mod.state.template.last_reason = "start_loop"
  M.schedule_route_loop(entry.id, 0)

  if type(mod.alias_loop_on_started) == "function" then
    pcall(mod.alias_loop_on_started, ctx)
  end

  return true
end

function M.stop_route_loop(name, reason, silent)
  local entry = _loop_entry(name)
  if not entry then return false end
  local mod = _ensure_route_module(entry)
  if type(mod) ~= "table" then return false end

  if type(mod.init) == "function" then
    pcall(mod.init)
  end

  local ctx = {
    entry = entry,
    reason = tostring(reason or "manual"),
    silent = (silent == true),
  }

  _loop_kill_timer(mod)
  _loop_set_enabled(mod, false)
  mod.state.busy = false
  _loop_clear_waiting(mod)
  mod.state.template = mod.state.template or {}
  mod.state.template.last_disable_reason = ctx.reason

  if type(mod.alias_loop_on_stopped) == "function" then
    pcall(mod.alias_loop_on_stopped, ctx)
  end

  _loop_release(entry)
  return true
end

function M.toggle_route_loop(name, reason)
  local entry = _loop_entry(name)
  if not entry then
    _echo(("Route <yellow>%s<reset> is not registered."):format(tostring(name)))
    return false
  end
  local mod = _ensure_route_module(entry)
  if type(mod) ~= "table" then
    _echo(("Route module <yellow>%s<reset> is unavailable."):format(tostring(entry.id or name)))
    return false
  end
  local state = _loop_state(mod)
  if state and state.loop_enabled == true then
    return M.stop_route_loop(entry.id, reason or "toggle", false)
  end
  return M.start_route_loop(entry.id, reason or "toggle")
end

function M.tick_route_loop(name)
  local entry = _loop_entry(name)
  if not entry then return false end
  local mod = _ensure_route_module(entry)
  if type(mod) ~= "table" then return false end

  local state = _loop_state(mod)
  state.timer_id = nil
  if state.loop_enabled ~= true then return false end

  if type(mod.is_active) == "function" then
    local ok, active = pcall(mod.is_active)
    if ok and active ~= true then
      return M.stop_route_loop(entry.id, "route_inactive", false)
    end
  end

  if state.busy == true then
    M.schedule_route_loop(entry.id, state.loop_delay)
    return false
  end

  if type(mod.alias_loop_waiting_blocks) == "function" then
    local ok, blocked = pcall(mod.alias_loop_waiting_blocks)
    if ok and blocked == true then
      M.schedule_route_loop(entry.id, state.loop_delay)
      return false
    end
  end

  state.busy = true
  local ok, sent, detail = pcall(function() return mod.attack_function() end)
  state.busy = false

  if not ok then
    if type(mod.alias_loop_on_error) == "function" then
      pcall(mod.alias_loop_on_error, sent)
    end
    M.schedule_route_loop(entry.id, state.loop_delay)
    return false
  end

  local stop_on = _loop_stop_details(mod)
  if sent ~= true then
    state.template = state.template or {}
  end

  if sent ~= true and stop_on[tostring(detail or "")] == true then
    return M.stop_route_loop(entry.id, detail, false)
  end

  M.schedule_route_loop(entry.id, state.loop_delay)
  return sent == true
end

function Yso.is_actively_fighting()
  local route = type(M.active_route_id) == "function" and M.active_route_id() or ""
  if route == "" or route == "none" then return false end
  if type(M.is_hunt) == "function" and M.is_hunt() then return false end
  if not (type(M.is_combat) == "function" and M.is_combat()) then
    return false
  end

  local t = ""
  if type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok then t = tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "") end
  elseif type(Yso.target) == "string" then
    t = tostring(Yso.target):gsub("^%s+", ""):gsub("%s+$", "")
  end
  return t ~= ""
end

function M.echo()
  _echo(("Mode: %s"):format(M.state))
end

function M.apply_profile(mode)
  mode = _norm(mode)
  local p = M.profile and M.profile[mode]
  if not p or not p.toggles then return end

  Yso.toggles = Yso.toggles or {}
  for k, v in pairs(p.toggles) do
    local cur = Yso.toggles[k]
    if cur == nil or type(cur) == "boolean" then
      Yso.toggles[k] = (v == true)
    end
  end
end

function M.set(mode, reason)
  mode = _norm(mode)
  if mode ~= "bash" and mode ~= "combat" then
    _echo(("Invalid mode: <yellow>%s<reset> (use bash|combat)"):format(tostring(mode)))
    return false
  end

  local old = M.state
  if old == mode then
    M.last_reason = reason or M.last_reason
    return true
  end

  if mode == "bash" then
    _stop_all_route_loops("mode_bash", true)
  end

  M.state = mode
  M.last_change = _now()
  M.last_reason = reason or "manual"

  M.apply_profile(mode)

  if type(raiseEvent) == "function" then
    raiseEvent("yso.mode.changed", old, mode, M.last_reason)
  end

  M.echo()

  return true
end

function M.toggle(reason)
  if M.is_bash() then
    return M.set("combat", reason or "toggle")
  elseif M.is_combat() then
    return M.set("bash", reason or "toggle")
  end
  return false
end

function M.on_engage(reason)    return M.set("combat", reason or "engage") end
function M.on_disengage(reason) return M.set("bash",   reason or "disengage") end

local function _refresh_huntmode(reason)
  if Yso.huntmode and type(Yso.huntmode.refresh) == "function" then
    pcall(Yso.huntmode.refresh, tostring(reason or "alias"))
  end
end

local function _set_bash_mode(reason, opts)
  opts = type(opts) == "table" and opts or {}
  local why = tostring(reason or "alias")
  local was_bash = M.is_bash()
  local ok = M.set("bash", why)
  if ok and was_bash and opts.refresh_if_already_bash == true then
    _refresh_huntmode(why)
  end
  return ok
end

Yso.util = Yso.util or {}
if type(Yso.util.toggle_route_alias) ~= "function" then
  function Yso.util.toggle_route_alias(route_id, reason)
    local function _try_toggle()
      if Yso and Yso.mode and type(Yso.mode.toggle_route_loop) == "function" then
        return Yso.mode.toggle_route_loop(route_id, reason)
      end
      return false, "controller_unavailable"
    end

    local call_ok, ok, why = pcall(_try_toggle)
    if call_ok then return ok, why end
    return false, tostring(ok)
  end
end

M._alias = M._alias or {}
local function _kill_alias(id) if id then pcall(killAlias, id) end end

if type(tempAlias) == "function" then
  _kill_alias(M._alias.mode)
  _kill_alias(M._alias.mode_set)
  _kill_alias(M._alias.hunt)
  _kill_alias(M._alias.bash)
  _kill_alias(M._alias.mbash)
  _kill_alias(M._alias.mhunt)
  _kill_alias(M._alias.combat)

  M._alias.mode = tempAlias([[^mode$]], function() M.echo() end)
  M._alias.mode_set = tempAlias([[^mode\s+(\S+)(?:\s+(\S+))?$]], function()
    local raw = tostring(matches[2] or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if raw == "bash" or raw == "hunt" then
      _set_bash_mode("alias:mode")
    else
      M.set(_norm(raw), "alias:mode")
    end
  end)

  M._alias.hunt = tempAlias([[^hunt$]], function() _set_bash_mode("alias:hunt") end)
  M._alias.bash = tempAlias([[^bash$]], function() _set_bash_mode("alias:bash") end)
  M._alias.mbash = tempAlias([[^mbash$]], function() _set_bash_mode("alias:mbash", { refresh_if_already_bash = true }) end)
  M._alias.mhunt = tempAlias([[^mhunt$]], function() _set_bash_mode("alias:mhunt", { refresh_if_already_bash = true }) end)
  M._alias.combat = tempAlias([[^(?:combat|mcombat)$]], function() M.set("combat", "alias:combat") end)

  _kill_alias(M._alias.mt)
  M._alias.mt = tempAlias([[^mt$]], function()
    M.toggle("alias:mt")
  end)
end

--========================================================--
