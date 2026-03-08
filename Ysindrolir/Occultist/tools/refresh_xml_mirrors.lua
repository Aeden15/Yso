-- Refresh promoted Occultist modular sources into xml mirror files.
-- Run with a standard Lua interpreter from the Occultist workspace root.

local manifest = dofile("EXPORT_MANIFEST.lua")

local function read_all(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local function write_all(path, data)
  local f = assert(io.open(path, "wb"))
  f:write(data)
  f:close()
end

for _, row in ipairs(manifest) do
  local data = read_all(row.source)
  write_all(row.mirror, data)
  io.write(string.format("refreshed %s -> %s\n", row.source, row.mirror))
end
