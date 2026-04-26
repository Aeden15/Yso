-- Auto-exported from Mudlet package script: AK+Legacy wiring
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso / Achaea Wiring
--  • Wires Yso.curing.adapters -> Legacy + game commands
--  • Wires Yso.ak -> AK1 / AK Tracker (affstrack + ak.check)
--  • Assumes:
--      - Legacy core is loaded (Prio/Deprio/UpdatePrios exist)
--      - AK Tracker.xml is loaded (affstrack, ak.check exist)
--      - Yso_curing_core + Yso_AK_core already loaded
--========================================================--

Yso        = Yso or {}
Yso.curing = Yso.curing or {}
Yso.ak     = Yso.ak or {}

------------------------------------------------------------
-- 0) SHIELD FALLBACK API (callable + compatibility aliases)
------------------------------------------------------------

local function _shield_key(target)
  target = tostring(target or ""):lower()
  target = target:gsub("^%s+", ""):gsub("%s+$", "")
  return target
end

local function _ak_targeted(target)
  local fn = rawget(_G, "IsTargetted")
  if type(fn) ~= "function" then return false end
  local ok, v = pcall(fn, tostring(target or ""))
  return ok and v == true
end

local function _shield_set(target, up, source)
  local key = _shield_key(target)
  if key == "" then return false end

  Yso._shield_by_target = Yso._shield_by_target or {}
  local state = (up == true)
  Yso._shield_by_target[key] = state
  Yso._shield_last_source = tostring(source or "")

  -- Mirror state into AK when available; AK remains primary source-of-truth.
  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    ak.defs = ak.defs or {}
    ak.defs.shield_by_target = ak.defs.shield_by_target or {}
    ak.defs.shield_by_target[key] = state

    if state then
      ak.defs.shield = true
    elseif _ak_targeted(target) then
      ak.defs.shield = false
    end
  end

  return state
end

local function _shield_up(target)
  local key = _shield_key(target)
  if key == "" then return false end

  local ak = rawget(_G, "ak")
  if type(ak) == "table" and type(ak.defs) == "table" then
    if type(ak.defs.shield_by_target) == "table" then
      local v = ak.defs.shield_by_target[key]
      if type(v) == "boolean" then
        Yso._shield_by_target = Yso._shield_by_target or {}
        Yso._shield_by_target[key] = v
        return v
      end
    end
    if type(ak.defs.shield) == "boolean" and _ak_targeted(target) then
      return ak.defs.shield == true
    end
  end

  local cache = Yso._shield_by_target
  if type(cache) == "table" and type(cache[key]) == "boolean" then
    return cache[key]
  end

  return false
end

local _shield_api = Yso.shield
if type(_shield_api) ~= "table" then
  _shield_api = {}
end

_shield_api.set = _shield_set
_shield_api.up = _shield_up
_shield_api.is_up = _shield_up

local _shield_mt = getmetatable(_shield_api) or {}
_shield_mt.__call = function(_, target)
  return _shield_up(target)
end
setmetatable(_shield_api, _shield_mt)
Yso.shield = _shield_api

------------------------------------------------------------
-- 1) CURING ADAPTERS -> LEGACY / GAME
------------------------------------------------------------

local function _cwire_echo(msg)
  if Yso.curing and Yso.curing.debug then
    cecho(string.format("<cyan>[Yso:CureWire] <reset>%s\n", msg))
  end
end

-- Ensure adapters table exists
Yso.curing.adapters = Yso.curing.adapters or {}
local C = Yso.curing.adapters

-- Toggle game-side CURING ON/OFF.
C.game_curing_on = function()
  if type(send) == "function" then
    send("curing on", false)
    _cwire_echo("sent: curing on")
  else
    _cwire_echo("wanted to send 'curing on' but send() is missing")
  end
end

C.game_curing_off = function()
  if type(send) == "function" then
    send("curing off", false)
    _cwire_echo("sent: curing off")
  else
    _cwire_echo("wanted to send 'curing off' but send() is missing")
  end
end

-- Raise an affliction priority via Legacy:
--  • Prefer Legacy's Prio(aff) helper (moves to slot 1).
--  • Fallback: raw CURING PRIORITY command.
C.raise_aff = function(aff)
  if not aff or aff == "" then return end
  aff = tostring(aff)

  if type(Prio) == "function" then
    Prio(aff)  -- Legacy: push to 1
    _cwire_echo("Legacy Prio("..aff..")")
  elseif type(send) == "function" then
    send(string.format("curing priority %s 1", aff), false)
    _cwire_echo("sent: curing priority "..aff.." 1")
  else
    _cwire_echo("cannot raise_aff("..aff.."): no Prio() or send()")
  end
