-- In-game AB screenshots supplied 2026-10-19 take precedence over web descriptions.
-- Reference data only: loading this file sends nothing and installs no handlers.
Yso = Yso or {}; Yso.ref = Yso.ref or {}; Yso.ref.apostate = Yso.ref.apostate or {}
local R = {meta={class='Apostate', skillset='Evileye', updated='2026-10-19',
  source_directory='C:/Users/shuji/OneDrive/Pictures/Screenshots',
  notes={'34 detailed AB entries; Truestare is index-confirmed only.',
    'Cooldowns are the listed AB values, not a readiness timer.',
    'Command keywords and AK score keys are deliberately separate.'}}, skills={}}
Yso.ref.apostate.evileye = R
local function eye(key, id, mana, aff, effect, stamp, works_on)
  R.skills[key] = {name=key:sub(1,1):upper()..key:sub(2), abadmin_id=id,
    syntax={'STARE <target> '..key:upper()}, works_on=works_on or 'adventurers',
    cooldown_s=1.90, cooldown_lane='balance', resource_mana=mana,
    affliction=aff, effect=effect, role=aff and 'affliction' or 'special',
    source='Screenshot 2026-10-19 '..stamp..'.png', details_captured=true,
    deadeyes_candidate=true}
end
eye('fear',80,33,nil,'Instils fear; do not invent a persistent fear score.','192715')
eye('deaf',81,33,'deaf','Removes hearing.','192715')
eye('impatience',82,45,'impatience','Prevents concentration on focused tasks.','192737')
eye('clumsy',83,50,'clumsiness','Causes fumbling.','192737')
eye('vertigo',84,50,'vertigo','Fear of heights.','192748')
eye('bleed',85,30,nil,'Induces bleeding; amount not specified.','192748','adventurers and denizens')
eye('amnesia',86,50,'amnesia','Makes the victim forget their intended action.','192757')
eye('agoraphobia',87,50,'agoraphobia','Fear of open spaces.','192757')
eye('breach',88,125,nil,'Removes Curseward; not a gained affliction.','192811')
R.skills.breach.role='defence_break'
eye('dizzy',89,50,'dizziness','Severe dizziness.','193026')
eye('paralysis',2940,70,'paralysis','Prevents most actions while it lasts.','193026','not captured')
eye('claustrophobia',90,50,'claustrophobia','Fear of enclosed spaces.','193038')
eye('paranoia',91,50,'paranoia','Fear of other people.','193038')
eye('blind',92,33,'blind','Removes eyesight.','193055')
eye('masochism',93,50,'masochism','Victim loves pain and inflicts it upon themselves.','193055')
eye('asthma',94,50,'asthma','Difficulty breathing.','193105')
eye('reckless',96,50,'recklessness','Disregard for personal wellbeing.','193105')
eye('epilepsy',97,75,'epilepsy','Causes seizures.','193115')
eye('confusion',98,33,'confusion','Befuddles the mind.','193115')
eye('peace',99,62,'pacifism','Fills the mind with peaceful thoughts.','193129')
eye('dementia',100,50,'dementia','Distorts perceptions of the world.','193129')
R.skills.sight={name='Sight',abadmin_id=101,syntax={'SIGHT'},works_on='self',
  cooldown_s=1.90,cooldown_lane='balance',resource_willpower=25,role='utility',
  effect='Clears blindness after a brief period of concentration.',
  source='Screenshot 2026-10-19 193147.png',details_captured=true,deadeyes_candidate=false}
eye('sicken',102,55,nil,'Manaleech, then slickness, then damage when both are present.','193147')
R.skills.sicken.role='conditional'; R.skills.sicken.outcomes={'manaleech','slickness','damage'}
eye('plague',103,75,'voyria','Afflicts with voyria.','193201')
eye('addiction',104,70,'addiction','Causes addiction.','193201')
eye('cowardice',105,150,nil,'Moves the victim in a random direction; does not cancel tumble from hindered opponents.',
  '193216','adventurers and denizens')
eye('stupid',106,60,'stupidity','Causes stupidity.','193216')
eye('manaleech',107,75,'manaleech','Saps the target mana.','193232')
eye('sensitivity',108,70,'sensitivity','First removes deafness; a subsequent hit while hearing increases sensitivity to pain. Same conditional effect as prefarar from any source.','193232')
R.skills.sensitivity.role='conditional'
R.skills.sensitivity.outcomes={'deafness_removed','sensitivity'}
eye('vomiting',109,75,'nausea','Induces severe vomiting.','193247')
eye('sleep',110,55,'sleep','Puts the target to sleep or removes sleep defences; announcement alone does not distinguish outcomes.','193247')
eye('anorexia',111,70,'anorexia','Prevents eating.','193256')
eye('weariness',112,75,'weariness','Weakens the body.','193256')
R.skills.deadeyes={name='Deadeyes',abadmin_id=95,
  syntax={'DEADEYES <target> <first evileye> <second evileye>'},
  works_on='adventurers and denizens',cooldown_s=2.30,cooldown_lane='balance',
  resource_rule='Sum of both selected evileye mana costs.',role='combo',
  effect='Two simultaneous evileyes; becomes faster as Evileye skill increases.',
  source='Screenshot 2026-10-19 192811.png',details_captured=true,deadeyes_candidate=false}
R.skills.truestare={name='Truestare',role='utility',details_captured=false,deadeyes_candidate=false,
  effect='Index description: cast the evileye through magical shields.',
  source='Earlier Evileye index screenshot; detailed AB not supplied.'}
R.curseward={ak_key='ak.defs.curseward', separate_from='magical shield',
  up_message='A shimmering curseward appears around <target>.',
  down_message="<target>'s curseward shatters!",
  absent_message="Your attempt to breach <target>'s curseward has no effect.",
  source='Screenshot 2026-10-19 193004.png',
  notes={'Breach is defence removal, never a scored affliction.',
    'AK treats the captured no-effect response as Curseward absent.',
    'Live test 2026-10-20: Deadeyes breach impatience shattered Curseward before impatience landed; Breach must be first.'}}
return R
