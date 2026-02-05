local MODULE_NAME = "ChatAdvertise"
local WINDOW_TITLE = "Chat Advertise"
local TIMER_REMINDER = "Timer done nya want to Shutout nya !?"
local WINDOW_WIDTH_EXPANDED = 420
local WINDOW_HEIGHT_EXPANDED = 260
local WINDOW_WIDTH_COLLAPSED = 320
local WINDOW_HEIGHT_COLLAPSED = 90
local WINDOW_PADDING = 12

local kittyname = UnitName("player")
if kittyname then
    kittyname = kittyname:match("^[^%-]+")
end

CatgirlSettingsDB = CatgirlSettingsDB or {}

local window = nil
local timerTicker = nil
local messageBoxes = {}
local timerBox = nil
local timerLabel = nil
local timerButton = nil
local sendButton = nil
local settingsButton = nil
local hintText = nil

local function IsModuleEnabled()
    return not CCT_IsModuleEnabled or CCT_IsModuleEnabled(MODULE_NAME)
end

local function GetState()
    CatgirlSettingsDB = CatgirlSettingsDB or {}
    CatgirlSettingsDB.chatAdvertise = CatgirlSettingsDB.chatAdvertise or {}
    local key = kittyname or "Unknown"
    CatgirlSettingsDB.chatAdvertise[key] = CatgirlSettingsDB.chatAdvertise[key] or {}
    local state = CatgirlSettingsDB.chatAdvertise[key]

    state.lines = state.lines or { "", "", "", "", "" }
    if #state.lines < 5 then
        for i = #state.lines + 1, 5 do
            state.lines[i] = ""
        end
    end

    if state.timerMinutes == nil then
        state.timerMinutes = 0
    end

    if state.showInputs == nil then
        state.showInputs = true
    end

    state.window = state.window or {}
    state.button = state.button or {}

    return state
end

local function ApplySavedWindowPosition(frame)
    if not frame then return end
    local db = GetState().window
    if not db.point then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 160, -200)
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint(db.point, UIParent, db.relativePoint or db.point, db.x or 0, db.y or 0)
end

local function SaveWindowPosition(frame)
    if not frame then return end
    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    if not point then return end
    local db = GetState().window
    db.point = point
    db.relativePoint = relativePoint
    db.x = xOfs
    db.y = yOfs
end

local function ShowTimerReminder()
    local msg = TIMER_REMINDER
    if CCT_RaidNotice then
        CCT_RaidNotice(msg)
    end
    print("|cffffcc00[Chat Advertise]:|r " .. msg)
end

local function StopTimer()
    if timerTicker then
        timerTicker:Cancel()
        timerTicker = nil
    end
end

local function StartTimer(minutes)
    StopTimer()
    local mins = tonumber(minutes)
    if not mins or mins <= 0 then
        return
    end
    local seconds = math.max(1, math.floor(mins * 60 + 0.5))
    timerTicker = C_Timer.NewTicker(seconds, ShowTimerReminder)
end

local function ApplyTimerMinutes(value)
    local state = GetState()
    local mins = tonumber(value)
    if not mins or mins <= 0 then
        state.timerMinutes = 0
        StopTimer()
        return
    end
    state.timerMinutes = mins
    if IsModuleEnabled() then
        StartTimer(mins)
    end
end

local function ApplyTimerFromInput()
    if not timerBox then return end
    ApplyTimerMinutes(timerBox:GetText())
end

local function Trim(text)
    if not text then return "" end
    local cleaned = tostring(text)
    cleaned = cleaned:gsub("^%s+", "")
    cleaned = cleaned:gsub("%s+$", "")
    return cleaned
end

