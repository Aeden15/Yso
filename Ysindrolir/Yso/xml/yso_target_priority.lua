-- Shared room-aware target priorities for manual aliases and Stormhammer.
tprio = tprio or {}
local P = tprio
P.list = P.list or {}
P.current = P.current or 0
local function name(raw)
  local s = tostring(raw or ''):match('^%s*(.-)%s*$')
  if not s:match('^[A-Za-z]+$') then return nil end
  return s:sub(1,1):upper() .. s:sub(2):lower()
end
local function index(who)
  for i,v in ipairs(P.list) do if v == who then return i end end
end
local function note(s) if type(cecho)=='function' then cecho('<yellow>[Priority] <reset>' .. s .. '\n') end end
function P.add(raw)
  local n = name(raw)
  if n and not index(n) then P.list[#P.list+1] = n end
end
function P.reset() P.list = {}; P.current = 0 end
function P.string() return 'Priority Targets: ' .. table.concat(P.list, ', ') .. '.' end
function P.print() note(P.string()) end
function P.addGroup(list)
  if type(list)=='string' then
    for n in list:gmatch('[^,%s]+') do if n:lower()~='and' then P.add(n) end end
  elseif type(list)=='table' then for _,n in ipairs(list) do P.add(n) end
  else return false end
  P.print(); return true
end
function P.remove(raw)
  local i = index(name(raw))
  if i then table.remove(P.list, i) end
  P.current = math.min(P.current, #P.list)
  P.print()
end
function P.pt()
  if #P.list==0 then note('No priority targets to announce.'); return false end
  send('pt ' .. P.string()); return true
end
function P.select(raw, quiet)
  local n = name(raw)
  if not n then return false end
  if not Yso or type(Yso.set_target)~='function' then
    if not quiet then note('Yso targeting is unavailable.') end
    return false
  end
  local ok, why = Yso.set_target(n, 'manual')
  if ok~=true then
    if not quiet then note('Target unchanged: ' .. tostring(why or 'targeting rejected selection')) end
    return false
  end
  P.current = index(n) or 0
  return true
end
local function navigate(step)
  if #P.list==0 then note('No priority targets.'); return false end
  local current = P.current
  if current~=0 then current = index(name(target)) or current end
  local i = math.max(1, math.min(#P.list, current+step))
  return P.select(P.list[i])
end
function P.next() return navigate(1) end
function P.previous() return navigate(-1) end
function tprio_pt(_, raw) return P.select(raw) end
function tprio_auto_target()
  local players = thammer and thammer.players or {}
  if players[name(target)] then return end
  for _,n in ipairs(P.list) do if players[n] then return P.select(n, true) end end
end
P.name = name
if type(registerAnonymousEventHandler)=='function' then
  if P.handler and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(P.handler) end
  P.handler = registerAnonymousEventHandler('tprio', tprio_pt)
end
return P
