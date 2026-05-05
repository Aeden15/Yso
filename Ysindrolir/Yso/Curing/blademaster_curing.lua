-- Yso/Curing/blademaster_curing.lua
-- Blademaster-specific defensive snapshot and gating logic.
-- Shared helper kept class-agnostic for combat routes.

Yso = Yso or {}
Yso.curing = Yso.curing or {}
Yso.curing.blademaster = Yso.curing.blademaster or {}

local BM = Yso.curing.blademaster

BM._targets = BM._targets or {}

local function _clock(v)
  v = tonumber(v)
  if not v then return 0 end
  if v > 20000000000 then v = v / 1000 end
  return v
end

local function _default_state()
  return {
    target_class = "",
    class_source = "",
    policy = false,
    state = "missing",
    ever_complete = false,
    blind = nil, blind_at = 0,
    deaf = nil, deaf_at = 0,
    shield = nil, shield_at = 0,
    physical = nil, physical_at = 0,
    mental = nil, mental_at = 0,
    speed = nil, speed_at = 0,
    mana_pct = nil, mana_at = 0,
  }
end

local function _get_state(tgt)
  tgt = tostring(tgt or ""):gsub("^%s+",""):gsub("%s+$",""):lower()
  if tgt == "" then return nil end
  BM._targets[tgt] = BM._targets[tgt] or _default_state()
  return BM._targets[tgt]
end

function BM.default_state()
  return _default_state()
end

function BM.reset_target(tgt)
  tgt = tostring(tgt or ""):gsub("^%s+",""):gsub("%s+$",""):lower()
  if tgt ~= "" then BM._targets[tgt] = nil end
end

function BM.snapshot_view(tgt, ctx)
  ctx = ctx or {}
  local info = ctx.class_info or { class = "", known = false, source = "" }
  local snap = ctx.snap
  local mana_pct = tonumber(ctx.mana_pct)
  local now = tonumber(ctx.now) or os.time()
  local shield_now = ctx.shield_is_up
  local meta = ctx.target_meta or {}
  local route_cfg = ctx.cfg or {}

  local fresh_ttl = tonumber(route_cfg.bm_snapshot_ttl_s or 24.0) or 24.0
  local carry_ttl = tonumber(route_cfg.bm_snapshot_carry_ttl_s or 30.0) or 30.0
  local shield_ttl = tonumber(route_cfg.bm_shield_ttl_s or 8.0) or 8.0

  local out = {
    active = false,
    class = info.class,
    class_known = info.known,
    class_source = info.source,
    state = "missing",
    needs_probe = false,
    passive_allowed = false,
    counts_under_pressure = false,
    blind = nil, blind_known = false, blind_fresh = false,
    deaf = nil, deaf_known = false, deaf_fresh = false,
    shield = nil, shield_known = false, shield_fresh = false,
    physical = nil, physical_known = false, physical_fresh = false,
    mental = nil, mental_known = false, mental_fresh = false,
    speed = nil, speed_known = false, speed_fresh = false,
    mana_pct = mana_pct,
    mana_known = (mana_pct ~= nil),
    mana_fresh = (mana_pct ~= nil),
  }

  if info.known ~= true or info.class ~= "Blademaster" then
    return out
  end

  local st = _get_state(tgt)
  if not st then return out end

  st.target_class = info.class
  st.class_source = info.source
  st.policy = true

  if snap and snap.fresh == true then
    if snap.read_complete == true then
      if snap.blind ~= nil then st.blind = (snap.blind == true); st.blind_at = now end
      if snap.deaf ~= nil then st.deaf = (snap.deaf == true); st.deaf_at = now end
      if snap.shield ~= nil then st.shield = (snap.shield == true); st.shield_at = now end
    end
    if snap.physical ~= nil then st.physical = tonumber(snap.physical); st.physical_at = now end
    if snap.mental ~= nil then st.mental = tonumber(snap.mental); st.mental_at = now end
    if snap.speed ~= nil then st.speed = (snap.speed == true); st.speed_at = now end
    if snap.had_mana == true and snap.mana_pct ~= nil then
      st.mana_pct = tonumber(snap.mana_pct)
      st.mana_at = now
    end
  end

  if mana_pct ~= nil then
    st.mana_pct = mana_pct
    st.mana_at = now
  end

  if type(shield_now) == "boolean" and (st.shield == nil or st.shield ~= shield_now) then
    st.shield = shield_now
    st.shield_at = now
  end

  local herb_at = _clock(meta.last_herb_at)
  local blind_fresh = (st.blind ~= nil) and ((now - _clock(st.blind_at)) <= fresh_ttl)
  local deaf_fresh = (st.deaf ~= nil) and ((now - _clock(st.deaf_at)) <= fresh_ttl)
  local shield_fresh_v = (st.shield ~= nil) and ((now - _clock(st.shield_at)) <= shield_ttl)
  local counts_under_pressure = (herb_at > 0)
    and ((herb_at > _clock(st.physical_at)) or (herb_at > _clock(st.mental_at)))
  local physical_fresh = (st.physical ~= nil) and ((now - _clock(st.physical_at)) <= fresh_ttl) and not counts_under_pressure
  local mental_fresh = (st.mental ~= nil) and ((now - _clock(st.mental_at)) <= fresh_ttl) and not counts_under_pressure
  local speed_fresh = (st.speed ~= nil) and ((now - _clock(st.speed_at)) <= carry_ttl)
  local mana_fresh_v = (st.mana_pct ~= nil) and ((now - _clock(st.mana_at)) <= carry_ttl)

  local complete_enough = blind_fresh and deaf_fresh and shield_fresh_v and physical_fresh and mental_fresh

  local required_known = 0
  if st.blind ~= nil then required_known = required_known + 1 end
  if st.deaf ~= nil then required_known = required_known + 1 end
  if st.shield ~= nil then required_known = required_known + 1 end
  if st.physical ~= nil then required_known = required_known + 1 end
  if st.mental ~= nil then required_known = required_known + 1 end

  if complete_enough then
    st.ever_complete = true
    st.state = "complete_enough"
  elseif required_known <= 0 then
    st.state = "missing"
  elseif st.ever_complete == true or counts_under_pressure then
    st.state = "stale"
  else
    st.state = "provisional"
  end

  out.active = true
  out.state = st.state
  out.needs_probe = (st.state ~= "complete_enough")
  out.passive_allowed = complete_enough
    and (tonumber(st.physical or 0) or 0) >= 4
    and (tonumber(st.mental or 0) or 0) >= 4
  out.counts_under_pressure = counts_under_pressure
  out.blind = blind_fresh and st.blind or nil
  out.blind_known = (st.blind ~= nil)
  out.blind_fresh = blind_fresh
  out.deaf = deaf_fresh and st.deaf or nil
  out.deaf_known = (st.deaf ~= nil)
  out.deaf_fresh = deaf_fresh
  out.shield = shield_fresh_v and st.shield or nil
  out.shield_known = (st.shield ~= nil)
  out.shield_fresh = shield_fresh_v
  out.physical = physical_fresh and st.physical or nil
  out.physical_known = (st.physical ~= nil)
  out.physical_fresh = physical_fresh
  out.mental = mental_fresh and st.mental or nil
  out.mental_known = (st.mental ~= nil)
  out.mental_fresh = mental_fresh
  out.speed = speed_fresh and st.speed or nil
  out.speed_known = (st.speed ~= nil)
  out.speed_fresh = speed_fresh
  out.mana_pct = mana_fresh_v and tonumber(st.mana_pct) or nil
  out.mana_known = (st.mana_pct ~= nil)
  out.mana_fresh = mana_fresh_v

  return out
