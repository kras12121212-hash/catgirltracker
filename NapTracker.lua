local kittyname = UnitName("player")

-- Route module prints through the shared debug gate.
local function AutoPrint(...)
    if CCT_AutoPrint then
        CCT_AutoPrint(...)
    end
end

local print = AutoPrint

local function DebugSay(msg)
    if CCT_IsDebugEnabled and CCT_IsDebugEnabled() then
        SendChatMessage(msg, "SAY")
    end
end

CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}


local onlineTime = 0
local napActive = false
local napDeadline = 0
local napStartTime = nil
local inNapWindow = false
local moveDetected = false
local emoteState = nil
local lastPosition = nil


local napTriggerTime = 0
local function setNextNapTime()
    napTriggerTime = math.random(7200, 18000) -- 2–5 hours
    --napTriggerTime = math.random(7, 18) --  7 to 18 seconds
    onlineTime = 0
    print("Next nap will trigger after", napTriggerTime, "seconds")
end
setNextNapTime()


local function getCurrentZone()
    return GetRealZoneText() or GetZoneText() or "Unknown"
end

local function isResting()
    return IsResting()
end

local function logNapResult(result)
    local entry = {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        --location = getCurrentZone(),
        event = "NapTasks",
        napResult = result
    }
    table.insert(CatgirlBehaviorDB.BehaviorLog[kittyname], entry)
end

local function announceToGuild(msg)
    if IsInGuild() then SendChatMessage(msg, "GUILD") end
end

local function triggerNapWindow()
    RaidNotice_AddMessage(RaidWarningFrame, "Good Kittens need to Nap Nya! Find a Inn to nap for 10 to 20 Minutes", ChatTypeInfo["RAID_WARNING"])
    print("|cffffff00[CatgirlNapTracker]:|r Nap time starts nya~")
    napDeadline = time() + 1800 -- 30 minutes
    inNapWindow = true
end

-- Movement tracking using position
local moveFrame = CreateFrame("Frame")
moveFrame:SetScript("OnUpdate", function()
    local x, y = UnitPosition("player")
    if x and y then
        if lastPosition then
            local dx = x - lastPosition.x
            local dy = y - lastPosition.y
            if (dx ~= 0 or dy ~= 0) and inNapWindow and napActive then
                moveDetected = true
                print("🚶 Nap interrupted by movement!")
                moveFrame:SetScript("OnUpdate", nil) -- stop checking after move
            end
        end
        lastPosition = { x = x, y = y }
    end
end)
moveFrame:SetScript("OnUpdate", nil) -- initially disabled

local function startMovementCheck()
    lastPosition = nil
    moveDetected = false
    moveFrame:SetScript("OnUpdate", function()
        local x, y = UnitPosition("player")
        if x and y then
            if lastPosition then
                local dx = x - lastPosition.x
                local dy = y - lastPosition.y
                if (dx ~= 0 or dy ~= 0) and inNapWindow and napActive then
                    moveDetected = true
                    print("🚶 Nap interrupted by movement!")
                    moveFrame:SetScript("OnUpdate", nil)
                end
            end
            lastPosition = { x = x, y = y }
        end
    end)
end

local function napMonitor()
    if napActive and napStartTime then
        local napDuration = time() - napStartTime
        print(" Nap duration:", napDuration)

        if moveDetected then
            print(" Movement detected during nap")
            napActive = false
            inNapWindow = false
            setNextNapTime()

            if napDuration < 600 then
                print("Woke up too early")
                DebugSay("DEBUG: WokeUpToEarly")
                logNapResult("WokeUpToEarly")
                announceToGuild("Was told to take her kitty Nap but was a cranky kitten that got up to early")
            elseif napDuration > 1200 then
                print("Overslept")
                DebugSay("DEBUG: Oversleept (after move)")
                logNapResult("Oversleept")
                announceToGuild("Was told to take a Nap but decided to sleep all day ! Bad Lazy Kitten !")
            else
                print("Slept as told")
                DebugSay("DEBUG: SleeptAsTold")
                logNapResult("SleeptAsTold")
                announceToGuild("Was a good kitten and took a nap as told make sure to give her headpets and praises Nya")
            end

        elseif napDuration > 1200 then
            print(" Overslept (no movement)")
            napActive = false
            inNapWindow = false
            setNextNapTime()
            DebugSay("DEBUG: Oversleept (no move)")
            logNapResult("Oversleept")
            announceToGuild("Was told to take a Nap but decided to sleep all day ! Bad Lazy Kitten !")
        end

    elseif inNapWindow and not napActive and time() > napDeadline then
        print(" Nap not taken at all")
        inNapWindow = false
        setNextNapTime()
        DebugSay("DEBUG: DidNotSleep")
        logNapResult("DidNotSleep")
        announceToGuild("Was told to take a Nap but did not Listen and should be punished by her owner.")
    end
end



-- Monitor for player emote /sleep
local emoteFrame = CreateFrame("Frame")
emoteFrame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
emoteFrame:SetScript("OnEvent", function(_, _, msg, sender)
    local name = sender:match("^[^%-]+")
    if name == kittyname and msg:lower():find("you fall asleep") and isResting() and inNapWindow then
        if not napActive then
            napStartTime = time()
            napActive = true
            moveDetected = false
            emoteState = "SLEEPING"
            print("|cffffff00[CatgirlNapTracker]:|r Nap started...")
            startMovementCheck()
        end
    end
end)

-- 1s ticker for nap logic


local tickerFrame = CreateFrame("Frame")
local tickerElapsed = 0
tickerFrame:SetScript("OnUpdate", function(_, elapsed)
    tickerElapsed = tickerElapsed + elapsed
    if tickerElapsed >= 1 then
        onlineTime = onlineTime + 1
        -- print(" Time online:", onlineTime)
        if not inNapWindow and onlineTime >= napTriggerTime then
            triggerNapWindow()
        end
        napMonitor()
        tickerElapsed = 0
    end
end)

print("CatgirlNapTracker loaded.")
