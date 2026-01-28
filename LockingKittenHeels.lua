-- test git
local kittyname = UnitName("player")
local addonPrefix = "CatgirlTracker"

local HEELS_TYPE_MAID = "maid"
local HEELS_TYPE_HIGH = "high"
local HEELS_TYPE_BALLET = "ballet"

local HEELS_SOUND_FILES = {
    [HEELS_TYPE_MAID] = "Interface\\AddOns\\CatgirlTracker\\Sounds\\HighHeels3.wav",
    [HEELS_TYPE_HIGH] = "Interface\\AddOns\\CatgirlTracker\\Sounds\\HighHeels8.wav",
    [HEELS_TYPE_BALLET] = "Interface\\AddOns\\CatgirlTracker\\Sounds\\HighHeels12.wav",
}

local HEELS_SOUND_PREFIX = {
    [HEELS_TYPE_MAID] = "HeelsStep3",
    [HEELS_TYPE_HIGH] = "HeelsStep8",
    [HEELS_TYPE_BALLET] = "HeelsStep12",
}

local HEEL_STEP_INTERVAL = 0.8
local HEELS_SOUND_INTERVALS = {
    [HEELS_TYPE_MAID] = 7.0,
    [HEELS_TYPE_HIGH] = 7.0,
    [HEELS_TYPE_BALLET] = 7.0,
}
local HEELS_WARNING_MESSAGE = "Kitten is Wearing High Heels you Cant Run or you will Fall !\n(Use Slow walk)"
local HEELS_WARNING_CHECK = 0.1
local HEELS_WARNING_COOLDOWN = 1.2
local HEELS_SAMPLE_COUNT = 12

local HEELS_BASE_SPEED = {
    [HEELS_TYPE_MAID] = 3.5,
    [HEELS_TYPE_HIGH] = 2.0,
    [HEELS_TYPE_BALLET] = 1.4,
}
local HEELS_FAILURE_TEXTURES = {
    [HEELS_TYPE_MAID] = "Interface\\AddOns\\CatgirlTracker\\Textures\\heels\\maid-heels.tga",
    [HEELS_TYPE_HIGH] = "Interface\\AddOns\\CatgirlTracker\\Textures\\heels\\high-heels.tga",
    [HEELS_TYPE_BALLET] = "Interface\\AddOns\\CatgirlTracker\\Textures\\heels\\ballet-boots.tga",
}
local HEELS_SPEED_PER_LEVEL = 0.05
local HEELS_MAX_LEVEL = 20
local HEELS_LEVEL_BASE_DURATION = 180
local HEELS_LEVEL_STEP_SECONDS = 60
local HEELS_PROGRESS_CHUNK_SECONDS = 5
local HEELS_PROGRESS_WINDOW = 30
local HEELS_PROGRESS_MIN_RATIO = 0.45
local HEELS_PROGRESS_RESET_RATIO = 1.0
local HEELS_PING_INTERVAL = 1.0

local heelsLocked = false
local activeHeelsType = nil
local heelsSoundTicker = nil
local heelsLoopHandle = nil
local heelsLoopActive = false
local heelsMoving = false
local lastHeelsPingAt = 0
local heelsWarningTicker = nil
local lastWarningAt = 0
local heelsWarningActive = false
local speedSamples = {}
local speedSum = 0
local speedBar = nil
local progressBar = nil
local heelsSkillLevels = nil
local skillProgress = {}
local skillWindow = {}
local skillWindowTrue = {}
local skillWalkAccum = {}
local failureOverlay = nil
local heelsFailActive = false

local function GetHeelDisplayName(kind)
    if kind == HEELS_TYPE_MAID then
        return "Maid Heels"
    elseif kind == HEELS_TYPE_HIGH then
        return "High Heels"
    elseif kind == HEELS_TYPE_BALLET then
        return "Ballet Boots"
    end
    return "Heels"
end

local function SendGuildMessage(message)
    if SendChatMessage then
        SendChatMessage(message, "GUILD")
    end
end

local function SendGroupMessage(message)
    if not SendChatMessage then
        return
    end
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        SendChatMessage(message, "INSTANCE_CHAT")
    elseif IsInRaid and IsInRaid() then
        SendChatMessage(message, "RAID")
    elseif IsInGroup and IsInGroup() then
        SendChatMessage(message, "PARTY")
    end
end

-- Behavior DB setup
CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

