-- Auto-exported from Mudlet package script: Fool logic
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso / Legacy Fool (Tarot) helper + AUTO + DIAG SNAPSHOT
--  • Uses Legacy.Curing.Affs for conditions
--  • Uses Yso.queue if present, else raw QUEUE commands
--  • Auto-Fool:
--      - GMCP: checks on gmcp.Char.Vitals
--      - Diagnose snapshot: checks when a queued DIAGNOSE finishes
--  • Requirements:
--      - in hunt cureset: cooldown ready + BAL ready now + 3+ current affs
--      - not prone
--      - not paralysis
--      - not webbed
--      - at least one arm NOT brokenleftarm/brokenrightarm
--      - AND (>= min_affs, with cureset-aware thresholds)
--      - non-hunt auto/diag paths still observe local cooldown timing
--========================================================--

Legacy              = Legacy              or {}
Legacy.Curing       = Legacy.Curing       or {}
Legacy.Curing.Affs  = Legacy.Curing.Affs  or {}
Legacy.Fool         = Legacy.Fool         or {}
Legacy.Fool.debug   = Legacy.Fool.debug   or false

-- Queue behaviour + thresholds
Legacy.Fool.queue_mode        = Legacy.Fool.queue_mode        or "addclearfull"  -- add / addclear / addclearfull
Legacy.Fool.queue_type        = Legacy.Fool.queue_type        or "bal"           -- bal / eqbal / free / full / flags
Legacy.Fool.min_affs_default  = Legacy.Fool.min_affs_default  or 6               -- non-hunt curesets
Legacy.Fool.min_affs_hunt     = Legacy.Fool.min_affs_hunt     or 3               -- compatibility field; hunt gate is fixed at 3+
Legacy.Fool.min_affs          = Legacy.Fool.min_affs          or nil             -- optional global override
Legacy.Fool.ignore_blind_deaf = (Legacy.Fool.ignore_blind_deaf ~= false)         -- true = do NOT count blind/deaf

Yso        = Yso        or {}
Yso.queue  = Yso.queue  or {}
Yso._eh    = Yso._eh    or {}
Yso._trig  = Yso._trig  or {}
Yso.fool   = Yso.fool   or {}

local F = Yso.fool
local _dev_cureset_override = nil

F.cfg = F.cfg or {
  enabled = true,   -- auto (GMCP + diagnose snapshot) on/off
  cd      = 35,     -- Fool class cooldown, seconds
  gcd     = 1.0,    -- min seconds between auto attempts
  debug   = false,
}

F.state = F.state or {
  last_used  = 0,     -- when Fool last actually fired
  last_auto  = 0,     -- when auto/diag last attempted Fool
  await_diag = false, -- set by dv alias; cleared on diag completion
  pending = false,
  pending_id = 0,
  pending_source = nil,
  pending_qtype = nil,
  pending_lane = nil,
  pending_cmd = nil,
  pending_owner_token = nil,
  pending_at = 0,
  pending_timer = nil,
  basher_hold = false,
  basher_hold_reason = nil,
  basher_hold_at = 0,
  basher_hold_timer = nil,
}

-- ---------- helpers ----------

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok,v = pcall(Yso.util.now)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  local t = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  if t and t > 20000000000 then t = t / 1000 end
  return t or os.time()
end

local function _is_occultist()
  if Yso and Yso.classinfo and type(Yso.classinfo.is_occultist) == "function" then
    return Yso.classinfo.is_occultist()
  end
  local cls = gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class
  if (type(cls) ~= "string" or cls == "") and type(Yso.class) == "string" then cls = Yso.class end
  return tostring(cls or "") == "Occultist"
end

local function _fool_echo(msg)
  if (F.cfg.debug or Legacy.Fool.debug) and cecho then
    cecho(string.format("<cyan>[Fool] %s\n", tostring(msg)))
  end
end

local function _Aff()
  return (Legacy and Legacy.Curing and Legacy.Curing.Affs) or {}
end

local function _self_has_aff(aff)
  local S = Yso and Yso.self or nil
  if not (S and type(S.has_aff) == "function") then
    return false, false
  end
  local ok, v = pcall(S.has_aff, aff)
  if not ok then
    return false, false
  end
  return (v == true), true
