-- Auto-exported from Mudlet package script: Doppleganger things
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso.dop — Doppleganger Remote Command Router (patched)
--  • Alias: ^dop(?:\s+(.*))?$
--  • Shorthand: dop <card> [<target>]  -> Tarotlink channel fling
--  • Supports: dop fling <card> [at] <target>
--  • Targeting follows AK (string OR table `target`)
--  • Prepends (balanceless): seek <target> + look
--
-- Added:
--  • Domination standard cecho prefix: <HotPink>[Domination] <LightCoral>
--  • Trigger: "Your doppleganger is out of range." -> prints alert twice
--========================================================--

Yso = Yso or {}
Yso.dop = Yso.dop or {}

local Dop = Yso.dop

Dop.cfg = Dop.cfg or {
  sep               = ";;",
  debug             = false,
  prepend_seeklook  = true,

  -- You said you can "channel fling lust at <target>"
  -- If it turns out your syntax is "channel fling <card> <target>" then set this false.
  tarot_uses_at      = true,

  -- Domination echo prefix standard (project-wide convention)
  dom_prefix         = "<HotPink>[Domination] <LightCoral>",

  -- Out-of-range alert behavior
  oor_repeat         = 2,     -- must state twice (per your requirement)
  oor_gag            = false, -- set true to deleteLine() the server message
}

Dop._last_target = Dop._last_target or ""
Dop.tarot_allow  = Dop.tarot_allow  or {}   -- if non-empty, only these allowed
Dop.tarot_block  = Dop.tarot_block  or {}   -- always blocked

-- ---------- helpers ----------
local function _trim(s)  return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function _lower(s) return tostring(s or ""):lower() end

local function _echo(msg)
  cecho(string.format("<cyan>[dop]<reset> %s\n", tostring(msg)))
end

local function _dbg(msg)
  if Dop.cfg.debug then
    cecho(string.format("<gray>[dop:dbg]<reset> %s\n", tostring(msg)))
  end
end

-- Standard Domination echo helper (use for Domination skillset-related alerts)
function Dop.dom_echo(msg)
  msg = tostring(msg or "")
  if msg == "" then return end
  cecho(string.format("%s(%s).<reset>\n", Dop.cfg.dom_prefix or "<HotPink>[Domination] <LightCoral>", msg))
end

local function _split_words(s)
  local t = {}
  for w in tostring(s or ""):gmatch("%S+") do t[#t+1] = w end
  return t
end

local function _has_any(tbl)
  if type(tbl) ~= "table" then return false end
  for _ in pairs(tbl) do return true end
  return false
end

local function _coerce_target(x)
  if type(x) == "string" then
    x = _trim(x)
    return (x ~= "" and x) or nil
  end
  if type(x) == "table" then
    local cand = x.name or x.target or x.current or x.who or x[1]
    if type(cand) == "string" then
      cand = _trim(cand)
      return (cand ~= "" and cand) or nil
    end
  end
  return nil
end

-- AK target resolution (string OR table)
local function _ak_target()
  -- Yso: ignore Legacy/AK global `target` to prevent poisoning
  local n = nil

  -- sometimes target lives under AK tables
  local ak = rawget(_G, "ak") or rawget(_G, "AK")
  if type(ak) == "table" then
    n = _coerce_target(ak.target) or _coerce_target(ak.Target) or _coerce_target(ak.current_target)
    if n then return n end
  end

  return nil
end

local function _qsend(cmd)
  local Q = Yso.queue
  if Q and type(Q.push) == "function" then
    -- Your Q.push appears to be: push(cmd, queueName)
    local ok = pcall(Q.push, cmd, "free")
    if not ok then
      -- Fallback: if push only takes one arg, still send the command.
      ok = pcall(Q.push, cmd)
    end
    if not ok then send(cmd) end
  else
    send(cmd)
  end
end

local function _send_chain(cmds)
  for _,c in ipairs(cmds) do
    _dbg("SEND: " .. c)
    _qsend(c)
  end
end

-- parse optional "at"
local function _parse_tgt(words, idx)
  local a = _lower(words[idx] or "")
  if a == "at" then return words[idx+1] end
  return words[idx]
end

-- Target resolution:
-- 1) explicit arg (doesn't mutate global target)
-- 2) AK global `target` (preferred)
-- 3) cached last target
-- 4) offense module target
-- 5) gmcp Char.Status target
function Dop.getTarget(explicit)
  local t = _coerce_target(explicit)
  if t then Dop._last_target = t; return t end

  local ak = _ak_target()
  if ak then Dop._last_target = ak; return ak end

  if _trim(Dop._last_target) ~= "" then return Dop._last_target end

  if Yso.off and Yso.off.oc then
    local ot = _coerce_target(Yso.off.oc.target)
    if ot then Dop._last_target = ot; return ot end
  end

  local g = gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.target
  g = _coerce_target(g)
  if g then Dop._last_target = g; return g end

  return nil
