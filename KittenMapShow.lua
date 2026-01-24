local playerShortName = UnitName("player"):match("^[^%-]+")
local overlay = nil
local mapHooked = false
local refreshTicker = nil
local lastMapID = nil
local lastKitten = nil
local lastStamp = nil
local cachedKittenKey = nil
local lastKittenUpdate = 0
local lastDebug = 0

local MAX_AGE_SECONDS = 7 * 24 * 60 * 60
local KITTEN_CACHE_SECONDS = 30
local DEBUG_THROTTLE_SECONDS = 5

local function DebugPrint(...)
    if CCT_AutoPrint then
        CCT_AutoPrint("|cff88ff88[KittenMapShow]|r", ...)
    end
end

local function IsEnabled()
    if CCT_IsModuleEnabled then
        return CCT_IsModuleEnabled("KittenMapShow")
    end
    return false
end

local function RequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function ShortName(name)
    if not name then return name end
    return name:match("^[^%-]+")
end

local function GetAssignedCatgirl()
    if not IsInGuild() then
        return nil
    end
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, officerNote = GetGuildRosterInfo(i)
        if name and officerNote then
            local ownerName = officerNote:match("owner=([^,]+)")
            if ownerName and ShortName(ownerName) == playerShortName then
                return name
            end
        end
    end
    return nil
end

local function GetTrackedKittenKey()
    local now = time()
    if cachedKittenKey and (now - lastKittenUpdate) < KITTEN_CACHE_SECONDS then
        return cachedKittenKey
    end
    local assigned = GetAssignedCatgirl()
    if assigned then
        cachedKittenKey = ShortName(assigned)
    else
        cachedKittenKey = playerShortName
    end
    lastKittenUpdate = now
    return cachedKittenKey
end

local function GetMapCanvas()
    if not WorldMapFrame then return nil end
    if WorldMapFrame.ScrollContainer then
        if WorldMapFrame.ScrollContainer.Child then
            return WorldMapFrame.ScrollContainer.Child
        end
        if WorldMapFrame.ScrollContainer.GetCanvas then
            return WorldMapFrame.ScrollContainer:GetCanvas()
        end
    end
    return WorldMapFrame
end

local function GetCurrentMapID()
    if not WorldMapFrame then return nil end
    if WorldMapFrame.GetMapID then
        return WorldMapFrame:GetMapID()
    end
    return WorldMapFrame.mapID
end

local function EnsureOverlay()
    local canvas = GetMapCanvas()
    if not canvas then return nil end
    if overlay and overlay:GetParent() == canvas then
        return overlay
    end

    overlay = CreateFrame("Frame", nil, canvas)
    overlay:SetAllPoints(canvas)
    overlay.marker = overlay:CreateTexture(nil, "ARTWORK")
    overlay.marker:SetSize(16, 16)
    overlay.marker:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    overlay.marker:Hide()
    overlay.marker.timestamp = nil

    overlay.hover = CreateFrame("Frame", nil, overlay)
    overlay.hover:EnableMouse(true)
    overlay.hover:SetFrameLevel(overlay:GetFrameLevel() + 1)
    overlay.hover:SetScript("OnEnter", function(self)
        if not GameTooltip or not self.timestamp then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(self.timestamp)
        GameTooltip:Show()
    end)
    overlay.hover:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    overlay.hover:Hide()
    overlay:SetFrameLevel(canvas:GetFrameLevel() + 5)
    return overlay
end

