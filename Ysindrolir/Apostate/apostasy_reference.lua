-- Supplied in-game AB captures and user clarification, 2026-10-19.
-- Data only. No sends, triggers, timers, or changes to AK tracking.
Yso=Yso or {};Yso.ref=Yso.ref or {};Yso.ref.apostate=Yso.ref.apostate or {}
local R={meta={class='Apostate',skillset='Apostasy',updated='2026-10-19',
  source_directory='C:/Users/shuji/OneDrive/Pictures/Screenshots',
  coverage='20 abilities in the supplied Apostasy screenshots; not the entire skillset.',
  notes={'Missing AB fields remain unspecified, not zero.',
    'Standard demon summons require a drawn pentagram (user clarification).',
    'summon_requires applies to summoning, not to every command in that skill.',
    'Eliminate is a channeled instant kill; 3.50s is listed EQ recovery, not a confirmed channel duration.'}},skills={}}
Yso.ref.apostate.apostasy=R
local function skill(key,row)
  row.name=row.name or key:sub(1,1):upper()..key:sub(2)
  row.afflictions=row.afflictions or {}
  row.source='Screenshot 2026-10-19 '..row.source..'.png'
  row.details_captured=true
  R.skills[key]=row
end
skill('daegger',{abadmin_id=159,syntax={'SUMMON DAEGGER','STAB <target>'},works_on='adventurers',
  cooldown_lane='equilibrium',resource_mana=300,role='weapon',summon_requires={'drawn_pentagram'},
  affliction_rule='Venom-dependent chance on an envenomed stab; no fixed affliction.',
  notes={'Living weapon assists accuracy; strength, accuracy and to a lesser extent speed depend on Apostasy skill.',
    'The capture gives no numeric recovery and does not allocate the displayed 300 mana between commands.'},source='210141'})
skill('hunt',{abadmin_id=161,syntax={'DAEGGER LEVITATE','DAEGGER HUNT <target>'},works_on='adventurers',
  cooldown_lane='equilibrium',cooldown_s=4.00,role='weapon_attack',
  notes={'Guided flying attack retries after a miss; higher Apostasy gives more passes.',
    'Intelligence affects power; Weaponry affects chance to hit. No fixed affliction or resource cost is supplied.'},source='210146'})
skill('envenom',{abadmin_id=164,syntax={'ENVENOM DAEGGER WITH <venom>','WIPE <weapon>'},role='weapon_preparation',
  affliction_rule='Depends on the selected venom, not on Envenom itself.',
  notes={'Requires the selected venom in a vial in inventory.',
    'Venoms stack last-on, first-off; one venom is delivered and removed per weapon hit.',
    'WIPE removes venoms. No recovery or resource field is supplied.'},source='210159'})
skill('baalzadeen',{abadmin_id=166,syntax={'SUMMON BAALZADEEN','BANISH BAALZADEEN'},
  cooldown_lane='equilibrium',cooldown_s=2.00,resource_life_essence_pct=0.50,role='summon',
  summon_requires={'drawn_pentagram'},notes={'Primary daemon powering demon commands; no direct affliction.'},source='210254'})
skill('horror',{abadmin_id=174,syntax={'DEMON HORROR <target>'},works_on='adventurers',
  cooldown_lane='equilibrium',cooldown_s=2.00,resource_baalzadeen_health=125,role='fear_effect',
  notes={'Instils fear. No persistent fear score is invented in AK.'},source='210254'})
skill('fiend',{abadmin_id=176,syntax={'SUMMON FIEND','ORDER FIEND ATTACK <target>','ORDER FIEND PASSIVE'},
  works_on='adventurers',cooldown_lane='equilibrium',cooldown_s=4.00,resource_mana=150,
  role='summon',summon_requires={'drawn_pentagram'},effect='Serious bleeding damage; amount unspecified.',source='210307'})
skill('scorch',{abadmin_id=178,syntax={'DEMON SCORCH <icewall>'},cooldown_lane='equilibrium',
  cooldown_s=2.50,resource_baalzadeen_health=150,role='obstruction_removal',
  notes={'Melts icewalls and withers Reclamation vines.',
    'Vines take one cast if the reclaimer is outside the area, two if in the area but outside the room, three if in the room.'},source='210307'})
skill('fortify',{abadmin_id=188,syntax={'DEMON FORTIFY'},cooldown_lane='equilibrium',cooldown_s=2.00,
  role='daemon_healing',resource_rule='Costs some player health; amount not supplied.',
  effect='Replenishes Baalzadeen power.',source='210333'})
skill('apathy',{abadmin_id=190,syntax={'DEMON APATHY'},cooldown_lane='equilibrium',cooldown_s=3.00,
  resource_baalzadeen_health=250,role='defence',duration_s=10,
  notes={'Damage from attacks is deferred for ten seconds, not erased.',
    'At the end, accumulated damage is received in one blow with a 40% reduction.'},source='210333'})
skill('shadowstrike',{abadmin_id=192,syntax={'DAEGGER SHADOWSTRIKE <target>'},
  works_on='adventurers and denizens',cooldown_lane='equilibrium',cooldown_s=4.50,
  role='impalement',requires={'levitated_daegger'},
  effects_by_target={adventurers='Impalement-equivalent restraint with ongoing damage; writhe free of the daegger.',
    denizens='Cutting damage on impact.'},
  tracking_notes={'AK has affstrack.impale as a separate state; no numeric impalement score or new trigger is assumed.'},source='210410'})
skill('beckon',{abadmin_id=194,syntax={'DEMON BECKON [<target>]'},works_on='adventurers and room',
  cooldown_lane='equilibrium',cooldown_s=4.00,resource_baalzadeen_health=300,role='forced_movement',
  effect='Attempts to draw a specific person or everybody in surrounding rooms into your room.',source='210437'})
