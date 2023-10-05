local PageFiles = {}

-- Rotorflight pages.
PageFiles[#PageFiles + 1] = { title = "PIDs", script = "pids.lua" }
PageFiles[#PageFiles + 1] = { title = "Profile", script = "profile.lua" }
PageFiles[#PageFiles + 1] = { title = "Rates", script = "ratesrf.lua" }
PageFiles[#PageFiles + 1] = { title = "Copy Profiles", script = "copy_profiles.lua" }
PageFiles[#PageFiles + 1] = { title = "Governor", script = "governor.lua" }
PageFiles[#PageFiles + 1] = { title = "Filters", script = "filters.lua" }
PageFiles[#PageFiles + 1] = { title = "Accelerometer Trim", script = "accelerometer.lua" }
PageFiles[#PageFiles + 1] = { title = "Receiver", script = "rxrf.lua" }
PageFiles[#PageFiles + 1] = { title = "Failsafe", script = "failsafe.lua" }
PageFiles[#PageFiles + 1] = { title = "Motors", script = "motors.lua" }

return PageFiles
