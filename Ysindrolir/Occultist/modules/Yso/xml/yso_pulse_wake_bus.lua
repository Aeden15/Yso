-- Auto-exported from Mudlet package script: Yso.pulse (wake bus)
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso.pulse (wake/tick bus) — PURE DISPATCHER
--========================================================--
-- What this is:
--   A centralized wake bus that simply *dispatches* work once per tick.
--   It does NOT maintain an independent readiness model.
--
-- What this is NOT:
--   No per-lane ready/pending state machine in the bus.
--   Readiness/backoff live in Yso.state / Yso.locks.
--   Emission lives in Yso.emit() / Yso.queue (RAW sendAll/send).
--
-- Key guarantee:
--   Dispatch is guarded by Yso.util.tick_once("yso.tick", 0.05, fn)
--   so disk pulse + mpackage wake sources cannot double-tick.
--========================================================--

Yso = Yso or {}
Yso.pulse = Yso.pulse or {}

local P = Yso.pulse
P.cfg = P.cfg or {
  debounce = 0.05,
  debug = false,

  -- Legacy qtype strings are retained for compatibility with callers that still
  -- pass them into Yso.queue.stage()/addclear(). They no longer represent
  -- server-side QUEUE usage.
  q_eq    = "e!p!w!t",
  q_bal   = "b!p!w!t",
  q_class = "c!p!w!t",
  q_free  = "free",

  replace_when_pending = true,
}

P.state = P.state or {
  reg = {},
  reg_order = {},
  reasons = {},
  _debounce_timer = nil,
  _in_flush = false,
  _did_emit = false, -- used by flush callbacks to detect a successful emit
  _eh_vitals = nil,
  _eh_prompt = nil,
}

local function _dbg(msg)
  if P.cfg.debug then cecho("<gray>[pulse] "..tostring(msg).."\n") end
end

local function _trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+",""):gsub("%s+$","")
  return s
end

