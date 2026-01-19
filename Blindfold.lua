local kittyname = UnitName("player")
local blindfoldState = "none"
local lastBlindfold = "none"

CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

local function GetBehaviorLog()
    CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}
    return CatgirlBehaviorDB.BehaviorLog[kittyname]
end

-- Get owner from officer note
local function getOwnerFromNote()
    C_GuildInfo.GuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note = GetGuildRosterInfo(i)
        if name and name:match("^[^%-]+") == kittyname and note then
            return note:match("owner=([^,]+)")
        end
    end
end

-- Logging blindfold state
local function logBlindfoldState(state)
    table.insert(GetBehaviorLog(), {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = time(),
        event = "KittenBlindfold",
        BlindfoldState = state,
        synced = 0,
    })
end

-- frame for light/full
local blindfoldFrame = CreateFrame("Frame", "CatgirlBlindfoldOverlay", UIParent, "BackdropTemplate")
blindfoldFrame:SetFrameStrata("FULLSCREEN_DIALOG")
blindfoldFrame:SetAllPoints(UIParent)
blindfoldFrame:Hide()

--  Mask Animation Setup 
local maskFrame = CreateFrame("Frame", "KittenMaskAnimFrame", UIParent)
maskFrame:SetFrameStrata("FULLSCREEN_DIALOG")
maskFrame:SetPoint("CENTER")

local texture = maskFrame:CreateTexture(nil, "BACKGROUND")
texture:SetAllPoints(maskFrame)

local function scaleToScreen()
    local screenW = UIParent:GetWidth()
    local screenH = UIParent:GetHeight()
    local aspect = screenW / screenH
    local targetW, targetH

    if aspect > 2.3 then -- 21:9
        targetH = screenH
        targetW = targetH * (21 / 9)
    else
        targetH = screenH
        targetW = targetH * (16 / 9)
    end

    maskFrame:SetSize(targetW, targetH)
end

local function playMaskAnimation(prefix, count, forward, onComplete)
    scaleToScreen()
    maskFrame:Show()

    local index = forward and 1 or count

    local function step()
        local path = string.format("Interface\\AddOns\\CatgirlTracker\\%s%d.tga", prefix, index)
        texture:SetTexture(path)

        if forward then
            index = index + 1
            if index <= count then
                C_Timer.After(0.3, step)
            elseif onComplete then
                onComplete()
            end
        else
            index = index - 1
            if index >= 1 then
                C_Timer.After(0.3, step)
            else
                texture:SetTexture(nil)
                maskFrame:Hide()
                if onComplete then onComplete() end
            end
        end
    end

    step()
end

function mask()
    local aspect = UIParent:GetWidth() / UIParent:GetHeight()
    if aspect > 2.3 then
        playMaskAnimation("KittenMaskuwZ", 9, true)
    else
        playMaskAnimation("KittenMaskZ", 7, true)
    end
end

function removemask()
    local aspect = UIParent:GetWidth() / UIParent:GetHeight()
    if aspect > 2.3 then
        playMaskAnimation("KittenMaskuwZ", 9, false)
    else
        playMaskAnimation("KittenMaskZ", 7, false)
    end
end

--  Blindfold  Logic===
local function applyBlindfoldVisual(state)
    blindfoldFrame:Hide()
    blindfoldFrame:SetBackdrop(nil)
    blindfoldFrame:EnableMouse(false)

    if state == "light" then
        blindfoldFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
        blindfoldFrame:SetBackdropColor(0, 0, 0, 0.4)
        blindfoldFrame:Show()

    elseif state == "full" then
        blindfoldFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
        blindfoldFrame:SetBackdropColor(0, 0, 0, 1)
        blindfoldFrame:EnableMouse(true)
        blindfoldFrame:Show()

    elseif state == "mask" then
        mask()
    elseif state == "remove" and lastBlindfold == "mask" then
        removemask()
    end

    lastBlindfold = state
end

-- === Public API ===
function BlindfoldSet(state)
    blindfoldState = state
    applyBlindfoldVisual(state)
end


function RemoveBlindfoldbySystem()
        BlindfoldSet("remove")
        logBlindfoldState("remove")
    CCT_AutoPrint("|cffffff00[System]:|r ttttttttt")
    CCT_RaidNotice("Blindfold removed (timer expired).")
end
_G.RemoveBlindfoldbySystem = RemoveBlindfoldbySystem


--  store on Login 
local function restoreBlindfoldState()
    local log = GetBehaviorLog()
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "KittenBlindfold" and entry.BlindfoldState then
            BlindfoldSet(entry.BlindfoldState)
            return
        end
    end
end

--  Whisper Listener 
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(_, event, msg, sender)
    if event == "PLAYER_LOGIN" then
        restoreBlindfoldState()
        return
    end

    local shortSender = sender:match("^[^%-]+")
    local owner = getOwnerFromNote()

    if shortSender:lower() ~= (owner and owner:lower()) then
        print("|cffff0000CatgirlTracker:|r Blindfold ignored: sender is not your owner.")
        return
    end

    if msg:find("light blindfold") then
        BlindfoldSet("light")
        logBlindfoldState("light")
        CCT_RaidNotice("Blindfold applied: light.")
        SendChatMessage("Oh Nyo a blurry light blindfold... should better Behave or it gets worse!", "WHISPER", nil, sender)

    elseif msg:find("kitty blindfold") then
        BlindfoldSet("mask")
        logBlindfoldState("mask")
        CCT_RaidNotice("Blindfold applied: kitty mask.")
        SendChatMessage("Wearing a cute kitty blindfold... vision limited nya~", "WHISPER", nil, sender)

    elseif msg:find("full blindfold") then
        BlindfoldSet("full")
        logBlindfoldState("full")
        CCT_RaidNotice("Blindfold applied: full.")
        SendChatMessage("Can't see anything! It's all black nya!", "WHISPER", nil, sender)

    elseif msg:find("removed your blindfold") then
        BlindfoldSet("remove")
        logBlindfoldState("remove")
        CCT_RaidNotice("Blindfold removed.")
        SendChatMessage("Blindfold removed... finally I can see again nya~", "WHISPER", nil, sender)
    end
end)

CCT_AutoPrint("BlindfoldTracker with animated mask loaded.")