end

local function _self_list_affs()
  local S = Yso and Yso.self or nil
  if not (S and type(S.list_affs) == "function") then
    return nil
  end
  local ok, list = pcall(S.list_affs)
  if not ok or type(list) ~= "table" then
    return nil
  end
  return list
end

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _normalize_cureset_name(v)
  v = _trim(v):lower()
  if v == "" or v == "live" or v == "clear" then
    return nil
  end
  if v == "bash" or v == "bashing" or v == "hunting" or v == "pve" then
    return "hunt"
  end
  return v
end

local function _has(aff)
  local has, known = _self_has_aff(aff)
  if known then
    return has
  end
  local A = _Aff()
  return A[aff] == true
end

local function _both_arms_broken()
  return _has("brokenleftarm") and _has("brokenrightarm")
end

local function _mode_implies_hunt()
  local mode = Yso and Yso.mode
  if type(mode) ~= "table" then
    return false
  end
  if type(mode.is_bash) == "function" then
    local ok, in_bash = pcall(mode.is_bash)
    if ok and in_bash == true then
      return true
    end
  end
  if type(mode.is_hunt) == "function" then
    local ok, in_hunt = pcall(mode.is_hunt)
    if ok and in_hunt == true then
      return true
    end
  end
  local state = _normalize_cureset_name(rawget(mode, "state"))
  return state == "hunt"
end

-- current cureset name from Legacy (e.g. "legacy", "hunt", "group")
local function _current_cureset()
  local cur = _normalize_cureset_name(_dev_cureset_override)
  if cur then
    return cur
  end

  local set = Legacy and Legacy.Curing and Legacy.Curing.ActiveServerSet
  cur = _normalize_cureset_name(set)
  if cur then
    return cur
  end

  local global_cur = rawget(_G, "CurrentCureset")
  cur = _normalize_cureset_name(global_cur)
  if cur then
    return cur
  end

  if _mode_implies_hunt() then
    return "hunt"
  end

  return "legacy"
end

-- Devtools/manual helper only: temporarily simulate a cureset for one call.
function F.dev_with_cureset(name, fn, ...)
  if type(fn) ~= "function" then
    return false, "fn must be a function"
  end

  local prev = _dev_cureset_override
  _dev_cureset_override = _normalize_cureset_name(name)

  local ok, a, b, c, d, e = pcall(fn, ...)
  _dev_cureset_override = prev

  if not ok then
    return false, a
  end
  return true, a, b, c, d, e
end

local function _is_tendon_key(k)
  k = tostring(k or ""):lower()
  return (k == "torntendons" or k == "tendons" or k == "torn_tendons")
end

local function _tendon_severity()
  local ak = rawget(_G, "ak") or rawget(_G, "AK")
  if type(ak) == "table" and type(ak.twoh) == "table" then
    local n = tonumber(ak.twoh.tendons)
    if n and n >= 1 then
      return math.floor(n + 0.00001)
    end
  end
  return 1
end

-- Aff count, optionally ignoring blind/deaf
local function _aff_count()
  local list = _self_list_affs()
  local n = 0
  local ignore_bd = Legacy.Fool.ignore_blind_deaf
  local counted_tendon = false

  local function _count_one(k)
    if k ~= "softlocked" and k ~= "truelocked" then
      if _is_tendon_key(k) then
        if not counted_tendon then
          n = n + _tendon_severity()
          counted_tendon = true
        end
      elseif ignore_bd then
        local kk = tostring(k):lower()
        if kk ~= "blind" and kk ~= "blindness"
           and kk ~= "deaf" and kk ~= "deafness" then
          n = n + 1
        end
      else
        n = n + 1
      end
    end
  end

  if type(list) == "table" then
    for i = 1, #list do
      _count_one(tostring(list[i] or ""))
    end
    return n
  end

  local A = _Aff()
  for k, v in pairs(A) do
    if v == true then
      _count_one(tostring(k or ""))
    end
  end
  return n
end

