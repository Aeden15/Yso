Yso = Yso or {}
Yso.bal = Yso.bal or {}
Yso.alc = Yso.alc or {}
Yso.alc.form = Yso.alc.form or {}

Yso.bal.humour = Yso.bal.humour ~= false

local F = Yso.alc.form

F.state = F.state or {}
F.phials = F.phials or {}
F.last_phiallist = F.last_phiallist or {}
F.cfg = F.cfg or {}

F.cfg.discovery = F.cfg.discovery ~= false
F.cfg.chart_path = F.cfg.chart_path or "Ysindrolir/Alchemist/Alchemical skill_reference chart"

local function _now()
  local t = (type(getEpoch) == "function" and tonumber(getEpoch())) or os.time()
  if t and t > 1000000000000 then
    t = t / 1000
  end
  return t or os.time()
end

local function _echo(msg)
  local text = string.format("[Yso:Alchemist] %s", tostring(msg or ""))
  if type(cecho) == "function" then
    cecho("\n<orange>" .. text .. "\n")
    return
  end
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

function Yso.alc.set_humour_ready(ready, source)
  Yso.bal.humour = ready and true or false
  F.state.last_humour_source = source or "unknown"
  F.state.last_humour_change = _now()
  return Yso.bal.humour
end

function Yso.alc.humour_ready()
  return Yso.bal.humour ~= false
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
