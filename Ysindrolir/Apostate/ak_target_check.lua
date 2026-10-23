-- Maintained AK Target Check. Game names and typed targets may differ in case.
-- Preserve AK's existing support for abbreviated target prefixes.
function IsTargetted(person)
 if type(person)~='string' or person=='' then return false end
 target=target or 'Dude'
 local wanted=tostring(target):lower()
 if wanted=='' then return false end
 return person:lower():sub(1,#wanted)==wanted
end
