-- All RF2 globals should be stored in the rf2 table, to avoid conflict with globals from other scripts.
rf2 = {
    luaVersion = "2.3.0-RC3",
    baseDir = "./",
    runningInSimulator = system:getVersion().simulation,

    sportTelemetryPop = function()
        -- Pops a received SPORT packet from the queue. Please note that only packets using a data ID within 0x5000 to 0x50FF (frame ID == 0x10), as well as packets with a frame ID equal 0x32 (regardless of the data ID) will be passed to the Lua telemetry receive queue.
        local frame = rf2.sensor:popFrame()
        if frame == nil then
            return nil, nil, nil, nil
        end
        -- physId = physical / remote sensor Id (aka sensorId)
        --   0x00 for FPORT, 0x1B for SmartPort
        -- primId = frame ID  (should be 0x32 for reply frames)
        -- appId = data Id
        return frame:physId(), frame:primId(), frame:appId(), frame:value()
    end,

    sportTelemetryPush = function(sensorId, frameId, dataId, value)
        -- OpenTX:
        -- When called without parameters, it will only return the status of the output buffer without sending anything.
        --   Equivalent in Ethos may be:   sensor:idle() ???
        -- @param sensorId  physical sensor ID
        -- @param frameId   frame ID
        -- @param dataId    data ID
        -- @param value     value
        -- @retval boolean  data queued in output buffer or not.
        -- @retval nil      incorrect telemetry protocol.  (added in 2.3.4)
        return rf2.sensor:pushFrame({physId=sensorId, primId=frameId, appId=dataId, value=value})
    end,

    getRSSI = function()
        if rf2.runningInSimulator then return 100 end
        if rf2.rssiSensor ~= nil then return rf2.rssiSensor:value() end
        return 0
    end,

    startsWith = function(str, prefix)
        if #prefix > #str then return false end
        for i = 1, #prefix do
            if str:byte(i) ~= prefix:byte(i) then
                return false
            end
        end
        return true
    end,

    endsWith = function(str, postfix)
        if #postfix > #str then return false end
        for i = 1, #postfix do
            if str:byte(#str - #postfix + i) ~= postfix:byte(i) then
                return false
            end
        end
        return true
    end,

    loadScript = function(script)
        --rf2.print("Loading script %s", script)
        if not rf2.startsWith(script, rf2.baseDir) then
            script = rf2.baseDir .. script
        end
        if not rf2.endsWith(script, ".lua") then
            script = script .. ".lua"
        end
        -- loadScript also works on 1.5.9, but is undocumented (?)
        return loadfile(script)
    end,

    executeScript = function(scriptName, ...)
        return assert(rf2.loadScript(scriptName), scriptName)(...)
    end,

    useApi = function(apiName)
        return rf2.executeScript("MSP/" .. apiName)
    end,

    loadSettings = function()
        return rf2.executeScript("PAGES/helpers/settingsHelper").loadSettings();
    end,

    saveSettings = function(settings)
        return rf2.executeScript("PAGES/helpers/settingsHelper").saveSettings(settings);
    end,

    clock = os.clock,

    apiVersion = nil,

    units = {
        percentage = "%",
        degrees = "°",
        degreesPerSecond = "°/s",
        herz = " Hz",
        seconds = " s",
        milliseconds = " ms",
        volt = " V",
        celsius = " C",
        rpm = " RPM",
        meters = " m",
        mah = " mAh"
    },

    formatTime = function(cs)
        local hours = math.floor(cs / 360000)
        cs = cs % 360000

        local minutes = math.floor(cs / 6000)
        cs = cs % 6000

        local seconds = math.floor(cs / 100)
        local centis = math.floor(cs % 100)

        return string.format("%02d:%02d:%02d:%02d", hours, minutes, seconds, centis)
    end,

    print = function(format, ...)
        local str = string.format("%s - RF2: " .. tostring(format), rf2.formatTime(os.clock() * 100), ...)
        if rf2.runningInSimulator then
            print(str)
        else
            --print(str) -- Ethos outputs print to serial
            --rf2.log(str)
        end
    end,

    log = function(str)
        if rf2.runningInSimulator then
            rf2.print(tostring(str))
        else
            if not rf2.logfile then
                rf2.logfile = io.open("/rf2.log", "a")
            end
            io.write(rf2.logfile, string.format("%.2f ", rf2.clock()) .. tostring(str) .. "\n")
        end
    end,

    getWindowSize = function()
        return lcd.getWindowSize()
        --return 784, 406
        --return 472, 288
        --return 472, 240
    end,
    
    call = function(func, ...)
        -- Use unprotected calls during development, so errors surface immediately.
        --func(...)

        -- Or use protected calls and show any errors afterwards.
        local status, err = pcall(func, ...)
        if not status then rf2.print(err) end
    end
}
