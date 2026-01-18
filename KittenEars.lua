local kittyname = UnitName("player")
local earmuffState = "none"

-- DB Setup
CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

-- Garbling logic
local function garbleIncomingText(msg)
    if earmuffState == "KittenEarmuffs" then
        local nyas = { "nya~", "nyan~", "*nya*", "<3 nya" }
        local words = {}
        for word in msg:gmatch("%S+") do
            table.insert(words, word)
            if math.random() < 0.5 then
                table.insert(words, nyas[math.random(#nyas)])
            end
        end
        return table.concat(words, " ")
    elseif earmuffState == "HeavyEarmuffs" then
        return msg:gsub(".", function()
            return math.random(0,1)==1 and "*" or "~"
        end)
    else
        return msg
    end
end

-- Save new state
local function logEarmuffState(state)
    earmuffState = state
    table.insert(CatgirlBehaviorDB.BehaviorLog[kittyname], {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = "KittenEarmuffs",
        state = state,
        synced = 0
    })
end

-- Restore saved state
local function restoreEarmuffState()
    local log = CatgirlBehaviorDB.BehaviorLog[kittyname]
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "KittenEarmuffs" then
            earmuffState = entry.state
            print("Earmuff state restored:", earmuffState)
            break
        end
    end
end

-- External API
function ApplyEarMuffs(state)
    if state == "KittenEarmuffs" or state == "HeavyEarmuffs" then
        logEarmuffState(state)
        print("Earmuffs applied:", state)
    end
end

function RemoveEarMuffs()
    logEarmuffState("none")
    print("Earmuffs removed")
end

_G.RemoveEarMuffs = RemoveEarMuffs

-- Whisper commands
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:SetScript("OnEvent", function(_, _, msg, sender)
    local s = msg:lower()
    if s:find("kitten earmuffs") then
        ApplyEarMuffs("KittenEarmuffs")
        print("Kitten earmuffs applied. Words sound cuter now nya~")
    elseif s:find("heavy earmuffs") then
        ApplyEarMuffs("HeavyEarmuffs")
        print("Heavy earmuffs secured. Everything sounds like muffled nonsense.")
    elseif s:find("removed your earmuffs") then
        RemoveEarMuffs()
        print("Your earmuffs have been removed.")
    end
end)

-- Incoming message filters
local incomingEvents = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_GUILD"
}

for _, event in ipairs(incomingEvents) do
    ChatFrame_AddMessageEventFilter(event, function(_, _, msg, ...)
        if earmuffState ~= "none" then
            return false, garbleIncomingText(msg), ...
        end
    end)
end

-- Restore earmuff state on login
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    restoreEarmuffState()
end)

print("CatgirlEarMuffTracker loaded and filtering chat.")
