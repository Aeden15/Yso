local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
local root=arg[1] or here..'../../'
local target,now,ai,timers,gains='Foe',10000,false,{},{}
function getEpoch() return now end
function tempTimer(_,fn) timers[#timers+1]=fn;return #timers end
function killTimer() end
function cecho() end
Yso={off={magi={}},get_target=function() return target end,target_is_valid=function() return true end}
local RC=dofile(root..'Magi/magi_route_core.lua')
affstrack={score={frozen=200,aflame=0,hypothermia=0,nausea=0,weariness=0,fulminated=0,epilepsy=0}}
ak={ai=function() return ai end,defs={},magi={resonance={Water=3,Air=3,Earth=3,Fire=3}},scoreup=function() end}
function OppGainedAff(aff)
  gains[#gains+1]=aff
  for word in aff:gmatch('%S+') do
    affstrack.score[word]=word=='frozen' and math.min(300,(affstrack.score[word] or 0)+100) or 100
  end
end
function OppLostAff(aff) affstrack.score[aff]=0 end
function ak.flameon(kind) affstrack.score.aflame=math.min(500,affstrack.score.aflame+(kind=='emanation' and 200 or 100)) end
local T=dofile(arg[2] or root..'Magi/magi_spell_feedback.lua')
local function handle(event,who,detail) return T.handle(event,who or target,detail) end
assert(handle('hypothermia'))
assert(affstrack.score.hypothermia==100 and affstrack.score.frozen==200,'Hypothermia confirmation predicted a cold stage')
local count=#gains
handle('hypothermia','Other');ai=true;handle('hypothermia');ai=false
assert(#gains==count,'foreign target or AI guard failed')
handle('dehydrate_attempt')
assert(affstrack.score.nausea==0 and affstrack.score.weariness==0,'attempt predicted outcome')
handle('dehydrate_freeze')
assert(affstrack.score.frozen==300 and affstrack.score.weariness==100 and affstrack.score.nausea==100)
handle('dehydrate_burning')
assert(affstrack.score.aflame==100)
handle('fulminate');assert(affstrack.score.fulminated==100 and affstrack.score.epilepsy==0)
handle('fulminate');assert(affstrack.score.epilepsy==100)
handle('fulminate');assert(affstrack.score.paralysis==100)
handle('emanation_earth');assert(T.observed.foe.calcifiedtorso_at==now and not affstrack.score.calcifiedhead and not affstrack.score.calcifiedtorso)
assert(ak.magi.resonance.Earth==0)
handle('magma');assert(affstrack.score.scalded==100)
local old_timer=timers[#timers]
now=now+1;handle('magma');old_timer()
assert(affstrack.score.scalded==100,'older expiry cleared refreshed Scalded')
local latest=timers[#timers];target='Other';latest()
assert(affstrack.score.scalded==100,'old target timer cleared new target scores')
target='Foe';handle('erode_start');handle('erode_result',nil,'shield')
assert(ak.defs.shield==false,'matched erosion did not clear shield')
ak.defs.shield=true;handle('erode_start');now=now+4;handle('erode_result',nil,'shield')
assert(ak.defs.shield==true,'stale erosion attribution cleared shield')
handle('conflagrate_fail');assert(affstrack.score.conflagrate~=100,'failure fabricated Conflagrate')
handle('conflagrate');assert(affstrack.score.conflagrate==100 and affstrack.score.aflame>=200)
local hp=ak.healthpercent;handle('conflagrate_tick');assert(ak.healthpercent==hp,'tick guessed HP')
ak.magi.resonance.Air=3
local prior=#gains
handle('emanation_air','Other')
assert(ak.magi.resonance.Air==0 and #gains==prior,'own resonance consumption depended on current victim')
ak.defs.shield=true
handle('erode_start');handle('erode_start','Other');handle('erode_result',nil,'shield')
assert(ak.defs.shield==true,'interleaved foreign Erode start retained stale attribution')
affstrack.score.aflame=100
handle('conflagrate_tick')
assert(affstrack.score.aflame==100,'ongoing Conflagrate fabricated a cured burn stack')
affstrack.score.aflame=400;handle('conflagrate_tick');assert(affstrack.score.aflame==400)
local prone_alerts,limb_flushes=0,0
function EchoForMajorAff(aff) assert(aff=='PRONE');prone_alerts=prone_alerts+1 end
ak.limbs={ParseonLine=function() limb_flushes=limb_flushes+1 end}
handle('mudslide');handle('plague');handle('plague','Other')
assert(prone_alerts==2,'migrated named prone responses lost local alerts')
handle('conflagrate');handle('conflagrate_tick');handle('conflagrate','Other')
assert(limb_flushes==3,'migrated Conflagrate responses lost AK limb evidence flushing')
print('PASS: Magi feedback confirmation, target/AI guards, tiers, safe timers, erosion and no predicted HP')
