local root=arg[1] or 'Ysindrolir'
local events,timers,serial={},{},0
raiseEvent=function(...) events[#events+1]={...} end
tempTimer=function(_,fn) serial=serial+1;timers[serial]=fn;return serial end
killTimer=function(id) timers[id]=nil end
cecho=function() end
Yso={monk={}};lb=nil
local load=loadfile(arg[2] or root..'/Monk/limb_tracker.lua');assert(load,'Maintained limb tracker missing');load()
dofile(root..'/Monk/shikudo_limb_bridge.lua')
local B=Yso.monk.limbs
lb.Old={hits={head=0,torso=0,['left arm']=0,['right arm']=0,['left leg']=0,['right leg']=0},meta={calibrated=true,uncertain={}}}
assert(not B.snapshot('Old').ready,'Legacy global calibration must not invent per-limb baselines')
assert(not B.snapshot('Bob').ready)
lb.initTarget('bob');assert(lb.Bob.hits['left leg']==0)
assert(not B.snapshot('Bob').ready, 'An unverified initial zero is not a measured feed')
lb.addHit('BOB','leftleg',7.6);assert(B.snapshot('bob').hits.leftleg==7.6)
assert(not B.snapshot('bob').ready,'One reported delta cannot verify every zero baseline')
assert(B.snapshot('bob').confidence.leftleg=='unknown')
lb.resetLimb('Bob','left leg')
assert(B.snapshot('bob').confidence.leftleg=='known' and B.snapshot('bob').confidence.head=='unknown')
lb.addHit('Bob','left leg',3.9)
assert(B.snapshot('bob').hits.leftleg==3.9,'Game-reported effective damage is never modified again')
local before=#events
assert(not lb.addHit('Bob','tail',20))
assert(not lb.addHit('Bob','head',-1))
assert(not lb.addHit('Bob','head','bad'))
assert(#events==before)
lb.addHit('Bob','left leg',100)
lb.salve('Bob','legs');assert(not B.snapshot('Bob').ready)
assert(B.snapshot('Bob').confidence.leftleg=='uncertain')
timers[lb.Bob.t.cure]()
assert(not B.snapshot('Bob').ready,'Generic salve timer is not confirmed healing')
before=#events;lb.resetLimb('Bob','left leg');assert(#events>before)
lb.resetAll('Bob');assert(B.snapshot('Bob').ready)
assert(B.snapshot('Bob').confidence.head=='known')
lb.salve('Bob','head');assert(B.snapshot('Bob').confidence.head=='uncertain')
assert(B.snapshot('Bob').confidence.leftarm=='known','A head salve must not invalidate arm confidence')
lb.confirmRecovery('Bob','head');assert(B.snapshot('Bob').ready)
lb.addHit('D-Name','head',12);assert(lb['D-name'].hits.head==12)
local t=lb['D-name'].t.head;timers[t]()
assert(not B.snapshot('D-Name').ready,'Expired tracking must not enable a break')
local old=lb.Bob.hits.head
B.note_success('Bob','hiraku')
assert(lb.Bob.hits.head==old,'A confirmation without a numeric damage message must not invent damage')
-- lra must reset the same target resolver used by the duel controller.
assert(type(lb.resetCurrentTarget)=='function','Visible current-target reset is missing')
target='Stale';Yso.get_target=function() return 'Current' end
assert(lb.resetCurrentTarget())
assert(B.snapshot('Current').ready and not B.snapshot('Stale').ready)
Yso.get_target=function() return '' end
assert(not lb.resetCurrentTarget(),'An empty canonical target must not reset a stale global target')
Yso.get_target=nil;target='Fallback'
assert(lb.resetCurrentTarget() and B.snapshot('Fallback').ready)
dofile(root..'/Monk/monk_reference.lua')
dofile(root..'/Monk/shikudo_duel_selector.lua')
local baseline=B.snapshot('Fallback')
local attacks=Yso.monk.shikudo.duel_selector.normalize_attacks(
  {limbs=baseline.hits,limb_confidence=baseline.confidence,affs={}},
  {'ruku light left','ruku light right'},{leftarm='prepare',rightarm='prepare'})
assert(attacks[1]=='ruku left' and attacks[2]=='ruku right','A reset baseline must enable normal arm preparation')
lb.addHit('Fallback','left arm',7.6)
assert(B.snapshot('Fallback').hits.leftarm==7.6,'Actual damage must accumulate after lra baseline')
print('PASS limb integration: normalization, reported damage, uncertainty, resets, expiry, no invented hits, current-target reset')
