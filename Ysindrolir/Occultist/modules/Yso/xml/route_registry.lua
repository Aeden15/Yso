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

local ROUTES = {
  occ_aff_burst = {
    id = "occ_aff_burst",
    mode = "combat",
    party_route = nil,
    namespace = "Yso.off.oc.occ_aff_burst",
    description = "Duel affliction loop",
    priority = 60,
    active = true,
  },
  group_damage = {
    id = "group_damage",
    mode = "party",
    party_route = "dam",
    namespace = "Yso.off.oc.group_damage",
    description = "Party damage",
    priority = 55,
    active = true,
  },
  party_aff = {
    id = "party_aff",
    mode = "party",
    party_route = "aff",
    namespace = "Yso.off.oc.party_aff",
    description = "Party affliction pressure",
    priority = 53,
    active = true,
  },
}

local ALIASES = {
  aff = "occ_aff_burst",
  occ = "occ_aff_burst",
  occ_aff = "occ_aff_burst",
  occultist_offense = "occ_aff_burst",
  burst = "occ_aff_burst",
  gd = "group_damage",
  dmg = "group_damage",
  dam = "group_damage",
  party_dam = "group_damage",
  party_damage = "group_damage",
  party_aff = "party_aff",
  team_aff = "party_aff",
}

local function _route_id(name)
  name = _norm(name)
  if name == "" or name == "none" then return nil end
  return ALIASES[name] or name
end

local function _sorted_rows(filter)
  local out = {}
  for _, entry in pairs(ROUTES) do
    if entry.active ~= false and (not filter or filter(entry)) then
      out[#out + 1] = _copy(entry)
    end
  end
  table.sort(out, function(a, b)
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
  for _, entry in pairs(ROUTES) do
    if entry.active ~= false and _norm(entry.party_route) == route then
      return _copy(entry)
    end
  end
  return nil
end

function RR.primary_for_mode(mode)
  local rows = RR.for_mode(mode)
  return rows[1]
end

return RR
