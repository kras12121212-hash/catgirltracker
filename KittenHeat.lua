local kittyname = UnitName("player")

local function GetNow()
    if GetTime then
        return GetTime()
    end
    return time()
end

local function GetUnixTime()
    if time then
        return time()
    end
    return 0
end

CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

CatgirlHeatDB = CatgirlHeatDB or {}
CatgirlHeatDB.kittens = CatgirlHeatDB.kittens or {}

local function GetBehaviorLog()
    CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}
    return CatgirlBehaviorDB.BehaviorLog[kittyname]
end

local function GetHeatData()
    local data = CatgirlHeatDB.kittens[kittyname]
    if not data then
        data = {}
        CatgirlHeatDB.kittens[kittyname] = data
    end
    if type(data.heat) ~= "number" then
        data.heat = 0
    end
    if type(data.lastUnixUpdate) ~= "number" then
        data.lastUnixUpdate = GetUnixTime()
    end
    if type(data.barPosition) ~= "table" then
        data.barPosition = nil
    end
    if type(data.lastSyncAt) ~= "number" then
        data.lastSyncAt = 0
    end
    if type(data.lastSyncHeat) ~= "number" then
        data.lastSyncHeat = data.heat
    end
    return data
end

local function AutoPrint(...)
    if CCT_AutoPrint then
        CCT_AutoPrint(...)
    else
        print(...)
    end
end

local cfg = CCT_HeatConfig or {}
local heatData = nil
local heatValue = 0
local lastUpdateAt = 0

local decayExponent = 0.7
local decayK = 0.2

local controls = {}
local controlStates = {}
local lastLogIndex = 0

local heatBar = nil
local orgasmFrame = nil

local function ClampNumber(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function GetHeatColor(value)
    local colors = (cfg and cfg.colors) or {}
    local low = colors.low or { 0.0, 0.45, 1.0 }
    local mid = colors.mid or { 1.0, 0.35, 0.75 }
    local high = colors.high or { 1.0, 0.0, 0.0 }
    local pct = ClampNumber(value / 100, 0, 1)
    if pct <= 0.5 then
        local t = pct / 0.5
        return Lerp(low[1], mid[1], t), Lerp(low[2], mid[2], t), Lerp(low[3], mid[3], t)
    end
    local t = (pct - 0.5) / 0.5
    return Lerp(mid[1], high[1], t), Lerp(mid[2], high[2], t), Lerp(mid[3], high[3], t)
end

local function RebuildDecayConstants()
    local ratio = tonumber(cfg.decay and cfg.decay.ratio100to10) or 5
    if ratio <= 1.01 then
        ratio = 1.01
    end
    local exponent = math.log(ratio) / math.log(10)
    if exponent >= 0.999 then
        exponent = 0.999
    end
    local totalSeconds = tonumber(cfg.decay and cfg.decay.totalSeconds) or 1200
    if totalSeconds < 60 then
        totalSeconds = 60
    end
    decayExponent = exponent
    decayK = 100 / (totalSeconds * (1 - decayExponent))
end

local function ApplyDecayExact(value, dt)
    if value <= 0 or dt <= 0 then
        return value
    end
    local u = value / 100
    if decayExponent == 1 then
        local decay = math.exp(-(decayK / 100) * dt)
        return ClampNumber(u * decay * 100, 0, 100)
    end
    local power = u ^ (1 - decayExponent)
    power = power - (decayK / 100) * (1 - decayExponent) * dt
    if power <= 0 then
        return 0
    end
    return ClampNumber((power ^ (1 / (1 - decayExponent))) * 100, 0, 100)
end

local function LogBehaviorEvent(eventName, state)
    table.insert(GetBehaviorLog(), {
        timestamp = date("%Y-%m-%d %H:%M"),
        unixtime = GetUnixTime(),
        event = eventName,
        state = state,
        synced = 0,
    })
end

local function SaveHeatBarPosition()
    if not heatBar or not heatData then
        return
    end
    local point, _, relativePoint, x, y = heatBar:GetPoint(1)
    if point and relativePoint then
        heatData.barPosition = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
end

local function RestoreHeatBarPosition()
    if not heatBar then
        return
    end
    heatBar:ClearAllPoints()
    if heatData and heatData.barPosition then
        local pos = heatData.barPosition
        heatBar:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x or 0, pos.y or 0)
        return
    end
    heatBar:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
end

local function UpdateHeatBar()
    if not heatBar then
        return
    end
    local displayValue = ClampNumber(heatValue, 0, 100)
    heatBar:SetMinMaxValues(0, 100)
    heatBar:SetValue(displayValue)
    local r, g, b = GetHeatColor(displayValue)
    heatBar:SetStatusBarColor(r, g, b)
    if heatBar.text then
        heatBar.text:SetText(string.format("Kitten Heat Bar: %d", math.floor(displayValue + 0.5)))
    end
end

