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
  gmcp_list_barrier_s = 0.20,
  gmcp_list_barrier_ms = nil,
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
    pinned = false,
    ensnared = false,
    trussed = false,
    shackled = false,
  },
}

SA.meta = SA.meta or {
  last_gmcp_at = 0,
  last_gmcp_list_at = 0,
  last_text_at = 0,
  last_source = "",
}

SA._eh = SA._eh or {}
SA._tr = SA._tr or {}
SA._compat_mirror_store = SA._compat_mirror_store or {}
SA._compat_mirror_ready = (SA._compat_mirror_ready == true)
SA._compat_write_guard = (SA._compat_write_guard == true)
SA._writhe_lane_blocked = (SA._writhe_lane_blocked == true)

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
  ["roped"] = "bound",
  ["roped up"] = "bound",
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
  pinned = true,
  ensnared = true,
  trussed = true,
  shackled = true,
}

SA.writhe_family = SA.writhe_family or {
  webbed = true,
  entangled = true,
  transfixed = true,
  bound = true,
  impaled = true,
  pinned = true,
  ensnared = true,
  trussed = true,
  shackled = true,
}

local _writhe_affs = SA.writhe_family
for aff in pairs(_writhe_affs) do
  if SA.states.writhe[aff] == nil then
    SA.states.writhe[aff] = false
  end
end

SA.arm_damage_family = SA.arm_damage_family or {
  brokenleftarm = true,
  brokenrightarm = true,
  damagedleftarm = true,
  damagedrightarm = true,
  mangledleftarm = true,
  mangledrightarm = true,
  crippledleftarm = true,
  crippledrightarm = true,
  brokenarm = true,
  damagedarm = true,
  mangledarm = true,
  crippledarm = true,
  brokenlimb = true,
  damagedlimb = true,
  mangledlimb = true,
  crippledlimb = true,
}

local _arm_damage_affs = SA.arm_damage_family

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
    if source == "gmcp.full" then
      SA.meta.last_gmcp_list_at = now
    end
  elseif source:find("text", 1, true) then
    SA.meta.last_text_at = now
  end
end

local function _text_allowed()
  local now = _now()
  local list_barrier_ms = tonumber(SA.cfg.gmcp_list_barrier_ms)
  local list_barrier = nil
  if list_barrier_ms and list_barrier_ms > 0 then
    list_barrier = list_barrier_ms / 1000
  else
    list_barrier = tonumber(SA.cfg.gmcp_list_barrier_s or 0.20) or 0.20
  end
  if list_barrier > 0 then
    local last_list = tonumber(SA.meta.last_gmcp_list_at or 0) or 0
    if last_list > 0 and (now - last_list) < list_barrier then
      return false
    end
  end

  local stale = tonumber(SA.cfg.text_stale_guard_s or 1.25) or 1.25
  if stale <= 0 then return true end
  local last = tonumber(SA.meta.last_gmcp_at or 0) or 0
  if last <= 0 then return true end
  return (now - last) >= stale
end

local function _compat_store()
  local store = SA._compat_mirror_store
  if type(store) ~= "table" then
    store = {}
    SA._compat_mirror_store = store
  end
  return store
end

local function _set_compat_guard(v)
  SA._compat_write_guard = (v == true)
end

local function _sync_store_from_legacy_affs()
  local src = Yso.affs
  if type(src) ~= "table" then return end
  local store = _compat_store()
  for k, v in pairs(src) do
    local key = SA.normalize(k)
    if key ~= "" then
      if v == true then
        store[key] = true
      elseif v == false or v == nil then
        store[key] = nil
      end
    end
  end
end

local function _install_affs_proxy()
  if SA._compat_mirror_ready == true and type(Yso.affs) == "table" then return end
  _sync_store_from_legacy_affs()
  local store = _compat_store()
  local proxy = {}

  local mt = {
    __index = function(_, k)
      return store[k]
    end,
    __newindex = function(_, k, v)
      local key = SA.normalize(k)
      if key == "" then return end

      if SA._compat_write_guard == true then
        if v == true then
          store[key] = true
        elseif v == nil or v == false then
          store[key] = nil
        else
          store[key] = v
        end
        return
      end

      if v == true then
        SA.gain(key, "compat")
      elseif v == nil or v == false then
        SA.cure(key, "compat")
      else
        store[key] = v
      end
    end,
    __pairs = function()
      return next, store, nil
    end,
  }

  setmetatable(proxy, mt)
  Yso.affs = proxy
  SA._compat_mirror_ready = true
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
  _install_affs_proxy()
  local store = _compat_store()
  _set_compat_guard(true)
  if active then store[key] = true else store[key] = nil end
  _set_compat_guard(false)
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

local function _sync_writhe_lane_blocks(source)
  local active = false
  local reason = ""
  for aff, row in pairs(SA.affs) do
    if _writhe_affs[aff] and type(row) == "table" and row.active == true then
      active = true
      reason = aff
      break
    end
  end

  if active == SA._writhe_lane_blocked then return false end
  SA._writhe_lane_blocked = active

  local Q = Yso and Yso.queue
  if type(Q) ~= "table" then return true end

  if active then
    for _, lane in ipairs({ "eq", "bal" }) do
      if type(Q.block_lane) == "function" then
        pcall(Q.block_lane, lane, reason ~= "" and reason or "writhe", {
          source = tostring(source or "self_aff.writhe"),
          clear_owned = true,
          clear_staged = true,
        })
      end
    end
  else
    for _, lane in ipairs({ "eq", "bal" }) do
      if type(Q.unblock_lane) == "function" then
        pcall(Q.unblock_lane, lane, "writhe_clear", {
          source = tostring(source or "self_aff.writhe"),
        })
      end
    end
  end

  if type(raiseEvent) == "function" then
    raiseEvent("yso.self.writhe_lane_block", active, reason)
  end
  return true
