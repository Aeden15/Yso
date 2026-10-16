local PATH_SEP = package.config:sub(1, 1)

local function script_dir()
  local source = debug.getinfo(1, "S").source or ""
  if source:sub(1, 1) == "@" then source = source:sub(2) end
  return source:match("^(.*)[/\\][^/\\]+$") or "."
end

local function join_path(...)
  local parts = { ... }
  local out = table.remove(parts, 1) or ""
  for i = 1, #parts do
    local part = tostring(parts[i] or "")
    if part ~= "" then
      if out ~= "" and out:sub(-1) ~= PATH_SEP then
        out = out .. PATH_SEP
      end
      out = out .. part
    end
  end
  return out
end

local SCRIPT_DIR = script_dir()
local ROUTE_CORE_PATH = join_path(SCRIPT_DIR, "..", "..", "Magi", "magi_route_core.lua")
local DISS_PATH = join_path(SCRIPT_DIR, "..", "..", "Magi", "magi_dissonance.lua")
local FOCUS_PATH = join_path(SCRIPT_DIR, "..", "..", "Magi", "magi_focus.lua")

local pass_count = 0
local fail_count = 0

local function fail(label, detail)
  fail_count = fail_count + 1
  io.stderr:write(string.format("FAIL: %s%s\n", label, detail and (" - " .. detail) or ""))
end

local function pass()
  pass_count = pass_count + 1
end

local function assert_eq(label, got, expected)
  if got ~= expected then
    fail(label, string.format("expected %s, got %s", tostring(expected), tostring(got)))
    return
  end
  pass()
end

local function assert_true(label, value)
  assert_eq(label, value == true, true)
end

local function defaulted_scores(src)
  local row = src or {}
  return setmetatable(row, { __index = function() return 0 end })
end

local function install_mudlet_stubs(now_ref)
  _G.setConsoleBufferSize = function() end
  _G.registerAnonymousEventHandler = function() return 1 end
  _G.killAnonymousEventHandler = function() end
  _G.tempRegexTrigger = function() return 1 end
  _G.killTrigger = function() end
  _G.tempAlias = function() return 1 end
  _G.killAlias = function() end
  _G.tempTimer = function() return 1 end
  _G.killTimer = function() end
  _G.expandAlias = function() return true end
  _G.raiseEvent = function() end
  _G.getCurrentLine = function() return "" end
  _G.matches = {}
  _G.cecho = function() end
  _G.echo = function() end
  _G.send = function() return true end
  _G.getEpoch = function() return now_ref() * 1000 end
end

