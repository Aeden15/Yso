--========================================================--
-- Yso_Offense_Coordination.lua  (SUPERSEDING DROP-IN)
--  • Combat mode coordination (NO autostart)
--  • Target auto-clear on death / tumble-out / not-in-room
--  • Slowtime heuristic: "You move sluggishly into action."
--
-- Patch (2026-01-11):
--  • On: "<tgt> begins to tumble towards the <dir>."
--      - If Soulmaster balance NOT ready -> QUEUE BAL_CLEAR: fling lust at <tgt>
--      - Else (Soulmaster ready) -> prefer Soulmaster anti-tumble (if available),
--        otherwise fall back to Lust.
--  • On: "<tgt> tumbles out to the <dir>."
--      - QUEUE FREE: outd empress
--      - QUEUE BAL_CLEAR: fling empress <tgt>
--  • Still marks tumble for group_damage (dmg) module, and won’t break other modules.
--
-- IMPORTANT COMPAT FIX (this drop-in):
--  • Do NOT overwrite Yso.off.oc.toggle() if the Unravel route module already defined it.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

-- Only define if Unravel route (or another driver) didn’t already define it.
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

-- CANCELLED per project decision (2026-03-01):
-- Lust/Empress reactive automation is forcibly OFF on load.
-- (If you ever want it back, change this line to true.)
C.cfg.lust_empress_automation = false

-- On leap-out, pause offense automation lanes.
C.cfg.pause_on_leap_out = true


C._ev = C._ev or {}
C._tr = C._tr or {}
C._st = C._st or { tumble_react = { last = {} } }

local function _pkill(fn, id) if id then pcall(fn, id) end end
local function _trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function _lc(s) return _trim(s):lower() end

local function _now()
  if Yso and type(Yso.now) == "function" then return tonumber(Yso.now()) or os.time() end
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
  -- AK compatibility: affstrack layouts vary by version.
  --  • Modern: affstrack.score[aff] = number (0..100)
  --  • Some builds: affstrack.score[aff] = { current = number, ... }
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
      -- Legacy: wipe any numeric .score fields found directly on affstrack entries
      for _, v in pairs(affstrack) do
        if type(v) == "table" and type(v.score) == "number" then v.score = 0 end
      end
    end
  end

  if type(oscore) == "number" then oscore = 0 end
  if type(softscore) == "number" then softscore = 0 end

  if Yso and Yso.tgt and type(Yso.tgt.set_mindseye) == "function" then
    Yso.tgt.set_mindseye(tgt, false, true)
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

--========================================================--
-- Target presence / room tracking
--  NOTE:
--   • Legacy maintains authoritative room occupant tracking.
--   • Yso MUST NOT auto-clear targets or gate offense on room presence.
--   • Any target clears should come only from explicit server lines
--     (e.g., death, flee, tumble), and only while actively fighting.
--========================================================--

--========================================================--


------------------------------------------------------------
-- Enemy cure telemetry (from XML triggers)
--  • The XML package has triggers for:
--      "<tgt> eats an aurum flake."
--      "<tgt> eats a piece of kelp."
--      "<tgt> touches a tree tattoo."
--    They call Yso.off.oc.on_enemy_* if present.
--
--  • This module implements those hooks so other offense planners can
--    read "last kelp eat" etc without hard-wiring trigger scripts.
------------------------------------------------------------

Yso.off.oc = Yso.off.oc or {}

-- Ensure the shared Occultist entity pool exists (routes may read this).
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
  _note_target_herb(who, "kelp") -- normalize: aurum+kelp both map to kelp bucket
  if Yso and Yso.off and Yso.off.oc and Yso.off.oc.group_damage and type(Yso.off.oc.group_damage.on_enemy_kelp_eat)=="function" then
    pcall(Yso.off.oc.group_damage.on_enemy_kelp_eat, who)
  end
end

function Yso.off.oc.on_enemy_aurum_eat(who)
  local E = Yso.off.oc.cure_events
  _mark(E.aurum_eat_at, E.aurum_eat_n, who)
  _note_target_herb(who, "kelp") -- aurum flake is a kelp-equivalent cure
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

--========================================================--
-- Yso.off.driver — offense route state/control only (single-authority orchestrator pass)
--  • Tracks policy + active route for the orchestrator and route proposals.
--  • Does NOT directly tick or emit offense routes.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.driver = Yso.off.driver or {}
local D = Yso.off.driver

D.cfg = D.cfg or {
  enabled = true,
  verbose = false,
  follow_mode = true,  -- when policy="auto": prefer route from Yso.mode (party->group_damage); never overrides policy="active"
  auto_priority = { "occ_aff_burst", "group_damage", "party_aff" },
}

D.state = D.state or {
  enabled = (D.cfg.enabled ~= false),
  policy  = "manual",            -- "manual" | "active" | "auto"
  active  = "none",              -- manual route selection when policy="active" ("none" = idle)
}

local function _trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function _lc(s) return _trim(s):lower() end

local function _v(msg)
  if not (D.cfg.verbose == true) then return end
  if type(cecho) == "function" then
    cecho(("<dim_grey>[Yso.driver] <reset>%s\n"):format(tostring(msg)))
  end
