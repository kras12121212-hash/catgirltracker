local kittyname = UnitName("player")
local shortName = kittyname and kittyname:match("^[^%-]+") or kittyname
local addonPrefix = "CatgirlTracker"

local TOYS = {
    {
        id = "dildo",
        label = "Dildo",
        icon = "Textures/Dildo.tga",
        msgKey = "DILDO",
        vibe = true,
        shock = true,
        restrict = "belt",
    },
    {
        id = "inflatable_butplug",
        label = "Inflatable Butplug",
        icon = "Textures/InflatableButplug.tga",
        msgKey = "INFLATABLE_BUTPLUG",
        inflate = true,
        group = "butplug",
        restrict = "belt",
    },
    {
        id = "inflatable_dildo",
        label = "Inflatable Dildo",
        icon = "Textures/InflatableDildo.tga",
        msgKey = "INFLATABLE_DILDO",
        inflate = true,
        restrict = "belt",
    },
    {
        id = "small_butplug",
        label = "Small Butplug",
        icon = "Textures/SmallButplug.tga",
        msgKey = "SMALL_BUTPLUG",
        group = "butplug",
        restrict = "belt",
    },
    {
        id = "large_butplug",
        label = "Large Butplug",
        icon = "Textures/LargeButplug.tga",
        msgKey = "LARGE_BUTPLUG",
        group = "butplug",
        restrict = "belt",
    },
    {
        id = "taill_butplug",
        label = "Taill Butplug",
        icon = "Textures/TaillButplug.tga",
        msgKey = "TAILL_BUTPLUG",
        group = "butplug",
        restrict = "belt",
    },
    {
        id = "vibes_pussy",
        label = "Vibes Pussy",
        icon = "Textures/Vibes.tga",
        msgKey = "VIBES_PUSSY",
        vibe = true,
        restrict = "belt",
    },
    {
        id = "vibes_nipples",
        label = "Vibes Nipples",
        icon = "Textures/Vibes.tga",
        msgKey = "VIBES_NIPPLES",
        vibe = true,
        restrict = "bra",
    },
    {
        id = "vibes_ears",
        label = "Vibes Ears",
        icon = "Textures/Vibes.tga",
        msgKey = "VIBES_EARS",
        vibe = true,
        shock = true,
    },
    {
        id = "nipple_piercings",
        label = "Nipple Piercings",
        icon = "Textures/Piercings.tga",
        msgKey = "NIPPLE_PIERCINGS",
        vibe = true,
        shock = true,
        restrict = "bra",
    },
    {
        id = "ear_piercings",
        label = "Ear Piercings",
        icon = "Textures/Piercings.tga",
        msgKey = "EAR_PIERCINGS",
        vibe = true,
        shock = true,
    },
    {
        id = "pussy_lipps_piercings",
        label = "Pussy Lipps Piercings",
        icon = "Textures/Piercings.tga",
        msgKey = "PUSSY_LIPPS_PIERCINGS",
        vibe = true,
        shock = true,
        restrict = "belt",
    },
}

local toyIndex = {}
local toyStates = {}
local toyEventMap = {}

local function ToyEventName(id)
    return "Toy_" .. id
end

local function ToyVibeEventName(id)
    return "Toy_" .. id .. "_Vibe"
end

local function ToyInflateEventName(id)
    return "Toy_" .. id .. "_Inflate"
end

local function ToyShockEventName(id)
    return "Toy_" .. id .. "_Shock"
end

for _, toy in ipairs(TOYS) do
    toyIndex[toy.id] = toy
    toyStates[toy.id] = { applied = false, vibe = 0, inflate = 0 }
    toyEventMap[ToyEventName(toy.id)] = { id = toy.id, kind = "applied" }
    if toy.vibe then
        toyEventMap[ToyVibeEventName(toy.id)] = { id = toy.id, kind = "vibe" }
    end
    if toy.inflate then
        toyEventMap[ToyInflateEventName(toy.id)] = { id = toy.id, kind = "inflate" }
    end
    if toy.shock then
        toyEventMap[ToyShockEventName(toy.id)] = { id = toy.id, kind = "shock" }
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

local function LogEvent(eventName, state)
    table.insert(GetBehaviorLog(), {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = eventName,
        state = state,
        synced = 0,
    })
end

