--========================================================--
-- yso_modes.lua (DROP-IN)
-- Purpose:
--   • Central "mode of play" switch for Yso
--   • Modes: "bash", "combat", "party"
--   • Party subroutes: "aff" (team affliction), "dam" (team damage)
--   • Non-destructive: only flips optional toggles if present
--
-- API:
--   Yso.mode.set("bash"|"combat"|"party"[, reason])
--   Yso.mode.toggle([reason])                 -- toggles bash <-> combat
--   Yso.mode.is_bash() / is_hunt() / is_combat() / is_party()
--   Yso.mode.set_party_route("aff"|"dam"[, reason])
--   raiseEvent("yso.mode.changed", old, new, reason) on mode change
--   raiseEvent("yso.party.route.changed", old, new, reason) on party route change
--
-- Suggested aliases (tempAlias, auto-registered if available):
--   ^mode$                               -> Yso.mode.echo()
--   ^mode\s+(bash|combat|party|hunt)$    -> Yso.mode.set(matches[2], "alias")
--   ^mbash$                              -> Yso.mode.set("bash", "alias")
--   ^combat$                             -> Yso.mode.set("combat", "alias")
--   ^party(?:\s+(aff|dam))?$             -> set party mode; optional route
--   ^partyroute\s+(aff|dam)$             -> Yso.mode.set_party_route(matches[2])
--   ^mt$                                 -> Yso.mode.toggle("alias")
--
-- Back-compat:
--   • "hunt" normalizes to "bash"
--   • is_hunt() remains available and maps to bash mode
--   • ^mhunt$ is kept as a compatibility shim to set bash mode
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
  owns = { dam = false, aff = false },
}

local function _route_norm(r)
  r = _norm(r)
  if r == "dmg" then r = "dam" end
  return r
end

local function _gd()
  return (Yso and Yso.off and Yso.off.oc and (Yso.off.oc.dmg or Yso.off.oc.group_damage)) or nil
end

local function _party_apply(reason)
  local route = _route_norm(M.party and M.party.route or "dam")

  if M.state ~= "party" then
    local gd = _gd()
    if gd and M.party and M.party.owns and M.party.owns.dam and type(gd.stop) == "function" then
      pcall(gd.stop)
    end
    if M.party and M.party.owns then
      M.party.owns.dam = false
      M.party.owns.aff = false
    end
    return
  end

  if route == "dam" then
    local gd = _gd()
    if gd and gd.state and gd.state.enabled ~= true and type(gd.start) == "function" then
      pcall(gd.start)
    end
    if M.party and M.party.owns then
      M.party.owns.dam = true
      M.party.owns.aff = false
    end
    _echo('Party route <yellow>dam<reset>: group damage ' .. ((gd and gd.state and gd.state.enabled) and 'ON' or 'requested'))

  elseif route == "aff" then
    local gd = _gd()
    if gd and M.party and M.party.owns and M.party.owns.dam and type(gd.stop) == "function" then
      pcall(gd.stop)
      M.party.owns.dam = false
    end
    _echo("Party route <yellow>aff<reset>: (driver not yet implemented)")
  end
end

function M.is_bash()   return M.state == "bash" end
function M.is_hunt()   return M.is_bash() end
function M.is_combat() return M.state == "combat" end
function M.is_party()  return M.state == "party" end

function M.party_route()
  return _route_norm(M.party and M.party.route or "dam")
end

function M.set_party_route(route, reason)
  route = _route_norm(route)
  if route ~= "aff" and route ~= "dam" then
    _echo(("Invalid party route: <yellow>%s<reset> (use aff|dam)"):format(tostring(route)))
    return false
  end

  local old = M.party_route()
  if old == route then
    if M.party then M.party.last_reason = reason or M.party.last_reason end
    return true
  end

  M.party.route = route
  M.party.last_change = _now()
  M.party.last_reason = reason or "manual"

  _party_apply("route:"..tostring(reason or "manual"))

  if type(raiseEvent) == "function" then
    raiseEvent("yso.party.route.changed", old, route, M.party.last_reason)
  end

  return true
end

function M.echo()
  if M.is_party() then
    _echo(("Mode: <yellow>%s<reset> (route: <yellow>%s<reset>)"):format(M.state, M.party_route()))
  else
    _echo(("Mode: <yellow>%s<reset>"):format(M.state))
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

  if mode == "party" then
    _echo(("Mode set to <yellow>%s<reset> (route: <yellow>%s<reset>)"):format(mode, M.party_route()))
  else
    _echo(("Mode set to <yellow>%s<reset>"):format(mode))
  end

  if type(raiseEvent) == "function" then
    raiseEvent("yso.mode.changed", old, mode, M.last_reason)
  end

  _party_apply("mode:"..tostring(M.last_reason))

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
function M.on_disengage(reason) return M.set("combat", reason or "disengage") end

M._alias = M._alias or {}
local function _kill_alias(id) if id then pcall(killAlias, id) end end

if type(tempAlias) == "function" then
  _kill_alias(M._alias.mode)
  M._alias.mode = tempAlias([[^mode$]], function() if Yso.mode and Yso.mode.echo then Yso.mode.echo() end end)

  _kill_alias(M._alias.mode_set)
  M._alias.mode_set = tempAlias([[^mode\s+(bash|combat|party|hunt)$]], function() Yso.mode.set(matches[2], "alias") end)

  _kill_alias(M._alias.hunt)
  _kill_alias(M._alias.bash)
  _kill_alias(M._alias.mbash)
  _kill_alias(M._alias.mhunt)
  -- NOTE: Do NOT register ^hunt$ here; Legacy uses it for actual bashing automation.
  M._alias.mbash = tempAlias([[^mbash$]], function() Yso.mode.set("bash", "alias") end)
  M._alias.mhunt = tempAlias([[^mhunt$]], function() Yso.mode.set("bash", "alias:compat") end)

  _kill_alias(M._alias.combat)
  M._alias.combat = tempAlias([[^combat$]], function() Yso.mode.set("combat", "alias") end)

  _kill_alias(M._alias.party)
  M._alias.party = tempAlias([[^party(?:\s+(aff|dam))?$]], function()
    local r = matches[2]
    if r and r ~= "" then
      Yso.mode.set("party", "alias")
      Yso.mode.set_party_route(r, "alias")
    else
      Yso.mode.set("party", "alias")
    end
  end)

  _kill_alias(M._alias.partyroute)
  M._alias.partyroute = tempAlias([[^partyroute\s+(aff|dam)$]], function() Yso.mode.set_party_route(matches[2], "alias") end)

  _kill_alias(M._alias.mt)
  M._alias.mt = tempAlias([[^mt$]], function() Yso.mode.toggle("alias") end)
end

M._tip_shown = M._tip_shown or false
if (not M._tip_shown) and type(cecho) == "function" then
  M._tip_shown = true
  cecho("<aquamarine>[Yso] <reset>Tip: type <white>party<reset> to use the group-damage route (default: <white>party dam<reset>)."..string.char(10))
end

--========================================================--
