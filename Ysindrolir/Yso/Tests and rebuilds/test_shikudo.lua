local root = 'Ysindrolir/Monk/'
Yso = {}
dofile(root .. 'monk_reference.lua')
dofile(root .. 'combo.lua')
assert(type(Yso.monk.combo.build_shikudo) == 'function', 'shared Shikudo combo builder missing')
local ai_file = assert(loadfile(root .. 'shikudo_ai.lua'))
ai_file()
dofile(root .. 'shikudo_forms.lua')
local C, A, F = Yso.monk.combo, Yso.monk.shikudo.ai, Yso.monk.shikudo
local function eq(got, want) assert(got == want, tostring(got)..' ~= '..tostring(want)) end
local function command(ctx)
  local opts, why = A.select(ctx)
  assert(opts, why)
  if opts.command then return opts.command end
  local cmd, reason = C.build_shikudo(ctx.target or 'Bob', opts)
  assert(cmd, reason)
  return cmd
end
eq(command{form='rain',kata=0}, 'combo Bob kuro left kuro left frontkick left')
eq(command{form='rain',kata=6,prone=true}, 'combo Bob frontkick left hiru hiru transition oak')
eq(command{form='oak',kata=5,affs={paralysis=true}}, 'combo Bob livestrike kuro left risingkick head transition gaital')
eq(command{form='gaital',kata=0}, 'combo Bob sweep flashheel left')
eq(command{form='gaital',kata=0,prone=true}, 'combo Bob needle needle spinkick')
eq(command{form='willow',kata=6}, 'combo Bob hiru hiraku flashheel left transition rain')
eq(command{form='tykonos',kata=5}, 'combo Bob thrust head thrust torso risingkick head transition willow')
eq(command{form='maelstrom',kata=5}, 'combo Bob livestrike ruku torso risingkick torso transition oak')
eq(command{form='rain',kata=21}, 'transition to oak form')
eq(command{form='gaital',kata=0,shield=true,dispatch_ready=true}, 'combo Bob shatter needle flashheel left')
for _, form in ipairs{'rain','oak','gaital','willow','tykonos','maelstrom'} do
  local cmd = command{form=form,kata=0,shield=true}
  assert(cmd:find('shatter',1,true), 'shield branch omitted Shatter: '..form)
  assert(not cmd:find('sweep',1,true), 'shield branch consumed both staff slots: '..form)
end
eq(command{form='gaital',kata=0,dispatch_ready=true,target='Bob'}, 'dispatch Bob')
eq(command{form='rain',kata=0,leg='right'}, 'combo Bob kuro right kuro right frontkick left')
eq(C.build_shikudo('Bob',{form='rain',attacks={'needle','needle','frontkick left'}}),nil)
eq(C.build_shikudo('Bob',{form='gaital',attacks={'sweep','shatter','spinkick'}}),nil)
eq(C.build_shikudo('Bob',{form='rain',attacks={'frontkick head'}}),nil)
eq(C.build_shikudo('Bob',{form='rain',attacks={'kuro left'},transition='gaital',kata=5}),nil)
eq(C.build_shikudo('Bob',{form='rain',attacks={'kuro left'},transition='oak',kata=4}),nil)
eq(C.build_shikudo('Bob',{form='gaital',attacks={'spinkick','dawnkick'}}),nil)
eq(C.build_shikudo('Bob',{form='gaital',attacks={'needle','needle','needle'}}),nil)
eq(C.build_shikudo('Bob&&quit',{form='rain',attacks={'kuro left'}}),nil)
shikstaff='staff123'; eq(F.staff_command(),'wield staff123')
shikstaff='staff456'; eq(F.staff_command(),'wield staff456')
shikstaff='staff123&&quit'; eq(F.staff_command(),nil)
F.set_form('rain'); F.set_kata(6)
eq(F.kata,6); command{form='rain',kata=F.kata}; eq(F.kata,6)
print('PASS Shikudo selection, legality, dynamic staff, confirmed state')
