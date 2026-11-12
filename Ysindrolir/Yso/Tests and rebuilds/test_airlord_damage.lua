local prefix = assert(arg[1], 'pass extracted package script prefix')
local checks = 0
local function world(slot,damage_only)
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
  assert(loadfile(prefix .. '.runtime.lua'))()
  if not damage_only then assert(loadfile(prefix .. '.lock.lua'))() end
  assert(loadfile(prefix .. '.damage.lua'))()
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

-- Consecutive Buffets require a real BAL cycle and live eligibility.
local r, attack, gauge = world()
assert(r.attack_function() == true, 'first Buffet should submit')
local _, why = r.attack_function()
assert(why == 'pending', 'Buffet must not submit twice before BAL recovery')
checks = checks + 2
gmcp.Char.Vitals.bal = '0'
r.attack_function()
gmcp.Char.Vitals.bal = '1'
attack('manifest buffet Enemy')
gauge(4)
attack('manifest buffet Enemy')

-- Pressure takes a two-booster window during setup, even when Tension is gone.
r, attack, gauge = world()
affstrack.score.tension = 0
gauge(2)
ak.duress.asphyxiate = false
attack('aero pressure Enemy')
affstrack.score.manaleech = 0
ak.duress.asphyxiate = true
attack('aero tension Enemy')
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

-- Stale Gauge cannot authorize Buffet; reset starts a fresh chain.
local set_time
r, attack, gauge, set_time = world()
set_time(4)
attack('aero pressure Enemy')
gauge(3)
attack('manifest buffet Enemy')
r.reset()
gauge(3)
attack('manifest buffet Enemy')

-- Eligibility loss clears only this route's queued Buffet.
r, attack, gauge = world()
local staged = 'manifest buffet Enemy'
local owner = {route = r.key, cmd = staged}
local cleared = 0
Yso.queue = {
  list = function() return staged end,
  get_staged_owner = function() return owner end,
  clear = function() staged = nil end,
  get_owned = function() return owner end,
  clear_lane = function() cleared = cleared + 1; owner = nil end,
}
assert(r.attack_function() == true and r.state.pending.category == 'buffet')
affstrack.score.tension, affstrack.score.deadening = 0, 0
r.sync_buffet()
assert(staged == nil and cleared == 1 and r.state.pending == nil,
  'lost damage bonuses must cancel the staged and installed Buffet')
checks = checks + 1

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
-- The real queue must send successive Buffets and submit observations while BAL is down.
r, attack, gauge, set_time = world()
now = Yso.util.now
assert(loadfile(prefix .. '.api.lua'))()
Yso.util.now = now
assert(loadfile(assert(arg[2], 'pass the native queue source path')))()
lines = {}
gmcp.Char.Vitals.eq = '1'
assert(r.attack_function() == true, 'the queue must install the first Buffet')
local duplicate_sent = r.attack_function()
assert(not duplicate_sent, 'the queue must not duplicate Buffet before BAL drops')
set_time(1.1)
gmcp.Char.Vitals.bal = '0'
r.attack_function()
set_time(2.2)
gmcp.Char.Vitals.bal = '1'
gauge(3)
assert(r.attack_function() == true, 'the real queue must reinstall Buffet on BAL recovery')
local buffet_count, observation_count = 0, 0
for _, line in ipairs(lines) do
  if line:find('manifest buffet Enemy', 1, true) then buffet_count = buffet_count + 1 end
  if line:find('gauge Enemy&&assess Enemy', 1, true) then observation_count = observation_count + 1 end
  assert(not line:find('CLEARQUEUE', 1, true), 'BAL recovery must not clear the server queue')
end
assert(buffet_count == 2, 'exactly two Buffets must reach the wire')
assert(observation_count == 3, 'identical observations must recur through the real queue')
checks = checks + 3

print('Airlord damage package: ' .. checks .. ' checks passed')
-- The separate damage module must also work when lock has never loaded.
r,attack,gauge=world('damage',true)
assert(Yso.off.airlord.lock==nil,'damage must not create lock')
attack('manifest buffet Enemy')
r.toggle_updraft()
assert(r.cfg.updraft_enabled==true,'damage Updraft must work independently')
print('PASS independent damage loading and Updraft toggle')
