local config = {}
config.taskName = "RF2 ELRS Telemetry"
config.taskKey = "rf2eltm"
config.taskDir = "/scripts/rf2elrstelemetry/"

local telemetryTask = assert(loadfile(config.taskDir .. "telemetry.lua"))()

local function init()
    system.registerTask({ name = config.taskName, key = config.taskKey, wakeup = telemetryTask.run })
end

return { init = init }
