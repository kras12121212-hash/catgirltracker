local master = nil

local addonPrefix = "CatgirlTracker"
local kittyname = UnitName("player")


local f = CreateFrame("Frame") -- we create a fram nya 

-- Register to receive addon messages under your prefix
-- if guild or direct messages is defined on sending 
C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)

--  Set sender name if a master comes online to the master
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == addonPrefix then
        local myname = UnitName("player")
        local shortSender = sender:match("^[^%-]+") -- strip realm from sender

        if msg == "master" and shortSender ~= myname then
            master = sender
            print("|cffffff00CatgirlTracker:|r Master has come online nya your report will be compiled !! " .. master)
        end
    end
end)
-- tis checks if the master is online in the guild
local function RequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

function IsGuildMemberOnline(targetName)
    -- Ensure guild roster is up to date
    RequestGuildRoster()

    -- removes realm name
    local shortName = master:match("^[^%-]+")

    for i = 1, GetNumGuildMembers() do -- loop from 1 to the number of guilld members
        -- removes other stuff like zone and notes oficer notest etc
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i) -- set the number we in to get guild info from
        if name then
            local cleanedName = name:match("^[^%-]+")
            if cleanedName == shortName then
                return online
            end
        end
    end

    return false
end


-- loop trough data to send for guild messages
print("kittyname is:", kittyname)
-- create a inifite loop 

