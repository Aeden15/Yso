-- Auto-exported from Mudlet package script: Yso serverside policy
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso/Curing/serverside_policy.lua
-- Serverside curing coordinator (phase 1 scaffold + working policy).
--  * Mode arbitration: group > class_overlay > default
--  * Delta-only write strategy
--  * Manual intervention grace window
--  * Conservative group hysteresis
--  * Emergency queue scaffold + tree-ready diagnostics
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
  set_untrusted = false,
  set_untrusted_reason = "",
  set_untrusted_since = 0,
  set_observed_streak = 0,
  set_last_observed = "",
  set_last_resync_req_at = 0,
  set_expected = "",
  set_expected_until = 0,

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
  tree_ready = false,
  tree_ready_known = false,
  tree_last_ready_at = 0,
  tree_last_source = "",

  priority_list_requested_at = 0,
}
P.state.set_untrusted = (P.state.set_untrusted == true)
P.state.set_untrusted_reason = tostring(P.state.set_untrusted_reason or "")
P.state.set_untrusted_since = tonumber(P.state.set_untrusted_since or 0) or 0
P.state.set_observed_streak = tonumber(P.state.set_observed_streak or 0) or 0
P.state.set_last_observed = tostring(P.state.set_last_observed or "")
P.state.set_last_resync_req_at = tonumber(P.state.set_last_resync_req_at or 0) or 0
P.state.set_expected = tostring(P.state.set_expected or "")
P.state.set_expected_until = tonumber(P.state.set_expected_until or 0) or 0
P.state.tree_ready = (P.state.tree_ready == true)
P.state.tree_ready_known = (P.state.tree_ready_known == true)
P.state.tree_last_ready_at = tonumber(P.state.tree_last_ready_at or 0) or 0
P.state.tree_last_source = tostring(P.state.tree_last_source or "")

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

local function _sync_tree_compat_mirrors()
  Yso.state = Yso.state or {}
  Yso.tree = Yso.tree or {}
  Yso.tree.state = Yso.tree.state or {}
  local ready = (P.state.tree_ready == true)
  local touched = (P.state.tree_ready_known == true and ready ~= true)
  Yso.state.tree_ready = ready
  Yso.tree.state.ready = ready
  Yso.state.tree_touched = touched
  rawset(_G, "tree_ready", ready)
  rawset(_G, "tree_touched", touched)
end

