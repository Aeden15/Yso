local root=arg[1] or 'Ysindrolir'
Yso={}
dofile(root..'/Monk/monk_reference.lua')
dofile(root..'/Monk/combo.lua')
dofile(arg[2] or root..'/Monk/shikudo_duel_selector.lua')
local S=Yso.monk.shikudo.duel_selector
assert(type(S.normalize_attacks)=='function','Ordered LIGHT normalizer is missing')
local function ctx()
  return {target='Bob',form='rain',mode='lock',kata=6,locked=true,hyperfocus='head',
    limbs={head=0,torso=0,leftarm=0,rightarm=0,leftleg=0,rightleg=0},
    limb_confidence={head='known',torso='known',leftarm='known',rightarm='known',leftleg='known',rightleg='known'},affs={}}
end
local c=ctx()
local intent={leftarm='prepare',rightarm='prepare',leftleg='prepare'}
local attacks,totals,why=S.normalize_attacks(c,{'ruku light left','kuro light left'},intent)
assert(attacks[1]=='ruku left' and attacks[2]=='kuro left')
assert(totals.leftarm==7.6 and totals.leftleg==7.6 and c.limbs.leftarm==0,'Projection must not mutate the snapshot')
c.limbs.leftarm=92.4
attacks,totals,why=S.normalize_attacks(c,{'ruku left','ruku left'},intent)
assert(attacks[1]=='ruku light left' and attacks[2]=='ruku light left','Exact 100 must be protected')
c.limbs.leftarm=90
attacks,totals,why=S.normalize_attacks(c,{'ruku left','ruku left'},intent)
assert(attacks[1]=='ruku left' and attacks[2]=='ruku light left','Second strike must include projected first-hit damage')
assert(math.abs(totals.leftarm-97.6)<0.00001)
assert(table.concat(why,' '):find('105.2',1,true))
c.limbs.leftarm=94
attacks,totals,why=S.normalize_attacks(c,{'ruku light left','ruku left'},{leftarm='break'})
assert(attacks[1]=='ruku left' and attacks[2]=='ruku light left','Break only once per limb in a combo')
assert(math.abs(totals.leftarm-101.6)<0.00001)
attacks=S.normalize_attacks(c,{'hiraku','ruku torso','risingkick torso'},intent)
assert(attacks[1]=='hiraku light' and attacks[2]=='ruku light torso' and #attacks==2,'Protect off-setup limbs and omit unsafe kicks')
c=ctx();c.form='willow';c.limbs.head=94
attacks,totals=S.normalize_attacks(c,{'hiraku'},{head='prepare'})
assert(attacks[1]=='hiraku' and math.abs(totals.head-97.95)<0.00001,'Hyperfocus halves projected staff damage once')
c.hit_damage={hiraku=10}
attacks,totals=S.normalize_attacks(c,{'hiraku'},{head='prepare'})
assert(attacks[1]=='hiraku' and totals.head==99,'Overrides are unmodified normal damage')
c.hyperfocus=nil
attacks=S.normalize_attacks(c,{'hiraku'},{head='prepare'})
assert(attacks[1]=='hiraku light')
c=ctx();c.limb_confidence.leftarm='unknown'
attacks,totals,why=S.normalize_attacks(c,{'ruku left','frontkick left'},{leftarm='break'})
assert(#attacks==1 and attacks[1]=='ruku light left' and totals.leftarm==0)
assert(table.concat(why,' '):find('unknown',1,true))
c.limb_confidence.leftarm='uncertain'
attacks=S.normalize_attacks(c,{'ruku left','frontkick left'},intent)
assert(#attacks==1 and attacks[1]=='ruku light left')
c=ctx();c.limbs.leftarm=94
attacks=S.normalize_attacks(c,{'frontkick left'},intent)
assert(#attacks==0,'Unsafe kicks cannot gain a LIGHT parameter')
attacks=S.normalize_attacks(c,{'frontkick left'},{leftarm='break'})
assert(attacks[1]=='frontkick left')
attacks=S.normalize_attacks(c,{'sweep','shatter'},intent)
assert(attacks[1]=='sweep' and attacks[2]=='shatter','Sweep/Shatter must remain unchanged')
c=ctx();c.limbs.leftarm=100;c.affs.leftarm=true
attacks=S.normalize_attacks(c,{'ruku left'},{leftarm='break'})
assert(attacks[1]=='ruku light left','Already broken limbs are protected')
c=ctx();c.form='gaital';c.affs.prone=true;c.hyperfocus='head';c.limbs.head=80
attacks=S.normalize_attacks(c,{'spinkick'},{head='prepare'})
assert(#attacks==0,'Prone kick damage is not reduced by Hyperfocus')
assert(c.limbs.head==80)
c=ctx();c.form='rain';c.affs.anorexia=true;c.kata=0;c.limbs.leftleg=94
c.limbs.leftarm=94;c.limbs.rightarm=94
local a=assert(S.select(c));assert(a.command:find('kuro light left',1,true))
assert(a.light_decisions and a.projected_limbs)
c.limbs.leftleg=0;a=assert(S.select(c));assert(a.command:find('kuro left',1,true))
c.selected_leg='rightleg';a=assert(S.select(c));assert(a.command:find('kuro right',1,true))
c.limb_confidence=nil;c.limb_ready=false
a=assert(S.select(c));assert(a.command:find('ruku light left',1,true),'Unknown baseline must still permit LIGHT pressure')
print('PASS intelligent LIGHT: ordered projection, intent, thresholds, confidence, overrides, Hyperfocus, legal kicks, diagnostics')
