local addonPrefix = "CatgirlTracker"
local kittyname = UnitName("player")
local shortName = kittyname and kittyname:match("^[^%-]+") or kittyname

local SOUND_ROOT = "Interface\\AddOns\\CatgirlTracker\\Sounds\\"
local DISCIPLINE_DIR = SOUND_ROOT .. "discipline-sound\\"
local TOY_DIR = SOUND_ROOT .. "discipline-sound\\"

local DISCIPLINE_SOUNDS = {
    spank_hand = DISCIPLINE_DIR .. "spank.wav",
    crop = DISCIPLINE_DIR .. "Crop.wav",
    paddle = DISCIPLINE_DIR .. "Paddle.wav",
    whip = DISCIPLINE_DIR .. "Whip.wav",
    vibrating_wand = function(level)
        return DISCIPLINE_DIR .. "Vibrate" .. tostring(level) .. ".wav"
    end,
    shock_wand = function(level)
        return DISCIPLINE_DIR .. "Shock" .. tostring(level) .. ".wav"
    end,
}

local TOY_VIBE_SOUNDS = {
    [1] = TOY_DIR .. "Vibrate1.wav",
    [2] = TOY_DIR .. "Vibrate2.wav",
    [3] = TOY_DIR .. "Vibrate3.wav",
    [4] = TOY_DIR .. "Vibrate4.wav",
    [5] = TOY_DIR .. "Vibrate5.wav",
}

local TOY_SHOCK_SOUNDS = {
    [1] = TOY_DIR .. "Shock1.wav",
    [2] = TOY_DIR .. "Shock2.wav",
    [3] = TOY_DIR .. "Shock3.wav",
}

local TOY_INFLATE_SOUND = TOY_DIR .. "Inflate.wav"
local TOY_DEFLATE_SOUND = TOY_DIR .. "Deflate.wav"

local TOY_INFLATE_IDS = {
    inflatable_butplug = true,
    inflatable_dildo = true,
    inflatable_gag = true,
}

local VIBE_LOOP_INTERVAL = 2.5
local VIBE_PING_INTERVAL = 3.0
local TOY_OWNER_CLOSE_RANGE = 0.02

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

local ownerCache = nil
local ownerCacheAt = 0
local OWNER_CACHE_SECONDS = 30

local function GetCachedOwner()
    local now = time()
    if ownerCache and (now - ownerCacheAt) < OWNER_CACHE_SECONDS then
        return ownerCache
    end
    ownerCacheAt = now
    ownerCache = GetOwnerFromNote()
    return ownerCache
end

local function OwnerShort(name)
    return name and name:match("^[^%-]+") or name
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
        if not mapID then return nil, nil, nil, instanceID end
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if not pos then return nil, nil, nil, instanceID end
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

local function GetPlayerMapCoords()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return nil, nil, nil end
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if not pos then return nil, nil, nil end
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

local function IsSameInstance(instanceID)
    local myInstanceID = GetInstanceID()
    if not instanceID or not myInstanceID then
        return false
    end
    return instanceID == myInstanceID
end

local function IsOwnerClose(mapID, x, y, instanceID)
    local ownerMapID, ownerX, ownerY = GetPlayerMapCoords()
    if ownerMapID and ownerX and ownerY and mapID and x and y and ownerMapID == mapID then
        local dx = ownerX - x
        local dy = ownerY - y
        local dist = math.sqrt(dx * dx + dy * dy)
        return dist <= TOY_OWNER_CLOSE_RANGE, dist
    end
    if IsSameInstance(instanceID) then
        return true, nil
    end
    return false, nil
end

local function PlaySoundHandle(path)
    if not path then
        return nil
    end
    local a, b = PlaySoundFile(path, "Master")
    if type(a) == "number" then
        return a
    end
    if type(b) == "number" then
        return b
    end
    return nil
end

local function StopSoundHandle(handle)
    if type(handle) == "number" and StopSound then
        StopSound(handle)
    end
end

