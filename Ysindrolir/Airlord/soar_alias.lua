-- ^soa([lhs])$: send the full game command rather than a client alias.
local elevations = {
  l = "low",
  h = "high",
  s = "stratosphere",
}
local elevation = elevations[matches[2]]
if elevation then
  sendAll("clearqueue all", "aero soar " .. elevation)
end
