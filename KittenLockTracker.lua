local kittyname = UnitName("player")
CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

local activeTimers = {}

local function logBindState(bind, minutes)
    local now = time()
    CatgirlBehaviorDB.BehaviorLog[kittyname][bind] = {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = now,
        event = "KittenLock",
        bind = bind,
        durationMinutes = minutes,
        unlockAt = now + (minutes * 60),
        synced = 0,
    }
end


local function bindUnlockedMessage(bind)
    if bind == "gag" then
        RemoveGagBySystem()
        CCT_AutoPrint("|cffffff00[System]:|r Your gag lock has expired!")

    elseif bind == "earmuffs" then
        RemoveEarMuffs(true)
        CCT_AutoPrint("|cff88ccff[System]:|r Your earmuffs were removed as the timer expired.")

    elseif bind == "blindfold" then
        RemoveBlindfoldbySystem()
        CCT_AutoPrint("|cffff99ff[System]:|r The blindfold timer ended. You can see again!")

    elseif bind == "bell" then
        RemoveBellSystem()
        CCT_AutoPrint("|cffffcc00[System]:|r The bell fell off as the time ran out.")

    elseif bind == "tailbell" then
        RemoveTailBellSystem()
        CCT_AutoPrint("|cffffcc00[System]:|r The tail bell fell off as the time ran out.")

    elseif bind == "mittens" then
        RemovePawMittensBySystem()
        CCT_AutoPrint("|cffffff00[System]:|r The paw mittens lock timer ended.")

    else
        CCT_AutoPrint("|cffff0000[System]:|r Unknown bind '" .. bind .. "' unlocked.")
    end
end


local function startBindTimer(bind)
    if activeTimers[bind] then
        activeTimers[bind]:Cancel()
    end

    local entry = CatgirlBehaviorDB.BehaviorLog[kittyname][bind]
    if not entry or not entry.unlockAt then return end

    local function update()
        local now = time()
        local remaining = entry.unlockAt - now
        if remaining <= 0 then
            activeTimers[bind]:Cancel()
            activeTimers[bind] = nil
            CatgirlBehaviorDB.BehaviorLog[kittyname][bind] = nil
            bindUnlockedMessage(bind)
        end
    end

    activeTimers[bind] = C_Timer.NewTicker(1, update)
end

-- Resume on login
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    for bind, entry in pairs(CatgirlBehaviorDB.BehaviorLog[kittyname]) do
        if entry.unlockAt and time() < entry.unlockAt then
            startBindTimer(bind)
        end
    end
end)

-- Whisper parser
local function parseBindWhisper(msg)
    local minutes = tonumber(msg:match("%((%d+)%)"))
    if not minutes then return end

    local bindType = nil
    if msg:find("gag to unlock") then bindType = "gag"
    elseif msg:find("earmuffs to unlock") then bindType = "earmuffs"
    elseif msg:find("blindfold to unlock") then bindType = "blindfold"
    elseif msg:find("paw mittens to unlock") then bindType = "mittens"
    elseif msg:find("tail bell to unlock") then bindType = "tailbell"
    elseif msg:find("bell to unlock") then bindType = "bell"
    end

    if bindType and minutes then
        logBindState(bindType, minutes)
        startBindTimer(bindType)
    end
end

-- Whisper listener
local whisperFrame = CreateFrame("Frame")
whisperFrame:RegisterEvent("CHAT_MSG_WHISPER")
whisperFrame:SetScript("OnEvent", function(_, _, msg)
    parseBindWhisper(msg)
end)