local function GetBehaviorLog()
    CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}
    return CatgirlBehaviorDB.BehaviorLog[kittyname]
end

local function InitializeHeelsSkills()
    local log = GetBehaviorLog()
    if type(log.HeelsSkillLevels) ~= "table" then
        log.HeelsSkillLevels = {}
    end
    if type(log.HeelsSkillLevelsSent) ~= "table" then
        log.HeelsSkillLevelsSent = {}
    end
    heelsSkillLevels = log.HeelsSkillLevels

    local types = { HEELS_TYPE_MAID, HEELS_TYPE_HIGH, HEELS_TYPE_BALLET }
    for _, kind in ipairs(types) do
        local level = tonumber(heelsSkillLevels[kind]) or 1
        if level < 1 then level = 1 end
        if level > HEELS_MAX_LEVEL then level = HEELS_MAX_LEVEL end
        heelsSkillLevels[kind] = level
        skillProgress[kind] = 0
        skillWindow[kind] = {}
        skillWindowTrue[kind] = 0
        skillWalkAccum[kind] = 0
    end
end

local function QueueSkillLevelSyncIfNeeded()
    if not heelsSkillLevels then
        InitializeHeelsSkills()
    end
    local log = GetBehaviorLog()
    log.HeelsSkillLevelsSent = log.HeelsSkillLevelsSent or {}
    local sent = log.HeelsSkillLevelsSent
    local types = { HEELS_TYPE_MAID, HEELS_TYPE_HIGH, HEELS_TYPE_BALLET }
    for _, kind in ipairs(types) do
        local level = tonumber(heelsSkillLevels[kind]) or 1
        if sent[kind] ~= level then
            table.insert(log, {
                timestamp = date("%Y-%m-%d %H:%M"),
                unixtime = time(),
                event = "HeelsSkill",
                state = string.format("%s:%d", kind, level),
                synced = 0,
            })
            sent[kind] = level
        end
    end
end

local function GetSkillLevel(kind)
    if not heelsSkillLevels then
        InitializeHeelsSkills()
    end
    return tonumber(heelsSkillLevels[kind]) or 1
end

local function SetSkillLevel(kind, level)
    if not heelsSkillLevels then
        InitializeHeelsSkills()
    end
    local newLevel = tonumber(level) or 1
    if newLevel < 1 then newLevel = 1 end
    if newLevel > HEELS_MAX_LEVEL then newLevel = HEELS_MAX_LEVEL end
    if heelsSkillLevels[kind] ~= newLevel then
        heelsSkillLevels[kind] = newLevel
        QueueSkillLevelSyncIfNeeded()
    end
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

local ownerCache = nil
local ownerCacheAt = 0
local OWNER_CACHE_SECONDS = 60

local function GetCachedOwner()
    local now = time()
    if ownerCache and (now - ownerCacheAt) < OWNER_CACHE_SECONDS then
        return ownerCache
    end
    ownerCacheAt = now
    ownerCache = GetOwnerFromNote()
    if ownerCache then
        ownerCache = ownerCache:match("^[^%-]+")
    end
    return ownerCache
end

local function Round(value, places)
    if not value then return nil end
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

local function SendHeelSound(prefix)
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end
    local owner = GetCachedOwner()
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

local function SendHeelsLoopEvent(action, heelsType)
    if not action then return end
    local kind = heelsType or activeHeelsType
    if not kind then return end
    local prefix = action == "Start" and "HeelsLoopStart"
        or action == "Stop" and "HeelsLoopStop"
        or "HeelsLoopPing"
    local msgPrefix = string.format("%s, type:%s", prefix, kind)
    SendHeelSound(msgPrefix)
end

local function PlayHeelsLoopSound()
    if not heelsLocked or not activeHeelsType then
        return
    end
    local sound = HEELS_SOUND_FILES[activeHeelsType]
    if not sound then
        return
    end
    if type(heelsLoopHandle) == "number" and StopSound then
        StopSound(heelsLoopHandle)
    end
    local a, b = PlaySoundFile(sound, "Master")
    if type(a) == "number" then
        heelsLoopHandle = a
    elseif type(b) == "number" then
        heelsLoopHandle = b
    else
        heelsLoopHandle = nil
    end
end

