--========================================================--
-- Yso Bootstrap Loader
--  Problem: "Route chassis loader" in the XML tries:
--    pcall(require, "Yso.Core.bootstrap")
--  but this silently fails because package.path is empty at
--  package-load time. Without bootstrap, package.path is never
--  set up, so require("Yso.xml.yso_modes") also fails, so
--  toggle_route_loop / start_route_loop / tick_route_loop never
--  get defined.
--
--  Fix: load bootstrap.lua via dofile() with a path found from
--  os.getenv(), which works even from an inline XML script context.
--  Once bootstrap runs it extends package.path, and all the
--  subsequent require() calls in "Route chassis loader" succeed.
--
--  ADD THIS AS A MUDLET SCRIPT that runs BEFORE "Route chassis
--  loader". You can do this by placing it above it in the script
--  list in the Mudlet Script Editor (Yso Scripts → Core scripts).
--
--  TO ADD A NEW CLASS:
--    1. Add its module require() calls in the CLASS MODULES section below.
--    2. Add its routes to route_registry.lua (ROUTES + ALIASES tables).
--    3. The status line at the end will automatically pick up any module
--       stored at Yso.off.<classname>.<routename>.
--========================================================--

if _G.yso_bootstrap_done then return end   -- already ran, nothing to do

local function _try_dofile(path)
  path = tostring(path or ""):gsub("\\", "/")
  local f = io.open(path, "r")
  if not f then return false end
  f:close()
  local ok, err = pcall(dofile, path)
  if not ok and type(cecho) == "function" then
    cecho(string.format("<yellow>[Yso:loader] bootstrap dofile failed: %s<reset>\n", tostring(err)))
  end
  return ok
end

local function _find_and_load()
  -- 1. Honour explicit global override set by the user.
  if type(_G.YSO_ROOT) == "string" and _G.YSO_ROOT ~= "" then
    local r = _G.YSO_ROOT:gsub("\\", "/"):gsub("/+$", "")
    if _try_dofile(r .. "/Yso/Core/bootstrap.lua") then return true end
    if _try_dofile(r .. "/Yso/xml/bootstrap.lua")  then return true end
  end

  -- 2. Auto-detect from USERPROFILE / HOME environment variable.
  local home = (os.getenv("USERPROFILE") or os.getenv("HOME") or ""):gsub("\\", "/"):gsub("/+$", "")
  if home ~= "" then
    local roots = {
      home .. "/OneDrive/Desktop/Yso systems/Ysindrolir",
      home .. "/Desktop/Yso systems/Ysindrolir",
      home .. "/Documents/Yso systems/Ysindrolir",
    }
    for _, r in ipairs(roots) do
      if _try_dofile(r .. "/Yso/Core/bootstrap.lua") then return true end
    end
  end

  -- 3. Mudlet profile dir fallback.
  if type(getMudletHomeDir) == "function" then
    local mhome = tostring(getMudletHomeDir() or ""):gsub("\\", "/"):gsub("/+$", "")
    if mhome ~= "" then
      local roots = {
        mhome .. "/Yso/modules",
        mhome .. "/modules/Yso",
      }
      for _, r in ipairs(roots) do
        if _try_dofile(r .. "/Yso/Core/bootstrap.lua") then return true end
      end
    end
  end

  return false
end

local loaded = _find_and_load()

if loaded then
  -- bootstrap.lua ran → package.path is now extended.
  -- Re-run the require chain that "Route chassis loader" already tried
  -- (it silently failed before; now they should succeed).
  if type(require) == "function" then
    pcall(require, "Yso.Core.modes")
    pcall(require, "Yso.xml.yso_modes")
    pcall(require, "Yso.Combat.route_registry")
    pcall(require, "Yso.xml.route_registry")
    pcall(require, "Yso.Combat.route_interface")
    pcall(require, "Yso.xml.route_interface")
    -- ── ALCHEMIST MODULES ──────────────────────────────────────────
    pcall(require, "alchemist_group_damage")
    pcall(require, "alchemist_duel_route")
    pcall(require, "alchemist_aurify_route")

    -- ── MAGI MODULES ───────────────────────────────────────────────
    pcall(require, "magi_route_core")
    pcall(require, "magi_reference")
    pcall(require, "magi_dissonance")
    pcall(require, "magi_vibes")
    pcall(require, "magi_focus")
    pcall(require, "magi_group_damage")
    pcall(require, "Magi_duel_dam")

    -- ── FUTURE CLASS MODULES ────────────────────────────────────────
    -- Add new class modules here:
    --   pcall(require, "myclass_duel_route")
    --   pcall(require, "myclass_group_damage")
  end

  if type(cecho) == "function" then
    local function _yn(v) return v and "<green>YES<reset>" or "<red>NO<reset>" end
    local has_toggle = type(Yso and Yso.mode and Yso.mode.toggle_route_loop) == "function"

    -- Alchemist
    local alc = Yso and Yso.off and Yso.off.alc or {}
    -- Magi
    local magi = Yso and Yso.off and Yso.off.magi or {}

    cecho(string.format(
      "<aquamarine>[Yso:loader]<reset> bootstrap OK | modes=%s\n" ..
      "  alc : duel_route=%s  group_damage=%s  aurify_route=%s\n" ..
      "  magi: focus=%s  dmg=%s  group_damage=%s\n",
      _yn(has_toggle),
      _yn(type(alc.duel_route)    == "table"),
      _yn(type(alc.group_damage)  == "table"),
      _yn(type(alc.aurify_route)  == "table"),
      _yn(type(magi.focus)        == "table"),
      _yn(type(magi.dmg)          == "table"),
      _yn(type(magi.group_damage) == "table")
    ))
  end
else
  if type(cecho) == "function" then
    cecho("<red>[Yso:loader] bootstrap.lua not found on disk.<reset> "
      .. "Set _G.YSO_ROOT = 'path/to/Ysindrolir' before package loads.\n")
  end
end
