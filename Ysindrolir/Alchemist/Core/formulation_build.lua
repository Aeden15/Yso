Yso = Yso or {}
Yso.alc = Yso.alc or {}
Yso.alc.form = Yso.alc.form or {}

local F = Yso.alc.form

local function _trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

local function _upper_words(s)
  return tostring(s or ""):upper()
end

local function _combine(parts)
  local out = {}
  for _, part in ipairs(parts) do
    if part and part ~= "" then
      out[#out + 1] = part
    end
  end
  return table.concat(out, " " .. ((type(F.sep) == "function" and F.sep()) or "&&") .. " ")
end

function F.ensure_wielded(phial)
  if not phial or not phial.compound or phial.compound == "" then
    return nil
  end
  F.state.last_wielded = {
    id = phial.id,
    compound = phial.compound,
    at = type(F.now) == "function" and F.now() or os.time(),
  }
  return "WIELD " .. _upper_words(phial.compound)
end

local function _build_action(meta, arg)
  local name = _upper_words(meta.use_name or meta.name)
  local use_arg = _trim(arg)

  if meta.delivery == "wield_throw" or meta.delivery == "room_throw" then
    if use_arg == "" then
      if type(F.warn) == "function" then
        F.warn(meta.name .. " needs a direction or 'ground'.")
      end
      return nil
    end
    if use_arg:lower() == "ground" then
      return "THROW " .. name .. " AT GROUND"
    end
    return "THROW " .. name .. " " .. _upper_words(use_arg)
  end

  if meta.delivery == "imbibe_or_administer" then
    if use_arg == "" then
      return "IMBIBE " .. name
    end
    return "ADMINISTER " .. name .. " " .. use_arg
  end

  if meta.delivery == "imbibe" then
    if use_arg ~= "" and type(F.warn) == "function" then
      F.warn(meta.name .. " does not take a target.")
      return nil
    end
    return "IMBIBE " .. name
  end

  if meta.delivery == "special_self_imbibe" then
    if use_arg ~= "" and type(F.warn) == "function" then
      F.warn(meta.name .. " does not take a target.")
      return nil
    end
    return "IMBIBE " .. name
  end

  if meta.delivery == "enhanced_state_ability" then
    if use_arg ~= "" and type(F.warn) == "function" then
      F.warn(meta.name .. " does not take a target.")
      return nil
    end
    return name
  end

  if type(F.warn) == "function" then
    F.warn(meta.name .. " is manual/utility right now.")
  end
  return nil
end

function F.build_use(name, arg)
  local meta = type(F.resolve) == "function" and F.resolve(name) or nil
  if not meta then
    return nil
  end

  local needs_phial = meta.delivery ~= "enhanced_state_ability" and meta.delivery ~= "utility"
  local phial
  if needs_phial then
    phial = type(F.require_phial) == "function" and F.require_phial(meta.use_name or meta.name) or nil
    if not phial then
      return nil
    end
  end

  local action = _build_action(meta, arg)
  if not action then
    return nil
  end

  local parts = {}
  if meta.needs_wield then
    parts[#parts + 1] = F.ensure_wielded(phial)
  end
  parts[#parts + 1] = action

  return _combine(parts), {
    meta = meta,
    phial = phial,
    action = action,
  }
end
