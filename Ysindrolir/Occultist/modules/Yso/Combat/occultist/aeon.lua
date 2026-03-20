--========================================================--
-- yso_aeon.lua
-- Central AEON module (Achaea / Occultist / Yso)
--
-- Purpose:
--   Provide a single, shared AEON controller that routes can "request"
--   and then call tick() opportunistically.
--
-- Mechanics encoded (per project decisions):
--   • AEON sources:
--       - Tarot: outd aeon && fling aeon at <tgt>   (BAL)  [MUST be solo vs EQ/ENTITY]
--       - Entropy: compel <tgt> entropy             (EQ)   [assume prereqs met by caller]
--       - Truename: utter truename <tgt>            (EQ)   [FINISHER-only]
--   • SPEED gating:
--       - Authoritative truth via READAURA (AK)
--       - If speed is up: strip via PINCHAURA <tgt> speed (EQ)
--       - Opponent often SIPs to restore speed after a verified 3s delay.
--         We arm a 3s "speed-down" window on SIP *only if* we pinchaura'd
--         recently (<= 6s).  (Option A)
--   • Hold condition (for AEON to be meaningful):
--       - anorexia + slickness + (shyness OR any mental)
--       - We prefer building shyness via DEVOLVE when needed.
--
-- Notes:
--   • This module does nothing unless a route calls request().
--   • tick() emits at most one command (via Yso.emit) and returns true if it did.
--========================================================--

Yso = Yso or {}
Yso.occ = Yso.occ or {}
Yso.occ.aeon = Yso.occ.aeon or {}

local A = Yso.occ.aeon

A.cfg = A.cfg or {
  enabled = true,
  debug = false,

  -- Aura speed freshness required for decisions (seconds)
  speed_ttl_s = 3.0,

  -- Pinchaura anti-spam cooldown (seconds)
  pinch_cd_s = 4.2,

  -- Option A: only arm sip-window if pinchaura was recent (seconds)
  pinch_recent_s = 6.0,

  -- Verified sip-delay until speed returns (seconds)
  sip_speed_return_s = 3.0,

  -- After pinchaura, assume speed is down briefly (seconds)
  assume_down_after_pinch_s = 6.0,

  -- COMPEL internal cooldown is unknown; apply a conservative local throttle.
  compel_cd_s = 1.5,
}

A.state = A.state or { by = {} }

-- ---------- small helpers ----------
local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _lc(s) return _trim(s):lower() end

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _dbg(msg)
  if A.cfg.debug and type(cecho) == "function" then
    cecho(string.format("<dim_grey>[Yso:AEON] <reset>%s\n", tostring(msg)))
  end
end

