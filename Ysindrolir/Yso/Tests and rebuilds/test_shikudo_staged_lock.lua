local root=arg[1] or 'Ysindrolir'
Yso={};dofile(root..'/Monk/monk_reference.lua');dofile(root..'/Monk/combo.lua')
dofile(arg[2] or root..'/Monk/shikudo_duel_selector.lua')
local S=Yso.monk.shikudo.duel_selector
local function context()
  return {target='Bob',tracked=true,mode='lock',form='rain',kata=0,locked=false,hyperfocus='head',
    selected_leg='leftleg',limbs={head=0,torso=0,leftarm=0,rightarm=0,leftleg=0,rightleg=0},
    limb_confidence={head='known',torso='known',leftarm='known',rightarm='known',leftleg='known',rightleg='known'},
    affs={},lock_plan={stage='prepare',pressure_step=1}}
end
local c=context()
local a=assert(S.select(c))
assert(a.command=='combo Bob ruku left ruku right','Start limb preparation despite absent mindlock/anorexia')
assert(type(S.select_lock_mental)=='function')
assert(S.select_lock_mental(c)==nil,'EQ attacks still require a confirmed mindlock')
c.locked=true;assert(S.select_lock_mental(c)==nil,'Preparation must not spend EQ on Impatience')
c.affs.impatience=true;assert(S.select_lock_mental(c)==nil)
c.hyperfocus=nil;assert(S.select(c).command=='hyperfocus head')
c.form=nil;assert(S.select(c).command=='adopt rain form')
c=context();c.limbs.leftarm=94;c.limbs.rightarm=94
a=assert(S.select(c));assert(a.command:find('kuro left',1,true),'Prepare selected leg once both arms are protected')
c.limbs.leftleg=94;c.kata=6
a=assert(S.select(c));assert(a.command:find('transition oak',1,true))
assert(a.next_lock_plan.stage=='pressure' and c.lock_plan.stage=='prepare','Pure preview must not advance live stage')
c.lock_plan=a.next_lock_plan;c.form='oak';c.kata=0
local expected={'nervestrike light livestrike light','livestrike light ruku light torso','nervestrike light ruku light torso'}
for i=1,3 do
  a=assert(S.select(c));assert(a.command:find(expected[i],1,true),'Oak pressure must not starve slickness when paralysis is cured')
  c.lock_plan=a.next_lock_plan;c.kata=c.kata+2
end
a=assert(S.select(c));assert(a.command=='combo Bob ruku left ruku right transition willow','Arm release must not depend on Impatience or mindlock')
c.locked=true;c.affs.impatience=true
a=assert(S.select(c));assert(a.command=='combo Bob ruku left ruku right transition willow')
assert(a.next_lock_plan.stage=='close_leg')
c.lock_plan=a.next_lock_plan;c.form='willow';c.kata=0
a=assert(S.select(c));assert(not a.command:find('flashheel',1,true),'Parried arm release must not be promoted to a closing window')
c.affs.leftarm=true;c.affs.rightarm=true
a=assert(S.select(c));assert(a.command=='combo Bob sweep flashheel left')
c.lock_plan=a.next_lock_plan
a=assert(S.select(c));assert(a.lock_stage=='prepare','Unconfirmed leg/prone must not count as a completed disable')
c.affs.leftleg=true;c.affs.prone=true
a=assert(S.select(c));assert(a.command=='combo Bob hiraku light hiru light')
c.lock_plan=a.next_lock_plan;c.affs.anorexia=true;c.affs.asthma=true;c.affs.slickness=true;c.affs.paralysis=true
c.affs.impatience=nil
a=assert(S.select(c));assert(a.lock_stage=='harden' and a.lane=='eq' and a.command=='mind impatience Bob')
assert(c.form=='willow','No form detour to Rain during a closing window')
c.mental_blocked=true;a=assert(S.select(c));assert(a.lane=='bal','A physical action must separate mental retries')
c.mental_blocked=nil;c.affs.impatience=true
a=assert(S.select(c));assert(a.lock_stage=='maintain')
assert(S.lock_level(c)=='hardlock','Weariness is required to claim truelock')
c.affs.weariness=true;assert(S.lock_level(c)=='truelock')
c.affs.impatience=nil;assert(S.lock_level(c)=='venomlock')
c.form='rain';a=assert(S.select(c));assert(a.lane=='eq' and a.command=='mind impatience Bob','Use Rain directly when already there')
c.locked=false;a=assert(S.select(c));assert(a.lane=='bal','No mental cast without confirmed mindlock')
c.locked=true;c.form='willow'
for _,aff in ipairs{'anorexia','asthma','slickness','paralysis'} do
  c.affs[aff]=nil;assert(S.select_lock_mental(c)==nil,'Missing '..aff..' cancels Impatience')
  a=assert(S.select(c));assert(a.lock_stage=='prepare','Lost prerequisite reassesses setup')
  c.affs[aff]=true
end
c.affs.anorexia=nil;a=assert(S.select(c));assert(a.lock_stage=='prepare','Cured closing attempt must reassess setup, not chase anorexia')
c=context();c.kata=22;a=assert(S.select(c));assert(a.command:find('transition oak',1,true) and a.next_lock_plan.stage=='prepare')
c=context();c.limb_confidence.leftarm='unknown';c.limb_confidence.rightarm='uncertain'
a=assert(S.select(c));assert(a.command=='combo Bob ruku light left ruku light right')
assert(a.requirements and #a.requirements.missing>0)
c=context();c.selected_leg='rightleg';c.limbs.leftarm=94;c.limbs.rightarm=94
a=assert(S.select(c));assert(a.command:find('kuro right',1,true))
c=context();c.mode='dispatch';c.locked=false
assert(S.select(c).command=='mind lock Bob','Other duel strategies retain their existing opener')
print('PASS staged lock planner: preparation without Impatience, bounded Oak rotation, confirmed disable, anorexia-last, closing-window EQ, lock levels, reassessment')
