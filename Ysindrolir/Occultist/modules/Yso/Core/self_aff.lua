-- Auto-exported from Mudlet package script: Yso self aff
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso/Core/self_aff.lua
-- Canonical self-affliction truth for Yso.
--  * Owns normalized self aff state and broader curing-relevant self state.
--  * Prefers GMCP ingest, accepts text fallback when GMCP is stale.
--  * Exposes stable helpers through Yso.self.*.
--========================================================--

Yso = Yso or {}
Yso.selfaff = Yso.selfaff or {}
Yso.self = Yso.self or {}
Yso.affs = Yso.affs or {}
Yso.util = Yso.util or {}

local SA = Yso.selfaff

SA.cfg = SA.cfg or {
  debug = false,
  text_stale_guard_s = 1.25,
}

SA.affs = SA.affs or {}
SA.states = SA.states or {
  prone = false,
  sleep = false,
  blackout = false,
  bleeding = 0,
  writhe = {
    webbed = false,
    entangled = false,
    transfixed = false,
    bound = false,
    impaled = false,
  },
}

SA.meta = SA.meta or {
  last_gmcp_at = 0,
  last_text_at = 0,
  last_source = "",
}

SA._eh = SA._eh or {}
SA._tr = SA._tr or {}

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 1e12 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _echo(msg)
  if SA.cfg.debug ~= true then return end
  if type(cecho) == "function" then
    cecho(string.format("<steel_blue>[Yso:self_aff] <reset>%s\n", tostring(msg)))
  end
end

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local _aliases = {
  ["blindness"] = "blind",
  ["deafness"] = "deaf",
  ["health leech"] = "healthleech",
  ["mana leech"] = "manaleech",
  ["paralyzed"] = "paralysis",
  ["sleeping"] = "sleep",
  ["asleep"] = "sleep",
  ["fallen"] = "prone",
  ["prefarar"] = "sensitivity",
  ["lover's effect"] = "loverseffect",
  ["internal trauma"] = "internaltrauma",
  ["tempered humours"] = "temperedhumours",
  ["stupidity"] = "stupidity",
  ["crippled limb"] = "crippledlimb",
  ["damaged limb"] = "damagedlimb",
  ["mangled limb"] = "mangledlimb",
  ["deadening"] = "deadening",
  ["healthleech"] = "healthleech",
  ["manaleech"] = "manaleech",
}

local _state_affs = {
  prone = true,
  sleep = true,
  blackout = true,
  webbed = true,
  entangled = true,
  transfixed = true,
  bound = true,
  impaled = true,
}

local _writhe_affs = {
  webbed = true,
  entangled = true,
  transfixed = true,
  bound = true,
  impaled = true,
}

function SA.normalize(name)
  local s = tostring(name or ""):lower()
  if s == "" then return "" end

  s = s:gsub("[%.,;:!%?]+$", "")
  s = s:gsub("[_%-]+", " ")
  s = s:gsub("%s+", " ")
  s = _trim(s)
  if s == "" then return "" end

  local alias = _aliases[s]
  if alias then return alias end

  s = s:gsub("%s+", "")
  alias = _aliases[s]
  if alias then return alias end

  return s
end

Yso.util.aff_aliases = Yso.util.aff_aliases or {}
for k, v in pairs(_aliases) do
  Yso.util.aff_aliases[k] = v
end
Yso.util.normalize_aff_name = SA.normalize
Yso.util.display_aff_name = SA.normalize

local function _mark_meta(source)
  source = tostring(source or "")
  local now = _now()
  SA.meta.last_source = source
  if source:find("gmcp", 1, true) then
    SA.meta.last_gmcp_at = now
  elseif source:find("text", 1, true) then
    SA.meta.last_text_at = now
  end
end

local function _text_allowed()
  local stale = tonumber(SA.cfg.text_stale_guard_s or 1.25) or 1.25
  if stale <= 0 then return true end
  local last = tonumber(SA.meta.last_gmcp_at or 0) or 0
  if last <= 0 then return true end
  return (_now() - last) >= stale
end

local function _ensure_row(key)
  local row = SA.affs[key]
  if type(row) == "table" then return row end
  row = {
    active = false,
    first_seen = 0,
    last_seen = 0,
    last_cured = 0,
    source = "",
  }
  SA.affs[key] = row
  return row
end

local function _sync_mirror(key, active)
  if active then
    Yso.affs[key] = true
  else
    Yso.affs[key] = nil
  end
end

local function _set_state_from_aff(key, active)
  if key == "prone" then
    SA.states.prone = (active == true)
  elseif key == "sleep" then
    SA.states.sleep = (active == true)
  elseif key == "blackout" then
    SA.states.blackout = (active == true)
  elseif _writhe_affs[key] then
    SA.states.writhe[key] = (active == true)
  end
end

