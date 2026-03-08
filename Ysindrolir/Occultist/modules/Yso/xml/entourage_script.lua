-- Auto-exported from Mudlet package script: Entourage script
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso_Domination_Entourage
--  • Watches the "entourage" output
--  • Parses the full list (handles wrapped lines)
--  • Tracks which Domination ents you *currently* have
--  • Cechos missing ents as: [Occultism] Missing Domination ents: ...
--========================================================--

Yso           = Yso           or {}
Yso.dom       = Yso.dom       or {}
Yso.dom.ents  = Yso.dom.ents  or {}
Yso.dom._trig = Yso.dom._trig or {}

local Ent = Yso.dom.ents

-- Ordered list of everything you can have in the entourage.
-- (Display names – used for the echo, and lowercased for keys.)
Ent.list = Ent.list or {
  "chaos hound",
  "humbug",
  "chimera",
  "green slime",
  "simpering sycophant",
  "bloodleech",
  "worm",
  "chaos orb",
  "eldritch abomination",
  "ethereal firelord",
  "soulmaster",
  "bubonis",
  "chaos storm",
  "withered crone",
  "Ysindrolir",
  "pathfinder",
}

-- Last seen entourage state, keyed by lowercase name -> true
Ent.current = Ent.current or {}

-- ---------- parser ----------

local function parse_entourage_block(block)
  if not block or block == "" then return end

  -- squash any newlines, just in case
  block = block:gsub("\n+", " ")

  local present = {}

  -- Grab each "name#12345" chunk and normalise the name
  for raw in block:gmatch("([^,]+)#%d+") do
    raw = raw:gsub("^%s+", "")    -- leading spaces
             :gsub("%s+$", "")    -- trailing spaces
             :gsub("%.$", "")     -- trailing period
             :gsub("^[Aa]n?%s+", "") -- drop "a " / "an "
    raw = raw:lower()
    if raw ~= "" then
      present[raw] = true
    end
  end

  Ent.current = present

  Ent.seen = true
  Ent.last_ts = (type(getEpoch)=="function" and math.floor(getEpoch()/1000) or os.time())
  if Yso then
    Yso.occ = Yso.occ or {}
    Yso.occ.entities_seen = true
    Yso.occ.entities_present = Ent.current
    Yso.occ.entities_present_ts = Ent.last_ts
  end

  -- Build missing list in the order of Ent.list
  local missing = {}
  for _, name in ipairs(Ent.list) do
    local key = name:lower()
    if not present[key] then
      table.insert(missing, name)
    end
  end

  -- ---------- echo ----------
  cecho("\n<orchid>[Occultism] <white>")

  if #missing == 0 then
    cecho("All Domination entities present.\n")
  else
    cecho(
      "Missing Domination ents: <ansi_green>"
      .. table.concat(missing, "<white>, <ansi_green>")
      .. "<white>.\n"
    )
  end
end

-- ---------- triggers ----------

-- Header line: starts the capture of the entourage block
if Yso.dom._trig.entourage then killTrigger(Yso.dom._trig.entourage) end
Yso.dom._trig.entourage = tempRegexTrigger(
  [[^The following beings are in your entourage:]],
  function()
    -- We’ll collect the next few lines (A chaos hound..., wraps, etc.)
    local buf, done = {}, false

    tempLineTrigger(1, 5, function()
      if done then return end

      local l = line or getCurrentLine()
      if not l:find("#%d+") then return end  -- ignore non-list lines

      table.insert(buf, l)

      -- The last line in the list ends with a period.
      if l:find("%.$") then
        done = true
        parse_entourage_block(table.concat(buf, " "))
      end
    end)
  end
)

-- No entourage / loyal companions messages -> clear (prevents stale Ent.current)
if Yso.dom._trig.no_entourage then killTrigger(Yso.dom._trig.no_entourage) end
Yso.dom._trig.no_entourage = tempRegexTrigger(
  [[^There are no beings in your entourage\.$]],
  function()
    Ent.current = {}
    Ent.seen = true
    Ent.last_ts = (type(getEpoch)=="function" and math.floor(getEpoch()/1000) or os.time())
    if Yso then
      Yso.occ = Yso.occ or {}
      Yso.occ.entities_seen = true
      Yso.occ.entities_present = Ent.current
      Yso.occ.entities_present_ts = Ent.last_ts
    end
    cecho(("\n<orchid>[Occultism] <white>Missing Domination ents: <ansi_green>%s<white>.\n"):format(table.concat(Ent.list, "<white>, <ansi_green>")))
  end
)

if Yso.dom._trig.no_loyals then killTrigger(Yso.dom._trig.no_loyals) end
Yso.dom._trig.no_loyals = tempRegexTrigger(
  [[^You have no loyal companions here\.$]],
  function()
    Ent.current = {}
    Ent.seen = true
    Ent.last_ts = (type(getEpoch)=="function" and math.floor(getEpoch()/1000) or os.time())
    if Yso then
      Yso.occ = Yso.occ or {}
      Yso.occ.entities_seen = true
      Yso.occ.entities_present = Ent.current
      Yso.occ.entities_present_ts = Ent.last_ts
    end
    cecho(("\n<orchid>[Occultism] <white>Missing Domination ents: <ansi_green>%s<white>.\n"):format(table.concat(Ent.list, "<white>, <ansi_green>")))
  end
)

--========================================================--

-- ---------- public helpers ----------
-- Returns true if the given entourage name (lowercase, without article) is currently present.
function Yso.dom.has_ent(name)
  if not name or name == "" then return false end
  name = tostring(name):lower()
  return (Ent.current and Ent.current[name] == true) or false
end

-- Convenience: eldritch abomination presence (Glaaki)
function Yso.dom.abomination_up()
  return Yso.dom.has_ent("eldritch abomination")
end
