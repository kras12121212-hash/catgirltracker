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
local TAIL_BELL_CLOSE_RANGE = 0.02
local PAW_SQUEAK_CLOSE_RANGE = 0.02
local HEELS_STEP_CLOSE_RANGE = 0.02
local PAW_SQUEAK_SOUNDS = {
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\pawsqueak1.wav",
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\pawsqueak2.wav",
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\pawsqueak3.wav",
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\pawsqueak4.wav",
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\pawsqueak5.wav",
}
local PAW_SQUEAK_COOLDOWN = 2
local PAW_CREAK_SOUNDS = {
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\creak-1.mp3",
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\creak-2.mp3",
    "Interface\\AddOns\\CatgirlTracker\\Sounds\\creak-3.mp3",
}
local PAW_CREAK_COOLDOWN = 2
local HEELS_STEP_SOUNDS = {
    HeelsStep3 = "Interface\\AddOns\\CatgirlTracker\\Sounds\\HighHeels3.wav",
    HeelsStep8 = "Interface\\AddOns\\CatgirlTracker\\Sounds\\HighHeels8.wav",
    HeelsStep12 = "Interface\\AddOns\\CatgirlTracker\\Sounds\\HighHeels12.wav",
}
local HEELS_STEP_COOLDOWN = 0.8
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

local function ParseNumber(value)
    if not value or value == "nil" then return nil end
    return tonumber(value)
end

local lastPawSqueakAt = 0
local lastPawCreakAt = 0
local lastHeelsStepAt = 0

local function GetNow()
    if GetTime then
        return GetTime()
    end
    return time()
end

local function CanPlayPawSqueak()
    local now = GetNow()
    if now - lastPawSqueakAt < PAW_SQUEAK_COOLDOWN then
        return false
    end
    lastPawSqueakAt = now
    return true
end

local function CanPlayPawCreak()
    local now = GetNow()
    if now - lastPawCreakAt < PAW_CREAK_COOLDOWN then
        return false
    end
    lastPawCreakAt = now
    return true
end

local function CanPlayHeelsStep()
    local now = GetNow()
    if now - lastHeelsStepAt < HEELS_STEP_COOLDOWN then
        return false
    end
    lastHeelsStepAt = now
    return true
end

