local addonPrefix = "CatgirlTracker"
local kittyname = UnitName("player")
local masterName = "Hollykitten"
local master = nil
local masterOnline = false

-- Route module prints through the shared debug gate.
local function AutoPrint(...)
    if CCT_AutoPrint then
        CCT_AutoPrint(...)
    end
end

local print = AutoPrint

local function ShortName(name)
    if not name then return name end
    return name:match("^[^%-]+")
end

local function RequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function GetGuildMemberInfo(shortName)
    if not shortName then return nil end
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name and ShortName(name):lower() == ShortName(shortName):lower() then
            return name, online
        end
    end
end

local function GetOwnerFromNote()
    if not IsInGuild() then
        return nil
    end

    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note, officerNote = GetGuildRosterInfo(i)
        if name and ShortName(name) == kittyname then
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

local function NormalizeRecipients(recipients)
    if recipients.master and recipients.owner then
        local masterShort = ShortName(recipients.master.name)
        local ownerShort = ShortName(recipients.owner.name)
        if masterShort and ownerShort and masterShort:lower() == ownerShort:lower() then
            recipients.master.alsoOwner = true
            recipients.owner.alsoMaster = true
        end
    end
end

local function BuildRecipients()
    local recipients = {}

    local masterRecipient = master
    local masterOnlineFlag = false
    if masterRecipient then
        local fullName, online = GetGuildMemberInfo(ShortName(masterRecipient))
        masterRecipient = fullName or masterRecipient
        if online == nil then
            masterOnlineFlag = masterOnline == true
        else
            masterOnlineFlag = online == true
            masterOnline = masterOnlineFlag
        end
    else
        local fullName, online = GetGuildMemberInfo(masterName)
        masterRecipient = fullName or masterName
        masterOnlineFlag = online == true
        if online ~= nil then
            masterOnline = masterOnlineFlag
        end
    end

    if masterRecipient then
        recipients.master = { name = masterRecipient, online = masterOnlineFlag }
    end

    local owner = GetOwnerFromNote()
    if owner then
        local ownerFull, ownerOnline = GetGuildMemberInfo(owner)
        recipients.owner = { name = ownerFull or owner, online = ownerOnline == true }
    end

    NormalizeRecipients(recipients)
    return recipients
end

local function EnsureRecipientTracking(entry)
    if not entry then return end
    if not entry.syncedRecipients then
        entry.syncedRecipients = {}
        if entry.synced == 1 then
            entry.syncedRecipients.master = true
            entry.syncedRecipients.owner = true
        end
    end
end

local function NeedsRecipient(entry, key)
    EnsureRecipientTracking(entry)
    return entry.syncedRecipients and not entry.syncedRecipients[key]
end

local function MarkRecipient(entry, key)
    EnsureRecipientTracking(entry)
    entry.syncedRecipients[key] = true
end

local function FinalizeSynced(entry, recipients)
    EnsureRecipientTracking(entry)
    local masterDone = true
    local ownerDone = true
    if recipients.master then
        masterDone = entry.syncedRecipients.master == true or recipients.master.alsoOwner
    end
    if recipients.owner and not recipients.owner.alsoMaster then
        ownerDone = entry.syncedRecipients.owner == true
    end
    if masterDone and ownerDone then
        entry.synced = 1
    end
end

local function HasPendingRecipients(entry, recipients)
    EnsureRecipientTracking(entry)
    if recipients.master and entry.syncedRecipients.master ~= true then
        return true
    end
    if recipients.owner and not recipients.owner.alsoMaster and entry.syncedRecipients.owner ~= true then
        return true
    end
    return false
end

local function SendToRecipient(entry, key, info, message)
    if not info or not info.name or not info.online then return false end
    if not NeedsRecipient(entry, key) then return false end

    if type(message) == "table" then
        for _, msg in ipairs(message) do
            C_ChatInfo.SendAddonMessage(addonPrefix, msg, "WHISPER", info.name)
        end
    else
        C_ChatInfo.SendAddonMessage(addonPrefix, message, "WHISPER", info.name)
    end

    MarkRecipient(entry, key)
    if key == "master" and info.alsoOwner then
        MarkRecipient(entry, "owner")
    elseif key == "owner" and info.alsoMaster then
        MarkRecipient(entry, "master")
    end
    return true
end

