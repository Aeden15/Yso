--========================================================--
-- yso_travel_router.lua (DROP-IN)
-- Purpose:
--   • Central travel router for Achaea (Yso namespace)
--   • Supports named routes (labels), provider selection, and map fallback
--   • Provider #1 (auto): Universe tarot IF Yso.uni is loaded
--   • Future providers can be added without changing calling code
--
-- Suggested aliases:
--   ^go$            -> Yso.travel.alias("")
--   ^go\s+(.+)$     -> Yso.travel.alias(matches[2])
--
-- Commands:
--   go <place>                  - route to place (label or provider match)
--   go uni <dest>               - force Universe provider
--   go list                     - list saved routes
--   go add <label> uni <dest>   - add label -> Universe destination
--   go add <label> room <id>    - add label -> Mudlet gotoRoom(id)
--   go add <label> walk <path>  - add label -> speedwalk("<path>")
--   go del <label>              - delete route label
--   go providers                - show provider availability
--   go help
--========================================================--

Yso = Yso or {}
Yso.travel = Yso.travel or {}
local TR = Yso.travel

TR.cfg = TR.cfg or {
  echo = true,
  persist_routes = true,
  persist_filename = "yso_travel_routes.lua",

  -- Provider order (first match wins)
  provider_order = { "routes", "universe", "map" },

  -- If forcing Universe:
  universe_auto_fling = true,  -- if true, router will request fling when Universe isn't "open" (based on Yso.uni state)
}

TR.providers = TR.providers or {}
TR.routes = TR.routes or {}    -- label_key -> spec { kind="uni"/"room"/"walk", ... }

-- ---------------- helpers ----------------
local function _now()
  return (type(getEpoch) == "function" and getEpoch()) or os.time()
end

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$",""))
end

local function _key(s)
  s = _trim(s):lower()
  s = s:gsub("[^%w%s%-_]", ""):gsub("[%s%-]+","_")
  return (s ~= "" and s) or nil
end

local function _ce(msg)
  if not TR.cfg.echo then return end
  if type(cecho) == "function" then
    cecho(("<aquamarine>[Yso]<aquamarine> <yellow>[Travel]<yellow> %s\n"):format(msg))
  end
end

local function _warn(msg)
  if type(cecho) == "function" then
    cecho(("<aquamarine>[Yso]<aquamarine> <yellow>[Travel]<yellow> <red>%s<red>\n"):format(msg))
  end
end

local function _persist_path()
  if not TR.cfg.persist_routes then return nil end
  if type(getMudletHomeDir) ~= "function" then return nil end
  return getMudletHomeDir() .. "/" .. (TR.cfg.persist_filename or "yso_travel_routes.lua")
end

local function _save_routes()
  local path = _persist_path()
  if not path then return end
  local f = io.open(path, "w+")
  if not f then return end

  f:write("return {\n  routes = {\n")
  for label, spec in pairs(TR.routes or {}) do
    if type(label) == "string" and type(spec) == "table" then
      f:write(("    [%q] = {\n"):format(label))
      for k,v in pairs(spec) do
        if type(v) == "string" then
          f:write(("      %s = %q,\n"):format(k, v))
        elseif type(v) == "number" then
          f:write(("      %s = %d,\n"):format(k, v))
        elseif type(v) == "boolean" then
          f:write(("      %s = %s,\n"):format(k, tostring(v)))
        end
      end
      f:write("    },\n")
    end
  end
  f:write("  }\n}\n")
  f:close()
end

local function _load_routes()
  local path = _persist_path()
  if not path then return end
  local f = io.open(path, "r")
  if not f then return end
  f:close()

  local ok, data = pcall(dofile, path)
  if ok and type(data) == "table" and type(data.routes) == "table" then
    TR.routes = data.routes
    _ce("Loaded saved routes ("..tostring((TR.routes and (function() local c=0; for _ in pairs(TR.routes) do c=c+1 end; return c end)()) or 0)..").")
  end
end

local function _split_first(s)
  s = _trim(s)
  if s == "" then return "", "" end
  local a,b = s:match("^(%S+)%s*(.-)%s*$")
  return tostring(a or ""), tostring(b or "")
end

-- ---------------- provider: routes ----------------
TR.providers.routes = TR.providers.routes or {}

function TR.providers.routes.available() return true end

function TR.providers.routes.resolve(query)
  local k = _key(query)
  if not k then return nil end
  local spec = TR.routes[k]
  if not spec then return nil end
  return { provider = "routes", label = k, spec = spec }
end