local function SendAddonToOwner(message)
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end
    local owner = GetCachedOwner()
    if not owner then
        return
    end
    if C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)
    end
    C_ChatInfo.SendAddonMessage(addonPrefix, message, "WHISPER", owner)
end

local function Clamp(value, minValue, maxValue)
    local num = tonumber(value) or minValue
    if num < minValue then
        num = minValue
    elseif num > maxValue then
        num = maxValue
    end
    return math.floor(num + 0.5)
end

local function GetDisciplineSound(actionId, strength)
    local entry = DISCIPLINE_SOUNDS[actionId]
    if not entry then
        return nil
    end
    if type(entry) == "function" then
        if actionId == "vibrating_wand" then
            return entry(Clamp(strength, 1, 3))
        end
        if actionId == "shock_wand" then
            return entry(Clamp(strength, 1, 5))
        end
        return entry(Clamp(strength, 1, 5))
    end
    return entry
end

local function PlayDisciplineLocal(actionId, strength)
    local sound = GetDisciplineSound(actionId, strength)
    PlaySoundHandle(sound)
end

local function SendDisciplineToOwner(actionId, strength)
    local owner = GetCachedOwner()
    if not owner then
        return
    end
    local ownerShort = OwnerShort(owner)
    local msg = string.format(
        "DiscSound, owner:%s, action:%s, strength:%s",
        tostring(ownerShort or ""),
        tostring(actionId or ""),
        tostring(strength or 1)
    )
    SendAddonToOwner(msg)
end

local toyVibeLevels = {}
local localVibeLevel = 0
local localVibeHandle = nil
local localVibeTicker = nil
local vibePingTicker = nil
local vibePingLevel = 0

local function PlayLocalVibeSound()
    if localVibeLevel <= 0 then
        return
    end
    local sound = TOY_VIBE_SOUNDS[localVibeLevel]
    StopSoundHandle(localVibeHandle)
    localVibeHandle = PlaySoundHandle(sound)
end

local function StopLocalVibeLoop()
    if localVibeTicker then
        localVibeTicker:Cancel()
        localVibeTicker = nil
    end
    StopSoundHandle(localVibeHandle)
    localVibeHandle = nil
end

local function SendToyVibeMessage(kind, level)
    local owner = GetCachedOwner()
    if not owner then
        return
    end
    local ownerShort = OwnerShort(owner)
    local mapID, x, y, instanceID = GetMapPosition()
    local msg = string.format(
        "ToyVibeLoop%s, owner:%s, level:%s, mapID:%s, x:%s, y:%s, instanceID:%s",
        tostring(kind),
        tostring(ownerShort or ""),
        tostring(level or 0),
        tostring(mapID or "nil"),
        tostring(x or "nil"),
        tostring(y or "nil"),
        tostring(instanceID or "nil")
    )
    SendAddonToOwner(msg)
end

local function StopVibePing()
    vibePingLevel = 0
    if vibePingTicker then
        vibePingTicker:Cancel()
        vibePingTicker = nil
    end
end

local function StartVibePing(level)
    vibePingLevel = level
    if vibePingTicker then
        return
    end
    vibePingTicker = C_Timer.NewTicker(VIBE_PING_INTERVAL, function()
        if vibePingLevel <= 0 then
            StopVibePing()
            return
        end
        SendToyVibeMessage("Ping", vibePingLevel)
    end)
end

local function UpdateLocalVibeLoop(level)
    if level <= 0 then
        localVibeLevel = 0
        StopLocalVibeLoop()
        StopVibePing()
        SendToyVibeMessage("Stop", 0)
        return
    end

    localVibeLevel = level
    PlayLocalVibeSound()
    if not localVibeTicker then
        localVibeTicker = C_Timer.NewTicker(VIBE_LOOP_INTERVAL, function()
            if localVibeLevel <= 0 then
                StopLocalVibeLoop()
                return
            end
            PlayLocalVibeSound()
        end)
    end
    SendToyVibeMessage("Start", localVibeLevel)
    SendToyVibeMessage("Ping", localVibeLevel)
    StartVibePing(localVibeLevel)
