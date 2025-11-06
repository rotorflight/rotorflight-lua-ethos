-- Protocol version
local MSP_VERSION = bit32.lshift(1,5)
local MSP_STARTFLAG = bit32.lshift(1,4)

-- Sequence number for next MSP packet
local mspSeq = 0
local mspRemoteSeq = 0
local mspRxBuf = {}
local mspRxError = false
local mspRxSize = 0
local mspRxCRC = 0
local mspRxReq = 0
local mspStarted = false
local mspLastReq = 0
local mspTxBuf = {}
local mspTxIdx = 1
local mspTxCRC = 0

-- merged v1/v2
local mspVersion = 1 -- 1 or 2

local common = {}

function common.setProtocolVersion(v)
    v = tonumber(v)
    mspVersion = (v == 2) and 2 or 1
end

function common.getProtocolVersion()
    return mspVersion
end

function common.mspProcessTxQ()
    if (#(mspTxBuf) == 0) then
        return false
    end
    local payload = {}
    local versionBits = (mspVersion == 2) and bit32.lshift(2,5) or MSP_VERSION
    payload[1] = mspSeq + versionBits
    mspSeq = bit32.band(mspSeq + 1, 0x0F)
    if mspTxIdx == 1 then
        payload[1] = payload[1] + MSP_STARTFLAG
    end
    local i = 2
    while (i <= rf2.protocol.maxTxBufferSize) and mspTxIdx <= #mspTxBuf do
        payload[i] = mspTxBuf[mspTxIdx]
        mspTxIdx = mspTxIdx + 1
        if mspVersion == 1 then mspTxCRC = bit32.bxor(mspTxCRC,payload[i]) end
        i = i + 1
    end
    if mspVersion == 1 then
        if i <= rf2.protocol.maxTxBufferSize then
            payload[i] = mspTxCRC; i = i + 1
            while i <= rf2.protocol.maxTxBufferSize do payload[i] = 0; i = i + 1 end
            rf2.protocol.mspSend(payload)
            mspTxBuf = {}; mspTxIdx = 1; mspTxCRC = 0
            return false
        end
        rf2.protocol.mspSend(payload)
        return true
    else
        while i <= rf2.protocol.maxTxBufferSize do payload[i] = payload[i] or 0; i = i + 1 end
        rf2.protocol.mspSend(payload)
        if mspTxIdx > #mspTxBuf then mspTxBuf = {}; mspTxIdx = 1; mspTxCRC = 0; return false end
        return true
    end
end

function common.mspSendRequest(cmd, payload)
    if #(mspTxBuf) ~= 0 or not cmd then
        return nil
    end
    if mspVersion == 1 then
        mspTxBuf[1] = #(payload)
        mspTxBuf[2] = bit32.band(cmd,0xFF)
        for i=1,#(payload) do mspTxBuf[i+2] = bit32.band(payload[i],0xFF) end
    else
        local len = #(payload)
        local cmd1 = cmd % 256
        local cmd2 = math.floor(cmd / 256) % 256
        local len1 = len % 256
        local len2 = math.floor(len / 256) % 256
        mspTxBuf = {0, cmd1, cmd2, len1, len2}
        for i=1,len do mspTxBuf[#mspTxBuf+1] = (payload[i] or 0) % 256 end
    end
    mspLastReq = cmd
    return common.mspProcessTxQ()
end

local function mspReceivedReply(payload)
    local idx = 1
    local status = payload[idx]
    local version = bit32.rshift(bit32.band(status, 0x60), 5)
    local start = bit32.btest(status, 0x10)
    local seq = bit32.band(status, 0x0F)
    idx = idx + 1
    if start then
        mspRxBuf = {}
        mspRxError = bit32.btest(status, 0x80)
        if mspVersion == 2 then
            local flags = payload[idx] or 0; idx = idx + 1
            local cmd1  = payload[idx] or 0; idx = idx + 1
            local cmd2  = payload[idx] or 0; idx = idx + 1
            local len1  = payload[idx] or 0; idx = idx + 1
            local len2  = payload[idx] or 0; idx = idx + 1
            mspRxReq  = bit32.bor(bit32.lshift(bit32.band(cmd2, 0xFF), 8), bit32.band(cmd1, 0xFF))
            mspRxSize = bit32.band(bit32.bor(bit32.lshift(bit32.band(len2, 0xFF), 8), bit32.band(len1, 0xFF)), 0xFFFF)
            mspRxCRC  = 0
            mspStarted= (mspRxReq == mspLastReq)
        else
            mspRxSize = payload[idx]
            mspRxReq  = mspLastReq
            idx = idx + 1
            if version == 1 then mspRxReq = payload[idx]; idx = idx + 1 end
            mspRxCRC = bit32.bxor(mspRxSize, mspRxReq)
            if mspRxReq == mspLastReq then mspStarted = true end
        end
    elseif not mspStarted then
        return nil
    elseif bit32.band(mspRemoteSeq + 1, 0x0F) ~= seq then
        mspStarted = false
        return nil
    end
    while (idx <= rf2.protocol.maxRxBufferSize) and (#mspRxBuf < mspRxSize) do
        mspRxBuf[#mspRxBuf + 1] = payload[idx]
        if mspVersion == 1 then mspRxCRC = bit32.bxor(mspRxCRC, payload[idx]) end
        idx = idx + 1
    end
    if #mspRxBuf < mspRxSize then
        mspRemoteSeq = seq
        return false
    end
    mspStarted = false
    if mspVersion == 1 and mspRxCRC ~= payload[idx] and version == 0 then
        return nil
    end
    return true
end

function common.mspPollReply()
    local startTime = rf2.clock()
    while (rf2.clock() - startTime < 0.05) do
        local mspData = rf2.protocol.mspPoll()
        if mspData ~= nil and mspReceivedReply(mspData) then
            mspLastReq = 0
            return mspRxReq, mspRxBuf, mspRxError
        end
    end
end

function common.mspClearTxBuf()
    mspTxBuf = {}
end

return common
