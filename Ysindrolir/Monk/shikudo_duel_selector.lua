-- Pure duel selection. Percentages plan attacks; only AK confirmations open kills.
Yso = Yso or {}
Yso.monk = Yso.monk or {}
Yso.monk.shikudo = Yso.monk.shikudo or {}
local S = {}
Yso.monk.shikudo.duel_selector = S
local graph = {tykonos={'willow'},willow={'rain'},rain={'oak','tykonos'},
  oak={'willow','gaital'},gaital={'rain','maelstrom'},maelstrom={'oak'}}
local mental_pool = {'stupidity','impatience','dizziness','epilepsy','confusion'}
local function has(c, aff)
  local v = (c.affs or {})[aff]
  return v == true or (tonumber(v) or 0) >= 100
end
local function limb(c, name) return tonumber((c.limbs or {})[name]) end
local function limb_known(c,name)
  local n=limb(c,name)
  return n and n==n and n>=0 and n<math.huge
    and ((c.limb_confidence and c.limb_confidence[name]=='known')
      or (c.limb_confidence==nil and c.limb_ready==true))
end
local function prepped(c, name, hit)
  local value = limb(c,name)
  return value and value < 100 and value + hit >= 100
end
local function action(command, lane, kind, phase, opts)
  return {command=command,lane=lane or 'bal',kind=kind or 'combo',phase=phase,opts=opts}
end
local function combo(c, attacks, phase, overrides, destination)
  local projected,decisions
  if c.mode=='lock' then
    local intent={leftarm='prepare',rightarm='prepare',
      [c.selected_leg=='rightleg' and 'rightleg' or 'leftleg']='prepare'}
    for name,value in pairs(overrides or {}) do intent[name]=value end
    attacks,projected,decisions=S.normalize_attacks(c,attacks,intent)
    if not attacks then return nil,projected end
    if #attacks==0 then return nil,'no_safe_attacks' end
  end
  local opts={form=c.form,kata=c.kata,attacks=attacks}
  if destination then opts.transition=destination;opts.destination=destination end
  local command,why=Yso.monk.combo.build_shikudo(c.target,opts)
  if not command then return nil,why end
  local a=action(command,'bal','combo',phase,opts)
  a.projected_limbs=projected;a.light_decisions=decisions
  return a
end
local fillers={tykonos={'thrust light torso','thrust light torso'},
  willow={'hiraku light','hiru light'},rain={'ruku light torso','kuro light left'},
  oak={'nervestrike light','livestrike light'},gaital={'needle light','ruku light torso'},
  maelstrom={'livestrike light','ruku light torso'}}