C_Timer.NewTicker(3, function()


    CatgirlGuildDB = CatgirlGuildDB or {}
    CatgirlGuildDB.GuildLog = CatgirlGuildDB.GuildLog or {}
    CatgirlGuildDB.GuildLog[kittyname] = CatgirlGuildDB.GuildLog[kittyname] or {}
    
    CatgirlZoneDB = CatgirlZoneDB or {}
    CatgirlZoneDB.ZoneLog = CatgirlZoneDB.ZoneLog or {}
    CatgirlZoneDB.ZoneLog[kittyname] = CatgirlZoneDB.ZoneLog[kittyname] or {}
    
    CatgirlPetDB = CatgirlPetDB or {}
    CatgirlPetDB.PetLog = CatgirlPetDB.PetLog or {}
    CatgirlPetDB.PetLog[kittyname] = CatgirlPetDB.PetLog[kittyname] or {}

    CatgirlEmoteDB = CatgirlEmoteDB or {}
    CatgirlEmoteDB.EmoteLog = CatgirlEmoteDB.EmoteLog or {}
    CatgirlEmoteDB.EmoteLog[kittyname] = CatgirlEmoteDB.EmoteLog[kittyname] or {}


    local logTableGuild = CatgirlGuildDB.GuildLog[kittyname]
    local logTablePet = CatgirlPetDB.PetLog[kittyname]
    local logTableZone = CatgirlZoneDB.ZoneLog[kittyname]
    local logTableBehavior = CatgirlBehaviorDB.BehaviorLog[kittyname]
    local logTableEmote = CatgirlEmoteDB.EmoteLog[kittyname]


    local sentSomething = false

    -- this is guild log writer loop
    if not sentSomething and logTableGuild then
        for i, entry in ipairs(logTableGuild) do
            if entry.synced == 0 then
                if #entry.message > 150 then
                    entry.messageFirstCase = string.sub(entry.message, 1, 149) -- lua index for string starts at 1
                    entry.messageSecondCase = string.sub(entry.message, 150, 255)
                    print(string.format("GuildLog, UNIXTIME:%s, SENDER:%s, MSG:%s", entry.unixtime, entry.sender, entry.messageFirstCase))
                    C_ChatInfo.SendAddonMessage(addonPrefix, string.format("GuildLog, UNIXTIME:%s, SENDER:%s, MSG:%s", entry.unixtime, entry.sender, entry.messageFirstCase), "WHISPER", master)
                    print(string.format("GuildLog, UNIXTIME:%s, SENDER:%s, MSG:%s", entry.unixtime, entry.sender, entry.messageSecondCase))
                    C_ChatInfo.SendAddonMessage(addonPrefix, string.format("GuildLog, UNIXTIME:%s, SENDER:%s, MSG:%s", entry.unixtime, entry.sender, entry.messageSecondCase), "WHISPER", master)
                else
                    entry.messageFirstCase = string.sub(entry.message, 1, 149)
                    print(string.format("GuildLog, UNIXTIME:%s, SENDER:%s, MSG:%s", entry.unixtime, entry.sender, entry.messageFirstCase))
                    C_ChatInfo.SendAddonMessage(addonPrefix, string.format("GuildLog, UNIXTIME:%s, SENDER:%s, MSG:%s", entry.unixtime, entry.sender, entry.messageFirstCase), "WHISPER", master)

                end
                entry.synced = 1
                sentSomething = true
                break -- kills it afther sync one entry --only breaks out of logtable loop not the c ticker one
            end
        end
    else
        print("No guild log found for", kittyname)
    end
    -- print("test afther guild")
    if not sentSomething and logTablePet then -- loop to send Pet afther guild is send
        for i, entry in ipairs(logTablePet) do
            if entry.synced == 0 then
                print(string.format("PetLog, Timestamp:%s, EVENT:%s",entry.timestamp, entry.event, entry.pet))
                C_ChatInfo.SendAddonMessage(addonPrefix, string.format("PetLog, Timestamp:%s, EVENT:%s",entry.timestamp, entry.event, entry.pet), "WHISPER", master)
                entry.synced = 1
                sentSomething = true
                break -- kills it afther sync one entry 
            end
        end
    else
        print("No Pet log found for", kittyname)
    end
    -- print ("test afther pet")

    if not sentSomething and logTableZone then -- loop to send Pet afther guild is send
        for i, entry in ipairs(logTableZone) do
            if entry.synced == 0 then
                print(string.format("ZoneLog, tiemstamp:%s, instanceType:%s, zone:%s",entry.timestamp, entry.instanceType, entry.zone))
                C_ChatInfo.SendAddonMessage(addonPrefix, string.format("ZoneLog, tiemstamp:%s, instanceType:%s, zone:%s",entry.timestamp, entry.instanceType, entry.zone), "WHISPER", master)
                entry.synced = 1
                sentSomething = true
                break -- kills it afther sync one entry -
            end
        end
    else
        print("No guild Zone log found for", kittyname)
    end
    -- print ("test afther zone")

local function safeField(value)
    if value == nil then return "nil" end
    return tostring(value)
end

    if not sentSomething and logTableBehavior then -- loop to send Pet afther guild is send
        -- print("test", kittyname)
        for i, entry in ipairs(logTableBehavior) do
                if entry.synced == 0 then
                --print(string.format("BellState, tiemstamp:%s, unixtime:%s, event:%s, state:%s, Gagstate:%s, BlindfoldState:%s ",entry.timestamp, entry.unixtime, entry.event, entry.state, entry.Gagstate, entry.BlindfoldState))
                print(string.format(
                "BehaviorLog, timestamp:%s, unixtime:%s, event:%s, state:%s, Gagstate:%s, BlindfoldState:%s",
                safeField(entry.timestamp),
                safeField(entry.unixtime),
                safeField(entry.event),
                safeField(entry.state),
                safeField(entry.Gagstate),
                safeField(entry.BlindfoldState)
                ))
                C_ChatInfo.SendAddonMessage(addonPrefix, string.format(
                "BehaviorLog, timestamp:%s, unixtime:%s, event:%s, state:%s, Gagstate:%s, BlindfoldState:%s",
                safeField(entry.timestamp),
                safeField(entry.unixtime),
                safeField(entry.event),
                safeField(entry.state),
                safeField(entry.Gagstate),
                safeField(entry.BlindfoldState)
                ), "WHISPER", master)
                entry.synced = 1
                sentSomething = true
                break -- kills it afther sync one entry -
            end
        end
    else
        print("No behavior log found for", kittyname)
    end
    -- print ("test afther zone")

    if not sentSomething and logTableEmote then
        for i, entry in ipairs(logTableEmote) do
            if entry.synced == 0 then
                print(string.format(
                    "EmoteLog, timestamp:%s, unixtime:%s, sender:%s, action:%s",
                    safeField(entry.timestamp),
                    safeField(entry.unixtime),
                    safeField(entry.sender),
                    safeField(entry.action)
                ))
                C_ChatInfo.SendAddonMessage(addonPrefix, string.format(
                    "EmoteLog, timestamp:%s, unixtime:%s, sender:%s, action:%s",
                    safeField(entry.timestamp),
                    safeField(entry.unixtime),
                    safeField(entry.sender),
                    safeField(entry.action)
                ), "WHISPER", master)
                entry.synced = 1
                sentSomething = true
                break
            end
        end
    else
        print("No emote log found for", kittyname)
    end

end)

print("Catgirl Send Data  loaded.")
