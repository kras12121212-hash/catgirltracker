local addonName = "CatGirlControlCenter"
local f = CreateFrame("Frame")
local kittyname = UnitName("player"):match("^[^%-]+") -- short name only
local controlOpenButton = nil

SLASH_CGCC1 = "/cgcc"

local function RequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

-- Find who you're the owner of (based on officer note format: owner=Holykitten,...)
local function GetAssignedCatgirl()
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, officerNote = GetGuildRosterInfo(i)
        if name and officerNote then
            local ownerName = officerNote:match("owner=([^,]+)")
            if ownerName and ownerName:match("^[^%-]+") == kittyname then
                return name
            end
        end
    end
    return nil
end

-- Whisper to kitten
local function WhisperToKitten(kitten, command)
    if kitten then
        SendChatMessage(command, "WHISPER", nil, kitten)
    end
end

local function ShortName(name)
    if not name then return name end
    return name:match("^[^%-]+")
end

local function FormatKittenLabel(kitten)
    if kitten and kitten ~= "" then
        return "Kitten: " .. kitten
    end
    return "Kitten: None assigned"
end

local function FindLastEvent(log, eventName)
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == eventName then
            return entry
        end
    end
end

local function FormatGagState(state)
    if not state then return "Unknown" end
    if type(state) == "string" then
        local stage = state:match("^Inflatable:(%d+)")
        if stage then
            return string.format("Inflatable gag (stage %s)", stage)
        end
        if state == "Inflatable" then
            return "Inflatable gag"
        end
    end
    local map = {
        Gag = "Heavy gag",
        LightGag = "Small gag",
        FullBlock = "Full mask gag",
        NyaMask = "Cute Nya mask",
        none = "None",
        UnGag = "None",
    }
    return map[state] or tostring(state)
end

local function FormatBlindfoldState(state)
    if not state then return "Unknown" end
    local map = {
        light = "Light",
        full = "Full",
        mask = "Kitty mask",
        remove = "None",
        none = "None",
    }
    return map[state] or tostring(state)
end

local function FormatEarmuffState(state)
    if not state then return "Unknown" end
    local map = {
        KittenEarmuffs = "Kitten earmuffs",
        HeavyEarmuffs = "Heavy earmuffs",
        none = "None",
    }
    return map[state] or tostring(state)
end

local function FormatBooleanState(value)
    if value == nil then return "Unknown" end
    return value and "On" or "Off"
end

local function FormatCoords(entry)
    if not entry then return "Unknown" end
    local stamp = entry.receivedAt and date("%Y-%m-%d %H:%M:%S", entry.receivedAt) or entry.timestamp
    local mapPart = entry.mapID and ("map " .. entry.mapID) or "map ?"
    if entry.x and entry.y then
        return string.format("%s (%s, %.4f, %.4f)", stamp or "Unknown time", mapPart, entry.x, entry.y)
    end
    return string.format("%s (%s)", stamp or "Unknown time", mapPart)
end

local function GetPlayerMapCoords()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return nil end
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if not pos then return nil end
        local x, y = pos.x, pos.y
        if pos.GetXY then
            x, y = pos:GetXY()
        end
        if x and y then
            return mapID, x, y
        end
    end
    if GetPlayerMapPosition then
        local x, y = GetPlayerMapPosition("player")
        if x and y then
            return nil, x, y
        end
    end
end

local function FormatDistanceToKitten(entry)
    if not entry or not entry.x or not entry.y then
        return "Distance to kitten: Unknown"
    end

    local ownerMapID, ownerX, ownerY = GetPlayerMapCoords()
    if not ownerX or not ownerY then
        return "Distance to kitten: Unknown (owner position)"
    end

    if entry.mapID and ownerMapID and entry.mapID ~= ownerMapID then
        return string.format("Distance to kitten: Map mismatch (kitten map %s, owner map %s)", tostring(entry.mapID), tostring(ownerMapID))
    end

    local dx = ownerX - entry.x
    local dy = ownerY - entry.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local mapPart = entry.mapID and ("map " .. entry.mapID) or "map ?"
    return string.format("Distance to kitten: %.4f (%s units)", dist, mapPart)
