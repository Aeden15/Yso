local root=arg[1] or 'Ysindrolir'
Yso={};local M=dofile(root..'/Apostate/lock_route.lua')
assert(type(M)=='table' and type(M.select)=='function','missing simplified selector')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function picks(scores,a,b)
 local snapshot={deaf=100};for k,v in pairs(scores) do snapshot[k]=v end
 local out=M.select(snapshot);eq(out[1],a);eq(out[2],b);return out
end
picks({deaf=0},'paralysis','undeaf')
picks({paralysis=100,deaf=0},'undeaf','impatience')
picks({paralysis=100,deaf=99},'undeaf','impatience')
picks({},'paralysis','impatience')
picks({paralysis=100},'impatience','asthma')
picks({paralysis=99,impatience=100},'paralysis','asthma')
picks({asthma=100,impatience=100},'paralysis','manaleech')
local s={paralysis=100,asthma=100,impatience=100}
picks(s,'manaleech','stupidity')
s.stupidity=100;picks(s,'manaleech','confusion')
s.confusion=100;s.dizziness=100;s.dementia=100;picks(s,'manaleech',nil)
s.manaleech=100;picks(s,'slickness','anorexia')
s.paralysis=0;picks(s,'paralysis','slickness');s.paralysis=100
s.slickness=100;picks(s,'anorexia',nil)
s.anorexia=100;s.deaf=100;local out=M.select(s);eq(#out,0)
-- The editable core list actually determines selection order.
local original=M.Affliction_giving
M.Affliction_giving={'asthma','impatience','paralysis','anorexia','slickness','manaleech','disloyalty'}
picks({},'asthma','impatience');picks({paralysis=100,asthma=100,impatience=100,manaleech=100},'anorexia','slickness')
M.Affliction_giving=original
local mental=M.Padding_mental_afflictions;M.Padding_mental_afflictions={'dementia','confusion'}
picks({paralysis=100,asthma=100,impatience=100},'manaleech','dementia')
M.Padding_mental_afflictions=mental
eq(M.eye_command('Saibel',{'paralysis','impatience'},true),'deadeyes Saibel breach paralysis')
eq(M.eye_command('Saibel',{'slickness','anorexia'},false),'deadeyes Saibel sicken anorexia')
eq(M.eye_command('Saibel',{'stupidity','dizziness'},false),'deadeyes Saibel stupid dizzy')
eq(M.eye_command('Saibel',{'manaleech'},false),'stare Saibel manaleech')
eq(M.eye_command('Saibel',{},true),nil)
eq(M.eye_command('Saibel',{'undeaf','impatience'},false),'deadeyes Saibel sensitivity impatience')
eq(s.paralysis,100)
print('PASS lock selector: core/mental order, stage gates, 99/100 scores, Breach and keyword mapping')
