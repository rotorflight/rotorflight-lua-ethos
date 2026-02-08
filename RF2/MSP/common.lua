-- Usage: local mspSendRequest, mspProcessTxQ, mspPollReply, mspClearTxBuf = rf2.executeScript("MSP/common")

local mspSeq = 0 -- Sequence number for next MSP packet
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

local protocolScript = "MSP/" .. rf2.executeScript("protocols")
local mspSend, mspPoll, telemetryPush, maxTxBufferSize, maxRxBufferSize = rf2.executeScript(protocolScript)

local MSP_VERSION_BIT = bit32.lshift(1, 5)
local MSP_STARTFLAG = bit32.lshift(1, 4)

local _mspVersion = (rf2 and rf2.mspProtocolVersion == 2) and 2 or 1

local function setProtocolVersion(v)
    v = tonumber(v)
    _mspVersion = (v == 2) and 2 or 1
    if rf2 then rf2.mspProtocolVersion = _mspVersion end
end

local function getProtocolVersion()
    return _mspVersion
end

if rf2 then
    rf2.mspSetProtocolVersion = setProtocolVersion
    rf2.mspGetProtocolVersion = getProtocolVersion
end

local function mkStatusByte(isStart)
    local versionBits = (_mspVersion == 2) and bit32.lshift(2, 5) or MSP_VERSION_BIT
    local status = mspSeq + versionBits
    if isStart then status = status + MSP_STARTFLAG end
    return bit32.band(status, 0x7F)
end

