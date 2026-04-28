--========================================================--
-- Yso offense coordination
--  * Generic route-driver compatibility and target auto-clear support.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.coord = Yso.off.coord or {}

local C = Yso.off.coord

C.cfg = C.cfg or {
  pause_on_leap_out = true,
}
C._tm = C._tm or {}
C._st = C._st or { dead = { pending = "", at = 0 } }
C.state = C.state or {}

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _lc(s)
  return _trim(s):lower()
end

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    if ok and tonumber(v) then return tonumber(v) end
  end
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _cur_target()
  if type(Yso.get_target) == "function" then return _trim(Yso.get_target() or "") end
  return _trim((type(Yso.target) == "string" and Yso.target) or (Yso.state and type(Yso.state.target) == "string" and Yso.state.target) or "")
end

local function _is_current(t)
  return _lc(_cur_target()) == _lc(t)
end

local function _clear(reason)
  if type(Yso.clear_target) == "function" then
    Yso.clear_target(reason or "auto")
  end
end

local function _cancel_dead_clear()
  if C._tm.dead_clear then pcall(killTimer, C._tm.dead_clear) end
  C._tm.dead_clear = nil
  C._st.dead.pending = ""
  C._st.dead.at = 0
end

function C.schedule_dead_clear(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return false end

  _cancel_dead_clear()
  C._st.dead.pending = tgt
  C._st.dead.at = _now()

  if type(tempTimer) ~= "function" then
    local pend = C._st.dead.pending
    _cancel_dead_clear()
    if pend ~= "" and _is_current(pend) then _clear("dead") end
    return true
  end

  local my_id
  my_id = tempTimer(2.2, function()
    if C._tm.dead_clear ~= my_id then return end
    local pend = C._st.dead.pending
    _cancel_dead_clear()
    if pend ~= "" and _is_current(pend) then _clear("dead") end
  end)
  C._tm.dead_clear = my_id
  return true
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
  if type(require) == "function" then
    local rmod = type(entry) == "table" and tostring(entry.module_name or "") or ""
    if rmod ~= "" then pcall(require, rmod) end
  end
  return _route_module(entry)
end

local function _active_route_id()
  local M = Yso and Yso.mode or nil
  if M and type(M.active_route_id) == "function" then
    local ok, v = pcall(M.active_route_id)
    if ok then return _lc(v or "") end
  end
  return ""
end

local function _reset_route_mod(mod, reason, tgt)
  if type(mod) == "table" and type(mod.reset_route_state) == "function" then
    pcall(mod.reset_route_state, reason, tgt)
    return true
  end
  return false
end

local function _reset_active_and_alchemist_routes(reason, tgt)
  local seen = {}
  local RR = _route_registry()

  local function reset_entry(id)
    id = _lc(id)
    if id == "" or seen[id] == true then return end
    seen[id] = true
    local entry = RR and RR.resolve and RR.resolve(id) or nil
    local mod = entry and _ensure_route_module(entry) or nil
    _reset_route_mod(mod, reason, tgt)
  end

  reset_entry(_active_route_id())
  reset_entry("alchemist_group_damage")
  reset_entry("alchemist_duel_route")
  reset_entry("alchemist_aurify_route")

  if Yso and Yso.off and Yso.off.alc then
    _reset_route_mod(Yso.off.alc.group_damage, reason, tgt)
    _reset_route_mod(Yso.off.alc.duel_route, reason, tgt)
    _reset_route_mod(Yso.off.alc.aurify_route, reason, tgt)
  end
end

function C.on_target_slain(tgt, source)
  tgt = _trim(tgt)
  source = tostring(source or "target_slain")
  if tgt == "" then return false end

  if Yso and Yso.alc and Yso.alc.phys and type(Yso.alc.phys.reave_on_target_slain) == "function" then
    pcall(Yso.alc.phys.reave_on_target_slain, tgt, source)
  end

  if _is_current(tgt) then
    _reset_active_and_alchemist_routes(source, tgt)
    C.schedule_dead_clear(tgt)
  end

  return true
end

function C.on_target_cleared(tgt, source)
  tgt = _trim(tgt)
  source = tostring(source or "target_clear")
  _reset_active_and_alchemist_routes(source, tgt)
  return true
end

function C.on_external_reset(source)
  source = tostring(source or "external_reset")
  local tgt = _cur_target()

  _reset_active_and_alchemist_routes(source, tgt)

  local Q = Yso and Yso.queue or nil
  if Q then
    local lanes = { "class", "eq", "bal", "free" }
    for i = 1, #lanes do
      local lane = lanes[i]
      if type(Q.clear_lane) == "function" then
        pcall(Q.clear_lane, lane)
      end
      if type(Q.clear) == "function" then
        pcall(Q.clear, lane)
      end
      if type(Q.clear_owned) == "function" then
        pcall(Q.clear_owned, lane)
      end
    end
  end

  if type(send) == "function" then
    pcall(send, "CLEARQUEUE c!p!w!t", false)
    pcall(send, "CLEARQUEUE e!p!w!t", false)
    pcall(send, "CLEARQUEUE b!p!w!t", false)
  end

  C.state.last_external_reset = {
    source = source,
    target = tgt,
    at = _now(),
  }

  return true
end

Yso.off.driver = Yso.off.driver or {}
local D = Yso.off.driver

D.cfg = D.cfg or {
  enabled = true,
  verbose = false,
}

D.state = D.state or {
  enabled = (D.cfg.enabled ~= false),
  policy = "manual",
  active = "none",
}

local function _mode()
  return Yso and Yso.mode or nil
end

local function _sync_state()
  D.state = D.state or {}
  local M = _mode()
  local route = ""
  if M and type(M.active_route_id) == "function" then
    local ok, v = pcall(M.active_route_id)
    if ok then route = _lc(v or "") end
  end

  D.state.enabled = (D.cfg.enabled ~= false)
  D.state.active = (route ~= "" and route) or "none"
  D.state.policy = (route ~= "" and "auto") or "manual"
  return D.state
end

function D.current_route()
  local st = _sync_state()
  local route = _lc(st.active or "")
  if route == "" or route == "none" then return nil end
  return route
end

function D.toggle(on)
  local prev = (D.state.enabled == true)
  local next_enabled = (on == nil) and (not prev) or (on == true)
  D.state.enabled = next_enabled
  D.cfg.enabled = next_enabled
  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    local ok = pcall(Yso.pulse.wake, "driver:toggle")
    if not ok then
      D.state.enabled = prev
      D.cfg.enabled = prev
    end
  end
  return D.state.enabled
end

function D.set_policy(p)
  p = _lc(p or "")
  if p ~= "" then
    D.state.policy = p
    D.cfg.policy = p
  end
  _sync_state()
  return D.state.policy
end

function D.set_active(route)
  route = _lc(route or "")
  if route ~= "" then D.state.active = route end
  _sync_state()
  return D.state.active
end

function D.tick(reasons)
  _sync_state()
  local core = Yso and Yso.off and Yso.off.core or nil
  if core and type(core.tick) == "function" then
    local ok, sent = pcall(core.tick, reasons)
    return (ok and sent == true)
  end
  return false
end

_sync_state()
return D
