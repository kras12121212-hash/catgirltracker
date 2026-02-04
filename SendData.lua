local addonPrefix = "CatgirlTracker"
local kittyname = UnitName("player")
local masterName = "Holykitten"
local master = nil
local masterOnline = false
local RESYNC_PAUSE_SECONDS = 60
local BIND_KEYS = { "gag", "earmuffs", "blindfold", "mittens", "heels", "bell", "tailbell", "chastitybelt", "chastitybra" }
local resyncQueue = {}
local sendState = {
    throttleUntil = 0,
    lastThrottleAt = 0,
    lastThrottleResult = nil,
    lastSendLabel = "Idle",
    lastSendAt = 0,
    ownerPriorityActive = false,
}

-- Route module prints through the shared debug gate.
local function AutoPrint(...)
    if CCT_AutoPrint then
        CCT_AutoPrint(...)
    end
end

local print = AutoPrint

local function GetUnixNow()
    if time then
        return time()
    end
    return 0
end

local function SetSendLabel(label)
    sendState.lastSendLabel = label or "Idle"
    sendState.lastSendAt = GetUnixNow()
end

local function IsSendThrottled(result)
    if type(Enum) == "table" and Enum.SendAddonMessageResult then
        local throttle = Enum.SendAddonMessageResult.AddonMessageThrottle
        local tooMany = Enum.SendAddonMessageResult.TooManyAddonMessages
        if result == throttle or result == tooMany then
            return true
        end
    end
    return false
end

local function IsSendSuccess(result)
    if result == nil then
        return true
    end
    if type(Enum) == "table" and Enum.SendAddonMessageResult then
        local ok = Enum.SendAddonMessageResult.Success
        if ok ~= nil then
            return result == ok
        end
    end
    return result == true
end

local function RecordThrottle(result)
    local now = GetUnixNow()
    sendState.lastThrottleAt = now
    sendState.lastThrottleResult = result
    sendState.throttleUntil = now + RESYNC_PAUSE_SECONDS
end

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

local function SendAddonMessageSafe(message, target)
    local result = C_ChatInfo.SendAddonMessage(addonPrefix, message, "WHISPER", target)
    if IsSendThrottled(result) then
        RecordThrottle(result)
        return false, true
    end
    if not IsSendSuccess(result) then
        return false, false
    end
    return true, false
end

local function SendToRecipient(entry, key, info, message)
    if not info or not info.name or not info.online then return false end
    if not NeedsRecipient(entry, key) then return false end

    if type(message) == "table" then
        for _, msg in ipairs(message) do
            local ok, throttled = SendAddonMessageSafe(msg, info.name)
            if throttled then
                return false, true
            end
            if not ok then
                return false, false
            end
        end
    else
        local ok, throttled = SendAddonMessageSafe(message, info.name)
        if throttled then
            return false, true
        end
        if not ok then
            return false, false
        end
    end

    MarkRecipient(entry, key)
    if key == "master" and info.alsoOwner then
        MarkRecipient(entry, "owner")
    elseif key == "owner" and info.alsoMaster then
        MarkRecipient(entry, "master")
    end
    return true, false
end

local function SendEntryToRecipients(entry, message, recipients)
    if not HasPendingRecipients(entry, recipients) then
        return false, false
    end

    local sent = false
    local throttled = false
    if recipients.owner and not recipients.owner.alsoMaster then
        local ok, wasThrottled = SendToRecipient(entry, "owner", recipients.owner, message)
        if wasThrottled then
            throttled = true
        end
        sent = ok or sent
        if throttled then
            if sent then
                FinalizeSynced(entry, recipients)
            end
            return sent, true
        end
    end
    if recipients.master and not sendState.ownerPriorityActive then
        local ok, wasThrottled = SendToRecipient(entry, "master", recipients.master, message)
        if wasThrottled then
            throttled = true
        end
        sent = ok or sent
        if throttled then
            if sent then
                FinalizeSynced(entry, recipients)
            end
            return sent, true
        end
    end

    if sent then
        FinalizeSynced(entry, recipients)
    end
    return sent, false
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

