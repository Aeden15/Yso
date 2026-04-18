--========================================================--
-- Yso Combat Offense Core (Canonical Lifecycle Surface)
--  • Shared lifecycle for Magi + Occultist route wiring.
--  • Thin aliases and shared hooks should call this module only.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.core = Yso.off.core or {}

local Core = Yso.off.core

Core.routes = Core.routes or {}
Core.state = Core.state or {
  active = "",
  last_reason = "init",
  last_tick = 0,
}

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
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

local function _echo(msg)
  if type(cecho) == "function" then
    cecho(string.format("<orange>[Yso:off.core] <reset>%s\n", tostring(msg)))
  elseif type(echo) == "function" then
    echo(string.format("[Yso:off.core] %s\n", tostring(msg)))
  end
end

local function _route_registry()
  local RR = Yso and Yso.Combat and Yso.Combat.RouteRegistry or nil
  if RR and type(RR.resolve) == "function" then return RR end
  if type(require) == "function" then
    pcall(require, "Yso.Combat.route_registry")
    pcall(require, "Yso.xml.route_registry")
  end
  RR = Yso and Yso.Combat and Yso.Combat.RouteRegistry or nil
  return (RR and type(RR.resolve) == "function") and RR or nil
end

local function _mode()
  return Yso and Yso.mode or nil
end

local function _namespace_lookup(ns)
  ns = _trim(ns)
  if ns == "" then return nil end
  local cur = _G
  for part in ns:gmatch("[^%.]+") do
    if type(cur) ~= "table" then return nil end
    cur = cur[part]
  end
  return type(cur) == "table" and cur or nil
end

local function _route_interface()
  local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
  if RI and type(RI.payload_has_route) == "function" then return RI end
  if type(require) == "function" then
    pcall(require, "Yso.Combat.route_interface")
    pcall(require, "Yso.xml.route_interface")
  end
  RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
  if RI and type(RI.payload_has_route) == "function" then return RI end
  return nil
end

local function _current_class()
  local C = Yso and Yso.classinfo or nil
  if type(C) == "table" then
    if type(C.get) == "function" then
      local ok, v = pcall(C.get)
      if ok and _trim(v) ~= "" then return _lc(v) end
    end
    if type(C.current_class) == "function" then
      local ok, v = pcall(C.current_class)
      if ok and _trim(v) ~= "" then return _lc(v) end
    end
  end
  local g = rawget(_G, "gmcp")
  local cls = g and g.Char and g.Char.Status and (g.Char.Status.class or g.Char.Status.classname) or nil
  if _trim(cls) ~= "" then return _lc(cls) end
  return _lc(Yso and Yso.class or "")
end

local function _class_ok(entry)
  if type(entry) ~= "table" then return true end
  local need = _lc(entry.class or "")
  if need == "" then return true end
  return _current_class() == need
end

local function _normalize_route_api(route)
  if type(route) ~= "table" then return route end
  if type(route.can_run) ~= "function" then
    route.can_run = function() return true end
  end
  if type(route.build) ~= "function" then
    if type(route.build_payload) == "function" then
      route.build = function(reason)
        local ctx = type(reason) == "table" and reason or { reason = tostring(reason or "") }
        return route.build_payload(ctx)
      end
    elseif type(route.attack_function) == "function" then
      route.build = function(reason)
        local ctx = type(reason) == "table" and reason or { reason = tostring(reason or "") }
        return route.attack_function({ ctx = ctx, preview = true })
      end
    end
  end
  if type(route.on_start) ~= "function" and type(route.on) == "function" then
    route.on_start = function() return route.on(true) end
  end
  if type(route.on_stop) ~= "function" and type(route.off) == "function" then
    route.on_stop = function() return route.off() end
  end
  return route
end

local function _resolve_entry(key)
  local RR = _route_registry()
  if not RR then return nil end
  local entry = RR.resolve(key)
  return type(entry) == "table" and entry or nil
end

