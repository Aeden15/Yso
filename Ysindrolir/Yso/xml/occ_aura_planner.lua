--========================================================--
-- Yso.occ.aura_planner — Centralized Readaura / Cleanseaura Planner
--
--  Shared surface for all Occultist offense routes (occ_aff_burst, party_aff,
--  group_damage, etc.) to plan readaura and cleanseaura EQ actions.
--
--  Fixes:
--    • Unified lockout tags prevent cross-route double-sends (Bug #1, #2)
--    • Single _aura_txn_active_for() definition (Bug #3)
--    • Unified needs_readaura logic (Bug #4, #6)
--    • CS.snapshot() lives here — no fragile cross-module dep (Bug #5)
--
--  Pattern: Sunder-style shared planner surface.
--  Routes call AP.readaura_plan() / AP.cleanseaura_plan() instead of
--  maintaining local copies.
--========================================================--

Yso = Yso or {}
Yso.occ = Yso.occ or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

Yso.off.oc.aura_planner = Yso.off.oc.aura_planner or {}
local AP = Yso.off.oc.aura_planner

-- Cleanseaura namespace (shared with occ_aff_burst CS alias)
Yso.off.oc.cleanseaura = Yso.off.oc.cleanseaura or {}
local CS = Yso.off.oc.cleanseaura

-- ===== Configuration =====
AP.cfg = AP.cfg or {
  aura_ttl_s              = 20,
  readaura_requery_s      = 8.0,
  readaura_lockout_s      = 1.0,
  cleanseaura_lockout_s   = 4.1,
  pinchaura_lockout_s     = 4.1,
  mana_burst_pct          = 40,
}

CS.cfg = CS.cfg or {
  mana_burst_pct = tonumber(AP.cfg.mana_burst_pct or 40) or 40,
}

-- ===== Helpers =====
local function _trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function _lc(s)   return _trim(s):lower() end

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  local t = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  if t and t > 20000000000 then t = t / 1000 end
  return t or os.time()
end

local function _offense_state()
  return Yso and Yso.off and Yso.off.state or nil
end

local function _recent_sent(tag, within_s)
  local S = _offense_state()
  if not (S and type(S.recent) == "function") then return false end
  return S.recent(tag, within_s)
end

local function _has_aff(tgt, aff)
  if Yso and Yso.occ and type(Yso.occ.has_aff) == "function" then
    local ok, v = pcall(Yso.occ.has_aff, tgt, aff)
    if ok then return v == true end
  end
  local ak = rawget(_G, "ak")
  if type(ak) == "table" and type(ak.isafflicted) == "function" then
    local ok, v = pcall(ak.isafflicted, aff)
    if ok then return v == true end
  end
  return false
end

local function _bool_field(v)
  if v == true then return true end
  if v == false then return false end
  return nil
end

-- ===== Unified Tags (Bug #1, #2 fix) =====
function AP.readaura_tag(tgt)
  return "occ:eq:readaura:" .. _lc(tgt)
end

function AP.cleanseaura_tag(tgt)
  return "occ:eq:cleanseaura:" .. _lc(tgt)
end

function AP.pinchaura_tag(tgt)
  return "occ:eq:pinchaura:" .. _lc(tgt)
end

-- ===== Shared Helpers (Bug #3 fix) =====
function AP.aura_txn_active_for(tgt)
  if not (Yso and Yso.occ and type(Yso.occ.aura_txn_status) == "function") then return false end
  local ok, status = pcall(Yso.occ.aura_txn_status, tgt)
  return ok and type(status) == "table" and status.active == true and status.matched == true
end

-- ===== Raw Aura Snapshot =====
local function _raw_snapshot(tgt)
  if _trim(tgt) == "" then return nil end
  local A = Yso and Yso.occ and Yso.occ.aura or nil
  if type(A) ~= "table" then return nil end
  return A[tgt] or A[_lc(tgt)]
end

-- ===== CS.snapshot (moved here — Bug #5 fix) =====
function AP.snapshot(tgt)
  local a = _raw_snapshot(tgt)
  local txn = { active = false, matched = false, window_remaining = 0, status = "", close_reason = "" }
  if Yso and Yso.occ and type(Yso.occ.aura_txn_status) == "function" then
    local ok, row = pcall(Yso.occ.aura_txn_status, tgt)
    if ok and type(row) == "table" then
      txn = row
    end
  end
  local ttl = tonumber((Yso and Yso.occ and Yso.occ.aura_cfg and Yso.occ.aura_cfg.ttl) or AP.cfg.aura_ttl_s or 20) or 20
  local parse_window_open = (txn.active == true and txn.matched == true)
  local parse_window_remaining = parse_window_open and (tonumber(txn.window_remaining or 0) or 0) or 0
  if not a then
    return {
      fresh = false,
      complete = false,
      read_complete = false,
      had_counts = false,
      had_mana = false,
      physical = nil,
      mental = nil,
      aff_total = nil,
      blind = nil,
      deaf = nil,
      speed = nil,
      shield = nil,
      mana_pct = nil,
      mana_cur = nil,
      mana_max = nil,
      defs_state = "missing",
      confidence_state = parse_window_open and "pending" or "missing",
      confidence_score = 0,
      missing_keys = { "defs", "counts", "mana" },
      parse_window_open = parse_window_open,
      parse_window_remaining = parse_window_remaining,
      txn_status = tostring(txn.status or ""),
      txn_reason = tostring(txn.close_reason or ""),
      txn_started_at = tonumber(txn.started_at or 0) or 0,
      txn_read_id = tonumber(txn.read_id or 0) or 0,
    }
  end
  local fresh = true
  if ttl > 0 then fresh = (_now() - tonumber(a.ts or 0)) <= ttl end
  local missing_keys = {}
  if fresh and type(a.missing_keys) == "table" then
    for i = 1, #a.missing_keys do
      missing_keys[#missing_keys + 1] = a.missing_keys[i]
    end
  end
  local confidence_state = fresh and tostring(a.confidence_state or "") or "stale"
  if confidence_state == "" then
    confidence_state = fresh and ((a.complete == true and "complete") or "partial") or "stale"
  end
  if parse_window_open and confidence_state == "missing" then
    confidence_state = "pending"
  end
  -- Boolean fields are intentionally nil when the snapshot is stale.
  -- Callers can treat nil as "unknown/not fresh yet".
  local function bf(key)
    if not fresh then return nil end
    if a[key] == true then return true end
    if a[key] == false then return false end
    return nil
  end
  local physical = fresh and tonumber(a.physical) or nil
  local mental = fresh and tonumber(a.mental) or nil
  local total = nil
  if physical ~= nil or mental ~= nil then total = (physical or 0) + (mental or 0) end
  return {
    fresh = fresh,
    complete = (fresh and a.complete == true) or false,
    read_complete = (fresh and a.read_complete == true) or false,
    had_counts = (fresh and a.had_counts == true) or false,
    had_mana = (fresh and a.had_mana == true) or false,
    physical = physical,
    mental = mental,
    aff_total = total,
    blind = bf("blind"),
    deaf = bf("deaf"),
    speed = bf("speed"),
    shield = bf("shield"),
    caloric = bf("caloric"),
    frost = bf("frost"),
    levitation = bf("levitation"),
    insomnia = bf("insomnia"),
    kola = bf("kola"),
    cloak = bf("cloak"),
    mana_pct = fresh and tonumber(a.mana_pct) or nil,
    mana_cur = fresh and tonumber(a.mana_cur) or nil,
    mana_max = fresh and tonumber(a.mana_max) or nil,
    raw = (fresh and type(a.raw) == "table") and a.raw or nil,
    defs_state = fresh and tostring(a.defs_state or "missing") or "missing",
    confidence_state = confidence_state,
    confidence_score = fresh and (tonumber(a.confidence_score or 0) or 0) or 0,
    missing_keys = missing_keys,
    parse_window_open = parse_window_open,
    parse_window_remaining = parse_window_remaining,
    txn_status = tostring(txn.status or ""),
    txn_reason = tostring(txn.close_reason or ""),
    txn_started_at = tonumber(txn.started_at or 0) or 0,
    txn_read_id = tonumber(txn.read_id or 0) or 0,
    ts = tonumber(a.ts or 0) or 0,
    read_id = tonumber(a.read_id or 0) or 0,
  }
end

-- Wire CS.snapshot to this centralized version
CS.snapshot = AP.snapshot

-- ===== Unified needs_readaura Logic (Bug #4, #6 fix) =====
function AP.needs_readaura(tgt, snap)
  snap = snap or AP.snapshot(tgt)
  local fresh = (snap.fresh == true)

  if fresh and snap.parse_window_open == true then
    return false, "parse_window_open"
  end
  if not fresh then
    return true, "snapshot_stale"
  end
  if snap.read_complete ~= true then
    return true, "snapshot_incomplete"
  end
  local needs_defs = (snap.defs_state == "missing")
  if needs_defs then
    return true, "defs_incomplete"
  end
  if snap.had_counts ~= true then
    return true, "counts_incomplete"
  end
  if snap.deaf == nil then
    return true, "deaf_unknown"
  end
  if snap.had_mana ~= true and snap.mana_pct == nil then
    return true, "mana_unknown"
  end
  return false, ""
end

-- ===== Unified should_probe (Bug #6 fix) =====
local function _missing_key(list, key)
  if type(list) ~= "table" then return false end
  key = _lc(key)
  for i = 1, #list do
    if _lc(list[i]) == key then return true end
  end
  return false
end

function AP.should_probe_readaura(tgt, plan, burst_ready)
  local tag = AP.readaura_tag(tgt)
  if _recent_sent(tag, tonumber(AP.cfg.readaura_requery_s or 8.0) or 8.0) then return false end
  if AP.aura_txn_active_for(tgt) then return false end
  if plan and plan.snapshot_parse_window_open == true then return false end

  if plan and plan.needs_readaura == true then return true end
  if plan and (plan.snapshot_confidence_state == "stale" or plan.snapshot_complete ~= true) then return true end

  local need_defs = plan and ((plan.snapshot_read_complete ~= true) or _missing_key(plan.snapshot_missing_keys, "defs"))
  local need_counts = plan and ((plan.snapshot_had_counts ~= true) or _missing_key(plan.snapshot_missing_keys, "counts"))
  local need_mana = plan and (plan.mana_pct == nil) and ((plan.snapshot_had_mana ~= true) or _missing_key(plan.snapshot_missing_keys, "mana"))
  if need_defs or need_counts or need_mana then return true end

  if burst_ready == true and plan and (plan.speed == nil or need_defs) then return true end

  return false
end

-- ===== Readaura Plan (returns cmd, category, tag, lockout) =====
function AP.readaura_plan(tgt, plan, burst_ready)
  if not AP.should_probe_readaura(tgt, plan, burst_ready) then return nil, nil, nil, nil end
  if not (Yso and Yso.occ and type(Yso.occ.readaura_is_ready) == "function") then return nil, nil, nil, nil end
  local ok, ready = pcall(Yso.occ.readaura_is_ready)
  if ok and ready == true then
    return ("readaura %s"):format(tgt),
           "cleanseaura_window",
           AP.readaura_tag(tgt),
           tonumber(AP.cfg.readaura_lockout_s or 1.0)
  end
  return nil, nil, nil, nil
end

-- ===== Bootstrap Readaura Plan (loyals opener path) =====
function AP.bootstrap_readaura_plan(tgt, plan)
  if not (plan and plan.loyals_bootstrap_pending == true and plan.readaura_via_loyals == true) then
    return nil, nil, nil, nil
  end
  local tag = AP.readaura_tag(tgt)
  if _recent_sent(tag, tonumber(AP.cfg.readaura_requery_s or 8.0) or 8.0) then return nil, nil, nil, nil end
  if AP.aura_txn_active_for(tgt) then return nil, nil, nil, nil end
  return ("readaura %s"):format(tgt),
         "cleanseaura_window",
         tag,
         tonumber(AP.cfg.readaura_lockout_s or 1.0)
end

-- ===== Cleanseaura Plan =====
function AP.cleanseaura_plan(tgt, plan, gate)
  if not (plan and plan.cleanseaura_ready == true) then return nil, nil, nil, nil end
  if not _has_aff(tgt, "manaleech") then return nil, nil, nil, nil end

  if Yso and Yso.occ and Yso.occ.truebook and type(Yso.occ.truebook.can_utter) == "function" then
    local ok, can = pcall(Yso.occ.truebook.can_utter, tgt)
    if ok and can == true then return nil, nil, nil, nil end
  end

  if gate and gate.stable ~= true then return nil, nil, nil, nil end

  local tag = AP.cleanseaura_tag(tgt)
  local lock = tonumber(AP.cfg.cleanseaura_lockout_s or 4.1) or 4.1
  if _recent_sent(tag, lock) then return nil, nil, nil, nil end

  return ("cleanseaura %s"):format(tgt),
         "truename_acquire",
         tag,
         lock
end

-- ===== Readaura Ready state passthrough =====
function AP.readaura_is_ready()
  if Yso and Yso.occ and type(Yso.occ.readaura_is_ready) == "function" then
    local ok, v = pcall(Yso.occ.readaura_is_ready)
    return ok and v == true
  end
  return false
end

function AP.set_readaura_ready(val, reason)
  if Yso and Yso.occ and type(Yso.occ.set_readaura_ready) == "function" then
    return Yso.occ.set_readaura_ready(val, reason)
  end
end

-- ===== Mana readiness check =====
function AP.cleanseaura_ready(tgt, snap)
  snap = snap or AP.snapshot(tgt)
  local mana = snap.mana_pct
  if Yso and Yso.tgt and type(Yso.tgt.get_mana_pct) == "function" then
    local ok, v = pcall(Yso.tgt.get_mana_pct, tgt)
    local n = ok and tonumber(v) or nil
    if n then mana = n end
  end
  local cap = tonumber(AP.cfg.mana_burst_pct or CS.cfg.mana_burst_pct or 40) or 40
  return (mana ~= nil and mana <= cap) or false, mana
end

--========================================================--