local function _cooldown_remaining()
  local cd = tonumber(F.cfg.cd or 35) or 35
  local last = tonumber(F.state.last_used or 0) or 0
  local rem = cd - (_now() - last)
  if rem < 0 then rem = 0 end
  return rem
end

local function _vitals()
  return (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
end

local function _bal_ready_now()
  if Yso and Yso.state and type(Yso.state.bal_ready) == "function" then
    local ok, v = pcall(Yso.state.bal_ready)
    if ok then
      return v == true
    end
  end
  local v = _vitals()
  local bal = v.bal or v.balance
  return bal == true or tostring(bal or "") == "1"
end

local function _emit_status(msg)
  if type(cecho) == "function" then
    cecho("<cyan>[Fool] "..tostring(msg).."\n")
  else
    print("[Fool] "..tostring(msg))
  end
end

local function _bool_word(v)
  return (v == true) and "true" or "false"
end

local function _pending_lane_from_qtype(qtype)
  local q = _trim(qtype):lower()
  if q == "bal" or q == "b" or q == "bu" or q == "b!p!w!t" then return "bal" end
  if q == "eq" or q == "e" or q == "e!p!w!t" then return "eq" end
  if q == "class" or q == "c" or q == "c!p!w!t" then return "class" end
  if q == "eqbal" or q == "be" or q == "eb" then return "bal" end
  return nil
end

local function _pending_owner_state()
  local lane = _trim(F.state.pending_lane)
  if lane == "" then return nil end

  local Q = Yso and Yso.queue or nil
  if not (Q and type(Q.get_owned) == "function") then
    return nil
  end

  local rec = Q.get_owned(lane)
  if type(rec) ~= "table" then
    return false
  end

  local token = tostring(F.state.pending_owner_token or "")
  local cmd = _trim(F.state.pending_cmd)
  local cmd_match = (cmd ~= "" and _trim(rec.cmd) == cmd)

  if token ~= "" then
    local note_match = (tostring(rec.note or "") == token)
    if note_match then
      return true
    end
    -- Token can drift if a lane owner row is rewritten by adjacent queue paths.
    -- If command still matches pending Fool, keep cancelability.
    if cmd_match then
      return true
    end
    return false
  end

  return cmd_match
end

local function _clear_pending(reason)
  local had_pending = (F.state.pending == true)
  local lane = _trim(F.state.pending_lane)
  local token = tostring(F.state.pending_owner_token or "")

  if F.state.pending_timer and type(killTimer) == "function" then
    pcall(killTimer, F.state.pending_timer)
  end

  if lane ~= "" and token ~= "" then
    local Q = Yso and Yso.queue or nil
    if Q and type(Q.get_owned) == "function" and type(Q.clear_owned) == "function" then
      local rec = Q.get_owned(lane)
      if type(rec) == "table" then
        local note_match = (tostring(rec.note or "") == token)
        local cmd = _trim(F.state.pending_cmd)
        local cmd_match = (cmd ~= "" and _trim(rec.cmd) == cmd)
        if note_match or cmd_match then
          Q.clear_owned(lane)
        end
      end
    end
  end

  F.state.pending = false
  F.state.pending_source = nil
  F.state.pending_qtype = nil
  F.state.pending_lane = nil
  F.state.pending_cmd = nil
  F.state.pending_owner_token = nil
  F.state.pending_at = 0
  F.state.pending_timer = nil
  if had_pending then
    _fool_echo("Pending Fool cleared ("..tostring(reason or "unknown")..").")
  end
end

local function _mark_pending(source, qtype, cmd)
  local lane = _pending_lane_from_qtype(qtype)
  F.state.pending_id = (tonumber(F.state.pending_id or 0) or 0) + 1
  local token = "fool_pending:" .. tostring(F.state.pending_id)

  F.state.pending = true
  F.state.pending_source = tostring(source or "manual")
  F.state.pending_qtype = tostring(qtype or Legacy.Fool.queue_type or "bal")
  F.state.pending_lane = lane
  F.state.pending_cmd = tostring(cmd or "fling fool at me")
  F.state.pending_owner_token = token
  F.state.pending_at = _now()

  local Q = Yso and Yso.queue or nil
  if lane and Q and type(Q.set_owned) == "function" then
    local rec = {
      cmd = F.state.pending_cmd,
      qtype = F.state.pending_qtype,
      target = "me",
      route = "fool",
      installed_at = F.state.pending_at,
      source_file = "fool_logic.lua",
      note = token,
      last_result = "installed",
      last_error = "",
    }
    if type(Q.fingerprint) == "function" then
      rec.fingerprint = Q.fingerprint(F.state.pending_cmd, {
        target = "me",
        route = "fool",
      })
    end
    Q.set_owned(lane, rec)
  end

  if type(tempTimer) == "function" then
    local pending_gen = F.state.pending_id
    local timer_id = tempTimer(15, function()
      if tonumber(F.state.pending_id or 0) ~= pending_gen then return end
      _clear_pending("timeout")
      _release_basher_hold("pending-timeout")
    end)
    if timer_id then
      F.state.pending_timer = timer_id
    else
      _fool_echo("WARNING: tempTimer returned nil; pending fallback auto-clearing.")
      _clear_pending("timer-unavailable")
    end
  else
    _fool_echo("WARNING: tempTimer unavailable; pending fallback auto-clearing.")
    _clear_pending("timer-unavailable")
  end

  _fool_echo(string.format(
    "Pending Fool armed (source=%s, qtype=%s, lane=%s).",
    F.state.pending_source,
    F.state.pending_qtype,
    tostring(F.state.pending_lane or "?")
  ))
end

local function _has_pending()
  return F.state.pending == true
end

local function _release_basher_hold(reason)
  local had_hold = (F.state.basher_hold == true) or (F.state.basher_hold_timer ~= nil)
  -- Invalidate any previously armed timeout callback generation first.
  F.state.basher_hold_gen = (tonumber(F.state.basher_hold_gen or 0) or 0) + 1
  if F.state.basher_hold_timer and type(killTimer) == "function" then
    local ok, killed = pcall(killTimer, F.state.basher_hold_timer)
    if not ok or killed == false then
      _fool_echo("Basher hold timer cleanup could not confirm kill.")
    end
  end
  F.state.basher_hold_timer = nil
  F.state.basher_hold = false
  F.state.basher_hold_reason = nil
  F.state.basher_hold_at = 0
  if had_hold then
    _fool_echo("Basher hold released ("..tostring(reason or "unknown")..").")
  end
end

local function _arm_basher_hold(reason)
  _release_basher_hold("refresh")

  F.state.basher_hold_gen = (tonumber(F.state.basher_hold_gen or 0) or 0) + 1
  local hold_gen = F.state.basher_hold_gen
  F.state.basher_hold = true
  F.state.basher_hold_reason = tostring(reason or "fool")
  F.state.basher_hold_at = _now()
  _fool_echo("Basher hold armed ("..F.state.basher_hold_reason..").")

  if type(tempTimer) ~= "function" then
    _fool_echo("WARNING: tempTimer unavailable; basher hold skipped.")
    F.state.basher_hold = false
    F.state.basher_hold_reason = nil
    F.state.basher_hold_at = 0
    F.state.basher_hold_timer = nil
    return
  end

  local timer_id = tempTimer(10, function()
    if tonumber(F.state.basher_hold_gen or 0) ~= hold_gen then return end
    _release_basher_hold("timeout")
  end)
  if timer_id then
    F.state.basher_hold_timer = timer_id
    return
  end

  _fool_echo("WARNING: tempTimer returned nil; basher hold skipped.")
  F.state.basher_hold = false
  F.state.basher_hold_reason = nil
  F.state.basher_hold_at = 0
  F.state.basher_hold_timer = nil
end

local function _clear_basher_queue()
  local S = Legacy and Legacy.Settings and Legacy.Settings.Basher
  if type(S) ~= "table" then
    return false
  end
  if S.status ~= true then
    return false
  end

  if type(send) == "function" then
    send("cq freestand", false)
  end
  S.queued = false
  return true
end

function F.blocks_basher()
  return F.state.basher_hold == true
end

local _is_lock_state
local _min_affs_for_current_set
local _evaluate_fool
local _cancel_pending_fool
local _recheck_pending_fool
local _cooldown_ready

function F.status()
  local curset = _current_cureset() or "legacy"
  local count = _aff_count()
  local is_locked = _is_lock_state()
  local min_affs, allow_lock = _min_affs_for_current_set()
  local qmode = tostring(Legacy.Fool.queue_mode or "addclearfull")
  local qtype = tostring(Legacy.Fool.queue_type or "bal")
  local auto = (F.cfg.enabled == true) and "on" or "off"
  local hold = (F.blocks_basher() == true) and "on" or "off"
  local hold_reason = tostring(F.state.basher_hold_reason or "-")
  local pending = (_has_pending() == true) and "on" or "off"
  local pending_src = tostring(F.state.pending_source or "-")

  _emit_status(string.format(
    "auto=%s cureset=%s aff_score=%d min=%d allow_lock=%s lock=%s cd_left=%.1fs queue=%s/%s pending=%s(%s) basher_hold=%s(%s)",
    auto,
    curset,
    count,
    min_affs,
    _bool_word(allow_lock),
    _bool_word(is_locked),
    _cooldown_remaining(),
    qmode,
    qtype,
    pending,
    pending_src,
    hold,
    hold_reason
  ))
end

function F.set_auto(v)
  local on = nil
  local t = type(v)
  if t == "boolean" then
    on = v
  elseif t == "number" then
    on = (v ~= 0)
  elseif t == "string" then
    local s = _trim(v):lower()
    if s == "on" or s == "1" or s == "true" then
      on = true
    elseif s == "off" or s == "0" or s == "false" then
      on = false
    end
  end

  if on == nil then
    _emit_status("Usage: lua Yso.fool.set_auto(true|false)")
    return false
  end

  F.cfg.enabled = on
  _emit_status("Auto-Fool is now "..(on and "ON." or "OFF."))
  return true
end

-- Lock detector (still used for non-hunt curesets)
_is_lock_state = function()
  if _has("softlocked") or _has("truelocked") then
    return true
  end

  local core = _has("impatience")
           and _has("asthma")
           and _has("slickness")
           and _has("anorexia")

  if not core then
    return false
  end

  return true
end

-- Resolve min_affs and whether "lock" is allowed to override the threshold
-- • HUNT cureset: fixed 3-aff threshold, lock does NOT override
-- • Other curesets: min_affs_default, lock CAN override (for PvP)
-- • Global Legacy.Fool.min_affs override (if set) always uses lock override.
_min_affs_for_current_set = function()
  local cur = _current_cureset() or "legacy"
  if cur == "hunt" then
    return 3, false -- Hunt is always a fixed 3-aff threshold with no lock override.
  end

  -- explicit global override wins
  if Legacy.Fool.min_affs ~= nil then
    local v = tonumber(Legacy.Fool.min_affs)
    if v and v >= 1 then
      return v, true  -- allow lock override in this case
    end
  end

  local v = tonumber(Legacy.Fool.min_affs_default or 6) or 6
  if v < 1 then v = 1 end
  return v, true   -- lock override allowed
end

_evaluate_fool = function(source)
  local ctx = {
    source = tostring(source or "manual"),
    curset = _current_cureset() or "?",
    count = _aff_count(),
    is_locked = _is_lock_state(),
  }
  ctx.min_affs, ctx.allow_lock = _min_affs_for_current_set()
  ctx.lock_ok = (ctx.allow_lock == true and ctx.is_locked == true)

  if _has("paralysis") then
    ctx.reason = "paralysis"
    ctx.message = "Not using Fool: paralysis."
    return false, ctx
  end

  if _has("prone") then
    ctx.reason = "prone"
    ctx.message = "Not using Fool: prone."
    return false, ctx
  end

  if _has("webbed") then
    ctx.reason = "webbed"
    ctx.message = "Not using Fool: webbed."
    return false, ctx
  end

  if _both_arms_broken() then
    ctx.reason = "both_arms_broken"
    ctx.message = "Not using Fool: both arms broken."
    return false, ctx
  end

  if ctx.curset == "hunt" then
    if not _cooldown_ready() then
      ctx.reason = "cooldown"
      ctx.message = "Not using Fool: cooldown not ready."
      return false, ctx
    end
    if not _bal_ready_now() then
      ctx.reason = "bal_not_ready"
      ctx.message = "Not using Fool: balance lane not ready."
      return false, ctx
    end
  end

  if ctx.count < ctx.min_affs and not ctx.lock_ok then
    ctx.reason = "threshold"
    ctx.message = string.format(
      "Not using Fool: cureset=%s, affs=%d (< %d), allow_lock=%s, lock=%s.",
      ctx.curset, ctx.count, ctx.min_affs, tostring(ctx.allow_lock), tostring(ctx.is_locked)
    )
    return false, ctx
  end

  ctx.reason = "ok"
  ctx.message = string.format(
    "Using Fool (source=%s, cureset=%s, affs=%d, min=%d, allow_lock=%s, lock=%s).",
    ctx.source, ctx.curset, ctx.count, ctx.min_affs,
    tostring(ctx.allow_lock), tostring(ctx.is_locked)
  )
  return true, ctx
end

_cancel_pending_fool = function(reason)
  if not _has_pending() then
    return false
  end

  local owner_state = _pending_owner_state()
  if owner_state == false then
    _fool_echo("Pending Fool ownership changed; skipping queue clear.")
    _clear_pending(reason or "replaced")
    _release_basher_hold("replaced")
    return true
  end

  local lane = _trim(F.state.pending_lane)
  local qtype = tostring(F.state.pending_qtype or Legacy.Fool.queue_type or "bal")
  local ok = false
  local Q = Yso and Yso.queue or nil

  if owner_state ~= true then
    _fool_echo("Pending Fool ownership unknown; attempting best-effort queue clear.")
  end

  if Q and lane ~= "" and type(Q.clear_lane) == "function" then
    local cleared = Q.clear_lane(lane, { qtype = qtype })
    ok = (cleared == true)
  elseif Q and type(Q.raw) == "function" then
    ok = (Q.raw("CLEARQUEUE " .. qtype) == true)
  elseif type(send) == "function" then
    send("CLEARQUEUE " .. qtype, false)
    ok = true
  end

  if ok then
    _fool_echo("Canceled pending Fool queue ("..tostring(reason or "stale")..").")
    _clear_pending(reason or "cancel")
    _release_basher_hold("cancel:"..tostring(reason or "stale"))
  else
    _fool_echo("Failed to clear pending Fool queue ("..tostring(reason or "stale")..").")
  end

  return ok
end

_recheck_pending_fool = function(source)
  if not _has_pending() then
    return false, "no_pending"
  end

  local ok, ctx = _evaluate_fool(F.state.pending_source or source or "pending")
  if ok then
    return false, "still_valid"
  end

  _fool_echo("Pending Fool became stale: "..tostring(ctx.reason or "unknown")..".")
  _cancel_pending_fool(ctx.reason or "stale")
  return true, tostring(ctx.reason or "stale")
end

F.recheck_pending = _recheck_pending_fool

-- Queue helper
local function _queue_fool(source)
  if not _is_occultist() then
    _fool_echo("Not using Fool: current class is not Occultist.")
    return false
  end
  local mode  = tostring(Legacy.Fool.queue_mode or "addclearfull")
  local qtype = tostring(Legacy.Fool.queue_type or "bal")
  local cmd   = "fling fool at me"
  local queue_fn_name = mode:lower()
  local queue_fn = Yso.queue and Yso.queue[queue_fn_name]
  local hold_reason = "fool:" .. tostring(source or "manual")

  _clear_basher_queue()

  if type(queue_fn) == "function" then
    -- Yso queue helper path
    local queued = (queue_fn(qtype, cmd) == true)
    if queued then
      _mark_pending(source, qtype, cmd)
      _arm_basher_hold(hold_reason)
      _fool_echo(string.format("Queued Fool via %s %s.", mode, qtype))
    else
      _clear_pending("queue-failed")
      _release_basher_hold("queue-failed")
    end
    return queued
  else
    -- raw queue path
    local ok = pcall(send, string.format("queue %s %s %s", mode, qtype, cmd), false)
    if not ok then
      _clear_pending("queue-error")
      _release_basher_hold("queue-error")
      return false
    end
    _mark_pending(source, qtype, cmd)
    _arm_basher_hold(hold_reason)
    _fool_echo(string.format("Queued Fool via %s %s.", mode, qtype))
    return true
  end
end

--========================================================--
--  Public helper: Legacy.FoolSelfCleanse(source)
--  • Used by:
--      - auto driver (GMCP)
--      - diagnose snapshot hook
--      - your ^fool$ alias (manual panic button)
--  • Returns true if Fool was queued.
--========================================================--
function Legacy.FoolSelfCleanse(source)
  if not (Legacy and Legacy.Curing and Legacy.Curing.Affs) then
    return false
  end
  source = tostring(source or "manual")

  if _has_pending() then
    _fool_echo("Not using Fool: pending queue already armed.")
    return false
  end

  local ok, ctx = _evaluate_fool(source)
  _fool_echo(ctx.message)
  if not ok then
    return false
  end

  local queued = _queue_fool(source)
  return queued == true
end

-- ---------- cooldown helpers for auto/diag paths ----------

_cooldown_ready = function()
  local cd   = tonumber(F.cfg.cd or 35) or 35
  local last = tonumber(F.state.last_used or 0) or 0
  return (_now() - last) >= cd
end

local function _gcd_ready()
  local gcd  = tonumber(F.cfg.gcd or 1) or 1
  local last = tonumber(F.state.last_auto or 0) or 0
  return (_now() - last) >= gcd
end

local function _safe(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then
      _fool_echo("ERROR: "..tostring(err))
    end
  end
end

--========================================================--
--  Auto driver #1: GMCP vitals tick
--========================================================--
function F.on_vitals()
  _recheck_pending_fool("vitals")

  if not F.cfg.enabled then return end
  if not _is_occultist() then return end
  if _has_pending() then return end
  if not _cooldown_ready() then return end
  if not _gcd_ready() then return end

  -- quick check: any affs at all?
  local A = _Aff()
  local list = _self_list_affs()
  local has_any = false
  if type(list) == "table" then
    has_any = (#list > 0)
  else
    for _, v in pairs(A) do
      if v == true then has_any = true; break end
    end
  end
  if not has_any then return end

  F.state.last_auto = _now()
  local used = Legacy.FoolSelfCleanse("auto")
  if used then
    _fool_echo("Auto-Fool fired from GMCP.")
  end
end

--========================================================--
--  Auto driver #2: Diagnose snapshot
--========================================================--

-- Called from your dv alias
function F.mark_diag_pending()
  F.state.await_diag = true
  _fool_echo("Marked: next EQ used line is from DIAGNOSE.")
end

-- Trigger: when equilibrium is used, and a diagnose is pending
if Yso._trig.fool_eq then
  killTrigger(Yso._trig.fool_eq)
end
Yso._trig.fool_eq = tempRegexTrigger(
  [[^Equilibrium used:\s+([0-9.]+)s\.]],
  _safe(function()
    if not F.state.await_diag then
      return
    end
    -- This EQ-used belongs to the queued DIAGNOSE.
    F.state.await_diag = false

    if not F.cfg.enabled then return end
    if not _cooldown_ready() then
      _fool_echo("Diag snapshot seen, but Fool cooldown not ready.")
      return
    end

    F.state.last_auto = _now()
    local used = Legacy.FoolSelfCleanse("diagnose")
    if used then
      _fool_echo("Fool fired on diagnose snapshot.")
    else
      _fool_echo("Diagnose snapshot: conditions failed, Fool not used.")
    end
  end)
)

if Yso._trig.fool_success then
  killTrigger(Yso._trig.fool_success)
end
Yso._trig.fool_success = tempRegexTrigger(
  [[^You press the Fool tarot to your forehead\.$]],
  _safe(function()
    F.state.last_used = _now()
    _clear_pending("success")
    _release_basher_hold("success")
    if type(cecho) == "function" then
      cecho("\n<yellow>[Tarot] <DeepSkyBlue>(PURGED!).<reset>\n")
      if type(resetFormat) == "function" then
        resetFormat()
      end
    end
  end)
)

--========================================================--
--  User-facing toggles
--========================================================--
function F.toggle_auto()
  F.set_auto(not (F.cfg.enabled == true))
end

function F.set_cd(seconds)
  local s = tonumber(seconds)
  if not s or s < 0 then
    cecho("<cyan>[Fool] Usage: lua Yso.fool.set_cd(<seconds>)\n")
    return
  end
  F.cfg.cd = s
  cecho(string.format("<cyan>[Fool] Cooldown set to %.1fs.\n", s))
end

function F.set_min_affs(n)
  local v = tonumber(n)
  if not v or v < 1 then
    cecho("<cyan>[Fool] Usage: lua Yso.fool.set_min_affs(<count>=1+)\n")
    return
  end
  Legacy.Fool.min_affs = v
  cecho(string.format("<cyan>[Fool] Global min_affs override now %d.\n", v))
end

local function _queue_diag()
  local Q = Yso and Yso.queue or nil
  if Q and type(Q.addclearfull) == "function" then
    Q.addclearfull("e", "diagnose")
    return true
  end
  if Q and type(Q.eq_clear) == "function" then
    Q.eq_clear("diagnose")
    return true
  end
  if type(send) == "function" then
    send("diagnose")
    return true
  end
  return false
end

local function _kill_alias(id)
  if id then
    pcall(killAlias, id)
  end
end

Yso._alias = Yso._alias or {}
if type(tempAlias) == "function" then
  _kill_alias(Yso._alias.fool_diag)
  Yso._alias.fool_diag = tempAlias([[^dv$]], _safe(function()
    if type(F.mark_diag_pending) == "function" then
      F.mark_diag_pending()
    else
      F.state.await_diag = true
    end

    if not _queue_diag() then
      _fool_echo("Failed to queue diagnose from dv alias.")
    end
  end))
  _kill_alias(Yso._alias.fool_status)
  Yso._alias.fool_status = tempAlias([[^fool status$]], _safe(function()
    F.status()
  end))
  _kill_alias(Yso._alias.fool_auto_on)
  Yso._alias.fool_auto_on = tempAlias([[^fool auto on$]], _safe(function()
    F.set_auto(true)
  end))
  _kill_alias(Yso._alias.fool_auto_off)
  Yso._alias.fool_auto_off = tempAlias([[^fool auto off$]], _safe(function()
    F.set_auto(false)
  end))
end

--========================================================--
--  Register GMCP handler
--========================================================--
if Yso._eh.fool_vitals then
  killAnonymousEventHandler(Yso._eh.fool_vitals)
end
Yso._eh.fool_vitals = registerAnonymousEventHandler(
  "gmcp.Char.Vitals",
  _safe(F.on_vitals)
)

if Yso._eh.fool_aff_add then
  killAnonymousEventHandler(Yso._eh.fool_aff_add)
end
Yso._eh.fool_aff_add = registerAnonymousEventHandler(
  "gmcp.Char.Afflictions.Add",
  _safe(function() _recheck_pending_fool("gmcp.aff.add") end)
)

if Yso._eh.fool_aff_remove then
  killAnonymousEventHandler(Yso._eh.fool_aff_remove)
end
Yso._eh.fool_aff_remove = registerAnonymousEventHandler(
  "gmcp.Char.Afflictions.Remove",
  _safe(function() _recheck_pending_fool("gmcp.aff.remove") end)
)

if Yso._eh.fool_aff_list then
  killAnonymousEventHandler(Yso._eh.fool_aff_list)
end
Yso._eh.fool_aff_list = registerAnonymousEventHandler(
  "gmcp.Char.Afflictions.List",
  _safe(function() _recheck_pending_fool("gmcp.aff.list") end)
)

if Yso._eh.fool_self_aff_changed then
  killAnonymousEventHandler(Yso._eh.fool_self_aff_changed)
end
Yso._eh.fool_self_aff_changed = registerAnonymousEventHandler(
  "yso.self.aff.changed",
  _safe(function() _recheck_pending_fool("yso.self.aff.changed") end)
)

_fool_echo("Yso Fool auto module loaded (GMCP+aff-change+diagnose hooks active).")
--========================================================--
