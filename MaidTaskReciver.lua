local addonPrefix = "CatgirlTracker"
local myName = UnitName("player")
local myShortName = myName and myName:match("^[^%-]+") or myName

CatgirlSettingsDB = CatgirlSettingsDB or {}
CatgirlSettingsDB.maidTaskInstructions = CatgirlSettingsDB.maidTaskInstructions or {}
CatgirlSettingsDB.maidTaskInstructions[myShortName] = CatgirlSettingsDB.maidTaskInstructions[myShortName] or {}

local maidRuntime = {
    updateId = nil,
    expectedCount = 0,
    receivedCount = 0,
    ownerShort = nil,
    itemsByIndex = {},
    items = {},
}

local maidFrame = nil
local maidInstructionText = nil
local maidItemsText = nil
local maidContent = nil

local function IsModuleEnabled()
    return not CCT_IsModuleEnabled or CCT_IsModuleEnabled("MaidTasks")
end

local function ShortName(name)
    if not name then return name end
    return name:match("^[^%-]+")
end

local function RequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function GetOwnerFromNote()
    if not IsInGuild() then
        return nil
    end
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note, officerNote = GetGuildRosterInfo(i)
        if name and ShortName(name) == myShortName then
            local source = nil
            if type(officerNote) == "string" and officerNote ~= "" then
                source = officerNote
            elseif type(note) == "string" and note ~= "" then
                source = note
            end
            local owner = source and source:match("owner=([^,]+)") or nil
            return ShortName(owner)
        end
    end
end

local function IsOwnerSender(senderShort)
    local ownerShort = GetOwnerFromNote()
    if not ownerShort or not senderShort then
        return false
    end
    return ownerShort:lower() == senderShort:lower()
end

local function Decode(text)
    if not text then return "" end
    local s = tostring(text)
    s = s:gsub("%%0A", "\n")
    s = s:gsub("%%3B", ";")
    s = s:gsub("%%2C", ",")
    s = s:gsub("%%25", "%%")
    return s
end

local function SaveInstruction(ownerShort, instruction)
    CatgirlSettingsDB = CatgirlSettingsDB or {}
    CatgirlSettingsDB.maidTaskInstructions = CatgirlSettingsDB.maidTaskInstructions or {}
    CatgirlSettingsDB.maidTaskInstructions[myShortName] = CatgirlSettingsDB.maidTaskInstructions[myShortName] or {}
    local db = CatgirlSettingsDB.maidTaskInstructions[myShortName]
    db.ownerShort = ownerShort
    db.text = instruction
    db.updatedAt = time()
end

local function GetSavedInstruction()
    CatgirlSettingsDB = CatgirlSettingsDB or {}
    CatgirlSettingsDB.maidTaskInstructions = CatgirlSettingsDB.maidTaskInstructions or {}
    CatgirlSettingsDB.maidTaskInstructions[myShortName] = CatgirlSettingsDB.maidTaskInstructions[myShortName] or {}
    local db = CatgirlSettingsDB.maidTaskInstructions[myShortName]
    return db and db.text or ""
end

local function EnsureMaidFrame()
    if maidFrame then return maidFrame end

    maidFrame = CreateFrame("Frame", "CatgirlMaidTaskFrame", UIParent, "BackdropTemplate")
    maidFrame:SetSize(320, 420)
    maidFrame:SetPoint("CENTER", UIParent, "CENTER", 380, 0)
    maidFrame:SetMovable(true)
    maidFrame:EnableMouse(true)
    maidFrame:RegisterForDrag("LeftButton")
    maidFrame:SetScript("OnDragStart", maidFrame.StartMoving)
    maidFrame:SetScript("OnDragStop", maidFrame.StopMovingOrSizing)

    maidFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    maidFrame:SetBackdropColor(0, 0, 0, 0.75)

    local closeBtn = CreateFrame("Button", nil, maidFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    local title = maidFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Maid Tasks")

    local scroll = CreateFrame("ScrollFrame", nil, maidFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -40)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)

    maidContent = CreateFrame("Frame", nil, scroll)
    maidContent:SetPoint("TOPLEFT", 0, 0)
    maidContent:SetWidth(260)
    scroll:SetScrollChild(maidContent)

    maidInstructionText = maidContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    maidInstructionText:SetPoint("TOPLEFT", 0, 0)
    maidInstructionText:SetWidth(250)
    maidInstructionText:SetJustifyH("LEFT")
    maidInstructionText:SetText("")

    maidItemsText = maidContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    maidItemsText:SetPoint("TOPLEFT", 0, -80)
    maidItemsText:SetWidth(250)
    maidItemsText:SetJustifyH("LEFT")
    maidItemsText:SetText("")

    maidFrame:Hide()
    return maidFrame
