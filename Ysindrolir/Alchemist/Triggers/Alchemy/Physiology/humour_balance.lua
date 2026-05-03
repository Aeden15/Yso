Yso = Yso or {}
Yso.alc = Yso.alc or {}
Yso.alc.phys = Yso.alc.phys or {}

local P = Yso.alc.phys

P.humour_types = P.humour_types or { "choleric", "melancholic", "phlegmatic", "sanguine" }
P.possessive_pronouns = P.possessive_pronouns or { "his", "her", "their", "its", "faes", "faen", "faer" }

P.humour_ready_line = P.humour_ready_line or "You may manipulate another's humours once more."
P.humour_fail_line = P.humour_fail_line or "You are unable to manipulate another's humours at this time."
P.evaluate_ready_line = P.evaluate_ready_line or "You may study the physiological composition of your subjects once again."
P.homunculus_ready_line = P.homunculus_ready_line or "You may order your homunculus once more."
P.evaluate_ready_line_alt = P.evaluate_ready_line_alt or "You may evaluate another's humours once more."

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

local function _is_evaluate_ready_line(line)
  line = _trim(line)
  if line == "" then
    return false
  end
  if line == P.evaluate_ready_line or line == P.evaluate_ready_line_alt then
    return true
  end
  return line:match("^You may evaluate .- humours once more%.$") ~= nil
end

local function _parse_evaluate_count(line)
  local prefixes = { "His", "Her", "Their", "Its", "Faes", "Faen" }
  for i = 1, #prefixes do
    local humour, count = line:match("^" .. prefixes[i] .. " ([a-z]+) humour has been tempered a total of (%d+) times?%.$")
    if humour and count then
      return humour, tonumber(count) or 0
    end
  end
  return nil, nil
end

local function _parse_insufficient_temper(line)
  local target, pronoun, humour = line:match("^You send ripples throughout ([%w'%-]+)'s body, but (%a+) ([a-z]+) humour is insufficiently tempered%.$")
  if not target or not pronoun or not humour then
    return nil, nil
  end
  if not _looks_like_pronoun(pronoun) then
    return nil, nil
  end
  return _trim(target), _lc(humour)
end