local function mspProcessTxQ()
    if (#(mspTxBuf) == 0) then
        return false
    end
    -- if not sensor:idle() then  -- was protocol.push() -- maybe sensor:idle()  here??
        -- rf2.print("Sensor not idle... waiting to send cmd: "..tostring(mspLastReq))
        -- return true
    -- end
    --rf2.print("Sending mspTxBuf size "..tostring(#mspTxBuf).." at Idx "..tostring(mspTxIdx).." for cmd: "..tostring(mspLastReq))
    local payload = {}
    payload[1] = mkStatusByte(mspTxIdx == 1)
    mspSeq = bit32.band(mspSeq + 1, 0x0F)
    local i = 2
    while (i <= maxTxBufferSize) and mspTxIdx <= #mspTxBuf do
        payload[i] = mspTxBuf[mspTxIdx]
        mspTxIdx = mspTxIdx + 1
        if _mspVersion == 1 then
            mspTxCRC = bit32.bxor(mspTxCRC, payload[i])
        end
        i = i + 1
    end

    if _mspVersion == 1 then
        if i <= maxTxBufferSize then
            payload[i] = mspTxCRC
            i = i + 1
            -- zero fill
            while i <= maxTxBufferSize do
                payload[i] = 0
                i = i + 1
            end
            mspSend(payload)
            mspTxBuf = {}
            mspTxIdx = 1
            mspTxCRC = 0
            return false
        end
        mspSend(payload)
        return true
    end

    -- MSPv2: pad unused bytes, no CRC here
    while i <= maxTxBufferSize do
        payload[i] = payload[i] or 0
        i = i + 1
    end
    mspSend(payload)
    if mspTxIdx > #mspTxBuf then
        mspTxBuf = {}
        mspTxIdx = 1
        mspTxCRC = 0
        return false
    end
    return true
end

local function mspSendRequest(cmd, payload)
    --rf2.print("Sending cmd "..cmd)
    -- busy
    if #(mspTxBuf) ~= 0 or not cmd then
        --rf2.print("Existing mspTxBuf is still being sent, failed send of cmd: "..tostring(cmd))
        return nil
    end
    if _mspVersion == 1 then
        mspTxBuf[1] = #(payload)
        mspTxBuf[2] = bit32.band(cmd, 0xFF)  -- MSP command
        for i = 1, #(payload) do
            mspTxBuf[i + 2] = bit32.band(payload[i], 0xFF)
        end
    else
        local len = #(payload)
        local cmd1 = bit32.band(cmd, 0xFF)
        local cmd2 = bit32.band(bit32.rshift(cmd, 8), 0xFF)
        local len1 = bit32.band(len, 0xFF)
        local len2 = bit32.band(bit32.rshift(len, 8), 0xFF)
        mspTxBuf = {0, cmd1, cmd2, len1, len2}
        for i = 1, len do
            mspTxBuf[#mspTxBuf + 1] = bit32.band(payload[i], 0xFF)
        end
    end
    mspLastReq = cmd
    mspTxIdx = 1
    mspTxCRC = 0
    return mspProcessTxQ()
end

local function mspReceivedReply(payload)
    --rf2.print("Starting mspReceivedReply")
    local idx = 1
    local status = payload[idx]
    local versionBits = bit32.rshift(bit32.band(status, 0x60), 5)
    local start = bit32.btest(status, 0x10)
    local seq = bit32.band(status, 0x0F)
    idx = idx + 1
    --rf2.print("payload length: "..#payload)
    --rf2.print(" msp sequence #:  "..string.format("%u",seq))
    if start then
        -- start flag set
        mspRxBuf = {}
        mspRxError = bit32.btest(status, 0x80)

        if _mspVersion == 2 then
            local flags = payload[idx] or 0; idx = idx + 1
            local cmd1 = payload[idx] or 0; idx = idx + 1
            local cmd2 = payload[idx] or 0; idx = idx + 1
            local len1 = payload[idx] or 0; idx = idx + 1
            local len2 = payload[idx] or 0; idx = idx + 1
            mspRxReq = bit32.bor(bit32.lshift(cmd2, 8), cmd1)
            mspRxSize = bit32.bor(bit32.lshift(len2, 8), len1)
            mspRxCRC = 0
            mspStarted = (mspRxReq == mspLastReq)
        else
            mspRxSize = payload[idx]
            mspRxReq = mspLastReq
            idx = idx + 1
            if versionBits == 1 then
                --rf2.print("version == 1")
                mspRxReq = payload[idx]
                idx = idx + 1
            end
            mspRxCRC = bit32.bxor(mspRxSize, mspRxReq)
            if mspRxReq == mspLastReq then
                mspStarted = true
                --rf2.print("Started cmd "..mspLastReq)
            end
        end
    else
        if not mspStarted then
            --rf2.print("  mspReceivedReply: missing Start flag")
            return nil
        elseif bit32.band(mspRemoteSeq + 1, 0x0F) ~= seq then
            mspStarted = false
            mspRxBuf = {}
            mspRxSize = 0
            mspRxCRC = 0
            mspRemoteSeq = 0
            return nil
        end
    end
    while (idx <= maxRxBufferSize) and (#mspRxBuf < mspRxSize) do
        mspRxBuf[#mspRxBuf + 1] = payload[idx]
        if _mspVersion == 1 then
            mspRxCRC = bit32.bxor(mspRxCRC, payload[idx])
        end
        idx = idx + 1
    end
    if #mspRxBuf < mspRxSize then
        --rf2.print("  mspReceivedReply:  payload continues into next frame.")
        -- Store the last sequence number so we can start there on the next continuation payload
        mspRemoteSeq = seq
        return false
    end
    mspStarted = false
    -- check CRC
    if _mspVersion == 1 then
        if mspRxCRC ~= payload[idx] and versionBits == 0 then
            --rf2.print("  mspReceivedReply:  payload checksum incorrect, message failed!")
            --rf2.print("    Calculated mspRxCRC:  0x"..string.format("%X", mspRxCRC))
            --rf2.print("    CRC from payload:     0x"..string.format("%X", payload[idx]))
            return nil
        end
    end
    --rf2.print("  Got reply for cmd "..mspRxReq)
    return true
end

local function mspPollReply()
    local now = rf2.clock
    local nonBlocking = (rf2.mspNonBlocking ~= false)
    local sliceSeconds = rf2.mspPollSliceSeconds or 0.006
    local slicePolls = rf2.mspPollSlicePolls or 4
    local budget = rf2.mspPollBudget or 0.07
    local idleCap = 0.02

    local inflight0 = mspStarted or (mspLastReq ~= 0)
    local window
    if nonBlocking then
        window = inflight0 and (sliceSeconds * 2) or sliceSeconds
    else
        window = inflight0 and budget or math.min(budget, idleCap)
    end

    local deadline = now() + window

    local MAX_NIL_IDLE = 4
    local MAX_NIL_INFLIGHT = nonBlocking and math.max(2, slicePolls) or 16
    local MAX_POLLS = nonBlocking and slicePolls or 24

    local nilPolls = 0
    local polls = 0

    while now() < deadline do
        polls = polls + 1
        if polls > MAX_POLLS then return nil end

        local mspData = mspPoll()
        if mspData == nil then
            nilPolls = nilPolls + 1
            local inflight = mspStarted or (mspLastReq ~= 0)
            local maxNil = inflight and MAX_NIL_INFLIGHT or MAX_NIL_IDLE
            if nilPolls >= maxNil then
                return nil
            end
        else
            nilPolls = 0
            if type(mspData) == "table" then
                local ok, done = pcall(mspReceivedReply, mspData)
                if ok and done then
                    mspLastReq = 0
                    return mspRxReq, mspRxBuf, mspRxError
                end
            end
        end
    end
end

local function mspClearTxBuf()
    mspTxBuf = {}
    mspTxIdx = 1
    mspTxCRC = 0
end

return mspSendRequest, mspProcessTxQ, mspPollReply, mspClearTxBuf, setProtocolVersion, getProtocolVersion
