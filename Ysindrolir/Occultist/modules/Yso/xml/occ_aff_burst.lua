--========================================================--
-- occ_aff_burst.lua
--  • Combat-mode duel affliction burst route for Occultist.
--  • Owns the mana-bury -> cleanseaura -> truename -> WM -> mentals ->
--    enlighten -> speed strip -> utter -> unravel sequence.
--  • Firelord intentionally omitted in this pass.
--  • Route returns proposals only; Yso.Orchestrator remains final authority.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

Yso.off.oc.occ_aff_burst = Yso.off.oc.occ_aff_burst or {}
local AB = Yso.off.oc.occ_aff_burst

-- Shared cleanseaura planner surface. Limb-side remains available as a namespace;
-- this pass adds the affliction / mana-burst branch used by combat-mode dueling.
Yso.off.oc.cleanseaura = Yso.off.oc.cleanseaura or {}
local CS = Yso.off.oc.cleanseaura

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
  enabled = true,
  use_orchestrator = true,
  echo = true,

  mana_burst_pct = 40,
  mental_target = 5,
  enlighten_target = 5,

  aura_ttl_s = 20,
  readaura_requery_s = 8,
  speed_hold_s = 3.2,
  utter_follow_s = 5.0,

  cleanseaura_lockout_s = 4.1,
  pinchaura_lockout_s = 4.1,
  readaura_lockout_s = 1.0,
  attend_lockout_s = 2.3,
  truename_branch_stability_pulses = 2,
}

AB.state = AB.state or {
  enabled = (AB.cfg.enabled ~= false),
  last_target = "",
  explain = {},
  resume_checkpoint = "mana_bury",
  resume_checkpoint_at = 0,
  truename_entry_stable_pulses = 0,
}

CS.cfg = CS.cfg or {
  mana_burst_pct = tonumber(AB.cfg.mana_burst_pct or 40) or 40,
}

local function _trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function _lc(s) return _trim(s):lower() end

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

local function _target()
  if Yso and Yso.targeting and type(Yso.targeting.get) == "function" then
    local ok, v = pcall(Yso.targeting.get)
    if ok and _trim(v) ~= "" then return _trim(v) end
  end
  if type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok and _trim(v) ~= "" then return _trim(v) end
  end
  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    if type(ak.target) == "string" and _trim(ak.target) ~= "" then return _trim(ak.target) end
    if type(ak.tgt) == "string" and _trim(ak.tgt) ~= "" then return _trim(ak.tgt) end
  end
  if type(Yso.target) == "string" and _trim(Yso.target) ~= "" then return _trim(Yso.target) end
  return ""
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

local function _snapshot(tgt)
  if tgt == "" then return nil end
  local A = Yso and Yso.occ and Yso.occ.aura or nil
  if type(A) ~= "table" then return nil end
  return A[tgt] or A[_lc(tgt)]
end

function CS.snapshot(tgt)
  local a = _snapshot(tgt)
  local ttl = tonumber((Yso and Yso.occ and Yso.occ.aura_cfg and Yso.occ.aura_cfg.ttl) or AB.cfg.aura_ttl_s or 20) or 20
  if not a then
    return { fresh = false, physical = nil, mental = nil, blind = nil, deaf = nil, speed = nil }
  end
  local fresh = true
  if ttl > 0 then fresh = (_now() - tonumber(a.ts or 0)) <= ttl end
  return {
    fresh = fresh,
    physical = tonumber(a.physical),
    mental = tonumber(a.mental),
    blind = (a.blind == true),
    deaf = (a.deaf == true),
    speed = (a.speed == true),
    caloric = (a.caloric == true),
    frost = (a.frost == true),
    levitation = (a.levitation == true),
    insomnia = (a.insomnia == true),
    kola = (a.kola == true),
    cloak = (a.cloak == true),
    ts = tonumber(a.ts or 0) or 0,
  }
end

function CS.plan_limb(tgt)
  return { route = "limb", target = tgt }