skill('daemonite',{abadmin_id=196,syntax={'SUMMON DAEMONITE','ORDER DAEMONITE ATTACK <target>','ORDER DAEMONITE PASSIVE'},
  works_on='adventurers',cooldown_lane='equilibrium',cooldown_s=4.00,resource_mana=150,
  role='summon',summon_requires={'drawn_pentagram'},effect='Repeatedly drives the target off balance; not a persistent affliction.',source='210437'})
skill('sear',{abadmin_id=200,syntax={'DEMON SEAR <target>','DEMON SEAR OFF','DEMON REST'},
  works_on='adventurers and denizens',cooldown_lane='equilibrium',cooldown_s=2.00,
  resource_baalzadeen_health=50,drains='Baalzadeen health on repeated adventurer ignitions',role='damage_and_affliction',
  afflictions={'aflame'},effects_by_target={adventurers='Repeatedly ignites the target (ablaze).',
    denizens='Fire damage; Baalzadeen does not lose health against denizens.'},
  tracking_notes={'AK Sear trigger calls ak.flameon("notadditive"); aflame is the existing score key.'},source='210506'})
skill('puncture',{abadmin_id=202,syntax={'DAEGGER PUNCTURE <target>'},works_on='adventurers',
  cooldown_lane='balance',cooldown_s=2.15,role='venom_delivery',bypasses={'rebounding'},
  affliction_rule='Delivers the venom on the daegger; affliction depends on venom.',
  notes={'Bypasses rebounding. The capture does not establish shield bypass or a resource cost.'},source='210537'})
skill('eliminate',{abadmin_id=204,syntax={'DAEGGER ELIMINATE <target>'},works_on='adventurers',
  cooldown_lane='equilibrium',cooldown_s=3.50,role='instant_kill',channeled=true,instant_kill=true,
  interrupted_by={'knocked_over','paralysed','webbed'},
  notes={'User confirms a channeled instant kill, not an affliction.',
    'Closing in can be stopped by knocking the attacker over, paralysis, or webbing.',
    'A successful completion penetrates target defences; channel duration is not supplied.',
    'No automatic activation or channel lifecycle triggers are added.'},source='210537'})
skill('nightmare',{abadmin_id=212,syntax={'SUMMON NIGHTMARE'},works_on='adventurers',
  cooldown_lane='equilibrium',cooldown_s=4.00,resource_mana=150,role='summon',
  summon_requires={'drawn_pentagram'},afflictions={'hypersomnia','dementia','hellsight'},
  outcomes={'hypersomnia','dementia','hellsight'},
  notes={'Applies hypersomnia first; if present, dementia, then hellsight.',
    'Cannot exist in sunlight, even with a pentagram.'},source='210557'})
skill('bloodworms',{abadmin_id=206,syntax={'SUMMON BLOODWORMS'},works_on='room',
  cooldown_lane='equilibrium',cooldown_s=4.00,resource_mana=500,role='summon',
  summon_requires={'drawn_pentagram'},afflictions={'masochism','dizziness'},
  outcomes={'masochism','dizziness','damage'},blocked_by={'deaf'},
  notes={'After a moment, spread into surrounding rooms.',
    'Non-deaf victims receive masochism first, then dizziness; both present causes mental and physical damage.'},source='210610'})
skill('stain',{abadmin_id=216,syntax={'DEMON STAIN <target>'},works_on='adventurers',
  cooldown_lane='equilibrium',cooldown_s=3.00,resource_baalzadeen_health=300,role='attribute_debuff',
  notes={'Temporarily lowers various attributes. Specific attributes, magnitude, duration and AK key are not supplied.',
    'AB states there is no known cure besides death. No named affliction or score is invented.'},source='210631'})
skill('bloodpact',{abadmin_id=319,syntax={'DEMON BLOODPACT <target> FOR <NIGHTMARE|FIEND|DAEMONITE>'},
  works_on='adventurers',role='summon_setup',requires={'fresh_target_blood_on_daegger'},
  creates={'drawn_pentagram','selected_demon'},choices={'nightmare','fiend','daemonite'},
  notes={'Immediately brings a pentagram and selected demon into being.',
    'Fresh blood lasts a short unspecified time after Hunt or Puncture strikes the target.',
    'Does not itself apply the selected demon afflictions; no prior drawn pentagram is assumed for this setup command.'},source='210631'})
skill('corrupt',{abadmin_id=224,syntax={'DEMON CORRUPT <target> [affliction]'},works_on='adventurers',
  cooldown_lane='equilibrium',cooldown_s=3.00,resource_baalzadeen_health=200,role='curse_conversion',
  notes={'Lifts curses applied through Evileye at a terrible price.',
    'User confirmed 2026-10-25: the specified affliction remains; other Evileye-applied curses are lifted.',
    'Do not invent a new corruption affliction or remove tracked afflictions on command send.'},source='210646'})
-- Recovery/resource data verified against the game-hosted Apostasy reference.
skill('sap',{syntax={'DEMON SAP <target>'},works_on='adventurers',
  cooldown_lane='equilibrium',cooldown_s=2.75,resource_baalzadeen_health=50,
  role='mana_drain',source='game-wiki'})
R.skills.sap.source='https://wiki.achaea.com/Apostasy'
skill('catharsis',{abadmin_id=226,syntax={'DEMON CATHARSIS <target>'},works_on='adventurers',
  cooldown_lane='equilibrium',cooldown_s=4.40,resource_baalzadeen_health=1000,
  role='instant_kill',requires={'target_mana_strictly_below_half'},source='user-capture-2026-10-25'})
return R
