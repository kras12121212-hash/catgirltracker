local kittyname = UnitName("player")
local addonPrefix = "CatgirlTracker"
local masterName = "Holykitten" -- short name only (no realm)
local myName = UnitName("player")
local isMaster = (myName == masterName) -- ← controls master mode

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

    -- Parse log type
    local logType = msg:match("^(%w+Log),")

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

    elseif logType == "BehaviorLog" then
        local timestamp, unixtime, event, state, gag, blind = msg:match(
            "timestamp:([^,]+), unixtime:(%d+), event:([^,]+), state:([^,]+), Gagstate:([^,]+), BlindfoldState:([^,]+)"
        )
        if timestamp and unixtime and event then
            table.insert(CatgirlBehaviorDB.BehaviorLog[slaveName], {
                timestamp = timestamp,
                unixtime = tonumber(unixtime),
                event = event,
                state = state ~= "nil" and state or nil,
                Gagstate = gag ~= "nil" and gag or nil,
                BlindfoldState = blind ~= "nil" and blind or nil,
                synced = 1
            })
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
    if isMaster and event == "CHAT_MSG_ADDON" and prefix == addonPrefix and channel == "WHISPER" then
        local shortName = sender:match("^[^%-]+")

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



