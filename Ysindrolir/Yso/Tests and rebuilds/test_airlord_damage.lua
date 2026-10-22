local prefix = assert(arg[1], 'pass extracted package script prefix')
local checks = 0
local function world(slot)
  local clock, sent = 0, {}
  Yso = {util = {now = function() return clock end}, get_target = function() return 'Enemy' end}
  gmcp = {Char = {Status = {class = 'air elemental lord'}, Vitals = {bal = '1'}}}
  affstrack = {score = {tension = 100, deadening = 100, manaleech = 100}}
  ak = {duress = {asphyxiate = true}, defs = {}}
  Yso.emit = function(payload)
    if payload.bal then sent[#sent + 1] = payload.bal end
    return true
  end
  assert(loadfile(prefix .. '.compression.lua'))()
  assert(loadfile(prefix .. '.attack.lua'))()
  local route = Yso.off.airlord[slot or 'damage']
  route.state.enabled, route.state.loop_enabled = true, true
  local function gauge(level) Yso.off.airlord.compression.observe('Enemy', level) end
  gauge(3)
  local function attack(want)
    local ok, why = route.attack_function()
    assert(ok, tostring(why))
    assert(sent[#sent] == want, 'expected ' .. want .. ', got ' .. tostring(sent[#sent]))
    checks = checks + 1
    gmcp.Char.Vitals.bal = '0'
    route.attack_function()
    clock = clock + 0.2
    gmcp.Char.Vitals.bal = '1'
  end
  return route, attack, gauge, function(value) clock = value end
end

-- Repeated recovery must alternate damage with building, even as pressure grows.
local r, attack, gauge = world()
attack('manifest buffet Enemy')
attack('aero pressure Enemy')
gauge(4)
attack('manifest buffet Enemy')
attack('aero pressure Enemy')

-- Cured Tension must be restored without monopolizing every building turn.
r, attack, gauge = world()
affstrack.score.tension = 0
attack('manifest buffet Enemy')
attack('aero tension Enemy')
attack('manifest buffet Enemy')
attack('aero pressure Enemy')

-- Lost eligibility restores setup rather than blindly following alternation.
r, attack, gauge = world()
attack('manifest buffet Enemy')
affstrack.score.deadening, affstrack.score.manaleech = 0, 0
attack('aero strangle Enemy')
affstrack.score.deadening = 100
attack('manifest buffet Enemy')
gauge(2)
attack('aero pressure Enemy')

-- Shield and terminal pressure override both weaving turns.
r, attack, gauge = world()
attack('manifest buffet Enemy')
ak.defs.shield = true
attack('manifest gale Enemy')
ak.defs.shield = false
gauge(6)
attack('aero compression Enemy')

-- Stale Gauge cannot authorize Buffet; reset restarts the weave cleanly.
local set_time
r, attack, gauge, set_time = world()
set_time(4)
attack('aero pressure Enemy')
gauge(3)
attack('manifest buffet Enemy')
r.reset()
gauge(3)
attack('manifest buffet Enemy')

-- Lock continues building pressure without adopting the damage weave.
r, attack = world('lock')
attack('aero pressure Enemy')
attack('aero pressure Enemy')
-- Real packaged emitter sends Gauge + balanceless Assess together, even off BAL/EQ.
r, attack, gauge, set_time = world()
local now = Yso.util.now
tempRegexTrigger = function() return 1 end
assert(loadfile(prefix .. '.api.lua'))()
Yso.util.now = now
local lines = {}
send = function(line) lines[#lines + 1] = line end
gmcp.Char.Vitals.bal, gmcp.Char.Vitals.eq = '0', '0'
r.attack_function()
assert(#lines == 1 and lines[1] == 'gauge Enemy&&assess Enemy', 'damage observations must share one free send')
set_time(0.5)
r.attack_function()
assert(#lines == 1, 'Assess must share Gauge throttling')
set_time(1.1)
r.attack_function()
assert(#lines == 2 and lines[2] == 'gauge Enemy&&assess Enemy', 'both observations must recur together')
Yso.get_target = function() return 'Other' end
r.attack_function()
assert(#lines == 3 and lines[3] == 'gauge Other&&assess Other', 'both observations must follow target swaps')
checks = checks + 4

r = world('lock')
now = Yso.util.now
assert(loadfile(prefix .. '.api.lua'))()
Yso.util.now = now
lines = {}
gmcp.Char.Vitals.bal = '0'
r.attack_function()
assert(#lines == 1 and lines[1] == 'gauge Enemy', 'lock must retain Gauge-only observations')
checks = checks + 1
print('Airlord damage package: ' .. checks .. ' checks passed')
