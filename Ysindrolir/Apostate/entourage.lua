-- Daemonite-only balanceless orders. Summoning and pentagram setup stay manual.
Yso = Yso or {}
Yso.apostate = Yso.apostate or {}
local E = Yso.apostate.entourage or {}
Yso.apostate.entourage = E

local function dispatch(command)
    local sender = Yso.send
    if type(sender) == 'function' then
        local ok, result = pcall(sender, command)
        return ok and result == true
    end
    if type(send) ~= 'function' then return false end
    local ok, result = pcall(send, command, false)
    return ok and result ~= false
end

function E.attack(target)
    if type(target) ~= 'string' or not target:match("^[A-Za-z][A-Za-z'%-]*$") then
        return false, 'invalid_target'
    end
    if E.target and E.target:lower() == target:lower() then return true end

    -- A sender can fail after transmitting: preserve the need for cleanup.
    E.needs_passive = true
    E.target = nil
    if not dispatch('order daemonite kill ' .. target) then return false, 'send_failed' end
    E.target = target
    return true
end

function E.passive()
    if not E.needs_passive then return true end
    E.target = nil
    if not dispatch('order daemonite passive') then return false, 'send_failed' end
    E.target = nil
    E.needs_passive = false
    return true
end

return E
