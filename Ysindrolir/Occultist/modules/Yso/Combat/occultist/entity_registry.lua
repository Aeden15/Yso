-- Auto-exported from Mudlet package script: entity_registry.lua
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- entity_registry.lua
--  • Route-agnostic Occultist entity registry / selector core
--  • Phase 1 roster: worm, storm, slime, sycophant, humbug, firelord
--  • Returns ranked legal candidates and compact skip reasons
--  • Tracks per-target bootstrap / invalidation / reservation / effect state
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}
Yso.off.oc.entity_registry = Yso.off.oc.entity_registry or {}

local ER = Yso.off.oc.entity_registry

ER.cfg = ER.cfg or {
  invalidation_timeout_s = 8,
  worm_duration_s = 20,
  worm_refresh_lead_s = 1.0,
  sycophant_duration_s = 30,
  sycophant_refresh_lead_s = 1.0,
  phase_one = { "worm", "storm", "slime", "sycophant", "humbug", "firelord" },
  stable_order = { worm = 1, storm = 2, slime = 3, sycophant = 4, humbug = 5, firelord = 6 },
}

ER.state = ER.state or {
  current_target = "",
  targets = {},
  cooldown_until = {},
  last_debug = nil,
  explicit_primebond = {},
}

local DOM_KEYS = {
  worm = "worm",
  storm = "danaeus",
  slime = "ninkharsag",
  sycophant = "rixil",
  humbug = "nemesis",
  firelord = "pyradius",
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
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  if type(getEpoch) == "function" then
    local ok, v = pcall(getEpoch)
    v = ok and tonumber(v) or nil
    if v then
      if v > 1e12 then v = v / 1000 end
      return v
    end
  end
  return os.time()
end

local function _dbg(msg)
  if ER.cfg.debug == true and type(cecho) == "function" then
    cecho(("<MediumPurple>[Yso:ER] <reset>%s\n"):format(tostring(msg)))
  end
end

local function _dom(ent)
  ent = _lc(ent)
  local key = DOM_KEYS[ent] or ent
  if Yso and Yso.occ and type(Yso.occ.getDom) == "function" then
    return Yso.occ.getDom(key)
  end
  return nil
end

local function _queue_flag(ent)
  local d = _dom(ent)
  return d and d.queue_flag or "ent"
end

local function _bal_cost(ent)
  local d = _dom(ent)
  return tonumber(d and d.bal_cost or 0) or 0
end

local function _tstate(tgt, create)
  local tkey = _lc(tgt)
  if tkey == "" then return nil end
  local T = ER.state.targets[tkey]
  if not T and create ~= false then
    T = {
      target = tgt,
      established = { worm = false, sycophant = false },
      invalid_until = {},
      invalid_reason = {},
      invalid_since = {},
      reservation = nil,
      effects = {
        worm = { target = "", until_t = 0, proc_count = 0, proc_window_until = 0, last_proc_at = 0 },
        sycophant = { target = "", until_t = 0 },
      },
      last_sent_at = {},
      last_success_at = {},
      last_target_valid_at = 0,
    }
    ER.state.targets[tkey] = T
  end
  return T
end

local function _clear_expired_invalids(T)
  if type(T) ~= "table" then return end
  local now = _now()
  for ent, until_t in pairs(T.invalid_until or {}) do
    if tonumber(until_t or 0) <= now then
      T.invalid_until[ent] = nil
      T.invalid_reason[ent] = nil
      T.invalid_since[ent] = nil
    end
  end
end

local function _cmd(ent, tgt, extra)
  ent = _lc(ent)
  tgt = _trim(tgt)
  if ent == "" or tgt == "" then return nil end
  local d = _dom(ent)
  local syn = d and d.syntax or nil
  if type(syn) == "table" then syn = syn[1] end
  syn = tostring(syn or "")
  if syn == "" then
    if ent == "firelord" and extra and extra ~= "" then
      return ("command firelord at %s %s"):format(tgt, extra)
    end
    return ("command %s at %s"):format(ent, tgt)
  end
  syn = syn:gsub("<target>", tgt)
  if extra and extra ~= "" then
    syn = syn:gsub("<affliction>", tostring(extra))
  else
    syn = syn:gsub("%s+<affliction>", "")
  end
  syn = syn:gsub("%s+;.*$", "")
  return syn:lower()
end

local function _parse_cmd(cmd)
  cmd = _trim(cmd)
  if cmd == "" then return nil end
  local lc = cmd:lower()
  local ent, tgt, extra = lc:match("^command%s+([%w_']+)%s+at%s+([%w_'-]+)%s*(.*)$")
  if ent then
    extra = _trim(extra)
    return ent, tgt, extra
  end
  return nil
end

local function _target_valid(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return false end
  if type(Yso.target_is_valid) == "function" then
    local ok, v = pcall(Yso.target_is_valid, tgt)
    if ok then return v == true end
  end
  return true
end

local function _has_aff_target(tgt, aff)
  tgt = _trim(tgt)
  aff = _lc(aff)
  if tgt == "" or aff == "" then return false end

  if Yso and Yso.tgt and type(Yso.tgt.has_aff) == "function" then
    local ok, v = pcall(Yso.tgt.has_aff, tgt, aff)
    if ok then return v == true end
  end

  if Yso and Yso.state and type(Yso.state.tgt_has_aff) == "function" then
    local ok, v = pcall(Yso.state.tgt_has_aff, tgt, aff)
    if ok then return v == true end
  end

  return false
end

local function _firelord_convert_aff(tgt, has_aff)
  has_aff = type(has_aff) == "function" and has_aff or function(aff)
    return _has_aff_target(tgt, aff)
  end

  local pyr = _dom("firelord") or _dom("pyradius") or {}
  local converts = type(pyr.converts) == "table" and pyr.converts or {}

  local wm_dest = _lc(converts.whisperingmadness or converts.whispering_madness or "recklessness")
  local ml_dest = _lc(converts.manaleech or "anorexia")
  local hl_dest = _lc(converts.healthleech or "psychic_damage")

  if has_aff("whisperingmadness") and not has_aff(wm_dest) then return wm_dest end
  if has_aff("whispering_madness") and not has_aff(wm_dest) then return wm_dest end
  if has_aff("manaleech") and not has_aff(ml_dest) then return ml_dest end
  if has_aff("healthleech") and not has_aff(hl_dest) then return hl_dest end
  return nil
end

local function _ent_ready(ctx)
  if ctx and ctx.ent_ready ~= nil then return ctx.ent_ready == true end
  if Yso.state and type(Yso.state.ent_ready) == "function" then
    local ok, v = pcall(Yso.state.ent_ready)
    if ok then return v == true end
  end
  return true
end

function ER.firelord_aff(tgt, ctx)
  ctx = type(ctx) == "table" and ctx or {}
  return _firelord_convert_aff(tgt, ctx.has_aff)
end

function ER.target_swap(tgt)
  local tkey = _lc(tgt)
  if tkey == "" then return end
  if ER.state.current_target ~= tkey then
    local old = ER.state.current_target
    if old ~= "" then ER.state.targets[old] = nil end
    ER.state.current_target = tkey
    ER.state.targets[tkey] = nil
    _tstate(tgt, true)
    _dbg("target_swap -> " .. tkey)
  else
    _tstate(tgt, true)
  end
end

function ER.clear_target(tgt)
  local tkey = _lc(tgt)
  if tkey ~= "" then ER.state.targets[tkey] = nil end
  if ER.state.current_target == tkey then ER.state.current_target = "" end
end

function ER.set_primebond(entity, on, src)
  entity = _lc(entity)
  if entity == "" then return end
  ER.state.explicit_primebond[entity] = (on == true)
  _dbg(("primebond %s=%s (%s)"):format(entity, tostring(on == true), tostring(src or "manual")))
end

function ER.is_primebonded(entity)
  entity = _lc(entity)
  if entity == "" then return false end
  if ER.state.explicit_primebond[entity] ~= nil then
    return ER.state.explicit_primebond[entity] == true
  end
  local P = Yso.primebond and Yso.primebond.bonds or nil
  if type(P) ~= "table" then return false end
  local d = _dom(entity)
  local name = _lc((d and d.name) or entity)
  return P[name] == true
end

function ER.note_target_valid(tgt)
  local T = _tstate(tgt, true)
  if not T then return end
  T.last_target_valid_at = _now()
  T.invalid_until = {}
  T.invalid_reason = {}
  T.invalid_since = {}
end

function ER.note_fail(entity, tgt, reason)
  entity = _lc(entity)
  local T = _tstate(tgt, true)
  if entity == "" or not T then return end
  local now = _now()
  local until_t = now + (tonumber(ER.cfg.invalidation_timeout_s) or 8)
  T.invalid_until[entity] = until_t
  T.invalid_reason[entity] = tostring(reason or "entity_fail")
  T.invalid_since[entity] = now
  _dbg(("invalid %s for %s (%s)"):format(entity, _lc(tgt), tostring(reason or "entity_fail")))
end

function ER.note_fail_from_cmd(cmd, reason)
  local ent, tgt = _parse_cmd(cmd)
  if ent and tgt then return ER.note_fail(ent, tgt, reason) end
end

function ER.note_success(entity, tgt, src)
  entity = _lc(entity)
  local T = _tstate(tgt, true)
  if entity == "" or not T then return end
  T.invalid_until[entity] = nil
  T.invalid_reason[entity] = nil
  T.invalid_since[entity] = nil
  T.last_success_at[entity] = _now()
  if entity == "worm" then
    T.established.worm = true
  elseif entity == "sycophant" then
    T.established.sycophant = true
  end
  _dbg(("success %s for %s (%s)"):format(entity, _lc(tgt), tostring(src or "ok")))
end

function ER.note_sent(entity, tgt, meta)
  entity = _lc(entity)
  local T = _tstate(tgt, true)
  if entity == "" or not T then return end
  local now = _now()
  local cd = _bal_cost(entity)
  if cd > 0 then ER.state.cooldown_until[entity] = now + cd end
  T.last_sent_at[entity] = now
  T.invalid_until[entity] = nil
  T.invalid_reason[entity] = nil
  T.invalid_since[entity] = nil

  if entity == "worm" then
    T.established.worm = true
    T.effects.worm.target = tgt
    T.effects.worm.until_t = now + (tonumber(ER.cfg.worm_duration_s) or 20)
    T.effects.worm.proc_count = 0
    T.effects.worm.proc_window_until = now + math.max(5, (tonumber(ER.cfg.worm_duration_s) or 20) + 15)
    T.effects.worm.last_proc_at = 0
  elseif entity == "sycophant" then
    T.established.sycophant = true
    T.effects.sycophant.target = tgt
    T.effects.sycophant.until_t = now + (tonumber(ER.cfg.sycophant_duration_s) or 30)
  elseif entity == "firelord" and type(meta) == "table" and tostring(meta.aff or "") == "healthleech" then
    T.reservation = nil
  end
end

function ER.note_manual_success(cmd_or_entity, tgt)
  local ent, target = nil, nil
  if type(cmd_or_entity) == "string" and cmd_or_entity:lower():match("^command%s+") then
    ent, target = _parse_cmd(cmd_or_entity)
  else
    ent, target = tostring(cmd_or_entity or ""), tostring(tgt or "")
  end
  ent, target = _lc(ent), _trim(target)
  if ent == "" or target == "" then return end
  ER.note_sent(ent, target, { source = "manual_success" })
  ER.note_success(ent, target, "manual_success")
end

function ER.note_payload_sent(payload)
  if type(payload) ~= "table" then return end
  local cls = payload.class or payload.ent or payload.entity
  if type(cls) ~= "string" then return end
  local ent, tgt, extra = _parse_cmd(cls)
  if not ent or not tgt then return end
  ER.note_sent(ent, tgt, { aff = extra, source = "payload" })
end

function ER.note_worm_proc(tgt)
  local T = _tstate(tgt, false)
  if not T then return end
  local W = T.effects.worm
  if _lc(W.target) ~= _lc(tgt) then return end
  local now = _now()
  if tonumber(W.proc_window_until or 0) < now then
    W.proc_count = 0
    W.proc_window_until = now + ((tonumber(ER.cfg.worm_duration_s) or 20) + 15)
  end
  W.last_proc_at = now
  T.last_success_at.worm = math.max(tonumber(T.last_success_at.worm or 0) or 0, now)
  W.proc_count = (tonumber(W.proc_count or 0) or 0) + 1
  if W.proc_count >= 2 then
    W.until_t = 0
    W.proc_count = 0
    W.proc_window_until = 0
  end
end

function ER.worm_should_refresh(tgt)
  local T = _tstate(tgt, false)
  if not T then return true end
  local W = T.effects.worm
  if _lc(W.target) ~= _lc(tgt) then return true end
  local now = _now()
  if tonumber(W.proc_count or 0) >= 2 then return true end
  return now >= ((tonumber(W.until_t or 0) or 0) - (tonumber(ER.cfg.worm_refresh_lead_s) or 1.0))
end

function ER.syc_should_refresh(tgt)
  local T = _tstate(tgt, false)
  if not T then return true end
  local S = T.effects.sycophant
  local now = _now()
  return now >= ((tonumber(S.until_t or 0) or 0) - (tonumber(ER.cfg.sycophant_refresh_lead_s) or 1.0))
end

function ER.bootstrap_done(tgt, ctx)
  local T = _tstate(tgt, true)
  if not T then return true end
  if T.established.worm == true and T.established.sycophant == true then return true end
  local probe = {}
  if type(ctx) == "table" then
    for k, v in pairs(ctx) do probe[k] = v end
  end
  probe.target = tgt
  probe.category = "bootstrap_setup"
  probe._bootstrap_probe = true
  local ranked = ER.rank(probe)
  return (#ranked == 0)
end

local function _candidate_sort(a, b)
  if tonumber(a.score or 0) ~= tonumber(b.score or 0) then
    return tonumber(a.score or 0) > tonumber(b.score or 0)
  end
  local ar = tonumber(a.recast or 99) or 99
  local br = tonumber(b.recast or 99) or 99
  if ar ~= br then return ar < br end
  local ab = tonumber(a.burst_support or 0) or 0
  local bb = tonumber(b.burst_support or 0) or 0
  if ab ~= bb then return ab > bb end
  local ao = tonumber((ER.cfg.stable_order or {})[a.entity] or 999) or 999
  local bo = tonumber((ER.cfg.stable_order or {})[b.entity] or 999) or 999
  return ao < bo
end

local function _skipped_set(skipped, entity, why)
  if skipped[entity] == nil then skipped[entity] = tostring(why or "skip") end
end

local function _is_invalid(T, ent)
  local until_t = tonumber(T.invalid_until[ent] or 0) or 0
  return until_t > _now(), until_t
end

function ER.rank(ctx)
  ctx = ctx or {}
  local tgt = _trim(ctx.target or ER.state.current_target)
  local tkey = _lc(tgt)
  if tkey == "" then return {}, { global = "no_target" } end
  ER.target_swap(tgt)
  local T = _tstate(tgt, true)
  _clear_expired_invalids(T)

  local category = tostring(ctx.category or "fallback_support")
  local st = ctx.route_state or {}
  local need = ctx.need or {}
  local has_aff = type(ctx.has_aff) == "function" and ctx.has_aff or function() return false end
  local ent_ready = _ent_ready(ctx)
  local target_valid
  if ctx.target_valid ~= nil then
    target_valid = (ctx.target_valid == true)
  else
    target_valid = _target_valid(tgt)
  end
  local ranked, skipped = {}, {}
  local now = _now()

  if not ent_ready then return ranked, { global = "lane_not_ready" } end
  if not target_valid then return ranked, { global = "target_invalid" } end

  local function legal_common(ent)
    local bad, until_t = _is_invalid(T, ent)
    if bad then return false, "invalidated" end
    local cd = tonumber(ER.state.cooldown_until[ent] or 0) or 0
    if cd > now then return false, "cooldown" end
    return true, nil
  end

  local function add(ent, score, extra_aff, meta)
    local ok, why = legal_common(ent)
    if not ok then _skipped_set(skipped, ent, why); return end
    local d = _dom(ent)
    ranked[#ranked + 1] = {
      entity = ent,
      cmd = _cmd(ent, tgt, extra_aff),
      score = tonumber(score or 0) or 0,
      category = category,
      meta = meta or {},
      recast = tonumber(d and d.bal_cost or 99) or 99,
      burst_support = tonumber((meta or {}).burst_support or 0) or 0,
    }
  end

  local prime_humbug = ER.is_primebonded("humbug")
  local prime_syc = ER.is_primebonded("sycophant")
  local prime_slime = ER.is_primebonded("slime")
  local addiction = has_aff("addiction") or st.addiction == true
  local paralysis = has_aff("paralysis") or st.paralysis == true
  local asthma = has_aff("asthma") or st.asthma == true
  local healthleech = has_aff("healthleech") or st.healthleech == true

  if category == "reserved_paired_burst" then
    if healthleech and ctx.eq_ready == true then
      add("firelord", 100, "healthleech", { burst_support = 10 })
    else
      _skipped_set(skipped, "firelord", "burst_not_ready")
    end
  elseif category == "convert_support" then
    local aff = _lc(ctx.firelord_aff or _firelord_convert_aff(tgt, has_aff) or "")
    if aff ~= "" then
      add("firelord", 72, aff, { burst_support = 8, convert = true })
    else
      _skipped_set(skipped, "firelord", "no_convert_source")
    end
  elseif category == "bootstrap_setup" then
    if T.established.worm ~= true then
      add("worm", 92 + ((need.healthleech and 1) or 0) * 4, nil, { burst_support = 6 })
    else
      _skipped_set(skipped, "worm", "bootstrap_done")
    end
    if T.established.sycophant ~= true then
      add("sycophant", 88 + ((prime_syc and 1) or 0) * 3, nil, { burst_support = 2 })
    else
      _skipped_set(skipped, "sycophant", "bootstrap_done")
    end
    if need.clumsiness == true then
      add("storm", 76, nil, { burst_support = 3 })
    else
      _skipped_set(skipped, "storm", "not_needed")
    end
  elseif category == "required_core_refresh" or category == "required_core_application" then
    if need.healthleech == true then
      if ER.worm_should_refresh(tgt) then
        add("worm", 84 + (((st.sensitivity and st.clumsiness) and 1) or 0) * 6, nil, { burst_support = 7 })
      else
        _skipped_set(skipped, "worm", "window_active")
      end
    end
    if need.clumsiness == true then
      add("storm", 82, nil, { burst_support = 4 })
    end
  elseif category == "fallback_support" or category == "passive_pressure_only" then
    if ER.syc_should_refresh(tgt) then
      add("sycophant", 36 + ((prime_syc and 1) or 0) * 8, nil, { burst_support = 2 })
    else
      _skipped_set(skipped, "sycophant", "window_active")
    end
    if healthleech or (asthma and not paralysis) then
      local bonus = 0
      if healthleech then bonus = bonus + 10 end
      if asthma and not paralysis then bonus = bonus + 8 end
      if prime_slime then bonus = bonus + 5 end
      add("slime", 32 + bonus, nil, { burst_support = 1 })
    else
      _skipped_set(skipped, "slime", "no_followup_value")
    end
    if not addiction then
      local bonus = prime_humbug and 18 or 0
      add("humbug", 24 + bonus, nil, { burst_support = 1 })
    else
      _skipped_set(skipped, "humbug", "already_addicted")
    end
  end

  table.sort(ranked, _candidate_sort)
  ER.state.last_debug = {
    at = now,
    target = tkey,
    category = category,
    ranked = ranked,
    skipped = skipped,
  }
  return ranked, skipped
end

function ER.pick(ctx)
  local ranked, skipped = ER.rank(ctx)
  if ranked[1] then return ranked[1], { ranked = ranked, skipped = skipped } end
  return nil, { ranked = ranked, skipped = skipped }
end

return ER
--========================================================--