local function SendEntryToRecipients(entry, message, recipients)
    if not HasPendingRecipients(entry, recipients) then
        return false
    end

    local sent = false
    if recipients.master then
        sent = SendToRecipient(entry, "master", recipients.master, message) or sent
    end
    if recipients.owner and not recipients.owner.alsoMaster then
        sent = SendToRecipient(entry, "owner", recipients.owner, message) or sent
    end

    if sent then
        FinalizeSynced(entry, recipients)
    end
    return sent
end

local function MarkAllRecipients(entry, recipients)
    EnsureRecipientTracking(entry)
    if recipients.master then
        entry.syncedRecipients.master = true
        if recipients.master.alsoOwner then
            entry.syncedRecipients.owner = true
        end
    end
    if recipients.owner then
        entry.syncedRecipients.owner = true
        if recipients.owner.alsoMaster then
            entry.syncedRecipients.master = true
        end
    end
    entry.synced = 1
end

local function SafeField(value)
    if value == nil then return "nil" end
    return tostring(value)
end

local f = CreateFrame("Frame")
C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)

f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == addonPrefix then
        local myname = UnitName("player")
        local shortSender = ShortName(sender)
        if msg == "master" and shortSender ~= myname then
            if shortSender and shortSender:lower() == masterName:lower() then
                master = sender
                masterOnline = true
                print("|cffffff00CatgirlTracker:|r Master has come online nya your report will be compiled !! " .. master)
            end
        end
    end
end)

print("kittyname is:", kittyname)

