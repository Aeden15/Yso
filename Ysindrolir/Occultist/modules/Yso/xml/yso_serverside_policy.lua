-- Auto-exported from Mudlet package script: Yso serverside policy
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso/Curing/serverside_policy.lua
-- Serverside curing coordinator (phase 1 scaffold + working policy).
--  * Mode arbitration: group > class_overlay > default
--  * Delta-only write strategy
--  * Manual intervention grace window
--  * Conservative group hysteresis
--  * Emergency queue + tree policy scaffolding
--========================================================--

Yso = Yso or {}
Yso.curing = Yso.curing or {}
Yso.curing.policy = Yso.curing.policy or {}

local P = Yso.curing.policy

P.cfg = P.cfg or {
  debug = false,
  tick_min_s = 0.25,

  base_set = "default",
  group_set = "group",

  aggression_timeout_s = 28,

  group_window_s = 10,
  group_enter_hits = 8,
  group_enter_attackers = 3,
  group_leave_calm_s = 18,
  group_min_dwell_s = 16,

  manual_grace_s = 8,
  self_send_guard_s = 0.35,

  emergency_min_gap_s = 2.0,
  tree_min_gap_s = 4.0,
}

P.state = P.state or {
  mode = "default",
  current_set = "",
  active_overlay = nil,

  group_active = false,
  group_since = 0,
  group_forced = nil,

  last_tick = 0,
  last_apply = 0,
  last_hostile_at = 0,
  aggression_until = 0,

  manual_grace_until = 0,
  last_manual_source = "",
  self_send_until = 0,

  hit_log = {},
  attacker_seen = {},

  overlay_applied = {},
  known_baseline = {},

  queue_recent = {},
  tree_policy = "",
  last_tree_at = 0,

  priority_list_requested_at = 0,
}

P.overlays = P.overlays or {
  blademaster = {
    class = "Blademaster",
    raise = {
      "paralysis",
      "asthma",
      "slickness",
      "impatience",
      "anorexia",
      "weariness",
      "clumsiness",
      "dizziness",
      "sensitivity",
      "damagedlimb",
      "crippledlimb",
      "mangledlimb",
    },
    lower = {},
    queue_emergency = {
      -- phase-1 scaffold
      -- { qtype = "bal", cmd = "touch tree", dedupe = "tree_touch" },
    },
    tree_hints = {
      prefer = "aff_trigger",
    },
  },
}

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 1e12 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _tbl_size(t)
  local n = 0
  if type(t) ~= "table" then return 0 end
  for _ in pairs(t) do n = n + 1 end
  return n
end

local function _echo(msg)
  if P.cfg.debug ~= true then return end
  if type(cecho) == "function" then
    cecho(string.format("<cadet_blue>[Yso:policy] <reset>%s\n", tostring(msg)))
  end
end

local function _canon_aff(aff)
  if Yso and Yso.selfaff and type(Yso.selfaff.normalize) == "function" then
    return Yso.selfaff.normalize(aff)
  end
  return tostring(aff or ""):lower()
end

local function _norm_class(v)
  v = _trim(v)
  if v == "" then return "" end
  return v:sub(1, 1):upper() .. v:sub(2):lower()
end

local function _mark_self_send()
  P.state.self_send_until = _now() + (tonumber(P.cfg.self_send_guard_s or 0.35) or 0.35)
end

local function _is_self_send_window()
  return _now() <= (tonumber(P.state.self_send_until or 0) or 0)
end

local function _manual_grace_active()
  return _now() < (tonumber(P.state.manual_grace_until or 0) or 0)
end

local function _adapter_table()
  Yso.curing = Yso.curing or {}
  Yso.curing.adapters = Yso.curing.adapters or {}
  return Yso.curing.adapters
end

local function _send_profile(set_name)
  set_name = _trim(set_name):lower()
  if set_name == "" then return false end

  if _trim(P.state.current_set):lower() == set_name then
    return false
  end

  local C = _adapter_table()
  _mark_self_send()
  if type(C.use_profile) == "function" then
    C.use_profile(set_name)
  elseif type(send) == "function" then
    send("curingset switch " .. set_name, false)
  end

  P.state.current_set = set_name
  _echo("switch set -> " .. set_name)
  return true
