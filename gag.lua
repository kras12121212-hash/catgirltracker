local kittyname = UnitName("player")
gagState = "none"

-- Setup DB
CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

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

-- Owner lookup from note
local function getOwnerFromNote()
    C_GuildInfo.GuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note = GetGuildRosterInfo(i)
        if name and name:match("^[^%-]+") == kittyname and note then
            return note:match("owner=([^,]+)")
        end
    end
end

-- Log gag state
       function logGagState(state)
    table.insert(CatgirlBehaviorDB.BehaviorLog[kittyname], {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = "KittenGag",
        Gagstate = state,
        synced = 0,
    })
end

-- Restore gag state on login
local function restoreGagState()
    local log = CatgirlBehaviorDB.BehaviorLog[kittyname]
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "KittenGag" then
            if entry.Gagstate == "Gag" then
                gagState = "huge"
                print(" Re-applying huge gag from previous session")
            elseif entry.Gagstate == "LightGag" then
                gagState = "small"
                print(" Re-applying light gag from previous session")
            elseif entry.Gagstate == "FullBlock" then
                gagState = "fullblock"
                print(" Re-applying full mask gag from previous session")
            elseif entry.Gagstate == "NyaMask" then
                gagState = "nyamask"
                print(" Re-applying Cute Nya Mask from previous session")
            else
                gagState = "none"
            end
            return
        end
    end
    gagState = "none"
end

function RemoveGagBySystem()
    gagState = "none"
    logGagState("UnGag")
    print("|cffffff00[System]:|r Your gag has been automatically removed nya~")
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
            print("|cffff0000CatgirlTracker:|r Gag ignored: sender is not your owner.")
            return
        end

        if msg:find("secured a heavy gag") then
            gagState = "huge"
            logGagState("Gag")
            print("|cffff66ccCatgirlTracker:|r You've been heavily gagged nya~")
            SendChatMessage("Has been gagged with a huge gag NYA!!! She's already whimpering... );", "WHISPER", nil, sender)

        elseif msg:find("small silken gag") then
            gagState = "small"
            logGagState("LightGag")
            print("|cffcc88ffCatgirlTracker:|r A small gag muffles your words...")
            SendChatMessage("Has been gagged with a small gag. Hopefully that will be a lesson.", "WHISPER", nil, sender)

        elseif msg:find("gag and") then
            gagState = "fullblock"
            logGagState("FullBlock")
            print("|cffff0000CatgirlTracker:|r You've been fully muzzled. No words can escape now!")
            SendChatMessage("She has been fully masked and gagged... not a sound can escape! Nya~", "WHISPER", nil, sender)

        elseif msg:find("gag has been removed") then
            gagState = "none"
            logGagState("none")
            print("|cffaaffaaCatgirlTracker:|r You've been ungagged nya~")
            SendChatMessage("Has been ungagged. She may speak freely again~", "WHISPER", nil, sender)

        elseif msg:find("cute~") then
            gagState = "nyamask"
            logGagState("NyaMask")
            print("|cffff88eeCatgirlTracker:|r You’re overcome with the urge to add ~Nya~ to everything!")
            SendChatMessage("Has been given a cute kitten mask. She's meowing every sentence! UwU", "WHISPER", nil, sender)
        end
    end
end)



-- Start a repeating check every 5 seconds


-- Capture original SendChatMessage once
local originalSendChatMessage = originalSendChatMessage or SendChatMessage

-- Final safe override with gag logic
SendChatMessage = function(msg, chatType, language, channel)
    local isSpeech = chatType == "SAY" or chatType == "YELL" or chatType == "PARTY" or chatType == "RAID" or chatType == "GUILD"

    if gagState == "fullblock" and isSpeech then
        print("|cffff0000CatgirlTracker:|r Your mask prevents you from speaking at all!")
        return -- BLOCK ENTIRELY
    end

    if gagState ~= "none" and isSpeech then
        if gagState == "huge" then
            local gags = { "mmf~", "mrrgghh~", "nnyaa-mmm!", "mmph!", "grrrgh~", "hnnnng~" }
            msg = string.rep(gags[math.random(#gags)] .. " ", math.random(1, 3))
        elseif gagState == "small" then
            msg = convertToLightGagSpeech(msg)
        elseif gagState == "nyamask" then
            msg = CuteNyaGarble(msg)
        end
    end

    originalSendChatMessage(msg, chatType, language, channel)
end

print("GagTracker with Cute Nya Mask loaded.")
