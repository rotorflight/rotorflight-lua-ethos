rf2.mspController:add("MSP_ACC_CALIBRATION")

return { f = function() return rf2.mspController:isReady() end, t = "Calibrating Accelerometer" }