local function _tkey(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return nil end
  return tgt:lower()
end

local function _get(tgt)
  local k = _tkey(tgt)
  if not k then return nil end
  A.state.by[k] = A.state.by[k] or {
    tgt = tgt,
    requested = false,
    finisher = false,
    last_pinchaura = 0,
    speed_down_until = 0,
    last_action = "",
    last_compel = 0,
  }
  A.state.by[k].tgt = tgt
  return A.state.by[k]
end

local function _eq_ready()
  if Yso.state and type(Yso.state.eq_ready) == "function" then
    local ok, v = pcall(Yso.state.eq_ready)
    if ok then return v == true end
  end
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(v.eq or v.equilibrium or "") == "1" or v.eq == true or v.equilibrium == true
end

local function _bal_ready()
  if Yso.state and type(Yso.state.bal_ready) == "function" then
    local ok, v = pcall(Yso.state.bal_ready)
    if ok then return v == true end
  end
  local v = (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
  return tostring(v.bal or v.balance or "") == "1" or v.bal == true or v.balance == true
end

local function _aff_score(aff)
  if Yso.oc and Yso.oc.ak and type(Yso.oc.ak.get_aff_score) == "function" then
    local ok, v = pcall(Yso.oc.ak.get_aff_score, aff)
    if ok then return tonumber(v) or 0 end
  end
  return 0
end

local function _stuck(aff)
  return _aff_score(aff) >= 100
end

local MENTALS = {
  "hallucinations",
  "dementia",
  "recklessness",
  "confusion",
  "stupidity",
  "paranoia",
}

local function _has_any_mental()
  for i = 1, #MENTALS do
    if _stuck(MENTALS[i]) then return true end
  end
  return false
end

local function _hold_ok()
  if not _stuck("anorexia") then return false end
  if not _stuck("slickness") then return false end
  if _stuck("shyness") then return true end
  return _has_any_mental()
end

local function _aura_snap(tgt)
  if not (Yso.occ and Yso.occ.aura) then return nil end
  local t = tostring(tgt or "")
  local a = Yso.occ.aura[t] or Yso.occ.aura[t:lower()]
  return (type(a) == "table") and a or nil
end

-- Returns: true (speed up), false (speed down), nil (unknown/stale)
local function _speed_fresh(tgt)
  local a = _aura_snap(tgt)
  if not a then return nil end
  local ts = tonumber(a.ts or 0) or 0
  if ts <= 0 then return nil end
  if (_now() - ts) > (tonumber(A.cfg.speed_ttl_s or 3.0) or 3.0) then
    return nil
  end
  return (a.speed == true)
end

local function _emit(payload, opts)
  if not (Yso.emit and type(Yso.emit) == "function") then return false end
  return Yso.emit(payload, opts or {}) == true
end

local function _can_utter(tgt)
  if not (Yso.occ and Yso.occ.truebook and type(Yso.occ.truebook.can_utter) == "function") then
    return false
  end
  local ok, v = pcall(Yso.occ.truebook.can_utter, tgt)
  return ok and v == true
end

-- ---------- public API ----------

function A.request(tgt, opts)
  opts = opts or {}
  local S = _get(tgt)
  if not S then return false end
  S.requested = true
  S.finisher = (opts.finisher == true)
  return true
end

function A.cancel(tgt)
  local S = _get(tgt)
  if not S then return false end
  S.requested = false
  S.finisher = false
  S.last_action = ""
  return true
end

function A.is_requested(tgt)
  local S = _get(tgt)
  return (S and S.requested == true) or false
end

-- Called by a sip trigger (vial text varies). Option A gating is applied here.
function A.on_sip(who)
  who = _trim(who)
  if who == "" then return false end

  -- Only react for the current combat target.
  if type(oc_isCurrentTarget) == "function" then
    local ok, cur = pcall(oc_isCurrentTarget, who)
    if ok and not cur then return false end
  end

  local S = _get(who)
  if not (S and S.requested) then return false end

  local now = _now()
  local recent = (now - (tonumber(S.last_pinchaura or 0) or 0)) <= (tonumber(A.cfg.pinch_recent_s or 6.0) or 6.0)
  if not recent then return false end

  -- Verified: sip -> speed returns in 3s.
  local until_t = now + (tonumber(A.cfg.sip_speed_return_s or 3.0) or 3.0)
  S.speed_down_until = math.max(tonumber(S.speed_down_until or 0) or 0, until_t)
  _dbg(string.format("SIP window armed for %s (down_until=%.2f)", who, S.speed_down_until))
  return true
end

-- One-step tick: emits at most one command, returns true if it emitted.
function A.tick(tgt, reasons)
  if A.cfg.enabled ~= true then return false end
  tgt = _trim(tgt)
  if tgt == "" then return false end

  local S = _get(tgt)
  if not (S and S.requested) then return false end

  -- If aeon is already on target, we're done.
  if _stuck("aeon") then
    S.requested = false
    S.finisher = false
    return false
  end

  local now = _now()

  -- 1) Build/maintain hold: anorexia + slickness + (shyness OR any mental)
  if not _stuck("anorexia") then
    if _eq_ready() then
      _dbg("build: regress (anorexia)")
      return _emit({ eq = ("regress %s"):format(tgt) }, { reason = "aeon:build_anorexia" })
    end
    return false
  end

  if not _stuck("slickness") then
    if _eq_ready() then
      _dbg("build: instill slickness")
      return _emit({ eq = ("instill %s with slickness"):format(tgt) }, { reason = "aeon:build_slickness" })
    end
    return false
  end

  if not (_stuck("shyness") or _has_any_mental()) then
    -- Prefer devolve for shyness (EQ).
    if _eq_ready() then
      _dbg("build: devolve (shyness)")
      return _emit({ eq = ("devolve %s"):format(tgt) }, { reason = "aeon:build_shyness" })
    end
    -- If EQ not ready, do nothing; other routes can keep pressure.
    return false
  end

  -- 2) Ensure SPEED is down (fresh aura truth or local assumed-down windows)
  local speed = _speed_fresh(tgt) -- true|false|nil
  local assumed_down = (tonumber(S.speed_down_until or 0) or 0) > now

  if speed == nil and not assumed_down then
    -- Need READAURA (authoritative)
    if _eq_ready() and Yso.occ and type(Yso.occ.readaura_is_ready) == "function" and Yso.occ.readaura_is_ready() then
      _dbg("need speed -> readaura")
      -- Mark aura pending for our own snapshot collector.
      if type(Yso.occ.aura_begin) == "function" then pcall(Yso.occ.aura_begin, tgt) end
      if type(Yso.occ.set_readaura_ready) == "function" then pcall(Yso.occ.set_readaura_ready, false, "sent") end
      return _emit({ eq = ("readaura %s"):format(tgt) }, { reason = "aeon:readaura" })
    end
    return false
  end

  if speed == true and not assumed_down then
    -- Speed is up: strip via pinchaura (anti-spam)
    local cd = tonumber(A.cfg.pinch_cd_s or 4.2) or 4.2
    local last = tonumber(S.last_pinchaura or 0) or 0
    if _eq_ready() and (now - last) >= cd then
      S.last_pinchaura = now
      S.speed_down_until = now + (tonumber(A.cfg.assume_down_after_pinch_s or 6.0) or 6.0)
      _dbg("pinchaura: speed")
      return _emit({ eq = ("pinchaura %s speed"):format(tgt) }, { reason = "aeon:pinchaura_speed" })
    end
    return false
  end

  -- At this point, speed is either confirmed down or we are inside the assumed-down window.
  local speed_down = (speed == false) or assumed_down
  if not speed_down then return false end

  -- 3) Apply AEON (dynamic: prefer BAL Aeon if ready; else EQ entropy)
  if S.finisher == true and _eq_ready() and _can_utter(tgt) then
    _dbg("apply: utter truename (finisher)")
    return _emit({ eq = ("utter truename %s"):format(tgt) }, { reason = "aeon:truename" })
  end

  if _bal_ready() then
    -- AEON fling must be solo vs EQ/ENTITY. BAL-only payload is allowed: outd && fling.
    _dbg("apply: tarot aeon (solo)")
    return _emit({ bal = ("outd aeon&&fling aeon at %s"):format(tgt) }, { reason = "aeon:tarot", solo = true, wake_lane = "bal" })
  end

  -- If BAL tarot is not available, try entropy via COMPEL (special/free).
  -- Compel requires BOTH EQ+BAL ready but consumes neither.
  if _eq_ready() and _bal_ready() then
    local cd = tonumber(A.cfg.compel_cd_s or 1.5) or 1.5
    local last = tonumber(S.last_compel or 0) or 0
    if (now - last) >= cd then
      S.last_compel = now
      _dbg("apply: compel entropy")
      return _emit({ free = ("compel %s entropy"):format(tgt) }, { reason = "aeon:entropy" })
    end
  end

  return false
end

-- Convenience: request+tick for current target.
function A.tick_current(reasons, opts)
  opts = opts or {}
  local tgt = ""
  if type(Yso.get_target) == "function" then tgt = _trim(Yso.get_target() or "") end
  if tgt == "" and type(Yso.target) == "string" then tgt = _trim(Yso.target) end
  if tgt == "" then return false end
  A.request(tgt, opts)
  return A.tick(tgt, reasons)
end

--========================================================--
