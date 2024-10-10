local template = assert(rf2.loadScript(rf2.radio.template))()
local margin = template.margin
local indent = template.indent
local lineSpacing = template.lineSpacing
local tableSpacing = template.tableSpacing
local sp = template.listSpacing.field
local yMinLim = rf2.radio.yMinLimit
local x = margin
local y = yMinLim - lineSpacing
local inc = { x = function(val) x = x + val return x end, y = function(val) y = y + val return y end }
local labels = {}
local fields = {}



local becVoltage = {[0] = "7.5 V","8.0 V","8.5 V","12 V"}
local motorDirection = {[0]="CW", "CCW"}
local fanControl = {[0]="Automatic", "Always On"}


local function getEscTypeLabel(values)
    local idx = bit32.bor(bit32.lshift(values[2 + 24], 8), values[2 + 23])
    return escType[idx] or "YGE ESC ("..idx..")"
end

function getUInt(page, vals)
    local v = 0
    for idx=1, #vals do
        local raw_val = page.values[vals[idx] + 2] or 0
        raw_val = bit32.lshift(raw_val, (idx-1)*8)
        v = bit32.bor(v, raw_val)
    end
    return v
end

local function getPageValue(page, index)
    return page.values[2 + index]
end

local function updateRatio(field, page)
    local fm = page.fields[17]
    local fp = page.fields[18]
    local l = page.labels[9]
    local v = fp.value ~= 0 and fm.value / fp.value or 1
    -- update gear ratio label text
    l.t = string.format("%.2f", v)..":1"
end

labels[1] = { t = "ESC not ready, waiting...", x = x,       y = inc.y(lineSpacing) }
labels[2] = { t = "---",                    x = x + indent, y = inc.y(lineSpacing), bold = false }
labels[3] = { t = "---",                    x = x + indent, y = inc.y(lineSpacing), bold = false }
labels[4] = { t = "---",                    x = x + indent, y = inc.y(lineSpacing), bold = false }

labels[5] = { t = "Basic",               x = x,          y = inc.y(lineSpacing) }
fields[1] = {t = "Cell Count",              x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 4, max = 14, vals = {2 + 24}}
fields[2] = {t = "BEC Voltage",             x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min=0, max = 3, vals = {2 + 27}, tableIdxInc = -1, table = becVoltage}
fields[3] = {t = "Motor direction",         x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min=0, max = 1, vals = {2 + 29}, tableIdxInc = -1, table = motorDirection}
fields[4] = {t = "Soft start",              x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 5, max = 55, vals = {2 + 35}}
fields[5] = {t = "Fan control",             x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min=0, max = 1, vals = {2 + 34}, table = fanControl}

-- Advanced
labels[6] = { t = "Advanced",              x = x,          y = inc.y(lineSpacing) }
fields[6] = {t = "Low voltage",            x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 28, max = 38, scale = 10, default = 30, decimals = 1, vals = {2 + 25}}
fields[7] = {t = "Temperature",            x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 50, max = 150, default = 125, vals = {2 + 26}}
fields[8] = {t = "Timing angle",           x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 1, max = 20, default = 10, vals = {2 + 28}}
fields[9] = {t = "Starting torque",        x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 1, max = 15, default = 3, vals = {2 + 30}}
fields[10] = {t = "Response speed",        x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 1, max = 15, default = 5, vals = {2 + 31}}
fields[11] = {t = "Buzzer volume",         x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 5, default = 2, vals = {2 + 32}}
fields[12] = {t = "Current gain",          x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 40, default = 20, offset = -20, vals = {2 + 33}}



return {
    read        = 217, -- MSP_ESC_PARAMETERS
    write       = 218, -- MSP_SET_ESC_PARAMETERS
    eepromWrite = false,
    reboot      = false,
    title       = "FLYROTOR ESC",
    minBytes    = 46,
    labels      = labels,
    fields      = fields,
    readOnly    = true,
    simulatorResponse = {115, 0, 0, 0, 150, 231, 79, 190, 216, 78, 29, 169, 244, 1, 0, 0, 1, 0, 2, 0, 4, 76, 7, 148, 0, 6, 30, 125, 0, 15, 0, 3, 15, 1, 20, 0, 10, 0, 0, 0, 0, 0, 0, 2, 73, 240},

    svFlags     = 0,

    postRead = function(self)
        if self.values[1] ~= 0x73 then -- FlyRotor signature
            self.values = nil
            self.labels[1].t = "Invalid ESC detected"
            return -1
        end
        -- The read-only flag is set when the ESC is connected to an RX pin instead of a TX pin in half-duplex mode. Only supported by YGE.
        self.readOnly = bit32.band(self.values[2], 0x40) == 0x40
    end,

    postLoad = function(self)
        -- esc type
        --local l = self.labels[1]
        --l.t = getEscTypeLabel(self.values)

        -- SN
        l = self.labels[2]
        l.t = "sn:"..string.format("%08X", getUInt(self, { 7, 6, 5, 4 }))..string.format("%08X", getUInt(self, { 11, 10, 9, 8 }))

        -- FW ver
        l = self.labels[3]
        l.t = "fw:"..getPageValue(self, 15).."."..getPageValue(self, 16).."."..getPageValue(self, 17)

        -- HW version + IAP
        l = self.labels[4]
        l.t = "hw:"..(getPageValue(self, 18) + 1)..".0/"..getPageValue(self, 12).."."..getPageValue(self, 13).."."..getPageValue(self, 14)


        -- enable 'Save Page'
        self.readOnly = false
    end,

    preSave = function (self)
        -- F3C autorotation
        -- apply bits to saved flags
        local f = self.fields[13]
        self.svFlags = bit32.replace(self.svFlags, f.value, escFlags.f3cAuto)

        -- direction
        -- apply bits to saved flags
        local f = self.fields[2]
        self.svFlags = bit32.replace(self.svFlags, f.value, escFlags.spinDirection)

        -- save flags (use direction field mapping)
        self.values[f.vals[1]] = self.svFlags

        -- motor timing
        f = self.fields[11]
        local value = motorTimingFromUI[f.value] or 0
        self.values[f.vals[1]] = bit32.band(value, 0xFF)
        self.values[f.vals[2]] = bit32.rshift(value, 8)

        return self.values
    end,
}
