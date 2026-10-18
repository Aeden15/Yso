-- Confirmed target/form/kata state in; damage-route options out. No sending,
-- predicted afflictions, limb damage, kata increments, or mutable decisions.
Yso = Yso or {}
Yso.monk = Yso.monk or {}
Yso.monk.shikudo = Yso.monk.shikudo or {}
local F = Yso.monk.shikudo
F.ai = F.ai or {}
local A = F.ai

function A.select(ctx)
  ctx = type(ctx) == 'table' and ctx or {}
  local form = tostring(ctx.form or ''):lower()
  if form == '' or form == 'none' then return {command='adopt rain form',kind='adopt'} end
  local ref = Yso.ref and Yso.ref.monk and Yso.ref.monk.shikudo
  if not ref or not ref[form] or not ref[form].attacks then return nil, 'unknown_form' end
  if ctx.shield ~= true and ctx.dispatch_ready == true then
    local target = tostring(ctx.target or '')
    if not target:match("^[%a%d_'-]+$") then return nil, 'invalid_target' end
    return {command='dispatch '..target,kind='dispatch'}
  end
  local kata = tonumber(ctx.kata) or 0
  local leg = ctx.leg == 'right' and 'right' or 'left'
  local arm = ctx.arm == 'right' and 'right' or 'left'
  local affs = type(ctx.affs) == 'table' and ctx.affs or {}
  local function has(key) return affs[key] == true or (tonumber(affs[key]) or 0) >= 100 end
  local attacks, next_form, flow
  if form == 'rain' then
    attacks = {'kuro '..leg, 'kuro '..leg, 'frontkick '..arm}
    if ctx.leg_ready == true or ctx.prone == true then
      attacks = {'hiru', 'hiru', 'frontkick '..arm}
    end
    -- Retain the installed damage route's fast progression at six confirmed
    -- actions; 24/12 below are conservative policy, not measured game caps.
    next_form, flow = 'oak', ctx.leg_ready == true or ctx.prone == true or kata >= 6
  elseif form == 'oak' then
    attacks = {has('paralysis') and 'livestrike' or 'nervestrike', 'kuro '..leg, 'risingkick head'}
    if ctx.leg_ready == true or ctx.prone == true then attacks[2] = 'livestrike' end
    next_form, flow = 'gaital', true
  elseif form == 'gaital' then
    attacks = ctx.prone == true and {'needle', 'needle', 'spinkick'} or {'sweep', 'flashheel '..leg}
    next_form, flow = 'rain', kata >= 9
  elseif form == 'willow' then
    attacks = {'hiru', has('anorexia') and has('stuttering') and 'hiru' or 'hiraku', 'flashheel '..leg}
    next_form, flow = 'rain', kata >= 6
  elseif form == 'tykonos' then
    attacks = {'thrust head', 'thrust torso', 'risingkick head'}
    next_form, flow = 'willow', true
  elseif form == 'maelstrom' then
    attacks = {'livestrike', 'ruku torso', 'risingkick torso'}
    next_form, flow = 'oak', true
  end
  if form ~= 'tykonos' and kata + 3 >= (form == 'rain' and 24 or 12) and kata >= 5 then
    return {command='transition to '..next_form..' form',kind='transition'}
  end
  if ctx.shield == true then
    -- Sweep consumes both staff balances; replace it before inserting Shatter.
    local strike = form == 'gaital' and 'needle' or attacks[2]
    local kick = attacks[#attacks]
    attacks = {'shatter', strike, kick}
  elseif form == 'rain' and (ctx.leg_ready == true or ctx.prone == true) then
    -- Preserve the installed order: prone first, then Hiru's prone benefit.
    attacks = {attacks[3], attacks[1], attacks[2]}
  end
  return {form=form, kata=kata, attacks=attacks,
    transition=flow and kata >= 5 and next_form or nil, kind='combo'}
end

-- Legacy callers still ask for only the second staff balance. Resolve through
-- the same selector, with absent scores treated as unconfirmed.
function shikudostafftwo()
  local target = type(Yso.get_target) == 'function' and Yso.get_target() or rawget(_G,'target')
  local selected = type(IsTargetted) == 'function' and IsTargetted(target)
  local scores = selected and rawget(_G,'affstrack') or nil
  local affs = scores and scores.score or {}
  local opts = A.select{form=F.form or rawget(_G,'shikudostance'), kata=F.kata,
    leg=rawget(_G,'tpll') == true and 'right' or 'left', affs=affs,
    prone=(tonumber(affs.prone) or 0) >= 100}
  stafftwo = opts and opts.attacks and opts.attacks[2] or ''
  return stafftwo
end
