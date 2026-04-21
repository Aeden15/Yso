-- Auto-exported from Mudlet package script: Yso_hunt_mode_upkeep
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso_hunt_mode_upkeep
--
-- Bash-mode entourage upkeep (trigger-driven, no polling):
--   1) refresh() sends ENT once.
--   2) ENT-result triggers parse the listing.
--   3) After parse, missing summons are sent once each (plain send).
--   4) Summon-confirmation triggers mark present; when all three
--      are present, MASK is sent once.
--   5) Rescan timer runs only while something is missing or mask
--      is not yet confirmed. Stops once stable (all present + masked).
--
-- No QUEUE ADDCLEAR and no idle polling.
-- Class changes are watched so only Occultist bash mode manages entourage.
-- Mudlet UI "Registered Events" will be empty; all wiring is in Lua.
--========================================================--

_G.Yso = _G.Yso or _G.yso or {}
_G.yso = _G.Yso
local Yso = _G.Yso

Yso.huntmode = Yso.huntmode or {}
local M = Yso.huntmode

local function _now()
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _send(cmd)
  cmd = tostring(cmd or "")
  if cmd == "" then return false end
  if type(send) == "function" then
    send(cmd, false)
    return true
  end
  if type(expandAlias) == "function" then
    expandAlias(cmd)
    return true
  end
  return false
end

local function _is_bash_mode()
  local mode = Yso and Yso.mode
  if type(mode) ~= "table" then return false end
  if type(mode.is_bash) == "function" then
    local ok, v = pcall(mode.is_bash)
    if ok then return v == true end
  end
  local s = tostring(mode.state or ""):lower()
  return s == "bash" or s == "hunt"
end

