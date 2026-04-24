--========================================================--
-- Yso Mudlet integration
--  * Class-neutral event helpers for shared Yso state.
--========================================================--

Yso = Yso or {}
Yso.mudlet = Yso.mudlet or {}

local M = Yso.mudlet

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _emit(name, ...)
  if type(raiseEvent) == "function" then
    raiseEvent(name, ...)
  end
end

function M.echo(msg, color)
  msg = tostring(msg or "")
  color = color or "<cyan>"
  if msg == "" then return end
  if Yso and Yso.util and type(Yso.util.cecho_line) == "function" then
    Yso.util.cecho_line(("%s[Yso] <reset>%s"):format(color, msg))
  elseif type(cecho) == "function" then
    cecho(("%s[Yso] <reset>%s\n"):format(color, msg))
  elseif type(print) == "function" then
    print("[Yso] " .. msg)
  end
end

function M.set_target(name, source)
  name = _trim(name)
  if name == "" then return false end
  if type(Yso.set_target) == "function" then
    pcall(Yso.set_target, name, source or "mudlet")
  else
    Yso.target = name
  end
  _emit("yso.target.changed", name, source or "mudlet")
  return true
end

function M.clear_target(reason)
  if type(Yso.clear_target) == "function" then
    pcall(Yso.clear_target, reason or "mudlet")
  else
    Yso.target = nil
  end
  _emit("yso.target.cleared", reason or "mudlet")
  return true
end

function M.aff_gain(who, aff, source)
  who = _trim(who)
  aff = _trim(aff):lower()
  if who == "" or aff == "" then return false end
  if Yso and Yso.tgt and type(Yso.tgt.aff_gain) == "function" then
    pcall(Yso.tgt.aff_gain, who, aff)
  end
  _emit("yso.target.aff.gained", who, aff, source or "mudlet")
  return true
end

function M.aff_cure(who, aff, source)
  who = _trim(who)
  aff = _trim(aff):lower()
  if who == "" or aff == "" then return false end
  if Yso and Yso.tgt and type(Yso.tgt.aff_cure) == "function" then
    pcall(Yso.tgt.aff_cure, who, aff)
  end
  _emit("yso.target.aff.cured", who, aff, source or "mudlet")
  return true
end

function M.note_target_herb(who, herb, source)
  who = _trim(who)
  herb = _trim(herb):lower()
  if who == "" or herb == "" then return false end
  if Yso and Yso.tgt and type(Yso.tgt.note_target_herb) == "function" then
    pcall(Yso.tgt.note_target_herb, who, herb)
  end
  _emit("yso.target.herb", who, herb, source or "mudlet")
  return true
end

return M
