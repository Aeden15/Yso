--Group damage offense logic
--========================================================--
-- group_damage.lua  (Achaea / Occultist / Yso)
--  • Group damage automation (party / team damage):
--      Track: healthleech, sensitivity, clumsiness (core) + slickness (optional fourth)
--      Setup: build/refresh missing core pieces using EQ instills + entity pressure
--      Burst: paired WARP + FIRELORD(healthleech) when healthleech is tracked and both lanes are ready
--
--  • Uses Yso.emit() lane table => lane-table payload transport (default separator: &&)
--  • Payload modes (GLOBAL, via Yso.cfg.payload_mode):
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
--  • Shared across Occultist offense routes (duel / party / utilities).
--  • The pool is intended to be stable; routes may READ from it, not redefine it.
--========================================================--
Yso.off.oc.entity_pool = Yso.off.oc.entity_pool or {
  rotation = { "worm", "storm", "bubonis", "slime", "sycophant", "bloodleech", "hound", "humbug", "chimera", "firelord" },
}

-- Compatibility aliases (callers may refer to these):
Yso.off.oc.dmg = GD
Yso.off.oc.gd_simple = GD

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

  -- Centralized orchestration only; legacy direct tick remains as fallback.
  use_orchestrator = true,
  echo = true,

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
local function _trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function _lc(s) return _trim(s):lower() end

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
--  • worm:     20s infestation window (fallback: 2nd chew-proc line)
--  • sycophant:30s rixil window
--  • Entities retarget to the current target; duration gates reset on target change.
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

local function _tkey(s)
  return _lc(s)
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
  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    if type(ak.target) == "string" and _trim(ak.target) ~= "" then return _trim(ak.target) end
    if type(ak.tgt) == "string" and _trim(ak.tgt) ~= "" then return _trim(ak.tgt) end
    if type(ak.Target) == "string" and _trim(ak.Target) ~= "" then return _trim(ak.Target) end
  end
  return ""
end

local function _room_id()
  if Yso.targeting and type(Yso.targeting.room_id) == "function" then
    local ok, v = pcall(Yso.targeting.room_id)
    if ok and tostring(v or "") ~= "" then return tostring(v) end
  end
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

local function _plan_bal_support(tgt, st, eq_cmd, class_cmd)
  if not _bal_ready() then return nil end
  if eq_cmd or class_cmd then return nil end
  if not st.aeon then
    return ("outd aeon&&fling aeon at %s"):format(tgt)
  end
  if not st.entangled then
    return ("outd hangedman&&fling hangedman at %s"):format(tgt)
  end
  return ("ruinate justice %s"):format(tgt)
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
    p.bal = _plan_bal_support(tgt, st, p.eq, p.class)
    if p.bal then p.bal_category = "fallback_support" end
    return p
  end

  if miss_clum then
    if not p.class then pick_class("required_core_refresh") end
    if not p.class then pick_class("required_core_application") end
    if not p.class and _eq_ready() then p.eq = ("instill %s with clumsiness"):format(tgt); p.eq_category = "required_core_refresh" end
    p.bal = _plan_bal_support(tgt, st, p.eq, p.class)
    if p.bal then p.bal_category = "fallback_support" end
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
    p.bal = _plan_bal_support(tgt, st, p.eq, p.class)
    if p.bal then p.bal_category = "fallback_support" end
    return p
  end

  -- Full core present: reserve paired burst when EQ is ready; otherwise use support lanes only.
  if st.healthleech and _eq_ready() then
    -- Hold EQ for burst reservation until entity lane can pair with Firelord.
    p.bal = _plan_bal_support(tgt, st, nil, nil)
    if p.bal then p.bal_category = "fallback_support" end
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

  p.bal = _plan_bal_support(tgt, st, p.eq, p.class)
  if p.bal then p.bal_category = "fallback_support" end
  return p
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------
local function _ensure_registered()
  if not (GD.cfg.use_orchestrator ~= false and Yso and Yso.Orchestrator and type(Yso.Orchestrator.register) == "function") then
    return false
  end

  -- Disable any legacy pulse-route registration; orchestrator is the only automated authority.
  if Yso and Yso.pulse and Yso.pulse.state and Yso.pulse.state.reg and Yso.pulse.state.reg["group_damage"] then
    Yso.pulse.state.reg["group_damage"].enabled = false
  end

  if not GD._orch_registered then
    local O = Yso.Orchestrator
    local already = false
    if O.modules and type(O.modules.list) == "table" then
      for i=1,#O.modules.list do
        if O.modules.list[i] and O.modules.list[i].id == "group_damage" then already = true; break end
      end
    end
    if not already then
      pcall(O.register, { id = "group_damage", kind = "offense", priority = 55, propose = function(ctx) return GD.propose(ctx) end })
    end
    GD._orch_registered = true
  end
  return true