end

local function BuildItemsLines(items)
    if not items or #items == 0 then
        return { "No maid tasks synced yet." }
    end
    local lines = { "Owner inventory:" }
    for _, item in ipairs(items) do
        local label = item.name or "Unknown item"
        local count = item.count or 0
        table.insert(lines, string.format("%s: %d", label, count))
    end
    return lines
end

local function UpdateMaidFrame()
    local frame = EnsureMaidFrame()
    if not frame or not maidInstructionText or not maidItemsText then return end

    local instruction = GetSavedInstruction()
    if instruction and instruction ~= "" then
        maidInstructionText:SetText("Instructions: " .. instruction)
    else
        maidInstructionText:SetText("Instructions: None.")
    end

    local lines = BuildItemsLines(maidRuntime.items)
    maidItemsText:SetText(table.concat(lines, "\n"))

    local instructionHeight = maidInstructionText:GetStringHeight() or 40
    maidItemsText:ClearAllPoints()
    maidItemsText:SetPoint("TOPLEFT", 0, -instructionHeight - 16)

    local totalLines = #lines + 4
    local height = (totalLines * 14) + instructionHeight + 40
    maidContent:SetHeight(math.max(200, height))
end

local function ShouldShowFrame()
    local instruction = GetSavedInstruction()
    if instruction and instruction ~= "" then
        return true
    end
    return maidRuntime.items and #maidRuntime.items > 0
end

local function FinalizeUpdate()
    maidRuntime.items = {}
    for index = 1, maidRuntime.expectedCount do
        local item = maidRuntime.itemsByIndex[index]
        if item then
            table.insert(maidRuntime.items, item)
        end
    end

    UpdateMaidFrame()

    local frame = EnsureMaidFrame()
    if ShouldShowFrame() then
        frame:Show()
    else
        frame:Hide()
    end
end

local function HandleHeader(msg, senderShort)
    local idText, ownerShort, countText, instructionText = msg:match(
        "^MaidTasksHeader, id:(%d+), owner:([^,]+), count:(%d+), instruction:(.*)$"
    )
    if not idText then return end

    maidRuntime.updateId = tonumber(idText)
    maidRuntime.expectedCount = tonumber(countText) or 0
    maidRuntime.receivedCount = 0
    maidRuntime.ownerShort = ownerShort
    maidRuntime.itemsByIndex = {}

    local decodedInstruction = Decode(instructionText or "")
    SaveInstruction(senderShort, decodedInstruction)

    if maidRuntime.expectedCount == 0 then
        FinalizeUpdate()
    end
end

local function HandleItem(msg)
    local idText, indexText, itemIDText, nameText, countText = msg:match(
        "^MaidTasksItem, id:(%d+), index:(%d+), itemID:([^,]+), name:(.*), count:(%d+)$"
    )
    if not idText then return end

    local id = tonumber(idText)
    if not maidRuntime.updateId or id ~= maidRuntime.updateId then
        return
    end

    local index = tonumber(indexText)
    if not index then return end

    if not maidRuntime.itemsByIndex[index] then
        maidRuntime.receivedCount = maidRuntime.receivedCount + 1
    end

    local itemID = itemIDText ~= "nil" and tonumber(itemIDText) or nil
    local name = Decode(nameText or "")
    local count = tonumber(countText) or 0

    maidRuntime.itemsByIndex[index] = {
        itemID = itemID,
        name = name,
        count = count,
    }

    if maidRuntime.receivedCount >= maidRuntime.expectedCount then
        FinalizeUpdate()
    end
end

C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
    if event ~= "CHAT_MSG_ADDON" then return end
    if prefix ~= addonPrefix then return end
    if not IsModuleEnabled() then return end
    if channel ~= "WHISPER" then return end

    local senderShort = ShortName(sender)
    if not IsOwnerSender(senderShort) then
        return
    end

    if msg:match("^MaidTasksHeader,") then
        HandleHeader(msg, senderShort)
        return
    end

    if msg:match("^MaidTasksItem,") then
        HandleItem(msg)
        return
    end
end)

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_LOGIN" then return end
    CatgirlSettingsDB = CatgirlSettingsDB or {}
    CatgirlSettingsDB.maidTaskInstructions = CatgirlSettingsDB.maidTaskInstructions or {}
    CatgirlSettingsDB.maidTaskInstructions[myShortName] = CatgirlSettingsDB.maidTaskInstructions[myShortName] or {}
    if CCT_SetModuleEnabled then
        CCT_SetModuleEnabled("MaidTasks", true)
    end
end)

CCT_AutoPrint("MaidTaskReciver loaded.")
