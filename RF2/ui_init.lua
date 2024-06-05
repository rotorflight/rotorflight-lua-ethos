local returnTable = { f = nil, t = "" }
local SUPPORTED_API_VERSION = "12.06" -- see main/msp/msp_protocol.h

local function init()
    --if true then return true end
    if rf2.getRSSI() == 0 then
        returnTable.t = "Waiting for connection"
        return false
    end

    if returnTable.t ~= "Waiting for API version" then
        returnTable.t = "Waiting for API version"
        rf2.mspQueue:add("MSP_API_VERSION")
    end

    rf2.mspQueue:processQueue()

    if rf2.mspQueue:isProcessed() then
        if tostring(rf2.FC.CONFIG.apiVersion) ~= SUPPORTED_API_VERSION then -- work-around for comparing floats
            returnTable.t = "This version of the Lua scripts ("..SUPPORTED_API_VERSION..")\ncan't be used with the selected model ("..tostring(rf2.FC.CONFIG.apiVersion)..")."
        else
            -- received correct API version, proceed
            return true
        end
    end

    return false
end

returnTable.f = init

return returnTable