local function _resort()
  local tmp = {}
  for name, r in pairs(P.state.reg) do
    tmp[#tmp+1] = { name = name, order = tonumber(r.order) or 50 }
  end
  table.sort(tmp, function(a,b)
    if a.order == b.order then return a.name < b.name end
    return a.order < b.order
  end)
  P.state.reg_order = tmp
end

function P.debug(on)
  P.cfg.debug = (on == true)
  _dbg("debug="..tostring(P.cfg.debug))
end

function P.register(name, fn, opts)
  name = tostring(name or "")
  if name == "" or type(fn) ~= "function" then return end
  opts = opts or {}
  P.state.reg[name] = {
    fn = fn,
    order = tonumber(opts.order) or 50,
    enabled = (opts.enabled ~= false),
  }
  _resort()
end

function P.enable(name, on)
  local r = P.state.reg[name]
  if not r then return end
  r.enabled = (on == true)
  P.wake("enable:"..tostring(name))
end

function P.wake(reason)
  reason = tostring(reason or "wake")
  P.state.reasons[reason] = true

  if P.state._debounce_timer then return end
  P.state._debounce_timer = tempTimer(P.cfg.debounce or 0.05, function()
    P.state._debounce_timer = nil
    P.flush()
  end)
end

P.bump = P.wake

-- ---------------- compatibility adapters (NOT a readiness model) ----------------
-- Some triggers/modules still call pulse.set_ready()/is_ready().
-- We forward to canonical Yso.state readiness helpers.
local function _lane_key(lane)
  lane = tostring(lane or ""):lower()
  if lane == "ent" or lane == "entity" then return "class" end
  return lane
end

function P.set_ready(lane, ready, src)
  lane = _lane_key(lane)
  ready = (ready == true)
  src = tostring(src or "pulse:set_ready")

  -- Only entity/class has a canonical settable readiness.
  if lane == "class" and Yso.state and type(Yso.state.set_ent_ready) == "function" then
    pcall(Yso.state.set_ent_ready, ready, src)
  end

  -- Always wake so handlers can re-evaluate.
  P.wake(src)
end

function P.is_ready(lane)
  lane = _lane_key(lane)
  if lane == "eq" and Yso.state and type(Yso.state.eq_ready)=="function" then
    local ok,v = pcall(Yso.state.eq_ready); if ok then return v==true end
  elseif lane == "bal" and Yso.state and type(Yso.state.bal_ready)=="function" then
    local ok,v = pcall(Yso.state.bal_ready); if ok then return v==true end
  elseif lane == "class" and Yso.state and type(Yso.state.ent_ready)=="function" then
    local ok,v = pcall(Yso.state.ent_ready); if ok then return v==true end
  end
  return true
end

-- Optional ack hook for entity command outcomes.
function P.entity_ack(kind, src)
  kind = tostring(kind or ""):lower()
  src = tostring(src or "entity_ack")

  -- On failure/cooldown/disregard:
  --   • clamp ENT lane immediately
  --   • clear any staged ENT payloads (silent no-op)
  --   • do NOT re-stage the last ENT command (avoids spam loops)
  local function _clamp_and_clear(reason, is_cooldown)
    local Y = rawget(_G, "Yso")
    if Y and Y.queue and type(Y.queue.clear) == "function" then
      pcall(Y.queue.clear, "class")
    end
    local last_ent_cmd = nil
    if Y and Y.state then
      last_ent_cmd = Y.state._last_ent_cmd
      Y.state._last_ent_cmd = nil
      Y.state._last_ent_cmd_ts = nil
    end
    local ER = Y and Y.off and Y.off.oc and Y.off.oc.entity_registry or nil
    if ER and type(ER.note_fail_from_cmd) == "function" and type(last_ent_cmd) == "string" and last_ent_cmd ~= "" then
      pcall(ER.note_fail_from_cmd, last_ent_cmd, reason)
    end

    local cd = (Y and Y.state and tonumber(Y.state._ent_last_cmd_cd)) or nil
    local backoff = is_cooldown and (cd or 1.25) or 0.85

    if Y and Y.state and type(Y.state.ent_fail) == "function" then
      pcall(Y.state.ent_fail, backoff, reason)
    elseif Y and Y.state and type(Y.state.set_ent_ready) == "function" then
      pcall(Y.state.set_ent_ready, false, reason)
    end

    P.wake(reason)
  end

  if kind == "fail" or kind == "disregard" then
    _clamp_and_clear(src .. ":" .. kind, false)
    return
  elseif kind == "cooldown" then
    _clamp_and_clear(src .. ":" .. kind, true)
    return
  elseif kind == "sent" then
    -- Mirror the old behavior: once we *send* an entity command, mark lane busy.
    if Yso.state and type(Yso.state.set_ent_ready) == "function" then
      pcall(Yso.state.set_ent_ready, false, src)
    end
    return
  end
end



-- Payload convenience: split by pipe separator and classify into lanes.
-- This is only a compatibility helper for older modules; preferred approach is
-- to call Yso.emit({eq=..., bal=..., class=..., free=...}).
local function _is_free(c)
  local lc = c:lower()
  return lc == "stand"
      or lc:match("^writhe%s+")
      or lc:match("^contemplate%s+")
      or lc:match("^order%s+")
end
local function _is_entity(c)
  local lc = c:lower()
  if not lc:match("^command%s+") then return false end
  -- Gremlin/soulmaster are EQ-lane despite the "command" verb.
  if lc:match("^command%s+gremlin%s+") or lc:match("^command%s+soulmaster%s+") then return false end
  return true
end
local function _is_bal_main(c)
  local lc = c:lower()
  return lc:match("^fling%s+")
      or lc:match("^flick%s+")
      or lc:match("^toss%s+")
      or lc:match("^ruinate%s+")
      or lc:match("^throw%s+")
      or lc:match("^wipe%s+")
      or lc:match("^envenom%s+")
end

local function _emit(payload, opts)
  -- Emission priority is intentional:
  -- 1) emit_now: immediate force-commit path for urgent/off-cycle sends.
  -- 2) emit: normal staged/commit-aware route path.
  -- 3) queue.emit: compatibility fallback when bus helpers load before api wiring.
  if type(Yso.emit_now) == "function" then
    local ok = Yso.emit_now(payload, opts)
    if ok then P.state._did_emit = true end
    return ok
  end
  if type(Yso.emit) == "function" then
    local ok = Yso.emit(payload, opts)
    if ok then P.state._did_emit = true end
    return ok
  end
  -- Fallback: route to raw queue emitter.
  if Yso.queue and type(Yso.queue.emit)=="function" then
    local ok, result = pcall(Yso.queue.emit, payload)
    if ok and result then P.state._did_emit = true end
    return ok and result
  end
  return false
