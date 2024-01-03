local supportedProtocols =
{
    smartPort =
    {
        mspTransport    = "/scripts/RF2/MSP/sp.lua",
        push            = sportTelemetryPush,
        maxTxBufferSize = 6,
        maxRxBufferSize = 6,
        saveMaxRetries  = 3,      -- originally 2
        saveTimeout     = 5.0,
        pageReqTimeout  = 0.8,
    },
    crsf =
    {
        mspTransport    = "/scripts/RF2/MSP/crsf.lua",
        maxTxBufferSize = 8,
        maxRxBufferSize = 58,
        saveMaxRetries  = 2,
        saveTimeout     = 1.5,
        pageReqTimeout  = 0.8,
    }
}

local function getProtocol()
    if system.getSource("Rx RSSI1") ~= nil then
        return supportedProtocols.crsf
    end
    return supportedProtocols.smartPort
end

return getProtocol()