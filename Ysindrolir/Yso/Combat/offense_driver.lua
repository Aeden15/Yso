--========================================================--
-- Yso combat offense driver
--  * Generic route-driver compatibility shim.
--========================================================--

Yso = Yso or {}
Yso.off = Yso.off or {}
Yso.off.driver = Yso.off.driver or {}

local D = Yso.off.driver

D.cfg = D.cfg or {
  enabled = true,
  verbose = false,
}

D.state = D.state or {
  enabled = (D.cfg.enabled ~= false),
  policy = "manual",
  active = "none",
}

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _lc(s)
  return _trim(s):lower()
end

local function _sync_state()
  D.state = D.state or {}
  local M = Yso and Yso.mode or nil
  local route = ""
  if M and type(M.active_route_id) == "function" then
    local ok, v = pcall(M.active_route_id)
    if ok then route = _lc(v or "") end
  end

  D.state.enabled = (D.cfg.enabled ~= false)
  D.state.active = (route ~= "" and route) or "none"
  D.state.policy = (route ~= "" and "auto") or "manual"
  return D.state
end

function D.current_route()
  local st = _sync_state()
  local route = _lc(st.active or "")
  if route == "" or route == "none" then return nil end
  return route
end

function D.toggle(on)
  local prev = (D.state.enabled == true)
  local next_enabled = (on == nil) and (not prev) or (on == true)
  D.state.enabled = next_enabled
  D.cfg.enabled = next_enabled
  if Yso.pulse and type(Yso.pulse.wake) == "function" then
    local ok = pcall(Yso.pulse.wake, "driver:toggle")
    if not ok then
      D.state.enabled = prev
      D.cfg.enabled = prev
    end
  end
  return D.state.enabled
end

function D.set_policy(p)
  p = _lc(p or "")
  if p ~= "" then
    D.state.policy = p
    D.cfg.policy = p
  end
  _sync_state()
  return D.state.policy
end

function D.set_active(route)
  route = _lc(route or "")
  if route ~= "" then D.state.active = route end
  _sync_state()
  return D.state.active
end

function D.tick(reasons)
  _sync_state()
  local core = Yso and Yso.off and Yso.off.core or nil
  if core and type(core.tick) == "function" then
    local ok, sent = pcall(core.tick, reasons)
    return (ok and sent == true)
  end
  return false
end

_sync_state()
return D
