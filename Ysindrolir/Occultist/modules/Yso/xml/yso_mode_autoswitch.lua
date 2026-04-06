--========================================================--
-- yso_mode_autoswitch.lua (DROP-IN)
-- Purpose:
--   • Auto-switch Yso.mode between bash/combat using:
--       1) Duel/Spar start/end lines (deterministic)
--       2) Aggression cooldown line (fallback)
--       3) PvP contact heuristics via gmcp.Room.Players + combat text
--
-- Notes:
--   • Does NOT require you to manually type "cooldowns", but if you do,
--     it will parse "Aggression: X minutes and Y seconds." automatically.
--   • Includes a "sniffer" that records lines containing duel/spar so you
--     can identify the exact start/end messages from your own output.
--
-- Where to place:
--   • Load AFTER yso_modes.lua (recommended), but safe standalone.
--========================================================--

_G.Yso = _G.Yso or _G.yso or {}
_G.yso = _G.Yso
Yso = _G.Yso


local function _norm_mode(mode)
  mode = tostring(mode or ""):lower()
  if mode == "hunt" or mode == "pve" or mode == "hunting" or mode == "bashing" then return "bash" end
  if mode == "pvp" then return "combat" end
  return mode
end

Yso.mode = Yso.mode or {}
-- Only install stubs if modes.lua hasn't loaded yet (safe standalone fallback).
-- These are intentionally minimal; the full API lives in modes.lua.
if not Yso.mode.set then
do
  local M = Yso.mode
  M.cfg = M.cfg or { echo = true }
  M.state = _norm_mode(M.state or "combat")
  local function _echo(msg)
    if not M.cfg.echo then return end
    if type(cecho) == "function" then
      cecho("<aquamarine>[Yso] <reset>" .. msg .. "<reset>\n")
    elseif type(echo) == "function" then
      echo("[Yso] " .. msg .. "\n")
    end
  end
  M.is_bash   = M.is_bash   or function() return _norm_mode(M.state) == "bash" end
  M.is_hunt   = M.is_hunt   or function() return M.is_bash() end
  M.is_combat = M.is_combat or function() return _norm_mode(M.state) == "combat" end
  M.is_party  = M.is_party  or function() return _norm_mode(M.state) == "party" end
  M.set = M.set or function(mode, _reason)
    mode = _norm_mode(mode)
    if mode ~= "bash" and mode ~= "combat" and mode ~= "party" then return false end
    if _norm_mode(M.state) ~= mode then
      M.state = mode
      _echo(("Mode set to <yellow>%s<reset>"):format(mode))
      if type(raiseEvent) == "function" then raiseEvent("yso.mode.changed", nil, mode, _reason or "auto") end
    end
    return true
  end
end
end

Yso.mode.auto = Yso.mode.auto or {}
local A = Yso.mode.auto

local function _now()
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _echo(msg)
  if not (Yso.mode and Yso.mode.cfg and Yso.mode.cfg.echo) then return end
  if type(cecho) == "function" then
    cecho("<aquamarine>[Yso] <reset>" .. msg .. "<reset>\n")
  elseif type(echo) == "function" then
    echo("[Yso] " .. msg .. "\n")
  end
end

A.cfg = A.cfg or {
  debug = false,
  sniff = true,
  sniff_max = 40,
  contact_hold = 20,
  use_aggression = true,
  idle_mode = "combat",      -- default idle/off state; do not auto-enter bash
  preserve_manual_bash = true, -- explicit mbash/mhunt stays sticky until changed
}

A.state = A.state or {
  forced = nil,
  combat_until = 0,
  room_players = {},
  sniff = {},
}

