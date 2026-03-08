-- Auto-exported from Mudlet package script: Yso list of functions
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso list of functions (Canonical getters / setters)
--  • Use these accessors in new logic going forward.
--  • Underlying tracking may change, but these should remain stable.
--========================================================--

Yso = Yso or {}

-- safe deleteLine wrapper (uses AK if present)
function Yso.deleteFull()
  local ak = rawget(_G, "ak")
  if ak and type(ak.deleteFull)=="function" then return ak.deleteFull() end
  if type(deleteLine)=="function" then deleteLine() end
end


-- common separators / metadata
Yso.cfg = Yso.cfg or {}
-- Default command separator (Achaea CONFIG SEPARATOR) for all payload pipelines.
-- User preference: "&&" (override by setting Yso.cfg.pipe_sep before load).
Yso.cfg.pipe_sep = Yso.cfg.pipe_sep or "&&"
-- Auto-clear target on movement when current target is not in room. Default OFF.
Yso.cfg.target_autoclear_not_in_room = (Yso.cfg.target_autoclear_not_in_room == true)

Yso.cfg.cmd_sep  = Yso.cfg.cmd_sep  or Yso.cfg.pipe_sep
Yso.sep   = Yso.sep   or Yso.cfg.pipe_sep
Yso.class = Yso.class or "" -- your class primarily for bashing (optional)

-- Centralized state bucket
Yso.state = Yso.state or {}
local S = Yso.state

-- Defaults (only set if nil)
if S.soulmaster_ready  == nil then S.soulmaster_ready  = false end
if S.loyals_hostile    == nil then S.loyals_hostile    = false end
if S.loyals_target     == nil then S.loyals_target     = nil   end
if S.tree_touched      == nil then S.tree_touched      = false end
if S.tree_ready        == nil then S.tree_ready        = false end
if S.sycophant_ready   == nil then S.sycophant_ready   = false end
if S.mind_focused      == nil then S.mind_focused      = false end

-- Legacy-global mirrors (kept for compatibility)
if rawget(_G, "soulmaster_ready") == nil then soulmaster_ready = false end
if rawget(_G, "loyals_attack")    == nil then loyals_attack    = false end
if rawget(_G, "tree_touched")     == nil then tree_touched     = false end
if rawget(_G, "tree_ready")       == nil then tree_ready       = false end
if rawget(_G, "sycophant_ready")  == nil then sycophant_ready  = false end
if rawget(_G, "mind_focused")     == nil then mind_focused     = false end

local function _bool(v) return v == true end

--========================
-- Setters (preferred)
--========================
function Yso.set_soulmaster_ready(v)
  S.soulmaster_ready = _bool(v)
  soulmaster_ready   = S.soulmaster_ready
end

-- Track whether loyals are currently in a hostile stance, optionally keyed to a target.
function Yso.set_loyals_attack(v, tgt)
  S.loyals_hostile = _bool(v)
  if S.loyals_hostile and type(tgt) == "string" and tgt ~= "" then
    S.loyals_target = tgt
  elseif not S.loyals_hostile then
    S.loyals_target = nil
  end
  loyals_attack = S.loyals_hostile
end

-- Convenience reset (use on yinit/yreload if your session state can persist)
function Yso.reset_loyals_attack()
  if type(Yso.set_loyals_attack) == "function" then
    Yso.set_loyals_attack(false)
  end
end

function Yso.set_tree_touched(v)
  S.tree_touched = _bool(v)
  tree_touched   = S.tree_touched
end

function Yso.set_tree_ready(v)
  S.tree_ready = _bool(v)
  tree_ready   = S.tree_ready
end

function Yso.set_sycophant_ready(v)
  S.sycophant_ready = _bool(v)
  sycophant_ready   = S.sycophant_ready
end

function Yso.set_mind_focused(v)
  S.mind_focused = _bool(v)
  mind_focused   = S.mind_focused
end

--========================
-- Getters (preferred API)
--========================
function Yso.soulmaster_ready()
  return _bool(S.soulmaster_ready) or _bool(rawget(_G, "soulmaster_ready"))
end

-- Optional parameter: if provided, return true only when hostile AND keyed to that target.
function Yso.loyals_attack(tgt)
  local hostile = _bool(S.loyals_hostile) or _bool(rawget(_G, "loyals_attack"))
  if not hostile then return false end
  if type(tgt) == "string" and tgt ~= "" then
    return S.loyals_target == tgt
  end
  return true
end

function Yso.tree_touched()
  return _bool(S.tree_touched) or _bool(rawget(_G, "tree_touched"))
end

function Yso.tree_ready()
  return _bool(S.tree_ready) or _bool(rawget(_G, "tree_ready"))
end

function Yso.sycophant_ready()
  return _bool(S.sycophant_ready) or _bool(rawget(_G, "sycophant_ready"))
end

function Yso.mind_focused()
  return _bool(S.mind_focused) or _bool(rawget(_G, "mind_focused"))
end

--========================================================--
-- Slowtime / Aeon / Retardation helpers (system-wide)
--  • Used by queue policy + offense modules
--========================================================--

function Yso.now()
  local v = (type(getEpoch)=="function" and tonumber(getEpoch())) or nil
  if v then
    if v > 1e12 then v = v / 1000 end -- normalize ms -> s if needed
    return v
  end
  return os.time()
end

function Yso.note_sluggish(src)
  S.slowtime_last_sluggish = Yso.now()
  S.slowtime_last_src      = tostring(src or "sluggish")
  if S.slowtime_ttl == nil then S.slowtime_ttl = 6.0 end
end

function Yso.is_slowtime()
  if Yso and Yso.self and type(Yso.self.has_aff) == "function" then
    if Yso.self.has_aff("aeon") or Yso.self.has_aff("retardation") then return true end
  end
  local last = tonumber(S.slowtime_last_sluggish or 0) or 0
  local ttl  = tonumber(S.slowtime_ttl or 6.0) or 6.0
  if last > 0 then return (Yso.now() - last) <= ttl end
  return false
end

--========================================================--
--========================================================--
-- Room presence (handled by Legacy)
--  NOTE:
--   • Legacy maintains authoritative gmcp.Room tracking.
--   • Yso offense MUST NOT auto-clear or gate combat logic on room presence.
--   • These helpers remain as compatibility stubs only.
--========================================================--

Yso.room = Yso.room or {}

