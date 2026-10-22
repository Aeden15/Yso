-- Balanceless preparation, called only immediately before a venom-delivering attack.
Yso=Yso or {};Yso.apostate=Yso.apostate or {}
local D=Yso.apostate.daegger or {};Yso.apostate.daegger=D
D.stock=D.stock or {curare=true,kalmia=true,slike=true,gecko=true,vernalius=true,
 aconite=true,eurypteria=true,voyria=true,selarnia=true,notechis=false,delphinium=true,
 xentio=true,prefarar=true,epseth=true}
local standard={xentio=true,eurypteria=true,kalmia=true,delphinium=true,digitalis=true,
 darkshade=true,curare=true,epteth=true,prefarar=true,monkshood=true,euphorbia=true,
 colocasia=true,vernalius=true,epseth=true,larkspur=true,slike=true,notechis=true,
 vardrax=true,aconite=true,selarnia=true,gecko=true,scytherus=true,voyria=true}
local preferred={paralysis='curare',asthma='kalmia',slickness='gecko',anorexia='slike',
 weariness='vernalius',stupidity='aconite',recklessness='eurypteria',voyria='voyria',
 haemophilia='notechis',selarnia='selarnia'}
function D.venom_for(aff)
 local v=preferred[aff]
 local map=affstrack and affstrack.venoms or {}
 if v and map[v]==aff then return v end
 local keys={};for venom,outcome in pairs(map) do
  if standard[venom] and outcome==aff then keys[#keys+1]=venom end
 end
 table.sort(keys);return keys[1]
end
function D.available(venom)
 local n=D.stock[venom];return n==true or (tonumber(n) or 0)>0
end
function D.select_venom(profile,snapshot)
 for _,aff in ipairs(profile or {}) do
  local value=(snapshot or {})[aff]
  if value~=true and (tonumber(value) or 0)<100 then
   local v=D.venom_for(aff)
   if v and D.available(v) then return v,aff end
  end
 end
 return nil,'no_available_venom'
end
function D.build_attack(action,victim,venom)
 local verb=({puncture='daegger puncture',stab='stab'})[action]
 if not verb or type(victim)~='string' or not victim:match("^[A-Za-z][A-Za-z'%-]*$")
  or not standard[venom] or not (affstrack and affstrack.venoms and affstrack.venoms[venom]) then
  return nil,'invalid_attack'
 end
 return {'wipe daegger','envenom daegger with '..venom,verb..' '..victim}
end
function D.note_application(venom,weapon)
 if type(weapon)~='string' or not weapon:lower():find('daegger',1,true) then return end
 if type(D.stock[venom])=='number' then D.stock[venom]=math.max(0,D.stock[venom]-1) end
end
function D.emit_attack(action,victim,profile,snapshot)
 local venom,aff=D.select_venom(profile,snapshot)
 if not venom then return false,aff end
 local cmds,why=D.build_attack(action,victim,venom);if not cmds then return false,why end
 if not Yso.emit then return false,'emitter_unavailable' end
 local A=ak and ak.apostate
 if A then A.pending_daegger_wipe=true end
 -- Keep preparation and attack in one ordered BAL batch. A separate "free"
 -- lane may be server-queued behind EQ in compatible queue-enabled profiles.
 local sep=Yso.sep or (Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep)) or '&&'
 local ok=Yso.emit({target=victim,bal=table.concat(cmds,sep)},
  {kind='offense',route='apostate_truelock',target=victim,reason='apostate_truelock',commit=true})==true
 if not ok and A then A.pending_daegger_wipe=nil end
 return ok,aff
end
return D
