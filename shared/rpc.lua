RPC = {}
local table_pack = table.pack
local table_unpack = table.unpack

local registeredCallbacks = {}
local isServer = IsDuplicityVersion()

local function generateRPCObject(opts)
  local defaultObj = {}

  defaultObj.rpcTimeout = opts.rpcTimeout or 15000

  return defaultObj
end

function RPC:new(opts)
  local objContents = generateRPCObject(opts)
  setmetatable(objContents, self)
  self.__index = self
  return objContents
end

function RPC:register(eventName, fn)
  if registeredCallbacks[eventName] then
    error('RPC event name: %s already is registered!')
  end

  RegisterNetEvent(eventName, function(respEventName, ...)
    local retObj = {
      error = false,
      data = {},
      errorMsg = 'none'
    }

    local src = isServer and source

    -- In case execution goes bad on the remote client
    -- lets inform the caller with the error msg
    local returnData = table_pack(fn(table_unpack(...)))

    --if not success then
    --  retObj.error = true
    --  retObj.errorMsg = ret
    --else
    --  retObj.data = ret
    --end

    retObj.data = returnData

    debugPrint(('Resp > %s, src: %s'):format(respEventName, tostring(src)))
    debugPrint('Return Data')
    tPrint(retObj)

    if isServer then
      TriggerClientEvent(respEventName, src, retObj)
    else
      TriggerServerEvent(respEventName, retObj)
    end
  end)
end

function RPC:unregister(eventName)
  registeredCallbacks[eventName] = nil
end

function RPC:trigger(eventName, ...)
  local p = promise.new()
  local hasTimedOut = false

  local args = {...}

  local uniqId = getUUID()

  local listenEventName = ('%s:%s'):format(eventName, uniqId)
  local timeoutTime = self.rpcTimeout

  debugPrint('Arguments')
  tPrint(args)

  if isServer then
    TriggerClientEvent(eventName, args[1], listenEventName, slice_table(args, 1))
  else
    TriggerServerEvent(eventName, listenEventName, args)
  end

  SetTimeout(timeoutTime, function()
    hasTimedOut = true
    p:reject(('RPC Trigger: %s, has timed out after waiting for response for %s'):format(eventName, tostring(timeoutTime)))
  end)
  -- Response Listener
  local ev = RegisterNetEvent(listenEventName, function(retData)
    debugPrint('Received Server Response, retData:')
    tPrint(retData)
    -- In case we get a response after timeout time
    if hasTimedOut then return end
    if retData.error then
      return p:reject(('Error occurred executing RPC event "%s", Error: %s'):format(listenEventName, retData.errorMsg))
    end
    p:resolve(retData.data)
  end)

  local promiseResp = Citizen.Await(p)

  RemoveEventHandler(ev)

  return table.unpack(promiseResp)
end

if isServer then
  local serverRPC = RPC:new({})

  serverRPC:register('niceEventName', function(data)
    debugPrint(data)
    return true, false
  end)
else
  local clientRPC = RPC:new({})

  RegisterCommand('testRPC', function()
    local res, res2 = clientRPC:trigger('niceEventName', 'woah')
    debugPrint('Returned Data:', res, res2)
  end)
end
