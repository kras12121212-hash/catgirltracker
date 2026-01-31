local kittyname = UnitName("player")
local shortName = kittyname and kittyname:match("^[^%-]+") or kittyname

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
    if not IsInGuild or not IsInGuild() then
        return nil
    end
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note, officerNote = GetGuildRosterInfo(i)
        if name and name:match("^[^%-]+") == shortName then
            local source = nil
            if type(officerNote) == "string" and officerNote ~= "" then
                source = officerNote
            elseif type(note) == "string" and note ~= "" then
                source = note
            end
            local ownerName = source and source:match("owner=([^,]+)")
            if ownerName and ownerName ~= "" then
                return ownerName
            end
        end
    end
end

local function IsKitten()
    local owner = GetOwnerFromNote()
    return owner and owner ~= ""
end

local function FindLastEvent(log, eventName)
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == eventName then
            return entry
        end
    end
end

local function GetStartOfDay(now)
    local t = date("*t", now)
    t.hour = 0
    t.min = 0
    t.sec = 0
    return time(t)
end

local function GetHeelsSkillLevels(log)
    local levels = { maid = 1, high = 1, ballet = 1 }
    local gotMaid = false
    local gotHigh = false
    local gotBallet = false
    if log and type(log.HeelsSkillLevels) == "table" then
        local maid = tonumber(log.HeelsSkillLevels.maid)
        local high = tonumber(log.HeelsSkillLevels.high)
        local ballet = tonumber(log.HeelsSkillLevels.ballet)
        if maid and maid > 0 then
            levels.maid = maid
            gotMaid = true
        end
        if high and high > 0 then
            levels.high = high
            gotHigh = true
        end
        if ballet and ballet > 0 then
            levels.ballet = ballet
            gotBallet = true
        end
    end
    if log and type(log) == "table" and not (gotMaid and gotHigh and gotBallet) then
        for i = #log, 1, -1 do
            local entry = log[i]
            if entry and entry.event == "HeelsSkill" and type(entry.state) == "string" then
                local kind, lvl = entry.state:match("^(%a+):(%d+)$")
                if kind and lvl and levels[kind] == 1 then
                    levels[kind] = tonumber(lvl) or levels[kind]
                    if kind == "maid" then gotMaid = true end
                    if kind == "high" then gotHigh = true end
                    if kind == "ballet" then gotBallet = true end
                    if gotMaid and gotHigh and gotBallet then
                        break
                    end
                end
            end
        end
    end
    return levels
end

local TOY_DEFS = {
    { id = "dildo" },
    { id = "inflatable_butplug" },
    { id = "inflatable_dildo" },
    { id = "small_butplug" },
    { id = "large_butplug" },
    { id = "taill_butplug" },
    { id = "vibes_pussy" },
    { id = "vibes_nipples" },
    { id = "vibes_ears" },
    { id = "nipple_piercings" },
    { id = "ear_piercings" },
    { id = "pussy_lipps_piercings" },
}

local function ToyEventName(id)
    return "Toy_" .. id
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

local function GetAppliedBindCount(log)
    if not log or type(log) ~= "table" then
        return 0
    end

    local count = 0

    local gagEntry = FindLastEvent(log, "KittenGag")
    local gagState = gagEntry and gagEntry.Gagstate
    if gagState == "Gag"
        or gagState == "LightGag"
        or gagState == "FullBlock"
        or gagState == "NyaMask"
        or (type(gagState) == "string" and gagState:match("^Inflatable")) then
        count = count + 1
    end

    local blindEntry = FindLastEvent(log, "KittenBlindfold")
    local blindState = blindEntry and blindEntry.BlindfoldState
    if blindState == "light" or blindState == "mask" or blindState == "full" then
        count = count + 1
    end

    local earEntry = FindLastEvent(log, "KittenEarmuffs")
    local earState = earEntry and earEntry.state
    if earState == "KittenEarmuffs" or earState == "HeavyEarmuffs" then
        count = count + 1
    end

    local mittensEntry = FindLastEvent(log, "PawMittens")
    local mittenState = mittensEntry and mittensEntry.state
    if mittenState == "locked"
        or mittenState == "heavy"
        or mittenState == "squeaking"
        or mittenState == "squeking" then
        count = count + 1
    end

    local heelsEntry = FindLastEvent(log, "KittenHeels")
    local heelsState = heelsEntry and heelsEntry.state
    if heelsState == "maid" or heelsState == "high" or heelsState == "ballet" then
        count = count + 1
    end

    local bellEntry = FindLastEvent(log, "BellState")
    if bellEntry and bellEntry.state then
        count = count + 1
    end

    local tailEntry = FindLastEvent(log, "TailBellState")
    if tailEntry and tailEntry.state then
        count = count + 1
    end

    local trackingEntry = FindLastEvent(log, "TrackingJewel")
    if trackingEntry and trackingEntry.state then
        count = count + 1
    end

    local beltEntry = FindLastEvent(log, "ChastityBelt")
    if beltEntry and beltEntry.state == true then
        count = count + 1
    end

    local braEntry = FindLastEvent(log, "ChastityBra")
    if braEntry and braEntry.state == true then
        count = count + 1
    end

    for _, toy in ipairs(TOY_DEFS) do
        local toyEntry = FindLastEvent(log, ToyEventName(toy.id))
        if toyEntry and toyEntry.state == true then
            count = count + 1
        end
    end

    if GetLeashState(log) == "Leashed" then
        count = count + 1
    end

    return count