local function _set_aff_active(key, active, source)
  key = SA.normalize(key)
  if key == "" then return false end
  source = tostring(source or "manual")

  if source:find("text", 1, true) and not _text_allowed() then
    return false
  end

  local row = _ensure_row(key)
  local now = _now()
  local was = (row.active == true)
  local is = (active == true)

  if is then
    if not was and (tonumber(row.first_seen or 0) or 0) <= 0 then
      row.first_seen = now
    end
    row.last_seen = now
  elseif was then
    row.last_cured = now
  end

  row.active = is
  row.source = source
  SA.affs[key] = row
  _sync_mirror(key, is)

  if _state_affs[key] then
    _set_state_from_aff(key, is)
  end

  if was ~= is and type(raiseEvent) == "function" then
    raiseEvent("yso.self.aff.changed", key, is, source)
  end

  _mark_meta(source)
  return true
end

local function _parse_aff_list(payload)
  local out = {}
  if type(payload) ~= "table" then return out end

  local function add_one(v)
    if type(v) == "string" then
      local n = SA.normalize(v)
      if n ~= "" then out[n] = true end
      return
    end
    if type(v) == "table" then
      local name = v.name or v.affliction or v.aff or v[1]
      local n = SA.normalize(name)
      if n ~= "" then out[n] = true end
    end
  end

  if type(payload.List) == "table" then
    for _, v in ipairs(payload.List) do add_one(v) end
  elseif type(payload.list) == "table" then
    for _, v in ipairs(payload.list) do add_one(v) end
  elseif type(payload.Afflictions) == "table" then
    for _, v in ipairs(payload.Afflictions) do add_one(v) end
  elseif type(payload.afflictions) == "table" then
    for _, v in ipairs(payload.afflictions) do add_one(v) end
  else
    for _, v in ipairs(payload) do add_one(v) end
  end

  return out
end

function SA.gain(name, source)
  return _set_aff_active(name, true, source or "manual")
end

function SA.cure(name, source)
  return _set_aff_active(name, false, source or "manual")
end

function SA.sync_full(list, source)
  source = tostring(source or "gmcp.full")
  local next_map = _parse_aff_list(list)
  local seen = {}

  for aff in pairs(next_map) do
    _set_aff_active(aff, true, source)
    seen[aff] = true
  end

  for aff, row in pairs(SA.affs) do
    if type(row) == "table" and row.active == true and not seen[aff] then
      _set_aff_active(aff, false, source)
    end
  end

  _mark_meta(source)
  if type(raiseEvent) == "function" then
    raiseEvent("yso.self.aff.synced", source)
  end
  return true
end

function SA.reset(source)
  source = tostring(source or "reset")
  for aff, row in pairs(SA.affs) do
    if type(row) == "table" and row.active == true then
      _set_aff_active(aff, false, source)
    end
  end
  SA.states.prone = false
  SA.states.sleep = false
  SA.states.blackout = false
  SA.states.bleeding = 0
  for k in pairs(SA.states.writhe) do
    SA.states.writhe[k] = false
  end
  _mark_meta(source)
  return true
end

function SA.set_bleeding(value, source)
  local n = tonumber(value) or 0
  if n < 0 then n = 0 end
  SA.states.bleeding = n
  _mark_meta(source or "gmcp.vitals")
end

function SA.ingest_gmcp_aff_list()
  local pkt = gmcp and gmcp.Char and gmcp.Char.Afflictions
  if type(pkt) ~= "table" then return false end
  if type(pkt.List) == "table" or type(pkt.list) == "table" then
    SA.sync_full(pkt, "gmcp.full")
    return true
  end
  return false
end

function SA.ingest_gmcp_add()
  local pkt = gmcp and gmcp.Char and gmcp.Char.Afflictions and gmcp.Char.Afflictions.Add
  if type(pkt) ~= "table" then return false end
  local name = pkt.name or pkt.affliction or pkt.aff or pkt[1]
  if not name then return false end
  return SA.gain(name, "gmcp.add")
end

function SA.ingest_gmcp_remove()
  local pkt = gmcp and gmcp.Char and gmcp.Char.Afflictions and gmcp.Char.Afflictions.Remove
  if type(pkt) ~= "table" then return false end
  local name = pkt.name or pkt.affliction or pkt.aff or pkt[1]
  if not name then return false end
  return SA.cure(name, "gmcp.remove")
end

function SA.ingest_gmcp_vitals()
  local v = gmcp and gmcp.Char and gmcp.Char.Vitals
  if type(v) ~= "table" then return false end

  local posture = tostring(v.position or v.posture or v.pose or ""):lower()
  if posture ~= "" then
    if posture:find("prone", 1, true) or posture:find("fallen", 1, true) then
      SA.gain("prone", "gmcp.vitals")
    elseif posture:find("stand", 1, true) then
      SA.cure("prone", "gmcp.vitals")
    end

    if posture:find("sleep", 1, true) then
      SA.gain("sleep", "gmcp.vitals")
    elseif posture:find("stand", 1, true) or posture:find("sit", 1, true) or posture:find("prone", 1, true) then
      SA.cure("sleep", "gmcp.vitals")
    end
  end

  if v.bleeding ~= nil then
    SA.set_bleeding(v.bleeding, "gmcp.vitals")
  end

  _mark_meta("gmcp.vitals")
  return true