end

local function RecomputeLocalVibeLevel()
    local maxLevel = 0
    for _, level in pairs(toyVibeLevels) do
        if level and level > maxLevel then
            maxLevel = level
        end
    end
    if maxLevel == localVibeLevel then
        return
    end
    UpdateLocalVibeLoop(maxLevel)
end

local remoteVibeLevel = 0
local remoteVibeHandle = nil
local remoteVibeTicker = nil

local function PlayRemoteVibeSound()
    if remoteVibeLevel <= 0 then
        return
    end
    local sound = TOY_VIBE_SOUNDS[remoteVibeLevel]
    StopSoundHandle(remoteVibeHandle)
    remoteVibeHandle = PlaySoundHandle(sound)
end

local function StopRemoteVibeLoop()
    if remoteVibeTicker then
        remoteVibeTicker:Cancel()
        remoteVibeTicker = nil
    end
    StopSoundHandle(remoteVibeHandle)
    remoteVibeHandle = nil
end

local function StartRemoteVibeLoop(level)
    if level <= 0 then
        remoteVibeLevel = 0
        StopRemoteVibeLoop()
        return
    end
    remoteVibeLevel = level
    PlayRemoteVibeSound()
    if not remoteVibeTicker then
        remoteVibeTicker = C_Timer.NewTicker(VIBE_LOOP_INTERVAL, function()
            if remoteVibeLevel <= 0 then
                StopRemoteVibeLoop()
                return
            end
            PlayRemoteVibeSound()
        end)
    end
end

local function SendToyInflateMessage(action)
    local owner = GetCachedOwner()
    if not owner then
        return
    end
    local ownerShort = OwnerShort(owner)
    local mapID, x, y, instanceID = GetMapPosition()
    local msg = string.format(
        "ToyInflateSound, owner:%s, action:%s, mapID:%s, x:%s, y:%s, instanceID:%s",
        tostring(ownerShort or ""),
        tostring(action or ""),
        tostring(mapID or "nil"),
        tostring(x or "nil"),
        tostring(y or "nil"),
        tostring(instanceID or "nil")
    )
    SendAddonToOwner(msg)
end

local function SendToyShockMessage(level)
    local owner = GetCachedOwner()
    if not owner then
        return
    end
    local ownerShort = OwnerShort(owner)
    local mapID, x, y, instanceID = GetMapPosition()
    local msg = string.format(
        "ToyShockSound, owner:%s, level:%s, mapID:%s, x:%s, y:%s, instanceID:%s",
        tostring(ownerShort or ""),
        tostring(level or 1),
        tostring(mapID or "nil"),
        tostring(x or "nil"),
        tostring(y or "nil"),
        tostring(instanceID or "nil")
    )
    SendAddonToOwner(msg)
end

local function PlayToyShockLocal(level)
    local stage = Clamp(level, 1, 3)
    local sound = TOY_SHOCK_SOUNDS[stage]
    PlaySoundHandle(sound)
end

local function PlayToyInflateLocal(action)
    if action == "inflate" then
        PlaySoundHandle(TOY_INFLATE_SOUND)
    elseif action == "deflate" then
        PlaySoundHandle(TOY_DEFLATE_SOUND)
    end
end

local engine = {}

function engine.PlayDisciplineAction(actionId, strength)
    PlayDisciplineLocal(actionId, strength)
    SendDisciplineToOwner(actionId, strength)
end

function engine.SetToyVibeState(toyId, level)
    if not toyId then
        return
    end
    toyVibeLevels[toyId] = tonumber(level) or 0
    RecomputeLocalVibeLevel()
end

function engine.SyncToyVibes(states)
    if type(states) ~= "table" then
        return
    end
    for id, state in pairs(states) do
        local level = 0
        if state and tonumber(state.vibe) then
            level = tonumber(state.vibe) or 0
        end
        toyVibeLevels[id] = level
    end
    RecomputeLocalVibeLevel()
