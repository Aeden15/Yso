--This will serve as a sample and standard of how automation scripts should be written and ran from top to bottom when executed.

-- This section is for anti-defensive measures on the target
-- shieldbreaking logic go here.  --if ak.defs.shield then send("command gremlin at " .. target) end
-- anti-tumbling and leaping logic goes here.
-- instant kill logics
-- if affstrack.enlightenscore => 5 then send("enlighten " .. target)
--elseif "enlighten" then
--send("unravel mind of " .. target)
--end
--========================================================================================================

-- This section is for defensive measures on me.
-- My fool card logic goes here
-- My shield logic goes here
-- My tumbling/leaping and other "get the fuck out" escape methods go here
--========================================================================================================
-- This will serve as the main offensive "spam" attack logics
-- if S.loyals_target and not S.loyals_hostile then
--send("order loyals kill "..target)
--end

--=======================================================================================================

--Offensive conditions will go here 
--=======================================================================================================

--Other miscellaneous conditions go here
--=======================================================================================================

-- Other scripts that may serve a purpose go here
--=======================================================================================================