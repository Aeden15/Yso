Yso = Yso or {}
Yso.alc = Yso.alc or {}
Yso.alc.phys = Yso.alc.phys or {}

local P = Yso.alc.phys

P.humour_success_lines = P.humour_success_lines or {
  "tempering his choleric humour.",
  "tempering his melancholic humour.",
  "tempering his phlegmatic humour.",
  "tempering his sanguine humour.",
}

P.humour_ready_line = P.humour_ready_line or "You may manipulate another's humours once more."
P.humour_fail_line = P.humour_fail_line or "You are unable to manipulate another's humours at this time."

function P.handle_humour_balance_line(line)
  line = tostring(line or "")
  if line == "" then
    return nil
  end

  if line == P.humour_ready_line then
    if Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
      Yso.alc.set_humour_ready(true, "humour_ready")
    end
    return true
  end

  if line == P.humour_fail_line then
    return nil
  end

  for _, fragment in ipairs(P.humour_success_lines) do
    if line:find(fragment, 1, true) then
      if Yso.alc and type(Yso.alc.set_humour_ready) == "function" then
        Yso.alc.set_humour_ready(false, fragment)
      end
      return false
    end
  end

  return nil
end
