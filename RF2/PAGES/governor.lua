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

fields[1] = { t = "Mode",                 x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[2] = { t = "Handover throttle%",   x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[3] = { t = "Startup time",         x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[4] = { t = "Spoolup time",         x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[5] = { t = "Tracking time",        x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[6] = { t = "Recovery time",        x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[7] = { t = "AR bailout time",      x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[8] = { t = "AR timeout",           x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[9] = { t = "AR min entry time",    x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[10] = { t = "Zero throttle TO",    x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[11] = { t = "HS signal timeout",   x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[12] = { t = "HS filter cutoff",    x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[13] = { t = "Volt. filter cutoff", x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[14] = { t = "TTA bandwidth",       x = x, y = inc.y(lineSpacing), sp = x + sp }
fields[15] = { t = "Precomp bandwidth",   x = x, y = inc.y(lineSpacing), sp = x + sp }

local function setValues()
    fields[1].data = governorConfig.gov_mode
    fields[2].data = governorConfig.gov_handover_throttle
    fields[3].data = governorConfig.gov_startup_time
    fields[4].data = governorConfig.gov_spoolup_time
    fields[5].data = governorConfig.gov_tracking_time
    fields[6].data = governorConfig.gov_recovery_time
    fields[7].data = governorConfig.gov_autorotation_bailout_time
    fields[8].data = governorConfig.gov_autorotation_timeout
    fields[9].data = governorConfig.gov_autorotation_min_entry_time
    fields[10].data = governorConfig.gov_zero_throttle_timeout
    fields[11].data = governorConfig.gov_lost_headspeed_timeout
    fields[12].data = governorConfig.gov_rpm_filter
    fields[13].data = governorConfig.gov_pwr_filter
    fields[14].data = governorConfig.gov_tta_filter
    fields[15].data = governorConfig.gov_ff_filter
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
        mspGovernorConfig.setGovernorConfig(governorConfig)
        rf2.settingsSaved()
    end,
    title       = "Governor",
    reboot      = true,
    eepromWrite = true,
    labels      = labels,
    fields      = fields,
}
