local template = assert(rf2.loadScript(rf2.radio.template))()
local mspGovernorConfig = assert(rf2.loadScript("/scripts/RF2/MSP/mspGovernorConfig.lua"))()
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
local governorConfig = {}

x = margin
y = yMinLim - tableSpacing.header

fields[1] = { t = "Mode",                x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 4,     vals = { 1 }, table = { [0]="OFF", "PASSTHROUGH", "STANDARD", "MODE1", "MODE2" } }
fields[2] = { t = "Handover throttle%",  x = x, y = inc.y(lineSpacing), sp = x + sp, min = 10, max = 50,   vals = { 20 } }
fields[3] = { t = "Startup time",        x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 600,   vals = { 2,3 }, scale = 10 }
fields[4] = { t = "Spoolup time",        x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 600,   vals = { 4,5 }, scale = 10 }
fields[5] = { t = "Tracking time",       x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 6,7 }, scale = 10 }
fields[6] = { t = "Recovery time",       x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 8,9 }, scale = 10 }
fields[7] = { t = "AR bailout time",     x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 16,17 }, scale = 10 }
fields[8] = { t = "AR timeout",          x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 14,15 }, scale = 10 }
fields[9] = { t = "AR min entry time",   x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 18,19 }, scale = 10 }
fields[10] = { t = "Zero throttle TO",    x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 10,11 }, scale = 10 }
fields[11] = { t = "HS signal timeout",   x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 12,13 }, scale = 10 }
fields[12] = { t = "HS filter cutoff",    x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 250,   vals = { 22 } }
fields[13] = { t = "Volt. filter cutoff", x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 250,   vals = { 21 } }
fields[14] = { t = "TTA bandwidth",       x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 250,   vals = { 23 } }
fields[15] = { t = "Precomp bandwidth",   x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 250,   vals = { 24 } }

local function setValues()
    fields[1].value = governorConfig.gov_mode
    fields[2].value = governorConfig.gov_handover_throttle
    fields[3].value = governorConfig.gov_startup_time
    fields[4].value = governorConfig.gov_spoolup_time
    fields[5].value = governorConfig.gov_tracking_time
    fields[6].value = governorConfig.gov_recovery_time
    fields[7].value = governorConfig.gov_autorotation_bailout_time
    fields[8].value = governorConfig.gov_autorotation_timeout
    fields[9].value = governorConfig.gov_autorotation_min_entry_time
    fields[10].value = governorConfig.gov_zero_throttle_timeout
    fields[11].value = governorConfig.gov_lost_headspeed_timeout
    fields[12].value = governorConfig.gov_rpm_filter
    fields[13].value = governorConfig.gov_pwr_filter
    fields[14].value = governorConfig.gov_tta_filter
    fields[15].value = governorConfig.gov_ff_filter
end

local function getValues()
    governorConfig.gov_mode = fields[1].value
    governorConfig.gov_handover_throttle = fields[2].value
    governorConfig.gov_startup_time = fields[3].value
    governorConfig.gov_spoolup_time = fields[4].value
    governorConfig.gov_tracking_time = fields[5].value
    governorConfig.gov_recovery_time = fields[6].value
    governorConfig.gov_autorotation_bailout_time = fields[7].value
    governorConfig.gov_autorotation_timeout = fields[8].value
    governorConfig.gov_autorotation_min_entry_time = fields[9].value
    governorConfig.gov_zero_throttle_timeout = fields[10].value
    governorConfig.gov_lost_headspeed_timeout = fields[11].value
    governorConfig.gov_rpm_filter = fields[12].value
    governorConfig.gov_pwr_filter = fields[13].value
    governorConfig.gov_tta_filter = fields[14].value
    governorConfig.gov_ff_filter = fields[15].value
end

return {
    read = function(self)
        mspGovernorConfig.getGovernorConfig(self.processGovernorConfig, self)
    end,
    processGovernorConfig = function(self, config)
        governorConfig = config
        setValues()
        rf2.lcdNeedsInvalidate = true
        self.isReady = true -- TODO: use pageStatus instead?
    end,
    write = function(page)
        getValues()
        mspGovernorConfig.setGovernorConfig(governorConfig)
        rf2.settingsSaved()
    end,
    title       = "Governor",
    reboot      = true,
    eepromWrite = true,
    minBytes    = 24,
    labels      = labels,
    fields      = fields,
}
