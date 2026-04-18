--========================================================--
-- finisher.lua
--  Occultist finisher route (stub -- not yet implemented).
--
--  This file is a valid but inactive route placeholder.
--  can_run() always returns false so the route system will
--  never fire commands from this module until real logic is
--  written here.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.oc = Yso.off.oc or {}

Yso.off.oc.finisher = Yso.off.oc.finisher or {}
local F = Yso.off.oc.finisher
F.alias_owned = true

F.route_contract = F.route_contract or {
  id = "oc_finisher",
  interface_version = 1,
  shared_categories = {},
  route_local_categories = { "finisher" },
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

F.cfg = F.cfg or {
  echo    = true,
  enabled = false,
}

F.state = F.state or {
  enabled      = false,
  loop_enabled = false,
  busy         = false,
  timer_id     = nil,
  explain      = {},
  template     = { last_target = "", last_reason = "", last_disable_reason = "" },
}

function F.init()
  F.cfg   = F.cfg   or {}
  F.state = F.state or {}
  return true
end

function F.is_enabled()
  return F.state and (F.state.enabled == true or F.state.loop_enabled == true)
end

function F.is_active()
  if Yso and Yso.mode and type(Yso.mode.route_loop_active) == "function" then
    return Yso.mode.route_loop_active("oc_finisher") == true
  end
  return false
end

-- Always blocked until real logic is added.
function F.can_run(ctx)
  return false, "not_implemented"
end

function F.attack_function(arg)
  return false, "not_implemented"
end

function F.build_payload(ctx)
  return nil, "not_implemented"
end

function F.alias_loop_prepare_start(ctx)
  F.state.enabled      = true
  F.state.loop_enabled = true
  F.state.busy         = false
  return ctx or {}
end

function F.alias_loop_on_started(ctx)
  F.state.busy = false
  if F.cfg.echo and type(cecho) == "function" then
    cecho("<orange>[Yso:Occultist] <HotPink>FINISHER ROUTE: not yet implemented.<reset>\n")
  end
  return true
end

function F.alias_loop_on_stopped(ctx)
  F.state.enabled      = false
  F.state.loop_enabled = false
  F.state.busy         = false
  return true
end

function F.alias_loop_clear_waiting()
  return true
end

function F.alias_loop_waiting_blocks()
  return false
end

function F.alias_loop_on_error(err)
  return true
end

F.alias_loop_stop_details = F.alias_loop_stop_details or {
  inactive        = true,
  disabled        = true,
  no_target       = true,
  paused          = true,
  target_invalid  = true,
  target_slain    = true,
  route_off       = true,
  not_implemented = true,  -- auto-stop when stub attack_function() fires
}

return F
