local function getStatus(callback, callbackParam)
    local message = {
        command = 101, -- MSP_STATUS
        processReply = function(self, buf)
            local status = {}
            buf.offset = 18
            status.armingDisableFlags = rf2.mspHelper.readU32(buf)
            --print("Arming disable flags: "..tostring(status.armingDisableFlags))
            buf.offset = 24
            status.profile = rf2.mspHelper.readU8(buf)
            --print("Profile: "..tostring(status.profile))
            status.numProfiles = rf2.mspHelper.readU8(buf)
            status.rateProfile = rf2.mspHelper.readU8(buf)
            status.numRateProfiles = rf2.mspHelper.readU8(buf)
            status.motorCount = rf2.mspHelper.readU8(buf)
            --print("Number of motors: "..tostring(status.motorCount))
            status.servoCount = rf2.mspHelper.readU8(buf)
            --print("Number of servos: "..tostring(status.servoCount))
            callback(callbackParam, status)
        end,
        simulatorResponse = { 240, 1, 124, 0, 35, 0, 0, 0, 0, 0, 0, 224, 1, 10, 1, 0, 26, 0, 0, 0, 0, 0, 2, 0, 6, 0, 6, 1, 4, 1 }
    }

    rf2.mspQueue:add(message)
end

return {
    getStatus = getStatus
}