end

local function _set_aff_active(key, active, source, opts)
  key = SA.normalize(key)
  if key == "" then return false end
  source = tostring(source or "manual")
  opts = opts or {}
  local force_text = (type(opts) == "table" and opts.force_text == true)

  if source:find("text", 1, true) and not force_text and not _text_allowed() then
    return false
  end

  local row = _ensure_row(key)
  local now = _now()
  local was = (row.active == true)
  local is = (active == true)

  if is then
    if not was then
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
  if _writhe_affs[key] then
    _sync_writhe_lane_blocks(source)
  end

  _mark_meta(source)
  if was ~= is and type(raiseEvent) == "function" then
    raiseEvent("yso.self.aff.changed", key, is, source)
  end
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

function SA.gain(name, source, opts)
  return _set_aff_active(name, true, source or "manual", opts)
end

function SA.cure(name, source, opts)
  return _set_aff_active(name, false, source or "manual", opts)
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

function SA.reset(source, opts)
  local reset_opts = opts
  if type(source) == "table" then
    reset_opts = source
    source = "reset"
  end
  source = tostring(source or "reset")
  reset_opts = reset_opts or {}

  local force = (reset_opts.force == true)
  local now = _now()
  local policy = Yso and Yso.curing and Yso.curing.policy
  local aggr_until = policy and policy.state and tonumber(policy.state.aggression_until or 0) or 0
  local auto_until = Yso and Yso.mode and Yso.mode.auto and Yso.mode.auto.state
    and tonumber(Yso.mode.auto.state.combat_until or 0) or 0
  local actively_fighting = false
  if Yso and type(Yso.is_actively_fighting) == "function" then
    local ok, v = pcall(Yso.is_actively_fighting)
    actively_fighting = ok and (v == true)
  elseif Yso and Yso.mode and type(Yso.mode.active_route_id) == "function" then
    local ok_route, rid = pcall(Yso.mode.active_route_id)
    local route_id = ok_route and _trim(rid):lower() or ""
    if route_id ~= "" and route_id ~= "none" then
      local in_live_mode = false
      if type(Yso.mode.is_combat) == "function" then
        local ok_mode, v = pcall(Yso.mode.is_combat)
        in_live_mode = ok_mode and (v == true)
      end
      actively_fighting = in_live_mode
    end
  end

  if not force and (aggr_until > now or auto_until > now or actively_fighting) then
    return false, "combat_active"
  end

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
  _sync_writhe_lane_blocks(source)
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

function SA.ingest_text_gain(name, opts)
  local source = "text"
  local write_opts = nil
  if type(opts) == "string" then
    source = tostring(opts)
  elseif type(opts) == "table" then
    source = tostring(opts.source or "text")
    if opts.force == true or opts.force_text == true then
      write_opts = { force_text = true }
    end
  end
  return SA.gain(name, source, write_opts)
end

function SA.ingest_text_cure(name, opts)
  local source = "text"
  if type(opts) == "string" then
    source = tostring(opts)
  elseif type(opts) == "table" then
    source = tostring(opts.source or "text")
  end
  return SA.cure(name, source)
end

local function _arm_damage_active()
  for aff in pairs(_arm_damage_affs) do
    if SA.has_aff(aff) then
      return true, aff
    end
  end
  return false, ""
end

function SA.ingest_text_arms_unusable(opts)
  local source = "text.hardblock.bound"
  if type(opts) == "table" and _trim(opts.source) ~= "" then
    source = tostring(opts.source)
  end

  local blocked, aff = _arm_damage_active()
  if blocked == true then
    _echo(string.format("arms-unusable hardblock ignored (arm damage aff active: %s)", tostring(aff)))
    return false, "arm_damage_active"
  end

  return SA.ingest_text_gain("bound", { source = source, force = true })
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
  for aff, row in pairs(SA.affs) do
    if _writhe_affs[aff] and type(row) == "table" and row.active == true then
      return true
    end
  end
  return false
end

function SA.is_writhe_aff(name)
  local key = SA.normalize(name)
  if key == "" then return false end
  return _writhe_affs[key] == true
end

function SA.list_writhe_affs()
  local out = {}
  for aff, row in pairs(SA.affs) do
    if _writhe_affs[aff] and type(row) == "table" and row.active == true then
      out[#out + 1] = aff
    end
  end
  table.sort(out)
  return out
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
Yso.self.reset = function(source, opts) return SA.reset(source, opts) end
Yso.self.is_prone = function() return SA.is_prone() end
Yso.self.is_asleep = function() return SA.is_asleep() end
Yso.self.is_blackout = function() return SA.is_blackout() end
Yso.self.is_writhed = function() return SA.is_writhed() end
Yso.self.is_writhe_aff = function(name) return SA.is_writhe_aff(name) end
Yso.self.list_writhe_affs = function() return SA.list_writhe_affs() end
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

    _kill_tr(SA._tr.hardblock_bound)
    SA._tr.hardblock_bound = tempRegexTrigger(
      [[^You cannot do that because both of your arms must be whole and unbound\.$]],
      function()
        SA.ingest_text_arms_unusable({ source = "text.hardblock.bound" })
      end
    )
  end

  SA._hooks_installed = true
  return true
end

SA.install_hooks()
SA.ingest_gmcp_aff_list()
SA.ingest_gmcp_vitals()
_install_affs_proxy()
_sync_writhe_lane_blocks("init")

return SA