local function make_world(opts)
  opts = opts or {}

  local current_target = opts.target or "foe"
  local current_room = tostring(opts.room_id or "1001")
  local now_s = tonumber(opts.now_s or 1000) or 1000
  local emits = {}
  local focus_active = (opts.focus_active == true)
  local hp_pct = opts.hp_pct
  local aff_scores = defaulted_scores(opts.aff_scores)
  local resonance = {
    air = tonumber(opts.air_res or 0) or 0,
    earth = tonumber(opts.earth_res or 0) or 0,
    fire = tonumber(opts.fire_res or 0) or 0,
    water = tonumber(opts.water_res or 0) or 0,
  }

  install_mudlet_stubs(function() return now_s end)

  _G.Yso = nil
  _G.yso = nil
  _G.affstrack = {
    score = aff_scores,
    kelpscore = tonumber(opts.kelpscore or 0) or 0,
  }
  _G.target = current_target
  _G.gmcp = {
    Char = {
      Status = { class = "Magi" },
      Vitals = { eq = "1", equilibrium = "1" },
    },
    Room = {
      Info = { num = current_room },
    },
  }

  _G.Yso = {
    Combat = {
      RouteInterface = {
        ensure_hooks = function() return true end,
      },
    },
    off = {
      magi = {},
    },
    magi = {
      resonance = {
        state = resonance,
        sync_from_ak = function() return true end,
        get = function(element)
          return resonance[tostring(element or ""):lower()] or 0
        end,
      },
      crystalism = {
        has_focus = function() return focus_active == true end,
        note_focus = function() focus_active = true end,
        clear_focus = function() focus_active = false end,
      },
      hellfumes = {
        is_up = function() return opts.hellfumes_up ~= false end,
      },
      elemental = {
        get_target_hp_percent = function() return hp_pct end,
      },
    },
    util = {
      now = function() return now_s end,
    },
    classinfo = {
      get = function() return "Magi" end,
      is_magi = function() return true end,
    },
    state = {
      eq_ready = function() return opts.eq_ready ~= false end,
    },
    mode = {
      is_combat = function() return true end,
      route_loop_active = function(id) return id == "focus" end,
      schedule_route_loop = function() return true end,
      stop_route_loop = function() return true end,
    },
    get_target = function()
      return current_target
    end,
    target_is_valid = function(who)
      return tostring(who or "") ~= ""
    end,
    offense_paused = function()
      return false
    end,
    queue = {
      clear = function() return true end,
    },
    emit = function(payload, emit_opts)
      emits[#emits + 1] = { payload = payload, opts = emit_opts }
      return true
    end,
  }
  _G.yso = _G.Yso

  dofile(ROUTE_CORE_PATH)
  dofile(DISS_PATH)
  dofile(FOCUS_PATH)

  local MF = Yso.off.magi.focus
  MF.state.enabled = true
  MF.state.loop_enabled = true
  MF.cfg.enabled = true
  MF.init()

  if tonumber(opts.dissonance_stage) then
    Yso.magi.dissonance.note(current_target, "tracked", {
      stage = tonumber(opts.dissonance_stage),
      confidence = opts.dissonance_confidence or "medium",
      evidence = opts.dissonance_evidence or "seeded",
    })
  end

  return {
    MF = MF,
    emits = emits,
    scores = aff_scores,
    set_target = function(who)
      current_target = tostring(who or "")
      _G.target = current_target
    end,
    set_room = function(room_id)
      current_room = tostring(room_id or "")
      _G.gmcp.Room.Info.num = current_room
    end,
    set_res = function(element, value)
      resonance[tostring(element or ""):lower()] = tonumber(value or 0) or 0
    end,
    set_hellfumes = function(on) opts.hellfumes_up = on end,
    set_focus = function(on)
      focus_active = (on == true)
    end,
    set_dissonance = function(stage, confidence, evidence)
      Yso.magi.dissonance.reset_target(current_target)
      if tonumber(stage or 0) > 0 then
        Yso.magi.dissonance.note(current_target, "tracked", {
          stage = tonumber(stage),
          confidence = confidence or "medium",
          evidence = evidence or "seeded",
        })
      end
    end,
    advance = function(dt)
      now_s = now_s + (tonumber(dt) or 0)
    end,
  }
end

local function preview_eq(world)
  local payload, why = world.MF.build_payload({})
  if not payload then return nil, why end
  local lanes = type(payload.lanes) == "table" and payload.lanes or {}
  local meta = type(payload.meta) == "table" and payload.meta or {}
  return lanes.eq, meta.main_reason
end

local function note_sent(world, cmd)
  world.MF.on_payload_sent({ eq = cmd })
end

-- A settled setup isolates selector behavior from the mandatory opening cast.
local function settled(changes)
  changes = changes or {}
  local scores = {
    waterbonds=100, frozen=100, frostbite=100, clumsiness=100, asthma=100,
    slickness=100, paralysis=100, anorexia=100, epilepsy=100, stupidity=100,
    scalded=100,
  }
  for key,value in pairs(changes.aff_scores or {}) do scores[key]=value end
  changes.aff_scores=scores
  for _,element in ipairs({"air","earth","fire","water"}) do
    local key=element.."_res"
    if changes[key]==nil then changes[key]=2 end
  end
  if changes.dissonance_stage==nil then changes.dissonance_stage=4 end
  local world=make_world(changes)
  note_sent(world, "cast dehydrate at foe")
  world.advance(3)
  return world
end

print("=== Opening Dehydrate ===")
do
  local world=make_world({hellfumes_up=false})
  assert_eq("hellfumes first", preview_eq(world), "cast hellfumes")
  note_sent(world,"cast hellfumes")
  assert_eq("dehydrate immediately after hellfumes",preview_eq(world),"cast dehydrate at foe")
  assert_eq("preview does not complete opener",preview_eq(world),"cast dehydrate at foe")
  note_sent(world,"cast dehydrate at foe")
  assert_eq("then waterbonds setup",preview_eq(world),"staff cast horripilation foe")
  world.set_hellfumes(true)
  assert_true("opening recorded",world.MF.explain().opening_dehydrate_done)
  world.set_target("other")
  assert_eq("target change opens again",preview_eq(world),"cast dehydrate at other")
  note_sent(world,"cast dehydrate at other")
  world.set_room("1002")
  assert_eq("room change respects immediate repeat guard",preview_eq(world),nil)
  world.advance(1)
  assert_eq("room change opens again",preview_eq(world),"cast dehydrate at other")
  world.MF.reset("test")
  world.advance(3)
  assert_eq("reset opens again",preview_eq(world),"cast dehydrate at other")
end

print("=== Core lock priorities ===")
do
  local world=settled({aff_scores={asthma=0}})
  assert_eq("asthma pressure",preview_eq(world),"cast bombard at foe")
  world=settled({aff_scores={slickness=0}})
  assert_eq("slickness pressure",preview_eq(world),"cast mudslide at foe")
  world=settled({aff_scores={slickness=0,frozen=0}})
  assert_eq("mudslide needs frozen",preview_eq(world),"cast freeze at foe")
  world=settled({aff_scores={paralysis=0,epilepsy=100}})
  assert_eq("paralysis even when kelpscore low and mechanics ready",preview_eq(world),"cast fulminate at foe")
  world=settled({aff_scores={anorexia=0},water_res=2})
  assert_eq("water progression toward anorexia",preview_eq(world),"cast freeze at foe")
  world=settled({aff_scores={anorexia=0},water_res=3})
  assert_eq("await actual anorexia through water pressure",preview_eq(world),"cast freeze at foe")
  local ex=world.MF.explain()
  assert_eq("major water is not confirmation",ex.lock.ready,false)
  assert_true("missing anorexia explained",ex.lock.missing_core[1]=="anorexia")
end

print("=== Any two mentals and strict Convergence gate ===")
do
  for _,pair in ipairs({{"epilepsy","stupidity"},{"epilepsy","dizziness"},{"stupidity","dizziness"}}) do
    local scores={epilepsy=0,stupidity=0,dizziness=0}
    scores[pair[1]]=100
    scores[pair[2]]=100
    local world=settled({aff_scores=scores})
    assert_eq("pair "..table.concat(pair,"/"),preview_eq(world),"cast convergence at foe")
    assert_eq("two mentals counted",world.MF.explain().lock.mental_count,2)
  end
  local world=settled({aff_scores={epilepsy=0,stupidity=100,dizziness=0}})
  assert_eq("existing paralysis does not hide missing epilepsy",preview_eq(world),"cast fulminate at foe")
  world=settled({aff_scores={stupidity=0,dizziness=0}})
  assert_eq("optional shock lightning",preview_eq(world),"staff cast lightning at foe")
  note_sent(world,"staff cast lightning at foe")
  preview_eq(world)
  assert_eq("pending lightning is not mental confirmation",world.MF.explain().lock.mental_count,1)
  world=settled({aff_scores={stupidity=0,dizziness=0},air_res=3})
  world.MF.cfg.shock_lightning_enabled=false
  assert_eq("disabled shock uses air emanation",preview_eq(world),"cast emanation at foe air")
  world=settled({aff_scores={stupidity=0,dizziness=0},air_res=2})
  world.MF.cfg.shock_lightning_enabled=false
  assert_eq("build air for dizziness",preview_eq(world),"cast bombard at foe")
  world=settled()
  world.MF.cfg.shock_lightning_enabled=false
  assert_eq("confirmed stupidity counts with feature disabled",preview_eq(world),"cast convergence at foe")
  world=settled({dissonance_stage=2})
  assert_eq("lock alone is insufficient",preview_eq(world),"embed dissonance")
  world=settled({fire_res=1})
  assert_eq("mechanical resonance still required",preview_eq(world),"cast firelash at foe")
end

print("=== Emanation and Dehydrate fallback ===")
do
  -- A pending Dissonance builder leaves the fallback reachable without satisfying Convergence.
  local function fallback(elements)
    local world=settled({dissonance_stage=1})
    note_sent(world,"embed dissonance")
    for _,element in ipairs(elements or {}) do world.set_res(element,3) end
    return world
  end
  for _,element in ipairs({"earth","fire","water","air"}) do
    local world=fallback({element})
    assert_eq("emanation "..element,preview_eq(world),"cast emanation at foe "..element)
    assert_eq("element explained",world.MF.explain().emanation_element,element)
    note_sent(world,"cast emanation at foe "..element)
    assert_eq("pending prevents repeat",preview_eq(world),nil)
    assert_eq("sending does not clear resonance",Yso.magi.resonance.get(element),3)
    world.advance(2.5)
    assert_eq("emanation retry after pending",preview_eq(world),"cast emanation at foe "..element)
  end
  local world=fallback({"earth","fire","water","air"})
  assert_eq("earth first",preview_eq(world),"cast emanation at foe earth")
  world.set_res("earth",2)
  assert_eq("fire second",preview_eq(world),"cast emanation at foe fire")
  world.set_res("fire",2)
  assert_eq("water third",preview_eq(world),"cast emanation at foe water")
  world.set_res("water",2)
  assert_eq("air fourth",preview_eq(world),"cast emanation at foe air")
  world=fallback()
  assert_eq("dehydrate final fallback",preview_eq(world),"cast dehydrate at foe")
  note_sent(world,"cast dehydrate at foe")
  assert_eq("dehydrate repeat suppressed",preview_eq(world),nil)
  preview_eq(world)
  local st=world.MF.explain().state
  assert_eq("nausea not fabricated",st.nausea,false)
  assert_eq("weariness not fabricated",st.weariness,false)
end

print("=== Guard, tracking and post-Convergence ===")
do
  local world=make_world({eq_ready=false})
  assert_eq("eq guard",preview_eq(world),nil)
  world=settled({aff_scores={conflagrate=100}})
  note_sent(world,"cast convergence at foe")
  assert_eq("destroy first",preview_eq(world),"cast destroy at foe")
  assert_true("destroy emits",world.MF.attack_function({})==true)
  local emit=world.emits[#world.emits]
  assert_eq("destroy clearfull preserved",emit.opts.queue_verb,"addclearfull")
  world=settled({aff_scores={slickness=0}})
  note_sent(world,"cast convergence at foe")
  assert_eq("maintain lock after convergence",preview_eq(world),"cast mudslide at foe")
  world=settled()
  note_sent(world,"cast convergence at foe")
  assert_eq("post-convergence dehydrate filler",preview_eq(world),"cast dehydrate at foe")
  world=settled({aff_scores={nausea=100,weariness=100,ablaze=200}})
  preview_eq(world)
  local st=world.MF.explain().state
  assert_true("nausea tracked",st.nausea)
  assert_true("weariness tracked",st.weariness)
  assert_eq("burning stacks retained raw",st.raw.ablaze,200)
  world.MF.reset("test")
  for _,slot in ipairs({"dehydrate","mudslide","lightning","emanation"}) do
    assert_eq("reset clears "..slot,world.MF.state.pending[slot].target,"")
  end
end

print("=== Review regressions ===")
do
  local world=settled({aff_scores={asthma=1,slickness=50,paralysis=1,anorexia=50,epilepsy=1,stupidity=33}})
  assert_eq("uncertain lock stays pressure",preview_eq(world),"cast bombard at foe")
  assert_eq("uncertain mentals do not count",world.MF.explain().lock.mental_count,0)
  assert_eq("uncertain lock is not ready",world.MF.explain().lock.ready,false)
  world=settled({aff_scores={frostbite=0},earth_res=3})
  note_sent(world,"cast convergence at foe")
  note_sent(world,"cast emanation at foe earth")
  assert_eq("blocked postconv major holds",preview_eq(world),nil)
  world=settled()
  world.MF.route_contract.route_local_categories={"maintenance"}
  world.MF.cfg.shock_lightning_enabled=false
  dofile(FOCUS_PATH)
  world.MF.init()
  local found=false
  for _,category in ipairs(world.MF.route_contract.route_local_categories) do
    if category=="lock_pressure" then found=true end
  end
  assert_true("hot reload adds lock category",found)
  assert_eq("hot reload preserves disabled shock",world.MF.cfg.shock_lightning_enabled,false)
end
io.write(string.format("PASS: %d\n",pass_count))
if fail_count>0 then
  io.stderr:write(string.format("FAILURES: %d\n",fail_count))
  os.exit(1)
end