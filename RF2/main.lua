-- RotorFlight + ETHOS LUA configuration
local LUA_VERSION = "2.0 - 240222"

apiVersion = 0

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
}

local telemetryStatus =
{
    ok = 1,
    noSensor = 2,
    noTelemetry = 3
}

local uiMsp =
{
    reboot = 68,
    eepromWrite = 250,
}

local uiState = uiStatus.init
local prevUiState
local pageState = pageStatus.display
-- local requestTimeout = 1.5   -- in seconds (originally 0.8)
local currentPage = 1
local currentField = 1
local saveTS = 0
local saveRetries = 0
local popupMenuActive = 1
local pageScrollY = 0
local mainMenuScrollY = 0
local telemetryState
local saveTimeout, saveMaxRetries, PageFiles, Page, init, popupMenu, requestTimeout, rssiSensor

-- New variables for Ethos version
local screenTitle = nil
local lastEvent = nil
local enterEvent = nil
local enterEventTime
local callCreate = true

lcdNeedsInvalidate = false

--- Virtual key translations from Ethos to OpenTX
local EVT_VIRTUAL_ENTER = 32
local EVT_VIRTUAL_ENTER_LONG = 129
local EVT_VIRTUAL_EXIT = 97
local EVT_VIRTUAL_PREV = 99
local EVT_VIRTUAL_NEXT = 98

protocol = nil
radio = nil
sensor = nil

rfglobals = {}

local function saveSettings()
    if Page.values then
        local payload = Page.values
        if Page.preSave then
            payload = Page.preSave(Page)
        end
        saveTS = os.clock()
        if pageState == pageStatus.saving then
            saveRetries = saveRetries + 1
        else
            pageState = pageStatus.saving
            saveRetries = 0
            print("Attempting to write page values...")
        end
        protocol.mspWrite(Page.write, payload)
    end
end

local function eepromWrite()
    saveTS = os.clock()
    if pageState == pageStatus.eepromWrite then
        saveRetries = saveRetries + 1
    else
        pageState = pageStatus.eepromWrite
        saveRetries = 0
        print("Attempting to write to eeprom...")
    end
    protocol.mspRead(uiMsp.eepromWrite)
end

local function rebootFc()
    -- Only sent once.  I think a response may come back from FC if successful?
    -- May want to either check for that and repeat if not, or check for loss of telemetry to confirm, etc.
    -- TODO: Implement an auto-retry?  Right now if the command gets lost then there's just no reboot and no notice.
    print("Attempting to reboot the FC (one shot)...")
    saveTS = os.clock()
    pageState = pageStatus.rebooting
    protocol.mspRead(uiMsp.reboot)
    -- https://github.com/rotorflight/rotorflight-firmware/blob/9a5b86d915df557ff320f30f1376cb8ce9377157/src/main/msp/msp.c#L1853
end

local function invalidatePages()
    Page = nil
    pageState = pageStatus.display
    saveTS = 0
    collectgarbage()
    lcdNeedsInvalidate = true
end

local function confirm(page)
    prevUiState = uiState
    uiState = uiStatus.confirm
    invalidatePages()
    currentField = 1
    Page = assert(loadScript(page))()
    lcdNeedsInvalidate = true
    collectgarbage()
end

function dataBindFields()
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
end