local function StartHeelsSoundLoop()
    if heelsLoopActive then
        return
    end
    heelsLoopActive = true
    PlayHeelsLoopSound()
    local interval = HEELS_SOUND_INTERVALS[activeHeelsType] or HEEL_STEP_INTERVAL
    heelsSoundTicker = C_Timer.NewTicker(interval, function()
        if not heelsLoopActive or not heelsLocked or not activeHeelsType then
            return
        end
        PlayHeelsLoopSound()
    end)
end

local function StopHeelsSoundLoop()
    heelsLoopActive = false
    if heelsSoundTicker then
        heelsSoundTicker:Cancel()
        heelsSoundTicker = nil
    end
    if type(heelsLoopHandle) == "number" and StopSound then
        StopSound(heelsLoopHandle)
    end
    heelsLoopHandle = nil
end

local function GetNow()
    if GetTime then
        return GetTime()
    end
    return time()
end

local function ResetSpeedSamples()
    speedSamples = {}
    speedSum = 0
end

local function AddSpeedSample(value)
    local sample = value or 0
    table.insert(speedSamples, sample)
    speedSum = speedSum + sample
    if #speedSamples > HEELS_SAMPLE_COUNT then
        speedSum = speedSum - table.remove(speedSamples, 1)
    end
end

local function GetAverageSpeed()
    if #speedSamples == 0 then
        return 0
    end
    return speedSum / #speedSamples
end

local function GetAllowedSpeed(kind)
    local heelsType = kind or activeHeelsType
    if not heelsType then
        return nil
    end
    local base = HEELS_BASE_SPEED[heelsType]
    if not base then
        return nil
    end
    local level = GetSkillLevel(heelsType)
    return base + (level - 1) * HEELS_SPEED_PER_LEVEL
end

local function GetLevelRequirement(level)
    return HEELS_LEVEL_BASE_DURATION + (level * HEELS_LEVEL_STEP_SECONDS)
end

failureOverlay = CreateFrame("Frame", "CatgirlHeelsFailureOverlay", UIParent)
failureOverlay:SetAllPoints(UIParent)
failureOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
failureOverlay:EnableMouse(false)
failureOverlay:Hide()

failureOverlay.texture = failureOverlay:CreateTexture(nil, "OVERLAY")
failureOverlay.texture:SetAllPoints()
failureOverlay.texture:SetAlpha(1)
failureOverlay.expireAt = nil

local function ShowFailureOverlay(kind)
    if not failureOverlay then
        return
    end
    local path = kind and HEELS_FAILURE_TEXTURES[kind]
    if not path then
        return
    end
    failureOverlay.texture:SetTexture(path)
    failureOverlay:Show()
    failureOverlay.expireAt = GetNow() + 5
end

local function HideFailureOverlay()
    if failureOverlay then
        failureOverlay.expireAt = nil
        failureOverlay:Hide()
    end
end

speedBar = CreateFrame("StatusBar", "CatgirlHeelsSpeedBar", UIParent, "BackdropTemplate")
speedBar:SetSize(240, 16)
speedBar:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
speedBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
speedBar:SetMinMaxValues(0, 1)
speedBar:SetValue(0)
speedBar:SetStatusBarColor(0.2, 0.8, 0.2)
speedBar:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
speedBar:SetBackdropColor(0, 0, 0, 0.6)
speedBar:Hide()

speedBar.text = speedBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
speedBar.text:SetPoint("CENTER")
speedBar.text:SetText("Balance bar 0.00 / 0.00")

progressBar = CreateFrame("StatusBar", "CatgirlHeelsProgressBar", UIParent, "BackdropTemplate")
progressBar:SetSize(240, 14)
progressBar:SetPoint("TOP", speedBar, "BOTTOM", 0, -6)
progressBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
progressBar:SetMinMaxValues(0, 1)
progressBar:SetValue(0)
progressBar:SetStatusBarColor(0.4, 0.6, 1)
progressBar:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
progressBar:SetBackdropColor(0, 0, 0, 0.6)
progressBar:Hide()

progressBar.text = progressBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
progressBar.text:SetPoint("CENTER")
progressBar.text:SetText("Level 1: 0 / 0s")

