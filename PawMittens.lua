local kittyname = UnitName("player")

local addonPrefix = "CatgirlTracker"

-- Module state
local pawMittensLocked = false
local activeMittensType = nil
local sabotageTicker = nil
local squeakCycleTicker = nil
local squeakWindowTimer = nil
local squeakWindowActive = false
local currentSabotageSlot = nil
local pendingSabotage = false
local pendingSqueakWindow = false
local pendingRestoreSlot = nil

-- Action bar sabotage configuration
local ACTION_SLOTS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
local MITTENS_MACRO_NAME = "PawMittensOops"
local MITTENS_MACRO_ICON = "INV_Misc_QuestionMark"

-- Cursor overlay configuration
local MITTENS_TEXTURE_PATH = "Interface\\AddOns\\CatgirlTracker\\Textures\\pawmittens.tga"
local HEAVY_MITTENS_TEXTURE_PATH = "Interface\\AddOns\\CatgirlTracker\\Textures\\heavypawmittens.tga"
local MITTENS_TEXTURE_SIZE = 72
local MITTENS_TYPE_NORMAL = "normal"
local MITTENS_TYPE_SQUEAKING = "squeaking"
local SQUEAK_WINDOW_SECONDS = 5
local SQUEAK_CYCLE_SECONDS = 30
local PAW_SQUEAK_SOUNDS = {
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\pawsqueak1.wav",
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\pawsqueak2.wav",
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\pawsqueak3.wav",
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\pawsqueak4.wav",
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\pawsqueak5.wav",
}
local PAW_SQUEAK_COOLDOWN = 2
local PAW_CREAK_SOUNDS = {
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\creak-1.wav",
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\creak-2.wav",
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\creak-3.wav",
}
local PAW_CREAK_COOLDOWN = 2

-- Behavior DB setup
CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

local function GetBehaviorLog()
    CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}
    return CatgirlBehaviorDB.BehaviorLog[kittyname]
end

local function AutoPrint(...)
    if CCT_AutoPrint then
        CCT_AutoPrint(...)
    else
        print(...)
    end
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
        if name and name:match("^[^%-]+") == kittyname then
            local source = nil
            if type(officerNote) == "string" and officerNote ~= "" then
                source = officerNote
            elseif type(note) == "string" and note ~= "" then
                source = note
            end
            return source and source:match("owner=([^,]+)") or nil
        end
    end
end

local function IsOwnerSender(sender)
    local owner = GetOwnerFromNote()
    if not owner then
        return false
    end
    local shortSender = sender and sender:match("^[^%-]+")
    return shortSender and shortSender:lower() == owner:lower()
end

local function Round(value, places)
    if not value then
        return nil
    end
    local pow = 10 ^ (places or 4)
    return math.floor(value * pow + 0.5) / pow
end

local function GetInstanceID()
    if not GetInstanceInfo then
        return nil
    end
    local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceID and instanceID > 0 then
        return instanceID
    end
end

local function GetMapPosition()
    local instanceID = GetInstanceID()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then
            return nil, nil, nil, instanceID
        end
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if not pos then
            return nil, nil, nil, instanceID
        end
        local x, y = pos.x, pos.y
        if pos.GetXY then
            x, y = pos:GetXY()
        end
        if x and y then
            return mapID, Round(x, 4), Round(y, 4), instanceID
        end
    end
    if GetPlayerMapPosition then
        local x, y = GetPlayerMapPosition("player")
        if x and y then
            return nil, Round(x, 4), Round(y, 4), instanceID
        end
    end
    return nil, nil, nil, instanceID
end

local lastSqueakAt = 0
local lastCreakAt = 0

local function GetNow()
    if GetTime then
        return GetTime()
    end
    return time()
end

local function CanPlayPawSqueak()
    local now = GetNow()
    if now - lastSqueakAt < PAW_SQUEAK_COOLDOWN then
        return false
    end
    lastSqueakAt = now
    return true
end

local function CanPlayPawCreak()
    local now = GetNow()
    if now - lastCreakAt < PAW_CREAK_COOLDOWN then
        return false
    end
    lastCreakAt = now
    return true
end

