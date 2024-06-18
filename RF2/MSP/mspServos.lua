local function getServoConfigurations(callback, callbackParam)
    local message = {
        command = 120, -- MSP_SERVO_CONFIGURATIONS
        processReply = function(self, buf)
            local servosCount = rf2.mspHelper.readU8(buf)
            print("Servo count "..tostring(servosCount))
            local configs = {}
            for i = 0, servosCount-1 do
                local config = {}
                config.mid = rf2.mspHelper.readU16(buf)
                config.min = rf2.mspHelper.readS16(buf)
                config.max = rf2.mspHelper.readS16(buf)
                config.scaleNeg = rf2.mspHelper.readU16(buf)
                config.scalePos = rf2.mspHelper.readU16(buf)
                config.rate = rf2.mspHelper.readU16(buf)
                config.speed = rf2.mspHelper.readU16(buf)
                config.flags = rf2.mspHelper.readU16(buf)
                configs[i] = config
            end
            callback(callbackParam, configs)
        end,
        simulatorResponse = { 120, { 2,
            220, 5, 68, 253, 188, 2, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0,
            221, 5, 68, 253, 188, 2, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0 } }
    }
    rf2.mspQueue:add(message)
end

local function setServoConfiguration(servoIndex, servoConfig)
    local message = {
        command = 212, -- MSP_SET_SERVO_CONFIGURATION
        payload = {}
    }
    rf2.mspHelper.writeU8(message.payload, servoIndex)
    rf2.mspHelper.writeU16(message.payload, servoConfig.mid)
    rf2.mspHelper.writeU16(message.payload, servoConfig.min)
    rf2.mspHelper.writeU16(message.payload, servoConfig.max)
    rf2.mspHelper.writeU16(message.payload, servoConfig.scaleNeg)
    rf2.mspHelper.writeU16(message.payload, servoConfig.scalePos)
    rf2.mspHelper.writeU16(message.payload, servoConfig.rate)
    rf2.mspHelper.writeU16(message.payload, servoConfig.speed)
    rf2.mspHelper.writeU16(message.payload, servoConfig.flags)
    rf2.mspQueue:add(message)
end

local function disableServoOverride(servoIndex)
    local message = {
        command = 193, -- MSP_SET_SERVO_OVERRIDE
        payload = { servoIndex }
    }
    rf2.mspHelper.writeU16(message.payload, 2001)
    rf2.mspQueue:add(message)
end

local function enableServoOverride(servoIndex)
    local message = {
        command = 193, -- MSP_SET_SERVO_OVERRIDE
        payload = { servoIndex }
    }
    rf2.mspHelper.writeU16(message.payload, 0)
    rf2.mspQueue:add(message)
end

return {
    enableServoOverride = enableServoOverride,
    disableServoOverride = disableServoOverride,
    getServoConfigurations = getServoConfigurations,
    setServoConfiguration = setServoConfiguration
}