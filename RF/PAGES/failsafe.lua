local template = assert(loadScript(radio.template))()
local margin = template.margin
local indent = template.indent
local lineSpacing = template.lineSpacing
local tableSpacing = template.tableSpacing
local sp = template.listSpacing.field
local yMinLim = radio.yMinLimit
local x = margin
local y = yMinLim - lineSpacing
local inc = { x = function(val) x = x + val return x end, y = function(val) y = y + val return y end }
local labels = {}
local fields = {}

labels[#labels + 1] = { t = "Failsafe Switch",   x = x,          y = inc.y(lineSpacing) }
fields[#fields + 1] = { t = "Action",            x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 2, vals = { 5 }, table = { [0] = "Stage 1", "Kill", "Stage 2" } }

labels[#labels + 1] = { t = "Stage 2 Settings" ,     x = x,          y = inc.y(lineSpacing) }
fields[#fields + 1] = { t = "Guard Time",            x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 200, vals = { 1 }, scale = 10 }
fields[#fields + 1] = { t = "Throttle Low Delay",    x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 300, vals = { 6, 7 }, scale = 10 }

return {
   read        = 75, -- MSP_FAILSAFE_CONFIG
   write       = 76, -- MSP_SET_FAILSAFE_CONFIG
   title       = "Failsafe",
   reboot      = true,
   eepromWrite = true,
   minBytes    = 8,
   labels      = labels,
   fields      = fields,
}