local function ParseChatLine(text)
    local trimmed = Trim(text)
    if trimmed == "" then return nil end

    if trimmed:sub(1, 1) ~= "/" then
        return { chatType = "SAY", message = trimmed }
    end

    local command, rest = trimmed:match("^/(%S+)%s*(.*)$")
    if not command then
        return nil
    end

    local lower = command:lower()
    if lower == "y" or lower == "yell" then
        return { chatType = "YELL", message = rest }
    end
    if lower == "s" or lower == "say" then
        return { chatType = "SAY", message = rest }
    end
    if lower == "g" or lower == "guild" then
        return { chatType = "GUILD", message = rest }
    end
    if lower == "p" or lower == "party" then
        return { chatType = "PARTY", message = rest }
    end
    if lower == "ra" or lower == "raid" then
        return { chatType = "RAID", message = rest }
    end
    if lower == "rw" or lower == "raidwarning" then
        return { chatType = "RAID_WARNING", message = rest }
    end
    if lower == "i" or lower == "instance" then
        return { chatType = "INSTANCE_CHAT", message = rest }
    end
    if lower == "bg" or lower == "battleground" then
        return { chatType = "BATTLEGROUND", message = rest }
    end
    if lower == "w" or lower == "whisper" or lower == "t" or lower == "tell" then
        local target, msg = rest:match("^(%S+)%s+(.+)$")
        if not target or not msg then
            return { error = "Whisper missing target" }
        end
        return { chatType = "WHISPER", message = msg, target = target }
    end

    if lower:match("^%d+$") then
        return { chatType = "CHANNEL", message = rest, channel = tonumber(lower) }
    end

    local channelId = GetChannelName and GetChannelName(command)
    if channelId and channelId > 0 then
        return { chatType = "CHANNEL", message = rest, channel = channelId }
    end

    if rest == "" then
        return { chatType = "SAY", message = trimmed }
    end

    return { chatType = "SAY", message = rest }
end

local function SendParsedLine(entry)
    if not entry or entry.error then
        return false
    end
    local msg = entry.message
    if not msg or msg == "" then
        return false
    end
    if not SendChatMessage then
        return false
    end

    if entry.chatType == "WHISPER" then
        if not entry.target or entry.target == "" then
            return false
        end
        SendChatMessage(msg, "WHISPER", nil, entry.target)
        return true
    end

    if entry.chatType == "CHANNEL" then
        if not entry.channel then
            return false
        end
        SendChatMessage(msg, "CHANNEL", nil, entry.channel)
        return true
    end

    SendChatMessage(msg, entry.chatType)
    return true
end

local function SaveLinesFromUI()
    local state = GetState()
    for i = 1, 5 do
        local box = messageBoxes[i]
        if box then
            state.lines[i] = box:GetText() or ""
        end
    end
end

local function SendAllMessages()
    if not IsModuleEnabled() then return end

    SaveLinesFromUI()

    local state = GetState()
    local sent = 0
    for i = 1, 5 do
        local text = state.lines[i] or ""
        local entry = ParseChatLine(text)
        if entry then
            if entry.error then
                print("|cffff5555[Chat Advertise]:|r " .. entry.error .. " (line " .. i .. ")")
            else
                if SendParsedLine(entry) then
                    sent = sent + 1
                end
            end
        end
    end

    if sent == 0 then
        print("|cffffcc00[Chat Advertise]:|r No messages to send.")
    end
end

local function SetVisible(frame, visible)
    if not frame then return end
    if visible then
        frame:Show()
    else
        frame:Hide()
    end
end

local function ApplyWindowLayout(showInputs)
    if not window then return end
    local expanded = showInputs == true
    local width = expanded and WINDOW_WIDTH_EXPANDED or WINDOW_WIDTH_COLLAPSED
    local height = expanded and WINDOW_HEIGHT_EXPANDED or WINDOW_HEIGHT_COLLAPSED
    window:SetSize(width, height)

    SetVisible(hintText, expanded)
    for i = 1, 5 do
        SetVisible(messageBoxes[i], expanded)
    end
    SetVisible(timerLabel, expanded)
    SetVisible(timerBox, expanded)
    SetVisible(timerButton, expanded)

    if expanded then
        local contentWidth = width - WINDOW_PADDING * 2
        if hintText then
            hintText:SetWidth(contentWidth)
        end
        for i = 1, 5 do
            local box = messageBoxes[i]
            if box then
                box:SetWidth(contentWidth)
            end
        end
    end
end

