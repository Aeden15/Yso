-- DO NOT EDIT IN XML; edit this file instead.

Yso = Yso or {}
Yso.entities = Yso.entities or {}

local E = Yso.entities

E.state = E.state or {
  ready = true,
  ready_reason = "init",
  active_pet = nil,
  active_pet_reason = "",
  last_command = nil,
}

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    v = ok and tonumber(v) or nil
    if v then return v end
  end
  if type(getEpoch) == "function" then
    local ok, v = pcall(getEpoch)
    v = ok and tonumber(v) or nil
    if v then
      if v > 1e12 then v = v / 1000 end
      return v
    end
  end
  return os.time()
end

local function _send(cmd, opts)
  opts = type(opts) == "table" and opts or {}
  if opts.dry_run == true or (Yso.net and Yso.net.cfg and Yso.net.cfg.dry_run == true) then
    return true, "dry_run"
  end
  if type(opts.sender) == "function" then
    opts.sender(cmd)
    return true, "sender"
  end
  if type(send) == "function" then
    send(cmd, false)
    return true, "send"
  end
  return false, "send_unavailable"
end

function E.ready()
  return E.state.ready == true
end

function E.set_ready(value, reason)
  E.state.ready = (value == true)
  E.state.ready_reason = _trim(reason)
  E.state.ready_at = _now()
  return E.state.ready
end

function E.active_pet()
  return E.state.active_pet
end

function E.set_active_pet(name, reason)
  name = _trim(name)
  if name == "" then return E.clear(reason or "empty_pet") end
  E.state.active_pet = name
  E.state.active_pet_reason = _trim(reason)
  E.state.active_pet_at = _now()
  return name
end

function E.clear(reason)
  E.state.active_pet = nil
  E.state.active_pet_reason = _trim(reason)
  E.state.active_pet_at = _now()
  return true
end

function E.command(cmd, opts)
  cmd = _trim(cmd)
  opts = type(opts) == "table" and opts or {}
  if cmd == "" then return false, "empty_command" end
  if E.ready() ~= true and opts.force ~= true then
    return false, E.state.ready_reason ~= "" and E.state.ready_reason or "not_ready"
  end

  local ok, via = _send(cmd, opts)
  E.state.last_command = {
    command = cmd,
    ok = ok == true,
    via = via,
    at = _now(),
    reason = _trim(opts.reason),
  }
  if ok then
    E.set_ready(false, opts.pending_reason or "command_sent")
  end
  return ok, via
end

return E
