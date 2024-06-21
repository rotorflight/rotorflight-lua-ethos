local template = assert(rf2.loadScript(rf2.radio.template))()
local mspStatus = assert(rf2.loadScript("/scripts/RF2/MSP/mspStatus.lua"))()
local margin = template.margin
local indent = template.indent
local lineSpacing = template.lineSpacing
local tableSpacing = template.tableSpacing
local colSpacing = tableSpacing.col * 0.65
local sp = template.listSpacing.field
local yMinLim = rf2.radio.yMinLimit
local x = margin
local y = yMinLim - lineSpacing
local inc = { x = function(val) x = x + val return x end, y = function(val) y = y + val return y end }
local labels = {}
local fields = {}

x = margin
y = yMinLim - tableSpacing.header
labels[#labels + 1] = { t = "",      x = x, y = inc.y(tableSpacing.header) }
labels[#labels + 1] = { t = "Ro",     x = x, y = inc.y(tableSpacing.row) }
labels[#labels + 1] = { t = "Pi",     x = x, y = inc.y(tableSpacing.row) }
labels[#labels + 1] = { t = "Ya",     x = x, y = inc.y(tableSpacing.row) }

x = x + tableSpacing.col/2
y = yMinLim - tableSpacing.header
labels[#labels + 1] = { t = "P",     x = x, y = inc.y(tableSpacing.header) }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 1,2 } }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 9,10 } }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 17,18 } }

x = x + colSpacing
y = yMinLim - tableSpacing.header
labels[#labels + 1] = { t = "I",     x = x, y = inc.y(tableSpacing.header) }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 3,4 } }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 11,12 } }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 19,20 } }

x = x + colSpacing
y = yMinLim - tableSpacing.header
labels[#labels + 1] = { t = "O",     x = x, y = inc.y(tableSpacing.header) }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 31,32 } }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 33,34 } }

x = x + colSpacing
y = yMinLim - tableSpacing.header
labels[#labels + 1] = { t = "D",     x = x, y = inc.y(tableSpacing.header) }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 5,6 } }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 13,14 } }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 21,22 } }

x = x + colSpacing
y = yMinLim - tableSpacing.header
labels[#labels + 1] = { t = "F",     x = x, y = inc.y(tableSpacing.header) }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 7,8 } }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 15,16 } }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 23,24 } }

x = x + colSpacing
y = yMinLim - tableSpacing.header
labels[#labels + 1] = { t = "B",     x = x, y = inc.y(tableSpacing.header) }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 25,26 } }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 27,28 } }
fields[#fields + 1] = {              x = x, y = inc.y(tableSpacing.row), min = 0, max = 1000, vals = { 29,30 } }

local currentProfile

local function checkProfileChanged(page, status)
    if not currentProfile then
        currentProfile = status.profile
        return
    end

    if currentProfile ~= status.profile then
        --print("old profile: "..tostring(currentProfile).." new profile: "..tostring(status.profile))
        currentProfile = status.profile
        rf2.readPage()
    end
end

return {
    read        = 112, -- MSP_PID_TUNING
    write       = 202, -- MSP_SET_PID_TUNING
    simulatorResponse = { 50, 0, 100, 0, 10, 0, 100, 0, 50, 0, 100, 0, 20, 0, 100, 0, 50, 0, 50, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 25, 0, 25, 0 },
    timerCounter = 0,
    timer = function(self)
        if self.timerCounter == 2 then
            mspStatus.getStatus(checkProfileChanged, self)
            self.timerCounter = 0
        else
            self.timerCounter = self.timerCounter + 1
        end
    end,
    title       = "PIDs",
    reboot      = false,
    eepromWrite = true,
    minBytes    = 34,
    labels      = labels,
    fields      = fields,
}