local function _sniff(line)
  if not A.cfg.sniff then return end
  local buf = A.state.sniff
  buf[#buf + 1] = { t = _now(), line = line }
  while #buf > (A.cfg.sniff_max or 40) do table.remove(buf, 1) end
end

function A.dump_sniff()
  local buf = A.state.sniff
  _echo(("Sniff buffer (%d lines):"):format(#buf))
  for i = 1, #buf do
    local row = buf[i]
    _echo(("[%02d] %s"):format(i, row.line))
  end
end

local function _in_room_players(name)
  if not name or name == "" then return false end
  return A.state.room_players[name:lower()] == true
end

local function _sync_mode(reason)
  if Yso.mode and ((type(Yso.mode.is_party)=="function" and Yso.mode.is_party()) or (_norm_mode(Yso.mode.state or "") == "party")) then
    return
  end
  if A.state.forced then
    if not (Yso.mode.is_combat and Yso.mode.is_combat()) then
      Yso.mode.set("combat", reason or "forced")
      if A.cfg.debug then _echo("Auto: forced combat ("..A.state.forced.kind..")") end
    end
    return
  end

  if _now() < (A.state.combat_until or 0) then
    if not (Yso.mode.is_combat and Yso.mode.is_combat()) then
      Yso.mode.set("combat", reason or "timer")
      if A.cfg.debug then _echo("Auto: combat (timer)") end
    end
  else
    local in_bash = false
    if Yso.mode.is_bash then
      in_bash = Yso.mode.is_bash()
    elseif Yso.mode.is_hunt then
      in_bash = Yso.mode.is_hunt()
    else
      in_bash = _norm_mode(Yso.mode.state or "") == "bash"
    end

    if in_bash and A.cfg.preserve_manual_bash ~= false then
      if A.cfg.debug then _echo("Auto: idle (preserving manual bash)") end
      return
    end

    local idle_mode = _norm_mode(A.cfg.idle_mode or "combat")
    if idle_mode == "" or idle_mode == "hold" or idle_mode == "none" then
      if A.cfg.debug then _echo("Auto: idle (holding current mode)") end
      return
    end
    if idle_mode ~= "combat" and idle_mode ~= "bash" then
      idle_mode = "combat"
    end

    local cur = _norm_mode((Yso.mode and Yso.mode.state) or "")
    if cur ~= idle_mode then
      Yso.mode.set(idle_mode, reason or "idle")
      if A.cfg.debug then _echo("Auto: "..idle_mode.." (idle)") end
    end
  end
end

function A.force_combat(kind, opponent, reason)
  A.state.forced = { kind = kind or "duel", opponent = opponent or "", since = _now(), reason = reason or "line" }
  _sync_mode("force:"..tostring(kind))
  _echo(("Auto: <yellow>%s<reset> started%s"):format(
    tostring(kind or "duel"),
    (opponent and opponent ~= "") and (" vs <yellow>"..opponent.."<reset>") or ""
  ))
end

function A.clear_force(reason)
  if A.state.forced then
    _echo(("Auto: <yellow>%s<reset> ended%s"):format(
      tostring(A.state.forced.kind),
      (A.state.forced.opponent and A.state.forced.opponent ~= "") and (" vs <yellow>"..A.state.forced.opponent.."<reset>") or ""
    ))
  end
  A.state.forced = nil
  A.state.combat_until = 0
  _sync_mode(reason or "force_end")
end

function A.bump_combat(seconds, reason)
  seconds = tonumber(seconds or 0) or 0
  if seconds <= 0 then return end
  local untilt = _now() + seconds
  if untilt > (A.state.combat_until or 0) then
    A.state.combat_until = untilt
  end
  _sync_mode(reason or "bump")
end

A._eh = A._eh or {}

local function _update_room_players()
  local set = {}
  local pkt = gmcp and gmcp.Room and gmcp.Room.Players
  if type(pkt) == "table" then
    for _, row in ipairs(pkt) do
      if type(row) == "table" and row.name then
        set[tostring(row.name):lower()] = true
      elseif type(row) == "string" then
        set[row:lower()] = true
      end
    end
  end
  A.state.room_players = set
end

local function _safe(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok and A.cfg.debug then _echo("Auto ERR: "..tostring(err)) end
  end
end

local function _kill_ae(id) if id then killAnonymousEventHandler(id) end end
_kill_ae(A._eh.room_players)
A._eh.room_players = registerAnonymousEventHandler("gmcp.Room.Players", _safe(_update_room_players))

local function _parse_aggression(line)
  local mins = line:match("(%d+)%s+minutes?")
  local secs = line:match("(%d+)%s+seconds?")
  mins = tonumber(mins or 0) or 0
  secs = tonumber(secs or 0) or 0
  return mins * 60 + secs
end

local function _maybe_update_dom_feed(line)
  local low = tostring(line or ""):lower()
  if low:find("domination feed:", 1, true) == nil then return false end
  if not (Yso and Yso.dom and type(Yso.dom.feed_update_from_cooldowns_line) == "function") then
    return false
  end
  local ok = pcall(Yso.dom.feed_update_from_cooldowns_line, line)
  return ok
end

local function _lower(s) return tostring(s or ""):lower() end

local function _looks_like_duel_start(s)
  s = _lower(s)
  return s:find("duel", 1, true)
     and (s:find("accept", 1, true) or s:find("accepted", 1, true) or s:find("begins", 1, true) or s:find("has begun", 1, true))
     and not s:find("declin", 1, true)
end

local function _looks_like_duel_end(s)
  s = _lower(s)
  return s:find("duel", 1, true)
     and (s:find("has ended", 1, true) or s:find("is over", 1, true) or s:find("ends", 1, true) or s:find("conclud", 1, true) or s:find("you have won", 1, true) or s:find("you have lost", 1, true))
end

local function _looks_like_spar_start(s)
  s = _lower(s)
  return (s:find("spar", 1, true) or s:find("sparring", 1, true))
     and (s:find("accept", 1, true) or s:find("accepted", 1, true) or s:find("begins", 1, true) or s:find("has begun", 1, true) or s:find("agreed", 1, true))
end

local function _looks_like_spar_end(s)
  s = _lower(s)
  return (s:find("spar", 1, true) or s:find("sparring", 1, true))
     and (s:find("has ended", 1, true) or s:find("is over", 1, true) or s:find("ends", 1, true) or s:find("conclud", 1, true))
end

local function _extract_name_near_you(s)
  local a = s:match("([A-Z][%w_%-']+) challenges you")
  if a then return a end
  local b = s:match("[Yy]ou challenge ([A-Z][%w_%-']+)")
  if b then return b end
  local c = s:match("([A-Z][%w_%-']+) accepts your")
  if c then return c end
  local d = s:match("[Yy]ou accept ([A-Z][%w_%-']+)'s")
  if d then return d end
  return nil
end

A._tr = A._tr or {}
local function _kill_tr(id) if id then killTrigger(id) end end

_kill_tr(A._tr.duel_spar_sniff)
A._tr.duel_spar_sniff = tempRegexTrigger([[.*]], _safe(function()
  local line = getCurrentLine() or ""
  local low  = _lower(line)

  if low:find("duel", 1, true) or low:find("spar", 1, true) or low:find("aggression:", 1, true) then
    _sniff(line)
  end

  if _looks_like_duel_start(line) then
    A.force_combat("duel", _extract_name_near_you(line), "duel_start")
    return
  end
  if _looks_like_spar_start(line) then
    A.force_combat("spar", _extract_name_near_you(line), "spar_start")
    return
  end
  if _looks_like_duel_end(line) then
    A.clear_force("duel_end")
    return
  end
  if _looks_like_spar_end(line) then
    A.clear_force("spar_end")
    return
  end

  if A.cfg.use_aggression and low:find("aggression:", 1, true) == 1 then
    local secs = _parse_aggression(line)
    if secs > 0 then
      A.bump_combat(secs, "aggression")
    else
      _sync_mode("aggression_zero")
    end
    return
  end

  -- Cooldowns fallback: keep Domination feed state fresh even if cast/ready
  -- lines were missed due to package reload or trigger timing.
  _maybe_update_dom_feed(line)

  local who = line:match("^([A-Z][%w_%-']+) .-")
  if who and _in_room_players(who) then
    local me = (gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.name) or nil
    if not me or who:lower() ~= tostring(me):lower() then
      A.bump_combat(A.cfg.contact_hold or 20, "pvp_contact")
    end
  end
end))

_sync_mode("init")
--========================================================--
