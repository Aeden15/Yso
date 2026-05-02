Yso = Yso or {}
Yso.bal = Yso.bal or {}
Yso.alc = Yso.alc or {}
Yso.alc.phys = Yso.alc.phys or {}
Yso.alc.reaving = (Yso.alc.reaving == true)
Yso.alc.reave_target = tostring(Yso.alc.reave_target or "")
Yso.alc.reave_pp_paused = (Yso.alc.reave_pp_paused == true)

Yso.bal.humour = Yso.bal.humour ~= false
Yso.bal.evaluate = Yso.bal.evaluate ~= false
Yso.bal.homunculus = Yso.bal.homunculus ~= false

local P = Yso.alc.phys

P.state = P.state or {}
P.targets = P.targets or {}
P.humours = P.humours or { "choleric", "melancholic", "phlegmatic", "sanguine" }
P.humour_to_affs = {
  choleric = { "nausea", "sensitivity", "slickness" },
  melancholic = { "stupidity", "anorexia", "impatience" },
  phlegmatic = { "clumsiness", "weariness", "asthma" },
  sanguine = { "haemophilia", "recklessness", "paralysis" },
}
P.cfg = P.cfg or {}
P.wrack_required_level = tonumber(P.wrack_required_level) or 1
P.truewrack_required_level = tonumber(P.truewrack_required_level) or 1
P.cfg.aurify_hp_threshold = tonumber(P.cfg.aurify_hp_threshold) or 60
P.cfg.aurify_mp_threshold = tonumber(P.cfg.aurify_mp_threshold) or 60
if P.cfg.aurify_require_both == nil then
  P.cfg.aurify_require_both = true
end
P.inundate_math = P.inundate_math or {
  choleric = {
    vital = "health",
    burst_pct_by_temper = {
      [6] = 50,
      [8] = 77,
    },
  },
  melancholic = {
    vital = "mana",
    burst_pct_by_temper = {
      [6] = 50,
      [8] = 77,
    },
  },
  sanguine = {
    vital = "bleeding",
    bleed_by_temper = {
      [6] = 2304,
      [8] = nil,
    },
  },
  phlegmatic = {
    vital = "affliction",
  },
}
P.cfg.alchemy_debuff_fallback = P.cfg.alchemy_debuff_fallback or {}
P.cfg.alchemy_debuff_fallback.phlogistication = tonumber(P.cfg.alchemy_debuff_fallback.phlogistication) or 46
P.cfg.alchemy_debuff_fallback.vitrification = tonumber(P.cfg.alchemy_debuff_fallback.vitrification) or 46
P.cfg.pending_class_timeout_s = tonumber(P.cfg.pending_class_timeout_s) or 2.5
P.state.evaluate = P.state.evaluate or {
  target = "",
  active = false,
  requested_at = 0,
  started_at = 0,
}
P.state.aff_lookup = P.state.aff_lookup or {}
P.state.corruption = P.state.corruption or {}
P.state.alchemy_debuffs = P.state.alchemy_debuffs or {}
P.state.homunculus_attack = P.state.homunculus_attack or {
  active = false,
  target = "",
  changed_at = 0,
}
P.state.pending_class = (type(P.state.pending_class) == "table") and P.state.pending_class or nil
P.state.pending_class_token = tonumber(P.state.pending_class_token or 0) or 0
P.state.last_confirmed_class_at = tonumber(P.state.last_confirmed_class_at or 0) or 0

local function _now()
  local t = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  if t and t > 1000000000000 then
    t = t / 1000
  end
  return t or os.time()
end

local function _echo(msg)
  local text = string.format("[Yso:Alchemist] %s", tostring(msg or ""))
  if type(cecho) == "function" then
    cecho("\n<orange>" .. text .. "\n")
    return
  end
  if type(echo) == "function" then
    echo("\n" .. text .. "\n")
    return
  end
  if type(print) == "function" then
    print(text)
  end
end

local function _phys_echo_corruption(msg)
  msg = tostring(msg or "")
  if msg == "" then
    return
  end
  if type(cecho) == "function" then
    cecho("\n<gold>[PHYSIOLOGY:] <HotPink>" .. msg .. "<reset>\n")
    return
  end
  if type(echo) == "function" then
    echo("\n[PHYSIOLOGY:] " .. msg .. "\n")
  end
end

local function _send_cmd(cmd)
  cmd = tostring(cmd or "")
  if cmd == "" or type(send) ~= "function" then
    return false
  end
  return pcall(send, cmd, false) == true
end

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _lc(s)
  return _trim(s):lower()
end

local function _clear_queue_verb(value)
  local verb = _lc(value)
  if verb == "addclear_full" or verb == "clearfull" then
    verb = "addclearfull"
  elseif verb == "clear" then
    verb = "addclear"
  end
  if verb ~= "addclear" and verb ~= "addclearfull" then
    verb = "addclearfull"
  end
  return verb
end

local function _target_key(name)
  local key = _lc(name)
  return key ~= "" and key or nil
end

local function _current_target()
  if type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok and _trim(v) ~= "" then
      return _trim(v)
    end
  end
  if type(Yso.target) == "string" and _trim(Yso.target) ~= "" then
    return _trim(Yso.target)
  end
  local tgt = rawget(_G, "target")
  if type(tgt) == "string" and _trim(tgt) ~= "" then
    return _trim(tgt)
  end
  return ""
end

local function _same_target(a, b)
  return _lc(a) ~= "" and _lc(a) == _lc(b)
end

local function _has_aff(aff)
  aff = _lc(aff)
  if aff == "" then
    return false
  end

  local A = rawget(_G, "affstrack")
  if type(A) == "table" then
    if type(A.score) == "table" and tonumber(A.score[aff]) then
      return tonumber(A.score[aff]) >= 100
    end
    local row = A[aff]
    if type(row) == "table" and tonumber(row.score) then
      return tonumber(row.score) >= 100
    end
  end

  if Yso and Yso.tgt and type(Yso.tgt.has_aff) == "function" then
    local ok, v = pcall(Yso.tgt.has_aff, _current_target(), aff)
    if ok and v == true then
      return true
    end
  end

  return false
end

local function _aff_list(list)
  return type(list) == "table" and list or {}
end

local function _list_has_aff(list, aff)
  aff = _lc(aff)
  for i = 1, #_aff_list(list) do
    if _lc(list[i]) == aff then
      return true
    end
  end
  return false
end

local function _debug_enabled()
  return Yso and Yso.ak and Yso.ak.debug == true
end

local function _debug(msg)
  if _debug_enabled() ~= true then
    return
  end
  _echo(msg)
end

local function _route_loop_active(route_id)
  route_id = _trim(route_id)
  if route_id == "" then
    return false
  end
  local M = Yso and Yso.mode or nil
  if type(M) ~= "table" then
    return false
  end
  if type(M.route_loop_active) == "function" then
    local ok, active = pcall(M.route_loop_active, route_id)
    if ok then
      return active == true
    end
  end
  return false
end