local function next_form(from,to)
  local queue,seen={{from}},{}
  while #queue>0 do
    local path=table.remove(queue,1); local last=path[#path]
    if last==to then return path[2] end
    if not seen[last] then
      seen[last]=true
      for _,name in ipairs(graph[last] or {}) do
        local p={}; for i,v in ipairs(path) do p[i]=v end
        p[#p+1]=name; queue[#queue+1]=p
      end
    end
  end
end
local function travel(c,to,phase)
  local destination=next_form(c.form,to)
  if not destination then return nil,'no_legal_transition' end
  if (tonumber(c.kata) or 0)<5 then
    local attacks={}
    for i,piece in ipairs(fillers[c.form]) do
      attacks[i]=c.mode=='lock' and c.selected_leg=='rightleg' and piece=='kuro light left' and 'kuro light right' or piece
    end
    return combo(c,attacks,phase..'_kata')
  end
  return action('transition to '..destination..' form','bal','transition',phase,{destination=destination})
end
local function dispatch_ready(c)
  return has(c,'prone') and has(c,'crushedthroat')
    and (has(c,'damagedhead') or has(c,'mangledhead') or has(c,'head'))
    and (has(c,'leftleg') or has(c,'rightleg'))
end
local function scythe_ready(c)
  if not has(c,'mangledhead') and (tonumber(c.head_severity) or 0)<200 then return false end
  local n=0; for _,aff in ipairs(mental_pool) do if has(c,aff) then n=n+1 end end
  return n>=2
end
local function hit_info(c,piece)
  if type(piece)~='string' then return nil,'invalid_attack' end
  local key,arg=piece:lower():match('^(%a+)%s*(.-)$')
  local row=key and Yso.ref.monk.shikudo[key]
  if not row or not row.commands then return nil,'unknown_attack' end
  local light=arg=='light' or arg:match('^light%s+')~=nil
  if light then arg=arg:gsub('^light%s*','') end
  local role=row.commands[1].role
  local info={key=key,arg=arg,light=light,role=role,utility=key=='sweep' or key=='shatter'}
  info.eligible=role=='strike' and not info.utility
  local damage=row.limb_damage
  if damage and damage.variants then damage=damage.variants[has(c,'prone') and 'prone' or 'standing'] end
  if damage then
    info.limb=damage.limb or (damage.limb_by_side or {})[arg] or (damage.limb_by_choice or {})[arg]
    if not info.limb and damage.targeting then info.limb=arg:gsub(' ','') end
    local amount=tonumber((c.hit_damage or {})[key]) or damage.pct
    if amount and amount==amount and amount>=0 and amount<math.huge then
      if c.hyperfocus==info.limb and role=='strike' then amount=amount*0.5 end
      info.amount=amount
    end
  end
  return info
end
-- Pure policy: process each strike in command order. Projected damage is never
-- written to lb or promoted to a confirmed injury/affliction.
function S.normalize_attacks(c,attacks,intent)
  local out,totals,decisions={},{},{}
  for name,value in pairs(c.limbs or {}) do totals[name]=value end
  local labels={head='head',torso='torso',leftarm='left arm',rightarm='right arm',leftleg='left leg',rightleg='right leg'}
  local function pct(n) return string.format('%.2f',n):gsub('0+$',''):gsub('%.$','') end
  for _,piece in ipairs(attacks) do
    local info,err=hit_info(c,piece)
    if not info then return nil,err end
    local key,name=info.key,info.limb
    local normal=key..(info.arg~='' and ' '..info.arg or '')
    local mode=(intent or {})[name] or 'protect'
    local before=tonumber(totals[name])
    local known=name and limb_known(c,name)
    local after=known and info.amount and before+info.amount
    local injury=name and has(c,name)
    local allow=after and not injury and before<100
      and (mode=='break' or (mode=='prepare' and after<100-0.000000001))
    local label=labels[name] or name or key
    local title=key:sub(1,1):upper()..key:sub(2)
    if info.utility then
      out[#out+1]=normal
    elseif allow then
      out[#out+1]=normal;totals[name]=after
      decisions[#decisions+1]=label..' '..mode..': '..title..' '..pct(before)..'% -> '..pct(after)..'%'
    else
      local reason
      if not known then
        local confidence=c.limb_confidence and c.limb_confidence[name] or 'unknown'
        reason=label..' '..tostring(confidence or 'unknown')..' baseline'
      elseif not info.amount then reason=label..' unknown strike damage'
      elseif after and mode~='protect' and before<100 and not injury then
        reason=label..' protected: normal '..title..' would reach '..pct(after)..'%'
      else reason=label..' protected: '..((injury or (before and before>=100)) and 'already broken' or 'affliction pressure') end
      if info.eligible then
        out[#out+1]=key..' light'..(info.arg~='' and ' '..info.arg or '')
        decisions[#decisions+1]=reason..'; '..title..' LIGHT'..(mode=='break' and ' (break withheld)' or '')
      elseif info.role=='kick' then decisions[#decisions+1]=reason..'; '..title..' omitted'
      else return nil,'invalid_attack_role' end
    end
  end
  return out,totals,decisions
end
-- Read every piece in order, including multiple hits to the same limb. This
-- function never writes to the input snapshot or the live limb tracker.
function S.project(c, attacks)
  local totals={}; for k,v in pairs(c.limbs or {}) do totals[k]=v end
  local ref=Yso.ref.monk.shikudo
  local prone=has(c,'prone')
  for _,piece in ipairs(attacks) do
    local key,arg=piece:match('^(%a+)%s*(.-)$')
    local row=ref[key]; local damage=row and row.limb_damage
    local light=arg=='light' or arg:match('^light%s+')
    if light then arg=arg:gsub('^light%s*','') end
    if damage and not light then
      if damage.variants then damage=damage.variants[prone and 'prone' or 'standing'] end
      local name=damage.limb or (damage.limb_by_side or {})[arg] or (damage.limb_by_choice or {})[arg]
      if not name and damage.targeting then name=arg:gsub(' ','') end
      if not name or not damage.pct or totals[name]==nil then return nil,'unknown_limb_damage' end
      local amount=tonumber((c.hit_damage or {})[key]) or damage.pct
      if c.hyperfocus==name and row.commands[1].role=='strike' then amount=amount*0.5 end
      totals[name]=totals[name]+amount
    end
    -- Do not assume Sweep/Frontkick successfully prones during a combination.
  end
  return totals
end
local function safe_prep(c, attacks, phase)
  local totals,why=S.project(c,attacks)
  if not totals then return nil,why end
  for _,name in ipairs{'head','leftleg','rightleg'} do
    if (limb(c,name) or 0)<100 and (totals[name] or 0)>=100 then return nil,'premature_'..name..'_break' end
  end
  return combo(c,attacks,phase)
end
local function lock(c)
  local legside=c.selected_leg=='rightleg' and 'right' or 'left'
  if not has(c,'anorexia') then
    if c.form~='willow' then return travel(c,'willow','refresh_anorexia') end
    return combo(c,{'hiraku light','hiru light'},'anorexia')
  end
  if c.form~='oak' then
    if c.form=='rain' and (tonumber(c.kata) or 0)<5 then
      return combo(c,{'ruku light torso','kuro light '..legside},'slickness_weariness')
    end
    return travel(c,'oak','oak_lock')
  end
  local a
  if not has(c,'paralysis') then a={'nervestrike light','livestrike light','risingkick torso'}
  elseif not has(c,'asthma') then a={'livestrike light','ruku light torso','risingkick torso'}
  elseif not has(c,'slickness') then a={'ruku light torso','nervestrike light','risingkick torso'}
  elseif not has(c,'impatience') then return action('mind impatience '..c.target,'eq','mental','impatience')
  elseif not has(c,'weariness') then a={'kuro light '..legside,'ruku light torso','risingkick torso'}
  elseif limb_known(c,'leftarm') and limb_known(c,'rightarm') and not (has(c,'leftarm') and has(c,'rightarm')) then
    if (limb(c,'leftarm') or 0)>=100 and (limb(c,'rightarm') or 0)>=100 then
      return combo(c,{'livestrike light','ruku light torso','risingkick torso'},'awaiting_arm_injuries')
    end
    local side=(limb(c,'leftarm') or 0)<=(limb(c,'rightarm') or 0) and 'left' or 'right'
    return combo(c,{'ruku '..side,'ruku '..side,'risingkick torso'},'riftlock',{[side..'arm']='break'})
  elseif not has(c,'addiction') then
    return travel(c,'gaital','addiction')
  else a={'livestrike light','ruku light torso','risingkick torso'} end
  return combo(c,a,'lock_pressure')
end
local function limb_route(c, fork)
  if fork and scythe_ready(c) then return action('mind scythe','eq','mental','scythe') end
  if dispatch_ready(c) then return action('dispatch '..c.target,'bal','dispatch','dispatch') end
  if not c.limb_ready then return nil,'unverified_limb_feed' end
  local hit=tonumber((c.hit_damage or {}).kuro) or Yso.ref.monk.shikudo.kuro.limb_damage.pct
  local headhit=tonumber((c.hit_damage or {}).needle) or Yso.ref.monk.shikudo.needle.limb_damage.pct
  local function leg_ready(name) return prepped(c,name,hit) or has(c,name) or (limb(c,name) or 0)>=100 end
  local legs=leg_ready('leftleg') and leg_ready('rightleg')
  local head=prepped(c,'head',headhit) or has(c,'damagedhead') or has(c,'mangledhead') or has(c,'head')
  if not legs then
    if c.form~='rain' then return travel(c,'rain','leg_prep') end
    local side='left'
    if leg_ready('leftleg') or (not leg_ready('rightleg') and limb(c,'rightleg')<limb(c,'leftleg')) then side='right' end
    local attacks={'kuro '..side,'ruku light torso'}
    return safe_prep(c,attacks,'leg_prep')
  elseif not head then
    if c.form~='oak' then return travel(c,'oak','head_prep') end
    local attacks={'nervestrike','ruku light torso'}
    local projected=S.project(c,attacks)
    if projected and projected.head>=100 then attacks[1]='nervestrike light'; attacks[3]='risingkick head' end
    return safe_prep(c,attacks,'head_prep')
  end
  if c.form~='gaital' then return travel(c,'gaital','kill_setup') end
  if fork and (has(c,'mangledhead') or (tonumber(c.head_severity) or 0)>=200) then
    if not has(c,'impatience') then return action('mind impatience '..c.target,'eq','mental','scythe_mental') end
    return action('mind batter '..c.target,'eq','mental','scythe_mental')
  end
  local side=has(c,'leftleg') and 'right' or 'left'
  if not has(c,'prone') then return combo(c,{'sweep','flashheel '..side},'prone_leg_break') end
  if not has(c,'leftleg') or not has(c,'rightleg') then
    return combo(c,{'needle','needle','flashheel '..side},'second_leg_head')
  end
  return combo(c,{'needle','needle','spinkick'},fork and 'scythe_head' or 'head_windpipe')
end
local function blackout(c)
  if dispatch_ready(c) then return action('dispatch '..c.target,'bal','dispatch','dispatch') end
  if not c.limb_ready then return nil,'unverified_limb_feed' end
  if c.blackout_attempted then
    if not c.blackout_burst_done and has(c,'blackout') and has(c,'paralysis') and c.form=='rain' then
      return combo(c,{'frontkick left','kuro left','ruku right'},'blackout_burst')
    end
    return lock(c)
  end
  if not has(c,'paralysis') or not has(c,'clumsiness') then
    if c.form~='oak' then return travel(c,'oak','blackout_hindrance') end
    return combo(c,{'nervestrike light','ruku light left','risingkick torso'},'blackout_hindrance')
  end
  if c.form~='rain' then return travel(c,'rain','blackout_prep') end
  for _,name in ipairs{'leftarm','rightarm','leftleg'} do
    if (limb(c,name) or 0)>=100 or has(c,name) then return nil,'awaiting_limb_recovery' end
  end
  local hit=Yso.ref.monk.shikudo.kuro.limb_damage.pct
  local ready=true
  for _,name in ipairs{'leftarm','rightarm','leftleg'} do if not prepped(c,name,hit) then ready=false end end
  if not ready or (tonumber(c.kata) or 0)<9 then
    local left=not prepped(c,'leftarm',hit) and 'ruku left' or 'ruku light left'
    local right=not prepped(c,'rightarm',hit) and 'ruku right' or 'ruku light right'
    local kick=not prepped(c,'leftleg',hit) and 'kuro left' or 'kuro light left'
    -- All three are staff strikes: select two and keep balance legality.
    if prepped(c,'leftarm',hit) and prepped(c,'rightarm',hit) then return combo(c,{kick,'ruku light torso'},'blackout_prep') end
    return combo(c,{left,right},'blackout_prep')
  end
  if has(c,'blackout') then return combo(c,{'frontkick left','kuro left','ruku right'},'blackout_burst') end
  if not c.blackout_physical_ready then return nil,'awaiting_blackout_timing' end
  return action('mind blackout','eq','mental','blackout_start')
end
function S.lock_requirements(c)
  local leg=c.selected_leg=='rightleg' and 'rightleg' or 'leftleg'
  local out={ready=true,missing={},prepared={},leg=leg}
  for _,name in ipairs{'leftarm','rightarm',leg} do
    local key=name==leg and 'kuro' or 'ruku'
    local side=name:find('right',1,true) and 'right' or 'left'
    local hit=hit_info(c,key..' '..side)
    local known=limb_known(c,name)
    local n=limb(c,name)
    local ready=has(c,name) or (known and hit.amount and n<100 and n+hit.amount>=100-0.000000001)
    out.prepared[name]=ready==true
    if not ready then
      out.ready=false
      local reason=not known and ((c.limb_confidence or {})[name] or 'unknown')..' baseline'
        or (n>=100 and 'injury unconfirmed' or 'needs preparation')
      out.missing[#out.missing+1]=name..': '..reason
    end
  end
  return out
end
local function venom_lock(c)
  for _,name in ipairs{'anorexia','asthma','slickness','paralysis'} do if not has(c,name) then return false end end
  return true
end
local function core_lock(c) return venom_lock(c) and has(c,'impatience') end
function S.lock_level(c)
  if core_lock(c) then return has(c,'weariness') and 'truelock' or 'hardlock' end
  if venom_lock(c) then return 'venomlock' end
  if has(c,'anorexia') and has(c,'asthma') and has(c,'slickness') then return 'softlock' end
  return 'building'
end
function S.select_lock_mental(c)
  local stage=(c.lock_plan or {}).stage
  if c.mode=='lock' and (stage=='harden' or stage=='maintain') and not c.mental_blocked
    and c.locked and c.hyperfocus=='head' and venom_lock(c) and not has(c,'impatience') then
    return action('mind impatience '..c.target,'eq','mental','harden_lock')
  end
end
local function staged_lock(c)
  local req=S.lock_requirements(c)
  local plan=c.lock_plan or {};local stage=plan.stage or 'prepare'
  if stage=='pressure' and not req.ready then stage='prepare' end
  if stage=='close_leg' and not (has(c,'leftarm') and has(c,'rightarm')) then stage='prepare' end
  if stage=='close_anorexia' and not (has(c,'leftarm') and has(c,'rightarm') and has(c,req.leg) and has(c,'prone')) then stage='prepare' end
  if stage=='maintain' and not core_lock(c) then stage='harden' end
  if (stage=='harden' or stage=='maintain') and not venom_lock(c) then stage='prepare' end
  if stage=='harden' and core_lock(c) then stage='maintain' end
  local function decorate(a,why)
    if a then a.lock_stage=stage;a.requirements=req end
    return a,why
  end
  local function make(attacks,phase,nextplan,intent,destination)
    local a,why=combo(c,attacks,phase,intent,destination)
    if a then a.next_lock_plan=nextplan end
    return decorate(a,why)
  end
  local function filler()
    local out={}
    for i,piece in ipairs(fillers[c.form] or {}) do
      out[i]=req.leg=='rightleg' and piece=='kuro light left' and 'kuro light right' or piece
    end
    return out
  end
  local function go(destination,nextplan)
    local hop=next_form(c.form,destination)
    if not hop then return nil,'no_legal_transition' end
    if (tonumber(c.kata) or 0)>=5 then
      return make(filler(),'lock_'..stage..'_travel',hop==destination and nextplan or {stage=stage,pressure_step=1},nil,hop)
    end
    return make(filler(),'lock_'..stage..'_kata',{stage=stage,pressure_step=1})
  end
  if not c.form or c.form=='none' then return decorate(action('adopt rain form','bal','adopt','opening')) end
  if not graph[c.form] then return nil,'unknown_form' end
  if c.hyperfocus~='head' then return decorate(action('hyperfocus head','bal','hyperfocus','head_parry_bypass')) end
  if c.shield then return make({'shatter',filler()[1]},'shield') end
  local kata=tonumber(c.kata) or 0
  if stage=='prepare' then
    if c.form~='rain' then return go('rain',{stage='prepare'}) end
    if req.ready then return go('oak',{stage='pressure',pressure_step=1}) end
    if kata>=21 then return go('oak',{stage='prepare'}) end
    if not req.prepared.leftarm or not req.prepared.rightarm then
      return make({'ruku left','ruku right'},'prepare_arms',{stage='prepare'})
    end
    return make({'kuro '..(req.leg=='rightleg' and 'right' or 'left'),'ruku light torso'},'prepare_leg',{stage='prepare'})
  elseif stage=='pressure' then
    if c.form~='oak' then return go('oak',{stage='pressure',pressure_step=1}) end
    local step=tonumber(plan.pressure_step) or 1
    if step>=4 and kata>=5 then
      return make({'ruku left','ruku right'},'release_arms',{stage='close_leg'},
        {leftarm='break',rightarm='break'},'willow')
    end
    if kata>=9 then return go('willow',{stage='prepare'}) end
    if step>=4 then step=1 end
    local rotation={{'nervestrike light','livestrike light'},
      {'livestrike light','ruku light torso'},{'nervestrike light','ruku light torso'}}
    return make(rotation[step],'oak_pressure_'..step,{stage='pressure',pressure_step=step+1})
  elseif stage=='close_leg' then
    if c.form~='willow' then return go('willow',{stage='close_leg'}) end
    if has(c,req.leg) and has(c,'prone') then
      return make({'hiraku light','hiru light'},'close_anorexia',{stage='harden'})
    end
    if not req.prepared[req.leg] then return go('rain',{stage='prepare'}) end
    return make({'sweep','flashheel '..(req.leg=='rightleg' and 'right' or 'left')},'release_leg',
      {stage='close_anorexia'},{[req.leg]='break'})
  elseif stage=='close_anorexia' then
    if c.form~='willow' then return go('willow',{stage='close_anorexia'}) end
    return make({'hiraku light','hiru light'},'close_anorexia',{stage='harden'})
  elseif stage=='harden' or stage=='maintain' then
    -- No form detour: consume the actual closing window in the current form.
    local mental=S.select_lock_mental(c)
    if mental then return decorate(mental) end
    if kata>=(c.form=='rain' and 21 or 9) then
      return go(({rain='oak',oak='willow',willow='rain'})[c.form] or 'rain',{stage=stage})
    end
    return make(filler(),stage=='harden' and 'harden_pressure' or 'maintain_lock',{stage=stage})
  end
  return nil,'unknown_lock_stage'
end
function S.select(c)
  if type(c)~='table' or not tostring(c.target or ''):match("^[%a%d_'-]+$") then return nil,'invalid_target' end
  if c.tracked==false then return nil,'untracked_target' end
  if c.mode=='lock' then return staged_lock(c) end
  if not c.locked then return action('mind lock '..c.target,'eq','mindlock','mindlock') end
  if not c.form or c.form=='none' then
    return action('adopt '..(c.mode=='lock' and 'willow' or 'rain')..' form','bal','adopt','opening')
  end
  if not graph[c.form] then return nil,'unknown_form' end
  if c.shield then return combo(c,{'shatter',fillers[c.form][1]},'shield') end
  if c.mode=='lock' and c.hyperfocus~='head' then
    return action('hyperfocus head','bal','hyperfocus','head_parry_bypass')
  end
  if c.mode=='scythe' and scythe_ready(c) then return action('mind scythe','eq','mental','scythe') end
  if c.mode~='lock' and dispatch_ready(c) then return action('dispatch '..c.target,'bal','dispatch','dispatch') end
  -- Keep the conservative existing 24/12 kata ceilings; never claim measured caps.
  if (tonumber(c.kata) or 0)>=(c.form=='rain' and 21 or 9) and c.form~='tykonos' then
    return travel(c,graph[c.form][1],'kata_recovery')
  end
  if c.mode=='lock' then
    if c.form=='gaital' and has(c,'anorexia') and has(c,'paralysis') and has(c,'asthma')
        and has(c,'slickness') and has(c,'impatience') and has(c,'weariness') and not has(c,'addiction') then
      return combo(c,{'jinzuku light','ruku light torso'},'addiction')
    end
    return lock(c)
  end
  if c.mode=='dispatch' then return limb_route(c,false) end
  if c.mode=='scythe' then return limb_route(c,true) end
  if c.mode=='blackout' then return blackout(c) end
  return nil,'unknown_strategy'
end
return S
