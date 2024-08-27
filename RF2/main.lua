-- RotorFlight + ETHOS LUA configuration
local LUA_VERSION = "2.1.0 - 240827"

local uiStatus =
{
    init     = 1,
    mainMenu = 2,
    pages    = 3,
    confirm  = 4,
}

local pageStatus =
{
    display = 1,
    editing = 2,
    saving  = 3,
    eepromWrite = 4,
    rebooting = 5,
    waiting = 6
}

local telemetryStatus =
{
    ok = 1,
    noSensor = 2,
    noTelemetry = 3
}

local uiState = uiStatus.init
local prevUiState
local pageState = pageStatus.display
local currentPage = 1
local currentField = 1
local saveTS = 0
local popupMenuActive = 1
local pageScrollY = 0
local mainMenuScrollY = 0
local telemetryState
local PageFiles, Page, init, popupMenu
local scrollSpeedTS = 0
local scrollSpeedMultiplier = 1
local displayMessage
local waitMessage

-- New variables for Ethos version
local screenTitle = nil
local lastEvent = nil
local enterEvent = nil
local enterEventTime
local callCreate = true

--- Virtual key translations from Ethos to OpenTX
local EVT_VIRTUAL_ENTER = 32
local EVT_VIRTUAL_ENTER_LONG = 129
local EVT_VIRTUAL_EXIT = 97
local EVT_VIRTUAL_PREV = 99
local EVT_VIRTUAL_PREV_LONG = 131
local EVT_VIRTUAL_NEXT = 98

local MENU_TITLE_BGCOLOR, ITEM_TEXT_SELECTED, ITEM_TEXT_NORMAL, ITEM_TEXT_EDITING

-- Initialize two global vars
bit32 = assert(loadfile("/scripts/RF2/LIBS/bit32.lua"))()
assert(loadfile("/scripts/RF2/rf2.lua"))()

local function invalidatePages()
    Page = nil
    pageState = pageStatus.display
    collectgarbage()
    rf2.lcdNeedsInvalidate = true
end

rf2.reloadPage = invalidatePages

rf2.setWaitMessage = function(message)
    pageState = pageStatus.waiting
    waitMessage = message
    rf2.lcdNeedsInvalidate = true
end

rf2.clearWaitMessage = function()
    pageState = pageStatus.display
    waitMessage = nil
    rf2.lcdNeedsInvalidate = true
end

rf2.displayMessage = function(title, text)
    displayMessage = { title = title, text = text }
    rf2.lcdNeedsInvalidate = true
end

local function rebootFc()
    --rf2.print("Attempting to reboot the FC...")
    pageState = pageStatus.rebooting
    rf2.lcdNeedsInvalidate = true
    rf2.mspQueue:add({
        command = 68, -- MSP_REBOOT
        processReply = function(self, buf)
            invalidatePages()
        end,
        simulatorResponse = {}
    })
end

local mspEepromWrite =
{
    command = 250, -- MSP_EEPROM_WRITE, fails when armed
    processReply = function(self, buf)
        if Page.reboot then
            rebootFc()
        else
            invalidatePages()
        end
    end,
    errorHandler = function(self)
        rf2.displayMessage("Save error", "Make sure your heli is disarmed.")
    end,
    simulatorResponse = {}
}

rf2.settingsSaved = function()
    -- check if this page requires writing to eeprom to save (most do)
    if Page and Page.eepromWrite then
        -- don't write again if we're already responding to earlier page.write()s
        if pageState ~= pageStatus.eepromWrite then
            pageState = pageStatus.eepromWrite
            rf2.mspQueue:add(mspEepromWrite)
        end
    elseif pageState ~= pageStatus.eepromWrite then
        -- If we're not already trying to write to eeprom from a previous save, then we're done.
        invalidatePages()
    end
    rf2.lcdNeedsInvalidate = true
end

local mspSaveSettings =
{
    processReply = function(self, buf)
        rf2.settingsSaved()
    end
}

