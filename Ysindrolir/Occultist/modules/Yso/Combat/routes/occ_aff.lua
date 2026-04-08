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
  off_passive_cmd = "order entourage passive",

  -- Instill priority list for the EQ slot during open/pressure phase.
  -- Each entry is a plain aff name (string) or
  -- { aff = "name", cond = function(tgt, has) return bool end }
  -- for affs that require a condition before instilling.
  aff_prio = {
    "healthleech",
    "sensitivity",
    "asthma",
    { aff = "paralysis", cond = function(tgt, has) return has(tgt, "asthma") end },
    { aff = "slickness", cond = function(tgt, has) return has(tgt, "asthma") end },
    "clumsiness",
    "darkshade",
  },

  -- Entity pressure priority for the class/entity slot.
  -- Same structure + cmd pattern (%s = target name).
  ent_prio = {
    { aff = "asthma",      cmd = "command bubonis at %s" },
    { aff = "paralysis",   cmd = "command slime at %s",   cond = function(tgt, has) return has(tgt, "asthma") end },
    { aff = "slickness",   cmd = "command bubonis at %s", cond = function(tgt, has) return has(tgt, "asthma") end },
    { aff = "clumsiness",  cmd = "command storm at %s" },
    { aff = "healthleech", cmd = "command worm at %s" },
    { aff = "haemophilia", cmd = "command bloodleech at %s" },
    { aff = "weariness",   cmd = "command hound at %s" },
    { aff = "addiction",   cmd = "command humbug at %s" },
  },

  -- Convert-phase firelord conversions.
  -- Fires when src aff is present and dest aff is missing.
  ent_convert = {
    { src = "whisperingmadness",  dest = "recklessness",   cmd = "command firelord at %s recklessness" },
    { src = "whispering_madness", dest = "recklessness",   cmd = "command firelord at %s recklessness" },
    { src = "manaleech",          dest = "anorexia",       cmd = "command firelord at %s anorexia" },
    { src = "healthleech",        dest = "psychic_damage", cmd = "command firelord at %s psychic_damage" },
  },
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

local function _command_sep()
  local sep = _trim((Yso and (Yso.sep or (Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep)))) or "&&")
  if sep == "" then sep = "&&" end
  return sep
end

local function _payload_line(payload)
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
  return table.concat(parts, _command_sep())
end

local function _same_attack_is_hot(cmd)
  cmd = _trim(cmd)
  if cmd == "" then return false end
  local last = A.state.last_attack or {}
  if _trim(last.cmd) ~= cmd then return false end
  local hot_window = math.max(0.10, (tonumber(A.state.loop_delay or A.cfg.loop_delay or 0.15) or 0.15) * 0.75)
  return (_now() - (tonumber(last.at) or 0)) < hot_window
end

