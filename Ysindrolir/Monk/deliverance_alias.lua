-- Pause curing and request Deliverance together; confirmation triggers own state.
if Yso and Yso.monk and Yso.monk.kai then
  local ok, reason = Yso.monk.kai.start_deliverance()
  if not ok and type(cecho) == "function" then
    cecho("\n<cyan>[Yso]<reset> Deliverance blocked: " .. tostring(reason) .. ".\n")
  end
end
