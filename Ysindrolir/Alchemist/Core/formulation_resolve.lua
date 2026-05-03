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

local function _key(s)
  return _trim(s):lower()
end

local function _source_dir()
  local info = debug.getinfo(1, "S")
  local src = info and info.source or ""
  if src:sub(1, 1) == "@" then
    src = src:sub(2)
  end
  return src:match("^(.*)[/\\][^/\\]+$") or ""
end

local function _chart_paths()
  local paths = {}
  if F.cfg and F.cfg.chart_path then
    paths[#paths + 1] = F.cfg.chart_path
  end

  local dir = _source_dir()
  if dir ~= "" then
    local base = dir:gsub("[/\\]Core$", "")
    paths[#paths + 1] = base .. "\\Alchemical skill_reference chart"
    paths[#paths + 1] = base .. "/Alchemical skill_reference chart"
  end

  paths[#paths + 1] = "Ysindrolir/Alchemist/Alchemical skill_reference chart"
  return paths
end

local function _read_chart()
  local tried = {}
  for _, path in ipairs(_chart_paths()) do
    if path and path ~= "" and not tried[path] then
      tried[path] = true
      local handle = io.open(path, "r")
      if handle then
        local text = handle:read("*a")
        handle:close()
        if text and text ~= "" then
          return text, path
        end
      end
    end
  end
  return nil, nil
end

local function _shape(meta)
  if not meta then
    return nil
  end

  meta.key = meta.key or _key(meta.name)
  meta.syntax = meta.syntax or {}
  meta.delivery = meta.delivery or "utility"
  meta.needs_wield = meta.delivery == "wield_throw" or meta.delivery == "room_throw"

  if meta.delivery == "wield_throw" or meta.delivery == "room_throw" then
    meta.target_mode = "ground_or_direction"
  elseif meta.delivery == "imbibe_or_administer" then
    meta.target_mode = "optional_target"
  elseif meta.delivery == "imbibe" or meta.delivery == "special_self_imbibe" or meta.delivery == "enhanced_state_ability" then
    meta.target_mode = "self"
  else
    meta.target_mode = "manual"
  end

  for _, syntax in ipairs(meta.syntax) do
    local wield_name = syntax:match("^WIELD%s+([A-Z][A-Z]+)")
    if wield_name then
      meta.use_name = wield_name:sub(1, 1) .. wield_name:sub(2):lower()
      break
    end
  end

  if not meta.use_name then
    for _, syntax in ipairs(meta.syntax) do
      local imbibe_name = syntax:match("^IMBIBE%s+([A-Z][A-Z]+)")
      if imbibe_name then
        meta.use_name = imbibe_name:sub(1, 1) .. imbibe_name:sub(2):lower()
        break
      end
    end
  end

  if not meta.use_name and meta.delivery == "enhanced_state_ability" then
    meta.use_name = meta.name
  end

  meta.use_name = meta.use_name or meta.name
  meta.use_key = _key(meta.use_name)

  return meta
end

local function _default_defs()
  local defs = {
    endorphin = _shape{ name = "Endorphin", syntax = { "WIELD ENDORPHIN", "THROW ENDORPHIN <AT GROUND|DIRECTION>" }, delivery = "wield_throw" },
    nutritional = _shape{ name = "Nutritional", syntax = { "IMBIBE NUTRITIONAL", "ADMINISTER NUTRITIONAL <target>" }, delivery = "imbibe_or_administer" },
    corrosive = _shape{ name = "Corrosive", syntax = { "WIELD CORROSIVE", "THROW CORROSIVE <AT GROUND|DIRECTION>" }, delivery = "wield_throw" },
    petrifying = _shape{ name = "Petrifying", syntax = { "IMBIBE PETRIFYING" }, delivery = "imbibe" },
    incendiary = _shape{ name = "Incendiary", syntax = { "WIELD INCENDIARY", "THROW INCENDIARY <AT GROUND|DIRECTION>" }, delivery = "wield_throw" },
    alteration = _shape{ name = "Alteration", syntax = { "ENHANCE POTENCY|STABILITY|VOLATILITY OF <compound>", "DILUTE POTENCY|STABILITY|VOLATILITY OF <compound>", "AMALGAMATE <compound>" }, delivery = "utility" },
    devitalisation = _shape{ name = "Devitalisation", syntax = { "WIELD DEVITALISATION", "THROW DEVITALISATION <AT GROUND|DIRECTION>" }, delivery = "wield_throw" },
    intoxicant = _shape{ name = "Intoxicant", syntax = { "WIELD INTOXICANT", "THROW INTOXICANT <AT GROUND|DIRECTION>" }, delivery = "wield_throw" },
    vaporisation = _shape{ name = "Vaporisation", syntax = { "WIELD VAPORISATION", "THROW VAPORISATION <AT GROUND|DIRECTION>" }, delivery = "wield_throw" },
    phosphorous = _shape{ name = "Phosphorous", syntax = { "WIELD PHOSPHOROUS", "THROW PHOSPHOROUS <AT GROUND|DIRECTION>" }, delivery = "wield_throw" },
    monoxide = _shape{ name = "Monoxide", syntax = { "WIELD MONOXIDE", "THROW MONOXIDE <AT GROUND|DIRECTION>" }, delivery = "wield_throw" },
    toxin = _shape{ name = "Toxin", syntax = { "WIELD TOXIN", "THROW TOXIN <AT GROUND|DIRECTION>" }, delivery = "wield_throw" },
    concussive = _shape{ name = "Concussive", syntax = { "WIELD CONCUSSIVE", "THROW CONCUSSIVE <AT GROUND|DIRECTION>" }, delivery = "wield_throw" },
    mayology = _shape{ name = "Mayology", syntax = { "AMALGAMATE DESTRUCTIVE", "IMBIBE DESTRUCTIVE" }, delivery = "special_self_imbibe" },
    halophilic = _shape{ name = "Halophilic", syntax = { "WIELD HALOPHILIC", "THROW HALOPHILIC <DIRECTION|AT GROUND>" }, delivery = "room_throw" },
    enhancement = _shape{ name = "Enhancement", syntax = { "IMBIBE ENHANCEMENT" }, delivery = "imbibe" },
    bolster = _shape{ name = "Bolster", syntax = { "BOLSTER" }, delivery = "enhanced_state_ability" },
  }
  return defs
end

local function _parse_chart(text)
  local defs = {}
  local in_formulation = false
  local current

  for raw in text:gmatch("[^\r\n]+") do
    local line = _trim(raw)
    if line == "## Formulation" then
      in_formulation = true
      current = nil
    elseif in_formulation and line:match("^## ") then
      break
    elseif in_formulation then
      local heading = line:match("^###%s+(.+)$")
      if heading then
        current = {
          name = _trim(heading),
          key = _key(heading),
          syntax = {},
        }
        defs[current.key] = current
      elseif current then
        local syntax = raw:match("^  %- `%s*(.-)%s*`$")
        if syntax then
          current.syntax[#current.syntax + 1] = syntax
        end

        local delivery = line:match("^%- %*%*Delivery type:%*%* `%s*([^`]+)%s*`$")
        if delivery then
          current.delivery = _trim(delivery)
        end
      end
    end
  end

  for key, meta in pairs(defs) do
    defs[key] = _shape(meta)
  end

  return defs
end

local function _alias_map()
  return {
    endo = "endorphin",
    endorphin = "endorphin",
    nutri = "nutritional",
    nutritional = "nutritional",
    cor = "corrosive",
    corrosive = "corrosive",
    petri = "petrifying",
    petrifying = "petrifying",
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
    dest = "mayology",
    destructive = "mayology",
    mayology = "mayology",
    enh = "enhancement",
    enhancement = "enhancement",
    bol = "bolster",
    bolster = "bolster",
    halophilic = "halophilic",
    alteration = "alteration",
  }
end

function F.resolve(name, opts)
  local key = _key(name)
  if key == "" then
    return nil
  end

  if not F.state.form_defs then
    local defs
    local text, path = _read_chart()
    if text then
      defs = _parse_chart(text)
      F.state.chart_path = path
    end
    if not defs or next(defs) == nil then
      defs = _default_defs()
      F.state.chart_path = "embedded_defaults"
    end
    F.state.form_defs = defs
  end

  local aliases = _alias_map()
  local canonical_key = aliases[key] or key
  local meta = F.state.form_defs[canonical_key]
  if not meta then
    if not (opts and opts.silent) and type(F.warn) == "function" then
      F.warn("No formulation reference entry found for " .. tostring(name) .. ".")
    end
    return nil
  end

  return {
    name = meta.name,
    key = meta.key,
    use_name = meta.use_name,
    use_key = meta.use_key,
    syntax = meta.syntax,
    delivery = meta.delivery,
    needs_wield = meta.needs_wield,
    target_mode = meta.target_mode,
  }
end
