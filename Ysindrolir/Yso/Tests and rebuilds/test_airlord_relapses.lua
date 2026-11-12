local prefix = assert(arg[1], 'pass extracted Airlord trigger prefix')

local function run(name)
  assert(loadfile(prefix .. '.' .. name .. '.lua'))()
end

local target = "O'Neil-Test"
local timers, stopped, scored, gained = {}, {}, {}, {}
ak = {duress = {}, scoreup = function(who) scored[#scored + 1] = who end}
Yso = {get_target = function() return target end}
function IsTargetted(who)
  return who:lower():sub(1, #target) == target:lower()
end
function tempTimer(delay, callback)
  local id = #timers + 1
  timers[id] = {delay = delay, callback = callback}
  return id
end
function killTimer(id)
  local timer = tonumber(id)
  if timer then stopped[timer] = true end
end
function OppGainedAff(aff) gained[#gained + 1] = aff end

local function trigger(name, who)
  matches = {[2] = who or target}
  run(name)
end

local helper = io.open(prefix .. '.tracker.lua')
if helper then
  helper:close()
  run('tracker')
end

for _, skill in ipairs({'strangle', 'scour', 'zephyr'}) do
  local flag = skill .. 'relapse'
  local timer = flag .. 'timer'
  trigger(skill)
  local first = ak.duress[timer]
  assert(ak.duress[flag] and timers[first].delay == 7, skill .. ' hit must arm a seven-second tracker')
  assert(type(timers[first].callback) == 'function', skill .. ' expiry must capture the target in a closure')
  assert(ak.duress.relapse_pending(skill, target:lower()), skill .. ' must track the current target case-insensitively')
  assert(not ak.duress.relapse_pending(skill, 'Other'), skill .. ' must not block recasts on other targets')
  trigger(skill .. '_continues', 'Other')
  assert(ak.duress[timer] == first, skill .. ' must ignore unrelated feedback')
  trigger(skill .. '_continues')
  local continued = ak.duress[timer]
  assert(continued ~= first and stopped[first], skill .. ' continuation must replace its old timer')
  if skill == 'zephyr' then
    trigger('zephyr_blackout')
    assert(stopped[continued], 'Zephyr blackout must renew the timer')
    continued = ak.duress[timer]
  end
  timers[first].callback()
  assert(ak.duress[timer] == continued, skill .. ' obsolete callback cleared a newer relapse')
  trigger(skill .. '_reapplies')
  assert(stopped[continued] and not ak.duress.relapse_pending(skill, target), skill .. ' reapplication must end tracking')

  trigger(skill)
  local expires = ak.duress[timer]
  timers[expires].callback()
  assert(not ak.duress[flag] and scored[#scored] == target, skill .. ' timeout must clear the flag and score the captured target')
end

trigger('strangle')
local old = ak.duress.stranglerelapsetimer
trigger('strangle')
local refreshed = ak.duress.stranglerelapsetimer
assert(stopped[old], 'a second initial Strangle must replace its old timer')
target = 'Other'
assert(not ak.duress.relapse_pending('strangle', target), 'target swap must hide the old relapse')
ak.duress.reset_relapses()
assert(stopped[refreshed] and not ak.duress.stranglerelapse, 'AK target reset must cancel tracked relapses')
trigger('strangle')
local replacement = ak.duress.stranglerelapsetimer
timers[refreshed].callback()
assert(ak.duress.stranglerelapsetimer == replacement, 'pre-reset callback must leave the new target alone')

Yso.get_target = function() return 'Unrelated' end
trigger('strangle')
local mismatch = ak.duress.stranglerelapsetimer
assert(not ak.duress.relapse_pending('strangle', 'Unrelated'), 'AK feedback must not borrow an unrelated Yso target')
local previous_scores = #scored
timers[mismatch].callback()
assert(#scored == previous_scores, 'expiry must not rescore an unrelated selected target')
Yso.get_target = function() return 'Other' end
trigger('strangle')
local changed_ak = ak.duress.stranglerelapsetimer
target = 'Swapped'
timers[changed_ak].callback()
assert(#scored == previous_scores, 'expiry must not rescore after AK retargets independently')
target = 'Other'

Yso.get_target = function() return 'Oth' end
trigger('strangle')
assert(ak.duress.relapse_pending('strangle', 'oth'), 'a matching abbreviated target must see the relapse')
Yso.get_target = function() return target end

Yso.util = {now = function() return 0 end}
run('compression')
local compression = Yso.off.airlord.compression
assert(compression.observe(target, 6) and compression.ready())
trigger('pressure_cure', 'OtherEnemy')
assert(compression.ready(), 'a different target must not invalidate terminal Gauge')
trigger('pressure_cure', target)
assert(not compression.ready(), 'current-target pear or calcite must invalidate terminal Gauge')
assert(compression.observe(target, 6) and compression.ready(), 'new Gauge must restore readiness')
print('PASS Airlord AK relapse trigger replay and pressure cure invalidation')