local function _loyals_active_for(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return false end
  if type(Yso.loyals_attack) == "function" then
    local ok, v = pcall(Yso.loyals_attack, tgt)
    if ok and v == true then return true end
  end
  if Yso and Yso.state then
    local hostile = (Yso.state.loyals_hostile == true)
    local keyed = _trim(Yso.state.loyals_target)
    if hostile and (keyed == "" or keyed:lower() == tgt:lower()) then
      return true
    end
  end
  return false
end

local function _loyals_any_active()
  if type(Yso.loyals_attack) == "function" then
    local ok, v = pcall(Yso.loyals_attack)
    if ok and v == true then return true end
  end
  return (Yso and Yso.state and Yso.state.loyals_hostile == true) or false
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

local function _emit_free(cmd, reason, tgt)
  cmd = _trim(cmd)
  if cmd == "" then return false end
  local payload = { free = { cmd }, eq = nil, bal = nil, class = nil, target = _trim(tgt) }
  local ok = false
  if type(Yso.emit) == "function" then
    local sent_ok, sent = pcall(Yso.emit, payload, { reason = reason or "occ_aff:free", kind = "offense", commit = true, target = tgt })
    ok = (sent_ok == true and sent == true)
  elseif Yso.queue and type(Yso.queue.emit) == "function" then
    local sent_ok, sent = pcall(Yso.queue.emit, payload, { reason = reason or "occ_aff:free", kind = "offense", commit = true, target = tgt })
    ok = (sent_ok == true and sent == true)
  elseif type(send) == "function" then
    local sent_ok, sent = pcall(send, cmd)
    ok = (sent_ok == true and sent ~= false)
  end
  return ok == true
end

local function _emit(payload, tgt)
  A.state.waiting = A.state.waiting or { queue = nil, at = 0 }
  A.state.last_attack = A.state.last_attack or { cmd = "", at = 0, target = "" }

  local emit_payload = {
    free = payload.free,
    eq = _trim(payload.eq) ~= "" and payload.eq or nil,
    bal = _trim(payload.bal) ~= "" and payload.bal or nil,
    class = _trim(payload.class) ~= "" and payload.class or nil,
    target = tgt,
  }

  local line = _payload_line(payload)
  if line == "" then return false end

  if A.alias_loop_waiting_blocks() then return false end

  if _same_attack_is_hot(line) then
    return false
  end

  local ok = false
  if type(Yso.emit) == "function" then
    local sent_ok, sent = pcall(Yso.emit, emit_payload, {
      reason = "occ_aff:emit",
      kind = "offense",
      commit = true,
      target = tgt,
      allow_eqbal = true,
      prefer = "eq",
    })
    ok = (sent_ok == true and sent == true)
  elseif Yso.queue and type(Yso.queue.emit) == "function" then
    local sent_ok, sent = pcall(Yso.queue.emit, emit_payload, {
      reason = "occ_aff:emit",
      kind = "offense",
      commit = true,
      target = tgt,
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

  if type(tempTimer) == "function" then
    local clear_after = math.max(0.10, tonumber(A.state.loop_delay or A.cfg.loop_delay or 0.15) or 0.15)
    pcall(tempTimer, clear_after, function()
      if A and type(A.alias_loop_clear_waiting) == "function" then
        pcall(A.alias_loop_clear_waiting)
      end
    end)
  end

  return true
end

-- Check whether a target currently has an affliction.
-- Tries AK score export, affstrack, then Yso state APIs in that order.
local function _tgt_has(tgt, aff)
  tgt = _trim(tgt)
  aff = tostring(aff or ""):lower()
  if tgt == "" or aff == "" then return false end
  if Yso and Yso.oc and Yso.oc.ak and type(Yso.oc.ak.get_aff_score) == "function" then
    local ok, v = pcall(Yso.oc.ak.get_aff_score, aff)
    local n = ok and tonumber(v) or nil
    if n then return n >= 100 end
  end
  if type(affstrack) == "table" and type(affstrack.score) == "table" then
    local n = tonumber(affstrack.score[aff] or 0) or 0
    if n >= 100 then return true end
  end
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

-- Return current mental aff score (used for enlighten/unravel thresholds).
local function _mental_score()
  if Yso and Yso.oc and Yso.oc.ak and Yso.oc.ak.scores and type(Yso.oc.ak.scores.mental) == "function" then
    local ok, v = pcall(Yso.oc.ak.scores.mental)
    if ok then
      local n = tonumber(v)
      if n then return n end
    end
  end
  if type(affstrack) == "table" and type(affstrack.mentalscore) == "number" then
    return tonumber(affstrack.mentalscore) or 0
  end
  return 0
end

-- Pick the next instill command for the EQ slot (open/pressure phase).
-- Walks A.cfg.aff_prio in order; respects per-entry conditions.
-- Falls through to whisperingmadness then devolve if all affs are present.
local function _pick_instill(tgt)
  for _, entry in ipairs(A.cfg.aff_prio or {}) do
    local aff  = type(entry) == "string" and entry or entry.aff
    local cond = type(entry) == "table"  and entry.cond or nil
    if not _tgt_has(tgt, aff) then
      if cond == nil or cond(tgt, _tgt_has) then
        return ("instill %s with %s"):format(tgt, aff)
      end
    end
  end
  if not (_tgt_has(tgt, "whisperingmadness") or _tgt_has(tgt, "whispering_madness")) then
    return ("whisperingmadness %s"):format(tgt)
  end
  return ("devolve %s"):format(tgt)
end

-- Pick the next entity command.
-- During convert/finish uses A.cfg.ent_convert (firelord conversions).
-- All other phases walk A.cfg.ent_prio in order.
local function _pick_entity(tgt, phase)
  phase = tostring(phase or ""):lower()
  if phase == "convert" or phase == "finish" then
    for _, entry in ipairs(A.cfg.ent_convert or {}) do
      if _tgt_has(tgt, entry.src) and not _tgt_has(tgt, entry.dest) then
        return entry.cmd:format(tgt)
      end
    end
    return nil
  end
  for _, entry in ipairs(A.cfg.ent_prio or {}) do
    if not _tgt_has(tgt, entry.aff) then
      if entry.cond == nil or entry.cond(tgt, _tgt_has) then
        return entry.cmd:format(tgt)
      end
    end
  end
  return nil
end

-- Pick the EQ command for convert/finish phase (enlighten → unravel path).
local function _pick_convert(tgt, ctx)
  ctx = type(ctx) == "table" and ctx or {}
  local phase = tostring(ctx.phase or "convert"):lower()
  if phase ~= "convert" and phase ~= "finish" then return nil end

  local enlighten_target = tonumber(ctx.enlighten_target or A.cfg.enlighten_target or 5) or 5
  local unravel_mentals  = tonumber(ctx.unravel_mentals  or A.cfg.unravel_mentals  or 4) or 4
  local mental           = _mental_score()

  local has_wm = _tgt_has(tgt, "whisperingmadness") or _tgt_has(tgt, "whispering_madness")
  if not has_wm then
    return ("whisperingmadness %s"):format(tgt)
  end

  local enlightened = _tgt_has(tgt, "enlightened")
  if not enlightened then
    if mental >= enlighten_target then
      return ("enlighten %s"):format(tgt)
    end
    local ra_ready = true
    if Yso.occ and type(Yso.occ.readaura_is_ready) == "function" then
      local ok, v = pcall(Yso.occ.readaura_is_ready)
      ra_ready = (ok and v == true)
    end
    if ra_ready then return ("readaura %s"):format(tgt) end
    return ("whisperingmadness %s"):format(tgt)
  end

  if mental >= unravel_mentals then
    return ("unravel %s"):format(tgt)
  end
  local ra_ready = true
  if Yso.occ and type(Yso.occ.readaura_is_ready) == "function" then
    local ok, v = pcall(Yso.occ.readaura_is_ready)
    ra_ready = (ok and v == true)
  end
  if ra_ready then return ("readaura %s"):format(tgt) end
  return ("unravel %s"):format(tgt)
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
  if _loyals_any_active() then
    local passive = _trim(tostring(A.cfg.off_passive_cmd or "order entourage passive"))
    if passive ~= "" then
      _emit_free(passive, "occ_aff:off_passive", _trim(A.state.last_target))
    end
    _set_loyals_hostile(false)
  end
  if not (type(ctx) == "table" and ctx.silent == true) then
    if A.cfg.echo == true then
      if type(cecho) == "function" then
        cecho("<HotPink>[Occultism] <reset>Aff loop OFF.\n")
      elseif type(echo) == "function" then
        echo("[Occultism] Aff loop OFF.\n")
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
  local queue = _trim(A.state and A.state.waiting and A.state.waiting.queue)
  if queue == "" then return false end
  local age = _now() - (tonumber(A.state.waiting and A.state.waiting.at) or 0)
  local stale_s = math.max(0.45, (tonumber(A.state.loop_delay or A.cfg.loop_delay or 0.15) or 0.15) * 6)
  if age >= stale_s then
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
  if not _loyals_active_for(tgt) then
    payload.free[#payload.free + 1] = string.format(A.cfg.loyals_on_cmd or "order entourage kill %s", tgt)
  end

  local ra_ready = true
  if Yso.occ and type(Yso.occ.readaura_is_ready) == "function" then
    local ok, v = pcall(Yso.occ.readaura_is_ready)
    ra_ready = (ok and v == true)
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
  if (phase == "open" or phase == "pressure") and payload.eq == "" and _eq() then
    payload.eq = _trim(_pick_instill(tgt) or "")
  end
  if (phase == "open" or phase == "pressure") and payload.eq == "" and _eq() and ra_ready and _ra_due() then
    payload.eq = "readaura " .. tgt
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

  -- 5 whisperingmadness->enlighten / unravel
  if payload.eq == "" and _eq() and (phase == "convert" or phase == "finish") then
    payload.eq = _trim(_pick_convert(tgt, {
      phase = phase,
      enlighten_target = tonumber(A.cfg.enlighten_target or 5) or 5,
      unravel_mentals  = tonumber(A.cfg.unravel_mentals  or 4) or 4,
    }) or "")
  end

  local target_enlightened = _tgt_has(tgt, "enlightened")
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

  -- 4 maintain pressure (entity fallback -- runs after cleanse so chimera roar gets priority)
  if payload.class == "" and _ent() then
    payload.class = _trim(_pick_entity(tgt, phase) or "")
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
    local has_ack_bus = Yso and Yso.locks and type(Yso.locks.note_payload) == "function"
    if not has_ack_bus then
      A.on_sent(payload, { target = tgt })
    end
    return true
  end

  return false
end

function A.build_payload(ctx)
  return A.attack_function({ ctx = ctx, preview = true })
end

local function _clear_owned_lanes(payload)
  local Q = Yso and Yso.queue or nil
  if not (Q and type(Q.clear_owned) == "function") then return end

  local cleared = {}
  local function clear_lane(lane)
    if cleared[lane] then return end
    cleared[lane] = true
    pcall(Q.clear_owned, lane)
  end

  if type(payload.free) == "table" and #payload.free > 0 then
    clear_lane("free")
  end
  if _trim(payload.eq) ~= "" then
    clear_lane("eq")
  end
  if _trim(payload.bal) ~= "" then
    clear_lane("bal")
  end
  if _trim(payload.class) ~= "" or _trim(payload.entity) ~= "" or _trim(payload.ent) ~= "" then
    clear_lane("class")
  end
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
        _set_loyals_hostile(true, tgt)
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
    local phase = ""
    if Yso.occ and type(Yso.occ.get_phase) == "function" then
      local ok, v = pcall(Yso.occ.get_phase, tgt)
      if ok and type(v) == "string" then
        phase = _trim(v)
      end
    end
    if phase == "cleanse" then
      local tkey = _lc(tgt)
      A.state.observe_tries[tkey] = (tonumber(A.state.observe_tries[tkey] or 0) or 0) + 1
    end
  end

  if eq_cmd == ("attend " .. tgt) then
    A.state.defer_unnamable = tgt:lower()
  end

  -- Allow loop routes to requeue the same lane command on the next pass.
  _clear_owned_lanes(payload)

  return true
end

A.S = A.S or {}
function A.S.loyals_hostile(tgt)
  tgt = _trim(tgt)
  if tgt ~= "" then
    return _loyals_active_for(tgt)
  end
  return _loyals_any_active()
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

function A.on_payload_sent(payload)
  return A.on_sent(payload, nil)
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
