-- MspQueueController class
local MspQueueController = {}
MspQueueController.__index = MspQueueController

function MspQueueController.new()
    local self = setmetatable({}, MspQueueController)
    self.messageQueue = {}
    self.currentMessage = nil
    self.lastTimeCommandSent = 0
    self.retryCount = 0
    self.maxRetries = 3
    return self
end

function MspQueueController:isProcessed()
    return not self.currentMessage and #self.messageQueue == 0
end

function MspQueueController:processQueue()
    if self:isProcessed() then
        return
    end

    if not self.currentMessage then
        self.currentMessage = table.remove(self.messageQueue, 1)
        self.retryCount = 0
    end

    if self.lastTimeCommandSent == 0 or self.lastTimeCommandSent + 50 < rf2.getTime() then
        if self.currentMessage.payload then
            rf2.protocol.mspWrite(self.currentMessage.command, self.currentMessage.payload)
        else
            rf2.protocol.mspWrite(self.currentMessage.command, {})
        end
        self.lastTimeCommandSent = getTime()
        self.retryCount = self.retryCount + 1
    end

    mspProcessTxQ()
    local cmd, buf, err = mspPollReply()
    if cmd then print("Received cmd: "..tostring(cmd)) end

    --[[
    local returnExampleTuple = function(table) return table[1], table[2], table[3] end
    local cmd, buf, err = returnExampleTuple(self.currentMessage.exampleResponse)
    --]]

    if (cmd == self.currentMessage.command and not err) or (self.currentMessage.command == 68 and self.retryCount == 2) then -- 68 = MSP_REBOOT
        if self.currentMessage.processReply then
            self.currentMessage:processReply(buf)
        end
        self.currentMessage = nil
    elseif self.retryCount == self.maxRetries then
        self.currentMessage = nil
    end
end

local function deepCopy(original)
    local copy
    if type(original) == "table" then
        copy = {}
        for key, value in next, original, nil do
            copy[deepCopy(key)] = deepCopy(value)
        end
        setmetatable(copy, deepCopy(getmetatable(original)))
    else -- number, string, boolean, etc
        copy = original
    end
    return copy
end

function MspQueueController:add(message)
    message = deepCopy(message)
    table.insert(self.messageQueue, message)
    return self
end

return MspQueueController.new()

-- Usage example

--[[
local mspCustomMessage =
{
    command = 111,
    processReply = nil,
    onProcessed = function(self, buf)
        print("Do something with the response!")
    end,
    exampleResponse = { 111, nil, nil}
}

local myMspQueue = MspQueueController.new()
myMspQueue
  :add("MSP_API_VERSION")
  :add("MSP_ACC_CALIBRATION")
  :add(mspCustomMessage)

while not myMspQueue:isProcessed() do
    myMspQueue:processQueue()
end
--]]