local here = debug.getinfo(1, 'S').source:sub(2):match('^(.*[/\\])')
local root = here .. '../../'
Yso={}; yso=Yso; cecho=function() end
tempRegexTrigger=function() return 1 end
killTrigger=function() end
dofile(root..'Yso/xml/api_stuff.lua')
local L=Yso.locks
assert(type(L)=='table','shared lock helper missing')
local rows={
  {v={},want=false}, {v={bal='0'},want=false}, {v={balance=false},want=false},
  {v={bal='1'},want=true}, {v={balance=true},want=true},
  {v={bal=false,balance=true},want=false},
}
local failures={}
for i,row in ipairs(rows) do
  gmcp={Char={Vitals=row.v}}
  if L.bal_ready()~=row.want then failures[#failures+1]='GMCP balance row '..i end
end
gmcp=nil
if L.bal_ready()~=false then failures[#failures+1]='missing GMCP must fail closed' end
Yso.state={bal_ready=function() return false end}
gmcp={Char={Vitals={bal='1'}}}
if L.bal_ready()~=false then failures[#failures+1]='state helper false must remain authoritative' end
Yso.state.bal_ready=function() error('state unavailable') end
if L.bal_ready()~=true then failures[#failures+1]='broken helper must fall back to GMCP' end
for _,why in ipairs(failures) do io.stderr:write('FAIL: '..why..'\n') end
assert(#failures==0,tostring(#failures)..' balance readiness cases failed')
print('PASS: GMCP balance readiness fallback')
