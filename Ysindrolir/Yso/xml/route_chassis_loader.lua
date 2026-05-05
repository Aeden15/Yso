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
