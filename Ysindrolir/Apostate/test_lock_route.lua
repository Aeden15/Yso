local root=arg[1] or 'Ysindrolir'
Yso={};local M=dofile(root..'/Apostate/lock_route.lua')
assert(type(M)=='table' and type(M.select)=='function','missing simplified selector')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function picks(scores,a,b)
 local snapshot={deaf=100};for k,v in pairs(scores) do snapshot[k]=v end
 local out=M.select(snapshot);eq(out[1],a);eq(out[2],b);eq(out[3],nil);return out
end
picks({deaf=0},'paralysis','undeaf')
picks({paralysis=100,deaf=0},'undeaf','impatience')
picks({paralysis=100,deaf=99},'undeaf','impatience')
picks({},'paralysis','impatience')
picks({paralysis=100},'impatience','asthma')
picks({paralysis=99,impatience=100},'paralysis','asthma')
picks({asthma=100,impatience=100},'paralysis','manaleech')
-- Asthma gets missing kelp padding; Impatience retains Masochism first.
picks({paralysis=100,impatience=100},'asthma','clumsiness')
picks({paralysis=100,asthma=100},'impatience','masochism')
picks({paralysis=100,impatience=100,masochism=99},'asthma','clumsiness')
picks({paralysis=100,asthma=100,masochism=99},'impatience','masochism')
picks({paralysis=100,asthma=100,masochism=100},'impatience','stupidity')
picks({paralysis=100,asthma=100,masochism=100,stupidity=100},'impatience','confusion')
local asthma={paralysis=100,impatience=100}
picks(asthma,'asthma','clumsiness')
asthma.clumsiness=99;picks(asthma,'asthma','clumsiness')
asthma.clumsiness=100;picks(asthma,'asthma','weariness')
asthma.weariness=true;picks(asthma,'asthma','sensitivity')
asthma.sensitivity='100';picks(asthma,'asthma','masochism')
asthma.masochism=100
picks(asthma,'asthma','stupidity')
asthma.stupidity=99;picks(asthma,'asthma','stupidity')
asthma.stupidity=100;picks(asthma,'asthma','confusion')
asthma.confusion=true;picks(asthma,'asthma','dizziness')
asthma.dizziness='100';picks(asthma,'asthma','dementia')
asthma.dementia=100;picks(asthma,'asthma',nil)
picks({paralysis=100,asthma=100,masochism=100,stupidity=100,confusion=100,dizziness=100,dementia=100},'impatience',nil)
picks({paralysis=100,impatience=100,deaf=0},'undeaf','asthma')
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
local kelp=M.Padding_kelp_afflictions
M.Padding_kelp_afflictions={'sensitivity','clumsiness'}
picks({paralysis=100,impatience=100},'asthma','sensitivity')
picks({paralysis=100,impatience=100,sensitivity=100},'asthma','clumsiness')
M.Padding_kelp_afflictions={}
picks({paralysis=100,impatience=100},'asthma','masochism')
M.Affliction_giving={'paralysis','undeaf','impatience','asthma','manaleech','slickness','anorexia'}
picks({paralysis=100,impatience=100},'asthma','stupidity')
M.Affliction_giving=original
local mental=M.Padding_mental_afflictions;M.Padding_mental_afflictions={'dementia','confusion'}
picks({paralysis=100,asthma=100,impatience=100},'manaleech','dementia')
M.Padding_mental_afflictions=mental
eq(M.eye_command('Saibel',{'asthma','clumsiness'},false),'deadeyes Saibel asthma clumsy')
M.Padding_mental_afflictions={'dementia','confusion'}
picks({paralysis=100,impatience=100,masochism=100},'asthma','dementia')
picks({paralysis=100,impatience=100,masochism=100,dementia=100},'asthma','confusion')
M.Padding_mental_afflictions={}
picks({paralysis=100,impatience=100,masochism=100},'asthma',nil)
picks({paralysis=100,asthma=100,masochism=100},'impatience',nil)
M.Padding_mental_afflictions=mental
M.Padding_kelp_afflictions=kelp
eq(M.eye_command('Saibel',{'paralysis','impatience'},true),'deadeyes Saibel breach paralysis')
eq(M.eye_command('Saibel',{'slickness','anorexia'},false),'deadeyes Saibel sicken anorexia')
eq(M.eye_command('Saibel',{'stupidity','dizziness'},false),'deadeyes Saibel stupid dizzy')
eq(M.eye_command('Saibel',{'manaleech'},false),'stare Saibel manaleech')
eq(M.eye_command('Saibel',{},true),nil)
eq(M.eye_command('Saibel',{'undeaf','impatience'},false),'deadeyes Saibel sensitivity impatience')
eq(s.paralysis,100)
print('PASS lock selector: core/kelp/mental order, stage gates, 99/100 scores, Breach and keyword mapping')
