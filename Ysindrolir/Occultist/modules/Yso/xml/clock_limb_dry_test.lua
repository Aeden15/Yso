--========================================================--
-- Dry test: cleanseaura limb route
-- Run from Mudlet after Yso/clock/queue/net are loaded.
-- Usage: require("Yso.xml.clock_limb_dry_test") then Yso.occ.clock_dry_test_limb()
--   or from alias: lua Yso.occ.clock_dry_test_limb()
--========================================================--

Yso = Yso or {}
Yso.occ = Yso.occ or {}
Yso.occ.clock = Yso.occ.clock or {}

local function _echo(msg)
  if type(cecho) == "function" then
    cecho(string.format("<orange>[clock dry-test] <reset>%s\n", tostring(msg)))
  else
    print("[clock dry-test] " .. tostring(msg))
  end
end

function Yso.occ.clock_dry_test_limb(tgt)
  local C = Yso.occ.clock
  if not C or type(C.tick) ~= "function" then
    _echo("Yso.occ.clock.tick not found (clock module not loaded).")
    return false
  end

  -- Resolve target
  tgt = tostring(tgt or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if tgt == "" and type(Yso.get_target) == "function" then
    tgt = Yso.get_target() or ""
  end
  if tgt == "" then
    tgt = (Yso.target or rawget(_G, "target") or "TestTarget")
  end
  if type(Yso.set_target) == "function" then
    pcall(Yso.set_target, tgt)
  elseif Yso.target ~= nil then
    Yso.target = tgt
  end

  -- Force limb route and enable clock for this tick
  local old_route = C.cfg and C.cfg.route
  local old_enabled = C.cfg and C.cfg.enabled
  if not C.cfg then C.cfg = {} end
  C.cfg.route = "lim"
  C.cfg.enabled = true

  -- Enable dry_run so net layer echoes instead of sending
  Yso.net = Yso.net or {}
  Yso.net.cfg = Yso.net.cfg or {}
  local old_dry = Yso.net.cfg.dry_run
  Yso.net.cfg.dry_run = true

  _echo("Running one tick (limb route) vs " .. tostring(tgt) .. ". Output below [Yso:DRY] if queue commits.")
  local ok, err = pcall(C.tick)
  if not ok then
    _echo("tick error: " .. tostring(err))
  end

  -- Restore
  Yso.net.cfg.dry_run = old_dry
  if old_route ~= nil then C.cfg.route = old_route end
  if old_enabled ~= nil then C.cfg.enabled = old_enabled end

  _echo("Done. Check for [Yso:DRY] lines above for the payload that would have been sent.")
  return true
end

return Yso.occ.clock_dry_test_limb
