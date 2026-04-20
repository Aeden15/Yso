Yso = Yso or {}
Yso.alc = Yso.alc or {}
Yso.alc.form = Yso.alc.form or {}

function Yso.alc.form.handle_phiallist_line(line)
  if type(Yso.alc.form.parse_phiallist) ~= "function" then
    return nil
  end
  return Yso.alc.form.parse_phiallist(line)
end
