Yso = Yso or {}
Yso.alc = Yso.alc or {}
Yso.alc.phys = Yso.alc.phys or {}

local P = Yso.alc.phys

P.humour_types = P.humour_types or { "choleric", "melancholic", "phlegmatic", "sanguine" }
P.possessive_pronouns = P.possessive_pronouns or { "his", "her", "their", "faer", "its", "faes", "faen" }

P.humour_ready_line = P.humour_ready_line or "You may manipulate another's humours once more."
P.humour_fail_line = P.humour_fail_line or "You are unable to manipulate another's humours at this time."
P.evaluate_ready_line = P.evaluate_ready_line or "You may study the physiological composition of your subjects once again."
P.homunculus_ready_line = P.homunculus_ready_line or "You may order your homunculus once more."

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _lc(s)
  return _trim(s):lower()
end

local function _current_target_fallback()
  if type(P.current_target) == "function" then
    local tgt = _trim(P.current_target())
    if tgt ~= "" then
      return tgt
    end
  end
  if type(Yso.get_target) == "function" then
    local ok, v = pcall(Yso.get_target)
    if ok and _trim(v) ~= "" then
      return _trim(v)
    end
  end
  local tgt = rawget(_G, "target")
  if type(tgt) == "string" and _trim(tgt) ~= "" then
    return _trim(tgt)
  end
  return ""
end

local function _looks_like_pronoun(word)
  local key = _lc(word)
  for i = 1, #P.possessive_pronouns do
    if key == P.possessive_pronouns[i] then
      return true
    end
  end
  return false
end

local function _extract_wrack_target(text)
  local who = text:match("^You send ripples throughout (.+?)(?:'s|') body, wracking ")
  if who then
    return _trim(who)
  end
  return _current_target_fallback()
end

local function _parse_evaluate_vitals(line)
  local lower = _lc(line)
  if not lower:find("health", 1, true) or not lower:find("mana", 1, true) then
    return nil
  end

  local hp, mp = lower:match("health[^%%]*(%d+)%%%s*[,;/|%- ]+%s*mana[^%%]*(%d+)%%")
  if hp and mp then
    return tonumber(hp), tonumber(mp)
  end

  mp, hp = lower:match("mana[^%%]*(%d+)%%%s*[,;/|%- ]+%s*health[^%%]*(%d+)%%")
  if hp and mp then
    return tonumber(hp), tonumber(mp)
  end

  hp, mp = lower:match("(%d+)%%%s+health.-(%d+)%%%s+mana")
  if hp and mp then
    return tonumber(hp), tonumber(mp)
  end

  mp, hp = lower:match("(%d+)%%%s+mana.-(%d+)%%%s+health")
  if hp and mp then
    return tonumber(hp), tonumber(mp)
  end

  return nil
end

local function _parse_evaluate_count(line)
  local prefixes = { "His", "Her", "Their", "Faer", "Its" }
  for i = 1, #prefixes do
    local humour, count = line:match("^" .. prefixes[i] .. " ([a-z]+) humour has been tempered a total of (%d+) times?%.$")
    if humour and count then
      return humour, tonumber(count) or 0
    end
  end
  return nil, nil
end