local function _resolve_id(key)
  key = _trim(key)
  if key == "" then
    local active = _trim(Core.state and Core.state.active or "")
    if active ~= "" then return _lc(active), _resolve_entry(active) end
    local M = _mode()
    if M and type(M.active_route_id) == "function" then
      local ok, rid = pcall(M.active_route_id)
      rid = ok and _trim(rid) or ""
      if rid ~= "" then return _lc(rid), _resolve_entry(rid) end
    end
    return nil, nil
  end

  local entry = _resolve_entry(key)
  if entry then return _lc(entry.id), entry end

  local rid = _lc(key)
  if type(Core.routes[rid]) == "table" then
    return rid, nil
  end
  return nil, nil
end

local function _ensure_route_module(entry)
  if type(entry) ~= "table" then return nil end
  local mod = _namespace_lookup(entry.namespace)
  if mod then return _normalize_route_api(mod) end

  if type(require) == "function" then
    pcall(require, "Yso._entry")
    -- Try the route-specific file if the registry advertises a module_name.
    local rmod = tostring(entry.module_name or "")
    if rmod ~= "" then pcall(require, rmod) end
  end
  mod = _namespace_lookup(entry.namespace)
  if mod then return _normalize_route_api(mod) end
  return nil
end

local function _route_for(id, entry)
  id = _lc(id)
  local route = Core.routes[id]
  if type(route) == "table" then
    return _normalize_route_api(route)
  end
  if not entry then entry = _resolve_entry(id) end
  route = _ensure_route_module(entry)
  if type(route) == "table" then
    Core.routes[id] = route
  end
  return route
end

local function _is_mode_driven(entry, route)
  if type(entry) == "table" and _lc(entry.driver or "") == "core" then
    return false
  end
  if type(route) == "table" and route.alias_owned == true then
    return true
  end
  if type(entry) == "table" and _trim(entry.namespace) ~= "" then
    return true
  end
  return false
end

local function _manual_send(payload_or_cmd, opts)
  opts = type(opts) == "table" and opts or {}
  local target = _trim(opts.target or "")

  if type(payload_or_cmd) == "table" then
    local payload = payload_or_cmd
    if type(Yso.emit) == "function" then
      return Yso.emit(payload, {
        reason = tostring(opts.reason or "off.core"),
        kind = "offense",
        commit = true,
        target = target,
      }) == true
    end
    if Yso and Yso.queue and type(Yso.queue.emit) == "function" then
      local ok, sent = pcall(Yso.queue.emit, payload, {
        reason = tostring(opts.reason or "off.core"),
        kind = "offense",
        commit = true,
        target = target,
      })
      return ok == true and sent == true
    end
    return false
  end

  local cmd = _trim(payload_or_cmd)
  if cmd == "" then return false end
  if type(send) ~= "function" then return false end
  local ok, sent = pcall(send, cmd)
  return ok == true and sent ~= false
end

local function _manual_tick(id, route, reason)
  route = _normalize_route_api(route)
  if type(route) ~= "table" then return false, "route_missing" end

  local ctx = type(reason) == "table" and reason or { reason = tostring(reason or "tick") }
  local ok_can, can_res, can_why = pcall(route.can_run, ctx)
  if not ok_can then return false, can_res end
  if can_res ~= true then return false, can_why or can_res or "cannot_run" end

  local ok_build, built, why = pcall(route.build, ctx)
  if not ok_build then return false, built end
  if built == nil or built == false then return false, why or "empty" end

  local target = _trim((type(ctx) == "table" and ctx.target) or "")
  local sent = _manual_send(built, { reason = "off.core:manual", target = target })
  if sent ~= true then return false, "send_failed" end

  if type(route.after_send) == "function" then
    pcall(route.after_send, built, reason)
  end
  return true
end

local function _update_active(id, reason)
  Core.state.active = _lc(id)
  Core.state.last_reason = tostring(reason or Core.state.last_reason or "manual")
end

local function _clear_active_if(id)
  id = _lc(id)
  if _lc(Core.state.active) == id then
    Core.state.active = ""
  end
