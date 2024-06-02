rf2.mspController:add("MSP_API_VERSION")
--rf2.mspController:add("MSP_ACC_CALIBRATION")

return { f = function() return rf2.mspController:isReady() end, t = "Waiting for API version" }