local function FindLastEvent(log, eventName)
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == eventName then
            return entry
        end
    end
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

local function GetToyMessageKey(toy, suffix)
    local base = toy.msgKey or toy.id or ""
    return "TOY_" .. base .. "_" .. suffix
end

local function NotifyToyLocal(message)
    AutoPrint("|cffcc88ffCatgirlTracker:|r " .. message)
    if CCT_RaidNotice then
        CCT_RaidNotice(message)
    end
end

local function ClampStage(level, maxStage, allowZero)
    local num = tonumber(level) or 0
    if allowZero and num <= 0 then
        return 0
    end
    if num < 1 then
        num = 1
    elseif num > maxStage then
        num = maxStage
    end
    return math.floor(num + 0.5)
end

local function GetShockHeat(toyId, level)
    local cfg = CCT_HeatConfig
    local toyCfg = cfg and cfg.toys and cfg.toys[toyId]
    local shockCfg = toyCfg and toyCfg.shock
    if not shockCfg then
        return 0
    end
    local value = shockCfg[level]
    if type(value) == "table" then
        value = value.heat
    end
    return tonumber(value) or 0
end

local function ApplyShockHeat(toyId, level)
    local delta = GetShockHeat(toyId, level)
    if delta == 0 then
        return
    end
    if CCT_AddHeatDelta then
        CCT_AddHeatDelta(delta)
    end
end

local function CanChangeToy(toy)
    if toy.restrict == "belt" and IsChastityBeltLocked() then
        return false, "TOY_BLOCKED_BELT"
    end
    if toy.restrict == "bra" and IsChastityBraLocked() then
        return false, "TOY_BLOCKED_BRA"
    end
    return true
end

local function SetToyApplied(toy, applied, sender)
    local state = toyStates[toy.id]
    if not state then
        return
    end
    if applied == state.applied then
        return
    end
    if (applied == true or applied == false) and sender then
        local ok, reason = CanChangeToy(toy)
        if not ok then
            SendOwnerMessage(sender, reason, toy.label)
            return
        end
    end
    if applied == true and toy.group == "butplug" then
        for _, other in ipairs(TOYS) do
            if other.id ~= toy.id and other.group == "butplug" then
                SetToyApplied(other, false, nil)
            end
        end
    end
    state.applied = applied and true or false
    LogEvent(ToyEventName(toy.id), state.applied)
    if state.applied and toy.inflate and state.inflate < 1 then
        state.inflate = 1
        LogEvent(ToyInflateEventName(toy.id), state.inflate)
    end
    if not state.applied then
        if toy.vibe then
            state.vibe = 0
            LogEvent(ToyVibeEventName(toy.id), 0)
        end
        if toy.inflate then
            state.inflate = 0
            LogEvent(ToyInflateEventName(toy.id), 0)
        end
    end
    if sender then
        local key = state.applied and GetToyMessageKey(toy, "APPLY") or GetToyMessageKey(toy, "REMOVE")
        local fallback = state.applied and "TOY_APPLY" or "TOY_REMOVE"
        SendOwnerMessageWithFallback(sender, key, fallback, toy.label)
    end
    if state.applied then
        NotifyToyLocal("Toy applied: " .. toy.label .. ".")
    else
        NotifyToyLocal("Toy removed: " .. toy.label .. ".")
    end
end

local function EnsureToyApplied(toy, sender)
    if toyStates[toy.id] and toyStates[toy.id].applied then
        return true
    end
    if sender then
        SendOwnerMessage(sender, "TOY_NOT_APPLIED", toy.label)
    end
    return false
end

local function SetToyVibe(toy, level, sender)
    if not toy.vibe then
        return
    end
    if not EnsureToyApplied(toy, sender) then
        return
    end
    local stage = ClampStage(level, 5, false)
    local state = toyStates[toy.id]
    if state.vibe == stage then
        return
    end
    state.vibe = stage
    LogEvent(ToyVibeEventName(toy.id), stage)
    if sender then
        local key = GetToyMessageKey(toy, "VIBE_" .. stage)
        SendOwnerMessageWithFallback(sender, key, "TOY_VIBE_SET", toy.label, stage)
    end
    NotifyToyLocal(string.format("%s vibration set to %d.", toy.label, stage))
end