end

local function _pre_seeklook(tgt)
  return {
    ("order doppleganger seek %s"):format(tgt),
    "order doppleganger look",
  }
end

local function _tarot_ok(card_l)
  if card_l == "" then return false, "No tarot card provided." end

  if _has_any(Dop.tarot_allow) then
    if not Dop.tarot_allow[card_l] then
      return false, ("Card '%s' is not in your allowlist."):format(card_l)
    end
    return true
  end

  if Dop.tarot_block[card_l] then
    return false, ("Card '%s' is currently blocked."):format(card_l)
  end

  return true
end

-- ---------- command builders ----------
function Dop.do_tarot_fling(card, tgt_override)
  local tgt = Dop.getTarget(tgt_override)
  if not tgt then _echo("No target set. Use: t <name>  or  dop target <name>"); return end

  local card_l = _lower(_trim(card))
  local ok, why = _tarot_ok(card_l)
  if not ok then _echo(why); return end

  local cmds = {}
  if Dop.cfg.prepend_seeklook then
    for _,c in ipairs(_pre_seeklook(tgt)) do cmds[#cmds+1] = c end
  end

  -- Tarotlink channeling
  if Dop.cfg.tarot_uses_at then
    cmds[#cmds+1] = ("order doppleganger channel fling %s at %s"):format(card_l, tgt)
  else
    cmds[#cmds+1] = ("order doppleganger channel fling %s %s"):format(card_l, tgt)
  end

  _send_chain(cmds)
end

function Dop.do_piridon_util(verb, arg)
  local tgt = Dop.getTarget()
  if not tgt then _echo("No target set. Use: t <name>  or  dop target <name>"); return end

  local cmds = {}
  if Dop.cfg.prepend_seeklook then
    for _,c in ipairs(_pre_seeklook(tgt)) do cmds[#cmds+1] = c end
  end

  if verb == "cloak" then
    cmds[#cmds+1] = "order doppleganger cloak"
  elseif verb == "exits" then
    cmds[#cmds+1] = "order doppleganger exits"
  elseif verb == "look" then
    if not Dop.cfg.prepend_seeklook then cmds[#cmds+1] = "order doppleganger look" end
  elseif verb == "return" then
    cmds[#cmds+1] = "order doppleganger return"
  elseif verb == "move" then
    local dir = _trim(arg)
    if dir == "" then _echo("Usage: dop move <dir>"); return end
    cmds[#cmds+1] = ("order doppleganger move %s"):format(dir)
  else
    _echo(("Unknown util verb: %s"):format(verb))
    return
  end

  _send_chain(cmds)
end

function Dop.seek(who)
  who = _trim(who)
  if who == "" then _echo("Usage: dop seek <name>"); return end

  -- prefer AK alias
  if type(expandAlias) == "function" then
    expandAlias("t " .. who)
  else
    rawset(_G, "target", who)
  end

  local tgt = Dop.getTarget() or who
  _send_chain({
    ("order doppleganger seek %s"):format(tgt),
    "order doppleganger look",
  })
end

function Dop.do_piridon_channel(ability, tgt_override)
  local tgt = Dop.getTarget(tgt_override)
  if not tgt then _echo("No target set. Use: t <name>  or  dop target <name>"); return end

  local cmds = {}
  if Dop.cfg.prepend_seeklook then
    for _,c in ipairs(_pre_seeklook(tgt)) do cmds[#cmds+1] = c end
  end
  cmds[#cmds+1] = ("order doppleganger channel %s %s"):format(ability, tgt)
  _send_chain(cmds)
end

-- ---------- user-facing ----------
function Dop.help()
  _echo("Usage:")
  _echo("  dop")
  _echo("  dop debug [on|off]")
  _echo("  dop target <name>            (via AK alias: t <name>)")
  _echo("  dop seek <name>")
  _echo("  dop cloak | exits | look | return | move <dir>")
  _echo("  dop ague|devolution|eldritchmists|quicken|shrivel|timewarp|warp [<target>]")
  _echo("  dop fling <card> [at] [<target>]")
  _echo("  dop <card> [<target>]        (shorthand for tarot fling)")
end

function Dop.setTarget(name)
  name = _trim(name)
  if name == "" then _echo("Usage: dop target <name>"); return end

  if type(expandAlias) == "function" then
    expandAlias("t " .. name)
  else
    rawset(_G, "target", name)
  end

  Dop._last_target = Dop.getTarget() or name
  _echo(("Target set: %s"):format(Dop._last_target))
end

-- ---------- main dispatcher ----------
function Dop.handle(rest)
  rest = _trim(rest or "")
  _dbg("IN: " .. rest)

  if rest == "" then Dop.help(); return end

  local w = _split_words(rest)
  local v = _lower(w[1] or "")

  if v == "debug" then
    local sw = _lower(w[2] or "")
    if sw == "on" then Dop.cfg.debug = true
    elseif sw == "off" then Dop.cfg.debug = false
    else Dop.cfg.debug = not Dop.cfg.debug end
    _echo("debug = " .. tostring(Dop.cfg.debug))
    return
  end

  if v == "target" then Dop.setTarget(w[2]); return end
  if v == "seek"   then Dop.seek(w[2]); return end

  if v == "fling" then
    local card = w[2]
    local tgt  = _parse_tgt(w, 3)       -- supports "dop fling lust at Bob"
    Dop.do_tarot_fling(card, tgt)
    return
  end

  local util = { cloak=true, exits=true, look=true, ["return"]=true, move=true }
  if util[v] then Dop.do_piridon_util(v, w[2]); return end

  local chan_map = {
    ague          = "ague",
    devolution    = "devolution",
    eldritchmists = "eldritchmists",
    quicken       = "quicken",
    shrivel       = "shrivel",
    timewarp      = "timewarp",
    warp          = "warp",
  }
  if chan_map[v] then
    local tgt = _parse_tgt(w, 2)
    Dop.do_piridon_channel(chan_map[v], tgt)
    return
  end

  -- SHORTHAND: treat unknown first word as tarot card
  -- Examples: "dop lust" or "dop lust Bob" or "dop lust at Bob"
  local tgt = _parse_tgt(w, 2)
  Dop.do_tarot_fling(v, tgt)
end

--========================================================--
-- Triggers: Doppleganger range feedback
--========================================================--
Dop._trig = Dop._trig or {}

if Dop._trig.out_of_range then killTrigger(Dop._trig.out_of_range) end
Dop._trig.out_of_range = tempRegexTrigger(
  [[^Your doppleganger is out of range\.$]],
  function()
    if Dop.cfg.oor_gag then deleteLine() end
    local n = tonumber(Dop.cfg.oor_repeat) or 2
    if n < 1 then n = 1 end
    for _ = 1, n do
      Dop.dom_echo("DOPPLEGANGER OUT OF RANGE!")
    end
  end
)

cecho("<cyan>[Yso] dop router loaded (patched).<reset>\n")
--========================================================--
