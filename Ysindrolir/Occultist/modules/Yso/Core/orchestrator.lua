--========================================================--
-- Yso.Orchestrator — Central Tick Orchestration (Single Authority Pass)
--  ✅ Exclusive driver (optional): blocks other pulse callbacks
--  ✅ Module proposal contract: register() + propose(ctx) -> actions
--  ✅ Deterministic arbitration: phase -> module priority -> action score
--  ✅ Single commit per pulse flush via Yso.queue
--
-- Action schema (table):
--   cmd        = "string"    (required)
--   qtype      = "eq|bal|free|..." (required; passed to Yso.queue.stage)
--   tag        = "stable.id" (recommended; used for lockout/no-repeat)
--   score      = number      (default 0)
--   kind       = "defense|cure|offense|utility" (optional; else module.kind)
--   requires   = { bal=true/false, eq=true/false, target=true, target_present=true/false,
--                  aff_present={...}, aff_absent={...} }
--   lockout    = seconds
--   no_repeat  = true|false (default true when tag exists)
--   exclusive  = { "other.tag", ... }  (mutual exclusion)
--   allow_multi= true|false (default false; per-qtype single primary)
--   replace    = true|false (allow replacing same-qtype primary if higher score)
--
-- Shared universal route categories:
--   • defense_break
--   • anti_tumble
-- Other strategic categories remain route-local and may differ by route.
--
-- Recommended orchestrator override policy:
--   • narrow_global_only
--   • override only for hard global conditions and shared universal categories
--========================================================--

Yso = Yso or {}
Yso.Orchestrator = Yso.Orchestrator or {}
local O = Yso.Orchestrator

O.cfg = O.cfg or {
  -- Single automated authority for Occultist offense.
  -- When we commit, later pulse callbacks should not emit again on the same wake.
  exclusive  = true,
  debug      = false,
  trace      = false,
  max_cmds   = 10,     -- Achaea global cap
  free_multi = 2,      -- allow up to N primary "free" actions per tick
  commit_even_if_no_proposals = false, -- single-authority mode: do not commit shadow staged offense
}

O.modules   = O.modules   or { list = {} }
O.lockouts  = O.lockouts  or {}   -- tag -> expire_time (epoch seconds)
O.last_sent = O.last_sent or {}   -- tag -> { cmd=..., state_sig=..., at=... }
O.last_lane_categories = O.last_lane_categories or {}
O.state = O.state or { last_tick = nil, last_picked = {}, last_override = false, last_reasons = {} }

O.override_policy = O.override_policy or {
  mode = "narrow_global_only",
  allowed = {
    reserved_burst        = true,
    target_invalid        = true,
    target_slain          = true,
    route_off             = true,
    pause                 = true,
    manual_suppression    = true,
    target_swap_bootstrap = true,
    defense_break         = true,
    anti_tumble           = true,
  },
}

O.route_contract = O.route_contract or {
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = "route_defined",
}

local PHASE = { defense=1, cure=2, offense=3, utility=4 }

local function _now()
  local getEpoch = rawget(_G, "getEpoch")
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  local _now = rawget(_G, "_now")
  if type(_now) == "function" then return _now() end
  return os.time()
end

local function _dbg(msg)
  if O.cfg.debug and cecho then
    cecho(("<dim_grey>[Yso.Orch] <reset>%s\n"):format(tostring(msg)))
  end
end

local function _trc(msg)
  if O.cfg.trace and cecho then
    cecho(("<gray>[Yso.Orch.trace] <reset>%s\n"):format(tostring(msg)))
  end
end

local function _has_aff(a)
  return (Yso.affs and Yso.affs[a] == true) or false
end

local function _is_shared_category(cat)
  cat = tostring(cat or "")
  if cat == "" then return false end

  local shared = (O.route_contract and O.route_contract.shared_categories) or {}
  if type(shared) == "table" then
    if shared[cat] == true then return true end
    for i = 1, #shared do
      if tostring(shared[i] or "") == cat then return true end
    end
  end

  return false
end