local function _trim2(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function _lc2(s) return _trim2(s):lower() end

-- Compatibility: always return true (Yso does not police presence).
function Yso.room.has(name)
  local n = _lc2(name)
  return n ~= ""
end

function Yso.room_has(name) return Yso.room.has(name) end

-- Compatibility: always true (presence gating removed from Yso).
function Yso.target_is_valid(name)
  local n = _lc2(name)
  if n == "" then return false end
  if gmcp and gmcp.Room and Yso.room and type(Yso.room.has) == "function" then
    return Yso.room.has(n)
  end
  return true
end

--========================================================--
-- Target clearing (auto on death / out-of-room)
--========================================================--
function Yso.clear_target(reason)
  local prev = ""
  -- Prefer canonical targeting service state if present.
  if Yso.targeting and Yso.targeting.state and type(Yso.targeting.state.name) == "string" then
    prev = tostring(Yso.targeting.state.name or "")
  end
  -- Fall back to public getter if needed.
  if prev == "" and type(Yso.get_target) == "function" then
    prev = tostring(Yso.get_target() or "")
  end

  prev = _trim2(prev)
  if prev == "" then return false end

  Yso.last_target = prev
  -- Canonical clear (Phase 1): clear targeting service + mirrors.
  local tgs = Yso.targeting
  if tgs and type(tgs.clear) == "function" then
    tgs.clear("system", tostring(reason or "auto"), true)
  else
    -- Legacy fallback mirrors
    rawset(_G, "target", "")
    Yso.target = ""
    if Yso.ingest and type(Yso.ingest.target_left) == "function" then
      pcall(Yso.ingest.target_left, tostring(reason or "auto"), { nowake = true })
    end
  end

  -- Clear module-local mirrors if present
  if Yso and Yso.off and Yso.off.oc then
    if Yso.off.oc.dmg and Yso.off.oc.dmg.state then
      Yso.off.oc.dmg.state.target = ""
    end
  end

  if type(raiseEvent) == "function" then
    raiseEvent("yso.target.cleared", prev, tostring(reason or "auto"))
  end

  if type(cecho) == "function" then
    cecho(string.format("<cyan>[Yso] Target cleared (%s): %s\n", tostring(reason or "auto"), prev))
  else
    echo(string.format("[Yso] Target cleared (%s): %s\n", tostring(reason or "auto"), prev))
  end

  return true
end

--========================================================--
-- READAURA snapshot (Occultist) — canonical target-defence intel
--========================================================--

Yso.occ = Yso.occ or {}
Yso.occ.aura = Yso.occ.aura or {}
Yso.occ.aura_cfg = Yso.occ.aura_cfg or { ttl = 20, debug = false }
Yso.occ.readaura_ready = (Yso.occ.readaura_ready ~= false)

--========================================================--
-- Ingest shims (AK -> Yso)
--  • AK's READAURA triggers call Yso.ingest.aura_begin/aura_def/aura_end.
--  • Provide these as thin wrappers into Yso.occ snapshot builder.
--  • IMPORTANT: do NOT implement readaura_ready/begin/result here to avoid recursion.
--========================================================--
Yso.ingest = Yso.ingest or {}
if type(Yso.ingest.aura_begin) ~= "function" then
  function Yso.ingest.aura_begin(tgt)
    if Yso.occ and type(Yso.occ.aura_begin) == "function" then
      return Yso.occ.aura_begin(tgt)
    end
    return false
  end
end
if type(Yso.ingest.aura_def) ~= "function" then
  function Yso.ingest.aura_def(key, val)
    if val == true and Yso.occ and type(Yso.occ.aura_seen) == "function" then
      return Yso.occ.aura_seen(key)
    end
    return false
  end
end
if type(Yso.ingest.aura_end) ~= "function" then
  function Yso.ingest.aura_end(_tgt, _phys, _ment)
    -- No-op by default: AK already calls Yso.occ.aura_finalize().
    return true
  end
end

local function _yso_now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok,v = pcall(Yso.util.now)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  local t = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  if t and t > 20000000000 then t = t / 1000 end
  return t or os.time()
end

-- ===== READAURA global ready-state (single source of truth) =====
Yso.occ._ra = Yso.occ._ra or { ready = (Yso.occ.readaura_ready ~= false), reason = "", mark = 0 }

function Yso.occ.set_readaura_ready(val, reason)
  local r = (val == true)
  Yso.occ._ra.ready  = r
  Yso.occ._ra.reason = tostring(reason or Yso.occ._ra.reason or "")
  Yso.occ._ra.mark   = _yso_now()
  Yso.occ.readaura_ready = r

  -- Phase 1 plumbing: mirror into Yso.state (no extra wake; pulse wake below)
  if Yso and Yso.ingest and type(Yso.ingest.readaura_ready) == "function" then
    pcall(Yso.ingest.readaura_ready, r, Yso.occ._ra.reason, "occ:set_readaura_ready", { nowake = true })
  end

  if Yso.pulse and type(Yso.pulse.wake)=="function" then
    Yso.pulse.wake("readaura:"..(r and "ready" or "down"))
  end
  return r
end

-- Compatibility: some triggers call Yso.set_readaura_ready(...)
if type(Yso.set_readaura_ready) ~= "function" then
  function Yso.set_readaura_ready(...)
    if Yso.occ and type(Yso.occ.set_readaura_ready)=="function" then
      return Yso.occ.set_readaura_ready(...)
    end
  end
end

function Yso.occ.readaura_is_ready()
  if Yso.occ._ra and Yso.occ._ra.ready ~= nil then return Yso.occ._ra.ready == true end
  return Yso.occ.readaura_ready ~= false
end

local _A_KEYS = {
  blind=true, deaf=true,
  cloak=true, speed=true, caloric=true, frost=true, levitation=true, insomnia=true, kola=true,
}

Yso.occ._aura_pending = Yso.occ._aura_pending or { t = "", seen = {} }

function Yso.occ.aura_begin(tgt)
  tgt = tostring(tgt or ""):gsub("^%s+",""):gsub("%s+$","")
  if tgt == "" then return false end
  Yso.occ._aura_pending.t = tgt
  Yso.occ._aura_pending.seen = {}

  -- Phase 1 plumbing: track pending in Yso.state
  if Yso and Yso.ingest and type(Yso.ingest.readaura_begin) == "function" then
    pcall(Yso.ingest.readaura_begin, tgt, "occ:aura_begin")
  end

  return true
end

function Yso.occ.aura_seen(key)
  key = tostring(key or ""):lower()
  if not _A_KEYS[key] then return false end
  Yso.occ._aura_pending.seen[key] = true
  return true
end

function Yso.occ.aura_finalize(tgt, phys, ment)
  tgt = tostring(tgt or ""):gsub("^%s+",""):gsub("%s+$","")
  if tgt == "" then return false end

  local p = tostring(Yso.occ._aura_pending.t or "")
  local seen = ((p ~= "" and p:lower() == tgt:lower()) and Yso.occ._aura_pending.seen) or {}

  local snap = {
    ts = _yso_now(),
    physical = tonumber(phys) or 0,
    mental   = tonumber(ment) or 0,
  }

  for k in pairs(_A_KEYS) do
    snap[k] = (seen[k] == true) and true or false
  end

  Yso.occ.aura[tgt] = snap
  Yso.occ.aura[tgt:lower()] = snap
  Yso.occ._aura_pending.t = ""
  Yso.occ._aura_pending.seen = {}

  -- Phase 1 plumbing: persist result in Yso.state.opp[*].aura
  if Yso and Yso.ingest and type(Yso.ingest.readaura_result) == "function" then
    local flags = {}
    for k in pairs(_A_KEYS) do flags[k] = (snap[k] == true) end
    pcall(Yso.ingest.readaura_result, tgt, snap.physical, snap.mental, flags, "occ:aura_finalize")
  end

  return true
end

function Yso.occ.aura_get(tgt, key)
  tgt = tostring(tgt or "")
  key = tostring(key or ""):lower()
  local a = Yso.occ.aura[tgt] or Yso.occ.aura[tgt:lower()]
  if not a then return nil end
  local ttl = (Yso.occ.aura_cfg and Yso.occ.aura_cfg.ttl) or 20
  if ttl and ttl > 0 and (_yso_now() - (a.ts or 0)) > ttl then return nil end
  return a[key]
end

-- Convenience boolean wrappers (fresh-only)
function Yso.blind(t)      return Yso.occ.aura_get(t,"blind")      == true end
function Yso.deaf(t)       return Yso.occ.aura_get(t,"deaf")       == true end
function Yso.cloak(t)      return Yso.occ.aura_get(t,"cloak")      == true end
function Yso.speed(t)      return Yso.occ.aura_get(t,"speed")      == true end
function Yso.caloric(t)    return Yso.occ.aura_get(t,"caloric")    == true end
function Yso.frost(t)      return Yso.occ.aura_get(t,"frost")      == true end
function Yso.levitation(t) return Yso.occ.aura_get(t,"levitation") == true end
function Yso.insomnia(t)   return Yso.occ.aura_get(t,"insomnia")   == true end
function Yso.kola(t)       return Yso.occ.aura_get(t,"kola")       == true end

-- Returns:
--   true  -> attend is recommended (blind/deaf detected on target)
--   false -> attend not needed (snapshot says no blind/deaf, or mindseye present)
--   nil   -> unknown (no fresh snapshot)
function Yso.occ.aura_need_attend(tgt)
  if Yso and Yso.tgt and type(Yso.tgt.has_mindseye)=="function" and Yso.tgt.has_mindseye(tgt) then
    return false
  end
  local _t = tostring(tgt or "")
  local a = Yso.occ.aura[_t] or Yso.occ.aura[_t:lower()]
  if not a then return nil end
  local ttl = (Yso.occ.aura_cfg and Yso.occ.aura_cfg.ttl) or 20
  if ttl and ttl > 0 and (_yso_now() - (a.ts or 0)) > ttl then return nil end
  return (a.blind or a.deaf) and true or false
end

-- Optional: offense helper (EQ-gated, cooldown message-gated)
function Yso.occ.queue_readaura(tgt)
  tgt = tostring(tgt or ""):gsub("^%s+",""):gsub("%s+$","")
  if tgt == "" then return false end
  if type(send) ~= "function" then return false end

  local v = gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  local eq = tostring(v.eq or v.equilibrium or "") == "1"
  if not eq then return false end

  if type(Yso.occ.readaura_is_ready) == "function" then
    if not Yso.occ.readaura_is_ready() then return false end
  elseif Yso.occ.readaura_ready == false then
    return false
  end

  if type(Yso.occ.set_readaura_ready) == "function" then
    Yso.occ.set_readaura_ready(false, "sent")
  else
    Yso.occ.readaura_ready = false
  end

  send("readaura " .. tgt)
  return true
end

--========================================================--
-- Magical shield tracking (Yso)
--========================================================--
Yso.defs = Yso.defs or {}
Yso.defs.shield = Yso.defs.shield or {}

Yso.shield = Yso.shield or {}

local function _yso_norm_tgt(tgt)
  tgt = tostring(tgt or "")
  return (tgt ~= "" and tgt) or nil
end

local function _yso_mirror_to_ak(tgt, state)
  if not rawget(_G, "ak") or not ak.defs then return end
  -- AK shield can be a table (per-target) or a single boolean. Avoid clobbering functions.
  if type(ak.defs.shield) == "table" then
    ak.defs.shield[tgt] = state and true or false
  elseif type(ak.defs.shield) == "boolean" then
    ak.defs.shield = state and true or false
  end
end

function Yso.shield.set(tgt, state, why)
  tgt = _yso_norm_tgt(tgt)
  if not tgt then return false end

  state = (state == true)
  Yso.defs.shield[tgt] = state

  -- Mirror for compatibility (requested).
  _yso_mirror_to_ak(tgt, state)

  -- Optional debug (silent by default)
  if Yso.cfg and Yso.cfg.debug_shield and type(cecho) == "function" then
    cecho(string.format("<gray>[Yso:shield] %s -> %s (%s)<reset>\n", tgt, tostring(state), tostring(why or "")))
  end
  return true
end

function Yso.shield.is_up(tgt)
  tgt = _yso_norm_tgt(tgt)
  if not tgt then return false end

  -- Prefer AK as source-of-truth when it has an explicit value.
  local akr = rawget(_G, "ak")
  if akr and akr.defs then
    local s = akr.defs.shield
    if type(s) == "boolean" then
      return s == true
    elseif type(s) == "table" then
      if s[tgt] ~= nil then return s[tgt] == true end
      local tl = tgt:lower()
      if s[tl] ~= nil then return s[tl] == true end
    end
  end

  -- Fallback: Yso's own tracking
  if Yso.defs.shield[tgt] == true then return true end
  return false
end

-- Compatibility hook used by some AK trigger scripts (if present):
-- Treats any "shield blocked" message as shield=true.
function Yso.shield.mark_block(tgt)
  return Yso.shield.set(tgt, true, "ak_mark_block")
end

--========================================================--
-- Central offense utility: shieldbreak (Gremlin)
--  • Gremlin uses EQUILIBRIUM lane (NOT entity balance)
--  • Returns an EQ-lane command string or nil
--========================================================--
Yso.off = Yso.off or {}
Yso.off.util = Yso.off.util or {}
function Yso.off.util.maybe_shieldbreak(tgt)
  tgt = _yso_norm_tgt(tgt)
  if not tgt then return nil end
  if type(Yso.shield.is_up) == "function" and Yso.shield.is_up(tgt) then
    return ("command gremlin at %s"):format(tgt)
  end
  return nil
end



--========================================================--
-- Readiness (SSOT helpers)
--========================================================--
Yso.state = Yso.state or {}
local _S = Yso.state

local function _vitals()
  return (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
end

function Yso.state.eq_ready()
  local v = _vitals()
  return tostring(v.eq or v.equilibrium or "") == "1" or (v.eq == true or v.equilibrium == true)
end

function Yso.state.bal_ready()
  local v = _vitals()
  return tostring(v.bal or v.balance or "") == "1" or (v.bal == true or v.balance == true)
end


-- ---- Entity cooldown table (seconds) ----
-- Source: AB DOMINATION helpfile screenshots + live timing.
Yso.occ = Yso.occ or {}
Yso.occ.entity_cd = Yso.occ.entity_cd or {
  sycophant  = 2.00,
  bloodleech = 2.20,
  humbug     = 2.20,
  bubonis    = 2.20,
  hound      = 2.20,
  slime      = 2.60,
  chimera    = 2.50,
  worm       = 3.10,
  firelord   = 3.00,
  crone      = 3.00,
  dervish    = 2.10,
  storm      = 2.20,
}

function Yso.occ.entity_cd_for_cmd(cmd)
  if type(cmd) ~= 'string' then return nil end
  local k = cmd:lower():match("^%s*command%s+([%w']+)")
  if not k or k == '' then return nil end
  return (Yso.occ.entity_cd and Yso.occ.entity_cd[k]) or nil, k
end

-- Entity readiness is NOT GMCP-native; we track it via cooldown triggers.
_S._ent_ready = (_S._ent_ready ~= false)
_S._ent_backoff_until = tonumber(_S._ent_backoff_until or 0) or 0
_S._ent_recover_timer = _S._ent_recover_timer or nil
_S._ent_last_cmd_cd = tonumber(_S._ent_last_cmd_cd or 0) or 0
_S._ent_last_cmd_key = tostring(_S._ent_last_cmd_key or "")


function Yso.state.ent_ready()
  -- Global policy: entity commands should be treated as unavailable while off-balance.
  -- This is critical after Tarot AEON (off-balance) and matches in-game restrictions.
  if type(Yso.state.bal_ready) == "function" and not Yso.state.bal_ready() then
    return false
  end

  local now = (Yso.util and Yso.util.now and Yso.util.now()) or os.time()
  if tonumber(_S._ent_backoff_until or 0) > now then return false end

  -- Best-effort GMCP presence check (Char.Vitals.charstats contains "Entity: Yes/No").
  local v = _vitals()
  local cs = v and v.charstats
  local present = nil
  if type(cs) == "table" then
    for _, s in ipairs(cs) do
      local t = tostring(s or ""):lower()
      if t:find("entity:%s*yes") then present = true; break end
      if t:find("entity:%s*no")  then present = false; break end
    end
  end
  if present == false then return false end

  -- Bootstrap: if we *have* an entity and our readiness is stale (eg. carried over as false on package reload),
  -- assume ready until proven otherwise by cooldown/command triggers.
  if present == true and _S._ent_ready ~= true then
    local ts = tonumber(_S._ent_last_ts or 0) or 0
    if ts == 0 or (now - ts) > 30 then
      _S._ent_ready = true
      _S._ent_last_src = "bootstrap:vitals"
      _S._ent_last_ts  = now
    end
  end

  return _S._ent_ready == true
end

function Yso.state.set_ent_ready(v, src)
  local prev = (_S._ent_ready == true)
  _S._ent_ready = (v == true)
  _S._ent_last_src = tostring(src or "")
  _S._ent_last_ts  = (Yso.util and Yso.util.now and Yso.util.now()) or os.time()

  -- Lane wake signal on 0->1 transition (freestyle lane isolation)
  if (not prev) and _S._ent_ready == true then
    if Yso and Yso.pulse and type(Yso.pulse.wake) == "function" then
      pcall(Yso.pulse.wake, "lane:class")
    end
  end
end


function Yso.state.ent_busy(seconds, src, key)
  -- Marks entity lane not-ready AND schedules a timed recovery.
  -- This prevents deadlocks when readiness triggers are missed.
  seconds = tonumber(seconds)
  if not seconds or seconds <= 0 then
    seconds = tonumber(_S._ent_last_cmd_cd or 0) or 0
    if seconds <= 0 then seconds = 2.5 end
  end
  if seconds < 0.5 then seconds = 0.5 end

  if key and key ~= "" then
    _S._ent_last_cmd_key = tostring(key)
    _S._ent_last_cmd_cd  = tonumber(seconds) or _S._ent_last_cmd_cd
  end

  Yso.state.set_ent_ready(false, src or "ent_busy")
  local now = (Yso.util and Yso.util.now and Yso.util.now()) or os.time()
  _S._ent_backoff_until = math.max(tonumber(_S._ent_backoff_until or 0) or 0, now + seconds)

  -- Cancel prior recovery timer
  if _S._ent_recover_timer and type(killTimer) == "function" then
    killTimer(_S._ent_recover_timer)
  end
  _S._ent_recover_timer = nil

  -- Schedule recovery slightly after the backoff expires
  if type(tempTimer) == "function" then
    _S._ent_recover_timer = tempTimer(seconds + 0.25, function()
      _S._ent_recover_timer = nil
      local n = (Yso.util and Yso.util.now and Yso.util.now()) or os.time()
      if tonumber(_S._ent_backoff_until or 0) <= n then
        Yso.state.set_ent_ready(true, "timer:ent_busy")
        if Yso and Yso.occ and Yso.occ.entity_ready ~= nil then
          Yso.occ.entity_ready = true
        end
      end
    end)
  end
end

function Yso.state.ent_fail(seconds, src)
  -- Failure/backoff path (e.g. "disregards your order").
  -- Defaults to last-known command cooldown, else 2.5s.
  Yso.state.ent_busy(seconds, src or "ent_fail")
end

--========================================================--
-- Locks (FULL) — pending/cooldown/backoff + lane wake reasons
--  • Upgrades the minimal locks from api_stuff.lua.
--  • Runs even if _yso_minlocks is already set.
--========================================================--
Yso.locks = Yso.locks or {}
do
  local L = Yso.locks
  if L._yso_fulllocks ~= true then
    L._yso_fulllocks = true

    -- Ensure base structures exist (may have been created by api_stuff.lua).
    L._lane = L._lane or {
      eq    = { pending_until = 0 },
      bal   = { pending_until = 0 },
      class = { pending_until = 0, backoff_until = 0 },
    }
    L.cfg = L.cfg or { pending = 0.35 }
    L._vitals = L._vitals or { eq = nil, bal = nil }

    local function _now()
      return (Yso.util and Yso.util.now and Yso.util.now()) or os.time()
    end

    function L.note_send(lane, pending)
      lane = tostring(lane or ""):lower()
      if lane == "ent" or lane == "entity" then lane = "class" end

      local st = L._lane[lane]; if not st then return end
      pending = tonumber(pending) or tonumber(L.cfg.pending) or 0.35
      st.pending_until = math.max(tonumber(st.pending_until or 0) or 0, _now() + pending)
    end

    -- Sync GMCP vitals; clears pending on 0->1 regain and emits wake reasons for freestyle lane isolation.
    function L.sync_vitals(v)
      v = v or (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
      local eq  = tostring(v.eq or v.equilibrium or "") == "1" or (v.eq == true or v.equilibrium == true)
      local bal = tostring(v.bal or v.balance or "") == "1" or (v.bal == true or v.balance == true)

      local eq_rise  = (eq == true and L._vitals.eq == false)
      local bal_rise = (bal == true and L._vitals.bal == false)

      if eq_rise and L._lane.eq then L._lane.eq.pending_until = 0 end
      if bal_rise and L._lane.bal then L._lane.bal.pending_until = 0 end

      L._vitals.eq, L._vitals.bal = eq, bal

      if (eq_rise or bal_rise) and Yso and Yso.pulse and type(Yso.pulse.wake) == "function" then
        if eq_rise then pcall(Yso.pulse.wake, "lane:eq") end
        if bal_rise then pcall(Yso.pulse.wake, "lane:bal") end
      end
    end

    -- Mark multi-lane payload as pending; for ENTITY lane also apply timed ent_busy() if possible.
    function L.note_payload(payload)
      if type(payload) ~= "table" then return end
      if payload.eq then L.note_send("eq") end
      if payload.bal then L.note_send("bal") end

      if payload.class or payload.ent or payload.entity then
        L.note_send("class")

        local cls = payload.class or payload.ent or payload.entity
        local cmd
        if type(cls) == "string" then cmd = cls
        elseif type(cls) == "table" then cmd = cls[1] end

        local cd, key
        if cmd and type(Yso.occ) == "table" and type(Yso.occ.entity_cd_for_cmd) == "function" then
          local ok, a, b = pcall(Yso.occ.entity_cd_for_cmd, cmd)
          if ok then cd, key = a, b end
        end

        if cd and Yso.state and type(Yso.state.ent_busy) == "function" then
          pcall(Yso.state.ent_busy, cd, "locks:payload", key)
        elseif Yso.state and type(Yso.state.set_ent_ready) == "function" then
          pcall(Yso.state.set_ent_ready, false, "locks:payload")
        end
      end
    end

    function L.ent_backoff(seconds, src)
      seconds = tonumber(seconds) or 1.0
      if seconds <= 0 then seconds = 0.5 end
      local st = L._lane.class
      st.backoff_until = math.max(tonumber(st.backoff_until or 0) or 0, _now() + seconds)
      if Yso.state and type(Yso.state.ent_fail) == "function" then
        pcall(Yso.state.ent_fail, seconds, src or "locks.ent_backoff")
      elseif Yso.state and type(Yso.state.set_ent_ready) == "function" then
        pcall(Yso.state.set_ent_ready, false, src or "locks.ent_backoff")
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

--========================================================--
--========================================================--
-- Yso.fnref (static full index + runtime walker)
--  • static: comprehensive function list (union of disk+mpackage sources)
--  • runtime: walk currently-loaded Yso table and list discovered functions
--========================================================--
Yso.fnref = Yso.fnref or {}
do
  local F = Yso.fnref
  F.all = F.all or {
    "Yso.Orchestrator.register",
    "Yso.Orchestrator.run",
    "Yso.Orchestrator.select",
    "Yso.Orchestrator.wake",
    "Yso._req.try",
    "Yso.ak.adapters.pull_full_state",
    "Yso.ak.any",
    "Yso.ak.count",
    "Yso.ak.cure",
    "Yso.ak.gain",
    "Yso.ak.has",
    "Yso.ak.init",
    "Yso.ak.list_affs",
    "Yso.ak.set_target",
    "Yso.ak.status",
    "Yso.ak.sync_from_ak",
    "Yso.ak.target",
    "Yso.ak.toggle_debug",
    "Yso.aliases.register",
    "Yso.blind",
    "Yso.bus.emit",
    "Yso.bus.on",
    "Yso.caloric",
    "Yso.clear_target",
    "Yso.cloak",
    "Yso.core._req.try",
    "Yso.core.boot",
    "Yso.core.ensure_aliases",
    "Yso.core.kick",
    "Yso.core.load",
    "Yso.core.reload",
    "Yso.curing.adapters.emergency",
    "Yso.curing.adapters.game_curing_off",
    "Yso.curing.adapters.game_curing_on",
    "Yso.curing.adapters.lower_aff",
    "Yso.curing.adapters.raise_aff",
    "Yso.curing.adapters.set_aff_prio",
    "Yso.curing.adapters.use_profile",
    "Yso.curing.emergency",
    "Yso.curing.game_curing_off",
    "Yso.curing.game_curing_on",
    "Yso.curing.init",
    "Yso.curing.lower_aff",
    "Yso.curing.raise_aff",
    "Yso.curing.set_aff_prio",
    "Yso.curing.set_mode",
    "Yso.curing.status",
    "Yso.curing.toggle",
    "Yso.curing.toggle_debug",
    "Yso.curing.use_profile",
    "Yso.deaf",
    "Yso.debug.snapshot.take",
    "Yso.debug.trace.is_on",
    "Yso.debug.trace.log",
    "Yso.debug.trace.set",
    "Yso.deleteFull",
    "Yso.diag.echo",
    "Yso.diag.snapshot",
    "Yso.dom.abomination_up",
    "Yso.dom.has_ent",
    "Yso.dom.orbdef.cmd",
    "Yso.dom.orbdef.on_down",
    "Yso.dom.orbdef.on_gmcp_add",
    "Yso.dom.orbdef.on_gmcp_remove",
    "Yso.dom.orbdef.on_up",
    "Yso.dom.orbdef.remaining",
    "Yso.dom.orbdef.start",
    "Yso.dom.orbdef.stop",
    "Yso.dom.pathfinder_available",
    "Yso.dom.pathfinder_go_home",
    "Yso.dom.pathfinder_home_string",
    "Yso.dom.pathfinder_set_ready",
    "Yso.dop.do_piridon_channel",
    "Yso.dop.do_piridon_util",
    "Yso.dop.do_tarot_fling",
    "Yso.dop.dom_echo",
    "Yso.dop.getTarget",
    "Yso.dop.handle",
    "Yso.dop.help",
    "Yso.dop.seek",
    "Yso.dop.setTarget",
    "Yso.emit",
    "Yso.entourage_attack",
    "Yso.entourage_set_hostile",
    "Yso.escape.press",
    "Yso.fnref.echo",
    "Yso.fnref.walk",
    "Yso.fool.mark_diag_pending",
    "Yso.fool.on_vitals",
    "Yso.fool.set_cd",
    "Yso.fool.set_min_affs",
    "Yso.fool.toggle_auto",
    "Yso.frost",
    "Yso.get_target",
    "Yso.insomnia",
    "Yso.is_slowtime",
    "Yso.kola",
    "Yso.lanes.normalize",
    "Yso.learn.debug_one",
    "Yso.learn.note_attempt",
    "Yso.learn.probe_due",
    "Yso.learn.quick_prob",
    "Yso.learn.samples",
    "Yso.learn.should_deprioritize",
    "Yso.learn.tick",
    "Yso.levitation",
    "Yso.locks.bal_ready",
    "Yso.locks.ent_backoff",
    "Yso.locks.ent_ready",
    "Yso.locks.eq_ready",
    "Yso.locks.note_payload",
    "Yso.locks.note_send",
    "Yso.locks.on_ent_ready",
    "Yso.locks.ready",
    "Yso.locks.status",
    "Yso.locks.sync_vitals",
    "Yso.log.error",
    "Yso.log.info",
    "Yso.log.warn",
    "Yso.loyals_attack",
    "Yso.magician.on_vitals",
    "Yso.magician.queue_self",
    "Yso.magician.queue_target",
    "Yso.magician.set_hp_min",
    "Yso.magician.set_mp_threshold",
    "Yso.magician.toggle_auto",
    "Yso.mind_focused",
    "Yso.mode.apply_profile",
    "Yso.mode.auto.bump_combat",
    "Yso.mode.auto.clear_force",
    "Yso.mode.auto.dump_sniff",
    "Yso.mode.auto.force_combat",
    "Yso.mode.echo",
    "Yso.mode.is_combat",
    "Yso.mode.is_hunt",
    "Yso.mode.on_disengage",
    "Yso.mode.on_engage",
    "Yso.mode.set",
    "Yso.mode.toggle",
    "Yso.note_sluggish",
    "Yso.now",
    "Yso.oc.ak.get_aff_score",
    "Yso.oc.ak.refresh_lists_from_AK",
    "Yso.oc.ak.scores.enlighten",
    "Yso.oc.ak.scores.ginseng",
    "Yso.oc.ak.scores.golden",
    "Yso.oc.ak.scores.kelp",
    "Yso.oc.ak.scores.mental",
    "Yso.oc.ak.scores.trample",
    "Yso.oc.ak.scores.whisper",
    "Yso.oc.cures.affs_in_eat_bucket",
    "Yso.oc.cures.bucket_score",
    "Yso.oc.cures.dump",
    "Yso.oc.cures.get",
    "Yso.oc.cures.ginseng_score",
    "Yso.oc.cures.golden_score",
    "Yso.oc.cures.kelp_score",
    "Yso.oc.cures.rebuild",
    "Yso.predict.cure.dump",
    "Yso.predict.cure.next",
    "Yso.predict.cure.observe",
    "Yso.predict.toggle",
    "Yso.predict.wire",
    "Yso.oc.map.rebuild_by_aff",
    "Yso.oc.prone.softscore",
    "Yso.oc.prone.step",
    "Yso.oc.prone.try_hook",
    "Yso.oc.prone.want_anorexia",
    "Yso.occ.aura_begin",
    "Yso.occ.aura_finalize",
    "Yso.occ.aura_get",
    "Yso.occ.aura_need_attend",
    "Yso.occ.aura_seen",
    "Yso.occ.clock.disable",
    "Yso.occ.clock.firelord_ack",
    "Yso.occ.clock.macro",
    "Yso.occ.clock.plan_and_fire",
    "Yso.occ.clock.tick",
    "Yso.occ.clock.toggle",
    "Yso.occ.clock_dry_test_limb",
    "Yso.occ.entities.get",
    "Yso.occ.entities.set",
    "Yso.occ.getDom",
    "Yso.occ.getDomById",
    "Yso.occ.is_cleansed",
    "Yso.occ.listDomByRole",
    "Yso.occ.mark_aura_restored",
    "Yso.occ.mark_cleansed",
    "Yso.occ.queue_readaura",
    "Yso.occ.readaura_is_ready",
    "Yso.occ.set_readaura_ready",
    "Yso.occ.set_target_mana_pct",
    "Yso.occ.truebook._begin_refresh",
    "Yso.occ.truebook._commit_refresh",
    "Yso.occ.truebook.add",
    "Yso.occ.truebook.can_utter",
    "Yso.occ.truebook.get",
    "Yso.occ.truebook.load",
    "Yso.occ.truebook.save",
    "Yso.occ.truebook.set",
    "Yso.occultist.aff_lanes",
    "Yso.occultist.aff_sources",
    "Yso.occultist.affs_by_lane",
    "Yso.occultist.build_affcap",
    "Yso.occultist.getOccultismSkill",
    "Yso.occultist.getTarot",
    "Yso.occultist.isOccultismOffense",
    "Yso.occultist.isTarotOffense",
    "Yso.occultist.listOccultismByRole",
    "Yso.occultist.listTarotByRole",
    "Yso.oclocks.echo",
    "Yso.oclocks.print",
    "Yso.oclocks.recommend_mode",
    "Yso.oclocks.status",
    "Yso.off.coord.on_target_leap",
    "Yso.off.oc.attack_eqonly",
    "Yso.off.oc.clear_sight",
    "Yso.off.oc.dmg.attack_cycle",
    "Yso.off.oc.dmg.conditions_logic",
    "Yso.off.oc.dmg.mark_tumble",
    "Yso.off.oc.dmg.pause",
    "Yso.off.oc.dmg.resume",
    "Yso.off.oc.dmg.start",
    "Yso.off.oc.dmg.status",
    "Yso.off.oc.dmg.stop",
    "Yso.off.oc.dmg.toggle",
    "Yso.off.oc.dmg.utility_logic",
    "Yso.off.oc.duel_limbs._loop",
    "Yso.off.oc.duel_limbs.start",
    "Yso.off.oc.duel_limbs.stop",
    "Yso.off.oc.duel_limbs.tick",
    "Yso.off.oc.duel_limbs.toggle",
    "Yso.off.oc.ensure_chimera_ready",
    "Yso.off.oc.get_ai",
    "Yso.off.oc.get_mode",
    "Yso.off.oc.get_tarot",
    "Yso.off.oc.need_sight",
    "Yso.off.oc.off",
    "Yso.off.oc.on",
    "Yso.off.oc.phase",
    "Yso.off.oc.queue_attend_if_needed",
    "Yso.off.oc.request_sight",
    "Yso.off.oc.set_ai",
    "Yso.off.oc.set_ent_mode",
    "Yso.off.oc.set_entity_key",
    "Yso.off.oc.set_entity_word",
    "Yso.off.oc.set_instill_mode",
    "Yso.off.oc.set_mode",
    "Yso.off.oc.set_target",
    "Yso.off.oc.set_tarot",
    "Yso.off.oc.sg_entity_cmd_for_aff",
    "Yso.off.oc.sg_pick_missing_aff",
    "Yso.off.oc.softscore",
    "Yso.off.oc.tick",
    "Yso.off.oc.toggle",
    "Yso.off.oc.toggle_ai",
    "Yso.off.oc.toggle_tarot",
    "Yso.off.oc.try_kelp_bury",
    "Yso.off.oc.try_softlock_setup",
    "Yso.pacts.begin_capture",
    "Yso.pacts.finish_capture",
    "Yso.pacts.get_low",
    "Yso.pacts.get_missing",
    "Yso.pacts.parse_line",
    "Yso.pacts.report_alerts",
    "Yso.pacts.report_low",
    "Yso.priestess.on_vitals",
    "Yso.priestess.queue_self",
    "Yso.priestess.queue_target",
    "Yso.priestess.set_threshold",
    "Yso.priestess.toggle_auto",
    "Yso.primebond.request",
    "Yso.probe.both",
    "Yso.probe.heartstone",
    "Yso.probe.simulacrum",
    "Yso.pulse._flush_inner",
    "Yso.pulse.debug",
    "Yso.pulse.enable",
    "Yso.pulse.entity_ack",
    "Yso.pulse.flush",
    "Yso.pulse.is_ready",
    "Yso.pulse.kick",
    "Yso.pulse.queue",
    "Yso.pulse.register",
    "Yso.pulse.send_bal",
    "Yso.pulse.send_entity",
    "Yso.pulse.send_eq",
    "Yso.pulse.send_free",
    "Yso.pulse.set_ready",
    "Yso.pulse.stop",
    "Yso.pulse.unregister",
    "Yso.pulse.wake",
    "Yso.queue.addclear",
    "Yso.queue.addclearfull",
    "Yso.queue.bal_clear",
    "Yso.queue.class_clear",
    "Yso.queue.clear",
    "Yso.queue.commit",
    "Yso.queue.emit",
    "Yso.queue.eq_clear",
    "Yso.queue.free",
    "Yso.queue.list",
    "Yso.queue.push",
    "Yso.queue.raw",
    "Yso.queue.replace",
    "Yso.queue.stage",
    "Yso.radianceAlert.banner",
    "Yso.radianceAlert.center",
    "Yso.radianceAlert.fire",
    "Yso.radianceAlert.sound",
    "Yso.reload",
    "Yso.resolve_target",
    "Yso.room.has",
    "Yso.room_has",
    "Yso.self.has_aff",
    "Yso.self.is_paralyzed",
    "Yso.set_loyals_attack",
    "Yso.set_mind_focused",
    "Yso.set_readaura_ready",
    "Yso.set_soulmaster_ready",
    "Yso.set_sycophant_ready",
    "Yso.set_target",
    "Yso.set_tree_ready",
    "Yso.set_tree_touched",
    "Yso.shield.is_up",
    "Yso.shield.mark_block",
    "Yso.shield.set",
    "Yso.shutdown",
    "Yso.sim._bak.sendAll_wrap",
    "Yso.sim._bak.send_wrap",
    "Yso.sim.report",
    "Yso.sim.reset",
    "Yso.sim.run",
    "Yso.sim.set_cure",
    "Yso.sim.start",
    "Yso.sim.status",
    "Yso.sim.step",
    "Yso.sim.stop",
    "Yso.soulmaster_ready",
    "Yso.speed",
    "Yso.state.bal_ready",
    "Yso.state.ent_fail",
    "Yso.state.ent_ready",
    "Yso.state.entities_missing",
    "Yso.state.eq_ready",
    "Yso.state.is_prone",
    "Yso.state.set_ent_ready",
    "Yso.state.set_entities_missing",
    "Yso.state.sync_vitals",
    "Yso.state.tgt_clear",
    "Yso.state.tgt_has_aff",
    "Yso.state.tgt_set_aff",
    "Yso.state.update_vitals",
    "Yso.sycophant_ready",
    "Yso.target_is_valid",
    "Yso.targeting._maybe_import_global",
    "Yso.targeting.clear",
    "Yso.targeting.get",
    "Yso.targeting.lock",
    "Yso.targeting.set",
    "Yso.targeting.unlock",
    "Yso.tarot.devil_active",
    "Yso.tarot.devil_down",
    "Yso.tarot.devil_up",
    "Yso.tgt.aff_cure",
    "Yso.tgt.aff_gain",
    "Yso.tgt.can_hear",
    "Yso.tgt.can_see",
    "Yso.tgt.drop",
    "Yso.tgt.get",
    "Yso.tgt.get_mana_pct",
    "Yso.tgt.has_aff",
    "Yso.tgt.has_mindseye",
    "Yso.tgt.lock_status",
    "Yso.tgt.note_target_herb",
    "Yso.tgt.note_tree_touch",
    "Yso.tgt.set_mana_pct",
    "Yso.tgt.set_mindseye",
    "Yso.trace.dump",
    "Yso.trace.echo",
    "Yso.trace.push",
    "Yso.travel.alias",
    "Yso.travel.go",
    "Yso.travel.help",
    "Yso.travel.plan",
    "Yso.travel.providers.map.available",
    "Yso.travel.providers.map.execute",
    "Yso.travel.providers.map.resolve",
    "Yso.travel.providers.routes.available",
    "Yso.travel.providers.routes.execute",
    "Yso.travel.providers.routes.resolve",
    "Yso.travel.providers.universe.available",
    "Yso.travel.providers.universe.execute",
    "Yso.travel.providers.universe.resolve",
    "Yso.travel.providers_status",
    "Yso.travel.route_add_room",
    "Yso.travel.route_add_uni",
    "Yso.travel.route_add_walk",
    "Yso.travel.route_del",
    "Yso.travel.route_list",
    "Yso.tree_ready",
    "Yso.tree_touched",
    "Yso.uni.alias",
    "Yso.uni.fav_add",
    "Yso.uni.fav_del",
    "Yso.uni.fav_list",
    "Yso.uni.favs_inline",
    "Yso.uni.fling",
    "Yso.uni.get_dest",
    "Yso.uni.go",
    "Yso.uni.help",
    "Yso.uni.is_open",
    "Yso.uni.list",
    "Yso.uni.set_dest",
    "Yso.uni.touch",
    "Yso.util.debug",
    "Yso.util.echo",
    "Yso.util.lower",
    "Yso.util.now",
    "Yso.util.safe",
    "Yso.util.tick_once",
    "Yso.util.trim",
  }
  F.static = F.static or {
    util = {
      "Yso.util.debug",
      "Yso.util.echo",
      "Yso.util.lower",
      "Yso.util.now",
      "Yso.util.safe",
      "Yso.util.tick_once",
      "Yso.util.trim",
    },
    state = {
      "Yso.state.bal_ready",
      "Yso.state.ent_fail",
      "Yso.state.ent_ready",
      "Yso.state.entities_missing",
      "Yso.state.eq_ready",
      "Yso.state.is_prone",
      "Yso.state.set_ent_ready",
      "Yso.state.set_entities_missing",
      "Yso.state.sync_vitals",
      "Yso.state.tgt_clear",
      "Yso.state.tgt_has_aff",
      "Yso.state.tgt_set_aff",
      "Yso.state.update_vitals",
    },
    locks = {
      "Yso.locks.bal_ready",
      "Yso.locks.ent_backoff",
      "Yso.locks.ent_ready",
      "Yso.locks.eq_ready",
      "Yso.locks.note_payload",
      "Yso.locks.note_send",
      "Yso.locks.on_ent_ready",
      "Yso.locks.ready",
      "Yso.locks.status",
      "Yso.locks.sync_vitals",
    },
    queue = {
      "Yso.queue.addclear",
      "Yso.queue.addclearfull",
      "Yso.queue.bal_clear",
      "Yso.queue.class_clear",
      "Yso.queue.clear",
      "Yso.queue.commit",
      "Yso.queue.emit",
      "Yso.queue.eq_clear",
      "Yso.queue.free",
      "Yso.queue.list",
      "Yso.queue.push",
      "Yso.queue.raw",
      "Yso.queue.replace",
      "Yso.queue.stage",
    },
    emit = {
      "Yso.emit",
      "Yso.lanes.normalize",
    },
    pulse = {
      "Yso.pulse._flush_inner",
      "Yso.pulse.debug",
      "Yso.pulse.enable",
      "Yso.pulse.entity_ack",
      "Yso.pulse.flush",
      "Yso.pulse.is_ready",
      "Yso.pulse.kick",
      "Yso.pulse.queue",
      "Yso.pulse.register",
      "Yso.pulse.send_bal",
      "Yso.pulse.send_entity",
      "Yso.pulse.send_eq",
      "Yso.pulse.send_free",
      "Yso.pulse.set_ready",
      "Yso.pulse.stop",
      "Yso.pulse.unregister",
      "Yso.pulse.wake",
    },
    trace = {
      "Yso.trace.dump",
      "Yso.trace.echo",
      "Yso.trace.push",
    },
    diag = {
      "Yso.diag.echo",
      "Yso.diag.snapshot",
    },
    offense = {
      "Yso.off.coord.on_target_leap",
      "Yso.off.oc.attack_eqonly",
      "Yso.off.oc.clear_sight",
      "Yso.off.oc.dmg.attack_cycle",
      "Yso.off.oc.dmg.conditions_logic",
      "Yso.off.oc.dmg.mark_tumble",
      "Yso.off.oc.dmg.pause",
      "Yso.off.oc.dmg.resume",
      "Yso.off.oc.dmg.start",
      "Yso.off.oc.dmg.status",
      "Yso.off.oc.dmg.stop",
      "Yso.off.oc.dmg.toggle",
      "Yso.off.oc.dmg.utility_logic",
      "Yso.off.oc.duel_limbs._loop",
      "Yso.off.oc.duel_limbs.start",
      "Yso.off.oc.duel_limbs.stop",
      "Yso.off.oc.duel_limbs.tick",
      "Yso.off.oc.duel_limbs.toggle",
      "Yso.off.oc.ensure_chimera_ready",
      "Yso.off.oc.get_ai",
      "Yso.off.oc.get_mode",
      "Yso.off.oc.get_tarot",
      "Yso.off.oc.need_sight",
      "Yso.off.oc.off",
      "Yso.off.oc.on",
      "Yso.off.oc.phase",
      "Yso.off.oc.queue_attend_if_needed",
      "Yso.off.oc.request_sight",
      "Yso.off.oc.set_ai",
      "Yso.off.oc.set_ent_mode",
      "Yso.off.oc.set_entity_key",
      "Yso.off.oc.set_entity_word",
      "Yso.off.oc.set_instill_mode",
      "Yso.off.oc.set_mode",
      "Yso.off.oc.set_target",
      "Yso.off.oc.set_tarot",
      "Yso.off.oc.sg_entity_cmd_for_aff",
      "Yso.off.oc.sg_pick_missing_aff",
      "Yso.off.oc.softscore",
      "Yso.off.oc.tick",
      "Yso.off.oc.toggle",
      "Yso.off.oc.toggle_ai",
      "Yso.off.oc.toggle_tarot",
      "Yso.off.oc.try_kelp_bury",
      "Yso.off.oc.try_softlock_setup",
    },
    occultist_intel = {
      "Yso.occ.aura_begin",
      "Yso.occ.aura_finalize",
      "Yso.occ.aura_get",
      "Yso.occ.aura_need_attend",
      "Yso.occ.aura_seen",
      "Yso.occ.clock.disable",
      "Yso.occ.clock.firelord_ack",
      "Yso.occ.clock.macro",
      "Yso.occ.clock.plan_and_fire",
      "Yso.occ.clock.tick",
      "Yso.occ.clock.toggle",
      "Yso.occ.clock_dry_test_limb",
      "Yso.occ.entities.get",
      "Yso.occ.entities.set",
      "Yso.occ.getDom",
      "Yso.occ.getDomById",
      "Yso.occ.is_cleansed",
      "Yso.occ.listDomByRole",
      "Yso.occ.mark_aura_restored",
      "Yso.occ.mark_cleansed",
      "Yso.occ.queue_readaura",
      "Yso.occ.readaura_is_ready",
      "Yso.occ.set_readaura_ready",
      "Yso.occ.set_target_mana_pct",
      "Yso.occ.truebook._begin_refresh",
      "Yso.occ.truebook._commit_refresh",
      "Yso.occ.truebook.add",
      "Yso.occ.truebook.can_utter",
      "Yso.occ.truebook.get",
      "Yso.occ.truebook.load",
      "Yso.occ.truebook.save",
      "Yso.occ.truebook.set",
    },
    aura_wrappers = {
      "Yso.blind",
      "Yso.caloric",
      "Yso.cloak",
      "Yso.deaf",
      "Yso.frost",
      "Yso.insomnia",
      "Yso.kola",
      "Yso.levitation",
      "Yso.speed",
    },
    shield = {
      "Yso.shield.is_up",
      "Yso.shield.mark_block",
      "Yso.shield.set",
    },
    room = {
      "Yso.room.has",
    },
    targeting = {
      "Yso.target_is_valid",
      "Yso.targeting._maybe_import_global",
      "Yso.targeting.clear",
      "Yso.targeting.get",
      "Yso.targeting.lock",
      "Yso.targeting.set",
      "Yso.targeting.unlock",
      "Yso.tgt.aff_cure",
      "Yso.tgt.aff_gain",
      "Yso.tgt.can_hear",
      "Yso.tgt.can_see",
      "Yso.tgt.drop",
      "Yso.tgt.get",
      "Yso.tgt.get_mana_pct",
      "Yso.tgt.has_aff",
      "Yso.tgt.has_mindseye",
      "Yso.tgt.lock_status",
      "Yso.tgt.note_target_herb",
      "Yso.tgt.note_tree_touch",
      "Yso.tgt.set_mana_pct",
      "Yso.tgt.set_mindseye",
    },
    curing = {
      "Yso.curing.adapters.emergency",
      "Yso.curing.adapters.game_curing_off",
      "Yso.curing.adapters.game_curing_on",
      "Yso.curing.adapters.lower_aff",
      "Yso.curing.adapters.raise_aff",
      "Yso.curing.adapters.set_aff_prio",
      "Yso.curing.adapters.use_profile",
      "Yso.curing.emergency",
      "Yso.curing.game_curing_off",
      "Yso.curing.game_curing_on",
      "Yso.curing.init",
      "Yso.curing.lower_aff",
      "Yso.curing.raise_aff",
      "Yso.curing.set_aff_prio",
      "Yso.curing.set_mode",
      "Yso.curing.status",
      "Yso.curing.toggle",
      "Yso.curing.toggle_debug",
      "Yso.curing.use_profile",
    },
    skillset_ref = {
      "Yso.occultist.aff_lanes",
      "Yso.occultist.aff_sources",
      "Yso.occultist.affs_by_lane",
      "Yso.occultist.build_affcap",
      "Yso.occultist.getOccultismSkill",
      "Yso.occultist.getTarot",
      "Yso.occultist.isOccultismOffense",
      "Yso.occultist.isTarotOffense",
      "Yso.occultist.listOccultismByRole",
      "Yso.occultist.listTarotByRole",
    },
    sim = {
      "Yso.sim._bak.sendAll_wrap",
      "Yso.sim._bak.send_wrap",
      "Yso.sim.report",
      "Yso.sim.reset",
      "Yso.sim.run",
      "Yso.sim.set_cure",
      "Yso.sim.start",
      "Yso.sim.status",
      "Yso.sim.step",
      "Yso.sim.stop",
    },
    learn = {
      "Yso.learn.debug_one",
      "Yso.learn.note_attempt",
      "Yso.learn.probe_due",
      "Yso.learn.quick_prob",
      "Yso.learn.samples",
      "Yso.learn.should_deprioritize",
      "Yso.learn.tick",
    },
    vitals_time = {
      "Yso.is_slowtime",
      "Yso.note_sluggish",
      "Yso.now",
    },
    fnref = {
      "Yso.fnref.echo",
      "Yso.fnref.walk",
    },
    misc_Orchestrator = {
      "Yso.Orchestrator.register",
      "Yso.Orchestrator.run",
      "Yso.Orchestrator.select",
      "Yso.Orchestrator.wake",
    },
    misc__req = {
      "Yso._req.try",
    },
    misc_ak = {
      "Yso.ak.adapters.pull_full_state",
      "Yso.ak.any",
      "Yso.ak.count",
      "Yso.ak.cure",
      "Yso.ak.gain",
      "Yso.ak.has",
      "Yso.ak.init",
      "Yso.ak.list_affs",
      "Yso.ak.set_target",
      "Yso.ak.status",
      "Yso.ak.sync_from_ak",
      "Yso.ak.target",
      "Yso.ak.toggle_debug",
    },
    misc_aliases = {
      "Yso.aliases.register",
    },
    misc_bus = {
      "Yso.bus.emit",
      "Yso.bus.on",
    },
    misc_clear_target = {
      "Yso.clear_target",
    },
    misc_core = {
      "Yso.core._req.try",
      "Yso.core.boot",
      "Yso.core.ensure_aliases",
      "Yso.core.kick",
      "Yso.core.load",
      "Yso.core.reload",
    },
    misc_debug = {
      "Yso.debug.snapshot.take",
      "Yso.debug.trace.is_on",
      "Yso.debug.trace.log",
      "Yso.debug.trace.set",
    },
    misc_deleteFull = {
      "Yso.deleteFull",
    },
    misc_dom = {
      "Yso.dom.abomination_up",
      "Yso.dom.has_ent",
      "Yso.dom.orbdef.cmd",
      "Yso.dom.orbdef.on_down",
      "Yso.dom.orbdef.on_gmcp_add",
      "Yso.dom.orbdef.on_gmcp_remove",
      "Yso.dom.orbdef.on_up",
      "Yso.dom.orbdef.remaining",
      "Yso.dom.orbdef.start",
      "Yso.dom.orbdef.stop",
      "Yso.dom.pathfinder_available",
      "Yso.dom.pathfinder_go_home",
      "Yso.dom.pathfinder_home_string",
      "Yso.dom.pathfinder_set_ready",
    },
    misc_dop = {
      "Yso.dop.do_piridon_channel",
      "Yso.dop.do_piridon_util",
      "Yso.dop.do_tarot_fling",
      "Yso.dop.dom_echo",
      "Yso.dop.getTarget",
      "Yso.dop.handle",
      "Yso.dop.help",
      "Yso.dop.seek",
      "Yso.dop.setTarget",
    },
    misc_entourage_attack = {
      "Yso.entourage_attack",
    },
    misc_entourage_set_hostile = {
      "Yso.entourage_set_hostile",
    },
    misc_escape = {
      "Yso.escape.press",
    },
    misc_fool = {
      "Yso.fool.mark_diag_pending",
      "Yso.fool.on_vitals",
      "Yso.fool.set_cd",
      "Yso.fool.set_min_affs",
      "Yso.fool.toggle_auto",
    },
    misc_get_target = {
      "Yso.get_target",
    },
    misc_log = {
      "Yso.log.error",
      "Yso.log.info",
      "Yso.log.warn",
    },
    misc_loyals_attack = {
      "Yso.loyals_attack",
    },
    misc_magician = {
      "Yso.magician.on_vitals",
      "Yso.magician.queue_self",
      "Yso.magician.queue_target",
      "Yso.magician.set_hp_min",
      "Yso.magician.set_mp_threshold",
      "Yso.magician.toggle_auto",
    },
    misc_mind_focused = {
      "Yso.mind_focused",
    },
    misc_mode = {
      "Yso.mode.apply_profile",
      "Yso.mode.auto.bump_combat",
      "Yso.mode.auto.clear_force",
      "Yso.mode.auto.dump_sniff",
      "Yso.mode.auto.force_combat",
      "Yso.mode.echo",
      "Yso.mode.is_combat",
      "Yso.mode.is_hunt",
      "Yso.mode.on_disengage",
      "Yso.mode.on_engage",
      "Yso.mode.set",
      "Yso.mode.toggle",
    },
    misc_oc = {
      "Yso.oc.ak.get_aff_score",
      "Yso.oc.ak.refresh_lists_from_AK",
      "Yso.oc.ak.scores.enlighten",
      "Yso.oc.ak.scores.ginseng",
      "Yso.oc.ak.scores.golden",
      "Yso.oc.ak.scores.kelp",
      "Yso.oc.ak.scores.mental",
      "Yso.oc.ak.scores.trample",
      "Yso.oc.ak.scores.whisper",
      "Yso.oc.cures.affs_in_eat_bucket",
      "Yso.oc.cures.bucket_score",
      "Yso.oc.cures.dump",
      "Yso.oc.cures.get",
      "Yso.oc.cures.ginseng_score",
      "Yso.oc.cures.golden_score",
      "Yso.oc.cures.kelp_score",
      "Yso.oc.cures.rebuild",
      "Yso.predict.cure.dump",
      "Yso.predict.cure.next",
      "Yso.predict.cure.observe",
      "Yso.predict.toggle",
      "Yso.predict.wire",
      "Yso.oc.map.rebuild_by_aff",
      "Yso.oc.prone.softscore",
      "Yso.oc.prone.step",
      "Yso.oc.prone.try_hook",
      "Yso.oc.prone.want_anorexia",
    },
    misc_oclocks = {
      "Yso.oclocks.echo",
      "Yso.oclocks.print",
      "Yso.oclocks.recommend_mode",
      "Yso.oclocks.status",
    },
    misc_pacts = {
      "Yso.pacts.begin_capture",
      "Yso.pacts.finish_capture",
      "Yso.pacts.get_low",
      "Yso.pacts.get_missing",
      "Yso.pacts.parse_line",
      "Yso.pacts.report_alerts",
      "Yso.pacts.report_low",
    },
    misc_priestess = {
      "Yso.priestess.on_vitals",
      "Yso.priestess.queue_self",
      "Yso.priestess.queue_target",
      "Yso.priestess.set_threshold",
      "Yso.priestess.toggle_auto",
    },
    misc_primebond = {
      "Yso.primebond.request",
    },
    misc_probe = {
      "Yso.probe.both",
      "Yso.probe.heartstone",
      "Yso.probe.simulacrum",
    },
    misc_radianceAlert = {
      "Yso.radianceAlert.banner",
      "Yso.radianceAlert.center",
      "Yso.radianceAlert.fire",
      "Yso.radianceAlert.sound",
    },
    misc_reload = {
      "Yso.reload",
    },
    misc_resolve_target = {
      "Yso.resolve_target",
    },
    misc_room_has = {
      "Yso.room_has",
    },
    misc_self = {
      "Yso.self.has_aff",
      "Yso.self.is_paralyzed",
    },
    misc_set_loyals_attack = {
      "Yso.set_loyals_attack",
    },
    misc_set_mind_focused = {
      "Yso.set_mind_focused",
    },
    misc_set_readaura_ready = {
      "Yso.set_readaura_ready",
    },
    misc_set_soulmaster_ready = {
      "Yso.set_soulmaster_ready",
    },
    misc_set_sycophant_ready = {
      "Yso.set_sycophant_ready",
    },
    misc_set_target = {
      "Yso.set_target",
    },
    misc_set_tree_ready = {
      "Yso.set_tree_ready",
    },
    misc_set_tree_touched = {
      "Yso.set_tree_touched",
    },
    misc_shutdown = {
      "Yso.shutdown",
    },
    misc_soulmaster_ready = {
      "Yso.soulmaster_ready",
    },
    misc_sycophant_ready = {
      "Yso.sycophant_ready",
    },
    misc_tarot = {
      "Yso.tarot.devil_active",
      "Yso.tarot.devil_down",
      "Yso.tarot.devil_up",
    },
    misc_travel = {
      "Yso.travel.alias",
      "Yso.travel.go",
      "Yso.travel.help",
      "Yso.travel.plan",
      "Yso.travel.providers.map.available",
      "Yso.travel.providers.map.execute",
      "Yso.travel.providers.map.resolve",
      "Yso.travel.providers.routes.available",
      "Yso.travel.providers.routes.execute",
      "Yso.travel.providers.routes.resolve",
      "Yso.travel.providers.universe.available",
      "Yso.travel.providers.universe.execute",
      "Yso.travel.providers.universe.resolve",
      "Yso.travel.providers_status",
      "Yso.travel.route_add_room",
      "Yso.travel.route_add_uni",
      "Yso.travel.route_add_walk",
      "Yso.travel.route_del",
      "Yso.travel.route_list",
    },
    misc_tree_ready = {
      "Yso.tree_ready",
    },
    misc_tree_touched = {
      "Yso.tree_touched",
    },
    misc_uni = {
      "Yso.uni.alias",
      "Yso.uni.fav_add",
      "Yso.uni.fav_del",
      "Yso.uni.fav_list",
      "Yso.uni.favs_inline",
      "Yso.uni.fling",
      "Yso.uni.get_dest",
      "Yso.uni.go",
      "Yso.uni.help",
      "Yso.uni.is_open",
      "Yso.uni.list",
      "Yso.uni.set_dest",
      "Yso.uni.touch",
    },
  }
  local function _get(path)
    if type(path) ~= "string" then return nil end
    local t = _G
    for seg in path:gmatch("[^%.]+") do
      if type(t) ~= "table" then return nil end
      t = t[seg]
      if t == nil then return nil end
    end
    return t
  end
  function F.exists(path) return type(_get(path)) == "function" end
  function F.walk(root, prefix, out, seen)
    root = root or Yso
    prefix = prefix or "Yso"
    out = out or {}
    seen = seen or {}
    if type(root) ~= "table" then return out end
    if seen[root] then return out end
    seen[root] = true
    for k,v in pairs(root) do
      local key = tostring(k)
      if key:sub(1,1) ~= "_" then
        local p = prefix .. "." .. key
        if type(v) == "function" then
          out[#out+1] = p
        elseif type(v) == "table" and key ~= "fnref" then
          F.walk(v, p, out, seen)
        end
      end
    end
    table.sort(out)
    return out
  end
  local function _echo(s)
    if type(cecho) == "function" then cecho(s.."\n") else echo(s.."\n") end
  end
  function F.echo_static(cat)
    if not cat or cat == "" then
      local keys = {}
      for k,_ in pairs(F.static or {}) do keys[#keys+1] = k end
      table.sort(keys)
      _echo("<dim_grey>[Yso.fnref] categories: "..table.concat(keys, ", ").."<reset>")
      return keys
    end
    local lst = (F.static and F.static[cat]) or {}
    _echo(string.format("<dim_grey>[Yso.fnref] %s: %d<reset>", tostring(cat), #lst))
    for i=1,#lst do
      local p = lst[i]
      local ok = (F.exists(p) and "<green>✓<reset>" or "<red>✗<reset>")
      _echo("<dim_grey>  "..ok.." "..p.."<reset>")
    end
    return lst
  end
  function F.echo_runtime(n)
    n = tonumber(n) or 60
    local lst = F.walk()
    _echo("<dim_grey>[Yso.fnref] runtime functions: "..tostring(#lst).."<reset>")
    for i=1, math.min(n, #lst) do _echo("<dim_grey>  "..lst[i].."<reset>") end
    return lst
  end
end
