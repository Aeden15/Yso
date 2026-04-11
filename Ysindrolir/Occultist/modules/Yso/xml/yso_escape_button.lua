--========================================================--
-- yso_escape_button.lua  (DROP-IN)  [REFRESHED for current Yso]
-- Purpose:
--   • F5 “escape” handler for Achaea (Yso namespace)
--   • Respects current Yso command separator (Yso.sep; default "&&")
--   • Universe TOUCH defaults to Newthera
--   • Prefers Yso self-aff tracker, with compatibility fallbacks
--   • Uses Yso.queue.*_clear (or addclear) when available; otherwise sends directly
--
-- Priority:
--   1) Universe  (touch if up; else fling + touch)
--   2) Hermit    (only if activated/ready)
--   3) Pathfinder HOME
--   4) Astral fallback (optional)
--
-- Safety gates:
--   • NEVER fires if prone/fallen OR paralysis/paresis
--   • Universe/Hermit additionally require NOT webbed/bound and at least one unbroken arm
--   • Only fires if HP% < threshold OR MP% < threshold
--========================================================--

_G.Yso = _G.Yso or _G.yso or {}
_G.yso = _G.Yso
local Yso = _G.Yso

Yso.escape = Yso.escape or {}
local E = Yso.escape

-- ---------------- configuration (non-destructive defaults) ----------------
E.cfg = E.cfg or {}

if E.cfg.sep == nil or E.cfg.sep == "" then
  E.cfg.sep =
    (Yso and Yso.sep)
    or (Yso and Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep))
    or "&&"
end

if E.cfg.echo == nil then E.cfg.echo = true end
if E.cfg.threshold_pct == nil then E.cfg.threshold_pct = 75 end

-- Default Universe destination: Newthera (closest “safe city” target per your note)
if E.cfg.universe_touch == nil or E.cfg.universe_touch == "" then
  E.cfg.universe_touch = "newthera"
end

if E.cfg.hermit_tag == nil then E.cfg.hermit_tag = "" end
if E.cfg.astral_cmd == nil then E.cfg.astral_cmd = "" end

-- ---------------- runtime state ----------------
E.state = E.state or {
  uni_pending = false,
  uni_up = false,
  uni_up_since = 0,
  uni_last_duration = 0,

  hermit_ready = false,
  last_press = 0,
}