end

-- Lower an affliction priority via Legacy:
--  • Prefer Legacy's Deprio(aff) helper (sets to 26).
--  • Fallback: raw CURING PRIORITY aff 26.
C.lower_aff = function(aff)
  if not aff or aff == "" then return end
  aff = tostring(aff)

  if type(Deprio) == "function" then
    Deprio(aff)
    _cwire_echo("Legacy Deprio("..aff..")")
  elseif type(send) == "function" then
    send(string.format("curing priority %s 26", aff), false)
    _cwire_echo("sent: curing priority "..aff.." 26")
  else
    _cwire_echo("cannot lower_aff("..aff.."): no Deprio() or send()")
  end
end

-- Explicitly set an aff's position:
--  • Prefer Legacy's Prio(aff, pos).
--  • Fallback: raw CURING PRIORITY aff pos.
C.set_aff_prio = function(aff, prio)
  if not aff or aff == "" then return end
  prio = tonumber(prio) or 1
  aff  = tostring(aff)

  if type(Prio) == "function" then
    Prio(aff, prio)
    _cwire_echo(string.format("Legacy Prio(%s, %d)", aff, prio))
  elseif type(send) == "function" then
    send(string.format("curing priority %s %d", aff, prio), false)
    _cwire_echo(string.format("sent: curing priority %s %d", aff, prio))
  else
    _cwire_echo("cannot set_aff_prio("..aff..","..tostring(prio)..")")
  end
end

-- Switch server-side curingset/profile:
--  • Legacy uses "curingset new legacy" + "curingset switch legacy"
--    on install, so we mirror that here.
C.use_profile = function(name)
  if not name or name == "" then return end
  name = tostring(name)

  if type(send) == "function" then
    send(string.format("curingset switch %s", name), false)
    _G.CurrentCureset = name
    _cwire_echo("sent: curingset switch "..name)
  else
    _cwire_echo("cannot use_profile("..name.."): send() missing")
  end
end

-- Tree policy bridge (phase-1 conservative scaffold).
-- aff_trigger: prioritize trigger behavior while under active pressure.
-- aff_count: fallback/default behavior.
C.set_tree_policy = function(mode, _ctx)
  mode = tostring(mode or ""):lower()
  if mode == "" then return end

  -- Keep wire-level behavior simple and non-destructive in phase one.
  -- Policy computes desired mode and the adapter exposes it for diagnostics.
  Yso.curing = Yso.curing or {}
  Yso.curing.tree_policy = mode
  _cwire_echo("tree policy -> " .. mode)
end

-- Emergency queue bridge used by serverside policy scaffolding.
C.queue_emergency = function(cmd, opts)
  cmd = tostring(cmd or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if cmd == "" then return false end

  opts = type(opts) == "table" and opts or {}
  local qtype = tostring(opts.qtype or "bal"):gsub("^%s+", ""):gsub("%s+$", "")
  if qtype == "" then qtype = "bal" end
  local idx = tonumber(opts.index)

  local line
  if idx and idx >= 1 then
    line = string.format("QUEUE INSERT %s %d %s", qtype, idx, cmd)
  else
    line = string.format("QUEUE ADD %s %s", qtype, cmd)
  end

  if type(send) ~= "function" then
    _cwire_echo("cannot queue_emergency: send() missing")
    return false
  end

  send(line, false)
  _cwire_echo("sent: " .. line)
  return true
end

-- Emergency hook is intentionally minimal; you can flesh this out later.
C.emergency = function(tag)
  tag = tostring(tag or "")
  if tag == "" then return end

  _cwire_echo("emergency("..tag..") called (no behaviour wired yet)")
  -- Example you might add later:
  -- if tag == "lockpanic" and type(send)=="function" then
  --   send("curing tree on", false)
  --   send("curing priority paralysis 1", false)
  --   _cwire_echo("lockpanic: raised paralysis + toggled tree")
  -- end
end

------------------------------------------------------------
-- 2) AK BRIDGE -> affstrack + ak.check
------------------------------------------------------------

Yso.ak         = Yso.ak or {}
Yso.ak.adapters = Yso.ak.adapters or {}
Yso.ak.threshold = Yso.ak.threshold or 100  -- score at/above this is "confirmed"

local function _akwire_echo(msg)
  if Yso.ak and Yso.ak.debug then
    cecho(string.format("<magenta>[Yso:AK-Bridge] <reset>%s\n", msg))
  end
end