local function EnsureWindow()
    if window then
        return window
    end

    local state = GetState()

    window = CreateFrame("Frame", "CatgirlChatAdvertiseWindow", UIParent, "BackdropTemplate")
    window:SetFrameStrata("DIALOG")
    window:SetSize(WINDOW_WIDTH_EXPANDED, WINDOW_HEIGHT_EXPANDED)
    window:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    window:SetBackdropColor(0, 0, 0, 0.8)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPosition(self)
    end)

    ApplySavedWindowPosition(window)

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText(WINDOW_TITLE)

    hintText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hintText:SetPoint("TOPLEFT", WINDOW_PADDING, -32)
    hintText:SetWidth(WINDOW_WIDTH_EXPANDED - WINDOW_PADDING * 2)
    hintText:SetJustifyH("LEFT")
    hintText:SetText("Enter messages with chat commands (e.g., /y Hello).")

    local y = -52
    for i = 1, 5 do
        local box = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
        box:SetSize(WINDOW_WIDTH_EXPANDED - WINDOW_PADDING * 2, 20)
        box:SetPoint("TOPLEFT", WINDOW_PADDING, y)
        box:SetAutoFocus(false)
        box:SetText(state.lines[i] or "")
        box:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end
            local db = GetState()
            db.lines[i] = self:GetText()
        end)
        box:SetScript("OnEditFocusLost", function(self)
            local db = GetState()
            db.lines[i] = self:GetText()
        end)
        box:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
        messageBoxes[i] = box
        y = y - 24
    end

    y = y - 4
    timerLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerLabel:SetPoint("TOPLEFT", WINDOW_PADDING, y)
    timerLabel:SetText("Timer minutes")

    timerBox = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    timerBox:SetSize(60, 20)
    timerBox:SetPoint("LEFT", timerLabel, "RIGHT", 8, 0)
    timerBox:SetAutoFocus(false)
    if state.timerMinutes and state.timerMinutes > 0 then
        timerBox:SetText(tostring(state.timerMinutes))
    else
        timerBox:SetText("")
    end
    timerBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        ApplyTimerFromInput()
    end)
    timerBox:SetScript("OnEditFocusLost", function()
        ApplyTimerFromInput()
    end)

    timerButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    timerButton:SetSize(90, 20)
    timerButton:SetPoint("LEFT", timerBox, "RIGHT", 8, 0)
    timerButton:SetText("Set Timer")
    timerButton:SetScript("OnClick", ApplyTimerFromInput)

    y = y - 28
    sendButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    sendButton:SetSize(160, 24)
    sendButton:SetPoint("BOTTOM", window, "BOTTOM", -56, 12)
    sendButton:SetText("Kitten scream!")
    sendButton:SetScript("OnClick", SendAllMessages)

    settingsButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    settingsButton:SetSize(90, 24)
    settingsButton:SetPoint("LEFT", sendButton, "RIGHT", 8, 0)
    settingsButton:SetText("Settings")
    settingsButton:SetScript("OnClick", function()
        local db = GetState()
        db.showInputs = not db.showInputs
        ApplyWindowLayout(db.showInputs)
    end)

    window:SetScript("OnShow", function()
        local db = GetState()
        ApplyWindowLayout(db.showInputs)
        for i = 1, 5 do
            if messageBoxes[i] then
                messageBoxes[i]:SetText(db.lines[i] or "")
            end
        end
        if timerBox then
            if db.timerMinutes and db.timerMinutes > 0 then
                timerBox:SetText(tostring(db.timerMinutes))
            else
                timerBox:SetText("")
            end
        end
    end)

    window:SetScript("OnHide", function()
        SaveLinesFromUI()
    end)

    ApplyWindowLayout(state.showInputs)

    window:Hide()

    return window
end

local function ApplyModuleState(enabled)
    if enabled then
        local frame = EnsureWindow()
        frame:Show()
        local state = GetState()
        StartTimer(state.timerMinutes)
    else
        if window then
            window:Hide()
        end
        StopTimer()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    ApplyModuleState(IsModuleEnabled())
    if CCT_RegisterModuleWatcher then
        CCT_RegisterModuleWatcher(MODULE_NAME, function(enabled)
            ApplyModuleState(enabled)
        end)
    end
end)

if CCT_AutoPrint then
    CCT_AutoPrint("Chat Advertise module loaded.")
end