local function GetRandomPawSqueakSound()
    return PAW_SQUEAK_SOUNDS[math.random(#PAW_SQUEAK_SOUNDS)]
end

local function GetRandomPawCreakSound()
    return PAW_CREAK_SOUNDS[math.random(#PAW_CREAK_SOUNDS)]
end

local function GetPlayerMapCoords()
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

local function GetInstanceID()
    if not GetInstanceInfo then
        return nil
    end
    local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceID and instanceID > 0 then
        return instanceID
    end
end

local function IsSameInstance(instanceID)
    local myInstanceID = GetInstanceID()
    if not instanceID or not myInstanceID then
        return false
    end
    return instanceID == myInstanceID
end

local function ParseTailBellJingle(msg)
    local owner, mapID, x, y, instanceID = msg:match("^TailBellJingle, owner:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)")
    if not owner then
        owner, mapID, x, y = msg:match("^TailBellJingle, owner:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+)")
    end
    if not owner then return nil end
    return owner:match("^[^%-]+"), ParseNumber(mapID), ParseNumber(x), ParseNumber(y), ParseNumber(instanceID)
end

local function IsTailBellClose(mapID, x, y, instanceID)
    local ownerMapID, ownerX, ownerY = GetPlayerMapCoords()
    if ownerMapID and ownerX and ownerY and mapID and x and y and ownerMapID == mapID then
        local dx = ownerX - x
        local dy = ownerY - y
        local dist = math.sqrt(dx * dx + dy * dy)
        return dist <= TAIL_BELL_CLOSE_RANGE, dist
    end
    if IsSameInstance(instanceID) then
        return true, nil
    end
    return false, nil
end

local function HandleTailBellJingle(msg, senderShort)
    local ownerShort, mapID, x, y, instanceID = ParseTailBellJingle(msg)
    if not ownerShort or ownerShort:lower() ~= myShortName:lower() then
        return
    end
    local close, dist = IsTailBellClose(mapID, x, y, instanceID)
    if close then
        PlaySoundFile("Interface\\AddOns\\CatgirlTracker\\Sounds\\sbell4seconds.ogg", "Master")
        print("|cff88ff88CatgirlTracker:|r Tail bell jingle heard from:", senderShort)
    else
        if dist then
            print("|cff88ff88CatgirlTracker:|r Tail bell jingle too far from:", senderShort, string.format("(%.4f)", dist))
        else
            print("|cff88ff88CatgirlTracker:|r Tail bell jingle ignored (no position):", senderShort)
        end
    end
end

local function ParsePawSqueak(msg)
    local owner, mapID, x, y, instanceID = msg:match("^PawSqueak, owner:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)")
    if not owner then
        owner, mapID, x, y = msg:match("^PawSqueak, owner:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+)")
    end
    if not owner then return nil end
    return owner:match("^[^%-]+"), ParseNumber(mapID), ParseNumber(x), ParseNumber(y), ParseNumber(instanceID)
end

local function IsPawSqueakClose(mapID, x, y, instanceID)
    local ownerMapID, ownerX, ownerY = GetPlayerMapCoords()
    if ownerMapID and ownerX and ownerY and mapID and x and y and ownerMapID == mapID then
        local dx = ownerX - x
        local dy = ownerY - y
        local dist = math.sqrt(dx * dx + dy * dy)
        return dist <= PAW_SQUEAK_CLOSE_RANGE, dist
    end
    if IsSameInstance(instanceID) then
        return true, nil
    end
    return false, nil
end

local function HandlePawSqueak(msg, senderShort)
    local ownerShort, mapID, x, y, instanceID = ParsePawSqueak(msg)
    if not ownerShort or ownerShort:lower() ~= myShortName:lower() then
        return
    end
    local close, dist = IsPawSqueakClose(mapID, x, y, instanceID)
    if close then
        if not CanPlayPawSqueak() then
            return
        end
        PlaySoundFile(GetRandomPawSqueakSound(), "Master")
        print("|cff88ff88CatgirlTracker:|r Paw squeak heard from:", senderShort)
    else
        if dist then
            print("|cff88ff88CatgirlTracker:|r Paw squeak too far from:", senderShort, string.format("(%.4f)", dist))
        else
            print("|cff88ff88CatgirlTracker:|r Paw squeak ignored (no position):", senderShort)
        end
    end
end

local function ParsePawCreak(msg)
    local owner, mapID, x, y, instanceID = msg:match("^PawCreak, owner:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)")
    if not owner then
        owner, mapID, x, y = msg:match("^PawCreak, owner:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+)")
    end
    if not owner then return nil end
    return owner:match("^[^%-]+"), ParseNumber(mapID), ParseNumber(x), ParseNumber(y), ParseNumber(instanceID)
end

local function HandlePawCreak(msg, senderShort)
    local ownerShort, mapID, x, y, instanceID = ParsePawCreak(msg)
    if not ownerShort or ownerShort:lower() ~= myShortName:lower() then
        return
    end
    local close, dist = IsPawSqueakClose(mapID, x, y, instanceID)
    if close then
        if not CanPlayPawCreak() then
            return
        end
        PlaySoundFile(GetRandomPawCreakSound(), "Master")
        print("|cff88ff88CatgirlTracker:|r Paw creak heard from:", senderShort)
    else
        if dist then
            print("|cff88ff88CatgirlTracker:|r Paw creak too far from:", senderShort, string.format("(%.4f)", dist))
        else
            print("|cff88ff88CatgirlTracker:|r Paw creak ignored (no position):", senderShort)
        end
    end
end

local function ParseHeelsStep(msg)
    local event, owner, mapID, x, y, instanceID = msg:match(
        "^(HeelsStep%d+), owner:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)"
    )
    if not event then
        event, owner, mapID, x, y = msg:match(
            "^(HeelsStep%d+), owner:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+)"
        )
    end
    if not event or not owner then return nil end
    return event, owner:match("^[^%-]+"), ParseNumber(mapID), ParseNumber(x), ParseNumber(y), ParseNumber(instanceID)
end

local function IsHeelsStepClose(mapID, x, y, instanceID)
    local ownerMapID, ownerX, ownerY = GetPlayerMapCoords()
    if ownerMapID and ownerX and ownerY and mapID and x and y and ownerMapID == mapID then
        local dx = ownerX - x
        local dy = ownerY - y
        local dist = math.sqrt(dx * dx + dy * dy)
        return dist <= HEELS_STEP_CLOSE_RANGE, dist
    end
    if IsSameInstance(instanceID) then
        return true, nil
    end
    return false, nil
end

local function HandleHeelsStep(msg, senderShort)
    local event, ownerShort, mapID, x, y, instanceID = ParseHeelsStep(msg)
    if not event or not ownerShort or ownerShort:lower() ~= myShortName:lower() then
        return
    end
    local close, dist = IsHeelsStepClose(mapID, x, y, instanceID)
    if close then
        if not CanPlayHeelsStep() then
            return
        end
        local sound = HEELS_STEP_SOUNDS[event]
        if sound then
            PlaySoundFile(sound, "Master")
            print("|cff88ff88CatgirlTracker:|r Heel steps heard from:", senderShort)
        end
    else
        if dist then
            print("|cff88ff88CatgirlTracker:|r Heel steps too far from:", senderShort, string.format("(%.4f)", dist))
        else
            print("|cff88ff88CatgirlTracker:|r Heel steps ignored (no position):", senderShort)
        end
    end
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
    if event ~= "CHAT_MSG_ADDON" or prefix ~= addonPrefix then
        return
    end

    local shortName = sender and sender:match("^[^%-]+")
    if not shortName then return end

    if msg and msg:match("^TailBellJingle,") then
        HandleTailBellJingle(msg, shortName)
        return
    end
    if msg and msg:match("^PawSqueak,") then
        HandlePawSqueak(msg, shortName)
        return
    end
    if msg and msg:match("^PawCreak,") then
        HandlePawCreak(msg, shortName)
        return
    end
    if msg and msg:match("^HeelsStep%d+,") then
        HandleHeelsStep(msg, shortName)
        return
    end

    if channel ~= "WHISPER" then
        return
    end
    if not isMaster and not IsOwnerOf(shortName) then
        return
    end

    if msg and (msg:match("^MaidTasksHeader,") or msg:match("^MaidTasksItem,")) then
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
end)



