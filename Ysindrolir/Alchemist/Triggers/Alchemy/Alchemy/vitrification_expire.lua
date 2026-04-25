if Yso.alc and Yso.alc.phys and type(Yso.alc.phys.set_alchemy_debuff) == "function" then
  Yso.alc.phys.set_alchemy_debuff(matches[2], "vitrification", false, "vitrification_expire")
end