local function UpdateSpeedBar(avgSpeed, allowedSpeed)
    if not speedBar then
        return
    end
    if not heelsLocked or not activeHeelsType or not allowedSpeed then
        speedBar:Hide()
        return
    end

    speedBar:Show()
    speedBar:SetMinMaxValues(0, allowedSpeed)
    local value = avgSpeed
    if value < 0 then value = 0 end
    if value > allowedSpeed then value = allowedSpeed end
    speedBar:SetValue(value)

    if avgSpeed >= allowedSpeed then
        speedBar:SetStatusBarColor(1, 0.2, 0.2)
    else
        local ratio = allowedSpeed > 0 and (avgSpeed / allowedSpeed) or 0
        local r = math.min(1, ratio * 1.2)
        local g = math.min(1, 1 - ratio * 0.5)
        speedBar:SetStatusBarColor(r, g, 0.2)
    end

    if speedBar.text then
        speedBar.text:SetText(string.format("Balance bar %.2f / %.2f", avgSpeed, allowedSpeed))
    end
end

local function UpdateProgressBar(progressSeconds, requiredSeconds, level)
    if not progressBar then
        return
    end
    if not heelsLocked or not activeHeelsType or not requiredSeconds then
        progressBar:Hide()
        return
    end

    progressBar:Show()
    progressBar:SetMinMaxValues(0, requiredSeconds)
    local value = progressSeconds or 0
    if value < 0 then value = 0 end
    if value > requiredSeconds then value = requiredSeconds end
    progressBar:SetValue(value)

    if progressBar.text then
        progressBar.text:SetText(string.format("Level %d: %.0f / %.0fs", level or 1, value, requiredSeconds))
    end
end

local function ResetSkillWindow(kind)
    skillWindow[kind] = {}
    skillWindowTrue[kind] = 0
    skillWalkAccum[kind] = 0
end

local function ResetSkillProgress(kind)
    skillProgress[kind] = 0
    ResetSkillWindow(kind)
end

local function UpdateSkillProgress(avgSpeed, allowedSpeed, currentSpeed)
    if not activeHeelsType or not allowedSpeed then
        return
    end
    local kind = activeHeelsType
    if skillProgress[kind] == nil then
        skillProgress[kind] = 0
    end
    if not skillWindow[kind] then
        ResetSkillWindow(kind)
    end

    local aboveRatio = avgSpeed >= (allowedSpeed * HEELS_PROGRESS_MIN_RATIO)
    table.insert(skillWindow[kind], aboveRatio)
    if aboveRatio then
        skillWindowTrue[kind] = (skillWindowTrue[kind] or 0) + 1
    end
    if #skillWindow[kind] > HEELS_PROGRESS_WINDOW then
        local removed = table.remove(skillWindow[kind], 1)
        if removed then
            skillWindowTrue[kind] = (skillWindowTrue[kind] or 0) - 1
        end
    end

    if avgSpeed > (allowedSpeed * HEELS_PROGRESS_RESET_RATIO) then
        ResetSkillProgress(kind)
        local level = GetSkillLevel(kind)
        UpdateProgressBar(0, GetLevelRequirement(level), level)
        return
    end

    local isMoving = (currentSpeed and currentSpeed > 0) or (IsPlayerMoving and IsPlayerMoving())
    if isMoving then
        skillWalkAccum[kind] = (skillWalkAccum[kind] or 0) + HEELS_WARNING_CHECK
        while skillWalkAccum[kind] >= HEELS_PROGRESS_CHUNK_SECONDS do
            if #skillWindow[kind] >= HEELS_PROGRESS_WINDOW and skillWindowTrue[kind] == HEELS_PROGRESS_WINDOW then
                skillProgress[kind] = (skillProgress[kind] or 0) + HEELS_PROGRESS_CHUNK_SECONDS
            end
            skillWalkAccum[kind] = skillWalkAccum[kind] - HEELS_PROGRESS_CHUNK_SECONDS
        end
    end

    local level = GetSkillLevel(kind)
    local required = GetLevelRequirement(level)
    if level < HEELS_MAX_LEVEL and (skillProgress[kind] or 0) >= required then
        ResetSkillProgress(kind)
        local newLevel = level + 1
        SetSkillLevel(kind, newLevel)
        SendGuildMessage(CCT_Msg(
            "HEELS_PROGRESS",
            kittyname or "Kitten",
            GetHeelDisplayName(kind),
            newLevel
        ))
        level = GetSkillLevel(kind)
        required = GetLevelRequirement(level)
    end

    UpdateProgressBar(skillProgress[kind] or 0, required, level)
end

