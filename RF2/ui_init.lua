local mspApiVersion = rf2.useApi("mspApiVersion")
local returnTable = { f = nil, t = "" }
local apiVersion
local lastRunTS

local function version_ge(a, b)
    local function split(v)
        local t = {}
        for part in tostring(v):gmatch("(%d+)") do t[#t + 1] = tonumber(part) end
        return t
    end
    local A, B = split(a), split(b)
    local len = math.max(#A, #B)
    for i = 1, len do
        local ai = A[i] or 0
        local bi = B[i] or 0
        if ai < bi then return false end
        if ai > bi then return true end
    end
    return true
end

local function init()
    if rf2.getRSSI() == 0 and not rf2.runningInSimulator then
        returnTable.t = "Waiting for connection"
        return false
    end

    if not apiVersion and (not lastRunTS or lastRunTS + 2 < rf2.clock()) then
        returnTable.t = "Waiting for API version"
        mspApiVersion.getApiVersion(function(_, version) apiVersion = version end)
        lastRunTS = rf2.clock()
    end

    rf2.mspQueue:processQueue()

    if rf2.mspQueue:isProcessed() and apiVersion then
        local apiVersionAsString = string.format("%.2f", apiVersion)
        if apiVersion < 12.06 then
            returnTable.t = "This version of the Lua\nscripts can't be used\nwith the selected model\nwhich has version "..apiVersionAsString.."."
        else
            -- received correct API version, proceed
            rf2.apiVersion = apiVersion
            local wantProto = 1
            if rf2.mspV2MinApiVersion and version_ge(apiVersionAsString, rf2.mspV2MinApiVersion) then
                wantProto = 2
            end
            if rf2.mspProtocolVersion ~= wantProto then
                rf2.mspProtocolVersion = wantProto
                if rf2.mspSetProtocolVersion then
                    rf2.mspSetProtocolVersion(wantProto)
                end
                --if rf2.print then
                --    rf2.print("MSP protocol set to v%d (api %s)", wantProto, apiVersionAsString)
                --end
                 print("MSP protocol set to v%d (api %s)", wantProto, apiVersionAsString)
            end
            collectgarbage()
            return true
        end
    end

    return false
end

returnTable.f = init

return returnTable
