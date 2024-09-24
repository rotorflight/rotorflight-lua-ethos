local supportedProtocols =
{
    smartPort =
    {
        mspTransport    = "MSP/sp.lua",
        push            = rf2.sportTelemetryPush,
        maxTxBufferSize = 6,
        maxRxBufferSize = 6,
        maxRetries      = 3,
        saveTimeout     = 5.0,
        pageReqTimeout  = 3,
    },
    crsf =
    {
        mspTransport    = "MSP/crsf.lua",
        maxTxBufferSize = 8,
        maxRxBufferSize = 58,
        maxRetries      = 3,
        saveTimeout     = 3.0,
        pageReqTimeout  = 3,
    }
}

local function getProtocol()
    if system.getSource("Rx RSSI1") ~= nil then
        return supportedProtocols.crsf
    end
    return supportedProtocols.smartPort
end

return getProtocol()