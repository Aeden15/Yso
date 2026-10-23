-- AK owns elemental resonance. These triggers diagnose tracking/failures only.
Yso = Yso or {}
Yso.magi = Yso.magi or {}
local F = Yso.magi.resonance_feedback or {}
Yso.magi.resonance_feedback = F
local levels = { minor = 1, moderate = 2, major = 3 }
local function report(message)
  if type(cecho) == 'function' then cecho('\n<orange>[Yso:resonance]<reset> ' .. message .. '\n')
  elseif type(echo) == 'function' then echo('[Yso:resonance] ' .. message .. '\n') end
end
function F.notice()
  local tracker = rawget(_G, 'ak')
  local guarded = false
  if tracker and type(tracker.ai) == 'function' then
    local ok, value = pcall(tracker.ai)
    guarded = ok and not not value
  end
  if guarded and not F.guard_warned then
    report('AK tracking is skipping this resonance notice (ak.ai() is active); resonance may be stale.')
  end
  F.guard_warned = guarded
  return not guarded
end
function F.failure(word, element)
  local required = levels[tostring(word or ''):lower()]
  element = tostring(element or ''):lower()
  if not required or (element ~= 'air' and element ~= 'earth' and element ~= 'fire' and element ~= 'water') then
    return false
  end
  F.last_failure = { element = element, required = required,
    at = type(getEpoch) == 'function' and getEpoch() or os.time() }
  report('Spell rejected: ' .. tostring(word) .. ' ' .. element
    .. ' resonance required. Actual level remains supplied by AK.')
  F.notice()
  return true
end
return F
