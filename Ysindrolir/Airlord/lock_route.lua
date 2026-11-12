-- Shared Airlord runtime owns scheduling, sends and cleanup.
local A = Yso.off.airlord
local M = A.make_route('lock', 'airlord_lock', 'Airlord lock')

function M.select_command(target)
  local scores = affstrack and affstrack.score or {}
  local duress = ak and ak.duress or {}
  local function confirmed(affliction)
    return (tonumber(scores[affliction]) or 0) >= 100
  end

  if ak and ak.defs and ak.defs.shield then
    return 'manifest gale ' .. target, 'defense_break'
  end

  local pressure = M.compression.level()
  if pressure and pressure >= 6 then
    return 'aero compression ' .. target, 'execute'
  end

  local boosters = 0
  for _, attack in ipairs(A.relapse_attacks) do
    if confirmed(attack.affliction) then
      boosters = boosters + 1
    end
  end
  local pressure_command = 'aero pressure ' .. target
  if boosters >= 2 or (boosters == 1 and pressure and pressure > 0) or pressure == 5 then
    return pressure_command, 'pressure'
  end

  local setup_command, category
  for _, attack in ipairs(A.relapse_attacks) do
    if not confirmed(attack.affliction) and not A.relapse_pending(attack.skill, target) then
      setup_command, category = attack.command .. ' ' .. target, 'affliction'
      break
    end
  end

  local tension = 'aero tension ' .. target
  if not setup_command and not confirmed('tension') and M.state.last_cmd ~= tension then
    setup_command, category = tension, 'tension'
  end

  if setup_command then
    if duress.asphyxiate ~= true then
      return 'aero asphyxiate ' .. target, 'smoke_tracking'
    end
    return setup_command, category
  end

  return pressure_command, 'pressure'
end

return M
