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
P.wrack_required_level = tonumber(P.wrack_required_level) or 1
P.truewrack_required_level = tonumber(P.truewrack_required_level) or 1
P.state.evaluate = P.state.evaluate or {
  target = "",
  active = false,
  requested_at = 0,
  started_at = 0,
}
P.state.aff_lookup = P.state.aff_lookup or {}
P.state.corruption = P.state.corruption or {}
P.state.homunculus_attack = P.state.homunculus_attack or {
  active = false,
  target = "",
  changed_at = 0,
}

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
        Q._staged = Q._staged or {}
        Q._staged.free = kept
        cleared_any = true
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
        if type(Q.clear_lane) == "function" then
          Q.clear_lane("bal")
        elseif type(Q.clear_owned) == "function" then
          Q.clear_owned("bal")
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
        if type(Q.clear_lane) == "function" then
          Q.clear_lane("free")
        elseif type(Q.clear_owned) == "function" then
          Q.clear_owned("free")
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

  P.state.evaluate.active = false
  P.state.evaluate.requested_at = 0
  P.state.evaluate.started_at = 0
  target_row.last_evaluated_at = _now()
  target_row.eval_dirty = false
  P.state.humour_eval_target = target_row.name
  P.clear_staged_for_target(target_row.name, "evaluate_result")
  return true
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
  P.state.corruption[key] = {
    target = target,
    applied_at = now,
    expected_expires_at = now + duration,
  }
  return true
end

function P.clear_corruption(name, source)
  local key = _target_key(name)
  if not key then
    return false
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
  if tonumber(row.expected_expires_at or 0) <= _now() then
    P.state.corruption[key] = nil
    return false
  end
  return true
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
  return hp ~= nil and mp ~= nil and hp <= 60 and mp <= 60
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

function P.fire_reave(name, profile)
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
  if not _send_cmd(cmd) then
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
  return P.aff_to_humour(first) or "choleric"
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
  if filler == nil or filler == "" then
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
