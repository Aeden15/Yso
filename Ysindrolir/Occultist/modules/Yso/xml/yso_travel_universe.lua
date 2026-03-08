--========================================================--
-- yso_travel_universe.lua (DROP-IN)
-- Purpose:
--   • Robust Universe Tarot travel helper for Achaea (Yso namespace)
--   • Parses "universe list" into a destination cache automatically
--   • Provides one-command travel with fuzzy matching + favorites
--   • Optional auto-fling + server-side BAL queueing
--
-- Install:
--   1) Add this as a Script in your Yso system (e.g., Yso Scripts/Travel).
--   2) Create/Update ONE alias:
--        Name: Universe
--        Pattern: ^uni(?:\s*(.*))$
--        Code:    Yso.uni.alias(matches[2])
--========================================================--

Yso = Yso or {}
Yso.uni = Yso.uni or {}
local U = Yso.uni

-- ---------------- config ----------------
U.cfg = U.cfg or {
  echo = true,                 -- cecho status lines
  auto_list_on_load = false,   -- send "universe list" once at login/load
  auto_fling = false,          -- if true: "uni <dest>" will queue fling+touch when not "open"
  open_ttl = 45,               -- seconds to consider Universe "open" after a fling we initiated
  use_server_queue = true,     -- use Achaea server-side queueing for BAL actions
  queue_type = "bal",          -- "bal" is correct for Tarot BAL actions
  persist_favorites = true,    -- save favorites to disk (if possible)
  persist_filename = "yso_universe_favs.lua",
}

-- ---------------- state ----------------
U.dest = U.dest or {}          -- keyed by normalized name -> { name="Azdu", desc="In the courtyard..." }
U.fav  = U.fav  or {}          -- array of normalized destination keys
U._state = U._state or { listing = false, got = 0, open_until = 0 }

-- ---------------- tiny helpers ----------------
local function _now()
  return (type(getEpoch) == "function" and getEpoch()) or os.time()
end

local function _trim(s)
  return tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")
end

local function _norm(s)
  s = _trim(s):lower()
  s = s:gsub("[%(%)]","")
       :gsub("[^%w%s%-_]", "")
       :gsub("[%s%-]+","_")
  return (s ~= "" and s) or nil
end

local function _ce(s)
  if not U.cfg.echo then return end
  if type(cecho) == "function" then
    cecho(("<aquamarine>[Yso]<aquamarine> <yellow>[Universe]<yellow> %s\n"):format(s))
  end
end

local function _warn(s)
  if type(cecho) == "function" then
    cecho(("<aquamarine>[Yso]<aquamarine> <yellow>[Universe]<yellow> <red>%s<red>\n"):format(s))
  end
end

local function _send(cmd)
  if type(send) == "function" then send(cmd) end
end

-- Prefer user queue helpers if present; else fall back to Achaea server queue.
local function _queue_bal(cmd)
  cmd = _trim(cmd)
  if cmd == "" then return false end

  local Q = Yso and Yso.queue
  if Q and type(Q.add) == "function" then
    Q.add(U.cfg.queue_type or "bal", cmd)
    return true
  end

  _warn("Yso.queue not loaded; cannot queue Universe action.")
  return false
end

local function _persist_path()
  if not U.cfg.persist_favorites then return nil end
  local base = nil
  if type(getMudletHomeDir) == "function" then base = getMudletHomeDir() end
  if not base then return nil end
  return base .. "/" .. (U.cfg.persist_filename or "yso_universe_favs.lua")
end

