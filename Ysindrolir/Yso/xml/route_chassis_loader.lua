-- Canonical copy for Mudlet script "Route chassis loader" in Yso system.xml.
-- Mudlet-native mode: no require/bootstrap loading, only table guards.

Yso = Yso or {}
Yso.bootstrap = Yso.bootstrap or {}
Yso.bootstrap.mode = "mudlet_native"

Yso.load_order_contract = Yso.load_order_contract or {
  "foundation",
  "core_state_queue_modes",
  "curing_helpers",
  "combat_shared_interface",
  "class_routes_alchemist_then_magi",
  "integration_events_aliases",
}

Yso.Combat = Yso.Combat or {}
Yso.Combat.RouteInterface = Yso.Combat.RouteInterface or {}
if type(Yso.Combat.RouteInterface.ensure_hooks) ~= "function" then
  Yso.Combat.RouteInterface.ensure_hooks = function(routeTable, routeContract)
    if type(routeTable) == "table" and type(routeContract) == "table" then
      routeTable.route_contract = routeTable.route_contract or routeContract
    end
    return routeTable
  end
end

-- #region agent log
local function _yso_dbg_log(hypothesisId, message, data)
  local payload = {
    sessionId = "f528bd",
    runId = "baseline",
    hypothesisId = hypothesisId,
    location = "route_chassis_loader.lua",
    message = message,
    data = data or {},
    timestamp = os.time() * 1000,
  }
  local ok, json = pcall(yajl.to_string, payload)
  if not ok or type(json) ~= "string" then return end
  local f = io.open("C:/Users/shuji/OneDrive/Desktop/Yso systems/debug-f528bd.log", "a")
  if not f then return end
  f:write(json .. "\n")
  f:close()
end

_yso_dbg_log("H1", "route_chassis_loader_ran", {
  has_mode_table = type(Yso.mode) == "table",
  has_toggle_route_loop = type(Yso.mode and Yso.mode.toggle_route_loop) == "function",
  has_route_registry = type(Yso.Combat and Yso.Combat.RouteRegistry) == "table",
  has_routeinterface_hooks = type(Yso.Combat.RouteInterface.ensure_hooks) == "function",
})
-- #endregion

-- #region agent log
Yso._dbg_alias = Yso._dbg_alias or {}
if Yso._dbg_alias.adam_probe and type(killAlias) == "function" then
  pcall(killAlias, Yso._dbg_alias.adam_probe)
  Yso._dbg_alias.adam_probe = nil
end
if type(tempAlias) == "function" then
  Yso._dbg_alias.adam_probe = tempAlias([[^adam$]], function()
    _yso_dbg_log("H2", "adam_command_probe", {
      has_toggle_route_alias = type(Yso.util and Yso.util.toggle_route_alias) == "function",
      has_mode_toggle_route_loop = type(Yso.mode and Yso.mode.toggle_route_loop) == "function",
      mode_state = tostring(Yso.mode and Yso.mode.state or ""),
      has_active_route_id = type(Yso.mode and Yso.mode.active_route_id) == "function",
    })
  end)
end
-- #endregion
