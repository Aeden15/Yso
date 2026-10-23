local here = debug.getinfo(1, 'S').source:sub(2):match('^(.*[/\\])')
local root = arg[1] or here .. '../../'
local failures, emitted, wields = {}, {}, 0
local function check(value, message)
  if not value then failures[#failures + 1] = message end
end
function getEpoch() return 10000 end
function cecho() end
Yso = {
  class = 'magi', off = { magi = {} },
  get_target = function() return 'Foe' end,
  is_magi = function() return true end,
  state = { eq_ready = function() return true end },
  mode = { is_combat = function() return true end, route_loop_active = function() return true end },
  emit = function(payload, opts)
    emitted[#emitted + 1] = { payload = payload, opts = opts }
    return true
  end,
  magi = { weapons = { send_wields = function() wields = wields + 1 end } },
}
-- These previously qualified for automatic self-purge: two Legacy self afflictions,
-- enough mana, both channels, no haemophilia, combat, and equilibrium available.
Legacy = { Curing = { Affs = { stupidity = true, dizziness = true } } }
gmcp = { Char = { Status = { class = 'Magi' }, Vitals = {
  eq = '1', mp = '100', charstats = { 'Channels: Fire Water' },
} } }
affstrack = { score = {} }
ak = { healthpercent = 100, magi = { resonance = {} }, defs = {} }
local RC = dofile(root .. 'Magi/magi_route_core.lua')
local W = dofile(root .. 'Magi/Magi_water_group.lua')
local F = dofile(root .. 'Magi/Magi_firestorm.lua')
for _, M in ipairs({ W, F }) do
  M.state = { enabled = true, loop_enabled = true }
  local plan = M.attack_function({ preview = true })
  check(type(plan) == 'table' and plan.lanes.eq == 'cast pebble at Foe',
    M.key .. ': qualifying self afflictions replaced normal Pebble decision')
  local ok, cmd = M.attack_function()
  check(ok and cmd == 'cast pebble at Foe', M.key .. ': normal route command was not emitted')
  local row = emitted[#emitted]
  check(row and row.opts.commit == true and row.opts.require_commit == nil and row.opts.repeat_command == nil,
    M.key .. ': obsolete purge commit options remain')
  -- Keep route cases independent even before the obsolete shared purge gate is removed.
  if RC.bloodboil then RC.bloodboil.pending_until = 0 end
end
check(wields == 1, 'water route skipped ordinary wield preparation')

-- Reload retains the shared table so existing route closures keep the same core.
-- Old runtime state and callable automation must be removed from that reused table.
RC.bloodboil = { cooling = true, pending_until = 10004 }
check(RC.eq_ready(), 'obsolete Bloodboil state still influences ordinary EQ readiness')
local removed = { 'bloodboil_note_cast', 'bloodboil_note_ready', 'bloodboil_note_eq_recovered',
  'bloodboil_command', 'with_bloodboil' }
for _, name in ipairs(removed) do RC[name] = function() error('stale automation called') end end
local reloaded = dofile(root .. 'Magi/magi_route_core.lua')
check(reloaded == RC, 'reload replaced the shared route-core table')
check(RC.bloodboil == nil, 'obsolete Bloodboil state survived reload')
for _, name in ipairs(removed) do check(RC[name] == nil, name .. ' survived reload') end
check(RC.eq_ready(), 'stale Bloodboil pending state blocked ordinary EQ readiness')
Yso.state.eq_ready = function() return false end
check(not RC.eq_ready(), 'ordinary EQ-down gate was removed')
Yso.state.eq_ready = function() return true end
local noted
Yso.magi.convergence = { note_queued = function(cmd, tgt) noted = { cmd, tgt } end }
RC.note_special_queued('cast convergence at Foe', 'Foe')
check(noted and noted[1] == 'cast convergence at Foe' and noted[2] == 'Foe',
  'convergence queue notification was lost')
for _, message in ipairs(failures) do io.stderr:write('FAIL: ' .. message .. '\n') end
assert(#failures == 0, tostring(#failures) .. ' manual Bloodboil regressions')
print('PASS: Bloodboil stays manual; group decisions, ordinary EQ, and convergence survive hot reload')
