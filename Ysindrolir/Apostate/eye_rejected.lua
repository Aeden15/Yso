-- Exact rejection lines only; never call this for "Equilibrium/Balance used".
local M=Yso and Yso.off and Yso.off.apostate and Yso.off.apostate.truelock
if not (M and type(M.note_eye_rejected)=='function') then return end
local line=matches[1] or ''
if line=='You must regain equilibrium first.' then M.note_eye_rejected('equilibrium')
elseif line=='You must regain balance first.' then M.note_eye_rejected('balance')
elseif line=='You cannot use the evil eye while blind.' then M.note_eye_rejected('blind')
else M.note_eye_rejected('curseward',matches[2]) end
