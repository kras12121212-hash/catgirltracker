local kittyname = UnitName("player")
local shortName = kittyname and kittyname:match("^[^%-]+") or kittyname
local addonPrefix = "CatgirlTracker"
local DISCIPLINE_CLOSE_RANGE = 0.02

local DISCIPLINE_ACTIONS = {
    {
        id = "spank_hand",
        label = "Spank Hand",
        icon = "Textures/Hand.tga",
        msgKey = "SPANK_HAND",
        maxStrength = 5,
        parts = {
            { id = "butt", label = "Butt" },
            { id = "thighs", label = "Thighs" },
        },
    },
    {
        id = "pinch",
        label = "Pinch",
        icon = "Textures/Hand.tga",
        msgKey = "PINCH",
        maxStrength = 3,
        parts = {
            { id = "ears", label = "Ears" },
            { id = "nipples", label = "Nipples", restrict = "bra" },
        },
    },
    {
        id = "vibrating_wand",
        label = "Vibrating Wand",
        icon = "Textures/VibratingWand.tga",
        msgKey = "VIBRATING_WAND",
        maxStrength = 3,
        parts = {
            { id = "tits", label = "Tits", restrict = "bra" },
            { id = "pussy", label = "Pussy", restrict = "belt" },
            { id = "ears", label = "Ears" },
        },
    },
    {
        id = "shock_wand",
        label = "Shock Wand",
        icon = "Textures/ShockWand.tga",
        msgKey = "SHOCK_WAND",
        maxStrength = 5,
        parts = {
            { id = "thighs", label = "Thighs" },
            { id = "paws", label = "Paws" },
            { id = "pussy", label = "Pussy", restrict = "belt" },
            { id = "belly", label = "Belly" },
            { id = "tits", label = "Tits", restrict = "bra" },
            { id = "nipples", label = "Nipples", restrict = "bra" },
            { id = "neck", label = "Neck" },
            { id = "ass", label = "Ass", restrict = "belt" },
        },
    },
    {
        id = "crop",
        label = "Crop",
        icon = "Textures/Crop.tga",
        msgKey = "CROP",
        maxStrength = 3,
        parts = {
            { id = "butt", label = "Butt" },
            { id = "thighs", label = "Thighs" },
        },
    },
    {
        id = "paddle",
        label = "Paddle",
        icon = "Textures/Paddle.tga",
        msgKey = "PADDLE",
        maxStrength = 3,
        parts = {
            { id = "butt", label = "Butt" },
            { id = "thighs", label = "Thighs" },
            { id = "tits", label = "Tits", restrict = "bra" },
            { id = "paws", label = "Paws" },
        },
    },
    {
        id = "heart_crop",
        label = "Heart Crop",
        icon = "Textures/HeartCrop.tga",
        msgKey = "HEART_CROP",
        maxStrength = 3,
        parts = {
            { id = "butt", label = "Butt" },
            { id = "thighs", label = "Thighs" },
            { id = "tits", label = "Tits", restrict = "bra" },
            { id = "paws", label = "Paws" },
        },
    },
    {
        id = "whip",
        label = "Whip",
        icon = "Textures/Whip.tga",
        msgKey = "WHIP",
        maxStrength = 3,
        parts = {
            { id = "butt", label = "Butt" },
            { id = "thighs", label = "Thighs" },
            { id = "tits", label = "Tits", restrict = "bra" },
            { id = "paws", label = "Paws" },
        },
    },
}

local disciplineIndex = {}

for _, action in ipairs(DISCIPLINE_ACTIONS) do
    disciplineIndex[action.id] = action
    action.partsIndex = {}
    for _, part in ipairs(action.parts or {}) do
        action.partsIndex[part.id] = part
    end
end

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

local function IsOwnerSender(sender)
    local owner = GetOwnerFromNote()
    if not owner or not sender then
        return false
    end
    local shortSender = sender:match("^[^%-]+")
    return shortSender and shortSender:lower() == owner:lower()
end

local function FindLastEvent(log, eventName)
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == eventName then
            return entry
        end
    end
end

local function Round(value, places)
    if not value then return nil end
    local pow = 10 ^ (places or 4)
    return math.floor(value * pow + 0.5) / pow
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

local function GetMapPosition()
    local instanceID = GetInstanceID()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then
            return nil, nil, nil, instanceID
        end
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if not pos then
            return nil, nil, nil, instanceID
        end
        local x, y = pos.x, pos.y
        if pos.GetXY then
            x, y = pos:GetXY()
        end
        if x and y then
            return mapID, Round(x, 4), Round(y, 4), instanceID
        end
    end
    if GetPlayerMapPosition then
        local x, y = GetPlayerMapPosition("player")
        if x and y then
            return nil, Round(x, 4), Round(y, 4), instanceID
        end
    end
    return nil, nil, nil, instanceID
end

local function IsChastityBeltLocked()
    local log = GetBehaviorLog()
    local entry = FindLastEvent(log, "ChastityBelt")
    return entry and entry.state == true
end

local function IsChastityBraLocked()
    local log = GetBehaviorLog()
    local entry = FindLastEvent(log, "ChastityBra")
    return entry and entry.state == true
end

local function SendOwnerMessage(sender, key, ...)
    if not sender then
        return
    end
    SendChatMessage(CCT_Msg(key, ...), "WHISPER", nil, sender)
end

