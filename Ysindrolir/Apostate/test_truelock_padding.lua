-- Pure planning checks; score 50 is a route threshold, never an AK score write.
local root=arg[1] or 'Ysindrolir'
Yso={};local M=dofile(root..'/Apostate/truelock.lua')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
assert(type(M.pressure_plan)=='function','missing staged pressure planner')
local original_random=math.random
math.random=function() return 1 end
local function plan(scores) return M.pressure_plan(scores,{}) end
local s={}
local p=plan(s);eq(p[1],'impatience');eq(p[2],'dizziness');eq(s.impatience,nil)
s={impatience=50,dizziness=50,epilepsy=49}
p=plan(s);eq(p[1],'epilepsy');eq(p[2],nil)
s.epilepsy=50;p=plan(s);eq(p[1],'asthma');eq(p[2],'clumsiness')
s.asthma=50;s.clumsiness=50;s.sensitivity=49
p=plan(s);eq(p[1],'sensitivity');eq(p[2],nil)
s.sensitivity=50;p=plan(s);eq(p[1],'manaleech');eq(p[2],'stupidity')
s.manaleech=50;p=plan(s);eq(p[1],'manaleech') -- Sicken needs confirmed manaleech.
s.manaleech=100;p=plan(s);eq(p[1],'slickness');eq(p[2],'anorexia')
s.slickness=100;s.anorexia=100;p=plan(s);eq(p[1],'paralysis')
s.impatience=49;p=plan(s);eq(p[1],'impatience') -- Repair earlier gates.
s.impatience=50;s.epilepsy=49;p=plan(s);eq(p[1],'epilepsy')
s.epilepsy=0;s.shyness=50;p=plan(s);eq(p[1],'paralysis') -- Venom padding counts.
s.dizziness=0;s.shyness=0
math.random=function(n) return n end
p=plan(s);eq(p[1],'stupidity');eq(p[2],'shyness')
s={impatience=100,dizziness=100,epilepsy=100,shyness=100,stupidity=100,
 asthma=100,clumsiness=100,sensitivity=100,weariness=100}
p=plan(s);eq(p[1],'manaleech');eq(p[2],nil) -- Never re-give a confirmed companion.
s.manaleech=100;s.slickness=100;s.anorexia=100;s.paralysis=100
eq(#plan(s),0)
s.paralysis=0
p=M.pressure_plan(s,{'haemophilia','paralysis'});eq(p[1],'haemophilia');eq(p[2],nil)
-- Random candidates are distinct and existing >=50 padding is retained.
math.random=original_random
local found={}
for i=1,150 do
 local picks=plan({impatience=100})
 assert(picks[1]~=picks[2]);found[picks[1]]=true;found[picks[2]]=true
end
for _,aff in ipairs({'dizziness','epilepsy','shyness','stupidity'}) do assert(found[aff],aff) end
print('PASS staged padding, 49/50 thresholds, random pools, manaleech, Sicken, paralysis last')