function TR.providers.routes.execute(plan)
  local spec = plan.spec or {}
  local kind = tostring(spec.kind or ""):lower()

  if kind == "uni" then
    local dest = spec.dest
    if not (Yso.uni and type(Yso.uni.go) == "function") then
      _warn("Route '"..plan.label.."' requires Universe, but Yso.uni is not loaded.")
      return
    end
    Yso.uni.go(dest)
    _ce("Route '"..plan.label.."' -> Universe: "..tostring(dest))
    return

  elseif kind == "room" then
    local id = tonumber(spec.room)
    if not id then _warn("Route '"..plan.label.."' has invalid room id.") return end
    if type(gotoRoom) == "function" then
      gotoRoom(id)
      _ce("Route '"..plan.label.."' -> gotoRoom("..id..")")
    else
      _warn("Mudlet gotoRoom() not available in this profile.")
    end
    return

  elseif kind == "walk" then
    local path = tostring(spec.path or "")
    if path == "" then _warn("Route '"..plan.label.."' has empty walk path.") return end
    if type(speedwalk) == "function" then
      speedwalk(path)
      _ce("Route '"..plan.label.."' -> speedwalk("..path..")")
    else
      _warn("Mudlet speedwalk() not available in this profile.")
    end
    return
  end

  _warn("Route '"..plan.label.."' has unknown kind: "..tostring(spec.kind))
end

-- ---------------- provider: universe (auto, if loaded) ----------------
TR.providers.universe = TR.providers.universe or {}

function TR.providers.universe.available()
  return (Yso.uni and type(Yso.uni.get_dest) == "function" and type(Yso.uni.go) == "function")
end

function TR.providers.universe.resolve(query)
  if not TR.providers.universe.available() then return nil end
  local k, r = Yso.uni.get_dest(query)
  if not (k and r and r.name) then return nil end
  return { provider = "universe", key = k, dest = r.name }
end

function TR.providers.universe.execute(plan, opts)
  if not TR.providers.universe.available() then
    _warn("Universe provider not available (Yso.uni not loaded).")
    return
  end

  opts = opts or {}
  -- If Universe module supports open-state and config wants auto-fling, request it.
  if TR.cfg.universe_auto_fling and Yso.uni.is_open and Yso.uni.fling then
    local ok, open = pcall(Yso.uni.is_open)
    if ok and not open then
      pcall(Yso.uni.fling) -- balance-queued inside Universe module (if you keep it that way)
    end
  end

  Yso.uni.go(plan.dest)
  _ce("Universe -> "..tostring(plan.dest))
end

-- ---------------- provider: map (fallback; expects numeric room id) ----------------
TR.providers.map = TR.providers.map or {}

function TR.providers.map.available()
  return (type(gotoRoom) == "function")
end

function TR.providers.map.resolve(query)
  local n = tonumber(_trim(query))
  if not n then return nil end
  if not TR.providers.map.available() then return nil end
  return { provider = "map", room = n }
end

function TR.providers.map.execute(plan)
  if not TR.providers.map.available() then
    _warn("Map provider not available (gotoRoom missing).")
    return
  end
  gotoRoom(plan.room)
  _ce("Map -> gotoRoom("..tostring(plan.room)..")")
end

-- ---------------- planning/execution ----------------
function TR.plan(query, forced_provider)
  query = _trim(query)
  if query == "" then return nil end

  if forced_provider and TR.providers[forced_provider] then
    local P = TR.providers[forced_provider]
    if P.available and not P.available() then return nil end
    if P.resolve then
      local plan = P.resolve(query)
      return plan
    end
    return nil
  end

  for _,name in ipairs(TR.cfg.provider_order or {}) do
    local P = TR.providers[name]
    if P and (not P.available or P.available()) and P.resolve then
      local plan = P.resolve(query)
      if plan then return plan end
    end
  end

  return nil
end

function TR.go(query, forced_provider)
  local plan = TR.plan(query, forced_provider)
  if not plan then
    _warn("No travel match for: "..tostring(query))
    _ce("Try: go providers | go list | go uni <dest> | (and run: uni list)")
    return
  end

  local P = TR.providers[plan.provider]
  if not (P and P.execute) then
    _warn("Provider missing execute(): "..tostring(plan.provider))
    return
  end

  P.execute(plan, {})
end

-- ---------------- route management ----------------
function TR.route_add_uni(label, dest)
  local k = _key(label); if not k then _warn("Invalid label.") return end
  TR.routes[k] = { kind = "uni", dest = _trim(dest) }
  _save_routes()
  _ce("Added route '"..k.."' -> Universe: ".._trim(dest))
