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

local function _normalize_phial_id(raw)
  local value = _trim(raw)
  if value == "" then
    return nil
  end
  local digits = value:match("^[Pp][Hh][Ii][Aa][Ll](%d+)$") or value:match("^(%d+)$")
  if not digits then
    return nil
  end
  return "Phial" .. digits
end

local function _is_permanent_months(months)
  return _trim(months) == "--"
end

local function _normalize_compound_key(name)
  local key = _key(name)
  local aliases = {
    endo = "endorphin",
    endorphin = "endorphin",
    enh = "enhancement",
    enhancement = "enhancement",
    cor = "corrosive",
    corrosive = "corrosive",
    incen = "incendiary",
    incendiary = "incendiary",
    devit = "devitalisation",
    devitalisation = "devitalisation",
    intox = "intoxicant",
    intoxicant = "intoxicant",
    vap = "vaporisation",
    vaporisation = "vaporisation",
    phos = "phosphorous",
    phosphorous = "phosphorous",
    mono = "monoxide",
    monoxide = "monoxide",
    tox = "toxin",
    toxin = "toxin",
    conc = "concussive",
    concussive = "concussive",
    halophilic = "halophilic",
  }
  return aliases[key] or key
end

local function _canonical_role(role)
  local key = _key(role):gsub("%s+", "_"):gsub("%-", "_")
  local aliases = {
    endo = "endorphin",
    endorphin = "endorphin",
    enhancement = "enhancement",
    enh = "enhancement",
    gas = "offensive_flex",
    offensive = "offensive_flex",
    flex = "offensive_flex",
    offensive_flex = "offensive_flex",
    offensive_gas = "offensive_flex",
    offensive_flex_slot = "offensive_flex",
  }
  return aliases[key]
end

local function _role_label(role_key)
  local labels = {
    endorphin = "Endorphin",
    enhancement = "Enhancement",
    offensive_flex = "Offensive gas flex",
  }
  return labels[role_key] or tostring(role_key or "Unknown")
end

