--Group damage offense logic
--========================================================--
-- group_damage.lua  (Achaea / Occultist / Yso)
--  * Group damage automation (party / team damage):
--      Track: healthleech, sensitivity, clumsiness (core) + slickness (optional fourth)
--      Setup: build/refresh missing core pieces using EQ instills + entity pressure
--      Burst: paired WARP + FIRELORD(healthleech) when healthleech is tracked and both lanes are ready
--
--  * Uses Yso.emit() lane table => lane-table payload transport (default separator: &&)
--  * Payload modes (GLOBAL, via Yso.cfg.payload_mode):
--      - "as_available" semantics are enforced by Yso.queue.commit() lane isolation (wake_lane)
--
--  Requirement (freestyle update):
--    - Freestyle combined payloads are allowed, with one action per lane.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

-- Canonical group damage driver lives here:
Yso.off.oc.group_damage = Yso.off.oc.group_damage or {}
local GD = Yso.off.oc.group_damage
--========================================================--
-- Occultist ENTITY pool (defaulted)
--  * Shared across Occultist offense routes (duel / party / utilities).
--  * The pool is intended to be stable; routes may READ from it, not redefine it.
--========================================================--
Yso.off.oc.entity_pool = Yso.off.oc.entity_pool or {
  rotation = { "worm", "storm", "bubonis", "slime", "sycophant", "bloodleech", "hound", "humbug", "chimera", "firelord" },
}

-- Compatibility aliases (callers may refer to these):
Yso.off.oc.dmg = GD
Yso.off.oc.gd_simple = GD
GD.alias_owned = true