local function _parse_inundate_success(line)
  local target, humour, pronoun = line:match("^You inundate ([%w'%-]+)'s ([a-z]+) humour, and a look of pain crosses (%a+) face%.$")
  if not target or not humour or not pronoun then
    return nil, nil
  end
  humour = _lc(humour)
  if humour ~= "choleric" and humour ~= "melancholic" and humour ~= "phlegmatic" and humour ~= "sanguine" then
    return nil, nil
  end
  if not _looks_like_pronoun(pronoun) then
    return nil, nil
  end
  return _trim(target), humour
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
    if type(P.clear_pending_class) == "function" then
      P.clear_pending_class("humour_balance_ready", { clear_any = true })
    end
    if type(P.wake_alchemist_routes) == "function" then
      P.wake_alchemist_routes("humour_balance_ready")
    end
    return true
  end

  if _is_evaluate_ready_line(line) then
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
    if type(P.wake_alchemist_routes) == "function" then
      P.wake_alchemist_routes("homunculus_ready")
    end
    return true
  end

  if line == P.humour_fail_line then
    if Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
      Yso.alc.set_humour_ready(false, "humour_fail")
    end
    if type(P.clear_pending_class) == "function" then
      P.clear_pending_class("humour_fail", { clear_any = true, clear_staged = true })
    end
    if type(send) == "function" then
      pcall(send, "CLEARQUEUE c!p!w!t", false)
    end
    P.state = P.state or {}
    P.state.last_humour_fail = {
      at = _now and _now() or os.time(),
      line = line,
    }
    return "humour_fail"
  end

  do
    local target = line:match("^A diminutive homunculus resembling Ysindrolir stares menacingly at ([%w'%-]+), its eyes flashing brightly%.$")
    if target then
      if type(Yso.set_homunculus_attack) == "function" then
        Yso.set_homunculus_attack(true, target)
      end
      return "homunculus_attack"
    end
  end

  if line:match("^A diminutive homunculus resembling Ysindrolir eases itself into a passive stance%.$") then
    if type(Yso.set_homunculus_attack) == "function" then
      Yso.set_homunculus_attack(false)
    end
    return "homunculus_passive"
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
      if type(P.set_humour_level) == "function" then
        P.set_humour_level(target, humour, count, "evaluate_count")
      end
      if type(P.maybe_finish_evaluate) == "function" then
        P.maybe_finish_evaluate(target)
      end
      return "evaluate_count"
    end
  end

  do
    if line:match("^.+ humours are all at normal levels%.$") then
      local target = type(P.resolve_evaluate_target) == "function" and P.resolve_evaluate_target() or _current_target_fallback()
      if type(P.note_evaluate_normal) == "function" then
        P.note_evaluate_normal(target)
      else
        if type(P.set_humour_level) == "function" then
          P.set_humour_level(target, "choleric", 0, "evaluate_normal")
          P.set_humour_level(target, "melancholic", 0, "evaluate_normal")
          P.set_humour_level(target, "phlegmatic", 0, "evaluate_normal")
          P.set_humour_level(target, "sanguine", 0, "evaluate_normal")
        end
        if type(P.finish_evaluate) == "function" then
          P.finish_evaluate(target)
        end
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
      local target = type(P.current_target) == "function" and P.current_target() or _current_target_fallback()
      if type(P.note_temper_success) == "function" then
        P.note_temper_success(target, humour, "temper_success")
      else
        if type(P.get_humour_level) == "function" and type(P.set_humour_level) == "function" then
          local prior = tonumber(P.get_humour_level(target, humour))
          local next_level = (prior ~= nil) and (prior + 1) or 1
          P.set_humour_level(target, humour, next_level, "temper_success")
        end
        if Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
          Yso.alc.set_humour_ready(false, "temper_success")
        end
      end
      return "temper_success"
    end
  end

  do
    local target, humour = _parse_inundate_success(line)
    if target and humour then
      if Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
        Yso.alc.set_humour_ready(false, "inundate_success")
      end
      if type(P.clear_pending_class) == "function" then
        P.clear_pending_class("inundate_success", { clear_any = true, clear_staged = true })
      end
      if Yso.alc and Yso.alc.phys and type(Yso.alc.phys.clear_all_humours) == "function" then
        Yso.alc.phys.clear_all_humours(target, "inundate_success:" .. tostring(humour))
      end
      if type(P.wake_alchemist_routes) == "function" then
        P.wake_alchemist_routes("inundate_success")
      end
      return "inundate_success"
    end
  end

  do
    local target, humour = _parse_insufficient_temper(line)
    if target and humour then
      if type(P.on_insufficient_temper) == "function" then
        P.on_insufficient_temper(target, humour)
      end
      return "wrack_insufficient_temper"
    end
  end

  do
    local humour_one, humour_two = line:match("^You send ripples throughout .-, wracking [%a]+ ([a-z]+) humour and [%a]+ ([a-z]+) humours?%.$")
    if not humour_one then
      humour_one, humour_two = line:match("^You send ripples throughout .-, wracking [%a]+ ([a-z]+) humour and [%a]+ ([a-z]+) humour%.$")
    end
    if humour_one then
      local Q = Yso and Yso.queue or nil
      if Q and type(Q.clear_lane_dispatched) == "function" then
        pcall(Q.clear_lane_dispatched, "bal", "truewrack_success")
      end
      if type(P.wake_alchemist_routes) == "function" then
        P.wake_alchemist_routes("truewrack_success")
      end
      return "truewrack_success"
    end

    local single = line:match("^You send ripples throughout .-, wracking [%a]+ ([a-z]+) humour%.$")
    if single then
      local Q = Yso and Yso.queue or nil
      if Q and type(Q.clear_lane_dispatched) == "function" then
        pcall(Q.clear_lane_dispatched, "bal", "wrack_success")
      end
      if type(P.wake_alchemist_routes) == "function" then
        P.wake_alchemist_routes("wrack_success")
      end
      return "wrack_success"
    end
  end

  do
    if line:match("^You do not see that person here%.$")
      or line:match("^There is no one here by that name%.$")
      or line:match("^You cannot find your target%.$")
    then
      if type(P.clear_pending_class) == "function" then
        P.clear_pending_class("class_target_invalid", { clear_any = true, clear_staged = true, wake = true })
      end
      if type(P.wake_alchemist_routes) == "function" then
        P.wake_alchemist_routes("class_target_invalid")
      end
      return "class_target_invalid"
    end
  end

  do
    local target, pronoun = line:match("^Channeling your focus through your link to your homunculus, you reach out to find the ethereal hook for ([%w'%-]+)'s humours%. Finding it, you use the alien connection with a diminutive homunculus resembling Ysindrolir to corrupt ([%a]+) humours%.$")
    if target and _looks_like_pronoun(pronoun) then
      if Yso.alc and type(Yso.alc.set_homunculus_ready) == "function" then
        Yso.alc.set_homunculus_ready(false, "homunculus_corrupt")
      end
      if type(P.note_corrupt_success) == "function" then
        P.note_corrupt_success(target, 45)
      end
      if type(P.wake_alchemist_routes) == "function" then
        P.wake_alchemist_routes("homunculus_corrupt")
      end
      return "homunculus_corrupt"
    end
  end

  do
    local target = line:match("^([%w'%-]+) looks far healthier all of a sudden%.$")
    if target then
      if type(P.clear_corruption) == "function" then
        P.clear_corruption(target, "corruption_lost")
      end
      if type(P.wake_alchemist_routes) == "function" then
        P.wake_alchemist_routes("corruption_lost")
      end
      return "corruption_lost"
    end
  end

  do
    local who = line:match("^([%w'%-]+) eats a ginger root%.$")
      or line:match("^([%w'%-]+) eats an antimony flake%.$")
    if who then
      if type(P.mark_all_eval_dirty) == "function" then
        P.mark_all_eval_dirty(who, "humour_eat")
      end
      if type(P.wake_alchemist_routes) == "function" then
        P.wake_alchemist_routes("humour_eat_dirty")
      end
      return "humour_eat_dirty"
    end
  end

  return nil
end
