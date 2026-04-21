--========================================================--
-- Yso Combat Route Interface (Common Contract)
--  • Canonical shared route contract for Occultist combat routes.
--  • Routes expose shared metadata/hooks for the alias-owned loop controller.
--  • Shared universal categories across future routes:
--      - defense_break
--      - anti_tumble
--  • Other strategic categories are route-local and may differ per route.
--  • All routes should expose the full lifecycle hook surface as callable stubs
--    even when the hook is currently a no-op.
--
-- Recommended override policy:
--  • Narrow global-only overrides.
--  • Shared route helpers may override route intent only for hard global conditions:
--      - reserved_burst
--      - target_invalid / target_slain
--      - route_off
--      - pause
--      - manual_suppression
--      - target_swap_bootstrap
--      - defense_break
--      - anti_tumble
--========================================================--

Yso = Yso or {}
Yso.Combat = Yso.Combat or {}
Yso.Combat.RouteInterface = Yso.Combat.RouteInterface or {}
local RI = Yso.Combat.RouteInterface

RI.VERSION = 1

RI.SHARED_CATEGORIES = RI.SHARED_CATEGORIES or {
  defense_break = true,
  anti_tumble   = true,
}

RI.DEFAULT_OVERRIDE_POLICY = RI.DEFAULT_OVERRIDE_POLICY or {
  mode = "narrow_global_only",
  allowed = {
    reserved_burst       = true,
    target_invalid       = true,
    target_slain         = true,
    route_off            = true,
    pause                = true,
    manual_suppression   = true,
    target_swap_bootstrap= true,
    defense_break        = true,
    anti_tumble          = true,
  },
}

RI.DEFAULT_HOOKS = RI.DEFAULT_HOOKS or {
  on_enter          = true,
  on_exit           = true,
  on_target_swap    = true,
  on_pause          = true,
  on_resume         = true,
  on_manual_success = true,
  on_send_result    = true,
  evaluate          = true,
  explain           = true,
}

local function _copy(tbl)
  local out = {}
  if type(tbl) ~= "table" then return out end
  for k, v in pairs(tbl) do out[k] = v end
  return out
end

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

local function _command_sep()
  local sep = _trim((Yso and (Yso.sep or (Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep)))) or "&&")
  if sep == "" then sep = "&&" end
  return sep
end

