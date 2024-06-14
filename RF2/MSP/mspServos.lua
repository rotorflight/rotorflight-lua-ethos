local loadServoConfigurationsMessage =
{
    command = 120, -- MSP_SERVO_CONFIGURATIONS
    processReply = function(self, buf)
        local servosCount = rf2.mspHelper.readU8(buf)
        print("Servo count "..tostring(servosCount))
        local configs = {}
        for i = 0, servosCount-1 do
            local config = {}
            config.mid = rf2.mspHelper.readU16(buf)
            config.min = rf2.mspHelper.readI16(buf)
            config.max = rf2.mspHelper.readI16(buf)
            config.scaleNeg = rf2.mspHelper.readU16(buf)
            config.scalePos = rf2.mspHelper.readU16(buf)
            config.rate = rf2.mspHelper.readU16(buf)
            config.speed = rf2.mspHelper.readU16(buf)
            config.flags = rf2.mspHelper.readU16(buf)
            configs[i] = config
        end
        self.reply = configs
    end,
}

local setServoConfigurationMessage = {
    command = 212, -- MSP_SET_SERVO_CONFIGURATION
    prepareRequest = function(self, servoIndex, servoConfig)
        self.payload = {}
        rf2.mspHelper.writeU8(self.payload, servoIndex)
        rf2.mspHelper.writeU16(self.payload, servoConfig.mid)
        rf2.mspHelper.writeU16(self.payload, servoConfig.min)
        rf2.mspHelper.writeU16(self.payload, servoConfig.max)
        rf2.mspHelper.writeU16(self.payload, servoConfig.scaleNeg)
        rf2.mspHelper.writeU16(self.payload, servoConfig.scalePos)
        rf2.mspHelper.writeU16(self.payload, servoConfig.rate)
        rf2.mspHelper.writeU16(self.payload, servoConfig.speed)
        rf2.mspHelper.writeU16(self.payload, servoConfig.flags)
    end,
}

return {
    getServoConfigurations = function(callbackParam, callback)
        rf2.mspQueue:add(loadServoConfigurationsMessage, callback, callbackParam)
    end,
    setServoConfiguration = function(index, config)
        setServoConfigurationMessage.prepareRequest(setServoConfigurationMessage, index, config)
        rf2.mspQueue:add(setServoConfigurationMessage)
    end
}