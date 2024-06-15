rf2.mspHelper = {
    readU8 = function(buf)
        local offset = buf.offset or 1
        local value = buf[offset]
        buf.offset = offset + 1
        return value
    end,
    readU16 = function(buf)
        local offset = buf.offset or 1
        local value = buf[offset]
        value = value | buf[offset + 1] << 8
        buf.offset = offset + 2
        return value
    end,
    readI16 = function(buf)
        local offset = buf.offset or 1
        local value = buf[offset]
        value = value | buf[offset + 1] << 8
        if value & (1 << 15) ~= 0 then value = value - (2 ^ 16) end
        buf.offset = offset + 2
        return value
    end,
    readU32 = function(buf)
        local offset = buf.offset or 1
        local value = 0
        for i = 0, 3 do
            value = value | buf[offset + i] << (i * 8)
        end
        buf.offset = offset + 2
        return value
    end,
    writeU8 = function(buf, value)
        local byte1 = value & 0xFF
        table.insert(buf, byte1)
    end,
    writeU16 = function(buf, value)
        local byte1 = value & 0xFF
        local byte2 = (value >> 8) & 0xFF
        table.insert(buf, byte1)
        table.insert(buf, byte2)
    end,
    writeU32 = function(buf, value)
        local byte1 = value & 0xFF
        local byte2 = (value >> 8) & 0xFF
        local byte3 = (value >> 16) & 0xFF
        local byte4 = (value >> 24) & 0xFF
        table.insert(buf, byte1)
        table.insert(buf, byte2)
        table.insert(buf, byte3)
        table.insert(buf, byte4)
    end,
}

local mspStatus =
{
    command = 101, -- MSP_STATUS
    processReply = function(self, buf)
        buf.offset = 18
        rf2.FC.CONFIG.armingDisableFlags = rf2.mspHelper.readU32(buf)
        print("Arming disable flags: "..tostring(rf2.FC.CONFIG.armingDisableFlags))
        buf.offset = 24
        rf2.FC.CONFIG.profile = rf2.mspHelper.readU8(buf)
        rf2.FC.CONFIG.numProfiles = rf2.mspHelper.readU8(buf)
        rf2.FC.CONFIG.rateProfile = rf2.mspHelper.readU8(buf)
        rf2.FC.CONFIG.numRateProfiles = rf2.mspHelper.readU8(buf)
        rf2.FC.CONFIG.motorCount = rf2.mspHelper.readU8(buf)
        print("Number of motors: "..tostring(rf2.FC.CONFIG.motorCount))
        rf2.FC.CONFIG.servoCount = rf2.mspHelper.readU8(buf)
        print("Number of servos: "..tostring(rf2.FC.CONFIG.servoCount))
    end,
}

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
    self.messages = {
        MSP_STATUS = mspStatus,
        MSP_ACC_CALIBRATION = mspAccCalibration,
    }
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

    -- 68 = MSP_REBOOT
    if (cmd == self.currentMessage.command and not err) or (self.currentMessage.command == 68 and self.retryCount == 2) then
        if self.currentMessage.processReply then
            self.currentMessage:processReply(buf)
        end
        --if self.currentMessage.onProcessed then
        --    self.currentMessage:onProcessed(self.currentMessage.onProcessedParameter)
        --end
        self.currentMessage = nil
    elseif self.retryCount == self.maxRetries then
        self.currentMessage = nil
    end
end

-- onProcessed and onProcessedParameter are optional parameters
function MspQueueController:add(message, onProcessed, onProcessedParameter)
    if type(message) == "string" then
        message = self.messages[message]
    else
        message = deepCopy(message)
    end

    if onProcessed then
        message.onProcessed = onProcessed
        message.onProcessedParameter = onProcessedParameter
    end

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