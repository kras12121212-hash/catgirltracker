local kittyname = UnitName("player")
local lastAffectionPost = 0

-- Initialize DB structure
CatgirlEmoteDB = CatgirlEmoteDB or {}
CatgirlEmoteDB.EmoteLog = CatgirlEmoteDB.EmoteLog or {}
CatgirlEmoteDB.EmoteLog[kittyname] = CatgirlEmoteDB.EmoteLog[kittyname] or {}

local function IsModuleEnabled()
    return not CCT_IsModuleEnabled or CCT_IsModuleEnabled("HeadPetTracker")
end




local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
f:RegisterEvent("CHAT_MSG_EMOTE")

f:SetScript("OnEvent", function(_, event, msg, sender)
    if not IsModuleEnabled() then return end
    CCT_AutoPrint(" EMOTE RECEIVED:", msg, "FROM:", sender)

    local lowerMsg = msg:lower()
    local now = time()
    local affectionType = nil

    -- Debug: show raw lowercased message
    CCT_AutoPrint(" lowerMsg:", lowerMsg)

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
        CCT_AutoPrint(" Detected affection:", affectionType)

        local success = pcall(function()
            table.insert(CatgirlEmoteDB.EmoteLog[kittyname], {
                timestamp = date("%Y-%m-%d %H:%M"),
                unixtime = now,
                sender = sender,
                action = affectionType,
                synced = 0
            })
        end)
        CCT_AutoPrint(" Log insert:", success)
    
        CCT_AutoPrint(string.format(" Tracked affection from %s: %s", sender, affectionType))
    
        local outMsg
        if affectionType == "Spanked" then
            outMsg = CCT_Msg("HEADPET_SPANKED", sender)
        elseif affectionType == "EarPinch" then
            outMsg = CCT_Msg("HEADPET_EARPINCH", sender)
        else
            outMsg = CCT_Msg("HEADPET_GOOD", affectionType, sender)
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
        CCT_AutoPrint(" No matching affection found in emote.")
    end
end)

CCT_AutoPrint("CatgirlHeadPetTracker loaded.")
