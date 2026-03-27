--========================================================--
-- Yso_Offense_Coordination.lua
--  • Compatibility shim for older aliases/debug surfaces.
--  • Authoritative alias-loop ownership now lives in Yso.mode.
--  • Target auto-clear and enemy cure telemetry still live here.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

if type(Yso.off.oc.toggle) ~= "function" then
  function Yso.off.oc.toggle(on)
    if on == nil then
      Yso.off.oc.enabled = not (Yso.off.oc.enabled == true)
    else
      Yso.off.oc.enabled = (on == true)
    end
    if Yso and Yso.pulse and type(Yso.pulse.wake) == "function" then
      Yso.pulse.wake("oc:toggle")
    end
    cecho(string.format("<orange>[Yso] Occultist offense %s.\n", Yso.off.oc.enabled and "ON" or "OFF"))
  end
end

Yso.off.coord = Yso.off.coord or {}
local C = Yso.off.coord

C.cfg = C.cfg or {}
C.cfg.lust_empress_automation = false
C.cfg.pause_on_leap_out = true

C._ev = C._ev or {}
C._tr = C._tr or {}
C._st = C._st or { tumble_react = { last = {} }, dead = { pending = "", at = 0 } }

local function _pkill(fn, id) if id then pcall(fn, id) end end
local function _trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function _lc(s) return _trim(s):lower() end

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then return tonumber(Yso.util.now()) or os.time() end
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _hotpink(msg)
  if type(cecho) == "function" then
    cecho(string.format("<HotPink>[OFFENSE:] %s\n", msg))
  else
    echo(string.format("[OFFENSE:] %s\n", msg))
  end
end

local function _cur_target()
  if type(Yso.get_target) == "function" then return _trim(Yso.get_target() or "") end
  return _trim((type(Yso.target) == "string" and Yso.target) or (Yso.state and type(Yso.state.target) == "string" and Yso.state.target) or "")
end

local function _is_current(t)
  return _lc(_cur_target()) == _lc(t)
end

local function _clear(reason)
  if type(Yso.clear_target) == "function" then
    Yso.clear_target(reason or "auto")
  end
end

C._tm = C._tm or {}
C._st = C._st or {}
C._st.dead = C._st.dead or { pending = "", at = 0 }

local function _cancel_dead_clear()
  if C._tm.dead_clear then pcall(killTimer, C._tm.dead_clear) end
  C._tm.dead_clear = nil
  C._st.dead.pending = ""
  C._st.dead.at = 0
end

local function _reset_enemy_state_on_starburst(tgt)
  if type(affstrack) == "table" then
    if type(affstrack.score) == "table" then
      for k, v in pairs(affstrack.score) do
        if type(v) == "number" then
          affstrack.score[k] = 0
        elseif type(v) == "table" then
          if type(v.current) == "number" then v.current = 0 end
          if type(v.score) == "number" then v.score = 0 end
        end
      end
    else
      for _, v in pairs(affstrack) do
        if type(v) == "table" and type(v.score) == "number" then v.score = 0 end
      end
    end
  end

  if type(oscore) == "number" then oscore = 0 end
  if type(softscore) == "number" then softscore = 0 end

  if Yso and Yso.tgt and type(Yso.tgt.set_mindseye) == "function" then
    pcall(Yso.tgt.set_mindseye, tgt, false, true)
  end
end

local function _schedule_dead_clear(tgt)
  tgt = _trim(tgt)
  if tgt == "" then return end

  _cancel_dead_clear()
  C._st.dead.pending = tgt
  C._st.dead.at = _now()

  C._tm.dead_clear = tempTimer(2.2, function()
    local pend = C._st.dead.pending
    C._tm.dead_clear = nil
    C._st.dead.pending = ""
    C._st.dead.at = 0
    if pend ~= "" and _is_current(pend) then
      _clear("dead")
    end
  end)
end

Yso.off.oc = Yso.off.oc or {}
Yso.off.oc.entity_pool = Yso.off.oc.entity_pool or {
  rotation = { "worm", "sycophant", "bubonis", "crone", "hound", "slime", "storm", "bloodleech", "firelord", "gremlin" },
  kelp = { asthma = "bubonis", clumsiness = "storm", healthleech = "worm", sensitivity = "slime" },
}

Yso.off.oc.cure_events = Yso.off.oc.cure_events or {
  kelp_eat_at   = {},
  kelp_eat_n    = {},
  aurum_eat_at  = {},
  aurum_eat_n   = {},
  tree_touch_at = {},
  tree_touch_n  = {},
}