end

function CS.plan_aff(tgt)
  local mana = nil
  if Yso and Yso.tgt and type(Yso.tgt.get_mana_pct) == "function" then
    local ok, v = pcall(Yso.tgt.get_mana_pct, tgt)
    if ok and tonumber(v) then mana = tonumber(v) end
  end

  local snap = CS.snapshot(tgt)
  local mana_cap = tonumber(CS.cfg.mana_burst_pct or 40) or 40
  local fresh = (snap and snap.fresh == true)

  local out = {
    route = "aff",
    target = tgt,
    mana_pct = mana,
    physical = snap and snap.physical or nil,
    mental = snap and snap.mental or nil,
    blind = snap and snap.blind or nil,
    deaf = snap and snap.deaf or nil,
    speed = fresh and snap.speed or nil,
    snapshot_fresh = fresh,
    mana_ready = (mana ~= nil and mana <= mana_cap) or false,
    needs_mana_bury = (mana == nil) or (mana > mana_cap),
    needs_readaura = (not fresh),
    needs_speed_strip = (fresh and snap.speed == true) or false,
    cleanseaura_ready = (mana ~= nil and mana <= mana_cap) or false,
    needs_attend = (fresh and (snap.blind == true or snap.deaf == true)) or false,
  }

  return out
end

local function _recent_sent(tag, within_s)
  local O = Yso and Yso.Orchestrator or nil
  if not (O and type(O.last_sent) == "table") then return false end
  local row = O.last_sent[tag]
  if type(row) ~= "table" then return false end
  return (_now() - tonumber(row.at or 0)) <= (tonumber(within_s or 0) or 0)
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
  if cat == "" or _is_truename_category(cat) then return end
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

local function _route_active()
  local D = Yso and Yso.off and Yso.off.driver or nil
  if not (D and D.state) then return false end
  local pol = _lc(D.state.policy)
  if pol ~= "auto" then return false end
  if type(D.current_route) == "function" then
    local ok, v = pcall(D.current_route)
    return ok and v == "occ_aff_burst"
  end
  return _lc(D.state.active) == "occ_aff_burst"
end

local function _need_core_instill(tgt)
  local order = { "asthma", "clumsiness", "healthleech", "sensitivity" }
  for i = 1, #order do
    if not _has_aff(tgt, order[i]) then return order[i] end
  end
  return nil
end

local function _entity_plan(tgt, plan)
  if not _ent_ready() then return nil, nil end

  local ER = Yso and Yso.off and Yso.off.oc and Yso.off.oc.entity_registry or nil
  if ER and type(ER.target_swap) == "function" then pcall(ER.target_swap, tgt) end

  local worm_refresh = true
  local syc_refresh = true
  if ER and type(ER.worm_should_refresh) == "function" then
    local ok, v = pcall(ER.worm_should_refresh, tgt)
    if ok then worm_refresh = (v == true) end
  end
  if ER and type(ER.syc_should_refresh) == "function" then
    local ok, v = pcall(ER.syc_should_refresh, tgt)
    if ok then syc_refresh = (v == true) end
  end


  if not _has_aff(tgt, "asthma") then return ("command bubonis at %s"):format(tgt), "mana_bury" end
  if not _has_aff(tgt, "clumsiness") then return ("command storm at %s"):format(tgt), "mana_bury" end
  if not _has_aff(tgt, "healthleech") and worm_refresh then return ("command worm at %s"):format(tgt), "mana_bury" end
  if not _has_aff(tgt, "sensitivity") then return ("command slime at %s"):format(tgt), "mana_bury" end

  if plan.needs_mana_bury and syc_refresh then
    return ("command sycophant at %s"):format(tgt), "mana_bury"
  end

  return nil, nil
end

