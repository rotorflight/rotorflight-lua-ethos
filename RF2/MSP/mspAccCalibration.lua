local function calibrate(callback, callbackParam)
    local message =
    {
        command = 205, -- MSP_ACC_CALIBRATION
        processReply = function(self, buf)
            print("Accelerometer calibrated.")
        end,
    }
    rf2.mspQueue:add(message)
end

return {
    calibrate = calibrate
}