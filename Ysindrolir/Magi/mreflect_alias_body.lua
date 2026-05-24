local arg = (matches[2] or ""):gsub("^%s+", ""):gsub("%s+$", "")
local tgt = (arg == "" or arg:lower() == "me") and "me" or arg
send("cast reflection at " .. tgt)
