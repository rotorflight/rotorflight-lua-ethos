local template = assert(rf2.loadScript(rf2.radio.template))()
local mspServos = assert(rf2.loadScript("/scripts/RF2/MSP/mspServos.lua"))()
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
local servoConfigs = {}
local selectedServoIndex = 0
local updateSelectedServoConfiguration = false

local  function setValues(servoIndex)
    fields[1].value = servoIndex
    fields[2].value = servoConfigs[servoIndex].mid
    fields[3].value = servoConfigs[servoIndex].min
    fields[4].value = servoConfigs[servoIndex].max
    fields[5].value = servoConfigs[servoIndex].scaleNeg
    fields[6].value = servoConfigs[servoIndex].scalePos
    fields[7].value = servoConfigs[servoIndex].rate
    fields[8].value = servoConfigs[servoIndex].speed
end

local function getValues(servoIndex)
    servoConfigs[servoIndex].mid = fields[2].value
    servoConfigs[servoIndex].min = fields[3].value
    servoConfigs[servoIndex].max = fields[4].value
    servoConfigs[servoIndex].scaleNeg = fields[5].value
    servoConfigs[servoIndex].scalePos = fields[6].value
    servoConfigs[servoIndex].rate = fields[7].value
    servoConfigs[servoIndex].speed = fields[8].value
end

-- Field event functions

local function onChangeServo(field, page)
    getValues(selectedServoIndex)
    selectedServoIndex = field.value
    rf2.lastChangedServo = selectedServoIndex
    setValues(selectedServoIndex)
end

local function onPreEditCenter(field, page)
    mspServos.enableServoOverride(selectedServoIndex)
end

local function onChangeCenter(field, page)
    updateSelectedServoConfiguration = true
end

local function onPostEditCenter(field, page)
    mspServos.disableServoOverride(selectedServoIndex)
end

fields[1] = { t = "Servo",       x = x,          y = inc.y(lineSpacing), sp = x + sp, min = 0,     max = 7,     vals = { 1 }, table = { [0] = "ELEVATOR", "CYCL L", "CYCL R", "TAIL" }, postEdit = onChangeServo }
fields[2] = { t = "Center",      x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 50,    max = 2250,  preEdit = onPreEditCenter, change = onChangeCenter, postEdit = onPostEditCenter }
fields[3] = { t = "Min",         x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = -1000, max = 1000,  vals = { 4,5 } }
fields[4] = { t = "Max",         x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = -1000, max = 1000, vals = { 6,7 } }
fields[5] = { t = "Scale neg",   x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 100,   max = 1000, vals = { 8,9 } }
fields[6] = { t = "Scale pos",   x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 100,   max = 1000, vals = { 10,11 } }
fields[7] = { t = "Rate",        x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 50,    max = 5000, vals = { 12,13 } }
fields[8] = { t = "Speed",       x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0,     max = 60000, vals = { 14,15 } }

return {
    read = function(self)
        mspServos.getServoConfigurations(self.processServoConfigurations, self)
    end,
    processServoConfigurations = function(self, configs)
        servoConfigs = configs
        selectedServoIndex = rf2.lastChangedServo
        setValues(selectedServoIndex)
        self.fields[1].max = #configs
        rf2.lcdNeedsInvalidate = true
        self.isReady = true -- TODO: use pageStatus instead?
    end,
    write = function(page)
        getValues(selectedServoIndex)
        for servoIndex = 0, #servoConfigs do
            mspServos.setServoConfiguration(servoIndex, servoConfigs[servoIndex])
        end
        rf2.settingsSaved()
    end,
    timer = function(page)
        if updateSelectedServoConfiguration then
            getValues(selectedServoIndex)
            mspServos.setServoConfiguration(selectedServoIndex, servoConfigs[selectedServoIndex])
            updateSelectedServoConfiguration = false
        end
    end,
    title       = "Servos",
    reboot      = false,
    eepromWrite = true,
    minBytes    = 33,
    labels      = labels,
    fields      = fields
}