-- Basic AK decisions. Yso's Airlord runtime owns scheduling, sends and cleanup.
local M=Yso.off.airlord.make_route('lock','airlord_lock','Airlord lock')

function M.select_command(target)
  local affs=affstrack and affstrack.score or {}
  local duress=ak and ak.duress or {}
  local function has(aff)
    return (tonumber(affs[aff]) or 0)>=100
  end
  local pressure=M.compression.level()

  if ak and ak.defs and ak.defs.shield then
    return 'manifest gale '..target,'defense_break'
  end
  if pressure and pressure>=6 then
    return 'aero compression '..target,'execute'
  end

  -- Tension first, with another attack between immediate reapplications.
  if not has('tension') and M.state.last_cmd~='aero tension '..target then
    if duress.asphyxiate~=true then
      return 'aero asphyxiate '..target,'smoke_tracking'
    end
    return 'aero tension '..target,'tension'
  end

  local boosters=0
  for _,aff in ipairs({'deadening','manaleech','disloyalty'}) do
    if has(aff) then boosters=boosters+1 end
  end
  if boosters>=2 or (boosters>=1 and pressure and pressure>0) then
    return 'aero pressure '..target,'pressure'
  end

  if duress.asphyxiate~=true then
    return 'aero asphyxiate '..target,'smoke_tracking'
  end
  if not has('deadening') and duress.stranglerelapse~=true then
    return 'aero strangle '..target,'affliction'
  elseif not has('manaleech') and duress.zephyrrelapse~=true then
    return 'manifest zephyr '..target,'affliction'
  elseif not has('disloyalty') and duress.scourrelapse~=true then
    return 'aero scour '..target,'affliction'
  end
  return 'aero pressure '..target,'pressure'
end

return M