end

local function _set_prio(aff, prio)
  aff = _canon_aff(aff)
  prio = tonumber(prio)
  if aff == "" or not prio then return false end

  local C = _adapter_table()
  _mark_self_send()
  if type(C.set_aff_prio) == "function" then
    C.set_aff_prio(aff, prio)
  elseif type(send) == "function" then
    send(string.format("curing priority %s %d", aff, prio), false)
  end
  return true
end

local function _restore_aff_default(aff)
  aff = _canon_aff(aff)
  if aff == "" then return false end

  local base = P.state.known_baseline[aff]
  if type(base) == "number" then
    return _set_prio(aff, base)
  end

  if type(Reprio) == "function" then
    _mark_self_send()
    Reprio(aff)
    return true
  end

  return _set_prio(aff, 26)
end

local function _read_baseline_from_legacy(set_name)
  local set = _trim(set_name):lower()
  if set == "" then return end
  local prios = Legacy and Legacy.Curing and Legacy.Curing.Prios
  local base_sets = prios and prios.baseSets
  local row = type(base_sets) == "table" and base_sets[set] or nil
  if type(row) ~= "table" then return end

  for aff, pos in pairs(row) do
    if type(pos) == "number" then
      P.state.known_baseline[_canon_aff(aff)] = pos
    end
  end
end

local function _read_current_set()
  local set = ""
  if Legacy and Legacy.Curing and type(Legacy.Curing.ActiveServerSet) == "string" then
    set = _trim(Legacy.Curing.ActiveServerSet):lower()
  end
  if set == "" and type(rawget(_G, "CurrentCureset")) == "string" then
    set = _trim(rawget(_G, "CurrentCureset")):lower()
  end
  if set ~= "" then
    P.state.current_set = set
  end
  return set
end

local function _target_name()
  if Yso and type(Yso.get_target) == "function" then
    local ok, t = pcall(Yso.get_target)
    t = ok and _trim(t) or ""
    if t ~= "" then return t end
  end
  return _trim(rawget(_G, "target"))
end

local function _legacy_enemy_class()
  local tgt = _target_name()
  if tgt == "" then return "" end

  local cls = ""
  if Legacy and Legacy.CT and type(Legacy.CT.Enemies) == "table" then
    cls = Legacy.CT.Enemies[tgt]
      or Legacy.CT.Enemies[tgt:lower()]
      or Legacy.CT.Enemies[tgt:sub(1, 1):upper() .. tgt:sub(2):lower()]
      or ""
  end

  if cls == "" and Legacy and Legacy.CT and type(Legacy.CT.timers) == "table" then
    local timer = Legacy.CT.timers[tgt] or Legacy.CT.timers[tgt:lower()]
    if type(timer) == "table" then
      cls = timer.class or ""
    end
  end

  return _norm_class(cls)
end

local function _legacy_group_signal()
  local en_class = _norm_class(rawget(_G, "enClass"))
  if en_class == "Group" then return true end

  if Legacy and Legacy.CT and type(Legacy.CT.timers) == "table" then
    if _tbl_size(Legacy.CT.timers) >= 3 then
      return true
    end
  end
  return false
end