end

function TR.route_add_room(label, room)
  local k = _key(label); if not k then _warn("Invalid label.") return end
  local n = tonumber(room)
  if not n then _warn("Room id must be numeric.") return end
  TR.routes[k] = { kind = "room", room = n }
  _save_routes()
  _ce("Added route '"..k.."' -> room: "..n)
end

function TR.route_add_walk(label, path)
  local k = _key(label); if not k then _warn("Invalid label.") return end
  path = _trim(path)
  if path == "" then _warn("Walk path cannot be empty.") return end
  TR.routes[k] = { kind = "walk", path = path }
  _save_routes()
  _ce("Added route '"..k.."' -> walk: "..path)
end

function TR.route_del(label)
  local k = _key(label); if not k then _warn("Invalid label.") return end
  if not TR.routes[k] then _warn("No such route: "..k) return end
  TR.routes[k] = nil
  _save_routes()
  _ce("Deleted route: "..k)
end

function TR.route_list()
  local n = 0
  for _ in pairs(TR.routes or {}) do n = n + 1 end
  if n == 0 then _ce("No routes saved. Add one: go add <label> uni <dest>") return end

  _ce("Routes ("..n.."):")
  if type(cecho) == "function" then
    for label, spec in pairs(TR.routes) do
      local kind = tostring(spec.kind or "")
      if kind == "uni" then
        cecho(("<gray>  %-18s<gray> <white>Universe<white> <dim_grey>-> %s<dim_grey>\n"):format(label, tostring(spec.dest)))
      elseif kind == "room" then
        cecho(("<gray>  %-18s<gray> <white>Room<white> <dim_grey>-> %s<dim_grey>\n"):format(label, tostring(spec.room)))
      elseif kind == "walk" then
        cecho(("<gray>  %-18s<gray> <white>Walk<white> <dim_grey>-> %s<dim_grey>\n"):format(label, tostring(spec.path)))
      else
        cecho(("<gray>  %-18s<gray> <red>Unknown kind<red>\n"):format(label))
      end
    end
  end
end

function TR.providers_status()
  _ce("Providers:")
  for name, P in pairs(TR.providers) do
    local ok = true
    if P.available then
      local s, res = pcall(P.available)
      ok = (s and res) and true or false
    end
    _ce(("  %-10s %s"):format(name, ok and "available" or "unavailable"))
  end
end

function TR.help()
  _ce("Commands:")
  if type(cecho) == "function" then
    cecho("<gray>  go <place><gray>                  - route (label or provider match)\n")
    cecho("<gray>  go uni <dest><gray>               - force Universe provider\n")
    cecho("<gray>  go list<gray>                     - list saved routes\n")
    cecho("<gray>  go add <label> uni <dest><gray>   - add route label -> Universe destination\n")
    cecho("<gray>  go add <label> room <id><gray>    - add route label -> gotoRoom(id)\n")
    cecho("<gray>  go add <label> walk <path><gray>  - add route label -> speedwalk(path)\n")
    cecho("<gray>  go del <label><gray>              - delete route\n")
    cecho("<gray>  go providers<gray>                - show provider availability\n")
  end
end

-- ---------------- alias entrypoint ----------------
function TR.alias(arg)
  arg = _trim(arg)
  if arg == "" then TR.help(); return end

  local cmd, rest = _split_first(arg)
  cmd = cmd:lower()

  if cmd == "help" then TR.help(); return end
  if cmd == "list" then TR.route_list(); return end
  if cmd == "providers" then TR.providers_status(); return end

  if cmd == "uni" then
    if rest == "" then _warn("Usage: go uni <destination>") return end
    TR.go(rest, "universe")
    return
  end

  if cmd == "add" then
    local label, tail = _split_first(rest)
    local kind, payload = _split_first(tail)
    kind = kind:lower()

    if label == "" or kind == "" then
      _warn("Usage: go add <label> (uni|room|walk) <value>")
      return
    end

    if kind == "uni" then TR.route_add_uni(label, payload); return end
    if kind == "room" then TR.route_add_room(label, payload); return end
    if kind == "walk" then TR.route_add_walk(label, payload); return end

    _warn("Unknown kind: "..kind.." (use uni|room|walk)")
    return
  end

  if cmd == "del" or cmd == "rm" or cmd == "remove" then
    if rest == "" then _warn("Usage: go del <label>") return end
    TR.route_del(rest)
    return
  end

  -- default: route
  TR.go(arg, nil)
end

-- Load saved routes
_load_routes()

_ce("Travel router loaded. Use: go help")
--========================================================--
