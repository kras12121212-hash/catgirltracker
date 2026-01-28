local kittyname = UnitName("player")
gagState = "none"
local inflatableStage = 0
local inflatableDroolTicker = nil

-- Setup DB
CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

local function GetBehaviorLog()
    CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}
    return CatgirlBehaviorDB.BehaviorLog[kittyname]
end

-- Create main frame
local gagFrame = CreateFrame("Frame")
gagFrame:RegisterEvent("CHAT_MSG_WHISPER")
gagFrame:RegisterEvent("PLAYER_LOGIN")

-- Cute Nya emotes
local cuteEmotes = {
    "(=^-ω-^=)", "(* >ω<)", "UwU", "⁄•⁄ω⁄•⁄ ⁄)", "(=^w^=)", "~Nya~",
    "(=^ω^=)", "UwU~", "(*≧ω≦)", "(=^-^=)", "~(=^・ω・^)", ":3", "^_^", "owo", "~nya nya~"
}

-- Cute mask garble
local function CuteNyaGarble(msg)
    local words = {}
    for word in msg:gmatch("%S+") do
        table.insert(words, word)
        if math.random() < 0.3 then
            table.insert(words, "~Nya~")
        end
    end
    local joined = table.concat(words, " ")
    return joined:gsub("([%.%!%?])", function(punct)
        return punct .. " " .. cuteEmotes[math.random(#cuteEmotes)]
    end)
end

-- Garble heavy gag
local function GarbleText(text)
    return text:gsub("%S+", function()
        return "m" .. ("f"):rep(math.random(2, 4)) .. "~"
    end)
end

-- Light gag translator
local function convertToLightGagSpeech(msg)
    local repl = { ["s"] = "sh", ["r"] = "h", ["l"] = "w", ["b"] = "bh", ["t"] = "th", ["c"] = "k" }
    return msg:gsub(".", function(c)
        local lower = c:lower()
        return repl[lower] and (c:match("%u") and repl[lower]:upper() or repl[lower]) or c
    end) .. " nya~"
end

local function InflatableGarble(msg, stage)
    if stage <= 1 then
        if math.random() < 0.3 then
            return msg .. " mmf~"
        end
        return msg
    elseif stage == 2 then
        return convertToLightGagSpeech(msg)
    elseif stage == 3 then
        local words = {}
        for word in msg:gmatch("%S+") do
            if math.random() < 0.4 then
                table.insert(words, "mmf~")
            else
                table.insert(words, word)
            end
        end
        return convertToLightGagSpeech(table.concat(words, " "))
    elseif stage == 4 then
        return GarbleText(msg)
    else
        return string.rep("mmmm~ ", math.random(3, 6))
    end
end

-- Owner lookup from note
local function getOwnerFromNote()
    if not IsInGuild() then
        return nil
    end

    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end

    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note, officerNote = GetGuildRosterInfo(i)
        if name and name:match("^[^%-]+") == kittyname then
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

-- Log gag state
       function logGagState(state)
    table.insert(GetBehaviorLog(), {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = "KittenGag",
        Gagstate = state,
        synced = 0,
    })
end

local function StopInflatableDrool()
    if inflatableDroolTicker then
        inflatableDroolTicker:Cancel()
        inflatableDroolTicker = nil
    end
end

local function GetInflatableDroolInterval(stage)
    local minutes = 7 - stage
    if minutes < 2 then
        minutes = 2
    end
    return minutes * 60
end

local function StartInflatableDrool()
    StopInflatableDrool()
    if gagState ~= "inflatable" or inflatableStage < 1 then
        return
    end
    local interval = GetInflatableDroolInterval(inflatableStage)
    inflatableDroolTicker = C_Timer.NewTicker(interval, function()
        if gagState ~= "inflatable" or inflatableStage < 1 then
            StopInflatableDrool()
            return
        end
        if DoEmote then
            DoEmote("DROOL")
        end
    end)
end

local function ClearInflatableGag()
    inflatableStage = 0
    StopInflatableDrool()
end

local function SetInflatableStage(stage, shouldLog)
    if type(stage) ~= "number" then
        return
    end
    if stage < 1 then
        stage = 1
    elseif stage > 5 then
        stage = 5
    end
    inflatableStage = stage
    gagState = "inflatable"
    if shouldLog then
        logGagState("Inflatable:" .. stage)
    end
    StartInflatableDrool()
end

-- Restore gag state on login
local function restoreGagState()
    local log = GetBehaviorLog()
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "KittenGag" then
            ClearInflatableGag()
            if entry.Gagstate == "Gag" then
                gagState = "huge"
                CCT_AutoPrint(" Re-applying huge gag from previous session")
            elseif entry.Gagstate == "LightGag" then
                gagState = "small"
                CCT_AutoPrint(" Re-applying light gag from previous session")
            elseif entry.Gagstate == "FullBlock" then
                gagState = "fullblock"
                CCT_AutoPrint(" Re-applying full mask gag from previous session")
            elseif entry.Gagstate == "NyaMask" then
                gagState = "nyamask"
                CCT_AutoPrint(" Re-applying Cute Nya Mask from previous session")
            elseif type(entry.Gagstate) == "string" and entry.Gagstate:match("^Inflatable:") then
                local stage = tonumber(entry.Gagstate:match("^Inflatable:(%d+)")) or 1
                SetInflatableStage(stage, false)
                CCT_AutoPrint(string.format(" Re-applying inflatable gag (stage %d) from previous session", inflatableStage))
            else
                gagState = "none"
            end
            return
        end
    end
    gagState = "none"
    ClearInflatableGag()
end

function RemoveGagBySystem()
    gagState = "none"
    ClearInflatableGag()
    logGagState("UnGag")
    CCT_AutoPrint("|cffffff00[System]:|r Your gag has been automatically removed nya~")
    CCT_RaidNotice("Gag removed (timer expired).")
end

_G.RemoveGagBySystem = RemoveGagBySystem

-- Handle whisper commands
gagFrame:SetScript("OnEvent", function(_, event, arg1, sender)
    if event == "PLAYER_LOGIN" then
        restoreGagState()
        return
    end

    if event == "CHAT_MSG_WHISPER" then
        local msg = arg1:lower()
        local shortSender = sender:match("^[^%-]+")
        local owner = getOwnerFromNote()

        if shortSender:lower() ~= (owner and owner:lower()) then
            CCT_AutoPrint("|cffff0000CatgirlTracker:|r Gag ignored: sender is not your owner.")
            return
        end

        if msg:find("secured a heavy gag") then
            gagState = "huge"
            ClearInflatableGag()
            logGagState("Gag")
            print("|cffff66ccCatgirlTracker:|r You've been heavily gagged nya~")
            CCT_RaidNotice("Gag applied: heavy gag.")
            SendChatMessage(CCT_Msg("GAG_HEAVY"), "WHISPER", nil, sender)

        elseif msg:find("small silken gag") then
            gagState = "small"
            ClearInflatableGag()
            logGagState("LightGag")
            print("|cffcc88ffCatgirlTracker:|r A small gag muffles your words...")
            CCT_RaidNotice("Gag applied: small gag.")
            SendChatMessage(CCT_Msg("GAG_SMALL"), "WHISPER", nil, sender)

        elseif msg:find("gag and") then
            gagState = "fullblock"
            ClearInflatableGag()
            logGagState("FullBlock")
            print("|cffff0000CatgirlTracker:|r You've been fully muzzled. No words can escape now!")
            CCT_RaidNotice("Gag applied: full mask gag.")
            SendChatMessage(CCT_Msg("GAG_FULLBLOCK"), "WHISPER", nil, sender)

        elseif msg:find("inflatable gag") then
            SetInflatableStage(1, true)
            print("|cffcc88ffCatgirlTracker:|r An inflatable gag fills your mouth... it's only a little swollen.")
            CCT_RaidNotice("Gag applied: inflatable (stage 1).")
            SendChatMessage(CCT_Msg("GAG_INFLATABLE"), "WHISPER", nil, sender)

        elseif msg:find("inflate") and msg:find("gag") then
            if gagState ~= "inflatable" then
                SetInflatableStage(1, true)
            else
                local nextStage = math.min(inflatableStage + 1, 5)
                if nextStage ~= inflatableStage then
                    SetInflatableStage(nextStage, true)
                end
            end
            print("|cffff99ffCatgirlTracker:|r The inflatable gag swells tighter in your mouth...")
            CCT_RaidNotice(string.format("Gag inflated to stage %d.", inflatableStage))
            SendChatMessage(CCT_Msg("GAG_INFLATE"), "WHISPER", nil, sender)

        elseif msg:find("deflate") and msg:find("gag") then
            if gagState == "inflatable" then
                local nextStage = math.max(inflatableStage - 1, 1)
                if nextStage ~= inflatableStage then
                    SetInflatableStage(nextStage, true)
                end
                print("|cff88ffccCatgirlTracker:|r The inflatable gag softens and loosens a bit...")
                CCT_RaidNotice(string.format("Gag deflated to stage %d.", inflatableStage))
                SendChatMessage(CCT_Msg("GAG_DEFLATE"), "WHISPER", nil, sender)
            end

        elseif msg:find("gag has been removed") then
            gagState = "none"
            ClearInflatableGag()
            logGagState("none")
            print("|cffaaffaaCatgirlTracker:|r You've been ungagged nya~")
            CCT_RaidNotice("Gag removed.")
            SendChatMessage(CCT_Msg("GAG_REMOVE"), "WHISPER", nil, sender)

        elseif msg:find("cute~") then
            gagState = "nyamask"
            ClearInflatableGag()
            logGagState("NyaMask")
            CCT_RaidNotice("Gag applied: cute mask.")
            print("|cffff88eeCatgirlTracker:|r You’re overcome with the urge to add ~Nya~ to everything!")
            SendChatMessage(CCT_Msg("GAG_NYAMASK"), "WHISPER", nil, sender)
        end
    end
end)



-- Start a repeating check every 5 seconds


-- Capture original SendChatMessage once
local originalSendChatMessage = originalSendChatMessage or SendChatMessage

-- Final safe override with gag logic
local function IsSpeechChatType(chatType)
    return chatType == "SAY"
        or chatType == "YELL"
        or chatType == "PARTY"
        or chatType == "PARTY_LEADER"
        or chatType == "RAID"
        or chatType == "RAID_LEADER"
        or chatType == "INSTANCE_CHAT"
        or chatType == "INSTANCE_CHAT_LEADER"
        or chatType == "GUILD"
        or chatType == "OFFICER"
end

local function ApplyGagToMessage(msg, chatType)
    if gagState == "fullblock" and IsSpeechChatType(chatType) then
        print("|cffff0000CatgirlTracker:|r Your mask prevents you from speaking at all!")
        return nil, true
    end

    if gagState ~= "none" and IsSpeechChatType(chatType) then
        if gagState == "huge" then
            local gags = { "mmf~", "mrrgghh~", "nnyaa-mmm!", "mmph!", "grrrgh~", "hnnnng~" }
            msg = string.rep(gags[math.random(#gags)] .. " ", math.random(1, 3))
        elseif gagState == "small" then
            msg = convertToLightGagSpeech(msg)
        elseif gagState == "nyamask" then
            msg = CuteNyaGarble(msg)
        elseif gagState == "inflatable" then
            local stage = inflatableStage > 0 and inflatableStage or 1
            msg = InflatableGarble(msg, stage)
        end
    end

    return msg, false
end

local inGagSend = false

SendChatMessage = function(msg, chatType, language, channel)
    if IsSpeechChatType(chatType) then
        local updated, blocked = ApplyGagToMessage(msg, chatType)
        if blocked then
            return -- BLOCK ENTIRELY
        end
        msg = updated
    end
    inGagSend = true
    local ok = originalSendChatMessage(msg, chatType, language, channel)
    inGagSend = false
    return ok
end

if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
    local originalCChatInfoSendChatMessage = C_ChatInfo.SendChatMessage
    C_ChatInfo.SendChatMessage = function(msg, chatType, language, channel)
        if not inGagSend and IsSpeechChatType(chatType) then
            local updated, blocked = ApplyGagToMessage(msg, chatType)
            if blocked then
                return -- BLOCK ENTIRELY
            end
            msg = updated
        end
        return originalCChatInfoSendChatMessage(msg, chatType, language, channel)
    end
end

CCT_AutoPrint("GagTracker with Cute Nya Mask and inflatable gag loaded.")