end

local function GetOrgasmTodayCount(log)
    if not log or type(log) ~= "table" then
        return 0
    end
    local now = time()
    local dayStart = GetStartOfDay(now)
    local today = 0
    for i = 1, #log do
        local entry = log[i]
        if entry and entry.event == "KittenOrgasm" and entry.unixtime and entry.unixtime >= dayStart then
            today = today + 1
        end
    end
    return today
end

local function GetDeniedOrgasmTotal(log)
    if not log or type(log) ~= "table" then
        return 0
    end
    local total = 0
    for i = 1, #log do
        local entry = log[i]
        if entry and entry.event == "ChastityDenyOrgasm" then
            total = total + 1
        end
    end
    return total
end

local function ClampNumber(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function CalculateSubmissiveness(log)
    local levels = GetHeelsSkillLevels(log)
    local levelSum = (tonumber(levels.maid) or 1)
        + (tonumber(levels.high) or 1)
        + (tonumber(levels.ballet) or 1)
    local deniedTotal = GetDeniedOrgasmTotal(log)
    local orgasmsToday = GetOrgasmTodayCount(log)
    local diff = deniedTotal - orgasmsToday
    if diff <= 0 then
        diff = 1
    end
    local bindCount = GetAppliedBindCount(log)
    if bindCount < 1 then
        bindCount = 1
    end
    local value = levelSum * diff * bindCount
    value = ClampNumber(value, 0, 100)
    return math.floor(value + 0.5)
end

local function LogBehaviorEvent(value)
    table.insert(GetBehaviorLog(), {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = "KittenSubmissiveness",
        state = value,
        synced = 0,
    })
end

local bar = nil
local lastLoggedValue = nil
local updateTicker = nil

local function GetSubmissivenessBarPosition()
    CatgirlSettingsDB = CatgirlSettingsDB or {}
    CatgirlSettingsDB.kittenSubmissivenessBar = CatgirlSettingsDB.kittenSubmissivenessBar or {}
    CatgirlSettingsDB.kittenSubmissivenessBar[shortName] = CatgirlSettingsDB.kittenSubmissivenessBar[shortName] or {}
    return CatgirlSettingsDB.kittenSubmissivenessBar[shortName]
end

local function SaveSubmissivenessBarPosition()
    if not bar then
        return
    end
    local point, _, relativePoint, x, y = bar:GetPoint(1)
    if not point then
        return
    end
    local db = GetSubmissivenessBarPosition()
    db.point = point
    db.relativePoint = relativePoint
    db.x = x
    db.y = y
end

local function RestoreSubmissivenessBarPosition()
    if not bar then
        return
    end
    bar:ClearAllPoints()
    local db = GetSubmissivenessBarPosition()
    if db.point then
        bar:SetPoint(db.point, UIParent, db.relativePoint or db.point, db.x or 0, db.y or 0)
        return
    end
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, -230)
end

local function UpdateBar(value)
    if not bar then
        return
    end
    local displayValue = ClampNumber(value, 0, 100)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(displayValue)
    bar:SetStatusBarColor(0.35, 0.8, 0.6)
    if bar.text then
        bar.text:SetText(string.format("Kitten Submissiveness: %d / 100", displayValue))
    end
end

local function EnsureBar()
    if bar then
        return
    end
    bar = CreateFrame("StatusBar", "KittenSubmissivenessBar", UIParent, "BackdropTemplate")
    bar:SetSize(240, 18)
    bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)
    bar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    bar:SetBackdropColor(0, 0, 0, 0.6)

    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER")
    bar.text:SetText("Kitten Submissiveness: 0 / 100")

    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", bar.StartMoving)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveSubmissivenessBarPosition()
    end)

    RestoreSubmissivenessBarPosition()
end

local function UpdateSubmissiveness()
    local log = GetBehaviorLog()
    local value = CalculateSubmissiveness(log)
    UpdateBar(value)
    if lastLoggedValue ~= value then
        lastLoggedValue = value
        LogBehaviorEvent(value)
    end
end

local function StartTicker()
    if updateTicker then
        return
    end
    updateTicker = C_Timer.NewTicker(2.0, UpdateSubmissiveness)
end

local function StopTicker()
    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
    end
end

local function RefreshKittenState()
    if IsKitten() then
        EnsureBar()
        bar:Show()
        StartTicker()
        UpdateSubmissiveness()
    else
        StopTicker()
        if bar then
            bar:Hide()
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1.0, RefreshKittenState)
        return
    end
    if event == "GUILD_ROSTER_UPDATE" then
        RefreshKittenState()
    end
end)

AutoPrint("KittenSubmissiveness tracker loaded.")
