-- Mudlet alias body for pattern: ^vibeds$
-- Paste this into the alias command box if you want the alias to load the
-- workspace helper automatically and then run the default embed sequence.

local function _norm(path)
  return (tostring(path or ""):gsub("\\", "/"):gsub("/+$", ""))
end

local function _exists(path)
  local fh = io.open(path, "rb")
  if not fh then return false end
  fh:close()
  return true
end

local function _candidate_paths()
  local out = {}
  local seen = {}
  local function push(root)
    root = _norm(root)
    if root == "" then return end
    local path = root .. "/Ysindrolir/Magi/magi_vibes.lua"
    if seen[path] then return end
    seen[path] = true
    out[#out + 1] = path
  end

  if type(Yso) == "table" and type(Yso.bootstrap) == "table" and type(Yso.bootstrap.root) == "string" then
    local root = _norm(Yso.bootstrap.root)
    -- Strip the full Occultist-module suffix so we land at the "Yso systems" root,
    -- not at Ysindrolir (which would make push() produce a double-Ysindrolir path).
    local sibling = root:gsub("/Ysindrolir/Occultist/modules$", "")
    if sibling ~= root then
      push(sibling)
    end
  end

  local home = _norm(os.getenv("USERPROFILE") or os.getenv("HOME") or "")
  if home ~= "" then
    push(home .. "/OneDrive/Desktop/Yso systems")
    push(home .. "/OneDrive - Personal/Desktop/Yso systems")
    push(home .. "/Desktop/Yso systems")
    push(home .. "/OneDrive/Yso systems")
  end

  return out
end

local mod_path
for _, candidate in ipairs(_candidate_paths()) do
  if _exists(candidate) then
    mod_path = candidate
    break
  end
end

if not mod_path then
  if type(cecho) == "function" then
    cecho("<red>[Yso:Magi:Vibes] load failed: magi_vibes.lua not found<reset>\n")
  end
  return
end

if not (Yso and Yso.magi and Yso.magi.vibes and type(Yso.magi.vibes.run) == "function") then
  local ok, err = pcall(dofile, mod_path)
  if not ok then
    if type(cecho) == "function" then
      cecho(string.format("<red>[Yso:Magi:Vibes] load failed: %s<reset>\n", tostring(err)))
    end
    return
  end
end

local ok, err = pcall(Yso.magi.vibes.run)
if not ok and type(cecho) == "function" then
  cecho(string.format("<red>[Yso:Magi:Vibes] run failed: %s<reset>\n", tostring(err)))
end
