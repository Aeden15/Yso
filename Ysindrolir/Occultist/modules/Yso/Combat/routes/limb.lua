--========================================================--
-- limb.lua (deprecated stub)
--  Temporary guard route until real limb strategy is implemented.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

local ROUTE_ID = "limb"
local R = Yso.off.oc[ROUTE_ID] or {}
Yso.off.oc[ROUTE_ID] = R

R.alias_owned = true
R.route_contract = R.route_contract or {
  id = ROUTE_ID,
  interface_version = 1,
  shared_categories = { "defense_break", "anti_tumble" },
  route_local_categories = { "deprecated" },
  capabilities = {
    uses_eq = false,
    uses_bal = false,
    uses_entity = false,
    supports_burst = false,
    supports_bootstrap = false,
    needs_target = false,
    shares_defense_break = false,
    shares_anti_tumble = false,
  },
  override_policy = { mode = "narrow_global_only", allowed = {} },
  lifecycle = {
    on_enter = true,
    on_exit = true,
    on_target_swap = true,
    on_pause = true,
    on_resume = true,
    on_manual_success = true,
    on_send_result = true,
    evaluate = true,
    explain = true,
  },
}

local function _warn()
  if type(cecho) == "function" then
    cecho(string.format("<orange>[Yso:%s] deprecated route stub; not implemented.\n", ROUTE_ID))
  end
end

function R.attack_function(_)
  _warn()
  return false
end

function R.build_payload(_)
  return { route = ROUTE_ID, lanes = {} }
end

function R.evaluate(_)
  return { ok = false, reason = "deprecated_route_stub" }
end

function R.explain()
  return { route = ROUTE_ID, deprecated = true }
end

function R.on_send_result(_, _)
  return false
end

function R.on_enter()
  return true
end

function R.on_exit()
  return true
end

function R.on_target_swap()
  return true
end

function R.on_pause()
  return true
end

function R.on_resume()
  return true
end

function R.on_manual_success()
  return true
end

return R