local function _load_favs()
  local path = _persist_path()
  if not path then return end
  local f = io.open(path, "r")
  if not f then return end
  f:close()
  local ok, data = pcall(dofile, path)
  if ok and type(data) == "table" and type(data.fav) == "table" then
    U.fav = data.fav
    _ce("Loaded favorites ("..tostring(#U.fav)..") from disk.")
  end
end

local function _save_favs()
  local path = _persist_path()
  if not path then return end
  local f = io.open(path, "w+")
  if not f then return end
  f:write("return {\n  fav = {\n")
  for _,k in ipairs(U.fav or {}) do
    if type(k) == "string" then
      f:write(("    %q,\n"):format(k))
    end
  end
  f:write("  }\n}\n")
  f:close()
end

-- ---------------- destination management ----------------
function U.set_dest(name, desc)
  local k = _norm(name)
  if not k then return end
  U.dest[k] = { name = _trim(name), desc = _trim(desc) }
end

function U.get_dest(query)
  local q = _norm(query)
  if not q then return nil end

  -- Exact match
  if U.dest[q] then return q, U.dest[q] end

  -- Starts-with (best)
  for k,v in pairs(U.dest) do
    if k:find("^"..q) then return k,v end
  end

  -- Contains (fallback)
  for k,v in pairs(U.dest) do
    if k:find(q, 1, true) then return k,v end
  end

  return nil
end

function U.favs_inline()
  if not (U.fav and #U.fav > 0) then return "" end
  local out = {}
  for _,k in ipairs(U.fav) do
    local r = U.dest[k]
    if r and r.name then table.insert(out, ("(%s)"):format(r.name)) end
  end
  return table.concat(out, " ")
end

function U.fav_list()
  if not (U.fav and #U.fav > 0) then
    _ce("Favorites: (none). Add with: uni fav add <destination>")
    return
  end
  _ce("Favorites: "..U.favs_inline())
  if type(cecho) == "function" then
    for i,k in ipairs(U.fav) do
      local r = U.dest[k]
      if r then
        cecho(("<gray>  %2d)<gray> <white>%s<white> <dim_grey>- %s<dim_grey>\n"):format(i, r.name, r.desc or ""))
      end
    end
  end
end

function U.fav_add(query)
  local k, r = U.get_dest(query)
  if not k then _warn("Unknown destination: "..tostring(query)) return end
  for _,x in ipairs(U.fav) do if x == k then _ce(r.name.." is already a favorite.") return end end
  table.insert(U.fav, k)
  _save_favs()
  _ce("Added favorite: "..r.name.." "..U.favs_inline())
end

function U.fav_del(query)
  local k = nil

  -- allow numeric index: "uni fav del 2"
  local idx = tonumber(_trim(query))
  if idx and U.fav[idx] then k = U.fav[idx] end

  if not k then
    local kk = _norm(query)
    if kk and U.dest[kk] then k = kk end
  end

  if not k then _warn("Couldn't resolve favorite: "..tostring(query)) return end

  for i=1,#U.fav do
    if U.fav[i] == k then
      local nm = (U.dest[k] and U.dest[k].name) or k
      table.remove(U.fav, i)
      _save_favs()
      _ce("Removed favorite: "..nm)
      return
    end
  end
  _warn("Favorite not found: "..tostring(query))
end

-- ---------------- universe actions ----------------
function U.list()
  U._state.listing = false
  U._state.got = 0
  _send("universe list")
end

function U.fling()
  U._state.open_until = _now() + (U.cfg.open_ttl or 45)
  _queue_bal("fling universe at ground")
end

function U.is_open()
  return _now() <= (U._state.open_until or 0)
end

function U.touch(dest)
  local k, r = U.get_dest(dest)
  if not k then
    _warn("Unknown destination: "..tostring(dest)..". Run: uni list")
    return
  end
  _queue_bal("touch "..r.name)
  _ce("Touching: "..r.name)
end

function U.go(dest)
  dest = _trim(dest)
  if dest == "" then U.help(); return end

  -- numeric shortcut: "uni 1" -> first favorite
  local idx = tonumber(dest)
  if idx and U.fav and U.fav[idx] then
    local k = U.fav[idx]
    local r = U.dest[k]
    if r then
      if U.cfg.auto_fling and not U.is_open() then U.fling() end
      U.touch(r.name)
      return
    end
  end

  if U.cfg.auto_fling and not U.is_open() then U.fling() end
  U.touch(dest)
end

-- ---------------- UX ----------------
function U.help()
  _ce("Commands:")
  if type(cecho) == "function" then
    cecho("<gray>  uni list<gray>                - refresh/cache Universe destinations\n")
    cecho("<gray>  uni f<gray>                   - fling Universe at ground (BAL)\n")
    cecho("<gray>  uni <destination><gray>       - touch destination (fuzzy match)\n")
    cecho("<gray>  uni <n><gray>                 - touch favorite #n\n")
    cecho("<gray>  uni fav<gray>                 - list favorites\n")
    cecho("<gray>  uni fav add <dest><gray>      - add favorite\n")
    cecho("<gray>  uni fav del <dest|n><gray>    - remove favorite\n")
    cecho(("<dim_grey>  favorites inline: %s<dim_grey>\n"):format(U.favs_inline() ~= "" and U.favs_inline() or "(none)"))
  end
end

-- ---------------- alias entrypoint ----------------
local function _split_first(s)
  s = _trim(s)
  if s == "" then return "", "" end
  local a,b = s:match("^(%S+)%s*(.-)%s*$")
  return tostring(a or ""), tostring(b or "")
end

function U.alias(arg)
  arg = _trim(arg)
  if arg == "" then U.help(); return end

  local cmd, rest = _split_first(arg:lower())

  if cmd == "l" or cmd == "list" then
    U.list(); return
  elseif cmd == "f" or cmd == "fling" or cmd == "g" or cmd == "ground" then
    U.fling(); return
  elseif cmd == "fav" or cmd == "favs" or cmd == "favorite" or cmd == "favorites" then
    local sub, rem = _split_first(rest)
    if sub == "" then U.fav_list(); return end
    if sub == "add" then U.fav_add(rem); return end
    if sub == "del" or sub == "rm" or sub == "remove" then U.fav_del(rem); return end
    U.fav_list(); return
  else
    U.go(arg)
  end
end

-- ---------------- triggers: parse "universe list" ----------------
U._trig = U._trig or {}

local function _kill(id)
  if id and type(killTrigger) == "function" then pcall(killTrigger, id) end
end

_kill(U._trig.uni_hdr)
_kill(U._trig.uni_line)
_kill(U._trig.uni_end)

U._trig.uni_hdr = tempRegexTrigger(
  [[^Touch\s+Destination\s*$]],
  function()
    U._state.listing = true
    U._state.got = 0
  end
)

U._trig.uni_line = tempRegexTrigger(
  [[^(\S+)\s+(.+)$]],
  function()
    if not U._state.listing then return end
    local touch = matches[2]
    local desc  = matches[3]
    if touch:lower() == "touch" and desc:lower():find("destination",1,true) then return end
    U.set_dest(touch, desc)
    U._state.got = (U._state.got or 0) + 1
  end
)

U._trig.uni_end = tempRegexTrigger(
  [[^[-]+$]],
  function()
    if not U._state.listing then return end
    if (U._state.got or 0) <= 0 then return end
    U._state.listing = false
    _ce(("Cached %d Universe destinations. Favorites: %s"):format(U._state.got or 0, (U.favs_inline() ~= "" and U.favs_inline() or "(none)")))
  end
)

-- Optional: detect fling line (best-effort; harmless if it never matches)
U._trig.uni_fling = U._trig.uni_fling or tempRegexTrigger(
  [[^You fling (?:the )?Universe tarot at the ground\b.*$]],
  function()
    U._state.open_until = _now() + (U.cfg.open_ttl or 45)
  end
)

-- Seed defaults (works even before you run "uni list")
if next(U.dest) == nil then
  local seed = {
    {"Azdu","In the courtyard of a ruined castle"},
    {"Bitterfork","Entering the gate"},
    {"Blackrock","A broken landscape"},
    {"Brasslantern","A lantern-lined pathway"},
    {"Caerwitrin","A steep climb up the mountains"},
    {"Genji","At the beginning of a steep path"},
    {"Manara","Copse of trees in the Granite Hills"},
    {"Mannaseh","Mannaseh Swamp north of the Pachaacacha"},
    {"Manusha","Along an overgrown pathway"},
    {"Mhojave","Collection of collapsed tents"},
    {"Newhope","Entrance to a humble village"},
    {"Newthera","Town centre of New Thera"},
    {"Shastaan","A flower-lined path"},
    {"Thraasi","A revitalised shipyard"},
  }
  for _,row in ipairs(seed) do U.set_dest(row[1], row[2]) end
end

-- Load favorites from disk (if enabled)
_load_favs()

-- Optionally refresh list immediately
if U.cfg.auto_list_on_load then
  tempTimer(1.0, function() U.list() end)
end

_ce("Universe travel module loaded. Type: uni")
--========================================================--