local function _normalize_class(cls)
  cls = tostring(cls or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if cls == "" then return "" end
  return cls:sub(1, 1):upper() .. cls:sub(2):lower()
end

local function _current_class()
  if Yso and Yso.classinfo and type(Yso.classinfo.get) == "function" then
    local ok, cls = pcall(Yso.classinfo.get)
    if ok and tostring(cls or "") ~= "" then
      return _normalize_class(cls)
    end
  end

  local g = rawget(_G, "gmcp")
  local cls = g and g.Char and g.Char.Status and g.Char.Status.class or nil
  if (type(cls) ~= "string" or cls == "") and g and g.Char and g.Char.Vitals then
    cls = g.Char.Vitals.class
  end
  if (type(cls) ~= "string" or cls == "") and type(Yso.class) == "string" then
    cls = Yso.class
  end
  return _normalize_class(cls)
end

local function _supports_entourage()
  return _current_class() == "Occultist"
end

M.cfg = M.cfg or {
  enabled = true,
  debug = false,
  ent_cmd = "ent",
  ent_inflight_timeout = 3.0,
  rescan_interval = 10.0,
  summons = {
    orb = "summon orb",
    hound = "summon hound",
    pathfinder = "summon pathfinder",
  },
  mask_cmd = "mask",
}

M.state = M.state or {
  present  = { orb = false, hound = false, pathfinder = false },
  sent     = { orb = false, hound = false, pathfinder = false, mask = false },
  mask_active = false,
  class_gate = {
    class = "",
    supports_entourage = false,
  },
  ent = {
    synced   = false,
    scanning = false,
    inflight = false,
    inflight_until = 0,
    buf = {},
  },
}
M.state.class_gate = M.state.class_gate or {
  class = "",
  supports_entourage = false,
}

local function _clear_ent_request()
  local e = M.state.ent
  e.synced = false
  e.scanning = false
  e.inflight = false
  e.inflight_until = 0
  e.buf = {}
end

local function _clear_presence()
  M.state.present.orb = false
  M.state.present.hound = false
  M.state.present.pathfinder = false
end

local function _sync_class_gate()
  local cls = _current_class()
  local supported = (cls == "Occultist")
  local gate = M.state.class_gate
  local changed = gate.class ~= cls or gate.supports_entourage ~= supported
  gate.class = cls
  gate.supports_entourage = supported
  return supported, cls, changed
end

local function _dbg(msg)
  if M.cfg.debug == true and type(cecho) == "function" then
    cecho(("[Yso] huntmode: " .. tostring(msg) .. "\n"))
  end
end

local function _all_present()
  return M.state.present.orb == true
     and M.state.present.hound == true
     and M.state.present.pathfinder == true
end

local function _is_stable()
  return _all_present() and M.state.mask_active == true
end

local _start_rescan, _stop_rescan

local function _reset_sent()
  M.state.sent = { orb = false, hound = false, pathfinder = false, mask = false }
end

local function _suspend_for_class(reason)
  _stop_rescan()
  _clear_ent_request()
  _clear_presence()
  _reset_sent()
  M.state.mask_active = false
  local cls = tostring((M.state.class_gate and M.state.class_gate.class) or "")
  _dbg(("skip entourage upkeep class=%s reason=%s"):format(cls ~= "" and cls or "unknown", tostring(reason or "")))
end

-- Send missing summons (once each) then mask if all present.
-- Called exactly once after ENT parse completes, and once after
-- each summon-confirmation trigger.
local function _act()
  if M.cfg.enabled ~= true then return end
  if not _is_bash_mode() then return end
  if not _supports_entourage() then
    _sync_class_gate()
    _suspend_for_class("act")
    return
  end

  if not M.state.ent.synced then return end

  local did_summon = false
  for _, id in ipairs({ "orb", "hound", "pathfinder" }) do
    if M.state.present[id] ~= true and M.state.sent[id] ~= true then
      local cmd = M.cfg.summons and M.cfg.summons[id] or ""
      if cmd ~= "" then
        M.state.sent[id] = true
        _dbg("send " .. cmd)
        _send(cmd)
        did_summon = true
      end
    end
  end
  if did_summon then return end

  if _all_present() and M.state.mask_active ~= true and M.state.sent.mask ~= true then
    M.state.sent.mask = true
    _dbg("send mask")
    _send(M.cfg.mask_cmd or "mask")
  end
end

-- ---------- ENT request / parse ----------

-- Only touches ent-inflight state; does NOT reset sent/mask flags.
-- Full reset lives in refresh() (called from mbash).
local function _request_ent()
  if not _supports_entourage() then
    _sync_class_gate()
    _suspend_for_class("request_ent")
    return false
  end
  local e = M.state.ent
  local now = _now()
  e.inflight = true
  e.scanning = false
  e.synced   = false
  e.inflight_until = now + (tonumber(M.cfg.ent_inflight_timeout or 3.0) or 3.0)
  e.buf = {}
  _dbg("send ent")
  return _send(M.cfg.ent_cmd or "ent")
end

local function _apply_block(block)
  local text = tostring(block or ""):lower()
  local old = {
    orb  = M.state.present.orb,
    hound = M.state.present.hound,
    pathfinder = M.state.present.pathfinder,
  }
  M.state.present.orb        = (text:find("chaos orb#%d+",  1, false) ~= nil)
  M.state.present.hound      = (text:find("chaos hound#%d+", 1, false) ~= nil)
  M.state.present.pathfinder = (text:find("pathfinder#%d+",  1, false) ~= nil)
  local e = M.state.ent
  e.synced   = true
  e.scanning = false
  e.inflight = false
  e.buf = {}

  local something_lost = false
  for _, id in ipairs({ "orb", "hound", "pathfinder" }) do
    if old[id] == true and M.state.present[id] ~= true then
      M.state.sent[id] = false
      something_lost = true
    end
  end
  if something_lost then
    M.state.mask_active = false
    M.state.sent.mask = false
  end

  _dbg(("ent parsed orb=%s hound=%s path=%s"):format(
    tostring(M.state.present.orb), tostring(M.state.present.hound), tostring(M.state.present.pathfinder)))

  if _is_stable() then
    _dbg("stable — rescan stopped")
    _stop_rescan()
    return
  end

  if something_lost then
    _start_rescan()
  end

  _act()
end

local function _apply_none()
  M.state.present.orb = false
  M.state.present.hound = false
  M.state.present.pathfinder = false
  local e = M.state.ent
  e.synced   = true
  e.scanning = false
  e.inflight = false
  e.buf = {}
  M.state.mask_active = false
  _reset_sent()
  _dbg("entourage empty")
  _start_rescan()
  _act()
end

-- ---------- public API ----------

function M.refresh(reason)
  reason = tostring(reason or "")
  if M.cfg.enabled ~= true then return false end
  _sync_class_gate()
  if not _supports_entourage() then
    _suspend_for_class("refresh:" .. reason)
    return false
  end
  _dbg("refresh " .. reason)
  _reset_sent()
  M.state.mask_active = false
  return _request_ent()
end

-- ---------- periodic rescan timer ----------

M._rescan_timer = M._rescan_timer or nil
local function _kill_timer(id) if id and type(killTimer) == "function" then pcall(killTimer, id) end end

_start_rescan = function()
  _sync_class_gate()
  if not _supports_entourage() then
    _suspend_for_class("start_rescan")
    return
  end
  _kill_timer(M._rescan_timer)
  local interval = tonumber(M.cfg.rescan_interval or 10.0) or 10.0
  M._rescan_timer = tempTimer(interval, function()
    M._rescan_timer = nil
    if M.cfg.enabled ~= true then return end
    if not _is_bash_mode() then return end
    if not _supports_entourage() then
      _sync_class_gate()
      _suspend_for_class("rescan_tick")
      return
    end
    if _is_stable() then
      _dbg("rescan tick: already stable, stopping")
      return
    end
    _dbg("rescan tick")
    _request_ent()
    _start_rescan()
  end)
end

_stop_rescan = function()
  _kill_timer(M._rescan_timer)
  M._rescan_timer = nil
end

-- ---------- triggers ----------

M._trig = M._trig or {}
local function _kill_tr(id)
  if id and type(killTrigger) == "function" then pcall(killTrigger, id) end
end

_kill_tr(M._trig.ent_header)
M._trig.ent_header = tempRegexTrigger([[^The following beings are in your entourage:]], function()
  local e = M.state.ent
  if e.inflight ~= true then return end
  e.scanning = true
  e.buf = {}
end)

_kill_tr(M._trig.ent_none)
M._trig.ent_none = tempRegexTrigger([[^There are no beings in your entourage\.$]], function()
  if M.state.ent.inflight ~= true then return end
  _apply_none()
end)

_kill_tr(M._trig.ent_line)
M._trig.ent_line = tempRegexTrigger([[#\d+]], function()
  local e = M.state.ent
  if not (e.inflight == true and e.scanning == true) then return end
  local ln = tostring(getCurrentLine() or "")
  if ln:find("#%d+", 1, false) then
    e.buf[#e.buf + 1] = ln
    if ln:match("%.%s*$") then
      _apply_block(table.concat(e.buf, "\n"))
    end
  end
end)

_kill_tr(M._trig.summon_orb)
M._trig.summon_orb = tempRegexTrigger(
  [[^A swirling portal of chaos opens, spits out a chaos orb, then vanishes\.]],
  function()
    M.state.present.orb = true
    M.state.sent.orb = false
    _dbg("orb confirmed")
    _act()
  end)

_kill_tr(M._trig.summon_hound)
M._trig.summon_hound = tempRegexTrigger(
  [[^A swirling portal of chaos opens, spits out a chaos hound, then vanishes\.]],
  function()
    M.state.present.hound = true
    M.state.sent.hound = false
    _dbg("hound confirmed")
    _act()
  end)

_kill_tr(M._trig.summon_pathfinder)
M._trig.summon_pathfinder = tempRegexTrigger(
  [[^A swirling portal of chaos opens, spits out a pathfinder, then vanishes\.]],
  function()
    M.state.present.pathfinder = true
    M.state.sent.pathfinder = false
    _dbg("pathfinder confirmed")
    _act()
  end)

_kill_tr(M._trig.mask_on)
M._trig.mask_on = tempRegexTrigger(
  [[^Calling upon your powers within, you mask the movements of your chaos entities from the world\.$]],
  function()
    M.state.mask_active = true
    M.state.sent.mask = false
    _dbg("mask confirmed")
    if _is_stable() then
      _dbg("stable — rescan stopped")
      _stop_rescan()
    end
  end)

-- ---------- event hooks ----------

M._eh = M._eh or {}
local function _kill_eh(id)
  if id and type(killAnonymousEventHandler) == "function" then
    pcall(killAnonymousEventHandler, id)
  end
end

_kill_eh(M._eh.mode_changed)
M._eh.mode_changed = registerAnonymousEventHandler("yso.mode.changed", function(_, old, new, _reason)
  local m = tostring(new or ""):lower()
  if m == "hunt" then m = "bash" end
  if m == "bash" then
    _sync_class_gate()
    if _supports_entourage() then
      M.refresh("event:mode_changed")
      _start_rescan()
    else
      _suspend_for_class("event:mode_changed")
    end
  else
    _stop_rescan()
    _clear_ent_request()
  end
end)

local function _on_class_update(reason)
  local supported, cls, changed = _sync_class_gate()
  if changed ~= true then return end
  _dbg(("class update class=%s supported=%s reason=%s"):format(
    cls ~= "" and cls or "unknown",
    tostring(supported),
    tostring(reason or "")))
  if not _is_bash_mode() then return end
  if supported then
    M.refresh("event:" .. tostring(reason or "class_update"))
    _start_rescan()
  else
    _suspend_for_class("event:" .. tostring(reason or "class_update"))
  end
end

_kill_eh(M._eh.class_status)
M._eh.class_status = registerAnonymousEventHandler("gmcp.Char.Status", function()
  _on_class_update("gmcp.Char.Status")
end)

_kill_eh(M._eh.class_vitals)
M._eh.class_vitals = registerAnonymousEventHandler("gmcp.Char.Vitals", function()
  _on_class_update("gmcp.Char.Vitals")
end)

-- Start rescan at load if in bash and not already stable
_sync_class_gate()
if _is_bash_mode() and M.state.class_gate.supports_entourage == true and not _is_stable() then
  _start_rescan()
end

--========================================================--