function P.handle_humour_balance_line(line)
  line = tostring(line or "")
  if line == "" then
    return nil
  end

  if line == P.humour_ready_line then
    if Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
      Yso.alc.set_humour_ready(true, "humour_ready")
    end
    return true
  end

  if line == P.evaluate_ready_line then
    if Yso.alc and type(Yso.alc.set_evaluate_ready) == "function" then
      Yso.alc.set_evaluate_ready(true, "evaluate_ready")
    end
    if type(P.finish_evaluate) == "function" then
      P.finish_evaluate()
    end
    return true
  end

  if line == P.homunculus_ready_line then
    if Yso.alc and type(Yso.alc.set_homunculus_ready) == "function" then
      Yso.alc.set_homunculus_ready(true, "homunculus_ready")
    end
    return true
  end

  if line == P.humour_fail_line then
    return nil
  end

  do
    local eval_target = line:match("^Looking over (.+), you see that:$")
    if eval_target then
      if Yso.alc and type(Yso.alc.set_evaluate_ready) == "function" then
        Yso.alc.set_evaluate_ready(false, "evaluate_header")
      end
      if type(P.begin_evaluate) == "function" then
        P.begin_evaluate(eval_target)
      end
      return "evaluate_header"
    end
  end

  do
    local humour, count = _parse_evaluate_count(line)
    if humour and count then
      local target = type(P.resolve_evaluate_target) == "function" and P.resolve_evaluate_target() or _current_target_fallback()
      if type(P.note_steady_count) == "function" then
        P.note_steady_count(target, humour, count)
      end
      return "evaluate_count"
    end
  end

  do
    if line:match("^.+ humours are all at normal levels%.$") then
      local target = type(P.resolve_evaluate_target) == "function" and P.resolve_evaluate_target() or _current_target_fallback()
      if type(P.note_all_normal) == "function" then
        P.note_all_normal(target)
      end
      return "evaluate_normal"
    end
  end

  do
    local hp, mp = _parse_evaluate_vitals(line)
    if hp and mp then
      local target = type(P.resolve_evaluate_target) == "function" and P.resolve_evaluate_target() or _current_target_fallback()
      if type(P.note_evaluate_vitals) == "function" then
        P.note_evaluate_vitals(target, hp, mp)
      end
      return "evaluate_vitals"
    end
  end

  do
    local pronoun, humour = line:match("^You redirect .-, tempering (%a+) ([a-z]+) humour%.$")
    if humour and pronoun and _looks_like_pronoun(pronoun) then
      if Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
        Yso.alc.set_humour_ready(false, "temper_success")
      end
      if type(P.note_temper_success) == "function" then
        P.note_temper_success(_current_target_fallback(), humour)
      end
      return "temper_success"
    end
  end

  do
    local target = _extract_wrack_target(line)
    local humour_one, humour_two = line:match("^You send ripples throughout .-, wracking [%a]+ ([a-z]+) humour and [%a]+ ([a-z]+) humours?%.$")
    if not humour_one then
      humour_one, humour_two = line:match("^You send ripples throughout .-, wracking [%a]+ ([a-z]+) humour and [%a]+ ([a-z]+) humour%.$")
    end
    if humour_one then
      if type(P.note_wrack_success) == "function" then
        P.note_wrack_success(target, humour_one, humour_two)
      end
      return "truewrack_success"
    end

    local single = line:match("^You send ripples throughout .-, wracking [%a]+ ([a-z]+) humour%.$")
    if single then
      if type(P.note_wrack_success) == "function" then
        P.note_wrack_success(target, single, nil)
      end
      return "wrack_success"
    end
  end

  do
    local target = line:match("^Your homunculus .- ([A-Z][%a'-]+), corrupting ")
      or line:match("^Your homunculus .- (.+?)(?:'s|') body, corrupting ")
      or _current_target_fallback()
    local found = line:lower():find("corrupt", 1, true)
    local mel = line:lower():find("melancholic", 1, true)
    local san = line:lower():find("sanguine", 1, true)
    if found and mel and san then
      if Yso.alc and type(Yso.alc.set_homunculus_ready) == "function" then
        Yso.alc.set_homunculus_ready(false, "homunculus_corrupt")
      end
      if type(P.note_corrupt_success) == "function" then
        P.note_corrupt_success(target, 45)
      end
      return "homunculus_corrupt"
    end
  end

  do
    local who = line:match("^(.+) eats an antimony mineral%.$")
      or line:match("^(.+) eats an antimony shard%.$")
      or line:match("^(.+) eats a ginger root%.$")
    if who and type(P.mark_all_eval_dirty) == "function" then
      P.mark_all_eval_dirty(who, "humour_reduction")
      return "humour_dirty"
    end
  end

  return nil
end