local function _bal_plan(tgt, plan)
  if not _bal_ready() then return nil, nil end

  if not _has_aff(tgt, "lovers") then
    return ("outd lovers&&fling lovers at %s"):format(tgt), "mana_bury"
  end

  if plan.needs_mana_bury and not _has_aff(tgt, "manaleech") then
    return ("ruinate lovers %s"):format(tgt), "mana_bury"
  end

  if _mental_score() < tonumber(AB.cfg.mental_target or 5) then
    return ("outd moon&&fling moon at %s"):format(tgt), "mental_build"
  end

  return nil, nil
end

local function _burst_ready(tgt)
  if not _truebook_can_utter(tgt) then return false end
  if not _has_aff(tgt, "whisperingmadness") and not _has_aff(tgt, "whispering_madness") then return false end
  return _enlighten_score() >= tonumber(AB.cfg.enlighten_target or 5)
end

local function _eq_plan(tgt, plan, gate)
  if not _eq_ready() then return nil, nil, nil, nil end

  local mental_score = _mental_score()
  local burst_ready = _burst_ready(tgt)
  local has_wm = _has_aff(tgt, "whisperingmadness") or _has_aff(tgt, "whispering_madness")
  local need_instill = _need_core_instill(tgt)

  if plan.needs_readaura and Yso and Yso.occ and type(Yso.occ.readaura_is_ready) == "function" then
    local ok, ready = pcall(Yso.occ.readaura_is_ready)
    if ok and ready == true then
      return ("readaura %s"):format(tgt), "cleanseaura_window", "ab:eq:readaura:" .. _lc(tgt), tonumber(AB.cfg.readaura_lockout_s or 1.0)
    end
  end

  if plan.cleanseaura_ready and not _truebook_can_utter(tgt) then
    if gate and gate.stable ~= true then return nil, nil, nil, nil end
    return ("cleanseaura %s"):format(tgt), "truename_acquire", "ab:eq:cleanseaura:" .. _lc(tgt), tonumber(AB.cfg.cleanseaura_lockout_s or 4.1)
  end

  if _truebook_can_utter(tgt) and not has_wm and _has_any_required_insanity(tgt) then
    return ("whisperingmadness %s"):format(tgt), "mental_build", "ab:eq:wm:" .. _lc(tgt), 2.3
  end

  if _truebook_can_utter(tgt) and plan.needs_attend and mental_score < tonumber(AB.cfg.mental_target or 5) then
    return ("attend %s"):format(tgt), "mental_build", "ab:eq:attend:" .. _lc(tgt), tonumber(AB.cfg.attend_lockout_s or 2.3)
  end

  if burst_ready then
    if plan.needs_speed_strip and not _recent_sent(_pin_tag(tgt), tonumber(AB.cfg.speed_hold_s or 3.2)) then
      return ("pinchaura %s speed"):format(tgt), "speed_strip_window", _pin_tag(tgt), tonumber(AB.cfg.pinchaura_lockout_s or 4.1)
    end
    if (plan.speed == false or _recent_sent(_pin_tag(tgt), tonumber(AB.cfg.speed_hold_s or 3.2))) then
      return ("utter truename %s"):format(tgt), "reserved_burst", _utter_tag(tgt), tonumber(AB.cfg.utter_follow_s or 5.0)
    end
  end

  if plan.needs_mana_bury and _has_aff(tgt, "manaleech") then
    return ("enervate %s"):format(tgt), "mana_bury", "ab:eq:enervate:" .. _lc(tgt), 4.0
  end

  if need_instill then
    return ("instill %s with %s"):format(tgt, need_instill), "mana_bury", "ab:eq:instill:" .. _lc(tgt) .. ":" .. need_instill, 2.5
  end

  return nil, nil, nil, nil
end