local function GetRandomPawSqueakSound()
    return PAW_SQUEAK_SOUNDS[math.random(#PAW_SQUEAK_SOUNDS)]
end

local function GetRandomPawCreakSound()
    return PAW_CREAK_SOUNDS[math.random(#PAW_CREAK_SOUNDS)]
end

local function SendPawSound(prefix)
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end
    local owner = GetOwnerFromNote()
    if owner then
        owner = owner:match("^[^%-]+")
    end
    if not owner or owner == "" then
        return
    end
    if C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)
    end

    local mapID, x, y, instanceID = GetMapPosition()
    local msg = string.format(
        "%s, owner:%s, mapID:%s, x:%s, y:%s, instanceID:%s",
        prefix,
        owner,
        tostring(mapID or "nil"),
        tostring(x or "nil"),
        tostring(y or "nil"),
        tostring(instanceID or "nil")
    )
    C_ChatInfo.SendAddonMessage(addonPrefix, msg, "GUILD")
end

local function SendPawSqueak()
    SendPawSound("PawSqueak")
end

local function SendPawCreak()
    SendPawSound("PawCreak")
end

local function TriggerPawSqueak()
    if not CanPlayPawSqueak() then
        return
    end
    PlaySoundFile(GetRandomPawSqueakSound(), "Master")
    SendPawSqueak()
end

local function TriggerPawCreak()
    if not CanPlayPawCreak() then
        return
    end
    PlaySoundFile(GetRandomPawCreakSound(), "Master")
    SendPawCreak()
end

local function LogMittensState(state)
    table.insert(GetBehaviorLog(), {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = "PawMittens",
        state = state,
        synced = 0,
    })
end

-- Cursor overlay that follows the mouse
local pawCursorFrame = CreateFrame("Frame", "CatgirlPawMittensCursor", UIParent)
pawCursorFrame:SetFrameStrata("FULLSCREEN_DIALOG")
pawCursorFrame:SetSize(MITTENS_TEXTURE_SIZE, MITTENS_TEXTURE_SIZE)
pawCursorFrame:EnableMouse(false)
pawCursorFrame:Hide()

pawCursorFrame.texture = pawCursorFrame:CreateTexture(nil, "OVERLAY")
pawCursorFrame.texture:SetAllPoints()
pawCursorFrame.texture:SetTexture(MITTENS_TEXTURE_PATH)
pawCursorFrame.texture:SetAlpha(0.95)

local function UpdateCursorOverlayPosition()
    local x, y = GetCursorPosition()
    if not x or not y then
        return
    end
    local scale = UIParent:GetEffectiveScale()
    x = x / scale
    y = y / scale

    pawCursorFrame:ClearAllPoints()
    pawCursorFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

local function GetMittensTexturePath()
    if activeMittensType == MITTENS_TYPE_SQUEAKING then
        return HEAVY_MITTENS_TEXTURE_PATH
    end
    return MITTENS_TEXTURE_PATH
end

pawCursorFrame:SetScript("OnUpdate", function()
    if not pawMittensLocked then
        return
    end
    UpdateCursorOverlayPosition()
end)

local function ShowCursorOverlay()
    pawCursorFrame.texture:SetTexture(GetMittensTexturePath())
    pawCursorFrame:Show()
    UpdateCursorOverlayPosition()
end

local function HideCursorOverlay()
    pawCursorFrame:Hide()
end

-- Action bar sabotage helpers
local originalActions = {}

local function CaptureAction(slot)
    local actionType, id, subType = GetActionInfo(slot)
    if actionType then
        originalActions[slot] = {
            actionType = actionType,
            id = id,
            subType = subType,
            hadAction = true,
        }
    else
        originalActions[slot] = {
            hadAction = false,
        }
    end
end

local function PerformRestoreAction(slot)
    if not slot then
        return
    end

    local data = originalActions[slot]
    if not data then
        return
    end

    if data.hadAction then
        if data.actionType == "spell" and data.id then
            PickupSpell(data.id)
        elseif data.actionType == "macro" and data.id then
            PickupMacro(data.id)
        elseif data.actionType == "item" and data.id then
            PickupItem(data.id)
        else
            -- Unknown action type; best effort is to leave the slot alone.
            originalActions[slot] = nil
            ClearCursor()
            return
        end
        PlaceAction(slot)
        ClearCursor()
    else
        -- Slot was originally empty; clear what we placed there.
        PickupAction(slot)
        ClearCursor()
    end

    originalActions[slot] = nil
end

local function RestoreAction(slot)
    if not slot then
        return false
    end
    if InCombatLockdown() then
        pendingRestoreSlot = slot
        return false
    end

    pendingRestoreSlot = nil
    PerformRestoreAction(slot)
    return true
end

local function EnsureMittensMacro()
    if InCombatLockdown() then
        pendingSabotage = true
        return nil
    end

    local body = "/say " .. CCT_Msg("PAW_MITTENS_SAY")
    local index = GetMacroIndexByName(MITTENS_MACRO_NAME)

    local ok, result = pcall(function()
        if index and index > 0 then
            EditMacro(index, MITTENS_MACRO_NAME, MITTENS_MACRO_ICON, body, false)
            return index
        end
        local created = CreateMacro(MITTENS_MACRO_NAME, MITTENS_MACRO_ICON, body, false)
        if created and created > 0 then
            return created
        end
        -- Fallback to a character macro if general macros are full.
        return CreateMacro(MITTENS_MACRO_NAME, MITTENS_MACRO_ICON, body, true)
    end)

    if not ok then
        AutoPrint("|cffff5555[PawMittens]|r Macro creation failed:", tostring(result))
        return nil
    end

    local finalIndex = GetMacroIndexByName(MITTENS_MACRO_NAME)
    if not finalIndex or finalIndex == 0 then
        AutoPrint("|cffff5555[PawMittens]|r Could not create mittens macro (slots may be full).")
        return nil
    end

    return finalIndex
end

local function PlaceMacroInSlot(slot, macroIndex)
    if not slot or not macroIndex then
        return
    end
    if InCombatLockdown() then
        pendingSabotage = true
        return
    end

    CaptureAction(slot)
    PickupMacro(macroIndex)
    PlaceAction(slot)
    ClearCursor()
end

local function GetCandidateSlots()
    local candidates = {}
    for _, slot in ipairs(ACTION_SLOTS) do
        local actionType = GetActionInfo(slot)
        if actionType then
            table.insert(candidates, slot)
        end
    end
    if #candidates == 0 then
        return ACTION_SLOTS
    end
    return candidates
end

local function ChooseNextSlot(previousSlot)
    local candidates = GetCandidateSlots()
    if #candidates == 1 then
        return candidates[1]
    end

    local slot = previousSlot
    local attempts = 0
    while slot == previousSlot and attempts < 20 do
        slot = candidates[math.random(#candidates)]
        attempts = attempts + 1
    end
    return slot or candidates[1]
end

local function SabotageTick()
    if not pawMittensLocked then
        return
    end
    if InCombatLockdown() then
        pendingSabotage = true
        return
    end

    local macroIndex = EnsureMittensMacro()
    if not macroIndex then
        return
    end

    if currentSabotageSlot then
        RestoreAction(currentSabotageSlot)
    end

    local nextSlot = ChooseNextSlot(currentSabotageSlot)
    currentSabotageSlot = nextSlot
    PlaceMacroInSlot(nextSlot, macroIndex)
end

local function ClearSabotageTimers()
    if sabotageTicker then
        sabotageTicker:Cancel()
        sabotageTicker = nil
    end
    if squeakCycleTicker then
        squeakCycleTicker:Cancel()
        squeakCycleTicker = nil
    end
    if squeakWindowTimer then
        squeakWindowTimer:Cancel()
        squeakWindowTimer = nil
    end
end

local function IsTimedMittens()
    return activeMittensType == MITTENS_TYPE_SQUEAKING
end

local function EndSqueakWindow()
    squeakWindowActive = false
    if currentSabotageSlot and RestoreAction(currentSabotageSlot) then
        currentSabotageSlot = nil
    end
end

local function StartSqueakWindow()
    if not pawMittensLocked or not IsTimedMittens() then
        return
    end
    if pendingRestoreSlot then
        pendingSqueakWindow = true
        return
    end
    if InCombatLockdown() then
        pendingSqueakWindow = true
        return
    end

    pendingSqueakWindow = false
    squeakWindowActive = true
    SabotageTick()
    if not currentSabotageSlot then
        squeakWindowActive = false
        return
    end

    if squeakWindowTimer then
        squeakWindowTimer:Cancel()
        squeakWindowTimer = nil
    end
    squeakWindowTimer = C_Timer.NewTimer(SQUEAK_WINDOW_SECONDS, EndSqueakWindow)
end

local function StartSqueakCycle()
    if squeakCycleTicker then
        squeakCycleTicker:Cancel()
        squeakCycleTicker = nil
    end

    StartSqueakWindow()
    squeakCycleTicker = C_Timer.NewTicker(SQUEAK_CYCLE_SECONDS, StartSqueakWindow)
end

local function StartSabotage()
    ClearSabotageTimers()
    SabotageTick()
    sabotageTicker = C_Timer.NewTicker(5, SabotageTick)
end

local function StopSabotage()
    ClearSabotageTimers()
    squeakWindowActive = false
    pendingSqueakWindow = false
    pendingSabotage = false

    if currentSabotageSlot and RestoreAction(currentSabotageSlot) then
        currentSabotageSlot = nil
    end
end

local function GetMittensResponse(mittensType)
    if mittensType == MITTENS_TYPE_SQUEAKING then
        return CCT_Msg("PAW_MITTENS_RESPONSE_SQUEAKING")
    end
    return CCT_Msg("PAW_MITTENS_RESPONSE_LOCKED")
end

local function ApplyPawMittens(sender, mittensType)
    StopSabotage()
    pawMittensLocked = true
    activeMittensType = mittensType or MITTENS_TYPE_NORMAL
    ShowCursorOverlay()

    if activeMittensType == MITTENS_TYPE_SQUEAKING then
        StartSqueakCycle()
        LogMittensState("squeaking")
    else
        StartSabotage()
        LogMittensState("locked")
    end

    if CCT_RaidNotice then
        if activeMittensType == MITTENS_TYPE_SQUEAKING then
            CCT_RaidNotice("Squeaking paw mittens locked.")
        else
            CCT_RaidNotice("Paw mittens locked: paws restricted.")
        end
    end

    local response = GetMittensResponse(activeMittensType)
    if sender then
        SendChatMessage(response, "WHISPER", nil, sender)
    end
end

local function RemovePawMittens(sender, isAuto)
    pawMittensLocked = false
    activeMittensType = nil
    HideCursorOverlay()
    StopSabotage()
    LogMittensState("removed")

    if CCT_RaidNotice then
        if isAuto then
            CCT_RaidNotice("Paw mittens removed (timer expired).")
        else
            CCT_RaidNotice("Paw mittens removed.")
        end
    end

    if sender then
        SendChatMessage(CCT_Msg("PAW_MITTENS_REMOVE"), "WHISPER", nil, sender)
    end
end

function RemovePawMittensBySystem()
    RemovePawMittens(nil, true)
    AutoPrint("|cffffff00[System]:|r Your paw mittens lock has expired!")
end
_G.RemovePawMittensBySystem = RemovePawMittensBySystem

local function RestoreMittensState()
    local log = GetBehaviorLog()
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "PawMittens" then
            if entry.state == "locked" or entry.state == "heavy" then
                pawMittensLocked = true
                activeMittensType = MITTENS_TYPE_NORMAL
                ShowCursorOverlay()
                StartSabotage()
            elseif entry.state == "squeaking" then
                pawMittensLocked = true
                activeMittensType = MITTENS_TYPE_SQUEAKING
                ShowCursorOverlay()
                StartSqueakCycle()
            else
                pawMittensLocked = false
                activeMittensType = nil
                HideCursorOverlay()
                StopSabotage()
            end
            return
        end
    end

    pawMittensLocked = false
    activeMittensType = nil
    HideCursorOverlay()
    StopSabotage()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        RestoreMittensState()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if pendingRestoreSlot then
            local slot = pendingRestoreSlot
            pendingRestoreSlot = nil
            PerformRestoreAction(slot)
            if slot == currentSabotageSlot then
                currentSabotageSlot = nil
            end
        end

        if pendingSqueakWindow and pawMittensLocked and IsTimedMittens() then
            pendingSqueakWindow = false
            StartSqueakWindow()
        end

        if pawMittensLocked and pendingSabotage then
            pendingSabotage = false
            if activeMittensType == MITTENS_TYPE_NORMAL or squeakWindowActive then
                SabotageTick()
            end
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = ...
        if unit == "player" and pawMittensLocked then
            if activeMittensType == MITTENS_TYPE_SQUEAKING then
                TriggerPawSqueak()
            elseif activeMittensType == MITTENS_TYPE_NORMAL then
                TriggerPawCreak()
            end
        end
        return
    end

    if event ~= "CHAT_MSG_WHISPER" then
        return
    end

    local msg, sender = ...
    if not IsOwnerSender(sender) then
        return
    end

    local text = msg and msg:lower() or ""

    if text:find("heavy paw mittens") then
        ApplyPawMittens(sender, MITTENS_TYPE_NORMAL)
    elseif text:find("squeking paw mittens")
        or text:find("squeaking paw mittens") then
        ApplyPawMittens(sender, MITTENS_TYPE_SQUEAKING)
    elseif text:find("locked tight paw mittens")
        or text:find("locked onto your paws")
        or text:find("lockable paw mittens") then
        ApplyPawMittens(sender, MITTENS_TYPE_NORMAL)
    elseif text:find("removed your paw mittens")
        or text:find("remove paw mittens") then
        RemovePawMittens(sender, false)
    end
end)

AutoPrint("PawMittens loaded.")
