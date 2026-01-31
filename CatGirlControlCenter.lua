local addonName = "CatGirlControlCenter"
local f = CreateFrame("Frame")
local kittyname = UnitName("player"):match("^[^%-]+") -- short name only
local controlOpenButton = nil
local addonPrefix = "CatgirlTracker"

SLASH_CGCC1 = "/cgcc"

local function RequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

-- Find who you're the owner of (based on officer note format: owner=Holykitten,...)
local function GetAssignedCatgirl()
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, officerNote = GetGuildRosterInfo(i)
        if name and officerNote then
            local ownerName = officerNote:match("owner=([^,]+)")
            if ownerName and ownerName:match("^[^%-]+") == kittyname then
                return name
            end
        end
    end
    return nil
end

-- Whisper to kitten
local function WhisperToKitten(kitten, command)
    if kitten then
        SendChatMessage(command, "WHISPER", nil, kitten)
    end
end

local function SendAddonToKitten(kitten, command)
    if not kitten then
        return
    end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        if C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)
        end
        C_ChatInfo.SendAddonMessage(addonPrefix, command, "WHISPER", kitten)
        return
    end
    WhisperToKitten(kitten, command)
end

local function ShortName(name)
    if not name then return name end
    return name:match("^[^%-]+")
end

local function FormatKittenLabel(kitten)
    if kitten and kitten ~= "" then
        return "Kitten: " .. kitten
    end
    return "Kitten: None assigned"
end

local function FindLastEvent(log, eventName)
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == eventName then
            return entry
        end
    end
end

local function FormatGagState(state)
    if not state then return "Unknown" end
    if type(state) == "string" then
        local stage = state:match("^Inflatable:(%d+)")
        if stage then
            return string.format("Inflatable gag (stage %s)", stage)
        end
        if state == "Inflatable" then
            return "Inflatable gag"
        end
    end
    local map = {
        Gag = "Heavy gag",
        LightGag = "Small gag",
        FullBlock = "Full mask gag",
        NyaMask = "Cute Nya mask",
        none = "None",
        UnGag = "None",
    }
    return map[state] or tostring(state)
end

local function FormatBlindfoldState(state)
    if not state then return "Unknown" end
    local map = {
        light = "Light",
        full = "Full",
        mask = "Kitty mask",
        remove = "None",
        none = "None",
    }
    return map[state] or tostring(state)
end

local function FormatEarmuffState(state)
    if not state then return "Unknown" end
    local map = {
        KittenEarmuffs = "Kitten earmuffs",
        HeavyEarmuffs = "Heavy earmuffs",
        none = "None",
    }
    return map[state] or tostring(state)
end

local function FormatMittensState(state)
    if not state then return "Unknown" end
    local map = {
        locked = "Locked",
        squeaking = "Squeaking",
        squeking = "Squeaking",
        heavy = "Locked",
        removed = "None",
        none = "None",
    }
    return map[state] or tostring(state)
end

local function FormatHeelsState(state)
    if not state then return "Unknown" end
    local map = {
        maid = "Locking Maid Heels 3-CM",
        high = "Locking High Heels 8-CM",
        ballet = "Locking Ballet Boot 12-CM",
        removed = "None",
        none = "None",
    }
    return map[state] or tostring(state)
end

local function FormatSkillLevel(level)
    if not level then return "Unknown" end
    return "Level " .. tostring(level)
end

local function GetHeelsSkillLevels(log)
    local levels = { maid = nil, high = nil, ballet = nil }
    if log and type(log.HeelsSkillLevels) == "table" then
        levels.maid = log.HeelsSkillLevels.maid
        levels.high = log.HeelsSkillLevels.high
        levels.ballet = log.HeelsSkillLevels.ballet
    end
    if not (levels.maid and levels.high and levels.ballet) then
        for i = #log, 1, -1 do
            local entry = log[i]
            if entry and entry.event == "HeelsSkill" and type(entry.state) == "string" then
                local kind, lvl = entry.state:match("^(%a+):(%d+)$")
                if kind and lvl and levels[kind] == nil then
                    levels[kind] = tonumber(lvl)
                    if levels.maid and levels.high and levels.ballet then
                        break
                    end
                end
            end
        end
    end
    return levels
end

local function FormatBooleanState(value)
    if value == nil then return "Unknown" end
    return value and "On" or "Off"
end

local function FormatChastityBeltState(beltEntry, modeEntry)
    if not beltEntry then
        return "Unknown"
    end
    if type(beltEntry.state) == "boolean" then
        return beltEntry.state and "On" or "Off"
    end
    return tostring(beltEntry.state)
end

local function FormatChastityBraState(entry)
    if not entry then
        return "Unknown"
    end
    return FormatBooleanState(entry.state)
end

local function FormatChastityBeltMode(beltEntry, modeEntry)
    if not beltEntry or beltEntry.state ~= true then
        return "Orgasm Allowed"
    end
    if modeEntry and modeEntry.state == "deny" then
        return "Orgasm Denied"
    end
    return "Orgasm Allowed"
end

local function FormatToyApplied(value)
    if value == nil then
        return "Unknown"
    end
    return value and "Applied" or "Not applied"
end

local function FormatToyStage(value)
    local num = tonumber(value) or 0
    if num <= 0 then
        return "Off"
    end
    return tostring(math.floor(num + 0.5))
end

local TOY_DEFS = {
    {
        id = "dildo",
        label = "Dildo",
        icon = "Textures/Dildo.tga",
        vibe = true,
        shock = true,
        restrict = "belt",
    },
    {
        id = "inflatable_butplug",
        label = "Inflatable Butplug",
        icon = "Textures/InflatableButplug.tga",
        inflate = true,
        restrict = "belt",
    },
    {
        id = "inflatable_dildo",
        label = "Inflatable Dildo",
        icon = "Textures/InflatableDildo.tga",
        inflate = true,
        restrict = "belt",
    },
    {
        id = "small_butplug",
        label = "Small Butplug",
        icon = "Textures/SmallButplug.tga",
        restrict = "belt",
    },
    {
        id = "large_butplug",
        label = "Large Butplug",
        icon = "Textures/LargeButplug.tga",
        restrict = "belt",
    },
    {
        id = "taill_butplug",
        label = "Taill Butplug",
        icon = "Textures/TaillButplug.tga",
        restrict = "belt",
    },
    {
        id = "vibes_pussy",
        label = "Vibes Pussy",
        icon = "Textures/Vibes.tga",
        vibe = true,
        restrict = "belt",
    },
    {
        id = "vibes_nipples",
        label = "Vibes Nipples",
        icon = "Textures/Vibes.tga",
        vibe = true,
        restrict = "bra",
    },
    {
        id = "vibes_ears",
        label = "Vibes Ears",
        icon = "Textures/Vibes.tga",
        vibe = true,
        shock = true,
    },
    {
        id = "nipple_piercings",
        label = "Nipple Piercings",
        icon = "Textures/Piercings.tga",
        vibe = true,
        shock = true,
        restrict = "bra",
    },
    {
        id = "ear_piercings",
        label = "Ear Piercings",
        icon = "Textures/Piercings.tga",
        vibe = true,
        shock = true,
    },
    {
        id = "pussy_lipps_piercings",
        label = "Pussy Lipps Piercings",
        icon = "Textures/Piercings.tga",
        vibe = true,
        shock = true,
        restrict = "belt",
    },
}

local DISCIPLINE_DEFS = {
    {
        id = "spank_hand",
        label = "Spank Hand",
        icon = "Textures/Hand.tga",
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
        maxStrength = 3,
        parts = {
            { id = "butt", label = "Butt" },
            { id = "thighs", label = "Thighs" },
            { id = "tits", label = "Tits", restrict = "bra" },
            { id = "paws", label = "Paws" },
        },
    },
}

local function ToyEventName(id)
    return "Toy_" .. id
end

local function ToyVibeEventName(id)
    return "Toy_" .. id .. "_Vibe"
end

local function ToyInflateEventName(id)
    return "Toy_" .. id .. "_Inflate"
end

local function FormatCoords(entry)
    if not entry then return "Unknown" end
    local stamp = entry.receivedAt and date("%Y-%m-%d %H:%M:%S", entry.receivedAt) or entry.timestamp
    local mapPart = entry.mapID and ("map " .. entry.mapID) or "map ?"
    if entry.x and entry.y then
        return string.format("%s (%s, %.4f, %.4f)", stamp or "Unknown time", mapPart, entry.x, entry.y)
    end
    return string.format("%s (%s)", stamp or "Unknown time", mapPart)
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

local function FormatDistanceToKitten(entry)
    if not entry or not entry.x or not entry.y then
        return "Distance to kitten: Unknown"
    end

    local ownerMapID, ownerX, ownerY = GetPlayerMapCoords()
    if not ownerX or not ownerY then
        return "Distance to kitten: Unknown (owner position)"
    end

    if entry.mapID and ownerMapID and entry.mapID ~= ownerMapID then
        return string.format("Distance to kitten: Map mismatch (kitten map %s, owner map %s)", tostring(entry.mapID), tostring(ownerMapID))
    end

    local dx = ownerX - entry.x
    local dy = ownerY - entry.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local mapPart = entry.mapID and ("map " .. entry.mapID) or "map ?"
    return string.format("Distance to kitten: %.4f (%s units)", dist, mapPart)
end

local function FormatRemaining(seconds)
    if not seconds or seconds <= 0 then return nil end
    local total = math.floor(seconds)
    local minutes = math.floor(total / 60)
    local hours = math.floor(minutes / 60)
    local remMinutes = minutes % 60
    local remSeconds = total % 60
    if hours > 0 then
        return string.format("%dh %dm", hours, remMinutes)
    end
    if minutes > 0 then
        return string.format("%dm %ds", minutes, remSeconds)
    end
    return string.format("%ds", remSeconds)
end

local function GetLeashState(log)
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "KittenLeash" then
            return "Leashed"
        elseif entry.event == "KittenUnleash" then
            return "Unleashed"
        end
    end
    return "Unknown"
end

local function GetStartOfDay(now)
    local t = date("*t", now)
    t.hour = 0
    t.min = 0
    t.sec = 0
    return time(t)
end

local function GetStartOfWeek(now)
    local t = date("*t", now)
    t.hour = 0
    t.min = 0
    t.sec = 0
    local midnight = time(t)
    local wday = t.wday or 1 -- Sunday = 1
    local daysFromMonday = (wday + 5) % 7
    return midnight - (daysFromMonday * 86400)
end

local function GetKittenHeatValue(log)
    local entry = FindLastEvent(log, "KittenHeat")
    if entry and entry.state ~= nil then
        local value = tonumber(entry.state)
        if value then
            return math.max(0, math.min(100, value))
        end
    end
    return 0
end

local function GetKittenSubmissivenessValue(log)
    local entry = FindLastEvent(log, "KittenSubmissiveness")
    if entry and entry.state ~= nil then
        local value = tonumber(entry.state)
        if value then
            return math.max(0, math.min(100, value))
        end
    end
    return 0
end

