-- Package script: Dispatch execute logic. Selection only; shdam owns emission.
Yso = Yso or {}
Yso.monk = Yso.monk or {}
Yso.monk.shikudo = Yso.monk.shikudo or {}
local E = Yso.monk.shikudo.execute or {}
Yso.monk.shikudo.execute = E

function E.can_dispatch(target)
  target = tostring(target or ''):gsub('^%s+',''):gsub('%s+$','')
  if not target:match('^[%a%d_\'-]+$') then return false,'invalid_target' end
  if type(IsTargetted)~='function' or not IsTargetted(target) then return false,'untracked_target' end
  if not (Yso.ak and type(Yso.ak.has)=='function') then return false,'no_aff_tracker' end
  -- Route policy requested by the user: prone + crushedthroat, no head gate.
  -- AK's adapter applies confirmation thresholds; numeric zero is truthy in Lua.
  if Yso.ak.has('prone')~=true then return false,'not_prone' end
  if Yso.ak.has('crushedthroat')~=true then return false,'no_crushedthroat' end
  return true,'dispatch_ready'
end
return E
