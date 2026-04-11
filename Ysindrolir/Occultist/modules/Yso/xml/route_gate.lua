-- DO NOT EDIT IN XML; edit this file instead.

Yso = Yso or {}
Yso.route_gate = Yso.route_gate or {}

local RG = Yso.route_gate

RG.state = RG.state or { last = nil }

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _clone(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for k, v in pairs(value) do
    out[_clone(k, seen)] = _clone(v, seen)
  end
  return out
end

local function _command_sep()
  local sep = _trim((Yso and (Yso.sep or (Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep)))) or "&&")
  if sep == "" then sep = "&&" end
  return sep
end

local function _payload_line(payload)
  local lanes = type(payload) == "table" and payload.lanes or nil
  if type(lanes) ~= "table" then return "" end
  local cmds = {}
  for _, lane in ipairs({ "free", "eq", "bal" }) do
    local cmd = _trim(lanes[lane])
    if cmd ~= "" then cmds[#cmds + 1] = cmd end
  end
  local entity_cmd = _trim(lanes.entity or lanes.class or lanes.ent)
  if entity_cmd ~= "" then cmds[#cmds + 1] = entity_cmd end
  return table.concat(cmds, _command_sep())
end

local function _payload_snapshot(payload)
  local lanes = type(payload) == "table" and payload.lanes or {}
  local meta = type(payload) == "table" and payload.meta or {}
  return {
    route = type(payload) == "table" and payload.route or "",
    target = type(payload) == "table" and payload.target or "",
    lanes = {
      free = lanes.free,
      eq = lanes.eq,
      bal = lanes.bal,
      entity = lanes.entity or lanes.class or lanes.ent,
    },
    categories = {
      free = meta.free_category,
      eq = meta.eq_category,
      bal = meta.bal_category,
      entity = meta.entity_category,
    },
    required_entities = _clone(meta.required_entities or {}),
    main_lane = meta.main_lane,
    line = _payload_line(payload),
  }
end

local function _normalize_payload(payload)
  local out = _clone(payload)
  out.lanes = out.lanes or {}
  out.lanes = type(out.lanes) == "table" and out.lanes or {}
  out.meta = type(out.meta) == "table" and out.meta or {}
  if out.lanes.pre ~= nil and out.lanes.free == nil then
    out.lanes.free = out.lanes.pre
  end
  if out.lanes.entity == nil then
    out.lanes.entity = out.lanes.class or out.lanes.ent
  end
  out.lanes.class = out.lanes.entity
  return out
end

local function _clone_for_emit(payload)
  local out = _normalize_payload(payload)
  out._planned_payload = nil
  out._route_gate = nil
  if type(out.meta) == "table" then
    out.meta.route_gate = nil
  end
  return out
end

local function _blocked_reasons(hinder, entities)
  local out = {}
  local function add(reason)
    reason = _trim(reason)
    if reason == "" then return end
    for i = 1, #out do
      if out[i] == reason then return end
    end
    out[#out + 1] = reason
  end

  if type(hinder) == "table" then
    for i = 1, #(hinder.blocked_reasons or {}) do
      add(hinder.blocked_reasons[i])
    end
  end
  if type(entities) == "table" and type(entities.blocked) == "table" then
    for _, row in pairs(entities.blocked) do
      if type(row) == "table" then add(row.blocked_reason) end
    end
  end
  return out
end

function RG.finalize(payload, ctx)
  local planned = _normalize_payload(payload)
  ctx = _clone(ctx or {})
  ctx.payload = planned

  local hinder_snapshot = Yso.hinder and Yso.hinder.collect and Yso.hinder.collect(ctx) or {}
  local hinder_decision = Yso.hinder and Yso.hinder.classify and Yso.hinder.classify(hinder_snapshot, planned, ctx) or {}
  ctx.hinder_decision = hinder_decision
  local hinder_queue_state = Yso.hinder and Yso.hinder.reconcile_queue and Yso.hinder.reconcile_queue(hinder_decision, ctx) or nil
  ctx.hinder_queue_state = hinder_queue_state

  local entity_state = Yso.entities and Yso.entities.collect and Yso.entities.collect(ctx) or {}
  local entity_obligations = Yso.entities and Yso.entities.classify and Yso.entities.classify(entity_state, planned, ctx) or {}
  local with_entities = Yso.entities and Yso.entities.apply and Yso.entities.apply(planned, entity_obligations, ctx) or planned
  local gated = Yso.hinder and Yso.hinder.apply and Yso.hinder.apply(with_entities, hinder_decision, ctx) or with_entities
  gated = _normalize_payload(gated)

  local ledger = {
    planned = _payload_snapshot(planned),
    gated = _payload_snapshot(gated),
    blocked_reasons = _blocked_reasons(hinder_decision, entity_obligations),
    hinder = {
      snapshot = _clone(hinder_snapshot),
      decision = _clone(hinder_decision),
      queue = _clone(hinder_queue_state),
    },
    entities = {
      required = _clone(entity_state.required or {}),
      obligations = _clone(entity_obligations),
    },
    emitted = {
      at = 0,
      lanes = {},
      line = "",
    },
    confirmed = {
      at = 0,
      lanes = {},
    },
  }

  gated.meta = gated.meta or {}
  gated.meta.route_gate = ledger
  gated._planned_payload = planned
  gated._route_gate = ledger
  RG.state.last = ledger
  return gated, ledger
end

function RG.payload_for_emit(payload)
  if type(payload) ~= "table" then return payload end
  if Yso and Yso.cfg and Yso.cfg.route_gate_live == true then
    return _clone_for_emit(payload)
  end
  if type(payload._planned_payload) == "table" then
    return _clone_for_emit(payload._planned_payload)
  end
  return _clone_for_emit(payload)
end

function RG.note_emitted(payload, emitted_payload, ctx)
  local ledger = type(payload) == "table" and (payload._route_gate or (payload.meta and payload.meta.route_gate)) or nil
  if type(ledger) ~= "table" then return nil end
  local snap = _payload_snapshot(_normalize_payload(emitted_payload))
  ledger.emitted = type(ledger.emitted) == "table" and ledger.emitted or {}
  ledger.emitted.at = (Yso and Yso.util and type(Yso.util.now) == "function" and Yso.util.now()) or os.time()
  ledger.emitted.lanes = snap.lanes
  ledger.emitted.line = snap.line
  return ledger
end

function RG.note_confirmed(payload, confirmed)
  local ledger = type(payload) == "table" and (payload._route_gate or (payload.meta and payload.meta.route_gate)) or nil
  if type(ledger) ~= "table" then return nil end
  ledger.confirmed = type(ledger.confirmed) == "table" and ledger.confirmed or {}
  ledger.confirmed.at = (Yso and Yso.util and type(Yso.util.now) == "function" and Yso.util.now()) or os.time()
  ledger.confirmed.lanes = _clone(confirmed or {})
  return ledger
end

return RG
