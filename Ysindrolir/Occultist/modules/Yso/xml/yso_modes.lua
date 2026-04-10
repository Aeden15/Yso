--========================================================--
-- yso_modes.lua (DROP-IN)
-- Purpose:
--   * Central "mode of play" switch for Yso
--   * Modes: "bash", "combat", "party"
--   * Party subroutes: "aff" (team affliction), "dam" (team damage)
--   * Non-destructive: only flips optional toggles if present
--
-- API:
--   Yso.mode.set("bash"|"combat"|"party"[, reason])
--   Yso.mode.toggle([reason])                 -- toggles bash <-> combat
--   Yso.mode.is_bash() / is_hunt() / is_combat() / is_party()
--   Yso.mode.set_party_route("aff"|"dam"[, reason])
--   raiseEvent("yso.mode.changed", old, new, reason) on mode change
--   raiseEvent("yso.party.route.changed", old, new, reason) on party route change
--
-- Runtime aliases (tempAlias, auto-registered if available):
--   ^hunt$    -> switch to bash mode without forcing a huntmode reset on noop
--   ^mbash$   -> if already in bash, force a huntmode refresh/reset
--   ^team...$  -> party mode / route toggle (see implementation)
--   ^teamroute\s+(\S+)$ -> Yso.mode.set_party_route(matches[2], "alias")
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
  party = {
    toggles = {
      offense  = true,
      affcall  = true,
      debug    = true,
      travel   = false,
      autoloot = false,
      party    = true,
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

M.party = M.party or {
  route       = "dam",
  last_change = _now(),
  last_reason = "init",
  owns = {},
}

M.route_loop = M.route_loop or {
  active = "",
  last_change = _now(),
  last_reason = "init",
}

local function _route_norm(r)
  r = _norm(r)
  if r == "dmg" then r = "dam" end
  return r
end

local function _route_registry()
  local RR = Yso and Yso.Combat and Yso.Combat.RouteRegistry or nil
  if RR and type(RR.resolve) == "function" then return RR end
  if type(require) == "function" then
    pcall(require, "Yso.Combat.route_registry")
    pcall(require, "Yso.xml.route_registry")
  end
  RR = Yso and Yso.Combat and Yso.Combat.RouteRegistry or nil
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

  local bootstrap = Yso and Yso.bootstrap or nil
  local id = type(entry) == "table" and tostring(entry.id or "") or ""
  if type(bootstrap) == "table" then
    if (id == "occ_aff" or id == "occ_aff_burst") then
      if type(bootstrap.occ_aff) == "function" then
        pcall(bootstrap.occ_aff, true)
      elseif type(bootstrap.occ_aff_burst) == "function" then
        pcall(bootstrap.occ_aff_burst, true)
      end
    elseif type(bootstrap.entry) == "function" then
      pcall(bootstrap.entry, true)
    end
  end

  mod = _route_module(entry)
  if mod then return mod end

  if type(require) == "function" then
    pcall(require, "Yso._entry")
  end

  return _route_module(entry)
end

local function _party_entries()
  local RR = _route_registry()
  if RR and type(RR.for_mode) == "function" then
    return RR.for_mode("party")
  end
  return {}
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

local function _party_entry(route)
  local RR = _route_registry()
  if RR and type(RR.for_party_route) == "function" then
    return RR.for_party_route(route)
  end
  return nil
end

local function _owns_key(entry)
  if type(entry) ~= "table" then return tostring(entry or "") end
  return tostring(entry.id or entry.party_route or "")
end

local function _owned(entry)
  local owns = M.party and M.party.owns or {}
  local key = _owns_key(entry)
  if owns[key] ~= nil then return owns[key] == true end
  local route = type(entry) == "table" and tostring(entry.party_route or "") or ""
  return route ~= "" and owns[route] == true
end

local function _set_owned(entry, on)
  M.party.owns = M.party.owns or {}
  local key = _owns_key(entry)
  if key ~= "" then M.party.owns[key] = (on == true) end
  local route = type(entry) == "table" and tostring(entry.party_route or "") or ""
  if route ~= "" then M.party.owns[route] = (on == true) end
end

local function _entry_enabled(entry)
  local mod = _route_module(entry)
  if not mod then return false end
  if mod.state and type(mod.state.enabled) == "boolean" then
    return mod.state.enabled == true
  end
  if type(mod.enabled) == "boolean" then
    return mod.enabled == true
  end
  return false
end

local function _reset_party_owns()
  M.party.owns = M.party.owns or {}
  for k in pairs(M.party.owns) do
    M.party.owns[k] = false
  end
end

local function _party_apply(reason)
  local route = _route_norm(M.party and M.party.route or "dam")
  local entries = _party_entries()
  local desired = _party_entry(route)

  if M.state ~= "party" then
    for i = 1, #entries do
      local entry = entries[i]
      local mod = _route_module(entry)
      if mod and (_owned(entry) or _entry_enabled(entry)) and type(mod.stop) == "function" then
        pcall(mod.stop)
      end
    end
    _reset_party_owns()
    return
  end

  if not desired then
    _echo(("Party route <yellow>%s<reset> is not registered."):format(tostring(route)))
    return
  end

  for i = 1, #entries do
    local entry = entries[i]
    local mod = _route_module(entry)
    local is_desired = (tostring(entry.id or "") == tostring(desired.id or ""))
    if mod and not is_desired and (_owned(entry) or _entry_enabled(entry)) and type(mod.stop) == "function" then
      pcall(mod.stop)
    end
    if not is_desired then _set_owned(entry, false) end
  end

  local mod = _route_module(desired)
  local desired_owned = _owned(desired)
  local is_alias_owned = (type(mod) == "table" and mod.alias_owned == true)
  local enabled = mod and mod.state and mod.state.enabled == true

  if mod and type(mod.start) == "function" and not is_alias_owned then
    if enabled ~= true then
      pcall(mod.start)
      enabled = mod.state and mod.state.enabled == true
    end
    _set_owned(desired, true)
    desired_owned = true
  elseif is_alias_owned then
    if enabled == true then
      _set_owned(desired, true)
      desired_owned = true
    elseif desired_owned ~= true then
      _set_owned(desired, false)
      desired_owned = false
    end
  else
    _set_owned(desired, false)
    desired_owned = false
  end

  -- Shared status echo lives in M.echo() so a single action does not stack
  -- a generic route line on top of the class-owned loop line.
end

function M.is_bash()   return M.state == "bash" end
function M.is_hunt()   return M.is_bash() end
function M.is_combat() return M.state == "combat" end
function M.is_party()  return M.state == "party" end

function M.party_route()
  return _route_norm(M.party and M.party.route or "dam")
end

function M.route_owned(route)
  local entry = _party_entry(route)
  if entry then return _owned(entry) end
  route = _route_norm(route)
  return M.party and M.party.owns and M.party.owns[route] == true or false
end

function M.set_route_owned(route, on)
  M.party = M.party or {
    route = "dam",
    last_change = _now(),
    last_reason = "manual",
    owns = {},
  }
  local entry = _party_entry(route)
  if entry then
    _set_owned(entry, on)
    return true
  end
  route = _route_norm(route)
  if route == "" then return false end
  M.party.owns = M.party.owns or {}
  M.party.owns[route] = (on == true)
  return true
end

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

  local mode = _norm(entry.mode or "")
  if mode == "party" then
    if entry.party_route and type(M.set_party_route) == "function" then
      pcall(M.set_party_route, entry.party_route, reason)
    end
    if entry.party_route and type(M.set_route_owned) == "function" then
      pcall(M.set_route_owned, entry.party_route, true)
    end
    if type(M.set) == "function" then
      pcall(M.set, "party", reason)
    end
  elseif mode ~= "" and type(M.set) == "function" then
    pcall(M.set, mode, reason)
  end

  _set_active_loop(entry, reason)
  return true
end

local function _loop_release(entry)
  if type(entry) ~= "table" then return false end

  if entry.party_route and type(M.set_route_owned) == "function" then
    pcall(M.set_route_owned, entry.party_route, false)
  end

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
  return false
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
  if not ((type(M.is_combat) == "function" and M.is_combat()) or (type(M.is_party) == "function" and M.is_party())) then
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

function M.set_party_route(route, reason)
  route = _route_norm(route)
  local entry = _party_entry(route)
  if not entry then
    _echo(("Invalid party route: <yellow>%s<reset> (use a registered party route)"):format(tostring(route)))
    return false
  end
  route = tostring(entry.party_route or route)

  local old = M.party_route()
  if old == route then
    if M.party then M.party.last_reason = reason or M.party.last_reason end
    _party_apply("route_noop")
    return true
  end

  M.party.route = route
  M.party.last_change = _now()
  M.party.last_reason = reason or "manual"

  _party_apply("route:"..tostring(reason or "manual"))

  if type(raiseEvent) == "function" then
    raiseEvent("yso.party.route.changed", old, route, M.party.last_reason)
  end

  if M.is_party() then M.echo() end

  return true
end

function M.echo()
  if M.is_party() then
    _echo(("Mode: %s (route: %s)"):format(M.state, M.party_route()))
  else
    _echo(("Mode: %s"):format(M.state))
  end
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
  if mode ~= "bash" and mode ~= "combat" and mode ~= "party" then
    _echo(("Invalid mode: <yellow>%s<reset> (use bash|combat|party)"):format(tostring(mode)))
    return false
  end

  local old = M.state
  if old == mode then
    M.last_reason = reason or M.last_reason
    if mode == "party" then _party_apply("mode_noop") end
    return true
  end

  M.state = mode
  M.last_change = _now()
  M.last_reason = reason or "manual"

  M.apply_profile(mode)

  if type(raiseEvent) == "function" then
    raiseEvent("yso.mode.changed", old, mode, M.last_reason)
  end

  _party_apply("mode:"..tostring(M.last_reason))
  M.echo()

  return true
end

function M.toggle(reason)
  if M.is_bash() then
    return M.set("combat", reason or "toggle")
  elseif M.is_combat() then
    return M.set("bash", reason or "toggle")
  else
    return false
  end
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

local function _set_party_mode(route, reason)
  local why = tostring(reason or "alias")
  local ok = M.set("party", why)
  if ok and route and tostring(route) ~= "" then
    M.set_party_route(route, why)
  end
  return ok
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
  _kill_alias(M._alias.team)
  _kill_alias(M._alias.teamroute)
  _kill_alias(M._alias.party)
  _kill_alias(M._alias.par)
  _kill_alias(M._alias.partyroute)
  M._alias.team = tempAlias([[^team(?:\s+(\S+))?$]], function()
    local r = matches[2]
    if r and r ~= "" then
      local route = _route_norm(r)
      if route == "aff" or route == "dam" then
        if Yso.mode and type(Yso.mode.toggle_route_loop) == "function" then
          Yso.mode.toggle_route_loop(route, "alias")
        end
      else
        _set_party_mode(r, "alias:team")
      end
    else
      _set_party_mode(nil, "alias:team")
    end
  end)

  M._alias.teamroute = tempAlias([[^teamroute\s+(\S+)$]], function() Yso.mode.set_party_route(matches[2], "alias:teamroute") end)

  M._alias.mode = tempAlias([[^mode$]], function() M.echo() end)
  M._alias.mode_set = tempAlias([[^mode\s+(\S+)(?:\s+(\S+))?$]], function()
    local mode = _norm(matches[2] or "")
    local arg = matches[3]
    if mode == "party" then
      _set_party_mode(arg, "alias:mode")
    elseif mode == "bash" then
      _set_bash_mode("alias:mode")
    else
      M.set(mode, "alias:mode")
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

M._tip_shown = M._tip_shown or false
if (not M._tip_shown) and type(cecho) == "function" then
  M._tip_shown = true
  cecho("<aquamarine>[Yso] <reset>Tip: type <white>team<reset> to use the group-damage route (default: <white>team dam<reset>)."..string.char(10))
end

--========================================================--