local function _active_writhe_affs()
  local out = {}
  if Yso and Yso.self and type(Yso.self.list_writhe_affs) == "function" then
    local ok, list = pcall(Yso.self.list_writhe_affs)
    if ok and type(list) == "table" then
      for i = 1, #list do
        local key = _trim(list[i]):lower()
        if key ~= "" then out[#out + 1] = key end
      end
      if #out > 0 then return out end
    end
  end
  if Yso and Yso.self and type(Yso.self.is_writhed) == "function" and Yso.self.is_writhed() == true then
    out[#out + 1] = "writhe"
  end
  return out
end

local function _is_touch_tree_cmd(cmd)
  cmd = _trim(cmd):lower()
  if cmd == "" then return false end
  if cmd:match("^touch%s+tree$") then return true end
  if cmd:match("^touch%s+tree%s+tattoo$") then return true end
  return false
end

local function _request_authoritative_resync(reason, force)
  local now = _now()
  if force ~= true and (now - (tonumber(P.state.set_last_resync_req_at or 0) or 0)) < 2.0 then
    return false
  end

  if type(send) == "function" then
    _mark_self_send()
    send("curingset list", false)
    send("curing priority list", false)
    P.state.set_last_resync_req_at = now
    P.state.priority_list_requested_at = now
    _echo("authoritative resync requested: " .. tostring(reason or "unknown"))
    return true
  end
  return false
end

local function _mark_set_untrusted(reason)
  local was_untrusted = (P.state.set_untrusted == true)
  local prior_reason = tostring(P.state.set_untrusted_reason or "")
  if P.state.set_untrusted ~= true then
    P.state.set_untrusted = true
    P.state.set_untrusted_since = _now()
    P.state.set_observed_streak = 0
  end
  P.state.set_untrusted_reason = tostring(reason or "set_unknown")
  _request_authoritative_resync(
    P.state.set_untrusted_reason,
    (not was_untrusted) or (prior_reason ~= P.state.set_untrusted_reason)
  )
end

local function _clear_set_untrusted(reason)
  if P.state.set_untrusted ~= true then return end
  P.state.set_untrusted = false
  P.state.set_untrusted_reason = ""
  P.state.set_untrusted_since = 0
  P.state.set_observed_streak = 0
  P.state.set_last_observed = ""
  _echo("set trust restored: " .. tostring(reason or "stable"))
end

local function _send_profile(set_name)
  set_name = _trim(set_name):lower()
  if set_name == "" then return false end

  if _trim(P.state.current_set):lower() == set_name then
    return false
  end

  local C = _adapter_table()
  _mark_self_send()
  P.state.set_expected = set_name
  P.state.set_expected_until = _now() + 3.0
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
  local now = _now()
  local legacy_set = ""
  local global_set = ""
  if Legacy and Legacy.Curing and type(Legacy.Curing.ActiveServerSet) == "string" then
    legacy_set = _trim(Legacy.Curing.ActiveServerSet):lower()
  end
  if type(rawget(_G, "CurrentCureset")) == "string" then
    global_set = _trim(rawget(_G, "CurrentCureset")):lower()
  end

  local disagreement = (legacy_set ~= "" and global_set ~= "" and legacy_set ~= global_set)
  local resolved = legacy_set ~= "" and legacy_set or global_set
  local current = _trim(P.state.current_set):lower()
  local expected = _trim(P.state.set_expected):lower()
  local expected_until = tonumber(P.state.set_expected_until or 0) or 0
  local in_expected_window = (expected ~= "" and now <= expected_until)

  if disagreement then
    local transient_self_sync = false
    if in_expected_window and (legacy_set == expected or global_set == expected) then
      resolved = expected
      transient_self_sync = true
    elseif _is_self_send_window() and current ~= "" and (legacy_set == current or global_set == current) then
      resolved = current
      transient_self_sync = true
    end

    if not transient_self_sync then
      _mark_set_untrusted("set_source_disagree")
      resolved = legacy_set ~= "" and legacy_set or global_set
    end
  elseif resolved == "" then
    _mark_set_untrusted("set_unknown")
  elseif
    not in_expected_window
    and current ~= ""
    and current ~= resolved
  then
    _mark_set_untrusted("external_switch")
  end

  if resolved ~= "" then
    P.state.current_set = resolved
    if resolved == (P.state.set_last_observed or "") then
      P.state.set_observed_streak = (tonumber(P.state.set_observed_streak or 0) or 0) + 1
    else
      P.state.set_last_observed = resolved
      P.state.set_observed_streak = 1
    end
  end

  if expected ~= "" and resolved == expected then
    P.state.set_expected = ""
    P.state.set_expected_until = 0
  end

  if P.state.set_untrusted == true and not disagreement and resolved ~= "" and (P.state.set_observed_streak or 0) >= 2 then
    _clear_set_untrusted("stable_observation")
    _read_baseline_from_legacy(P.cfg.base_set)
  end

  return resolved
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
  P.clear_emergency_dedupe("manual_intervention")
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
  -- Phase-one note: tree adapter currently carries policy mode only.
  -- Cooldown-aware tree command orchestration stays intentionally deferred.
  policy = _trim(policy)
  if policy == "" then return false end
  if P.state.tree_policy == policy then return false end

  local now = _now()
  local min_gap = tonumber(P.cfg.tree_min_gap_s or 4.0) or 4.0
  if now - (tonumber(P.state.last_tree_at or 0) or 0) < min_gap then
    return false
  end

  P.state.tree_policy = policy
  P.state.last_tree_at = now

  if type(raiseEvent) == "function" then
    raiseEvent("yso.curing.tree_policy", policy, overlay)
  end

  return true
end

function P.set_tree_ready(v, source)
  local ready = (v == true)
  local now = _now()
  P.state.tree_ready = ready
  P.state.tree_ready_known = true
  P.state.tree_last_source = tostring(source or "manual")
  if ready then
    P.state.tree_last_ready_at = now
  end
  _sync_tree_compat_mirrors()
  if type(raiseEvent) == "function" then
    raiseEvent("yso.curing.tree_state", ready, P.state.tree_last_source)
  end
  return true
end

function P.set_tree_touched(v, source)
  if v == true then
    return P.set_tree_ready(false, source or "compat:set_tree_touched")
  end
  return false
end

function P.note_tree_attempt(source)
  return P.set_tree_ready(false, source or "tree_attempt")
end

function P.note_tree_unchanged(source)
  if type(raiseEvent) == "function" then
    raiseEvent("yso.curing.tree_unchanged", tostring(source or "tree_unchanged"))
  end
  return true
end

function P.tree_touch_blocked_reason(cmd)
  if _is_touch_tree_cmd(cmd) then
    return "tree_state_only", {}
  end
  return nil, {}
end

function P.tree_ready()
  return P.state.tree_ready == true
end

function P.tree_touched()
  if P.state.tree_ready_known ~= true then return false end
  return P.state.tree_ready ~= true
end

function P.queue_emergency(cmd, opts)
  opts = opts or {}
  cmd = _trim(cmd)
  if cmd == "" then return false, "empty" end
  if _manual_grace_active() then return false, "manual_grace" end

  if _is_touch_tree_cmd(cmd) then
    return false, "tree_state_only"
  end

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

function P.clear_emergency_dedupe(reason)
  P.state.queue_recent = {}
  if type(raiseEvent) == "function" then
    raiseEvent("yso.curing.queue_dedupe_cleared", tostring(reason or "manual"))
  end
  return true
end

function P.resync(reason)
  reason = tostring(reason or "resync")
  _request_authoritative_resync("resync:" .. reason)
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
  if P.state.set_untrusted == true then
    return true, "set_untrusted"
  end

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
  local writhe_affs = _active_writhe_affs()
  return {
    mode = P.state.mode,
    current_set = P.state.current_set,
    set_untrusted = (P.state.set_untrusted == true),
    set_untrusted_reason = P.state.set_untrusted_reason,
    overlay = P.state.active_overlay,
    group_active = (P.state.group_active == true),
    manual_grace = math.max(0, (tonumber(P.state.manual_grace_until or 0) or 0) - _now()),
    aggression_left = math.max(0, (tonumber(P.state.aggression_until or 0) or 0) - _now()),
    tree_policy = P.state.tree_policy,
    tree_ready = (P.state.tree_ready == true),
    tree_ready_known = (P.state.tree_ready_known == true),
    writhe_blocked = (#writhe_affs > 0),
    writhe_affs = writhe_affs,
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
      local cmd = _trim(command)
      if cmd == "" then return end
      if _is_self_send_window() then return end
      P.note_manual_intervention("sysDataSendRequest")
    end)

    _kill_eh(P._eh.tree_ready_evt)
    P._eh.tree_ready_evt = registerAnonymousEventHandler("yso.tree.ready", function(_, v)
      P.set_tree_ready(v ~= false, "event:yso.tree.ready")
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

    _kill_tr(P._tr.queue_cleared)
    P._tr.queue_cleared = tempRegexTrigger([[^You clear your \w+ queue\.$]], function()
      P.clear_emergency_dedupe("text_ack:queue_clear")
    end)

    _kill_tr(P._tr.tree_touch_line)
    P._tr.tree_touch_line = tempRegexTrigger([[^You touch the tree of life tattoo\.$]], function()
      P.set_tree_ready(false, "text_ack:tree_touch")
    end)

    _kill_tr(P._tr.tree_ready_line)
    P._tr.tree_ready_line = tempRegexTrigger([[^You may utilise the tree tattoo again\.$]], function()
      P.set_tree_ready(true, "text_ack:tree_ready")
    end)

    _kill_tr(P._tr.tree_unchanged)
    P._tr.tree_unchanged = tempRegexTrigger(
      [[^Your tree of life tattoo glows faintly for a moment then fades, leaving you unchanged\.$]],
      function()
        P.note_tree_unchanged("text_ack:tree_unchanged")
      end
    )
  end

  P._hooks_installed = true
  return true
end

function P.init()
  _sync_tree_compat_mirrors()
  _read_current_set()
  _read_baseline_from_legacy(P.cfg.base_set)
  P.install_hooks()
  P.resync("init")
  return true
end

P.init()

return P