local function _wake_route_loop(route_id, reason)
  route_id = _trim(route_id)
  if route_id == "" then
    return false
  end
  local M = Yso and Yso.mode or nil
  if type(M) ~= "table" then
    return false
  end
  if _route_loop_active(route_id) ~= true then
    return false
  end
  if type(M.nudge_route_loop) == "function" then
    local ok, nudged = pcall(M.nudge_route_loop, route_id, tostring(reason or "physiology"))
    if ok and nudged == true then
      return true
    end
  end
  if type(M.schedule_route_loop) == "function" then
    local ok, scheduled = pcall(M.schedule_route_loop, route_id, 0)
    if ok and scheduled == true then
      return true
    end
  end
  return false
end

local function _rebuild_aff_lookup()
  local map = {}
  for humour, affs in pairs(P.humour_to_affs or {}) do
    local key = _lc(humour)
    if key ~= "" and type(affs) == "table" then
      for i = 1, #affs do
        local aff = _lc(affs[i])
        if aff ~= "" then
          map[aff] = key
        end
      end
    end
  end
  P.state.aff_lookup = map
  return map
end

local function _aff_lookup()
  local map = type(P.state.aff_lookup) == "table" and P.state.aff_lookup or nil
  if not map or next(map) == nil then
    map = _rebuild_aff_lookup()
  end
  return map
end

