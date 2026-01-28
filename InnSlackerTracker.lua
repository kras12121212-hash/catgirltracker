local kittyname = UnitName("player")
local restingStart = nil
local hasPosted = false
local lastSleepTime = 0

-- Initialize database
CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

local function IsModuleEnabled()
    return not CCT_IsModuleEnabled or CCT_IsModuleEnabled("InnSlackerTracker")
end

-- Cities to exclude
local bigCities = {
    ["Orgrimmar"] = true,
    ["Stormwind City"] = true,
    ["Ironforge"] = true,
    ["Darnassus"] = true,
    ["Undercity"] = true,
    ["Thunder Bluff"] = true,
    ["Shattrath City"] = true,
    ["Silvermoon City"] = true,
    ["The Exodar"] = true,
}

-- Log behavior
local function logSlackingOff(zone, subzone)
    local now = time()
    local timestamp = date("%Y-%m-%d %H:%M")
    local location = (subzone and subzone ~= "") and subzone .. ", " .. zone or zone

    table.insert(CatgirlBehaviorDB.BehaviorLog[kittyname], {
        event = "slagged off",
        location = location,
        unixtime = now,
        timestamp = timestamp,
        synced = 0
    })

    CCT_AutoPrint(" Logged slagging off in:", location)
end

-- Monitor EMOTES for /sleep
local emoteFrame = CreateFrame("Frame")
emoteFrame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
emoteFrame:SetScript("OnEvent", function(_, _, msg, sender)
    if not IsModuleEnabled() then return end
    local lowerMsg = msg:lower()
    local playerName = UnitName("player")
    if sender:find(playerName) and lowerMsg:find("fall asleep") then
        lastSleepTime = time()
        CCT_AutoPrint(" Sleep emote detected, suppressing slacker message for 10 mins.")
    end
end)

-- Main resting logic
C_Timer.NewTicker(10, function()
    if not IsModuleEnabled() then return end
    local zone = GetRealZoneText() or GetZoneText() or "Unknown"
    local subzone = GetSubZoneText() or ""

    if IsResting() then
        CCT_AutoPrint(" Resting detected in:", zone, "/", subzone)

        if not bigCities[zone] then
            if not restingStart then
                restingStart = time()
                CCT_AutoPrint(" Started resting timer...")
            elseif not hasPosted and (time() - restingStart) >= 600 then
                -- Check if recently used /sleep
                if (time() - lastSleepTime) < 1200 then
                    CCT_AutoPrint(" Catgirl is sleeping cutely, not slacking off.")
                else
                    local msg = CCT_Msg("INN_SLACKING")
                    CCT_AutoPrint(" Sending guild message:", msg)
                    if IsInGuild() then SendChatMessage(msg, "GUILD") end

                    logSlackingOff(zone, subzone)
                end
                hasPosted = true
            end
        else
            restingStart = nil
            hasPosted = false
        end
    else
        restingStart = nil
        hasPosted = false
    end
end)

CCT_AutoPrint("Catgirl InnSlackerTracker with sleep emote filter loaded.")
