local leashFrame = CreateFrame("Frame")
local kittyname = UnitName("player"):match("^[^%-]+")

-- DB initialization
CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

-- Local state
local isLeashed = false
local leasher = nil
local savedBindings = {}
CatgirlBehaviorDB.BehaviorLog[kittyname].LeashBindings = savedBindings
local pawIconFrame = nil
local fullScreenButton = nil

-- Paw icon not OWrking at all shit
local function showPawIcon()
    if pawIconFrame then pawIconFrame:Show(); return end
    pawIconFrame = CreateFrame("Frame", nil, UIParent)
    pawIconFrame:SetSize(48, 48)
    pawIconFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -40)
    pawIconFrame.texture = pawIconFrame:CreateTexture(nil, "OVERLAY")
    pawIconFrame.texture:SetAllPoints()
    pawIconFrame.texture:SetTexture("Interface\\PetBattles\\PetBattle-StatIcons")
    pawIconFrame.texture:SetTexCoord(0.5, 0.625, 0, 0.125)
    pawIconFrame:Show()
end

local function hidePawIcon()
    if pawIconFrame then pawIconFrame:Hide() end
end

-- Utility: log to BehaviorLog
local function logLeashEvent(eventName, leasherName)
    local now = time()
    table.insert(CatgirlBehaviorDB.BehaviorLog[kittyname], {
        event = eventName,
        leasher = leasherName or "",
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = now,
        synced = 0
    })
end

-- Restore action bar
local function restoreActionBar()
    for slot = 1, 120 do
        local data = savedBindings[slot]
        if data then
            local actionType, id = unpack(data)
            if actionType == "spell" then PickupSpell(id)
            elseif actionType == "macro" then PickupMacro(id)
            elseif actionType == "item" then PickupItem(id) end
            PlaceAction(slot)
            ClearCursor()
        else
            PickupAction(slot)
            ClearCursor()
        end
    end
end

-- Save current bar state
local function saveActionBar()
    savedBindings = {}
    for slot = 1, 120 do
        local actionType, id, subType = GetActionInfo(slot)
        savedBindings[slot] = actionType and { actionType, id, subType } or nil
    end
    CatgirlBehaviorDB.BehaviorLog[kittyname].LeashBindings = savedBindings
end

-- Replace bar with leash macro
local function replaceWithLeashMacro(targetName)
    local macroName = "FollowLeashMacro"
    local macroId = GetMacroIndexByName(macroName)
    local macroText = "/target " .. targetName .. "\n/follow"

    if macroId == 0 then
        macroId = CreateMacro(macroName, "INV_MISC_QUESTIONMARK", macroText, true)
    else
        EditMacro(macroId, macroName, "INV_MISC_QUESTIONMARK", macroText, true)
    end

    for slot = 1, 120 do
        PickupMacro(macroId)
        PlaceAction(slot)
        ClearCursor()
    end
end

-- Fullscreen button
local function createLeashButton()
    if fullScreenButton then return end
    fullScreenButton = CreateFrame("Button", "CatgirlLeashButton", UIParent, "SecureActionButtonTemplate")
    fullScreenButton:SetPoint("CENTER")
    fullScreenButton:SetSize(UIParent:GetWidth(), UIParent:GetHeight())
    fullScreenButton:SetFrameStrata("FULLSCREEN_DIALOG")
    fullScreenButton:SetAttribute("type", "macro")
    fullScreenButton:Hide()

    fullScreenButton.texture = fullScreenButton:CreateTexture(nil, "BACKGROUND")
    fullScreenButton.texture:SetAllPoints()
    fullScreenButton.texture:SetColorTexture(0, 0, 0, 0.3)

    fullScreenButton.text = fullScreenButton:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    fullScreenButton.text:SetPoint("CENTER")
    fullScreenButton.text:SetText("Click to follow your Master nya~")
end

local function updateButtonForFollow()
    if not leasher then return end
    fullScreenButton:SetAttribute("macrotext", "/target " .. leasher .. "\n/follow")
    fullScreenButton.text:SetText("Click to follow your Master nya~")
    fullScreenButton:Show()
end

local function updateButtonForUnfollow()
    fullScreenButton:SetAttribute("macrotext", "/stopfollow")
    fullScreenButton.text:SetText("Click to stop following nya~")
    fullScreenButton:Show()
    fullScreenButton:SetScript("PostClick", function()
        fullScreenButton:Hide()
        fullScreenButton:SetScript("PostClick", nil)
    end)
end

-- Get owner from guild note
local function getOwnerFromNote()
    GuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note = GetGuildRosterInfo(i)
        if name and name:match("^[^%-]+") == kittyname and note then
            return note:match("owner=([^,]+)")
        end
    end
    return nil
end

-- Check last leash state from BehaviorLog
local function checkLeashStateFromLog()
    local log = CatgirlBehaviorDB.BehaviorLog[kittyname]
    local lastLeash, lastUnleash

    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "KittenLeash" and not lastLeash then
            lastLeash = entry
        elseif entry.event == "KittenUnleash" and not lastUnleash then
            lastUnleash = entry
        end
        if lastLeash and lastUnleash then break end
    end

    if lastLeash and (not lastUnleash or lastUnleash.unixtime < lastLeash.unixtime) then
        return true, lastLeash.leasher
    end

    return false
end

leashFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        local restored, storedLeasher = checkLeashStateFromLog()
        if restored and storedLeasher then
            print("|cffffff00CatgirlTracker:|r Restoring leash state.")
            isLeashed = true
            leasher = storedLeasher
            savedBindings = CatgirlBehaviorDB.BehaviorLog[kittyname].LeashBindings or {}
            replaceWithLeashMacro(leasher)
            createLeashButton()
            updateButtonForFollow()
            showPawIcon()
        end

    elseif event == "CHAT_MSG_WHISPER" then
        local msgLower = arg1:lower()
        local sender = arg2
        local shortName = sender:match("^[^%-]+")

        if msgLower == "leash" and not isLeashed then
            local owner = getOwnerFromNote()
            if not owner or owner:lower() ~= shortName:lower() then
                print("|cffff0000CatgirlTracker:|r Leash rejected: " .. shortName .. " is not your registered owner.")
                return
            end

            leasher = shortName
            isLeashed = true
            saveActionBar()
            replaceWithLeashMacro(leasher)
            createLeashButton()
            updateButtonForFollow()
            showPawIcon()
            logLeashEvent("KittenLeash", leasher)

            SendChatMessage("You have clipped the leash onto " .. kittyname .. "... There's no escape now, nya~", "WHISPER", nil, sender)
            print("|cffffff00CatgirlTracker:|r Leashed by " .. leasher .. " nya~")

        elseif msgLower == "unleash" and isLeashed and shortName == leasher then
            restoreActionBar()
            updateButtonForUnfollow()
            hidePawIcon()
            isLeashed = false
            logLeashEvent("KittenUnleash", leasher)

            SendChatMessage("The leash slips free from " .. kittyname .. ". She's free... for now nya~", "WHISPER", nil, sender)
            print("|cffffff00CatgirlTracker:|r Unleashed nya~")
            leasher = nil
        end
    end
end)

-- Register events
leashFrame:RegisterEvent("CHAT_MSG_WHISPER")
leashFrame:RegisterEvent("PLAYER_LOGIN")

print("LeashTracker loaded with full persistence and empty slot fix.")
