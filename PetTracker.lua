local kittyname = UnitName("player")

CatgirlPetDB = CatgirlPetDB or {}
CatgirlPetDB.PetLog = CatgirlPetDB.PetLog or {}
CatgirlPetDB.PetLog[kittyname] = CatgirlPetDB.PetLog[kittyname] or {}

local function IsModuleEnabled()
    return not CCT_IsModuleEnabled or CCT_IsModuleEnabled("PetTracker")
end

local macroName = "CatNya"
local catSummoned = false
local macroReady = false
local pendingMacroUpdate = false
local checkDone = false
local checkPending = false
local catButton = nil

local function IsDebugEnabled()
    return CCT_IsDebugEnabled and CCT_IsDebugEnabled() or false
end

local function DebugPrint(...)
    if not IsDebugEnabled() then return end
    if CCT_AutoPrint then
        CCT_AutoPrint("|cffffcc00[CatgirlTracker Debug]:|r", ...)
    else
        print("|cffffcc00[CatgirlTracker Debug]:|r", ...)
    end
end

SLASH_CGCATBTNDEBUG1 = "/cgcatbtndebug"
SlashCmdList["CGCATBTNDEBUG"] = function()
    if CCT_ToggleDebug then
        CCT_ToggleDebug()
    end
end

local function GetPetLog()
    CatgirlPetDB.PetLog[kittyname] = CatgirlPetDB.PetLog[kittyname] or {}
    return CatgirlPetDB.PetLog[kittyname]
end

local function LogPetEvent(eventName)
    table.insert(GetPetLog(), {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = eventName,
        pet = macroName,
        synced = 0
    })
end

local function UpdateButtonText()
    if not catButton then return end
    if catSummoned then
        catButton:SetText("Good Kitten!, You Cat is Summoned")
    else
        catButton:SetText("Summon your cat Nya !")
    end
end

local function UpdateButtonMacro()
    if not catButton then return end
    if InCombatLockdown and InCombatLockdown() then
        pendingMacroUpdate = true
        DebugPrint("UpdateButtonMacro blocked in combat")
        return
    end

    pendingMacroUpdate = false
    local macroId = GetMacroIndexByName(macroName)
    macroReady = macroId and macroId > 0
    DebugPrint("UpdateButtonMacro macroId:", tostring(macroId), "ready:", tostring(macroReady))

    catButton:SetAttribute("type", "macro")
    catButton:SetAttribute("type1", "macro")
    if macroReady then
        local _, _, body = GetMacroInfo(macroId)
        if body and body ~= "" then
            catButton:SetAttribute("macrotext", nil)
            catButton:SetAttribute("macrotext1", body)
        else
            catButton:SetAttribute("macrotext", nil)
            catButton:SetAttribute("macrotext1", nil)
        end
        catButton:SetAttribute("macro", nil)
        catButton:SetAttribute("macro1", nil)
    else
        catButton:SetAttribute("macro", nil)
        catButton:SetAttribute("macro1", nil)
        catButton:SetAttribute("macrotext", nil)
        catButton:SetAttribute("macrotext1", nil)
    end
end

local function CreateCatButton()
    if catButton then return end
    catButton = CreateFrame("Button", "CatgirlSummonCatButton", UIParent, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    catButton:SetSize(260, 24)
    catButton:SetPoint("TOP", 0, -180)
    catButton:RegisterForClicks("LeftButtonDown")
    catButton:SetAlpha(1.0)
    catButton:SetMovable(true)
    catButton:EnableMouse(true)
    catButton:RegisterForDrag("LeftButton")
    catButton:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    catButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    catButton:SetScript("PostClick", function()
        if not macroReady then
            print("|cffffcc00[CatgirlTracker]:|r Macro 'CatNya' not found.")
            return
        end
        DebugPrint("PostClick", "macroId:", tostring(GetMacroIndexByName(macroName)),
            "type:", tostring(catButton:GetAttribute("type")))
        catSummoned = not catSummoned
        UpdateButtonText()
        LogPetEvent(catSummoned and "CatSummoned" or "CatDismissed")
    end)

    UpdateButtonText()
    UpdateButtonMacro()
end

local function ApplyPetTrackerEnabled(enabled)
    if enabled then
        if not catButton then
            CreateCatButton()
        end
        catButton:Show()
        UpdateButtonText()
        UpdateButtonMacro()
    else
        if catButton then
            catButton:Hide()
        end
    end
end

local function SendGuildMessage(msg)
    if IsInGuild() then
        SendChatMessage(msg, "GUILD")
    end
end

local function RunFiveMinuteCheck()
    if not IsModuleEnabled() then return end
    if checkDone then return end
    if UnitIsDeadOrGhost("player") then
        checkPending = true
        return
    end

    checkDone = true
    checkPending = false

    if catSummoned then
        SendGuildMessage("Was a good kitten and rembered to summon their Cat")
        LogPetEvent("CatReminderGood")
    else
        SendGuildMessage("Was a Bad Kitten and forgot to summon their cat")
        LogPetEvent("CatReminderBad")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("PLAYER_UNGHOST")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UPDATE_MACROS")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        catSummoned = false
        ApplyPetTrackerEnabled(IsModuleEnabled())
        if IsModuleEnabled() then
            UpdateButtonText()
            DebugPrint("PLAYER_LOGIN", "macroId:", tostring(GetMacroIndexByName(macroName)))
            C_Timer.After(300, RunFiveMinuteCheck)
        end
        return
    end

    if not IsModuleEnabled() then return end

    if event == "PLAYER_DEAD" then
        catSummoned = false
        UpdateButtonText()
        LogPetEvent("CatResetOnDeath")
        return
    end

    if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        if checkPending then
            RunFiveMinuteCheck()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and pendingMacroUpdate then
        UpdateButtonMacro()
        return
    end

    if event == "UPDATE_MACROS" then
        DebugPrint("UPDATE_MACROS")
        UpdateButtonMacro()
        return
    end
end)

if CCT_RegisterModuleWatcher then
    CCT_RegisterModuleWatcher("PetTracker", function(enabled)
        ApplyPetTrackerEnabled(enabled)
    end)
end

CCT_AutoPrint("CatgirlPetTracker loaded (CatNya button mode).")