end

function P.send_free(cmd, opts)   return _emit({ free = cmd }, opts or { reason = "pulse.send_free" }) end
function P.send_eq(cmd, opts)     return _emit({ eq = cmd },   opts or { reason = "pulse.send_eq", prefer = "eq" }) end
function P.send_bal(cmd, opts)    return _emit({ bal = cmd },  opts or { reason = "pulse.send_bal", prefer = "bal" }) end
function P.send_entity(cmd, opts) return _emit({ class = cmd }, opts or { reason = "pulse.send_entity" }) end

function P.queue(payload, opts)
  payload = _trim(payload)
  if payload == "" then return false end

  local sep = (Yso and Yso.cfg and Yso.cfg.pipe_sep) or (Yso and Yso.sep) or "&&"
  local parts = {}

  -- Split on separator (plain find; safe for any separator string)
  local i = 1
  while true do
    local a,b = payload:find(sep, i, true)
    if not a then
      local chunk = _trim(payload:sub(i))
      if chunk ~= "" then parts[#parts+1] = chunk end
      break
    end
    local chunk = _trim(payload:sub(i, a-1))
    if chunk ~= "" then parts[#parts+1] = chunk end
    i = b + 1
  end

  local free = {}
  local ent, eq, bal = nil, nil, nil

  local prefer = opts and tostring(opts.prefer or ""):lower() or ""
  if prefer ~= "bal" then prefer = "eq" end

  for _,c in ipairs(parts) do
    local lc = c:lower()
    if lc:match("^command%s+gremlin%s+") then
      -- Gremlin shieldbreak is EQ-solo. Do not attach anything.
      return P.send_eq(c, { solo=true, prefer="eq", reason="pulse.queue:gremlin" })
    elseif lc:match("^command%s+soulmaster%s+") or lc:match("^order%s+soulmaster%s+") then
      -- Soulmaster commands are EQUILIBRIUM-based in Achaea; treat as EQ-solo.
      return P.send_eq(c, { solo=true, prefer="eq", reason="pulse.queue:soulmaster" })
    elseif _is_free(c) then
      free[#free+1] = c
    elseif _is_entity(c) then
      ent = ent or c
    else
      if _is_bal_main(c) then
        bal = bal or c
      else
        eq = eq or c
      end
    end
  end

  -- Never EQ+BAL together unless explicitly allowed.
  if eq and bal and not (opts and opts.allow_eqbal == true) then
    if prefer == "bal" then eq = nil else bal = nil end
  end

  return _emit({ free = free, class = ent, eq = eq, bal = bal }, opts or { reason = "pulse.queue" })
end

local function _staged_has_payload(staged)
  if type(staged) ~= "table" then return false end
  if type(staged.free) == "table" and #staged.free > 0 then return true end
  if _trim(staged.eq) ~= "" then return true end
  if _trim(staged.bal) ~= "" then return true end
  if _trim(staged.class) ~= "" then return true end
  return false
end

local function _flush_staged_queue()
  local Q = Yso and Yso.queue or nil
  if not (Q and type(Q.commit) == "function") then return false end

  local staged = type(Q.list) == "function" and Q.list() or Q._staged
  if not _staged_has_payload(staged) then
    Q._commit_hint = nil
    return false
  end

  local opts = type(Q._commit_hint) == "table" and Q._commit_hint or {}
  local ok, sent = pcall(Q.commit, opts)
  if not ok then
    _dbg("queue.commit error: " .. tostring(sent))
    return false
  end
  if sent ~= true then return false end

  Q._commit_hint = nil
  P.state._did_emit = true
  return true
end

P.register("queue.commit", _flush_staged_queue, { order = -100 })

-- ---------------- dispatch loop ----------------
function P._flush_inner()
  if P.state._in_flush then return end
  P.state._in_flush = true
  P.state._did_emit = false

  local reasons = {}
  for k,_ in pairs(P.state.reasons) do reasons[#reasons+1] = k end
  table.sort(reasons)
  P.state.reasons = {}

  if P.cfg.debug and #reasons > 0 then
    _dbg("wake: "..table.concat(reasons, ", "))
  end

  for _,row in ipairs(P.state.reg_order) do
    local r = P.state.reg[row.name]
    if r and r.enabled and type(r.fn)=="function" then
      local ok, err = pcall(r.fn, reasons)
      if not ok then _dbg("ERR "..row.name..": "..tostring(err)) end
      if P.state._did_emit then break end
    end
  end

  P.state._in_flush = false
end

function P.flush()
  if Yso.util and type(Yso.util.tick_once) == "function" then
    local ok, res = Yso.util.tick_once("yso.tick", 0.05, P._flush_inner)
    return res
  end
  return P._flush_inner()
end

-- GMCP wake: mirror vitals into Yso.state via ingest, then wake.
local function _on_vitals()
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}

  if Yso and Yso.ingest and type(Yso.ingest.vitals) == "function" then
    pcall(Yso.ingest.vitals, v, "gmcp")
  end

  if Yso and Yso.locks and type(Yso.locks.sync_vitals) == "function" then
    pcall(Yso.locks.sync_vitals, v)
  end

  P.wake("gmcp:vitals")
end

if P.state._eh_vitals then pcall(killAnonymousEventHandler, P.state._eh_vitals) end
P.state._eh_vitals = registerAnonymousEventHandler("gmcp.Char.Vitals", _on_vitals)
if not P.state._eh_vitals then _dbg("failed to register gmcp.Char.Vitals handler") end

-- Prompt wake fallback: prevents "sleep" if GMCP/line triggers are missed.
local function _on_prompt()
  P.wake("prompt")
end
if P.state._eh_prompt then pcall(killAnonymousEventHandler, P.state._eh_prompt) end
P.state._eh_prompt = registerAnonymousEventHandler("sysPrompt", _on_prompt)
if not P.state._eh_prompt then _dbg("failed to register sysPrompt handler") end

_dbg("pulse bus loaded (dispatcher-only)")
--========================================================--


-- ---------------- compatibility shims ----------------
-- Some older disk-based modules call kick()/stop()/unregister(); keep them working.
if type(P.kick) ~= "function" then
  function P.kick(reason) return P.wake(reason or "kick") end
end

if type(P.unregister) ~= "function" then
  function P.unregister(name)
    name = tostring(name or "")
    if name == "" then return end
    P.state.reg[name] = nil
    _resort()
  end
end

if type(P.stop) ~= "function" then
  function P.stop()
    -- Disable every registered handler and cancel any pending debounce flush.
    for _, r in pairs(P.state.reg or {}) do
      if type(r) == "table" then r.enabled = false end
    end
    if P.state._debounce_timer and type(killTimer) == "function" then
      pcall(killTimer, P.state._debounce_timer)
    end
    P.state._debounce_timer = nil
    P.state.reasons = {}
  end
end

-- If the disk-based init.lua boot already ran before this bus loaded, wake once.
do
  local root = rawget(_G, "Yso")
  if type(root) == "table" and type(root._boot) == "table" and root._boot.loaded == true then
    P.wake("boot")
  end
end
