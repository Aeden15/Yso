--========================================================--
-- occ_aff.lua
--  Thin Occultist affliction loop (Sunder-style)
--  Canonical module: Yso.off.oc.occ_aff
--  Compatibility aliases: Yso.off.oc.aff, Yso.off.oc.occ_aff_burst
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

Yso.off.oc.occ_aff = Yso.off.oc.occ_aff or Yso.off.oc.aff or Yso.off.oc.occ_aff_burst or {}
Yso.off.oc.aff = Yso.off.oc.occ_aff
Yso.off.oc.occ_aff_burst = Yso.off.oc.occ_aff

local A = Yso.off.oc.occ_aff
A.alias_owned = true

A.route_contract = A.route_contract or {
  id = "occ_aff",
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = {
    "open",
    "pressure",
    "maintain_pressure",
    "cleanse_truename",
    "whisper_enlighten",
    "unravel",
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

A.cfg = A.cfg or {
  echo = true,
  enabled = false,
  loop_delay = 0.15,
  readaura_every = 8,
  max_observe = 3,
  enlighten_target = 5,
  unravel_mentals = 4,
  loyals_on_cmd = "order entourage kill %s",
}

A.state = A.state or {
  enabled = (A.cfg.enabled == true),
  loop_enabled = (A.cfg.enabled == true),
  busy = false,
  timer_id = nil,
  waiting = { queue = nil, at = 0 },
  last_attack = { cmd = "", at = 0, target = "" },
  loop_delay = tonumber(A.cfg.loop_delay or 0.15) or 0.15,
  last_target = "",
  last_readaura = 0,
  observe_tries = {},
  defer_unnamable = nil,
  explain = {},
}

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
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

local function _eq()
  if Yso and Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then return v == true end
  end
  local vit = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(vit.eq or vit.equilibrium or "") == "1" or vit.eq == true or vit.equilibrium == true
end

local function _bal()
  if Yso and Yso.state and type(Yso.state.bal_ready) == "function" then
    local ok, v = pcall(Yso.state.bal_ready)
    if ok then return v == true end
  end
  local vit = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(vit.bal or vit.balance or "") == "1" or vit.bal == true or vit.balance == true
end

local function _ent()
  if Yso and Yso.state and type(Yso.state.ent_ready) == "function" then
    local ok, v = pcall(Yso.state.ent_ready)
    if ok then return v == true end
  end
  return true
end

local function _ra_due()
  local every = tonumber(A.cfg.readaura_every or 8) or 8
  return (_now() - (tonumber(A.state.last_readaura or 0) or 0)) >= every
end

local function _emit(payload, tgt)
  A.state.waiting = A.state.waiting or { queue = nil, at = 0 }
  A.state.last_attack = A.state.last_attack or { cmd = "", at = 0, target = "" }

  local parts = {}
  if type(payload.free) == "table" then
    for i = 1, #payload.free do
      local s = _trim(payload.free[i])
      if s ~= "" then parts[#parts + 1] = s end
    end
  end

  local eq_cmd = _trim(payload.eq)
  local bal_cmd = _trim(payload.bal)
  local ent_cmd = _trim(payload.class)

  if eq_cmd ~= "" then parts[#parts + 1] = eq_cmd end
  if bal_cmd ~= "" then parts[#parts + 1] = bal_cmd end
  if ent_cmd ~= "" then parts[#parts + 1] = ent_cmd end

  local line = table.concat(parts, Yso.sep or "&&")
  if line == "" then return false end

  if _trim(A.state.waiting.queue) ~= "" then
    return false
  end

  local last = A.state.last_attack
  if _trim(last.cmd) == line and _trim(last.target) == _trim(tgt) then
    return false
  end

  local ok = false
  if Yso.queue and type(Yso.queue.emit) == "function" then
    local sent_ok, sent = pcall(Yso.queue.emit, payload, {
      target = tgt,
      route = "occ_aff",
      allow_eqbal = true,
      prefer = "eq",
    })
    ok = (sent_ok == true and sent == true)
  elseif type(Yso.attack) == "function" then
    local sent_ok, sent = pcall(Yso.attack, line)
    ok = (sent_ok == true and sent == true)
  end

  if ok ~= true then
    return false
  end

  A.state.last_attack.cmd = line
  A.state.last_attack.at = _now()
  A.state.last_attack.target = _trim(tgt)

  A.state.waiting.queue = line
  A.state.waiting.at = _now()

  local release_after = tonumber(A.state.loop_delay or A.cfg.loop_delay or 0.15) or 0.15
  if type(tempTimer) == "function" then
    tempTimer(release_after, function()
      if A and A.state and type(A.state.waiting) == "table" then
        A.state.waiting.queue = nil
        A.state.waiting.at = 0
      end
    end)
  else
    A.state.waiting.queue = nil
    A.state.waiting.at = 0
  end

  return true
end

function A.init()
  A.cfg = A.cfg or {}
  A.state = A.state or {}
  A.state.waiting = A.state.waiting or { queue = nil, at = 0 }
  A.state.last_attack = A.state.last_attack or { cmd = "", at = 0, target = "" }
  A.state.observe_tries = A.state.observe_tries or {}
  A.state.explain = type(A.state.explain) == "table" and A.state.explain or {}
  if A.state.loop_delay == nil then
    A.state.loop_delay = tonumber(A.cfg.loop_delay or 0.15) or 0.15
  end
  return true
end

function A.reset(reason)
  A.init()
  local target = _trim(A.state.last_target)
  A.state.waiting.queue = nil
  A.state.waiting.at = 0
  A.state.last_attack = { cmd = "", at = 0, target = "" }
  A.state.defer_unnamable = nil
  A.state.observe_tries = {}
  A.state.last_readaura = 0
  if target ~= "" and Yso.occ and type(Yso.occ.set_phase) == "function" then
    pcall(Yso.occ.set_phase, target, "open", reason or "reset")
  end
  return true
end

function A.is_enabled()
  return A.state and A.state.enabled == true
end

function A.is_active()
  return A.state and A.state.loop_enabled == true
end

function A.can_run(ctx)
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() == true then
    return false, "pause"
  end
  return true
end

function A.schedule_loop(delay)
  if Yso and Yso.mode and type(Yso.mode.schedule_route_loop) == "function" then
    return Yso.mode.schedule_route_loop("occ_aff", delay)
  end
  return false
end

A.alias_loop_stop_details = A.alias_loop_stop_details or {
  target_invalid = true,
  target_slain = true,
  route_off = true,
}

function A.alias_loop_prepare_start(ctx)
  A.init()
  A.state.enabled = true
  A.state.loop_enabled = true
  A.state.busy = false
  A.state.waiting.queue = nil
  A.state.waiting.at = 0
  return ctx or {}
end

function A.alias_loop_on_started(ctx)
  if A.cfg.echo == true then
    if type(cecho) == "function" then
      cecho("<HotPink>[Occultism] <reset>Aff loop ON.\n")
    elseif type(echo) == "function" then
      echo("[Occultism] Aff loop ON.\n")
    end
  end
  return true
end

function A.alias_loop_on_stopped(ctx)
  A.state.loop_enabled = false
  A.state.busy = false
  A.state.waiting.queue = nil
  A.state.waiting.at = 0
  if not (type(ctx) == "table" and ctx.silent == true) then
    if A.cfg.echo == true then
      if type(cecho) == "function" then
        cecho(string.format("<HotPink>[Occultism] <reset>Aff loop OFF (%s).\n", tostring((ctx and ctx.reason) or "manual")))
      elseif type(echo) == "function" then
        echo(string.format("[Occultism] Aff loop OFF (%s).\n", tostring((ctx and ctx.reason) or "manual")))
      end
    end
  end
  return true
end

function A.alias_loop_clear_waiting()
  A.state.waiting = A.state.waiting or {}
  A.state.waiting.queue = nil
  A.state.waiting.at = 0
  return true
end

function A.alias_loop_waiting_blocks()
  local wait = A.state and A.state.waiting or nil
  if type(wait) ~= "table" then return false end
  local q = _trim(wait.queue)
  if q == "" then return false end
  local max_age = math.max(0.15, tonumber(A.state.loop_delay or A.cfg.loop_delay or 0.15) or 0.15) + 0.35
  local age = _now() - (tonumber(wait.at or 0) or 0)
  if age >= max_age then
    A.alias_loop_clear_waiting()
    return false
  end
  return true
end

function A.alias_loop_on_error(err)
  if A.cfg.echo == true then
    if type(cecho) == "function" then
      cecho(string.format("<HotPink>[Occultism] <reset>Loop error: %s\n", tostring(err)))
    elseif type(echo) == "function" then
      echo(string.format("[Occultism] Loop error: %s\n", tostring(err)))
    end
  end
  return true
end

function A.attack_function(arg)
  A.init()
  arg = type(arg) == "table" and arg or {}
  local ctx = type(arg.ctx) == "table" and arg.ctx or {}
  local preview = (arg.preview == true)

  local tgt = _trim(ctx.target)
  if tgt == "" and type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok then tgt = _trim(v) end
  end
  if tgt == "" then
    local ak = rawget(_G, "ak")
    if type(ak) == "table" then
      tgt = _trim(ak.target or ak.tgt)
    end
  end
  if tgt == "" then
    return false, "no_target"
  end

  if type(Yso.target_is_valid) == "function" then
    local ok, valid = pcall(Yso.target_is_valid, tgt)
    if ok and valid ~= true then
      return false, "target_invalid"
    end
  end

  local tkey = tgt:lower()
  A.state.last_target = tgt

  if _trim(A.state.phase_tgt) ~= tkey then
    A.state.phase_tgt = tkey
    A.state.observe_tries[tkey] = 0
    A.state.defer_unnamable = nil
    if Yso.occ and type(Yso.occ.set_phase) == "function" then
      pcall(Yso.occ.set_phase, tgt, "open", "new_target")
    end
  end

  local payload = {
    target = tgt,
    route = "occ_aff",
    free = {},
    eq = "",
    bal = "",
    class = "",
  }

  local phase = "open"
  if Yso.occ and type(Yso.occ.get_phase) == "function" then
    local ok, v = pcall(Yso.occ.get_phase, tgt)
    if ok and type(v) == "string" and _trim(v) ~= "" then
      phase = _trim(v)
    end
  end

  -- 1 open
  local loyals_hostile = false
  if type(Yso.loyals_attacking) == "function" then
    local ok, v = pcall(Yso.loyals_attacking, tgt)
    loyals_hostile = (ok and v == true)
  elseif type(Yso.loyals_attack) == "function" then
    local ok, v = pcall(Yso.loyals_attack, tgt)
    loyals_hostile = (ok and v == true)
  end
  if not loyals_hostile then
    payload.free[#payload.free + 1] = string.format(A.cfg.loyals_on_cmd or "order entourage kill %s", tgt)
  end

  local ra_ready = true
  if Yso.occ and type(Yso.occ.readaura_is_ready) == "function" then
    local ok, v = pcall(Yso.occ.readaura_is_ready)
    ra_ready = (ok and v == true)
  end
  if payload.eq == "" and _eq() and ra_ready and _ra_due() and (phase == "open" or phase == "pressure") then
    payload.eq = "readaura " .. tgt
  end

  local cleanse_live = false
  if Yso.occ and type(Yso.occ.cleanse_ready) == "function" then
    local ok, v = pcall(Yso.occ.cleanse_ready, tgt)
    cleanse_live = (ok and v == true)
  end

  if phase == "open" then
    if Yso.occ and type(Yso.occ.set_phase) == "function" then
      pcall(Yso.occ.set_phase, tgt, "pressure", "open_done")
    end
  elseif phase == "pressure" and cleanse_live then
    if Yso.occ and type(Yso.occ.set_phase) == "function" then
      pcall(Yso.occ.set_phase, tgt, "cleanse", "cleanse_gate_on")
    end
  elseif phase == "cleanse" and not cleanse_live then
    if Yso.occ and type(Yso.occ.set_phase) == "function" then
      pcall(Yso.occ.set_phase, tgt, "pressure", "cleanse_gate_drop")
    end
  end
  phase = "open"
  if Yso.occ and type(Yso.occ.get_phase) == "function" then
    local ok, v = pcall(Yso.occ.get_phase, tgt)
    if ok and type(v) == "string" and _trim(v) ~= "" then
      phase = _trim(v)
    end
  end

  -- 2 pressure
  if (phase == "open" or phase == "pressure") and payload.eq == "" and _eq() and Yso.occ and type(Yso.occ.pressure) == "function" then
    local ok, cmd = pcall(Yso.occ.pressure, tgt)
    payload.eq = ok and _trim(cmd) or ""
  end

  -- 4 maintain pressure
  if payload.class == "" and _ent() and Yso.occ and type(Yso.occ.ent_refresh) == "function" then
    local ok, cmd = pcall(Yso.occ.ent_refresh, tgt, { phase = phase })
    payload.class = ok and _trim(cmd) or ""
  end

  -- 3 cleanse/truename
  if phase == "cleanse" then
    local need_attend = false
    if Yso.occ and type(Yso.occ.aura_need_attend) == "function" then
      local ok, v = pcall(Yso.occ.aura_need_attend, tgt)
      need_attend = (ok and v == true)
    end

    if need_attend and payload.eq == "" and _eq() then
      payload.eq = "attend " .. tgt
    end

    if need_attend and payload.class == "" and _ent() then
      if Yso.occ and type(Yso.occ.ent_for_aff) == "function" then
        local ok, cmd = pcall(Yso.occ.ent_for_aff, tgt, "chimera_roar")
        payload.class = ok and _trim(cmd) or ""
      end
      if payload.class == "" then
        payload.class = "command chimera at " .. tgt
      end
    end

    if payload.eq == ("attend " .. tgt) then
      A.state.defer_unnamable = tkey
    end

    if A.state.defer_unnamable == tkey and payload.bal == "" and _bal() then
      payload.bal = "unnamable speak"
      if not preview then
        A.state.defer_unnamable = nil
      end
    end

    local can_utter = false
    if Yso.occ and Yso.occ.truebook and type(Yso.occ.truebook.can_utter) == "function" then
      local ok, v = pcall(Yso.occ.truebook.can_utter, tgt)
      can_utter = (ok and v == true)
    end

    if cleanse_live then
      if can_utter and payload.eq == "" and _eq() then
        payload.eq = "utter truename " .. tgt
      elseif payload.eq == "" and _eq() and ra_ready and _ra_due()
          and (tonumber(A.state.observe_tries[tkey] or 0) or 0) < (tonumber(A.cfg.max_observe or 3) or 3) then
        payload.eq = "readaura " .. tgt
      elseif payload.eq == "" and _eq() then
        payload.eq = "cleanseaura " .. tgt
      end
    end

    local burst_ready = false
    if Yso.occ and type(Yso.occ.burst) == "function" then
      local ok, v = pcall(Yso.occ.burst, tgt, {
        phase = phase,
        eq_cmd = payload.eq,
        need_attend = need_attend,
        cleanse_ready = cleanse_live,
      })
      burst_ready = (ok and v == true)
    end
    if burst_ready then
      if Yso.occ and type(Yso.occ.set_phase) == "function" then
        pcall(Yso.occ.set_phase, tgt, "convert", "cleanse_branch_active")
      end
    end
  end

  phase = "open"
  if Yso.occ and type(Yso.occ.get_phase) == "function" then
    local ok, v = pcall(Yso.occ.get_phase, tgt)
    if ok and type(v) == "string" and _trim(v) ~= "" then
      phase = _trim(v)
    end
  end

  if payload.eq == "" and _eq() and ra_ready and _ra_due() then
    payload.eq = "readaura " .. tgt
  end

  -- 5 whisperingmadness->enlighten
  -- 6 unravel
  if payload.eq == "" and _eq() and (phase == "convert" or phase == "finish") and Yso.occ and type(Yso.occ.convert) == "function" then
    local ok, cmd = pcall(Yso.occ.convert, tgt, {
      phase = phase,
      enlighten_target = tonumber(A.cfg.enlighten_target or 5) or 5,
      unravel_mentals = tonumber(A.cfg.unravel_mentals or 4) or 4,
    })
    payload.eq = ok and _trim(cmd) or ""
  end

  local target_enlightened = false
  if tgt ~= "" and Yso and Yso.tgt and type(Yso.tgt.has_aff) == "function" then
    local ok, v = pcall(Yso.tgt.has_aff, tgt, "enlightened")
    if ok then target_enlightened = (v == true) end
  end
  if target_enlightened ~= true and Yso and Yso.state and type(Yso.state.tgt_has_aff) == "function" then
    local ok, v = pcall(Yso.state.tgt_has_aff, tgt, "enlightened")
    if ok then target_enlightened = (v == true) end
  end
  if target_enlightened then
    if Yso.occ and type(Yso.occ.set_phase) == "function" then
      pcall(Yso.occ.set_phase, tgt, "finish", "target_enlightened")
    end
  end
  phase = "open"
  if Yso.occ and type(Yso.occ.get_phase) == "function" then
    local ok, v = pcall(Yso.occ.get_phase, tgt)
    if ok and type(v) == "string" and _trim(v) ~= "" then
      phase = _trim(v)
    end
  end

  if payload.class == "" and _ent() and Yso.occ and type(Yso.occ.ent_refresh) == "function" then
    local ok, cmd = pcall(Yso.occ.ent_refresh, tgt, { phase = phase })
    payload.class = ok and _trim(cmd) or ""
  end

  if payload.class == "" and _ent() and Yso.occ and type(Yso.occ.firelord) == "function" then
    local ok, cmd = pcall(Yso.occ.firelord, tgt, { phase = phase })
    payload.class = ok and _trim(cmd) or ""
  end

  payload.meta = {
    phase = phase,
    route = "occ_aff",
  }

  if preview then
    return {
      target = tgt,
      route = "occ_aff",
      lanes = {
        free = (#payload.free > 0) and payload.free[1] or nil,
        eq = _trim(payload.eq) ~= "" and _trim(payload.eq) or nil,
        bal = _trim(payload.bal) ~= "" and _trim(payload.bal) or nil,
        entity = _trim(payload.class) ~= "" and _trim(payload.class) or nil,
      },
      payload = payload,
      meta = payload.meta,
    }
  end

  local sent = _emit(payload, tgt)
  if sent == true then
    A.on_sent(payload, { target = tgt })
    if payload.eq == ("readaura " .. tgt) and phase == "cleanse" then
      A.state.observe_tries[tkey] = (tonumber(A.state.observe_tries[tkey] or 0) or 0) + 1
    end
    return true
  end

  return false
end

function A.build_payload(ctx)
  return A.attack_function({ ctx = ctx, preview = true })
end

function A.on_sent(payload, ctx)
  payload = type(payload) == "table" and payload or {}
  local tgt = _trim(payload.target or (type(ctx) == "table" and ctx.target) or A.state.last_target)
  if tgt == "" then return false end

  local eq_cmd = _trim(payload.eq)
  local free = payload.free

  if type(free) == "table" then
    for i = 1, #free do
      local cmd = _trim(free[i]):lower()
      if cmd == ("order entourage kill " .. tgt:lower()) or cmd == ("order loyals kill " .. tgt:lower()) then
        if type(Yso.set_loyals_attack) == "function" then
          pcall(Yso.set_loyals_attack, true, tgt)
        end
        break
      end
    end
  end

  if eq_cmd == ("readaura " .. tgt) then
    A.state.last_readaura = _now()
    if Yso.occ and type(Yso.occ.aura_begin) == "function" then
      pcall(Yso.occ.aura_begin, tgt, "occ_aff_send")
    end
    if Yso.occ and type(Yso.occ.set_readaura_ready) == "function" then
      pcall(Yso.occ.set_readaura_ready, false, "sent")
    end
  end

  if eq_cmd == ("attend " .. tgt) then
    A.state.defer_unnamable = tgt:lower()
  end

  return true
end

function A.evaluate(ctx)
  local tgt = _trim((type(ctx) == "table" and ctx.target) or A.state.last_target)
  return {
    route = "occ_aff",
    active = A.is_active(),
    enabled = A.is_enabled(),
    target = tgt,
    phase = (function()
      if tgt == "" then return "open" end
      if Yso.occ and type(Yso.occ.get_phase) == "function" then
        local ok, v = pcall(Yso.occ.get_phase, tgt)
        if ok and type(v) == "string" and _trim(v) ~= "" then return _trim(v) end
      end
      return "open"
    end)(),
  }
end

function A.status()
  local tgt = _trim(A.state.last_target)
  return {
    route = "occ_aff",
    enabled = A.is_enabled(),
    active = A.is_active(),
    target = tgt,
    phase = (function()
      if tgt == "" then return "open" end
      if Yso.occ and type(Yso.occ.get_phase) == "function" then
        local ok, v = pcall(Yso.occ.get_phase, tgt)
        if ok and type(v) == "string" and _trim(v) ~= "" then return _trim(v) end
      end
      return "open"
    end)(),
    waiting = _trim(A.state.waiting and A.state.waiting.queue),
  }
end

function A.on_enter(ctx)
  A.init()
  return true
end

function A.on_exit(ctx)
  if Yso and Yso.mode and type(Yso.mode.stop_route_loop) == "function" then
    pcall(Yso.mode.stop_route_loop, "occ_aff", "exit", true)
  end
  A.reset("exit")
  return true
end

function A.on_target_swap(old_target, new_target)
  old_target = _trim(old_target)
  new_target = _trim(new_target)
  if old_target:lower() ~= new_target:lower() then
    A.state.phase_tgt = ""
    A.state.last_target = new_target
    if new_target ~= "" and Yso.occ and type(Yso.occ.set_phase) == "function" then
      pcall(Yso.occ.set_phase, new_target, "open", "target_swap")
    end
    A.alias_loop_clear_waiting()
    if A.state.loop_enabled == true then
      A.schedule_loop(0)
    end
  end
  return true
end

function A.on_pause(ctx)
  return true
end

function A.on_resume(ctx)
  if A.state.loop_enabled == true then
    A.schedule_loop(0)
  end
  return true
end

function A.on_manual_success(ctx)
  if A.state.loop_enabled == true then
    A.schedule_loop(A.state.loop_delay)
  end
  return true
end

function A.on_send_result(payload, ctx)
  return A.on_sent(payload, ctx)
end

function A.explain()
  local tgt = _trim(A.state.last_target)
  local ex = {
    route = "occ_aff",
    target = tgt,
    phase = (function()
      if tgt == "" then return "open" end
      if Yso.occ and type(Yso.occ.get_phase) == "function" then
        local ok, v = pcall(Yso.occ.get_phase, tgt)
        if ok and type(v) == "string" and _trim(v) ~= "" then return _trim(v) end
      end
      return "open"
    end)(),
    enabled = A.is_enabled(),
    active = A.is_active(),
    waiting = {
      active = _trim(A.state.waiting and A.state.waiting.queue) ~= "",
      queue = _trim(A.state.waiting and A.state.waiting.queue),
      age = math.max(0, _now() - (tonumber(A.state.waiting and A.state.waiting.at or 0) or 0)),
    },
    last_attack = A.state.last_attack,
  }
  A.state.explain = ex
  return ex
end

do
  local RI = Yso and Yso.Combat and Yso.Combat.RouteInterface or nil
  if RI and type(RI.ensure_hooks) == "function" then
    RI.ensure_hooks(A, A.route_contract)
  end
end

return A
