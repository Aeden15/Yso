-- DO NOT EDIT IN XML; edit this file instead.

Yso = Yso or {}
Yso.entities = Yso.entities or {}

local E = Yso.entities

E.cfg = E.cfg or {
  command_confirm_grace_s = 1.5,
  order = { "worm", "sycophant" },
}
E.state = E.state or {
  last = nil,
  hooks_installed = false,
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
    if ok and tonumber(v) then return tonumber(v) end
  end
  return os.time()
end

local function _clone(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for k, v in pairs(value) do
    out[_clone(k, seen)] = _clone(v, seen)
  end
  return out
end

local function _er()
  return Yso and Yso.off and Yso.off.oc and Yso.off.oc.entity_registry or nil
end

local function _target_state(tgt)
  local ER = _er()
  local targets = ER and ER.state and ER.state.targets or nil
  if type(targets) ~= "table" then return nil end
  return targets[_lc(tgt)]
end

local function _entity_cmd(entity, tgt)
  entity = _lc(entity)
  tgt = _trim(tgt)
  if entity == "" or tgt == "" then return nil end
  return ("command %s at %s"):format(entity, tgt)
end

local function _required_map(ctx)
  local out = {}
  local payload = type(ctx) == "table" and ctx.payload or nil
  local meta = type(payload) == "table" and payload.meta or nil
  local src = (type(ctx) == "table" and ctx.required_entities) or (type(meta) == "table" and meta.required_entities) or nil
  if type(src) ~= "table" then return out end
  for name, wanted in pairs(src) do
    out[_lc(name)] = (wanted == true)
  end
  return out
end

local function _entity_duration(entity)
  local ER = _er()
  local cfg = ER and ER.cfg or nil
  if entity == "worm" then
    return tonumber(cfg and cfg.worm_duration_s or 20) or 20
  end
  if entity == "sycophant" then
    return tonumber(cfg and cfg.sycophant_duration_s or 30) or 30
  end
  return 0
end

local function _ak_enemy_matches(tgt)
  local enemy = Yso and Yso.ak and Yso.ak.enemy or nil
  if type(enemy) ~= "table" then return false end
  local name = _lc(enemy.name or enemy.target or "")
  return name ~= "" and name == _lc(tgt)
end

local function _sycophant_confirm_state(tgt)
  local last_gain = 0
  local last_cure = 0
  local aff_name = "rixil"
  local enemy = Yso and Yso.ak and Yso.ak.enemy or nil
  if type(enemy) == "table" then
    local gains = type(enemy.last_gain) == "table" and enemy.last_gain or {}
    local cures = type(enemy.last_cure) == "table" and enemy.last_cure or {}
    last_gain = tonumber(gains[aff_name] or gains[_lc(aff_name)] or 0) or 0
    last_cure = tonumber(cures[aff_name] or cures[_lc(aff_name)] or 0) or 0
  end

  local score = 0
  if Yso and Yso.oc and Yso.oc.ak and type(Yso.oc.ak.get_aff_score) == "function" then
    local ok, v = pcall(Yso.oc.ak.get_aff_score, aff_name)
    if ok then score = tonumber(v or 0) or 0 end
  end
  local has_aff = false
  if Yso and Yso.ak and type(Yso.ak.has) == "function" then
    local ok, v = pcall(Yso.ak.has, aff_name)
    if ok then has_aff = (v == true) end
  end

  local target_matches = _ak_enemy_matches(tgt)
  local confirmed = target_matches and last_gain > 0 and last_gain >= last_cure and (has_aff or score >= 100)
  return {
    last_confirmed_at = confirmed and last_gain or 0,
    cured_at = target_matches and last_cure or 0,
    active_confirmed = confirmed,
  }
end

local function _collect_entity_state(entity, tgt, wanted)
  local now = _now()
  local T = _target_state(tgt)
  local last_sent = 0
  local last_success = 0
  local expires_at = 0
  local active_confirmed = false
  local stale = false

  if T and type(T.last_sent_at) == "table" then
    last_sent = tonumber(T.last_sent_at[entity] or 0) or 0
  end

  if entity == "worm" then
    local W = T and T.effects and T.effects.worm or nil
    local proc_at = W and tonumber(W.last_proc_at or 0) or 0
    last_success = math.max(
      tonumber(T and T.last_success_at and T.last_success_at.worm or 0) or 0,
      proc_at
    )
    expires_at = tonumber(W and W.until_t or 0) or 0
    active_confirmed = last_success > 0 and expires_at > now
  elseif entity == "sycophant" then
    local S = T and T.effects and T.effects.sycophant or nil
    local confirm = _sycophant_confirm_state(tgt)
    last_success = tonumber(confirm.last_confirmed_at or 0) or 0
    expires_at = math.max(
      tonumber(S and S.until_t or 0) or 0,
      (last_success > 0) and (last_success + _entity_duration(entity)) or 0
    )
    active_confirmed = confirm.active_confirmed == true and expires_at > now
    if tonumber(confirm.cured_at or 0) > last_success then
      -- Cured timestamp supersedes prior confirmation.
      active_confirmed = false
      stale = true
    end
  end

  local grace = tonumber(E.cfg.command_confirm_grace_s or 1.5) or 1.5
  if wanted == true then
    if active_confirmed ~= true and last_sent > 0 and (now - last_sent) > grace then
      stale = true
    end
    if active_confirmed == true and expires_at <= now then
      stale = true
      active_confirmed = false
    end
    if active_confirmed ~= true and last_success <= 0 and last_sent <= 0 then
      stale = true
    end
  end

  return {
    entity = entity,
    target = _trim(tgt),
    wanted = wanted == true,
    active_confirmed = active_confirmed == true,
    last_commanded_at = last_sent,
    last_confirmed_at = last_success,
    expires_at = expires_at,
    stale = stale == true,
    blocked_reason = "",
  }
end

function E.install_hooks()
  if E.state.hooks_installed == true then return true end
  if type(tempRegexTrigger) ~= "function" then return false end

  E._hook_ids = E._hook_ids or {}
  if E._hook_ids.worm_chew then pcall(killTrigger, E._hook_ids.worm_chew) end
  E._hook_ids.worm_chew = tempRegexTrigger(
    [[^Many somethings writhe beneath the skin of (.+), and the sickening sound of chewing can be heard\.$]],
    function()
      local who = matches[2] or ""
      local ER = _er()
      if who ~= "" and ER and type(ER.note_worm_proc) == "function" then
        pcall(ER.note_worm_proc, who)
      end
    end
  )

  E.state.hooks_installed = true
  return true
end

function E.uninstall_hooks()
  E._hook_ids = E._hook_ids or {}
  if E._hook_ids.worm_chew and type(killTrigger) == "function" then
    pcall(killTrigger, E._hook_ids.worm_chew)
  end
  E._hook_ids.worm_chew = nil
  E.state = E.state or {}
  E.state.hooks_installed = false
  return true
end

function E.collect(ctx)
  pcall(E.install_hooks)
  local payload = type(ctx) == "table" and ctx.payload or nil
  local tgt = _trim((type(ctx) == "table" and ctx.target) or (type(payload) == "table" and payload.target) or "")
  local required = _required_map(ctx)
  local snapshot = {
    at = _now(),
    target = tgt,
    required = {},
  }

  for i = 1, #(E.cfg.order or {}) do
    local entity = _lc(E.cfg.order[i])
    snapshot.required[entity] = _collect_entity_state(entity, tgt, required[entity] == true)
  end

  E.state.last = snapshot
  return snapshot
end

function E.classify(required_state, payload, ctx)
  local out = {
    required = {},
    obligations = {},
    blocked = {},
    stale = {},
    top = nil,
  }

  local lane_ready = not (type(ctx) == "table" and type(ctx.lane_ready) == "table")
    or ctx.lane_ready.entity ~= false
  local hinder = type(ctx) == "table" and ctx.hinder_decision or nil
  local hinder_block = nil
  if type(hinder) == "table" and type(hinder.blocked_lanes) == "table"
    and type(hinder.blocked_lanes.entity) == "table" and #hinder.blocked_lanes.entity > 0 then
    hinder_block = tostring(hinder.blocked_lanes.entity[1] or "entity_blocked")
  end

  for i = 1, #(E.cfg.order or {}) do
    local entity = _lc(E.cfg.order[i])
    local row = type(required_state) == "table" and type(required_state.required) == "table" and required_state.required[entity] or nil
    if type(row) == "table" then
      local item = _clone(row)
      out.required[entity] = item
      if item.wanted == true and (item.active_confirmed ~= true or item.stale == true) then
        item.reason = (item.last_confirmed_at or 0) > 0 and "stale" or "missing"
        if item.stale == true then
          out.stale[entity] = _clone(item)
        end
        if hinder_block then
          item.blocked_reason = hinder_block
          out.blocked[entity] = _clone(item)
        elseif lane_ready ~= true then
          item.blocked_reason = "entity_not_ready"
          out.blocked[entity] = _clone(item)
        else
          item.cmd = _entity_cmd(entity, item.target)
          out.obligations[entity] = _clone(item)
          if not out.top then
            out.top = _clone(item)
          end
        end
      end
    end
  end

  return out
end

function E.apply(payload, obligations, ctx)
  local out = _clone(payload)
  out.lanes = type(out.lanes) == "table" and out.lanes or {}
  out.meta = type(out.meta) == "table" and out.meta or {}

  local top = type(obligations) == "table" and obligations.top or nil
  if type(top) == "table" and _trim(top.cmd) ~= "" then
    out.meta.original_entity_lane = out.lanes.entity or out.lanes.class
    out.meta.original_entity_category = out.meta.entity_category
    out.lanes.entity = top.cmd
    out.lanes.class = top.cmd
    out.meta.entity_category = "required_entity_maintenance"
    out.meta.required_entity = top.entity
  end

  return out
end

return E