local function ShowOrgasmFlash()
    if not orgasmFrame then
        return
    end
    local texturePath = cfg.orgasm and cfg.orgasm.texture
    if not texturePath or texturePath == "" then
        return
    end
    orgasmFrame.texture:SetTexture(texturePath)
    orgasmFrame:SetAlpha(cfg.orgasm.alpha or 0.9)
    orgasmFrame:Show()
    local hideAt = GetNow() + (cfg.orgasm.flashDuration or 0.6)
    orgasmFrame.hideAt = hideAt
    orgasmFrame:SetScript("OnUpdate", function(self)
        if GetNow() >= (self.hideAt or 0) then
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end)
end

local function TriggerOrgasm()
    ShowOrgasmFlash()
    LogBehaviorEvent("KittenOrgasm", 100)
    heatValue = 0
    if heatData then
        heatData.heat = heatValue
        heatData.lastSyncHeat = heatValue
    end
    LogBehaviorEvent("KittenHeat", 0)
    if heatData then
        heatData.lastSyncAt = GetUnixTime()
    end
    UpdateHeatBar()
end

local function AddHeat(amount)
    if amount <= 0 then
        return
    end
    heatValue = heatValue + amount
    if heatValue >= 100 then
        if CCT_HandleOrgasmAttempt then
            local allowed, newHeat = CCT_HandleOrgasmAttempt(heatValue)
            if allowed == false then
                heatValue = ClampNumber(newHeat or 70, 0, 100)
                if heatData then
                    heatData.heat = heatValue
                    heatData.lastSyncHeat = heatValue
                    heatData.lastSyncAt = GetUnixTime()
                end
                LogBehaviorEvent("KittenHeat", math.floor(heatValue + 0.5))
                UpdateHeatBar()
                return
            end
        end
        TriggerOrgasm()
        return
    end
    heatValue = ClampNumber(heatValue, 0, 100)
    if heatData then
        heatData.heat = heatValue
    end
    UpdateHeatBar()
end

local function MaybeSyncHeat()
    if not heatData then
        return
    end
    local syncInterval = tonumber(cfg.syncIntervalSeconds) or 0
    if syncInterval <= 0 then
        return
    end
    local minDelta = tonumber(cfg.syncMinDelta) or 0
    local nowUnix = GetUnixTime()
    if nowUnix - (heatData.lastSyncAt or 0) < syncInterval
        and math.abs(heatValue - (heatData.lastSyncHeat or 0)) < minDelta then
        return
    end
    LogBehaviorEvent("KittenHeat", math.floor(heatValue + 0.5))
    heatData.lastSyncAt = nowUnix
    heatData.lastSyncHeat = heatValue
end

local function IsValueInList(value, list)
    if type(list) ~= "table" then
        return false
    end
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

local function EvaluateActive(control, value)
    if control.activeWhenTrue then
        return value == true
    end
    if control.activeWhenFalse then
        return value == false
    end
    if control.activeValues then
        return IsValueInList(value, control.activeValues)
    end
    if control.inactiveValues then
        return not IsValueInList(value, control.inactiveValues)
    end
    return value ~= nil
end

local function DeriveActiveFromEntry(control, entry)
    if not entry or not control then
        return nil
    end
    if control.eventActive then
        if entry.event == control.eventActive then
            return true
        end
        if control.eventInactive and entry.event == control.eventInactive then
            return false
        end
    end
    if control.event and entry.event == control.event then
        local value = entry.state
        if control.stateField and entry[control.stateField] ~= nil then
            value = entry[control.stateField]
        end
        return EvaluateActive(control, value)
    end
    return nil
end

