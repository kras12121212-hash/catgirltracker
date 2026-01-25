local kittyname = UnitName("player")

-- Module state
local pawMittensLocked = false
local sabotageTicker = nil
local currentSabotageSlot = nil
local pendingSabotage = false

-- Action bar sabotage configuration
local ACTION_SLOTS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
local MITTENS_MACRO_NAME = "PawMittensOops"
local MITTENS_MACRO_ICON = "INV_Misc_QuestionMark"
local MITTENS_SAY_TEXT = "Looks like kitten has trouble using her spells with her locked on Paw mittens nya!"

-- Cursor overlay configuration
local MITTENS_TEXTURE_PATH = "Interface\\AddOns\\CatgirlTracker\\Textures\\pawmittens.tga"
local MITTENS_TEXTURE_SIZE = 72

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

pawCursorFrame:SetScript("OnUpdate", function()
    if not pawMittensLocked then
        return
    end
    UpdateCursorOverlayPosition()
end)

local function ShowCursorOverlay()
    pawCursorFrame.texture:SetTexture(MITTENS_TEXTURE_PATH)
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

local function RestoreAction(slot)
    if not slot then
        return
    end
    if InCombatLockdown() then
        pendingSabotage = true
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

local function EnsureMittensMacro()
    if InCombatLockdown() then
        pendingSabotage = true
        return nil
    end

    local body = "/say " .. MITTENS_SAY_TEXT
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

local function StartSabotage()
    if sabotageTicker then
        sabotageTicker:Cancel()
        sabotageTicker = nil
    end

    SabotageTick()
    sabotageTicker = C_Timer.NewTicker(5, SabotageTick)
end

local function StopSabotage()
    if sabotageTicker then
        sabotageTicker:Cancel()
        sabotageTicker = nil
    end

    if currentSabotageSlot then
        RestoreAction(currentSabotageSlot)
        currentSabotageSlot = nil
    end
end

local function ApplyPawMittens(sender)
    pawMittensLocked = true
    ShowCursorOverlay()
    StartSabotage()
    LogMittensState("locked")

    if CCT_RaidNotice then
        CCT_RaidNotice("Paw mittens locked: paws restricted.")
    end

    local response = "Tight paw mittens have been locked onto your kitten's paws. They are reinforced, so she cannot use her paws properly or extend her claws at all."
    if sender then
        SendChatMessage(response, "WHISPER", nil, sender)
    end
end

local function RemovePawMittens(sender, isAuto)
    pawMittensLocked = false
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
        SendChatMessage("Your paw mittens have been removed. Your paws and claws are free again nya~", "WHISPER", nil, sender)
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
            if entry.state == "locked" then
                pawMittensLocked = true
                ShowCursorOverlay()
                StartSabotage()
            else
                pawMittensLocked = false
                HideCursorOverlay()
                StopSabotage()
            end
            return
        end
    end

    pawMittensLocked = false
    HideCursorOverlay()
    StopSabotage()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

f:SetScript("OnEvent", function(_, event, msg, sender)
    if event == "PLAYER_LOGIN" then
        RestoreMittensState()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if pawMittensLocked and pendingSabotage then
            pendingSabotage = false
            SabotageTick()
        end
        return
    end

    if event ~= "CHAT_MSG_WHISPER" then
        return
    end

    if not IsOwnerSender(sender) then
        return
    end

    local text = msg and msg:lower() or ""

    if text:find("locked tight paw mittens")
        or text:find("locked onto your paws")
        or text:find("lockable paw mittens") then
        ApplyPawMittens(sender)
    elseif text:find("removed your paw mittens")
        or text:find("remove paw mittens") then
        RemovePawMittens(sender, false)
    end
end)

AutoPrint("PawMittens loaded.")