end

function SA.ingest_text_gain(name)
  return SA.gain(name, "text")
end

function SA.ingest_text_cure(name)
  return SA.cure(name, "text")
end

function SA.has_aff(aff)
  local key = SA.normalize(aff)
  if key == "" then return false end
  local row = SA.affs[key]
  return type(row) == "table" and row.active == true
end

function SA.any_aff(list)
  if type(list) ~= "table" then return false end
  for i = 1, #list do
    if SA.has_aff(list[i]) then return true end
  end
  return false
end

function SA.aff_count(arg)
  local c = 0
  if type(arg) == "table" then
    for i = 1, #arg do
      if SA.has_aff(arg[i]) then c = c + 1 end
    end
    return c
  end

  for _, row in pairs(SA.affs) do
    if type(row) == "table" and row.active == true then
      c = c + 1
    end
  end
  return c
end

function SA.list_affs()
  local out = {}
  for aff, row in pairs(SA.affs) do
    if type(row) == "table" and row.active == true then
      out[#out + 1] = aff
    end
  end
  table.sort(out)
  return out
end

function SA.is_prone()
  return SA.states.prone == true or SA.has_aff("prone")
end

function SA.is_asleep()
  return SA.states.sleep == true or SA.has_aff("sleep")
end

function SA.is_blackout()
  return SA.states.blackout == true or SA.has_aff("blackout")
end

function SA.is_writhed()
  for _, v in pairs(SA.states.writhe or {}) do
    if v == true then return true end
  end
  return false
end

function SA.bleeding()
  return tonumber(SA.states.bleeding or 0) or 0
end

function SA.is_standing()
  if SA.is_prone() then return false end
  if SA.is_asleep() then return false end
  return true
end

Yso.self.has_aff = function(aff) return SA.has_aff(aff) end
Yso.self.any_aff = function(list) return SA.any_aff(list) end
Yso.self.aff_count = function(arg) return SA.aff_count(arg) end
Yso.self.list_affs = function() return SA.list_affs() end
Yso.self.gain = function(name, source) return SA.gain(name, source) end
Yso.self.cure = function(name, source) return SA.cure(name, source) end
Yso.self.sync_full = function(list, source) return SA.sync_full(list, source) end
Yso.self.reset = function(source) return SA.reset(source) end
Yso.self.is_prone = function() return SA.is_prone() end
Yso.self.is_asleep = function() return SA.is_asleep() end
Yso.self.is_blackout = function() return SA.is_blackout() end
Yso.self.is_writhed = function() return SA.is_writhed() end
Yso.self.bleeding = function() return SA.bleeding() end
Yso.self.is_standing = function() return SA.is_standing() end
Yso.self.is_paralyzed = function() return SA.has_aff("paralysis") end

local function _kill_eh(id)
  if id and type(killAnonymousEventHandler) == "function" then
    pcall(killAnonymousEventHandler, id)
  end
end

local function _kill_tr(id)
  if id and type(killTrigger) == "function" then
    pcall(killTrigger, id)
  end
end

function SA.install_hooks()
  if SA._hooks_installed == true then return true end

  if type(registerAnonymousEventHandler) == "function" then
    _kill_eh(SA._eh.aff_list)
    SA._eh.aff_list = registerAnonymousEventHandler("gmcp.Char.Afflictions.List", function()
      SA.ingest_gmcp_aff_list()
    end)

    _kill_eh(SA._eh.aff_add)
    SA._eh.aff_add = registerAnonymousEventHandler("gmcp.Char.Afflictions.Add", function()
      SA.ingest_gmcp_add()
    end)

    _kill_eh(SA._eh.aff_remove)
    SA._eh.aff_remove = registerAnonymousEventHandler("gmcp.Char.Afflictions.Remove", function()
      SA.ingest_gmcp_remove()
    end)

    _kill_eh(SA._eh.vitals)
    SA._eh.vitals = registerAnonymousEventHandler("gmcp.Char.Vitals", function()
      SA.ingest_gmcp_vitals()
    end)
  end

  if type(tempRegexTrigger) == "function" then
    _kill_tr(SA._tr.aff_cured)
    SA._tr.aff_cured = tempRegexTrigger([[^You have cured the ([\w' -]+) affliction\.$]], function()
      if matches and matches[2] then
        SA.ingest_text_cure(matches[2])
      end
    end)

    _kill_tr(SA._tr.not_prone)
    SA._tr.not_prone = tempRegexTrigger([[^You are not fallen or kneeling\.$]], function()
      SA.ingest_text_cure("prone")
    end)
  end

  SA._hooks_installed = true
  return true
end

SA.install_hooks()
SA.ingest_gmcp_aff_list()
SA.ingest_gmcp_vitals()

return SA