local function SendOwnerMessageWithFallback(sender, key, fallbackKey, ...)
    if not sender then
        return
    end
    local useKey = key
    if not (CCT_Messages and CCT_Messages[key]) and fallbackKey then
        useKey = fallbackKey
    end
    SendChatMessage(CCT_Msg(useKey, ...), "WHISPER", nil, sender)
end

local function SendOwnerWarning(sender)
    if not sender then
        return
    end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        if C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)
        end
        C_ChatInfo.SendAddonMessage(addonPrefix, "ccdiscwarn", "WHISPER", sender)
        return
    end
    SendOwnerMessage(sender, "DISCIPLINE_TOO_FAR")
end

local function ParseNumber(value)
    if not value or value == "nil" then
        return nil
    end
    return tonumber(value)
end

local function IsOwnerClose(ownerMapID, ownerX, ownerY, ownerInstanceID)
    local mapID, x, y, instanceID = GetMapPosition()
    if mapID and x and y and ownerMapID and ownerX and ownerY and mapID == ownerMapID then
        local dx = x - ownerX
        local dy = y - ownerY
        local dist = math.sqrt(dx * dx + dy * dy)
        return dist <= DISCIPLINE_CLOSE_RANGE, dist
    end
    if ownerInstanceID and instanceID and ownerInstanceID == instanceID then
        return true, nil
    end
    return false, nil
end

local function ClampStrength(level, maxStrength)
    local num = tonumber(level) or 0
    if num < 1 then
        num = 1
    elseif num > maxStrength then
        num = maxStrength
    end
    return math.floor(num + 0.5)
end

local function GetDisciplineHeat(actionId, strength)
    local cfg = CCT_HeatConfig
    local actionCfg = cfg and cfg.discipline and cfg.discipline[actionId]
    if not actionCfg then
        return 0
    end
    local heatTable = actionCfg.heat or actionCfg
    local value = heatTable[strength]
    if type(value) == "table" then
        value = value.heat
    end
    return tonumber(value) or 0
end

local function ApplyDisciplineHeat(actionId, strength)
    local delta = GetDisciplineHeat(actionId, strength)
    if delta == 0 then
        return
    end
    if CCT_AddHeatDelta then
        CCT_AddHeatDelta(delta)
    end
end

local function CanUseDisciplinePart(part)
    if not part then
        return false
    end
    if part.restrict == "belt" and IsChastityBeltLocked() then
        return false, "belt"
    end
    if part.restrict == "bra" and IsChastityBraLocked() then
        return false, "bra"
    end
    return true
end

local function GetActionMessageKey(action, strength)
    local base = action.msgKey or action.id or ""
    return "DISCIPLINE_" .. base .. "_" .. tostring(strength)
end

local function GetBlockedMessageKey(action, kind)
    local base = action.msgKey or action.id or ""
    return "DISCIPLINE_" .. base .. "_BLOCKED_" .. kind
end

local function ApplyDiscipline(action, part, strength, sender)
    if not action or not part then
        return
    end
    local ok, blockedBy = CanUseDisciplinePart(part)
    if not ok then
        if sender then
            if blockedBy == "belt" then
                SendOwnerMessageWithFallback(sender, GetBlockedMessageKey(action, "BELT"), "DISCIPLINE_BLOCKED_BELT", action.label, part.label)
            elseif blockedBy == "bra" then
                SendOwnerMessageWithFallback(sender, GetBlockedMessageKey(action, "BRA"), "DISCIPLINE_BLOCKED_BRA", action.label, part.label)
            end
        end
        return
    end

    local stage = ClampStrength(strength, action.maxStrength or 1)
    ApplyDisciplineHeat(action.id, stage)

    if sender then
        local key = GetActionMessageKey(action, stage)
        SendOwnerMessageWithFallback(sender, key, "DISCIPLINE_ACTION", action.label, part.label, stage)
    end

    if CCT_ShowDisciplineIcon then
        CCT_ShowDisciplineIcon(action.icon)
    end
end

local function HandleDisciplineCommand(msg, sender)
    local cmd, actionId, partId, strength, mapID, x, y, instanceID =
        msg:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*(%S*)")
    if not cmd then
        cmd, actionId, partId, strength = msg:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
    end
    if cmd ~= "ccdisc" then
        return false
    end
    local action = disciplineIndex[actionId]
    if not action then
        return true
    end
    local part = action.partsIndex and action.partsIndex[partId]
    if not part then
        return true
    end
    local ownerMapID = ParseNumber(mapID)
    local ownerX = ParseNumber(x)
    local ownerY = ParseNumber(y)
    local ownerInstanceID = ParseNumber(instanceID)
    local close = IsOwnerClose(ownerMapID, ownerX, ownerY, ownerInstanceID)
    if not close then
        SendOwnerWarning(sender)
        return true
    end
    ApplyDiscipline(action, part, tonumber(strength) or 1, sender)
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)
        end
        return
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = ...
        if prefix ~= addonPrefix then
            return
        end
        if channel ~= "WHISPER" then
            return
        end
        if not IsOwnerSender(sender) then
            return
        end
        local text = msg and msg:lower() or ""
        if text == "" then
            return
        end
        HandleDisciplineCommand(text, sender)
        return
    end

    if event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        if not IsOwnerSender(sender) then
            return
        end
        local text = msg and msg:lower() or ""
        if text == "" then
            return
        end
        HandleDisciplineCommand(text, sender)
    end
end)

AutoPrint("Discipline module loaded.")
