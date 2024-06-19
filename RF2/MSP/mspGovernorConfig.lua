local function getGovernorConfig(callback, callbackParam)
    local message = {
        command = 142, -- MSP_GOVERNOR_CONFIG
        processReply = function(self, buf)
            local config = {}
            print("buf length: "..#buf)
            config.gov_mode = rf2.mspHelper.readU8(buf)
            config.gov_startup_time = rf2.mspHelper.readU16(buf)
            config.gov_spoolup_time = rf2.mspHelper.readU16(buf)
            config.gov_tracking_time = rf2.mspHelper.readU16(buf)
            config.gov_recovery_time = rf2.mspHelper.readU16(buf)
            config.gov_zero_throttle_timeout = rf2.mspHelper.readU16(buf)
            config.gov_lost_headspeed_timeout = rf2.mspHelper.readU16(buf)
            config.gov_autorotation_timeout = rf2.mspHelper.readU16(buf)
            config.gov_autorotation_bailout_time = rf2.mspHelper.readU16(buf)
            config.gov_autorotation_min_entry_time = rf2.mspHelper.readU16(buf)
            config.gov_handover_throttle = rf2.mspHelper.readU8(buf)
            config.gov_pwr_filter = rf2.mspHelper.readU8(buf)
            config.gov_rpm_filter = rf2.mspHelper.readU8(buf)
            config.gov_tta_filter = rf2.mspHelper.readU8(buf)
            config.gov_ff_filter = rf2.mspHelper.readU8(buf)
            callback(callbackParam, config)
        end,
        simulatorResponse = {
            1, -- mode
            200, 0, --startup
            100, 0, --spoolup
            20, 0,  --tracking
            20, 0,  --recovery
            30, 0,  --zero throttle to
            10, 0,  --lost headspeed to
            0, 0,   --ar to
            0, 0,   --ar bailout to
            50, 0,  --ar min entry time
            20,     --gov handover
            5,      --pwr filter
            10,     --rpm filter
            0,      --tta filter
            10      --ff filter
            }
    }
    rf2.mspQueue:add(message)
end

local function setGovernorConfig(config)
    local message = {
        command = 143, -- MSP_SET_GOVERNOR_CONFIG
        payload = {}
    }
    rf2.mspHelper.writeU8(message.payload, config.gov_mode)
    rf2.mspHelper.writeU16(message.payload, config.gov_startup_time)
    rf2.mspHelper.writeU16(message.payload, config.gov_spoolup_time)
    rf2.mspHelper.writeU16(message.payload, config.gov_tracking_time)
    rf2.mspHelper.writeU16(message.payload, config.gov_recovery_time)
    rf2.mspHelper.writeU16(message.payload, config.gov_zero_throttle_timeout)
    rf2.mspHelper.writeU16(message.payload, config.gov_lost_headspeed_timeout)
    rf2.mspHelper.writeU16(message.payload, config.gov_autorotation_timeout)
    rf2.mspHelper.writeU16(message.payload, config.gov_autorotation_bailout_time)
    rf2.mspHelper.writeU16(message.payload, config.gov_autorotation_min_entry_time)
    rf2.mspHelper.writeU8(message.payload, config.gov_handover_throttle)
    rf2.mspHelper.writeU8(message.payload, config.gov_pwr_filter)
    rf2.mspHelper.writeU8(message.payload, config.gov_rpm_filter)
    rf2.mspHelper.writeU8(message.payload, config.gov_tta_filter)
    rf2.mspHelper.writeU8(message.payload, config.gov_ff_filter)
    simulatorResponse = {}
end

return {
    getGovernorConfig = getGovernorConfig,
    setGovernorConfig = setGovernorConfig
}