local function _lane_text(v)
  if type(v) == "table" then
    local out = {}
    for i = 1, #v do
      local part = _trim(v[i])
      if part ~= "" then out[#out + 1] = part end
    end
    return table.concat(out, _command_sep())
  end
  return _trim(v)
end

local function _lane_has_value(v)
  if type(v) == "table" then return #v > 0 end
  return _trim(v) ~= ""
end

local function _normalize_targets(route_ids)
  local out, seen = {}, {}
  if type(route_ids) ~= "table" then
    route_ids = { route_ids }
  end
  for i = 1, #route_ids do
    local id = _lc(route_ids[i])
    if id ~= "" and not seen[id] then
      seen[id] = true
      out[#out + 1] = id
    end
  end
  return out
end

local function _noop() return nil end
local function _noop_evaluate() return {} end
local function _noop_explain() return {} end

function RI.normalize(spec)
  spec = type(spec) == "table" and spec or {}
  spec.interface_version = tonumber(spec.interface_version or RI.VERSION)
  spec.shared_categories = spec.shared_categories or { "defense_break", "anti_tumble" }
  spec.route_local_categories = spec.route_local_categories or {}
  spec.capabilities = spec.capabilities or {}
  spec.override_policy = spec.override_policy or _copy(RI.DEFAULT_OVERRIDE_POLICY)
  spec.lifecycle = spec.lifecycle or {
    on_enter = false,
    on_exit = false,
    on_target_swap = false,
    on_pause = false,
    on_resume = false,
    on_manual_success = false,
    on_send_result = false,
    evaluate = false,
    explain = false,
  }
  return spec
end

function RI.ensure_hooks(route, spec)
  route = type(route) == "table" and route or {}
  spec = RI.normalize(spec)

  local hook_impls = {
    on_enter = _noop,
    on_exit = _noop,
    on_target_swap = _noop,
    on_pause = _noop,
    on_resume = _noop,
    on_manual_success = _noop,
    on_send_result = _noop,
    evaluate = _noop_evaluate,
    explain = _noop_explain,
  }

  spec.lifecycle = spec.lifecycle or {}
  for hook, fn in pairs(hook_impls) do
    if type(route[hook]) ~= "function" then
      route[hook] = fn
    end
    spec.lifecycle[hook] = true
  end

  return route, spec
end

function RI.validate(spec)
  spec = RI.normalize(spec)
  local errs = {}
  if type(spec.id) ~= "string" or spec.id == "" then errs[#errs+1] = "missing route id" end
  if type(spec.shared_categories) ~= "table" then errs[#errs+1] = "shared_categories must be a table" end
  if type(spec.route_local_categories) ~= "table" then errs[#errs+1] = "route_local_categories must be a table" end
  if type(spec.capabilities) ~= "table" then errs[#errs+1] = "capabilities must be a table" end
  if type(spec.override_policy) ~= "table" then errs[#errs+1] = "override_policy must be a table" end
  return (#errs == 0), errs, spec
end

function RI.normalize_lanes(payload)
  payload = type(payload) == "table" and payload or {}
  local lanes = type(payload.lanes) == "table" and payload.lanes or payload
  local out = {
    free = lanes.free or lanes.pre,
    eq = lanes.eq,
    bal = lanes.bal,
    class = lanes.class or lanes.entity or lanes.ent,
  }
  out.entity = out.class
  return out
end

function RI.attach_legacy_lanes(payload)
  payload = type(payload) == "table" and payload or {}
  local lanes = RI.normalize_lanes(payload)
  payload.lanes = payload.lanes or {}
  payload.lanes.free = lanes.free
  payload.lanes.eq = lanes.eq
  payload.lanes.bal = lanes.bal
  payload.lanes.class = lanes.class
  payload.lanes.entity = lanes.class
  payload.free = lanes.free
  payload.eq = lanes.eq
  payload.bal = lanes.bal
  payload.class = lanes.class
  payload.entity = lanes.class
  payload.ent = lanes.class
  return payload
end

function RI.payload_line(payload)
  local lanes = RI.normalize_lanes(payload)
  local cmds = {}

  local free = lanes.free
  if type(free) == "table" then
    for i = 1, #free do
      local cmd = _trim(free[i])
      if cmd ~= "" then cmds[#cmds + 1] = cmd end
    end
  else
    local cmd = _trim(free)
    if cmd ~= "" then cmds[#cmds + 1] = cmd end
  end

  local eq = _trim(lanes.eq)
  if eq ~= "" then cmds[#cmds + 1] = eq end
  local bal = _trim(lanes.bal)
  if bal ~= "" then cmds[#cmds + 1] = bal end
  local class_cmd = _trim(lanes.class)
  if class_cmd ~= "" then cmds[#cmds + 1] = class_cmd end

  return table.concat(cmds, _command_sep())
end

local function _payload_route_values(payload)
  payload = type(payload) == "table" and payload or {}
  local values, seen = {}, {}

  local function add(value)
    local id = _lc(value)
    if id == "" or seen[id] then return end
    seen[id] = true
    values[#values + 1] = id
  end

  add(payload.route)
  add(payload.meta and payload.meta.route)

  local rb = payload.route_by_lane or (payload.meta and payload.meta.route_by_lane)
  if type(rb) == "table" then
    for _, lane in ipairs({ "eq", "bal", "class", "free" }) do
      add(rb[lane])
    end
  end

  return values
end

function RI.payload_has_any_route(payload)
  return #_payload_route_values(payload) > 0
end

function RI.payload_has_route(payload, route_ids)
  local targets = _normalize_targets(route_ids)
  if #targets == 0 then return false end
  local values = _payload_route_values(payload)
  if #values == 0 then return false end
  local wanted = {}
  for i = 1, #targets do wanted[targets[i]] = true end
  for i = 1, #values do
    if wanted[values[i]] then return true end
  end
  return false
end

function RI.payload_target(payload)
  payload = type(payload) == "table" and payload or {}
  return _trim(payload.target or (payload.meta and payload.meta.target))
end

function RI.emit_route_payload(route_id, payload, opts)
  route_id = _lc(route_id)
  if route_id == "" then return false, "missing_route" end

  opts = type(opts) == "table" and _copy(opts) or {}
  payload = type(payload) == "table" and payload or {}
  local lanes = RI.normalize_lanes(payload)

  local target = _trim(opts.target or payload.target or (payload.meta and payload.meta.target))
  local emit_payload = {
    free = lanes.free,
    eq = lanes.eq,
    bal = lanes.bal,
    class = lanes.class,
    target = target,
  }

  opts.route = route_id
  opts.target = target
  opts.kind = _trim(opts.kind) ~= "" and opts.kind or "offense"
  if opts.commit == nil then opts.commit = true end
  if _trim(opts.reason) == "" then opts.reason = route_id .. ":emit" end

  local sent = false
  if type(Yso.emit) == "function" then
    sent = (Yso.emit(emit_payload, opts) == true)
    if not sent then return false, "emit_failed" end
  else
    local Q = Yso and Yso.queue or nil
    if not (Q and type(Q.emit) == "function") then
      return false, "queue_emit_unavailable"
    end
    local ok, res = pcall(Q.emit, emit_payload, opts)
    if not ok then return false, res end
    if res ~= true then return false, "queue_emit_failed" end
  end

  local route_by_lane = {}
  local target_by_lane = {}
  for _, lane in ipairs({ "eq", "bal", "class", "free" }) do
    if _lane_has_value(emit_payload[lane]) then
      route_by_lane[lane] = route_id
      target_by_lane[lane] = target
    end
  end

  local ack_payload = {
    route = route_id,
    target = target,
    lanes = {
      free = emit_payload.free,
      eq = emit_payload.eq,
      bal = emit_payload.bal,
      class = emit_payload.class,
      entity = emit_payload.class,
    },
    meta = _copy(payload.meta),
    route_by_lane = route_by_lane,
    target_by_lane = target_by_lane,
  }
  ack_payload.meta.route = route_id
  ack_payload.meta.target = target
  ack_payload.meta.route_by_lane = route_by_lane
  ack_payload.meta.target_by_lane = target_by_lane
  ack_payload.meta.source = "route_emit"
  RI.attach_legacy_lanes(ack_payload)
  ack_payload.cmd = RI.payload_line(ack_payload)

  return true, ack_payload.cmd, ack_payload
end

function RI.ensure_waiting_state(state, route_id)
  state = type(state) == "table" and state or {}
  route_id = _lc(route_id)
  if route_id == "" then route_id = _lc(state.route or "") end
  state.waiting = state.waiting or { queue = nil, main_lane = nil, lanes = nil, fingerprint = "", reason = "", at = 0 }
  state.last_attack = state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil, fingerprint = "" }
  state.in_flight = state.in_flight or { fingerprint = "", target = "", route = route_id, at = 0, resolved_at = 0, lanes = nil, eq = "", entity = "", reason = "" }
  if _trim(state.in_flight.route) == "" then
    state.in_flight.route = route_id
  end
  return state
end

function RI.clear_waiting(state, route_id)
  state = RI.ensure_waiting_state(state, route_id)
  state.waiting.queue = nil
  state.waiting.main_lane = nil
  state.waiting.lanes = nil
  state.waiting.fingerprint = ""
  state.waiting.reason = ""
  state.waiting.at = 0

  state.in_flight.resolved_at = _now()
  state.in_flight.fingerprint = ""
  state.in_flight.target = ""
  state.in_flight.lanes = nil
  state.in_flight.eq = ""
  state.in_flight.entity = ""
  state.in_flight.reason = ""
  return true
end

function RI.mark_waiting(state, route_id, payload, opts)
  state = RI.ensure_waiting_state(state, route_id)
  payload = RI.attach_legacy_lanes(_copy(payload))
  opts = type(opts) == "table" and opts or {}
  local lanes = RI.normalize_lanes(payload)
  local cmd = _trim(opts.cmd or RI.payload_line(payload))
  local target = _trim(opts.target or RI.payload_target(payload))
  local ts = tonumber(opts.at) or _now()

  local lane_list = {}
  local function add(name, value)
    if not _lane_has_value(value) then return end
    lane_list[#lane_list + 1] = _lc(name)
  end
  add("eq", lanes.eq)
  add("bal", lanes.bal)
  add("class", lanes.class)

  local main_lane = _lc(opts.main_lane or (payload.meta and payload.meta.main_lane))
  if main_lane == "" then
    main_lane = lane_list[1] or (_lane_has_value(lanes.free) and "free" or "")
  end

  local wait_reason = _trim(opts.wait_reason)
  if wait_reason == "" then
    wait_reason = "waiting_outcome"
    if #lane_list == 1 then
      if lane_list[1] == "eq" then wait_reason = "waiting_eq"
      elseif lane_list[1] == "class" then wait_reason = "waiting_ent" end
    end
  end

  local fp = _trim(opts.fingerprint)
  if fp == "" then
    local pieces = { route_id, target, _lane_text(lanes.eq), _lane_text(lanes.class), _lane_text(lanes.bal), _lane_text(lanes.free) }
    fp = table.concat(pieces, "|")
  end

  state.last_attack.cmd = cmd
  state.last_attack.at = ts
  state.last_attack.target = target
  state.last_attack.main_lane = main_lane
  state.last_attack.lanes = lane_list
  state.last_attack.fingerprint = fp

  state.waiting.queue = cmd
  state.waiting.main_lane = main_lane
  state.waiting.lanes = lane_list
  state.waiting.fingerprint = fp
  state.waiting.reason = wait_reason
  state.waiting.at = ts

  state.in_flight.fingerprint = fp
  state.in_flight.target = target
  state.in_flight.route = _lc(route_id)
  state.in_flight.at = ts
  state.in_flight.lanes = lane_list
  state.in_flight.eq = _trim(lanes.eq)
  state.in_flight.entity = _trim(lanes.class)
  state.in_flight.reason = wait_reason

  return true
end

function RI.clear_waiting_on_ack(state, route_id, payload, opts)
  state = RI.ensure_waiting_state(state, route_id)
  opts = type(opts) == "table" and opts or {}
  local has_routes = RI.payload_has_any_route(payload)
  if has_routes then
    if not RI.payload_has_route(payload, route_id) then
      return false
    end
  elseif opts.require_route == true then
    return false
  end
  return RI.clear_waiting(state, route_id)
end

function RI.nudge_route(route_id, reason)
  local M = Yso and Yso.mode or nil
  if M and type(M.nudge_route_loop) == "function" then
    return M.nudge_route_loop(route_id, reason)
  end
  return false, "mode_nudge_unavailable"
end

return RI