GD.route_contract = GD.route_contract or {
  id = "group_damage",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "bootstrap",
    "required_core_refresh",
    "required_core_application",
    "fallback_support",
    "reserved_burst",
    "passive_pressure_only",
  },
  capabilities = {
    uses_eq = true,
    uses_bal = true,
    uses_entity = true,
    supports_burst = true,
    supports_bootstrap = true,
    needs_target = true,
    uses_primebond_scoring = true,
    shares_defense_break = true,
    shares_anti_tumble = true,
  },
  override_policy = {
    mode = "narrow_global_only",
    allowed = {
      reserved_burst = true,
      target_invalid = true,
      target_slain = true,
      route_off = true,
      pause = true,
      manual_suppression = true,
      target_swap_bootstrap = true,
      defense_break = true,
      anti_tumble = true,
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

do
  local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(GD, GD.route_contract)
  end
end

local function _ER()
  return Yso and Yso.off and Yso.off.oc and Yso.off.oc.entity_registry or nil
end

GD.cfg = GD.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,

  -- No entourage opener in Occultist group damage.
  opener_enable = false,
  opener_cmd = nil,

  -- Route-off cleanup (all loyals, every time), gated by a ready wake.
  off_passive_cmd = "order loyals passive",

  -- Entity pool used by this route when an entity can contribute required/follow-up value.
  entity_rotation = { "worm", "storm", "bubonis", "slime", "sycophant", "bloodleech", "hound", "humbug", "chimera", "firelord" },

  -- Entity duration / refresh policy.
  prefer_storm_clumsiness = true,
  prefer_worm_for_healthleech = true,
  prefer_sycophant_rixil = true,
  avoid_overlap = true,
  worm_duration_s = 20,
  worm_refresh_lead_s = 1.0,
  sycophant_duration_s = 30,
  sycophant_refresh_lead_s = 1.0,

  -- Commit semantics: freestyle combined payload, one action per lane.
  freestyle_isolate_lanes = false,

  -- minimum send throttles (milliseconds)
  dupe_window_ms = 120,
}

-- Lust/Empress reactive rescue automation (anti-tumble + empress pull)
-- CANCELLED by default per project decision (2026-03-01).
GD.cfg.rescue_lust_empress = false  -- CANCELLED per project decision (2026-03-01).


-- Entity pool policy: default + lock to the shared Occultist pool unless explicitly unlocked.
if GD.cfg.lock_entity_pool == nil then GD.cfg.lock_entity_pool = true end
if GD.cfg.lock_entity_pool == true then
  GD.cfg.entity_rotation = (Yso.off.oc.entity_pool and Yso.off.oc.entity_pool.rotation) or GD.cfg.entity_rotation
end

GD.state = GD.state or {
  enabled = false,
  loop_enabled = false,
  timer_id = nil,
  busy = false,
  waiting = { queue = nil, main_lane = nil, at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "" },
  loop_delay = tonumber(GD.cfg.loop_delay or 0.15) or 0.15,
  opener_sent_for = "",
  rr_idx = 0,
  stop_pending = false,
  last_room_id = "",
  last_target = "",
  entity_target = "",
  worm = { target = "", until_t = 0, proc_count = 0, proc_window_until = 0 },
  syc = { target = "", until_t = 0 },
}

-- Anti-tumble / Empress rescue state (Lust+Empress recovery)
GD.state.tumble = GD.state.tumble or { target = "", dir = "", at = 0, until_t = 0, fired = false }
GD.state.empress = GD.state.empress or { pending = false, target = "", dir = "", started_at = 0, last_try = 0, fail_until = 0 }
GD.state.justice_once = GD.state.justice_once or {}
local function _trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function _lc(s) return _trim(s):lower() end
local function _tkey(s) return _lc(s) end

local function _now()
  -- Use canonical clock (seconds, handles getEpoch ms) to keep worm timers sane.
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok,v = pcall(Yso.util.now)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  if type(getEpoch) == "function" then
    local ok,v = pcall(getEpoch)
    v = ok and tonumber(v) or nil
    if v then
      if v > 1e12 then v = v / 1000 end
      return v
    end
  end
  return os.time()
end

-- Worm (Domination: COMMAND WORM) behaves like a ~20s DoT.
-- We gate re-commanding per-target using a simple timer so we don't spam entity balance.
--========================================================--
-- Entity effect duration gates (route-local)
--  * worm:     20s infestation window (fallback: 2nd chew-proc line)
--  * sycophant:30s rixil window
--  * Entities retarget to the current target; duration gates reset on target change.
--========================================================--

local function _worm_reset()
  GD.state.worm = GD.state.worm or { target = "", until_t = 0, proc_count = 0, proc_window_until = 0 }
  GD.state.worm.target, GD.state.worm.until_t, GD.state.worm.proc_count, GD.state.worm.proc_window_until = "", 0, 0, 0
end

local function _worm_is_active(tgt)
  local w = GD.state.worm or {}
  return _tkey(tgt) ~= "" and _tkey(tgt) == _tkey(w.target) and _now() < (w.until_t or 0)
end

local function _worm_mark_used(tgt, dur)
  local w = GD.state.worm or {}
  GD.state.worm = w
  w.target = tgt
  w.until_t = _now() + (dur or GD.cfg.worm_duration_s)
  w.proc_count = 0
  w.proc_window_until = _now() + math.max(5, (dur or GD.cfg.worm_duration_s) + 15)
end

function GD.note_worm_sent(tgt)
  if _tkey(tgt) == "" then return end
  local ER = _ER()
  if ER and type(ER.note_sent) == "function" then pcall(ER.note_sent, "worm", tgt, { source = "gd" }) end
end

local function _worm_should_refresh(tgt)
  if _tkey(tgt) == "" then return false end
  local ER = _ER()
  if ER and type(ER.worm_should_refresh) == "function" then
    local ok, v = pcall(ER.worm_should_refresh, tgt)
    if ok then return v == true end
  end
  local w = GD.state.worm or {}
  if _tkey(w.target) ~= _tkey(tgt) then return true end
  return _now() >= (w.until_t or 0)
end

function GD.note_worm_proc(tgt)
  if _tkey(tgt) == "" then return end
  local ER = _ER()
  if ER and type(ER.note_worm_proc) == "function" then pcall(ER.note_worm_proc, tgt) end
end

-- Runtime trigger for worm chew-proc backup.
GD._trig = GD._trig or {}
if type(tempRegexTrigger) == "function" then
  if GD._trig.worm_chew then killTrigger(GD._trig.worm_chew) end
  GD._trig.worm_chew = tempRegexTrigger(
    [[^Many somethings writhe beneath the skin of (.+), and the sickening sound of chewing can be heard\.$]],
    function()
      local who = matches[2] or ""
      if who ~= "" and GD.note_worm_proc then GD.note_worm_proc(who) end
    end
  )
end

local function _syc_reset()
  GD.state.syc = GD.state.syc or { target = "", until_t = 0 }
  GD.state.syc.target, GD.state.syc.until_t = "", 0
end

local function _syc_is_active(tgt)
  local s = GD.state.syc or {}
  return _tkey(tgt) ~= "" and _tkey(tgt) == _tkey(s.target) and _now() < (s.until_t or 0)
end

local function _syc_mark_used(tgt, dur)
  local s = GD.state.syc or {}
  GD.state.syc = s
  s.target = tgt
  s.until_t = _now() + (dur or GD.cfg.sycophant_duration_s)
end

function GD.note_syc_sent(tgt)
  if _tkey(tgt) == "" then return end
  local ER = _ER()
  if ER and type(ER.note_sent) == "function" then pcall(ER.note_sent, "sycophant", tgt, { source = "gd" }) end
end

local function _syc_should_refresh(tgt)
  if _tkey(tgt) == "" then return false end
  local ER = _ER()
  if ER and type(ER.syc_should_refresh) == "function" then
    local ok, v = pcall(ER.syc_should_refresh, tgt)
    if ok then return v == true end
  end
  local s = GD.state.syc or {}
  return _now() >= (s.until_t or 0)
end

-- Reset duration gates on target change.
local function _reset_entity_gates_on_target_change(tgt)
  local last = GD.state.entity_target or ""
  if _tkey(last) ~= _tkey(tgt) then
    GD.state.entity_target = tgt
    GD.state.rr_idx = 0
    GD.state.opener_sent_for = ""
    local ER = _ER()
    if ER and type(ER.target_swap) == "function" then pcall(ER.target_swap, tgt) end
  end
end

local function _tgt_valid(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return false end
  if type(Yso.target_is_valid) == "function" then
    local ok, v = pcall(Yso.target_is_valid, tgt)
    if ok then return v == true end
  end
  return true
end

local function _set_loyals_hostile(v)
  if not Yso.state then return end
  if type(Yso.state.loyals_hostile) == "function" then
    pcall(Yso.state.loyals_hostile, v)
  else
    Yso.state.loyals_hostile = (v == true)
  end
end

local function _vitals()
  return (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
end

local function _eq_ready()
  if Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then return v == true end
  end
  local v = _vitals()
  local eq = v.eq or v.equilibrium
  return eq == true or tostring(eq or "") == "1"
end

local function _bal_ready()
  if Yso.state and type(Yso.state.bal_ready) == "function" then
    local ok, v = pcall(Yso.state.bal_ready)
    if ok then return v == true end
  end
  local v = _vitals()
  local bal = v.bal or v.balance
  return bal == true or tostring(bal or "") == "1"
end

local function _target()
  if type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok and _trim(v) ~= "" then return _trim(v) end
  end
  local cur = rawget(_G, "target")
  if type(cur) == "string" and _trim(cur) ~= "" then return _trim(cur) end
  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    if type(ak.target) == "string" and _trim(ak.target) ~= "" then return _trim(ak.target) end
    if type(ak.tgt) == "string" and _trim(ak.tgt) ~= "" then return _trim(ak.tgt) end
    if type(ak.Target) == "string" and _trim(ak.Target) ~= "" then return _trim(ak.Target) end
  end
  return ""
end

local function _room_id()
  local g = rawget(_G, "gmcp")
  local info = g and g.Room and g.Room.Info
  if info and info.num ~= nil then return tostring(info.num) end
  if info and info.id ~= nil then return tostring(info.id) end
  return ""
end

local function _worm_active(tgt)
  return not _worm_should_refresh(tgt)
end

local function _worm_mark(tgt, dur)
  local ER = _ER()
  if ER and type(ER.note_sent) == "function" then return pcall(ER.note_sent, "worm", tgt, { source = "mark", dur = dur }) end
  return _worm_mark_used(tgt, dur)
end

local function _syc_mark(tgt, dur)
  local ER = _ER()
  if ER and type(ER.note_sent) == "function" then return pcall(ER.note_sent, "sycophant", tgt, { source = "mark", dur = dur }) end
  return _syc_mark_used(tgt, dur)
end

local function _ent_ready()
  if Yso.state and type(Yso.state.ent_ready) == "function" then
    local ok,v = pcall(Yso.state.ent_ready); if ok then return v==true end
  end
  -- fallback: allow, but lane throttling in Yso.emit / locks should backoff if the server rejects
  return true
end

-- Prefer AK score exports if present, then raw affstrack.score, then Yso.tgt.has_aff
local function _aff_score(aff)
  aff = _lc(aff)
  if aff == "" then return 0 end
  if Yso.oc and Yso.oc.ak and type(Yso.oc.ak.get_aff_score) == "function" then
    local ok,v = pcall(Yso.oc.ak.get_aff_score, aff)
    if ok then return tonumber(v or 0) or 0 end
  end
  if type(affstrack) == "table" and type(affstrack.score) == "table" then
    return tonumber(affstrack.score[aff] or 0) or 0
  end
  local tgt = _target()
  if tgt ~= "" and Yso.tgt and type(Yso.tgt.has_aff) == "function" then
    return Yso.tgt.has_aff(tgt, aff) and 100 or 0
  end
  return 0
end

local function _has_aff(aff) return _aff_score(aff) >= 100 end

local function _ak_speed_is_down()
  local A = rawget(_G, "ak")
  return type(A) == "table" and type(A.defs) == "table" and A.defs.speed == false
end

local function _prone_is_forced()
  return _aff_score("prone") >= 100
end

local function _random_crone_arm(tgt)
  local salt = math.floor((_now() * 1000) + (#_trim(tgt) * 17))
  return ((salt % 2) == 0) and "left arm" or "right arm"
end

local JUSTICE_CONVERSION_AFFS = {
  "paralysis", "sensitivity", "healthleech",
  "haemophilia", "weariness", "asthma", "clumsiness",
}

local function _justice_conversion_count()
  local n = 0
  for i = 1, #JUSTICE_CONVERSION_AFFS do
    if _aff_score(JUSTICE_CONVERSION_AFFS[i]) >= 100 then
      n = n + 1
    end
  end
  return n
end

local function _justice_already_sent(tgt)
  local k = _lc(tgt)
  return k ~= "" and GD.state and GD.state.justice_once and GD.state.justice_once[k] == true
end

local function _mark_justice_sent(tgt)
  local k = _lc(tgt)
  if k == "" then return end
  GD.state.justice_once = GD.state.justice_once or {}
  GD.state.justice_once[k] = true
end

local function _payload_mode()
  if type(Yso.get_payload_mode)=="function" then return Yso.get_payload_mode() end
  return tostring((Yso.cfg and Yso.cfg.payload_mode) or "as_available")
end

local function _echo(msg)
  if GD.cfg.echo and type(cecho) == "function" then
    -- NOTE: avoid "\\n" escape sequences; use a literal LF via string.char(10).
    cecho(string.format("<orange>[Yso:GD] <reset>%s%s", tostring(msg), string.char(10)))
  end
end

local function _command_sep()
  local sep = _trim((Yso and (Yso.sep or (Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep)))) or "&&")
  if sep == "" then sep = "&&" end
  return sep
end

local function _safe_send(cmd)
  cmd = _trim(cmd)
  if cmd == "" or type(send) ~= "function" then return false, "send_unavailable" end
  local ok, err = pcall(send, cmd, false)
  if not ok then return false, err end
  return true
end

local function _set_loop_enabled(on)
  local enabled = (on == true)
  GD.state.enabled = enabled
  GD.state.loop_enabled = enabled
  GD.loop_enabled = enabled
  GD.cfg.enabled = enabled
  GD.state.loop_delay = tonumber(GD.state.loop_delay or GD.cfg.loop_delay or 0.15) or 0.15
  GD.state.waiting = GD.state.waiting or { queue = nil, main_lane = nil, at = 0 }
  GD.state.last_attack = GD.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "" }
  return enabled
end

local function _clear_waiting()
  GD.state.waiting = GD.state.waiting or {}
  GD.state.waiting.queue = nil
  GD.state.waiting.main_lane = nil
  GD.state.waiting.at = 0
end

local function _remember_attack(cmd, payload)
  local meta = type(payload) == "table" and (payload.meta or {}) or {}
  local main_lane = _lc(meta.main_lane or "")
  GD.state.last_attack = GD.state.last_attack or {}
  GD.state.last_attack.cmd = _trim(cmd)
  GD.state.last_attack.at = _now()
  GD.state.last_attack.target = _trim(type(payload) == "table" and payload.target or "")
  GD.state.last_attack.main_lane = main_lane
  GD.state.waiting = GD.state.waiting or {}
  GD.state.waiting.queue = GD.state.last_attack.cmd
  GD.state.waiting.main_lane = main_lane
  GD.state.waiting.at = GD.state.last_attack.at
end

local function _waiting_blocks_tick()
  local wait = GD.state.waiting or {}
  local queued = _trim(wait.queue)
  if queued == "" then return false end
  if (_now() - (tonumber(wait.at) or 0)) >= 3.0 then
    _clear_waiting()
    return false
  end

  local lane = _lc(wait.main_lane or "")
  if lane == "eq" then
    if _eq_ready() then _clear_waiting(); return false end
    return true
  end
  if lane == "bal" then
    if _bal_ready() then _clear_waiting(); return false end
    return true
  end
  if lane == "entity" or lane == "class" then
    if _ent_ready() then _clear_waiting(); return false end
    return true
  end

  _clear_waiting()
  return false
end

local function _same_attack_is_hot(cmd)
  cmd = _trim(cmd)
  if cmd == "" then return false end
  local last = GD.state.last_attack or {}
  if _trim(last.cmd) ~= cmd then return false end
  local hot_window = math.max(0.10, (tonumber(GD.state.loop_delay or GD.cfg.loop_delay or 0.15) or 0.15) * 0.75)
  return (_now() - (tonumber(last.at) or 0)) < hot_window
end

local function _eq_lane_score(cat)
  cat = tostring(cat or "")
  if cat == "anti_tumble" then return 120 end
  return 30
end

local function _bal_lane_score(cat)
  cat = tostring(cat or "")
  if cat == "anti_tumble" then return 118 end
  return 12
end

local function _choose_main_lane(eq_cmd, eq_cat, bal_cmd, bal_cat)
  local pick_eq = { lane = "eq", cmd = eq_cmd, category = eq_cat, score = _eq_lane_score(eq_cat) }
  local pick_bal = { lane = "bal", cmd = bal_cmd, category = bal_cat, score = _bal_lane_score(bal_cat) }

  if _trim(eq_cmd) == "" and _trim(bal_cmd) == "" then
    return { lane = "", cmd = nil, category = nil, score = 0, alt = nil }
  end
  if _trim(eq_cmd) == "" then
    return { lane = pick_bal.lane, cmd = pick_bal.cmd, category = pick_bal.category, score = pick_bal.score, alt = nil }
  end
  if _trim(bal_cmd) == "" then
    return { lane = pick_eq.lane, cmd = pick_eq.cmd, category = pick_eq.category, score = pick_eq.score, alt = nil }
  end

  if pick_bal.score > pick_eq.score then
    pick_bal.alt = pick_eq
    return pick_bal
  end

  pick_eq.alt = pick_bal
  return pick_eq
end

local function _payload_line(payload)
  if type(payload) ~= "table" or type(payload.lanes) ~= "table" then return "" end
  local lanes = payload.lanes
  local cmds = {}
  if _trim(lanes.free) ~= "" then cmds[#cmds + 1] = _trim(lanes.free) end
  if _trim(lanes.eq) ~= "" then cmds[#cmds + 1] = _trim(lanes.eq) end
  if _trim(lanes.bal) ~= "" then cmds[#cmds + 1] = _trim(lanes.bal) end
  local entity_cmd = _trim(lanes.entity or lanes.class)
  if entity_cmd ~= "" then cmds[#cmds + 1] = entity_cmd end
  return table.concat(cmds, _command_sep())
end

------------------------------------------------------------
-- Opener helper disabled for this route
-- NOTE: retained as no-op helpers for compatibility.
------------------------------------------------------------
local function _want_opener(tgt)
  return nil
end

local function _mark_opener_sent(tgt)
  return nil
end


------------------------------------------------------------
-- Route helpers
------------------------------------------------------------
local function _core_state()
  local st = {
    healthleech = _has_aff("healthleech"),
    sensitivity = _has_aff("sensitivity"),
    clumsiness  = _has_aff("clumsiness"),
    slickness   = _has_aff("slickness"),
    asthma      = _has_aff("asthma"),
    aeon        = _has_aff("aeon"),
    entangled   = _has_aff("entangled"),
  }
  local n = 0
  if st.healthleech then n = n + 1 end
  if st.sensitivity then n = n + 1 end
  if st.clumsiness then n = n + 1 end
  st.count = n
  return st
end

local function _count_core_affs()
  return _core_state().count
end

local function _cmd_entity(ent, tgt, extra)
  ent = tostring(ent or ""):lower()
  tgt = tostring(tgt or "")
  if ent == "" or tgt == "" then return nil end
  if ent == "firelord" and extra and extra ~= "" then
    return ("command %s at %s %s"):format(ent, tgt, extra)
  end
  return ("command %s at %s"):format(ent, tgt)
end


local function _primebonded(ent)
  local ER = _ER()
  if ER and type(ER.is_primebonded) == "function" then
    local ok, v = pcall(ER.is_primebonded, ent)
    if ok then return v == true end
  end
  return false
end

local function _entity_pick(tgt, st, category, opts)
  local ER = _ER()
  if not (ER and type(ER.pick) == "function") then return nil, nil, nil end
  opts = opts or {}
  local ctx = {
    route = "group_damage",
    target = tgt,
    target_valid = _tgt_valid(tgt),
    ent_ready = _ent_ready(),
    eq_ready = _eq_ready(),
    bal_ready = _bal_ready(),
    has_aff = _has_aff,
    route_state = st,
    category = category,
    need = {
      healthleech = opts.need_healthleech == true,
      sensitivity = opts.need_sensitivity == true,
      clumsiness = opts.need_clumsiness == true,
      slickness = opts.need_slickness == true,
      addiction = opts.need_addiction == true,
    },
  }
  local cand, dbg = ER.pick(ctx)
  GD.state.last_entity_debug = dbg
  if not cand then return nil, category, dbg end
  return cand.cmd, cand.category or category, dbg
end

local function _pick_entity_cmd(tgt, st, opts)
  opts = opts or {}
  if not _ent_ready() then return nil, nil end
  return _entity_pick(tgt, st, tostring(opts.category or "fallback_support"), opts)
end

local function _plan_bal_support(tgt, st, eq_cmd, class_cmd, opts)
  opts = opts or {}
  if not _bal_ready() then return nil, nil, nil end
  if eq_cmd or class_cmd then return nil, nil, nil end

  if not st.aeon and _ak_speed_is_down() then
    if _ent_ready() then
      local filler_cmd, filler_category = _pick_entity_cmd(tgt, st, {
        category = "fallback_support",
        need_healthleech = opts.need_healthleech == true,
        need_sensitivity = opts.need_sensitivity == true,
        need_clumsiness = opts.need_clumsiness == true,
        need_slickness = opts.need_slickness == true,
        need_addiction = opts.need_addiction == true,
      })
      if filler_cmd then
        return ("outd aeon&&fling aeon at %s"):format(tgt), filler_cmd, filler_category or "fallback_support"
      end
    end
  elseif not st.entangled and _prone_is_forced() then
    if _ent_ready() then
      return ("outd hangedman&&fling hangedman at %s"):format(tgt),
        ("command crone at %s %s"):format(tgt, _random_crone_arm(tgt)),
        "fallback_support"
    end
  end

  if _justice_conversion_count() >= 2 and not _justice_already_sent(tgt) then
    return ("ruinate justice %s"):format(tgt), nil, nil
  end

  return nil, nil, nil
end

local function _plan_route(tgt)
  local st = _core_state()
  local p = { eq = nil, bal = nil, class = nil, st = st, eq_category = nil, bal_category = nil, class_category = nil }

  local miss_hl = not st.healthleech
  local miss_sens = not st.sensitivity
  local miss_clum = not st.clumsiness
  local miss_slick = not st.slickness
  local need_addiction = _primebonded("humbug") and (not _has_aff("addiction"))

  local ER = _ER()
  local bootstrap_done = true
  if ER and type(ER.bootstrap_done) == "function" then
    local ok, v = pcall(ER.bootstrap_done, tgt, {
      target = tgt,
      target_valid = _tgt_valid(tgt),
      ent_ready = _ent_ready(),
      eq_ready = _eq_ready(),
      has_aff = _has_aff,
      route_state = st,
      need = { healthleech = miss_hl, clumsiness = miss_clum },
    })
    if ok then bootstrap_done = (v == true) end
  end

  local function pick_class(category)
    local cmd, solved = _pick_entity_cmd(tgt, st, {
      category = category,
      need_healthleech = miss_hl,
      need_sensitivity = miss_sens,
      need_clumsiness = miss_clum,
      need_slickness = miss_slick,
      need_addiction = need_addiction,
    })
    if cmd and not p.class then
      p.class = cmd
      p.class_category = solved or category
    end
    return p.class
  end

  local function apply_bal_support()
    local bal_cmd, bal_class_cmd, bal_class_category = _plan_bal_support(tgt, st, p.eq, p.class, {
      need_healthleech = miss_hl,
      need_sensitivity = miss_sens,
      need_clumsiness = miss_clum,
      need_slickness = miss_slick,
      need_addiction = need_addiction,
    })
    if bal_class_cmd and not p.class then
      p.class = bal_class_cmd
      p.class_category = bal_class_category or "fallback_support"
    end
    p.bal = bal_cmd
    if p.bal then p.bal_category = "fallback_support" end
  end

  -- Reserved paired burst is the only category allowed to outrank a dropped core.
  if st.healthleech and _eq_ready() and _ent_ready() then
    local burst_cmd, solved = _pick_entity_cmd(tgt, st, {
      category = "reserved_paired_burst",
      need_healthleech = false,
      need_sensitivity = false,
      need_clumsiness = false,
      need_slickness = miss_slick,
      need_addiction = need_addiction,
    })
    if burst_cmd then
      p.eq = ("warp %s"):format(tgt)
      p.eq_category = "reserved_paired_burst"
      p.class = burst_cmd
      p.class_category = solved or "reserved_paired_burst"
      return p
    end
  end

  if not bootstrap_done then
    pick_class("bootstrap_setup")
  end

  -- Core refresh/application wins after any reserved burst and bootstrap work.
  if miss_sens then
    if _eq_ready() then p.eq = ("instill %s with sensitivity"):format(tgt); p.eq_category = "required_core_refresh" end
    if not p.class then pick_class("required_core_refresh") end
    if not p.class then pick_class("required_core_application") end
    apply_bal_support()
    return p
  end

  if miss_clum then
    if not p.class then pick_class("required_core_refresh") end
    if not p.class then pick_class("required_core_application") end
    if not p.class and _eq_ready() then p.eq = ("instill %s with clumsiness"):format(tgt); p.eq_category = "required_core_refresh" end
    apply_bal_support()
    return p
  end

  if miss_hl then
    if st.count >= 2 and _eq_ready() then
      p.eq = ("warp %s"):format(tgt)
      p.eq_category = "required_core_application"
    elseif _eq_ready() and not _ent_ready() then
      p.eq = ("instill %s with healthleech"):format(tgt)
      p.eq_category = "required_core_application"
    end
    if not p.class then pick_class("required_core_refresh") end
    if not p.class then pick_class("required_core_application") end
    apply_bal_support()
    return p
  end

  -- Full core present: reserve paired burst when EQ is ready; otherwise use support lanes only.
  if st.healthleech and _eq_ready() then
    -- Hold EQ for burst reservation until entity lane can pair with Firelord.
    apply_bal_support()
    return p
  end

  -- Optional support: addiction (primebonded humbug) and general fallback entity pressure.
  if not p.class then pick_class("fallback_support") end
  if not p.class then pick_class("passive_pressure_only") end

  -- Optional slickness is lower than missing-core work, but higher than fallback BAL support when EQ is free.
  if miss_slick and _eq_ready() then
    p.eq = ("instill %s with slickness"):format(tgt)
    p.eq_category = "fallback_support"
  end

  apply_bal_support()
  return p
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------
------------------------------------------------------------
-- Template Contract Facade
--  * Standardized surface matching the Offense Template guidance.
--  * Keeps legacy propose/tick behavior intact while exposing a uniform
--    route API for future routes and tooling.
------------------------------------------------------------
local function _party_damage_context_active()
  local M = Yso and Yso.mode or nil
  if type(M) ~= "table" then return true end

  local is_party = true
  if type(M.is_party) == "function" then
    local ok, v = pcall(M.is_party)
    if ok then is_party = (v == true) end
  else
    is_party = (_lc(M.state or "") == "party")
  end
  if not is_party then return false end

  local route = ""
  if type(M.party_route) == "function" then
    local ok, v = pcall(M.party_route)
    if ok then route = _lc(v or "") end
  elseif M.party then
    route = _lc(M.party.route or "")
  end
  if route == "dmg" then route = "dam" end
  return route == "" or route == "dam"
end

local function _route_is_active()
  if not _party_damage_context_active() then return false end
  if Yso and Yso.mode and type(Yso.mode.route_loop_active) == "function" then
    return Yso.mode.route_loop_active("group_damage") == true
  end
  return GD.state and GD.state.loop_enabled == true
end
local function _automation_allowed()
  return _route_is_active()
end

function GD.init()
  GD.cfg = GD.cfg or {}
  GD.state = GD.state or {}
  GD.state.justice_once = GD.state.justice_once or {}
  GD.state.template = GD.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil, last_target = GD.state.last_target or "" }
  GD.state.waiting = GD.state.waiting or { queue = nil, main_lane = nil, at = 0 }
  GD.state.last_attack = GD.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "" }
  GD.state.busy = (GD.state.busy == true)
  GD.state.loop_delay = tonumber(GD.state.loop_delay or GD.cfg.loop_delay or 0.15) or 0.15
  _set_loop_enabled((GD.state.loop_enabled == true) or (GD.state.enabled == true))
  return true
end
function GD.reset(reason)
  GD.init()
  GD.state.opener_sent_for = ""
  GD.state.rr_idx = 0
  GD.state.stop_pending = false
  GD.state.last_room_id = ""
  GD.state.last_target = ""
  GD.state.entity_target = ""
  GD.state.busy = false
  _clear_waiting()
  GD.state.last_attack = { cmd = "", at = 0, target = "", main_lane = "" }
  GD.state.template.last_reason = tostring(reason or "manual")
  GD.state.template.last_payload = nil
  _worm_reset()
  _syc_reset()
  GD.state.tumble = { target = "", dir = "", at = 0, until_t = 0, fired = false }
  GD.state.empress = { pending = false, target = "", dir = "", started_at = 0, last_try = 0, fail_until = 0 }
  return true
end

function GD.is_enabled()
  return GD.state and GD.state.enabled == true
end

function GD.is_active()
  return _route_is_active()
end

function GD.can_run(ctx)
  GD.init()
  if not GD.is_enabled() then return false, "disabled" end
  if not GD.is_active() then return false, "inactive" end
  if not _automation_allowed() then return false, "policy" end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return false, "paused" end
  local tgt = _trim((ctx and ctx.target) or _target())
  if tgt == "" then return false, "no_target" end
  if not _tgt_valid(tgt) then return false, "invalid_target" end
  return true, tgt
end

local function _attack_opts(arg)
  if type(arg) == "table" and (arg.preview ~= nil or arg.ctx ~= nil) then
    return arg.ctx, (arg.preview == true)
  end
  return arg, false
end

function GD.attack_function(arg)
  local ctx, preview = _attack_opts(arg)
  local ok, info = GD.can_run(ctx)
  if not ok then
    if preview then return nil, info end
    return false, info
  end

  local tgt = info
  local now = (ctx and tonumber(ctx.now)) or _now()
  _reset_entity_gates_on_target_change(tgt)

  local eq_cmd, eq_cat = nil, nil
  local bal_cmd, bal_cat = nil, nil
  local entity_cmd, entity_cat = nil, nil
  local st = _core_state()
  local p = nil
  local rescue = nil

  -- A. Anti-defensive measures on target.
  if GD.cfg.rescue_lust_empress == true then
    local anti = _rescue_antitumble_action(now)
    local empress = _rescue_empress_action(now)
    rescue = anti
    if empress and (not rescue or tonumber(empress.score or 0) > tonumber(rescue.score or 0)) then
      rescue = empress
    end
    if rescue then
      if rescue.qtype == "eq" then
        eq_cmd, eq_cat = rescue.cmd, rescue.category or "anti_tumble"
      elseif rescue.qtype == "bal" then
        bal_cmd, bal_cat = rescue.cmd, rescue.category or "anti_tumble"
      end
    end
  end

  -- B. Defensive measures on me.
  -- No self-defense pre-send branch lives in this route today.

  -- C. Main offensive spam logic.
  if not eq_cmd and not bal_cmd then
    p = _plan_route(tgt)
    if not p then
      if preview then return nil, "no_plan" end
      return false, "no_plan"
    end

    if GD.cfg.avoid_overlap and p.eq and type(p.eq) == "string" then
      local eqlc = p.eq:lower()
      if eqlc:match("^%s*instill%s+") and eqlc:find("with%s+healthleech") then
        local clc = tostring(p.class or ""):lower()
        if clc:find("^%s*command%s+worm") or _worm_active(tgt) then
          p.eq = nil
        end
      end
    end

    eq_cmd, eq_cat = p.eq, p.eq_category
    bal_cmd, bal_cat = p.bal, p.bal_category
    entity_cmd, entity_cat = p.class, p.class_category
    st = p.st or st
  end

  -- D. Offensive conditions / overrides.
  local main = _choose_main_lane(eq_cmd, eq_cat, bal_cmd, bal_cat)
  local selected_eq = (main.lane == "eq") and main.cmd or nil
  local selected_bal = (main.lane == "bal") and main.cmd or nil
  local main_lane = main.lane
  if main_lane == "" and _trim(entity_cmd) ~= "" then
    main_lane = "entity"
  end

  -- E. Misc / bookkeeping / optional echoes.
  local payload = {
    route = "group_damage",
    target = tgt,
    lanes = {
      eq = selected_eq,
      bal = selected_bal,
      entity = entity_cmd,
    },
    meta = {
      eq_category = (main.lane == "eq") and main.category or nil,
      bal_category = (main.lane == "bal") and main.category or nil,
      entity_category = entity_cat,
      core_state = st,
      main_lane = main_lane,
      main_category = main.category,
      alt_lane = main.alt and main.alt.lane or nil,
      alt_category = main.alt and main.alt.category or nil,
      rescue_tag = rescue and rescue.tag or nil,
    },
  }
  GD.state.template.last_payload = payload
  GD.state.template.last_target = tgt

  if not payload.lanes.eq and not payload.lanes.bal and not payload.lanes.entity then
    if preview then return nil, "empty" end
    return false, "empty"
  end

  if preview then
    return payload
  end

  local cmd = _payload_line(payload)
  if _trim(cmd) == "" then return false, "empty" end
  if _same_attack_is_hot(cmd) then return false, "hot_attack" end

  local sent, err = _safe_send(cmd)
  if not sent then return false, err end

  GD.on_sent(payload, ctx)
  _remember_attack(cmd, payload)
  return true, cmd, payload
end

function GD.build_payload(ctx)
  return GD.attack_function({ ctx = ctx, preview = true })
end
function GD.on_sent(payload, ctx)
  GD.init()
  local legacy = payload
  if type(payload) == "table" and payload.lanes then
    legacy = {
      eq = payload.lanes.eq,
      bal = payload.lanes.bal,
      class = payload.lanes.entity,
      free = payload.lanes.free,
    }
  end
  GD.state.template.last_payload = payload
  return GD.on_payload_sent(legacy)
end

function GD.evaluate(ctx)
  local payload, why = GD.build_payload(ctx)
  if not payload then return { ok = false, reason = why } end
  return { ok = true, payload = payload }
end

function GD.explain()
  local st = _core_state()
  return {
    route = "group_damage",
    enabled = GD.is_enabled(),
    active = GD.is_active(),
    target = _target(),
    core = st,
    last_reason = GD.state and GD.state.template and GD.state.template.last_reason or "",
    last_disable_reason = GD.state and GD.state.template and GD.state.template.last_disable_reason or "",
    last_payload = GD.state and GD.state.template and GD.state.template.last_payload or nil,
  }
end

function GD.on_enter(ctx)
  GD.init()
  return true
end

function GD.on_exit(ctx)
  if Yso and Yso.mode and type(Yso.mode.stop_route_loop) == "function" then
    Yso.mode.stop_route_loop("group_damage", "exit", true)
  end
  GD.reset("exit")
  return true
end

function GD.on_target_swap(old_target, new_target)
  if _lc(old_target) ~= _lc(new_target) then
    GD.reset("target_swap")
    GD.state.last_target = _trim(new_target)
    if GD.state.loop_enabled == true then
      GD.schedule_loop(0)
    end
  end
  return true
end

function GD.on_pause(ctx)
  return true
end

function GD.on_resume(ctx)
  if GD.state and GD.state.loop_enabled == true then
    GD.schedule_loop(0)
  end
  return true
end

function GD.on_manual_success(ctx)
  if GD.state and GD.state.loop_enabled == true then
    GD.schedule_loop(GD.state.loop_delay)
  end
  return true
end

function GD.on_send_result(payload, ctx)
  return GD.on_sent(payload, ctx)
end

local function _kill_loop_timer()
  if GD.state and GD.state.timer_id then
    pcall(killTimer, GD.state.timer_id)
    GD.state.timer_id = nil
  end
end

function GD.schedule_loop(delay)
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    return Yso.mode.schedule_route_loop("group_damage", delay)
  end
  return false
end

GD.alias_loop_stop_details = GD.alias_loop_stop_details or {
  inactive = true,
  disabled = true,
  policy = true,
}

function GD.alias_loop_prepare_start(ctx)
  GD.init()
  return ctx or {}
end

function GD.alias_loop_on_started(ctx)
  GD.state.stop_pending = false
  GD.state.busy = false
  _clear_waiting()

  _echo("Group damage loop ON.")
  local tgt = _target()
  if tgt == "" then
    _echo("No target yet; holding.")
  elseif not _tgt_valid(tgt) then
    _echo(string.format("%s is not in room; holding.", tgt))
  end
end

function GD.alias_loop_on_stopped(ctx)
  GD.init()
  ctx = ctx or {}
  local reason = tostring(ctx.reason or "manual")
  GD.state.stop_pending = false

  local passive = _trim(tostring(GD.cfg.off_passive_cmd or "order loyals passive"))
  if passive ~= "" then
    _safe_send(passive)
  end
  _set_loyals_hostile(false)

  if ctx.silent ~= true then
    _echo(string.format("Group damage loop OFF (%s).", reason))
  end
end

function GD.alias_loop_clear_waiting()
  return _clear_waiting()
end

function GD.alias_loop_waiting_blocks()
  return _waiting_blocks_tick()
end

function GD.alias_loop_on_error(err)
  _echo("Group damage loop error: " .. tostring(err))
end
------------------------------------------------------------
-- Anti-tumble / Empress rescue (stateful)
--  * Wired by triggers in yso_offense_coordination.lua:
--      - tumble_begin -> GD.mark_tumble(tgt, dir)
--      - tumble_out   -> GD.mark_tumble_out(tgt, DIRU)
--  * Wired by Tarot triggers:
--      - Empress fail  -> GD.mark_empress_fail()
--      - Lust success  -> GD.mark_lust_landed(tgt)
------------------------------------------------------------
local function _tgt_present(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return false end
  if Yso and Yso.room and type(Yso.room.has) == "function" then
    local ok, v = pcall(Yso.room.has, tgt)
    if ok then return v == true end
  end
  if type(Yso.target_is_valid) == "function" then
    local ok, v = pcall(Yso.target_is_valid, tgt)
    if ok then return v == true end
  end
  return false
end

local function _emit_lane(lane, cmd, reason)
  cmd = _trim(cmd)
  if cmd == "" then return false end
  local ok = _safe_send(cmd)
  return ok == true
end

function GD.mark_tumble(tgt, dir)
  tgt = _trim(tgt); dir = _trim(dir)
  if tgt == "" then return end
  local now = _now()
  local T = GD.state.tumble
  T.target  = tgt
  T.dir     = dir
  T.at      = now
  T.until_t = now + 0.75
  T.fired   = false
  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    Yso.pulse.wake("gd:tumble_begin")
  end
end

function GD.mark_tumble_out(tgt, diru)
  tgt = _trim(tgt); diru = _trim(diru)
  if tgt == "" then return end
  GD.mark_tumble(tgt, diru)
  local now = _now()
  local E = GD.state.empress
  E.pending    = true
  E.target     = tgt
  E.dir        = diru
  E.started_at = now
  -- don't clear fail_until here: if we just failed empress, keep the backoff
  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    Yso.pulse.wake("gd:tumble_out")
  end
end

function GD.mark_empress_fail()
  local now = _now()
  local E = GD.state.empress
  E.fail_until = now + 10.0
  -- keep pending true so we retry after backoff (once Lust lands)
  if GD.cfg.echo then _echo("Empress failed: backing off 10s (need Lust).") end
end

function GD.mark_lust_landed(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return end
  local E = GD.state.empress
  if E.pending and _lc(E.target) == _lc(tgt) then
    E.fail_until = 0
    if Yso.pulse and type(Yso.pulse.wake) == "function" then
      Yso.pulse.wake("gd:lust_landed")
    end
  end
end

local function _maybe_antitumble(now)
  local T = GD.state.tumble
  if T.target == "" then return false end
  if now > (tonumber(T.until_t) or 0) then
    T.target = ""; T.dir = ""; T.fired = false
    return false
  end
  if T.fired then return false end

  -- Prefer reacting for current target only (prevents stale target spam).
  local tgt = _target()
  if tgt == "" or _lc(tgt) ~= _lc(T.target) then return false end

  -- SM dominate is EQ lane; Lust is BAL lane.
  local sm_ready = false
  if Yso and type(Yso.soulmaster_ready) == "function" then
    local ok,v = pcall(Yso.soulmaster_ready); if ok then sm_ready = (v == true) end
  else
    sm_ready = (rawget(_G, "soulmaster_ready") == true)
  end

  if sm_ready and Yso and Yso.occ and type(Yso.occ.sm_cmd_tumble) == "function" then
    if not _eq_ready() then return false end
    local ok,cmd = pcall(Yso.occ.sm_cmd_tumble, tgt, T.dir)
    cmd = _trim(ok and cmd or "")
    if cmd ~= "" then
      _echo(("%s TUMBLE BEGIN -> Soulmaster dominate (anti-tumble)"):format(tgt))
      if _emit_lane("eq", cmd, "gd:antitumble") then
        T.fired = true
        return true
      end
    end
  end

  -- fallback: Lust
  if not _bal_ready() then return false end
  _echo(("%s TUMBLE BEGIN -> Lust (SM not ready/usable)"):format(tgt))
  if _emit_lane("bal", ("fling lust at %s"):format(tgt), "gd:antitumble") then
    T.fired = true
    return true
  end
  return false
end

local function _maybe_empress(now)
  local E = GD.state.empress
  if not E.pending then return false end

  local tgt = _trim(E.target)
  if tgt == "" then E.pending = false; return false end

  -- Clear pending if target is already back in the room.
  if _tgt_present(tgt) then
    E.pending = false
    return false
  end

  -- Hard timeout (don't keep this pending forever if presence tracking is missing).
  if E.started_at ~= 0 and (now - (tonumber(E.started_at) or 0)) > 15.0 then
    E.pending = false
    return false
  end

  if now < (tonumber(E.fail_until) or 0) then return false end
  if not _bal_ready() then return false end

  if (now - (tonumber(E.last_try) or 0)) < 0.9 then return false end
  E.last_try = now

  _echo(("%s TUMBLED OUT -> Empress pull (%s)"):format(tgt, tostring(E.dir or "?")))
  return (_safe_send(("outd empress%sfling empress %s"):format(_command_sep(), tgt)) == true)
end

local function _rescue_antitumble_action(now)
  if GD.cfg.rescue_lust_empress ~= true then return nil end

  local T = GD.state.tumble
  if T.target == "" then return nil end
  if now > (tonumber(T.until_t) or 0) then
    T.target = ""; T.dir = ""; T.fired = false
    return nil
  end
  if T.fired then return nil end

  local tgt = _target()
  if tgt == "" or _lc(tgt) ~= _lc(T.target) then return nil end

  local sm_ready = false
  if Yso and type(Yso.soulmaster_ready) == "function" then
    local ok, v = pcall(Yso.soulmaster_ready)
    if ok then sm_ready = (v == true) end
  else
    sm_ready = (rawget(_G, "soulmaster_ready") == true)
  end

  if sm_ready and Yso and Yso.occ and type(Yso.occ.sm_cmd_tumble) == "function" and _eq_ready() then
    local ok, cmd = pcall(Yso.occ.sm_cmd_tumble, tgt, T.dir)
    cmd = _trim(ok and cmd or "")
    if cmd ~= "" then
      return {
        cmd = cmd,
        qtype = "eq",
        kind = "offense",
        score = 120,
        tag = "gd:anti:eq:" .. _lc(tgt) .. ":" .. _lc(T.dir),
        category = "anti_tumble",
        lockout = 0.75,
      }
    end
  end

  if not _bal_ready() then return nil end
  return {
    cmd = ("fling lust at %s"):format(tgt),
    qtype = "bal",
    kind = "offense",
    score = 118,
    tag = "gd:anti:bal:" .. _lc(tgt) .. ":" .. _lc(T.dir),
    category = "anti_tumble",
    lockout = 0.75,
  }
end

local function _rescue_empress_action(now)
  if GD.cfg.rescue_lust_empress ~= true then return nil end

  local E = GD.state.empress
  if not E.pending then return nil end

  local tgt = _trim(E.target)
  if tgt == "" then E.pending = false; return nil end
  if _tgt_present(tgt) then E.pending = false; return nil end
  if E.started_at ~= 0 and (now - (tonumber(E.started_at) or 0)) > 15.0 then
    E.pending = false
    return nil
  end
  if now < (tonumber(E.fail_until) or 0) then return nil end
  if not _bal_ready() then return nil end
  if (now - (tonumber(E.last_try) or 0)) < 0.9 then return nil end

  return {
    cmd = ("outd empress&&fling empress %s"):format(tgt),
    qtype = "bal",
    kind = "offense",
    score = 116,
    tag = "gd:empress:" .. _lc(tgt) .. ":" .. _lc(E.dir),
    category = "anti_tumble",
    lockout = 0.9,
    no_repeat = false,
  }
end
-- Main tick
------------------------------------------------------------
function GD.tick(reasons)
  -- Alias-owned loop is the primary automated driver for this route.
  return false
end


-- =========================================================
-- Commit hook (called from Yso.locks.note_payload)
-- Used for per-target timers that must only latch on *actual* send.
-- =========================================================
local function _payload_contains_cmd(payload, lane, cmd)
  if type(payload) ~= "table" then return false end
  local row = payload[lane]
  if row == nil then return false end
  if type(row) == "string" then return row == cmd end
  if type(row) == "table" then
    for i=1,#row do
      if row[i] == cmd then return true end
    end
  end
  return false
end

local function _mark_justice_payload(payload)
  local function note(cmd)
    cmd = _trim(cmd)
    local tgt = cmd:match("^ruinate%s+justice%s+(.+)$")
    if tgt and tgt ~= "" then
      _mark_justice_sent(tgt)
    end
  end

  local bal = payload.bal
  if type(bal) == "string" then
    note(bal)
  elseif type(bal) == "table" then
    for i = 1, #bal do
      note(bal[i])
    end
  end
end

function GD.on_payload_sent(payload)
  if type(payload) ~= "table" then return end
  _mark_justice_payload(payload)

  -- OFF-cleanup bookkeeping: if we successfully sent the passive command, finalize shutdown.
  if GD.state.stop_pending then
    local want = tostring(GD.cfg.off_passive_cmd or "order loyals passive")
    local free = payload.free
    local ok = false
    if type(free) == "string" then
      ok = (free == want)
    elseif type(free) == "table" then
      for i=1,#free do if free[i] == want then ok = true; break end end
    end

    if ok then
      _set_loyals_hostile(false)
      GD.state.stop_pending = false
      GD.state.enabled = false
      GD.state.opener_sent_for = ""
      GD.state.last_room_id = ""
      GD.state.last_target = ""
      _echo("Group damage OFF. loyals passive.")
    end
  end

  local now = _now()
  local T = GD.state and GD.state.tumble or nil
  if type(T) == "table" and T.target ~= "" and T.fired ~= true then
    local lust_cmd = ("fling lust at %s"):format(T.target)
    if _payload_contains_cmd(payload, "bal", lust_cmd) then
      T.fired = true
    elseif Yso and Yso.occ and type(Yso.occ.sm_cmd_tumble) == "function" then
      local ok, cmd = pcall(Yso.occ.sm_cmd_tumble, T.target, T.dir)
      cmd = _trim(ok and cmd or "")
      if cmd ~= "" and _payload_contains_cmd(payload, "eq", cmd) then
        T.fired = true
      end
    end
  end

  local E = GD.state and GD.state.empress or nil
  if type(E) == "table" and E.pending then
    local empress_cmd = ("outd empress&&fling empress %s"):format(_trim(E.target))
    if _payload_contains_cmd(payload, "bal", empress_cmd) then
      E.last_try = now
    end
  end

  -- Opener sent bookkeeping (best-effort).
  local pend = GD.state and GD.state._pending_opener
  if pend and type(pend) == "table" and pend.cmd and pend.tkey then
    local free = payload.free
    local sent = false
    if type(free) == "string" then
      sent = (free == pend.cmd)
    elseif type(free) == "table" then
      for i=1,#free do if free[i] == pend.cmd then sent = true; break end end
    end
    if sent then
      _mark_opener_sent(pend.tkey)
      GD.state._pending_opener = nil
    end
  end
end

-- Mudlet/party-mode friendly surface:
function GD.status()
  local tgt = _target()
  local st = _core_state()
  local snapshot = {
    route = "group_damage",
    enabled = tostring(GD.state and GD.state.loop_enabled == true),
    active = tostring(GD.is_active()),
    target = tostring(tgt),
    core_count = st.count,
    healthleech = st.healthleech,
    sensitivity = st.sensitivity,
    clumsiness = st.clumsiness,
    slickness = st.slickness,
    addiction = _has_aff("addiction"),
    last_reason = GD.state and GD.state.template and GD.state.template.last_reason or "",
    last_disable_reason = GD.state and GD.state.template and GD.state.template.last_disable_reason or "",
  }
  _echo(string.format("loop=%s active=%s target=%s core=%d/3 (hl=%s sens=%s clumsy=%s slick=%s addiction=%s)",
    snapshot.enabled, snapshot.active, snapshot.target, snapshot.core_count,
    tostring(snapshot.healthleech), tostring(snapshot.sensitivity), tostring(snapshot.clumsiness), tostring(snapshot.slickness), tostring(snapshot.addiction)
  ))
  return snapshot
end



