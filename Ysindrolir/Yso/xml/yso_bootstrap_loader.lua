--========================================================--
-- Yso Bootstrap Loader
--
--  Disk vs Mudlet (bidirectional):
--    • Prefer editing Lua on disk in this repo, then re-embed the Mudlet package
--      with Ysindrolir/scripts/export_yso_system_xml.ps1 (see script header there).
--    • If you tweak this script inside Mudlet's editor, copy the result back into
--      Ysindrolir/Yso/xml/yso_bootstrap_loader.lua so the repo stays canonical.
--
--  YSO_ROOT (optional, recommended if install path is nonstandard):
--    Set the environment variable YSO_ROOT to your Ysindrolir repo root — the
--    directory that contains the Yso/ folder (same value as _G.YSO_ROOT).
--    Precedence in this loader: (1) _G.YSO_ROOT if set, (2) getMudletHomeDir()
--    heuristics, (3) os.getenv("YSO_ROOT"), (4) USERPROFILE/Desktop fallbacks.
--    Examples (comments only — do not paste into Lua):
--      setx YSO_ROOT "C:\path\to\Ysindrolir"
--      $env:YSO_ROOT = "C:\path\to\Ysindrolir"   # PowerShell: current session
--
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
--  ADDING A NEW CLASS (checklist):
--    1. Implement route modules under Ysindrolir/<Class>/ or Ysindrolir/Yso/… and
--       ensure package.path / bootstrap can require() them by module name.
--    2. Register ids + toggle aliases in:
--         Ysindrolir/Yso/Combat/route_registry.lua
--       (keep Yso/xml/route_registry.lua in sync if you maintain the mirror.)
--    3. Add pcall(require, "…") lines in BOTH places below so disk ↔ Mudlet stay
--       aligned:
--         • CLASS MODULES (this script)
--         • Ysindrolir/Yso/xml/route_chassis_loader.lua  → embedded as the
--           Mudlet script "Route chassis loader" (re-embed via export script).
--    4. Re-run: Ysindrolir/scripts/export_yso_system_xml.ps1
--    5. Optional: extend the loader status echo if you want visibility for new
--       Yso.off.<namespace> tables.
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
  local function try_repo_root(r)
    r = tostring(r or ""):gsub("\\", "/"):gsub("/+$", "")
    if r == "" then return false end
    if _try_dofile(r .. "/Yso/Core/bootstrap.lua") then return true end
    if _try_dofile(r .. "/Yso/xml/bootstrap.lua") then return true end
    return false
  end

  -- 1. Explicit global (canonical for automation / imports).
  if type(_G.YSO_ROOT) == "string" and _G.YSO_ROOT ~= "" then
    if try_repo_root(_G.YSO_ROOT) then return true end
  end

  -- 2. Mudlet profile / install dirs (no hardcoded OneDrive).
  if type(getMudletHomeDir) == "function" then
    local mhome = tostring(getMudletHomeDir() or ""):gsub("\\", "/"):gsub("/+$", "")
    if mhome ~= "" then
      local roots = {
        mhome .. "/Yso/modules",
        mhome .. "/modules/Yso",
        mhome .. "/Ysindrolir",
      }
      for _, r in ipairs(roots) do
        if try_repo_root(r) then return true end
      end
    end
  end

  -- 3. Environment: YSO_ROOT, then USERPROFILE/HOME heuristics.
  local env_root = os.getenv("YSO_ROOT")
  if type(env_root) == "string" and env_root ~= "" then
    if try_repo_root(env_root) then return true end
  end

  local home = (os.getenv("USERPROFILE") or os.getenv("HOME") or ""):gsub("\\", "/"):gsub("/+$", "")
  if home ~= "" then
    local roots = {
      home .. "/OneDrive/Desktop/Yso systems/Ysindrolir",
      home .. "/Desktop/Yso systems/Ysindrolir",
      home .. "/Documents/Yso systems/Ysindrolir",
    }
    for _, r in ipairs(roots) do
      if try_repo_root(r) then return true end
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

    -- ── MAGI MODULES (keep order identical to route_chassis_loader.lua) ──
    pcall(require, "magi_route_core")
    pcall(require, "magi_reference")
    pcall(require, "magi_dissonance")
    pcall(require, "magi_vibes")
    pcall(require, "magi_focus")
    pcall(require, "magi_group_damage")
    pcall(require, "Magi_duel_dam")
  end

  if type(cecho) == "function" then
    local function _yn(v) return v and "<green>YES<reset>" or "<red>NO<reset>" end
    local has_toggle = type(Yso and Yso.mode and Yso.mode.toggle_route_loop) == "function"

    -- Alchemist
    local alc = Yso and Yso.off and Yso.off.alc or {}
    -- Magi (offense routes under Yso.off.magi; mass-embed helper under Yso.magi.vibes)
    local magi = Yso and Yso.off and Yso.off.magi or {}
    local magi_vibes = Yso and Yso.magi and Yso.magi.vibes
    local vibes_ok = type(magi_vibes) == "table" and type(magi_vibes.run) == "function"

    cecho(string.format(
      "<aquamarine>[Yso:loader]<reset> bootstrap OK | modes=%s\n" ..
      "  alc : duel_route=%s  group_damage=%s  aurify_route=%s\n" ..
      "  magi: vibes=%s  focus=%s  dmg=%s  group_damage=%s\n",
      _yn(has_toggle),
      _yn(type(alc.duel_route)    == "table"),
      _yn(type(alc.group_damage)  == "table"),
      _yn(type(alc.aurify_route)  == "table"),
      _yn(vibes_ok),
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