C_Timer.NewTicker(3, function()
    if not IsInGuild() then return end

    CatgirlGuildDB = CatgirlGuildDB or {}
    CatgirlGuildDB.GuildLog = CatgirlGuildDB.GuildLog or {}
    CatgirlGuildDB.GuildLog[kittyname] = CatgirlGuildDB.GuildLog[kittyname] or {}

    CatgirlZoneDB = CatgirlZoneDB or {}
    CatgirlZoneDB.ZoneLog = CatgirlZoneDB.ZoneLog or {}
    CatgirlZoneDB.ZoneLog[kittyname] = CatgirlZoneDB.ZoneLog[kittyname] or {}

    CatgirlPetDB = CatgirlPetDB or {}
    CatgirlPetDB.PetLog = CatgirlPetDB.PetLog or {}
    CatgirlPetDB.PetLog[kittyname] = CatgirlPetDB.PetLog[kittyname] or {}

    CatgirlLocationDB = CatgirlLocationDB or {}
    CatgirlLocationDB.LocationLog = CatgirlLocationDB.LocationLog or {}
    CatgirlLocationDB.LocationLog[kittyname] = CatgirlLocationDB.LocationLog[kittyname] or {}

    CatgirlEmoteDB = CatgirlEmoteDB or {}
    CatgirlEmoteDB.EmoteLog = CatgirlEmoteDB.EmoteLog or {}
    CatgirlEmoteDB.EmoteLog[kittyname] = CatgirlEmoteDB.EmoteLog[kittyname] or {}

    local logTableGuild = CatgirlGuildDB.GuildLog[kittyname]
    local logTablePet = CatgirlPetDB.PetLog[kittyname]
    local logTableZone = CatgirlZoneDB.ZoneLog[kittyname]
    local logTableBehavior = CatgirlBehaviorDB.BehaviorLog[kittyname]
    local logTableEmote = CatgirlEmoteDB.EmoteLog[kittyname]
    local logTableLocation = CatgirlLocationDB.LocationLog[kittyname]

    local recipients = BuildRecipients()
    if not (recipients.master or recipients.owner) then
        return
    end

    local sentSomething = false

    local function BuildGuildMessages(entry)
        local message = entry.message or ""
        local messages = {}
        if #message > 150 then
            entry.messageFirstCase = entry.messageFirstCase or string.sub(message, 1, 149)
            entry.messageSecondCase = entry.messageSecondCase or string.sub(message, 150, 255)
            table.insert(messages, string.format(
                "GuildLog, UNIXTIME:%s, SENDER:%s, MSG:%s",
                entry.unixtime,
                entry.sender,
                entry.messageFirstCase
            ))
            table.insert(messages, string.format(
                "GuildLog, UNIXTIME:%s, SENDER:%s, MSG:%s",
                entry.unixtime,
                entry.sender,
                entry.messageSecondCase
            ))
        else
            entry.messageFirstCase = entry.messageFirstCase or string.sub(message, 1, 149)
            table.insert(messages, string.format(
                "GuildLog, UNIXTIME:%s, SENDER:%s, MSG:%s",
                entry.unixtime,
                entry.sender,
                entry.messageFirstCase
            ))
        end

        for _, msg in ipairs(messages) do
            print(msg)
        end
        return messages
    end

    if not sentSomething and logTableGuild then
        for _, entry in ipairs(logTableGuild) do
            if HasPendingRecipients(entry, recipients) then
                local messages = BuildGuildMessages(entry)
                if SendEntryToRecipients(entry, messages, recipients) then
                    sentSomething = true
                    break
                end
            end
        end
    end

    if not sentSomething and logTablePet then
        for _, entry in ipairs(logTablePet) do
            if HasPendingRecipients(entry, recipients) then
                local msg = string.format("PetLog, Timestamp:%s, EVENT:%s", entry.timestamp, entry.event, entry.pet)
                print(msg)
                if SendEntryToRecipients(entry, msg, recipients) then
                    sentSomething = true
                    break
                end
            end
        end
    end

    if not sentSomething and logTableZone then
        for _, entry in ipairs(logTableZone) do
            if HasPendingRecipients(entry, recipients) then
                local msg = string.format(
                    "ZoneLog, tiemstamp:%s, instanceType:%s, zone:%s",
                    entry.timestamp,
                    entry.instanceType,
                    entry.zone
                )
                print(msg)
                if SendEntryToRecipients(entry, msg, recipients) then
                    sentSomething = true
                    break
                end
            end
        end
    end

    if not sentSomething and logTableBehavior then
        for _, entry in ipairs(logTableBehavior) do
            if HasPendingRecipients(entry, recipients) then
                if entry.event == "BellJingle" or entry.event == "TailBellJingle" then
                    MarkAllRecipients(entry, recipients)
                    break
                end
                local msg = string.format(
                    "BehaviorLog, timestamp:%s, unixtime:%s, event:%s, state:%s, Gagstate:%s, BlindfoldState:%s",
                    SafeField(entry.timestamp),
                    SafeField(entry.unixtime),
                    SafeField(entry.event),
                    SafeField(entry.state),
                    SafeField(entry.Gagstate),
                    SafeField(entry.BlindfoldState)
                )
                print(msg)
                if SendEntryToRecipients(entry, msg, recipients) then
                    sentSomething = true
                    break
                end
            end
        end
    end

    if not sentSomething and logTableBehavior then
        local bindKeys = { "gag", "earmuffs", "blindfold", "mittens", "heels", "bell", "tailbell", "chastitybelt", "chastitybra" }
        for _, bind in ipairs(bindKeys) do
            local entry = logTableBehavior[bind]
            if entry and entry.unlockAt and HasPendingRecipients(entry, recipients) then
                local msg = string.format(
                    "BindTimer, bind:%s, unlockAt:%s, durationMinutes:%s",
                    SafeField(bind),
                    SafeField(entry.unlockAt),
                    SafeField(entry.durationMinutes)
                )
                print(msg)
                if SendEntryToRecipients(entry, msg, recipients) then
                    sentSomething = true
                    break
                end
            end
        end
    end

    if not sentSomething and logTableEmote then
        for _, entry in ipairs(logTableEmote) do
            if HasPendingRecipients(entry, recipients) then
                local msg = string.format(
                    "EmoteLog, timestamp:%s, unixtime:%s, sender:%s, action:%s",
                    SafeField(entry.timestamp),
                    SafeField(entry.unixtime),
                    SafeField(entry.sender),
                    SafeField(entry.action)
                )
                print(msg)
                if SendEntryToRecipients(entry, msg, recipients) then
                    sentSomething = true
                    break
                end
            end
        end
    end

    if not sentSomething and logTableLocation then
        for _, entry in ipairs(logTableLocation) do
            if HasPendingRecipients(entry, recipients) then
                local msg = string.format(
                    "LocationLog, timestamp:%s, unixtime:%s, mapID:%s, x:%s, y:%s, instanceID:%s",
                    SafeField(entry.timestamp),
                    SafeField(entry.unixtime),
                    SafeField(entry.mapID),
                    SafeField(entry.x),
                    SafeField(entry.y),
                    SafeField(entry.instanceID)
                )
                if CCT_AutoPrint then
                    CCT_AutoPrint(msg)
                end
                if SendEntryToRecipients(entry, msg, recipients) then
                    sentSomething = true
                    break
                end
            end
        end
    end
end)

print("Catgirl Send Data loaded.")

