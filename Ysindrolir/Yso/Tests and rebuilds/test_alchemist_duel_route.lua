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
local ROUTE_PATH = join_path(SCRIPT_DIR, "..", "..", "Alchemist", "Core", "duel route.lua")

local pass_count = 0
local fail_count = 0

local function fail(label, detail)
  fail_count = fail_count + 1
  io.stderr:write(string.format("FAIL: %s%s\n", label, detail and (" - " .. detail) or ""))
end

local function pass() pass_count = pass_count + 1 end

local function assert_eq(label, got, expected)
  if got ~= expected then
    fail(label, string.format("expected %s, got %s", tostring(expected), tostring(got)))
    return
  end
  pass()
end

local function assert_true(label, cond)
  if cond ~= true then
    fail(label, "expected true")
    return
  end
  pass()
end

local function assert_false(label, cond)
  if cond ~= false then
    fail(label, "expected false")
    return
  end
  pass()
end

local function contains_text(list, text)
  for i = 1, #list do
    if tostring(list[i] or ""):find(text, 1, true) then
      return true
    end
  end
  return false
end

local function free_has(payload, text)
  local free = payload and payload.free or nil
  if type(free) == "table" then
    for i = 1, #free do
      if tostring(free[i] or ""):find(text, 1, true) then
        return true
      end
    end
    return false
  end
  return tostring(free or ""):find(text, 1, true) ~= nil
end

