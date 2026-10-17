-- Two-line success confirmation; only update the selected opponent.
if type(IsTargetted) ~= "function"
    or type(OppGainedAff) ~= "function" then return end
if type(ak) == "table" and type(ak.ai) == "function" and ak.ai() then return end

local victim = type(multimatches) == "table"
  and type(multimatches[1]) == "table" and multimatches[1][2]
if type(victim) ~= "string" or victim == "" or not IsTargetted(victim) then return end

OppGainedAff("leftleg rightleg rightarm leftarm prone")