local function BuildBehaviorMessage(entry)
    return string.format(
        "BehaviorLog, timestamp:%s, unixtime:%s, event:%s, state:%s, Gagstate:%s, BlindfoldState:%s",
        SafeField(entry.timestamp),
        SafeField(entry.unixtime),
        SafeField(entry.event),
        SafeField(entry.state),
        SafeField(entry.Gagstate),
        SafeField(entry.BlindfoldState)
    )
end

local function QueueResyncMessage(label, message)
    local entry = { synced = 0 }
    table.insert(resyncQueue, {
        label = label,
        entry = entry,
        message = message,
    })
end

local function FindLastBehaviorEvent(log, eventName)
    if not log then
        return nil
    end
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry and entry.event == eventName then
            return entry
        end
    end
    return nil
end

local function ForceResyncLatestState()
    if not CatgirlBehaviorDB or not CatgirlBehaviorDB.BehaviorLog then
        return
    end
    local log = CatgirlBehaviorDB.BehaviorLog[kittyname]
    if not log then
        return
    end

    resyncQueue = {}

    local nowStamp = date("%Y-%m-%d %H:%M")
    local nowUnix = GetUnixNow()

    local levels = log.HeelsSkillLevels
    if type(levels) == "table" then
        for _, kind in ipairs({ "maid", "high", "ballet" }) do
            local level = tonumber(levels[kind]) or 1
            local entry = {
                timestamp = nowStamp,
                unixtime = nowUnix,
                event = "HeelsSkill",
                state = string.format("%s:%d", kind, level),
                synced = 0,
            }
            QueueResyncMessage("HeelsSkill " .. kind, BuildBehaviorMessage(entry))
        end
    end

    local stateEvents = {
        "KittenHeels",
        "BellState",
        "TailBellState",
        "PawMittens",
        "KittenGag",
        "KittenBlindfold",
        "KittenEarmuffs",
        "TrackingJewel",
        "ChastityBelt",
        "ChastityBra",
        "KittenHeat",
        "KittenSubmissiveness",
    }

    for _, eventName in ipairs(stateEvents) do
        local lastEntry = FindLastBehaviorEvent(log, eventName)
        if lastEntry then
            local entry = {
                timestamp = lastEntry.timestamp,
                unixtime = lastEntry.unixtime,
                event = lastEntry.event,
                state = lastEntry.state,
                Gagstate = lastEntry.Gagstate,
                BlindfoldState = lastEntry.BlindfoldState,
                synced = 0,
            }
            QueueResyncMessage(eventName, BuildBehaviorMessage(entry))
        end
    end

    for _, bind in ipairs(BIND_KEYS) do
        local entry = log[bind]
        if entry and entry.unlockAt then
            local msg = string.format(
                "BindTimer, bind:%s, unlockAt:%s, durationMinutes:%s",
                SafeField(bind),
                SafeField(entry.unlockAt),
                SafeField(entry.durationMinutes)
            )
            QueueResyncMessage("BindTimer " .. bind, msg)
        end
    end
end

local syncDebugFrame = nil

