local kittyname = UnitName("player")
local bellActive = false
local bellTimerScheduled = false

-- DB Setup
CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

--ereminder UI
local reminder = CreateFrame("Frame", nil, UIParent)
reminder:SetSize(400, 30)
reminder:SetPoint("TOP", UIParent, "TOP", 0, -50)
local text = reminder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text:SetText("Kitten is wearing a bell... it might ring at the wrong moment nya.")
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

--   Bell Trigger
local function TriggerBellEvent()
    if not bellActive then return end

    PlaySoundFile("Interface\\AddOns\\CatgirlTracker\\Sounds\\Bell.ogg", "Master")
    print("|cffffff00CatgirlTracker:|r The bell on your collar jingles softly nya...")

    table.insert(CatgirlBehaviorDB.BehaviorLog[kittyname], {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = "BellJingle",
    })
end

-- bell RP Timer
local function scheduleNextBell()
    if bellTimerScheduled then return end
    bellTimerScheduled = true

    local delay = math.random(120, 300) -- 2 to 5 minutes
    print("|cffffff00CatgirlTracker:|r Bell will jingle from time to time")

    C_Timer.After(delay, function()
        bellTimerScheduled = false
        if bellActive then
            TriggerBellEvent()
        end
        scheduleNextBell()
    end)
end

-- og Bell State
local function logBellState(state)
    bellActive = state
    table.insert(CatgirlBehaviorDB.BehaviorLog[kittyname], {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = "BellState",
        state = state,
        synced = 0
    })
end

local function restoreBellState()
    local log = CatgirlBehaviorDB.BehaviorLog[kittyname]
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "BellState" and type(entry.state) == "boolean" then
            if entry.state then
                bellActive = true
                reminder:Show()
                scheduleNextBell()
                print("|cffffff00CatgirlTracker:|r Restored bell state: ON")
            else
                bellActive = false
                reminder:Hide()
                print("|cffffff00CatgirlTracker:|r Restored bell state: OFF")
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

        if lower:find("tiny bell to your collar") and shortName == owner then
            logBellState(true)
            reminder:Show()
            scheduleNextBell()
            print("|cffffff00CatgirlTracker:|r You now wear a jingling bell on your collar nya...")
        elseif lower:find("removes the bell") and shortName == owner then
            logBellState(false)
            reminder:Hide()
            print("|cffffff00CatgirlTracker:|r The bell has been removed... you're safe for now nya.")
        end
    end
end)

_G.TriggerBellEvent = TriggerBellEvent
_G.SetBellActive = function(state)
    logBellState(state)
    if state then
        reminder:Show()
        scheduleNextBell()
    else
        reminder:Hide()
    end
end

            logBellState(false)
            reminder:Hide()

function RemoveBellSystem()
    logBellState(false)
    reminder:Hide()
    print("|cffffff00[System]:|r Your bell  has been automatically removed nya~")
end
_G.RemoveBellSystem = RemoveBellSystem

print("Bell Collar RP Module loaded.")
