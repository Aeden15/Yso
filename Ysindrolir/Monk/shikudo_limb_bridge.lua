-- Read-only adapter. Injury afflictions and limb percentages stay separate.
Yso=Yso or {};Yso.monk=Yso.monk or {}
local B=Yso.monk.limbs or {observations={}}
Yso.monk.limbs=B
local mapping={head='head',torso='torso',leftarm='left arm',rightarm='right arm',leftleg='left leg',rightleg='right leg'}
function B.snapshot(target)
  local out={ready=false,source='unavailable',hits={},confidence={}}
  for key in pairs(mapping) do out.confidence[key]='unknown' end
  if type(lb)~='table' or type(lb.normalizeName)~='function' then return out end
  local name=lb.normalizeName(target);local row=name and lb[name]
  if not row or type(row.hits)~='table' then return out end
  local meta=row.meta or {};out.source=meta.source or 'unverified'
  if meta.calibrated~=true and B.observations[name:lower()] then out.source='success_seen:no_numeric_damage' end
  local complete=true
  for key,label in pairs(mapping) do
    local n=tonumber(row.hits[label])
    local valid=n and n==n and n>=0 and n<math.huge
    if valid then out.hits[key]=n end
    if (meta.uncertain or {})[label] then out.confidence[key]='uncertain'
    elseif valid and (meta.known or {})[label]==true then out.confidence[key]='known' end
    if out.confidence[key]~='known' then complete=false end
  end
  out.ready=complete
  if next(meta.uncertain or {}) then out.source='uncertain:'..out.source end
  return out
end
function B.note_success(target,strike)
  target=tostring(target or ''):lower()
  B.observations[target]=B.observations[target] or {}
  local data=B.observations[target]
  data[strike]=(data[strike] or 0)+1
  -- Success output proves an effect, not a numerical total or LIGHT modifier.
  -- Retain it for diagnostics; lb.addHit alone owns measured accumulation.
end
return B