end

local function _get_gd()
  return (Yso.off and Yso.off.oc and (Yso.off.oc.group_damage or Yso.off.oc.dmg)) or nil
end

local function _is_enabled(mod)
  if not mod then return false end
  if type(mod) == "table" then
    if mod.state and type(mod.state.enabled) == "boolean" then return mod.state.enabled end
    if mod.cfg and type(mod.cfg.enabled) == "boolean" then return mod.cfg.enabled end
    if type(mod.enabled) == "boolean" then return mod.enabled end
  end
  return false
end

local function _route_registry()
  local RR = Yso and Yso.Combat and Yso.Combat.RouteRegistry or nil
  if RR and type(RR.resolve) == "function" then return RR end
  if type(require) == "function" then
    pcall(require, "Yso.Combat.route_registry")
    pcall(require, "Yso.xml.route_registry")
  end
  RR = Yso and Yso.Combat and Yso.Combat.RouteRegistry or nil
  if RR and type(RR.resolve) == "function" then return RR end
  return nil
end

local function _route_id(route)
  route = _lc(route)
  if route == "" or route == "none" then return nil end

  local RR = _route_registry()
  if not (RR and type(RR.resolve) == "function") then
    return nil
  end
  local entry = RR.resolve(route)
  if entry and type(entry.id) == "string" and entry.id ~= "" then
    return entry.id
  end
  return nil
end

local function _resolve_route()
  -- ACTIVE-ROUTE ONLY: when policy is not auto, do nothing.
  local pol = _lc(D.state.policy)
  if pol == "active" then pol = "manual" end -- legacy alias
  if pol ~= "auto" then return nil end

  local route = _lc(D.state.active)
  if route == "" or route == "none" then return nil end
  return _route_id(route)
end

function D.current_route()
  local pol = _lc(D.state.policy)
  if pol ~= "auto" then return nil end

  local mode = Yso and Yso.mode or nil
  if mode and type(mode.is_hunt) == "function" and mode.is_hunt() then return nil end

  local explicit = _resolve_route()
  if explicit then return explicit end

  local RR = _route_registry()
  if not RR then return nil end

  if mode and type(mode.is_party) == "function" and mode.is_party() then
    local pr = type(mode.party_route) == "function" and _lc(mode.party_route()) or ""
    if type(RR.for_party_route) == "function" then
      local entry = RR.for_party_route(pr)
      if entry and entry.id then return entry.id end
    end
    return nil
  end

  if mode and type(mode.is_combat) == "function" and mode.is_combat() then
    if type(RR.primary_for_mode) == "function" then
      local entry = RR.primary_for_mode("combat")
      if entry and entry.id then return entry.id end
    end
    return nil
  end

  return nil
end

-- External helper: used by target presence auto-clear and other guards.
function Yso.is_actively_fighting()
  if not (D and D.state and D.state.enabled == true) then return false end
  local pol = _lc(D.state.policy)
  if pol == "active" then pol = "manual" end
  if pol ~= "auto" then return false end

  local route = ""
  if type(D.current_route) == "function" then
    local ok, v = pcall(D.current_route)
    if ok then route = _lc(v or "") end
  end
  if route == "" then
    route = _lc(D.state.active)
  end
  if route == "" or route == "none" then return false end

  -- Hunt mode: driver does not own bashing.
  if Yso and Yso.mode and type(Yso.mode.is_hunt) == "function" and Yso.mode.is_hunt() then
    return false
  end

  -- Require a current target.
  local t = ""
  if type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok then t = _trim(v or "") end
  elseif type(Yso.target) == "string" then
    t = _trim(Yso.target)
  end
  if t == "" then return false end

  return true
end

function D.toggle(on)
  if on == nil then
    D.state.enabled = not (D.state.enabled == true)
  else
    D.state.enabled = (on == true)
  end
  _v("enabled="..tostring(D.state.enabled))
  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    Yso.pulse.wake("driver:toggle")
  end
  return D.state.enabled
end

function D.set_policy(p)
  p = _lc(p)
  if p == "active" then p = "manual" end -- legacy alias
  if p ~= "manual" and p ~= "auto" then return D.state.policy end
  D.state.policy = p
  _v("policy="..p)
  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    Yso.pulse.wake("driver:policy")
  end
  return p
end

function D.set_active(route)
  route = _lc(route)
  if route == "" or route == "none" then route = "none" end
  if route ~= "none" then
    route = _route_id(route)
  end
  if route == nil then
    return D.state.active
  end
  D.state.active = route
  _v("active="..route)
  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    Yso.pulse.wake("driver:active")
  end
  return route
end

function D.tick(reasons)
  -- Single-authority pass: the orchestrator owns all automated offense emits.
  -- Driver remains as route/policy state for proposal modules and manual controls.
  return false
end

-- Disable any legacy pulse-driver registration; orchestrator is the only automated emitter.
if Yso and Yso.pulse and Yso.pulse.state and Yso.pulse.state.reg and Yso.pulse.state.reg["offense_driver"] then
  Yso.pulse.state.reg["offense_driver"].enabled = false
end

--========================================================--