end

local function FormatRemaining(seconds)
    if not seconds or seconds <= 0 then return nil end
    local total = math.floor(seconds)
    local minutes = math.floor(total / 60)
    local hours = math.floor(minutes / 60)
    local remMinutes = minutes % 60
    local remSeconds = total % 60
    if hours > 0 then
        return string.format("%dh %dm", hours, remMinutes)
    end
    if minutes > 0 then
        return string.format("%dm %ds", minutes, remSeconds)
    end
    return string.format("%ds", remSeconds)
end

local function GetLeashState(log)
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "KittenLeash" then
            return "Leashed"
        elseif entry.event == "KittenUnleash" then
            return "Unleashed"
        end
    end
    return "Unknown"
end

local function BuildStatsLines(kittenName)
    if not kittenName or kittenName == "" then
        return { "No data synced for this kitten yet." }
    end
    local kittenKey = ShortName(kittenName)
    local log = CatgirlBehaviorDB
        and CatgirlBehaviorDB.BehaviorLog
        and CatgirlBehaviorDB.BehaviorLog[kittenKey]

    if not log or type(log) ~= "table" then
        return { "No data synced for this kitten yet." }
    end

    local lines = {}
    table.insert(lines, "Applied binds:")

    local gagEntry = FindLastEvent(log, "KittenGag")
    table.insert(lines, "Gag: " .. FormatGagState(gagEntry and gagEntry.Gagstate))

    local blindEntry = FindLastEvent(log, "KittenBlindfold")
    table.insert(lines, "Blindfold: " .. FormatBlindfoldState(blindEntry and blindEntry.BlindfoldState))

    local earEntry = FindLastEvent(log, "KittenEarmuffs")
    table.insert(lines, "Earmuffs: " .. FormatEarmuffState(earEntry and earEntry.state))

    local bellEntry = FindLastEvent(log, "BellState")
    table.insert(lines, "Bell: " .. FormatBooleanState(bellEntry and bellEntry.state))

    local tailEntry = FindLastEvent(log, "TailBellState")
    table.insert(lines, "Tail Bell: " .. FormatBooleanState(tailEntry and tailEntry.state))

    local trackingEntry = FindLastEvent(log, "TrackingJewel")
    table.insert(lines, "Tracking Jewel: " .. FormatBooleanState(trackingEntry and trackingEntry.state))

    table.insert(lines, "Leash: " .. GetLeashState(log))

    local locationLog = CatgirlLocationDB
        and CatgirlLocationDB.LocationLog
        and CatgirlLocationDB.LocationLog[kittenKey]
    if locationLog and #locationLog > 0 then
        local lastLocation = locationLog[#locationLog]
        table.insert(lines, "Last Location Sync: " .. FormatCoords(lastLocation))
        table.insert(lines, FormatDistanceToKitten(lastLocation))
    else
        table.insert(lines, "Last Location Sync: None")
        table.insert(lines, "Distance to kitten: Unknown")
    end

    local timerLines = {}
    local timerKeys = {
        { key = "gag", label = "Gag" },
        { key = "earmuffs", label = "Earmuffs" },
        { key = "blindfold", label = "Blindfold" },
        { key = "bell", label = "Bell" },
        { key = "tailbell", label = "Tail Bell" },
    }

    for _, timer in ipairs(timerKeys) do
        local entry = log[timer.key]
        if entry and entry.unlockAt then
            local remaining = entry.unlockAt - time()
            local remainingText = FormatRemaining(remaining)
            if remainingText then
                table.insert(timerLines, string.format("%s: %s remaining", timer.label, remainingText))
            end
        end
    end

    table.insert(lines, "")
    if #timerLines > 0 then
        table.insert(lines, "Timed removals:")
        for _, line in ipairs(timerLines) do
            table.insert(lines, line)
        end
    else
        table.insert(lines, "Timed removals: none")
    end

    return lines
end

-- Create control panel UI
local function ShowControlPanel(kitten)
    local hasKitten = kitten and kitten ~= ""
    local kittenName = hasKitten and kitten or nil
    local frame = CatGirlControlPanel
    if frame then
        frame.kitten = kittenName
        frame.hasKitten = hasKitten
        frame.kittenName:SetText(FormatKittenLabel(frame.kitten))
        frame:Show()
        if frame.selectedTab == "Stats" and frame.UpdateStats then
            frame:UpdateStats()
        end
        return
    end

    frame = CreateFrame("Frame", "CatGirlControlPanel", UIParent, "BackdropTemplate")
    frame:SetSize(360, 520)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.6)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -10)
    frame.title:SetText("Catgirl Control")

    frame.kittenName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.kittenName:SetPoint("TOP", 0, -30)
    frame.kittenName:SetText(FormatKittenLabel(kittenName))

    frame.kitten = kittenName
    frame.hasKitten = hasKitten

    local function CreateScrollArea(parent)
        local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 0, 0)
        scroll:SetPoint("BOTTOMRIGHT", -26, 0)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetPoint("TOPLEFT", 0, 0)
        content:SetWidth(300)
        scroll:SetScrollChild(content)
        return scroll, content
    end

    local function AddHeader(parent, y, text)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 0, y)
        label:SetText(text)
        return y - 16
    end

    local function AddButton(parent, y, label, command)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(240, 20)
        btn:SetPoint("TOPLEFT", 0, y)
        btn:SetText(label)
        btn:SetScript("OnClick", function()
            WhisperToKitten(frame.kitten, command)
        end)
        return y - 24
    end

    local function AddDelayRow(parent, y, label, msgTemplate)
        local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        box:SetSize(30, 20)
        box:SetPoint("TOPLEFT", 0, y)
        box:SetAutoFocus(false)
        box:SetText("1.5")

        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(200, 20)
        btn:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 0)
        btn:SetText(label)

        btn:SetScript("OnClick", function()
            local val = tonumber(box:GetText())
            if val and val > 0 then
                local minutes = math.floor(val * 60 + 0.5)
                local msg = msgTemplate:format(val, minutes)
                WhisperToKitten(frame.kitten, msg)
            else
                print("|cffff5555[CatGirlControlCenter]|r Invalid number.")
            end
        end)
        return y - 24
    end

    local function AddCheckbox(parent, y, label, getValue, setValue)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 0, y)
        local text = cb.Text or cb.text
        if text then
            text:SetText(label)
        end
        cb:SetChecked(getValue())
        cb:SetScript("OnClick", function(self)
            setValue(self:GetChecked())
        end)
        cb:SetScript("OnShow", function(self)
            self:SetChecked(getValue())
        end)
        return cb, y - 24
    end

    local tabNames = { "Stats", "Apply Binds", "Remove Binds", "Settings" }
    local tabButtons = {}
    local tabFrames = {}

    local tabWidth = 80
    local tabSpacing = 4
    for i, name in ipairs(tabNames) do
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(tabWidth, 20)
        btn:SetPoint("TOPLEFT", 10 + (i - 1) * (tabWidth + tabSpacing), -55)
        btn:SetText(name)
        tabButtons[name] = btn
    end

    local contentArea = CreateFrame("Frame", nil, frame)
    contentArea:SetPoint("TOPLEFT", 10, -80)
    contentArea:SetPoint("BOTTOMRIGHT", -10, 10)

    local function CreateTabFrame()
        local tab = CreateFrame("Frame", nil, contentArea)
        tab:SetAllPoints(contentArea)
        tab:Hide()
        return tab
    end

    -- Stats tab
    local statsTab = CreateTabFrame()
    local statsScroll, statsContent = CreateScrollArea(statsTab)
    local refreshBtn = CreateFrame("Button", nil, statsContent, "UIPanelButtonTemplate")
    refreshBtn:SetSize(120, 20)
    refreshBtn:SetPoint("TOPLEFT", 0, 0)
    refreshBtn:SetText("Refresh")

    local warningText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    warningText:SetPoint("TOPLEFT", 0, -26)
    warningText:SetJustifyH("LEFT")
    warningText:SetWidth(280)
    warningText:SetTextColor(1, 0.1, 0.1)
    warningText:SetText("You dont own a kitten yet most Functions not avilable!!!")
    warningText:Hide()

    local statsText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsText:SetPoint("TOPLEFT", 0, -70)
    statsText:SetJustifyH("LEFT")
    statsText:SetWidth(280)
    statsText:SetText("")

    frame.UpdateStats = function(self)
        local noKitten = not self.kitten
        warningText:SetShown(noKitten)
        local lines = BuildStatsLines(self.kitten)
        statsText:SetText(table.concat(lines, "\n"))
        local lineHeight = 14
        local height = (#lines * lineHeight) + 40
        if noKitten then
            height = height + 44
        end
        statsContent:SetHeight(math.max(120, height))
    end

    refreshBtn:SetScript("OnClick", function()
        frame:UpdateStats()
    end)

    tabFrames["Stats"] = statsTab

    -- Apply Binds tab
    local applyTab = CreateTabFrame()
    local applyScroll, applyContent = CreateScrollArea(applyTab)
    local y = -4

    y = AddHeader(applyContent, y, "Leash")
    y = AddButton(applyContent, y, "Leash", "leash")
    y = y - 6

    y = AddHeader(applyContent, y, "Gags and Masks")
    y = AddButton(applyContent, y, "Cute Kitten Mask", "Your owner gave you a cute~ Kitten Mask ~UwU~ It gives you an irresistible urge to Nya in every sentence.")
    y = AddButton(applyContent, y, "Small Gag", "Your owner has fitted a small silken gag over your mouth. Speech is now garbled.")
    y = AddButton(applyContent, y, "Heavy Gag", "Your owner has secured a heavy gag in place. You can no longer speak.")
    y = AddButton(applyContent, y, "Kitty Mask With Gag!", "Your owner put a gag and a Kitten Mask on you! You must have been a really naughty cat!")
    y = AddButton(applyContent, y, "Inflatable Gag", "Your owner fits an inflatable gag over your mouth.")
    y = AddButton(applyContent, y, "Inflate Gag", "Your owner inflates your gag.")
    y = AddButton(applyContent, y, "Deflate Gag", "Your owner deflates your gag.")
    y = y - 6

    y = AddHeader(applyContent, y, "Earmuffs")
    y = AddButton(applyContent, y, "Kitten Earmuffs", "Your owner put kitten earmuffs on you.")
    y = AddButton(applyContent, y, "Heavy Earmuffs", "Your owner put heavy earmuffs on you, Nyo!!!")
    y = y - 6

    y = AddHeader(applyContent, y, "Blindfolds")
    y = AddButton(applyContent, y, "Light Blindfold", "Your owner put a light blindfold on you.")
    y = AddButton(applyContent, y, "Cute Kitty Blindfold", "Your owner put a cute kitty blindfold on you.")
    y = AddButton(applyContent, y, "Full Blindfold", "Your owner put a full blindfold on you.")
    y = y - 6

    y = AddHeader(applyContent, y, "Bells")
    y = AddButton(applyContent, y, "Attach Bell", "You hear a soft *click* as your owner attaches a tiny bell to your collar. Every step now jingles~")
    y = AddButton(applyContent, y, "Attach Tail Bell", "You hear a soft *click* as your owner attaches a tiny bell to your tail. Every step now jingles~")
    y = y - 6

    y = AddHeader(applyContent, y, "Tracking")
    y = AddButton(applyContent, y, "Attach Tracking Jewel", "Your owner attached a glowing jewel to your collar. Its magic will track your every move!")

    applyContent:SetHeight(math.max(200, -y + 10))
    tabFrames["Apply Binds"] = applyTab

    -- Remove Binds tab
    local removeTab = CreateTabFrame()
    local removeScroll, removeContent = CreateScrollArea(removeTab)
    y = -4

    y = AddHeader(removeContent, y, "Leash")
    y = AddButton(removeContent, y, "Unleash", "unleash")
    y = y - 6

    y = AddHeader(removeContent, y, "Gags and Masks")
    y = AddButton(removeContent, y, "Ungag", "Your gag has been removed by your owner. You can speak freely again.")
    y = AddDelayRow(removeContent, y, "Remove Gag in X Hours", "Your owner set your gag to unlock in %.1f hours (%d) minutes.")
    y = y - 6

    y = AddHeader(removeContent, y, "Earmuffs")
    y = AddButton(removeContent, y, "Remove Earmuffs", "Your owner removed your earmuffs. Puhhh~")
    y = AddDelayRow(removeContent, y, "Remove Earmuffs in X Hours", "Your owner set your earmuffs to unlock in %.1f hours (%d) minutes.")
    y = y - 6

    y = AddHeader(removeContent, y, "Blindfolds")
    y = AddButton(removeContent, y, "Remove Blindfold", "Your owner removed your blindfold.")
    y = AddDelayRow(removeContent, y, "Remove Blindfold in X Hours", "Your owner set your blindfold to unlock in %.1f hours (%d) minutes.")
    y = y - 6

    y = AddHeader(removeContent, y, "Bell")
    y = AddButton(removeContent, y, "Remove Bell", "With a gentle touch, your owner removes the bell from your collar. It's quiet again... for now.")
    y = AddDelayRow(removeContent, y, "Remove Bell in X Hours", "Your owner set your bell to unlock in %.1f hours (%d) minutes.")
    y = y - 6

    y = AddHeader(removeContent, y, "Tail Bell")
    y = AddButton(removeContent, y, "Remove Tail Bell", "With a gentle touch, your owner removes the tail bell. It's quiet again... for now.")
    y = AddDelayRow(removeContent, y, "Remove Tail Bell in X Hours", "Your owner set your tail bell to unlock in %.1f hours (%d) minutes.")
    y = y - 6

    y = AddHeader(removeContent, y, "Tracking")
    y = AddButton(removeContent, y, "Remove Tracking Jewel", "Your owner removed the glowing jewel from your collar. Its magic will no longer track you.")

    removeContent:SetHeight(math.max(200, -y + 10))
    tabFrames["Remove Binds"] = removeTab

    -- Settings tab
    local settingsTab = CreateTabFrame()
    local settingsScroll, settingsContent = CreateScrollArea(settingsTab)
    y = -4

    y = AddHeader(settingsContent, y, "Debug")
    local debugBox
    debugBox, y = AddCheckbox(
        settingsContent,
        y,
        "Enable debug output",
        function() return CCT_IsDebugEnabled and CCT_IsDebugEnabled() or false end,
        function(value)
            if CCT_SetDebugEnabled then
                CCT_SetDebugEnabled(value)
            end
        end
    )
    y = y - 6

    y = AddHeader(settingsContent, y, "Modules")
    local hpBox
    hpBox, y = AddCheckbox(
        settingsContent,
        y,
        "HeadPetTracker",
        function() return CCT_IsModuleEnabled and CCT_IsModuleEnabled("HeadPetTracker") or true end,
        function(value)
            if CCT_SetModuleEnabled then
                CCT_SetModuleEnabled("HeadPetTracker", value)
            end
        end
    )
    local innBox
    innBox, y = AddCheckbox(
        settingsContent,
        y,
        "InnSlackerTracker",
        function() return CCT_IsModuleEnabled and CCT_IsModuleEnabled("InnSlackerTracker") or true end,
        function(value)
            if CCT_SetModuleEnabled then
                CCT_SetModuleEnabled("InnSlackerTracker", value)
            end
        end
    )
    local petBox
    petBox, y = AddCheckbox(
        settingsContent,
        y,
        "PetTracker (Summon button)",
        function() return CCT_IsModuleEnabled and CCT_IsModuleEnabled("PetTracker") or true end,
        function(value)
            if CCT_SetModuleEnabled then
                CCT_SetModuleEnabled("PetTracker", value)
            end
        end
    )

    local mapBox
    mapBox, y = AddCheckbox(
        settingsContent,
        y,
        "Show tracking path on world map",
        function() return CCT_IsModuleEnabled and CCT_IsModuleEnabled("KittenMapShow") or false end,
        function(value)
            if CCT_SetModuleEnabled then
                CCT_SetModuleEnabled("KittenMapShow", value)
            end
        end
    )

    y = y - 6
    y = AddHeader(settingsContent, y, "Maid Tasks")

    local maidInput = CreateFrame("EditBox", nil, settingsContent, "InputBoxTemplate")
    maidInput:SetSize(180, 20)
    maidInput:SetPoint("TOPLEFT", 0, y)
    maidInput:SetAutoFocus(false)
    maidInput:SetText("")

    local maidAddBtn = CreateFrame("Button", nil, settingsContent, "UIPanelButtonTemplate")
    maidAddBtn:SetSize(90, 20)
    maidAddBtn:SetPoint("LEFT", maidInput, "RIGHT", 6, 0)
    maidAddBtn:SetText("Add Task")

    local maidListTopY = y - 26
    local maidListContainer = CreateFrame("Frame", nil, settingsContent)
    maidListContainer:SetPoint("TOPLEFT", 0, maidListTopY)
    maidListContainer:SetWidth(280)
    maidListContainer:SetHeight(24)

    local maidRows = {}
    local maidInstructionUpdating = false

    local maidInstructionHeader = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    maidInstructionHeader:SetPoint("TOPLEFT", maidListContainer, "BOTTOMLEFT", 0, -12)
    maidInstructionHeader:SetText("Maid Instructions")

    local maidInstructionBox = CreateFrame("EditBox", nil, settingsContent, "InputBoxTemplate")
    maidInstructionBox:SetSize(200, 20)
    maidInstructionBox:SetPoint("TOPLEFT", maidInstructionHeader, "BOTTOMLEFT", 0, -6)
    maidInstructionBox:SetAutoFocus(false)
    maidInstructionBox:SetText("")

    local maidSetInstructionBtn = CreateFrame("Button", nil, settingsContent, "UIPanelButtonTemplate")
    maidSetInstructionBtn:SetSize(60, 20)
    maidSetInstructionBtn:SetPoint("LEFT", maidInstructionBox, "RIGHT", 6, 0)
    maidSetInstructionBtn:SetText("Set")

    local maidClearInstructionBtn = CreateFrame("Button", nil, settingsContent, "UIPanelButtonTemplate")
    maidClearInstructionBtn:SetSize(60, 20)
    maidClearInstructionBtn:SetPoint("TOPLEFT", maidInstructionBox, "BOTTOMLEFT", 0, -6)
    maidClearInstructionBtn:SetText("Clear")

    local maidModuleMissingText = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    maidModuleMissingText:SetPoint("TOPLEFT", maidListContainer, "TOPLEFT", 0, 0)
    maidModuleMissingText:SetWidth(280)
    maidModuleMissingText:SetJustifyH("LEFT")
    maidModuleMissingText:SetText("|cffff5555Maid Tasks module not loaded.|r")
    maidModuleMissingText:Hide()

    local function ClearMaidRows()
        for _, row in ipairs(maidRows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(maidRows)
    end

    local maidSectionTopDepth = -maidListTopY
    local maidInstructionBlockHeight = 120

    local function UpdateSettingsHeight(tasksHeight)
        local newHeight = maidSectionTopDepth + (tasksHeight or 24) + maidInstructionBlockHeight + 80
        settingsContent:SetHeight(math.max(320, newHeight))
    end

    local function MaidModuleAvailable()
        return CCT_MaidTasks_GetOwnerItems and CCT_MaidTasks_AddItem and CCT_MaidTasks_RemoveItemByIndex
    end

    local function GetMaidItems()
        if not CCT_MaidTasks_GetOwnerItems then
            return {}
        end
        local items = CCT_MaidTasks_GetOwnerItems()
        if type(items) ~= "table" then
            return {}
        end
        return items
    end

    local function GetMaidItemCount(item)
        if CCT_MaidTasks_GetOwnerItemCount then
            return CCT_MaidTasks_GetOwnerItemCount(item)
        end
        return 0
    end

    local function RefreshMaidInstructionUI()
        if maidInstructionUpdating then return end
        maidInstructionUpdating = true
        local text = ""
        if CCT_MaidTasks_GetInstructionText then
            text = CCT_MaidTasks_GetInstructionText() or ""
        end
        maidInstructionBox:SetText(text)
        maidInstructionUpdating = false
    end

    local function RefreshMaidTasksUI()
        ClearMaidRows()

        if not MaidModuleAvailable() then
            maidModuleMissingText:Show()
            maidListContainer:SetHeight(24)
            UpdateSettingsHeight(24)
            return
        end

        maidModuleMissingText:Hide()

        local items = GetMaidItems()
        local rowHeight = 22
        local offset = 0

        if #items == 0 then
            local row = CreateFrame("Frame", nil, maidListContainer)
            row:SetSize(280, rowHeight)
            row:SetPoint("TOPLEFT", 0, 0)

            local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("LEFT", 0, 0)
            label:SetWidth(260)
            label:SetJustifyH("LEFT")
            label:SetText("No maid tasks yet. Paste an item and click Add Task.")

            table.insert(maidRows, row)
            offset = rowHeight
        else
            for index, item in ipairs(items) do
                local row = CreateFrame("Frame", nil, maidListContainer)
                row:SetSize(280, rowHeight)
                row:SetPoint("TOPLEFT", 0, -offset)

                local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                label:SetPoint("LEFT", 0, 0)
                label:SetWidth(230)
                label:SetJustifyH("LEFT")
                label:SetText(string.format("%s: %d (synced)", item.displayName or "Unknown", GetMaidItemCount(item)))

                local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                removeBtn:SetSize(22, 18)
                removeBtn:SetPoint("RIGHT", -2, 0)
                removeBtn:SetText("x")
                removeBtn:SetScript("OnClick", function()
                    if CCT_MaidTasks_RemoveItemByIndex then
                        CCT_MaidTasks_RemoveItemByIndex(index)
                    end
                    RefreshMaidTasksUI()
                end)

                table.insert(maidRows, row)
                offset = offset + rowHeight
            end
        end

        local tasksHeight = math.max(rowHeight, offset + 4)
        maidListContainer:SetHeight(tasksHeight)
        UpdateSettingsHeight(tasksHeight)
    end

    local function AddTaskFromInput()
        local text = maidInput:GetText()
        if not text or text == "" then return end
        if CCT_MaidTasks_AddItem then
            CCT_MaidTasks_AddItem(text)
        end
        maidInput:SetText("")
        RefreshMaidTasksUI()
    end

    maidAddBtn:SetScript("OnClick", AddTaskFromInput)
    maidInput:SetScript("OnEnterPressed", AddTaskFromInput)

    maidSetInstructionBtn:SetScript("OnClick", function()
        if CCT_MaidTasks_SetInstructionText then
            CCT_MaidTasks_SetInstructionText(maidInstructionBox:GetText() or "")
        end
        RefreshMaidInstructionUI()
    end)

    maidInstructionBox:SetScript("OnEnterPressed", function()
        if CCT_MaidTasks_SetInstructionText then
            CCT_MaidTasks_SetInstructionText(maidInstructionBox:GetText() or "")
        end
        RefreshMaidInstructionUI()
    end)

    maidClearInstructionBtn:SetScript("OnClick", function()
        maidInstructionBox:SetText("")
        if CCT_MaidTasks_SetInstructionText then
            CCT_MaidTasks_SetInstructionText("")
        end
        RefreshMaidInstructionUI()
    end)

    frame.UpdateMaidTasksUI = RefreshMaidTasksUI
    frame.UpdateMaidInstructionUI = RefreshMaidInstructionUI
    UpdateSettingsHeight(maidListContainer:GetHeight() or 24)
    tabFrames["Settings"] = settingsTab

    local function ShowTab(name)
        for _, tabFrame in pairs(tabFrames) do
            tabFrame:Hide()
        end
        local selected = tabFrames[name]
        if selected then
            selected:Show()
        end
        for tabName, button in pairs(tabButtons) do
            button:SetEnabled(tabName ~= name)
        end
        frame.selectedTab = name
        if name == "Stats" and frame.UpdateStats then
            frame:UpdateStats()
            return
        end
        if name == "Settings" then
            if frame.UpdateMaidInstructionUI then
                frame:UpdateMaidInstructionUI()
            end
            if frame.UpdateMaidTasksUI then
                frame:UpdateMaidTasksUI()
            end
        end
    end

    for name, button in pairs(tabButtons) do
        local tabName = name
        button:SetScript("OnClick", function()
            ShowTab(tabName)
        end)
    end

    ShowTab("Stats")
end

local function GetOpenButtonPosition()
    CatgirlSettingsDB = CatgirlSettingsDB or {}
    CatgirlSettingsDB.cgccOpenButton = CatgirlSettingsDB.cgccOpenButton or {}
    CatgirlSettingsDB.cgccOpenButton[kittyname] = CatgirlSettingsDB.cgccOpenButton[kittyname] or {}
    return CatgirlSettingsDB.cgccOpenButton[kittyname]
end

local function ApplySavedOpenButtonPosition(button)
    if not button then return end
    local db = GetOpenButtonPosition()
    if not db.point then
        button:SetPoint("TOP", 0, -210)
        return
    end
    button:ClearAllPoints()
    button:SetPoint(db.point, UIParent, db.relativePoint or db.point, db.x or 0, db.y or -210)
end

local function SaveOpenButtonPosition(button)
    if not button then return end
    local point, _, relativePoint, xOfs, yOfs = button:GetPoint(1)
    if not point then return end
    local db = GetOpenButtonPosition()
    db.point = point
    db.relativePoint = relativePoint
    db.x = xOfs
    db.y = yOfs
end

local function CreateOpenButton()
    if controlOpenButton then return end
    controlOpenButton = CreateFrame("Button", "CatGirlControlCenterOpenButton", UIParent, "UIPanelButtonTemplate")
    controlOpenButton:SetSize(80, 24)
    ApplySavedOpenButtonPosition(controlOpenButton)
    controlOpenButton:SetText("cgcc")
    controlOpenButton:RegisterForClicks("LeftButtonUp")
    controlOpenButton:SetMovable(true)
    controlOpenButton:EnableMouse(true)
    controlOpenButton:RegisterForDrag("LeftButton")
    controlOpenButton:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    controlOpenButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveOpenButtonPosition(self)
    end)
    controlOpenButton:SetScript("OnClick", function()
        SlashCmdList["CGCC"]()
    end)
end

f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        CreateOpenButton()
    end
end)

-- Slash command handler
SlashCmdList["CGCC"] = function()
    if not IsInGuild() then
        print("|cffff5555[CatGirlControlCenter]|r You are not in a guild.")
        return
    end

    RequestGuildRoster()
    C_Timer.After(1.0, function()
        local kitten = GetAssignedCatgirl()
        if kitten then
            ShowControlPanel(kitten)
        else
            print("|cffff5555[CatGirlControlCenter]|r You don't own a kitten yet!")
            ShowControlPanel(nil)
        end
    end)
end

CCT_AutoPrint("CatGirlControlCenter loaded.")