local function BuildControlList()
    controls = {}
    local controlDefs = cfg and cfg.controls
    if type(controlDefs) == "table" then
        if #controlDefs > 0 then
            for _, def in ipairs(controlDefs) do
                if type(def) == "table" then
                    local key = def.key or def.label or tostring(#controls + 1)
                    def.key = key
                    table.insert(controls, def)
                end
            end
        else
            for key, def in pairs(controlDefs) do
                if type(def) == "table" then
                    def.key = def.key or key
                    table.insert(controls, def)
                end
            end
        end
    end

    controlStates = {}
    for _, control in ipairs(controls) do
        if control.enabled ~= false then
            controlStates[control.key] = { active = false, elapsed = 0 }
        end
    end
end

local function InitializeControlStates()
    local log = GetBehaviorLog()
    if not log or #controls == 0 then
        lastLogIndex = #log
        return
    end

    local pending = {}
    local pendingCount = 0
    for _, control in ipairs(controls) do
        if controlStates[control.key] then
            pending[control.key] = true
            pendingCount = pendingCount + 1
        end
    end

    for i = #log, 1, -1 do
        local entry = log[i]
        if entry then
            for _, control in ipairs(controls) do
                if pending[control.key] then
                    local active = DeriveActiveFromEntry(control, entry)
                    if active ~= nil then
                        local state = controlStates[control.key]
                        if state then
                            state.active = active
                            state.elapsed = 0
                        end
                        pending[control.key] = nil
                        pendingCount = pendingCount - 1
                        if pendingCount <= 0 then
                            lastLogIndex = #log
                            return
                        end
                    end
                end
            end
        end
    end

    lastLogIndex = #log
end

local function ProcessNewLogEntries()
    local log = GetBehaviorLog()
    if not log or #controls == 0 then
        lastLogIndex = #log
        return
    end
    if #log < lastLogIndex then
        lastLogIndex = 0
    end
    for i = lastLogIndex + 1, #log do
        local entry = log[i]
        if entry then
            for _, control in ipairs(controls) do
                local state = controlStates[control.key]
                if state then
                    local active = DeriveActiveFromEntry(control, entry)
                    if active ~= nil and active ~= state.active then
                        state.active = active
                        state.elapsed = 0
                    end
                end
            end
        end
    end
    lastLogIndex = #log
end

local function ApplyControlHeat(dt)
    for _, control in ipairs(controls) do
        local state = controlStates[control.key]
        if state and state.active and control.enabled ~= false then
            local interval = tonumber(control.intervalSeconds) or 0
            local heat = tonumber(control.heat) or 0
            if interval > 0 and heat ~= 0 then
                state.elapsed = state.elapsed + dt
                while state.elapsed >= interval do
                    state.elapsed = state.elapsed - interval
                    AddHeat(heat)
                end
            end
        end
    end
end

local function BuildHeatBar()
    local width = (cfg.bar and cfg.bar.width) or 240
    local height = (cfg.bar and cfg.bar.height) or 18
    heatBar = CreateFrame("StatusBar", "KittenHeatBar", UIParent, "BackdropTemplate")
    heatBar:SetSize(width, height)
    heatBar:SetStatusBarTexture((cfg.bar and cfg.bar.texture) or "Interface\\TARGETINGFRAME\\UI-StatusBar")
    heatBar:SetMinMaxValues(0, 100)
    heatBar:SetValue(0)
    heatBar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    heatBar:SetBackdropColor(0, 0, 0, 0.6)

    heatBar.text = heatBar:CreateFontString(nil, "OVERLAY", (cfg.bar and cfg.bar.font) or "GameFontHighlightSmall")
    heatBar.text:SetPoint("CENTER")

    heatBar:SetMovable(true)
    heatBar:EnableMouse(true)
    heatBar:RegisterForDrag("LeftButton")
    heatBar:SetScript("OnDragStart", function(self)
        if cfg.bar and cfg.bar.locked then
            return
        end
        self:StartMoving()
    end)
    heatBar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveHeatBarPosition()
    end)

    RestoreHeatBarPosition()
    heatBar:Show()
end

local function BuildOrgasmFrame()
    orgasmFrame = CreateFrame("Frame", "KittenHeatOrgasmFlash", UIParent)
    orgasmFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    orgasmFrame:SetAllPoints(UIParent)
    orgasmFrame:Hide()

    orgasmFrame.texture = orgasmFrame:CreateTexture(nil, "OVERLAY")
    orgasmFrame.texture:SetAllPoints()
end

local function UpdateHeat(dt)
    if dt <= 0 then
        return
    end
    ProcessNewLogEntries()
    ApplyControlHeat(dt)
    heatValue = ApplyDecayExact(heatValue, dt)
    if heatData then
        heatData.heat = heatValue
        heatData.lastUnixUpdate = GetUnixTime()
    end
    UpdateHeatBar()
    MaybeSyncHeat()
end

local function InitializeHeat()
    heatData = GetHeatData()
    cfg = CCT_HeatConfig or cfg
    RebuildDecayConstants()

    BuildControlList()
    InitializeControlStates()

    BuildHeatBar()
    BuildOrgasmFrame()

    local nowUnix = GetUnixTime()
    local offlineDelta = nowUnix - (heatData.lastUnixUpdate or nowUnix)
    if offlineDelta > 0 then
        heatValue = ApplyDecayExact(heatData.heat, offlineDelta)
    else
        heatValue = heatData.heat
    end

    heatValue = ClampNumber(heatValue, 0, 100)
    heatData.heat = heatValue
    heatData.lastUnixUpdate = nowUnix
    lastUpdateAt = GetNow()

    UpdateHeatBar()
    LogBehaviorEvent("KittenHeat", math.floor(heatValue + 0.5))
    heatData.lastSyncAt = GetUnixTime()
    heatData.lastSyncHeat = heatValue

    local updateInterval = tonumber(cfg.updateInterval) or 0.25
    if updateInterval < 0.05 then
        updateInterval = 0.05
    end

    C_Timer.NewTicker(updateInterval, function()
        local now = GetNow()
        local dt = now - lastUpdateAt
        lastUpdateAt = now
        UpdateHeat(dt)
    end)

    AutoPrint("KittenHeat loaded.")
end

function CCT_AddHeat(amount)
    if not heatData then
        return
    end
    local value = tonumber(amount) or 0
    AddHeat(value)
end

function CCT_GetHeat()
    return heatValue
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        InitializeHeat()
    end
end)
