--========================================================--
-- group_damage.lua
--  Party damage route for Occultist.
--  Alias-controlled loop ownership is handled by Yso.mode.
--========================================================--

_G.Yso = _G.Yso or _G.yso or {}
_G.yso = _G.Yso

Yso = _G.Yso
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

Yso.off.oc.group_damage = Yso.off.oc.group_damage or {}
local GD = Yso.off.oc.group_damage
GD.alias_owned = true

local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
if not (RI and type(RI.ensure_hooks) == "function") and type(require) == "function" then
  pcall(require, "Yso.Combat.route_interface")
  pcall(require, "Yso.xml.route_interface")
  RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
end

GD.route_contract = GD.route_contract or {
  id = "group_damage",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = { "giving_pressure", "entity_pressure", "damage_conversion", "filler" },
  capabilities = {
    uses_eq = true,
    uses_bal = true,
    uses_entity = true,
    supports_burst = false,
    supports_bootstrap = true,
    needs_target = true,
    shares_defense_break = true,
    shares_anti_tumble = true,
  },
  override_policy = {
    mode = "narrow_global_only",
    allowed = {
      target_invalid = true,
      target_slain = true,
      route_off = true,
      pause = true,
      manual_suppression = true,
    },
  },
  lifecycle = {
    on_enter = true,
    on_exit = true,
    on_target_swap = true,
    on_pause = true,
    on_resume = true,
    on_manual_success = true,
    on_send_result = true,
    evaluate = true,
    explain = true,
  },
}

GD.cfg = GD.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,
  giving_priority = {
    "paralysis",
    "asthma",
    "sensitivity",
    "haemophilia",
    "healthleech",
  },
}

GD.state = GD.state or {
  enabled = false,
  loop_enabled = false,
  timer_id = nil,
  busy = false,
  waiting = { queue = nil, main_lane = nil, lanes = nil, at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil },
  template = { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" },
  explain = {},
}

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
    local v = tonumber(getEpoch()) or os.time()
    if v > 20000000000 then v = v / 1000 end
    return v
  end
  return os.time()
end

local function _echo(msg)
  if GD.cfg.echo ~= true then return end
  if type(cecho) == "function" then
    cecho(string.format("<orange>[Yso:Occultist] <HotPink>%s<reset>\n", tostring(msg)))
  elseif type(echo) == "function" then
    echo(string.format("[Yso:Occultist] %s\n", tostring(msg)))
  end
end

local function _target()
  if type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok and _trim(v) ~= "" then return _trim(v) end
  end
  local t = rawget(_G, "target")
  if type(t) == "string" and _trim(t) ~= "" then return _trim(t) end
  return ""
end

local function _target_valid(tgt)
  if type(Yso.target_is_valid) == "function" then
    local ok, v = pcall(Yso.target_is_valid, tgt)
    if ok then return v == true end
  end
  return _trim(tgt) ~= ""
end

local function _is_occultist()
  if type(Yso.is_occultist) == "function" then
    local ok, v = pcall(Yso.is_occultist)
    if ok then return v == true end
  end
  local cls = gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class or ""
  return _lc(cls) == "occultist"
end

local function _eq_ready()
  if Yso and Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then return v == true end
  end
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(v.eq or v.equilibrium or "") == "1" or (v.eq == true or v.equilibrium == true)
end

local function _bal_ready()
  if Yso and Yso.state and type(Yso.state.bal_ready) == "function" then
    local ok, v = pcall(Yso.state.bal_ready)
    if ok then return v == true end
  end
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(v.bal or v.balance or "") == "1" or (v.bal == true or v.balance == true)
end

local function _ent_ready()
  if Yso and Yso.state and type(Yso.state.ent_ready) == "function" then
    local ok, v = pcall(Yso.state.ent_ready)
    if ok then return v == true end
  end
  return true
end

local function _aff_score(aff)
  aff = tostring(aff or "")
  if aff == "" then return 0 end
  local A = rawget(_G, "affstrack")
  if type(A) == "table" then
    if type(A.score) == "table" and tonumber(A.score[aff]) then
      return tonumber(A.score[aff]) or 0
    end
    local row = A[aff]
    if type(row) == "table" and tonumber(row.score) then
      return tonumber(row.score) or 0
    end
  end
  return 0
end

local function _has_aff(aff)
  return _aff_score(aff) >= 100
end

local function _slime_should_refresh(tgt)
  local ER = Yso and Yso.off and Yso.off.oc and Yso.off.oc.entity_registry or nil
  if type(ER) == "table" and type(ER.slime_should_refresh) == "function" then
    local ok, v = pcall(ER.slime_should_refresh, tgt)
    if ok then return v == true end
  end
  return true
end

local function _next_giving()
  local prio = GD.cfg.giving_priority or {}
  for i = 1, #prio do
    local aff = tostring(prio[i] or "")
    if aff ~= "" and not _has_aff(aff) then
      return aff
    end
  end
  return ""
end

local function _is_party_damage_route()
  local M = Yso and Yso.mode or nil
  if not (type(M) == "table") then return false end
  if type(M.is_party) == "function" then
    local ok, v = pcall(M.is_party)
    if ok and v ~= true then return false end
  end
  if type(M.party_route) == "function" then
    local ok, v = pcall(M.party_route)
    local route = ok and _lc(v) or ""
    if route ~= "" and route ~= "dam" and route ~= "dmg" then return false end
  end
  if type(M.route_loop_active) == "function" then
    local ok, v = pcall(M.route_loop_active, "group_damage")
    if ok and v ~= true then return false end
  end
  return true
end

local function _pick_main_lane(lanes)
  if lanes.eq then return "eq" end
  if lanes.entity then return "entity" end
  if lanes.bal then return "bal" end
  return ""
end

function GD.init()
  GD.cfg = GD.cfg or {}
  GD.state = GD.state or {}
  GD.state.waiting = GD.state.waiting or { queue = nil, main_lane = nil, lanes = nil, at = 0 }
  GD.state.last_attack = GD.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil }
  GD.state.template = GD.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = "" }
  GD.state.explain = GD.state.explain or {}
  GD.state.loop_enabled = (GD.state.loop_enabled == true)
  GD.state.enabled = (GD.state.enabled == true)
  GD.state.busy = (GD.state.busy == true)
  GD.state.timer_id = GD.state.timer_id
  GD.cfg.loop_delay = tonumber(GD.cfg.loop_delay or 0.15) or 0.15

  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(GD, GD.route_contract)
  end
  if Yso and Yso.off and Yso.off.core and type(Yso.off.core.register) == "function" then
    pcall(Yso.off.core.register, "group_damage", GD)
  end
  return true
