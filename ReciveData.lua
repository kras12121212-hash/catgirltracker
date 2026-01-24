local kittyname = UnitName("player")

-- Route module prints through the shared debug gate.
local function AutoPrint(...)
    if CCT_AutoPrint then
        CCT_AutoPrint(...)
    end
end

local print = AutoPrint
local addonPrefix = "CatgirlTracker"
local masterName = "Hollykitten" -- short name only (no realm)
local myName = UnitName("player")
local myShortName = myName:match("^[^%-]+")
local isMaster = (myShortName:lower() == masterName:lower()) -- ← controls master mode

local function RequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function IsOwnerOf(senderShort)
    if not IsInGuild() then
        return false
    end
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note, officerNote = GetGuildRosterInfo(i)
        if name and name:match("^[^%-]+") == senderShort then
            local source = nil
            if type(officerNote) == "string" and officerNote ~= "" then
                source = officerNote
            elseif type(note) == "string" and note ~= "" then
                source = note
            end
            local owner = source and source:match("owner=([^,]+)") or nil
            return owner and owner:match("^[^%-]+"):lower() == myShortName:lower()
        end
    end
    return false
end

-- Register prefix once
C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)

-- Broadcast master status every minute if isMaster is true
local function broadcastMasterStatus()
    if isMaster then
        C_ChatInfo.SendAddonMessage(addonPrefix, "master", "GUILD")
        print("|cffffcc00CatgirlTracker:|r Broadcasted master status to guild.")
    end
end

SlaveKittyname = sender




-- Broadcast every 60 seconds
C_Timer.NewTicker(60, broadcastMasterStatus)


local function ensureSlaveDatabases(slaveName)
    CatgirlGuildDB = CatgirlGuildDB or {}
    CatgirlGuildDB.GuildLog = CatgirlGuildDB.GuildLog or {}
    CatgirlGuildDB.GuildLog[slaveName] = CatgirlGuildDB.GuildLog[slaveName] or {}

    CatgirlZoneDB = CatgirlZoneDB or {}
    CatgirlZoneDB.ZoneLog = CatgirlZoneDB.ZoneLog or {}
    CatgirlZoneDB.ZoneLog[slaveName] = CatgirlZoneDB.ZoneLog[slaveName] or {}

    CatgirlPetDB = CatgirlPetDB or {}
    CatgirlPetDB.PetLog = CatgirlPetDB.PetLog or {}
    CatgirlPetDB.PetLog[slaveName] = CatgirlPetDB.PetLog[slaveName] or {}

    CatgirlLocationDB = CatgirlLocationDB or {}
    CatgirlLocationDB.LocationLog = CatgirlLocationDB.LocationLog or {}
    CatgirlLocationDB.LocationLog[slaveName] = CatgirlLocationDB.LocationLog[slaveName] or {}

    CatgirlBehaviorDB = CatgirlBehaviorDB or {}
    CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
    CatgirlBehaviorDB.BehaviorLog[slaveName] = CatgirlBehaviorDB.BehaviorLog[slaveName] or {}

    CatgirlEmoteDB = CatgirlEmoteDB or {}
    CatgirlEmoteDB.EmoteLog = CatgirlEmoteDB.EmoteLog or {}
    CatgirlEmoteDB.EmoteLog[slaveName] = CatgirlEmoteDB.EmoteLog[slaveName] or {}
