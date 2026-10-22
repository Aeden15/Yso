-- Supplied in-game Necromancy AB captures, 2026-10-19. Data only.
Yso=Yso or {};Yso.ref=Yso.ref or {};Yso.ref.apostate=Yso.ref.apostate or {}
local R={meta={class='Apostate',skillset='Necromancy',updated='2026-10-19',
  source_directory='C:/Users/shuji/OneDrive/Pictures/Screenshots',
  coverage='14 detailed AB entries and one partially captured Essence entry; not the entire skillset.',
  notes={'Missing fields remain unspecified, not zero.',
    'Recovery times are listed AB values, not runtime readiness or channel duration.',
    'Multi-command entries retain the AB-level recovery/resource fields without inventing per-command costs.',
    'This reference sends nothing, registers no handlers, and changes no AK tracking.'}},skills={}}
Yso.ref.apostate.necromancy=R
local function skill(key,row)
  row.name=row.name or key:sub(1,1):upper()..key:sub(2)
  row.afflictions=row.afflictions or {}
  row.source='Screenshot 2026-10-19 '..row.source..'.png'
  row.details_captured=row.details_captured~=false
  R.skills[key]=row
end
skill('chill',{abadmin_id=115,syntax={'CHILL <target>','CHILL <direction>'},works_on='adventurers',
  cooldown_lane='equilibrium',cooldown_s=2.20,resource_mana=100,role='conditional_affliction',
  afflictions={'shivering','frozen'},outcomes={'caloric_removed','shivering','frozen'},
  effects_by_argument={target='Removes caloric if present; otherwise causes shivering, or freezes an already shivering target.',
    direction='Destroys a firewall blocking the selected exit.'},
  notes={'Shivering regularly causes loss of equilibrium. Caloric removal is a defence change, not an affliction.',
    'AK has a frozen score; no separate shivering score or numeric stage mapping is inferred from this AB.'},source='211530'})
skill('decay',{abadmin_id=117,syntax={'DECAY <target>'},works_on='adventurers and denizens',
  cooldown_lane='equilibrium',cooldown_s=4.00,resource_mana=80,role='damage',
  effect='Magical damage; no fixed affliction is specified.',source='211530'})
skill('screech',{abadmin_id=120,syntax={'SCREECH'},works_on='room',
  cooldown_lane='equilibrium',cooldown_s=4.00,resource_mana=70,role='forced_movement',
  effect='Drives those who can hear out of the location; no persistent affliction is specified.',source='211549'})
skill('shrivel',{abadmin_id=129,syntax={'SHRIVEL <arms/legs> <target>','SHRIVEL <left/right> <arm/leg> <target>'},
  works_on='adventurers',cooldown_lane='equilibrium',cooldown_s=2.10,resource_mana=300,role='limb_affliction',
  afflictions={'leftarm','rightarm','leftleg','rightleg'},
  effect='Destroys the marrow of an affected limb, rendering it useless.',
  notes={'The four keys are possible affected limbs, not a claim that one cast affects all four.',
    'Existing tracking confirms only identified sides; unsided responses remain unresolved observations.',
    'See Necromancy Shrivel reference.md for captured responses and AK integration.'},source='211549'})
skill('essence',{syntax={'ESSENCE'},role='resource_report',details_captured=false,
  effect='Reports the amount of life essence possessed.',
  notes={'Only syntax and the reporting description are visible. AB ID, target type, recovery, and costs are not captured.'},source='211644'})
skill('sapience',{abadmin_id=132,syntax={'SAPIENCE'},cooldown_lane='equilibrium',cooldown_s=3.50,
  resource_life_essence_pct=1.50,role='self_resource_recovery',
  effect='Draws on life essence to boost mana; amount restored is not specified.',source='211644'})
skill('vigour',{abadmin_id=133,syntax={'VIGOUR'},cooldown_lane='equilibrium',cooldown_s=3.50,
  resource_life_essence_pct=1.50,role='self_resource_recovery',
  effect='Draws on life essence to boost health; amount restored is not specified.',source='211644'})
skill('soulstorm',{abadmin_id=142,syntax={'SOULSTORM <target>'},works_on='adventurers and denizens',
  cooldown_lane='equilibrium',cooldown_s=4.00,resource_life_essence_pct=1.00,role='morph_removal_and_damage_modifier',
  effects_by_target={adventurers='Attempts to force a metamorphosised adventurer back to mortal form.',
    denizens='Profanes the soul, increasing damage from the specified attacks by 10%.'},
  denizen_damage_increase_pct=10,
  denizen_amplified_attacks={'NECROMANCY DECAY','NECROMANCY TAINT','EVILEYE BLEED',
    'Weapon-based WEAPONMASTERY attacks performed by an Infernal'},
  notes={'Against denizens, EQ and essence costs are greatly reduced; exact reduced values and effect duration are not supplied.'},source='211732'})
