-- Auto-exported from Mudlet package script: Yso.queue
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso.queue — RAW payload emitter + lightweight client-side staging
--========================================================--
-- This REPLACES the prior server-side QUEUE engine.
--  • No "QUEUE ADD/REPLACE" commands are sent to the game.
--  • All emissions are RAW send()/sendAll() of real game commands.
--  • Provides a compatible surface for existing modules:
--      - stage()/commit()
--      - addclear()/addclearfull()
--      - replace()
--      - push(cmd, flag)
--      - lane helpers: eq_clear/bal_clear/class_clear/free
--
-- Lanes (canonical):
--   free, eq, bal, class
--
-- Policy:
--   • By default, never emit EQ+BAL together in the same commit.
--     If both are staged, commit() chooses one (opts.prefer = "eq"/"bal")
--     and leaves the other staged for the next commit.
--========================================================--

Yso       = Yso       or {}

--========================================================--
-- Yso.net  (pipeline source-of-truth)
--  • Preferred joiner: "&&"
--  • Fallback joiner: ";;" (last resort)
--  • Default transport: send(joined_payload)
--  • sendAll() only if explicitly enabled: Yso.net.cfg.use_sendAll=true
--========================================================--
Yso.net = Yso.net or {}
do
  local N = Yso.net
  N.cfg = N.cfg or {}

  if N.cfg.dry_run == nil then N.cfg.dry_run = false end
  local function _now_ms()
    if type(getEpoch) == "function" then return getEpoch() end
    return math.floor((os.clock() or 0) * 1000)
  end
  local function _trim(s)
    if type(s) ~= "string" then s = tostring(s or "") end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
  end

  function N.get_sep()
    local cfg = Yso.cfg or {}
    local sep = tostring(N.cfg.sep or cfg.pipe_sep or cfg.raw_sep or Yso.raw_sep or "&&")
    sep = _trim(sep)
    if sep == "" then sep = "&&" end
    -- Allow a small, safe set of separators; default to user preference "&&".
    if sep ~= "&&" and sep ~= "|" and sep ~= ";;" then sep = "&&" end
    return sep
  end

  function N.get_fallback_sep()
    local cfg = Yso.cfg or {}
    local sep = tostring(N.cfg.fallback_sep or cfg.fallback_sep or ";;")
    sep = _trim(sep)
    if sep == "" then sep = ";;" end
    return sep
  end

  local function _dedupe(list)
    local out, seen = {}, {}
    for i = 1, #list do
      local c = _trim(list[i])
      if c ~= "" and not seen[c] then
        seen[c] = true
        out[#out+1] = c
      end
    end
    return out
  end

  local function _as_list(cmds)
    if cmds == nil then return {} end
    if type(cmds) == "string" then
      local s = _trim(cmds)
      return (s ~= "") and { s } or {}
    end
    if type(cmds) == "table" then
      if cmds[1] ~= nil then
        local out = {}
        for i = 1, #cmds do out[#out+1] = tostring(cmds[i] or "") end
        return out
      end
    end
    return {}
  end

  function N.payload_to_list(payload)
    if type(payload) ~= "table" then return _as_list(payload) end
    local out = {}
    local function add(v)
      local list = _as_list(v)
      for i = 1, #list do out[#out+1] = list[i] end
    end
    if payload.free ~= nil then add(payload.free) else add(payload.pre) end
    add(payload.eq)
    add(payload.bal)
    add(payload.class or payload.ent or payload.entity)
    return out
  end

  N._last = N._last or { t = 0, sig = "" }
  N._lane_last = N._lane_last or { free = 0, eq = 0, bal = 0, class = 0 }

  function N.emit(cmds, opts)
    opts = opts or {}

    local lane = tostring(opts.lane or "free")
    if lane == "ent" or lane == "entity" then lane = "class" end

    local cd = tonumber(opts.cd or 0) or 0
    local t = _now_ms()
    if cd > 0 and (t - (N._lane_last[lane] or 0)) < cd then
      return false
    end

    local list = _dedupe(_as_list(cmds))
    if #list == 0 then return false end

    -- NOTE: avoid "\\n" escape sequences; use a literal LF via string.char(10).
    local sig = table.concat(list, string.char(10))
    local window = tonumber(opts.dupe_window_ms or N.cfg.dupe_window_ms or 80) or 80
    if (t - (N._last.t or 0)) < window and sig == (N._last.sig or "") then
      return false
    end
    N._last.t, N._last.sig = t, sig
    N._lane_last[lane] = t

    local sep = N.get_sep()


    -- Manual inhibit: detect offense keywords only for non-automation sends
    local D = Yso.off and Yso.off.driver
    local from_driver = (D and D._from_driver == true)
    if not from_driver and Yso.inhibit and type(Yso.inhibit.check_cmd) == "function" then
      for _, c in ipairs(list) do Yso.inhibit.check_cmd(c) end
    end

    if N.cfg.dry_run == true and type(cecho) == "function" then
      cecho(string.format("<dim_grey>[Yso:DRY] <reset>%s%s", table.concat(list, sep), string.char(10)))
      return true
    end
    if N.cfg.use_sendAll == true and type(sendAll) == "function" then
      sendAll(unpack(list))
      return true
    end

    if type(send) == "function" then
      send(table.concat(list, sep))
      return true
    end
    return false
  end

  function N.emit_payload(payload, opts)
    local list = N.payload_to_list(payload)
    if opts == nil then opts = {} end
    if N.cfg.dry_run ~= true then
      if type(payload) == "table" and (payload.class ~= nil or payload.ent ~= nil or payload.entity ~= nil) then
        if Yso.state and type(Yso.state.set_ent_ready) == "function" then
          pcall(Yso.state.set_ent_ready, false, "net.emit_payload")
        end
      end
    end
    return N.emit(list, opts)
  end
end

Yso.queue = Yso.queue or {}
local Q   = Yso.queue

Yso.cfg = Yso.cfg or {}
-- Prefer "|" everywhere; fallback to ";;" only if explicitly set.
Yso.cfg.pipe_sep = Yso.cfg.pipe_sep or "&&"
Yso.cfg.cmd_sep  = Yso.cfg.cmd_sep  or Yso.cfg.pipe_sep
Yso.cfg.fallback_sep = Yso.cfg.fallback_sep or ";;"
Yso.raw_sep = Yso.raw_sep or Yso.cfg.pipe_sep
Yso.sep = Yso.sep or Yso.cfg.pipe_sep

Q.cfg = Q.cfg or {}
if Q.cfg.enabled == nil then Q.cfg.enabled = true end
Q.cfg.debug = (Q.cfg.debug == true)
-- One source-of-truth: prefer payload send() (joined); sendAll is opt-in via Yso.net.cfg.use_sendAll
Q.cfg.batch_sends = false
Q.cfg.pipe_sep = Q.cfg.pipe_sep or Yso.cfg.pipe_sep
Q.cfg.cmd_sep  = Q.cfg.cmd_sep  or Yso.cfg.cmd_sep
Q.cfg.autocommit = (Q.cfg.autocommit ~= false)

-- staged intents per lane
Q._staged = Q._staged or { free = {}, eq = nil, bal = nil, class = nil }

local function _trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+",""):gsub("%s+$","")
  return s
end

local function _dbg(msg)
  if Q.cfg.debug and type(cecho) == "function" then
    cecho("<dim_grey>[Yso.queue] "..tostring(msg)..string.char(10))
  end
end

local function _pipe()
  local p = tostring((Yso.net and Yso.net.get_sep and Yso.net.get_sep()) or Q.cfg.pipe_sep or Yso.cfg.pipe_sep or "|")
  p = p:gsub("^%s+",""):gsub("%s+$","")
  return (p ~= "" and p) or "|"
end

local function _cmdsep()
  local p = tostring(Q.cfg.cmd_sep or Yso.cfg.cmd_sep or "|")
  p = p:gsub("^%s+",""):gsub("%s+$","")
  return (p ~= "" and p) or "|"
end

local function _split_plain(s, sep)
  local out = {}
  s = tostring(s or "")
  sep = tostring(sep or "|")
  if s == "" then return out end
  if sep == "" then out[1] = s; return out end
  local i = 1
  while true do
    local j = string.find(s, sep, i, true)
    if not j then
      out[#out+1] = string.sub(s, i)
      break
    end
    out[#out+1] = string.sub(s, i, j-1)
    i = j + #sep
    if i > #s + 1 then break end
  end
  return out
end

local function _norm_cmds(cmd)
  if cmd == nil then return nil end
  if type(cmd) == "string" then
    local s = _trim(cmd)
    if s == "" then return nil end
    -- If the command contains pipe_sep, treat it as an inline pipeline.
    local p = _pipe()
    if p ~= "" and s:find(p, 1, true) then
      local parts = _split_plain(s, p)
      local out = {}
      for i=1,#parts do
        local c = _trim(parts[i])
        if c ~= "" then out[#out+1] = c end
      end
      return (#out > 0) and out or nil
    end
    return { s }
  elseif type(cmd) == "table" then
    local out = {}
    for i=1,#cmd do
      local c = _trim(cmd[i])
      if c ~= "" then out[#out+1] = c end
    end
    return (#out > 0) and out or nil
  end
  return nil
end

local function _send(cmd)
  if cmd == nil or cmd == "" then return end
  if type(send) == "function" then
    send(cmd, false)
  end
end

local function _send_all(list)
  if type(list) ~= "table" or #list == 0 then return end
  -- Always prefer joined payload sends via pipe separator.
  if Yso.net and type(Yso.net.emit) == "function" then
    return Yso.net.emit(list)
  end
  _send(table.concat(list, _pipe()))
end

-- RAW single command
function Q.raw(cmd)
  cmd = _trim(cmd)
  if cmd ~= "" then _send(cmd) end
end

-- RAW multi-lane emission.
-- payload may be:
--  • string: pipeline "cmd1|cmd2|cmd3" (pipe_sep)
--  • array: {"cmd1","cmd2",...}
--  • table lanes: free/eq/bal/class/ent/entity/pre
-- ---------- emit observers (post-commit) ----------
-- Tracks certain effect-duration gates only when a payload is actually emitted.
local function _observe_offense_emits(cmd_list)
  if type(cmd_list) ~= "table" then return end
  local routes = (Yso.off and Yso.off.routes) or {}
  local GD = routes.group_damage
  if not GD then return end

  local function _scan(s)
    if type(s) ~= "string" or s == "" then return end
    local low = s:lower()
    local w = low:match("command%s+worm%s+at%s+([^;]+)")
    if w and type(GD.note_worm_sent) == "function" then pcall(GD.note_worm_sent, _trim(w)) end
    local sy = low:match("command%s+sycophant%s+at%s+([^;]+)")
    if sy and type(GD.note_syc_sent) == "function" then pcall(GD.note_syc_sent, _trim(sy)) end
  end

  for i = 1, #cmd_list do _scan(cmd_list[i]) end
end

function Q.emit(payload)
  if payload == nil then return false end

  local ordered = {}

  local function add(cmds)
    cmds = _norm_cmds(cmds)
    if not cmds then return end
    for i=1,#cmds do ordered[#ordered+1] = cmds[i] end
  end

  if type(payload) == "string" then
    add(payload)

  elseif type(payload) == "table" then
    local looks_like_array = (payload[1] ~= nil)
      and (payload.free == nil and payload.pre == nil and payload.eq == nil and payload.bal == nil and payload.class == nil and payload.ent == nil and payload.entity == nil)

    if looks_like_array then
      add(payload)
    else      if payload.free ~= nil then add(payload.free) else add(payload.pre) end
      add(payload.eq)
      add(payload.bal)
      add(payload.class or payload.ent or payload.entity)
    end
  else
    return false
  end

  if #ordered == 0 then return false end

  -- ENT spend hardening:
  -- If we are emitting any entity command via a raw string/array payload,
  -- mark entity balance as spent immediately (do not wait for the next GMCP/prompt refresh).
  local function _spend_ent(src)
    if Yso and Yso.net and Yso.net.cfg and Yso.net.cfg.dry_run == true then return end
    if Yso and Yso.locks and type(Yso.locks.note_send) == "function" then
      pcall(Yso.locks.note_send, "class")
    end
    if Yso and Yso.state and type(Yso.state.set_ent_ready) == "function" then
      pcall(Yso.state.set_ent_ready, false, src or "queue.emit")
    end
  end

  local _need_ent_spend = false
  if type(payload) == "table" then
    local looks_like_array = (payload[1] ~= nil)
      and (payload.free == nil and payload.pre == nil and payload.eq == nil and payload.bal == nil and payload.class == nil and payload.ent == nil and payload.entity == nil)
    if not looks_like_array and (payload.class ~= nil or payload.ent ~= nil or payload.entity ~= nil) then
      _need_ent_spend = true
    end
  end
  if not _need_ent_spend then
    for i=1,#ordered do
      local c = tostring(ordered[i] or ""):lower()
      if c:match("^%s*command%s+") then
        -- Gremlin/soulmaster are EQ-lane despite the "command" verb; do NOT spend entity balance for them.
        if c:match("^%s*command%s+gremlin%s+") or c:match("^%s*command%s+soulmaster%s+") then
          -- skip
        else
          _need_ent_spend = true
          break
        end
      end
    end
  end
  if _need_ent_spend then
    local function _now()
      if type(getEpoch) == "function" then return getEpoch() end
      return os.time()
    end
    for i=1,#ordered do
      local orig = tostring(ordered[i] or "")
      local c = orig:lower()
      if c:match("^%s*command%s+") and not (c:match("^%s*command%s+gremlin%s+") or c:match("^%s*command%s+soulmaster%s+")) then
        if Yso and Yso.state then
          Yso.state._last_ent_cmd = orig
          Yso.state._last_ent_cmd_ts = _now()
        end
        break
      end
    end
    _spend_ent("queue.emit")
  end

  _dbg("TX: "..table.concat(ordered, " ".._pipe().." "))
  -- Route through pipeline source-of-truth.
  if Yso.net and type(Yso.net.emit_payload) == "function" then
    return Yso.net.emit_payload(payload)
  end
  _send_all(ordered)
  return true
end

-- ---------- lane normalization ----------
local function _lane_for(flag)
  flag = tostring(flag or ""):lower()
  if flag == "" then return "free" end
  if flag == "ent" or flag == "entity" or flag == "class" then return "class" end
  if flag == "free" or flag == "pre" then return "free" end

  -- Legacy queue-type strings (server QUEUE syntax)
  if flag == "ebc!p!w!t" or flag:match("^eb") then return "bal" end
  if flag == "ec!p!w!t" or flag:match("^ec") then return "eq" end
  if flag == "c!p!w!t"  or flag:sub(1,1) == "c" then return "class" end
  if flag:sub(1,1) == "b" then return "bal" end
  if flag == "eq" or (flag:sub(1,1) == "e" and not flag:match("^eb")) then return "eq" end
  if flag == "bal" then return "bal" end

  return flag
end

-- ---------- readiness (best effort) ----------
local function _eq_ready()
  if Yso and Yso.locks and type(Yso.locks.eq_ready)=="function" then
    local ok,v = pcall(Yso.locks.eq_ready); if ok then return v==true end
  end
  if Yso and Yso.state and type(Yso.state.eq_ready)=="function" then
    local ok, v = pcall(Yso.state.eq_ready); if ok then return v == true end
  end
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(v.eq or v.equilibrium or "") == "1" or (v.eq == true or v.equilibrium == true)
end
local function _bal_ready()
  if Yso and Yso.locks and type(Yso.locks.bal_ready)=="function" then
    local ok,v = pcall(Yso.locks.bal_ready); if ok then return v==true end
  end
  if Yso and Yso.state and type(Yso.state.bal_ready)=="function" then
    local ok, v = pcall(Yso.state.bal_ready); if ok then return v == true end
  end
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(v.bal or v.balance or "") == "1" or (v.bal == true or v.balance == true)
end
local function _class_ready()
  if Yso and Yso.locks and type(Yso.locks.ent_ready)=="function" then
    local ok,v = pcall(Yso.locks.ent_ready); if ok then return v==true end
  end
  if Yso and Yso.state and type(Yso.state.ent_ready)=="function" then
    local ok, v = pcall(Yso.state.ent_ready); if ok then return v == true end
  end
  return true
end

-- ---------- stage/commit compatible API ----------
function Q.stage(qtype, body, opts)
  opts = opts or {}
  local lane = _lane_for(qtype)
  local cmds = _norm_cmds(body)
  if not cmds then return false end

  if lane == "free" then
    Q._staged.free = Q._staged.free or {}
    for i=1,#cmds do Q._staged.free[#Q._staged.free+1] = cmds[i] end
    return true
  end

  -- eq/bal/class default replace1 semantics
  if #cmds == 1 then
    Q._staged[lane] = cmds[1]
  else
    Q._staged[lane] = cmds
  end
  return true
end

-- commit staged lanes as RAW sends.
-- opts:
--   • prefer: "eq" or "bal" when both staged (default "eq")
--   • allow_eqbal: true to permit both (not recommended)
function Q.commit(opts)
  opts = opts or {}
  local prefer = tostring(opts.prefer or (Yso.cfg and Yso.cfg.emit_prefer) or "eq"):lower()
  if prefer ~= "bal" then prefer = "eq" end
  local allow = (opts.allow_eqbal == true)

    local mode = "as_available" -- locked: single payload policy
  local piggyback = not (Yso.cfg and Yso.cfg.piggyback_class == false)
  Q._last_payload = nil

  -- Optional: lane hint for isolation.
  -- If provided, as_available will emit ONLY that lane (plus free), with optional ENT piggyback.
  local wlane = tostring(opts.wake_lane or opts.only_lane or opts.lane or ""):lower()
  if wlane:match("^lane:") then wlane = wlane:sub(6) end
  if wlane == "ent" or wlane == "entity" then wlane = "class" end

  local staged_free  = Q._staged.free
  local staged_eq    = Q._staged.eq
  local staged_bal   = Q._staged.bal
  local staged_class = Q._staged.class

  local eq_r    = _eq_ready()
  local bal_r   = _bal_ready()
  local class_r = _class_ready()

  local p = { free = staged_free }

  local send_eq, send_bal, send_class = nil, nil, nil
  local paired = false

  local function choose_default()
    if staged_eq ~= nil and eq_r then
      send_eq = staged_eq
      if piggyback and staged_class ~= nil and class_r then send_class = staged_class; paired = true end
      return
    end
    if staged_class ~= nil and class_r then
      send_class = staged_class
      return
    end
    if staged_bal ~= nil and bal_r then
      send_bal = staged_bal
      if piggyback and staged_class ~= nil and class_r then send_class = staged_class; paired = true end
      return
    end
  end

  -- Selection:
  --   • Wake hint present: prefer that lane (and optionally piggyback ENT onto EQ/BAL)
  --   • If the hinted lane is unavailable by commit time, fall back to normal coalescing
  --   • No hint: coalesce eq > class > bal
  local function choose()
    if wlane == "eq" then
      if staged_eq ~= nil and eq_r then send_eq = staged_eq end
      if piggyback and send_eq and staged_class ~= nil and class_r then send_class = staged_class; paired = true end
    elseif wlane == "bal" then
      if staged_bal ~= nil and bal_r then send_bal = staged_bal end
      if piggyback and send_bal and staged_class ~= nil and class_r then send_class = staged_class; paired = true end
    elseif wlane == "class" then
      if staged_class ~= nil and class_r then send_class = staged_class end
    end

    if send_eq ~= nil or send_bal ~= nil or send_class ~= nil then
      return
    end

    choose_default()
  end

  choose()

-- Optional override: allow emitting EQ+BAL together (NOT recommended).
  if allow and (not paired) and send_class == nil and wlane == "" then
    if staged_eq ~= nil and eq_r then send_eq = staged_eq end
    if staged_bal ~= nil and bal_r then send_bal = staged_bal end
  end

  p.eq = send_eq
  p.bal = send_bal
  p.class = send_class

  local sent_any = (p.free and #p.free > 0) or p.eq or p.bal or p.class
  if not sent_any then return false, nil end

  Q._last_payload = p

  if Yso.trace and type(Yso.trace.push)=="function" then
    local lanes = {}
    if p.free and #p.free > 0 then lanes[#lanes+1] = "free" end
    if p.eq then lanes[#lanes+1] = "eq" end
    if p.bal then lanes[#lanes+1] = "bal" end
    if p.class then lanes[#lanes+1] = "class" end
    Yso.trace.push("emit", { reason = "queue.commit", lanes = table.concat(lanes, ",") })
  end

  local _dry_run = (Yso.net and Yso.net.cfg and Yso.net.cfg.dry_run == true)
  if not _dry_run then
      if Yso and Yso.locks and type(Yso.locks.note_payload)=="function" then
        pcall(Yso.locks.note_payload, p)
      elseif Yso and Yso.locks and type(Yso.locks.note_send)=="function" then
        if p.eq then pcall(Yso.locks.note_send, "eq") end
        if p.bal then pcall(Yso.locks.note_send, "bal") end
        if p.class then pcall(Yso.locks.note_send, "class") end
      end
  end

  Q.emit(p)

  Q._staged.free = {}
  if p.eq ~= nil then Q._staged.eq = nil end
  if p.bal ~= nil then Q._staged.bal = nil end
  if p.class ~= nil then Q._staged.class = nil end

  return true, p
end
-- Convenience wrappers (legacy surface)
function Q.addclear(qtype, body, opts) Q.stage(qtype, body, opts); if Q.cfg.autocommit then Q.commit(opts) end end
function Q.addclearfull(qtype, body, opts) return Q.addclear(qtype, body, opts) end

function Q.replace(qtype, idx, body, opts)
  -- supports replace(qtype, body) or replace(qtype, 1, body)
  if body == nil then body, idx = idx, 1 end
  return Q.stage(qtype, body, opts)
end

function Q.push(cmd, flag, opts)
  flag = flag or "free"
  Q.stage(flag, cmd, opts)
  if Q.cfg.autocommit then Q.commit(opts) end
end

-- Lane helpers used by modules
function Q.free(cmd)       return Q.push(cmd, "free") end
function Q.eq_clear(cmd)   return Q.push(cmd, "eq") end
function Q.bal_clear(cmd)  return Q.push(cmd, "bal") end
function Q.class_clear(cmd) return Q.push(cmd, "class") end

--========================================================--

-- Added by yso_fixup.ps1: clear lane(s) without erroring callers.
-- Updated (2026-02-28): SSOT staged-only clearing (no legacy Q._lanes) + nil semantics.
function Q.clear(lane)
  Q._staged = Q._staged or {}

  if type(lane) == "string" and lane ~= "" then
    lane = lane:lower()
    if lane == "free" then
      Q._staged.free = {}
    else
      Q._staged[lane] = nil
    end
    return true
  end

  -- clear all lanes
  Q._staged.free = {}
  for k in pairs(Q._staged) do
    if k ~= "free" then Q._staged[k] = nil end
  end
  return true
end

