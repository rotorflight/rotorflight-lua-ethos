local mspAccCalibration = assert(rf2.loadScript("/scripts/RF2/MSP/mspAccCalibration.lua"))()

mspAccCalibration.calibrate()

return { f = function() return rf2.mspQueue:isProcessed() end, t = "Calibrating Accelerometer" }
