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
local followMacroName = "FollowLeashMacro"
local pendingFollowUpdate = false

local function GetBehaviorLog()
    CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}
    return CatgirlBehaviorDB.BehaviorLog[kittyname]
end

GetBehaviorLog().LeashBindings = savedBindings
local pawIconFrame = nil
local fullScreenButton = nil

local function IsDebugEnabled()
    return CCT_IsDebugEnabled and CCT_IsDebugEnabled() or false
end

local function DebugPrint(...)
    if not IsDebugEnabled() then return end
    if CCT_AutoPrint then
        CCT_AutoPrint("|cffff88ff[CatgirlTracker]|r", ...)
    else
        print("|cffff88ff[CatgirlTracker]|r", ...)
    end
end

local function ToggleDebug()
    if CCT_ToggleDebug then
        CCT_ToggleDebug()
    end
end

SLASH_CGDEBUG1 = "/cgdebug"
SlashCmdList["CGDEBUG"] = ToggleDebug

SLASH_CGLEASHDEBUG1 = "/cgleashdebug"
SlashCmdList["CGLEASHDEBUG"] = ToggleDebug

local function DumpButtonAttributes(prefix)
    if not IsDebugEnabled() or not fullScreenButton then return end
    DebugPrint(prefix or "Button", "shown:", tostring(fullScreenButton:IsShown()),
        "enabled:", tostring(fullScreenButton:IsEnabled()),
        "size:", string.format("%dx%d", fullScreenButton:GetWidth(), fullScreenButton:GetHeight()),
        "strata:", tostring(fullScreenButton:GetFrameStrata()),
        "level:", tostring(fullScreenButton:GetFrameLevel()))
    DebugPrint("attrs",
        "type:", tostring(fullScreenButton:GetAttribute("type")),
        "type1:", tostring(fullScreenButton:GetAttribute("type1")),
        "macro:", tostring(fullScreenButton:GetAttribute("macro")),
        "macro1:", tostring(fullScreenButton:GetAttribute("macro1")),
        "macroname:", tostring(fullScreenButton:GetAttribute("macroname")),
        "macroname1:", tostring(fullScreenButton:GetAttribute("macroname1")),
        "macrotext:", tostring(fullScreenButton:GetAttribute("macrotext")),
        "macrotext1:", tostring(fullScreenButton:GetAttribute("macrotext1")),
        "clickbutton:", tostring(fullScreenButton:GetAttribute("clickbutton")),
        "clickbutton1:", tostring(fullScreenButton:GetAttribute("clickbutton1")),
        "action:", tostring(fullScreenButton:GetAttribute("action")),
        "action1:", tostring(fullScreenButton:GetAttribute("action1")))
end

local function GetActionButton1Slot()
    if not ActionButton1 then return nil end
    local slot = ActionButton1.action or ActionButton1:GetAttribute("action")
    if not slot and ActionButton_GetPagedID then
        slot = ActionButton_GetPagedID(ActionButton1)
    end
    return slot
end

