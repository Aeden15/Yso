local root = arg[1] or 'Ysindrolir'
Yso = {}
dofile(root..'/Monk/monk_reference.lua')
dofile(root..'/Monk/combo.lua')
local loader = loadfile(root..'/Monk/shikudo_duel_selector.lua')
assert(loader, 'Shikudo duel selector missing')
loader()
local S = Yso.monk.shikudo.duel_selector
local function context(form, affs)
  return {target='Bob',form=form,kata=6,mode='lock',locked=true,hyperfocus='head',affs=affs or {},
    limbs={head=0,leftleg=0,rightleg=0,leftarm=0,rightarm=0,torso=0},limb_ready=true}
end
local function choose(c)
  local a, reason = S.select(c)
  assert(a, reason)
  assert(type(a.command)=='string' and a.command~='')
  return a
end
local c=context(nil); local a=choose(c)
assert(a.command=='adopt rain form')
c=context('willow'); a=choose(c)
assert(a.command:find('hiraku light',1,true) and a.command:find('transition rain',1,true))
c.hyperfocus=nil;a=choose(c)
assert(a.command=='hyperfocus head' and a.lane=='bal' and a.kind=='hyperfocus','Lock mode must bypass the observed head parry before pressure')
c.hyperfocus='torso';assert(choose(c).command=='hyperfocus head')
c=context('rain');a=choose(c);assert(a.command=='combo Bob ruku left ruku right')
c.limbs.leftarm=94;c.limbs.rightarm=94;c.limbs.leftleg=94
a=choose(c);assert(a.command:find('transition oak',1,true))
c=context('oak');c.lock_plan={stage='pressure',pressure_step=1};c.limbs.leftarm=94;c.limbs.rightarm=94;c.limbs.leftleg=94;a=choose(c)
assert(a.command:find('nervestrike light',1,true))
assert(S.select_lock_mental(c)==nil)
c.lock_plan={stage='harden'};c.affs={anorexia=true,asthma=true,slickness=true,paralysis=true}
assert(S.select_lock_mental(c).command=='mind impatience Bob')
c.affs.impatience=true;assert(S.select_lock_mental(c)==nil)
c=context('rain'); c.kata=0; a=choose(c)
assert(a.kind=='combo' and not a.command:find('transition',1,true))
c=context('rain'); c.locked=false; assert(choose(c).command=='combo Bob ruku left ruku right')
c=context('oak'); c.shield=true; assert(choose(c).command:find('shatter',1,true))
c=context('oak'); c.tracked=false; assert(S.select(c)==nil)
c=context('oak');c.limbs.leftarm=94;c.limbs.rightarm=94;c.limbs.leftleg=94;c.lock_plan={stage='pressure',pressure_step=1};c.affs.paralysis=0
assert(choose(c).command:find('nervestrike light',1,true), 'Numeric zero cannot be a confirmed affliction')
for _,mode in ipairs{'dispatch','blackout','scythe'} do
  c=context('rain'); c.mode=mode; c.limb_ready=false
  local out,why=S.select(c); assert(out==nil and why=='unverified_limb_feed')
  c.limb_ready=true; a=choose(c); assert(a.command~='')
end
c=context('gaital',{prone=true,crushedthroat=true,damagedhead=true,leftleg=true})
c.mode='dispatch'; assert(choose(c).command=='dispatch Bob')
c.affs.damagedhead=nil; assert(choose(c).command~='dispatch Bob')
c=context('gaital',{prone=true,crushedthroat=true,damagedhead=true,leftleg=true})
c.mode='scythe'; c.affs.mangledhead=true; c.affs.stupidity=true; c.affs.impatience=true
assert(choose(c).command=='mind scythe')
c=context('rain'); c.mode='dispatch'; c.limbs.leftleg=95;c.limbs.rightleg=95
a=choose(c); assert(not a.command:find('kuro left ',1,true) and not a.command:find('kuro right ',1,true))
c=context('rain',{paralysis=true,clumsiness=true});c.mode='blackout';c.kata=10
c.limbs.leftarm=100;c.limbs.rightarm=95;c.limbs.leftleg=95;c.blackout_physical_ready=true
local out,why=S.select(c)
assert(out==nil and why=='awaiting_limb_recovery','Blackout prep must not keep attacking a broken limb')
c.blackout_attempted=true;c.blackout_burst_done=true;c.affs.blackout=true
a=choose(c);assert(a.phase~='blackout_burst','A completed blackout burst must not repeat')
c=context('gaital',{prone=true,crushedthroat=true,damagedhead=true,leftleg=true});c.mode='dispatch';c.kata=10
assert(choose(c).command=='dispatch Bob','A confirmed kill must take priority over kata rotation')
local combo=Yso.monk.combo.build_shikudo
assert(combo('Bob',{form='oak',attacks={'nervestrike light','ruku light torso','risingkick torso'}}))
assert(not combo('Bob',{form='oak',attacks={'risingkick light head'}}))
assert(not combo('Bob',{form='oak',attacks={'ruku torso light'}}))
assert(not combo('Bob',{form='oak',attacks={'nervestrike light light'}}))
assert(not combo('Bob',{form='willow',attacks={'livestrike light'}}))
print('PASS Shikudo duel selection: forms, lock priorities, four modes, gates, LIGHT syntax')
