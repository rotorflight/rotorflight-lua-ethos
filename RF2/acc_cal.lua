local MSP_ACC_CALIBRATION = 205
local accCalibrated = false
local lastRunTS = 0
local INTERVAL = 500

local function processMspReply(cmd,rx_buf,err)
    if cmd == MSP_ACC_CALIBRATION and not err then
        accCalibrated = true
    end
end

local function accCal()
    if not accCalibrated and (lastRunTS == 0 or lastRunTS + INTERVAL < getTime()) then
        protocol.mspRead(MSP_ACC_CALIBRATION)
        lastRunTS = getTime()
    end

    mspProcessTxQ()
    processMspReply(mspPollReply())
    return accCalibrated
end

return { f = accCal, t = "Calibrating Accelerometer" }
