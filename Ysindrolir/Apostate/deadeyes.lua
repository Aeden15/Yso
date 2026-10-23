-- Pure preparation helpers. No alias, send, timer, or route registration.
Yso=Yso or {};Yso.apostate=Yso.apostate or {}
local D=Yso.apostate.deadeyes or {};Yso.apostate.deadeyes=D
D.priorities=D.priorities or {}
local function catalog() return Yso.ref and Yso.ref.apostate and Yso.ref.apostate.evileye end
local function present(value) return value==true or (tonumber(value) or 0)>=100 end
function D.build(target,first,second)
  local R=catalog()
  if type(target)~='string' or not target:match("^[A-Za-z][A-Za-z'%-]*$") then return nil,'invalid_target' end
  for _,key in ipairs({first or '',second or ''}) do
    if type(key)~='string' or not R or not R.skills[key] or not R.skills[key].deadeyes_candidate then
      return nil,'invalid_evileye'
    end
  end
  return 'deadeyes '..target..' '..first..' '..second
end
function D.select(priorities,afflictions)
  local R=catalog();if not R then return nil,nil,'reference_unavailable' end
  local snapshot={};for k,v in pairs(afflictions or {}) do snapshot[k]=v end
  local selected,seen={},{}
  for _,entry in ipairs(priorities or D.priorities) do
    local key=type(entry)=='table' and entry.keyword or entry
    local skill=R.skills[key]
    if skill and skill.deadeyes_candidate and not seen[key] then
      seen[key]=true
      local aff=type(entry)=='table' and entry.affliction or skill.affliction
      if key=='sicken' then
        aff=not present(snapshot.manaleech) and 'manaleech'
          or (not present(snapshot.slickness) and 'slickness' or nil)
      end
      local eligible=type(entry)~='table' or not entry.eligible or entry.eligible(snapshot,skill)
      -- General pressure selection uses tracked afflictions, not defence breaks or unspecified damage.
      if eligible and aff and not present(snapshot[aff]) then
        selected[#selected+1]=key;snapshot[aff]=100
        if #selected==2 then return selected[1],selected[2] end
      end
    end
  end
  return nil,nil,'insufficient_candidates'
end
return D
