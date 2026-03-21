-- Auto-exported from Mudlet package script: Yso_hunt_mode_upkeep
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso_hunt_mode_upkeep
--
-- Bash-mode entourage upkeep only:
--   1) Request ENT and parse entourage listing.
--   2) Queue missing summons (Achaea server queue syntax).
--   3) Send MASK only when chaos orb, chaos hound, and pathfinder are present.
--
-- Mudlet UI: "Registered Events" may stay empty. This script registers
-- anonymous handlers at load (gmcp.Char.Vitals, yso.mode.changed) and
-- tempRegexTriggers for game lines. Call Yso.huntmode.refresh(...) from mbash.
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

--- Achaea HELP QUEUEING: QUEUE ADDCLEAR <queue> <command>
local function _queue_addclear_free(cmd)
  cmd = tostring(cmd or "")
  if cmd == "" then return false end
  return _send(("QUEUE ADDCLEAR free %s"):format(cmd))
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

M.cfg = M.cfg or {
  enabled = true,
  debug = false,
  ent_cmd = "ent",
  ent_request_gcd = 2.5,
  ent_rescan_gcd = 8.0,
  ent_inflight_timeout = 3.0,
  summons = {
    orb = "summon orb",
    hound = "summon hound",
    pathfinder = "summon pathfinder",
  },
  mask_cmd = "mask",
}

M.state = M.state or {
  present = { orb = false, hound = false, pathfinder = false },
  mask_active = false,
  ent = {
    synced = false,
    scanning = false,
    inflight = false,
    inflight_until = 0,
    last_request = 0,
    buf = {},
  },
}

local function _dbg(msg)
  if M.cfg.debug == true and type(cecho) == "function" then
    cecho(("[Yso] huntmode: " .. tostring(msg) .. "\n"))
  end
end

local function _missing_entities()
  local out = {}
  if M.state.present.orb ~= true then out[#out + 1] = "orb" end
  if M.state.present.hound ~= true then out[#out + 1] = "hound" end
  if M.state.present.pathfinder ~= true then out[#out + 1] = "pathfinder" end
  return out
end

local function _sync_mask_with_presence()
  if #_missing_entities() > 0 then
    M.state.mask_active = false
  end
end

local function _reset_ent_sync()
  local e = M.state.ent
  e.synced = false
  e.scanning = false
  e.inflight = false
  e.inflight_until = 0
  e.buf = {}
end

local function _request_ent(force)
  local e = M.state.ent
  local now = _now()
  local gcd = tonumber(M.cfg.ent_request_gcd or 2.5) or 2.5
  if force ~= true and (now - tonumber(e.last_request or 0)) < gcd then
    return false
  end
  e.last_request = now
  e.inflight = true
  e.scanning = false
  e.inflight_until = now + (tonumber(M.cfg.ent_inflight_timeout or 3.0) or 3.0)
  e.buf = {}
  _dbg("request ent")
  return _send(M.cfg.ent_cmd or "ent")
end

local function _apply_block(block)
  local text = tostring(block or ""):lower()
  M.state.present.orb = (text:find("chaos orb#%d+", 1, false) ~= nil)
  M.state.present.hound = (text:find("chaos hound#%d+", 1, false) ~= nil)
  M.state.present.pathfinder = (text:find("pathfinder#%d+", 1, false) ~= nil)
  local e = M.state.ent
  e.synced = true
  e.scanning = false
  e.inflight = false
  e.inflight_until = 0
  e.buf = {}
  _sync_mask_with_presence()
  _dbg(("ent parsed orb=%s hound=%s path=%s"):format(
    tostring(M.state.present.orb), tostring(M.state.present.hound), tostring(M.state.present.pathfinder)))
end

local function _apply_none()
  M.state.present.orb = false
  M.state.present.hound = false
  M.state.present.pathfinder = false
  local e = M.state.ent
  e.synced = true
  e.scanning = false
  e.inflight = false
  e.inflight_until = 0
  e.buf = {}
  M.state.mask_active = false
  _dbg("entourage empty")
end

local function _upkeep_pass(force_ent)
  if M.cfg.enabled ~= true then return false end
  if not _is_bash_mode() then return false end

  local e = M.state.ent
  if e.inflight == true and _now() > tonumber(e.inflight_until or 0) then
    e.inflight = false
    e.scanning = false
    e.buf = {}
    _dbg("ent inflight timeout")
  end

  if force_ent == true or e.synced ~= true then
    return _request_ent(force_ent == true)
  end

  if (_now() - tonumber(e.last_request or 0)) >= (tonumber(M.cfg.ent_rescan_gcd or 8.0) or 8.0) then
    return _request_ent(false)
  end

  local missing = _missing_entities()
  if #missing > 0 then
    M.state.mask_active = false
    for i = 1, #missing do
      local id = missing[i]
      local cmd = M.cfg.summons and M.cfg.summons[id] or ""
      if cmd ~= "" then
        _dbg("queue summon: " .. cmd)
        _queue_addclear_free(cmd)
      end
    end
    return true
  end

  if M.state.mask_active ~= true then
    _dbg("queue mask")
    return _queue_addclear_free(M.cfg.mask_cmd or "mask")
  end
  return true
end

--- Force a fresh ent scan and re-run upkeep (call from mbash even if already bash).
function M.refresh(reason)
  reason = tostring(reason or "")
  if M.cfg.enabled ~= true then return false end
  _dbg("refresh " .. reason)
  _reset_ent_sync()
  M.state.mask_active = false
  return _upkeep_pass(true)
end

-- ---------- triggers (entourage + summon feedback + mask line) ----------

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
  _upkeep_pass(false)
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
      _upkeep_pass(false)
    end
  end
end)

_kill_tr(M._trig.summon_orb)
M._trig.summon_orb = tempRegexTrigger(
  [[^A swirling portal of chaos opens, spits out a chaos orb, then vanishes\.]],
  function()
    M.state.present.orb = true
    M.state.mask_active = false
    _upkeep_pass(false)
  end)

_kill_tr(M._trig.summon_hound)
M._trig.summon_hound = tempRegexTrigger(
  [[^A swirling portal of chaos opens, spits out a chaos hound, then vanishes\.]],
  function()
    M.state.present.hound = true
    M.state.mask_active = false
    _upkeep_pass(false)
  end)

_kill_tr(M._trig.summon_pathfinder)
M._trig.summon_pathfinder = tempRegexTrigger(
  [[^A swirling portal of chaos opens, spits out a pathfinder, then vanishes\.]],
  function()
    M.state.present.pathfinder = true
    M.state.mask_active = false
    _upkeep_pass(false)
  end)

_kill_tr(M._trig.mask_on)
M._trig.mask_on = tempRegexTrigger(
  [[^Calling upon your powers within, you mask the movements of your chaos entities from the world\.$]],
  function()
    M.state.mask_active = true
  end)

-- ---------- event hooks (registered here; not via package UI) ----------

M._eh = M._eh or {}
local function _kill_eh(id)
  if id and type(killAnonymousEventHandler) == "function" then
    pcall(killAnonymousEventHandler, id)
  end
end

_kill_eh(M._eh.vitals)
M._eh.vitals = registerAnonymousEventHandler("gmcp.Char.Vitals", function()
  _upkeep_pass(false)
end)

_kill_eh(M._eh.mode_changed)
M._eh.mode_changed = registerAnonymousEventHandler("yso.mode.changed", function(_, old, new, _reason)
  local m = tostring(new or ""):lower()
  if m == "hunt" then m = "bash" end
  if m == "bash" then
    M.refresh("event:mode_changed")
  end
end)

--========================================================--
