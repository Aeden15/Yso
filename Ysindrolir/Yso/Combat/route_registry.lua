--========================================================--
-- Yso Combat Route Registry
--  • Single source of truth for active Yso combat routes.
--  • Keeps ids, aliases, namespaces, and mode/party mapping together.
--========================================================--

Yso = Yso or {}
Yso.Combat = Yso.Combat or {}
Yso.Combat.RouteRegistry = Yso.Combat.RouteRegistry or {}

local RR = Yso.Combat.RouteRegistry

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _norm(s)
  return _trim(s):lower()
end

local function _copy(entry)
  local out = {}
  if type(entry) ~= "table" then return out end
  for k, v in pairs(entry) do out[k] = v end
  return out
end

local function _current_class()
  local C = Yso and Yso.classinfo or nil
  if type(C) == "table" then
    if type(C.get) == "function" then
      local ok, v = pcall(C.get)
      if ok and type(v) == "string" and _trim(v) ~= "" then return _norm(v) end
    end
    if type(C.current_class) == "function" then
      local ok, v = pcall(C.current_class)
      if ok and type(v) == "string" and _trim(v) ~= "" then return _norm(v) end
    end
  end

  local gmcp = rawget(_G, "gmcp")
  local status = gmcp and gmcp.Char and gmcp.Char.Status or nil
  local cls = status and (status.class or status.classname) or nil
  if type(cls) == "string" and _trim(cls) ~= "" then return _norm(cls) end

  if type(Yso.class) == "string" and _trim(Yso.class) ~= "" then
    return _norm(Yso.class)
  end

  return ""
end

local function _entry_class(entry)
  return type(entry) == "table" and _norm(entry.class or "") or ""
end

local function _class_rank(entry, cls)
  local needed = _entry_class(entry)
  if needed == "" then return 1 end
  if cls ~= "" and needed == cls then return 2 end
  return 0
end

local function _alias_target(value)
  if type(value) == "string" then return value end
  if type(value) ~= "table" then return nil end

  local cls = _current_class()
  local target = cls ~= "" and value[cls] or nil
  if type(target) == "string" and target ~= "" then return target end

  target = value.default or value.any or value["*"]
  if type(target) == "string" and target ~= "" then return target end

  return nil
end

local ROUTES = {
  magi_focus = {
    id = "magi_focus",
    mode = "combat",
    party_route = nil,
    namespace = "Yso.off.magi.focus",
    description = "Magi duel convergence",
    priority = 61,
    class = "magi",
    active = true,
    module_name = "magi_focus",
  },
  magi_dmg = {
    id = "magi_dmg",
    mode = "combat",
    party_route = nil,
    namespace = "Yso.off.magi.dmg",
    description = "Magi duel damage",
    priority = 62,
    class = "magi",
    active = true,
    module_name = "Magi_duel_dam",
  },
  alchemist_duel_route = {
    id = "alchemist_duel_route",
    mode = "combat",
    party_route = nil,
    namespace = "Yso.off.alc.duel_route",
    description = "Alchemist duel lock pressure",
    priority = 63,
    class = "alchemist",
    active = true,
    module_name = "alchemist_duel_route",
  },
  alchemist_aurify_route = {
    id = "alchemist_aurify_route",
    mode = "combat",
    party_route = nil,
    namespace = "Yso.off.alc.aurify_route",
    description = "Alchemist aurify bleed pressure",
    priority = 64,
    class = "alchemist",
    active = true,
    module_name = "alchemist_aurify_route",
  },
  magi_group_damage = {
    id = "magi_group_damage",
    mode = "party",
    party_route = "dam",
    namespace = "Yso.off.magi.group_damage",
    description = "Magi party damage",
    priority = 56,
    class = "magi",
    active = true,
    module_name = "magi_group_damage",
  },
  alchemist_group_damage = {
    id = "alchemist_group_damage",
    mode = "party",
    party_route = "dam",
    namespace = "Yso.off.alc.group_damage",
    description = "Alchemist party damage",
    priority = 57,
    class = "alchemist",
    active = true,
    module_name = "alchemist_group_damage",
  },
}

local ALIASES = {
  focus = { magi = "magi_focus" },
  mfocus = { magi = "magi_focus" },
  magi_focus = { magi = "magi_focus" },
  mdam = { magi = "magi_dmg" },
  magi_dmg = { magi = "magi_dmg" },
  aduel = { alchemist = "alchemist_duel_route" },
  alchemist_duel_route = { alchemist = "alchemist_duel_route" },
  bleed = { alchemist = "alchemist_aurify_route" },
  alchemist_aurify_route = { alchemist = "alchemist_aurify_route" },
  adam = { alchemist = "alchemist_group_damage" },
  alchemist_group_damage = { alchemist = "alchemist_group_damage" },
  gd = { magi = "magi_group_damage", alchemist = "alchemist_group_damage" },
  mgd = { magi = "magi_group_damage" },
  dmg = { magi = "magi_group_damage", alchemist = "alchemist_group_damage" },
  dam = { magi = "magi_group_damage", alchemist = "alchemist_group_damage" },
  party_dam = { magi = "magi_group_damage", alchemist = "alchemist_group_damage" },
  party_damage = { magi = "magi_group_damage", alchemist = "alchemist_group_damage" },
}

local function _route_id(name)
  name = _norm(name)
  if name == "" or name == "none" then return nil end
  if ROUTES[name] then return name end
  return _alias_target(ALIASES[name])
end

local function _sorted_rows(filter)
  local out = {}
  local cls = _current_class()
  for _, entry in pairs(ROUTES) do
    if entry.active ~= false and (not filter or filter(entry)) then
      out[#out + 1] = _copy(entry)
    end
  end
  table.sort(out, function(a, b)
    local ar = _class_rank(a, cls)
    local br = _class_rank(b, cls)
    if ar ~= br then
      return ar > br
    end
    if (a.priority or 0) ~= (b.priority or 0) then
      return (a.priority or 0) > (b.priority or 0)
    end
    return tostring(a.id or "") < tostring(b.id or "")
  end)
  return out
end

function RR.resolve(name)
  local id = _route_id(name)
  local entry = id and ROUTES[id] or nil
  if not entry or entry.active == false then return nil end
  return _copy(entry)
end

function RR.active_ids()
  local rows = _sorted_rows()
  local out = {}
  for i = 1, #rows do out[i] = rows[i].id end
  return out
end

function RR.for_mode(mode)
  mode = _norm(mode)
  return _sorted_rows(function(entry)
    return _norm(entry.mode) == mode
  end)
end

function RR.for_party_route(route)
  route = _norm(route)
  if route == "dmg" then route = "dam" end
  local cls = _current_class()
  local best, best_rank, best_priority = nil, -1, -math.huge
  for _, entry in pairs(ROUTES) do
    if entry.active ~= false and _norm(entry.party_route) == route then
      local rank = _class_rank(entry, cls)
      if rank > 0 and (not best or rank > best_rank or (rank == best_rank and (entry.priority or 0) > best_priority)) then
        best = entry
        best_rank = rank
        best_priority = entry.priority or 0
      end
    end
  end
  return best and _copy(best) or nil
end

function RR.primary_for_mode(mode)
  local rows = RR.for_mode(mode)
  return rows[1]
end

return RR
