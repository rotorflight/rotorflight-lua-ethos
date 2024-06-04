local mspApiVersion =
{
    command = 1, -- MSP_API_VERSION
    processReply = function(self, buf)
        if #buf >= 3 then
            rf2.fc.apiVersion = buf[2] + buf[3] / 100
            print("API version: "..rf2.fc.apiVersion)
        end
    end,
    --exampleResponse = { 1, { 0, 12, 6 }, nil}
}

local mspAccCalibration =
{
    command = 205, -- MSP_ACC_CALIBRATION
    processReply = function(self, buf)
        print("Calibrated!")
    end,
    --exampleResponse = { 205, nil, nil}
}

local MspQueueController = {}

function MspQueueController.new()
    local self = {
        messageQueue = {},
        currentMessage = nil,
        lastTimeCommandSent = 0,
        retryCount = 0,
        maxRetries = 3,
        messages = {
            MSP_API_VERSION = mspApiVersion,
            MSP_ACC_CALIBRATION = mspAccCalibration
        }
    }

    function self:isProcessed()
        return not self.currentMessage and #self.messageQueue == 0
    end

    function self:processQueue()
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
                rf2.protocol.mspRead(self.currentMessage.command)
            end
            self.lastTimeCommandSent = getTime()
            self.retryCount = self.retryCount + 1
        end

        mspProcessTxQ()
        local cmd, buf, err = mspPollReply()

        --[[
        local returnExampleTuple = function(table) return table[1], table[2], table[3] end
        local cmd, buf, err = returnExampleTuple(self.currentMessage.exampleResponse)
        --]]

        if (cmd == self.currentMessage.command and not err) or (self.currentMessage.command == 68 and self.retryCount == 2) then
            if self.currentMessage.processReply then
                self.currentMessage:processReply(buf)
            end
            self.currentMessage = nil
        elseif self.retryCount == self.maxRetries then
            self.currentMessage = nil
        end
    end

    function self:add(message)
        table.insert(self.messageQueue, self.messages[message])
        return self
    end

    function self:addCustom(message)
        table.insert(self.messageQueue, message)
        return self
    end

    return self
end

return MspQueueController.new()

--[[
local mspCustom =
{
    command = 111,
    processReply = function(self, buf)
        print("Do something with the response!")
    end,
    exampleResponse = { 111, nil, nil}
}

local myMspQueue = MspQueueController.new()
myMspQueue
  :add("MSP_API_VERSION")
  :add("MSP_ACC_CALIBRATION")
  :addCustom(mspCustom)

while not myMspQueue:isProcessed() do end
--]]