local function _akwire_now()
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _canon_aff(aff)
  aff = tostring(aff or ""):lower()
  if aff == "" then return "" end
  if Yso and Yso.util and type(Yso.util.normalize_aff_name) == "function" then
    aff = Yso.util.normalize_aff_name(aff)
  elseif aff == "prefarar" then
    aff = "sensitivity"
  end
  return aff
end

-- Build a { aff_name = true } map from AK's affstrack.score.
local function _aff_map_from_ak()
  local map = {}

  if not affstrack or type(affstrack) ~= "table" or type(affstrack.score) ~= "table" then
    return map
  end

  local threshold = Yso.ak.threshold or 100

  for name, score in pairs(affstrack.score) do
    if type(name) == "string" and type(score) == "number" then
      if score >= threshold then
        map[_canon_aff(name)] = true
      end
    end
  end

  return map
end

-- Helper to count keys in a table.
local function _tbl_count(t)
  local c = 0
  for _ in pairs(t) do c = c + 1 end
  return c
end

-- Override adapters.pull_full_state so Yso.ak.sync_from_ak() works.
Yso.ak.adapters.pull_full_state = function()
  local m = _aff_map_from_ak()
  _akwire_echo("pull_full_state() -> ".._tbl_count(m).." affs from AK")
  return m
end

-- Let Yso tell AK when the combat target changes (resets AK's internal state).
Yso.ak.adapters.on_target_change = function(name)
  name = tostring(name or "")
  if type(ak) == "table" then
    -- Common AK reset helper.
    if type(ak.deleteFull) == "function" then
      pcall(ak.deleteFull)
    end
    -- Some variants expose ak.target.set
    if type(ak.target) == "table" and type(ak.target.set) == "function" and name ~= "" then
      pcall(ak.target.set, name)
    end
  end
  _akwire_echo("on_target_change -> "..name)
end


-- Optional: keep on_target_change as-is if you've wired it already,
-- otherwise leave the stub from the skeleton.

------------------------------------------------------------
-- Override query helpers to read AK live
------------------------------------------------------------

function Yso.ak.has(aff)
  if not aff or aff == "" then return false end
  aff = _canon_aff(aff)

  -- Prefer AK's check helper if it exists (handles venom->aff mapping).
  if ak and type(ak.check) == "function" then
    if ak.check(aff, Yso.ak.threshold or 100) then return true end
    if aff == "sensitivity" and ak.check("prefarar", Yso.ak.threshold or 100) then return true end
    return false
  end

  -- Fallback: direct inspect affstrack.score.
  if affstrack and affstrack.score and type(affstrack.score[aff]) == "number" then
    return affstrack.score[aff] >= (Yso.ak.threshold or 100)
  end
  if aff == "sensitivity" and affstrack and affstrack.score and type(affstrack.score.prefarar) == "number" then
    return affstrack.score.prefarar >= (Yso.ak.threshold or 100)
  end

  return false
end

function Yso.ak.count(affs)
  if not affs then return 0 end
  local list = {}

  if type(affs) == "string" then
    for part in affs:gmatch("([^/]+)") do
      list[#list+1] = part:lower()
    end
  elseif type(affs) == "table" then
    for _, a in ipairs(affs) do
      list[#list+1] = tostring(a):lower()
    end
  else
    return 0
  end

  local n = 0
  for _, a in ipairs(list) do
    if Yso.ak.has(a) then n = n + 1 end
  end
  return n
end

function Yso.ak.any(affs, n)
  n = tonumber(n) or 1
  if n <= 0 then return true end
  return Yso.ak.count(affs) >= n
end

-- Returns a sorted list of current confirmed affs from AK.
function Yso.ak.list_affs()
  local map = _aff_map_from_ak()
  local out = {}
  for a,_ in pairs(map) do
    out[#out+1] = a
  end
  table.sort(out)
  return out
end

-- Keep Yso.ak.enemy.* in sync for UI / status if you want.
function Yso.ak.sync_from_ak()
  Yso.ak.enemy = Yso.ak.enemy or { name = "", affs = {}, last_gain = {}, last_cure = {} }

  local state = _aff_map_from_ak()
  Yso.ak.enemy.affs = {}

  for aff,_ in pairs(state) do
    local canon = _canon_aff(aff)
    Yso.ak.enemy.affs[canon]      = true
    Yso.ak.enemy.last_gain[canon] = Yso.ak.enemy.last_gain[canon] or _akwire_now()
  end
_akwire_echo("sync_from_ak(): "..tostring(#Yso.ak.list_affs()).." affs synced from AK")
end

_akwire_echo("Yso / Achaea wiring loaded (Legacy + AK bridge)")
--========================================================--
