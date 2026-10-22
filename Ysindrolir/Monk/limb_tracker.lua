-- Maintained limb.1.2 core. Keep lb[name].hits/t and public methods compatible.
lb=lb or {}
local keys={'head','torso','left arm','right arm','left leg','right leg'}
local aliases={head='head',torso='torso',leftarm='left arm',rightarm='right arm',leftleg='left leg',rightleg='right leg'}
function lb.normalizeName(name)
  name=tostring(name or ''):gsub('^%s+',''):gsub('%s+$',''):lower()
  if not name:match("^[%a%d_'-]+$") then return nil end
  return name:sub(1,1):upper()..name:sub(2)
end
function lb.normalizeLimb(limb)
  return aliases[tostring(limb or ''):lower():gsub('[%s_]','')]
end
local function event(name,limb,amount,source)
  if type(raiseEvent)=='function' then
    raiseEvent('limb hits updated',name,limb,amount)
    raiseEvent('yso.limb.sample',name,limb,amount,source)
  end
end
function lb.echo(text) if type(cecho)=='function' then cecho('<turquoise>[Limb]: <white>'..text..'\n') end end
function lb.initTarget(name)
  name=lb.normalizeName(name);if not name then return false end
  lb[name]=lb[name] or {}
  local row=lb[name];row.hits=row.hits or {};row.t=row.t or {}
  for _,key in ipairs(keys) do if row.hits[key]==nil then row.hits[key]=0 end end
  row.meta=row.meta or {source='unverified',calibrated=false,uncertain={},samples=0}
  -- Historical calibrated=true does not prove that every limb started at zero.
  row.meta.known=row.meta.known or {};row.meta.uncertain=row.meta.uncertain or {}
  event(name,'all',nil,'init');return row
end
local function cancel(id) if id and type(killTimer)=='function' then killTimer(id) end end
function lb.addHit(name,limb,amount)
  name=lb.normalizeName(name);limb=lb.normalizeLimb(limb);amount=tonumber(amount)
  if not name or not limb or not amount or amount~=amount or amount<0 or amount==math.huge then return false end
  local row=lb.initTarget(name)
  row.hits[limb]=row.hits[limb]+amount
  row.meta.samples=row.meta.samples+1;row.meta.calibrated=true;row.meta.source='game_reported'
  cancel(row.t[limb])
  if type(tempTimer)=='function' then
    row.t[limb]=tempTimer(180,function() lb.resetLimb(name,limb,'expired') end)
  end
  if type(cecho)=='function' then cecho(' <yellow>('..row.hits[limb]..'%)') end
  event(name,limb,amount,'game_reported');return true
end
function lb.resetLimb(name,limb,source)
  name=lb.normalizeName(name);limb=lb.normalizeLimb(limb)
  local row=name and lb[name]
  if not row or not limb then return false end
  row.meta=row.meta or {source='unverified',uncertain={},samples=0}
  row.meta.known=row.meta.known or {};row.meta.uncertain=row.meta.uncertain or {}
  source=type(source)=='string' and source or 'manual_reset'
  row.hits[limb]=0;cancel(row.t[limb]);row.t[limb]=nil
  if source=='manual_reset' or source=='confirmed_recovery' then
    row.meta.uncertain[limb]=nil;row.meta.known[limb]=true;row.meta.calibrated=true
  else row.meta.uncertain[limb]=true end
  row.meta.source=source
  event(name,limb,0,source);return true
end
function lb.confirmRecovery(name,limb) return lb.resetLimb(name,limb,'confirmed_recovery') end
function lb.salve(name,area)
  name=lb.normalizeName(name);local row=name and lb[name]
  local groups={head={'head'},torso={'torso'},arms={'left arm','right arm'},legs={'left leg','right leg'}}
  local limbs=groups[tostring(area or ''):lower()]
  if not row or not limbs then return false end
  row.meta=row.meta or {source='unverified',uncertain={},samples=0}
  for _,limb in ipairs(limbs) do row.meta.uncertain[limb]=true end
  row.meta.source='salve_observed'
  event(name,tostring(area),nil,'salve_observed')
  cancel(row.t.cure)
  if type(tempTimer)=='function' then
    row.t.cure=tempTimer(3.7,function()
      row.t.cure=nil
      for _,limb in ipairs(limbs) do
        if row.hits[limb]>=100 then lb.resetLimb(name,limb,'salve_estimate');break end
      end
    end)
  end
  return true
end
function lb.resetAll(name)
  name=lb.normalizeName(name);if not name then return false end
  local row=lb.initTarget(name);cancel(row.t.cure);row.t.cure=nil
  for _,limb in ipairs(keys) do lb.resetLimb(name,limb,'manual_reset') end
  return true
end
function lb.resetCurrentTarget()
  local resolver=Yso and Yso.get_target
  local name
  if type(resolver)=='function' then name=resolver() else name=rawget(_G,'target') end
  name=lb.normalizeName(name)
  if not name then lb.echo('Reset failed: no valid current target.');return false end
  if not lb.resetAll(name) then lb.echo('Reset failed for '..name..'.');return false end
  lb.echo('Reset '..name..': all six limbs known at 0% (manual baseline).')
  return true
end