end

function GD.toggle(on)
  -- Always ensure the pulse handler exists so OFF-cleanup can run on the next wake.
  _ensure_registered()

  local want
  if on == nil then
    want = not (GD.state.enabled == true)
  else
    want = (on == true)
  end

  if want then
    GD.state.enabled = true
    GD.state.stop_pending = false
    GD.state.opener_sent_for = ""
    GD.state.last_room_id = ""
    _echo("Group damage ON.")
  else
    GD.state.enabled = false
    GD.state.stop_pending = true
    _echo("Group damage OFF (pending: order loyals passive via orchestrator on next ready wake).")
  end

  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    Yso.pulse.wake("group_damage:toggle")
  end
end


------------------------------------------------------------
-- Anti-tumble / Empress rescue (stateful)
--  • Wired by triggers in yso_offense_coordination.lua:
--      - tumble_begin -> GD.mark_tumble(tgt, dir)
--      - tumble_out   -> GD.mark_tumble_out(tgt, DIRU)
--  • Wired by Tarot triggers:
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
  reason = reason or "gd:anti"
  if Yso.emit and type(Yso.emit) == "function" then
    local payload = {}; payload[lane] = cmd
    return (Yso.emit(payload, { reason = reason, solo = true, dupe_window_ms = GD.cfg.dupe_window_ms }) == true)
  end
  -- fallback: push directly if lane helper exists
  local Q = Yso.queue
  if Q then
    if lane == "free" and type(Q.free) == "function" then local ok=pcall(Q.free, cmd); return ok==true end
    if lane == "bal"  and type(Q.bal_clear) == "function" then local ok=pcall(Q.bal_clear, cmd); return ok==true end
    if lane == "eq"   and type(Q.eq_clear) == "function" then local ok=pcall(Q.eq_clear, cmd); return ok==true end
  end
  if type(send) == "function" then send(cmd); return true end
  return false
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

  -- Hard timeout (don’t keep this pending forever if presence tracking is missing).
  if E.started_at ~= 0 and (now - (tonumber(E.started_at) or 0)) > 15.0 then
    E.pending = false
    return false
  end

  if now < (tonumber(E.fail_until) or 0) then return false end
  if not _bal_ready() then return false end

  if (now - (tonumber(E.last_try) or 0)) < 0.9 then return false end
  E.last_try = now

  _echo(("%s TUMBLED OUT -> Empress pull (%s)"):format(tgt, tostring(E.dir or "?")))
  _emit_lane("free", "outd empress", "gd:empress")
  return _emit_lane("bal", ("fling empress %s"):format(tgt), "gd:empress")
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
------------------------------------------------------------
-- Orchestrator proposal (preferred)
-- Universal shared route categories:
--   • defense_break
--   • anti_tumble
-- All other strategic categories for group_damage are route-local.
--  Returns a list of actions for Yso.Orchestrator to arbitrate/stage.
------------------------------------------------------------
function GD.propose(ctx)
  local actions = {}

  local D = (Yso and Yso.off and Yso.off.driver) or nil
  local pol = D and D.state and tostring(D.state.policy or ""):lower() or ""
  if pol == "active" then pol = "manual" end
  if pol ~= "auto" then return actions end

  local route = ""
  if D and type(D.current_route) == "function" then
    local ok, v = pcall(D.current_route)
    if ok then route = tostring(v or ""):lower() end
  else
    route = D and D.state and tostring(D.state.active or ""):lower() or ""
    if route == "gd" or route == "dmg" then route = "group_damage" end
  end
  if route ~= "group_damage" then return actions end
  if not GD.state.enabled then return actions end

  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return actions end

  local now = (ctx and tonumber(ctx.now)) or _now()

  if GD.state.stop_pending then
    if _eq_ready() or _bal_ready() then
      local cmd = tostring(GD.cfg.off_passive_cmd or "order loyals passive")
      actions[#actions+1] = { cmd = cmd, qtype = "free", kind = "offense", score = 100, tag = "gd:off" }
    end
    return actions
  end

  if GD.cfg.rescue_lust_empress == true then
    local anti = _rescue_antitumble_action(now)
    if anti then actions[#actions+1] = anti end

    local empress = _rescue_empress_action(now)
    if empress then actions[#actions+1] = empress end
  end

  local tgt = _target()
  if tgt == "" or not _tgt_valid(tgt) then return actions end
  _reset_entity_gates_on_target_change(tgt)

  local p = _plan_route(tgt)
  local tkey = _lc(tgt)

  if p.eq and _eq_ready() then
    actions[#actions+1] = { cmd = p.eq, qtype = "eq", kind = "offense", score = 30, tag = "gd:eq:"..tkey, category = p.eq_category or "route" }
  end
  if p.class and _ent_ready() then
    local score = (tostring(p.class):lower():find("firelord", 1, true) and 32) or 28
    actions[#actions+1] = { cmd = p.class, qtype = "class", kind = "offense", score = score, tag = "gd:class:"..tkey, category = p.class_category or "route" }
  end
  if p.bal and _bal_ready() then
    actions[#actions+1] = { cmd = p.bal, qtype = "bal", kind = "offense", score = 12, tag = "gd:bal:"..tkey, category = p.bal_category or "route" }
  end

  return actions
end
------------------------------------------------------------
-- Main tick
------------------------------------------------------------
function GD.tick(reasons)
  if GD.cfg.use_orchestrator == true then return end

  do
    local D = (Yso and Yso.off and Yso.off.driver) or nil
    local enabled = (D and ((D.state and D.state.enabled) or D.enabled)) or false
    if enabled and not (D._from_driver == true) then return end
  end

  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return end

  if GD.state.stop_pending then
    if _eq_ready() or _bal_ready() then
      local cmd = tostring(GD.cfg.off_passive_cmd or "order loyals passive")
      local sent = false
      if Yso.emit and type(Yso.emit) == "function" then
        sent = (Yso.emit({ free = cmd }, { reason = "group_damage:off", solo = true, dupe_window_ms = GD.cfg.dupe_window_ms }) == true)
      elseif Yso.queue and type(Yso.queue.free) == "function" then
        local ok = pcall(Yso.queue.free, cmd); sent = ok == true
      elseif type(send) == "function" then
        send(cmd); sent = true
      end

      if sent then
        _set_loyals_hostile(false)
        GD.state.stop_pending = false
        GD.state.enabled = false
        GD.state.last_room_id = ""
        GD.state.last_target = ""
        _echo("Group damage OFF. loyals passive.")
      end
    end
    return
  end

  local now = _now()
  if GD.cfg.rescue_lust_empress == true then
    _maybe_antitumble(now)
    _maybe_empress(now)
  end

  local tgt = _target()
  if tgt == "" or not _tgt_valid(tgt) then return end
  _reset_entity_gates_on_target_change(tgt)

  local p = _plan_route(tgt)
  local payload = {}
  if p.eq then payload.eq = p.eq end
  if p.class then payload.class = p.class end
  if p.bal then payload.bal = p.bal end
  if not payload.eq and not payload.class and not payload.bal then return end

  if GD.cfg.avoid_overlap and payload.eq and type(payload.eq) == "string" then
    local eqlc = payload.eq:lower()
    if eqlc:match("^%s*instill%s+") and eqlc:find("with%s+healthleech") then
      local clc = tostring(payload.class or ""):lower()
      if clc:find("^%s*command%s+worm") or _worm_active(tgt) then
        payload.eq = nil
      end
    end
  end

  local sent = false
  if Yso.emit and type(Yso.emit) == "function" then
    sent = (Yso.emit(payload, { reason = "group_damage", allow_eqbal = true, dupe_window_ms = GD.cfg.dupe_window_ms }) == true)
  elseif Yso.queue and type(Yso.queue.emit) == "function" then
    local ok = pcall(Yso.queue.emit, payload)
    sent = (ok == true)
  end

  return sent
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

function GD.on_payload_sent(payload)
  if type(payload) ~= "table" then return end

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
function GD.start(arg) GD.toggle(true) end
function GD.stop() GD.toggle(false) end
function GD.status()
  local tgt = _target()
  local st = _core_state()
  _echo(string.format("enabled=%s target=%s core=%d/3 (hl=%s sens=%s clumsy=%s slick=%s addiction=%s)",
    tostring(GD.state.enabled==true), tostring(tgt), st.count,
    tostring(st.healthleech), tostring(st.sensitivity), tostring(st.clumsiness), tostring(st.slickness), tostring(_has_aff("addiction"))
  ))
end

-- Register with pulse bus (so EQ/BAL/ENT wake triggers drive it)
_ensure_registered()