local function SetToyInflateStage(toy, stage, sender, key)
    if not toy.inflate then
        return
    end
    if not EnsureToyApplied(toy, sender) then
        return
    end
    local clamped = ClampStage(stage, 5, false)
    local state = toyStates[toy.id]
    if state.inflate == clamped then
        return
    end
    state.inflate = clamped
    LogEvent(ToyInflateEventName(toy.id), clamped)
    if sender then
        local suffix = (key == "TOY_DEFLATE_SET") and ("DEFLATE_" .. clamped) or ("INFLATE_" .. clamped)
        local msgKey = GetToyMessageKey(toy, suffix)
        SendOwnerMessageWithFallback(sender, msgKey, key, toy.label, clamped)
    end
    NotifyToyLocal(string.format("%s inflation stage %d.", toy.label, clamped))
end

local function InflateToy(toy, sender)
    local state = toyStates[toy.id]
    if not state then
        return
    end
    if not EnsureToyApplied(toy, sender) then
        return
    end
    local nextStage = ClampStage(state.inflate + 1, 5, false)
    SetToyInflateStage(toy, nextStage, sender, "TOY_INFLATE_SET")
end

local function DeflateToy(toy, sender)
    local state = toyStates[toy.id]
    if not state then
        return
    end
    if not EnsureToyApplied(toy, sender) then
        return
    end
    local nextStage = ClampStage(state.inflate - 1, 5, false)
    SetToyInflateStage(toy, nextStage, sender, "TOY_DEFLATE_SET")
end

local function ShockToy(toy, level, sender)
    if not toy.shock then
        return
    end
    if not EnsureToyApplied(toy, sender) then
        return
    end
    local stage = ClampStage(level, 3, false)
    LogEvent(ToyShockEventName(toy.id), stage)
    ApplyShockHeat(toy.id, stage)
    if sender then
        local key = GetToyMessageKey(toy, "SHOCK_" .. stage)
        SendOwnerMessageWithFallback(sender, key, "TOY_SHOCK", toy.label, stage)
    end
    NotifyToyLocal(string.format("%s shock intensity %d.", toy.label, stage))
end

local function RestoreToyStates()
    local log = GetBehaviorLog()
    local pending = {}
    local pendingCount = 0

    for _, toy in ipairs(TOYS) do
        local applyEvent = ToyEventName(toy.id)
        pending[applyEvent] = true
        pendingCount = pendingCount + 1
        if toy.vibe then
            pending[ToyVibeEventName(toy.id)] = true
            pendingCount = pendingCount + 1
        end
        if toy.inflate then
            pending[ToyInflateEventName(toy.id)] = true
            pendingCount = pendingCount + 1
        end
    end

    for i = #log, 1, -1 do
        local entry = log[i]
        local info = entry and entry.event and toyEventMap[entry.event]
        if info and pending[entry.event] then
            local state = toyStates[info.id]
            if state then
                if info.kind == "applied" then
                    state.applied = entry.state == true
                elseif info.kind == "vibe" then
                    state.vibe = tonumber(entry.state) or 0
                elseif info.kind == "inflate" then
                    state.inflate = tonumber(entry.state) or 0
                end
            end
            pending[entry.event] = nil
            pendingCount = pendingCount - 1
            if pendingCount <= 0 then
                break
            end
        end
    end
end

local function HandleToyCommand(msg, sender)
    local cmd, toyId, action, arg = msg:match("^(%S+)%s+(%S+)%s+(%S+)%s*(%S*)")
    if cmd ~= "cctoy" then
        return false
    end
    local toy = toyIndex[toyId]
    if not toy then
        return true
    end
    if action == "apply" then
        SetToyApplied(toy, true, sender)
    elseif action == "remove" then
        SetToyApplied(toy, false, sender)
    elseif action == "vibe" then
        SetToyVibe(toy, tonumber(arg) or 0, sender)
    elseif action == "shock" then
        ShockToy(toy, tonumber(arg) or 0, sender)
    elseif action == "inflate" then
        InflateToy(toy, sender)
    elseif action == "deflate" then
        DeflateToy(toy, sender)
    end
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        RestoreToyStates()
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
        HandleToyCommand(text, sender)
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
        HandleToyCommand(text, sender)
    end
end)

AutoPrint("Toys module loaded.")