local function RequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

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
    table.insert(GetBehaviorLog(), {
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
    GetBehaviorLog().LeashBindings = savedBindings
end

-- Replace bar with leash macro
local function replaceWithLeashMacro(targetName)
    local macroId = GetMacroIndexByName(followMacroName)
    local macroText = "/target " .. targetName .. "\n/follow"

    if macroId == 0 then
        macroId = CreateMacro(followMacroName, "INV_MISC_QUESTIONMARK", macroText, true)
    else
        EditMacro(macroId, followMacroName, "INV_MISC_QUESTIONMARK", macroText, true)
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
    fullScreenButton:SetAttribute("type1", "macro")
    fullScreenButton:EnableMouse(true)
    fullScreenButton:RegisterForClicks("AnyUp")
    fullScreenButton:SetScript("PreClick", function(_, button)
        DebugPrint("PreClick", "button:", tostring(button))
        DumpButtonAttributes("PreClick")
    end)
    fullScreenButton:SetScript("PostClick", function(_, button)
        DebugPrint("PostClick", "button:", tostring(button))
        DumpButtonAttributes("PostClick")
    end)
    fullScreenButton:Hide()

    fullScreenButton.texture = fullScreenButton:CreateTexture(nil, "BACKGROUND")
    fullScreenButton.texture:SetAllPoints()
    fullScreenButton.texture:SetColorTexture(0, 0, 0, 0.3)

    fullScreenButton.text = fullScreenButton:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    fullScreenButton.text:SetPoint("CENTER")
    fullScreenButton.text:SetText("Press 1 follow your Master nya~")
end

local function updateButtonForFollow()
    if not leasher then return end
    if InCombatLockdown() then
        pendingFollowUpdate = true
        leashFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        if ActionButton1 then
            fullScreenButton:SetAttribute("type", "click")
            fullScreenButton:SetAttribute("type1", "click")
            fullScreenButton:SetAttribute("clickbutton", "ActionButton1")
            fullScreenButton:SetAttribute("clickbutton1", "ActionButton1")
            fullScreenButton:SetAttribute("macro", nil)
            fullScreenButton:SetAttribute("macro1", nil)
            fullScreenButton:SetAttribute("macroname", nil)
            fullScreenButton:SetAttribute("macroname1", nil)
            fullScreenButton:SetAttribute("macrotext", nil)
            fullScreenButton:SetAttribute("macrotext1", nil)
            if IsDebugEnabled() then
                local slot = GetActionButton1Slot()
                if slot then
                    local actionType, id = GetActionInfo(slot)
                    DebugPrint("ActionButton1 slot:", tostring(slot), "type:", tostring(actionType), "id:", tostring(id))
                else
                    DebugPrint("ActionButton1 slot: nil")
                end
            end
        else
            local macroId = GetMacroIndexByName(followMacroName)
            fullScreenButton:SetAttribute("type", "macro")
            fullScreenButton:SetAttribute("type1", "macro")
            if macroId and macroId > 0 then
                fullScreenButton:SetAttribute("macro", macroId)
                fullScreenButton:SetAttribute("macro1", macroId)
                fullScreenButton:SetAttribute("macroname", followMacroName)
                fullScreenButton:SetAttribute("macroname1", followMacroName)
                fullScreenButton:SetAttribute("macrotext", nil)
                fullScreenButton:SetAttribute("macrotext1", nil)
            else
                local macroText = "/target " .. leasher .. "\n/follow"
                fullScreenButton:SetAttribute("macro", nil)
                fullScreenButton:SetAttribute("macro1", nil)
                fullScreenButton:SetAttribute("macroname", nil)
                fullScreenButton:SetAttribute("macroname1", nil)
                fullScreenButton:SetAttribute("macrotext", macroText)
                fullScreenButton:SetAttribute("macrotext1", macroText)
            end
        end
    end
    fullScreenButton.text:SetText("Press 1 follow your Master nya~")
    fullScreenButton:Show()
    DebugPrint("Update follow", "leasher:", tostring(leasher), "macroId:", tostring(GetMacroIndexByName(followMacroName)))
    DumpButtonAttributes("After follow update")
end

local function updateButtonForUnfollow()
    fullScreenButton:SetAttribute("type", "macro")
    fullScreenButton:SetAttribute("type1", "macro")
    fullScreenButton:SetAttribute("macro", nil)
    fullScreenButton:SetAttribute("macro1", nil)
    fullScreenButton:SetAttribute("macrotext", "/stopfollow")
    fullScreenButton:SetAttribute("macrotext1", "/stopfollow")
    fullScreenButton.text:SetText("Click to stop following nya~")
    fullScreenButton:Show()
    DumpButtonAttributes("After unfollow update")
    fullScreenButton:SetScript("PostClick", function()
        fullScreenButton:Hide()
        fullScreenButton:SetScript("PostClick", nil)
    end)
end

-- Get owner from guild note
local function getOwnerFromNote()
    if not IsInGuild() then
        DebugPrint("Not in a guild; cannot resolve owner.")
        return nil
    end
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note, officerNote = GetGuildRosterInfo(i)
        if name and name:match("^[^%-]+") == kittyname then
            DebugPrint("Notes for", name, "note:", note or "nil", "officer:", officerNote or "nil")
            if note then
                return note:match("owner=([^,]+)")
            end
            return nil
        end
    end
    return nil
end

-- Check last leash state from BehaviorLog
local function checkLeashStateFromLog()
    local log = GetBehaviorLog()
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
    if event == "CHAT_MSG_WHISPER" then
        DebugPrint("Whisper received", "msg:", tostring(arg1), "sender:", tostring(arg2))
    end
    if event == "PLAYER_LOGIN" then
        local restored, storedLeasher = checkLeashStateFromLog()
        if restored and storedLeasher then
            CCT_AutoPrint("|cffffff00CatgirlTracker:|r Restoring leash state.")
            isLeashed = true
            leasher = storedLeasher
            savedBindings = GetBehaviorLog().LeashBindings or {}
            replaceWithLeashMacro(leasher)
            createLeashButton()
            updateButtonForFollow()
            showPawIcon()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingFollowUpdate then
            pendingFollowUpdate = false
            leashFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
            updateButtonForFollow()
        end
    elseif event == "CHAT_MSG_WHISPER" then
        local msgLower = arg1:lower()
        local sender = arg2
        local shortName = sender:match("^[^%-]+")

        if msgLower == "leash" and not isLeashed then
            local owner = getOwnerFromNote()
            DebugPrint("Owner from note:", tostring(owner), "sender:", shortName, "isLeashed:", tostring(isLeashed))
            if not owner or owner:lower() ~= shortName:lower() then
                CCT_AutoPrint("|cffff0000CatgirlTracker:|r Leash rejected: " .. shortName .. " is not your registered owner.")
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

            SendChatMessage(CCT_Msg("LEASH_APPLY", kittyname), "WHISPER", nil, sender)
            print("|cffffff00CatgirlTracker:|r Leashed by " .. leasher .. " nya~")
            CCT_RaidNotice("Leash applied.")

        elseif msgLower == "unleash" and isLeashed and shortName == leasher then
            restoreActionBar()
            updateButtonForUnfollow()
            hidePawIcon()
            isLeashed = false
            logLeashEvent("KittenUnleash", leasher)

            SendChatMessage(CCT_Msg("LEASH_REMOVE", kittyname), "WHISPER", nil, sender)
            print("|cffffff00CatgirlTracker:|r Unleashed nya~")
            CCT_RaidNotice("Leash removed.")
            leasher = nil
        end
    end
end)

-- Register events
leashFrame:RegisterEvent("CHAT_MSG_WHISPER")
leashFrame:RegisterEvent("PLAYER_LOGIN")

CCT_AutoPrint("LeashTracker loaded with full persistence and empty slot fix.")