local function _join_ids(rows)
  local ids = {}
  for _, row in ipairs(rows or {}) do
    ids[#ids + 1] = tostring(row.id)
  end
  table.sort(ids)
  return table.concat(ids, ", ")
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
  local compound_text = _trim(compound)
  local compound_key = _key(compound_text)
  local row = {
    id = _trim(id),
    container = _trim(id),
    kind = "phial",
    compound = compound_text,
    compound_key = compound_key,
    empty = compound_key == "empty",
    months = tonumber(months) or _trim(months),
    potency = tonumber(potency) or _trim(potency),
    volatility = tonumber(volatility) or _trim(volatility),
    stability = tonumber(stability) or _trim(stability),
    permanent = _is_permanent_months(months),
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
    permanent = _is_permanent_months(months),
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

function F.normalize_phial_id(raw)
  return _normalize_phial_id(raw)
end

function F.find_phial_by_id(raw)
  local id = _normalize_phial_id(raw)
  if not id then
    return nil
  end
  return F.phials[id]
end

function F.permanent_phials()
  local rows = {}
  for _, row in pairs(F.phials) do
    if row.kind == "phial" and row.permanent then
      rows[#rows + 1] = row
    end
  end
  table.sort(rows, function(a, b) return tostring(a.id) < tostring(b.id) end)
  return rows
end

function F.empty_phials()
  local rows = {}
  for _, row in pairs(F.phials) do
    if row.kind == "phial" and row.empty then
      rows[#rows + 1] = row
    end
  end
  table.sort(rows, function(a, b) return tostring(a.id) < tostring(b.id) end)
  return rows
end

function F.is_offensive_gas(name)
  local key = _normalize_compound_key(name)
  local pool = (F.cfg and F.cfg.offensive_gas_pool) or {}
  return pool[key] == true, key
end

function F.reserved_role(role)
  local role_key = _canonical_role(role)
  if not role_key then
    return nil, "Unknown reserved role '" .. tostring(role or "") .. "'."
  end

  local reserved = (F.cfg and F.cfg.reserved_phials) or {}
  if role_key == "endorphin" or role_key == "enhancement" then
    local id = _normalize_phial_id(reserved[role_key])
    if not id then
      return nil, _role_label(role_key) .. " slot policy is missing a phial ID."
    end
    return {
      role = role_key,
      label = _role_label(role_key),
      id = id,
      expected_compound = role_key,
    }
  end

  local pinned = _normalize_phial_id(reserved.offensive_flex or reserved.offensive)
  if pinned then
    return {
      role = role_key,
      label = _role_label(role_key),
      id = pinned,
      expected_pool = (F.cfg and F.cfg.offensive_gas_pool) or {},
    }
  end

  local permanent_rows = F.permanent_phials()
  local fixed = {}
  local endo_id = _normalize_phial_id(reserved.endorphin)
  local enh_id = _normalize_phial_id(reserved.enhancement)
  if endo_id then fixed[endo_id] = true end
  if enh_id then fixed[enh_id] = true end

  local candidates = {}
  for _, row in ipairs(permanent_rows) do
    if not fixed[row.id] then
      candidates[#candidates + 1] = row.id
    end
  end
  table.sort(candidates)

  if #candidates == 1 then
    return {
      role = role_key,
      label = _role_label(role_key),
      id = candidates[1],
      expected_pool = (F.cfg and F.cfg.offensive_gas_pool) or {},
    }
  end
  if #candidates == 0 then
    return nil, "No permanent offensive flex slot found from phiallist. Keep one permanent phial outside Endorphin/Enhancement reserved IDs."
  end
  return nil, "Multiple permanent offensive flex candidates found (" .. table.concat(candidates, ", ") .. "). Set one dedicated offensive flex slot."
end

function F.remind_reserved_mismatch(role)
  local policy, err = F.reserved_role(role)
  if not policy then
    if type(F.warn) == "function" then
      F.warn(err)
    end
    return nil, err
  end

  local row = F.phials[policy.id]
  if not row then
    local msg = policy.label .. " slot state is unknown for " .. policy.id .. ". Run PHIALLIST."
    if type(F.request_discovery) == "function" then
      F.request_discovery()
    end
    if type(F.warn) == "function" then
      F.warn(msg)
    end
    return nil, msg
  end

  if row.empty then
    return false
  end

  if policy.expected_compound and row.compound_key ~= policy.expected_compound then
    local msg = string.format("%s slot mismatch: %s currently holds %s. Use EMPTY %s when ready.", policy.label, policy.id, tostring(row.compound or "?"), policy.id:upper())
    if type(F.warn) == "function" then
      F.warn(msg)
    end
    return true, msg
  end

  if policy.expected_pool and not policy.expected_pool[row.compound_key] then
    local msg = string.format("%s slot mismatch: %s currently holds %s. Use EMPTY %s when ready.", policy.label, policy.id, tostring(row.compound or "?"), policy.id:upper())
    if type(F.warn) == "function" then
      F.warn(msg)
    end
    return true, msg
  end

  return false
end

function F.find_phial(name)
  if not name or name == "" then
    return nil
  end

  local by_id = F.find_phial_by_id(name)
  if by_id then
    return by_id
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

function F.build_adjustment(action, axis, target)
  local action_key = _key(action)
  if action_key ~= "enhance" and action_key ~= "dilute" then
    if type(F.warn) == "function" then
      F.warn("Adjustment action must be ENHANCE or DILUTE.")
    end
    return nil
  end

  local axis_key = _key(axis)
  local valid_axis = {
    potency = true,
    stability = true,
    volatility = true,
  }
  if not valid_axis[axis_key] then
    if type(F.warn) == "function" then
      F.warn("Adjustment axis must be POTENCY, STABILITY, or VOLATILITY.")
    end
    return nil
  end

  local target_text = _trim(target)
  if target_text == "" then
    if type(F.warn) == "function" then
      F.warn("Adjustment target is required.")
    end
    return nil
  end

  local phial_id = _normalize_phial_id(target_text)
  if phial_id then
    target_text = phial_id
  else
    target_text = _normalize_compound_key(target_text)
  end

  return string.format("%s %s OF %s", action_key:upper(), axis_key:upper(), target_text:upper())
end

function F.send_adjustment(action, axis, target)
  local cmd = F.build_adjustment(action, axis, target)
  if not cmd then
    return nil
  end
  if type(send) == "function" then
    send(cmd)
  end
  return cmd
end

function F.build_role_amalgamate(role, compound)
  local policy, err = F.reserved_role(role)
  if not policy then
    if type(F.warn) == "function" then
      F.warn(err)
    end
    return nil
  end

  if next(F.phials or {}) == nil then
    if type(F.request_discovery) == "function" then
      F.request_discovery()
    end
    if type(F.warn) == "function" then
      F.warn("Unsafe Amalgamate state: phiallist is unknown. Run PHIALLIST.")
    end
    return nil
  end

  local desired_compound = _normalize_compound_key(compound or policy.expected_compound or "")
  if desired_compound == "" then
    if type(F.warn) == "function" then
      F.warn(policy.label .. " helper needs a compound.")
    end
    return nil
  end

  if policy.expected_compound and desired_compound ~= policy.expected_compound then
    if type(F.warn) == "function" then
      F.warn(policy.label .. " helper expects " .. policy.expected_compound:sub(1, 1):upper() .. policy.expected_compound:sub(2) .. ".")
    end
    return nil
  end

  if policy.expected_pool then
    local ok = policy.expected_pool[desired_compound] == true
    if not ok then
      if type(F.warn) == "function" then
        F.warn("Offensive gas flex pool excludes " .. desired_compound:sub(1, 1):upper() .. desired_compound:sub(2) .. ".")
      end
      return nil
    end
  end

  local slot = F.phials[policy.id]
  if not slot then
    if type(F.warn) == "function" then
      F.warn("Unsafe Amalgamate state: " .. policy.id .. " is missing from current phiallist. Run PHIALLIST.")
    end
    if type(F.request_discovery) == "function" then
      F.request_discovery()
    end
    return nil
  end

  if not slot.empty then
    local msg = string.format("%s slot mismatch: %s currently holds %s. Use EMPTY %s when ready.", policy.label, policy.id, tostring(slot.compound or "?"), policy.id:upper())
    if type(F.warn) == "function" then
      F.warn(msg)
    end
    return nil
  end

  local empties = F.empty_phials()
  if #empties ~= 1 or empties[1].id ~= policy.id then
    if #empties > 1 then
      if type(F.warn) == "function" then
        F.warn("Unsafe Amalgamate state: multiple empty phials detected (" .. _join_ids(empties) .. "). Keep only " .. policy.id .. " empty before AMALGAMATE " .. desired_compound:upper() .. ".")
      end
      return nil
    end
    if #empties == 0 then
      if type(F.warn) == "function" then
        F.warn("Unsafe Amalgamate state: " .. policy.id .. " is not empty. Use EMPTY " .. policy.id:upper() .. " when ready.")
      end
      return nil
    end
    if type(F.warn) == "function" then
      F.warn("Unsafe Amalgamate state: " .. policy.id .. " must be the only empty phial before AMALGAMATE " .. desired_compound:upper() .. ".")
    end
    return nil
  end

  return "AMALGAMATE " .. desired_compound:upper(), {
    role = policy.role,
    role_label = policy.label,
    phial_id = policy.id,
    compound = desired_compound,
  }
end

function F.send_role_amalgamate(role, compound)
  local cmd, context = F.build_role_amalgamate(role, compound)
  if not cmd then
    return nil
  end

  if type(send) == "function" then
    send(cmd)
    send("phiallist")
  end
  F.state.last_amalgamate = {
    cmd = cmd,
    role = context and context.role,
    phial_id = context and context.phial_id,
    compound = context and context.compound,
    at = type(F.now) == "function" and F.now() or os.time(),
  }
  return cmd, context
end

function F.build_endorphin_amalgamate()
  return F.build_role_amalgamate("endorphin", "endorphin")
end

function F.build_enhancement_amalgamate()
  return F.build_role_amalgamate("enhancement", "enhancement")
end

function F.build_offensive_gas_amalgamate(compound)
  return F.build_role_amalgamate("offensive_flex", compound)
end

function F.send_endorphin_amalgamate()
  return F.send_role_amalgamate("endorphin", "endorphin")
end

function F.send_enhancement_amalgamate()
  return F.send_role_amalgamate("enhancement", "enhancement")
end

function F.send_offensive_gas_amalgamate(compound)
  return F.send_role_amalgamate("offensive_flex", compound)
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
    local permanence = row.permanent and " permanent" or ""
    if row.empty then
      lines[#lines + 1] = string.format("%s -> Empty (%s months%s, qty %s)", id, tostring(row.months or "?"), permanence, tostring(row.quantity or "?"))
    else
      lines[#lines + 1] = string.format(
        "%s -> %s (%s months%s, p%s v%s s%s)",
        id,
        tostring(row.compound or "?"),
        tostring(row.months or "?"),
        permanence,
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