local function make_world(opts)
  opts = opts or {}
  local now_s = tonumber(opts.now_s or 1300) or 1300
  local current_target = opts.target or "TargetOne"
  local sent = {}

  _G.Yso = nil
  _G.yso = nil
  _G.target = current_target
  _G.matches = {}
  _G.getCurrentLine = function() return "" end
  _G.getEpoch = function() return now_s * 1000 end
  _G.cecho = function() end
  _G.echo = function() end
  _G.send = function(cmd)
    sent[#sent + 1] = cmd
    return true
  end

  _G.gmcp = {
    Char = {
      Status = { class = "Alchemist" },
      Vitals = { eq = "1", equilibrium = "1", bal = "1", balance = "1" },
    },
  }

  local homunculus_state = { active = false, target = "" }

  local stub_P = {
    target = function(name) return { name = name } end,
    target_needs_evaluate = function() return false end,
    note_evaluate_request = function() return true end,
    reave_sync_target = function() return false end,
    clear_staged_for_target = function() return true end,
    can_aurify = function() return opts.can_aurify == true end,
    can_reave = function()
      if opts.can_reave == true then
        return true, { legal = true }
      end
      return false, { legal = false }
    end,
    fire_reave = function(name)
      sent[#sent + 1] = "reave " .. tostring(name or "")
      return true
    end,
    pick_temper_humour = function()
      return opts.temper_humour
    end,
    build_truewrack_with_staged = function(_, _, staged_info)
      if opts.require_staged == true and (not staged_info or staged_info.temper_humour ~= opts.temper_humour) then
        return nil
      end
      return opts.truewrack_cmd
    end,
    build_wrack_fallback_with_staged = function(_, _, staged_info)
      if opts.require_staged == true and (not staged_info or staged_info.temper_humour ~= opts.temper_humour) then
        return nil
      end
      return opts.wrack_cmd
    end,
    build_truewrack = function() return opts.truewrack_cmd end,
    build_wrack_fallback = function() return opts.wrack_cmd end,
    current_humour_count = function(_, humour)
      humour = tostring(humour or ""):lower()
      return (opts.humours and opts.humours[humour]) or 0
    end,
    health_pct = function() return opts.hp end,
    mana_pct = function() return opts.mp end,
    alchemy_debuff_active = function()
      if opts.vitri_active then
        return true, "vitrification", {}
      end
      return false, nil, nil
    end,
    corruption_active = function()
      return opts.corrupt_active == true
    end,
    clear_all_humours = function() return true end,
  }

  _G.Yso = {
    cfg = { UseQueueing = "NO", pipe_sep = "&&" },
    Combat = {
      RouteInterface = {
        ensure_hooks = function() return true end,
      },
    },
    off = {
      alc = {},
      core = {
        register = function() return true end,
      },
    },
    util = { now = function() return now_s end },
    state = {
      eq_ready = function() return opts.eq_ready ~= false end,
      bal_ready = function() return opts.bal_ready ~= false end,
    },
    bal = {
      humour = opts.class_ready ~= false,
      evaluate = true,
      homunculus = opts.homunculus_ready ~= false,
    },
    alc = {
      phys = stub_P,
    },
    mode = {
      is_party = function() return false end,
      active_route_id = function() return "alchemist_duel_route" end,
      route_loop_active = function(id) return id == "alchemist_duel_route" end,
      schedule_route_loop = function() return true end,
    },
    get_target = function() return current_target end,
    target_is_valid = function(who) return tostring(who or "") ~= "" end,
    offense_paused = function() return false end,
    shield = {
      up = function() return opts.shielded == true end,
    },
    set_homunculus_attack = function(v, tgt)
      homunculus_state.active = (v == true)
      homunculus_state.target = (v == true) and tostring(tgt or "") or ""
      return homunculus_state.active
    end,
    homunculus_attack = function(tgt)
      if homunculus_state.active ~= true then return false end
      tgt = tostring(tgt or "")
      if tgt == "" then return true end
      return homunculus_state.target:lower() == tgt:lower()
    end,
  }
  _G.yso = _G.Yso

  _G.Yso.alc.set_humour_ready = function(ready)
    _G.Yso.bal.humour = (ready == true)
    return _G.Yso.bal.humour
  end
  _G.Yso.alc.humour_ready = function() return _G.Yso.bal.humour ~= false end
  _G.Yso.alc.set_evaluate_ready = function(ready)
    _G.Yso.bal.evaluate = (ready == true)
    return _G.Yso.bal.evaluate
  end
  _G.Yso.alc.evaluate_ready = function() return _G.Yso.bal.evaluate ~= false end
  _G.Yso.alc.set_homunculus_ready = function(ready)
    _G.Yso.bal.homunculus = (ready == true)
    return _G.Yso.bal.homunculus
  end
  _G.Yso.alc.homunculus_ready = function() return _G.Yso.bal.homunculus ~= false end

  _G.Yso.queue = { can_plan_lane = function() return true end }

  _G.ak = {
    defs = {
      shield_by_target = {
        [string.lower(current_target)] = (opts.shielded == true),
      },
      shield = (opts.shielded == true),
    },
  }

  dofile(ROUTE_PATH)
  local R = _G.Yso.off.alc.duel_route
  R.init()
  R.cfg.enabled = true
  R.state.enabled = true
  R.state.loop_enabled = true

  return {
    R = R,
    sent = sent,
    set_target = function(t)
      current_target = t
      _G.target = t
    end,
  }
end

print("=== Test 1: shieldbreak supports staged truewrack combo ===")
do
  local world = make_world({
    shielded = true,
    temper_humour = "choleric",
    truewrack_cmd = "truewrack TargetOne melancholic paralysis",
    require_staged = true,
  })
  local payload = world.R.build_payload({ target = "TargetOne" })
  assert_eq("1a: shield uses copper", payload and payload.eq, "educe copper TargetOne")
  assert_eq("1b: temper appended", payload and payload.class, "temper TargetOne choleric")
  assert_eq("1c: staged truewrack appended", payload and payload.bal, "truewrack TargetOne melancholic paralysis")
end

print("\n=== Test 2: aurify/reave blocked by shield ===")
do
  local aur_world = make_world({ shielded = true, can_aurify = true, temper_humour = "choleric" })
  local p_aur = aur_world.R.build_payload({ target = "TargetOne" })
  assert_eq("2a: aurify not fired through shield", p_aur and p_aur.eq, "educe copper TargetOne")
  assert_false("2b: payload not direct aurify", (p_aur and p_aur.eq == "aurify TargetOne"))

  local reave_world = make_world({ shielded = true, can_reave = true, temper_humour = "choleric" })
  local p_reave = reave_world.R.build_payload({ target = "TargetOne" })
  assert_false("2c: reave not fired through shield", tostring(p_reave and p_reave.class or ""):find("reave TargetOne", 1, true) ~= nil)
end

print("\n=== Test 3: duel keeps homunculus corrupt as free/pre action ===")
do
  local world = make_world({
    shielded = false,
    can_aurify = false,
    can_reave = false,
    class_ready = false,
    eq_ready = false,
    bal_ready = false,
    homunculus_ready = true,
    corrupt_active = false,
  })
  local payload = world.R.build_payload({ target = "TargetOne" })
  assert_true("3a: payload contains homunculus corrupt", free_has(payload, "homunculus corrupt TargetOne"))
end

print("\n=== Test 4: lifecycle pacify and target swap homunculus attack ===")
do
  local world = make_world({ temper_humour = "choleric", wrack_cmd = "wrack TargetOne paralysis" })
  local R = world.R

  R.start()
  local p1 = R.build_payload({ target = "TargetOne" })
  assert_true("4a: start arms homunculus attack", free_has(p1, "homunculus attack TargetOne"))

  world.set_target("TargetTwo")
  local p2 = R.build_payload({ target = "TargetTwo" })
  assert_true("4b: target swap rearms homunculus attack", free_has(p2, "homunculus attack TargetTwo"))

  R.stop("manual")
  assert_true("4c: stop sends pacify", contains_text(world.sent, "homunculus pacify"))
  assert_false("4d: stop never sends passive", contains_text(world.sent, "homunculus passive"))
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
