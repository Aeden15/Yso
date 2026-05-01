Yso = Yso or {}
Yso.alc = Yso.alc or {}
Yso.alc.form = Yso.alc.form or {}

local F = Yso.alc.form

F.state = F.state or {}
F.phials = F.phials or {}
F.last_phiallist = F.last_phiallist or {}
F.cfg = F.cfg or {}
F._eh = F._eh or {}

F.cfg.discovery = F.cfg.discovery ~= false
F.cfg.chart_path = F.cfg.chart_path or "Ysindrolir/Alchemist/Alchemical skill_reference chart"
F.cfg.reserved_phials = F.cfg.reserved_phials or {
  endorphin = "Phial658898",
  enhancement = "Phial475762",
}
F.cfg.offensive_gas_pool = F.cfg.offensive_gas_pool or {
  corrosive = true,
  incendiary = true,
  devitalisation = true,
  intoxicant = true,
  vaporisation = true,
  phosphorous = true,
  monoxide = true,
  toxin = true,
  concussive = true,
}

local function _now()
  local t = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  if t and t > 1000000000000 then
    t = t / 1000
  end
  return t or os.time()
end

local function _echo(msg)
  local payload = tostring(msg or "")
  if type(cecho) == "function" then
    cecho("\n<gold>[FORMULATION:] <aquamarine>" .. payload .. "\n")
    return
  end
  local text = string.format("[FORMULATION:] %s", payload)
  if type(echo) == "function" then
    echo("\n" .. text .. "\n")
    return
  end
  if type(print) == "function" then
    print(text)
  end
end

local function _sep()
  if type(Yso.sep) == "string" and Yso.sep ~= "" then
    return Yso.sep
  end
  if type(Yso.cfg) == "table" and type(Yso.cfg.pipe_sep) == "string" and Yso.cfg.pipe_sep ~= "" then
    return Yso.cfg.pipe_sep
  end
  return "&&"
end

function F.warn(msg)
  _echo(msg)
end

function F.now()
  return _now()
end

function F.sep()
  return _sep()
end

function F.reset_phials()
  F.phials = {}
  F.last_phiallist = {}
  F.state.discovery_requested = false
  F.state.discovery_requested_at = nil
  F.state.last_phiallist_at = _now()
end

function F.note_phiallist()
  F.state.last_phiallist_at = _now()
  F.state.discovery_requested = false
  if F.state.validate_reserved_on_next_phiallist == true and type(F.validate_reserved_policy) == "function" then
    F.state.validate_reserved_on_next_phiallist = false
    local ok, validate_ok = pcall(F.validate_reserved_policy, "phiallist")
    if not ok then
      local err = tostring(validate_ok or "unknown")
      F.state.last_reserved_validate_error = err
      if F.state.last_reserved_validate_error_seen ~= err then
        F.state.last_reserved_validate_error_seen = err
        F.warn("reserved policy validation error (" .. err .. ")")
      end
    end
  end
end

function F.request_discovery()
  if F.state.discovery_requested then
    return false
  end
  F.state.discovery_requested = true
  F.state.discovery_requested_at = _now()
  if type(send) == "function" then
    send("phiallist")
  end
  return true
end

function F.validate_reserved_policy(reason)
  if type(F.remind_reserved_mismatch) ~= "function" then
    return false, "reserved_policy_unavailable"
  end
  local ok = true
  local roles = { "endorphin", "enhancement" }
  for i = 1, #roles do
    local _, err = F.remind_reserved_mismatch(roles[i])
    if err then ok = false end
  end
  F.state.last_reserved_validate_at = _now()
  F.state.last_reserved_validate_reason = tostring(reason or "manual")
  return ok
end

-- Validate reserved-slot policy each login/session reconnect and request
-- a fresh phiallist snapshot when discovery is enabled.
if type(registerAnonymousEventHandler) == "function" then
  if F._eh.connection then
    pcall(killAnonymousEventHandler, F._eh.connection)
  end
  F._eh.connection = registerAnonymousEventHandler("sysConnectionEvent", function()
    F.state.validate_reserved_on_next_phiallist = true
    if F.cfg.discovery ~= false and type(F.request_discovery) == "function" then
      pcall(F.request_discovery)
    end
  end)
end
