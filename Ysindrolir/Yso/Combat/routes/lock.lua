--========================================================--
-- lock.lua
--  Occultist lock route (stub -- not yet implemented).
--
--  This file is a valid but inactive route placeholder.
--  can_run() always returns false so the route system will
--  never fire commands from this module until real logic is
--  written here.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

Yso.off.oc.lock = Yso.off.oc.lock or {}
local L = Yso.off.oc.lock
L.alias_owned = true

L.route_contract = L.route_contract or {
  id = "oc_lock",
  interface_version = 1,
  shared_categories = {},
  route_local_categories = { "lock" },
  capabilities = {
    uses_eq   = true,
    uses_bal  = true,
    uses_entity = false,
    needs_target = true,
  },
  override_policy = {
    mode    = "narrow_global_only",
    allowed = {
      target_invalid = true,
      target_slain   = true,
      route_off      = true,
      pause          = true,
    },
  },
  lifecycle = {
    on_enter  = true,
    on_exit   = true,
    evaluate  = true,
    explain   = true,
  },
}

L.cfg = L.cfg or {
  echo    = true,
  enabled = false,
}

L.state = L.state or {
  enabled      = false,
  loop_enabled = false,
  busy         = false,
  timer_id     = nil,
  explain      = {},
  template     = { last_target = "", last_reason = "", last_disable_reason = "" },
}

function L.init()
  L.cfg   = L.cfg   or {}
  L.state = L.state or {}
  return true
end

function L.is_enabled()
  return L.state and (L.state.enabled == true or L.state.loop_enabled == true)
end

function L.is_active()
  if Yso and Yso.mode and type(Yso.mode.route_loop_active) == "function" then
    return Yso.mode.route_loop_active("oc_lock") == true
  end
  return false
end

-- Always blocked until real logic is added.
function L.can_run(ctx)
  return false, "not_implemented"
end

function L.attack_function(arg)
  return false, "not_implemented"
end

function L.build_payload(ctx)
  return nil, "not_implemented"
end

function L.alias_loop_prepare_start(ctx)
  L.state.enabled      = true
  L.state.loop_enabled = true
  L.state.busy         = false
  return ctx or {}
end

function L.alias_loop_on_started(ctx)
  L.state.busy = false
  if L.cfg.echo and type(cecho) == "function" then
    cecho("<orange>[Yso:Occultist] <HotPink>LOCK ROUTE: not yet implemented.<reset>\n")
  end
  return true
end

function L.alias_loop_on_stopped(ctx)
  L.state.enabled      = false
  L.state.loop_enabled = false
  L.state.busy         = false
  return true
end

function L.alias_loop_clear_waiting()
  return true
end

function L.alias_loop_waiting_blocks()
  return false
end

function L.alias_loop_on_error(err)
  return true
end

L.alias_loop_stop_details = L.alias_loop_stop_details or {
  inactive        = true,
  disabled        = true,
  no_target       = true,
  paused          = true,
  target_invalid  = true,
  target_slain    = true,
  route_off       = true,
  not_implemented = true,  -- auto-stop when stub attack_function() fires
}

return L
