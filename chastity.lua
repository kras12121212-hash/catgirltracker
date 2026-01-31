local kittyname = UnitName("player")

local beltEquipped = false
local braEquipped = false
local beltMode = "allow"

CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

local function GetBehaviorLog()
    CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}
    return CatgirlBehaviorDB.BehaviorLog[kittyname]
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
    if not owner or not sender then
        return false
    end
    local shortSender = sender:match("^[^%-]+")
    return shortSender and shortSender:lower() == owner:lower()
end

local function LogEvent(eventName, state)
    table.insert(GetBehaviorLog(), {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = eventName,
        state = state,
        synced = 0,
    })
end

local function LogChastityBeltState(state)
    beltEquipped = state and true or false
    LogEvent("ChastityBelt", beltEquipped)
end

local function LogChastityBraState(state)
    braEquipped = state and true or false
    LogEvent("ChastityBra", braEquipped)
end

local function LogChastityBeltMode(mode)
    if mode ~= "deny" and mode ~= "allow" then
        return
    end
    beltMode = mode
    LogEvent("ChastityBeltMode", mode)
end

local function LogDeniedOrgasm()
    LogEvent("ChastityDenyOrgasm", "deny")
end

local function LogSessionStart()
    LogEvent("ChastitySessionStart", "start")
end

local function FindLastEvent(log, eventName)
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == eventName then
            return entry
        end
    end
end

local function RestoreChastityState()
    local log = GetBehaviorLog()
    local beltEntry = FindLastEvent(log, "ChastityBelt")
    if beltEntry and type(beltEntry.state) == "boolean" then
        beltEquipped = beltEntry.state
    else
        beltEquipped = false
    end

    local braEntry = FindLastEvent(log, "ChastityBra")
    if braEntry and type(braEntry.state) == "boolean" then
        braEquipped = braEntry.state
    else
        braEquipped = false
    end

    local modeEntry = FindLastEvent(log, "ChastityBeltMode")
    if modeEntry and (modeEntry.state == "deny" or modeEntry.state == "allow") then
        beltMode = modeEntry.state
    else
        beltMode = "allow"
    end

    if not beltEquipped then
        beltMode = "allow"
    end
end

local shockFrame = nil
local shockToken = 0

local function ShowBeltShock()
    if not shockFrame then
        shockFrame = CreateFrame("Frame", "CatgirlChastityShockFrame", UIParent)
        shockFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        shockFrame:SetAllPoints(UIParent)
        shockFrame.texture = shockFrame:CreateTexture(nil, "OVERLAY")
        shockFrame.texture:SetAllPoints()
        shockFrame.texture:SetTexture("Interface\\AddOns\\CatgirlTracker\\Textures\\BeltShockDeny.tga")
        shockFrame:Hide()
    end

    shockFrame:Show()
    shockToken = shockToken + 1
    local token = shockToken
    C_Timer.After(5, function()
        if shockFrame and shockToken == token then
            shockFrame:Hide()
        end
    end)
end

local function SetBeltEquipped(state, sender, isAuto)
    LogChastityBeltState(state)
    if not state then
        if beltMode ~= "allow" then
            LogChastityBeltMode("allow")
        else
            beltMode = "allow"
        end
    end
    if sender then
        local key = state and "CHASTITY_BELT_APPLY" or "CHASTITY_BELT_REMOVE"
        SendChatMessage(CCT_Msg(key), "WHISPER", nil, sender)
    end
    if CCT_RaidNotice then
        if state then
            CCT_RaidNotice("Chastity belt locked.")
        else
            local note = isAuto and "Chastity belt removed (timer expired)." or "Chastity belt removed."
            CCT_RaidNotice(note)
        end
    end
end

local function SetBraEquipped(state, sender, isAuto)
    LogChastityBraState(state)
    if sender then
        local key = state and "CHASTITY_BRA_APPLY" or "CHASTITY_BRA_REMOVE"
        SendChatMessage(CCT_Msg(key), "WHISPER", nil, sender)
    end
    if CCT_RaidNotice then
        if state then
            CCT_RaidNotice("Chastity bra locked.")
        else
            local note = isAuto and "Chastity bra removed (timer expired)." or "Chastity bra removed."
            CCT_RaidNotice(note)
        end
    end
end

local function SetBeltMode(mode, sender)
    if mode ~= "deny" and mode ~= "allow" then
        return
    end
    if not beltEquipped then
        return
    end
    LogChastityBeltMode(mode)
    if sender then
        local key = mode == "deny" and "CHASTITY_BELT_DENY" or "CHASTITY_BELT_ALLOW"
        SendChatMessage(CCT_Msg(key), "WHISPER", nil, sender)
    end
    if CCT_RaidNotice then
        local note = mode == "deny" and "Chastity belt set to Deny Orgasm." or "Chastity belt set to Allow Orgasm."
        CCT_RaidNotice(note)
    end
end

function CCT_HandleOrgasmAttempt()
    if beltEquipped and beltMode == "deny" then
        ShowBeltShock()
        LogDeniedOrgasm()
        local owner = GetOwnerFromNote()
        if owner then
            SendChatMessage(CCT_Msg("CHASTITY_DENY_SHOCK"), "WHISPER", nil, owner)
        end
        if CCT_RaidNotice then
            CCT_RaidNotice("Chastity belt denied an orgasm.")
        end
        return false, 70
    end
    return true
end

function RemoveChastityBeltBySystem()
    SetBeltEquipped(false, nil, true)
    if CCT_AutoPrint then
        CCT_AutoPrint("|cffffff00[System]:|r Your chastity belt has been automatically removed nya~")
    end
end
_G.RemoveChastityBeltBySystem = RemoveChastityBeltBySystem

function RemoveChastityBraBySystem()
    SetBraEquipped(false, nil, true)
    if CCT_AutoPrint then
        CCT_AutoPrint("|cffffff00[System]:|r Your chastity bra has been automatically removed nya~")
    end
end
_G.RemoveChastityBraBySystem = RemoveChastityBraBySystem

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_WHISPER")

f:SetScript("OnEvent", function(_, event, msg, sender)
    if event == "PLAYER_LOGIN" then
        RestoreChastityState()
        LogSessionStart()
        return
    end

    if event ~= "CHAT_MSG_WHISPER" then
        return
    end
    if not IsOwnerSender(sender) then
        return
    end

    local text = msg and msg:lower() or ""
    if text == "" then
        return
    end

    if text:find("deny orgasm") then
        SetBeltMode("deny", sender)
        return
    end

    if text:find("allow orgasm") then
        SetBeltMode("allow", sender)
        return
    end

    if text:find("locked a chastity belt") then
        SetBeltEquipped(true, sender, false)
        return
    end

    if text:find("locked a chastity bra") then
        SetBraEquipped(true, sender, false)
        return
    end

    if text:find("removed your chastity belt") or text:find("remove chastity belt") then
        SetBeltEquipped(false, sender, false)
        return
    end

    if text:find("removed your chastity bra") or text:find("remove chastity bra") then
        SetBraEquipped(false, sender, false)
        return
    end
end)

CCT_AutoPrint("Chastity module loaded.")