end

function GD.is_active()
  if not _is_occultist() then return false end
  if GD.cfg.enabled ~= true or GD.state.enabled ~= true or GD.state.loop_enabled ~= true then
    return false
  end
  if type(Yso.offense_paused) == "function" then
    local ok, v = pcall(Yso.offense_paused)
    if ok and v == true then return false end
  end
  return _is_party_damage_route()
end

function GD.alias_loop_on_started()
  _echo("Group damage loop ON.")
end

function GD.alias_loop_on_stopped(ctx)
  ctx = ctx or {}
  if ctx.silent ~= true then
    _echo(string.format("Group damage loop OFF (%s).", tostring(ctx.reason or "manual")))
  end
end

function GD.alias_loop_clear_waiting()
  GD.state.waiting = GD.state.waiting or {}
  GD.state.waiting.queue = nil
  GD.state.waiting.main_lane = nil
  GD.state.waiting.lanes = nil
  GD.state.waiting.at = 0
end

function GD.alias_loop_waiting_blocks()
  return false
end

function GD.build_payload(ctx)
  ctx = ctx or {}
  GD.init()

  local tgt = _target()
  if tgt == "" then return nil, "no_target" end
  if not _target_valid(tgt) then return nil, "invalid_target" end

  local lanes = {}
  local has_healthleech = _has_aff("healthleech")
  local has_paralysis = _has_aff("paralysis")
  local has_asthma = _has_aff("asthma")

  if _eq_ready() then
    if has_healthleech then
      lanes.eq = string.format("warp %s", tgt)
    else
      local nxt = _next_giving()
      if nxt ~= "" then
        lanes.eq = string.format("instill %s with %s", tgt, nxt)
      end
    end
  end

  if _ent_ready() then
    if has_healthleech then
      lanes.entity = string.format("command firelord at %s healthleech", tgt)
    elseif has_asthma and not has_paralysis then
      if _slime_should_refresh(tgt) then
        lanes.entity = string.format("command slime at %s", tgt)
      else
        lanes.entity = string.format("command worm at %s", tgt)
      end
    else
      lanes.entity = string.format("command bubonis at %s", tgt)
    end
  end

  if _bal_ready() and not lanes.eq and not lanes.entity and has_paralysis and has_asthma then
    lanes.bal = string.format("ruinate justice %s", tgt)
  end

  if not (lanes.eq or lanes.entity or lanes.bal) then
    return nil, "no_lanes_ready"
  end

  local payload = {
    route = "group_damage",
    target = tgt,
    lanes = lanes,
    main_lane = _pick_main_lane(lanes),
    category = "party_damage",
    allow_eqbal = true,
  }
  return payload, payload.main_lane
end

function GD.attack_function(ctx)
  GD.init()
  if not GD.is_active() then return false, "route_inactive" end

  local payload, why = GD.build_payload(ctx)
  if not payload then return false, why end

  if type(Yso.emit) == "function" then
    local ok, sent = pcall(Yso.emit, payload)
    if not ok or sent ~= true then
      return false, "emit_failed"
    end
  else
    local cmds = {}
    if payload.lanes.eq then cmds[#cmds + 1] = payload.lanes.eq end
    if payload.lanes.bal then cmds[#cmds + 1] = payload.lanes.bal end
    if payload.lanes.entity then cmds[#cmds + 1] = payload.lanes.entity end
    if #cmds == 0 then return false, "no_lanes_ready" end
    local line = table.concat(cmds, " / ")
    if type(send) == "function" then
      local ok = send(line, false)
      if ok == false then return false, "send_failed" end
    else
      return false, "send_unavailable"
    end
  end

  GD.state.last_attack = GD.state.last_attack or {}
  GD.state.last_attack.at = _now()
  GD.state.last_attack.target = payload.target
  GD.state.last_attack.main_lane = payload.main_lane
  GD.state.last_attack.lanes = payload.lanes
  GD.state.template = GD.state.template or {}
  GD.state.template.last_payload = payload
  GD.state.template.last_target = payload.target
  GD.state.template.last_reason = "attack_sent"
  return true, payload.main_lane
end

function GD.start()
  GD.init()
  GD.cfg.enabled = true
  GD.state.enabled = true
  GD.state.loop_enabled = true
  GD.state.busy = false
  GD.alias_loop_clear_waiting()
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    pcall(Yso.mode.schedule_route_loop, "group_damage", 0)
  end
  return true
end

function GD.stop(reason)
  GD.init()
  GD.state.loop_enabled = false
  GD.state.enabled = false
  GD.cfg.enabled = false
  GD.state.busy = false
  GD.alias_loop_clear_waiting()
  GD.state.template = GD.state.template or {}
  GD.state.template.last_disable_reason = tostring(reason or "manual")
  return true
end

return GD

