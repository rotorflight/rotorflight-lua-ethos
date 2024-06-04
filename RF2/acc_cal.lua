rf2.mspQueue:add("MSP_ACC_CALIBRATION")

return { f = function() return rf2.mspQueue:isProcessed() end, t = "Calibrating Accelerometer" }
