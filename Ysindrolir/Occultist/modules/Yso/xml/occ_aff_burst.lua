--========================================================--
-- occ_aff_burst.lua
--  * Combat-mode duel affliction burst route for Occultist.
--  * Owns the mana-bury -> cleanseaura -> truename -> WM -> mentals ->
--    enlighten -> speed strip -> utter -> unravel sequence.
--  * Firelord intentionally omitted in this pass.
--  * Alias-controlled loop ownership now lives in the shared mode controller.
--    This route keeps payload/propose logic plus route-specific lifecycle hooks.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

Yso.off.oc.occ_aff_burst = Yso.off.oc.occ_aff_burst or {}
local AB = Yso.off.oc.occ_aff_burst
AB.alias_owned = true

-- Shared cleanseaura planner surface. Limb-side remains available as a namespace;
-- this pass adds the affliction / mana-burst branch used by combat-mode dueling.
Yso.off.oc.cleanseaura = Yso.off.oc.cleanseaura or {}
local CS = Yso.off.oc.cleanseaura
local AP = Yso.off.oc.aura_planner or {}

AB.route_contract = AB.route_contract or {
  id = "occ_aff_burst",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "mana_bury",
    "cleanseaura_window",
    "truename_acquire",
    "mental_build",
    "enlighten_gate",
    "speed_strip_window",
    "reserved_burst",
  },
  capabilities = {
    uses_eq = true,
    uses_bal = true,
    uses_entity = true,
    supports_burst = true,
    supports_bootstrap = true,
    needs_target = true,
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

AB.cfg = AB.cfg or {
  enabled = false,
  echo = true,
  loop_delay = 0.15,

  mana_burst_pct = 40,
  mental_target = 5,
  enlighten_target = 5,
  mental_pressure_threshold = 3,
  loyals_on_cmd = "order entourage kill %s",
  off_passive_cmd = "order loyals passive",

  aura_ttl_s = 20,
  readaura_requery_s = 8,
  predict_bias_threshold = 0.60,
  speed_hold_s = 3.2,
  utter_follow_s = 5.0,

  cleanseaura_lockout_s = 4.1,
  pinchaura_lockout_s = 4.1,
  readaura_lockout_s = 1.0,
  shieldbreak_lockout_s = 1.0,
  attend_lockout_s = 2.3,
  unnamable_lockout_s = 30.0,
  unnamable_attend_debounce_s = 3.5,
  truename_branch_stability_pulses = 2,
  eq_retry_cooldown_s = 1.2,
  para_entity_cd_s = 6.0,
  para_eq_cd_s = 3.5,
  para_recent_apply_s = 3.5,
  para_recent_cure_s = 2.5,
  para_override_threshold = 0.75,
  para_bm_override_threshold = 0.65,
  para_require_asthma = true,
  bm_snapshot_ttl_s = 24.0,
  bm_snapshot_carry_ttl_s = 30.0,
  bm_shield_ttl_s = 8.0,
  debug_screen_interval_s = 1.0,
}

local function _offense_state()
  return Yso and Yso.off and Yso.off.state or nil
end

AB.state = AB.state or {
  enabled = (AB.cfg.enabled ~= false),
  loop_enabled = (AB.cfg.enabled ~= false),
  timer_id = nil,
  busy = false,
  waiting = { queue = nil, main_lane = nil, lanes = nil, at = 0 },
  last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil },
  loop_delay = tonumber(AB.cfg.loop_delay or 0.15) or 0.15,
  last_target = "",
  explain = {},
  resume_checkpoint = "mana_bury",
  resume_checkpoint_at = 0,
  truename_entry_stable_pulses = 0,
  loyals_sent_for = "",
  predict_bootstrapped = false,
  last_invalid_echo_at = 0,
  self_gate = {
    retry_until = 0,
    not_standing_until = 0,
    arms_until = 0,
    bound_until = 0,
    last_failure_line = "",
  },
  pending_free = {},
  targets = {},
}
AB.debug = AB.debug or {
  enabled = false,
  last_render_at = 0,
  last_text = "",
}
local _mana_bury_ready
local _focus_lock_count
local _focus_lock_chimera_desired
CS.cfg = CS.cfg or {
  mana_burst_pct = tonumber(AB.cfg.mana_burst_pct or 40) or 40,
}

