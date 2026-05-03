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

local function _target_record(name)
  if not (Yso and Yso.tgt and type(Yso.tgt.get) == "function") then return nil end
  local ok, rec = pcall(Yso.tgt.get, name)
  if ok and type(rec) == "table" then return rec end
  return nil
end

local function _set_meta(name, key, value)
  local rec = _target_record(name)
  if not rec then return false end
  rec.meta = rec.meta or {}
  rec.meta[tostring(key or "")] = value
  rec.meta.last_mudlet_event_at = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  return true
end

local function _is_current_target(name)
  if type(name) ~= "string" or _trim(name) == "" then return false end
  if Yso and type(Yso.is_current_target) == "function" then
    local ok, v = pcall(Yso.is_current_target, name)
    if ok then return v == true end
  end
  if Yso and Yso.targeting and type(Yso.targeting.is_current) == "function" then
    local ok, v = pcall(Yso.targeting.is_current, name)
    if ok then return v == true end
  end
  return true
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

function M.onEnemySalve(who, loc, source)
  who = _trim(who)
  loc = _trim(loc):lower()
  if who == "" then return false end
  if not _is_current_target(who) then return false end
  _set_meta(who, "last_salve_loc", loc)
  _set_meta(who, "last_salve_source", source or "mudlet")
  _emit("yso.target.salve", who, loc, source or "mudlet")
  return true
end

function M.onCeasesToFavour(who, limb, source)
  who = _trim(who)
  limb = _trim(limb):lower()
  if who == "" then return false end
  if not _is_current_target(who) then return false end
  _set_meta(who, "last_ceases_to_favour_limb", limb)
  _emit("yso.target.favour.cleared", who, limb, source or "mudlet")
  return true
end

function M.onTargetSip(who, item, source)
  who = _trim(who)
  item = _trim(item):lower()
  if who == "" then return false end
  if not _is_current_target(who) then return false end
  _set_meta(who, "last_sip_item", item)
  _emit("yso.target.sip", who, item, source or "mudlet")
  return true
end

function M.onTargetEat(who, what, source)
  who = _trim(who)
  what = _trim(what):lower()
  if who == "" then return false end
  if not _is_current_target(who) then return false end
  _set_meta(who, "last_eat_item", what)
  if Yso and Yso.tgt and type(Yso.tgt.note_target_herb) == "function" then
    pcall(Yso.tgt.note_target_herb, who, what)
  end
  _emit("yso.target.eat", who, what, source or "mudlet")
  return true
end

function M.onTargetSmoke(who, what, source)
  who = _trim(who)
  what = _trim(what):lower()
  if who == "" then return false end
  if not _is_current_target(who) then return false end
  _set_meta(who, "last_smoke_item", what)
  _emit("yso.target.smoke", who, what, source or "mudlet")
  return true
end

function M.onOppProneGained(who, source)
  who = _trim(who)
  if who == "" then return false end
  if not _is_current_target(who) then return false end
  if Yso and Yso.tgt and type(Yso.tgt.aff_gain) == "function" then
    pcall(Yso.tgt.aff_gain, who, "prone")
  end
  _set_meta(who, "prone", true)
  _emit("yso.target.prone.gained", who, source or "mudlet")
  return true
end

function M.onOppProneCured(who, source)
  who = _trim(who)
  if who == "" then return false end
  if not _is_current_target(who) then return false end
  if Yso and Yso.tgt and type(Yso.tgt.aff_cure) == "function" then
    pcall(Yso.tgt.aff_cure, who, "prone")
  end
  _set_meta(who, "prone", false)
  _emit("yso.target.prone.cured", who, source or "mudlet")
  return true
end

function M.onOppFrozenGained(who, source)
  who = _trim(who)
  if who == "" then return false end
  if not _is_current_target(who) then return false end
  if Yso and Yso.tgt and type(Yso.tgt.aff_gain) == "function" then
    pcall(Yso.tgt.aff_gain, who, "frozen")
  end
  _set_meta(who, "frozen", true)
  _emit("yso.target.frozen.gained", who, source or "mudlet")
  return true
end

function M.onLimbDamage(who, limb, pct, source)
  who = _trim(who)
  limb = _trim(limb):lower()
  pct = tonumber(pct)
  if who == "" or limb == "" or not pct then return false end
  if not _is_current_target(who) then return false end
  local rec = _target_record(who)
  if rec then
    rec.meta = rec.meta or {}
    rec.meta.limb_damage = rec.meta.limb_damage or {}
    rec.meta.limb_damage[limb] = pct
    rec.meta.last_limb_damage = { limb = limb, pct = pct }
  end
  _emit("yso.target.limb.damage", who, limb, pct, source or "mudlet")
  return true
end

function M.onTargetFocusMind(who, source)
  who = _trim(who)
  if who == "" then return false end
  if not _is_current_target(who) then return false end
  _set_meta(who, "last_focus_mind_at", (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time())
  _emit("yso.target.focus_mind", who, source or "mudlet")
  return true
end

function M.onTargetTree(who, source)
  who = _trim(who)
  if who == "" then return false end
  if not _is_current_target(who) then return false end
  _set_meta(who, "last_tree_at", (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time())
  _emit("yso.target.tree", who, source or "mudlet")
  return true
end

function M.onDeathChannelEnd(source)
  _emit("yso.death.channel_end", source or "mudlet")
  return true
end

function M.onDeathFlingFail(source)
  _emit("yso.death.fling_fail", source or "mudlet")
  return true
end

function M.onDeathFlingSuccess(who, source)
  _emit("yso.death.fling_success", _trim(who), source or "mudlet")
  return true
end

function M.onDeathRub(who, source)
  _emit("yso.death.rub", _trim(who), source or "mudlet")
  return true
end

function M.onDeathSniff(who, count, source)
  _emit("yso.death.sniff", _trim(who), tonumber(count) or 0, source or "mudlet")
  return true
end

return M