end

local function _is_active(id, entry)
  id = _lc(id)
  local M = _mode()
  if M and type(M.route_loop_active) == "function" then
    local ok, v = pcall(M.route_loop_active, id)
    if ok and v == true then return true end
  end

  local route = _route_for(id, entry)
  if type(route) == "table" and type(route.enabled) == "boolean" then
    return route.enabled == true
  end
  if type(route) == "table" and type(route.state) == "table" and type(route.state.enabled) == "boolean" then
    return route.state.enabled == true
  end
  return false
end

function Core.register(key, route)
  local id, entry = _resolve_id(key)
  if not id then id = _lc(key) end
  if id == "" or type(route) ~= "table" then return false end
  Core.routes[id] = _normalize_route_api(route)
  if type(entry) == "table" and _lc(entry.id) ~= id then
    Core.routes[_lc(entry.id)] = Core.routes[id]
  end
  return true
end

function Core.set_active(key)
  local id, entry = _resolve_id(key)
  if not id then return false, "unknown_route" end
  if entry and not _class_ok(entry) then return false, "wrong_class" end
  _update_active(id, "set_active")
  return true, id
end

function Core.on(key)
  local id, entry = _resolve_id(key)
  if not id then return false, "unknown_route" end
  if entry and not _class_ok(entry) then return false, "wrong_class" end

  local route = _route_for(id, entry)
  local mode_driven = _is_mode_driven(entry, route)
  local ok = false

  if mode_driven then
    local M = _mode()
    if M and type(M.start_route_loop) == "function" then
      local call_ok, started = pcall(M.start_route_loop, id, "off.core:on")
      ok = (call_ok == true and started == true)
    end
  else
    if type(route) == "table" then
      route.enabled = true
      route.state = type(route.state) == "table" and route.state or {}
      route.state.enabled = true
      if type(route.on_start) == "function" then
        pcall(route.on_start)
      end
      ok = true
    end
  end

  if ok then
    _update_active(id, "on")
    return true, id
  end
  return false, "start_failed"
end

function Core.off(key)
  local id, entry = _resolve_id(key)
  if not id then return false, "unknown_route" end

  local route = _route_for(id, entry)
  local mode_driven = _is_mode_driven(entry, route)
  local ok = false

  if mode_driven then
    local M = _mode()
    if M and type(M.stop_route_loop) == "function" then
      local call_ok, stopped = pcall(M.stop_route_loop, id, "off.core:off", false)
      ok = (call_ok == true and stopped == true)
    end
  else
    if type(route) == "table" then
      if type(route.on_stop) == "function" then
        pcall(route.on_stop)
      end
      route.enabled = false
      route.state = type(route.state) == "table" and route.state or {}
      route.state.enabled = false
      ok = true
    end
  end

  if ok then
    _clear_active_if(id)
    return true, id
  end
  return false, "stop_failed"
end

function Core.toggle(key)
  local id, entry = _resolve_id(key)
  if not id then return false, "unknown_route" end
  if entry and not _class_ok(entry) then return false, "wrong_class" end

  if _is_active(id, entry) then
    return Core.off(id)
  end
  return Core.on(id)
end

function Core.tick(reason)
  local id, entry = _resolve_id("")
  if not id then return false, "inactive" end
  if entry and not _class_ok(entry) then return false, "wrong_class" end

  local route = _route_for(id, entry)
  local mode_driven = _is_mode_driven(entry, route)
  local ok, why = false, nil

  if mode_driven then
    local M = _mode()
    if M and type(M.tick_route_loop) == "function" then
      local call_ok, sent = pcall(M.tick_route_loop, id)
      ok = (call_ok == true and sent == true)
      if not call_ok then why = sent end
    else
      why = "mode_unavailable"
    end
  else
    ok, why = _manual_tick(id, route, reason)
  end

  Core.state.last_tick = _now()
  Core.state.last_reason = tostring(reason or "tick")
  return ok, why
end