local function _trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function _lc(s) return _trim(s):lower() end
local function _push_unique(tbl, value)
  if type(tbl) ~= "table" then return end
  value = tostring(value or "")
  if value == "" then return end
  for i = 1, #tbl do
    if tbl[i] == value then return end
  end
  tbl[#tbl + 1] = value
end
local _entity_aff_cmd

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

local function _clock(v)
  v = tonumber(v)
  if not v then return 0 end
  if v > 20000000000 then v = v / 1000 end
  return v
end

local function _same_target(a, b)
  a = _lc(a)
  b = _lc(b)
  return a ~= "" and a == b
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
  end
  return ""
end

local function _eq_ready()
  if Yso and Yso.locks and type(Yso.locks.eq_ready) == "function" then
    local ok, v = pcall(Yso.locks.eq_ready)
    if ok then return v == true end
  end
  if Yso and Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then return v == true end
  end
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(v.eq or v.equilibrium or "") == "1" or (v.eq == true or v.equilibrium == true)
end

local function _bal_ready()
  if Yso and Yso.locks and type(Yso.locks.bal_ready) == "function" then
    local ok, v = pcall(Yso.locks.bal_ready)
    if ok then return v == true end
  end
  if Yso and Yso.state and type(Yso.state.bal_ready) == "function" then
    local ok, v = pcall(Yso.state.bal_ready)
    if ok then return v == true end
  end
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(v.bal or v.balance or "") == "1" or (v.bal == true or v.balance == true)
end

local function _ent_ready()
  if Yso and Yso.locks and type(Yso.locks.ent_ready) == "function" then
    local ok, v = pcall(Yso.locks.ent_ready)
    if ok then return v == true end
  end
  if Yso and Yso.state and type(Yso.state.ent_ready) == "function" then
    local ok, v = pcall(Yso.state.ent_ready)
    if ok then return v == true end
  end
  return true
end

local function _truebook_can_utter(tgt)
  local TB = Yso and Yso.occ and Yso.occ.truebook or nil
  if TB and type(TB.can_utter) == "function" then
    local ok, v = pcall(TB.can_utter, tgt)
    if ok then return v == true end
  end
  return false
end

local function _aff_score(tgt, aff)
  aff = tostring(aff or "")
  if aff == "" then return 0 end

  if Yso and Yso.oc and Yso.oc.ak and type(Yso.oc.ak.get_aff_score) == "function" then
    local ok, v = pcall(Yso.oc.ak.get_aff_score, aff)
    if ok and tonumber(v) then return tonumber(v) end
  end

  local A = rawget(_G, "affstrack")
  if type(A) == "table" then
    if type(A.score) == "table" and tonumber(A.score[aff]) then return tonumber(A.score[aff]) end
    local row = A[aff]
    if type(row) == "table" and tonumber(row.score) then return tonumber(row.score) end
  end

  if tgt ~= "" and Yso and Yso.tgt and type(Yso.tgt.has_aff) == "function" then
    local ok, v = pcall(Yso.tgt.has_aff, tgt, aff)
    if ok and v == true then return 100 end
  end

  return 0
end

local function _has_aff(tgt, aff)
  return _aff_score(tgt, aff) >= 100
end

local function _mental_score()
  if Yso and Yso.oc and Yso.oc.ak and Yso.oc.ak.scores and type(Yso.oc.ak.scores.mental) == "function" then
    local ok, v = pcall(Yso.oc.ak.scores.mental)
    if ok and tonumber(v) then return tonumber(v) end
  end
  local A = rawget(_G, "affstrack")
  return (type(A) == "table" and tonumber(A.mentalscore)) or 0
end

local function _enlighten_score()
  if Yso and Yso.oc and Yso.oc.ak and Yso.oc.ak.scores and type(Yso.oc.ak.scores.enlighten) == "function" then
    local ok, v = pcall(Yso.oc.ak.scores.enlighten)
    if ok and tonumber(v) then return tonumber(v) end
  end
  local A = rawget(_G, "affstrack")
  return (type(A) == "table" and tonumber(A.enlightenscore)) or 0
end

local function _has_any_required_insanity(tgt)
  local list = {
    "dementia","stupidity","confusion","hypersomnia","paranoia","hallucinations",
    "impatience","addiction","agoraphobia","lovers","loneliness","recklessness","masochism"
  }
  for i = 1, #list do
    if _has_aff(tgt, list[i]) then return true end
  end
  return false
end

-- _snapshot() moved to occ_aura_planner.lua

local function _target_meta(tgt)
  if tgt == "" or not (Yso and Yso.tgt and type(Yso.tgt.get) == "function") then return {} end
  local ok, row = pcall(Yso.tgt.get, tgt)
  if ok and type(row) == "table" and type(row.meta) == "table" then
    return row.meta
  end
  return {}
end

local function _normalize_class_name(cls)
  cls = _trim(cls)
  if cls == "" or _lc(cls) == "unknown" then return "" end
  return cls:sub(1, 1):upper() .. cls:sub(2):lower()
end

local function _target_class_info(tgt)
  local out = { class = "", known = false, source = "" }
  tgt = _trim(tgt)
  if tgt == "" then return out end
  local providers = {
    { rawget(_G, "ndba"), "ndba" },
    { rawget(_G, "ndb"), "ndb" },
  }
  for i = 1, #providers do
    local db, source = providers[i][1], providers[i][2]
    if type(db) == "table" then
      local okay_person = true
      if type(db.isperson) == "function" then
        local ok, v = pcall(db.isperson, tgt)
        if ok and v == false then okay_person = false end
      end
      if okay_person and type(db.getclass) == "function" then
        local ok, cls = pcall(db.getclass, tgt)
        cls = _normalize_class_name(ok and cls or "")
        if cls ~= "" then
          out.class = cls
          out.known = true
          out.source = source
          return out
        end
      end
    end
  end
  return out
end

local _target_state
local _shield_is_up
local _current_target_matches

local function _class_defense_gates(plan)
  local BMC = Yso.curing and Yso.curing.blademaster
  if BMC and type(BMC.should_gate) == "function" then return BMC.should_gate(plan) end
  return false
end

local function _bm_snapshot_view(tgt, snap, mana_pct)
  local BMC = Yso.curing and Yso.curing.blademaster
  if BMC and type(BMC.snapshot_view) == "function" then
    return BMC.snapshot_view(tgt, {
      snap = snap,
      mana_pct = mana_pct,
      class_info = _target_class_info(tgt),
      shield_is_up = _shield_is_up and _shield_is_up(tgt) or nil,
      target_meta = _target_meta(tgt),
      now = _now(),
      cfg = AB.cfg,
    })
  end
  local info = _target_class_info(tgt)
  return {
    active = false,
    class = info.class,
    class_known = info.known,
    class_source = info.source,
    state = "missing",
    needs_readaura = false,
    passive_allowed = false,
    counts_under_pressure = false,
    blind = nil, blind_known = false, blind_fresh = false,
    deaf = nil, deaf_known = false, deaf_fresh = false,
    shield = nil, shield_known = false, shield_fresh = false,
    physical = nil, physical_known = false, physical_fresh = false,
    mental = nil, mental_known = false, mental_fresh = false,
    speed = nil, speed_known = false, speed_fresh = false,
    mana_pct = tonumber(mana_pct),
    mana_known = (tonumber(mana_pct) ~= nil),
    mana_fresh = (tonumber(mana_pct) ~= nil),
  }
end

-- CS.snapshot now provided by occ_aura_planner.lua (AP.snapshot)

function CS.plan_aff(tgt)
  local snap = CS.snapshot(tgt)
  local fresh = (snap and snap.fresh == true)
  local missing = {}
  if snap and type(snap.missing_keys) == "table" then
    for i = 1, #snap.missing_keys do
      missing[tostring(snap.missing_keys[i] or "")] = true
    end
  end

  local mana = nil
  if Yso and Yso.tgt and type(Yso.tgt.get_mana_pct) == "function" then
    local ok, v = pcall(Yso.tgt.get_mana_pct, tgt)
    if ok and tonumber(v) then mana = tonumber(v) end
  end
  if mana == nil and fresh and snap and snap.had_mana == true and tonumber(snap.mana_pct) then
    mana = tonumber(snap.mana_pct)
  end

  local bm = _bm_snapshot_view(tgt, snap, mana)
  local blind = snap and snap.blind or nil
  local deaf = snap and snap.deaf or nil
  local speed = snap and snap.speed or nil
  local shield = snap and snap.shield or nil
  local physical = snap and snap.physical or nil
  local mental = snap and snap.mental or nil
  if bm.active == true then
    blind = bm.blind
    deaf = bm.deaf
    speed = (bm.speed ~= nil) and bm.speed or speed
    shield = (bm.shield ~= nil) and bm.shield or shield
    physical = bm.physical
    mental = bm.mental
    if bm.mana_pct ~= nil then mana = bm.mana_pct end
  end

  local mana_cap = tonumber(CS.cfg.mana_burst_pct or 40) or 40
  local aff_total = nil
  if tonumber(physical) ~= nil or tonumber(mental) ~= nil then
    aff_total = (tonumber(physical) or 0) + (tonumber(mental) or 0)
  elseif fresh and tonumber(snap.aff_total) then
    aff_total = tonumber(snap.aff_total)
  end
  local focus_count = (_focus_lock_count and _focus_lock_count(tgt)) or 0
  local mana_bury_ready = (_mana_bury_ready and _mana_bury_ready(tgt)) or false
  local needs_chimera = (_focus_lock_chimera_desired and _focus_lock_chimera_desired(tgt)) or false
  if bm.active == true and bm.passive_allowed ~= true then
    needs_chimera = false
  end
  local needs_attend = (deaf == true) and needs_chimera
    and not (bm.active == true and bm.passive_allowed ~= true)
  local loyals_readaura = false
  if AB.S and type(AB.S.loyals_hostile) == "function" then
    local ok, hostile = pcall(AB.S.loyals_hostile, tgt)
    loyals_readaura = (ok and hostile == true) or false
  end
  local needs_readaura, readaura_reason = AP.needs_readaura(tgt, snap)
  local bm_entry = (bm.active == true and _has_aff(tgt, "asthma"))
  local bm_branch_active = bm_entry and bm.state == "complete_enough" and (_has_aff(tgt, "paralysis") or _has_aff(tgt, "weariness"))
  local bm_branch_provisional = bm_entry and not bm_branch_active
  local sensory_stage = ((mana ~= nil and mana <= mana_cap) or false) and "cleanseaura_window" or "pressure"
  local sensory_mode = (sensory_stage == "cleanseaura_window") and "burst_first_deaf_only" or "maintain_blind_deaf_deaf_bias"

  local out = {
    route = "aff",
    target = tgt,
    target_class = bm.class,
    mana_pct = mana,
    physical = physical,
    mental = mental,
    blind = blind,
    deaf = deaf,
    speed = speed,
    shield = shield,
    snapshot_fresh = fresh,
    snapshot_complete = fresh and snap.complete == true,
    snapshot_read_complete = fresh and snap.read_complete == true,
    snapshot_had_counts = fresh and snap.had_counts == true,
    snapshot_had_mana = fresh and snap.had_mana == true,
    snapshot_defs_state = tostring(snap.defs_state or "missing"),
    snapshot_confidence_state = tostring(snap.confidence_state or (fresh and "missing" or "stale")),
    snapshot_confidence_score = tonumber(snap.confidence_score or 0) or 0,
    snapshot_missing_keys = snap.missing_keys or {},
    snapshot_parse_window_open = (snap.parse_window_open == true),
    snapshot_parse_window_remaining = tonumber(snap.parse_window_remaining or 0) or 0,
    snapshot_txn_status = tostring(snap.txn_status or ""),
    snapshot_txn_reason = tostring(snap.txn_reason or ""),
    snapshot_txn_read_id = tonumber(snap.txn_read_id or 0) or 0,
    snapshot_aff_total = aff_total,
    snapshot_ts = snap and tonumber(snap.ts or 0) or 0,
    snapshot_read_id = snap and tonumber(snap.read_id or 0) or 0,
    mana_ready = (mana ~= nil and mana <= mana_cap) or false,
    needs_mana_bury = (mana == nil) or (mana > mana_cap),
    mana_bury_ready = mana_bury_ready,
    needs_readaura = needs_readaura,
    readaura_reason = readaura_reason,
    readaura_via_loyals = loyals_readaura,
    needs_speed_strip = (speed == true) or false,
    cleanseaura_ready = (mana ~= nil and mana <= mana_cap) or false,
    needs_attend = needs_attend,
    needs_chimera = needs_chimera,
    sensory_stage = sensory_stage,
    sensory_mode = sensory_mode,
    sensory_deaf_priority = (sensory_stage == "pressure"),
    focus_lock_count = focus_count,
    bm_snapshot = bm,
    bm_snapshot_state = bm.state,
    bm_snapshot_active = (bm.active == true),
    bm_snapshot_complete = (bm.state == "complete_enough"),
    bm_snapshot_provisional = (bm.state == "provisional"),
    bm_branch_active = (bm_branch_active == true),
    bm_branch_provisional = (bm_branch_provisional == true),
    bm_passive_allowed = (bm.passive_allowed == true),
  }

  return out
end

local function _recent_sent(tag, within_s)
  local S = _offense_state()
  if not (S and type(S.recent) == "function") then return false end
  return S.recent(tag, within_s)
end

local function _note_recent_tag(tag, cmd, lockout)
  tag = _trim(tag)
  cmd = _trim(cmd)
  if tag == "" or cmd == "" then return false end
  local S = _offense_state()
  if not (S and type(S.note) == "function") then return false end
  return S.note(tag, cmd, { lockout = lockout, state_sig = "route_local" })
end

local function _note_payload_tags(payload)
  if type(payload) ~= "table" then return false end
  local meta = type(payload.meta) == "table" and payload.meta or {}
  local lanes = type(payload.lanes) == "table" and payload.lanes or payload
  if type(lanes) ~= "table" then return false end

  _note_recent_tag(meta.free_tag, lanes.free or lanes.pre, 0)
  _note_recent_tag(meta.eq_tag, lanes.eq, meta.eq_lockout)
  _note_recent_tag(meta.bal_tag, lanes.bal, meta.bal_lockout)
  return true
end

local function _pin_tag(tgt)
  return "ab:eq:speed_strip:" .. _lc(tgt)
end

local function _utter_tag(tgt)
  return "ab:eq:utter:" .. _lc(tgt)
end

local function _is_truename_category(cat)
  cat = tostring(cat or "")
  return cat == "truename_acquire"
      or cat == "mental_build"
      or cat == "speed_strip_window"
      or cat == "reserved_burst"
end

local function _record_checkpoint(cat)
  cat = tostring(cat or "")
  if cat == "" or cat == "required_entity_maintenance" or _is_truename_category(cat) then return end
  AB.state.resume_checkpoint = cat
  AB.state.resume_checkpoint_at = _now()
end

local function _truename_entry_eligible(tgt, plan)
  if _trim(tgt) == "" or type(plan) ~= "table" then return false end
  return plan.cleanseaura_ready == true and not _truebook_can_utter(tgt)
end

local function _truename_gate(tgt, plan)
  local required = tonumber(AB.cfg.truename_branch_stability_pulses or 2) or 2
  if required < 1 then required = 1 end

  local same_target = (_lc(AB.state.last_target or "") == _lc(tgt or ""))
  if not same_target then
    AB.state.truename_entry_stable_pulses = 0
  end

  local eligible = _truename_entry_eligible(tgt, plan)
  if eligible then
    AB.state.truename_entry_stable_pulses = tonumber(AB.state.truename_entry_stable_pulses or 0) + 1
  else
    AB.state.truename_entry_stable_pulses = 0
  end

  local stable = eligible and AB.state.truename_entry_stable_pulses >= required
  return {
    eligible = eligible,
    stable = stable,
    stable_pulses = tonumber(AB.state.truename_entry_stable_pulses or 0) or 0,
    required = required,
  }
end

local function _prefer_over_shared(cat)
  return _is_truename_category(cat)
end

local function _combat_mode_active()
  local M = Yso and Yso.mode or nil
  if type(M) ~= "table" then return true end
  if type(M.is_combat) == "function" then
    local ok, v = pcall(M.is_combat)
    if ok then return v == true end
  end
  return _lc(M.state or "") == "combat"
end

local function _route_active()
  if not _combat_mode_active() then return false end
  if Yso and Yso.mode and type(Yso.mode.route_loop_active) == "function" then
    return Yso.mode.route_loop_active("occ_aff_burst") == true
  end
  return AB.state and AB.state.loop_enabled == true
end

local _FOCUS_LOCK_CHIMERA_POOL = {
  "agoraphobia",
  "confusion",
  "claustrophobia",
  "dementia",
  "hallucinations",
}
local _FOCUS_LOCK_MOON_FALLBACK = {
  "stupidity",
  "epilepsy",
  "confusion",
  "hallucinations",
  "claustrophobia",
  "agoraphobia",
  "masochism",
  "hypersomnia",
}
local _FOCUS_LOCK_DISCORD_FALLBACK = { "loneliness", "dizziness" }
local _FOCUS_LOCK_ENLIGHTEN_FALLBACK = {
  "claustrophobia",
  "agoraphobia",
  "lovers",
  "dementia",
  "epilepsy",
  "hallucinations",
  "confusion",
  "stupidity",
  "paranoia",
  "vertigo",
  "shyness",
  "addiction",
  "recklessness",
  "masochism",
}
local _ENTITY_FILLER_ORDER = {
  "clumsiness",
  "healthleech",
  "weariness",
  "haemophilia",
  "addiction",
}

local function _normalized_aff_list(src)
  local out = {}
  if type(src) ~= "table" then return out end
  if #src > 0 then
    for i = 1, #src do
      local aff = _lc(src[i])
      if aff ~= "" then _push_unique(out, aff) end
    end
    return out
  end
  for k, v in pairs(src) do
    if type(v) == "string" then
      local aff = _lc(v)
      if aff ~= "" then _push_unique(out, aff) end
    elseif v == true and type(k) == "string" then
      local aff = _lc(k)
      if aff ~= "" then _push_unique(out, aff) end
    end
  end
  return out
end

local function _list_to_set(list)
  local out = {}
  for i = 1, #(list or {}) do
    local aff = _lc(list[i])
    if aff ~= "" then out[aff] = true end
  end
  return out
end

local function _moon_focus_affs()
  local map = Yso and Yso.oc and Yso.oc.map and Yso.oc.map.skills or nil
  if type(map) == "table"
    and type(map.tarot) == "table"
    and type(map.tarot.moon) == "table"
  then
    local live = _normalized_aff_list(map.tarot.moon.affs)
    if #live > 0 then return live end
  end
  return _normalized_aff_list(_FOCUS_LOCK_MOON_FALLBACK)
end

local function _discord_focus_affs()
  local map = Yso and Yso.oc and Yso.oc.map and Yso.oc.map.skills or nil
  if type(map) == "table"
    and type(map.occultism) == "table"
    and type(map.occultism.compel_discord) == "table"
  then
    local live = _normalized_aff_list(map.occultism.compel_discord.affs)
    if #live > 0 then return live end
  end
  return _normalized_aff_list(_FOCUS_LOCK_DISCORD_FALLBACK)
end

local function _enlighten_focus_affs()
  local AK = Yso and Yso.oc and Yso.oc.ak or nil
  if type(AK) == "table" and type(AK.refresh_lists_from_AK) == "function" then
    pcall(AK.refresh_lists_from_AK)
  end
  if type(AK) == "table" and type(AK.lists) == "table" then
    local live = _normalized_aff_list(AK.lists.enlightenlist)
    if #live > 0 then return live end
  end
  return _normalized_aff_list(_FOCUS_LOCK_ENLIGHTEN_FALLBACK)
end

local function _focus_lock_chimera_set()
  return _list_to_set(_FOCUS_LOCK_CHIMERA_POOL)
end

local function _focus_lock_moon_set()
  return _list_to_set(_moon_focus_affs())
end

local function _focus_lock_discord_set()
  return _list_to_set(_discord_focus_affs())
end

local function _focus_lock_enlighten_set()
  return _list_to_set(_enlighten_focus_affs())
end

local function _focus_lock_aff_in_set(aff, set)
  aff = _lc(aff)
  return aff ~= "" and type(set) == "table" and set[aff] == true
end

local function _focus_lock_in_chimera_pool(aff)
  return _focus_lock_aff_in_set(aff, _focus_lock_chimera_set())
end

local function _focus_lock_in_moon_pool(aff)
  return _focus_lock_aff_in_set(aff, _focus_lock_moon_set())
end

local function _focus_lock_in_discord_pool(aff)
  return _focus_lock_aff_in_set(aff, _focus_lock_discord_set())
end

local function _discord_contribution_present(tgt)
  local list = _discord_focus_affs()
  for i = 1, #list do
    if _has_aff(tgt, list[i]) then return true end
  end
  return _has_aff(tgt, "asthma") and _has_aff(tgt, "healthleech")
end

local function _has_bloodroot_hold(tgt)
  return _has_aff(tgt, "slickness") or _has_aff(tgt, "paralysis")
end

_mana_bury_ready = function(tgt)
  return _has_aff(tgt, "asthma")
    and _has_bloodroot_hold(tgt)
    and _has_aff(tgt, "healthleech")
end

_focus_lock_count = function(tgt)
  local n = 0
  local seen = {}
  local function count_aff(aff)
    aff = _lc(aff)
    if aff == "" or seen[aff] or _focus_lock_in_discord_pool(aff) then return end
    if _has_aff(tgt, aff) then
      seen[aff] = true
      n = n + 1
    end
  end
  for i = 1, #_FOCUS_LOCK_CHIMERA_POOL do count_aff(_FOCUS_LOCK_CHIMERA_POOL[i]) end
  local moon = _moon_focus_affs()
  for i = 1, #moon do count_aff(moon[i]) end
  local enlighten = _enlighten_focus_affs()
  for i = 1, #enlighten do count_aff(enlighten[i]) end
  if _discord_contribution_present(tgt) then n = n + 1 end
  return n
end

local function _lock_stable(tgt)
  local need = tonumber(AB.cfg.mental_pressure_threshold or 3) or 3
  if need < 1 then need = 1 end
  return _focus_lock_count(tgt) >= need
end

local function _entity_refresh_state(tgt)
  local ER = Yso and Yso.off and Yso.off.oc and Yso.off.oc.entity_registry or nil
  local out = {
    registry = ER,
    worm_refresh = true,
    syc_refresh = true,
  }
  if ER and type(ER.worm_should_refresh) == "function" then
    local ok, v = pcall(ER.worm_should_refresh, tgt)
    if ok then out.worm_refresh = (v == true) end
  end
  if ER and type(ER.syc_should_refresh) == "function" then
    local ok, v = pcall(ER.syc_should_refresh, tgt)
    if ok then out.syc_refresh = (v == true) end
  end
  return out
end

local function _predict_cure_info(tgt)
  local out = { pick = "", p = 0 }
  if not (Yso and Yso.predict and Yso.predict.cure and type(Yso.predict.cure.next) == "function") then
    return out
  end
  local ok, res = pcall(Yso.predict.cure.next, tgt)
  if not ok or type(res) ~= "table" then return out end
  out.pick = tostring(res.pick or "")
  out.p = tonumber(res.p or 0) or 0
  return out
end

local function _predict_cured_aff_in_family(tgt, allowed_set)
  local info = _predict_cure_info(tgt)
  local aff = _lc(info.pick or "")
  local threshold = tonumber(AB.cfg.predict_bias_threshold or 0.60) or 0.60
  if aff == "" or info.p < threshold then return nil end
  if type(allowed_set) ~= "table" or allowed_set[aff] ~= true or _has_aff(tgt, aff) then return nil end
  return aff
end

local function _mana_bury_prediction_set()
  return {
    asthma = true,
    slickness = true,
    paralysis = true,
    healthleech = true,
    manaleech = true,
  }
end

local function _focus_lock_prediction_set()
  local set = _focus_lock_chimera_set()
  for aff in pairs(_focus_lock_moon_set()) do set[aff] = true end
  for aff in pairs(_focus_lock_enlighten_set()) do set[aff] = true end
  for aff in pairs(_focus_lock_discord_set()) do set[aff] = true end
  return set
end

local function _chimera_pool_complete(tgt)
  for i = 1, #_FOCUS_LOCK_CHIMERA_POOL do
    if not _has_aff(tgt, _FOCUS_LOCK_CHIMERA_POOL[i]) then
      return false
    end
  end
  return true
end

local function _entity_filler_plan(tgt, ES)
  for i = 1, #_ENTITY_FILLER_ORDER do
    local aff = _ENTITY_FILLER_ORDER[i]
    if not _has_aff(tgt, aff) then
      local cmd, cat = _entity_aff_cmd(aff, tgt, ES)
      if _trim(cmd) ~= "" then
        return aff, cmd, cat or "mana_bury"
      end
    end
  end
  return nil, nil, nil
end

local function _predict_mana_bury_aff(tgt, plan)
  return _predict_cured_aff_in_family(tgt, _mana_bury_prediction_set())
end

local function _predict_focus_lock_aff(tgt, plan)
  return _predict_cured_aff_in_family(tgt, _focus_lock_prediction_set())
end

_focus_lock_chimera_desired = function(tgt)
  if _lock_stable(tgt) ~= true then return true end
  return _focus_lock_in_chimera_pool(_predict_focus_lock_aff(tgt))
end

local function _focus_lock_needs_moon(tgt)
  local target = tonumber(AB.cfg.mental_target or 5) or 5
  if target < 1 then target = 1 end
  if _focus_lock_count(tgt) < target then return true end
  return _focus_lock_in_moon_pool(_predict_focus_lock_aff(tgt))
end

local function _entity_candidates(tgt, plan)
  local predicted = nil
  local out, seen = {}, {}
  local function push(aff)
    aff = tostring(aff or "")
    if aff == "" or seen[aff] or _has_aff(tgt, aff) then return end
    seen[aff] = true
    out[#out + 1] = aff
  end
  if _has_aff(tgt, "manaleech") ~= true then
    predicted = _predict_mana_bury_aff(tgt, plan)
    if predicted == "asthma" or predicted == "slickness" or predicted == "paralysis" or predicted == "healthleech" then
      push(predicted)
    end
    if not _has_aff(tgt, "asthma") then
      push("asthma")
    elseif not _has_bloodroot_hold(tgt) then
      push("slickness")
      push("paralysis")
    elseif not _has_aff(tgt, "healthleech") then
      push("healthleech")
    end
    return out, predicted and "predict" or "mana_bury"
  end
  predicted = _predict_focus_lock_aff(tgt, plan)
  if _focus_lock_in_chimera_pool(predicted) then push("chimera_command") end
  if _focus_lock_chimera_desired(tgt) then push("chimera_command") end
  return out, predicted and "predict" or "focus_lock"
end

_entity_aff_cmd = function(aff, tgt, ES)
  if _lc(aff) == "chimera_command" then
    return ("command chimera at %s"):format(tgt), "mental_build"
  end
  if Yso.ent_cmd_for_aff and type(Yso.ent_cmd_for_aff) == "function" then
    return Yso.ent_cmd_for_aff(_lc(aff), tgt, _has_aff)
  end
  return nil, nil
end

local _para_state

local function _lock_maturity(tgt)
  local total = 0
  local has_asthma = _has_aff(tgt, "asthma")
  if _has_aff(tgt, "clumsiness") then total = total + 1.0 end
  if _has_aff(tgt, "sensitivity") then total = total + 1.0 end
  if _has_aff(tgt, "healthleech") then total = total + 0.75 end
  if _has_aff(tgt, "haemophilia") then total = total + 0.75 end
  if _has_aff(tgt, "addiction") then total = total + 0.5 end
  return {
    value = total,
    asthma = has_asthma,
    eligible = (((AB.cfg.para_require_asthma ~= false) and has_asthma) or (AB.cfg.para_require_asthma == false))
      and total >= 2.75,
  }
end

local function _para_override_choice(tgt, plan, pair, ctx)
  local PS = _para_state(tgt)
  local now = _now()
  local predict = _predict_cure_info(tgt)
  local maturity = _lock_maturity(tgt)
  local meta = _target_meta(tgt)
  local last_herb = _lc(PS and PS.last_cure_herb or meta.last_herb or "")
  local threshold, _bm_para_bonus
  do
    local BMC = Yso.curing and Yso.curing.blademaster
    if BMC and type(BMC.para_adjust) == "function" then
      threshold, _bm_para_bonus = BMC.para_adjust(AB.cfg, ctx and ctx.bm_branch_active == true)
    else
      threshold = tonumber(AB.cfg.para_override_threshold or 0.75) or 0.75
      _bm_para_bonus = 0
    end
  end
  local out = {
    predicted_next_cure = tostring(predict.pick or ""),
    confidence = tonumber(predict.p or 0) or 0,
    lock_maturity = tonumber(maturity.value or 0) or 0,
    allowed = false,
    score = 0,
    block_reason = "",
    lane = "",
    last_lane = tostring(PS and PS.last_refresh_lane or ""),
    last_herb = tostring(last_herb or ""),
  }
  local function finish(reason, allowed, lane, score)
    out.block_reason = tostring(reason or "")
    out.allowed = (allowed == true)
    out.lane = tostring(lane or "")
    out.score = tonumber(score or out.score or 0) or 0
    if PS then
      PS.last_allow = out.allowed
      PS.last_block_reason = out.block_reason
      PS.last_eval = {
        predicted_next_cure = out.predicted_next_cure,
        confidence = out.confidence,
        lock_maturity = out.lock_maturity,
        allowed = out.allowed,
        para_score = out.score,
        block_reason = out.block_reason,
        last_lane = out.last_lane,
        last_herb = out.last_herb,
        lane = out.lane,
      }
    end
    return out
  end

  if AB.cfg.para_require_asthma ~= false and maturity.asthma ~= true then
    return finish("no asthma")
  end
  if maturity.eligible ~= true then
    return finish("lock immature")
  end
  if not (last_herb == "bloodroot" or last_herb == "magnesium") then
    return finish("no bloodroot evidence")
  end
  if PS and PS.last_refresh_aff == "paralysis" then
    return finish("para was last refresh")
  end

  local since_apply = now - _clock(PS and PS.last_applied_at or 0)
  local since_cure = now - _clock(PS and PS.last_cured_at or 0)
  local recent_apply_s = tonumber(AB.cfg.para_recent_apply_s or 3.5) or 3.5
  local recent_cure_s = tonumber(AB.cfg.para_recent_cure_s or 2.5) or 2.5
  local eq_cd = tonumber(AB.cfg.para_eq_cd_s or 3.5) or 3.5
  local ent_cd = tonumber(AB.cfg.para_entity_cd_s or 6.0) or 6.0
  local evidence_bonus = 0.22
  local bm_bonus = _bm_para_bonus or 0
  local recent_apply_penalty = (since_apply > 0 and since_apply < recent_apply_s) and 0.18 or 0
  local recent_cure_penalty = (since_cure > 0 and since_cure < recent_cure_s) and 0.12 or 0
  local lane_scores = {}
  local lane_blocks = {}

  local function eval_lane(lane)
    local cooldown = (lane == "entity") and ent_cd or eq_cd
    if since_apply > 0 and since_apply < cooldown then
      lane_blocks[lane] = "lane cooldown"
      return nil, nil
    end
    local score = out.confidence + evidence_bonus + bm_bonus - recent_apply_penalty - recent_cure_penalty
    if lane == "entity" then score = score - 0.08 end
    local need = threshold + ((lane == "entity") and 0.05 or 0)
    lane_scores[lane] = score
    if score >= need then
      return score, need
    end
    return score, need
  end

  local best_lane, best_score = nil, -1
  if ctx and ctx.eq_available == true then
    local score, need = eval_lane("eq")
    if score and score >= need and score > best_score then
      best_lane, best_score = "eq", score
    end
  end
  if ctx and ctx.entity_available == true then
    local score, need = eval_lane("entity")
    if score and score >= need and score > best_score then
      best_lane, best_score = "entity", score
    end
  end

  if best_lane then
    return finish("", true, best_lane, best_score)
  end
  if lane_blocks.eq == "lane cooldown" and lane_blocks.entity == "lane cooldown" then
    return finish("lane cooldown", false, "", math.max(tonumber(lane_scores.eq or 0) or 0, tonumber(lane_scores.entity or 0) or 0))
  end
  return finish("score below threshold", false, "", math.max(tonumber(lane_scores.eq or 0) or 0, tonumber(lane_scores.entity or 0) or 0))
end

local function _entity_pair(tgt, plan, ctx)
  local ent_ready = (ctx and ctx.entity_available == true) or false
  local eq_ready = (ctx and ctx.eq_available == true) or false
  local ES = _entity_refresh_state(tgt)
  local has_wm = _has_aff(tgt, "whisperingmadness") or _has_aff(tgt, "whispering_madness")
  local out = {
    eq_aff = nil,
    entity_aff = nil,
    entity_cmd = nil,
    entity_cat = nil,
    reason = "",
    para = {
      predicted_next_cure = "",
      confidence = 0,
      lock_maturity = 0,
      allowed = false,
      score = 0,
      block_reason = "",
      lane = "",
      last_lane = "",
      last_herb = "",
    },
  }
  local entity_reserved = false

  local _ak_deaf = rawget(_G, "affstrack") and affstrack.score
    and tonumber(affstrack.score.deaf or 0) or 0
  local target_is_deaf = (_ak_deaf >= 100) or (plan and plan.deaf == true)

  if target_is_deaf and ent_ready
    and not _class_defense_gates(plan)
    and not (plan.finish_stage == "transition" or plan.finish_stage == "burst")
  then
    out.entity_cmd = ("command chimera at %s"):format(tgt)
    out.entity_cat = "mental_build"
    out.attend_for_deaf = true
    out.reason = "attend_deaf_chimera"
    ent_ready = false
    entity_reserved = true
  elseif plan and plan.needs_chimera == true and ent_ready
    and not _class_defense_gates(plan)
    and not (plan.finish_stage == "transition" or plan.finish_stage == "burst")
  then
    out.entity_cmd = ("command chimera at %s"):format(tgt)
    out.entity_cat = "mental_build"
    out.reason = "chimera_setup"
    ent_ready = false
    entity_reserved = true
  end

  local candidates, source = _entity_candidates(tgt, plan)
  local entity_aff = nil

  if ent_ready and out.entity_cmd == nil then
    for i = 1, #candidates do
      local cmd, cat = _entity_aff_cmd(candidates[i], tgt, ES)
      if cmd then
        entity_aff = candidates[i]
        out.entity_cmd = cmd
        out.entity_cat = cat or "mana_bury"
        break
      end
    end
  end

  if eq_ready and out.eq_aff == nil then
    for i = 1, #candidates do
      if candidates[i] ~= entity_aff then
        out.eq_aff = candidates[i]
        break
      end
    end
  end

  if eq_ready and out.eq_aff == nil and entity_aff == nil then
    out.eq_aff = candidates[1]
  end

  if out.reason == "" and source and source ~= "" then
    out.reason = "entity:" .. source
  end

  out.para = _para_override_choice(tgt, plan, out, {
    eq_available = eq_ready,
    entity_available = ent_ready and not entity_reserved,
    bm_branch_active = ((ctx and ctx.bm_branch_active == true) or (plan and plan.bm_branch_active == true)),
  })
  if out.para.allowed == true then
    if out.para.lane == "entity" and ent_ready and not entity_reserved then
      out.entity_cmd = ("command slime at %s"):format(tgt)
      out.entity_cat = "mana_bury"
      entity_aff = "paralysis"
      out.reason = "paralysis_override_entity"
    elseif out.para.lane == "eq" and eq_ready then
      out.eq_aff = "paralysis"
      out.reason = "paralysis_override_eq"
    end
  end

  if ent_ready and out.entity_cmd == nil and plan and plan.needs_mana_bury == true and ES.syc_refresh == true and has_wm ~= true then
    out.entity_cmd = ("command sycophant at %s"):format(tgt)
    out.entity_cat = "mana_bury"
    if out.reason == "" then out.reason = "sycophant_mana_support" end
  end

  out.entity_aff = entity_aff
  return out
end

local function _soulmaster_order_cmd(tgt)
  if not (Yso and type(Yso.soulmaster_ready) == "function") then return nil, nil end
  local ok, ready = pcall(Yso.soulmaster_ready)
  if not (ok and ready == true) then return nil, nil end

  local tag = "ab:eq:soulmaster:" .. _lc(tgt)
  if _recent_sent(tag, 4.0) then return nil, nil end

  local ER = Yso and Yso.off and Yso.off.oc and Yso.off.oc.entity_registry or nil
  local syc_active = false
  if ER then
    local T = ER.state and ER.state.targets and ER.state.targets[_lc(tgt)]
    if T and T.effects and T.effects.sycophant then
      syc_active = (tonumber(T.effects.sycophant.until_t or 0) or 0) > _now()
    end
  end

  if _has_aff(tgt, "haemophilia") then
    if syc_active then
      return ("order %s focus mind"):format(tgt), tag
    end
    return ("order %s focus mind"):format(tgt), tag
  end

  return ("order %s clot"):format(tgt), tag
end

local function _finish_state(tgt)
  local row = _target_state(tgt)
  if not row then return nil end
  row.finish = row.finish or {
    stage = "pressure",
    stage_at = 0,
    last_progress_at = 0,
    blocker = "",
    next_action = "",
    cleanseaura_state = "",
    stalled = false,
    signature = "",
  }
  return row.finish
end

local function _finish_view(tgt, plan)
  local FS = _finish_state(tgt)
  if not FS then
    return {
      stage = "pressure",
      next_action = "maintain aff",
      blocker = "no target",
      cleanseaura_state = "unknown",
      stalled = false,
      mana_ready = false,
    }
  end

  local now = _now()
  local mana_cap = tonumber(CS.cfg.mana_burst_pct or 40) or 40
  local mana = tonumber(plan and plan.mana_pct or nil)
  local clean_ready = (plan and plan.cleanseaura_ready == true)
  local stage = "pressure"
  local next_action = "maintain aff"
  local blocker = ""

  if _truebook_can_utter(tgt) then
    stage = "burst"
    next_action = (plan and plan.needs_speed_strip == true) and "pinchaura speed" or "utter truename"
    if plan and plan.needs_speed_strip == true then blocker = "speed strip" end
  elseif clean_ready and _has_aff(tgt, "manaleech") then
    stage = "transition"
    next_action = "cleanseaura"
    if plan and plan.needs_readaura == true then
      blocker = "readaura needed"
      next_action = "readaura"
    end
  elseif mana ~= nil and mana <= (mana_cap + 10) and _has_aff(tgt, "manaleech") then
    stage = "primed"
    next_action = clean_ready and "cleanseaura" or "maintain aff"
    if clean_ready ~= true then blocker = "waiting cleanseaura" end
  else
    stage = "pressure"
    if mana == nil then
      blocker = "mana unknown"
    elseif mana > mana_cap then
      blocker = "mana high"
    elseif not _has_aff(tgt, "manaleech") then
      blocker = ((plan and plan.mana_bury_ready == true) and "manaleech missing") or "mana_bury setup"
    end
  end

  local signature = table.concat({
    tostring(stage),
    tostring(next_action),
    tostring(blocker),
    tostring(clean_ready),
  }, "|")
  if signature ~= tostring(FS.signature or "") then
    FS.last_progress_at = now
    FS.stage_at = now
  end

  local stalled = (stage ~= "pressure") and ((now - tonumber(FS.last_progress_at or now)) > 4.5)
  if stalled then
    stage = "pressure"
    next_action = "re-evaluate"
    blocker = "stalled"
    signature = table.concat({
      tostring(stage),
      tostring(next_action),
      tostring(blocker),
      tostring(clean_ready),
    }, "|")
    FS.last_progress_at = now
    FS.stage_at = now
  end

  FS.stage = stage
  FS.next_action = next_action
  FS.blocker = blocker
  FS.cleanseaura_state = clean_ready and "ready" or "not ready"
  FS.stalled = (stalled == true)
  FS.signature = signature

  return {
    stage = stage,
    next_action = next_action,
    blocker = blocker,
    cleanseaura_state = FS.cleanseaura_state,
    stalled = FS.stalled,
    mana_ready = (mana ~= nil and mana <= mana_cap) or false,
  }
end

local function _loyals_active_for(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return false end
  if type(Yso.loyals_attack) == "function" then
    local ok, v = pcall(Yso.loyals_attack, tgt)
    if ok and v == true then return true end
  end
  return _lc(AB.state.loyals_sent_for or "") == _lc(tgt)
end

local function _loyals_open_cmd(tgt)
  tgt = _trim(tgt)
  if tgt == "" or _loyals_active_for(tgt) then return nil, nil end
  return (tostring(AB.cfg.loyals_on_cmd or "order entourage kill %s")):format(tgt), "target_swap_bootstrap"
end

local function _set_loyals_hostile(v, tgt)
  local hostile = (v == true)
  tgt = _trim(tgt)
  if type(Yso.set_loyals_attack) == "function" then
    pcall(Yso.set_loyals_attack, hostile, tgt)
    return
  end
  if Yso and Yso.state then
    Yso.state.loyals_hostile = hostile
    if hostile and tgt ~= "" then
      Yso.state.loyals_target = tgt
    elseif not hostile then
      Yso.state.loyals_target = nil
    end
  end
  rawset(_G, "loyals_attack", hostile)
end

local function _clear_loyals_hostile()
  _set_loyals_hostile(false)
  AB.state.loyals_sent_for = ""
end

local function _loyals_any_active()
  if type(Yso.loyals_attack) == "function" then
    local ok, v = pcall(Yso.loyals_attack)
    if ok and v == true then return true end
  end
  return _trim(AB.state.loyals_sent_for or "") ~= ""
end

AB.S = AB.S or {}
function AB.S.loyals_hostile(tgt)
  tgt = _trim(tgt)
  if tgt ~= "" then
    return _loyals_active_for(tgt)
  end
  return _loyals_any_active()
end

local function _command_sep()
  local sep = _trim((Yso and (Yso.sep or (Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep)))) or "&&")
  if sep == "" then sep = "&&" end
  return sep
end

local function _chain_cmds(...)
  local out = {}
  for i = 1, select("#", ...) do
    local cmd = _trim(select(i, ...))
    if cmd ~= "" then out[#out + 1] = cmd end
  end
  return table.concat(out, _command_sep())
end

local function _append_free_part(parts, cmd, offense)
  cmd = _trim(cmd)
  if cmd == "" then return end
  parts[#parts + 1] = {
    cmd = cmd,
    offense = (offense == true),
  }
end

local function _queue_free_recovery(cmd)
  cmd = _trim(cmd)
  if cmd == "" then return false end
  AB.state.pending_free = AB.state.pending_free or {}
  for i = 1, #AB.state.pending_free do
    if AB.state.pending_free[i] == cmd then return false end
  end
  AB.state.pending_free[#AB.state.pending_free + 1] = cmd
  return true
end

local function _take_free_recovery()
  local pending = AB.state.pending_free or {}
  if #pending == 0 then return "" end
  local out = table.concat(pending, _command_sep())
  AB.state.pending_free = {}
  return out
end

local function _safe_send(cmd)
  cmd = _trim(cmd)
  if cmd == "" or type(send) ~= "function" then return false, "send_unavailable" end
  local ok, err = pcall(send, cmd, false)
  if not ok then return false, err end
  return true
end

local _payload_line

local function _waiting_lanes_from_payload(payload)
  local lanes = {}
  local seen = {}
  local lane_tbl = type(payload) == "table" and payload.lanes or payload

  local function add(name, cmd)
    name = _lc(name)
    if name == "entity" then name = "class" end
    if name == "" or name == "free" or seen[name] then return end
    if _trim(cmd) == "" then return end
    seen[name] = true
    lanes[#lanes + 1] = name
  end

  if type(lane_tbl) == "table" then
    add("eq", lane_tbl.eq)
    add("bal", lane_tbl.bal)
    add("class", lane_tbl.class or lane_tbl.ent or lane_tbl.entity)
  end
  if #lanes == 0 and type(payload) == "table" and type(payload.meta) == "table" then
    add(payload.meta.main_lane, "__fallback__")
  end

  return lanes
end

local function _lane_ready(lane)
  lane = _lc(lane)
  if lane == "eq" then return _eq_ready() end
  if lane == "bal" then return _bal_ready() end
  if lane == "entity" or lane == "class" then return _ent_ready() end
  return true
end

local function _eq_lane_score(cat)
  cat = tostring(cat or "")
  if cat == "reserved_burst" then return 130 end
  if cat == "defense_break" then return 122 end
  if cat == "team_coordination" then return 110 end
  if cat == "truename_acquire" then return 108 end
  if cat == "speed_strip_window" then return 104 end
  if cat == "mana_bury" then return 42 end
  if cat == "mental_build" then return 40 end
  return 36
end

local function _bal_lane_score(cat)
  cat = tostring(cat or "")
  if cat == "mental_build" then return 22 end
  return 16
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

local function _emit_payload(payload)
  local lane_tbl = type(payload) == "table" and payload.lanes or payload
  if type(lane_tbl) ~= "table" then return false, "invalid_payload" end

  local emit_payload = {
    free = lane_tbl.free or lane_tbl.pre,
    eq = lane_tbl.eq,
    bal = lane_tbl.bal,
    class = lane_tbl.class or lane_tbl.ent or lane_tbl.entity,
  }
  local cmd = _payload_line({ lanes = emit_payload })
  if _trim(cmd) == "" then return false, "empty" end

  local Q = Yso and Yso.queue or nil
  local used_queue = false
  if Q and type(Q.emit) == "function" then
    local ok, res = pcall(Q.emit, emit_payload)
    if not ok then return false, res end
    if res ~= true then return false, "queue_emit_failed" end
    used_queue = true
  else
    local sent, err = _safe_send(cmd)
    if not sent then return false, err end
  end

  if Yso and Yso.locks and type(Yso.locks.note_send) == "function" then
    if _trim(emit_payload.eq) ~= "" then pcall(Yso.locks.note_send, "eq") end
    if _trim(emit_payload.bal) ~= "" then pcall(Yso.locks.note_send, "bal") end
    if not used_queue and _trim(emit_payload.class) ~= "" then
      pcall(Yso.locks.note_send, "class")
    end
  end
  if not used_queue and _trim(emit_payload.class) ~= "" and Yso and Yso.state and type(Yso.state.set_ent_ready) == "function" then
    pcall(Yso.state.set_ent_ready, false, "occ_aff_burst:fallback_emit")
  end

  return true, cmd
end

local function _route_gate_finalize(payload, ctx, tgt, required_entities)
  if not (Yso and Yso.route_gate and type(Yso.route_gate.finalize) == "function") then
    return payload, nil
  end
  return Yso.route_gate.finalize(payload, {
    route = "occ_aff_burst",
    target = tgt,
    lane_ready = {
      eq = _eq_ready(),
      bal = _bal_ready(),
      entity = _ent_ready(),
    },
    required_entities = required_entities or {},
    ctx = ctx,
  })
end

local function _record_payload_checkpoint(payload)
  if type(payload) ~= "table" then return false end
  local meta = type(payload.meta) == "table" and payload.meta or {}
  local eq_cat = tostring(meta.eq_category or "")
  local raw_eq_cat = tostring(meta.raw_eq_category or "")
  local bal_cat = tostring(meta.bal_category or "")
  local entity_cat = tostring(meta.entity_category or "")
  if eq_cat == "defense_break" then
    _record_checkpoint(raw_eq_cat)
  else
    _record_checkpoint(eq_cat)
  end
  _record_checkpoint(bal_cat)
  _record_checkpoint(entity_cat)
  return true
end

local function _self_gate_state()
  AB.state.self_gate = AB.state.self_gate or {
    retry_until = 0,
    not_standing_until = 0,
    arms_until = 0,
    bound_until = 0,
    last_failure_line = "",
  }

  local SG = AB.state.self_gate
  local now = _now()
  local reasons = {}
  if now < tonumber(SG.not_standing_until or 0) then _push_unique(reasons, "not standing") end
  if now < tonumber(SG.arms_until or 0) then _push_unique(reasons, "arms unusable") end
  if now < tonumber(SG.bound_until or 0) then _push_unique(reasons, "bound") end

  return {
    eq_blocked = (#reasons > 0),
    eq_block_reasons = reasons,
    retry_until = tonumber(SG.retry_until or 0) or 0,
    queue_stand = false,
    last_failure_line = tostring(SG.last_failure_line or ""),
  }
end

_target_state = function(tgt)
  AB.state.targets = AB.state.targets or {}
  local key = _lc(tgt)
  if key == "" then return nil end
  local row = AB.state.targets[key]
  if type(row) ~= "table" then
    row = {
      shieldbreak = {
        pending = false,
        sent_at = 0,
        last_result = "",
        fail_count = 0,
        summon_attempts = 0,
        gremlin_skip_until = 0,
        cooldown_until = 0,
        preshield_stage = "",
        preshield_eq_cmd = "",
        preshield_checkpoint = "",
      },
      para = {
        last_refresh_lane = "",
        last_refresh_at = 0,
        last_refresh_aff = "",
        last_applied_at = 0,
        last_cured_at = 0,
        last_cure_herb = "",
        last_eval = {},
        last_allow = false,
        last_block_reason = "",
      },
      unnamable = {
        can_hear = nil,
        can_see = nil,
        last_mode = "",
        last_cast_at = 0,
        ready_at = 0,
        last_attend_at = 0,
        initial_attend_done = false,
        last_success_at = 0,
        last_aura_at = 0,
        last_aura_read_id = 0,
        last_reopen_at = 0,
        last_hear_reopen_at = 0,
        last_see_reopen_at = 0,
        last_ak_hear_at = 0,
        last_ak_see_at = 0,
        last_allow = false,
        last_block_reason = "",
        last_attend_status = "wait",
      },
    }
    AB.state.targets[key] = row
  end
  row.name = _trim(tgt)
  return row
end

_para_state = function(tgt)
  local row = _target_state(tgt)
  if not row then return nil end
  row.para = row.para or {
    last_refresh_lane = "",
    last_refresh_at = 0,
    last_refresh_aff = "",
    last_applied_at = 0,
    last_cured_at = 0,
    last_cure_herb = "",
    last_eval = {},
    last_allow = false,
    last_block_reason = "",
  }
  return row.para
end

local function _unnamable_state(tgt)
  local row = _target_state(tgt)
  if not row then return nil end
  row.unnamable = row.unnamable or {
    can_hear = nil,
    can_see = nil,
    last_mode = "",
    last_cast_at = 0,
    ready_at = 0,
    last_attend_at = 0,
    initial_attend_done = false,
    last_success_at = 0,
    last_aura_at = 0,
    last_aura_read_id = 0,
    last_reopen_at = 0,
    last_hear_reopen_at = 0,
    last_see_reopen_at = 0,
    last_ak_hear_at = 0,
    last_ak_see_at = 0,
    last_allow = false,
    last_block_reason = "",
    last_attend_status = "wait",
  }
  return row.unnamable
end

local function _debug_event(section, text)
  if AB.debug.enabled ~= true or type(cecho) ~= "function" then return false end
  cecho(string.format("<CadetBlue>[ABDBG:%s]<reset> %s\n", tostring(section or "Event"), tostring(text or "")))
  return true
end

local function _ak_last_cure_at(tgt, affs)
  local enemy = Yso and Yso.ak and Yso.ak.enemy or nil
  if type(enemy) ~= "table" or not _same_target(enemy.name or enemy.target or "", tgt) then
    return 0, ""
  end
  local last = type(enemy.last_cure) == "table" and enemy.last_cure or nil
  if not last then return 0, "" end

  local best_at, best_aff = 0, ""
  for i = 1, #(affs or {}) do
    local aff = tostring(affs[i] or "")
    local at = _clock(last[aff] or last[_lc(aff)] or 0)
    if at > best_at then
      best_at = at
      best_aff = aff
    end
  end
  return best_at, best_aff
end

local function _unnamable_set_reopen(tgt, field, source, when)
  local US = _unnamable_state(tgt)
  if not US then return false end

  field = tostring(field or "")
  when = _clock(when)
  if when <= 0 then when = _now() end
  if field ~= "can_hear" and field ~= "can_see" then return false end

  local changed = (US[field] ~= true)
  US[field] = true
  if field == "can_hear" then
    US.last_hear_reopen_at = when
  else
    US.last_see_reopen_at = when
  end
  US.last_reopen_at = math.max(_clock(US.last_reopen_at), when)

  if changed then
    _debug_event("Unnamable", string.format("%s reopened tgt=%s via %s",
      (field == "can_hear") and "can_hear" or "can_see", tostring(tgt), tostring(source or "evidence")))
  end
  return true
end

local function _unnamable_sync_from_plan(tgt, plan)
  local US = _unnamable_state(tgt)
  if not US or tgt == "" or type(plan) ~= "table" then return US end

  if plan.snapshot_fresh == true then
    local aura_ts = _clock(plan.snapshot_ts)
    local aura_id = tonumber(plan.snapshot_read_id or 0) or 0
    local is_new = false
    if aura_id > 0 and aura_id ~= tonumber(US.last_aura_read_id or 0) then
      is_new = true
      US.last_aura_read_id = aura_id
    elseif aura_ts > 0 and aura_ts ~= _clock(US.last_aura_at) then
      is_new = true
    end
    if aura_ts > 0 then
      US.last_aura_at = aura_ts
    else
      US.last_aura_at = _now()
    end

    if plan.deaf ~= nil then
      US.can_hear = (plan.deaf ~= true)
    end
    if plan.blind ~= nil then
      US.can_see = (plan.blind ~= true)
    end

    if is_new then
      local hear = (US.can_hear == true) and "yes" or (US.can_hear == false and "no" or "?")
      local see = (US.can_see == true) and "yes" or (US.can_see == false and "no" or "?")
      _debug_event("Unnamable", string.format("aura updated tgt=%s hear=%s see=%s", tostring(tgt), hear, see))
    end
  end

  local meta = _target_meta(tgt)
  local ak_deaf_cure_at = _ak_last_cure_at(tgt, { "deafness", "deaf" })
  local deaf_cure_at = math.max(_clock(meta.last_deaf_strip_at), _clock(ak_deaf_cure_at))
  if deaf_cure_at > _clock(US.last_ak_hear_at) then
    US.last_ak_hear_at = deaf_cure_at
    _unnamable_set_reopen(tgt, "can_hear", "deaf stripped", deaf_cure_at)
  end

  local ak_blind_cure_at = _ak_last_cure_at(tgt, { "blindness", "blind" })
  local blind_cure_at = math.max(_clock(meta.last_blind_strip_at), _clock(ak_blind_cure_at))
  if blind_cure_at > _clock(US.last_ak_see_at) then
    US.last_ak_see_at = blind_cure_at
    _unnamable_set_reopen(tgt, "can_see", "blind stripped", blind_cure_at)
  end

  return US
end

local function _unnamable_attend_status(tgt, plan)
  local US = _unnamable_state(tgt)
  if not US then return "wait" end

  local now = _now()
  local debounce = tonumber(AB.cfg.unnamable_attend_debounce_s or 3.5) or 3.5
  local needs_initial = (US.initial_attend_done ~= true) and _clock(US.last_aura_at) > 0
  local needs_refresh = (type(plan) == "table" and plan.needs_attend == true)

  if needs_initial ~= true and needs_refresh ~= true then
    US.last_attend_status = "done"
    return "done"
  end
  if (now - _clock(US.last_attend_at)) < debounce then
    US.last_attend_status = "wait"
    return "wait"
  end

  US.last_attend_status = "due"
  return "due"
end

local function _unnamable_attend_plan(tgt, plan)
  local status = _unnamable_attend_status(tgt, plan)
  if status ~= "due" then return nil, nil, nil, nil end

  local tag = "ab:eq:attend:" .. _lc(tgt)
  local lock = math.max(
    tonumber(AB.cfg.attend_lockout_s or 0) or 0,
    tonumber(AB.cfg.unnamable_attend_debounce_s or 3.5) or 3.5
  )
  return ("attend %s"):format(tgt), "mental_build", tag, lock
end

local function _unnamable_candidate(tgt, plan)
  local US = _unnamable_state(tgt)
  local now = _now()
  local out = {
    eligible = false,
    cmd = nil,
    mode = "",
    attend = _unnamable_attend_status(tgt, plan),
    ready_in = math.max(0, _clock(US and US.ready_at or 0) - now),
    hear = US and US.can_hear or nil,
    see = US and US.can_see or nil,
    last_mode = tostring(US and US.last_mode or ""),
    block_reason = "",
  }

  local function finish(reason, cmd, mode)
    out.block_reason = tostring(reason or "")
    out.cmd = cmd
    out.mode = tostring(mode or "")
    out.eligible = (_trim(cmd) ~= "")
    if US then
      US.last_allow = out.eligible
      US.last_block_reason = out.block_reason
    end
    return out
  end

  if not US then return finish("missing state") end
  if tgt == "" then return finish("no target") end
  if _route_active() ~= true then return finish("route inactive") end
  if _eq_ready() ~= true then return finish("eq not ready") end
  if _current_target_matches(tgt) ~= true then return finish("target swap") end
  if _clock(US.ready_at) > now then return finish("lockout") end
  if out.attend ~= "done" then
    return finish((out.attend == "due") and "attend due" or "attend debounce")
  end

  local has_aura = (type(plan) == "table" and plan.snapshot_fresh == true)
  local has_reopen = math.max(_clock(US.last_reopen_at), _clock(US.last_ak_hear_at), _clock(US.last_ak_see_at)) > 0
  if has_aura ~= true and has_reopen ~= true then
    return finish("no aura")
  end

  if US.can_hear == true and US.can_see == false then
    return finish("", "unnamable speak", "speak")
  end
  if US.can_see == true and US.can_hear == false then
    return finish("", "unnamable vision", "vision")
  end
  if US.can_hear == true and US.can_see == true then
    local last_mode = _lc(US.last_mode or "")
    local mode = (last_mode == "speak") and "vision" or "speak"
    return finish("", "unnamable " .. mode, mode)
  end
  if US.can_hear ~= true and US.can_see ~= true then
    return finish("no hear/see")
  end
  return finish("sense unknown")
end

local function _note_para_cure_evidence(tgt, herb)
  local low = _lc(herb)
  if tgt == "" or (low ~= "bloodroot" and low ~= "magnesium") then return false end
  if Yso and Yso.tgt and type(Yso.tgt.note_target_herb) == "function" then
    pcall(Yso.tgt.note_target_herb, tgt, low)
  end
  local PS = _para_state(tgt)
  if not PS then return false end
  PS.last_cured_at = _now()
  PS.last_cure_herb = low
  return true
end

local function _note_refresh_sent(tgt, lane, aff)
  local PS = _para_state(tgt)
  if not PS then return false end
  aff = _lc(aff)
  lane = _lc(lane)
  if aff == "" or lane == "" then return false end
  PS.last_refresh_lane = lane
  PS.last_refresh_at = _now()
  PS.last_refresh_aff = aff
  if aff == "paralysis" then
    PS.last_applied_at = PS.last_refresh_at
  end
  return true
end

local function _shieldbreak_state(tgt)
  local row = _target_state(tgt)
  if not row then return nil end
  row.shieldbreak = row.shieldbreak or {
    pending = false,
    sent_at = 0,
    last_result = "",
    fail_count = 0,
    summon_attempts = 0,
    gremlin_skip_until = 0,
    cooldown_until = 0,
    preshield_stage = "",
    preshield_eq_cmd = "",
    preshield_checkpoint = "",
  }
  return row.shieldbreak
end

local function _pending_shieldbreak_target()
  for _, row in pairs(AB.state.targets or {}) do
    if type(row) == "table" and type(row.shieldbreak) == "table" and row.shieldbreak.pending == true then
      return _trim(row.name or "")
    end
  end
  return ""
end

_current_target_matches = function(name)
  return _same_target(_target(), name)
end

local function _shieldbreak_release(tgt, result)
  local SB = _shieldbreak_state(tgt)
  if not SB then return false end
  SB.pending = false
  SB.sent_at = 0
  SB.last_result = tostring(result or "")
  SB.cooldown_until = 0
  if result == "success" or result == "no_shield" or result == "other_break" then
    SB.fail_count = 0
  end
  if _trim(SB.preshield_stage) ~= "" then
    AB.state.resume_checkpoint = _trim(SB.preshield_stage)
  elseif _trim(SB.preshield_checkpoint) ~= "" then
    AB.state.resume_checkpoint = _trim(SB.preshield_checkpoint)
  end
  AB.state.resume_checkpoint_at = _now()
  return true
end

local function _shieldbreak_timeout(tgt)
  local SB = _shieldbreak_state(tgt)
  if not SB or SB.pending ~= true then return false end
  SB.pending = false
  SB.last_result = "timeout"
  SB.sent_at = 0
  SB.fail_count = tonumber(SB.fail_count or 0) + 1
  SB.cooldown_until = _now() + 1.25
  return true
end

local function _shieldbreak_entity_missing(tgt)
  local SB = _shieldbreak_state(tgt)
  if not SB then return false end
  SB.pending = false
  SB.sent_at = 0
  SB.last_result = "entity_missing"
  SB.fail_count = tonumber(SB.fail_count or 0) + 1
  SB.summon_attempts = tonumber(SB.summon_attempts or 0) + 1
  SB.cooldown_until = _now() + 1.25
  if tonumber(SB.fail_count or 0) >= 2 then
    SB.gremlin_skip_until = _now() + 5.0
  end
  _queue_free_recovery("summon gremlin")
  return true
end

local function _shieldbreak_sync(tgt)
  local SB = _shieldbreak_state(tgt)
  if not SB or SB.pending ~= true then return false end

  if _shield_is_up(tgt) ~= true then
    return _shieldbreak_release(tgt, "other_break")
  end
  if (_now() - tonumber(SB.sent_at or 0)) > 2.25 then
    return _shieldbreak_timeout(tgt)
  end
  return false
end

local function _eq_wasted_by_shield(cmd, cat)
  cmd = _lc(cmd)
  cat = tostring(cat or "")
  if cmd == "" then return false end
  if cat == "cleanseaura_window" and cmd:match("^readaura%s+") then return false end
  if cat == "mental_build" and (cmd == "unnamable speak" or cmd == "unnamable vision") then return false end
  return cmd:match("^instill%s+")
      or cmd:match("^devolve%s+")
      or cmd:match("^regress%s+")
      or cmd:match("^enervate%s+")
      or cmd:match("^cleanseaura%s+")
      or cmd:match("^whisperingmadness%s+")
      or cmd:match("^pinchaura%s+")
      or cmd:match("^utter%s+truename%s+")
end

local function _note_eq_failure(kind, line)
  AB.state.self_gate = AB.state.self_gate or {}
  local SG = AB.state.self_gate
  local now = _now()
  local cd = tonumber(AB.cfg.eq_retry_cooldown_s or 1.2) or 1.2
  SG.retry_until = math.max(tonumber(SG.retry_until or 0) or 0, now + cd)
  SG.last_failure_line = tostring(line or SG.last_failure_line or "")

  if kind == "not_standing" then
    SG.not_standing_until = math.max(tonumber(SG.not_standing_until or 0) or 0, now + cd)
  elseif kind == "arms_unusable" then
    SG.arms_until = math.max(tonumber(SG.arms_until or 0) or 0, now + cd)
  elseif kind == "bound" then
    SG.bound_until = math.max(tonumber(SG.bound_until or 0) or 0, now + cd)
  end
end

local function _install_runtime_hooks()
  if AB._hooks_installed == true then return true end
  if type(tempRegexTrigger) ~= "function" then return false end

  AB._hook_ids = AB._hook_ids or {}
  AB._hook_ids.eq_not_standing = tempRegexTrigger([[^You must be standing first\.$]], function()
    _note_eq_failure("not_standing", "You must be standing first.")
  end)
  AB._hook_ids.eq_arms = tempRegexTrigger([[^[Bb]oth of your arms must be whole and unbound.*$]], function()
    _note_eq_failure("arms_unusable", "both of your arms must be whole and unbound")
  end)
  AB._hook_ids.eq_bound = tempRegexTrigger([[^(?:You are .*?(?:bound|webbed|entangled|transfixed|impaled).*|You must first writhe free.*)$]], function()
    _note_eq_failure("bound", "bound")
  end)
  AB._hook_ids.sb_success = tempRegexTrigger([[^You command your gremlin to shatter the defences surrounding ([\w'\-]+)\.$]], function()
    _shieldbreak_release(matches[2], "success")
  end)
  AB._hook_ids.sb_no_shield = tempRegexTrigger([[^([\w'\-]+) has no shield for your gremlin to shatter, occultist\.$]], function()
    _shieldbreak_release(matches[2], "no_shield")
  end)
  AB._hook_ids.sb_missing_entity = tempRegexTrigger([[^You have no such entity here\.$]], function()
    local pending_tgt = _pending_shieldbreak_target()
    if pending_tgt ~= "" then
      _shieldbreak_entity_missing(pending_tgt)
    end
  end)
  AB._hook_ids.enemy_bloodroot = tempRegexTrigger([[^([\w'\-]+) eats a bloodroot leaf\.$]], function()
    _note_para_cure_evidence(matches[2], "bloodroot")
  end)
  AB._hook_ids.enemy_magnesium = tempRegexTrigger([[^([\w'\-]+) eats a magnesium chip\.$]], function()
    _note_para_cure_evidence(matches[2], "magnesium")
  end)
  AB._hook_ids.enemy_bayberry = tempRegexTrigger([[^([\w'\-]+) eats some bayberry bark\.$]], function()
    if _current_target_matches(matches[2]) then
      _unnamable_set_reopen(matches[2], "can_see", "bayberry bark")
    end
  end)
  AB._hook_ids.enemy_arsenic = tempRegexTrigger([[^([\w'\-]+) eats an arsenic pellet\.$]], function()
    if _current_target_matches(matches[2]) then
      _unnamable_set_reopen(matches[2], "can_see", "arsenic pellet")
    end
  end)
  AB._hook_ids.enemy_hawthorn = tempRegexTrigger([[^([\w'\-]+) eats a hawthorn berry\.$]], function()
    if _current_target_matches(matches[2]) then
      _unnamable_set_reopen(matches[2], "can_hear", "hawthorn berry")
    end
  end)
  AB._hook_ids.enemy_calamine = tempRegexTrigger([[^([\w'\-]+) eats a calamine crystal\.$]], function()
    if _current_target_matches(matches[2]) then
      _unnamable_set_reopen(matches[2], "can_hear", "calamine crystal")
    end
  end)
  AB._hooks_installed = true
  return true
end

local function _set_loop_enabled(on)
  local enabled = (on == true)
  AB.state.enabled = enabled
  AB.state.loop_enabled = enabled
  AB.cfg.enabled = enabled
  AB.state.loop_delay = tonumber(AB.state.loop_delay or AB.cfg.loop_delay or 0.15) or 0.15
  AB.state.waiting = AB.state.waiting or { queue = nil, main_lane = nil, lanes = nil, at = 0 }
  AB.state.last_attack = AB.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil }
  return enabled
end

local function _clear_waiting()
  AB.state.waiting = AB.state.waiting or {}
  AB.state.waiting.queue = nil
  AB.state.waiting.main_lane = nil
  AB.state.waiting.lanes = nil
  AB.state.waiting.at = 0
end

local function _remember_attack(cmd, payload)
  local meta = type(payload) == "table" and (payload.meta or {}) or {}
  local main_lane = _lc(meta.main_lane or "")
  local lanes = _waiting_lanes_from_payload(payload)
  AB.state.last_attack = AB.state.last_attack or {}
  AB.state.last_attack.cmd = _trim(cmd)
  AB.state.last_attack.at = _now()
  AB.state.last_attack.target = _trim(type(payload) == "table" and payload.target or "")
  AB.state.last_attack.main_lane = main_lane
  AB.state.last_attack.lanes = lanes
  AB.state.waiting = AB.state.waiting or {}
  AB.state.waiting.queue = AB.state.last_attack.cmd
  AB.state.waiting.main_lane = main_lane
  AB.state.waiting.lanes = lanes
  AB.state.waiting.at = AB.state.last_attack.at
end

local function _waiting_blocks_tick()
  local wait = AB.state.waiting or {}
  local queued = _trim(wait.queue)
  if queued == "" then
    if type(AB.state.explain) == "table" and type(AB.state.explain.waiting) == "table" then
      AB.state.explain.waiting.active = false
      AB.state.explain.waiting.queue = ""
      AB.state.explain.waiting.main_lane = ""
      AB.state.explain.waiting.lanes = {}
      AB.state.explain.waiting.age = 0
    end
    return false
  end

  local age = math.max(0, _now() - (tonumber(wait.at) or _now()))
  if (_now() - (tonumber(wait.at) or 0)) >= 3.0 then
    _clear_waiting()
    return false
  end

  if type(AB.state.explain) ~= "table" then AB.state.explain = {} end
  AB.state.explain.route = AB.state.explain.route or "occ_aff_burst"
  AB.state.explain.target = AB.state.explain.target or AB.state.last_target or _target()
  AB.state.explain.resume_checkpoint = AB.state.explain.resume_checkpoint or AB.state.resume_checkpoint
  AB.state.explain.debug = (AB.debug and AB.debug.enabled == true) or false
  AB.state.explain.waiting = {
    active = true,
    queue = queued,
    main_lane = _lc(wait.main_lane or ""),
    lanes = (type(wait.lanes) == "table") and wait.lanes or {},
    age = age,
  }

  local lanes = wait.lanes
  if type(lanes) == "table" and #lanes > 0 then
    for i = 1, #lanes do
      if not _lane_ready(lanes[i]) then
        return true
      end
    end
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
  local last = AB.state.last_attack or {}
  if _trim(last.cmd) ~= cmd then return false end
  local hot_window = math.max(0.20, (tonumber(AB.state.loop_delay or AB.cfg.loop_delay or 0.15) or 0.15) + 0.05)
  return (_now() - (tonumber(last.at) or 0)) < hot_window
end

_payload_line = function(payload)
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

local function _send_loyals_passive(reason)
  local cmd = _trim(tostring(AB.cfg.off_passive_cmd or "order loyals passive"))
  if cmd == "" then return false end
  local ok = _safe_send(cmd)
  return ok == true
end

local function _mark_loyals_for_target(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return end
  AB.state.loyals_sent_for = tgt
  _set_loyals_hostile(true, tgt)
end

local function _lane_contains_cmd(lane, want)
  want = _trim(want)
  if want == "" then return false end
  if type(lane) == "string" then
    return _trim(lane) == want
  end
  if type(lane) == "table" then
    for i = 1, #lane do
      if _trim(lane[i]) == want then return true end
    end
  end
  return false
end

local function _dop_state(tgt)
  if not (Yso and Yso.dop and type(Yso.dop.get_state) == "function") then return nil end
  local ok, v = pcall(Yso.dop.get_state, tgt)
  if ok and type(v) == "table" then return v end
  return nil
end

local function _anti_tumble_plan(tgt)
  local st = _dop_state(tgt)
  local active = (type(st) == "table") and (st.remote_lust_pending == true or st.remote_lust_followup == true) or false
  local out = {
    active = active,
    state = st,
    free_cmd = nil,
    free_cat = nil,
    free_tag = nil,
    bal_cmd = nil,
    bal_cat = nil,
    bal_tag = nil,
  }
  if tgt == "" or active ~= true then return out end

  if st.remote_lust_pending == true then
    out.free_cmd = ("outd lust&&order doppleganger seek %s&&order doppleganger channel fling lust at %s"):format(tgt, tgt)
    out.free_cat = "anti_tumble"
    out.free_tag = "ab:free:anti:dop:" .. _lc(tgt)
    return out
  end

  if st.remote_lust_followup == true and st.ally == true and _bal_ready() then
    out.bal_cmd = ("fling lust at %s"):format(tgt)
    out.bal_cat = "anti_tumble"
    out.bal_tag = "ab:bal:anti:lust:" .. _lc(tgt)
  end

  return out
end

local function _ak_shield_is_up(tgt)
  local ak = rawget(_G, "ak")
  if type(ak) ~= "table" then return nil end

  if type(ak.shield) == "function" then
    local ok, v = pcall(ak.shield, tgt)
    if ok then
      if type(v) == "boolean" then return v end
      if tonumber(v) ~= nil then return tonumber(v) ~= 0 end
    end
  end

  local defs = ak.defs
  if type(defs) ~= "table" then return nil end
  local s = defs.shield
  if type(s) == "boolean" then
    return s == true
  elseif type(s) == "table" then
    local key = _trim(tgt)
    local low = _lc(tgt)
    if s[key] ~= nil then return s[key] == true end
    if s[low] ~= nil then return s[low] == true end
  end

  return nil
end

_shield_is_up = function(tgt)
  local ak_state = _ak_shield_is_up(tgt)
  if ak_state ~= nil then return ak_state end

  if Yso and Yso.shield and type(Yso.shield.is_up) == "function" then
    local ok, v = pcall(Yso.shield.is_up, tgt)
    if ok and v == true then return true end
  end

  return false
end

local function _shieldbreak_plan(tgt, proposed_cat, proposed_cmd)
  if tgt == "" or not _eq_ready() then return nil, nil, nil, nil end

  local SB = _shieldbreak_state(tgt)
  if not SB then return nil, nil, nil, nil end
  if SB.pending == true then return nil, nil, nil, nil end
  if _shield_is_up(tgt) ~= true then return nil, nil, nil, nil end
  if _eq_wasted_by_shield(proposed_cmd, proposed_cat) ~= true then return nil, nil, nil, nil end

  local now = _now()
  if now < tonumber(SB.gremlin_skip_until or 0) then
    SB.last_result = "skipped"
    return nil, nil, nil, nil
  end
  if now < tonumber(SB.cooldown_until or 0) then
    return nil, nil, nil, nil
  end

  local tag = "ab:eq:shieldbreak:" .. _lc(tgt)
  local lock = tonumber(AB.cfg.shieldbreak_lockout_s or 1.0) or 1.0
  if _recent_sent(tag, lock) then return nil, nil, nil, nil end

  SB.pending = true
  SB.sent_at = now
  SB.preshield_stage = tostring(proposed_cat or "")
  SB.preshield_eq_cmd = _trim(proposed_cmd)
  SB.preshield_checkpoint = tostring(AB.state.resume_checkpoint or "")

  local cmd = ""
  if Yso and Yso.off and Yso.off.util and type(Yso.off.util.maybe_shieldbreak) == "function" then
    local ok, v = pcall(Yso.off.util.maybe_shieldbreak, tgt)
    cmd = _trim(ok and v or "")
  end
  if cmd == "" then
    cmd = ("command gremlin at %s"):format(tgt)
  end

  return cmd, "defense_break", tag, lock
end

local function _entity_plan(tgt, plan, pair)
  if not _ent_ready() then return nil, nil end

  local ES = _entity_refresh_state(tgt)
  local ER = ES.registry
  if ER and type(ER.target_swap) == "function" then pcall(ER.target_swap, tgt) end

  pair = pair or _entity_pair(tgt, plan, {
    eq_available = _eq_ready(),
    entity_available = true,
    bm_branch_active = (plan and plan.bm_branch_active == true),
  })
  if pair.entity_cmd then
    return pair.entity_cmd, pair.entity_cat or "mana_bury"
  end

  return nil, nil
end

local function _bal_plan(tgt, plan)
  if not _bal_ready() then return nil, nil end

  if not _has_aff(tgt, "manaleech") then
    if _mana_bury_ready(tgt) ~= true then
      return nil, nil
    end
    return ("outd lovers&&ruinate lovers at %s"):format(tgt), "mana_bury",
      "ab:bal:manaleech:" .. _lc(tgt), 3.0
  end

  if _lock_stable(tgt) ~= true then
    return nil, nil
  end

  if _class_defense_gates(plan) then
    return nil, nil
  end
  if plan and (plan.finish_stage == "transition" or plan.finish_stage == "burst") then
    return nil, nil
  end

  if _focus_lock_needs_moon(tgt) then
    local moon_tag = "ab:bal:moon:" .. _lc(tgt)
    if not _recent_sent(moon_tag, tonumber(AB.cfg.moon_lockout_s or 4.5) or 4.5) then
      return ("outd moon&&fling moon at %s"):format(tgt), "mental_build", moon_tag, tonumber(AB.cfg.moon_lockout_s or 4.5)
    end
  end

  return nil, nil
end
local function _burst_ready(tgt)
  if not _truebook_can_utter(tgt) then return false end
  if not _has_aff(tgt, "whisperingmadness") and not _has_aff(tgt, "whispering_madness") then return false end
  return _enlighten_score() >= tonumber(AB.cfg.enlighten_target or 5)
end

local function _chimera_pressure_pair_active(tgt, plan)
  if type(plan) ~= "table" then return false end
  if plan.deaf == true then return false end
  if tostring(plan.finish_stage or "") ~= "pressure" then return false end
  return _chimera_pool_complete(tgt) ~= true
end

local function _anorexia_fallback_due(tgt, plan)
  if type(plan) ~= "table" then return false end
  if plan.cleanseaura_ready == true or plan.needs_mana_bury ~= true then return false end
  if _has_aff(tgt, "manaleech") ~= true or _has_aff(tgt, "disloyalty") ~= true then return false end
  if _has_aff(tgt, "anorexia") == true then return false end
  local mana = tonumber(plan.mana_pct or nil)
  local cap = tonumber(CS.cfg.mana_burst_pct or 40) or 40
  if mana == nil or mana <= (cap + 12) then return false end
  local key = _lc(tgt)
  if not _recent_sent("ab:eq:devolve:" .. key, 8.0) then return false end
  if not _recent_sent("ab:eq:enervate:" .. key, 9.0) then return false end
  return true
end

-- _readaura_tag, _aura_txn_active_for, _missing_key, _should_probe_readaura,
-- _readaura_plan, _bootstrap_readaura_plan moved to occ_aura_planner.lua (AP.*)

local function _eq_plan(tgt, plan, gate)
  if not _eq_ready() then return nil, nil, nil, nil end

  local burst_ready = _burst_ready(tgt)
  local has_wm = _has_aff(tgt, "whisperingmadness") or _has_aff(tgt, "whispering_madness")
  local has_manaleech = _has_aff(tgt, "manaleech")
  local bootstrap_cmd, bootstrap_cat, bootstrap_tag, bootstrap_lock = AP.bootstrap_readaura_plan(tgt, plan)
  if bootstrap_cmd then
    return bootstrap_cmd, bootstrap_cat, bootstrap_tag, bootstrap_lock
  end
  local readaura_cmd, readaura_cat, readaura_tag, readaura_lock = AP.readaura_plan(tgt, plan, burst_ready)

  if readaura_cmd then
    return readaura_cmd, readaura_cat, readaura_tag, readaura_lock
  end

  local cs_cmd, cs_cat, cs_tag, cs_lock = AP.cleanseaura_plan(tgt, plan, gate)
  if cs_cmd then
    return cs_cmd, cs_cat, cs_tag, cs_lock
  end

  if _truebook_can_utter(tgt) and not has_wm and _has_any_required_insanity(tgt) then
    return ("whisperingmadness %s"):format(tgt), "mental_build", "ab:eq:wm:" .. _lc(tgt), 2.3
  end

  if burst_ready then
    if plan.needs_speed_strip and not _recent_sent(_pin_tag(tgt), tonumber(AB.cfg.speed_hold_s or 3.2)) then
      return ("pinchaura %s speed"):format(tgt), "speed_strip_window", _pin_tag(tgt), tonumber(AB.cfg.pinchaura_lockout_s or 4.1)
    end
    if (plan.speed == false or _recent_sent(_pin_tag(tgt), tonumber(AB.cfg.speed_hold_s or 3.2))) then
      return ("utter truename %s"):format(tgt), "reserved_burst", _utter_tag(tgt), tonumber(AB.cfg.utter_follow_s or 5.0)
    end
  end

  if plan.needs_mana_bury and has_manaleech then
    if not _has_aff(tgt, "disloyalty") then
      return ("devolve %s"):format(tgt), "mana_bury", "ab:eq:devolve:" .. _lc(tgt), 2.5
    end
    if _chimera_pressure_pair_active(tgt, plan) and _ent_ready() and not _class_defense_gates(plan) then
      return nil, nil, nil, nil
    end
    if _anorexia_fallback_due(tgt, plan) then
      return ("regress %s"):format(tgt), "mana_bury", "ab:eq:regress:" .. _lc(tgt), 2.5
    end
    return ("enervate %s"):format(tgt), "mana_bury", "ab:eq:enervate:" .. _lc(tgt), 4.0
  end

  local attend_cmd, attend_cat, attend_tag, attend_lock = _unnamable_attend_plan(tgt, plan)
  if attend_cmd then
    return attend_cmd, attend_cat, attend_tag, attend_lock
  end

  local unnamable = _unnamable_candidate(tgt, plan)
  if unnamable and _trim(unnamable.cmd) ~= "" then
    return unnamable.cmd, "mental_build", "ab:eq:unnamable:" .. _lc(tgt), 4.0
  end

  local sm_cmd, sm_tag = _soulmaster_order_cmd(tgt)
  if sm_cmd then
    return sm_cmd, "mana_bury", sm_tag, 4.0
  end

  return nil, nil, nil, nil
end

local function _mana_bury_eq_cmd(tgt, aff)
  aff = _lc(aff)
  if aff == "asthma" or aff == "slickness" or aff == "paralysis" or aff == "healthleech" or aff == "clumsiness" then
    return ("instill %s with %s"):format(tgt, aff), "mana_bury", "ab:eq:instill:" .. _lc(tgt) .. ":" .. aff, 2.5
  end
  if aff == "disloyalty" then
    return ("devolve %s"):format(tgt), "mana_bury", "ab:eq:devolve:" .. _lc(tgt), 2.5
  end
  if aff == "anorexia" then
    return ("regress %s"):format(tgt), "mana_bury", "ab:eq:regress:" .. _lc(tgt), 2.5
  end
  return nil, nil, nil, nil
end

local function _mana_bury_entity_aff(tgt, predicted)
  predicted = _lc(predicted)
  if not _has_aff(tgt, "asthma") then return "asthma" end
  if not _has_bloodroot_hold(tgt) then
    if predicted == "paralysis" then return "paralysis" end
    if predicted == "slickness" then return "slickness" end
    return "slickness"
  end
  if not _has_aff(tgt, "healthleech") then return "healthleech" end
  if predicted == "paralysis" then return "paralysis" end
  if predicted == "slickness" then return "slickness" end
  return nil
end

local function _mana_bury_eq_aff(tgt, entity_aff, predicted)
  predicted = _lc(predicted)
  entity_aff = _lc(entity_aff)
  if predicted == "asthma" and entity_aff ~= "asthma" and not _has_aff(tgt, "asthma") then
    return "asthma"
  end
  if (predicted == "slickness" or predicted == "paralysis")
    and (
      (_has_aff(tgt, "asthma") and not _has_bloodroot_hold(tgt) and entity_aff == "")
      or (entity_aff == "asthma")
    )
  then
    return predicted
  end
  if predicted == "healthleech" and not _has_aff(tgt, "healthleech") and entity_aff ~= "healthleech" then
    return "healthleech"
  end

  if not _has_aff(tgt, "asthma") and entity_aff ~= "asthma" then
    return "asthma"
  end
  if not _has_bloodroot_hold(tgt) then
    if entity_aff == "asthma" then return "paralysis" end
    if entity_aff == "slickness" then return "paralysis" end
    return "slickness"
  end
  if not _has_aff(tgt, "healthleech") and entity_aff ~= "healthleech" then
    return "healthleech"
  end
  return nil
end

local function _chimera_pressure_eq_aff(tgt, entity_aff)
  entity_aff = _lc(entity_aff)
  if not _has_aff(tgt, "disloyalty") then return "disloyalty" end
  if not _has_aff(tgt, "healthleech") and entity_aff ~= "healthleech" then return "healthleech" end
  if not _has_aff(tgt, "asthma") and entity_aff ~= "asthma" then return "asthma" end
  if not _has_bloodroot_hold(tgt) then
    if entity_aff == "slickness" then return "paralysis" end
    return "slickness"
  end
  if not _has_aff(tgt, "clumsiness") then return "clumsiness" end
  return nil
end

local function _route_pair_plan(tgt, plan)
  local out = {
    eq_cmd = nil, eq_cat = nil, eq_tag = nil, eq_lock = nil,
    eq_aff = nil,
    entity_cmd = nil, entity_cat = nil,
    entity_aff = nil,
    compensate_aff = nil,
    reason = "",
  }

  local ES = _entity_refresh_state(tgt)
  local ent_ready = _ent_ready()
  local eq_ready = _eq_ready()
  local has_manaleech = _has_aff(tgt, "manaleech")
  local has_wm = _has_aff(tgt, "whisperingmadness") or _has_aff(tgt, "whispering_madness")
  local predicted_mana = _predict_mana_bury_aff(tgt, plan)
  local predicted_focus = _predict_focus_lock_aff(tgt, plan)
  local chimera_pair_pressure = _chimera_pressure_pair_active(tgt, plan)

  if has_manaleech ~= true then
    if ent_ready then
      local entity_aff = _mana_bury_entity_aff(tgt, predicted_mana)
      if entity_aff then
        out.entity_cmd, out.entity_cat = _entity_aff_cmd(entity_aff, tgt, ES)
        out.entity_aff = entity_aff
      end
    end

    if eq_ready then
      local eq_aff = _mana_bury_eq_aff(tgt, out.entity_aff or "", predicted_mana)
      if eq_aff then
        out.eq_cmd, out.eq_cat, out.eq_tag, out.eq_lock = _mana_bury_eq_cmd(tgt, eq_aff)
        out.eq_aff = eq_aff
        out.compensate_aff = eq_aff
      end
    end

    if out.eq_aff or out.entity_aff then
      out.reason = predicted_mana ~= nil and ("mana_bury_predict:" .. predicted_mana) or "mana_bury_setup"
    else
      out.reason = (_mana_bury_ready(tgt) == true) and "mana_bury_payoff_window" or "mana_bury_wait"
    end
    return out
  end

  if ent_ready
    and not (plan and (plan.finish_stage == "transition" or plan.finish_stage == "burst"))
    and not _class_defense_gates(plan)
  then
    if plan and plan.needs_attend == true then
      out.entity_cmd = ("command chimera at %s"):format(tgt)
      out.entity_cat = "mental_build"
      out.entity_aff = "chimera_command"
      out.reason = "attend_deaf_chimera"
    elseif chimera_pair_pressure then
      out.entity_cmd = ("command chimera at %s"):format(tgt)
      out.entity_cat = "mental_build"
      out.entity_aff = "chimera_command"
      out.reason = "chimera_pressure_pair"
    elseif (plan and plan.needs_chimera == true) or _focus_lock_chimera_desired(tgt) or _focus_lock_in_chimera_pool(predicted_focus) then
      local hearing_target = not (plan and plan.deaf == true)
      local chimera_pool_full = hearing_target and _chimera_pool_complete(tgt)
      if chimera_pool_full then
        local filler_aff, filler_cmd, filler_cat = _entity_filler_plan(tgt, ES)
        if _trim(filler_cmd) ~= "" then
          out.entity_cmd = filler_cmd
          out.entity_cat = filler_cat
          out.entity_aff = filler_aff
          out.reason = "chimera_filler:" .. tostring(filler_aff)
        end
      end
      if out.entity_cmd == nil then
        out.entity_cmd = ("command chimera at %s"):format(tgt)
        out.entity_cat = "mental_build"
        out.entity_aff = "chimera_command"
        out.reason = _focus_lock_in_chimera_pool(predicted_focus) and ("focus_lock_predict:" .. predicted_focus) or "focus_lock_chimera"
      end
    elseif ES.syc_refresh == true and has_wm ~= true and plan and plan.cleanseaura_ready ~= true then
      out.entity_cmd = ("command sycophant at %s"):format(tgt)
      out.entity_cat = "mental_build"
      out.entity_aff = "sycophant"
      out.reason = "focus_lock_sycophant"
    end
  end

  if eq_ready and has_manaleech == true and chimera_pair_pressure and out.eq_cmd == nil and out.entity_aff == "chimera_command" then
    local eq_aff = _chimera_pressure_eq_aff(tgt, out.entity_aff or "")
    if eq_aff then
      out.eq_cmd, out.eq_cat, out.eq_tag, out.eq_lock = _mana_bury_eq_cmd(tgt, eq_aff)
      out.eq_aff = eq_aff
      out.compensate_aff = eq_aff
      if out.reason == "" then out.reason = "chimera_pressure_pair" end
    end
  end

  return out
end

local function _focus_lock_giving_sources(tgt, plan)
  local predicted = _predict_focus_lock_aff(tgt, plan)
  local out = {}
  if _focus_lock_chimera_desired(tgt) or _focus_lock_in_chimera_pool(predicted) then
    out[#out + 1] = "chimera_command"
  end
  if _focus_lock_needs_moon(tgt) or _focus_lock_in_moon_pool(predicted) then
    out[#out + 1] = "moon"
  end
  local unnamable = _unnamable_candidate(tgt, plan)
  if unnamable and unnamable.eligible == true then
    out[#out + 1] = "unnamable"
  end
  if _discord_contribution_present(tgt) then
    out[#out + 1] = "discord"
  end
  return out
end
local function _ensure_predict_enabled()
  local P = Yso and Yso.predict or nil
  if type(P) ~= "table" then return false end
  if P.enabled == true then return true end
  P.enabled = true
  if type(P.wire) == "function" then pcall(P.wire) end
  AB.state = AB.state or {}
  AB.state.predict_bootstrapped = true
  return true
end

local function _release_predict_if_bootstrapped()
  AB.state = AB.state or {}
  if AB.state.predict_bootstrapped ~= true then return false end
  local P = Yso and Yso.predict or nil
  if type(P) == "table" then
    if type(P.unwire) == "function" then pcall(P.unwire) end
    P.enabled = false
  end
  AB.state.predict_bootstrapped = false
  return true
end

local function _kill_loop_timer()
  if AB.state and AB.state.timer_id then
    pcall(killTimer, AB.state.timer_id)
    AB.state.timer_id = nil
  end
end

function AB.schedule_loop(delay)
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    return Yso.mode.schedule_route_loop("occ_aff_burst", delay)
  end
  return false
end

AB.alias_loop_stop_details = AB.alias_loop_stop_details or {
  inactive = true,
  disabled = true,
}

function AB.alias_loop_prepare_start(ctx)
  AB.init()
  pcall(_install_runtime_hooks)
  ctx = ctx or {}
  ctx.runtime_ready = true
  return ctx
end

function AB.alias_loop_on_started(ctx)
  ctx = ctx or {}
  _ensure_predict_enabled()
  AB.state.busy = false
  _clear_waiting()

  if AB.cfg.echo == true and type(cecho) == "function" then
    if ctx.runtime_ready ~= true then
      cecho("<HotPink>[Occultism] <reset>aff runtime bootstrap incomplete; using local fallback state.\n")
    end
    cecho("<dark_orchid>[Occultism] <aquamarine>aff loop ON<reset>\n")

    local armed_tgt = _trim(_target())
    local armed_invalid = false
    if armed_tgt ~= "" then
      if type(Yso.target_is_valid) == "function" then
        local ok, v = pcall(Yso.target_is_valid, armed_tgt)
        if ok then armed_invalid = (v ~= true) end
      end
      if armed_invalid then
        cecho(string.format("<HotPink>[Occultism] <reset>%s is not in room; waiting for a valid target.\n", armed_tgt))
      end
    end
  end
end

function AB.alias_loop_on_stopped(ctx)
  AB.init()
  ctx = ctx or {}
  local reason = tostring(ctx.reason or "manual")

  if _loyals_any_active() then
    _send_loyals_passive("occ_aff_burst:" .. reason)
    _clear_loyals_hostile()
  else
    _clear_loyals_hostile()
  end
  _release_predict_if_bootstrapped()

  if ctx.silent ~= true and AB.cfg.echo == true and type(cecho) == "function" then
    cecho(string.format("<dark_orchid>[Occultism] <yellow>aff loop OFF<reset> (%s)\n", reason))
  end
end

function AB.alias_loop_clear_waiting()
  return _clear_waiting()
end

function AB.alias_loop_waiting_blocks()
  return _waiting_blocks_tick()
end

function AB.alias_loop_on_error(err)
  if AB.cfg.echo == true and type(cecho) == "function" then
    cecho(string.format("<HotPink>[Occultism] <reset>aff loop error: %s\n", tostring(err)))
  end
end

------------------------------------------------------------
-- Template Contract Facade
------------------------------------------------------------
function AB.init()
  AB.cfg = AB.cfg or {}
  AB.state = AB.state or {}
  AB.state.loyals_sent_for = _trim(AB.state.loyals_sent_for or "")
  AB.state.template = AB.state.template or { last_reason = "init", last_disable_reason = "", last_payload = nil }
  AB.state.self_gate = AB.state.self_gate or { retry_until = 0, not_standing_until = 0, arms_until = 0, bound_until = 0, last_failure_line = "" }
  AB.state.pending_free = AB.state.pending_free or {}
  AB.state.targets = AB.state.targets or {}
  AB.state.waiting = AB.state.waiting or { queue = nil, main_lane = nil, lanes = nil, at = 0 }
  AB.state.last_attack = AB.state.last_attack or { cmd = "", at = 0, target = "", main_lane = "", lanes = nil }
  AB.state.busy = (AB.state.busy == true)
  AB.state.loop_delay = tonumber(AB.state.loop_delay or AB.cfg.loop_delay or 0.15) or 0.15
  _set_loop_enabled((AB.state.loop_enabled == true) or (AB.state.enabled == true))
  pcall(_install_runtime_hooks)
  return true
end
function AB.reset(reason)
  AB.init()
  AB.state.explain = {}
  AB.state.last_target = ""
  AB.state.resume_checkpoint = "mana_bury"
  AB.state.resume_checkpoint_at = 0
  AB.state.truename_entry_stable_pulses = 0
  AB.state.busy = false
  _clear_waiting()
  AB.state.pending_free = {}
  AB.state.last_attack = { cmd = "", at = 0, target = "", main_lane = "", lanes = nil }
  AB.state.template.last_reason = tostring(reason or "manual")
  AB.state.template.last_payload = nil
  return true
end

function AB.is_enabled()
  return AB.state and AB.state.enabled == true
end

function AB.is_active()
  return _route_active()
end

function AB.can_run(ctx)
  AB.init()
  if not AB.is_enabled() then return false, "disabled" end
  if not AB.is_active() then return false, "inactive" end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return false, "paused" end
  if Yso and Yso.mode and type(Yso.mode.is_hunt) == "function" and Yso.mode.is_hunt() then return false, "hunt_mode" end
  if Yso and Yso.mode and type(Yso.mode.is_party) == "function" and Yso.mode.is_party() then return false, "party_mode" end
  local tgt = _trim((ctx and ctx.target) or _target())
  if tgt == "" then return false, "no_target" end

  local invalid = false
  if type(Yso.target_is_valid) == "function" then
    local ok, v = pcall(Yso.target_is_valid, tgt)
    if ok and v ~= true then invalid = true end
  end

  if invalid then
    AB.state = AB.state or {}
    local last_echo = tonumber(AB.state.last_invalid_echo_at or 0) or 0
    if (_now() - last_echo) >= 5 then
      AB.state.last_invalid_echo_at = _now()
      if AB.cfg.echo == true and type(cecho) == "function" then
        cecho(string.format("<HotPink>[Occultism] <reset>%s is not in room; holding.\n", tgt))
      end
    end
    return false, "invalid_target"
  end

  return true, tgt
end

local function _attack_opts(arg)
  if type(arg) == "table" and (arg.preview ~= nil or arg.ctx ~= nil) then
    return arg.ctx, (arg.preview == true)
  end
  return arg, false
end

function AB.attack_function(arg)
  local ctx, preview = _attack_opts(arg)
  local ok, info = AB.can_run(ctx)
  if not ok then
    if preview then return nil, info end
    return false, info
  end

  local tgt = info
  local loyals_bootstrap_pending = (_trim(select(1, _loyals_open_cmd(tgt))) ~= "")
  local plan = CS.plan_aff(tgt)
  plan.loyals_bootstrap_pending = (loyals_bootstrap_pending == true)
  if loyals_bootstrap_pending then
    plan.needs_readaura = true
    plan.readaura_via_loyals = true
    plan.snapshot_fresh = false
  end
  local anti = _anti_tumble_plan(tgt)
  plan.finish = _finish_view(tgt, plan)
  plan.finish_stage = plan.finish and plan.finish.stage or "pressure"
  plan.finish_transition_active = plan.finish_stage == "transition" or plan.finish_stage == "burst"
  _target_state(tgt)
  _unnamable_sync_from_plan(tgt, plan)
  _shieldbreak_sync(tgt)
  local shieldbreak = _shieldbreak_state(tgt)
  local legality = _self_gate_state()
  legality.queue_stand = legality.eq_blocked == true and _lc(table.concat(legality.eq_block_reasons or {}, ",")):find("not standing", 1, true) ~= nil
  local gate = {
    eligible = false,
    stable = false,
    stable_pulses = tonumber(AB.state.truename_entry_stable_pulses or 0) or 0,
    required = tonumber(AB.cfg.truename_branch_stability_pulses or 2) or 2,
  }

  local free_cmd, free_cat, free_tag = anti.free_cmd, anti.free_cat, anti.free_tag
  local eq_cmd, eq_cat, eq_tag, eq_lock = nil, nil, nil, nil
  local bal_cmd, bal_cat, bal_tag, bal_lock = anti.bal_cmd, anti.bal_cat, anti.bal_tag, nil
  local entity_cmd, entity_cat = nil, nil
  local parry_cmd, parry_limb = nil, nil

  -- A. Defensive measures on me.
  -- This route currently has no self-defensive pre-send branch beyond loop invalidation.

  -- B. Main offensive spam logic.
  local raw_eq_cmd, raw_eq_cat, raw_eq_tag, raw_eq_lock = nil, nil, nil, nil
  local pair = nil
  if anti.active ~= true then
    gate = _truename_gate(tgt, plan)
    free_cmd, free_cat = _loyals_open_cmd(tgt)
    free_tag = free_cmd and ("ab:free:loyals:" .. _lc(tgt)) or nil

    if legality.eq_blocked ~= true and not (shieldbreak and shieldbreak.pending == true) then
      raw_eq_cmd, raw_eq_cat, raw_eq_tag, raw_eq_lock = _eq_plan(tgt, plan, gate)
      eq_cmd, eq_cat, eq_tag, eq_lock = _shieldbreak_plan(tgt, raw_eq_cat, raw_eq_cmd)
      if not eq_cmd then
        eq_cmd, eq_cat, eq_tag, eq_lock = raw_eq_cmd, raw_eq_cat, raw_eq_tag, raw_eq_lock
      end
    end

    pair = _route_pair_plan(tgt, plan)

    if not eq_cmd and pair.eq_cmd then
      eq_cmd = pair.eq_cmd
      eq_cat = pair.eq_cat
      eq_tag = pair.eq_tag
      eq_lock = pair.eq_lock
    end

    if pair.entity_cmd then
      entity_cmd = pair.entity_cmd
      entity_cat = pair.entity_cat
    end

    bal_cmd, bal_cat, bal_tag, bal_lock = _bal_plan(tgt, plan)
  end

  if Yso and Yso.parry and type(Yso.parry.next_command) == "function" then
    local ok_parry, cand_cmd, cand_limb = pcall(Yso.parry.next_command, { source = "occ_aff_burst", target = tgt })
    if ok_parry then
      parry_cmd = _trim(cand_cmd)
      parry_limb = _trim(cand_limb)
    end
  end

  local free_recovery_cmd = _take_free_recovery()
  local free_parts = {}
  _append_free_part(free_parts, (legality.queue_stand == true) and "stand" or "", false)
  _append_free_part(free_parts, parry_cmd, false)
  _append_free_part(free_parts, free_recovery_cmd, false)
  _append_free_part(free_parts, free_cmd, true)
  free_cmd = _chain_cmds((legality.queue_stand == true) and "stand" or "", parry_cmd, free_recovery_cmd, free_cmd)
  if legality.queue_stand == true or _trim(parry_cmd) ~= "" then
    free_cat = free_cat or "self_legality"
  end

  local main = _choose_main_lane(eq_cmd, eq_cat, bal_cmd, bal_cat)
  local selected_eq = (main.lane == "eq") and main.cmd or nil
  local selected_bal = (main.lane == "bal") and main.cmd or nil

  if anti.active ~= true and main.lane == "bal" and _trim(selected_eq) == "" and pair and _trim(entity_cmd) == "" then
    local compensate_aff = _lc(pair.compensate_aff or pair.eq_aff)
    if compensate_aff ~= "" and not _has_aff(tgt, compensate_aff) then
      local compensate_cmd, compensate_cat = _entity_aff_cmd(compensate_aff, tgt, _entity_refresh_state(tgt))
      if _trim(compensate_cmd) ~= "" then
        entity_cmd = compensate_cmd
        entity_cat = compensate_cat or pair.entity_cat or "mana_bury"
        pair.entity_aff = compensate_aff
        pair.reason = "bal_compensate:" .. compensate_aff
      end
    end
  end

  -- C. Main lane for wait tracking (EQ is bottleneck in Sunder style).
  local main_lane = main.lane
  if main_lane == "" and _trim(entity_cmd) ~= "" then
    main_lane = "entity"
  end

  -- D. Bookkeeping.
  AB.state.last_target = tgt
  local has_wm = _has_aff(tgt, "whisperingmadness") or _has_aff(tgt, "whispering_madness")
  local required_entities = {
    sycophant = (pair and pair.entity_aff == "sycophant")
      or (entity_cmd == ("command sycophant at %s"):format(tgt))
      or (plan and plan.needs_mana_bury == true and has_wm ~= true)
      or (_has_aff(tgt, "manaleech") and has_wm ~= true and plan and plan.cleanseaura_ready ~= true),
  }
  local unnamable = _unnamable_candidate(tgt, plan)
  local US = _unnamable_state(tgt)
  AB.state.explain = {
    route = "occ_aff_burst",
    debug = AB.debug.enabled == true,
    target = tgt,
    target_class = plan.target_class,
    mana_pct = plan.mana_pct,
    aura_physical = plan.physical,
    aura_mental = plan.mental,
    aura_speed = plan.speed,
    aura_blind = plan.blind,
    aura_deaf = plan.deaf,
    needs_readaura = plan.needs_readaura,
    readaura_reason = plan.readaura_reason or "",
    readaura_via_loyals = plan.readaura_via_loyals == true,
    loyals_bootstrap_pending = plan.loyals_bootstrap_pending == true,
    snapshot_complete = plan.snapshot_complete,
    snapshot_read_complete = plan.snapshot_read_complete,
    snapshot_had_counts = plan.snapshot_had_counts,
    snapshot_had_mana = plan.snapshot_had_mana,
    needs_mana_bury = plan.needs_mana_bury,
    mana_bury_ready = plan.mana_bury_ready == true,
    cleanseaura_ready = plan.cleanseaura_ready,
    sensory_stage = plan.sensory_stage or "",
    sensory_mode = plan.sensory_mode or "",
    sensory_deaf_priority = plan.sensory_deaf_priority == true,
    truename_ready = _truebook_can_utter(tgt),
    truename_entry_eligible = gate.eligible,
    truename_entry_stable = gate.stable,
    truename_entry_stable_pulses = gate.stable_pulses,
    truename_entry_required = gate.required,
    resume_checkpoint = AB.state.resume_checkpoint,
    whisperingmadness = has_wm,
    mental_score = _mental_score(),
    enlighten_score = _enlighten_score(),
    burst_ready = _burst_ready(tgt),
    loyals_active = _loyals_active_for(tgt),
    focus_lock_count = _focus_lock_count(tgt),
    lock_stable = _lock_stable(tgt),
    focus_lock_sources = _focus_lock_giving_sources(tgt, plan),
    manaleech = _has_aff(tgt, "manaleech"),
    chimera_pool_complete = (plan and plan.deaf ~= true) and _chimera_pool_complete(tgt) or false,
    eq_aff = pair and pair.eq_aff or "",
    entity_aff = pair and pair.entity_aff or "",
    pair_reason = pair and pair.reason or "",
    bm_snapshot = (function()
      local BMC = Yso.curing and Yso.curing.blademaster
      if BMC and type(BMC.explain) == "function" then return BMC.explain(plan) end
      return { state = plan.bm_snapshot_state, active = plan.bm_snapshot_active == true }
    end)(),
    bm_branch_active = plan.bm_branch_active == true,
    bm_branch_provisional = plan.bm_branch_provisional == true,
    shield_up = _shield_is_up(tgt),
    shieldbreak_active = (eq_cat == "defense_break"),
    shieldbreak = {
      pending = shieldbreak and shieldbreak.pending == true or false,
      last_result = shieldbreak and shieldbreak.last_result or "",
      fail_count = shieldbreak and tonumber(shieldbreak.fail_count or 0) or 0,
      summon_attempts = shieldbreak and tonumber(shieldbreak.summon_attempts or 0) or 0,
      gremlin_skipped = shieldbreak and (_now() < tonumber(shieldbreak.gremlin_skip_until or 0)) or false,
      preshield_stage = shieldbreak and shieldbreak.preshield_stage or "",
    },
    eq_blocked = legality.eq_blocked == true,
    eq_block_reasons = legality.eq_block_reasons,
    eq_retry_until = legality.retry_until,
    eq_failure_line = legality.last_failure_line,
    para = {
      predicted_next_cure = "",
      confidence = 0,
      lock_maturity = 0,
      allowed = false,
      para_score = 0,
      block_reason = "",
      lane = "",
      last_lane = "",
      last_herb = "",
    },
    unnamable = {
      target = tgt,
      hear = US and US.can_hear or nil,
      see = US and US.can_see or nil,
      attend = US and US.last_attend_status or "",
      ready_in = math.max(0, _clock(US and US.ready_at or 0) - _now()),
      last_mode = US and US.last_mode or "",
      last_cast_at = US and US.last_cast_at or 0,
      last_success_at = US and US.last_success_at or 0,
      allowed = unnamable and unnamable.eligible == true or false,
      block_reason = unnamable and unnamable.block_reason or "",
      mode = unnamable and unnamable.mode or "",
    },
    finish_transition = plan.finish,
    anti_tumble_active = (anti.active == true),
    anti_tumble = anti.state,
    waiting = {
      active = false,
      queue = "",
      main_lane = "",
      lanes = {},
      age = 0,
    },
    planned = { free = free_cmd, eq = selected_eq, bal = selected_bal, entity = entity_cmd },
    categories = {
      free = free_cat,
      eq = (main.lane == "eq") and main.category or nil,
      bal = (main.lane == "bal") and main.category or nil,
      entity = entity_cat,
    },
    main_lane = main_lane,
  }

  if not free_cmd and not eq_cmd and not bal_cmd and not entity_cmd then
    local why = ((anti.active == true) and "anti_tumble_wait" or "empty")
    if preview then return nil, why end
    return false, why
  end

  local payload = {
    route = "occ_aff_burst",
    target = tgt,
    lanes = {
      free = free_cmd,
      eq = selected_eq,
      bal = selected_bal,
      class = entity_cmd,
      entity = entity_cmd,
    },
    meta = {
      free_category = free_cat,
      free_tag = free_tag,
      free_parts = (#free_parts > 0) and free_parts or nil,
      eq_category = (main.lane == "eq") and main.category or nil,
      raw_eq_category = raw_eq_cat,
      eq_tag = eq_tag,
      eq_lockout = eq_lock,
      bal_category = (main.lane == "bal") and main.category or nil,
      bal_tag = bal_tag,
      bal_lockout = bal_lock,
      entity_category = entity_cat,
      checkpoint = AB.state.resume_checkpoint,
      explain = AB.state.explain,
      main_lane = main_lane,
      main_category = main.category,
      parry_cmd = parry_cmd,
      parry_limb = parry_limb,
      required_entities = required_entities,
    },
  }
  payload, _ = _route_gate_finalize(payload, ctx, tgt, required_entities)
  local gate_state = type(payload) == "table" and (payload._route_gate or (payload.meta and payload.meta.route_gate)) or nil
  AB.state.explain.planned = gate_state and gate_state.planned and gate_state.planned.lanes or AB.state.explain.planned
  AB.state.explain.gated = gate_state and gate_state.gated and gate_state.gated.lanes or payload.lanes
  AB.state.explain.blocked_reasons = gate_state and gate_state.blocked_reasons or {}
  AB.state.explain.hindrance = gate_state and gate_state.hinder or {}
  AB.state.explain.required_entities = gate_state and gate_state.entities and gate_state.entities.required or {}
  AB.state.explain.entity_obligations = gate_state and gate_state.entities and gate_state.entities.obligations or {}
  AB.state.explain.emitted = gate_state and gate_state.emitted or {}
  AB.state.explain.confirmed = gate_state and gate_state.confirmed or {}
  AB.state.template.last_payload = payload

  local emit_payload = (Yso and Yso.route_gate and type(Yso.route_gate.payload_for_emit) == "function")
    and Yso.route_gate.payload_for_emit(payload)
    or payload
  local planner_empty = not payload.lanes.free and not payload.lanes.eq and not payload.lanes.bal and not payload.lanes.entity
  local emit_empty = not emit_payload.lanes.free and not emit_payload.lanes.eq and not emit_payload.lanes.bal and not emit_payload.lanes.entity
  if preview then
    if planner_empty then return nil, "empty" end
    return payload
  end
  if emit_empty then return false, "empty" end
  local cmd = _payload_line(emit_payload)
  if _trim(cmd) == "" then return false, "empty" end
  if _same_attack_is_hot(cmd) then return false, "hot_attack" end

  local sent, err = _emit_payload(emit_payload)
  if not sent then
    if eq_cat == "defense_break" then
      local SB = _shieldbreak_state(tgt)
      if SB then
        SB.pending = false
        SB.sent_at = 0
        SB.last_result = "send_failed"
        SB.cooldown_until = _now() + 1.0
      end
    end
    return false, err
  end

  AB.state.template.last_emitted_payload = emit_payload
  if Yso and Yso.route_gate and type(Yso.route_gate.note_emitted) == "function" then
    pcall(Yso.route_gate.note_emitted, payload, emit_payload, ctx)
  end
  _note_payload_tags(emit_payload)
  AB.on_sent(emit_payload, ctx)
  _remember_attack(cmd, emit_payload)
  return true, cmd, payload
end

function AB.build_payload(ctx)
  return AB.attack_function({ ctx = ctx, preview = true })
end
function AB.on_sent(payload, ctx)
  AB.init()
  AB.state.template.last_emitted_payload = payload
  _record_payload_checkpoint(payload)
  if type(AB.state.explain) == "table" then
    AB.state.explain.resume_checkpoint = AB.state.resume_checkpoint
  end

  local tgt = ""
  local free_lane = nil
  local eq_lane = nil
  local bal_lane = nil
  local class_lane = nil
  local explain = nil
  if type(payload) == "table" then
    tgt = _trim(payload.target or "")
    if type(payload.lanes) == "table" then
      free_lane = payload.lanes.free
      eq_lane = payload.lanes.eq
      bal_lane = payload.lanes.bal
      class_lane = payload.lanes.class or payload.lanes.entity
    else
      free_lane = payload.free or payload.pre
      eq_lane = payload.eq
      bal_lane = payload.bal
      class_lane = payload.class or payload.ent or payload.entity
    end
    if type(payload.meta) == "table" and type(payload.meta.explain) == "table" then
      explain = payload.meta.explain
    end
  end
  if tgt == "" and type(ctx) == "table" then
    tgt = _trim(ctx.target or "")
  end

  if tgt ~= "" then
    local loyals_cmd = (tostring(AB.cfg.loyals_on_cmd or "order entourage kill %s")):format(tgt)
    if type(payload.meta) == "table" and _trim(payload.meta.parry_limb or "") ~= "" and Yso and Yso.parry and type(Yso.parry.note_sent) == "function" then
      pcall(Yso.parry.note_sent, payload.meta.parry_limb)
    end

    if _lane_contains_cmd(free_lane, loyals_cmd) then
      _mark_loyals_for_target(tgt)
    end
    local passive_cmd = tostring(AB.cfg.off_passive_cmd or "order loyals passive")
    if _lane_contains_cmd(free_lane, passive_cmd) then
      _clear_loyals_hostile()
    end

    local readaura_cmd = ("readaura %s"):format(tgt)
    if _lane_contains_cmd(eq_lane, readaura_cmd) and Yso and Yso.occ then
      if type(Yso.occ.aura_begin) == "function" then
        pcall(Yso.occ.aura_begin, tgt, "occ_aff_burst_send")
      end
      if type(Yso.occ.set_readaura_ready) == "function" then
        pcall(Yso.occ.set_readaura_ready, false, "sent")
      end
    end

    local attend_cmd = ("attend %s"):format(tgt)
    if _lane_contains_cmd(eq_lane, attend_cmd) then
      local US = _unnamable_state(tgt)
      if US then
        local was_initial = (US.initial_attend_done ~= true)
        local stamped = _now()
        US.last_attend_at = stamped
        US.initial_attend_done = true
        US.last_attend_status = "done"
        US.can_hear = true
        US.can_see = true
        US.last_reopen_at = math.max(_clock(US.last_reopen_at), stamped)
        if was_initial then
          _debug_event("Unnamable", string.format("initial attend sent tgt=%s", tgt))
        end
      end
    end

    for _, mode in ipairs({ "speak", "vision" }) do
      local unnamable_cmd = "unnamable " .. mode
      if _lane_contains_cmd(eq_lane, unnamable_cmd) then
        local US = _unnamable_state(tgt)
        if US then
          local stamped = _now()
          US.last_mode = mode
          US.last_cast_at = stamped
          US.ready_at = stamped + (tonumber(AB.cfg.unnamable_lockout_s or 30.0) or 30.0)
          US.last_allow = true
          US.last_block_reason = ""
        end
        if mode == "vision" and Yso and Yso.off and Yso.off.oc and type(Yso.off.oc.request_sight) == "function" then
          pcall(Yso.off.oc.request_sight, nil, "unnamable_vision")
        end
        _debug_event("Unnamable", string.format("selected tgt=%s mode=%s", tgt, mode))
      end
    end

    local gremlin_cmd = ("command gremlin at %s"):format(tgt)
    if _lane_contains_cmd(eq_lane, gremlin_cmd) then
      local SB = _shieldbreak_state(tgt)
      if SB then
        SB.pending = true
        SB.sent_at = _now()
      end
    end

    local para_lane = _lc(explain and explain.para and explain.para.lane or "")
    local eq_aff = _lc(explain and explain.eq_aff or "")
    local entity_aff = _lc(explain and explain.entity_aff or "")
    local entity_cmd = _trim(explain and explain.planned and explain.planned.entity or "")
    if para_lane == "eq" and _lane_contains_cmd(eq_lane, ("instill %s with paralysis"):format(tgt)) then
      _note_refresh_sent(tgt, "eq", "paralysis")
    elseif para_lane == "entity" and _lane_contains_cmd(class_lane, ("command slime at %s"):format(tgt)) then
      _note_refresh_sent(tgt, "entity", "paralysis")
    else
      if eq_aff ~= "" and (
        _lane_contains_cmd(eq_lane, ("instill %s with %s"):format(tgt, eq_aff))
        or (eq_aff == "disloyalty" and _lane_contains_cmd(eq_lane, ("devolve %s"):format(tgt)))
        or (eq_aff == "anorexia" and _lane_contains_cmd(eq_lane, ("regress %s"):format(tgt)))
      ) then
        _note_refresh_sent(tgt, "eq", eq_aff)
      elseif entity_aff ~= "" and entity_aff ~= "chimera_command" and entity_aff ~= "sycophant"
        and entity_cmd ~= "" and _lane_contains_cmd(class_lane, entity_cmd)
      then
        _note_refresh_sent(tgt, "entity", entity_aff)
      end
    end

    local remote_lust_cmd = ("outd lust&&order doppleganger seek %s&&order doppleganger channel fling lust at %s"):format(tgt, tgt)
    if _lane_contains_cmd(free_lane, remote_lust_cmd)
      and Yso and Yso.dop and type(Yso.dop.note_remote_lust_sent) == "function" then
      pcall(Yso.dop.note_remote_lust_sent, tgt)
    end

    local followup_lust_cmd = ("fling lust at %s"):format(tgt)
    if _lane_contains_cmd(bal_lane, followup_lust_cmd)
      and Yso and Yso.dop and type(Yso.dop.consume_followup_lust) == "function" then
      pcall(Yso.dop.consume_followup_lust, tgt)
    end
  end

  if class_lane and Yso and Yso.off and Yso.off.oc and Yso.off.oc.entity_registry
    and type(Yso.off.oc.entity_registry.note_payload_sent) == "function" then
    pcall(Yso.off.oc.entity_registry.note_payload_sent, { class = class_lane })
  end

  return true
end
function AB.evaluate(ctx)
  local payload, why = AB.build_payload(ctx)
  if not payload then return { ok = false, reason = why } end
  return { ok = true, payload = payload }
end

function AB.status()
  local snapshot = {
    route = "occ_aff_burst",
    enabled = AB.is_enabled(),
    active = AB.is_active(),
    target = _target(),
    checkpoint = AB.state and AB.state.resume_checkpoint or "",
    explain = AB.explain(),
    last_reason = AB.state and AB.state.template and AB.state.template.last_reason or "",
    last_disable_reason = AB.state and AB.state.template and AB.state.template.last_disable_reason or "",
  }
  if type(cecho) == "function" then
    cecho(string.format("<SlateBlue>[Occultism] <reset>aff loop enabled=%s active=%s checkpoint=%s target=%s\n",
      tostring(snapshot.enabled), tostring(snapshot.active), tostring(snapshot.checkpoint), tostring(snapshot.target)))
  end
  return snapshot
end

function AB.on_enter(ctx)
  AB.init()
  return true
end

function AB.on_exit(ctx)
  if Yso and Yso.mode and type(Yso.mode.stop_route_loop) == "function" then
    Yso.mode.stop_route_loop("occ_aff_burst", "exit", true)
  end
  AB.reset("exit")
  return true
end

function AB.on_target_swap(old_target, new_target)
  if _lc(old_target) ~= _lc(new_target) then
    AB.reset("target_swap")
    AB.state.last_target = _trim(new_target)
    if AB.state.loop_enabled == true then
      AB.schedule_loop(0)
    end
  end
  return true
end

function AB.on_pause(ctx)
  return true
end

function AB.on_resume(ctx)
  if AB.state and AB.state.loop_enabled == true then
    AB.schedule_loop(0)
  end
  return true
end

function AB.on_manual_success(ctx)
  if AB.state and AB.state.loop_enabled == true then
    AB.schedule_loop(AB.state.loop_delay)
  end
  return true
end

function AB.on_send_result(payload, ctx)
  return AB.on_sent(payload, ctx)
end

function AB.explain()
  AB.state = AB.state or {}
  AB.state.explain = type(AB.state.explain) == "table" and AB.state.explain or {}
  local ex = AB.state.explain
  ex.route = ex.route or "occ_aff_burst"
  ex.target = ex.target or AB.state.last_target or _target()
  ex.resume_checkpoint = ex.resume_checkpoint or AB.state.resume_checkpoint
  ex.debug = AB.debug and AB.debug.enabled == true or false
  ex.route_enabled = AB.is_enabled()
  ex.active = AB.is_active()

  local wait = AB.state.waiting or {}
  local queued = _trim(wait.queue)
  ex.waiting = ex.waiting or {}
  ex.waiting.active = queued ~= ""
  ex.waiting.queue = queued
  ex.waiting.main_lane = _lc(wait.main_lane or "")
  ex.waiting.lanes = (type(wait.lanes) == "table") and wait.lanes or {}
  ex.waiting.age = (queued ~= "") and math.max(0, _now() - (tonumber(wait.at) or _now())) or 0
  return ex
end

do
  local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(AB, AB.route_contract)
  end
end

return AB
