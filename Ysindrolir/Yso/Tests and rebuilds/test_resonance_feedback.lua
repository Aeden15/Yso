local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])')
local root=here..'../../'
local messages={}
function cecho(message) messages[#messages+1]=message end
function getEpoch() return 10000 end
local guarded=false
ak={ai=function() return guarded end,magi={resonance={Air=0,Earth=0,Fire=0,Water=0}}}
Yso={magi={}}; yso=Yso
dofile(root..'Magi/magi_reference.lua')
dofile(root..'Magi/magi_route_core.lua')
local F=dofile(arg[1] or root..'Magi/resonance_feedback.lua')
local R=Yso.magi.resonance
local RC=Yso.off.magi.route_core
-- AK's tracker is authoritative: positive and depletion observations must not
-- create a second route-local resonance value or mutate AK's measurements.
ak.magi.resonance.Air=2; ak.magi.resonance.Earth=2
F.notice()
local r=RC.read_resonance(); assert(r.air==2 and r.earth==2,'dual notice not read from AK')
ak.magi.resonance.Air=0; F.notice()
assert(RC.read_resonance().air==0,'depletion not read from AK')
guarded=true
local before=#messages
F.notice(); F.notice()
assert(#messages==before+1,'AK guard must warn once instead of pretending to track')
guarded=false; F.notice(); guarded=true; F.notice()
assert(#messages==before+2,'guard warning did not reset')
ak.magi.resonance.Fire=1
F.failure('major','Fire')
assert(F.last_failure.element=='fire' and F.last_failure.required==3,'failure diagnostic missing')
assert(ak.magi.resonance.Fire==1 and RC.read_resonance().fire==1,'failure invented a resonance level')
assert(type(Yso.off.magi.focus)~='table' or Yso.off.magi.focus.note_resonance==nil,'legacy callbacks restored')
assert(not F.failure('invalid','Fire'),'invalid feedback accepted')
assert(not F.failure('major','bogus'),'invalid element accepted')
print('PASS: AK owns resonance; guarded tracking and insufficient resonance are reported without fabricated state')