rf2.saveSettings = function()
    if pageState ~= pageStatus.saving then
        pageState = pageStatus.saving
        saveTS = rf2.clock()

        if Page.values then
            local payload = Page.values
            mspSaveSettings.command = Page.write
            mspSaveSettings.payload = payload
            mspSaveSettings.simulatorResponse = {}
            rf2.mspQueue:add(mspSaveSettings)
        elseif type(Page.write) == "function" then
            Page.write(Page)
        end

        rf2.lcdNeedsInvalidate = true
    end
end

local mspLoadSettings =
{
    processReply = function(self, buf)
        rf2.print("Page is processing reply for cmd "..tostring(self.command).." len buf: "..#buf.." expected: "..Page.minBytes)
        Page.values = buf
        if Page.postRead then
            Page.postRead(Page)
        end
        rf2.dataBindFields()
        if Page.postLoad then
            Page.postLoad(Page)
        end
        rf2.lcdNeedsInvalidate = true
    end
}

rf2.readPage = function()
    if type(Page.read) == "function" then
        Page.read(Page)
    else
        mspLoadSettings.command = Page.read
        mspLoadSettings.simulatorResponse = Page.simulatorResponse
        rf2.mspQueue:add(mspLoadSettings)
    end
end

local function requestPage()
    if not Page.reqTS or Page.reqTS + rf2.protocol.pageReqTimeout <= rf2.clock() then
        Page.reqTS = rf2.clock()
        if Page.read then
            rf2.readPage()
        end
    end
end

local function confirm(page)
    prevUiState = uiState
    uiState = uiStatus.confirm
    invalidatePages()
    currentField = 1
    Page = assert(rf2.loadScript(page))()
    rf2.lcdNeedsInvalidate = true
    collectgarbage()
end

local function createPopupMenu()
    popupMenuActive = 1
    popupMenu = {}
    if uiState == uiStatus.pages then
        if not Page.readOnly then
            popupMenu[#popupMenu + 1] = { t = "Save Page", f = rf2.saveSettings }
        end
        popupMenu[#popupMenu + 1] = { t = "Reload", f = invalidatePages }
    end
    popupMenu[#popupMenu + 1] = { t = "Reboot", f = rebootFc }
    popupMenu[#popupMenu + 1] = { t = "Acc Cal", f = function() confirm("/scripts/RF2/CONFIRM/acc_cal.lua") end }
end

rf2.dataBindFields = function()
    for i=1,#Page.fields do
        if #Page.values >= Page.minBytes then
            local f = Page.fields[i]
            if f.vals then
                f.value = 0
                for idx=1, #f.vals do
                    local raw_val = Page.values[f.vals[idx]] or 0
                    raw_val = raw_val<<((idx-1)*8)
                    f.value = f.value|raw_val
                end
                local bits = #f.vals * 8
                if f.min and f.min < 0 and (f.value & (1 << (bits - 1)) ~= 0) then
                    f.value = f.value - (2 ^ bits)
                end
                f.value = f.value/(f.scale or 1)
            end
        end
    end
    rf2.lcdNeedsInvalidate = true
end

local function incMax(val, inc, base)
    return ((val + inc + base - 1) % base) + 1
end

local function clipValue(val,min,max)
    if val < min then
        val = min
    elseif val > max then
        val = max
    end
    return val
end

local function incField(inc)
    if not Page then return end
    currentField = clipValue(currentField + inc, 1, #Page.fields)
end

local function incMainMenu(inc)
    currentPage = clipValue(currentPage + inc, 1, #PageFiles)
end

local function incPopupMenu(inc)
    popupMenuActive = clipValue(popupMenuActive + inc, 1, #popupMenu)
end

local function incValue(inc)
    local f = Page.fields[currentField]
    if f.data then
        local scale = f.data.scale or 1
        local mult = f.data.mult or 1
        f.data.value = clipValue(f.data.value + inc*mult, (f.data.min or 0), (f.data.max or 255))
        f.data.value = math.floor(f.data.value/mult + 0.5)*mult
    else
        local scale = f.scale or 1
        local mult = f.mult or 1
        f.value = clipValue(f.value + inc*mult/scale, (f.min or 0)/scale, (f.max or 255)/scale)
        f.value = math.floor(f.value*scale/mult + 0.5)*mult/scale
        if Page.values then
            for idx=1, #f.vals do
                Page.values[f.vals[idx]] = math.floor(f.value*scale + 0.5)>>((idx-1)*8)
            end
        end
    end
    if f.change then
        f:change(Page)
    end
end

local function updateTelemetryState()
    local oldTelemetryState = telemetryState

    if not rf2.rssiSensor then
        telemetryState = telemetryStatus.noSensor
    elseif rf2.getRSSI() == 0 then
        telemetryState = telemetryStatus.noTelemetry
    else
        telemetryState = telemetryStatus.ok
    end

    if oldTelemetryState ~= telemetryState then
        rf2.lcdNeedsInvalidate = true
    end
end

local function fieldIsButton(f)
    return f.t and string.sub(f.t, 1, 1) == "[" and not (f.data or f.value)
end

---
--- ETHOS system tool functions
---

local translations = {en="Rotorflight 2"}

local function name(widget)
    local locale = system.getLocale()
    return translations[locale] or translations["en"]
end

-- CREATE:  Called once each time the system widget is opened by the user.
local function create()
    --rf2.print("create called")
    rf2.sensor = sport.getSensor({primId=0x32})
    rf2.rssiSensor =
        system.getSource("RSSI") or
        system.getSource("RSSI 2.4G") or
        system.getSource("RSSI 900M") or
        system.getSource("RSSI Int") or
        system.getSource("Rx RSSI1") or
        system.getSource("Rx RSSI2")

    --rf2.sensor:idle(false)

    rf2.protocol = assert(rf2.loadScript("protocols.lua"))()
    rf2.radio = assert(rf2.loadScript("radios.lua"))().msp
    rf2.mspQueue = assert(rf2.loadScript("MSP/mspQueue.lua"))()
    rf2.mspQueue.maxRetries = rf2.protocol.maxRetries
    rf2.mspHelper = assert(rf2.loadScript("MSP/mspHelper.lua"))()
    assert(rf2.loadScript(rf2.protocol.mspTransport))()
    assert(rf2.loadScript("MSP/common.lua"))()

    -- Initial var setting
    --saveTimeout = rf2.protocol.saveTimeout
    screenTitle = "Rotorflight "..LUA_VERSION
    uiState = uiStatus.init
    init = nil
    popupMenu = nil
    lastEvent = nil
    callCreate = false

    return {}
end

local function exit()
    uiState = uiStatus.init
    lastEvent = nil
    callCreate = true
    invalidatePages()
    if rf2.logfile then
        io.close(rf2.logfile)
        rf2.logfile = nil
    end
    system.exit()
end

local function processEvent()
    rf2.lcdNeedsInvalidate = true

    if displayMessage then
        if lastEvent == EVT_VIRTUAL_EXIT or lastEvent == EVT_VIRTUAL_ENTER then
            displayMessage = nil
            invalidatePages()
        end
    elseif popupMenu then
        if lastEvent == EVT_VIRTUAL_EXIT then
            popupMenu = nil
        elseif lastEvent == EVT_VIRTUAL_PREV then
            incPopupMenu(-1)
        elseif lastEvent == EVT_VIRTUAL_NEXT then
            incPopupMenu(1)
        elseif lastEvent == EVT_VIRTUAL_ENTER then
            popupMenu[popupMenuActive].f()
            popupMenu = nil
        end
    elseif uiState == uiStatus.init then
        if lastEvent == EVT_VIRTUAL_EXIT then
            exit()
            return 0
        end
    elseif uiState == uiStatus.mainMenu then
        if lastEvent == EVT_VIRTUAL_EXIT then
            exit()
            return 0
        elseif lastEvent == EVT_VIRTUAL_NEXT then
            incMainMenu(1)
        elseif lastEvent == EVT_VIRTUAL_PREV then
            incMainMenu(-1)
        elseif lastEvent == EVT_VIRTUAL_ENTER then
            prevUiState = uiStatus.mainMenu
            uiState = uiStatus.pages
            pageState = pageStatus.display  -- added in case we reboot from popup over main menu
        elseif lastEvent == EVT_VIRTUAL_ENTER_LONG then
            rf2.print("Popup from main menu")
            createPopupMenu()
        end
    elseif uiState == uiStatus.pages then
        if prevUiState ~= uiState then
            prevUiState = uiState
        end
        if pageState == pageStatus.display then
            if lastEvent == EVT_VIRTUAL_PREV then
                incField(-1)
            elseif lastEvent == EVT_VIRTUAL_NEXT then
                incField(1)
            elseif Page and lastEvent == EVT_VIRTUAL_ENTER then
                local f = Page.fields[currentField]
                if (Page.isReady or (Page.values and f.vals and Page.values[f.vals[#f.vals]])) and not f.readOnly then
                    if not fieldIsButton(Page.fields[currentField]) then
                        pageState = pageStatus.editing
                    end
                    if Page.fields[currentField].preEdit then
                        Page.fields[currentField]:preEdit(Page)
                    end
                end
            elseif lastEvent == EVT_VIRTUAL_ENTER_LONG then
                rf2.print("Popup from page")
                createPopupMenu()
            elseif lastEvent == EVT_VIRTUAL_EXIT then
                invalidatePages()
                currentField = 1
                uiState = uiStatus.mainMenu
                screenTitle = "Rotorflight "..LUA_VERSION
				lastEvent = nil
                return 0
            end
        elseif pageState == pageStatus.editing then
            if ((lastEvent == EVT_VIRTUAL_EXIT) or (lastEvent == EVT_VIRTUAL_ENTER)) then
                if Page.fields[currentField].postEdit then
                    Page.fields[currentField]:postEdit(Page)
                end
                pageState = pageStatus.display
            elseif lastEvent == EVT_VIRTUAL_NEXT then
                incValue(1 * scrollSpeedMultiplier)
            elseif lastEvent == EVT_VIRTUAL_PREV then
                incValue(-1 * scrollSpeedMultiplier)
            end
        end
    elseif uiState == uiStatus.confirm then
        if lastEvent == EVT_VIRTUAL_ENTER then
            uiState = uiStatus.init
            init = Page.init
            invalidatePages()
        elseif lastEvent == EVT_VIRTUAL_EXIT then
            invalidatePages()
            uiState = prevUiState
            prevUiState = nil
        end
    end
end

-- WAKEUP:  Called every ~30-50ms by the main Ethos software loop
local function wakeup(widget)
    if callCreate then
        -- HACK for enabling the rotary wheel, see https://github.com/FrSkyRC/ETHOS-Feedback-Community/issues/2292
        -- TLDR: don't specify create in system.registerSystemTool but call it here.
        create()
        processEvent()
    end

	-- HACK for processing long enter events without processing normal enter events as well.
    -- A long enter event might follow some time (max 0.6s) after a normal enter event.
    -- Only process normal enter events after that time if no long enter event has been received.
	if enterEvent ~= nil and (rf2.clock() - enterEventTime > 0.6) then
        lastEvent = enterEvent
		enterEvent = nil
        processEvent()
	end

    if (rf2.radio == nil or rf2.protocol == nil) then
        rf2.print("Error:  wakeup() called but create must have failed!")
        return 0
    end

    updateTelemetryState()

    -- run_ui(event)
    if uiState == uiStatus.init then
        screenTitle = "Rotorflight "..LUA_VERSION
        local prevInitText = init and init.t or nil
        init = init or assert(rf2.loadScript("ui_init.lua"))()
        local initSuccess = init.f()
        if prevInitText ~= init.t then lcd.invalidate() end
        if not initSuccess then
            -- waiting on api version to finish successfully.
            return 0
        end
        init = nil
        PageFiles = assert(rf2.loadScript("pages.lua"))()
        invalidatePages()
        uiState = prevUiState or uiStatus.mainMenu
        prevUiState = nil
    elseif uiState == uiStatus.pages then
        if pageState == pageStatus.saving then
            if saveTS + rf2.protocol.saveTimeout < rf2.clock() then
                --rf2.print("Save timeout!")
                pageState = pageStatus.display
                invalidatePages()
            end
        end
        if Page and Page.timer and (not Page.lastTimeTimerFired or Page.lastTimeTimerFired + 0.5 < rf2.clock()) then
            Page.timer(Page)
            if Page then Page.lastTimeTimerFired = rf2.clock() end
        end
        if not Page then
            Page = assert(rf2.loadScript("PAGES/"..PageFiles[currentPage].script))()
            screenTitle = "Rotorflight / "..Page.title
            collectgarbage()
        end
        if not(Page.values or Page.isReady) and pageState == pageStatus.display then
            requestPage()
        end
    end

    -- Process outgoing TX packets and check for incoming frames
    -- Should run every wakeup() cycle with a few exceptions where returns happen earlier
    rf2.mspQueue:processQueue()

    lastEvent = nil

    if rf2.lcdNeedsInvalidate == true then
        rf2.lcdNeedsInvalidate = false
        lcd.invalidate()
    end

  return 0
end


-- EVENT:  Called for button presses, scroll events, touch events, etc.
local function event(widget, category, value, x, y)
    --rf2.print("Event received: "..category.."  "..value)
    if category == EVT_KEY then
        if value == 4099 or value == 4100 then
            local scrollSpeed = rf2.clock() - scrollSpeedTS
            --rf2.print(scrollSpeed)
            if scrollSpeed < 0.1 then
                scrollSpeedMultiplier = 5
            else
                scrollSpeedMultiplier = 1
            end
            scrollSpeedTS = rf2.clock()
        end

        if value == EVT_VIRTUAL_PREV_LONG then
            exit()
            return 0
        elseif value ==  97 then
            -- Process enter later when it's clear it's not a long enter
            enterEvent = EVT_VIRTUAL_ENTER
            enterEventTime = rf2.clock()
            processEvent()
            return true
        elseif value == 129 then
            -- Long enter
            -- Clear the normal enter and only process the long enter
            rf2.print("Time elapsed since last enter: "..(rf2.clock() - enterEventTime))
            enterEvent = nil
            lastEvent = EVT_VIRTUAL_ENTER_LONG
            processEvent()
            return true
        elseif value == 35 then
            -- Rtn released.
            if not enterEvent then
                lastEvent = EVT_VIRTUAL_EXIT
            end
            processEvent()
            return true
        elseif value ==  4099 then
            -- rotary left
            if not enterEvent then
                lastEvent = EVT_VIRTUAL_PREV
            end
            processEvent()
            return true
        elseif value ==  4100 then
            -- rotary right
            if not enterEvent then
                lastEvent = EVT_VIRTUAL_NEXT
            end
            processEvent()
            return true
        end
    end

    return false
end

local function drawPage()
    local LCD_W, LCD_H = rf2.getWindowSize()
    if Page then
        local yMinLim = rf2.radio.yMinLimit
        local yMaxLim = rf2.radio.yMaxLimit
        local currentFieldY = Page.fields[currentField].y
        if currentFieldY <= Page.fields[1].y then
            pageScrollY = 0
        elseif currentFieldY - pageScrollY <= yMinLim then
            pageScrollY = currentFieldY - yMinLim
        elseif currentFieldY - pageScrollY >= yMaxLim then
            pageScrollY = currentFieldY - yMaxLim
        end
        for i=1,#Page.labels do
            local f = Page.labels[i]
            local y = f.y - pageScrollY
            if y >= 0 and y <= LCD_H then
                lcd.font((f.bold == false and FONT_STD) or FONT_BOLD)
                lcd.color(ITEM_TEXT_NORMAL)
                lcd.drawText(f.x, y, f.t)
            end
        end
        for i=1,#Page.fields do
            local val = "---"
            local f = Page.fields[i]
            if f.data and f.data.value then
                val = f.data.value
                if type(val) == "number" then
                    val = val / (f.data.scale or 1)
                end
                if f.data.table and f.data.table[val] then
                    val = f.data.table[val]
                end
            elseif f.value then
                val = f.value
                if f.table and f.table[f.value] then
                    val = f.table[f.value]
                end
            end
            local y = f.y - pageScrollY
            if y >= 0 and y <= LCD_H then
                if fieldIsButton(f) then
                    val = f.t
                elseif f.t then
                    lcd.font(FONT_STD)
                    lcd.color(ITEM_TEXT_NORMAL)
                    lcd.drawText(f.x, y, f.t)
                end
                if i == currentField then
                    if pageState == pageStatus.editing then
                        lcd.font(FONT_BOLD)
                        lcd.color(ITEM_TEXT_EDITING)
                    else
                        lcd.font(FONT_BOLD)
                        lcd.color(ITEM_TEXT_SELECTED)
                    end
                else
                    lcd.font(FONT_STD)
                    lcd.color(ITEM_TEXT_NORMAL)
                end
                strVal = ""
                --rf2.print("val is "..type(val))
                if (type(val) == "string") then
                    strVal = val
                elseif (type(val) == "number") then
                    if math.floor(val) == val then
                        strVal = string.format("%i",val)
                    else
                        strVal = tostring(val)
                    end
                else
                    strVal = val
                end
                lcd.drawText(f.sp or f.x, y, strVal)
            end
        end
    end
end

local function drawMessage(title, message)
    local LCD_W, LCD_H = rf2.getWindowSize()

    lcd.color(MENU_TITLE_BGCOLOR)
    lcd.drawFilledRectangle(50, 40, LCD_W - 100, 90)
    lcd.color(ITEM_TEXT_NORMAL)
    lcd.font(FONT_L)
    lcd.drawText(70, 50, title)

    lcd.color(MENU_TITLE_BGCOLOR)
    lcd.drawFilledRectangle(50, 90, LCD_W - 100, LCD_H - 100)
    lcd.font(FONT_STD)
    lcd.color(ITEM_TEXT_NORMAL)
    lcd.drawText(70, 100, message)
end

-- PAINT:  Called when the screen or a portion of the screen is invalidated (timer, etc)
local function paint(widget)
    --rf2.print("uiState: "..uiState.." pageState: "..pageState)

    if not rf2 or not rf2.radio or not rf2.protocol then
        print("Error:  paint() called, but create must have failed!")
        return
    end

    MENU_TITLE_BGCOLOR = lcd.themeColor(THEME_FOCUS_BGCOLOR)
    ITEM_TEXT_SELECTED = lcd.themeColor(THEME_FOCUS_COLOR)
    ITEM_TEXT_NORMAL = lcd.themeColor(THEME_DEFAULT_COLOR)
    ITEM_TEXT_EDITING = lcd.themeColor(THEME_WARNING_COLOR)

    local LCD_W, LCD_H = rf2.getWindowSize()

    if displayMessage then
        drawMessage(displayMessage.title, displayMessage.text)
    elseif init and uiState == uiStatus.init then
        --rf2.print("painting uiState == uiStatus.init")
        lcd.color(ITEM_TEXT_NORMAL)
        lcd.font(FONT_STD)
        lcd.drawText(6, rf2.radio.yMinLimit, init.t)
    elseif uiState == uiStatus.mainMenu then
        --rf2.print("painting uiState == uiStatus.mainMenu")
        local yMinLim = rf2.radio.yMinLimit
        local yMaxLim = rf2.radio.yMaxLimit
        local lineSpacing = rf2.radio.lineSpacing
        local currentFieldY = (currentPage-1)*lineSpacing + yMinLim
        if currentFieldY <= yMinLim then
            mainMenuScrollY = 0
        elseif currentFieldY - mainMenuScrollY <= yMinLim then
            mainMenuScrollY = currentFieldY - yMinLim
        elseif currentFieldY - mainMenuScrollY >= yMaxLim then
            mainMenuScrollY = currentFieldY - yMaxLim
        end
        for i=1, #PageFiles do
            local attr = currentPage == i and INVERS or 0
            local y = (i-1)*lineSpacing + yMinLim - mainMenuScrollY
            if y >= 0 and y <= LCD_H then
                if currentPage == i then
                    lcd.font(FONT_BOLD)
                    lcd.color(ITEM_TEXT_SELECTED)
                else
                    lcd.font(FONT_STD)
                    lcd.color(ITEM_TEXT_NORMAL)
                end
                lcd.drawText(6, y, PageFiles[i].title)
            end
        end
    elseif uiState == uiStatus.pages then
        drawPage()
        if pageState >= pageStatus.saving then
            local saveMsg = ""
            if pageState == pageStatus.saving then
                saveMsg = "Saving..."
            elseif pageState == pageStatus.eepromWrite then
                saveMsg = "Updating..."
            elseif pageState == pageStatus.rebooting then
                saveMsg = "Rebooting..."
            elseif pageState == pageStatus.waiting then
                saveMsg = waitMessage
            end
            lcd.color(MENU_TITLE_BGCOLOR)
            lcd.drawFilledRectangle(rf2.radio.SaveBox.x,rf2.radio.SaveBox.y,rf2.radio.SaveBox.w,rf2.radio.SaveBox.h)
            lcd.color(ITEM_TEXT_NORMAL)
            lcd.font(FONT_L)
            lcd.drawText(rf2.radio.SaveBox.x+rf2.radio.SaveBox.x_offset,rf2.radio.SaveBox.y+rf2.radio.SaveBox.h_offset,saveMsg)
        end
    elseif uiState == uiStatus.confirm then
        drawPage()
    end

    if screenTitle then
        lcd.color(MENU_TITLE_BGCOLOR)
        lcd.drawFilledRectangle(0, 0, LCD_W, 30)
        lcd.color(ITEM_TEXT_NORMAL)
        lcd.font(FONT_STD)
        lcd.drawText(5,5,screenTitle)
    end

    if popupMenu then
        rf2.print("painting popupMenu")
        local x = rf2.radio.MenuBox.x
        local y = rf2.radio.MenuBox.y
        local w = rf2.radio.MenuBox.w
        local h_line = rf2.radio.MenuBox.h_line
        local h_offset = rf2.radio.MenuBox.h_offset
        local h = #popupMenu * h_line + h_offset*2

        lcd.color(MENU_TITLE_BGCOLOR)
        lcd.drawFilledRectangle(x,y,w,h)

        for i,e in ipairs(popupMenu) do
            if popupMenuActive == i then
                lcd.font(FONT_BOLD)
                lcd.color(ITEM_TEXT_SELECTED)
            else
                lcd.font(FONT_STD)
                lcd.color(ITEM_TEXT_NORMAL)
            end
           lcd.drawText(x+rf2.radio.MenuBox.x_offset,y+(i-1)*h_line+h_offset,e.t)
        end
    end

    lcd.color(ITEM_TEXT_EDITING)
    lcd.font(FONT_STD)
    if telemetryState == telemetryStatus.noTelemetry then
        lcd.drawText(LCD_W - 180, 5, "No Telemetry!  ")
    elseif telemetryState == telemetryStatus.noSensor then
        lcd.drawText(LCD_W - 180, 5, "No RSSI sensor!")
    elseif telemetryState == telemetryStatus.ok then
        lcd.drawText(LCD_W - 180, 5, "               ")
    end
end

local icon = lcd.loadMask("/scripts/RF2/RF.png")

local function init()
    system.registerSystemTool({name=name, icon=icon, wakeup=wakeup, paint=paint, event=event})
end

return { init = init }