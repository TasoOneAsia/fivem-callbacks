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
    local success, ret = pcall({fn(...)})

    if not success then
      retObj.error = true
      retObj.errorMsg = ret
    else
      retObj.data = ret
    end

    if isServer then
      TriggerServerEvent(respEventName, retObj)
    else
      TriggerClientEvent(respEventName, src, retObj)
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

  if isServer then
    TriggerClientEvent(eventName, args[1], listenEventName, slice_table(args, 1))
  else
    TriggerServerEvent(eventName, listenEventName, args)
  end

  SetTimeout(timeoutTime, function()
    hasTimedOut = true
    p.reject(('RPC Trigger: %s, has timed out after waiting for response for %'):format(eventName, tostring(timeoutTime)))
  end)
  -- Response Listener
  local ev = RegisterNetEvent(listenEventName, function(retData)
    if hasTimedOut then return end
    if retData.error then
      p.reject(('Error occurred executing RPC event "%s", Error: %s'):format(listenEventName, retData.errorMsg))
    end
    p.resolve(table.unpack(retData.data))
  end)

  local promiseResp = Citizen.Await(p)
  local respCopy = clone_table(promiseResp)

  RemoveEventHandler(ev)

  return table.unpack(respCopy)
end