end

function engine.PlayToyShock(level)
    PlayToyShockLocal(level)
    SendToyShockMessage(Clamp(level, 1, 3))
end

function engine.PlayToyInflateDeflate(sourceId, action)
    if not TOY_INFLATE_IDS[sourceId] then
        return
    end
    if action ~= "inflate" and action ~= "deflate" then
        return
    end
    PlayToyInflateLocal(action)
    SendToyInflateMessage(action)
end

local function ParseNumber(value)
    if not value or value == "nil" then
        return nil
    end
    return tonumber(value)
end

local function IsMessageForMe(ownerShort)
    if not ownerShort or not shortName then
        return false
    end
    return ownerShort:lower() == shortName:lower()
end

local function HandleDiscSound(msg)
    local owner, action, strength = msg:match("^DiscSound, owner:([^,]+), action:([^,]+), strength:([^,]+)")
    if not owner then
        return false
    end
    if not IsMessageForMe(owner:match("^[^%-]+")) then
        return true
    end
    PlayDisciplineLocal(action, tonumber(strength) or 1)
    return true
end

local function HandleToyInflateSound(msg)
    local owner, action, mapID, x, y, instanceID = msg:match(
        "^ToyInflateSound, owner:([^,]+), action:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)"
    )
    if not owner then
        owner, action, mapID, x, y = msg:match(
            "^ToyInflateSound, owner:([^,]+), action:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+)"
        )
    end
    if not owner then
        return false
    end
    if not IsMessageForMe(owner:match("^[^%-]+")) then
        return true
    end
    local close = IsOwnerClose(ParseNumber(mapID), ParseNumber(x), ParseNumber(y), ParseNumber(instanceID))
    if close then
        PlayToyInflateLocal(action)
    end
    return true
end

local function HandleToyShockSound(msg)
    local owner, level, mapID, x, y, instanceID = msg:match(
        "^ToyShockSound, owner:([^,]+), level:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)"
    )
    if not owner then
        owner, level, mapID, x, y = msg:match(
            "^ToyShockSound, owner:([^,]+), level:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+)"
        )
    end
    if not owner then
        return false
    end
    if not IsMessageForMe(owner:match("^[^%-]+")) then
        return true
    end
    local close = IsOwnerClose(ParseNumber(mapID), ParseNumber(x), ParseNumber(y), ParseNumber(instanceID))
    if close then
        PlayToyShockLocal(tonumber(level) or 1)
    end
    return true
end

local function HandleToyVibeLoop(msg)
    local action, owner, level, mapID, x, y, instanceID = msg:match(
        "^ToyVibeLoop(%a+), owner:([^,]+), level:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)"
    )
    if not owner then
        action, owner, level, mapID, x, y = msg:match(
            "^ToyVibeLoop(%a+), owner:([^,]+), level:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+)"
        )
    end
    if not owner then
        return false
    end
    if not IsMessageForMe(owner:match("^[^%-]+")) then
        return true
    end
    if action == "Stop" then
        remoteVibeLevel = 0
        StopRemoteVibeLoop()
        return true
    end
    local stage = Clamp(level, 1, 5)
    local close = IsOwnerClose(ParseNumber(mapID), ParseNumber(x), ParseNumber(y), ParseNumber(instanceID))
    if close then
        StartRemoteVibeLoop(stage)
    else
        remoteVibeLevel = 0
        StopRemoteVibeLoop()
    end
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)
        end
        return
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, msg = ...
        if prefix ~= addonPrefix or not msg or msg == "" then
            return
        end
        if HandleDiscSound(msg) then
            return
        end
        if HandleToyInflateSound(msg) then
            return
        end
        if HandleToyShockSound(msg) then
            return
        end
        if HandleToyVibeLoop(msg) then
            return
        end
    end
end)

_G.CCT_ToyDisciplineSoundEngine = engine