local function _giving_humour_pools(giving)
  local pools = {}
  for i = 1, #_aff_list(giving) do
    local aff = _lc(giving[i])
    local humour = P.aff_to_humour(aff)
    if humour then
      pools[humour] = pools[humour] or {}
      pools[humour][#pools[humour] + 1] = aff
    end
  end
  return pools
end

local function _pool_order(pools)
  local out = {}
  for i = 1, #P.humours do
    local humour = P.humours[i]
    if pools[humour] and #pools[humour] > 0 then
      out[#out + 1] = humour
    end
  end
  return out
end

local function _target_row(name)
  local key = _target_key(name)
  if not key then
    return nil
  end

  local row = P.targets[key]
  if row then
    row.name = _trim(name)
    row.last_seen_at = _now()
    return row
  end

  row = {
    name = _trim(name),
    key = key,
    created_at = _now(),
    last_seen_at = _now(),
    last_evaluated_at = 0,
    last_wrack_at = 0,
    eval_dirty = true,
    vitals = {
      health_pct = nil,
      mana_pct = nil,
      last_evaluated_at = 0,
    },
    humours = {},
  }

  P.targets[key] = row
  return row
end

local function _ensure_humour_row(target_row, humour)
  if type(target_row) ~= "table" then
    return nil
  end
  target_row.humours = type(target_row.humours) == "table" and target_row.humours or {}
  humour = _lc(humour)
  if humour == "" then
    return nil
  end
  local row = target_row.humours[humour]
  if type(row) ~= "table" then
    row = {
      level = nil,
      dirty = true,
      reason = "init",
      updated_at = 0,
    }
    target_row.humours[humour] = row
  end
  return row
end

local function _ak_humour_table()
  local ak = rawget(_G, "ak")
  local alc = type(ak) == "table" and ak.alchemist or nil
  local humours = type(alc) == "table" and alc.humour or nil
  return type(humours) == "table" and humours or nil
end

local function _humour_missing_desired(target, humour, giving)
  humour = _lc(humour)
  if humour == "" then
    return false
  end
  local pools = _giving_humour_pools(giving)
  local affs = pools[humour]
  if type(affs) ~= "table" then
    return false
  end
  for i = 1, #affs do
    local aff = _lc(affs[i])
    if aff ~= "" and not _has_aff(aff) then
      return true
    end
  end
  return false
end

local function _valid_humour(humour)
  humour = _lc(humour)
  if humour == "" then
    return nil
  end
  for i = 1, #P.humours do
    if P.humours[i] == humour then
      return humour
    end
  end
  return nil
end

local function _humour_truth_trusted(name)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end
  if target == "" or not _same_target(target, _current_target()) then
    return false
  end
  local row = _target_row(target)
  if not row or row.eval_dirty == true then
    return false
  end
  if tonumber(row.last_evaluated_at or 0) <= 0 then
    return false
  end
  return _same_target(P.state.humour_eval_target or "", target)
end

local function _self_has_aff(name)
  local key = _lc(name)
  if key == "" then
    return false
  end

  if Yso and Yso.self and type(Yso.self.has_aff) == "function" then
    local ok, v = pcall(Yso.self.has_aff, key)
    if ok and v == true then
      return true
    end
  end

  return false
end

local function _reave_blockers()
  local blockers = {}
  local seen = {}

  local function _add(name)
    local key = _lc(name)
    if key == "" or seen[key] then
      return
    end
    seen[key] = true
    blockers[#blockers + 1] = key
  end

  local prone = false
  if Yso and Yso.self and type(Yso.self.is_prone) == "function" then
    local ok, v = pcall(Yso.self.is_prone)
    prone = ok and v == true
  end
  if prone or _self_has_aff("prone") then
    _add("prone")
  end

  if _self_has_aff("paralysis") then
    _add("paralysis")
  end
  if _self_has_aff("paresis") then
    _add("paresis")
  end
  if _self_has_aff("webbed") then
    _add("webbed")
  end
  if _self_has_aff("roped") then
    _add("roped")
  end
  if _self_has_aff("transfixed") then
    _add("transfixed")
  end

  if Yso and Yso.self and type(Yso.self.list_writhe_affs) == "function" then
    local ok, list = pcall(Yso.self.list_writhe_affs)
    if ok and type(list) == "table" then
      for i = 1, #list do
        _add(list[i])
      end
    end
  end

  if #blockers == 0 and Yso and Yso.self and type(Yso.self.is_writhed) == "function" then
    local ok, writhed = pcall(Yso.self.is_writhed)
    if ok and writhed == true then
      _add("writhe")
    end
  end

  return blockers
end

local function _reave_channel_duration(distinct)
  local n = tonumber(distinct or 0) or 0
  if n >= 4 then return 4 end
  if n == 3 then return 6 end
  if n == 2 then return 8 end
  return 10
end

local function _reave_resume_and_clear(source)
  if Yso.alc.reave_pp_paused == true then
    _send_cmd("pp")
  end
  Yso.alc.reaving = false
  Yso.alc.reave_target = ""
  Yso.alc.reave_pp_paused = false
  P.state.reave = P.state.reave or {}
  P.state.reave.last_clear = {
    source = tostring(source or "manual"),
    at = _now(),
  }
  return true
end

function Yso.alc.set_humour_ready(ready, source)
  Yso.bal.humour = ready and true or false
  P.state.last_humour_source = source or "unknown"
  P.state.last_humour_change = _now()
  return Yso.bal.humour
end

function Yso.alc.humour_ready()
  return Yso.bal.humour ~= false
end

function Yso.alc.set_evaluate_ready(ready, source)
  Yso.bal.evaluate = ready and true or false
  P.state.last_evaluate_source = source or "unknown"
  P.state.last_evaluate_change = _now()
  return Yso.bal.evaluate
end

function Yso.alc.evaluate_ready()
  return Yso.bal.evaluate ~= false
end

function Yso.alc.set_homunculus_ready(ready, source)
  Yso.bal.homunculus = ready and true or false
  P.state.last_homunculus_source = source or "unknown"
  P.state.last_homunculus_change = _now()
  return Yso.bal.homunculus
end

function Yso.alc.homunculus_ready()
  return Yso.bal.homunculus ~= false
end

function Yso.set_homunculus_attack(v, tgt)
  P.state.homunculus_attack = P.state.homunculus_attack or {}
  P.state.homunculus_attack.active = v == true
  P.state.homunculus_attack.changed_at = _now()
  if v == true and _trim(tgt) ~= "" then
    P.state.homunculus_attack.target = _trim(tgt)
  elseif v ~= true then
    P.state.homunculus_attack.target = ""
  end
  return P.state.homunculus_attack.active
end

function Yso.homunculus_attack(tgt)
  local st = P.state.homunculus_attack or {}
  if st.active ~= true then
    return false
  end
  tgt = _trim(tgt)
  if tgt == "" then
    return true
  end
  return _same_target(st.target or "", tgt)
end

local function _aurify_route_active()
  local route = Yso and Yso.off and Yso.off.alc and Yso.off.alc.aurify_route or nil
  if type(route) == "table" and type(route.is_active) == "function" then
    local ok, active = pcall(route.is_active)
    if ok then
      return active == true
    end
  end
  return false
end

function P.wake_route(route_id, reason)
  return _wake_route_loop(route_id, reason)
end

function P.wake_alchemist_routes(reason)
  local woke = false
  if _wake_route_loop("alchemist_group_damage", reason) then
    woke = true
  end
  if _wake_route_loop("alchemist_duel_route", reason) then
    woke = true
  end
  if _wake_route_loop("alchemist_aurify_route", reason) then
    woke = true
  end
  return woke
end

function P.now()
  return _now()
end

function P.target(name)
  return _target_row(name)
end

function P.current_target()
  return _current_target()
end

function P.aff_to_humour(aff)
  aff = _lc(aff)
  if aff == "" then
    return nil
  end
  return _aff_lookup()[aff]
end

function P.required_humour_level_for_wrack(kind, aff)
  kind = _lc(kind)
  local base = (kind == "truewrack") and tonumber(P.truewrack_required_level or 1) or tonumber(P.wrack_required_level or 1)
  base = math.max(0, base or 1)
  if _lc(aff) == "paralysis" then
    return math.max(base, 2)
  end
  return base
end

function P.set_humour_level(target, humour, level, reason)
  humour = _valid_humour(humour)
  if not humour then
    return false
  end
  local target_row = _target_row(target)
  if not target_row then
    return false
  end

  local hrow = _ensure_humour_row(target_row, humour)
  if not hrow then
    return false
  end

  level = tonumber(level)
  if level ~= nil then
    level = math.max(0, level)
  end
  hrow.level = level
  hrow.dirty = (level == nil)
  hrow.reason = tostring(reason or "manual")
  hrow.updated_at = _now()
  return true
end

function P.set_humour_dirty(target, humour, reason)
  humour = _valid_humour(humour)
  if not humour then
    return false
  end
  local target_row = _target_row(target)
  if not target_row then
    return false
  end

  local hrow = _ensure_humour_row(target_row, humour)
  hrow.level = nil
  hrow.dirty = true
  hrow.reason = tostring(reason or "dirty")
  hrow.updated_at = _now()

  target_row.eval_dirty = true
  target_row.last_dirty_source = tostring(reason or "dirty")
  target_row.last_dirty_at = _now()
  if _same_target(P.state.humour_eval_target or "", target_row.name) then
    P.state.humour_eval_target = ""
  end
  return true
end

function P.clear_all_humours(target, reason)
  local row = P.target(target)
  if not row then
    return false
  end

  for i = 1, #P.humours do
    local humour = P.humours[i]
    P.set_humour_level(row.name, humour, 0, reason or "clear_all")
  end

  row.eval_dirty = true
  row.last_dirty_source = tostring(reason or "clear_all")
  row.last_dirty_at = P.now and P.now() or _now()
  if _same_target(P.state.humour_eval_target or "", row.name) then
    P.state.humour_eval_target = ""
  end

  return true
end

function P.get_humour_level(target, humour)
  humour = _valid_humour(humour)
  if not humour then
    return nil
  end
  local target_row = _target_row(target)
  if not target_row then
    return nil
  end

  local hrow = _ensure_humour_row(target_row, humour)
  if _humour_truth_trusted(target_row.name) then
    local current = tonumber(P.ak_humour_count(target_row.name, humour))
    if current == nil then
      return nil
    end
    current = math.max(0, current)
    if hrow then
      hrow.level = current
      hrow.dirty = false
      hrow.reason = "trusted_current"
      hrow.updated_at = _now()
    end
    return current
  end

  if hrow and hrow.dirty ~= true and tonumber(hrow.level) ~= nil then
    return math.max(0, tonumber(hrow.level))
  end

  return nil
end

function P.can_wrack(target, humour, required_level)
  humour = _valid_humour(humour)
  if not humour then
    return false, nil
  end
  local need = tonumber(required_level) or tonumber(P.wrack_required_level or 1) or 1
  need = math.max(0, need)
  local known = tonumber(P.get_humour_level(target, humour))
  if known == nil then
    return false, nil
  end
  return known >= need, known
end

function P.staged_humour_count(target, humour, staged)
  humour = _lc(humour)
  local known = tonumber(P.current_humour_count(target, humour) or 0) or 0
  if staged and _lc(staged.temper_humour or "") == humour then
    known = known + 1
  end
  return known
end

function P.can_wrack_with_staged(target, humour, required_level, staged)
  humour = _valid_humour(humour)
  if not humour then
    return false, nil
  end
  local need = tonumber(required_level) or tonumber(P.wrack_required_level or 1) or 1
  need = math.max(0, need)
  local known = tonumber(P.staged_humour_count(target, humour, staged) or 0) or 0
  return known >= need, known
end

local function _same_target_cmd(cmd, target)
  cmd = _lc(cmd)
  target = _lc(target)
  if cmd == "" or target == "" then
    return false
  end
  return cmd:find(target, 1, true) ~= nil
end

function P.clear_staged_for_target(target, reason)
  target = _trim(target)
  if target == "" then
    target = _current_target()
  end
  if target == "" then
    return false
  end

  local lower_target = _lc(target)
  local Q = Yso and Yso.queue or nil
  local cleared_any = false
  local function _class_cmd_for_target(cmd_lc)
    if cmd_lc == "" or not _same_target_cmd(cmd_lc, lower_target) then
      return false
    end
    return cmd_lc:match("^temper%s+") ~= nil
      or cmd_lc:match("^inundate%s+") ~= nil
      or cmd_lc:match("^aurify%s+") ~= nil
      or cmd_lc:match("^reave%s+") ~= nil
  end

  if type(P.resolve_evaluate_target) == "function" and _same_target(P.resolve_evaluate_target(), target) then
    P.state.evaluate.active = false
    P.state.evaluate.requested_at = 0
    P.state.evaluate.started_at = 0
  end

  if Q and type(Q.list) == "function" and type(Q.clear) == "function" then
    local bal = _trim(Q.list("bal") or "")
    local bal_lc = _lc(bal)
    if bal ~= "" and _same_target_cmd(bal_lc, lower_target)
      and (bal_lc:match("^wrack%s+") or bal_lc:match("^truewrack%s+"))
    then
      Q.clear("bal")
      cleared_any = true
    end

    local class_lane = Q.list("class")
    if type(class_lane) == "string" then
      local class_lc = _lc(class_lane)
      if _class_cmd_for_target(class_lc) then
        Q.clear("class")
        cleared_any = true
      end
    elseif type(class_lane) == "table" then
      local kept = {}
      local removed = false
      for i = 1, #class_lane do
        local cmd = _trim(class_lane[i])
        local cmd_lc = _lc(cmd)
        if _class_cmd_for_target(cmd_lc) then
          removed = true
        else
          kept[#kept + 1] = cmd
        end
      end
      if removed then
        if type(Q.clear) == "function" and type(Q.stage) == "function" then
          Q.clear("class")
          if #kept > 0 then
            Q.stage("class", kept, { replace = true })
          end
          cleared_any = true
        end
      end
    end

    local free = Q.list("free")
    if type(free) == "table" then
      local kept = {}
      local removed = false
      for i = 1, #free do
        local cmd = _trim(free[i])
        local cmd_lc = _lc(cmd)
        if cmd_lc ~= "" and _same_target_cmd(cmd_lc, lower_target) and cmd_lc:match("^evaluate%s+") and cmd_lc:find("humours", 1, true) then
          removed = true
        else
          kept[#kept + 1] = cmd
        end
      end
      if removed then
        if type(Q.clear) == "function" and type(Q.stage) == "function" then
          Q.clear("free")
          if #kept > 0 then
            Q.stage("free", kept, { replace = true })
          end
          cleared_any = true
        end
      end
    end
  end

  if Q and type(Q.get_owned) == "function" then
    local owned_bal = Q.get_owned("bal")
    if type(owned_bal) == "table" then
      local cmd = _lc(owned_bal.cmd or "")
      local route = _lc(owned_bal.route or "")
      local tgt = _lc(owned_bal.target or "")
      if route:find("alchemist", 1, true) and (tgt == lower_target or _same_target_cmd(cmd, lower_target))
        and (cmd:match("^wrack%s+") or cmd:match("^truewrack%s+"))
      then
        if type(Q.clear_owned) == "function" then
          Q.clear_owned("bal")
        end
        if type(Q.clear_lane_dispatched) == "function" then
          Q.clear_lane_dispatched("bal", tostring(reason or "staged_clear"))
        end
        cleared_any = true
      end
    end

    local owned_free = Q.get_owned("free")
    if type(owned_free) == "table" then
      local cmd = _lc(owned_free.cmd or "")
      local route = _lc(owned_free.route or "")
      local tgt = _lc(owned_free.target or "")
      if route:find("alchemist", 1, true) and (tgt == lower_target or _same_target_cmd(cmd, lower_target))
        and cmd:match("^evaluate%s+") and cmd:find("humours", 1, true)
      then
        if type(Q.clear_owned) == "function" then
          Q.clear_owned("free")
        end
        cleared_any = true
      end
    end

    local owned_class = Q.get_owned("class")
    if type(owned_class) == "table" then
      local cmd = _lc(owned_class.cmd or "")
      local route = _lc(owned_class.route or "")
      local tgt = _lc(owned_class.target or "")
      if route:find("alchemist", 1, true) and (tgt == lower_target or _same_target_cmd(cmd, lower_target))
        and _class_cmd_for_target(cmd)
      then
        if type(Q.clear_owned) == "function" then
          Q.clear_owned("class")
        end
        if type(Q.clear_lane_dispatched) == "function" then
          Q.clear_lane_dispatched("class", tostring(reason or "staged_clear"))
        end
        cleared_any = true
      end
    end
  end

  P.state.last_staged_clear = {
    target = target,
    reason = tostring(reason or "manual"),
    at = _now(),
    cleared = (cleared_any == true),
  }
  return cleared_any
end

function P.clear_pending_class(reason, opts)
  opts = type(opts) == "table" and opts or {}
  local pending = type(P.state.pending_class) == "table" and P.state.pending_class or nil
  if type(pending) ~= "table" then
    return false
  end

  local clear_any = (opts.clear_any == true)
  local want_route = _trim(opts.route)
  local want_target = _trim(opts.target)
  local want_action = _lc(opts.action)
  local want_humour = _lc(opts.humour)

  if not clear_any then
    if want_route ~= "" and _lc(pending.route or "") ~= _lc(want_route) then
      return false
    end
    if want_target ~= "" and not _same_target(pending.target or "", want_target) then
      return false
    end
    if want_action ~= "" and _lc(pending.action or "") ~= want_action then
      return false
    end
    if want_humour ~= "" and _lc(pending.humour or "") ~= want_humour then
      return false
    end
  end

  local now = _now()
  if pending.timer_id and type(killTimer) == "function" then
    pcall(killTimer, pending.timer_id)
  end

  local clear_reason = tostring(reason or "pending_class_clear")
  P.state.pending_class = nil
  P.state.last_pending_class_clear = {
    action = _lc(pending.action or ""),
    target = _trim(pending.target or ""),
    humour = _lc(pending.humour or ""),
    route = _trim(pending.route or ""),
    reason = clear_reason,
    at = now,
  }

  if clear_reason == "temper_sent_no_confirm_timeout" then
    P.state.pending_timeout_event = {
      action = _lc(pending.action or ""),
      target = _trim(pending.target or ""),
      humour = _lc(pending.humour or ""),
      route = _trim(pending.route or ""),
      reason = clear_reason,
      at = now,
    }
  end

  if opts.clear_staged == true and type(P.clear_staged_for_target) == "function" then
    local pending_target = _trim(pending.target or "")
    if pending_target ~= "" then
      pcall(P.clear_staged_for_target, pending_target, clear_reason)
    end
  end

  if opts.wake == true then
    local wake_route = _trim(opts.wake_route or pending.route or "")
    if wake_route ~= "" then
      _wake_route_loop(wake_route, clear_reason)
    else
      P.wake_alchemist_routes(clear_reason)
    end
  end

  return true
end

function P.note_pending_class(action, target, humour, cmd, route, source)
  action = _lc(action)
  if action == "" then
    return false
  end

  target = _trim(target)
  if target == "" then
    target = _current_target()
  end
  if target == "" then
    return false
  end

  P.clear_pending_class("pending_replace", { clear_any = true })

  local now = _now()
  local timeout_s = tonumber(P.cfg.pending_class_timeout_s or 2.5) or 2.5
  local token = tonumber(P.state.pending_class_token or 0) + 1
  P.state.pending_class_token = token

  local pending = {
    action = action,
    target = target,
    humour = _lc(humour),
    cmd = _trim(cmd),
    route = _trim(route),
    source = tostring(source or "route"),
    sent_at = now,
    timeout_s = timeout_s,
    token = token,
  }

  if timeout_s > 0 and type(tempTimer) == "function" then
    pending.timer_id = tempTimer(timeout_s, function()
      local current = P.state.pending_class
      if type(current) ~= "table" then
        return
      end
      if tonumber(current.token or 0) ~= token then
        return
      end
      P.state.pending_timeout_event = {
        action = _lc(current.action or ""),
        target = _trim(current.target or ""),
        humour = _lc(current.humour or ""),
        route = _trim(current.route or ""),
        reason = "temper_pending_longer_than_expected",
        at = _now(),
      }
    end)
  end

  P.state.pending_class = pending
  return true
end

function P.pending_class_status(route, target, max_age_s)
  route = _trim(route)
  target = _trim(target)

  local timeout_event = type(P.state.pending_timeout_event) == "table" and P.state.pending_timeout_event or nil
  if timeout_event then
    local route_ok = (route == "" or _lc(timeout_event.route or "") == _lc(route))
    local target_ok = (target == "" or _same_target(timeout_event.target or "", target))
    if route_ok and target_ok then
      if tostring(timeout_event.reason or "") == "temper_pending_longer_than_expected" then
        local current = type(P.state.pending_class) == "table" and P.state.pending_class or nil
        if current then
          return true, "temper_pending", current
        end
      end
      P.state.pending_timeout_event = nil
      return false, tostring(timeout_event.reason or "temper_sent_no_confirm_timeout"), timeout_event
    end
  end

  local pending = type(P.state.pending_class) == "table" and P.state.pending_class or nil
  if type(pending) ~= "table" then
    return false, nil, nil
  end

  if route ~= "" and _lc(pending.route or "") ~= _lc(route) then
    return false, nil, nil
  end
  if target ~= "" and not _same_target(pending.target or "", target) then
    return false, nil, nil
  end

  local sent_at = tonumber(pending.sent_at or 0) or 0
  local age = _now() - sent_at
  local timeout_s = tonumber(max_age_s or pending.timeout_s or P.cfg.pending_class_timeout_s or 2.5) or 2.5
  if timeout_s > 0 and sent_at > 0 and age >= timeout_s then
    P.state.pending_timeout_event = {
      action = _lc(pending.action or ""),
      target = _trim(pending.target or ""),
      humour = _lc(pending.humour or ""),
      route = _trim(pending.route or ""),
      reason = "temper_pending_longer_than_expected",
      at = _now(),
    }
    return true, "temper_pending", pending
  end

  return true, "temper_pending", pending
end

function P.note_temper_success(name, humour, source)
  humour = _valid_humour(humour)
  if not humour then
    return false
  end

  local target = _trim(name)
  if target == "" then
    target = _trim((type(P.state.pending_class) == "table" and P.state.pending_class.target) or "")
  end
  if target == "" then
    target = _current_target()
  end
  if target == "" then
    return false
  end

  local prior = tonumber(P.get_humour_level(target, humour))
  local next_level = (prior ~= nil) and (prior + 1) or 1
  P.set_humour_level(target, humour, next_level, tostring(source or "temper_success"))

  if Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
    Yso.alc.set_humour_ready(false, "temper_success")
  end

  P.state.last_confirmed_class_at = _now()
  P.clear_pending_class("temper_success", {
    action = "temper",
    target = target,
    humour = humour,
    clear_staged = true,
  })
  P.wake_alchemist_routes("temper_success")
  return true
end

function P.on_insufficient_temper(target, humour)
  local tgt = _trim(target)
  if tgt == "" then
    tgt = _current_target()
  end
  humour = _valid_humour(humour)
  if tgt == "" or not humour then
    return false
  end

  local required = P.required_humour_level_for_wrack("wrack")
  local known = tonumber(P.get_humour_level(tgt, humour))
  if known ~= nil and known >= required then
    P.set_humour_level(tgt, humour, required - 1, "insufficient_temper_clamp")
  end
  P.set_humour_dirty(tgt, humour, "insufficient_temper")
  P.clear_staged_for_target(tgt, "insufficient_temper")

  local Q = Yso and Yso.queue or nil
  if Q and type(Q.clear_lane_dispatched) == "function" then
    pcall(Q.clear_lane_dispatched, "bal", "insufficient_temper")
  end

  P.clear_pending_class("insufficient_temper", {
    action = "temper",
    target = tgt,
    humour = humour,
    clear_staged = true,
    wake = true,
  })
  P.wake_alchemist_routes("insufficient_temper")

  _debug(string.format("[Alchemist] insufficient temper: %s %s; clearing staged BAL", tgt, humour))
  return true
end

function P.evaluate_staged_for_target(target)
  target = _trim(target)
  if target == "" then
    target = _current_target()
  end
  if target == "" then
    return false
  end

  if _same_target(P.state.evaluate and P.state.evaluate.target or "", target) then
    local row = P.state.evaluate or {}
    if row.active == true then
      return true
    end
    if tonumber(row.requested_at or 0) > 0 then
      return true
    end
  end

  local q = Yso and Yso.queue or nil
  if not q or type(q.list) ~= "function" then
    return false
  end

  local target_lc = _lc(target)
  local staged = q.list("free")
  if type(staged) == "table" then
    for i = 1, #staged do
      local cmd = _lc(staged[i])
      if cmd:match("^evaluate%s+") and cmd:find(target_lc, 1, true) and cmd:find("humours", 1, true) then
        return true
      end
    end
  end

  if type(q.get_owned) == "function" then
    local owned = q.get_owned("free")
    if type(owned) == "table" then
      local cmd = _lc(owned.cmd or "")
      if cmd:match("^evaluate%s+") and cmd:find(target_lc, 1, true) and cmd:find("humours", 1, true) then
        return true
      end
    end
  end

  return false
end

function P.mark_all_eval_dirty(name, source)
  local target_row = _target_row(name)
  if not target_row then
    return false
  end

  target_row.eval_dirty = true
  target_row.last_dirty_source = tostring(source or "manual")
  target_row.last_dirty_at = _now()
  target_row.humours = type(target_row.humours) == "table" and target_row.humours or {}
  for i = 1, #P.humours do
    local humour = P.humours[i]
    local hrow = _ensure_humour_row(target_row, humour)
    if hrow then
      hrow.level = nil
      hrow.dirty = true
      hrow.reason = tostring(source or "manual")
      hrow.updated_at = _now()
    end
  end
  if _same_target(P.state.humour_eval_target or "", target_row.name) then
    P.state.humour_eval_target = ""
  end
  return true
end

function P.note_evaluate_request(name, source)
  local target_row = _target_row(name)
  if not target_row then
    return false
  end

  if P.evaluate_staged_for_target(target_row.name) then
    _debug(string.format("[Alchemist] evaluate duplicate ignored for %s", target_row.name))
    return false
  end

  P.state.evaluate.target = target_row.name
  P.state.evaluate.requested_at = _now()
  P.state.evaluate.started_at = 0
  P.state.evaluate.active = false
  P.state.evaluate.request_source = tostring(source or "route")
  _debug(string.format("[Alchemist] evaluate staged for %s", target_row.name))
  return true
end

function P.begin_evaluate(name)
  local target_row = _target_row(name)
  if not target_row then
    return false
  end

  local now = _now()
  P.state.evaluate.target = target_row.name
  P.state.evaluate.active = true
  P.state.evaluate.started_at = now
  return true
end

function P.active_evaluate_target()
  local name = _trim(P.state.evaluate and P.state.evaluate.target or "")
  return name
end

function P.resolve_evaluate_target(default_target)
  local target = _trim(default_target)
  if target ~= "" then
    return target
  end

  target = _trim(P.state.evaluate and P.state.evaluate.target or "")
  if target ~= "" then
    return target
  end

  return _current_target()
end

function P.finish_evaluate(name)
  local target = P.resolve_evaluate_target(name)
  local target_row = _target_row(target)
  if not target_row then
    return false
  end

  P.state.evaluate.target = target_row.name
  P.state.evaluate.active = false
  P.state.evaluate.requested_at = 0
  P.state.evaluate.started_at = 0
  target_row.last_evaluated_at = _now()
  target_row.eval_dirty = false
  P.state.humour_eval_target = target_row.name
  P.clear_staged_for_target(target_row.name, "evaluate_result")
  P.wake_alchemist_routes("finish_evaluate")
  return true
end

function P.note_evaluate_normal(name)
  local target = P.resolve_evaluate_target(name)
  local target_row = _target_row(target)
  if not target_row then
    return false
  end

  for i = 1, #P.humours do
    local humour = P.humours[i]
    P.set_humour_level(target_row.name, humour, 0, "evaluate_normal")
  end

  return P.finish_evaluate(target_row.name)
end

function P.maybe_finish_evaluate(name)
  local target = P.resolve_evaluate_target(name)
  local target_row = _target_row(target)
  if not target_row then
    return false
  end

  for i = 1, #P.humours do
    local humour = P.humours[i]
    local hrow = _ensure_humour_row(target_row, humour)
    if type(hrow) ~= "table" or hrow.dirty == true or tonumber(hrow.level) == nil then
      return false
    end
  end

  return P.finish_evaluate(target_row.name)
end

function P.note_evaluate_vitals(name, health_pct, mana_pct)
  local target_row = _target_row(name)
  if not target_row then
    return false
  end

  local now = _now()
  if tonumber(health_pct) then
    target_row.vitals.health_pct = math.max(0, math.min(100, tonumber(health_pct)))
  end
  if tonumber(mana_pct) then
    target_row.vitals.mana_pct = math.max(0, math.min(100, tonumber(mana_pct)))
  end
  target_row.vitals.last_evaluated_at = now
  return true
end

function P.note_corrupt_success(name, seconds)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end
  if target == "" then
    return false
  end

  local now = _now()
  local duration = tonumber(seconds) or 45
  local key = _target_key(target)
  if not key then
    return false
  end
  local existing = P.state.corruption[key]
  if type(existing) == "table" and existing.timer_id and type(killTimer) == "function" then
    pcall(killTimer, existing.timer_id)
  end
  local token = tonumber((existing and existing.token) or 0) + 1
  P.state.corruption[key] = {
    target = target,
    applied_at = now,
    expected_expires_at = now + duration,
    token = token,
    active = true,
    timer_id = nil,
  }
  if duration > 0 and type(tempTimer) == "function" then
    P.state.corruption[key].timer_id = tempTimer(duration, function()
      local row = P.state.corruption and P.state.corruption[key]
      if type(row) ~= "table" then
        return
      end
      if row.active ~= true or tonumber(row.token or 0) ~= token then
        return
      end
      if not _same_target(row.target or "", _current_target()) then
        return
      end
      if _aurify_route_active() ~= true then
        return
      end
      row.active = false
      row.timer_id = nil
      row.expired_at = _now()
      _phys_echo_corruption("RECAST CORRUPTION!")
      P.wake_alchemist_routes("corruption_expired")
    end)
  end
  _phys_echo_corruption(target .. " IS CORRUPTED! 45s TO GO!")
  return true
end

function P.clear_corruption(name, source)
  local key = _target_key(name)
  if not key then
    return false
  end
  local row = P.state.corruption[key]
  if type(row) == "table" and row.timer_id and type(killTimer) == "function" then
    pcall(killTimer, row.timer_id)
  end
  P.state.corruption[key] = nil
  P.state.last_corruption_clear = {
    target = name,
    source = tostring(source or "manual"),
    at = _now(),
  }
  return true
end

function P.corruption_active(name)
  local key = _target_key(name)
  if not key then
    return false
  end
  local row = P.state.corruption[key]
  if type(row) ~= "table" then
    return false
  end
  if row.active ~= true then
    return false
  end
  if tonumber(row.expected_expires_at or 0) <= _now() then
    row.active = false
    row.timer_id = nil
    return false
  end
  return true
end

function P.set_alchemy_debuff(target, kind, active, source)
  target = _trim(target)
  kind = _lc(kind)

  if target == "" or (kind ~= "phlogistication" and kind ~= "vitrification") then
    return false
  end

  local key = _target_key(target)
  if not key then
    return false
  end

  P.state.alchemy_debuffs = P.state.alchemy_debuffs or {}
  P.state.alchemy_debuffs[key] = P.state.alchemy_debuffs[key] or {
    target = target,
    token = 0,
  }

  local row = P.state.alchemy_debuffs[key]
  row.target = target
  row.token = tonumber(row.token or 0) + 1
  row.source = tostring(source or "unknown")
  row.changed_at = _now()

  if row.timer_id and type(killTimer) == "function" then
    pcall(killTimer, row.timer_id)
    row.timer_id = nil
  end

  if active == true then
    row.active = true
    row.kind = kind
    row.applied_at = _now()
    row.cleared_at = nil
    row.clear_source = nil

    local seconds = tonumber(P.cfg.alchemy_debuff_fallback[kind] or 0) or 0
    if seconds > 0 and type(tempTimer) == "function" then
      local token = row.token
      row.expected_expires_at = row.applied_at + seconds
      row.timer_id = tempTimer(seconds, function()
        local current = P.state.alchemy_debuffs and P.state.alchemy_debuffs[key]
        if current and current.active == true and current.kind == kind and current.token == token then
          P.set_alchemy_debuff(target, kind, false, kind .. "_fallback_timer")
        end
      end)
    else
      row.expected_expires_at = nil
    end

    return true
  end

  if row.kind == kind or row.kind == nil then
    row.active = false
    row.cleared_at = _now()
    row.clear_source = tostring(source or "unknown")
  end

  return true
end

function P.alchemy_debuff_active(target)
  target = _trim(target)
  if target == "" then
    target = _current_target()
  end

  local key = _target_key(target)
  if not key then
    return false, nil, nil
  end

  local row = P.state.alchemy_debuffs and P.state.alchemy_debuffs[key]
  if type(row) ~= "table" or row.active ~= true then
    return false, nil, row
  end

  return true, row.kind, row
end

function P.can_use_alchemy_debuff(target)
  local active, kind = P.alchemy_debuff_active(target)
  if active == true then
    return false, kind
  end
  return true, nil
end

function P.ak_humour_count(target, humour)
  target = _trim(target)
  if target == "" then
    target = _current_target()
  end
  humour = _lc(humour)
  if target == "" or humour == "" or not _same_target(target, _current_target()) then
    return nil
  end

  local humours = _ak_humour_table()
  local value = humours and tonumber(humours[humour]) or nil
  if value == nil then
    return nil
  end
  if value < 0 then
    value = 0
  end
  return value
end

function P.current_humour_count(target, humour)
  if not _humour_truth_trusted(target) then
    return nil
  end
  return P.ak_humour_count(target, humour)
end

function P.target_needs_evaluate(name)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end
  if target == "" then
    return false
  end
  if not _same_target(target, _current_target()) then
    return true
  end
  return not _humour_truth_trusted(target)
end

function P.health_pct(name)
  local target_row = _target_row(name)
  return target_row and target_row.vitals and target_row.vitals.health_pct or nil
end

function P.mana_pct(name)
  local target_row = _target_row(name)
  return target_row and target_row.vitals and target_row.vitals.mana_pct or nil
end

function P.can_aurify(name)
  local hp = tonumber(P.health_pct(name))
  local mp = tonumber(P.mana_pct(name))
  if hp == nil or mp == nil then
    return false
  end
  local hp_ok = hp <= (tonumber(P.cfg.aurify_hp_threshold) or 60)
  local mp_ok = mp <= (tonumber(P.cfg.aurify_mp_threshold) or 60)
  if P.cfg.aurify_require_both == true then
    return hp_ok and mp_ok
  end
  return hp_ok or mp_ok
end

function P.reave_profile(name)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end

  local trusted = _humour_truth_trusted(target)
  local counts = {}
  local distinct = 0
  local total = 0
  local max_count = 0

  for i = 1, #P.humours do
    local humour = P.humours[i]
    local count = tonumber(P.current_humour_count(target, humour) or 0) or 0
    if count < 0 then
      count = 0
    end
    counts[humour] = count
    if count >= 1 then
      distinct = distinct + 1
    end
    total = total + count
    if count > max_count then
      max_count = count
    end
  end

  return {
    target = target,
    trusted = trusted,
    distinct_tempered = distinct,
    total_temperings = total,
    max_humour_count = max_count,
    estimated_channel_duration = _reave_channel_duration(distinct),
    humour_counts = counts,
  }
end

function P.can_reave(name)
  local profile = P.reave_profile(name)
  local blockers = _reave_blockers()
  local humour_ready = false

  if Yso.alc and type(Yso.alc.humour_ready) == "function" then
    local ok, v = pcall(Yso.alc.humour_ready)
    humour_ready = ok and v == true
  else
    humour_ready = Yso and Yso.bal and Yso.bal.humour ~= false
  end

  profile.humour_ready = humour_ready == true
  profile.blockers = blockers
  profile.all_four_tempered = (profile.distinct_tempered >= 4)

  local legal = profile.target ~= ""
    and profile.trusted == true
    and profile.humour_ready == true
    and profile.all_four_tempered == true
    and #blockers == 0

  profile.legal = legal
  return legal, profile
end

function P.fire_reave(name, profile, opts)
  opts = opts or {}
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end
  if target == "" then
    return false, "no_target"
  end

  local can_reave = false
  can_reave, profile = P.can_reave(target)
  if can_reave ~= true then
    return false, "reave_not_legal"
  end

  if not _send_cmd("pp") then
    return false, "pp_pause_failed"
  end

  local cmd = string.format("reave %s", target)
  local queued = false
  local Q = Yso and Yso.queue or nil
  local queue_verb = _clear_queue_verb(opts.queue_verb)
  local clearfull_lane = (queue_verb == "addclearfull") and "class" or nil
  if Q and type(Q.install_lane) == "function" then
    local qopts = {
      route = _trim(opts.route or "alchemist_reave"),
      target = target,
      queue_verb = queue_verb,
      clearfull_lane = clearfull_lane,
      reason = _trim(opts.reason or "alchemist_reave:reave"),
      kind = _trim(opts.kind or "offense"),
    }
    queued = (Q.install_lane("class", cmd, qopts) == true)
    if queued == true then
      if type(Q.mark_lane_dispatched) == "function" then
        pcall(Q.mark_lane_dispatched, "class", "reave:" .. queue_verb)
      end
      if type(Q.mark_payload_fired) == "function" then
        pcall(Q.mark_payload_fired, { class = cmd, target = target })
      end
    end
  elseif queue_verb == "addclear" and Q and type(Q.addclear) == "function" then
    queued = (Q.addclear("c!p!w!t", cmd) == true)
  elseif Q and type(Q.addclearfull) == "function" then
    queued = (Q.addclearfull("c!p!w!t", cmd) == true)
  elseif type(send) == "function" then
    local raw_verb = (queue_verb == "addclear") and "ADDCLEAR" or "ADDCLEARFULL"
    queued = (pcall(send, "QUEUE " .. raw_verb .. " c!p!w!t " .. cmd, false) == true)
  end

  if queued ~= true then
    _send_cmd("pp")
    return false, "reave_send_failed"
  end

  Yso.alc.reaving = true
  Yso.alc.reave_target = target
  Yso.alc.reave_pp_paused = true

  P.state.reave = P.state.reave or {}
  P.state.reave.last_start = {
    target = target,
    at = _now(),
    profile = profile,
  }

  if Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
    Yso.alc.set_humour_ready(false, "reave_sent")
  end

  local eta = tonumber((profile and profile.estimated_channel_duration) or 4) or 4
  if type(cecho) == "function" then
    cecho(string.format("<gold>[PHYSIOLOGY:] <aquamarine>Reave window on %s: all four humours tempered, estimated channel %ds.\n", target, eta))
  elseif type(echo) == "function" then
    echo(string.format("[PHYSIOLOGY:] Reave window on %s: all four humours tempered, estimated channel %ds.\n", target, eta))
  end

  return true, cmd
end

function P.reave_sync_target(name, source)
  local observed = name
  if observed == nil then
    observed = _current_target()
  end
  observed = _trim(observed)
  local active_target = _trim(Yso.alc.reave_target)

  if Yso.alc.reaving ~= true and Yso.alc.reave_pp_paused ~= true then
    return false
  end

  if active_target == "" then
    return _reave_resume_and_clear("reave_target_missing:" .. tostring(source or "sync"))
  end

  if observed == "" or not _same_target(active_target, observed) then
    return _reave_resume_and_clear("reave_target_change:" .. tostring(source or "sync"))
  end

  return false
end

function P.reave_on_target_slain(name, source)
  local slain = _trim(name)
  local active_target = _trim(Yso.alc.reave_target)
  if active_target == "" then
    return false
  end
  if slain ~= "" and not _same_target(active_target, slain) then
    return false
  end
  return _reave_resume_and_clear("reave_target_slain:" .. tostring(source or "line"))
end

function P.iron_aff_count(name, giving)
  local count = 0
  for i = 1, #_aff_list(giving) do
    if _has_aff(giving[i]) then
      count = count + 1
    end
  end
  return count
end

function P.pick_missing_aff(name, giving)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end

  local sanguine = tonumber(P.current_humour_count(target, "sanguine") or 0) or 0
  for i = 1, #_aff_list(giving) do
    local aff = _lc(giving[i])
    if aff ~= "" and not _has_aff(aff) then
      if aff ~= "paralysis" or sanguine >= 2 then
        return aff
      end
    end
  end
  return nil
end

function P.pick_filler_humour(name, forced_aff, giving)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end

  local preferred = P.aff_to_humour(forced_aff)
  local options = _pool_order(_giving_humour_pools(giving))
  local best_humour, best_count = nil, -1

  for i = 1, #options do
    local humour = options[i]
    local required = P.required_humour_level_for_wrack("truewrack")
    local legal, count = P.can_wrack(target, humour, required)
    count = tonumber(count or 0) or 0
    if humour ~= preferred and legal == true and _humour_missing_desired(target, humour, giving) then
      if count > best_count then
        best_humour = humour
        best_count = count
      end
    end
  end

  return best_humour
end

function P.pick_temper_humour(name, giving)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end

  local pools = _giving_humour_pools(giving)
  local options = _pool_order(pools)
  if #options == 0 then
    return nil
  end

  local sanguine = tonumber(P.current_humour_count(target, "sanguine") or 0) or 0
  if _list_has_aff(giving, "paralysis") and not _has_aff("paralysis") and sanguine < 2 then
    return "sanguine"
  end

  local best_humour = nil
  local best_missing = -1
  local best_count = math.huge

  for i = 1, #options do
    local humour = options[i]
    local affs = pools[humour]
    local missing = 0
    for j = 1, #affs do
      local aff = affs[j]
      local allowed = true
      if aff == "paralysis" and sanguine < 2 then
        allowed = false
      end
      if allowed and not _has_aff(aff) then
        missing = missing + 1
      end
    end

    if missing > 0 then
      local count = tonumber(P.current_humour_count(target, humour) or 0) or 0
      if missing > best_missing or (missing == best_missing and count < best_count) then
        best_humour = humour
        best_missing = missing
        best_count = count
      end
    end
  end

  if best_humour then
    return best_humour
  end

  local first = P.pick_missing_aff(target, giving)
  if not first then
    return nil
  end
  return P.aff_to_humour(first)
end

function P.build_truewrack(name, giving)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end

  local forced = P.pick_missing_aff(target, giving)
  if not forced then
    return nil
  end

  local forced_humour = P.aff_to_humour(forced)
  if not forced_humour then
    return nil
  end
  local required = P.required_humour_level_for_wrack("truewrack", forced)
  local legal, known = P.can_wrack(target, forced_humour, required)
  if legal ~= true then
    _debug(string.format(
      "[Alchemist] wrack blocked: %s requires %s level %d, known=%s",
      tostring(forced),
      tostring(forced_humour),
      tonumber(required) or 0,
      known == nil and "unknown" or tostring(known)
    ))
    return nil
  end

  local filler = P.pick_filler_humour(target, forced, giving)
  if not filler then
    _debug(string.format(
      "[Alchemist] truewrack blocked: no valid filler humour for forced=%s target=%s",
      tostring(forced),
      tostring(target)
    ))
    return nil
  end

  return string.format("truewrack %s %s %s", target, filler, forced), filler, forced
end

function P.build_truewrack_with_staged(name, giving, staged)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end

  local forced = P.pick_missing_aff(target, giving)
  if not forced then
    return nil
  end

  local forced_humour = P.aff_to_humour(forced)
  if not forced_humour then
    return nil
  end
  local required = P.required_humour_level_for_wrack("truewrack", forced)
  local legal, known = P.can_wrack_with_staged(target, forced_humour, required, staged)
  if legal ~= true then
    _debug(string.format(
      "[Alchemist] wrack blocked(staged): %s requires %s level %d, known=%s",
      tostring(forced),
      tostring(forced_humour),
      tonumber(required) or 0,
      known == nil and "unknown" or tostring(known)
    ))
    return nil
  end

  local preferred = P.aff_to_humour(forced)
  local options = _pool_order(_giving_humour_pools(giving))
  local filler, best_count = nil, -1
  for i = 1, #options do
    local humour = options[i]
    local req = P.required_humour_level_for_wrack("truewrack")
    local ok_wrack, count = P.can_wrack_with_staged(target, humour, req, staged)
    count = tonumber(count or 0) or 0
    if humour ~= preferred and ok_wrack == true and _humour_missing_desired(target, humour, giving) then
      if count > best_count then
        filler = humour
        best_count = count
      end
    end
  end

  if not filler then
    _debug(string.format(
      "[Alchemist] truewrack blocked(staged): no valid filler humour for forced=%s target=%s",
      tostring(forced),
      tostring(target)
    ))
    return nil
  end

  return string.format("truewrack %s %s %s", target, filler, forced), filler, forced
end

function P.build_wrack_fallback(name, giving)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end
  if target == "" then
    return nil
  end

  local aff = P.pick_missing_aff(target, giving)
  if aff == nil or aff == "" then
    return nil
  end

  local humour = P.aff_to_humour(aff)
  if not humour then
    return nil
  end
  local required = P.required_humour_level_for_wrack("wrack", aff)
  local legal, known = P.can_wrack(target, humour, required)
  if legal ~= true then
    _debug(string.format(
      "[Alchemist] wrack blocked: %s requires %s level %d, known=%s",
      tostring(aff),
      tostring(humour),
      tonumber(required) or 0,
      known == nil and "unknown" or tostring(known)
    ))
    return nil
  end
  return string.format("wrack %s %s", target, aff), aff
end

function P.build_wrack_fallback_with_staged(name, giving, staged)
  local target = _trim(name)
  if target == "" then
    target = _current_target()
  end
  if target == "" then
    return nil
  end

  local aff = P.pick_missing_aff(target, giving)
  if aff == nil or aff == "" then
    return nil
  end

  local humour = P.aff_to_humour(aff)
  if not humour then
    return nil
  end
  local required = P.required_humour_level_for_wrack("wrack", aff)
  local legal, known = P.can_wrack_with_staged(target, humour, required, staged)
  if legal ~= true then
    _debug(string.format(
      "[Alchemist] wrack blocked(staged): %s requires %s level %d, known=%s",
      tostring(aff),
      tostring(humour),
      tonumber(required) or 0,
      known == nil and "unknown" or tostring(known)
    ))
    return nil
  end
  return string.format("wrack %s %s", target, aff), aff
end

function P.inundate_candidate(target, route_id, opts)
  opts = opts or {}
  target = _trim(target)
  if target == "" then
    target = _current_target()
  end
  if target == "" then
    return nil
  end

  local humour_ready = false
  if Yso.alc and type(Yso.alc.humour_ready) == "function" then
    local ok, res = pcall(Yso.alc.humour_ready)
    humour_ready = ok and res == true
  else
    humour_ready = Yso and Yso.bal and Yso.bal.humour ~= false
  end
  if humour_ready ~= true then
    return nil
  end

  local function pct_candidate(humour, vital_name)
    local count = tonumber(P.current_humour_count(target, humour) or 0) or 0
    local burst = ((P.inundate_math[humour] or {}).burst_pct_by_temper or {})[count]
    if burst == nil then
      return nil
    end
    local now_vital = vital_name == "health" and tonumber(P.health_pct(target)) or tonumber(P.mana_pct(target))
    if now_vital == nil then
      return nil
    end
    local after = now_vital - tonumber(burst)
    if after < 0 then
      after = 0
    end
    return {
      humour = humour,
      cmd = "inundate " .. target .. " " .. humour,
      vital = vital_name,
      count = count,
      estimated_burst_pct = tonumber(burst),
      predicted_after_pct = after,
      route_id = tostring(route_id or ""),
      reason = humour == "choleric" and "inundate_health_burst" or "inundate_mana_burst",
    }
  end

  local c = pct_candidate("choleric", "health")
  if c then
    return c
  end
  local m = pct_candidate("melancholic", "mana")
  if m then
    return m
  end

  local s_count = tonumber(P.current_humour_count(target, "sanguine") or 0) or 0
  if s_count >= 6 then
    local out = {
      humour = "sanguine",
      cmd = "inundate " .. target .. " sanguine",
      vital = "bleeding",
      count = s_count,
      route_id = tostring(route_id or ""),
    }
    if s_count >= 8 then
      out.estimated_bleeding = 2304
      out.exact_bleeding_unknown = true
      out.reason = "inundate_bleed_burst_tbd_8"
    else
      out.estimated_bleeding = 2304
      out.reason = "inundate_bleed_burst"
    end
    return out
  end

  return nil
end
