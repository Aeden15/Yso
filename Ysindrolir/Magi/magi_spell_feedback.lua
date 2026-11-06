-- Confirmed Magi response adapter. Native triggers supply event + named victim.
-- AK owns scores/cures. This module never sends commands or estimates enemy HP.
Yso = Yso or {}
Yso.magi = Yso.magi or {}
local T = Yso.magi.spell_feedback or {}
Yso.magi.spell_feedback = T
T.hypothermia_tracking = true
T.observed, T.expiries = T.observed or {}, T.expiries or {}
local function core() return Yso.off and Yso.off.magi and Yso.off.magi.route_core end
local function now() return core() and core().now() or os.time() end
local function current() return core() and core().get_target() or tostring(rawget(_G,'target') or '') end
local function same(a,b) return tostring(a or ''):lower()==tostring(b or ''):lower() end
local function tracking_ready()
  if type(ak)~='table' or type(affstrack)~='table' or type(affstrack.score)~='table' then return false end
  if type(ak.ai)=='function' then
    local ok, blocked=pcall(ak.ai)
    if not ok or blocked then return false end
  end
  return type(OppGainedAff)=='function'
end
local function allowed(who)
  return tracking_ready() and who and who~='' and same(who,current()) and
    (not core() or core().target_valid(who)) and type(OppGainedAff)=='function'
end
local function score(aff) return tonumber(affstrack.score[aff]) or 0 end
local function gain(aff) OppGainedAff(aff) end
local function flame(kind)
  if type(ak.flameon)=='function' then ak.flameon(kind or 'additive') end
end
local function confirm_min(aff,value)
  affstrack.score[aff]=math.max(score(aff),value)
  if ak.scoreup then ak.scoreup(current()) end
end
local function timed(aff,who,seconds)
  local scores=affstrack.score
  -- AK's generic blisters gain installs a target-global string timer. Keep the
  -- confirmed score, but use the target-safe callback below for this event.
  if aff=='blisters' then confirm_min(aff,100) else gain(aff) end
  local token={}
  T.expiries[aff]=token
  if type(tempTimer)=='function' then tempTimer(seconds,function()
    if T.expiries[aff]~=token then return end
    T.expiries[aff]=nil
    if allowed(who) and affstrack.score==scores and type(OppLostAff)=='function' then OppLostAff(aff) end
  end) end
end
local simple = {
  transfix='transfixed', bombard='clumsiness', mudslide='prone slickness',
  asthma='asthma', sensitivity='sensitivity', healthleech='healthleech',
  frostbite='frostbite', stuttering='stuttering', anorexia='nausea anorexia',
  paralysis='paralysis', hypothermia='hypothermia', freeze='frozen',
  dehydrate_dry='nausea weariness', dehydrate_freeze='frozen nausea weariness',
  lightning_stupidity='stupidity', plague='leftleg rightleg prone',
}
function T.handle(event,who,detail)
  -- Every named cast starts a new erosion sequence, including casts aimed at
  -- another victim. Such a start must invalidate our previous attribution.
  if event=='erode_start' then T.erode=nil end
  if (event=='conflagrate' or event=='conflagrate_tick') and tracking_ready()
      and ak.limbs and type(ak.limbs.ParseonLine)=='function' then
    ak.limbs.ParseonLine()
  end
  -- These first-person cast responses consume our resonance even if the user
  -- changed target before the named victim's confirmation arrived.
  local plane=event:match('^emanation_(%a+)$')
  if plane and tracking_ready() and ak.magi and ak.magi.resonance then
    ak.magi.resonance[plane:sub(1,1):upper()..plane:sub(2)]=0
  end
  -- Erosion's second line has a defence, not a victim. Attribute it only to a
  -- recent named first line; arbitrary follow-up text never drops a shield.
  if event=='erode_result' then
    local pending=T.erode
    T.erode=nil
    if not pending or now()-pending.at>2.5 or not same(pending.target,current()) then return false end
    who=pending.target
  end
  -- The unnamed room result establishes no particular enemy's cold stage.
  if event=='deepfreeze' then T.last_room_event={event=event,at=now()}; return true end
  if not allowed(who) then return false end
  T.last_event={event=event,target=who,at=now()}
  if simple[event] then
    if (event=='mudslide' or event=='plague') and type(EchoForMajorAff)=='function' then
      EchoForMajorAff('PRONE')
    end
    gain(simple[event]); return true
  end
  if event=='dehydrate_attempt' or event=='conflagrate_fail' then
    return true -- An attempt/failure is not evidence of an applied affliction.
  elseif event=='dehydrate_burning' then
    gain('weariness'); flame()
  elseif event=='fulminate' then
    gain(score('fulminated')<100 and 'fulminated' or score('epilepsy')<100 and 'epilepsy' or 'paralysis')
  elseif event=='magma' then
    timed('scalded',who,20)
  elseif event=='fire_moderate' then
    if score('scalded')<100 then timed('scalded',who,20) else flame() end
  elseif event=='blisters' then
    if score('blisters')>=100 then flame() else timed('blisters',who,20) end
  elseif event=='fire_major_burning' or event=='firelash' or event=='scintilla_burning' then
    flame()
  elseif event=='limb_break' then
    local limb=tostring(detail or ''):lower():gsub('%s+','')
    if limb=='leftarm' or limb=='rightarm' or limb=='leftleg' or limb=='rightleg' then gain(limb) else return false end
  elseif event:match('^emanation_') then
    if plane=='air' then gain('paralysis dizziness')
    elseif plane=='water' then gain('frozen disrupt') -- Stuttering belongs to Water's separate icicle proc.
    elseif plane=='fire' then flame('emanation')
    elseif plane=='earth' then
      -- AK lacks a torso calcification cure model. Keep named evidence, never
      -- fabricate calcifiedhead or an uncureable calcifiedtorso score.
      T.observed[who:lower()]=T.observed[who:lower()] or {}
      T.observed[who:lower()].calcifiedtorso_at=now()
    end
  elseif event=='conflagrate' or event=='conflagrate_tick' then
    -- Two burn levels are required to APPLY it. An ongoing tick proves only
    -- one remains; the victim may have cured a level since the initial cast.
    confirm_min('aflame',event=='conflagrate' and 200 or 100); gain('conflagrate')
  elseif event=='immolation' then
    T.observed[who:lower()]=T.observed[who:lower()] or {}
    T.observed[who:lower()].scintilla_until=now()+4
  elseif event=='unblind' then
    if type(OppLostAff)=='function' then OppLostAff('blind') end
  elseif event=='erode_start' then
    T.erode={target=who,at=now()}
  elseif event=='erode_result' then
    local defence=tostring(detail or ''):lower()
    if not defence:match('^%a+$') then return false end
    ak.defs=ak.defs or {}
    ak.defs[defence]=false
    if defence=='shield' then
      if ak.defs.shield_by_target then ak.defs.shield_by_target[who:lower()]=false end
      if Yso.shield and Yso.shield.set then Yso.shield.set(who,false,'line:erode') end
    end
  elseif event=='dissonance_escalation' then
    local D=Yso.magi.dissonance
    if D and D.note and D.snapshot then
      local stage=math.min(4,math.max(2,(D.snapshot(who).stage or 0)+1))
      D.note(who,'tracked',{stage=stage,confidence='high',evidence='named_dissonance_hum'})
    end -- Existing vibration notice alone increments Convergence's tick count.
  else return false end
  return true
end
return T