local function BuildMarker(mapID, kittenKey, latestEntry)
    if not mapID then return end
    local canvas = EnsureOverlay()
    if not canvas then return end

    if not latestEntry then
        overlay.marker:Hide()
        overlay.hover:Hide()
        DebugPrint("No location log for:", kittenKey)
        return
    end

    if latestEntry.mapID ~= mapID then
        overlay.marker:Hide()
        overlay.hover:Hide()
        overlay:Hide()
        DebugPrint("Latest entry is on another map:", tostring(latestEntry.mapID))
        return
    end

    local width = overlay:GetWidth()
    local height = overlay:GetHeight()
    if width <= 0 or height <= 0 then
        overlay.marker:Hide()
        overlay.hover:Hide()
        return
    end

    local cutoff = time() - MAX_AGE_SECONDS
    local entryTime = latestEntry.unixtime or latestEntry.receivedAt
    if not entryTime or entryTime < cutoff or not latestEntry.x or not latestEntry.y then
        overlay.marker:Hide()
        overlay.hover:Hide()
        overlay:Hide()
        DebugPrint("Latest entry is out of range or missing coords.")
        return
    end

    local x = latestEntry.x * width
    local y = latestEntry.y * height
    overlay:Show()
    overlay.marker:ClearAllPoints()
    overlay.marker:SetPoint("CENTER", overlay, "TOPLEFT", x, -y)
    overlay.marker:Show()

    overlay.hover:ClearAllPoints()
    overlay.hover:SetPoint("CENTER", overlay.marker, "CENTER")
    overlay.hover:SetSize(20, 20)
    overlay.hover.timestamp = latestEntry.timestamp
        or (latestEntry.unixtime and date("%Y-%m-%d %H:%M:%S", latestEntry.unixtime))
        or "Unknown time"
    overlay.hover:Show()
    DebugPrint("Rendered marker:", "mapID=" .. tostring(mapID), "x=" .. tostring(latestEntry.x), "y=" .. tostring(latestEntry.y))
end

local function HideOverlay()
    if overlay then
        overlay:Hide()
    end
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function RefreshIfNeeded(force)
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        return
    end
    if not IsEnabled() then
        HideOverlay()
        return
    end
    local mapID = GetCurrentMapID()
    local kittenKey = GetTrackedKittenKey()
    local log = CatgirlLocationDB
        and CatgirlLocationDB.LocationLog
        and CatgirlLocationDB.LocationLog[kittenKey]
    local stamp = nil
    local latestEntry = nil
    if log and #log > 0 then
        local bestTime = nil
        local bestReceived = nil
        for i = 1, #log do
            local entry = log[i]
            if entry and (entry.unixtime or entry.receivedAt) then
                local entryTime = entry.unixtime or entry.receivedAt
                local received = entry.receivedAt or entryTime
                if not bestTime
                    or entryTime > bestTime
                    or (entryTime == bestTime and received > (bestReceived or 0)) then
                    bestTime = entryTime
                    bestReceived = received
                    latestEntry = entry
                end
            end
        end
        stamp = latestEntry and (latestEntry.unixtime or latestEntry.receivedAt) or nil
    end
    if force or mapID ~= lastMapID or kittenKey ~= lastKitten or stamp ~= lastStamp then
        lastMapID = mapID
        lastKitten = kittenKey
        lastStamp = stamp
        local now = time()
        if now - lastDebug > DEBUG_THROTTLE_SECONDS then
            DebugPrint("Refresh:", "mapID=" .. tostring(mapID), "kitten=" .. tostring(kittenKey), "stamp=" .. tostring(stamp))
            lastDebug = now
        end
        BuildMarker(mapID, kittenKey, latestEntry)
    end
end

local function StartRefreshLoop()
    if refreshTicker then return end
    refreshTicker = C_Timer.NewTicker(1, function()
        if not WorldMapFrame or not WorldMapFrame:IsShown() then
            return
        end
        RefreshIfNeeded(false)
    end)
end

local function StopRefreshLoop()
    if refreshTicker then
        refreshTicker:Cancel()
        refreshTicker = nil
    end
end

local function HookWorldMap()
    if mapHooked then return end
    if not WorldMapFrame then return end
    mapHooked = true
    WorldMapFrame:HookScript("OnShow", function()
        StartRefreshLoop()
        RefreshIfNeeded(true)
    end)
    WorldMapFrame:HookScript("OnHide", function()
        StopRefreshLoop()
        HideOverlay()
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    HookWorldMap()
    if CCT_RegisterModuleWatcher then
        CCT_RegisterModuleWatcher("KittenMapShow", function(enabled)
            if enabled then
                RefreshIfNeeded(true)
            else
                HideOverlay()
            end
        end)
    end
end)

CCT_AutoPrint("KittenMapShow loaded.")
