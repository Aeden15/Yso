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

local ROOT = join_path(script_dir(), "..", "..", "Monk")

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

local function assert_nil(label, value)
  if value ~= nil then
    fail(label, "expected nil, got " .. tostring(value))
    return
  end
  pass()
end

_G.Yso = {}
_G.affstrack = { score = {} }
_G.target = "bob"
_G.send = function(cmd)
  _G._last_send = cmd
  return true
end

Yso.ak = {
  has = function(name)
    return (tonumber(affstrack.score[name]) or 0) >= 100
  end,
}

dofile(join_path(ROOT, "monk_reference.lua"))
dofile(join_path(ROOT, "stance.lua"))
dofile(join_path(ROOT, "kai_resource.lua"))
dofile(join_path(ROOT, "combo.lua"))
dofile(join_path(ROOT, "scythe.lua"))

local function apply(list)
  Yso.monk.kai.apply_charstats(list)
end

apply({ "Bleed: 0", "Rage: 0", "Kai: 0%", "Stance: None" })
assert_eq("kai none percent", hadoken, 0)
assert_eq("kai current matches hadoken", Yso.monk.kai.current, 0)
assert_eq("stance word none", Yso.monk.stance.word, "none")
assert_nil("stance cleared", Yso.monk.stance.current)

apply({ "Bleed: 0", "Rage: 0", "Kai: 0%", "Stance: Dragon" })
assert_eq("dragon command", Yso.monk.stance.current and Yso.monk.stance.current.command, "DRS")

apply({ "Bleed: 0", "Rage: 0", "Kai: 40%", "Stance: horse" })
assert_eq("kai 40", hadoken, 40)
assert_eq("horse command case-insensitive", Yso.monk.stance.current and Yso.monk.stance.current.command, "HRS")

assert_eq("axe id", Yso.ref.monk.tekura.axe.abadmin_id, 862)
assert_eq("cat id", Yso.ref.monk.tekura.cat.abadmin_id, 851)
assert_eq("scythe syntax", Yso.ref.monk.telepathy.scythe.syntax[1], "MIND SCYTHE")
assert_nil("no shikudo table", Yso.ref.monk.shikudo)

local function clear_scores()
  affstrack.score = {}
end

clear_scores()
affstrack.score.head = 100
affstrack.score.stupidity = 100
affstrack.score.impatience = 100
assert_true("scythe not ready on first head break", Yso.monk.scythe.ready("bob") == false)

clear_scores()
affstrack.score.head = 200
affstrack.score.epilepsy = 100
assert_true("scythe not ready on one mental", Yso.monk.scythe.ready("bob") == false)

local pool = Yso.ref.monk.telepathy.scythe.mental_pool
pool[#pool + 1] = "epilepsy"
assert_true("epilepsy still counts once", Yso.monk.scythe.ready("bob") == false)
table.remove(pool)

clear_scores()
affstrack.score.head = 200
affstrack.score.epilepsy = 100
affstrack.score.confusion = 100
_G._last_send = nil
assert_true("scythe ready", Yso.monk.scythe.ready("bob") == true)
assert_true("scythe sends bare command", Yso.monk.scythe.execute("bob") == true)
assert_eq("scythe command", _G._last_send, "mind scythe")

clear_scores()
assert_eq(
  "combo plain",
  Yso.monk.combo.build("bob", { kick = "sdk", punch1 = "hkp", punch2 = "ucp" }),
  "combo bob sdk hkp ucp"
)

affstrack.score.rightleg = 80
affstrack.score.leftleg = 10
assert_eq(
  "combo prefers damaged leg",
  Yso.monk.combo.build("bob", { kick = "snk", punch1 = "hkp", punch2 = "ucp" }),
  "combo bob snk right hkp ucp"
)

affstrack.score.leftleg = 200
affstrack.score.rightleg = 200
assert_eq(
  "combo broken legs fall back to left",
  Yso.monk.combo.build("bob", { kick = "sdk", punch1 = "hfp", punch2 = "ucp" }),
  "combo bob sdk hfp left ucp"
)

assert_eq(
  "combo appends jpk",
  Yso.monk.combo.build("bob", { kick = "sdk", punch1 = "hkp", punch2 = "ucp", jpk = true }),
  "combo bob sdk hkp ucp jpk"
)

assert_eq(
  "combo does not repeat jpk",
  Yso.monk.combo.build("bob", { kick = "jpk", punch1 = "hkp", punch2 = "ucp", jpk = true }),
  "combo bob jpk hkp ucp"
)

local bad = Yso.monk.combo.build("bob", { kick = "slt", punch1 = "hkp", punch2 = "ucp" })
assert_nil("throw is not a combo kick", bad)

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
