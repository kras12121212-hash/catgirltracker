CatgirlGuildDB = CatgirlGuildDB or {}
CatgirlGuildDB.GuildLog = CatgirlGuildDB.GuildLog or {}
local kittyname = UnitName("player")

CatgirlGuildDB.GuildLog[kittyname] = CatgirlGuildDB.GuildLog[kittyname] or {}

local f = CreateFrame("Frame")

local function logMessage(sender, msg)
    local lowerMsg = msg:lower()
    if lowerMsg:find("WorldBuff") or lowerMsg:find("questie") then return end

    table.insert(CatgirlGuildDB.GuildLog[kittyname], {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        sender = sender,
        message = msg,
        synced = 0
    })
end

f:RegisterEvent("CHAT_MSG_GUILD")
f:RegisterEvent("CHAT_MSG_SYSTEM")

f:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "CHAT_MSG_GUILD" then
        logMessage(arg2 or "Unknown", arg1)
    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = arg1
        if msg:find("has come online") or msg:find("has gone offline") or msg:find("has joined the guild") then
            logMessage("System", msg)
        end
    end
end)

CCT_AutoPrint("CatgirlGuildTracker loaded.")