skill('disfigure',{abadmin_id=140,syntax={'DISFIGURE <target>'},works_on='adventurers',
  cooldown_lane='equilibrium',cooldown_s=3.00,role='affliction',afflictions={'disloyalty'},
  effect='Horrifies the victim visage so even close allies turn on them.',
  tracking_notes={'Existing Apostate AK Disfigure confirmation uses disloyalty.'},source='211745'})
skill('leprosy',{abadmin_id=146,syntax={'LEPROSY'},works_on='room',
  cooldown_lane='equilibrium',cooldown_s=4.50,resource_life_essence_pct=3.50,resource_mana=500,
  role='room_limb_affliction',afflictions={'leftarm','rightarm','leftleg','rightleg'},
  notes={'Causes random limbs to shrivel on many others in the room, friend or foe.',
    'The four limb keys enumerate possible outcomes; no number of limbs or exact side is inferred from sending the command.'},source='211801'})
skill('soulspear',{abadmin_id=152,syntax={'EVOKE SOULSPEAR FROM <target corpse>','THROW SOULSPEAR AT <target> <direction>'},
  works_on='adventurers',cooldown_lane='balance',cooldown_s=6.00,resource_life_essence_pct=2.50,
  role='ranged_defence_break_or_room_hinder',requires={'adventurer_corpse_above_level_30'},
  throw_requires={'target_outside_current_room','target_in_line_of_sight'},
  outcomes={'shield_or_prismatic_barrier_removal','gravehands_at_target_location'},
  notes={'A level-30-or-lower corpse is too weak; beyond that, higher corpse level gives a more powerful soulspear.',
    'Throwing shatters shields and prismatic barriers; if neither is present, summons hands of the grave at the target location.',
    'A defence/room effect, not a fixed affliction. No Curseward removal is inferred.'},source='211805'})
skill('transverse',{abadmin_id=153,syntax={'TRANSVERSE <target>'},works_on='adventurers',
  cooldown_lane='equilibrium',cooldown_s=3.00,resource_life_essence_pct=2.00,resource_mana=500,
  role='travel',requires={'gravehands_at_origin'},
  outcomes_by_destination={gravehands_present='Instant travel.',
    gravehands_absent='Target must practise Necromancy; travel is delayed.'},source='211820'})
skill('blackwind',{abadmin_id=154,syntax={'BLACKWIND','HUMAN','CHOKE <target>','SURGE <direction>'},
  works_on='adventurers',cooldown_lane='equilibrium',cooldown_s=4.00,
  resource_life_essence_pct=5.00,resource_mana=500,drains='Willpower',role='form_and_movement',
  notes={'Blackwind severely restricts freedom and vulnerability to harm, with rapid willpower drain.',
    'CHOKE is available in Blackwind form; HUMAN returns to normal form.',
    'SURGE is a channeled action that bypasses closed doors but not locked doors.',
    'No named persistent Choke affliction, channel duration, or drain rate is supplied.'},
  commands={blackwind={role='form'},human={role='revert'},choke={requires={'blackwind_form'}},
    surge={requires={'blackwind_form'},channeled=true,bypasses={'closed_unlocked_doors'},blocked_by={'locked_doors'}}},source='211824'})
skill('desecration',{abadmin_id=156,syntax={'DESECRATE <rite>'},works_on='room',
  cooldown_lane='balance',cooldown_s=4.00,resource_life_essence_pct=3.50,resource_mana=500,
  role='room_rite_removal',
  notes={'Severs a devotional rite in the current location.',
    'If the person who laid the rite is present, removal takes some time during which no actions may be taken.',
    'Duration is unspecified; listed balance recovery is not an inferred channel time.'},source='211849'})
skill('vivisect',{abadmin_id=157,syntax={'VIVISECT <target>'},works_on='adventurers',
  cooldown_lane='equilibrium',cooldown_s=4.00,resource_mana=300,role='instant_kill',instant_kill=true,
  requires={'all_four_target_limbs_withered'},required_limb_keys={'leftarm','rightarm','leftleg','rightleg'},
  prevents={'starburst_resurrection_on_success'},
  notes={'The AB explains splayed out and helpless as all four limbs withered; no additional prone requirement is added.',
    'No channel duration or channel classification is established by this capture.',
    'This reference does not evaluate readiness or activate Vivisect automatically.'},source='211849'})
return R