local function _ensure_registered()
  if not (AB.cfg.use_orchestrator == true and Yso and Yso.Orchestrator and type(Yso.Orchestrator.register) == "function") then
    return false
  end

  if Yso and Yso.pulse and Yso.pulse.state and Yso.pulse.state.reg and Yso.pulse.state.reg["occ_aff_burst"] then
    Yso.pulse.state.reg["occ_aff_burst"].enabled = false
  end

  if not AB._orch_registered then
    local O = Yso.Orchestrator
    local already = false
    if O.modules and type(O.modules.list) == "table" then
      for i = 1, #O.modules.list do
        if O.modules.list[i] and O.modules.list[i].id == "occ_aff_burst" then already = true break end
      end
    end
    if not already then
      pcall(O.register, { id = "occ_aff_burst", kind = "offense", priority = 58, propose = function(ctx) return AB.propose(ctx) end })
    end
    AB._orch_registered = true
  end
  return true
end

AB._ensure_registered = _ensure_registered

function AB.toggle(on)
  _ensure_registered()
  if on == nil then
    AB.state.enabled = not (AB.state.enabled == true)
  else
    AB.state.enabled = (on == true)
  end
  AB.cfg.enabled = (AB.state.enabled == true)
  if Yso and Yso.pulse and type(Yso.pulse.wake) == "function" then
    Yso.pulse.wake("occ_aff_burst:toggle")
  end
  if AB.cfg.echo == true and type(cecho) == "function" then
    cecho(string.format("<SlateBlue>[Occultism] <reset>aff burst %s\n",
      (AB.state.enabled == true) and "<aqua>ON<reset>" or "<yellow>OFF<reset>"))
  end
  return (AB.state.enabled == true)
end

function AB.automation_toggle()
  _ensure_registered()

  Yso = Yso or {}
  Yso.off = Yso.off or {}
  Yso.off.oc = Yso.off.oc or {}
  Yso.off.driver = Yso.off.driver or {}

  local D = Yso.off.driver
  local was_on = (AB.state and AB.state.enabled == true) or false
  local want = not was_on

  Yso.occ = Yso.occ or {}
  Yso.occ.clock = Yso.occ.clock or {}

  if want then
    if Yso.mode and type(Yso.mode.set) == "function" then
      pcall(Yso.mode.set, "combat", "alias:aff")
    end

    if type(D.toggle) == "function" then
      pcall(D.toggle, true)
    else
      D.state = D.state or {}
      D.state.enabled = true
    end

    if type(D.set_active) == "function" then pcall(D.set_active, "occ_aff_burst") end
    if type(D.set_policy) == "function" then pcall(D.set_policy, "auto") end

    if type(AB.toggle) == "function" then
      pcall(AB.toggle, true)
    else
      AB.state = AB.state or {}
      AB.cfg = AB.cfg or {}
      AB.state.enabled = true
      AB.cfg.enabled = true
      if Yso and Yso.pulse and type(Yso.pulse.wake) == "function" then
        Yso.pulse.wake("occ_aff_burst:toggle")
      end
    end

    if type(Yso.occ.clock.set_route) == "function" then
      pcall(Yso.occ.clock.set_route, "aff")
    else
      Yso.occ.clock.cfg = Yso.occ.clock.cfg or {}
      Yso.occ.clock.cfg.route = "aff"
    end

    if type(cecho) == "function" then
      cecho("<dark_orchid>[Occultism] <aquamarine>aff burst armed<reset>\n")
    end
  else
    if type(AB.toggle) == "function" then
      pcall(AB.toggle, false)
    else
      AB.state = AB.state or {}
      AB.cfg = AB.cfg or {}
      AB.state.enabled = false
      AB.cfg.enabled = false
      if Yso and Yso.pulse and type(Yso.pulse.wake) == "function" then
        Yso.pulse.wake("occ_aff_burst:toggle")
      end
    end

    if type(D.set_active) == "function" then pcall(D.set_active, "none") end
    if type(D.set_policy) == "function" then pcall(D.set_policy, "manual") end

    if type(cecho) == "function" then
      cecho("<dark_orchid>[Occultism] <yellow>aff burst idle<reset>\n")
    end
  end
end

function AB.start() return AB.toggle(true) end
function AB.stop()  return AB.toggle(false) end

function AB.explain()
  return AB.state and AB.state.explain or {}
