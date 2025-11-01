
-- Runtime version selection (1 or 2)
local MSPV_DEFAULT = 2
local MSPV = MSPV_DEFAULT

local function VERSION_FLAG()
  -- v1 uses bit5, v2 uses bit6
  if MSPV == 2 then
    return bit32.lshift(1,6)
  else
    return bit32.lshift(1,5)
  end
end

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

local common = {}

function common.setMSPVersion(v)
  if v == 1 or v == 2 then
    MSPV = v
    -- optional: rf2.print("MSP version set to v"..tostring(v))
  else
    -- rf2.print("Ignored invalid MSP version: "..tostring(v))
  end
end

function common.getMSPVersion()
  return MSPV
end

function common.mspProcessTxQ()
    if (#(mspTxBuf) == 0) then
        return false
    end

    local payload = {}
    payload[1] = mspSeq + VERSION_FLAG()
    mspSeq = bit32.band(mspSeq + 1, 0x0F)
    if mspTxIdx == 1 then
        payload[1] = payload[1] + MSP_STARTFLAG
    end

    local i = 2
    while (i <= rf2.protocol.maxTxBufferSize) and (mspTxIdx <= #mspTxBuf) do
        payload[i] = mspTxBuf[mspTxIdx]
        mspTxIdx = mspTxIdx + 1
        if MSPV ~= 2 then
          -- v1 accumulates XOR across bytes we actually transmit
          mspTxCRC = bit32.bxor(mspTxCRC, payload[i])
        end
        i = i + 1
    end

    if i <= rf2.protocol.maxTxBufferSize then
        -- Frame completes in this chunk
        if MSPV ~= 2 then
          -- v1: append XOR byte
          payload[i] = mspTxCRC
          i = i + 1
        end
        -- zero fill
        while i <= rf2.protocol.maxTxBufferSize do
            payload[i] = 0
            i = i + 1
        end
        rf2.protocol.mspSend(payload)
        -- reset for next frame
        mspTxBuf = {}
        mspTxIdx = 1
        mspTxCRC = 0
        return false
    end

    -- Not enough room; send partial chunk and continue next tick
    rf2.protocol.mspSend(payload)
    return true
end

function common.mspSendRequest(cmd, payload)
    -- busy or bad args
    if #(mspTxBuf) ~= 0 or not cmd or type(payload) ~= "table" then
        return nil
    end

    mspTxBuf = {}
    mspTxIdx = 1
    mspTxCRC = 0

    local len = #(payload)

    if MSPV == 2 then
        -- MSPv2: flags(1), cmdLo(1), cmdHi(1), lenLo(1), lenHi(1), payload...
        local flags = 0
        mspTxBuf[1] = flags
        mspTxBuf[2] = bit32.band(cmd, 0xFF)
        mspTxBuf[3] = bit32.band(bit32.rshift(cmd, 8), 0xFF)
        mspTxBuf[4] = bit32.band(len, 0xFF)
        mspTxBuf[5] = bit32.band(bit32.rshift(len, 8), 0xFF)
        for i = 1, len do
            mspTxBuf[5 + i] = bit32.band(payload[i] or 0, 0xFF)
        end
        -- no XOR for v2
    else
        -- MSPv1: len(1), cmd(1), payload..., XOR(1)
        mspTxBuf[1] = bit32.band(len, 0xFF)
        mspTxBuf[2] = bit32.band(cmd, 0xFF)
        mspTxCRC = bit32.bxor(mspTxBuf[1], mspTxBuf[2])
        for i = 1, len do
            local b = bit32.band(payload[i] or 0, 0xFF)
            mspTxBuf[2 + i] = b
            mspTxCRC = bit32.bxor(mspTxCRC, b)
        end
        -- Pre-append XOR so single-chunk frames are complete immediately
        mspTxBuf[#mspTxBuf + 1] = mspTxCRC
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
    local err = bit32.btest(status, 0x80)
    idx = idx + 1

    if start then
        -- start flag set
        mspRxBuf = {}
        mspRxError = err

        if version == 2 then
            -- v2 header: flags, cmdLo, cmdHi, lenLo, lenHi
            local _flags = payload[idx]; idx = idx + 1
            local cmdLo  = payload[idx]; idx = idx + 1
            local cmdHi  = payload[idx]; idx = idx + 1
            local lenLo  = payload[idx]; idx = idx + 1
            local lenHi  = payload[idx]; idx = idx + 1
            mspRxReq  = bit32.bor(bit32.lshift(cmdHi, 8), cmdLo)
            mspRxSize = bit32.bor(bit32.lshift(lenHi, 8), lenLo)
            mspRxCRC  = 0  -- no XOR in v2
        else
            -- v1/legacy header: size, [cmd if version==1]
            mspRxSize = payload[idx]; idx = idx + 1
            mspRxReq  = mspLastReq
            if version == 1 then
                mspRxReq = payload[idx]; idx = idx + 1
            end
            mspRxCRC = bit32.bxor(mspRxSize, mspRxReq)
        end

        if mspRxReq == mspLastReq then
            mspStarted = true
        end
    elseif not mspStarted then
        return nil
    elseif bit32.band(mspRemoteSeq + 1, 0x0F) ~= seq then
        mspStarted = false
        return nil
    end

    while (idx <= rf2.protocol.maxRxBufferSize) and (#mspRxBuf < mspRxSize) do
        mspRxBuf[#mspRxBuf + 1] = payload[idx]
        if version ~= 2 then
          mspRxCRC = bit32.bxor(mspRxCRC, payload[idx])
        end
        idx = idx + 1
    end

    if idx > rf2.protocol.maxRxBufferSize then
        mspRemoteSeq = seq
        return false
    end

    mspStarted = false

    -- Check XOR for v1/legacy only
    if version ~= 2 then
        if mspRxCRC ~= payload[idx] then
            return nil
        end
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
    mspTxIdx = 1
    mspTxCRC = 0
end

return common