local function ShowHeelsWarning()
    local now = GetNow()
    if now - lastWarningAt < HEELS_WARNING_COOLDOWN then
        return
    end
    lastWarningAt = now
    heelsWarningActive = true
    if CCT_RaidNotice then
        CCT_RaidNotice(HEELS_WARNING_MESSAGE)
    elseif RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] then
        RaidNotice_AddMessage(RaidWarningFrame, HEELS_WARNING_MESSAGE, ChatTypeInfo["RAID_WARNING"])
    end
end

local function ClearHeelsWarning()
    if not heelsWarningActive then
        return
    end
    if RaidNotice_Clear and RaidWarningFrame then
        RaidNotice_Clear(RaidWarningFrame)
    elseif RaidWarningFrame and RaidWarningFrame.Hide then
        RaidWarningFrame:Hide()
    end
    heelsWarningActive = false
end

local function HeelsWarningTick()
    if not heelsLocked or not activeHeelsType then
        ClearHeelsWarning()
        ResetSpeedSamples()
        UpdateSpeedBar(0, nil)
        UpdateProgressBar(0, nil)
        HideFailureOverlay()
        if heelsMoving then
            SendHeelsLoopEvent("Stop", activeHeelsType)
            heelsMoving = false
        end
        StopHeelsSoundLoop()
        return
    end

    if failureOverlay and failureOverlay.expireAt and GetNow() >= failureOverlay.expireAt then
        HideFailureOverlay()
    end

    local speed = 0
    if GetUnitSpeed then
        speed = GetUnitSpeed("player") or 0
    end
    AddSpeedSample(speed)
    local avgSpeed = GetAverageSpeed()
    local allowedSpeed = GetAllowedSpeed()
    UpdateSpeedBar(avgSpeed, allowedSpeed)
    UpdateSkillProgress(avgSpeed, allowedSpeed, speed)

    if allowedSpeed and avgSpeed > allowedSpeed then
        if not heelsFailActive then
            heelsFailActive = true
            local level = GetSkillLevel(activeHeelsType)
            local failMessage = CCT_Msg(
                "HEELS_FAIL",
                kittyname or "Kitten",
                GetHeelDisplayName(activeHeelsType),
                level
            )
            SendGuildMessage(failMessage)
            SendGroupMessage(failMessage)
        end
        ShowHeelsWarning()
        ShowFailureOverlay(activeHeelsType)
    else
        heelsFailActive = false
        ClearHeelsWarning()
    end

    local isMoving = speed > 0
    if isMoving and not heelsMoving then
        heelsMoving = true
        StartHeelsSoundLoop()
        SendHeelsLoopEvent("Start", activeHeelsType)
    elseif not isMoving and heelsMoving then
        heelsMoving = false
        StopHeelsSoundLoop()
        SendHeelsLoopEvent("Stop", activeHeelsType)
    end

    if heelsMoving then
        local now = GetNow()
        if now - lastHeelsPingAt >= HEELS_PING_INTERVAL then
            lastHeelsPingAt = now
            SendHeelsLoopEvent("Ping", activeHeelsType)
        end
    end
end

local function StartHeelsWarningLoop()
    if heelsWarningTicker then
        return
    end
    heelsWarningTicker = C_Timer.NewTicker(HEELS_WARNING_CHECK, HeelsWarningTick)
end

local function StopHeelsWarningLoop()
    if heelsWarningTicker then
        heelsWarningTicker:Cancel()
        heelsWarningTicker = nil
    end
    ClearHeelsWarning()
end

local function LogHeelsState(state)
    table.insert(GetBehaviorLog(), {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = "KittenHeels",
        state = state,
        synced = 0,
    })
end

local function GetHeelsResponse(heelsType)
    if heelsType == HEELS_TYPE_MAID then
        return CCT_Msg("HEELS_RESPONSE_MAID")
    elseif heelsType == HEELS_TYPE_HIGH then
        return CCT_Msg("HEELS_RESPONSE_HIGH")
    elseif heelsType == HEELS_TYPE_BALLET then
        return CCT_Msg("HEELS_RESPONSE_BALLET")
    end
    return CCT_Msg("HEELS_RESPONSE_GENERIC")
end

local function UpdateWalkModeForHeels()
    -- Warning-only behavior; no forced walk toggles.
end