end

function AB.propose(ctx)
  local actions = {}

  if not _route_active() then return actions end
  if AB.state.enabled ~= true then return actions end
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then return actions end
  if Yso and Yso.mode and type(Yso.mode.is_hunt) == "function" and Yso.mode.is_hunt() then return actions end
  if Yso and Yso.mode and type(Yso.mode.is_party) == "function" and Yso.mode.is_party() then return actions end

  local tgt = _target()
  if tgt == "" then return actions end
  if type(Yso.target_is_valid) == "function" then
    local ok, v = pcall(Yso.target_is_valid, tgt)
    if ok and v ~= true then return actions end
  end

  local plan = CS.plan_aff(tgt)
  if plan.needs_mana_bury == true then
    _record_checkpoint("mana_bury")
  end
  local gate = _truename_gate(tgt, plan)
  local eq_cmd, eq_cat, eq_tag, eq_lock = _eq_plan(tgt, plan, gate)
  local bal_cmd, bal_cat = _bal_plan(tgt, plan)
  local class_cmd, class_cat = _entity_plan(tgt, plan)

  _record_checkpoint(eq_cat)
  _record_checkpoint(bal_cat)
  _record_checkpoint(class_cat)

  AB.state.last_target = tgt
  AB.state.explain = {
    route = "occ_aff_burst",
    target = tgt,
    mana_pct = plan.mana_pct,
    aura_physical = plan.physical,
    aura_mental = plan.mental,
    aura_speed = plan.speed,
    aura_blind = plan.blind,
    aura_deaf = plan.deaf,
    needs_readaura = plan.needs_readaura,
    needs_mana_bury = plan.needs_mana_bury,
    cleanseaura_ready = plan.cleanseaura_ready,
    truename_ready = _truebook_can_utter(tgt),
    truename_entry_eligible = gate.eligible,
    truename_entry_stable = gate.stable,
    truename_entry_stable_pulses = gate.stable_pulses,
    truename_entry_required = gate.required,
    resume_checkpoint = AB.state.resume_checkpoint,
    whisperingmadness = _has_aff(tgt, "whisperingmadness") or _has_aff(tgt, "whispering_madness"),
    mental_score = _mental_score(),
    enlighten_score = _enlighten_score(),
    burst_ready = _burst_ready(tgt),
    planned = { eq = eq_cmd, bal = bal_cmd, class = class_cmd },
    categories = { eq = eq_cat, bal = bal_cat, class = class_cat },
  }

  if eq_cmd then
    actions[#actions + 1] = {
      cmd = eq_cmd,
      qtype = "eq",
      kind = "offense",
      score = (eq_cat == "reserved_burst" and 60) or (eq_cat == "speed_strip_window" and 52) or (eq_cat == "truename_acquire" and 44) or 36,
      tag = eq_tag or ("ab:eq:" .. _lc(tgt)),
      category = eq_cat or "route",
      lockout = eq_lock,
      prefer_over_shared = _prefer_over_shared(eq_cat),
    }
  end

  if class_cmd and _ent_ready() then
    actions[#actions + 1] = {
      cmd = class_cmd,
      qtype = "class",
      kind = "offense",
      score = (class_cat == "reserved_burst" and 59) or 30,
      tag = "ab:class:" .. _lc(tgt) .. ":" .. _lc(class_cat or "route"),
      category = class_cat or "route",
    }
  end

  if bal_cmd and _bal_ready() then
    actions[#actions + 1] = {
      cmd = bal_cmd,
      qtype = "bal",
      kind = "offense",
      score = (bal_cat == "mental_build" and 24) or 16,
      tag = "ab:bal:" .. _lc(tgt) .. ":" .. _lc(bal_cat or "route"),
      category = bal_cat or "route",
    }
  end

  return actions
end

do
  local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(AB, AB.route_contract)
  end
end

if AB.cfg.use_orchestrator == true then
  _ensure_registered()
end

return AB
