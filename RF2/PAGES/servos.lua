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
local servos = {}
local selectedServoIndex = 0

local  function setValues(servoIndex)
    fields[1].value = servoIndex
    fields[2].value = servos.configs[servoIndex].mid
    fields[3].value = servos.configs[servoIndex].min
    fields[4].value = servos.configs[servoIndex].max
    fields[5].value = servos.configs[servoIndex].scaleNeg
    fields[6].value = servos.configs[servoIndex].scalePos
    fields[7].value = servos.configs[servoIndex].rate
    fields[8].value = servos.configs[servoIndex].speed
end

local function getValues(servoIndex)
    servos.configs[servoIndex].mid = fields[2].value
    servos.configs[servoIndex].min = fields[3].value
    servos.configs[servoIndex].max = fields[4].value
    servos.configs[servoIndex].scaleNeg = fields[5].value
    servos.configs[servoIndex].scalePos = fields[6].value
    servos.configs[servoIndex].rate = fields[7].value
    servos.configs[servoIndex].speed = fields[8].value
end

local onCenterChanged = function(self, page)
    if not self.lastTimeSet or self.lastTimeSet + 50 < rf2.getTime() then
        getValues(selectedServoIndex)
        mspServos.setServoConfiguration(selectedServoIndex, servos.configs[selectedServoIndex])
        self.lastTimeSet = rf2.getTime()
    end
end

fields[1] = { t = "Servo",         x = x,          y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 7, vals = { 1 }, table = { [0] = "ELEVATOR", "CYCL L", "CYCL R", "TAIL" },
    postEdit = function(self, page) page.servoChanged(page, self.value) end }
fields[2] = {
    t = "Center",
    x = x + indent,
    y = inc.y(lineSpacing),
    sp = x + sp,
    min = 50,
    max = 2250,
    preEdit = function(self, page) rf2.mspHelper.enableServoOverride(selectedServoIndex) end,
    change = onCenterChanged,
    postEdit = function(self, page) rf2.mspHelper.disableServoOverride(selectedServoIndex) end
}
fields[3] = { t = "Min",           x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = -1000, max = 1000, vals = { 4,5 } }
fields[4] = { t = "Max",           x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = -1000, max = 1000, vals = { 6,7 } }
fields[5] = { t = "Scale neg",     x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 100, max = 1000, vals = { 8,9 } }
fields[6] = { t = "Scale pos",     x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 100, max = 1000, vals = { 10,11 } }
fields[7] = { t = "Rate",          x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 50, max = 5000, vals = { 12,13 } }
fields[8] = { t = "Speed",         x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 60000, vals = { 14,15 } }

return {
    read = function(self)
        mspServos.getServoConfigurations(self, self.processServoConfigurations)
    end,
    processServoConfigurations = function(message, page)
        servos.configs = message.reply -- TODO: don't like this
        selectedServoIndex = rf2.lastChangedServo
        setValues(selectedServoIndex)
        rf2.lcdNeedsInvalidate = true
        page.isReady = true -- TODO: use pageStatus instead?
    end,
    write = function(page)
        getValues(selectedServoIndex)
        for servoIndex = 0, #servos.configs do
            mspServos.setServoConfiguration(servoIndex, servos.configs[servoIndex])
        end
        rf2.settingsSaved()
    end,
    servoChanged = function(self, servoIndex)
        getValues(selectedServoIndex)
        selectedServoIndex = servoIndex
        rf2.lastChangedServo = servoIndex
        setValues(servoIndex)
    end,
    title       = "Servos",
    reboot      = false,
    eepromWrite = true,
    minBytes    = 33,
    labels      = labels,
    fields      = fields
}