local function GetOrgasmStats(log)
    local total, today, week = 0, 0, 0
    local lastEntry = nil
    if not log or type(log) ~= "table" then
        return total, today, week, lastEntry
    end
    local now = time()
    local dayStart = GetStartOfDay(now)
    local weekStart = GetStartOfWeek(now)
    for i = 1, #log do
        local entry = log[i]
        if entry and entry.event == "KittenOrgasm" then
            total = total + 1
            if entry.unixtime then
                if entry.unixtime >= dayStart then
                    today = today + 1
                end
                if entry.unixtime >= weekStart then
                    week = week + 1
                end
            end
            lastEntry = entry
        end
    end
    return total, today, week, lastEntry
end

local function GetDeniedOrgasmStats(log)
    local total = 0
    local session = 0
    if not log or type(log) ~= "table" then
        return total, session
    end

    local sessionIndex = nil
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry and entry.event == "ChastitySessionStart" then
            sessionIndex = i
            break
        end
    end

    for i = 1, #log do
        local entry = log[i]
        if entry and entry.event == "ChastityDenyOrgasm" then
            total = total + 1
            if not sessionIndex or i >= sessionIndex then
                session = session + 1
            end
        end
    end

    return total, session
end

local function FormatOrgasmTimestamp(entry)
    if not entry then
        return "Never"
    end
    if entry.timestamp and entry.timestamp ~= "" then
        return entry.timestamp
    end
    if entry.unixtime then
        return date("%Y-%m-%d %H:%M", entry.unixtime)
    end
    return "Unknown"
end

local function GetHeatBarColor(value)
    local colors = CCT_HeatConfig and CCT_HeatConfig.colors or nil
    local low = colors and colors.low or { 0.0, 0.45, 1.0 }
    local mid = colors and colors.mid or { 1.0, 0.35, 0.75 }
    local high = colors and colors.high or { 1.0, 0.0, 0.0 }
    local pct = math.max(0, math.min(1, (value or 0) / 100))
    if pct <= 0.5 then
        local t = pct / 0.5
        return low[1] + (mid[1] - low[1]) * t,
            low[2] + (mid[2] - low[2]) * t,
            low[3] + (mid[3] - low[3]) * t
    end
    local t = (pct - 0.5) / 0.5
    return mid[1] + (high[1] - mid[1]) * t,
        mid[2] + (high[2] - mid[2]) * t,
        mid[3] + (high[3] - mid[3]) * t
end

local function GetAppliedBindIconFiles(log)
    local icons = {}
    if not log or type(log) ~= "table" then
        return icons
    end

    local function addIcon(fileName)
        if fileName then
            table.insert(icons, fileName)
        end
    end

    local gagEntry = FindLastEvent(log, "KittenGag")
    local gagState = gagEntry and gagEntry.Gagstate
    if gagState == "Gag" then
        addIcon("Heavy-gag-232-with-bg_ergebnis.tga")
    elseif gagState == "LightGag" then
        addIcon("small-gag-232-with-bg_ergebnis.tga")
    elseif gagState == "FullBlock" then
        addIcon("kitty-mask-with-gag-232-with-bg_ergebnis.tga")
    elseif gagState == "NyaMask" then
        addIcon("cute-kitty-mask-232-with-bg_ergebnis.tga")
    elseif type(gagState) == "string" and gagState:match("^Inflatable") then
        addIcon("Inflatable-gag-232-with-bg_ergebnis.tga")
    end

    local blindEntry = FindLastEvent(log, "KittenBlindfold")
    local blindState = blindEntry and blindEntry.BlindfoldState
    if blindState == "light" then
        addIcon("Light-Blindfold-232-with-bg_ergebnis.tga")
    elseif blindState == "mask" then
        addIcon("Cute-Kitty-Blindfold-232-with-bg_ergebnis.tga")
    elseif blindState == "full" then
        addIcon("Heavy-Blindfold-232-with-bg_ergebnis.tga")
    end

    local earEntry = FindLastEvent(log, "KittenEarmuffs")
    local earState = earEntry and earEntry.state
    if earState == "KittenEarmuffs" then
        addIcon("Kitten-Earmuffs-bg_ergebnis.tga")
    elseif earState == "HeavyEarmuffs" then
        addIcon("Heav-Earmuffs-bg_ergebnis.tga")
    end

    local mittensEntry = FindLastEvent(log, "PawMittens")
    local mittenState = mittensEntry and mittensEntry.state
    if mittenState == "locked" or mittenState == "heavy" then
        addIcon("locking-paw-mitten-232-with-bg_ergebnis.tga")
    elseif mittenState == "squeaking" or mittenState == "squeking" then
        addIcon("paw-mitten-232-with-bg_ergebnis.tga")
    end

    local heelsEntry = FindLastEvent(log, "KittenHeels")
    local heelsState = heelsEntry and heelsEntry.state
    if heelsState == "maid" then
        addIcon("maid-heell-232-with-bg_ergebnis.tga")
    elseif heelsState == "high" then
        addIcon("heell-232-with-bg_ergebnis.tga")
    elseif heelsState == "ballet" then
        addIcon("balletheel-232-with-bg_ergebnis.tga")
    end

    local bellEntry = FindLastEvent(log, "BellState")
    if bellEntry and bellEntry.state then
        addIcon("bell-232-with-bg_ergebnis.tga")
    end

    local tailEntry = FindLastEvent(log, "TailBellState")
    if tailEntry and tailEntry.state then
        addIcon("tail-bell-232-with-bg_ergebnis.tga")
    end

    local trackingEntry = FindLastEvent(log, "TrackingJewel")
    if trackingEntry and trackingEntry.state then
        addIcon("jewel-232-with-bg_ergebnis.tga")
    end

    local beltEntry = FindLastEvent(log, "ChastityBelt")
    if beltEntry and beltEntry.state == true then
        addIcon("Chastitybelt.tga")
    end

    local braEntry = FindLastEvent(log, "ChastityBra")
    if braEntry and braEntry.state == true then
        addIcon("chastitybra.tga")
    end

    for _, toy in ipairs(TOY_DEFS) do
        local toyEntry = FindLastEvent(log, ToyEventName(toy.id))
        if toyEntry and toyEntry.state == true then
            addIcon(toy.icon)
        end
    end

    if GetLeashState(log) == "Leashed" then
        addIcon("leash-232-with-gb_ergebnis.tga")
    end

    return icons
end

