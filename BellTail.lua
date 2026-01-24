local kittyname = UnitName("player")
local tailBellActive = false
local tailBellTimerScheduled = false

-- DB Setup
CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

local function GetBehaviorLog()
    CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}
    return CatgirlBehaviorDB.BehaviorLog[kittyname]
end

--ereminder UI
local reminder = CreateFrame("Frame", nil, UIParent)
reminder:SetSize(400, 30)
reminder:SetPoint("TOP", UIParent, "TOP", 0, -60)
local text = reminder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text:SetText("Kitten is wearing a tail bell; it will ring with every step.")
text:SetPoint("CENTER")
reminder:Hide()

-- Get owner from officer note
function getOwnerFromNote()
    C_GuildInfo.GuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note = GetGuildRosterInfo(i)
        if name and name:match("^[^%-]+") == kittyname and note then
            return note:match("owner=([^,]+)")
        end
    end
end

-- Tail bell trigger
local function TriggerBellEvent()
    if not tailBellActive then return end
    if IsPlayerMoving and not IsPlayerMoving() then return end

    PlaySoundFile("Interface\\AddOns\\CatgirlTracker\\Sounds\\sbell4seconds.ogg", "Master")

end

-- bell RP Timer
local function scheduleNextBell()
    if tailBellTimerScheduled then return end
    tailBellTimerScheduled = true

    local delay = math.random(5, 6) -- 5 to 6 seconds
    CCT_AutoPrint("|cffffff00CatgirlTracker:|r Tail bell will jingle frequently")

    C_Timer.After(delay, function()
        tailBellTimerScheduled = false
        if tailBellActive then
            TriggerBellEvent()
        end
        scheduleNextBell()
    end)
end

-- og Bell State
local function logTailBellState(state)
    tailBellActive = state
    table.insert(GetBehaviorLog(), {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = "TailBellState",
        state = state,
        synced = 0
    })
end

local function restoreBellState()
    local log = GetBehaviorLog()
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "TailBellState" and type(entry.state) == "boolean" then
            if entry.state then
                tailBellActive = true
                reminder:Show()
                scheduleNextBell()
                CCT_AutoPrint("|cffffff00CatgirlTracker:|r Restored tail bell state: ON")
            else
                tailBellActive = false
                reminder:Hide()
                CCT_AutoPrint("|cffffff00CatgirlTracker:|r Restored tail bell state: OFF")
            end
            break
        end
    end
end

 --Whisper ogin
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(_, event, msg, sender)
    if event == "PLAYER_LOGIN" then
        -- Restore after all 
        C_Timer.After(2, restoreBellState)
        return
    end

    if event == "CHAT_MSG_WHISPER" and msg and sender then
        local shortName = sender:match("^[^%-]+")
        local owner = getOwnerFromNote() or ""
        local lower = msg:lower()

        if lower:find("tiny bell to your tail") and shortName == owner then
            logTailBellState(true)
            reminder:Show()
            scheduleNextBell()
            print("|cffffff00CatgirlTracker:|r You now wear a jingling tail bell nya...")
            CCT_RaidNotice("Tail bell attached.")
        elseif lower:find("removes the tail bell") and shortName == owner then
            logTailBellState(false)
            reminder:Hide()
            print("|cffffff00CatgirlTracker:|r The tail bell has been removed... you're safe for now nya.")
            CCT_RaidNotice("Tail bell removed.")
        end
    end
end)

_G.TriggerTailBellEvent = TriggerBellEvent
_G.SetTailBellActive = function(state)
    logTailBellState(state)
    if state then
        reminder:Show()
        scheduleNextBell()
    else
        reminder:Hide()
    end
end

            logTailBellState(false)
            reminder:Hide()

function RemoveTailBellSystem()
    logTailBellState(false)
    reminder:Hide()
    CCT_AutoPrint("|cffffff00[System]:|r Your tail bell has been automatically removed nya~")
    CCT_RaidNotice("Tail bell removed (timer expired).")
end
_G.RemoveTailBellSystem = RemoveTailBellSystem

CCT_AutoPrint("Tail Bell RP Module loaded.")