local function _prefer_route_local_over_shared(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return nil end

  local a_pref = (a.prefer_over_shared == true)
  local b_pref = (b.prefer_over_shared == true)
  if a_pref == b_pref then return nil end

  local a_shared = _is_shared_category(a.category)
  local b_shared = _is_shared_category(b.category)

  if a_pref and b_shared and not a_shared then return true end
  if b_pref and a_shared and not b_shared then return false end

  return nil
end

local function _snapshot()
  if Yso.state and type(Yso.state.snapshot) == "function" then
    local ok, s = pcall(Yso.state.snapshot)
    if ok and type(s) == "table" then return s end
  end
  return { raw = (Yso.state or {}) }
end

local function _state_sig(s)
  local tgt = ""
  if s and s.tgt and s.tgt.name then tgt = tostring(s.tgt.name) end
  local me = s and s.me or {}
  local bal = tostring(me.bal or me.balance or "")
  local eq  = tostring(me.eq  or me.equilibrium or "")
  local hp  = tostring(me.hp or "")
  local mp  = tostring(me.mp or "")
  local av  = tostring((Yso.state and Yso.state.aff_version) or (s and s.aff_version) or "")
  return table.concat({tgt, bal, eq, hp, mp, av}, "|")
end

local function _requires_ok(req, s)
  if not req then return true end
  local me  = (s and s.me)  or {}
  local tgt = (s and s.tgt) or {}

  if req.target then
    if not (tgt and tgt.present and tgt.name and tgt.name ~= "") then return false end
  end

  if req.bal ~= nil then
    local bal = (me.bal == true) or (tostring(me.bal or me.balance or "") == "1")
    if bal ~= req.bal then return false end
  end
  if req.eq ~= nil then
    local eq = (me.eq == true) or (tostring(me.eq or me.equilibrium or "") == "1")
    if eq ~= req.eq then return false end
  end

  if type(req.aff_present) == "table" then
    for i=1,#req.aff_present do
      if not _has_aff(req.aff_present[i]) then return false end
    end
  end
  if type(req.aff_absent) == "table" then
    for i=1,#req.aff_absent do
      if _has_aff(req.aff_absent[i]) then return false end
    end
  end

  return true
end

local function _lockout_ok(tag)
  if not tag or tag == "" then return true end
  local exp = O.lockouts[tag]
  return (not exp) or (_now() >= exp)
end

local function _apply_lockout(tag, seconds)
  if not tag or tag == "" then return end
  local s = tonumber(seconds or 0)
  if s > 0 then O.lockouts[tag] = _now() + s end
end

local function _no_repeat_ok(a, s)
  if a.no_repeat == false then return true end
  if not a.tag or a.tag == "" then return true end
  local last = O.last_sent[a.tag]
  if not last then return true end
  return not (last.cmd == a.cmd and last.state_sig == _state_sig(s))
end

local function _mark_sent(a, s)
  if not a.tag or a.tag == "" then return end
  O.last_sent[a.tag] = { cmd = a.cmd, state_sig = _state_sig(s), at = _now() }
end

local function _payload_contains_cmd(payload, qtype, cmd)
  if type(payload) ~= "table" then return false end
  local lane = tostring(qtype or ""):lower()
  if lane == "ent" or lane == "entity" then lane = "class" end
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

local function _mark_sent_actions(actions, payload, s)
  if type(actions) ~= "table" or type(payload) ~= "table" then return end
  for i=1,#actions do
    local a = actions[i]
    if type(a) == "table" and _payload_contains_cmd(payload, a.qtype, a.cmd) then
      O.last_lane_categories[a.qtype] = a.category or "unspecified"
      _apply_lockout(a.tag, a.lockout)
      _mark_sent(a, s)
    end
  end
end

function O.register(mod)
  if type(mod) ~= "table" or type(mod.id) ~= "string" then return false end
  mod.kind     = mod.kind or "utility"
  mod.priority = tonumber(mod.priority or 0)
  mod._phase   = PHASE[mod.kind] or 99
  table.insert(O.modules.list, mod)
  return true
end

local function _collect_actions(ctx)
  local out = {}

  local mods = {}
  for i=1,#O.modules.list do mods[#mods+1] = O.modules.list[i] end
  table.sort(mods, function(a,b)
    if a._phase ~= b._phase then return a._phase < b._phase end
    if a.priority ~= b.priority then return a.priority > b.priority end
    return (a.id or "") < (b.id or "")
  end)

  for _, m in ipairs(mods) do
    if type(m.propose) == "function" then
      local ok, proposed = pcall(m.propose, ctx)
      if ok and type(proposed) == "table" then
        for i=1,#proposed do
          local a = proposed[i]
          if type(a) == "table" then
            a._mid   = m.id
            a._mprio = m.priority
            a._phase = PHASE[a.kind or m.kind] or m._phase or 99
            a.score  = tonumber(a.score or 0)
            a.tag    = a.tag or (m.id .. ":" .. tostring(i))
            if a.no_repeat == nil then a.no_repeat = true end
            out[#out+1] = a
            if O.cfg.trace then _trc(("%s -> %s [%s]"):format(m.id, tostring(a.cmd), tostring(a.tag))) end
          end
        end
      end
    end
  end

  return out
end

-- Lua 5.1 compatible "continue" pattern: per-iteration repeat..until true
function O.select(actions, s)
  local picked = {}
  local used_cmd = {}
  local used_tag = {}
  local used_q_primary = {} -- qtype -> true
  local blocked = {}        -- tag -> true
  local free_left = tonumber(O.cfg.free_multi or 2)
  local cap = tonumber(O.cfg.max_cmds or 10)

  table.sort(actions, function(a,b)
    if a._phase ~= b._phase then return a._phase < b._phase end

    local pref = _prefer_route_local_over_shared(a, b)
    if pref ~= nil then return pref end

    if a._mprio ~= b._mprio then return a._mprio > b._mprio end
    if a.score ~= b.score then return a.score > b.score end
    local aid = (a._mid or "") .. ":" .. (a.tag or "")
    local bid = (b._mid or "") .. ":" .. (b.tag or "")
    return aid < bid
  end)

  for _, a in ipairs(actions) do
    if #picked >= cap then break end

    repeat
      if type(a.cmd) ~= "string" or a.cmd == "" then break end
      a.qtype = tostring(a.qtype or "")
      if a.qtype == "" then break end

      if blocked[a.tag] then break end
      if not _requires_ok(a.requires, s) then break end
      if not _lockout_ok(a.tag) then break end
      if not _no_repeat_ok(a, s) then break end
      if used_cmd[a.cmd] then break end

      -- exclusives: don't allow if any exclusive already used
      if type(a.exclusive) == "table" then
        local bad = false
        for i=1,#a.exclusive do
          if used_tag[a.exclusive[i]] then bad = true; break end
        end
        if bad then break end
      end

      local is_free = (a.qtype == "free")
      local allow_multi = (a.allow_multi == true)

      -- per-qtype primary rule (except allow_multi)
      if not allow_multi then
        if is_free then
          if free_left <= 0 then break end
        else
          if used_q_primary[a.qtype] then
            -- replace existing primary if requested + higher score
            if a.replace then
              local idx, old = nil, nil
              for i=1,#picked do
                if picked[i].qtype == a.qtype and picked[i]._primary then idx, old = i, picked[i]; break end
              end
              if idx and old and a.score > tonumber(old.score or 0) then
                used_cmd[old.cmd] = nil
                used_tag[old.tag] = nil
                picked[idx] = a
                a._primary = true
                used_cmd[a.cmd] = true
                used_tag[a.tag] = true
                used_q_primary[a.qtype] = true
                if type(a.exclusive) == "table" then
                  for j=1,#a.exclusive do blocked[a.exclusive[j]] = true end
                end
              end
            end
            break
          end
        end
      end

      -- accept
      a._primary = (not allow_multi)
      picked[#picked+1] = a
      used_cmd[a.cmd] = true
      used_tag[a.tag] = true

      if a._primary and not is_free then used_q_primary[a.qtype] = true end
      if is_free and not allow_multi then free_left = free_left - 1 end

      if type(a.exclusive) == "table" then
        for j=1,#a.exclusive do blocked[a.exclusive[j]] = true end
      end
    until true
  end

  return picked
end

local function _queue_has_staged()
  local Q = Yso.queue
  if not (Q and type(Q._staged) == "table") then return false end
  for _, list in pairs(Q._staged) do
    if type(list) == "table" and #list > 0 then return true end
  end
  return false
end

function O.run(reasons)
  O.last_lane_categories = {}
  local s = _snapshot()
  local ctx = {
    now = _now(),
    reasons = reasons or {},
    snap = s,
    state = Yso.state,
    affs = Yso.affs,
  }

  -- Hard stop: if offense is paused, clear any staged payloads and do not emit.
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() then
    local Qp = Yso.queue
    if Qp and type(Qp.clear) == "function" then
      pcall(Qp.clear)
    end
    return false
  end

  -- Manual inhibit: block automation commit during 400ms window after manual cmd
  if Yso.inhibit and type(Yso.inhibit.active) == "function" and Yso.inhibit.active() then
    _dbg("inhibit active — skipping commit")
    local Qi = Yso.queue
    if Qi and type(Qi.clear) == "function" then pcall(Qi.clear) end
    return false
  end

  local actions = _collect_actions(ctx)
  local picked = {}
  if #actions > 0 then
    picked = O.select(actions, s)
  end

    local Q = Yso.queue
  if not (Q and type(Q.stage) == "function" and type(Q.commit) == "function") then
    _dbg("queue missing stage/commit; skipping output")
    return false
  end

  -- Enforce centralized commit: turn off legacy autocommit wrappers (migration-safe)
  if Q.cfg and Q.cfg.legacy_autocommit ~= false then
    Q.cfg.legacy_autocommit = false
  end

  -- Stage picked actions
  local staged = {}
  for i=1,#picked do
    local a = picked[i]
    local ok, staged_ok = pcall(Q.stage, a.qtype, a.cmd, a.opts or {})
    if ok and staged_ok == true then
      staged[#staged+1] = a
    end
  end

  -- Commit once if we staged anything OR if other code staged ops (migration-friendly)
  local did_commit = false
  if (#staged > 0) or (O.cfg.commit_even_if_no_proposals and _queue_has_staged()) then
        local hint = (Q and type(Q._commit_hint)=="table" and Q._commit_hint) or {}
    Q._commit_hint = nil

    -- Derive lane isolation from pulse wake reasons (coalesce eq > class > bal).
    if hint.wake_lane == nil and type(reasons) == "table" then
      local w = nil
      for i=1,#reasons do
        if tostring(reasons[i] or "") == "lane:eq" then w = "eq"; break end
      end
      if not w then
        for i=1,#reasons do
          if tostring(reasons[i] or "") == "lane:class" then w = "class"; break end
        end
      end
      if not w then
        for i=1,#reasons do
          if tostring(reasons[i] or "") == "lane:bal" then w = "bal"; break end
        end
      end
      if w then hint.wake_lane = w end
    end

    -- Piggyback hint: allow EQ+CLASS in the same emission only when both lanes woke.
    if hint.piggyback == nil and type(reasons) == "table" then
      local saw_eq, saw_class = false, false
      for i=1,#reasons do
        local r = tostring(reasons[i] or "")
        if r == "lane:eq" then saw_eq = true
        elseif r == "lane:class" then saw_class = true
        end
      end
      if saw_eq and saw_class then hint.piggyback = true end
    end

    local ok_commit, commit_ok, sent_payload = pcall(Q.commit, hint)
    if ok_commit and commit_ok == true then
      _mark_sent_actions(staged, sent_payload, s)
      did_commit = true
    end
  end

  O.state.last_tick = _now()
  O.state.last_reasons = reasons or {}
  O.state.last_picked = picked

  if O.cfg.debug then
    local cats = {}
    for lane, cat in pairs(O.last_lane_categories or {}) do cats[#cats+1] = tostring(lane)..":"..tostring(cat) end
    table.sort(cats)
    _dbg(("tick: proposals=%d picked=%d commit=%s cats=%s"):format(#actions, #picked, tostring(did_commit), table.concat(cats, ",")))
  end

  return did_commit
end

function O.wake(reason)
  reason = tostring(reason or "orchestrator")
  if Yso and Yso.pulse and type(Yso.pulse.wake) == "function" then
    return pcall(Yso.pulse.wake, "orch:"..reason)
  end
  return false
end

-- Compatibility: older code may call Yso.tick("reason")
if type(_G.Yso.tick) ~= "function" then
  function _G.Yso.tick(reason) O.wake(reason) end
end

-- Pulse driver (exclusive by default)
if Yso and Yso.pulse and type(Yso.pulse.register) == "function" then
  Yso.pulse.register("orchestrator", function(reasons)
    local ok, did_commit = pcall(O.run, reasons)
    -- Only block other callbacks when we *actually* committed commands.
    local ex = (O.cfg.exclusive == true)
    if Yso and Yso.mode and type(Yso.mode.is_hunt)=="function" and Yso.mode.is_hunt() then ex = false end
    if ex and ok and did_commit and Yso.pulse and Yso.pulse.state then
      Yso.pulse.state._did_emit = true
    end
  end, { order = 1 })
end

_dbg("Orchestrator loaded (exclusive=" .. tostring(O.cfg.exclusive) .. ")")
--========================================================--