local function EnsureSyncDebugFrame()
    if syncDebugFrame then
        return
    end
    syncDebugFrame = CreateFrame("Frame", "CatgirlSyncDebugFrame", UIParent, "BackdropTemplate")
    syncDebugFrame:SetSize(360, 300)
    syncDebugFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -30, -120)
    syncDebugFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    syncDebugFrame:SetBackdropColor(0, 0, 0, 0.8)
    syncDebugFrame:SetMovable(true)
    syncDebugFrame:EnableMouse(true)
    syncDebugFrame:RegisterForDrag("LeftButton")
    syncDebugFrame:SetScript("OnDragStart", syncDebugFrame.StartMoving)
    syncDebugFrame:SetScript("OnDragStop", syncDebugFrame.StopMovingOrSizing)

    syncDebugFrame.title = syncDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    syncDebugFrame.title:SetPoint("TOPLEFT", 12, -10)
    syncDebugFrame.title:SetText("Catgirl Sync Queue")

    syncDebugFrame.noticeText = syncDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    syncDebugFrame.noticeText:SetPoint("TOPLEFT", syncDebugFrame.title, "BOTTOMLEFT", 0, -6)
    syncDebugFrame.noticeText:SetWidth(330)
    syncDebugFrame.noticeText:SetJustifyH("LEFT")
    syncDebugFrame.noticeText:SetText("THIS IS CATGIRL SIDE ONLY IF YOU ARE OWNER TELL YOUR CATGIRL TO CHECK THE STATS")

    syncDebugFrame.statusText = syncDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    syncDebugFrame.statusText:SetPoint("TOPLEFT", syncDebugFrame.noticeText, "BOTTOMLEFT", 0, -6)
    syncDebugFrame.statusText:SetText("Status: Idle")

    syncDebugFrame.rosterText = syncDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    syncDebugFrame.rosterText:SetPoint("TOPLEFT", syncDebugFrame.statusText, "BOTTOMLEFT", 0, -6)
    syncDebugFrame.rosterText:SetWidth(330)
    syncDebugFrame.rosterText:SetJustifyH("LEFT")
    syncDebugFrame.rosterText:SetText("Roster: n/a")

    syncDebugFrame.ownerStatusText = syncDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    syncDebugFrame.ownerStatusText:SetPoint("TOPLEFT", syncDebugFrame.rosterText, "BOTTOMLEFT", 0, -6)
    syncDebugFrame.ownerStatusText:SetWidth(330)
    syncDebugFrame.ownerStatusText:SetJustifyH("LEFT")
    syncDebugFrame.ownerStatusText:SetText("Owner: n/a")

    syncDebugFrame.masterStatusText = syncDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    syncDebugFrame.masterStatusText:SetPoint("TOPLEFT", syncDebugFrame.ownerStatusText, "BOTTOMLEFT", 0, -6)
    syncDebugFrame.masterStatusText:SetWidth(330)
    syncDebugFrame.masterStatusText:SetJustifyH("LEFT")
    syncDebugFrame.masterStatusText:SetText("Master: n/a")

    syncDebugFrame.ownerQueueText = syncDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    syncDebugFrame.ownerQueueText:SetPoint("TOPLEFT", syncDebugFrame.masterStatusText, "BOTTOMLEFT", 0, -6)
    syncDebugFrame.ownerQueueText:SetWidth(330)
    syncDebugFrame.ownerQueueText:SetJustifyH("LEFT")
    syncDebugFrame.ownerQueueText:SetText("Owner pending: 0")

    syncDebugFrame.masterQueueText = syncDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    syncDebugFrame.masterQueueText:SetPoint("TOPLEFT", syncDebugFrame.ownerQueueText, "BOTTOMLEFT", 0, -6)
    syncDebugFrame.masterQueueText:SetWidth(330)
    syncDebugFrame.masterQueueText:SetJustifyH("LEFT")
    syncDebugFrame.masterQueueText:SetText("Master pending: 0")

    syncDebugFrame.currentText = syncDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    syncDebugFrame.currentText:SetPoint("TOPLEFT", syncDebugFrame.masterQueueText, "BOTTOMLEFT", 0, -6)
    syncDebugFrame.currentText:SetWidth(330)
    syncDebugFrame.currentText:SetJustifyH("LEFT")
    syncDebugFrame.currentText:SetText("Sending: Idle")

    syncDebugFrame.throttleText = syncDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    syncDebugFrame.throttleText:SetPoint("TOPLEFT", syncDebugFrame.currentText, "BOTTOMLEFT", 0, -6)
    syncDebugFrame.throttleText:SetWidth(330)
    syncDebugFrame.throttleText:SetJustifyH("LEFT")
    syncDebugFrame.throttleText:SetText("Throttle: None")

    syncDebugFrame.warningText = syncDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    syncDebugFrame.warningText:SetPoint("TOPLEFT", syncDebugFrame.throttleText, "BOTTOMLEFT", 0, -10)
    syncDebugFrame.warningText:SetWidth(330)
    syncDebugFrame.warningText:SetJustifyH("LEFT")
    syncDebugFrame.warningText:SetText("Caution only use afther you waited for sync log to empty using this will couse duplicate entry")

    syncDebugFrame.forceButton = CreateFrame("Button", nil, syncDebugFrame, "UIPanelButtonTemplate")
    syncDebugFrame.forceButton:SetSize(120, 22)
    syncDebugFrame.forceButton:SetPoint("TOPLEFT", syncDebugFrame.warningText, "BOTTOMLEFT", 0, -6)
    syncDebugFrame.forceButton:SetText("Force Resync")
    syncDebugFrame.forceButton:SetScript("OnClick", function()
        ForceResyncLatestState()
    end)