end
local function parseAndStoreSlaveData(msg, sender)
    local slaveName = sender:match("^[^%-]+")
    ensureSlaveDatabases(slaveName)

    local function parseStateValue(value)
        if value == "true" then return true end
        if value == "false" then return false end
        return value
    end

    -- Parse log type
    local logType = msg:match("^(%w+),")

    if not logType then
        print("⚠️ Unknown message type:", msg)
        return
    end

    -- Parse and store based on log type
    if logType == "GuildLog" then
        local unixtime, senderName, message = msg:match("UNIXTIME:(%d+), SENDER:([^,]+), MSG:(.+)")
        if unixtime and senderName and message then
            table.insert(CatgirlGuildDB.GuildLog[slaveName], {
                unixtime = tonumber(unixtime),
                sender = senderName,
                message = message,
                timestamp = date("%Y-%m-%d %H:%M", tonumber(unixtime)),
                synced = 1
            })
        end

    elseif logType == "PetLog" then
        local timestamp, event, pet = msg:match("Timestamp:([^,]+), EVENT:([^,]+),? ?(.*)")
        if timestamp and event then
            table.insert(CatgirlPetDB.PetLog[slaveName], {
                timestamp = timestamp,
                event = event,
                pet = pet ~= "" and pet or nil,
                synced = 1
            })
        end

    elseif logType == "ZoneLog" then
        local timestamp, instanceType, zone = msg:match("tiemstamp:([^,]+), instanceType:([^,]+), zone:(.+)")
        if timestamp and instanceType and zone then
            table.insert(CatgirlZoneDB.ZoneLog[slaveName], {
                timestamp = timestamp,
                instanceType = instanceType,
                zone = zone,
                synced = 1
            })
        end

    elseif logType == "LocationLog" then
        local timestamp, unixtime, mapID, x, y = msg:match(
            "timestamp:([^,]+), unixtime:(%d+), mapID:([^,]+), x:([^,]+), y:([^,]+)"
        )
        if timestamp and unixtime and x and y then
            table.insert(CatgirlLocationDB.LocationLog[slaveName], {
                timestamp = timestamp,
                unixtime = tonumber(unixtime),
                mapID = mapID ~= "nil" and tonumber(mapID) or nil,
                x = x ~= "nil" and tonumber(x) or nil,
                y = y ~= "nil" and tonumber(y) or nil,
                receivedAt = time(),
                synced = 1
            })
        end

    elseif logType == "BehaviorLog" then
        local timestamp, unixtime, event, state, gag, blind = msg:match(
            "timestamp:([^,]+), unixtime:(%d+), event:([^,]+), state:([^,]+), Gagstate:([^,]+), BlindfoldState:([^,]+)"
        )
        if timestamp and unixtime and event then
            table.insert(CatgirlBehaviorDB.BehaviorLog[slaveName], {
                timestamp = timestamp,
                unixtime = tonumber(unixtime),
                event = event,
                state = state ~= "nil" and parseStateValue(state) or nil,
                Gagstate = gag ~= "nil" and gag or nil,
                BlindfoldState = blind ~= "nil" and blind or nil,
                synced = 1
            })
        end
    elseif logType == "BindTimer" then
        local bind, unlockAt, duration = msg:match("bind:([^,]+), unlockAt:(%d+), durationMinutes:(%d+)")
        if bind and unlockAt then
            CatgirlBehaviorDB.BehaviorLog[slaveName][bind] = {
                event = "KittenLock",
                bind = bind,
                unlockAt = tonumber(unlockAt),
                durationMinutes = duration and tonumber(duration) or nil,
                synced = 1
            }
        end
    elseif logType == "EmoteLog" then
    local timestamp, unixtime, senderName, action = msg:match("timestamp:([^,]+), unixtime:(%d+), sender:([^,]+), action:(%a+)")
    if timestamp and unixtime and senderName and action then
        table.insert(CatgirlEmoteDB.EmoteLog[slaveName], {
            timestamp = timestamp,
            unixtime = tonumber(unixtime),
            sender = senderName,
            action = action,
            synced = 1
        })
    end
    else
        print("Unhandled log type:", logType)
    end
end


local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == addonPrefix and channel == "WHISPER" then
        local shortName = sender:match("^[^%-]+")
        if not isMaster and not IsOwnerOf(shortName) then
            return
        end

        -- Prepare DB structure for that slave
        ensureSlaveDatabases(shortName)

        -- Now you can access their DBs
        local logTableGuild = CatgirlGuildDB.GuildLog[shortName]
        local logTablePet = CatgirlPetDB.PetLog[shortName]
        local logTableZone = CatgirlZoneDB.ZoneLog[shortName]
        local logTableBehavior = CatgirlBehaviorDB.BehaviorLog[shortName]
        parseAndStoreSlaveData(msg, sender)
        -- Debug: output that slave sent something
        print("|cff88ff88CatgirlTracker:|r Received WHISPER addon message from slave:", shortName)
    end
end)



