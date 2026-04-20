Yso = Yso or {}
Yso.alc = Yso.alc or {}
Yso.alc.form = Yso.alc.form or {}

local F = Yso.alc.form

F.state = F.state or {}
F.phials = F.phials or {}
F.last_phiallist = F.last_phiallist or {}

local function _trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

local function _key(name)
  return _trim(name):lower()
end

local function _append_raw(line)
  table.insert(F.last_phiallist, line)
  F.state.last_phiallist = table.concat(F.last_phiallist, "\n")
end

local function _clear_for_header(line)
  if line:match("^%s*Phial%s*|%s*Compound%s*|%s*Months%s*|%s*Potency") then
    F.reset_phials()
    return true
  end
  if line:match("^%s*Phial%s*|%s*Compound%s*|%s*Months left%s*|%s*Quantity") then
    if next(F.phials) == nil then
      F.last_phiallist = {}
    end
    return true
  end
  return false
end

local function _store_filled(id, compound, months, potency, volatility, stability)
  if not id:match("^Phial") then
    return nil
  end
  local row = {
    id = _trim(id),
    container = _trim(id),
    kind = "phial",
    compound = _trim(compound),
    compound_key = _key(compound),
    empty = false,
    months = tonumber(months) or _trim(months),
    potency = tonumber(potency) or _trim(potency),
    volatility = tonumber(volatility) or _trim(volatility),
    stability = tonumber(stability) or _trim(stability),
    seen_at = type(F.now) == "function" and F.now() or os.time(),
  }
  F.phials[row.id] = row
  F.note_phiallist()
  return row
end

local function _store_empty(id, months, quantity)
  if not id:match("^Phial") then
    return nil
  end
  local row = {
    id = _trim(id),
    container = _trim(id),
    kind = "phial",
    compound = "Empty",
    compound_key = "empty",
    empty = true,
    months = tonumber(months) or _trim(months),
    quantity = tonumber(quantity) or _trim(quantity),
    seen_at = type(F.now) == "function" and F.now() or os.time(),
  }
  F.phials[row.id] = row
  F.note_phiallist()
  return row
end

function F.parse_phiallist(line_or_block)
  if type(line_or_block) ~= "string" or line_or_block == "" then
    return nil
  end

  if line_or_block:find("\n", 1, true) or line_or_block:find("\r", 1, true) then
    local parsed
    for line in line_or_block:gmatch("[^\r\n]+") do
      parsed = F.parse_phiallist(line) or parsed
    end
    return parsed
  end

  local line = _trim(line_or_block)
  if line == "" then
    return nil
  end

  _append_raw(line)

  if line:match("^%s*Vial") or line:find("| Vial", 1, true) then
    return nil
  end

  if _clear_for_header(line) then
    return nil
  end

  local id, compound, months, potency, volatility, stability =
    line:match("^(Phial[%w%d]+)%s*|%s*([^|]+)%s*|%s*([^|]+)%s*|%s*([^|]+)%s*|%s*([^|]+)%s*|%s*([^|]+)%s*$")
  if id then
    return _store_filled(id, compound, months, potency, volatility, stability)
  end

  local eid, emonths, quantity =
    line:match("^(Phial[%w%d]+)%s*|%s*Empty%s*|%s*([^|]+)%s*|%s*([^|]+)%s*$")
  if eid then
    return _store_empty(eid, emonths, quantity)
  end

  return nil
end

function F.find_phial(name)
  if not name or name == "" then
    return nil
  end

  local target = _key(name)
  if type(F.resolve) == "function" then
    local meta = F.resolve(name)
    if meta and meta.use_name then
      target = _key(meta.use_name)
    elseif meta and meta.key then
      target = meta.key
    end
  end

  local ids = {}
  for id, row in pairs(F.phials) do
    if row.kind == "phial" and not row.empty and row.compound_key == target then
      ids[#ids + 1] = id
    end
  end

  table.sort(ids)
  if ids[1] then
    return F.phials[ids[1]]
  end
  return nil
end

function F.require_phial(name)
  local phial = F.find_phial(name)
  if phial then
    return phial
  end

  local requested = tostring(name or "unknown")
  if F.cfg and F.cfg.discovery ~= false and type(F.request_discovery) == "function" and F.request_discovery() then
    if type(F.warn) == "function" then
      F.warn("No phial found for " .. requested .. ". Requested phiallist refresh.")
    end
    return nil
  end

  if type(F.warn) == "function" then
    F.warn("No phial found for " .. requested .. ".")
  end
  return nil
end

function F.show_phials()
  local ids = {}
  for id in pairs(F.phials) do
    ids[#ids + 1] = id
  end
  table.sort(ids)

  if #ids == 0 then
    if type(F.warn) == "function" then
      F.warn("No known phials.")
    end
    return {}
  end

  local lines = {}
  for _, id in ipairs(ids) do
    local row = F.phials[id]
    if row.empty then
      lines[#lines + 1] = string.format("%s -> Empty (%s months, qty %s)", id, tostring(row.months or "?"), tostring(row.quantity or "?"))
    else
      lines[#lines + 1] = string.format(
        "%s -> %s (%s months, p%s v%s s%s)",
        id,
        tostring(row.compound or "?"),
        tostring(row.months or "?"),
        tostring(row.potency or "?"),
        tostring(row.volatility or "?"),
        tostring(row.stability or "?")
      )
    end
  end

  if type(F.warn) == "function" then
    F.warn("Known phials:\n" .. table.concat(lines, "\n"))
  end
  return lines
end