end

local function CountPendingListForRecipient(list, recipientKey)
    local count = 0
    if not list then
        return 0
    end
    for _, entry in ipairs(list) do
        if NeedsRecipient(entry, recipientKey) then
            count = count + 1
        end
    end
    return count
end

local function CountPendingBindTimersForRecipient(log, recipientKey)
    local count = 0
    if not log then
        return 0
    end
    for _, bind in ipairs(BIND_KEYS) do
        local entry = log[bind]
        if entry and entry.unlockAt and NeedsRecipient(entry, recipientKey) then
            count = count + 1
        end
    end
    return count
end

local function CountPendingResyncForRecipient(recipientKey)
    local count = 0
    for _, item in ipairs(resyncQueue) do
        if item.entry and NeedsRecipient(item.entry, recipientKey) then
            count = count + 1
        end
    end
    return count
end

local function UpdateSyncDebugFrame(recipients, logTableBehavior, logTableGuild, logTablePet, logTableZone, logTableEmote, logTableLocation)
    if not (CCT_IsDebugEnabled and CCT_IsDebugEnabled()) then
        if syncDebugFrame then
            syncDebugFrame:Hide()
        end
        return
    end
    recipients = recipients or {}
    EnsureSyncDebugFrame()
    syncDebugFrame:Show()

    local rosterCount = nil
    if GetNumGuildMembers then
        rosterCount = GetNumGuildMembers()
    end
    if IsInGuild and not IsInGuild() then
        syncDebugFrame.rosterText:SetText("Roster: not in guild")
    elseif rosterCount and rosterCount > 0 then
        syncDebugFrame.rosterText:SetText("Roster: " .. rosterCount .. " members")
    else
        syncDebugFrame.rosterText:SetText("Roster: 0 (not ready?)")
    end

    local function FormatRecipientStatus(label, info)
        if not info then
            return label .. ": n/a"
        end
        local name = info.name or "unknown"
        local status = info.online == true and "online" or "offline"
        if info.online == nil then
            status = "unknown"
        end
        return string.format("%s: %s (%s)", label, name, status)
    end

    syncDebugFrame.ownerStatusText:SetText(FormatRecipientStatus("Owner", recipients.owner))
    syncDebugFrame.masterStatusText:SetText(FormatRecipientStatus("Master", recipients.master))

    local countsOwner = {}
    local countsMaster = {}

    if recipients.owner then
        countsOwner.resync = CountPendingResyncForRecipient("owner")
        countsOwner.behavior = CountPendingListForRecipient(logTableBehavior, "owner")
        countsOwner.binds = CountPendingBindTimersForRecipient(logTableBehavior, "owner")
        countsOwner.pet = CountPendingListForRecipient(logTablePet, "owner")
        countsOwner.zone = CountPendingListForRecipient(logTableZone, "owner")
        countsOwner.emote = CountPendingListForRecipient(logTableEmote, "owner")
        countsOwner.guild = CountPendingListForRecipient(logTableGuild, "owner")
        countsOwner.location = CountPendingListForRecipient(logTableLocation, "owner")
        countsOwner.total = countsOwner.resync + countsOwner.behavior + countsOwner.binds + countsOwner.pet
            + countsOwner.zone + countsOwner.emote + countsOwner.guild + countsOwner.location
    end

    if recipients.master then
        countsMaster.resync = CountPendingResyncForRecipient("master")
        countsMaster.behavior = CountPendingListForRecipient(logTableBehavior, "master")
        countsMaster.binds = CountPendingBindTimersForRecipient(logTableBehavior, "master")
        countsMaster.pet = CountPendingListForRecipient(logTablePet, "master")
        countsMaster.zone = CountPendingListForRecipient(logTableZone, "master")
        countsMaster.emote = CountPendingListForRecipient(logTableEmote, "master")
        countsMaster.guild = CountPendingListForRecipient(logTableGuild, "master")
        countsMaster.location = CountPendingListForRecipient(logTableLocation, "master")
        countsMaster.total = countsMaster.resync + countsMaster.behavior + countsMaster.binds + countsMaster.pet
            + countsMaster.zone + countsMaster.emote + countsMaster.guild + countsMaster.location
    end

    local statusText = "Status: Idle"
    local now = GetUnixNow()
    if sendState.throttleUntil and now < sendState.throttleUntil then
        local remaining = math.max(0, sendState.throttleUntil - now)
        statusText = string.format("Status: Paused %ds", remaining)
    end
    syncDebugFrame.statusText:SetText(statusText)
    if recipients.owner then
        syncDebugFrame.ownerQueueText:SetText(string.format(
            "Owner pending: %d (Resync:%d Behavior:%d Bind:%d Pet:%d Zone:%d Emote:%d Guild:%d Location:%d)",
            countsOwner.total,
            countsOwner.resync,
            countsOwner.behavior,
            countsOwner.binds,
            countsOwner.pet,
            countsOwner.zone,
            countsOwner.emote,
            countsOwner.guild,
            countsOwner.location
        ))
    else
        syncDebugFrame.ownerQueueText:SetText("Owner pending: n/a")
    end
    if recipients.master then
        syncDebugFrame.masterQueueText:SetText(string.format(
            "Master pending: %d (Resync:%d Behavior:%d Bind:%d Pet:%d Zone:%d Emote:%d Guild:%d Location:%d)",
            countsMaster.total,
            countsMaster.resync,
            countsMaster.behavior,
            countsMaster.binds,
            countsMaster.pet,
            countsMaster.zone,
            countsMaster.emote,
            countsMaster.guild,
            countsMaster.location
        ))
    else
        syncDebugFrame.masterQueueText:SetText("Master pending: n/a")
    end
    syncDebugFrame.currentText:SetText("Sending: " .. (sendState.lastSendLabel or "Idle"))

    if sendState.lastThrottleAt and sendState.lastThrottleAt > 0 then
        local when = date("%H:%M:%S", sendState.lastThrottleAt)
        syncDebugFrame.throttleText:SetText("Throttle: " .. when)
    else
        syncDebugFrame.throttleText:SetText("Throttle: None")
    end
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