local function ApplyHeels(sender, heelsType)
    heelsLocked = true
    activeHeelsType = heelsType
    StartHeelsWarningLoop()
    ResetSpeedSamples()
    heelsMoving = false
    lastHeelsPingAt = 0
    StopHeelsSoundLoop()
    ResetSkillWindow(heelsType)
    LogHeelsState(heelsType)
    UpdateWalkModeForHeels()

    if CCT_RaidNotice then
        if heelsType == HEELS_TYPE_MAID then
            CCT_RaidNotice("Maid heels locked (3 cm).")
        elseif heelsType == HEELS_TYPE_HIGH then
            CCT_RaidNotice("High heels locked (8 cm).")
        else
            CCT_RaidNotice("Ballet boots locked (12 cm).")
        end
    end

    if sender then
        SendChatMessage(GetHeelsResponse(heelsType), "WHISPER", nil, sender)
    end
end

local function RemoveHeels(sender, isAuto)
    local prevType = activeHeelsType
    heelsLocked = false
    activeHeelsType = nil
    StopHeelsSoundLoop()
    if heelsMoving then
        SendHeelsLoopEvent("Stop", prevType)
    end
    heelsMoving = false
    lastHeelsPingAt = 0
    StopHeelsWarningLoop()
    ResetSpeedSamples()
    UpdateSpeedBar(0, nil)
    UpdateProgressBar(0, nil)
    HideFailureOverlay()
    if prevType then
        ResetSkillWindow(prevType)
    end
    LogHeelsState("removed")
    UpdateWalkModeForHeels()

    if CCT_RaidNotice then
        if isAuto then
            CCT_RaidNotice("Heels removed (timer expired).")
        else
            CCT_RaidNotice("Heels removed.")
        end
    end

    if sender then
        SendChatMessage(CCT_Msg("HEELS_REMOVE"), "WHISPER", nil, sender)
    end
end

function RemoveHeelsBySystem()
    RemoveHeels(nil, true)
    AutoPrint("|cffffff00[System]:|r Your heel lock has expired!")
end
_G.RemoveHeelsBySystem = RemoveHeelsBySystem

local function RestoreHeelsState()
    local log = GetBehaviorLog()
    local prevType = activeHeelsType
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "KittenHeels" then
            if entry.state == HEELS_TYPE_MAID
                or entry.state == HEELS_TYPE_HIGH
                or entry.state == HEELS_TYPE_BALLET then
                heelsLocked = true
                activeHeelsType = entry.state
                StartHeelsWarningLoop()
                ResetSpeedSamples()
                heelsMoving = false
                lastHeelsPingAt = 0
                StopHeelsSoundLoop()
                ResetSkillWindow(entry.state)
                UpdateWalkModeForHeels()
            else
                heelsLocked = false
                activeHeelsType = nil
                StopHeelsSoundLoop()
                if heelsMoving then
                    SendHeelsLoopEvent("Stop", prevType)
                end
                heelsMoving = false
                lastHeelsPingAt = 0
                StopHeelsWarningLoop()
                ResetSpeedSamples()
                UpdateSpeedBar(0, nil)
                UpdateProgressBar(0, nil)
                HideFailureOverlay()
                UpdateWalkModeForHeels()
            end
            return
        end
    end
    heelsLocked = false
    activeHeelsType = nil
    StopHeelsSoundLoop()
    if heelsMoving then
        SendHeelsLoopEvent("Stop", prevType)
    end
    heelsMoving = false
    lastHeelsPingAt = 0
    StopHeelsWarningLoop()
    ResetSpeedSamples()
    UpdateSpeedBar(0, nil)
    UpdateProgressBar(0, nil)
    HideFailureOverlay()
    UpdateWalkModeForHeels()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_WHISPER")

f:SetScript("OnEvent", function(_, event, msg, sender)
    if event == "PLAYER_LOGIN" then
        InitializeHeelsSkills()
        QueueSkillLevelSyncIfNeeded()
        RestoreHeelsState()
        return
    end

    if event ~= "CHAT_MSG_WHISPER" then
        return
    end

    if not IsOwnerSender(sender) then
        return
    end

    local text = msg and msg:lower() or ""
    if text:find("maid heels") then
        ApplyHeels(sender, HEELS_TYPE_MAID)
    elseif text:find("high heels") then
        ApplyHeels(sender, HEELS_TYPE_HIGH)
    elseif text:find("ballet boot") or text:find("ballet boots") then
        ApplyHeels(sender, HEELS_TYPE_BALLET)
    elseif text:find("removed your heels") or text:find("remove heels") then
        RemoveHeels(sender, false)
    end
end)

AutoPrint("LockingKittenHeels loaded.")
