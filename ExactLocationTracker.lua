local kittyname = UnitName("player")

CatgirlLocationDB = CatgirlLocationDB or {}
CatgirlLocationDB.LocationLog = CatgirlLocationDB.LocationLog or {}
CatgirlLocationDB.LocationLog[kittyname] = CatgirlLocationDB.LocationLog[kittyname] or {}

CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

local TRACK_INTERVAL = 10
local MAX_AGE_SECONDS = 7 * 24 * 60 * 60
local trackingActive = false
local locationTicker = nil
local lastNoPositionLog = 0

local function DebugPrint(...)
    if CCT_AutoPrint then
        CCT_AutoPrint("|cff88ff88[ExactLocation]|r", ...)
    end
end

local function GetLocationLog()
    CatgirlLocationDB.LocationLog[kittyname] = CatgirlLocationDB.LocationLog[kittyname] or {}
    return CatgirlLocationDB.LocationLog[kittyname]
end

local function GetBehaviorLog()
    CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}
    return CatgirlBehaviorDB.BehaviorLog[kittyname]
end

local function Round(value, places)
    if not value then return nil end
    local pow = 10 ^ (places or 4)
    return math.floor(value * pow + 0.5) / pow
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

local function LogTrackingState(state)
    table.insert(GetBehaviorLog(), {
        timestamp = date("%Y-%m-%d %H:%M:%S"),
        unixtime = time(),
        event = "TrackingJewel",
        state = state and true or false,
        synced = 0
    })
end

local function SetTrackingActive(state, silent)
    local newState = state and true or false
    if trackingActive == newState then
        return
    end
    trackingActive = newState
    if not silent then
        LogTrackingState(trackingActive)
    end
    DebugPrint("Tracking active:", tostring(trackingActive))
    if trackingActive then
        print("|cffffff00CatgirlTracker:|r Your tracking jewel glows. Location tracking enabled.")
        if CCT_RaidNotice then
            CCT_RaidNotice("Tracking jewel attached.")
        end
    else
        print("|cffffff00CatgirlTracker:|r The tracking jewel has been removed. Location tracking disabled.")
        if CCT_RaidNotice then
            CCT_RaidNotice("Tracking jewel removed.")
        end
    end
end

local function RestoreTrackingState()
    local log = GetBehaviorLog()
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "TrackingJewel" then
            SetTrackingActive(entry.state == true, true)
            return
        end
    end
    SetTrackingActive(false, true)
end

local function GetMapPosition()
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

local function PurgeOldEntries(log)
    local cutoff = time() - MAX_AGE_SECONDS
    while log[1] and log[1].unixtime and log[1].unixtime < cutoff do
        table.remove(log, 1)
    end
end

local function LogLocation()
    if not trackingActive then return end
    local mapID, x, y = GetMapPosition()
    if not x or not y then
        local now = time()
        if now - lastNoPositionLog > 60 then
            DebugPrint("No position available for logging.")
            lastNoPositionLog = now
        end
        return
    end
    local entry = {
        timestamp = date("%Y-%m-%d %H:%M:%S"),
        unixtime = time(),
        mapID = mapID,
        x = Round(x, 4),
        y = Round(y, 4),
        synced = 0
    }
    local log = GetLocationLog()
    table.insert(log, entry)
    PurgeOldEntries(log)
    DebugPrint("Logged location:", "mapID=" .. tostring(mapID), "x=" .. tostring(entry.x), "y=" .. tostring(entry.y))
end

local function EnsureTicker()
    if locationTicker then return end
    locationTicker = C_Timer.NewTicker(TRACK_INTERVAL, LogLocation)
    DebugPrint("Location ticker started.")
end

local function IsTrackingAttachMessage(lower)
    if not lower then return false end
    local hasJewel = lower:find("jewel") or lower:find("jewl")
    local hasAttach = lower:find("attach") or lower:find("attached")
    return lower:find("glowing") and hasJewel and hasAttach
end

local function IsTrackingRemoveMessage(lower)
    if not lower then return false end
    local hasJewel = lower:find("jewel") or lower:find("jewl")
    return hasJewel and (lower:find("removed") or lower:find("remove"))
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_WHISPER")

f:SetScript("OnEvent", function(_, event, msg, sender)
    if event == "PLAYER_LOGIN" then
        RestoreTrackingState()
        EnsureTicker()
        DebugPrint("Login:", "trackingActive=" .. tostring(trackingActive))
        return
    end

    if event == "CHAT_MSG_WHISPER" and msg and sender then
        local shortSender = sender:match("^[^%-]+")
        local owner = GetOwnerFromNote()
        if not owner or not shortSender or owner:lower() ~= shortSender:lower() then
            DebugPrint("Tracking whisper ignored from:", tostring(shortSender))
            return
        end

        local lower = msg:lower()
        if IsTrackingAttachMessage(lower) then
            SetTrackingActive(true)
        elseif IsTrackingRemoveMessage(lower) then
            SetTrackingActive(false)
        end
    end
end)

CCT_AutoPrint("ExactLocationTracker loaded.")