local function _prune_hits(now)
  local win = tonumber(P.cfg.group_window_s or 10) or 10
  local kept = {}
  local seen = {}

  for i = 1, #(P.state.hit_log or {}) do
    local row = P.state.hit_log[i]
    if type(row) == "table" then
      local at = tonumber(row.at or 0) or 0
      if at > 0 and (now - at) <= win then
        kept[#kept + 1] = row
        if row.attacker ~= "" then seen[row.attacker] = true end
      end
    end
  end

  P.state.hit_log = kept
  P.state.attacker_seen = seen

  return #kept, _tbl_size(seen)
end

function P.note_hostile_hit(attacker, source)
  local now = _now()
  attacker = _trim(attacker):lower()

  local row = {
    at = now,
    attacker = attacker,
    source = tostring(source or "hostile"),
  }
  P.state.hit_log[#P.state.hit_log + 1] = row
  if attacker ~= "" then
    P.state.attacker_seen[attacker] = true
  end

  P.state.last_hostile_at = now
  local expiry = now + (tonumber(P.cfg.aggression_timeout_s or 28) or 28)
  if expiry > (tonumber(P.state.aggression_until or 0) or 0) then
    P.state.aggression_until = expiry
  end

  _prune_hits(now)
  return true
end

function P.note_manual_intervention(source)
  if _is_self_send_window() then return false end
  local now = _now()
  local grace = tonumber(P.cfg.manual_grace_s or 8) or 8
  P.state.manual_grace_until = now + grace
  P.state.last_manual_source = tostring(source or "manual")
  if type(raiseEvent) == "function" then
    raiseEvent("yso.curing.manual_intervention", P.state.last_manual_source, grace)
  end
  _echo("manual grace armed from " .. P.state.last_manual_source)
  return true
end

local function _aggression_active(now)
  now = tonumber(now) or _now()
  if now < (tonumber(P.state.aggression_until or 0) or 0) then
    return true
  end

  if Yso and Yso.mode and Yso.mode.auto and Yso.mode.auto.state then
    local until_at = tonumber(Yso.mode.auto.state.combat_until or 0) or 0
    if now < until_at then return true end
  end

  local last = tonumber(P.state.last_hostile_at or 0) or 0
  local timeout = tonumber(P.cfg.aggression_timeout_s or 28) or 28
  if last > 0 and (now - last) <= timeout then
    return true
  end

  return false
end

local function _compute_group_active(now)
  now = tonumber(now) or _now()
  if P.state.group_forced ~= nil then
    return P.state.group_forced == true
  end

  local hits, attackers = _prune_hits(now)
  local legacy = _legacy_group_signal()
  local fallback = hits >= (tonumber(P.cfg.group_enter_hits or 8) or 8)
    and attackers >= (tonumber(P.cfg.group_enter_attackers or 3) or 3)

  if P.state.group_active == true then
    if legacy or fallback then return true end

    local dwell = tonumber(P.cfg.group_min_dwell_s or 16) or 16
    if (now - (tonumber(P.state.group_since or now) or now)) < dwell then
      return true
    end

    local calm = tonumber(P.cfg.group_leave_calm_s or 18) or 18
    if (now - (tonumber(P.state.last_hostile_at or 0) or 0)) < calm then
      return true
    end

    return false
  end

  return legacy or fallback
end

local function _select_overlay(now)
  now = tonumber(now) or _now()
  if not _aggression_active(now) then
    return nil
  end

  local cls = _legacy_enemy_class()
  if cls == "Blademaster" then
    return "blademaster"
  end

  return nil
end

local function _clear_overlay_deltas()
  local had = false
  for aff in pairs(P.state.overlay_applied or {}) do
    had = true
    _restore_aff_default(aff)
  end
  P.state.overlay_applied = {}
  P.state.active_overlay = nil
  return had
end

local function _apply_overlay(name)
  if _trim(name) == "" then
    return _clear_overlay_deltas()
  end

  if P.state.active_overlay == name then
    return false
  end

  _clear_overlay_deltas()

  local spec = P.overlays[name]
  if type(spec) ~= "table" then
    return false
  end

  for i = 1, #(spec.raise or {}) do
    local aff = _canon_aff(spec.raise[i])
    if aff ~= "" then
      _set_prio(aff, 1)
      P.state.overlay_applied[aff] = 1
    end
  end

  for i = 1, #(spec.lower or {}) do
    local aff = _canon_aff(spec.lower[i])
    if aff ~= "" then
      _set_prio(aff, 26)
      P.state.overlay_applied[aff] = 26
    end
  end

  P.state.active_overlay = name
  _echo("overlay -> " .. name)
  return true
end

local function _compute_tree_policy(now, overlay)
  now = tonumber(now) or _now()

  local in_hunt = false
  if Yso and Yso.mode and type(Yso.mode.is_hunt) == "function" then
    local ok, v = pcall(Yso.mode.is_hunt)
    in_hunt = ok and (v == true)
  end

  if not in_hunt then
    local set = _trim(P.state.current_set):lower()
    in_hunt = (set == "hunt" or set == "bash")
  end

  if in_hunt then return "aff_count" end
  if overlay ~= nil or _aggression_active(now) then return "aff_trigger" end
  return "aff_count"
end

local function _apply_tree_policy(policy, overlay)
  policy = _trim(policy)
  if policy == "" then return false end
  if P.state.tree_policy == policy then return false end

  local now = _now()
  local min_gap = tonumber(P.cfg.tree_min_gap_s or 4.0) or 4.0
  if now - (tonumber(P.state.last_tree_at or 0) or 0) < min_gap then
    return false
  end

  local C = _adapter_table()
  if type(C.set_tree_policy) == "function" then
    _mark_self_send()
    C.set_tree_policy(policy, {
      overlay = overlay,
      mode = P.state.mode,
      curingset = P.state.current_set,
    })
  end

  P.state.tree_policy = policy
  P.state.last_tree_at = now

  if type(raiseEvent) == "function" then
    raiseEvent("yso.curing.tree_policy", policy, overlay)
  end

  return true
end

function P.queue_emergency(cmd, opts)
  opts = opts or {}
  cmd = _trim(cmd)
  if cmd == "" then return false, "empty" end
  if _manual_grace_active() then return false, "manual_grace" end

  local now = _now()
  local qtype = _trim(opts.qtype or "bal")
  local idx = tonumber(opts.index)
  local key = string.format("%s|%s|%s", qtype, tostring(idx or ""), cmd:lower())

  local last = tonumber(P.state.queue_recent[key] or 0) or 0
  local min_gap = tonumber(P.cfg.emergency_min_gap_s or 2.0) or 2.0
  if last > 0 and (now - last) < min_gap then
    return false, "dedupe"
  end

  local line
  if idx and idx >= 1 then
    line = string.format("QUEUE INSERT %s %d %s", qtype, idx, cmd)
  else
    line = string.format("QUEUE ADD %s %s", qtype, cmd)
  end

  local C = _adapter_table()
  _mark_self_send()
  if type(C.queue_emergency) == "function" then
    local ok = C.queue_emergency(cmd, {
      qtype = qtype,
      index = idx,
    })
    if ok ~= true then
      return false, "adapter_rejected"
    end
  elseif type(send) == "function" then
    send(line, false)
  else
    return false, "send_missing"
  end

  P.state.queue_recent[key] = now
  return true
end

function P.resync(reason)
  reason = tostring(reason or "resync")
  _read_current_set()
  _read_baseline_from_legacy(P.cfg.base_set)

  local now = _now()
  local requested_at = tonumber(P.state.priority_list_requested_at or 0) or 0
  if (now - requested_at) >= 6 and type(send) == "function" then
    _mark_self_send()
    send("curing priority list", false)
    P.state.priority_list_requested_at = now
  end

  P.tick("resync:" .. reason, true)
  return true
end

function P.set_group_override(v, reason)
  if v == nil then
    local was_forced = (P.state.group_forced == true)
    P.state.group_forced = nil
    if was_forced then
      -- Clearing an explicit override should not inherit fallback hysteresis.
      P.state.group_active = false
      P.state.group_since = 0
    end
    P.tick("group_override:clear", true)
    return true
  end

  P.state.group_forced = (v == true)
  P.tick("group_override:" .. tostring(reason or "manual"), true)
  return true
end

function P.tick(source, force)
  local now = _now()
  local min_tick = tonumber(P.cfg.tick_min_s or 0.25) or 0.25
  if force ~= true and (now - (tonumber(P.state.last_tick or 0) or 0)) < min_tick then
    return false, "throttled"
  end
  P.state.last_tick = now

  _read_current_set()

  local group_on = _compute_group_active(now)
  local overlay = (group_on and nil) or _select_overlay(now)

  if _manual_grace_active() then
    P.state.mode = group_on and "group" or (overlay and "class_overlay" or "default")
    return true, "manual_grace"
  end

  local changed = false

  if group_on then
    if P.state.group_active ~= true then
      P.state.group_active = true
      P.state.group_since = now
    end

    if _send_profile(P.cfg.group_set) then changed = true end
    if _clear_overlay_deltas() then changed = true end
    P.state.mode = "group"
  else
    if P.state.group_active == true then
      P.state.group_active = false
      if _send_profile(P.cfg.base_set) then changed = true end
    else
      if _trim(P.state.current_set) == "" then
        if _send_profile(P.cfg.base_set) then changed = true end
      end
    end

    if overlay then
      if _trim(P.state.current_set):lower() ~= _trim(P.cfg.base_set):lower() then
        if _send_profile(P.cfg.base_set) then changed = true end
      end
      if _apply_overlay(overlay) then changed = true end
      P.state.mode = "class_overlay"
    else
      if _clear_overlay_deltas() then changed = true end
      P.state.mode = "default"
    end
  end

  local tree_policy = _compute_tree_policy(now, overlay)
  if _apply_tree_policy(tree_policy, overlay) then
    changed = true
  end

  if changed then
    P.state.last_apply = now
    if type(raiseEvent) == "function" then
      raiseEvent("yso.curing.policy.applied", P.state.mode, overlay or "")
    end
  end

  return true, changed and "applied" or "stable"
end

function P.status()
  return {
    mode = P.state.mode,
    current_set = P.state.current_set,
    overlay = P.state.active_overlay,
    group_active = (P.state.group_active == true),
    manual_grace = math.max(0, (tonumber(P.state.manual_grace_until or 0) or 0) - _now()),
    aggression_left = math.max(0, (tonumber(P.state.aggression_until or 0) or 0) - _now()),
    tree_policy = P.state.tree_policy,
  }
end

local function _kill_eh(id)
  if id and type(killAnonymousEventHandler) == "function" then
    pcall(killAnonymousEventHandler, id)
  end
end

local function _kill_tr(id)
  if id and type(killTrigger) == "function" then
    pcall(killTrigger, id)
  end
end

function P.install_hooks()
  if P._hooks_installed == true then return true end
  P._eh = P._eh or {}
  P._tr = P._tr or {}

  if type(registerAnonymousEventHandler) == "function" then
    _kill_eh(P._eh.vitals)
    P._eh.vitals = registerAnonymousEventHandler("gmcp.Char.Vitals", function()
      P.tick("gmcp.vitals")
    end)

    _kill_eh(P._eh.prompt)
    P._eh.prompt = registerAnonymousEventHandler("sysPrompt", function()
      P.tick("prompt")
    end)

    _kill_eh(P._eh.mode)
    P._eh.mode = registerAnonymousEventHandler("yso.mode.changed", function()
      P.tick("mode_changed", true)
    end)

    _kill_eh(P._eh.slc_hit)
    P._eh.slc_hit = registerAnonymousEventHandler("Legacy.SLC.Hit", function(_, attacker)
      P.note_hostile_hit(attacker, "Legacy.SLC.Hit")
    end)

    _kill_eh(P._eh.send_request)
    P._eh.send_request = registerAnonymousEventHandler("sysDataSendRequest", function(_, command)
      if type(command) ~= "string" then return end
      if _trim(command) == "" then return end
      if _is_self_send_window() then return end
      P.note_manual_intervention("sysDataSendRequest")
    end)
  end

  if type(tempRegexTrigger) == "function" then
    _kill_tr(P._tr.prio_changed)
    P._tr.prio_changed = tempRegexTrigger([[^Changed the priority of .+\.$]], function()
      if _is_self_send_window() then return end
      P.note_manual_intervention("text_ack:prio")
    end)

    _kill_tr(P._tr.set_changed)
    P._tr.set_changed = tempRegexTrigger([[^Changed the set named .+\.$]], function()
      if _is_self_send_window() then return end
      P.note_manual_intervention("text_ack:set")
    end)
  end

  P._hooks_installed = true
  return true
end

function P.init()
  _read_current_set()
  _read_baseline_from_legacy(P.cfg.base_set)
  P.install_hooks()
  P.resync("init")
  return true
end

P.init()

return P
