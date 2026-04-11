-- Auto-exported from Mudlet package script: Api stuff
-- DO NOT EDIT IN XML; edit this file instead.

--========================
-- Namespace normalization (Yso/yso bridge)
-- Ensures BOTH _G.Yso and _G.yso exist and point to the same root table.
--========================
do
  local root = rawget(_G, "Yso")
  if type(root) ~= "table" then root = rawget(_G, "yso") end
  if type(root) ~= "table" then root = {} end
  _G.Yso = root
  _G.yso = root
  Yso = root
  yso = root
end

--========================================================--
-- Yso / Achaea Curing Core (Skeleton)
--  • No snd() usage, Achaea-only.
--  • Assumes: Legacy handles serverside CURING PRIORITY, etc.
--  • Assumes: AK1 + AK Tracker track ENEMY afflictions only.
--  • This file just defines the Yso.curing API and debug/status.
--========================================================--
setConsoleBufferSize("main", 300000, 1000)

Yso          = Yso or {}
Yso.affs     = Yso.affs or {}        -- our own afflictions (you can wire GMCP/text later)
Yso.curing   = Yso.curing or {}
Yso.ak       = Yso.ak or {}          -- forward declare so we can reference later if needed
Yso.cfg      = Yso.cfg or {}

-- Boot defaults: Devtools/DRY must be OFF by default each load.
Yso.net = Yso.net or {}
Yso.net.cfg = Yso.net.cfg or {}
Yso.net.cfg.dry_run = false
-- Default command separator (Achaea CONFIG SEPARATOR) for all payload pipelines.
-- User preference: "&&" (override by setting Yso.cfg.pipe_sep before load).
Yso.cfg.pipe_sep = Yso.cfg.pipe_sep or "&&"
Yso.cfg.cmd_sep  = Yso.cfg.cmd_sep  or Yso.cfg.pipe_sep
Yso.cfg.route_gate_live = (Yso.cfg.route_gate_live == true)
Yso.sep      = Yso.sep or Yso.cfg.pipe_sep      -- used for multi-command sends


-- ----------------- tiny helpers (shared) -----------------
Yso.util = Yso.util or {}

function Yso.util.now()
  local v = (type(getEpoch)=="function" and tonumber(getEpoch())) or nil
  if v then
    if v > 1e12 then v = v / 1000 end
    return v
  end
  return os.time()
end

Yso.util.aff_aliases = Yso.util.aff_aliases or {
  prefarar = "sensitivity",
}

function Yso.util.normalize_aff_name(name)
  name = tostring(name or ""):lower()
  if name == "" then return "" end
  local aliases = Yso.util.aff_aliases or {}
  return tostring(aliases[name] or name)
end

function Yso.util.display_aff_name(name)
  return Yso.util.normalize_aff_name(name)
end

function Yso.util.cecho_line(text)
  if type(cecho) ~= "function" then return end
  text = tostring(text or "")
  if text == "" then return end

  local prefix = ""
  if type(getCurrentLine) == "function" then
    local ok, line = pcall(getCurrentLine)
    line = ok and tostring(line or "") or ""
    if line:match("%S") then
      prefix = "\n"
    end
  end

  if not text:match("\n$") then
    text = text .. "\n"
  end
  cecho(prefix .. text)
end

function Yso.util.echo(msg, color)
  local p = (Yso.cfg and Yso.cfg.echo_prefix) or "[Yso] "
  local c = color or "<cyan>"
  if type(Yso.util.cecho_line) == "function" then
    Yso.util.cecho_line(string.format("%s%s%s<reset>", p, c, tostring(msg)))
    return
  end
  if type(cecho) ~= "function" then return end
  cecho(string.format("%s%s%s<reset>\n", p, c, tostring(msg)))
end

-- ----------------- class tracking / segregation -----------------
Yso.classinfo = Yso.classinfo or {}
do
  local C = Yso.classinfo

  local function _trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
  end

  function C.normalize(cls)
    cls = _trim(cls)
    if cls == "" then return "" end
    return cls:sub(1,1):upper() .. cls:sub(2):lower()
  end

  function C.set(cls, src)
    cls = C.normalize(cls)
    if cls == "" then return C.current or Yso.class or "" end
    C.current = cls
    C.last_source = tostring(src or "")
    C.last_update = (Yso.util and Yso.util.now and Yso.util.now()) or os.time()
    Yso.class = cls
    return cls
  end

  function C.get()
    local cls = nil
    local g = rawget(_G, "gmcp")
    if type(g) == "table" and type(g.Char) == "table" then
      if type(g.Char.Status) == "table" and type(g.Char.Status.class) == "string" and g.Char.Status.class ~= "" then
        cls = g.Char.Status.class
      elseif type(g.Char.Vitals) == "table" and type(g.Char.Vitals.class) == "string" and g.Char.Vitals.class ~= "" then
        cls = g.Char.Vitals.class
      end
    end
    cls = C.normalize(cls or C.current or Yso.class or "")
    if cls ~= "" then
      C.current = cls
      Yso.class = cls
    end
    return cls
  end

  function C.is(cls)
    local cur = C.get():lower()
    local want = C.normalize(cls):lower()
    return cur ~= "" and want ~= "" and cur == want
  end

  function C.is_occultist() return C.is("Occultist") end
  function C.is_magi() return C.is("Magi") end

  Yso.is_occultist = Yso.is_occultist or function() return C.is_occultist() end
  Yso.is_magi      = Yso.is_magi      or function() return C.is_magi() end

  local function _sync_from_status(src)
    local g = rawget(_G, "gmcp")
    local cls = g and g.Char and g.Char.Status and g.Char.Status.class or nil
    if (type(cls) ~= "string" or cls == "") and g and g.Char and g.Char.Vitals then
      cls = g.Char.Vitals.class
    end
    if type(cls) == "string" and cls ~= "" then
      C.set(cls, src)
    end
  end

  Yso._eh = Yso._eh or {}
  if Yso._eh.class_status then killAnonymousEventHandler(Yso._eh.class_status) end
  Yso._eh.class_status = registerAnonymousEventHandler("gmcp.Char.Status", function()
    _sync_from_status("gmcp.Char.Status")
  end)

  if Yso._eh.class_vitals then killAnonymousEventHandler(Yso._eh.class_vitals) end
  Yso._eh.class_vitals = registerAnonymousEventHandler("gmcp.Char.Vitals", function()
    _sync_from_status("gmcp.Char.Vitals")
  end)

  Yso._trig = Yso._trig or {}
  if Yso._trig.class_swap then killTrigger(Yso._trig.class_swap) end
  Yso._trig.class_swap = tempRegexTrigger(
    [[^You are now a member of the (\w+) class\.$]],
    function()
      if not matches or not matches[2] then return end
      C.set(matches[2], "class_swap")
    end
  )

  C.get()
