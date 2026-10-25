-- Embedded in AK.xml. Independent of Yso package load order.
ak=ak or {};ak.apostate=ak.apostate or {}
local A=ak.apostate
A.evileye_map={deaf='deaf',impatience='impatience',clumsy='clumsiness',vertigo='vertigo',
  amnesia='amnesia',agoraphobia='agoraphobia',dizzy='dizziness',paralysis='paralysis',
  claustrophobia='claustrophobia',paranoia='paranoia',blind='blind',masochism='masochism',
  asthma='asthma',reckless='recklessness',epilepsy='epilepsy',confusion='confusion',
  peace='pacifism',dementia='dementia',plague='voyria',addiction='addiction',stupid='stupidity',
  manaleech='manaleech',sensitivity='sensitivity',vomiting='nausea',anorexia='anorexia',weariness='weariness'}
A.shrivel_unresolved=A.shrivel_unresolved or {}
A.evileye_active=A.evileye_active or {}
local function route()
  return Yso and Yso.off and Yso.off.apostate and Yso.off.apostate.truelock
end
local function current(name)
  return type(name)=='string' and type(target)=='string' and name:lower()==target:lower()
end
local function present(aff)
  return ((affstrack and affstrack.score and tonumber(affstrack.score[aff])) or 0)>=100
end
function A.clear_pending()
  A.cursePull={};A.eye_target=nil;A.eye_pending={};A.eye_scores=nil
  if type(disableTrigger)=='function' then disableTrigger('Curse Pull Dump') end
end
A.clear_pending()
function A.reset_tracking()
  A.clear_pending();A.shrivel_unresolved={};A.evileye_active={};A.pending_daegger_wipe=nil
  local M=route();if M and M.is_enabled() then M.stop('tracking_reset') end
end
function A.capture_eye(name,curse)
  if (ak.ai and ak.ai()) or not current(name) then return false end
  if A.eye_target and A.eye_target:lower()~=name:lower() then A.clear_pending() end
  A.eye_target=name
  A.eye_scores=affstrack.score
  local aff=A.evileye_map[curse]
  if curse=='sicken' then
    local function has(k)
      if present(k) then return true end
      for _,row in ipairs(A.eye_pending) do if row.aff==k then return true end end
      return false
    end
    aff=not has('manaleech') and 'manaleech' or (not has('slickness') and 'slickness' or nil)
  end
  -- One row per announced eye, including non-affliction effects, so a clumsy failure
  -- always removes the correct slot rather than a preceding successful affliction.
  A.eye_pending[#A.eye_pending+1]={curse=curse,aff=aff}
  A.cursePull={}
  for _,row in ipairs(A.eye_pending) do if row.aff then A.cursePull[#A.cursePull+1]=row.aff end end
  if type(enableTrigger)=='function' then enableTrigger('Curse Pull Dump') end
  return true
end
function A.fail_eye()
  if not A.eye_target or not current(A.eye_target) then A.clear_pending();return end
  table.remove(A.eye_pending)
  A.cursePull={}
  for _,row in ipairs(A.eye_pending) do if row.aff then A.cursePull[#A.cursePull+1]=row.aff end end
end
function A.commit_eyes()
  local name=A.eye_target
  local affs=A.cursePull
  local scores=A.eye_scores
  A.clear_pending()
  if (ak.ai and ak.ai()) or not current(name) or scores~=affstrack.score then return false end
  if #affs>0 then
    -- Resolve provenance in batch order too: the first Sensitivity while deaf
    -- removes a defence, so Corrupt must not consume it as an evileye affliction.
    local hearing=affstrack.score.deaf~=0
    local applied={}
    for _,aff in ipairs(affs) do
      if aff=='sensitivity' and not hearing then
        hearing=true
      else
        applied[#applied+1]=aff
        if aff=='deaf' then hearing=true end
      end
    end
    OppGainedAff(table.concat(affs,' '),'evileye')
    for _,aff in ipairs(applied) do A.evileye_active[aff]=name:lower() end
  end
  local M=route();if M then M.note_pressure('eyes',name) end
  return true
end
-- Called by the real AK gain/loss writers, including cures and other delivery sources.
function A.note_gain(aff,source)
  if source=='evileye' then return end
  for word in tostring(aff):gmatch('%a+') do
    A.evileye_active[(affstrack.venoms or {})[word] or word]=nil
  end
end
function A.note_loss(aff)
  for word in tostring(aff):gmatch('%a+') do A.evileye_active[word]=nil end
end
function A.consume_corrupt(name,retained)
  if not current(name) then return false end
  A.clear_pending()
  local lost={}
  for aff,owner in pairs(A.evileye_active) do
    if owner==name:lower() and aff~=retained then lost[#lost+1]=aff end
  end
  for _,aff in ipairs(lost) do OppLostAff(aff);A.evileye_active[aff]=nil end
  if retained=='paralysis' then OppGainedAff('paralysis','evileye') end
  return true
end
function A.wipe(weapon)
  currentvenoms=currentvenoms or {}
  if weapon then currentvenoms[weapon]={}
  elseif A.pending_daegger_wipe then
    for key in pairs(currentvenoms) do
      if key:lower():find('daegger',1,true) then currentvenoms[key]={} end
    end
  end
  A.pending_daegger_wipe=nil
end
function A.puncture(name)
  if ak.ai and ak.ai() then return false end
  local weapon,delivered
  for key,coating in pairs(currentvenoms or {}) do
    if key:lower():find('daegger',1,true) and #coating>0 then
      if weapon then return false end -- ambiguous inventory: never choose another weapon's venom
      weapon=key
    end
  end
  if weapon then
    local venom=table.remove(currentvenoms[weapon],1)
    local aff=(affstrack.venoms or {})[venom]
    if aff and current(name) then OppGainedAff(aff);A.note_gain(aff);delivered=true end
  end
  local M=route();if M then M.note_pressure('puncture',name,delivered==true) end
  return true
end
function A.shrivel_exhausted(name,limb)
  if (ak.ai and ak.ai()) or not current(name) then return false end
  if limb~='arm' and limb~='leg' then return false end
  for _,side in ipairs({'left','right'}) do
    local key=side..limb
    if not present(key) then OppGainedAff(key) end
  end
  return true
end
function A.shrivel(name,side,limb)
  if (ak.ai and ak.ai()) or not current(name) then return false end
  if limb then
    if (side~='left' and side~='right') or (limb~='arm' and limb~='leg') then return false end
    local key=side..limb
    if not present(key) then OppGainedAff(key) end
    return true
  end
  if side~='arm' and side~='leg' then return false end
  local key=name:lower()
  local observation=A.shrivel_unresolved[key] or {arms=0,legs=0}
  A.shrivel_unresolved[key]=observation
  observation[side..'s']=observation[side..'s']+1
  observation.last_kind=side
  observation.at=type(getEpoch)=='function' and getEpoch() or os.time()
  return true
end
if type(registerAnonymousEventHandler)=='function' then
  A.tracking_handlers=A.tracking_handlers or {}
  for _,event in ipairs({'yso.target.changed','yso.target.cleared','sysDisconnectionEvent','gmcp.Char.Status'}) do
    if A.tracking_handlers[event] and type(killAnonymousEventHandler)=='function' then
      killAnonymousEventHandler(A.tracking_handlers[event])
    end
    A.tracking_handlers[event]=registerAnonymousEventHandler(event,A.reset_tracking)
  end
end
return A
