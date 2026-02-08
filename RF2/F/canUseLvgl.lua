-- Usage: local canUseLvgl = rf2.executeScript("F/canUseLvgl")()
local function canUseLvgl()
    return false -- EdgeTX 2.11+ only
end

return canUseLvgl