local function _route_ids()
  local out = {}
  local seen = {}

  local RR = _route_registry()
  if RR and type(RR.active_ids) == "function" then
    local ids = RR.active_ids()
    for i = 1, #(ids or {}) do
      local id = _lc(ids[i])
      if id ~= "" and not seen[id] then
        seen[id] = true
        out[#out + 1] = id
      end
    end
  end

  for id in pairs(Core.routes) do
    id = _lc(id)
    if id ~= "" and not seen[id] then
      seen[id] = true
      out[#out + 1] = id
    end
  end

  return out
end

function Core.route_event(name, ...)
  name = _trim(name)
  if name == "" then return false end
  local fn_name = "on_" .. name
  local any = false

  local ids = _route_ids()
  for i = 1, #ids do
    local id = ids[i]
    local entry = _resolve_entry(id)
    local route = _route_for(id, entry)
    local fn = type(route) == "table" and route[fn_name] or nil
    if type(fn) == "function" then
      pcall(fn, ...)
      any = true
    end
  end
  return any
end

function Core.on_payload_sent(payload, reason)
  local any = false
  local RI = _route_interface()
  local has_route_meta = RI and type(RI.payload_has_any_route) == "function" and RI.payload_has_any_route(payload)
  local ids = _route_ids()
  for i = 1, #ids do
    local id = ids[i]
    local entry = _resolve_entry(id)
    local route = _route_for(id, entry)
    local should_notify = true
    if has_route_meta then
      should_notify = RI.payload_has_route(payload, id)
    end
    if should_notify and type(route) == "table" and type(route.on_payload_sent) == "function" then
      local ctx = { reason = reason or "off.core:payload", route_id = id, has_route_meta = has_route_meta == true }
      pcall(route.on_payload_sent, payload, ctx)
      if type(route.on_send_result) == "function" and route.on_send_result ~= route.on_payload_sent then
        pcall(route.on_send_result, payload, ctx)
      end
      any = true
    end
  end
  return any
end

function Core.on_target_change(old_target, new_target, reason)
  Core.route_event("target_swap", old_target, new_target, reason)
  return Core.tick(reason or "target_change")
end

function Core.on_enemy_kelp_eat(who)
  return Core.route_event("enemy_kelp_eat", who)
end

function Core.on_enemy_aurum_eat(who)
  return Core.route_event("enemy_aurum_eat", who)
end

function Core.on_enemy_tree_touch(who)
  return Core.route_event("enemy_tree_touch", who)
end

local function _bootstrap_registry_routes()
  local RR = _route_registry()
  if not (RR and type(RR.active_ids) == "function" and type(RR.resolve) == "function") then
    return
  end
  local ids = RR.active_ids()
  for i = 1, #(ids or {}) do
    local entry = RR.resolve(ids[i])
    local id = entry and _lc(entry.id) or _lc(ids[i])
    if id ~= "" and type(Core.routes[id]) ~= "table" then
      local route = _ensure_route_module(entry)
      if type(route) == "table" then
        Core.routes[id] = _normalize_route_api(route)
      end
    end
  end
end

_bootstrap_registry_routes()

Yso.off.oc = Yso.off.oc or {}
Yso.off.oc.on = function() return Core.on("oc_aff") end
Yso.off.oc.off = function() return Core.off("oc_aff") end
Yso.off.oc.toggle = function(on)
  if on == nil then return Core.toggle("oc_aff") end
  if on == true then return Core.on("oc_aff") end
  return Core.off("oc_aff")
end
Yso.off.oc.tick = function(reason) return Core.tick(reason) end

Yso.off.oc.on_enemy_kelp_eat = function(who) return Core.on_enemy_kelp_eat(who) end
Yso.off.oc.on_enemy_aurum_eat = function(who) return Core.on_enemy_aurum_eat(who) end
Yso.off.oc.on_enemy_tree_touch = function(who) return Core.on_enemy_tree_touch(who) end

if type(Core.register) ~= "function" then
  _echo("offense core lifecycle failed to initialize")
end

return Core