-- Run lcd.invalidate() if anything actionable comes back from it.
local function processMspReply(cmd,rx_buf,err)
    if Page and rx_buf ~= nil then
        print("Page is processing reply for cmd "..tostring(cmd).." len rx_buf: "..#rx_buf.." expected: "..Page.minBytes)
    end
    if not Page or not rx_buf then
    elseif cmd == Page.write then
        -- check if this page requires writing to eeprom to save (most do)
        if Page.eepromWrite then
            -- don't write again if we're already responding to earlier page.write()s
            if pageState ~= pageStatus.eepromWrite then
                eepromWrite()
            end
        elseif pageState ~= pageStatus.eepromWrite then
            -- If we're not already trying to write to eeprom from a previous save, then we're done.
            invalidatePages()
        end
        lcdNeedsInvalidate = true
    elseif cmd == uiMsp.eepromWrite then
        if Page.reboot then
            rebootFc()
        end
        invalidatePages()
    elseif (cmd == Page.read) and (#rx_buf > 0) then
        --print("processMspReply:  Page.read and non-zero rx_buf")
        Page.values = rx_buf
        if Page.postRead then
            Page.postRead(Page)
        end
        dataBindFields()
        if Page.postLoad then
            Page.postLoad(Page)
            print("Postload executed")
        end
        lcdNeedsInvalidate = true
    end
end

local function requestPage()
    if Page.read and ((not Page.reqTS) or (Page.reqTS + requestTimeout <= os.clock())) then
        --print("Trying requestPage()")
        Page.reqTS = os.clock()
        protocol.mspRead(Page.read)
    end
end

local function createPopupMenu()
    popupMenuActive = 1
    popupMenu = {}
    if uiState == uiStatus.pages then
        popupMenu[#popupMenu + 1] = { t = "Save Page", f = saveSettings }
        popupMenu[#popupMenu + 1] = { t = "Reload", f = invalidatePages }
    end
    popupMenu[#popupMenu + 1] = { t = "Reboot", f = rebootFc }
    popupMenu[#popupMenu + 1] = { t = "Acc Cal", f = function() confirm("/scripts/RF2/CONFIRM/acc_cal.lua") end }
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

-- local function incPage(inc)
    -- currentPage = incMax(currentPage, inc, #PageFiles)
    -- currentField = 1
    -- invalidatePages()
-- end

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
    local scale = f.scale or 1
    local mult = f.mult or 1
    f.value = clipValue(f.value + inc*mult/scale, (f.min or 0)/scale, (f.max or 255)/scale)
    f.value = math.floor(f.value*scale/mult + 0.5)*mult/scale
    for idx=1, #f.vals do
        Page.values[f.vals[idx]] = math.floor(f.value*scale + 0.5)>>((idx-1)*8)
    end
    if f.upd and Page.values then
        f.upd(Page)
    end
end

-- OpenTX <-> Ethos mapping functions

function sportTelemetryPop()
    -- Pops a received SPORT packet from the queue. Please note that only packets using a data ID within 0x5000 to 0x50FF (frame ID == 0x10), as well as packets with a frame ID equal 0x32 (regardless of the data ID) will be passed to the LUA telemetry receive queue.
    local frame = sensor:popFrame()
    if frame == nil then
        return nil, nil, nil, nil
    end
    -- physId = physical / remote sensor Id (aka sensorId)
    --   0x00 for FPORT, 0x1B for SmartPort
    -- primId = frame ID  (should be 0x32 for reply frames)
    -- appId = data Id
    return frame:physId(), frame:primId(), frame:appId(), frame:value()
end

function sportTelemetryPush(sensorId, frameId, dataId, value)
    -- OpenTX:
    -- When called without parameters, it will only return the status of the output buffer without sending anything.
    --   Equivalent in Ethos may be:   sensor:idle() ???
    -- @param sensorId  physical sensor ID
    -- @param frameId   frame ID
    -- @param dataId    data ID
    -- @param value     value
    -- @retval boolean  data queued in output buffer or not.
    -- @retval nil      incorrect telemetry protocol.  (added in 2.3.4)
    return sensor:pushFrame({physId=sensorId, primId=frameId, appId=dataId, value=value})
end

-- Ethos: when the RF1 and RF2 system tools are both installed, RF1 tries to call getRSSI in RF2 and gets stuck.
-- To avoid this, getRSSI is renamed in RF2.
function rf2_getRSSI()
      --print("getRSSI RF2")
    if rssiSensor ~= nil and rssiSensor:state() then
      -- this will return the last known value if nothing is received
      return rssiSensor:value()
    end
    -- return 0 if no telemetry signal to match OpenTX
    return 0
end

function getTime()
    return os.clock() * 100;
end

function loadScript(script)
    return loadfile(script)
end

function getWindowSize()
    return lcd.getWindowSize()
    --return 784, 406
    --return 472, 288
    --return 472, 240
end

local function updateTelemetryState()
    local oldTelemetryState = telemetryState

    if not rssiSensor then
        telemetryState = telemetryStatus.noSensor
    elseif rf2_getRSSI() == 0 then
        telemetryState = telemetryStatus.noTelemetry
    else
        telemetryState = telemetryStatus.ok
    end

    if oldTelemetryState ~= telemetryState then
        lcdNeedsInvalidate = true
    end
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
    sensor = sport.getSensor({primId=0x32})
    rssiSensor = system.getSource("RSSI")
    if not rssiSensor then
        rssiSensor = system.getSource("RSSI 2.4G")
        if not rssiSensor then
            rssiSensor = system.getSource("RSSI 900M")
            if not rssiSensor then
                rssiSensor = system.getSource("Rx RSSI1")
                if not rssiSensor then
                    rssiSensor = system.getSource("Rx RSSI2")
                end
            end
        end
    end

    --sensor:idle(false)

    protocol = assert(loadScript("/scripts/RF2/protocols.lua"))()
    radio = assert(loadScript("/scripts/RF2/radios.lua"))().msp
    assert(loadScript(protocol.mspTransport))()
    assert(loadScript("/scripts/RF2/MSP/common.lua"))()

    -- Initial var setting
    saveTimeout = protocol.saveTimeout
    saveMaxRetries = protocol.saveMaxRetries
    requestTimeout = protocol.pageReqTimeout
    screenTitle = "Rotorflight "..LUA_VERSION
    uiState = uiStatus.init
    init = nil
    popupMenu = nil
    lastEvent = nil
    apiVersion = 0
    callCreate = false

    return {}
end


-- WAKEUP:  Called every ~30-50ms by the main Ethos software loop
local function wakeup(widget)
    if callCreate then
        -- HACK for enabling the rotary wheel, see https://github.com/FrSkyRC/ETHOS-Feedback-Community/issues/2292
        -- TLDR: don't specify create in system.registerSystemTool but call it here.
        create()
    end

	-- HACK for processing long enter events without processing normal enter events as well.
    -- A long enter event might follow some time (max 0.6s) after a normal enter event.
    -- Only process normal enter events after that time if no long enter event has been received.
	if enterEvent ~= nil and (os.clock() - enterEventTime > 0.6) then
        lastEvent = enterEvent
		enterEvent = nil
	end

    if (radio == nil or protocol == nil) then
        print("Error:  wakeup() called but create must have failed!")
        return 0
    end

    updateTelemetryState()

    -- run_ui(event)
    if popupMenu then
        if lastEvent == EVT_VIRTUAL_EXIT then
            popupMenu = nil
            lcdNeedsInvalidate = true
        elseif lastEvent == EVT_VIRTUAL_PREV then
            incPopupMenu(-1)
            lcdNeedsInvalidate = true
        elseif lastEvent == EVT_VIRTUAL_NEXT then
            incPopupMenu(1)
            lcdNeedsInvalidate = true
        elseif lastEvent == EVT_VIRTUAL_ENTER then
            popupMenu[popupMenuActive].f()
            popupMenu = nil
            lcdNeedsInvalidate = true
        end
    elseif uiState == uiStatus.init then
        screenTitle = "Rotorflight "..LUA_VERSION
        local prevInit
        if init ~= nil then
            prevInit = init.t
        end
        init = init or assert(loadScript("/scripts/RF2/ui_init.lua"))()
        if lastEvent == EVT_VIRTUAL_EXIT then
			lastEvent = nil
			lcd.invalidate()
            callCreate = true
            system.exit()
            return 0
        end
        local initSuccess = init.f()
        if prevInit ~= init.t then
            -- Update initialization message
            lcd.invalidate()
        end
        if not initSuccess then
            -- waiting on api version to finish successfully.
            return 0
        end
        init = nil
        PageFiles = assert(loadScript("/scripts/RF2/pages.lua"))()
        invalidatePages()
        uiState = prevUiState or uiStatus.mainMenu
        prevUiState = nil
    elseif uiState == uiStatus.mainMenu then
        screenTitle = "Rotorflight "..LUA_VERSION
        if lastEvent == EVT_VIRTUAL_EXIT then
			lastEvent = nil
			lcd.invalidate()
            callCreate = true
            system.exit()
            return 0
        elseif lastEvent == EVT_VIRTUAL_NEXT then
            incMainMenu(1)
            lcdNeedsInvalidate = true
        elseif lastEvent == EVT_VIRTUAL_PREV then
            incMainMenu(-1)
            lcdNeedsInvalidate = true
        elseif lastEvent == EVT_VIRTUAL_ENTER then
            prevUiState = uiStatus.mainMenu
            uiState = uiStatus.pages
            pageState = pageStatus.display  -- added in case we reboot from popup over main menu
            lcdNeedsInvalidate = true
        elseif lastEvent == EVT_VIRTUAL_ENTER_LONG then
            print("Popup from main menu")
            createPopupMenu()
            lcdNeedsInvalidate = true
        end
    elseif uiState == uiStatus.pages then
        if prevUiState ~= uiState then
            lcdNeedsInvalidate = true
            prevUiState = uiState
        end

        if pageState == pageStatus.saving then
            if (saveTS + saveTimeout) < os.clock() then
                if saveRetries < saveMaxRetries then
                    saveSettings()
                    lcdNeedsInvalidate = true
                else
                    print("Failed to write page values!")
                    invalidatePages()
                end
                -- drop through to processMspReply to send MSP_SET and see if we've received a response to this yet.
            end
        elseif pageState == pageStatus.eepromWrite then
            if (saveTS + saveTimeout) < os.clock() then
                if saveRetries < saveMaxRetries then
                    eepromWrite()
                    lcdNeedsInvalidate = true
                else
                    print("Failed to write to eeprom!")
                    invalidatePages()
                end
                -- drop through to processMspReply to send MSP_SET and see if we've received a response to this yet.
            end
        elseif pageState == pageStatus.rebooting then
            -- TODO:  Rebooting is only a one-try shot.  Would be nice if it retried automatically.
            if (saveTS + saveTimeout) < os.clock() then
                invalidatePages()
            end
            -- drop through to processMspReply to send MSP_SET and see if we've received a response to this yet.
        elseif pageState == pageStatus.display then
            if lastEvent == EVT_VIRTUAL_PREV then
                incField(-1)
                lcdNeedsInvalidate = true
            elseif lastEvent == EVT_VIRTUAL_NEXT then
                incField(1)
                lcdNeedsInvalidate = true
            elseif lastEvent == EVT_VIRTUAL_ENTER then
                if Page then
                    local f = Page.fields[currentField]
                    if Page.values and f.vals and Page.values[f.vals[#f.vals]] and not f.ro then
                        pageState = pageStatus.editing
                        lcdNeedsInvalidate = true
                    end
                end
            elseif lastEvent == EVT_VIRTUAL_ENTER_LONG then
                print("Popup from page")
                createPopupMenu()
                lcdNeedsInvalidate = true
            elseif lastEvent == EVT_VIRTUAL_EXIT then
                invalidatePages()
                currentField = 1
                uiState = uiStatus.mainMenu
                lcd.invalidate()
				lastEvent = nil
                return 0
            end
        elseif pageState == pageStatus.editing then
            if ((lastEvent == EVT_VIRTUAL_EXIT) or (lastEvent == EVT_VIRTUAL_ENTER)) then
                if Page.fields[currentField].postEdit then
                    Page.fields[currentField].postEdit(Page)
                end
                pageState = pageStatus.display
				lcdNeedsInvalidate = true
            elseif lastEvent == EVT_VIRTUAL_NEXT then
                incValue(1)
				lcdNeedsInvalidate = true
            elseif lastEvent == EVT_VIRTUAL_PREV then
                incValue(-1)
				lcdNeedsInvalidate = true
            end
        end
        if not Page then
            Page = assert(loadScript("/scripts/RF2/PAGES/"..PageFiles[currentPage].script))()
            collectgarbage()
        end
        if not Page.values and pageState == pageStatus.display then
            requestPage()
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

    -- Process outgoing TX packets and check for incoming frames
    -- Should run every wakeup() cycle with a few exceptions where returns happen earlier
    mspProcessTxQ()
    processMspReply(mspPollReply())
    lastEvent = nil

    if lcdNeedsInvalidate == true then
        lcdNeedsInvalidate = false
        lcd.invalidate()
    end

  return 0
end


-- EVENT:  Called for button presses, scroll events, touch events, etc.
local function event(widget, category, value, x, y)
    print("Event received:", category, value, x, y)
    if category == EVT_KEY then
        if value ==  97 then
            -- Process enter later when it's clear it's not a long enter
            enterEvent = EVT_VIRTUAL_ENTER
            enterEventTime = os.clock()
            return true
        elseif value == 129 then
            -- Long enter
            -- Clear the normal enter and only process the long enter
            print("Time elapsed since last enter: "..(os.clock() - enterEventTime))
            enterEvent = nil
            lastEvent = EVT_VIRTUAL_ENTER_LONG
            return true
        elseif value == 35 then
            -- Rtn released.
            if not enterEvent then
                lastEvent = EVT_VIRTUAL_EXIT
            end
            return true
        elseif value ==  4099 then
            -- rotary left
            if not enterEvent then
                lastEvent = EVT_VIRTUAL_PREV
            end
            return true
        elseif value ==  4100 then
            -- rotary right
            if not enterEvent then
                lastEvent = EVT_VIRTUAL_NEXT
            end
            return true
        end
    end

    return false
end

-- Paint() helpers:
local MENU_TITLE_BGCOLOR = lcd.RGB(55, 55, 55)  -- dark grey
local MENU_TITLE_COLOR = lcd.RGB(62, 145, 247)  -- light blue
local ITEM_TEXT_SELECTED = lcd.RGB(62, 145, 247)  -- selected in light blue
local ITEM_TEXT_NORMAL = lcd.RGB(200, 200, 200)  -- unselected text in light grey/white
local ITEM_TEXT_EDITING = lcd.RGB(255, 0, 0)     -- red text

local function drawScreen()
    local LCD_W, LCD_H = getWindowSize()
    if Page then
        local yMinLim = radio.yMinLimit
        local yMaxLim = radio.yMaxLimit
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
                lcd.font(FONT_BOLD)
                lcd.color(ITEM_TEXT_NORMAL)
                lcd.drawText(f.x, y, f.t)
            end
        end
        local val = "---"
        for i=1,#Page.fields do
            local f = Page.fields[i]
            if f.value then
                if f.upd and Page.values then
                    f.upd(Page)
                end
                val = f.value
                if f.table and f.table[f.value] then
                    val = f.table[f.value]
                end
            end
            local y = f.y - pageScrollY
            if y >= 0 and y <= LCD_H then
                if f.t then
                    lcd.font(FONT_STD)
                    lcd.color(ITEM_TEXT_NORMAL)
                    lcd.drawText(f.x, y, f.t)
                end
                if i == currentField then
                    if pageState == pageStatus.editing then
                        lcd.font(FONT_BOLD)
                        lcd.color(ITEM_TEXT_EDITING)
                    else
                        lcd.font(FONT_STD)
                        lcd.color(ITEM_TEXT_SELECTED)
                    end
                else
                    lcd.font(FONT_STD)
                    lcd.color(ITEM_TEXT_NORMAL)
                end
                strVal = ""
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
        screenTitle = "Rotorflight / "..Page.title
    end
end

-- PAINT:  Called when the screen or a portion of the screen is invalidated (timer, etc)
local function paint(widget)

    if (radio == nil or protocol == nil) then
        print("Error:  paint() called, but create must have failed!")
        return
    end

    local LCD_W, LCD_H = getWindowSize()
    --lcd.color(MENU_TITLE_BGCOLOR)
    --lcd.drawFilledRectangle(0,0,LCD_W,LCD_H)

    if uiState == uiStatus.init then
        print("painting uiState == uiStatus.init")
        lcd.color(ITEM_TEXT_EDITING)
        lcd.font(FONT_STD)
        lcd.drawText(6, radio.yMinLimit, init.t)
    elseif uiState == uiStatus.mainMenu then
        print("painting uiState == uiStatus.mainMenu")
        local yMinLim = radio.yMinLimit
        local yMaxLim = radio.yMaxLimit
        local lineSpacing = radio.lineSpacing
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
        drawScreen()
        if pageState >= pageStatus.saving then
            local saveMsg = ""
            if pageState == pageStatus.saving then
                saveMsg = "Saving..."
                if saveRetries > 0 then
                    saveMsg = "Retry #"..string.format("%u",saveRetries)
                end
            elseif pageState == pageStatus.eepromWrite then
                saveMsg = "Updating..."
                if saveRetries > 0 then
                    saveMsg = "Retry #"..string.format("%u",saveRetries)
                end
            elseif pageState == pageStatus.rebooting then
                saveMsg = "Rebooting..."
            end
            lcd.color(MENU_TITLE_BGCOLOR)
            lcd.drawFilledRectangle(radio.SaveBox.x,radio.SaveBox.y,radio.SaveBox.w,radio.SaveBox.h)
            lcd.color(MENU_TITLE_COLOR)
            lcd.drawRectangle(radio.SaveBox.x,radio.SaveBox.y,radio.SaveBox.w,radio.SaveBox.h)
            lcd.color(MENU_TITLE_COLOR)
            lcd.font(FONT_L)
            lcd.drawText(radio.SaveBox.x+radio.SaveBox.x_offset,radio.SaveBox.y+radio.SaveBox.h_offset,saveMsg)
        end
    elseif uiState == uiStatus.confirm then
        drawScreen()
    end

    -- drawScreenTitle(screenTitle) from ui.c
    if screenTitle then
        lcd.color(MENU_TITLE_BGCOLOR)
        lcd.drawFilledRectangle(0, 0, LCD_W, 30)
        lcd.color(MENU_TITLE_COLOR)
        lcd.font(FONT_STD)
        lcd.drawText(5,5,screenTitle)
    end

    -- drawPopupMenu() from ui.c
    if popupMenu then
        print("painting popupMenu")
        local x = radio.MenuBox.x
        local y = radio.MenuBox.y
        local w = radio.MenuBox.w
        local h_line = radio.MenuBox.h_line
        local h_offset = radio.MenuBox.h_offset
        local h = #popupMenu * h_line + h_offset*2

        lcd.color(MENU_TITLE_BGCOLOR)
        lcd.drawFilledRectangle(x,y,w,h)
        lcd.color(MENU_TITLE_COLOR)
        lcd.drawRectangle(x,y,w-1,h-1)
        lcd.color(MENU_TITLE_COLOR)
        lcd.font(FONT_STD)

        for i,e in ipairs(popupMenu) do
            if popupMenuActive == i then
                lcd.font(FONT_BOLD)
                lcd.color(ITEM_TEXT_SELECTED)
            else
                lcd.font(FONT_STD)
                lcd.color(ITEM_TEXT_NORMAL)
            end
           lcd.drawText(x+radio.MenuBox.x_offset,y+(i-1)*h_line+h_offset,e.t)
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

return {init=init}