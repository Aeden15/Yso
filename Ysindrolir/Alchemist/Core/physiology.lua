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
P.aff_to_humour = {}
for humour, affs in pairs(P.humour_to_affs) do
  for i = 1, #affs do
    P.aff_to_humour[affs[i]] = humour
  end
end
P.state.evaluate = P.state.evaluate or {
  target = "",
  active = false,
  requested_at = 0,
  started_at = 0,
}
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

local function _giving_humour_pools(giving)
  local pools = {}
  for i = 1, #_aff_list(giving) do
    local aff = _lc(giving[i])
    local humour = P.aff_to_humour[aff]
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
  }

  P.targets[key] = row
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

function P.mark_all_eval_dirty(name, source)
  local target_row = _target_row(name)
  if not target_row then
    return false
  end

  target_row.eval_dirty = true
  target_row.last_dirty_source = tostring(source or "manual")
  target_row.last_dirty_at = _now()
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

  P.state.evaluate.target = target_row.name
  P.state.evaluate.requested_at = _now()
  P.state.evaluate.request_source = tostring(source or "route")
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
  target_row.last_evaluated_at = _now()
  target_row.eval_dirty = false
  P.state.humour_eval_target = target_row.name
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

  local preferred = P.aff_to_humour[_lc(forced_aff or "")]
  local options = _pool_order(_giving_humour_pools(giving))
  local best_humour, best_count = nil, -1

  for i = 1, #options do
    local humour = options[i]
    local count = tonumber(P.current_humour_count(target, humour) or 0) or 0
    if humour ~= preferred and count >= 1 and _humour_missing_desired(target, humour, giving) then
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
  return P.aff_to_humour[_lc(first or "")] or "choleric"
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
  return string.format("wrack %s %s", target, aff), aff
end
