local LCD_W, LCD_H = rf2.getWindowSize()
local resolution = LCD_W.."x"..LCD_H

local supportedRadios =
{
    -- TANDEM X20, TANDEM XE (800x480)
    ["784x406"] =
    {
        msp = {
            template = "/scripts/RF2/TEMPLATES/784x406.lua",
            lineSpacing = 35,
            MenuBox = { x = (LCD_W - 200)/2, y = (LCD_H - 80)/2, w = 200, x_offset = 50, h_line = 35, h_offset = 20 },
            SaveBox = { x = (LCD_W - 180)/2, y = (LCD_H - 60)/2, w = 180, x_offset = 12, h = 60, h_offset = 12 },
            NoTelem = { LCD_W/2 - 50, LCD_H - 28, "No Telemetry", BLINK },
            textSize = 0,
            yMinLimit = 35,
            yMaxLimit = 361,
        },
    },
    -- TANDEM X18, TWIN X Lite (480x320)
    ["472x288"] =
    {
        msp = {
            template = "/scripts/RF2/TEMPLATES/472x288.lua",
            lineSpacing = 25,
            MenuBox = { x = (LCD_W - 150)/2, y = (LCD_H - 80)/2, w = 150, x_offset = 25, h_line = 28, h_offset = 15 },
            SaveBox = { x = (LCD_W - 180)/2, y = (LCD_H - 60)/2, w = 180, x_offset = 12, h = 60, h_offset = 12 },
            textSize = 0,
            yMinLimit = 35,
            yMaxLimit = 243,
        },
    },
    -- Horus X10, Horus X12 (480x272)
    ["472x240"] =
    {
        msp = {
            template = "/scripts/RF2/TEMPLATES/472x240.lua",
            lineSpacing = 20,
            MenuBox = { x = (LCD_W - 200)/2, y = (LCD_H - 80)/2, w = 200, x_offset = 50, h_line = 20, h_offset = 20 },
            SaveBox = { x = (LCD_W - 180)/2, y = (LCD_H - 60)/2, w = 180, x_offset = 12, h = 60, h_offset = 12 },
            textSize = 0,
            yMinLimit = 35,
            yMaxLimit = 195,
        },
    },
    -- Twin X14 (632x314)
    ["632x314"] =
    {
        msp = {
            template = "/scripts/RF2/TEMPLATES/632x314.lua",
            lineSpacing = 25,
            MenuBox = { x = (LCD_W - 200)/2, y = (LCD_H - 80)/2, w = 200, x_offset = 50, h_line = 20, h_offset = 20 },
            SaveBox = { x = (LCD_W - 180)/2, y = (LCD_H - 60)/2, w = 180, x_offset = 12, h = 60, h_offset = 12 },
            textSize = 0,
            yMinLimit = 35,
            yMaxLimit = 300,
        },
    },
}

local radio = assert(supportedRadios[resolution], resolution.." not supported")
print(radio)

return radio
