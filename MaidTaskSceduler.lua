local addonPrefix = "CatgirlTracker"
local ownerName = UnitName("player")
local ownerShort = ownerName and ownerName:match("^[^%-]+") or ownerName

CatgirlSettingsDB = CatgirlSettingsDB or {}
CatgirlSettingsDB.maidTasksOwners = CatgirlSettingsDB.maidTasksOwners or {}

local maidInstructionText = ""
local maidTicker = nil
local lastSendAt = 0
local maidUpdateSeq = 0

local function IsModuleEnabled()
    return not CCT_IsModuleEnabled or CCT_IsModuleEnabled("MaidTasks")
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

local function GetAssignedCatgirl()
    if not IsInGuild() then
        return nil
    end
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note, officerNote = GetGuildRosterInfo(i)
        if name then
            local source = nil
            if type(officerNote) == "string" and officerNote ~= "" then
                source = officerNote
            elseif type(note) == "string" and note ~= "" then
                source = note
            end
            local noteOwner = source and source:match("owner=([^,]+)") or nil
            if noteOwner and ShortName(noteOwner) and ShortName(noteOwner):lower() == (ownerShort or ""):lower() then
                return name
            end
        end
    end
    return nil
end

local function GetOwnerState()
    CatgirlSettingsDB = CatgirlSettingsDB or {}
    CatgirlSettingsDB.maidTasksOwners = CatgirlSettingsDB.maidTasksOwners or {}
    CatgirlSettingsDB.maidTasksOwners[ownerShort] = CatgirlSettingsDB.maidTasksOwners[ownerShort] or {}
    local state = CatgirlSettingsDB.maidTasksOwners[ownerShort]
    state.items = state.items or {}
    return state
end

local function StripItemLink(text)
    if not text then return nil end
    local bracketName = text:match("%[(.-)%]")
    if bracketName and bracketName ~= "" then
        return bracketName
    end
    return text
end

local function ExtractItemID(text)
    if not text then return nil end
    local idFromLink = text:match("item:(%d+)")
    if idFromLink then
        return tonumber(idFromLink)
    end
    local numeric = tonumber(text)
    if numeric then
        return numeric
    end
    if GetItemInfoInstant then
        local maybeID = select(1, GetItemInfoInstant(text))
        if maybeID then
            return maybeID
        end
    end
    return nil
end

local function ResolveItemName(itemID, fallbackText)
    if itemID and GetItemInfo then
        local name = GetItemInfo(itemID)
        if name and name ~= "" then
            return name
        end
    end
    return fallbackText
end

local function NormalizeItemInput(text)
    if not text then return nil, nil end
    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then return nil, nil end
    local itemID = ExtractItemID(trimmed)
    local fallback = StripItemLink(trimmed)
    local name = ResolveItemName(itemID, fallback)
    if not name or name == "" then
        name = fallback
    end
    if not name or name == "" then
        return nil, nil
    end
    return itemID, name
end

local function ItemMatches(existing, itemID, name)
    if existing.itemID and itemID and existing.itemID == itemID then
        return true
    end
    if existing.displayName and name and existing.displayName:lower() == name:lower() then
        return true
    end
    return false
end

local function GetItemCountSafe(item)
    if not item then return 0 end
    if item.itemID then
        return GetItemCount(item.itemID, true) or 0
    end
    if item.displayName then
        return GetItemCount(item.displayName, true) or 0
    end
    return 0
end

local function Encode(text)
    if text == nil then
        return ""
    end
    local s = tostring(text)
    s = s:gsub("%%", "%%25")
    s = s:gsub(",", "%%2C")
    s = s:gsub(";", "%%3B")
    s = s:gsub("\n", "%%0A")
    s = s:gsub("\r", "")
    return s
end

local function ClampInstruction(text)
    if not text then return "" end
    local cleaned = tostring(text)
    cleaned = cleaned:gsub("[\r\n]+", " ")
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
    local maxLen = 140
    if #cleaned > maxLen then
        cleaned = cleaned:sub(1, maxLen)
    end
    return cleaned
end

local function ShouldThrottle(force)
    if force then return false end
    local now = time()
    if now - lastSendAt < 5 then
        return true
    end
    return false
end

local function NextUpdateId()
    maidUpdateSeq = (maidUpdateSeq + 1) % 1000
    -- Keep the update id within 32-bit integer range to avoid overflow.
    local base = time() % 2000000
    return (base * 1000) + maidUpdateSeq
end

local function SendMaidTasks(force)
    if not IsModuleEnabled() then return end
    if not IsInGuild() then return end
    if ShouldThrottle(force) then return end

    local kitten = GetAssignedCatgirl()
    if not kitten then return end

    local state = GetOwnerState()
    local updateId = NextUpdateId()
    local itemCount = #state.items
    local instruction = ClampInstruction(maidInstructionText)

    local headerMsg = string.format(
        "MaidTasksHeader, id:%d, owner:%s, count:%d, instruction:%s",
        updateId,
        ownerShort or "unknown",
        itemCount,
        Encode(instruction)
    )

    C_ChatInfo.SendAddonMessage(addonPrefix, headerMsg, "WHISPER", kitten)

    for index, item in ipairs(state.items) do
        local count = GetItemCountSafe(item)
        local itemMsg = string.format(
            "MaidTasksItem, id:%d, index:%d, itemID:%s, name:%s, count:%d",
            updateId,
            index,
            item.itemID and tostring(item.itemID) or "nil",
            Encode(item.displayName or ""),
            count
        )
        C_ChatInfo.SendAddonMessage(addonPrefix, itemMsg, "WHISPER", kitten)
    end

    lastSendAt = time()
end

local function StartTicker()
    if maidTicker then return end
    maidTicker = C_Timer.NewTicker(60, function()
        SendMaidTasks(false)
    end)
end

function CCT_MaidTasks_GetOwnerItems()
    return GetOwnerState().items
end

function CCT_MaidTasks_GetOwnerItemCount(item)
    return GetItemCountSafe(item)
end

function CCT_MaidTasks_AddItem(text)
    if not IsModuleEnabled() then
        return false, "Maid Tasks module is disabled."
    end

    local itemID, name = NormalizeItemInput(text)
    if not name then
        return false, "Invalid item."
    end

    local state = GetOwnerState()
    for _, existing in ipairs(state.items) do
        if ItemMatches(existing, itemID, name) then
            return false, "Item already added."
        end
    end

    table.insert(state.items, {
        itemID = itemID,
        displayName = name,
    })

    SendMaidTasks(true)
    return true
end

function CCT_MaidTasks_RemoveItemByIndex(index)
    if not IsModuleEnabled() then return false end
    local state = GetOwnerState()
    if not index or not state.items[index] then
        return false
    end
    table.remove(state.items, index)
    SendMaidTasks(true)
    return true
end

function CCT_MaidTasks_GetInstructionText()
    return maidInstructionText
end

function CCT_MaidTasks_SetInstructionText(text)
    if not IsModuleEnabled() then return false end
    maidInstructionText = ClampInstruction(text)
    SendMaidTasks(true)
    return true
end

function CCT_MaidTasks_SendUpdateNow()
    SendMaidTasks(true)
end

C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if CCT_SetModuleEnabled then
            CCT_SetModuleEnabled("MaidTasks", true)
        end
        GetOwnerState()
        StartTicker()
        C_Timer.After(2.0, function()
            SendMaidTasks(true)
        end)
    end
end)

CCT_AutoPrint("MaidTaskSceduler loaded.")