end

-- Single-tick scheduler guard (shared key across disk/mpackage)
Yso.util._tick_once_last = Yso.util._tick_once_last or {}
function Yso.util.tick_once(key, min_dt, fn, ...)
  key = tostring(key or "")
  if key == "" or type(fn) ~= "function" then return false, "badargs" end
  min_dt = tonumber(min_dt) or 0
  local now = Yso.util.now()
  local last = tonumber(Yso.util._tick_once_last[key] or 0) or 0
  if min_dt > 0 and (now - last) < min_dt then
    return false, "throttled"
  end
  Yso.util._tick_once_last[key] = now
  local ok, res = pcall(fn, ...)
  if not ok then
    Yso.util.echo("tick_once ERR: "..tostring(res), "<red>")
    return false, res
  end
  return true, res
end


-- ----------------- minimal locks (pending/backoff/cooldown hints) -----------------
-- NOTE: This is SSOT for lane readiness stability under GMCP lag.
Yso.locks = Yso.locks or {}
do
  local L = Yso.locks
  if L._yso_fulllocks ~= true and L._yso_minlocks ~= true then
    L._yso_minlocks = true
    L.cfg = L.cfg or { pending = 0.35 }
    L._lane = L._lane or {
      eq    = { pending_until = 0 },
      bal   = { pending_until = 0 },
      class = { pending_until = 0, backoff_until = 0 },
    }
    L._vitals = L._vitals or { eq = nil, bal = nil }

    local function _now() return (Yso.util and Yso.util.now and Yso.util.now()) or os.time() end

    function L.note_send(lane, pending)
      lane = tostring(lane or ""):lower()
      if lane == "ent" or lane == "entity" then lane = "class" end
      local st = L._lane[lane]; if not st then return end
      pending = tonumber(pending) or tonumber(L.cfg.pending) or 0.35
      st.pending_until = math.max(tonumber(st.pending_until or 0) or 0, _now() + pending)
    end

    function L.ent_backoff(seconds, src)
      seconds = tonumber(seconds) or 1.0
      if seconds <= 0 then seconds = 0.5 end
      local st = L._lane.class
      st.backoff_until = math.max(tonumber(st.backoff_until or 0) or 0, _now() + seconds)
      if Yso.state and type(Yso.state.set_ent_ready)=="function" then
        pcall(Yso.state.set_ent_ready, false, src or "locks.ent_backoff")
      end
    end

    function L.sync_vitals(v)
      v = v or (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
      local eq = tostring(v.eq or v.equilibrium or "") == "1" or (v.eq == true or v.equilibrium == true)
      local bal = tostring(v.bal or v.balance or "") == "1" or (v.bal == true or v.balance == true)
      if eq and L._vitals.eq == false and L._lane.eq then L._lane.eq.pending_until = 0 end
      if bal and L._vitals.bal == false and L._lane.bal then L._lane.bal.pending_until = 0 end
      L._vitals.eq, L._vitals.bal = eq, bal
    end

    function L.note_payload(payload)
      if type(payload) ~= "table" then return end
      if payload.eq then L.note_send("eq") end
      if payload.bal then L.note_send("bal") end
      if payload.class or payload.ent or payload.entity then
        L.note_send("class")
        if Yso.state and type(Yso.state.set_ent_ready)=="function" then
          pcall(Yso.state.set_ent_ready, false, "locks:payload")
        end
      end
      -- Hooks: allow offense modules / entity framework to latch on actual sends.
      local ER = (Yso and Yso.off and Yso.off.oc and Yso.off.oc.entity_registry) or nil
      if ER and type(ER.note_payload_sent) == "function" then
        pcall(ER.note_payload_sent, payload)
      end
      local GD = (Yso and Yso.off and Yso.off.oc and (Yso.off.oc.group_damage or Yso.off.oc.dmg)) or nil
      if GD and type(GD.on_payload_sent) == "function" then
        pcall(GD.on_payload_sent, payload)
      end
      local PA = (Yso and Yso.off and Yso.off.oc and Yso.off.oc.party_aff) or nil
      if PA and type(PA.on_payload_sent) == "function" then
        pcall(PA.on_payload_sent, payload)
      end
      local OA = (Yso and Yso.off and Yso.off.oc and (Yso.off.oc.occ_aff or Yso.off.oc.aff)) or nil
      if OA and type(OA.on_payload_sent) == "function" then
        pcall(OA.on_payload_sent, payload)
      end
      local MGD = (Yso and Yso.off and Yso.off.magi and (Yso.off.magi.group_damage or Yso.off.magi.dmg)) or nil
      if MGD and type(MGD.on_payload_sent) == "function" then
        pcall(MGD.on_payload_sent, payload)
      end
      local MF = (Yso and Yso.off and Yso.off.magi and Yso.off.magi.focus) or nil
      if MF and type(MF.on_payload_sent) == "function" then
        pcall(MF.on_payload_sent, payload)
      end

    end

    function L.ready(lane)
      lane = tostring(lane or ""):lower()
      if lane == "ent" or lane == "entity" then lane = "class" end
      local st = L._lane[lane]
      local now = _now()
      if st and tonumber(st.pending_until or 0) > now then return false end
      if lane == "eq" then
        local v = nil

        if Yso.state and type(Yso.state.eq_ready)=="function" then

          local ok, r = pcall(Yso.state.eq_ready)

          if ok and r ~= nil then v = (r == true) end

        end

        if v ~= nil then return v end

        return true
      elseif lane == "bal" then
        local v = nil

        if Yso.state and type(Yso.state.bal_ready)=="function" then

          local ok, r = pcall(Yso.state.bal_ready)

          if ok and r ~= nil then v = (r == true) end

        end

        if v ~= nil then return v end

        return true
      elseif lane == "class" then
        if st and tonumber(st.backoff_until or 0) > now then return false end
        local v = nil

        if Yso.state and type(Yso.state.ent_ready)=="function" then

          local ok, r = pcall(Yso.state.ent_ready)

          if ok and r ~= nil then v = (r == true) end

        end

        if v ~= nil then return v end

        return true
      end
      return true
    end

    function L.eq_ready() return L.ready("eq") end
    function L.bal_ready() return L.ready("bal") end
    function L.ent_ready() return L.ready("class") end
  end
end

-- ----------------- trace ring (introspection) -----------------
Yso.trace = Yso.trace or {}
do
  local T = Yso.trace
  T.max = tonumber(T.max or 200) or 200
  if T.max < 1 then T.max = 1 end
  T.buf = T.buf or {}
  T.idx = tonumber(T.idx or 0) or 0

  local function _push(entry)
    if type(entry) ~= "table" then entry = { msg = tostring(entry) } end
    entry.ts = entry.ts or (Yso.util and Yso.util.now and Yso.util.now()) or os.time()
    T.idx = (T.idx % T.max) + 1
    T.buf[T.idx] = entry
  end

  function T.push(kind, entry)
    entry = entry or {}
    entry.kind = kind or entry.kind or "log"
    _push(entry)
  end

  function T.dump(n)
    n = tonumber(n) or T.max
    if n <= 0 then return {} end
    local out = {}
    local count = math.min(n, #T.buf, T.max)
    local start = T.idx - count + 1
    for i = 0, count-1 do
      local j = start + i
      if j <= 0 then j = j + T.max end
      out[#out+1] = T.buf[j]
    end
    return out
  end

  function T.echo(n)
    local rows = T.dump(n)
    if type(cecho) ~= "function" then return rows end
    cecho("<dim_grey>[Yso.trace] last "..tostring(#rows).."\n")
    for i=1,#rows do
      local e = rows[i] or {}
      local ts = tostring(e.ts or "")
      local k  = tostring(e.kind or "")
      local r  = tostring(e.reason or e.src or e.msg or "")
      cecho(string.format("<dim_grey>  %s %-6s %s\n", ts, k, r))
    end
    return rows
  end
end




-- ----------------- global payload mode -----------------
Yso.cfg = Yso.cfg or {}
-- Single-payload policy: Occultist offense uses ONLY as_available.
Yso.cfg.payload_mode = "as_available"

function Yso.get_payload_mode()
  return "as_available"
end

function Yso.set_payload_mode(mode, quiet)
  -- Ignore requested mode and enforce as_available.
  Yso.cfg = Yso.cfg or {}
  Yso.cfg.payload_mode = "as_available"

  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    Yso.pulse.wake("payload_mode")
  end
  return true
end

-- ----------------- unified emitter (RAW, lane-aware) -----------------
Yso.lanes = Yso.lanes or {}
function Yso.lanes.normalize(lane)
  lane = tostring(lane or ""):lower()
  if lane == "ent" or lane == "entity" then return "class" end
  if lane == "pre" then return "free" end
  return lane
end

-- ----------------- automation pause (offense gating) -----------------
-- Used to halt offense automation (EQ/BAL/ENTITY lane payloads) when the
-- target is not actionable (e.g., leapt to the out).
Yso.pause = Yso.pause or {}
Yso.pause.offense = Yso.pause.offense or { active = false, reason = "", at = 0 }

function Yso.offense_paused()
  return (Yso.pause and Yso.pause.offense and Yso.pause.offense.active == true) or false
end

function Yso.pause_offense(on, reason, quiet)
  local P = Yso.pause.offense
  on = (on == true)

  if on then
    P.active = true
    P.reason = tostring(reason or P.reason or "paused")
    P.at = (Yso.util and type(Yso.util.now) == "function" and Yso.util.now()) or os.time()
  else
    P.active = false
    P.reason = ""
    P.at = 0
  end

  -- Hard stop: clear any staged payloads immediately when pausing.
  if on and Yso.queue and type(Yso.queue.clear) == "function" then
    pcall(Yso.queue.clear)
  end

  if not quiet and type(cecho) == "function" then
    if on then
      cecho(string.format("<orange>[Yso] Offense PAUSED<reset> (%s)\n", tostring(P.reason)))
    else
      cecho("<orange>[Yso] Offense RESUMED<reset>\n")
    end
  end

  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    pcall(Yso.pulse.wake, "offense_pause")
  end

  return true
end

-- ----------------- manual inhibit (400ms window) -----------------
-- Blocks offense automation from committing when the player sends a
-- manual offense command (alias or keyword-detected send).
Yso.inhibit = Yso.inhibit or {}
Yso.inhibit.cfg = Yso.inhibit.cfg or { duration_ms = 400, debug = false }
Yso.inhibit._until = Yso.inhibit._until or 0

function Yso.inhibit.set(reason)
  local now_ms
  if type(getEpoch) == "function" then
    now_ms = getEpoch()
    if now_ms < 1e10 then now_ms = now_ms * 1000 end
  else
    now_ms = os.time() * 1000
  end
  Yso.inhibit._until = now_ms + (tonumber(Yso.inhibit.cfg.duration_ms) or 400)
  if Yso.inhibit.cfg.debug and type(cecho) == "function" then
    cecho(string.format("<dim_grey>[inhibit] set (%s) for %dms\n", tostring(reason or "?"), Yso.inhibit.cfg.duration_ms))
  end
end

function Yso.inhibit.active()
  local now_ms
  if type(getEpoch) == "function" then
    now_ms = getEpoch()
    if now_ms < 1e10 then now_ms = now_ms * 1000 end
  else
    now_ms = os.time() * 1000
  end
  return now_ms < (tonumber(Yso.inhibit._until) or 0)
end

-- Offense keyword patterns for detecting manual commands in send().
local _OFFENSE_KW = {
  "^%s*instill%s",    "^%s*bodywarp%s",   "^%s*shrivel%s",
  "^%s*enervate%s",   "^%s*cleanseaura%s","^%s*pinchaura%s",
  "command%s+%w+%s+at%s", "fling%s+%w+%s+at%s",
}

function Yso.inhibit.check_cmd(cmd)
  if type(cmd) ~= "string" or cmd == "" then return false end
  local lc = cmd:lower()
  for _, pat in ipairs(_OFFENSE_KW) do
    if lc:find(pat) then
      Yso.inhibit.set("manual_cmd")
      return true
    end
  end
  return false
end

local function _has(v)
  if v == nil then return false end
  if type(v) == "string" then
    v = v:gsub("^%s+",""):gsub("%s+$","")
    return v ~= ""
  elseif type(v) == "table" then
    return v[1] ~= nil
  end
  return false
end

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function Yso.emit(payload, opts)
  opts = opts or {}
  if type(payload) == "table" and _trim(opts.target or "") == "" then
    local tgt = _trim(payload.target)
    if tgt ~= "" then opts.target = tgt end
  end

  -- Offense pause gate: when active, block offense automation emission unless forced.
  if type(Yso.offense_paused) == "function" and Yso.offense_paused() and opts.force ~= true then
    local kind = tostring(opts.kind or ""):lower()
    local reason = tostring(opts.reason or opts.src or ""):lower()

    -- Allow cure/defense/utility emits to proceed even during an offense pause.
    local allow_non_offense =
      (kind == "cure") or (kind == "defense") or (kind == "utility")
      or reason:find("cure", 1, true)
      or reason:find("heal", 1, true)
      or reason:find("def", 1, true)

    if not allow_non_offense then
      local has_lane = false
      if type(payload) == "table" then
        if payload.eq ~= nil or payload.bal ~= nil or payload.class ~= nil or payload.ent ~= nil or payload.entity ~= nil then
          has_lane = true
        end
      end

      local is_offense =
        (kind == "offense")
        or reason:find("offense", 1, true)
        or reason:find("group_damage", 1, true)
        or reason:find("gd:", 1, true)
        or reason:find("occ", 1, true)
        or reason:find("shieldbreak", 1, true)
        or reason:find("limb", 1, true)

      if is_offense or has_lane then
        return false
      end
    end
  end

  local Q = (Yso and Yso.queue)
  if not (Q and type(Q.stage)=="function" and type(Q.commit)=="function") then
    if Q and type(Q.emit)=="function" then
      return Q.emit(payload)
    end
    return false
  end

  if opts.solo == true and type(Q.clear)=="function" then
    Q.clear()
  end

  -- Decide whether to commit immediately or stage-only (for orchestrated offense).
  local function _in_combat_party()
    if Yso and Yso.mode then
      if type(Yso.mode.is_combat) == "function" and Yso.mode.is_combat() then return true end
      if type(Yso.mode.is_party) == "function" and Yso.mode.is_party() then return true end
    end
    return false
  end

  local function _is_lane_payload(p)
    if type(p) ~= "table" then return false end
    return (p.eq ~= nil) or (p.bal ~= nil) or (p.class ~= nil) or (p.ent ~= nil) or (p.entity ~= nil) or (p.free ~= nil) or (p.pre ~= nil)
  end

  local function _offenseish()
    local kind = tostring(opts.kind or ""):lower()
    local reason = tostring(opts.reason or opts.src or ""):lower()
    if kind == "offense" then return true end
    return reason:find("offense", 1, true)
        or reason:find("group_damage", 1, true)
        or reason:find("gd:", 1, true)
        or reason:find("occ", 1, true)
        or reason:find("shieldbreak", 1, true)
        or reason:find("kelp", 1, true)
        or reason:find("unravel", 1, true)
        or reason:find("warp", 1, true)
  end

  local function _should_commit(p)
    if opts.commit == true or opts.force_commit == true then return true end
    if opts.commit == false then return false end
    if opts.force == true then return true end
    -- In combat/party, lane-table offense emits are staged so the route loop or
    -- wake bus can flush them on the next viable reopen.
    if _in_combat_party() and _is_lane_payload(p) and _offenseish() then return false end
    return true
  end

  local do_commit = _should_commit(payload)

  -- --- stage payload ---
  if type(payload) == "string" then
    if Yso.trace and type(Yso.trace.push)=="function" then
      Yso.trace.push("emit", { reason = opts.reason or opts.src or "raw", lanes = "raw" })
    end
    Q.stage("free", payload, opts)
  elseif type(payload) == "table" and payload[1] ~= nil and payload.free == nil and payload.pre == nil and payload.eq == nil and payload.bal == nil and payload.class == nil and payload.ent == nil and payload.entity == nil then
    Q.stage("free", payload, opts)
  elseif type(payload) == "table" then
    if payload.free ~= nil then Q.stage("free", payload.free, opts) elseif payload.pre ~= nil then Q.stage("free", payload.pre, opts) end
    if payload.eq ~= nil then Q.stage("eq", payload.eq, opts) end
    if payload.bal ~= nil then Q.stage("bal", payload.bal, opts) end
    local cls = payload.class or payload.ent or payload.entity
    if cls ~= nil then Q.stage("class", cls, opts) end

    if Yso.trace and type(Yso.trace.push)=="function" then
      local lanes = {}
      if _has(payload.free) or _has(payload.pre) then lanes[#lanes+1] = "free" end
      if _has(payload.eq) then lanes[#lanes+1] = "eq" end
      if _has(payload.bal) then lanes[#lanes+1] = "bal" end
      if _has(cls) then lanes[#lanes+1] = "class" end
      Yso.trace.push("emit", { reason = opts.reason or opts.src, lanes = table.concat(lanes, ",") })
    end
  else
    return false
  end

  -- --- commit or stage-only ---
  if do_commit then
    local ok = Q.commit(opts)
    if ok and Yso.pulse and Yso.pulse.state and Yso.pulse.state._in_flush then
      Yso.pulse.state._did_emit = true
    end
    if ok then
      if Q then Q._commit_hint = nil end
      return true
    end

    -- If a lane spend could not commit yet, keep the staged payload alive and
    -- hand it back to the wake bus so it flushes on the next viable reopen.
    if _is_lane_payload(payload) and Yso.pulse and type(Yso.pulse.wake) == "function" then
      Q._commit_hint = opts
      if not (Yso.pulse.state and Yso.pulse.state._in_flush) then
        pcall(Yso.pulse.wake, "emit:staged")
      end
      return true
    end

    if Q then Q._commit_hint = nil end
    return false
  end

  -- Stage-only: preserve commit hint (wake_lane, allow_eqbal, etc) for the next flush.
  Q._commit_hint = opts
  if Yso.pulse and type(Yso.pulse.wake) == "function" and not (Yso.pulse.state and Yso.pulse.state._in_flush) then
    pcall(Yso.pulse.wake, "emit:staged")
  end
  return true
end

-- Manual/emergency helper: force an immediate commit attempt (bypasses offense pause gating).
function Yso.emit_now(payload, opts)
  opts = opts or {}
  opts.force = true
  opts.commit = true
  opts.reason = opts.reason or opts.src or "emit_now"
  return Yso.emit(payload, opts)
end


-- ----------------- tiny helpers (CURING) -----------------
local function _cure_echo(msg)
  if Yso and Yso.curing and Yso.curing.debug then
    cecho(string.format("<cyan>[Yso:Cure] <reset>%s\n", msg))
  end
end

local function _cure_warn(msg)
  cecho(string.format("<yellow>[Yso:Cure] <reset>%s\n", msg))
end

local function _cure_err(msg)
  cecho(string.format("<red>[Yso:Cure:ERR] <reset>%s\n", msg))
end

local function _send(cmd)
  if not cmd or cmd == "" then return end
  if type(send) == "function" then
    send(cmd, false)
  else
    _cure_err("send() not available to send: "..cmd)
  end
end


-- ----------------- config / adapters -----------------

-- Mode: "serverside" (default) or "manual"
Yso.curing.mode  = Yso.curing.mode or "serverside"
Yso.curing.debug = Yso.curing.debug or false

-- Adapters are where you wire to Legacy + game commands.
-- Override these in a separate file if you like.
Yso.curing.adapters = Yso.curing.adapters or {

  -- Toggle game-side CURING ON/OFF if you desire.
  game_curing_on = function()
    -- example:
    -- _send("CURING ON")
    _cure_echo("game_curing_on() called (adapter not yet wired)")
  end,

  game_curing_off = function()
    -- example:
    -- _send("CURING OFF")
    _cure_echo("game_curing_off() called (adapter not yet wired)")
  end,

  -- Legacy prio helpers: wire these to your real Legacy aliases/commands.
  raise_aff = function(aff)
    -- ex: _send(string.format("LEGACY PRIOUP %s", aff))
    _cure_echo(string.format("raise_aff(%s) called (adapter not yet wired)", tostring(aff)))
  end,

  lower_aff = function(aff)
    -- ex: _send(string.format("LEGACY PRIODOWN %s", aff))
    _cure_echo(string.format("lower_aff(%s) called (adapter not yet wired)", tostring(aff)))
  end,

  set_aff_prio = function(aff, prio)
    -- ex: _send(string.format("CURING PRIORITY %s %d", aff, prio))
    _cure_echo(string.format("set_aff_prio(%s, %s) called (adapter not yet wired)", tostring(aff), tostring(prio)))
  end,

  use_profile = function(name)
    -- ex: _send(string.format("LEGACY PROFILE %s", name))
    _cure_echo(string.format("use_profile(%s) called (adapter not yet wired)", tostring(name)))
  end,

  -- Optional “emergency” hooks, to be implemented as you decide.
  emergency = function(tag)
    -- ex: if tag == "lockpanic" then _send("LEGACY LOCKPANIC") end
    _cure_echo(string.format("emergency(%s) called (adapter not yet wired)", tostring(tag)))
  end,

  -- Optional tree policy hook for serverside_policy.lua.
  set_tree_policy = function(mode, ctx)
    _cure_echo(string.format(
      "set_tree_policy(%s) called (adapter not yet wired)",
      tostring(mode)
    ))
  end,

  -- Optional emergency queue hook for serverside_policy.lua.
  queue_emergency = function(cmd, opts)
    _cure_echo(string.format(
      "queue_emergency(%s) called (adapter not yet wired)",
      tostring(cmd)
    ))
    return false
  end,
}

-- shortcut
local C = Yso.curing.adapters

-- ----------------- public API: mode & toggles -----------------

function Yso.curing.set_mode(mode)
  mode = tostring(mode or ""):lower()
  if mode ~= "serverside" and mode ~= "manual" then
    _cure_warn("Invalid mode '"..mode.."'. Use 'serverside' or 'manual'.")
    return
  end
  Yso.curing.mode = mode
  _cure_echo("Mode set to "..mode)
end

function Yso.curing.toggle()
  if Yso.curing.mode == "serverside" then
    Yso.curing.set_mode("manual")
  else
    Yso.curing.set_mode("serverside")
  end
end

function Yso.curing.toggle_debug()
  Yso.curing.debug = not Yso.curing.debug
  _cure_echo("Debug is now "..(Yso.curing.debug and "ON" or "OFF"))
end

-- Optional helpers for explicit CURING ON/OFF via game.
function Yso.curing.game_curing_on()
  C.game_curing_on()
end

function Yso.curing.game_curing_off()
  C.game_curing_off()
end

-- ----------------- public API: priority & profiles -----------------

-- High-level wrappers: these are what offense/logic code should call.

function Yso.curing.raise_aff(aff)
  if not aff or aff == "" then return end
  C.raise_aff(aff)
end

function Yso.curing.lower_aff(aff)
  if not aff or aff == "" then return end
  C.lower_aff(aff)
end

function Yso.curing.set_aff_prio(aff, prio)
  if not aff or aff == "" then return end
  prio = tonumber(prio)
  if not prio then
    _cure_warn("set_aff_prio("..tostring(aff)..", ?) called with invalid priority")
    return
  end
  C.set_aff_prio(aff, prio)
end

function Yso.curing.use_profile(name)
  if not name or name == "" then return end
  C.use_profile(name)
end

-- Emergency entry point. “tag” is free-form, e.g. "lockpanic", "damagepanic".
function Yso.curing.emergency(tag)
  if not tag or tag == "" then return end
  C.emergency(tag)
end

-- ----------------- status & diagnostics -----------------

local function _curing_on_off()
  -- stub; if you later parse game CURING status, return "ON"/"OFF" here.
  return "unknown"
end

local function _legacy_profile()
  -- stub; if Legacy exposes current profile, return it here.
  return "unknown"
end

function Yso.curing.status()
  cecho("<green>[Yso:Cure Status]\n")
  cecho(string.format("  Mode:         <white>%s\n", Yso.curing.mode))
  cecho(string.format("  Debug:        <white>%s\n", Yso.curing.debug and "ON" or "OFF"))
  cecho(string.format("  Game CURING:  <white>%s\n", _curing_on_off()))
  cecho(string.format("  Legacy set:   <white>%s\n", _legacy_profile()))
  -- If you expose AK Tracker state, you can echo it here:
  -- cecho(string.format("  AK Tracker:   <white>%s\n", Yso.ak and Yso.ak.ready and "READY" or "n/a"))
end

-- ----------------- init helper -----------------

function Yso.curing.init()
  _cure_echo("Yso.curing core skeleton initialised.")
  -- If needed, you can call this once from your startup scripts.
end

-- Auto-init on load (if you prefer passive behaviour)
Yso.curing.init()

--========================================================--
-- End of Yso / Achaea Curing Core (Skeleton)
--========================================================--


--========================================================--
-- Yso / Achaea AK Wrapper (Enemy Aff Tracker Skeleton)
--  • Wraps AK1 / AK Tracker under Yso.ak namespace.
--  • Does NOT replace AK – it just mirrors/normalizes it.
--  • Other code should ONLY talk to Yso.ak, never raw AK.
--========================================================--

Yso.ak         = Yso.ak or {}
Yso.ak.enemy   = Yso.ak.enemy or {
  name      = "",        -- current tracked enemy (string)
  affs      = {},        -- [aff_name] = true
  last_gain = {},        -- [aff_name] = timestamp
  last_cure = {},        -- [aff_name] = timestamp
}
Yso.ak.debug     = Yso.ak.debug or false
Yso.ak.threshold = Yso.ak.threshold or 100   -- used later for embellished status / bridge

-- ----------------- tiny helpers (AK) -----------------
local function _ak_now()
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _ak_echo(msg)
  if Yso.ak.debug then
    cecho(string.format("<magenta>[Yso:AK] <reset>%s\n", msg))
  end
end

local function _ak_warn(msg)
  cecho(string.format("<yellow>[Yso:AK] <reset>%s\n", msg))
end

local function _ak_trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  -- Strip Mudlet auto-complete tags like " (player)" / " (npc)" at end
  s = s:gsub("%s*%b()%s*$", "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  -- Player names are single-token; if junk remains, keep first token
  s = s:match("^(%S+)") or s
  return s
end

-- ----------------- adapters (to AK Tracker) -----------------
-- You wire these to your real AK Tracker implementation.
-- For example: pull AK's aff table, or hook AK's callbacks into gain/cure.
Yso.ak.adapters = Yso.ak.adapters or {

  -- Return a table of current enemy affs from AK:
  --   { paralysis = true, asthma = true, ... }
  pull_full_state = function()
    -- Example (pseudocode, replace with real AK access):
    -- return table.copy(AK.enemy.affs)
    _ak_echo("adapters.pull_full_state() called (not wired)")
    return nil
  end,

  -- Optional: let AK know when we change target.
  on_target_change = function(name)
    -- Example:
    -- AK.setTarget(name)
    _ak_echo(string.format("adapters.on_target_change(%s) called (not wired)", tostring(name)))
  end,
}

local AK = Yso.ak.adapters

-- ----------------- core state API -----------------

function Yso.ak.set_target(name, opts)
  name = _ak_trim(name)
  if name == "" then
    _ak_warn("set_target() called with empty name; keeping current enemy.")
    return
  end

  opts = opts or {}
  local reset = opts.reset ~= false  -- default true

  if Yso.ak.enemy.name ~= name and reset then
    Yso.ak.enemy.affs      = {}
    Yso.ak.enemy.last_gain = {}
    Yso.ak.enemy.last_cure = {}
    _ak_echo("Target changed; enemy affs reset.")
  end

  Yso.ak.enemy.name = name
  _ak_echo("Tracking enemy: "..name)

  -- Notify AK if desired.
  AK.on_target_change(name)
end

-- Called by your AK Tracker when it believes enemy gains an aff.
-- You can hook this in directly from AK1/Tracker logic.
function Yso.ak.gain(aff, meta)
  if not aff or aff == "" then return end
  aff = tostring(aff):lower()

  Yso.ak.enemy.affs[aff]      = true
  Yso.ak.enemy.last_gain[aff] = _ak_now()

  if meta and meta.source then
    _ak_echo(string.format("GAIN %s (%s)", aff, meta.source))
  else
    _ak_echo("GAIN "..aff)
  end
end

-- Called by your AK Tracker when it believes enemy cures an aff.
function Yso.ak.cure(aff, meta)
  if not aff or aff == "" then return end
  aff = tostring(aff):lower()

  if Yso.ak.enemy.affs[aff] then
    Yso.ak.enemy.affs[aff]      = nil
    Yso.ak.enemy.last_cure[aff] = _ak_now()

    if meta and meta.source then
      _ak_echo(string.format("CURE %s (%s)", aff, meta.source))
    else
      _ak_echo("CURE "..aff)
    end
  end
end

-- Full sync from AK Tracker (e.g. on target swap, or periodic recalc)
function Yso.ak.sync_from_ak()
  local state = AK.pull_full_state()
  if not state or type(state) ~= "table" then
    _ak_warn("sync_from_ak(): adapter returned no state.")
    return
  end

  Yso.ak.enemy.affs = {}
  for aff, present in pairs(state) do
    if present then
      aff = tostring(aff):lower()
      Yso.ak.enemy.affs[aff]      = true
      Yso.ak.enemy.last_gain[aff] = Yso.ak.enemy.last_gain[aff] or _ak_now()
    end
  end

  _ak_echo("Enemy affs synced from AK.")
end

-- ----------------- query helpers -----------------

-- Basic “does enemy have X?”
function Yso.ak.has(aff)
  if not aff or aff == "" then return false end
  aff = tostring(aff):lower()
  return Yso.ak.enemy.affs[aff] and true or false
end

-- Count how many of a list enemy has.
-- affs can be { "asthma", "paralysis" } or "asthma/paralysis/...".
function Yso.ak.count(affs)
  if not affs then return 0 end
  local list = {}

  if type(affs) == "string" then
    for part in affs:gmatch("([^/]+)") do
      list[#list+1] = part:lower()
    end
  elseif type(affs) == "table" then
    for _,a in ipairs(affs) do list[#list+1] = tostring(a):lower() end
  else
    return 0
  end

  local n = 0
  for _,a in ipairs(list) do
    if Yso.ak.enemy.affs[a] then n = n + 1 end
  end
  return n
end

-- “Does enemy have at least N of these affs?”
function Yso.ak.any(affs, n)
  n = tonumber(n) or 1
  if n <= 0 then return true end
  return Yso.ak.count(affs) >= n
end

-- Returns a sorted list of current aff names.
function Yso.ak.list_affs()
  local out = {}
  for a,_ in pairs(Yso.ak.enemy.affs) do
    out[#out+1] = a
  end
  table.sort(out)
  return out
end

-- ----------------- status / debug (embellished) -----------------

function Yso.ak.status()
  Yso.ak.enemy = Yso.ak.enemy or { name = "", affs = {} }
  local target = Yso.ak.enemy.name or ""
  if target == "" then target = "(none)" end

  local list      = Yso.ak.list_affs()
  local total     = #list
  local max_show  = 10
  local threshold = Yso.ak.threshold or 100

  cecho("<magenta>[Yso:AK Status]\n")
  cecho(string.format("  Target:     <white>%s\n", target))
  cecho(string.format("  Debug:      <white>%s\n", Yso.ak.debug and "ON" or "OFF"))
  cecho(string.format("  Threshold:  <white>%d\n", threshold))
  cecho(string.format("  AK affs:    <white>%d\n", total))

  if total == 0 then
    cecho("  Affs list:  <white>none\n")
  else
    local shown = {}
    for i = 1, math.min(total, max_show) do
      shown[#shown+1] = list[i]
    end
    local extra = total - #shown

    if extra > 0 then
      cecho(string.format(
        "  Affs list:  <white>%s<reset> <gray>(+%d more)\n",
        table.concat(shown, ", "),
        extra
      ))
    else
      cecho("  Affs list:  <white>"..table.concat(shown, ", ").."\n")
    end
  end
end

function Yso.ak.toggle_debug()
  Yso.ak.debug = not Yso.ak.debug
  _ak_echo("Debug is now "..(Yso.ak.debug and "ON" or "OFF"))
end

-- ----------------- init -----------------

function Yso.ak.init()
  _ak_echo("Yso.ak core skeleton initialised.")
end

Yso.ak.init()

--========================================================--
-- End of Yso / Achaea AK Wrapper (Skeleton)
--========================================================--


--========================================================--
-- Self-aff helpers (used by offense + queue guards)
--========================================================--

Yso = Yso or {}
Yso.self = Yso.self or {}

local function _selfaff_module()
  if Yso and Yso.selfaff and type(Yso.selfaff) == "table" then
    return Yso.selfaff
  end
  if type(require) == "function" then
    local ok = pcall(require, "Yso.Core.self_aff")
    if ok and Yso and type(Yso.selfaff) == "table" then
      return Yso.selfaff
    end
  end
  return nil
end

local function _gmcp_aff_has(key)
  local g = gmcp and gmcp.Char and gmcp.Char.Afflictions
  if type(g) ~= "table" then return false end
  local candidates = { g.list, g.List, g.afflictions, g.Afflictions }
  for _, lst in ipairs(candidates) do
    if type(lst) == "table" then
      for _, v in ipairs(lst) do
        if type(v) == "string" and v:lower() == key then return true end
        if type(v) == "table" and tostring(v.name or ""):lower() == key then return true end
      end
    end
  end
  if g[key] == true then return true end
  return false
end

function Yso.self.has_aff(aff)
  local SA = _selfaff_module()
  if SA and type(SA.has_aff) == "function" then
    local ok, v = pcall(SA.has_aff, aff)
    if ok then return v == true end
  end
  local key = tostring(aff or ""):lower()
  if key == "" then return false end
  return _gmcp_aff_has(key)
end

function Yso.self.any_aff(list)
  local SA = _selfaff_module()
  if SA and type(SA.any_aff) == "function" then
    local ok, v = pcall(SA.any_aff, list)
    if ok then return v == true end
  end
  if type(list) ~= "table" then return false end
  for i = 1, #list do
    if Yso.self.has_aff(list[i]) then return true end
  end
  return false
end

function Yso.self.aff_count(arg)
  local SA = _selfaff_module()
  if SA and type(SA.aff_count) == "function" then
    local ok, v = pcall(SA.aff_count, arg)
    if ok and type(v) == "number" then return v end
  end
  if type(arg) == "table" then
    local n = 0
    for i = 1, #arg do
      if Yso.self.has_aff(arg[i]) then n = n + 1 end
    end
    return n
  end
  return 0
end

function Yso.self.list_affs()
  local SA = _selfaff_module()
  if SA and type(SA.list_affs) == "function" then
    local ok, v = pcall(SA.list_affs)
    if ok and type(v) == "table" then return v end
  end
  return {}
end

function Yso.self.gain(name, source)
  local SA = _selfaff_module()
  if SA and type(SA.gain) == "function" then
    local ok, v = pcall(SA.gain, name, source or "manual")
    if ok then return v == true end
  end
  return false
end

function Yso.self.cure(name, source)
  local SA = _selfaff_module()
  if SA and type(SA.cure) == "function" then
    local ok, v = pcall(SA.cure, name, source or "manual")
    if ok then return v == true end
  end
  return false
end

function Yso.self.sync_full(list, source)
  local SA = _selfaff_module()
  if SA and type(SA.sync_full) == "function" then
    local ok, v = pcall(SA.sync_full, list, source or "manual")
    if ok then return v == true end
  end
  return false
end

function Yso.self.reset(source)
  local SA = _selfaff_module()
  if SA and type(SA.reset) == "function" then
    local ok, v = pcall(SA.reset, source or "manual")
    if ok then return v == true end
  end
  return false
end

function Yso.self.is_prone()
  local SA = _selfaff_module()
  if SA and type(SA.is_prone) == "function" then
    local ok, v = pcall(SA.is_prone)
    if ok then return v == true end
  end
  return Yso.self.has_aff("prone")
end

function Yso.self.is_asleep()
  local SA = _selfaff_module()
  if SA and type(SA.is_asleep) == "function" then
    local ok, v = pcall(SA.is_asleep)
    if ok then return v == true end
  end
  return Yso.self.has_aff("sleep")
end

function Yso.self.is_blackout()
  local SA = _selfaff_module()
  if SA and type(SA.is_blackout) == "function" then
    local ok, v = pcall(SA.is_blackout)
    if ok then return v == true end
  end
  return Yso.self.has_aff("blackout")
end

function Yso.self.is_writhed()
  local SA = _selfaff_module()
  if SA and type(SA.is_writhed) == "function" then
    local ok, v = pcall(SA.is_writhed)
    if ok then return v == true end
  end
  return Yso.self.any_aff({ "webbed", "entangled", "transfixed", "bound", "impaled" })
end

function Yso.self.bleeding()
  local SA = _selfaff_module()
  if SA and type(SA.bleeding) == "function" then
    local ok, v = pcall(SA.bleeding)
    if ok and type(v) == "number" then return v end
  end
  local v = gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.bleeding
  return tonumber(v) or 0
end

function Yso.self.is_standing()
  local SA = _selfaff_module()
  if SA and type(SA.is_standing) == "function" then
    local ok, v = pcall(SA.is_standing)
    if ok then return v == true end
  end
  return (not Yso.self.is_prone()) and (not Yso.self.is_asleep())
end

function Yso.self.is_paralyzed()
  return Yso.self.has_aff("paralysis")
end

-- Try to warm-load new curing subsystems for live sessions.
if type(require) == "function" then
  pcall(require, "Yso.Core.self_aff")
  pcall(require, "Yso.Curing.self_curedefs")
  pcall(require, "Yso.Curing.serverside_policy")
end