local function BuildStatsSections(kittenName)
    local sections = {
        controls = {},
        toys = {},
        other = {},
        skills = {},
        heat = {},
        location = {},
        icons = {},
        heatValue = 0,
        submissivenessValue = 0,
    }
    if not kittenName or kittenName == "" then
        sections.controls = { "No data synced for this kitten yet." }
        return sections
    end
    local kittenKey = ShortName(kittenName)
    local log = CatgirlBehaviorDB
        and CatgirlBehaviorDB.BehaviorLog
        and CatgirlBehaviorDB.BehaviorLog[kittenKey]

    if not log or type(log) ~= "table" then
        sections.controls = { "No data synced for this kitten yet." }
        return sections
    end

    local controlsLines = {}

    local gagEntry = FindLastEvent(log, "KittenGag")
    table.insert(controlsLines, "Gag: " .. FormatGagState(gagEntry and gagEntry.Gagstate))

    local blindEntry = FindLastEvent(log, "KittenBlindfold")
    table.insert(controlsLines, "Blindfold: " .. FormatBlindfoldState(blindEntry and blindEntry.BlindfoldState))

    local earEntry = FindLastEvent(log, "KittenEarmuffs")
    table.insert(controlsLines, "Earmuffs: " .. FormatEarmuffState(earEntry and earEntry.state))

    local mittensEntry = FindLastEvent(log, "PawMittens")
    table.insert(controlsLines, "Paw Mittens: " .. FormatMittensState(mittensEntry and mittensEntry.state))

    local heelsEntry = FindLastEvent(log, "KittenHeels")
    table.insert(controlsLines, "Heels: " .. FormatHeelsState(heelsEntry and heelsEntry.state))

    local bellEntry = FindLastEvent(log, "BellState")
    table.insert(controlsLines, "Bell: " .. FormatBooleanState(bellEntry and bellEntry.state))

    local tailEntry = FindLastEvent(log, "TailBellState")
    table.insert(controlsLines, "Tail Bell: " .. FormatBooleanState(tailEntry and tailEntry.state))

    local trackingEntry = FindLastEvent(log, "TrackingJewel")
    table.insert(controlsLines, "Tracking Jewel: " .. FormatBooleanState(trackingEntry and trackingEntry.state))

    local beltEntry = FindLastEvent(log, "ChastityBelt")
    local beltModeEntry = FindLastEvent(log, "ChastityBeltMode")
    table.insert(controlsLines, "Chastity Belt: " .. FormatChastityBeltState(beltEntry, beltModeEntry))
    table.insert(controlsLines, "Belt state: " .. FormatChastityBeltMode(beltEntry, beltModeEntry))

    local braEntry = FindLastEvent(log, "ChastityBra")
    table.insert(controlsLines, "Chastity Bra: " .. FormatChastityBraState(braEntry))

    table.insert(controlsLines, "Leash: " .. GetLeashState(log))

    local toysLines = {}
    for _, toy in ipairs(TOY_DEFS) do
        local toyEntry = FindLastEvent(log, ToyEventName(toy.id))
        table.insert(toysLines, string.format("%s: %s", toy.label, FormatToyApplied(toyEntry and toyEntry.state)))
        if toy.vibe then
            local vibeEntry = FindLastEvent(log, ToyVibeEventName(toy.id))
            table.insert(toysLines, "  Vibration intensity: " .. FormatToyStage(vibeEntry and vibeEntry.state))
        end
        if toy.inflate then
            local inflateEntry = FindLastEvent(log, ToyInflateEventName(toy.id))
            table.insert(toysLines, "  Inflation stage: " .. FormatToyStage(inflateEntry and inflateEntry.state))
        end
    end

    local otherLines = {}
    local locationLines = {}
    local locationLog = CatgirlLocationDB
        and CatgirlLocationDB.LocationLog
        and CatgirlLocationDB.LocationLog[kittenKey]
    if locationLog and #locationLog > 0 then
        local lastLocation = locationLog[#locationLog]
        table.insert(locationLines, "Last Location Sync: " .. FormatCoords(lastLocation))
        table.insert(locationLines, FormatDistanceToKitten(lastLocation))
    else
        table.insert(locationLines, "Last Location Sync: None")
        table.insert(locationLines, "Distance to kitten: Unknown")
    end

    local heelsSkills = GetHeelsSkillLevels(log)
    local skillsLines = {
        "Maid heels: " .. FormatSkillLevel(heelsSkills.maid),
        "High heels: " .. FormatSkillLevel(heelsSkills.high),
        "Ballet boots: " .. FormatSkillLevel(heelsSkills.ballet),
    }

    local timerLines = {}
    local timerKeys = {
        { key = "gag", label = "Gag" },
        { key = "earmuffs", label = "Earmuffs" },
        { key = "blindfold", label = "Blindfold" },
        { key = "mittens", label = "Paw Mittens" },
        { key = "heels", label = "Heels" },
        { key = "bell", label = "Bell" },
        { key = "tailbell", label = "Tail Bell" },
        { key = "chastitybelt", label = "Chastity Belt" },
        { key = "chastitybra", label = "Chastity Bra" },
    }

    for _, timer in ipairs(timerKeys) do
        local entry = log[timer.key]
        if entry and entry.unlockAt then
            local remaining = entry.unlockAt - time()
            local remainingText = FormatRemaining(remaining)
            if remainingText then
                table.insert(timerLines, string.format("%s: %s remaining", timer.label, remainingText))
            end
        end
    end

    if #timerLines > 0 then
        table.insert(otherLines, "Timed removals:")
        for _, line in ipairs(timerLines) do
            table.insert(otherLines, line)
        end
    else
        table.insert(otherLines, "Timed removals: none")
    end

    local heatValue = GetKittenHeatValue(log)
    local submissivenessValue = GetKittenSubmissivenessValue(log)
    local orgasmTotal, orgasmToday, orgasmWeek, lastOrgasm = GetOrgasmStats(log)
    local deniedTotal, deniedSession = GetDeniedOrgasmStats(log)

    local heatLines = {
        string.format("Kitten Heat Bar: %d / 100", heatValue),
        "Orgasm Counter: " .. tostring(orgasmTotal),
        "Last Orgasm: " .. FormatOrgasmTimestamp(lastOrgasm),
        "Orgasms Today: " .. tostring(orgasmToday),
        "Orgasms This Week: " .. tostring(orgasmWeek),
        "Denied Orgasms: " .. tostring(deniedTotal),
        "Denied Orgasms This Session: " .. tostring(deniedSession),
    }

    sections.controls = controlsLines
    sections.toys = toysLines
    sections.other = otherLines
    sections.skills = skillsLines
    sections.heat = heatLines
    sections.location = locationLines
    sections.icons = GetAppliedBindIconFiles(log)
    sections.heatValue = heatValue
    sections.submissivenessValue = submissivenessValue
    return sections
end

-- Create control panel UI
local function ShowControlPanel(kitten)
    local hasKitten = kitten and kitten ~= ""
    local kittenName = hasKitten and kitten or nil
    local frame = CatGirlControlPanel
    if frame then
        frame.kitten = kittenName
        frame.hasKitten = hasKitten
        frame.kittenName:SetText(FormatKittenLabel(frame.kitten))
        frame:Show()
        if frame.selectedTab == "Stats" and frame.UpdateStats then
            frame:UpdateStats()
        end
        return
    end

    frame = CreateFrame("Frame", "CatGirlControlPanel", UIParent, "BackdropTemplate")
    frame:SetSize(360, 520)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.6)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -10)
    frame.title:SetText("Catgirl Control")

    frame.kittenName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.kittenName:SetPoint("TOP", 0, -30)
    frame.kittenName:SetText(FormatKittenLabel(kittenName))

    frame.kitten = kittenName
    frame.hasKitten = hasKitten

    local function CreateScrollArea(parent)
        local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 0, 0)
        scroll:SetPoint("BOTTOMRIGHT", -26, 0)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetPoint("TOPLEFT", 0, 0)
        content:SetWidth(300)
        scroll:SetScrollChild(content)
        return scroll, content
    end

    local function AddHeader(parent, y, text)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 0, y)
        label:SetText(text)
        return y - 16
    end

    local CGCC_TEXTURE_PATH = "Interface\\AddOns\\CatgirlTracker\\Textures\\cgcc\\"
    local CONTROL_ICON_SIZE = 20
    local CONTROL_PREVIEW_SIZE = 232
    local controlIconPreview = nil

    local function BuildControlIconPath(fileName)
        if not fileName or fileName == "" then
            return nil
        end
        if fileName:find("[/\\]") then
            return "Interface\\AddOns\\CatgirlTracker\\" .. fileName:gsub("/", "\\")
        end
        return CGCC_TEXTURE_PATH .. fileName
    end

    local function EnsureControlIconPreview()
        if controlIconPreview then
            return controlIconPreview
        end
        controlIconPreview = CreateFrame("Frame", "CGCCControlIconPreview", UIParent, "BackdropTemplate")
        controlIconPreview:SetSize(CONTROL_PREVIEW_SIZE + 8, CONTROL_PREVIEW_SIZE + 8)
        controlIconPreview:SetFrameStrata("TOOLTIP")
        controlIconPreview:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 10,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        controlIconPreview:SetBackdropColor(0, 0, 0, 0.9)
        controlIconPreview.texture = controlIconPreview:CreateTexture(nil, "ARTWORK")
        controlIconPreview.texture:SetSize(CONTROL_PREVIEW_SIZE, CONTROL_PREVIEW_SIZE)
        controlIconPreview.texture:SetPoint("CENTER")
        controlIconPreview:Hide()
        return controlIconPreview
    end

    local function ShowControlIconPreview(owner, texturePath)
        if not texturePath then return end
        local preview = EnsureControlIconPreview()
        preview.texture:SetTexture(texturePath)
        preview:ClearAllPoints()
        preview:SetPoint("LEFT", owner, "RIGHT", 115, 0)
        preview:Show()
    end

    local function HideControlIconPreview()
        if controlIconPreview then
            controlIconPreview:Hide()
        end
    end

    frame:HookScript("OnHide", HideControlIconPreview)

    local function AddButton(parent, y, label, command, iconFile)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(240, 20)
        btn:SetPoint("TOPLEFT", 0, y)
        btn:SetText(label)
        btn:SetScript("OnClick", function()
            WhisperToKitten(frame.kitten, command)
        end)
        if iconFile then
            local iconPath = BuildControlIconPath(iconFile)
            btn:SetScript("OnEnter", function(self)
                ShowControlIconPreview(self, iconPath)
            end)
            btn:SetScript("OnLeave", function()
                HideControlIconPreview()
            end)

            local iconButton = CreateFrame("Button", nil, parent)
            iconButton:SetSize(CONTROL_ICON_SIZE, CONTROL_ICON_SIZE)
            iconButton:SetPoint("LEFT", btn, "RIGHT", 6, 0)
            iconButton:EnableMouse(true)

            local icon = iconButton:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(iconButton)
            icon:SetTexture(iconPath)

            iconButton:SetScript("OnEnter", function(self)
                ShowControlIconPreview(self, iconPath)
            end)
            iconButton:SetScript("OnLeave", function()
                HideControlIconPreview()
            end)
        end
        return y - 24
    end

    local function BuildToyCommand(toyId, action, level)
        if level ~= nil then
            return string.format("cctoy %s %s %s", toyId, action, tostring(level))
        end
        return string.format("cctoy %s %s", toyId, action)
    end

    local function FormatCoord(value)
        if value == nil then
            return "nil"
        end
        return string.format("%.4f", value)
    end

    local function BuildDisciplineCommand(actionId, partId, strength)
        local mapID, x, y = GetPlayerMapCoords()
        local instanceID = GetInstanceID()
        return string.format(
            "ccdisc %s %s %s %s %s %s %s",
            actionId,
            partId,
            tostring(strength),
            tostring(mapID or "nil"),
            FormatCoord(x),
            FormatCoord(y),
            tostring(instanceID or "nil")
        )
    end

    local DISCIPLINE_CLOSE_RANGE = 0.02

    local function IsChastityBeltActive()
        if not frame.kitten or frame.kitten == "" then
            return false
        end
        local kittenKey = ShortName(frame.kitten)
        local log = CatgirlBehaviorDB
            and CatgirlBehaviorDB.BehaviorLog
            and CatgirlBehaviorDB.BehaviorLog[kittenKey]
        if not log or type(log) ~= "table" then
            return false
        end
        local beltEntry = FindLastEvent(log, "ChastityBelt")
        return beltEntry and beltEntry.state == true
    end

    local function IsChastityBraActive()
        if not frame.kitten or frame.kitten == "" then
            return false
        end
        local kittenKey = ShortName(frame.kitten)
        local log = CatgirlBehaviorDB
            and CatgirlBehaviorDB.BehaviorLog
            and CatgirlBehaviorDB.BehaviorLog[kittenKey]
        if not log or type(log) ~= "table" then
            return false
        end
        local braEntry = FindLastEvent(log, "ChastityBra")
        return braEntry and braEntry.state == true
    end

    local function GetLatestLocationEntry(kittenName)
        if not kittenName or kittenName == "" then
            return nil
        end
        local kittenKey = ShortName(kittenName)
        local log = CatgirlLocationDB
            and CatgirlLocationDB.LocationLog
            and CatgirlLocationDB.LocationLog[kittenKey]
        if not log or type(log) ~= "table" then
            return nil
        end
        for i = #log, 1, -1 do
            local entry = log[i]
            if entry and entry.x and entry.y then
                return entry
            end
        end
        return nil
    end

    local function IsOwnerNearKitten(kittenName)
        local entry = GetLatestLocationEntry(kittenName)
        if not entry then
            return false, nil
        end
        local ownerMapID, ownerX, ownerY = GetPlayerMapCoords()
        if ownerX and ownerY and entry.x and entry.y then
            if entry.mapID and ownerMapID and entry.mapID ~= ownerMapID then
                if IsSameInstance(entry.instanceID) then
                    return true, nil
                end
                return false, nil
            end
            local dx = ownerX - entry.x
            local dy = ownerY - entry.y
            local dist = math.sqrt(dx * dx + dy * dy)
            return dist <= DISCIPLINE_CLOSE_RANGE, dist
        end
        if IsSameInstance(entry.instanceID) then
            return true, nil
        end
        return false, nil
    end

    local function WarnDisciplineTooFar()
        local message = CCT_Msg and CCT_Msg("DISCIPLINE_TOO_FAR") or "You are near your Kitten Nya!"
        if CCT_RaidNotice then
            CCT_RaidNotice(message)
        else
            print("|cffff5555[CatGirlControlCenter]|r " .. message)
        end
    end

    local function AddToyButton(parent, y, label, toy, action, iconFile)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(240, 20)
        btn:SetPoint("TOPLEFT", 0, y)
        btn:SetText(label)
        btn:SetScript("OnClick", function()
            if action == "apply" or action == "remove" then
                if toy.restrict == "belt" and IsChastityBeltActive() then
                    print("|cffff5555[CatGirlControlCenter]|r Cannot change this toy while a chastity belt is locked.")
                    return
                end
                if toy.restrict == "bra" and IsChastityBraActive() then
                    print("|cffff5555[CatGirlControlCenter]|r Cannot change this toy while a chastity bra is locked.")
                    return
                end
            end
            SendAddonToKitten(frame.kitten, BuildToyCommand(toy.id, action))
        end)
        if iconFile then
            local iconPath = BuildControlIconPath(iconFile)
            btn:SetScript("OnEnter", function(self)
                ShowControlIconPreview(self, iconPath)
            end)
            btn:SetScript("OnLeave", function()
                HideControlIconPreview()
            end)

            local iconButton = CreateFrame("Button", nil, parent)
            iconButton:SetSize(CONTROL_ICON_SIZE, CONTROL_ICON_SIZE)
            iconButton:SetPoint("LEFT", btn, "RIGHT", 6, 0)
            iconButton:EnableMouse(true)

            local icon = iconButton:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(iconButton)
            icon:SetTexture(iconPath)

            iconButton:SetScript("OnEnter", function(self)
                ShowControlIconPreview(self, iconPath)
            end)
            iconButton:SetScript("OnLeave", function()
                HideControlIconPreview()
            end)
        end
        return y - 24
    end

    local function AddToyIntensityRow(parent, y, label, toy, action, maxLevel)
        local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("TOPLEFT", 0, y)
        text:SetText(label)

        local btnWidth = 22
        local btnHeight = 20
        local startX = 140
        local spacing = 4
        for i = 1, maxLevel do
            local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            btn:SetSize(btnWidth, btnHeight)
            btn:SetPoint("TOPLEFT", startX + (i - 1) * (btnWidth + spacing), y)
            btn:SetText(tostring(i))
            btn:SetScript("OnClick", function()
                SendAddonToKitten(frame.kitten, BuildToyCommand(toy.id, action, i))
            end)
        end
        return y - 24
    end

    local function AddToyInflateRow(parent, y, toy)
        local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("TOPLEFT", 0, y)
        text:SetText("Inflation")

        local inflateBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        inflateBtn:SetSize(70, 20)
        inflateBtn:SetPoint("TOPLEFT", 140, y)
        inflateBtn:SetText("Inflate")
        inflateBtn:SetScript("OnClick", function()
            SendAddonToKitten(frame.kitten, BuildToyCommand(toy.id, "inflate"))
        end)

        local deflateBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        deflateBtn:SetSize(70, 20)
        deflateBtn:SetPoint("LEFT", inflateBtn, "RIGHT", 6, 0)
        deflateBtn:SetText("Deflate")
        deflateBtn:SetScript("OnClick", function()
            SendAddonToKitten(frame.kitten, BuildToyCommand(toy.id, "deflate"))
        end)

        return y - 24
    end

    local function AddChastityModeButton(parent, y, label, command)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(240, 20)
        btn:SetPoint("TOPLEFT", 0, y)
        btn:SetText(label)
        btn:SetScript("OnClick", function()
            if not IsChastityBeltActive() then
                print("|cffff5555[CatGirlControlCenter]|r Chastity belt is not locked on the kitten.")
                return
            end
            WhisperToKitten(frame.kitten, command)
        end)
        return y - 24
    end

    local function AddDelayRow(parent, y, label, msgTemplate)
        local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        box:SetSize(30, 20)
        box:SetPoint("TOPLEFT", 0, y)
        box:SetAutoFocus(false)
        box:SetText("1.5")

        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(200, 20)
        btn:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 0)
        btn:SetText(label)

        btn:SetScript("OnClick", function()
            local val = tonumber(box:GetText())
            if val and val > 0 then
                local minutes = math.floor(val * 60 + 0.5)
                local msg = msgTemplate:format(val, minutes)
                WhisperToKitten(frame.kitten, msg)
            else
                print("|cffff5555[CatGirlControlCenter]|r Invalid number.")
            end
        end)
        return y - 24
    end

    local function AddCheckbox(parent, y, label, getValue, setValue)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 0, y)
        local text = cb.Text or cb.text
        if text then
            text:SetText(label)
        end
        cb:SetChecked(getValue())
        cb:SetScript("OnClick", function(self)
            setValue(self:GetChecked())
        end)
        cb:SetScript("OnShow", function(self)
            self:SetChecked(getValue())
        end)
        return cb, y - 24
    end

    local tabNames = { "Stats", "Control", "Toys", "Discipline", "Settings" }
    local tabButtons = {}
    local tabFrames = {}

    local tabSpacing = 4
    local tabWidth = math.floor((frame:GetWidth() - 20 - (tabSpacing * (#tabNames - 1))) / #tabNames)
    if tabWidth < 60 then
        tabWidth = 60
    end
    for i, name in ipairs(tabNames) do
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(tabWidth, 20)
        btn:SetPoint("TOPLEFT", 10 + (i - 1) * (tabWidth + tabSpacing), -55)
        btn:SetText(name)
        tabButtons[name] = btn
    end

    local contentArea = CreateFrame("Frame", nil, frame)
    contentArea:SetPoint("TOPLEFT", 10, -80)
    contentArea:SetPoint("BOTTOMRIGHT", -10, 10)

    local function CreateTabFrame()
        local tab = CreateFrame("Frame", nil, contentArea)
        tab:SetAllPoints(contentArea)
        tab:Hide()
        return tab
    end

    -- Stats tab
    local statsTab = CreateTabFrame()
    local statsScroll, statsContent = CreateScrollArea(statsTab)
    local refreshBtn = CreateFrame("Button", nil, statsContent, "UIPanelButtonTemplate")
    refreshBtn:SetSize(120, 20)
    refreshBtn:SetPoint("TOPLEFT", 0, 0)
    refreshBtn:SetText("Refresh")

    local warningText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    warningText:SetPoint("TOPLEFT", refreshBtn, "BOTTOMLEFT", 0, -6)
    warningText:SetJustifyH("LEFT")
    warningText:SetWidth(280)
    warningText:SetTextColor(1, 0.1, 0.1)
    warningText:SetText("You dont own a kitten yet most Functions not avilable!!!")
    warningText:Hide()

    local controlsStatusHeader = statsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    controlsStatusHeader:SetPoint("TOPLEFT", refreshBtn, "BOTTOMLEFT", 0, 0)
    controlsStatusHeader:SetJustifyH("LEFT")
    controlsStatusHeader:SetWidth(280)
    controlsStatusHeader:SetTextColor(1, 0.2, 0.2)
    controlsStatusHeader:SetText("Controls Status")

    local statsControlsText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsControlsText:SetPoint("TOPLEFT", controlsStatusHeader, "BOTTOMLEFT", 0, 0)
    statsControlsText:SetJustifyH("LEFT")
    statsControlsText:SetWidth(280)
    statsControlsText:SetText("")

    local toysHeader = statsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    toysHeader:SetPoint("TOPLEFT", statsControlsText, "BOTTOMLEFT", 0, 0)
    toysHeader:SetJustifyH("LEFT")
    toysHeader:SetWidth(280)
    toysHeader:SetTextColor(1, 0.2, 0.2)
    toysHeader:SetText("Toys")

    local statsToysText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsToysText:SetPoint("TOPLEFT", toysHeader, "BOTTOMLEFT", 0, 0)
    statsToysText:SetJustifyH("LEFT")
    statsToysText:SetWidth(280)
    statsToysText:SetText("")

    local gearHeader = statsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    gearHeader:SetPoint("TOPLEFT", statsToysText, "BOTTOMLEFT", 0, -2)
    gearHeader:SetJustifyH("LEFT")
    gearHeader:SetWidth(280)
    gearHeader:SetTextColor(1, 0.2, 0.2)
    gearHeader:SetText("Kitten Gear:")

    local statsIcons = CreateFrame("Frame", nil, statsContent)
    statsIcons:SetPoint("TOPLEFT", gearHeader, "BOTTOMLEFT", 0, -2)
    statsIcons:SetWidth(280)
    statsIcons:SetHeight(1)

    local statsOtherText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsOtherText:SetPoint("TOPLEFT", statsIcons, "BOTTOMLEFT", 0, -8)
    statsOtherText:SetJustifyH("LEFT")
    statsOtherText:SetWidth(280)
    statsOtherText:SetText("")

    local skillsHeader = statsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    skillsHeader:SetPoint("TOPLEFT", statsOtherText, "BOTTOMLEFT", 0, -8)
    skillsHeader:SetJustifyH("LEFT")
    skillsHeader:SetWidth(280)
    skillsHeader:SetTextColor(1, 0.2, 0.2)
    skillsHeader:SetText("Kitten Skills")

    local statsSkillsText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsSkillsText:SetPoint("TOPLEFT", skillsHeader, "BOTTOMLEFT", 0, -2)
    statsSkillsText:SetJustifyH("LEFT")
    statsSkillsText:SetWidth(280)
    statsSkillsText:SetText("")

    local heatHeader = statsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heatHeader:SetPoint("TOPLEFT", statsSkillsText, "BOTTOMLEFT", 0, -8)
    heatHeader:SetJustifyH("LEFT")
    heatHeader:SetWidth(280)
    heatHeader:SetTextColor(1, 0.2, 0.2)
    heatHeader:SetText("Kitten Heat Status")

    local statsHeatText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsHeatText:SetPoint("TOPLEFT", heatHeader, "BOTTOMLEFT", 0, -2)
    statsHeatText:SetJustifyH("LEFT")
    statsHeatText:SetWidth(280)
    statsHeatText:SetText("")

    local statsLocationText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsLocationText:SetPoint("TOPLEFT", statsHeatText, "BOTTOMLEFT", 0, -8)
    statsLocationText:SetJustifyH("LEFT")
    statsLocationText:SetWidth(280)
    statsLocationText:SetText("")

    local kittenSubmissivenessBar = CreateFrame("StatusBar", nil, statsContent, "BackdropTemplate")
    kittenSubmissivenessBar:SetSize(260, 14)
    kittenSubmissivenessBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    kittenSubmissivenessBar:SetMinMaxValues(0, 100)
    kittenSubmissivenessBar:SetValue(0)
    kittenSubmissivenessBar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    kittenSubmissivenessBar:SetBackdropColor(0, 0, 0, 0.6)
    kittenSubmissivenessBar.text = kittenSubmissivenessBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    kittenSubmissivenessBar.text:SetPoint("CENTER")
    kittenSubmissivenessBar.text:SetText("Kitten Submissiveness: 0 / 100")
    kittenSubmissivenessBar:Hide()

    local kittenHeatBar = CreateFrame("StatusBar", nil, statsContent, "BackdropTemplate")
    kittenHeatBar:SetSize(260, 14)
    kittenHeatBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    kittenHeatBar:SetMinMaxValues(0, 100)
    kittenHeatBar:SetValue(0)
    kittenHeatBar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    kittenHeatBar:SetBackdropColor(0, 0, 0, 0.6)
    kittenHeatBar.text = kittenHeatBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    kittenHeatBar.text:SetPoint("CENTER")
    kittenHeatBar.text:SetText("Kitten Heat Bar: 0")
    kittenHeatBar:Hide()

    local statsIconTextures = {}

    frame.UpdateStats = function(self)
        local noKitten = not self.kitten
        warningText:SetShown(noKitten)

        local sections = BuildStatsSections(self.kitten)
        local controlsLines = sections.controls or {}
        local toysLines = sections.toys or {}
        local otherLines = sections.other or {}
        local skillsLines = sections.skills or {}
        local heatLines = sections.heat or {}
        local locationLines = sections.location or {}
        local iconFiles = sections.icons or {}
        local iconCount = iconFiles and #iconFiles or 0
        local heatValue = sections.heatValue or 0
        local submissivenessValue = sections.submissivenessValue or 0

        statsControlsText:SetText(table.concat(controlsLines, "\n"))
        statsToysText:SetText(table.concat(toysLines, "\n"))
        statsOtherText:SetText(table.concat(otherLines, "\n"))
        statsSkillsText:SetText(table.concat(skillsLines, "\n"))
        statsHeatText:SetText(table.concat(heatLines, "\n"))
        statsLocationText:SetText(table.concat(locationLines, "\n"))

        local lineHeight = 14
        statsControlsText:SetHeight(#controlsLines * lineHeight)
        statsToysText:SetHeight(#toysLines * lineHeight)
        statsOtherText:SetHeight(#otherLines * lineHeight)
        statsSkillsText:SetHeight(#skillsLines * lineHeight)
        statsHeatText:SetHeight(#heatLines * lineHeight)
        statsLocationText:SetHeight(#locationLines * lineHeight)

        toysHeader:SetShown(#toysLines > 0)
        statsToysText:SetShown(#toysLines > 0)
        skillsHeader:SetShown(#skillsLines > 0)
        statsSkillsText:SetShown(#skillsLines > 0)
        heatHeader:SetShown(#heatLines > 0)
        statsHeatText:SetShown(#heatLines > 0)
        gearHeader:SetShown(iconCount > 0)
        statsLocationText:SetShown(#locationLines > 0)

        warningText:ClearAllPoints()
        controlsStatusHeader:ClearAllPoints()
        statsControlsText:ClearAllPoints()
        toysHeader:ClearAllPoints()
        statsToysText:ClearAllPoints()
        gearHeader:ClearAllPoints()
        statsIcons:ClearAllPoints()
        statsOtherText:ClearAllPoints()
        skillsHeader:ClearAllPoints()
        statsSkillsText:ClearAllPoints()
        heatHeader:ClearAllPoints()
        statsHeatText:ClearAllPoints()
        statsLocationText:ClearAllPoints()

        local topAnchor = refreshBtn
        if noKitten then
            warningText:SetPoint("TOPLEFT", refreshBtn, "BOTTOMLEFT", 0, 0)
            topAnchor = warningText
        end

        local currentAnchor = topAnchor

        if #skillsLines > 0 then
            skillsHeader:SetPoint("TOPLEFT", currentAnchor, "BOTTOMLEFT", 0, -2)
            statsSkillsText:SetPoint("TOPLEFT", skillsHeader, "BOTTOMLEFT", 0, 0)
            currentAnchor = statsSkillsText
        end

        if #heatLines > 0 then
            heatHeader:SetPoint("TOPLEFT", currentAnchor, "BOTTOMLEFT", 0, -4)
            statsHeatText:SetPoint("TOPLEFT", heatHeader, "BOTTOMLEFT", 0, 0)
            currentAnchor = statsHeatText
        end

        kittenSubmissivenessBar:ClearAllPoints()
        local showSubBar = not noKitten
        if showSubBar then
            kittenSubmissivenessBar:SetPoint("TOPLEFT", currentAnchor, "BOTTOMLEFT", 0, -4)
            local displayValue = tonumber(submissivenessValue) or 0
            displayValue = math.max(0, math.min(100, displayValue))
            kittenSubmissivenessBar:SetValue(displayValue)
            kittenSubmissivenessBar:SetStatusBarColor(0.35, 0.8, 0.6)
            kittenSubmissivenessBar.text:SetText(string.format("Kitten Submissiveness: %d / 100", displayValue))
            kittenSubmissivenessBar:Show()
            currentAnchor = kittenSubmissivenessBar
        else
            kittenSubmissivenessBar:Hide()
        end

        kittenHeatBar:ClearAllPoints()
        local showHeatBar = not noKitten
        if showHeatBar then
            kittenHeatBar:SetPoint("TOPLEFT", currentAnchor, "BOTTOMLEFT", 0, -4)
            local displayValue = tonumber(heatValue) or 0
            displayValue = math.max(0, math.min(100, displayValue))
            kittenHeatBar:SetValue(displayValue)
            local r, g, b = GetHeatBarColor(displayValue)
            kittenHeatBar:SetStatusBarColor(r, g, b)
            kittenHeatBar.text:SetText(string.format("Kitten Heat Bar: %d / 100", displayValue))
            kittenHeatBar:Show()
            currentAnchor = kittenHeatBar
        else
            kittenHeatBar:Hide()
        end

        if iconCount > 0 then
            gearHeader:SetPoint("TOPLEFT", currentAnchor, "BOTTOMLEFT", 0, -4)
            statsIcons:SetPoint("TOPLEFT", gearHeader, "BOTTOMLEFT", 0, -2)
            currentAnchor = statsIcons
        end

        if #otherLines > 0 then
            statsOtherText:SetPoint("TOPLEFT", currentAnchor, "BOTTOMLEFT", 0, -4)
            currentAnchor = statsOtherText
        end

        controlsStatusHeader:SetPoint("TOPLEFT", currentAnchor, "BOTTOMLEFT", 0, -4)
        statsControlsText:SetPoint("TOPLEFT", controlsStatusHeader, "BOTTOMLEFT", 0, 0)
        currentAnchor = statsControlsText

        if #toysLines > 0 then
            toysHeader:SetPoint("TOPLEFT", currentAnchor, "BOTTOMLEFT", 0, 0)
            statsToysText:SetPoint("TOPLEFT", toysHeader, "BOTTOMLEFT", 0, 0)
            currentAnchor = statsToysText
        end

        local statsIconSize = 40
        local statsIconPadding = 6
        local statsSectionSpacing = 8

        local iconsPerRow = math.max(1, math.floor((statsIcons:GetWidth() + statsIconPadding) / (statsIconSize + statsIconPadding)))
        local iconRows = iconCount > 0 and (math.floor((iconCount - 1) / iconsPerRow) + 1) or 0
        local iconsHeight = iconRows > 0
            and (iconRows * statsIconSize + (iconRows - 1) * statsIconPadding)
            or 0

        for i, fileName in ipairs(iconFiles or {}) do
            local tex = statsIconTextures[i]
            if not tex then
                tex = statsIcons:CreateTexture(nil, "ARTWORK")
                statsIconTextures[i] = tex
            end
            local row = math.floor((i - 1) / iconsPerRow)
            local col = (i - 1) % iconsPerRow
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", col * (statsIconSize + statsIconPadding), -row * (statsIconSize + statsIconPadding))
            tex:SetSize(statsIconSize, statsIconSize)
            tex:SetTexture(BuildControlIconPath(fileName))
            tex:Show()
        end
        for i = iconCount + 1, #statsIconTextures do
            statsIconTextures[i]:Hide()
        end

        if iconCount > 0 then
            statsIcons:SetHeight(iconsHeight)
            statsIcons:Show()
        else
            statsIcons:SetHeight(1)
            statsIcons:Hide()
        end

        if #locationLines > 0 then
            statsLocationText:SetPoint("TOPLEFT", currentAnchor, "BOTTOMLEFT", 0, -2)
            currentAnchor = statsLocationText
        end

        local lastElement = currentAnchor

        local contentTop = statsContent:GetTop()
        local contentBottom = lastElement and lastElement:GetBottom()
        if contentTop and contentBottom then
            local height = contentTop - contentBottom + 20
            statsContent:SetHeight(math.max(120, height))
        else
            statsContent:SetHeight(120)
        end
    end

    refreshBtn:SetScript("OnClick", function()
        frame:UpdateStats()
    end)

    tabFrames["Stats"] = statsTab

    -- Control tab (combined apply + remove)
    local controlTab = CreateTabFrame()
    local controlScroll, controlContent = CreateScrollArea(controlTab)

    local controlBlocks = {}
    local LayoutControlBlocks

    local function UpdateControlHeight(totalHeight)
        controlContent:SetHeight(math.max(200, totalHeight))
        if controlScroll.UpdateScrollChildRect then
            controlScroll:UpdateScrollChildRect()
        end
    end

    local function CreateCollapsibleBlock(title)
        local block = {
            kind = "collapsible",
            title = title,
            expanded = false,
        }

        block.header = CreateFrame("Button", nil, controlContent, "UIPanelButtonTemplate")
        block.header:SetSize(270, 20)
        local headerFont = block.header:GetFontString()
        if headerFont then
            headerFont:SetJustifyH("LEFT")
        end

        block.content = CreateFrame("Frame", nil, controlContent)
        block.content:SetWidth(300)
        block.content:Hide()

        local function UpdateHeaderVisuals()
            local marker = block.expanded and "[-]" or "[+]"
            block.header:SetText(string.format("%s %s", marker, block.title))
            block.header:SetHeight(20)
            local fontString = block.header:GetFontString()
            if fontString then
                if block.expanded then
                    fontString:SetTextColor(1, 0.82, 0)
                else
                    fontString:SetTextColor(1, 1, 1)
                end
            end
        end

        function block:SetExpanded(expanded)
            self.expanded = expanded and true or false
            self.content:SetShown(self.expanded)
            UpdateHeaderVisuals()
            if LayoutControlBlocks then
                LayoutControlBlocks()
            end
        end

        block.header:SetScript("OnClick", function()
            block:SetExpanded(not block.expanded)
        end)

        UpdateHeaderVisuals()
        table.insert(controlBlocks, block)
        return block
    end

    local function CreateStaticBlock(builder)
        local block = {
            kind = "static",
            frame = CreateFrame("Frame", nil, controlContent),
            height = 0,
        }
        block.frame:SetWidth(300)
        block.height = builder(block.frame) or 0
        block.frame:SetHeight(block.height)
        table.insert(controlBlocks, block)
        return block
    end

    local function FinalizeBlockHeight(yValue)
        return math.max(24, -yValue + 10)
    end

    local function BuildCollapsibleContent(block, builder)
        local yBlock = -4
        yBlock = builder(block.content, yBlock)
        block.contentHeight = FinalizeBlockHeight(yBlock)
        block.content:SetHeight(block.contentHeight)
        block.content:Hide()
    end

    LayoutControlBlocks = function()
        local yOffset = -4
        local spacing = 6

        for _, block in ipairs(controlBlocks) do
            if block.kind == "collapsible" then
                block.header:ClearAllPoints()
                block.header:SetPoint("TOPLEFT", controlContent, "TOPLEFT", 0, yOffset)
                yOffset = yOffset - block.header:GetHeight()

                if block.expanded then
                    block.content:ClearAllPoints()
                    block.content:SetPoint("TOPLEFT", block.header, "BOTTOMLEFT", 0, -2)
                    block.content:SetHeight(block.contentHeight or 0)
                    block.content:Show()
                    yOffset = yOffset - (block.contentHeight or 0) - spacing
                else
                    block.content:Hide()
                    yOffset = yOffset - spacing
                end
            else
                block.frame:ClearAllPoints()
                block.frame:SetPoint("TOPLEFT", controlContent, "TOPLEFT", 0, yOffset)
                block.frame:SetHeight(block.height or 0)
                yOffset = yOffset - (block.height or 0) - spacing
            end
        end

        UpdateControlHeight(-yOffset + 10)
    end

    -- Collapsible: Leash (hidden by default)
    local leashBlock = CreateCollapsibleBlock("Leash")
    BuildCollapsibleContent(leashBlock, function(parent, y)
        y = AddHeader(parent, y, "Apply")
        y = AddButton(parent, y, "Leash", "leash", "leash-232-with-gb_ergebnis.tga")
        y = y - 4
        y = AddHeader(parent, y, "Remove")
        y = AddButton(parent, y, "Unleash", "unleash")
        return y
    end)

    -- Collapsible: Gags and Masks (hidden by default)
    local gagBlock = CreateCollapsibleBlock("Gags and Masks")
    BuildCollapsibleContent(gagBlock, function(parent, y)
        y = AddHeader(parent, y, "Apply")
        y = AddButton(parent, y, "Cute Kitten Mask", "Your owner gave you a cute~ Kitten Mask ~UwU~ It gives you an irresistible urge to Nya in every sentence.", "cute-kitty-mask-232-with-bg_ergebnis.tga")
        y = AddButton(parent, y, "Small Gag", "Your owner has fitted a small silken gag over your mouth. Speech is now garbled.", "small-gag-232-with-bg_ergebnis.tga")
        y = AddButton(parent, y, "Heavy Gag", "Your owner has secured a heavy gag in place. You can no longer speak.", "Heavy-gag-232-with-bg_ergebnis.tga")
        y = AddButton(parent, y, "Kitty Mask With Gag!", "Your owner put a gag and a Kitten Mask on you! You must have been a really naughty cat!", "kitty-mask-with-gag-232-with-bg_ergebnis.tga")
        y = AddButton(parent, y, "Inflatable Gag", "Your owner fits an inflatable gag over your mouth.", "Inflatable-gag-232-with-bg_ergebnis.tga")
        y = AddButton(parent, y, "Inflate Gag", "Your owner inflates your gag.")
        y = AddButton(parent, y, "Deflate Gag", "Your owner deflates your gag.")
        y = y - 4
        y = AddHeader(parent, y, "Remove")
        y = AddButton(parent, y, "Ungag", "Your gag has been removed by your owner. You can speak freely again.")
        y = AddDelayRow(parent, y, "Remove Gag in X Hours", "Your owner set your gag to unlock in %.1f hours (%d) minutes.")
        return y
    end)

    -- Collapsible: Blindfolds (hidden by default)
    local blindfoldBlock = CreateCollapsibleBlock("Blindfolds")
    BuildCollapsibleContent(blindfoldBlock, function(parent, y)
        y = AddHeader(parent, y, "Apply")
        y = AddButton(parent, y, "Light Blindfold", "Your owner put a light blindfold on you.", "Light-Blindfold-232-with-bg_ergebnis.tga")
        y = AddButton(parent, y, "Cute Kitty Blindfold", "Your owner put a cute kitty blindfold on you.", "Cute-Kitty-Blindfold-232-with-bg_ergebnis.tga")
        y = AddButton(parent, y, "Full Blindfold", "Your owner put a full blindfold on you.", "Heavy-Blindfold-232-with-bg_ergebnis.tga")
        y = y - 4
        y = AddHeader(parent, y, "Remove")
        y = AddButton(parent, y, "Remove Blindfold", "Your owner removed your blindfold.")
        y = AddDelayRow(parent, y, "Remove Blindfold in X Hours", "Your owner set your blindfold to unlock in %.1f hours (%d) minutes.")
        return y
    end)

    -- Collapsible: Earmuffs (hidden by default)
    local earmuffsBlock = CreateCollapsibleBlock("Earmuffs")
    BuildCollapsibleContent(earmuffsBlock, function(parent, y)
        y = AddHeader(parent, y, "Apply")
        y = AddButton(parent, y, "Kitten Earmuffs", "Your owner put kitten earmuffs on you.", "Kitten-Earmuffs-bg_ergebnis.tga")
        y = AddButton(parent, y, "Heavy Earmuffs", "Your owner put heavy earmuffs on you, Nyo!!!", "Heav-Earmuffs-bg_ergebnis.tga")
        y = y - 4
        y = AddHeader(parent, y, "Remove")
        y = AddButton(parent, y, "Remove Earmuffs", "Your owner removed your earmuffs. Puhhh~")
        y = AddDelayRow(parent, y, "Remove Earmuffs in X Hours", "Your owner set your earmuffs to unlock in %.1f hours (%d) minutes.")
        return y
    end)

    -- Collapsible: Bells (hidden by default)
    local bellsBlock = CreateCollapsibleBlock("Bells")
    BuildCollapsibleContent(bellsBlock, function(parent, y)
        y = AddHeader(parent, y, "Apply")
        y = AddButton(parent, y, "Attach Bell", "You hear a soft *click* as your owner attaches a tiny bell to your collar. Every step now jingles~", "bell-232-with-bg_ergebnis.tga")
        y = AddButton(parent, y, "Attach Tail Bell", "You hear a soft *click* as your owner attaches a tiny bell to your tail. Every step now jingles~", "tail-bell-232-with-bg_ergebnis.tga")
        y = y - 4
        y = AddHeader(parent, y, "Remove")
        y = AddButton(parent, y, "Remove Bell", "With a gentle touch, your owner removes the bell from your collar. It's quiet again... for now.")
        y = AddDelayRow(parent, y, "Remove Bell in X Hours", "Your owner set your bell to unlock in %.1f hours (%d) minutes.")
        y = AddButton(parent, y, "Remove Tail Bell", "With a gentle touch, your owner removes the tail bell. It's quiet again... for now.")
        y = AddDelayRow(parent, y, "Remove Tail Bell in X Hours", "Your owner set your tail bell to unlock in %.1f hours (%d) minutes.")
        return y
    end)

    -- Collapsible: Mittens (hidden by default)
    local mittensBlock = CreateCollapsibleBlock("Mittens")
    BuildCollapsibleContent(mittensBlock, function(parent, y)
        y = AddHeader(parent, y, "Apply")
        y = AddButton(parent, y, "Lockable Paw Mittens", "Your owner has locked tight paw mittens onto your paws. They are reinforced so you cannot use your paws properly or extend your claws at all.", "locking-paw-mitten-232-with-bg_ergebnis.tga")
        y = AddButton(parent, y, "Squeking Paw Mittens", "Your owner has locked squeking paw mittens onto your paws. They squeak whenever you cast and only swap your spells briefly every 30 seconds.", "paw-mitten-232-with-bg_ergebnis.tga")
        y = y - 4
        y = AddHeader(parent, y, "Remove")
        y = AddButton(parent, y, "Remove Paw Mittens", "Your owner removed your paw mittens. Your paws are free again.")
        y = AddDelayRow(parent, y, "Remove Paw Mittens in X Hours", "Your owner set your paw mittens to unlock in %.1f hours (%d) minutes.")
        return y
    end)

    -- Collapsible: Chastity (hidden by default)
    local chastityBlock = CreateCollapsibleBlock("Chastity")
    BuildCollapsibleContent(chastityBlock, function(parent, y)
        y = AddHeader(parent, y, "Apply")
        y = AddButton(parent, y, "Lock Chastity Belt", "Your owner locked a chastity belt around your hips. Your pleasure is sealed away.", "Chastitybelt.tga")
        y = AddButton(parent, y, "Lock Chastity Bra", "Your owner locked a chastity bra around your chest. Your nipples are sealed away.", "chastitybra.tga")
        y = y - 4
        y = AddHeader(parent, y, "Belt Mode")
        y = AddChastityModeButton(parent, y, "Deny Orgasm", "Your owner set the chastity belt to Deny Orgasm.")
        y = AddChastityModeButton(parent, y, "Allow Orgasm", "Your owner set the chastity belt to Allow Orgasm.")
        y = y - 4
        y = AddHeader(parent, y, "Remove")
        y = AddButton(parent, y, "Remove Chastity Belt", "Your owner removed your chastity belt.")
        y = AddDelayRow(parent, y, "Remove Chastity Belt in X Hours", "Your owner set your chastity belt to unlock in %.1f hours (%d) minutes.")
        y = AddButton(parent, y, "Remove Chastity Bra", "Your owner removed your chastity bra.")
        y = AddDelayRow(parent, y, "Remove Chastity Bra in X Hours", "Your owner set your chastity bra to unlock in %.1f hours (%d) minutes.")
        return y
    end)

    -- Collapsible: Heels (hidden by default)
    local heelsBlock = CreateCollapsibleBlock("Heels")
    BuildCollapsibleContent(heelsBlock, function(parent, y)
        y = AddHeader(parent, y, "Apply")
        y = AddButton(parent, y, "Locking Maid Heels 3-CM", "Your owner locked you into locking maid heels 3-CM. The heels are locked on; the higher the heel, the harder it is to walk.", "maid-heell-232-with-bg_ergebnis.tga")
        y = AddButton(parent, y, "Locking High Heels 8-CM", "Your owner locked you into locking high heels 8-CM. The heels are locked on; the higher the heel, the harder it is to walk.", "heell-232-with-bg_ergebnis.tga")
        y = AddButton(parent, y, "Locking Ballet Boot 12-CM", "Your owner locked you into locking ballet boot 12-CM. The heels are locked on; the higher the heel, the harder it is to walk. Your feet were squeezed into them, and it is going to be painful for an untrained kitten after just a few minutes.", "balletheel-232-with-bg_ergebnis.tga")
        y = y - 4
        y = AddHeader(parent, y, "Remove")
        y = AddButton(parent, y, "Remove Heels", "Your owner removed your heels. Your feet are free again.")
        y = AddDelayRow(parent, y, "Remove Heels in X Hours", "Your owner set your heels to unlock in %.1f hours (%d) minutes.")
        return y
    end)

    -- Collapsible: Tracking (hidden by default)
    local trackingBlock = CreateCollapsibleBlock("Tracking")
    BuildCollapsibleContent(trackingBlock, function(parent, y)
        y = AddHeader(parent, y, "Apply")
        y = AddButton(parent, y, "Attach Tracking Jewel", "Your owner attached a glowing jewel to your collar. Its magic will track your every move!", "jewel-232-with-bg_ergebnis.tga")
        y = y - 4
        y = AddHeader(parent, y, "Remove")
        y = AddButton(parent, y, "Remove Tracking Jewel", "Your owner removed the glowing jewel from your collar. Its magic will no longer track you.")
        return y
    end)

    LayoutControlBlocks()
    tabFrames["Control"] = controlTab

    -- Toys tab
    local toysTab = CreateTabFrame()
    local toysScroll, toysContent = CreateScrollArea(toysTab)

    local toyBlocks = {}
    local LayoutToyBlocks

    local function UpdateToysHeight(totalHeight)
        toysContent:SetHeight(math.max(200, totalHeight))
        if toysScroll.UpdateScrollChildRect then
            toysScroll:UpdateScrollChildRect()
        end
    end

    local function CreateToyCollapsibleBlock(title)
        local block = {
            kind = "collapsible",
            title = title,
            expanded = false,
        }

        block.header = CreateFrame("Button", nil, toysContent, "UIPanelButtonTemplate")
        block.header:SetSize(270, 20)
        local headerFont = block.header:GetFontString()
        if headerFont then
            headerFont:SetJustifyH("LEFT")
        end

        block.content = CreateFrame("Frame", nil, toysContent)
        block.content:SetWidth(300)
        block.content:Hide()

        local function UpdateHeaderVisuals()
            local marker = block.expanded and "[-]" or "[+]"
            block.header:SetText(string.format("%s %s", marker, block.title))
            block.header:SetHeight(20)
            local fontString = block.header:GetFontString()
            if fontString then
                if block.expanded then
                    fontString:SetTextColor(1, 0.82, 0)
                else
                    fontString:SetTextColor(1, 1, 1)
                end
            end
        end

        function block:SetExpanded(expanded)
            self.expanded = expanded and true or false
            self.content:SetShown(self.expanded)
            UpdateHeaderVisuals()
            if LayoutToyBlocks then
                LayoutToyBlocks()
            end
        end

        block.header:SetScript("OnClick", function()
            block:SetExpanded(not block.expanded)
        end)

        UpdateHeaderVisuals()
        table.insert(toyBlocks, block)
        return block
    end

    local function BuildToyCollapsibleContent(block, builder)
        local yBlock = -4
        yBlock = builder(block.content, yBlock)
        block.contentHeight = FinalizeBlockHeight(yBlock)
        block.content:SetHeight(block.contentHeight)
        block.content:Hide()
    end

    LayoutToyBlocks = function()
        local yOffset = -4
        local spacing = 6

        for _, block in ipairs(toyBlocks) do
            block.header:ClearAllPoints()
            block.header:SetPoint("TOPLEFT", toysContent, "TOPLEFT", 0, yOffset)
            yOffset = yOffset - block.header:GetHeight()

            if block.expanded then
                block.content:ClearAllPoints()
                block.content:SetPoint("TOPLEFT", block.header, "BOTTOMLEFT", 0, -2)
                block.content:SetHeight(block.contentHeight or 0)
                block.content:Show()
                yOffset = yOffset - (block.contentHeight or 0) - spacing
            else
                block.content:Hide()
                yOffset = yOffset - spacing
            end
        end

        UpdateToysHeight(-yOffset + 10)
    end

    for _, toy in ipairs(TOY_DEFS) do
        local toyBlock = CreateToyCollapsibleBlock(toy.label)
        BuildToyCollapsibleContent(toyBlock, function(parent, y)
            y = AddToyButton(parent, y, "Apply " .. toy.label, toy, "apply", toy.icon)
            y = AddToyButton(parent, y, "Remove " .. toy.label, toy, "remove")
            if toy.vibe then
                y = AddToyIntensityRow(parent, y, "Vibration intensity", toy, "vibe", 5)
            end
            if toy.shock then
                y = AddToyIntensityRow(parent, y, "Shock intensity", toy, "shock", 3)
            end
            if toy.inflate then
                y = AddToyInflateRow(parent, y, toy)
            end
            return y
        end)
    end

    LayoutToyBlocks()
    tabFrames["Toys"] = toysTab

    -- Discipline tab
    local disciplineTab = CreateTabFrame()
    local disciplineScroll, disciplineContent = CreateScrollArea(disciplineTab)

    local disciplineBlocks = {}
    local LayoutDisciplineBlocks

    local function UpdateDisciplineHeight(totalHeight)
        disciplineContent:SetHeight(math.max(200, totalHeight))
        if disciplineScroll.UpdateScrollChildRect then
            disciplineScroll:UpdateScrollChildRect()
        end
    end

    local function CreateDisciplineCollapsibleBlock(action)
        local block = {
            kind = "collapsible",
            title = action.label,
            icon = action.icon,
            expanded = false,
        }

        block.header = CreateFrame("Button", nil, disciplineContent, "UIPanelButtonTemplate")
        block.header:SetSize(270, 20)
        local headerFont = block.header:GetFontString()
        if headerFont then
            headerFont:SetJustifyH("LEFT")
        end

        block.content = CreateFrame("Frame", nil, disciplineContent)
        block.content:SetWidth(300)
        block.content:Hide()

        local iconPath = block.icon and BuildControlIconPath(block.icon) or nil
        if iconPath then
            block.header:SetScript("OnEnter", function(self)
                ShowControlIconPreview(self, iconPath)
            end)
            block.header:SetScript("OnLeave", function()
                HideControlIconPreview()
            end)
        end

        local function UpdateHeaderVisuals()
            local marker = block.expanded and "[-]" or "[+]"
            block.header:SetText(string.format("%s %s", marker, block.title))
            block.header:SetHeight(20)
            local fontString = block.header:GetFontString()
            if fontString then
                if block.expanded then
                    fontString:SetTextColor(1, 0.82, 0)
                else
                    fontString:SetTextColor(1, 1, 1)
                end
            end
        end

        function block:SetExpanded(expanded)
            self.expanded = expanded and true or false
            self.content:SetShown(self.expanded)
            UpdateHeaderVisuals()
            if LayoutDisciplineBlocks then
                LayoutDisciplineBlocks()
            end
        end

        block.header:SetScript("OnClick", function()
            block:SetExpanded(not block.expanded)
        end)

        UpdateHeaderVisuals()
        table.insert(disciplineBlocks, block)
        return block
    end

    local function BuildDisciplineCollapsibleContent(block, builder)
        local yBlock = -4
        yBlock = builder(block.content, yBlock)
        block.contentHeight = FinalizeBlockHeight(yBlock)
        block.content:SetHeight(block.contentHeight)
        block.content:Hide()
    end

    LayoutDisciplineBlocks = function()
        local yOffset = -4
        local spacing = 6

        for _, block in ipairs(disciplineBlocks) do
            block.header:ClearAllPoints()
            block.header:SetPoint("TOPLEFT", disciplineContent, "TOPLEFT", 0, yOffset)
            yOffset = yOffset - block.header:GetHeight()

            if block.expanded then
                block.content:ClearAllPoints()
                block.content:SetPoint("TOPLEFT", block.header, "BOTTOMLEFT", 0, -2)
                block.content:SetHeight(block.contentHeight or 0)
                block.content:Show()
                yOffset = yOffset - (block.contentHeight or 0) - spacing
            else
                block.content:Hide()
                yOffset = yOffset - spacing
            end
        end

        UpdateDisciplineHeight(-yOffset + 10)
    end

    local function AddDisciplinePartRow(parent, y, action, part)
        local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", 10, y)
        text:SetText(part.label)

        local btnWidth = 22
        local btnHeight = 20
        local startX = 140
        local spacing = 4
        for i = 1, action.maxStrength or 1 do
            local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            btn:SetSize(btnWidth, btnHeight)
            btn:SetPoint("TOPLEFT", startX + (i - 1) * (btnWidth + spacing), y)
            btn:SetText(tostring(i))
            btn:SetScript("OnClick", function()
                SendAddonToKitten(frame.kitten, BuildDisciplineCommand(action.id, part.id, i))
            end)
        end
        return y - 22
    end

    for _, action in ipairs(DISCIPLINE_DEFS) do
        local disciplineBlock = CreateDisciplineCollapsibleBlock(action)
        BuildDisciplineCollapsibleContent(disciplineBlock, function(parent, y)
            for _, part in ipairs(action.parts or {}) do
                y = AddDisciplinePartRow(parent, y, action, part)
            end
            return y
        end)
    end

    LayoutDisciplineBlocks()
    tabFrames["Discipline"] = disciplineTab

    -- Settings tab
    local settingsTab = CreateTabFrame()
    local settingsScroll, settingsContent = CreateScrollArea(settingsTab)
    local y = -4

    y = AddHeader(settingsContent, y, "Debug")
    local debugBox
    debugBox, y = AddCheckbox(
        settingsContent,
        y,
        "Enable debug output",
        function() return CCT_IsDebugEnabled and CCT_IsDebugEnabled() or false end,
        function(value)
            if CCT_SetDebugEnabled then
                CCT_SetDebugEnabled(value)
            end
        end
    )
    y = y - 6

    y = AddHeader(settingsContent, y, "Modules")
    local hpBox
    hpBox, y = AddCheckbox(
        settingsContent,
        y,
        "HeadPetTracker",
        function()
            if CCT_IsModuleEnabled then
                return CCT_IsModuleEnabled("HeadPetTracker")
            end
            return true
        end,
        function(value)
            if CCT_SetModuleEnabled then
                CCT_SetModuleEnabled("HeadPetTracker", value)
            end
        end
    )
    local innBox
    innBox, y = AddCheckbox(
        settingsContent,
        y,
        "InnSlackerTracker",
        function()
            if CCT_IsModuleEnabled then
                return CCT_IsModuleEnabled("InnSlackerTracker")
            end
            return true
        end,
        function(value)
            if CCT_SetModuleEnabled then
                CCT_SetModuleEnabled("InnSlackerTracker", value)
            end
        end
    )
    local petBox
    petBox, y = AddCheckbox(
        settingsContent,
        y,
        "PetTracker (Summon button)",
        function()
            if CCT_IsModuleEnabled then
                return CCT_IsModuleEnabled("PetTracker")
            end
            return true
        end,
        function(value)
            if CCT_SetModuleEnabled then
                CCT_SetModuleEnabled("PetTracker", value)
            end
        end
    )

    local mapBox
    mapBox, y = AddCheckbox(
        settingsContent,
        y,
        "Show tracking path on world map",
        function()
            if CCT_IsModuleEnabled then
                return CCT_IsModuleEnabled("KittenMapShow")
            end
            return false
        end,
        function(value)
            if CCT_SetModuleEnabled then
                CCT_SetModuleEnabled("KittenMapShow", value)
            end
        end
    )

    y = y - 10
    local mapRangeLabel = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mapRangeLabel:SetPoint("TOPLEFT", 0, y)
    mapRangeLabel:SetText("Map history day")
    y = y - 18

    local mapRangeValue = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mapRangeValue:SetPoint("TOPLEFT", 0, y)
    mapRangeValue:SetText("Today")

    local mapRangeSlider = CreateFrame("Slider", "CGCCMapHistorySlider", settingsContent, "OptionsSliderTemplate")
    mapRangeSlider:SetPoint("TOPLEFT", mapRangeValue, "BOTTOMLEFT", 0, -8)
    mapRangeSlider:SetMinMaxValues(0, 30)
    mapRangeSlider:SetValueStep(1)
    mapRangeSlider:SetObeyStepOnDrag(true)
    mapRangeSlider:SetWidth(200)

    if mapRangeSlider.Low then mapRangeSlider.Low:SetText("0") end
    if mapRangeSlider.High then mapRangeSlider.High:SetText("30") end

    local function SetMapRangeText(value)
        local offset = tonumber(value) or 0
        if offset < 0 then offset = 0 end
        if offset > 30 then offset = 30 end
        local dayTime = time() - (offset * 24 * 60 * 60)
        local label = date("%Y-%m-%d", dayTime)
        if offset == 0 then
            mapRangeValue:SetText(label .. " (Today)")
        else
            mapRangeValue:SetText(label .. " (" .. tostring(offset) .. " days ago)")
        end
    end

    local function GetMapHistoryOffset()
        CatgirlSettingsDB = CatgirlSettingsDB or {}
        local val = tonumber(CatgirlSettingsDB.mapHistoryOffsetDays)
        if not val or val < 0 then
            val = 0
        elseif val > 30 then
            val = 30
        end
        return val
    end

    mapRangeSlider:SetScript("OnValueChanged", function(self, value)
        local days = math.floor((tonumber(value) or 0) + 0.5)
        CatgirlSettingsDB = CatgirlSettingsDB or {}
        CatgirlSettingsDB.mapHistoryOffsetDays = days
        SetMapRangeText(days)
    end)

    local initialDays = GetMapHistoryOffset()
    mapRangeSlider:SetValue(initialDays)
    SetMapRangeText(initialDays)

    y = y - 70
    y = y - 6
    y = AddHeader(settingsContent, y, "Maid Tasks")

    local maidInput = CreateFrame("EditBox", nil, settingsContent, "InputBoxTemplate")
    maidInput:SetSize(180, 20)
    maidInput:SetPoint("TOPLEFT", 0, y)
    maidInput:SetAutoFocus(false)
    maidInput:SetText("")

    local maidAddBtn = CreateFrame("Button", nil, settingsContent, "UIPanelButtonTemplate")
    maidAddBtn:SetSize(90, 20)
    maidAddBtn:SetPoint("LEFT", maidInput, "RIGHT", 6, 0)
    maidAddBtn:SetText("Add Task")

    local maidListTopY = y - 26
    local maidListContainer = CreateFrame("Frame", nil, settingsContent)
    maidListContainer:SetPoint("TOPLEFT", 0, maidListTopY)
    maidListContainer:SetWidth(280)
    maidListContainer:SetHeight(24)

    local maidRows = {}
    local maidInstructionUpdating = false

    local maidInstructionHeader = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    maidInstructionHeader:SetPoint("TOPLEFT", maidListContainer, "BOTTOMLEFT", 0, -12)
    maidInstructionHeader:SetText("Maid Instructions")

    local maidInstructionBox = CreateFrame("EditBox", nil, settingsContent, "InputBoxTemplate")
    maidInstructionBox:SetSize(200, 20)
    maidInstructionBox:SetPoint("TOPLEFT", maidInstructionHeader, "BOTTOMLEFT", 0, -6)
    maidInstructionBox:SetAutoFocus(false)
    maidInstructionBox:SetText("")

    local maidSetInstructionBtn = CreateFrame("Button", nil, settingsContent, "UIPanelButtonTemplate")
    maidSetInstructionBtn:SetSize(60, 20)
    maidSetInstructionBtn:SetPoint("LEFT", maidInstructionBox, "RIGHT", 6, 0)
    maidSetInstructionBtn:SetText("Set")

    local maidClearInstructionBtn = CreateFrame("Button", nil, settingsContent, "UIPanelButtonTemplate")
    maidClearInstructionBtn:SetSize(60, 20)
    maidClearInstructionBtn:SetPoint("TOPLEFT", maidInstructionBox, "BOTTOMLEFT", 0, -6)
    maidClearInstructionBtn:SetText("Clear")

    local maidInstructionDisplayHeader = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    maidInstructionDisplayHeader:SetPoint("TOPLEFT", maidClearInstructionBtn, "BOTTOMLEFT", 0, -10)
    maidInstructionDisplayHeader:SetText("Current Instruction")

    local maidInstructionDisplay = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    maidInstructionDisplay:SetPoint("TOPLEFT", maidInstructionDisplayHeader, "BOTTOMLEFT", 0, -4)
    maidInstructionDisplay:SetWidth(280)
    maidInstructionDisplay:SetJustifyH("LEFT")
    maidInstructionDisplay:SetText("None.")

    local maidModuleMissingText = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    maidModuleMissingText:SetPoint("TOPLEFT", maidListContainer, "TOPLEFT", 0, 0)
    maidModuleMissingText:SetWidth(280)
    maidModuleMissingText:SetJustifyH("LEFT")
    maidModuleMissingText:SetText("|cffff5555Maid Tasks module not loaded.|r")
    maidModuleMissingText:Hide()

    local function ClearMaidRows()
        for _, row in ipairs(maidRows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(maidRows)
    end

    local maidSectionTopDepth = -maidListTopY
    local maidInstructionBlockHeight = 180

    local function UpdateSettingsHeight(tasksHeight)
        local newHeight = maidSectionTopDepth + (tasksHeight or 24) + maidInstructionBlockHeight + 80
        settingsContent:SetHeight(math.max(320, newHeight))
    end

    local function MaidModuleAvailable()
        return CCT_MaidTasks_GetOwnerItems and CCT_MaidTasks_AddItem and CCT_MaidTasks_RemoveItemByIndex
    end

    local function GetMaidItems()
        if not CCT_MaidTasks_GetOwnerItems then
            return {}
        end
        local items = CCT_MaidTasks_GetOwnerItems()
        if type(items) ~= "table" then
            return {}
        end
        return items
    end

    local function GetMaidItemCount(item)
        if CCT_MaidTasks_GetOwnerItemCount then
            return CCT_MaidTasks_GetOwnerItemCount(item)
        end
        return 0
    end

    local function RefreshMaidInstructionUI()
        if maidInstructionUpdating then return end
        maidInstructionUpdating = true
        local text = ""
        if CCT_MaidTasks_GetInstructionText then
            text = CCT_MaidTasks_GetInstructionText() or ""
        end
        maidInstructionBox:SetText(text)
        if text and text ~= "" then
            maidInstructionDisplay:SetText(text)
        else
            maidInstructionDisplay:SetText("None.")
        end
        maidInstructionUpdating = false
    end

    local function RefreshMaidTasksUI()
        ClearMaidRows()

        if not MaidModuleAvailable() then
            maidModuleMissingText:Show()
            maidListContainer:SetHeight(24)
            UpdateSettingsHeight(24)
            return
        end

        maidModuleMissingText:Hide()

        local items = GetMaidItems()
        local rowHeight = 22
        local offset = 0

        if #items == 0 then
            local row = CreateFrame("Frame", nil, maidListContainer)
            row:SetSize(280, rowHeight)
            row:SetPoint("TOPLEFT", 0, 0)

            local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("LEFT", 0, 0)
            label:SetWidth(260)
            label:SetJustifyH("LEFT")
            label:SetText("No maid tasks yet. Paste an item and click Add Task.")

            table.insert(maidRows, row)
            offset = rowHeight
        else
            for index, item in ipairs(items) do
                local row = CreateFrame("Frame", nil, maidListContainer)
                row:SetSize(280, rowHeight)
                row:SetPoint("TOPLEFT", 0, -offset)

                local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                label:SetPoint("LEFT", 0, 0)
                label:SetWidth(230)
                label:SetJustifyH("LEFT")
                label:SetText(string.format("%s: %d (synced)", item.displayName or "Unknown", GetMaidItemCount(item)))

                local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                removeBtn:SetSize(22, 18)
                removeBtn:SetPoint("RIGHT", -2, 0)
                removeBtn:SetText("x")
                removeBtn:SetScript("OnClick", function()
                    if CCT_MaidTasks_RemoveItemByIndex then
                        CCT_MaidTasks_RemoveItemByIndex(index)
                    end
                    RefreshMaidTasksUI()
                end)

                table.insert(maidRows, row)
                offset = offset + rowHeight
            end
        end

        local tasksHeight = math.max(rowHeight, offset + 4)
        maidListContainer:SetHeight(tasksHeight)
        UpdateSettingsHeight(tasksHeight)
    end

    local function AddTaskFromInput()
        local text = maidInput:GetText()
        if not text or text == "" then return end
        if CCT_MaidTasks_AddItem then
            CCT_MaidTasks_AddItem(text)
        end
        maidInput:SetText("")
        RefreshMaidTasksUI()
    end

    maidAddBtn:SetScript("OnClick", AddTaskFromInput)
    maidInput:SetScript("OnEnterPressed", AddTaskFromInput)

    maidSetInstructionBtn:SetScript("OnClick", function()
        if CCT_MaidTasks_SetInstructionText then
            CCT_MaidTasks_SetInstructionText(maidInstructionBox:GetText() or "")
        end
        RefreshMaidInstructionUI()
    end)

    maidInstructionBox:SetScript("OnEnterPressed", function()
        if CCT_MaidTasks_SetInstructionText then
            CCT_MaidTasks_SetInstructionText(maidInstructionBox:GetText() or "")
        end
        RefreshMaidInstructionUI()
    end)

    maidClearInstructionBtn:SetScript("OnClick", function()
        maidInstructionBox:SetText("")
        if CCT_MaidTasks_SetInstructionText then
            CCT_MaidTasks_SetInstructionText("")
        end
        RefreshMaidInstructionUI()
    end)

    frame.UpdateMaidTasksUI = RefreshMaidTasksUI
    frame.UpdateMaidInstructionUI = RefreshMaidInstructionUI
    UpdateSettingsHeight(maidListContainer:GetHeight() or 24)
    tabFrames["Settings"] = settingsTab

    local function ShowTab(name)
        for _, tabFrame in pairs(tabFrames) do
            tabFrame:Hide()
        end
        local selected = tabFrames[name]
        if selected then
            selected:Show()
        end
        for tabName, button in pairs(tabButtons) do
            button:SetEnabled(tabName ~= name)
        end
        frame.selectedTab = name
        if name == "Stats" and frame.UpdateStats then
            frame:UpdateStats()
            return
        end
        if name == "Settings" then
            if frame.UpdateMaidInstructionUI then
                frame:UpdateMaidInstructionUI()
            end
            if frame.UpdateMaidTasksUI then
                frame:UpdateMaidTasksUI()
            end
        end
    end

    for name, button in pairs(tabButtons) do
        local tabName = name
        button:SetScript("OnClick", function()
            ShowTab(tabName)
        end)
    end

    ShowTab("Stats")
end

local function GetOpenButtonPosition()
    CatgirlSettingsDB = CatgirlSettingsDB or {}
    CatgirlSettingsDB.cgccOpenButton = CatgirlSettingsDB.cgccOpenButton or {}
    CatgirlSettingsDB.cgccOpenButton[kittyname] = CatgirlSettingsDB.cgccOpenButton[kittyname] or {}
    return CatgirlSettingsDB.cgccOpenButton[kittyname]
end

local function ApplySavedOpenButtonPosition(button)
    if not button then return end
    local db = GetOpenButtonPosition()
    if not db.point then
        button:SetPoint("TOP", 0, -210)
        return
    end
    button:ClearAllPoints()
    button:SetPoint(db.point, UIParent, db.relativePoint or db.point, db.x or 0, db.y or -210)
end

local function SaveOpenButtonPosition(button)
    if not button then return end
    local point, _, relativePoint, xOfs, yOfs = button:GetPoint(1)
    if not point then return end
    local db = GetOpenButtonPosition()
    db.point = point
    db.relativePoint = relativePoint
    db.x = xOfs
    db.y = yOfs
end

local function CreateOpenButton()
    if controlOpenButton then return end
    controlOpenButton = CreateFrame("Button", "CatGirlControlCenterOpenButton", UIParent, "UIPanelButtonTemplate")
    controlOpenButton:SetSize(80, 24)
    ApplySavedOpenButtonPosition(controlOpenButton)
    controlOpenButton:SetText("cgcc")
    controlOpenButton:RegisterForClicks("LeftButtonUp")
    controlOpenButton:SetMovable(true)
    controlOpenButton:EnableMouse(true)
    controlOpenButton:RegisterForDrag("LeftButton")
    controlOpenButton:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    controlOpenButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveOpenButtonPosition(self)
    end)
    controlOpenButton:SetScript("OnClick", function()
        SlashCmdList["CGCC"]()
    end)
end

f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        CreateOpenButton()
    end
end)

-- Slash command handler
SlashCmdList["CGCC"] = function()
    if not IsInGuild() then
        print("|cffff5555[CatGirlControlCenter]|r You are not in a guild.")
        return
    end

    RequestGuildRoster()
    C_Timer.After(1.0, function()
        local kitten = GetAssignedCatgirl()
        if kitten then
            ShowControlPanel(kitten)
        else
            print("|cffff5555[CatGirlControlCenter]|r You don't own a kitten yet!")
            ShowControlPanel(nil)
        end
    end)
end

CCT_AutoPrint("CatGirlControlCenter loaded.")