local function _mark(tbl_at, tbl_n, who)
  who = tostring(who or ""):gsub("^%s+",""):gsub("%s+$","")
  if who == "" then return end
  local k = who:lower()
  local now = (type(getEpoch)=="function" and getEpoch()) or os.time()
  if now > 20000000000 then now = now / 1000 end
  tbl_at[k] = now
  tbl_n[k]  = (tonumber(tbl_n[k] or 0) or 0) + 1
end

local function _note_target_herb(who, herb_key)
  if Yso and Yso.tgt and type(Yso.tgt.note_target_herb) == "function" then
    pcall(Yso.tgt.note_target_herb, who, herb_key)
  end
end

function Yso.off.oc.on_enemy_kelp_eat(who)
  local E = Yso.off.oc.cure_events
  _mark(E.kelp_eat_at, E.kelp_eat_n, who)
  _note_target_herb(who, "kelp")
  if Yso and Yso.off and Yso.off.oc and Yso.off.oc.group_damage and type(Yso.off.oc.group_damage.on_enemy_kelp_eat)=="function" then
    pcall(Yso.off.oc.group_damage.on_enemy_kelp_eat, who)
  end
end

function Yso.off.oc.on_enemy_aurum_eat(who)
  local E = Yso.off.oc.cure_events
  _mark(E.aurum_eat_at, E.aurum_eat_n, who)
  _note_target_herb(who, "aurum")
  if Yso and Yso.off and Yso.off.oc and Yso.off.oc.group_damage and type(Yso.off.oc.group_damage.on_enemy_aurum_eat)=="function" then
    pcall(Yso.off.oc.group_damage.on_enemy_aurum_eat, who)
  end
end

function Yso.off.oc.on_enemy_tree_touch(who)
  local E = Yso.off.oc.cure_events
  _mark(E.tree_touch_at, E.tree_touch_n, who)
  if Yso and Yso.tgt and type(Yso.tgt.get)=="function" then
    local ok,r = pcall(Yso.tgt.get, who)
    if ok and type(r)=="table" then
      r.meta = r.meta or {}
      r.meta.last_tree_touch_at = E.tree_touch_at[tostring(who or ""):lower()]
    end
  end
  if Yso and Yso.off and Yso.off.oc and Yso.off.oc.group_damage and type(Yso.off.oc.group_damage.on_enemy_tree_touch)=="function" then
    pcall(Yso.off.oc.group_damage.on_enemy_tree_touch, who)
  end
end

function Yso.off.oc.last_kelp_eat_at(who)
  local k = tostring(who or ""):lower()
  local E = Yso.off.oc.cure_events
  return E and tonumber(E.kelp_eat_at and E.kelp_eat_at[k] or 0) or 0
end

Yso.off.driver = Yso.off.driver or {}
local D = Yso.off.driver

D.cfg = D.cfg or {
  enabled = true,
  verbose = false,
}

D.state = D.state or {
  enabled = (D.cfg.enabled ~= false),
  policy  = "manual",
  active  = "none",
}

local function _v(msg)
  if not (D.cfg.verbose == true) then return end
  if type(cecho) == "function" then
    cecho(("<dim_grey>[Yso.driver] <reset>%s\n"):format(tostring(msg)))
  end
end

local function _mode()
  return Yso and Yso.mode or nil
end

local function _sync_state()
  D.state = D.state or {}
  local M = _mode()
  local route = ""
  if M and type(M.active_route_id) == "function" then
    local ok, v = pcall(M.active_route_id)
    if ok then route = _lc(v or "") end
  end

  D.state.enabled = (D.cfg.enabled ~= false)
  D.state.active = (route ~= "" and route) or "none"
  D.state.policy = (route ~= "" and "auto") or "manual"
  return D.state
end

function D.current_route()
  local st = _sync_state()
  local route = _lc(st.active or "")
  if route == "" or route == "none" then return nil end
  return route
end

function D.toggle(on)
  if on == nil then
    D.state.enabled = not (D.state.enabled == true)
  else
    D.state.enabled = (on == true)
  end
  D.cfg.enabled = (D.state.enabled == true)
  _v("enabled="..tostring(D.state.enabled))
  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    Yso.pulse.wake("driver:toggle")
  end
  return D.state.enabled
end

function D.set_policy(_p)
  _sync_state()
  return D.state.policy
end

function D.set_active(_route)
  _sync_state()
  return D.state.active
end

function D.tick(_reasons)
  _sync_state()
  return false
end

_sync_state()

if Yso and Yso.pulse and Yso.pulse.state and Yso.pulse.state.reg and Yso.pulse.state.reg["offense_driver"] then
  Yso.pulse.state.reg["offense_driver"].enabled = false
end

return D
