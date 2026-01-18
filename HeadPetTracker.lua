local kittyname = UnitName("player")
local lastAffectionPost = 0

-- Initialize DB structure
CatgirlEmoteDB = CatgirlEmoteDB or {}
CatgirlEmoteDB.EmoteLog = CatgirlEmoteDB.EmoteLog or {}
CatgirlEmoteDB.EmoteLog[kittyname] = CatgirlEmoteDB.EmoteLog[kittyname] or {}




local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
f:RegisterEvent("CHAT_MSG_EMOTE")

f:SetScript("OnEvent", function(_, event, msg, sender)
    print(" EMOTE RECEIVED:", msg, "FROM:", sender)

    local lowerMsg = msg:lower()
    local now = time()
    local affectionType = nil

    -- Debug: show raw lowercased message
    print(" lowerMsg:", lowerMsg)

    if lowerMsg:find("pets you") then
        affectionType = "Headpet"
    elseif lowerMsg:find("hugs you") then
        affectionType = "Hug"
    elseif lowerMsg:find("blows you a kiss") then
        affectionType = "kiss"
    elseif lowerMsg:find("spanks you") then
        affectionType = "Spanked"
    elseif lowerMsg:find("pinches your ear") then
        affectionType = "EarPinch"
    end

    -- Debug: did we detect an affection type?
    if affectionType then
        print(" Detected affection:", affectionType)

        local success = pcall(function()
            table.insert(CatgirlEmoteDB.EmoteLog[kittyname], {
                timestamp = date("%Y-%m-%d %H:%M"),
                unixtime = now,
                sender = sender,
                action = affectionType,
                synced = 0
            })
        end)
        print(" Log insert:", success)
    
        print(string.format(" Tracked affection from %s: %s", sender, affectionType))
    
        local outMsg
        if affectionType == "Spanked" then
            outMsg = string.format("Was a Bad Kitten and got spanked from %s", sender)
        elseif affectionType == "EarPinch" then
            outMsg = string.format("Was a Bad Kitten and got pinched in the ear from %s", sender)
        else
            outMsg = string.format("Was a good Kitten and received a %s from %s", affectionType, sender)
        end
        

        if IsInGuild() then
            SendChatMessage(outMsg, "GUILD")
        end
        if IsInRaid() then
            SendChatMessage(outMsg, "RAID")
        elseif IsInGroup() then
            SendChatMessage(outMsg, "PARTY")
        end
        

        lastAffectionPost = now
    else
        print(" No matching affection found in emote.")
    end
end)

print("CatgirlHeadPetTracker loaded.")
