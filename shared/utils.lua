function clone_table(t)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[deepcopy(orig_key)] = deepcopy(orig_value)
    end
    setmetatable(copy, deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

function tPrint(tbl, indent)
  indent = indent or 0
  for k, v in pairs(tbl) do
    local tblType = type(v)
    local formatting = ("%s ^3%s:^0"):format(string.rep("  ", indent), k)

    if tblType == "table" then
      print(formatting)
      tPrint(v, indent + 1)
    elseif tblType == 'boolean' then
      print(("%s^1 %s ^0"):format(formatting,v))
    elseif tblType == "function" then
      print(("%s^9 %s ^0"):format(formatting,v))
    elseif tblType == 'number' then
      print(("%s^5 %s ^0"):format(formatting,v))
    elseif tblType == 'string' then
      print(("%s ^2'%s' ^0"):format(formatting,v))
    else
      print(("%s^2 %s ^0"):format(formatting,v))
    end
  end
end

function slice_table(t, first, last, step)
  local sliced = {}

  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end

  return sliced
end

local currentResourceName = GetCurrentResourceName()
local debugIsEnabled = GetConvarInt('pe-debugMode', 0) == 1

function debugPrint(...)
  if not debugIsEnabled then return end
  local args <const> = { ... }

  local appendStr = ''
  for _, v in ipairs(args) do
    appendStr = appendStr .. ' ' .. tostring(v)
  end
  local msgTemplate = '^3[%s]^0%s'
  local finalMsg = msgTemplate:format(currentResourceName, appendStr)
  print(finalMsg)
end