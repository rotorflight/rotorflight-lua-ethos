local function getProtocol()
    if system.getSource("Rx RSSI1") ~= nil then
        return "crsf"
    end
    return "sp"
end

return getProtocol()