-- ---------------- tiny helpers ----------------
local function _now()
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _vitals()
  return (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
end

local function _pct(cur, max)
  cur, max = tonumber(cur or 0), tonumber(max or 0)
  if max <= 0 then return 0 end
  return (cur / max) * 100
end

local function _current_class()
  if Yso and Yso.classinfo and type(Yso.classinfo.get) == "function" then
    return Yso.classinfo.get()
  end
  local cls = gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class
  if (type(cls) ~= "string" or cls == "") and type(Yso.class) == "string" then cls = Yso.class end
  return tostring(cls or "")
end

local function _is_occultist()
  if Yso and Yso.classinfo and type(Yso.classinfo.is_occultist) == "function" then
    return Yso.classinfo.is_occultist()
  end
  return _current_class() == "Occultist"
end

local function _cecho(msg)
  if E.cfg.echo and type(cecho) == "function" then
    cecho("<aquamarine>[Yso] " .. tostring(msg) .. "<reset>\n")
  end
end

local function _send_line(cmd)
  if not cmd or cmd == "" then return end
  if type(send) == "function" then
    send(cmd, false)
  end
end

-- Split and send a compound payload using the configured separator
local function _send_compound(body)
  body = tostring(body or "")
  if body == "" then return end

  local sep =
    (E.cfg and E.cfg.sep)
    or (Yso and Yso.sep)
    or (Yso and Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep))
    or "&&"
  local parts = nil
  if Yso and Yso.util and type(Yso.util.split) == "function" then
    local ok, out = pcall(Yso.util.split, body, sep)
    if ok and type(out) == "table" then parts = out end
  end

  if type(parts) ~= "table" then
    parts = {}
    local idx = 1
    while true do
      local a, b = body:find(sep, idx, true)
      local part = a and body:sub(idx, a - 1) or body:sub(idx)
      part = part:gsub("^%s+",""):gsub("%s+$","")
      if part ~= "" then parts[#parts+1] = part end
      if not a then break end
      idx = b + 1
    end
  end

  for i = 1, #parts do
    _send_line(parts[i])
  end
end

-- Prefer Yso.queue *clear wrappers if present; otherwise send directly.
local function _queue_clear(qtype, payload)
  payload = tostring(payload or "")
  if payload == "" then return end

  local Q = Yso and Yso.queue or nil
  if type(Q) == "table" then
    -- Prefer sugar: eq_clear / bal_clear / eqbal_clear, etc.
    local fn =
      (qtype == "eq"  and Q.eq_clear)  or
      (qtype == "bal" and Q.bal_clear) or
      (qtype == "eqbal" and Q.eqbal_clear) or
      nil

    if type(fn) == "function" then
      fn(payload)
      return
    end

    -- Fallback: addclear(qtype, payload)
    if type(Q.addclear) == "function" then
      Q.addclear(qtype, payload)
      return
    end
  end

  -- Last resort: client-side split and send
  _send_compound(payload)
end

-- ---------------- affliction source: Yso-first ----------------
local function _yso_affs()
  if type(Yso) == "table" and type(Yso.affs) == "table" then
    return Yso.affs
  end
  return nil
end

local function _legacy_affs()
  if type(Legacy) == "table"
     and type(Legacy.Curing) == "table"
     and type(Legacy.Curing.Affs) == "table"
  then
    return Legacy.Curing.Affs
  end
  return nil
end

local function _gmcp_has_aff(key)
  local g = gmcp and gmcp.Char and gmcp.Char.Afflictions
  if type(g) ~= "table" then return false end
  if g[key] == true then return true end

  local lists = { g.List, g.list, g.Afflictions, g.afflictions }
  for i = 1, #lists do
    local list = lists[i]
    if type(list) == "table" then
      for j = 1, #list do
        local v = list[j]
        local name = type(v) == "table" and v.name or v
        if tostring(name or ""):lower() == key then
          return true
        end
      end
    end
  end
  return false
end

local function _has_aff(key)
  key = tostring(key or ""):lower()
  if key == "" then return false end

  if Yso and Yso.self and type(Yso.self.has_aff) == "function" then
    local ok, v = pcall(Yso.self.has_aff, key)
    if ok and v == true then return true end
  end

  local Y = _yso_affs()
  if Y then
    if Y[key] then return true end
  end

  if _gmcp_has_aff(key) then return true end

  local L = _legacy_affs()
  if L and L[key] then return true end

  return false
end

local function _has_any(list)
  for i = 1, #list do
    if _has_aff(list[i]) then return true end
  end
  return false
end

local function _vitals_prone()
  local v = _vitals()
  local pos = tostring(v.position or ""):lower()
  return (pos:find("prone", 1, true) ~= nil)
end

local function _both_arms_broken()
  -- GMCP/Legacy-style keys (plus a couple common synonyms)
  local l = _has_any({ "left_arm_broken", "leftarmbroken", "left_arm_mangled", "mangled_left_arm" })
  local r = _has_any({ "right_arm_broken", "rightarmbroken", "right_arm_mangled", "mangled_right_arm" })
  return l and r
end

local function _blocked_global()
  -- All routes fail while prone/paralyzed (per your design notes)
  if _has_any({ "paralysis", "paralyzed", "paresis" }) then return true end
  if _has_any({ "prone", "fallen" }) or _vitals_prone() then return true end
  return false
end

local function _blocked_for_cards()
  -- Universe/Hermit: must not be webbed/bound, and must have at least one usable arm (not BOTH broken)
  if _has_any({ "webbed", "bound" }) then return true end
  if _both_arms_broken() then return true end
  return false
end

-- ---------------- Universe/Hermit tracking triggers ----------------
E._trig = E._trig or {}
local function _killTrig(id) if id then killTrigger(id) end end

-- Universe: fling starts pending
_killTrig(E._trig.uni_fling)
E._trig.uni_fling = tempRegexTrigger(
  [[^You fling the card at the ground, and it vanishes into the earth in a spark of magic\.$]],
  function() E.state.uni_pending = true end
)

-- Universe: map rises (up)
_killTrig(E._trig.uni_up)
E._trig.uni_up = tempRegexTrigger(
  [[^A shimmering, translucent image rises up before you, its glittering surface displaying ]],
  function()
    E.state.uni_pending = false
    E.state.uni_up = true
    E.state.uni_up_since = _now()
  end
)

-- Universe: map folds (down) — record duration
_killTrig(E._trig.uni_down)
E._trig.uni_down = tempRegexTrigger(
  [[^The shimmering map folds up and vanishes into the ether\.$]],
  function()
    if E.state.uni_up and (E.state.uni_up_since or 0) > 0 then
      E.state.uni_last_duration = _now() - E.state.uni_up_since
    end
    E.state.uni_pending = false
    E.state.uni_up = false
    E.state.uni_up_since = 0
  end
)

-- Hermit: activated (ready)
_killTrig(E._trig.hermit_activate)
E._trig.hermit_activate = tempRegexTrigger(
  [[^You activate the hermit card.*$]],
  function() E.state.hermit_ready = true end
)

-- Hermit: used (no longer ready)
_killTrig(E._trig.hermit_used)
E._trig.hermit_used = tempRegexTrigger(
  [[^You fling the hermit card at the ground.*$]],
  function() E.state.hermit_ready = false end
)

-- ---------------- main entry ----------------
function E.press()
  if not _is_occultist() then
    return
  end

  -- threshold gate
  local v = _vitals()
  local hp_pct = _pct(v.hp, v.maxhp)
  local mp_pct = _pct(v.mp, v.maxmp)

  local thr = tonumber(E.cfg.threshold_pct or 75) or 75
  if not (hp_pct < thr or mp_pct < thr) then return end

  -- global blockers
  if _blocked_global() then return end

  local sep =
    (E.cfg and E.cfg.sep)
    or (Yso and Yso.sep)
    or (Yso and Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep))
    or "&&"
  local touch_to = tostring(E.cfg.universe_touch or "newthera")
  if touch_to == "" then touch_to = "newthera" end

  -- 1) Universe
  if touch_to ~= "" and not _blocked_for_cards() then
    if E.state.uni_up then
      _queue_clear("bal", ("touch %s"):format(touch_to))
    else
      -- fling consumes BAL; touch will either execute after or ride the server queue depending on separator behavior
      _queue_clear("bal", ("fling universe at ground%s touch %s"):format(sep, touch_to))
    end
    E.state.last_press = _now()
    return
  end

  -- 2) Hermit (only if activated)
  if E.state.hermit_ready and not _blocked_for_cards() then
    local tag = tostring(E.cfg.hermit_tag or "")
    if tag ~= "" then
      _queue_clear("bal", ("fling hermit at ground %s"):format(tag))
    else
      _queue_clear("bal", "fling hermit at ground")
    end
    E.state.last_press = _now()
    return
  end

  -- 3) Pathfinder HOME
  _queue_clear("eq", "order pathfinder home")
  E.state.last_press = _now()
  return
end

_cecho(string.format(
  "Escape button loaded: sep='%s', universe_touch='%s'",
  tostring(E.cfg.sep or ""), tostring(E.cfg.universe_touch or "")
))
--========================================================--