C_Timer.NewTicker(1.2, function()
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
    UpdateSyncDebugFrame(recipients, logTableBehavior, logTableGuild, logTablePet, logTableZone, logTableEmote, logTableLocation)
    if not (recipients.master or recipients.owner) then
        return
    end

    local nowUnix = GetUnixNow()
    if sendState.throttleUntil and nowUnix < sendState.throttleUntil then
        SetSendLabel("Paused")
        UpdateSyncDebugFrame(recipients, logTableBehavior, logTableGuild, logTablePet, logTableZone, logTableEmote, logTableLocation)
        return
    end

    local ownerPendingTotal = 0
    if recipients.owner and recipients.owner.online == true and not recipients.owner.alsoMaster then
        ownerPendingTotal = CountPendingResyncForRecipient("owner")
            + CountPendingListForRecipient(logTableBehavior, "owner")
            + CountPendingBindTimersForRecipient(logTableBehavior, "owner")
            + CountPendingListForRecipient(logTablePet, "owner")
            + CountPendingListForRecipient(logTableZone, "owner")
            + CountPendingListForRecipient(logTableEmote, "owner")
            + CountPendingListForRecipient(logTableGuild, "owner")
            + CountPendingListForRecipient(logTableLocation, "owner")
    end
    sendState.ownerPriorityActive = ownerPendingTotal > 0

    local sentSomething = false
    SetSendLabel("Idle")

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

    if not sentSomething and #resyncQueue > 0 then
        local i = 1
        while i <= #resyncQueue do
            local item = resyncQueue[i]
            if not item or not item.entry or not HasPendingRecipients(item.entry, recipients) then
                table.remove(resyncQueue, i)
            else
                SetSendLabel(string.format("Resync %d/%d: %s", i, #resyncQueue, item.label or "item"))
                local sent, throttled = SendEntryToRecipients(item.entry, item.message, recipients)
                if throttled then
                    SetSendLabel(sendState.lastSendLabel .. " (throttled)")
                    UpdateSyncDebugFrame(recipients, logTableBehavior, logTableGuild, logTablePet, logTableZone, logTableEmote, logTableLocation)
                    return
                end
                if sent then
                    table.remove(resyncQueue, i)
                    sentSomething = true
                end
                break
            end
        end
    end

    if not sentSomething and logTablePet then
        for i, entry in ipairs(logTablePet) do
            if HasPendingRecipients(entry, recipients) then
                SetSendLabel(string.format("PetLog %d/%d", i, #logTablePet))
                local msg = string.format("PetLog, Timestamp:%s, EVENT:%s", entry.timestamp, entry.event, entry.pet)
                print(msg)
                local sent, throttled = SendEntryToRecipients(entry, msg, recipients)
                if throttled then
                    SetSendLabel(sendState.lastSendLabel .. " (throttled)")
                    UpdateSyncDebugFrame(recipients, logTableBehavior, logTableGuild, logTablePet, logTableZone, logTableEmote, logTableLocation)
                    return
                end
                if sent then
                    sentSomething = true
                    break
                end
            end
        end
    end

    if not sentSomething and logTableZone then
        for i, entry in ipairs(logTableZone) do
            if HasPendingRecipients(entry, recipients) then
                SetSendLabel(string.format("ZoneLog %d/%d", i, #logTableZone))
                local msg = string.format(
                    "ZoneLog, tiemstamp:%s, instanceType:%s, zone:%s",
                    entry.timestamp,
                    entry.instanceType,
                    entry.zone
                )
                print(msg)
                local sent, throttled = SendEntryToRecipients(entry, msg, recipients)
                if throttled then
                    SetSendLabel(sendState.lastSendLabel .. " (throttled)")
                    UpdateSyncDebugFrame(recipients, logTableBehavior, logTableGuild, logTablePet, logTableZone, logTableEmote, logTableLocation)
                    return
                end
                if sent then
                    sentSomething = true
                    break
                end
            end
        end
    end

    if not sentSomething and logTableBehavior then
        for i, entry in ipairs(logTableBehavior) do
            if HasPendingRecipients(entry, recipients) then
                if entry.event == "BellJingle" or entry.event == "TailBellJingle" then
                    MarkAllRecipients(entry, recipients)
                    break
                end
                SetSendLabel(string.format("BehaviorLog %d/%d", i, #logTableBehavior))
                local msg = BuildBehaviorMessage(entry)
                print(msg)
                local sent, throttled = SendEntryToRecipients(entry, msg, recipients)
                if throttled then
                    SetSendLabel(sendState.lastSendLabel .. " (throttled)")
                    UpdateSyncDebugFrame(recipients, logTableBehavior, logTableGuild, logTablePet, logTableZone, logTableEmote, logTableLocation)
                    return
                end
                if sent then
                    sentSomething = true
                    break
                end
            end
        end
    end

    if not sentSomething and logTableBehavior then
        for _, bind in ipairs(BIND_KEYS) do
            local entry = logTableBehavior[bind]
            if entry and entry.unlockAt and HasPendingRecipients(entry, recipients) then
                SetSendLabel("BindTimer " .. bind)
                local msg = string.format(
                    "BindTimer, bind:%s, unlockAt:%s, durationMinutes:%s",
                    SafeField(bind),
                    SafeField(entry.unlockAt),
                    SafeField(entry.durationMinutes)
                )
                print(msg)
                local sent, throttled = SendEntryToRecipients(entry, msg, recipients)
                if throttled then
                    SetSendLabel(sendState.lastSendLabel .. " (throttled)")
                    UpdateSyncDebugFrame(recipients, logTableBehavior, logTableGuild, logTablePet, logTableZone, logTableEmote, logTableLocation)
                    return
                end
                if sent then
                    sentSomething = true
                    break
                end
            end
        end
    end

    if not sentSomething and logTableEmote then
        for i, entry in ipairs(logTableEmote) do
            if HasPendingRecipients(entry, recipients) then
                SetSendLabel(string.format("EmoteLog %d/%d", i, #logTableEmote))
                local msg = string.format(
                    "EmoteLog, timestamp:%s, unixtime:%s, sender:%s, action:%s",
                    SafeField(entry.timestamp),
                    SafeField(entry.unixtime),
                    SafeField(entry.sender),
                    SafeField(entry.action)
                )
                print(msg)
                local sent, throttled = SendEntryToRecipients(entry, msg, recipients)
                if throttled then
                    SetSendLabel(sendState.lastSendLabel .. " (throttled)")
                    UpdateSyncDebugFrame(recipients, logTableBehavior, logTableGuild, logTablePet, logTableZone, logTableEmote, logTableLocation)
                    return
                end
                if sent then
                    sentSomething = true
                    break
                end
            end
        end
    end

    if not sentSomething and logTableGuild then
        for i, entry in ipairs(logTableGuild) do
            if HasPendingRecipients(entry, recipients) then
                SetSendLabel(string.format("GuildLog %d/%d", i, #logTableGuild))
                local messages = BuildGuildMessages(entry)
                local sent, throttled = SendEntryToRecipients(entry, messages, recipients)
                if throttled then
                    SetSendLabel(sendState.lastSendLabel .. " (throttled)")
                    UpdateSyncDebugFrame(recipients, logTableBehavior, logTableGuild, logTablePet, logTableZone, logTableEmote, logTableLocation)
                    return
                end
                if sent then
                    sentSomething = true
                    break
                end
            end
        end
    end

    if not sentSomething and logTableLocation then
        for i, entry in ipairs(logTableLocation) do
            if HasPendingRecipients(entry, recipients) then
                SetSendLabel(string.format("LocationLog %d/%d", i, #logTableLocation))
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
                local sent, throttled = SendEntryToRecipients(entry, msg, recipients)
                if throttled then
                    SetSendLabel(sendState.lastSendLabel .. " (throttled)")
                    UpdateSyncDebugFrame(recipients, logTableBehavior, logTableGuild, logTablePet, logTableZone, logTableEmote, logTableLocation)
                    return
                end
                if sent then
                    sentSomething = true
                    break
                end
            end
        end
    end

    UpdateSyncDebugFrame(recipients, logTableBehavior, logTableGuild, logTablePet, logTableZone, logTableEmote, logTableLocation)
end)

print("Catgirl Send Data loaded.")

