local kittyname = UnitName("player")

local function IsDebugEnabled()
    return CCT_IsDebugEnabled and CCT_IsDebugEnabled()
end

local cleanupFrame = nil

local function EnsureCleanupFrame()
    if cleanupFrame then
        return
    end

    cleanupFrame = CreateFrame("Frame", "CatgirlCleanupFrame", UIParent, "BackdropTemplate")
    cleanupFrame:SetSize(360, 220)
    cleanupFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -30, -440)
    cleanupFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    cleanupFrame:SetBackdropColor(0, 0, 0, 0.8)
    cleanupFrame:SetMovable(true)
    cleanupFrame:EnableMouse(true)
    cleanupFrame:RegisterForDrag("LeftButton")
    cleanupFrame:SetScript("OnDragStart", cleanupFrame.StartMoving)
    cleanupFrame:SetScript("OnDragStop", cleanupFrame.StopMovingOrSizing)

    cleanupFrame.title = cleanupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cleanupFrame.title:SetPoint("TOPLEFT", 12, -10)
    cleanupFrame.title:SetText("Catgirl Cleanup")

    cleanupFrame.totalText = cleanupFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cleanupFrame.totalText:SetPoint("TOPLEFT", cleanupFrame.title, "BOTTOMLEFT", 0, -8)
    cleanupFrame.totalText:SetWidth(330)
    cleanupFrame.totalText:SetJustifyH("LEFT")
    cleanupFrame.totalText:SetText("Total entries: 0")

    cleanupFrame.detailText = cleanupFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cleanupFrame.detailText:SetPoint("TOPLEFT", cleanupFrame.totalText, "BOTTOMLEFT", 0, -4)
    cleanupFrame.detailText:SetWidth(330)
    cleanupFrame.detailText:SetJustifyH("LEFT")
    cleanupFrame.detailText:SetText("")

    cleanupFrame.inputLabel = cleanupFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cleanupFrame.inputLabel:SetPoint("TOPLEFT", cleanupFrame.detailText, "BOTTOMLEFT", 0, -10)
    cleanupFrame.inputLabel:SetText("Delete oldest entries (total):")

    cleanupFrame.inputBox = CreateFrame("EditBox", nil, cleanupFrame, "InputBoxTemplate")
    cleanupFrame.inputBox:SetSize(80, 20)
    cleanupFrame.inputBox:SetPoint("TOPLEFT", cleanupFrame.inputLabel, "BOTTOMLEFT", 0, -4)
    cleanupFrame.inputBox:SetAutoFocus(false)
    if cleanupFrame.inputBox.SetNumeric then
        cleanupFrame.inputBox:SetNumeric(true)
    end
    cleanupFrame.inputBox:SetText("100")
    cleanupFrame.inputBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    cleanupFrame.inputBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    cleanupFrame.deleteButton = CreateFrame("Button", nil, cleanupFrame, "UIPanelButtonTemplate")
    cleanupFrame.deleteButton:SetSize(80, 22)
    cleanupFrame.deleteButton:SetPoint("LEFT", cleanupFrame.inputBox, "RIGHT", 8, 0)
    cleanupFrame.deleteButton:SetText("Delete")

    cleanupFrame.statusText = cleanupFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cleanupFrame.statusText:SetPoint("TOPLEFT", cleanupFrame.inputBox, "BOTTOMLEFT", 0, -8)
    cleanupFrame.statusText:SetWidth(330)
    cleanupFrame.statusText:SetJustifyH("LEFT")
    cleanupFrame.statusText:SetText("")

    cleanupFrame:Hide()
end

local function GetLogsForKitty()
    local logs = {}

    local function add(label, list)
        if type(list) == "table" then
            table.insert(logs, { label = label, list = list })
        end
    end

    if CatgirlBehaviorDB and CatgirlBehaviorDB.BehaviorLog then
        add("Behavior", CatgirlBehaviorDB.BehaviorLog[kittyname])
    end
    if CatgirlPetDB and CatgirlPetDB.PetLog then
        add("Pet", CatgirlPetDB.PetLog[kittyname])
    end
    if CatgirlZoneDB and CatgirlZoneDB.ZoneLog then
        add("Zone", CatgirlZoneDB.ZoneLog[kittyname])
    end
    if CatgirlEmoteDB and CatgirlEmoteDB.EmoteLog then
        add("Emote", CatgirlEmoteDB.EmoteLog[kittyname])
    end
    if CatgirlGuildDB and CatgirlGuildDB.GuildLog then
        add("Guild", CatgirlGuildDB.GuildLog[kittyname])
    end
    if CatgirlLocationDB and CatgirlLocationDB.LocationLog then
        add("Location", CatgirlLocationDB.LocationLog[kittyname])
    end

    return logs
end

local function CountTotals(logs)
    local total = 0
    local lines = {}
    for _, log in ipairs(logs) do
        local count = 0
        if log.list then
            count = #log.list
        end
        total = total + count
        table.insert(lines, string.format("%s: %d", log.label, count))
    end
    return total, table.concat(lines, "  ")
end

local function DeleteOldestEntries(logs, count)
    if count <= 0 then
        return 0
    end

    local total = 0
    for _, log in ipairs(logs) do
        if log.list then
            total = total + #log.list
        end
    end
    if total == 0 then
        return 0
    end

    if count > total then
        count = total
    end

    local removed = 0
    local logIndex = 1
    local logCount = #logs

    while removed < count and logCount > 0 do
        if logIndex > logCount then
            logIndex = 1
        end
        local log = logs[logIndex]
        if log and log.list and #log.list > 0 then
            table.remove(log.list, 1)
            removed = removed + 1
        end
        logIndex = logIndex + 1
    end

    return removed
end

local function RefreshCleanupFrame()
    if not IsDebugEnabled() then
        if cleanupFrame then
            cleanupFrame:Hide()
        end
        return
    end

    EnsureCleanupFrame()
    cleanupFrame:Show()

    local logs = GetLogsForKitty()
    local total, detail = CountTotals(logs)
    cleanupFrame.totalText:SetText("Total entries: " .. total)
    cleanupFrame.detailText:SetText(detail ~= "" and detail or "No logs found.")
end

local function OnDeleteClicked()
    local logs = GetLogsForKitty()
    local total = 0
    for _, log in ipairs(logs) do
        if log.list then
            total = total + #log.list
        end
    end

    local value = tonumber(cleanupFrame.inputBox:GetText())
    if not value or value <= 0 then
        cleanupFrame.statusText:SetText("Enter a number greater than 0.")
        return
    end
    if total <= 0 then
        cleanupFrame.statusText:SetText("No entries to delete.")
        return
    end

    local removed = DeleteOldestEntries(logs, value)
    cleanupFrame.statusText:SetText(string.format("Deleted %d entries.", removed))
    RefreshCleanupFrame()
end

local function InitializeCleanup()
    EnsureCleanupFrame()
    cleanupFrame.deleteButton:SetScript("OnClick", OnDeleteClicked)
    RefreshCleanupFrame()
    C_Timer.NewTicker(2, RefreshCleanupFrame)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    InitializeCleanup()
end)