end

function BM.should_gate(t)
  if type(t) ~= "table" then return false end
  local active = (t.bm_snapshot_active == true) or (t.active == true)
  local passive = (t.bm_passive_allowed == true) or (t.passive_allowed == true)
  return active and not passive
end

function BM.plan_fields(bm, tgt, has_aff_fn)
  local has_aff = type(has_aff_fn) == "function" and has_aff_fn or function() return false end
  local bm_entry = (bm.active == true and has_aff(tgt, "asthma"))
  local bm_branch_active = bm_entry and bm.state == "complete_enough"
    and (has_aff(tgt, "paralysis") or has_aff(tgt, "weariness"))
  local bm_branch_provisional = bm_entry and not bm_branch_active
  return {
    bm_snapshot = bm,
    bm_snapshot_state = bm.state,
    bm_snapshot_active = (bm.active == true),
    bm_snapshot_complete = (bm.state == "complete_enough"),
    bm_snapshot_provisional = (bm.state == "provisional"),
    bm_branch_active = (bm_branch_active == true),
    bm_branch_provisional = (bm_branch_provisional == true),
    bm_passive_allowed = (bm.passive_allowed == true),
  }
end

function BM.overlay(bm, vals)
  if bm.active ~= true then return vals end
  vals = vals or {}
  vals.blind = bm.blind
  vals.deaf = bm.deaf
  vals.speed = (bm.speed ~= nil) and bm.speed or vals.speed
  vals.shield = (bm.shield ~= nil) and bm.shield or vals.shield
  vals.physical = bm.physical
  vals.mental = bm.mental
  if bm.mana_pct ~= nil then vals.mana_pct = bm.mana_pct end
  return vals
end

function BM.para_adjust(cfg, is_bm_branch_active)
  cfg = cfg or {}
  local threshold = tonumber(
    (is_bm_branch_active and cfg.para_bm_override_threshold)
    or cfg.para_override_threshold or 0.75
  ) or 0.75
  local bonus = is_bm_branch_active and 0.10 or 0
  return threshold, bonus
end

function BM.explain(plan)
  if type(plan) ~= "table" then return {} end
  local snap = plan.bm_snapshot
  return {
    state = plan.bm_snapshot_state,
    active = plan.bm_snapshot_active == true,
    complete = plan.bm_snapshot_complete == true,
    provisional = plan.bm_snapshot_provisional == true,
    blind = { known = snap and snap.blind_known == true, fresh = snap and snap.blind_fresh == true, value = snap and snap.blind },
    deaf = { known = snap and snap.deaf_known == true, fresh = snap and snap.deaf_fresh == true, value = snap and snap.deaf },
    shield = { known = snap and snap.shield_known == true, fresh = snap and snap.shield_fresh == true, value = snap and snap.shield },
    physical = { known = snap and snap.physical_known == true, fresh = snap and snap.physical_fresh == true, value = snap and snap.physical },
    mental = { known = snap and snap.mental_known == true, fresh = snap and snap.mental_fresh == true, value = snap and snap.mental },
    speed = { known = snap and snap.speed_known == true, fresh = snap and snap.speed_fresh == true, value = snap and snap.speed },
    mana = { known = snap and snap.mana_known == true, fresh = snap and snap.mana_fresh == true, value = snap and snap.mana_pct },
    passive_allowed = plan.bm_passive_allowed == true,
    counts_under_pressure = snap and snap.counts_under_pressure == true,
  }
end

return BM
