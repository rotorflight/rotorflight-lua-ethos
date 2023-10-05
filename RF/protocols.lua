local supportedProtocols =
{
    smartPort =
    {
        mspTransport    = "/scripts/RF/MSP/sp.lua",
        push            = sportTelemetryPush,
        maxTxBufferSize = 6,
        maxRxBufferSize = 6,
        saveMaxRetries  = 3,      -- originally 2
        saveTimeout     = 5.0,
        pageReqTimeout  = 0.8,
    }
}

return supportedProtocols.smartPort
