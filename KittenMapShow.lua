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
local lastOffset = nil
local ownerCache = nil
local ownerCacheTime = 0
local ownerOfAnyCache = nil
local ownerOfAnyCacheTime = 0
local MASTER_NAME = "Hollykitten"

local DEFAULT_HISTORY_OFFSET = 0
local MAX_HISTORY_OFFSET = 30
local KITTEN_CACHE_SECONDS = 30
local DEBUG_THROTTLE_SECONDS = 5
local MARKER_TEXTURE = "Interface\\AddOns\\CatgirlTracker\\Textures\\catgirltga32.tga"
local MARKER_SIZE = 16

local function GetHistoryOffsetDays()
    if CatgirlSettingsDB and CatgirlSettingsDB.mapHistoryOffsetDays ~= nil then
        local val = tonumber(CatgirlSettingsDB.mapHistoryOffsetDays)
        if val and val >= 0 then
            return math.min(MAX_HISTORY_OFFSET, math.floor(val + 0.5))
        end
    end
    return DEFAULT_HISTORY_OFFSET
end

local function GetSelectedDayRange()
    local offset = GetHistoryOffsetDays()
    local now = time()
    local day = date("*t", now - (offset * 24 * 60 * 60))
    day.hour = 0
    day.min = 0
    day.sec = 0
    local startTime = time(day)
    local endTime = startTime + 24 * 60 * 60
    return startTime, endTime, offset
end

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

local function GetOwnerFromNote()
    if not IsInGuild() then
        return nil
    end
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note, officerNote = GetGuildRosterInfo(i)
        if name and name:match("^[^%-]+") == playerShortName then
            local source = nil
            if type(officerNote) == "string" and officerNote ~= "" then
                source = officerNote
            elseif type(note) == "string" and note ~= "" then
                source = note
            end
            return source and source:match("owner=([^,]+)") or nil
        end
    end
end

local function IsKittenViewer()
    local now = time()
    if now - ownerCacheTime < 30 then
        return ownerCache ~= nil
    end
    ownerCache = GetOwnerFromNote()
    ownerCacheTime = now
    return ownerCache ~= nil
end

local function IsOwnerViewer()
    local now = time()
    if now - ownerOfAnyCacheTime < 30 then
        return ownerOfAnyCache == true
    end
    ownerOfAnyCache = false
    if IsInGuild() then
        RequestGuildRoster()
        for i = 1, GetNumGuildMembers() do
            local name, _, _, _, _, _, _, note, officerNote = GetGuildRosterInfo(i)
            local source = nil
            if type(officerNote) == "string" and officerNote ~= "" then
                source = officerNote
            elseif type(note) == "string" and note ~= "" then
                source = note
            end
            if source then
                local owner = source:match("owner=([^,]+)")
                if owner and owner:match("^[^%-]+"):lower() == playerShortName:lower() then
                    ownerOfAnyCache = true
                    break
                end
            end
        end
    end
    ownerOfAnyCacheTime = now
    return ownerOfAnyCache == true
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
    overlay:SetFrameStrata("HIGH")
    overlay.markers = {}
    overlay.markerHovers = {}
    overlay:SetFrameLevel(canvas:GetFrameLevel() + 5)
    return overlay
end

local function HideUnused(list, startIndex)
    for i = startIndex, #list do
        list[i]:Hide()
    end
end

local function AcquireMarker(index)
    local marker = overlay.markers[index]
    if not marker then
        marker = overlay:CreateTexture(nil, "ARTWORK")
        marker:SetSize(MARKER_SIZE, MARKER_SIZE)
        marker:SetTexture(MARKER_TEXTURE)
        marker:SetDrawLayer("OVERLAY", 2)
        marker:SetAlpha(0.85)
        marker:SetBlendMode("BLEND")
        overlay.markers[index] = marker
    end
    marker:Show()
    return marker
end

local function AcquireMarkerHover(index)
    local hover = overlay.markerHovers[index]
    if not hover then
    hover = CreateFrame("Frame", nil, overlay)
    hover:EnableMouse(true)
    hover:SetFrameLevel(overlay:GetFrameLevel() + 10)
        hover:SetScript("OnEnter", function(self)
            if not GameTooltip or not self.timestamp then return end
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(self.timestamp)
            GameTooltip:Show()
        end)
        hover:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
        overlay.markerHovers[index] = hover
    end
    hover:Show()
    return hover
end

local function BuildMarkers(mapID, kittenKey, log)
    if not mapID then return end
    local canvas = EnsureOverlay()
    if not canvas then return end

    if not log or #log == 0 then
        HideUnused(overlay.markers, 1)
        HideUnused(overlay.markerHovers, 1)
        overlay:Hide()
        DebugPrint("No location log for:", kittenKey)
        return
    end

    local width = overlay:GetWidth()
    local height = overlay:GetHeight()
    if width <= 0 or height <= 0 then
        HideUnused(overlay.markers, 1)
        HideUnused(overlay.markerHovers, 1)
        return
    end

    local dayStart, dayEnd = GetSelectedDayRange()
    local markerIndex = 0
    local fallbackCount = 0

    local function IsDescendant(parentID, childID)
        if not parentID or not childID or not C_Map or not C_Map.GetMapInfo then
            return false
        end
        local current = childID
        local guard = 0
        while current and guard < 20 do
            if current == parentID then
                return true
            end
            local info = C_Map.GetMapInfo(current)
            current = info and info.parentMapID
            guard = guard + 1
        end
        return false
    end

    local function GetEntryMapPos(entry)
        if entry.mapID == mapID then
            return entry.x, entry.y
        end
        if C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D then
            local a, b = C_Map.GetWorldPosFromMapPos(entry.mapID, CreateVector2D(entry.x, entry.y))
            local worldPos = nil
            local continentID = nil
            if type(a) == "userdata" then
                worldPos = a
                continentID = b
            elseif type(b) == "userdata" then
                worldPos = b
                continentID = a
            end
            if worldPos then
                local uiMapID, mapPos = nil, nil
                if continentID then
                    uiMapID, mapPos = C_Map.GetMapPosFromWorldPos(continentID, worldPos, mapID)
                else
                    uiMapID, mapPos = C_Map.GetMapPosFromWorldPos(mapID, worldPos)
                end
                if not mapPos and uiMapID and type(uiMapID) == "userdata" then
                    mapPos = uiMapID
                end
                if mapPos then
                    local x, y = mapPos.x, mapPos.y
                    if mapPos.GetXY then
                        x, y = mapPos:GetXY()
                    end
                    return x, y
                end
            end
        end
    end

    for i = 1, #log do
        local entry = log[i]
        local entryTime = entry and (entry.unixtime or entry.receivedAt) or nil
        if entry
            and entry.x and entry.y
            and entryTime
            and entryTime >= dayStart
            and entryTime < dayEnd then
            local mapX, mapY = GetEntryMapPos(entry)
            if mapX and mapY and mapX >= 0 and mapX <= 1 and mapY >= 0 and mapY <= 1 then
                markerIndex = markerIndex + 1
                local marker = AcquireMarker(markerIndex)
                local x = mapX * width
                local y = mapY * height
                marker:ClearAllPoints()
                marker:SetPoint("CENTER", overlay, "TOPLEFT", x, -y)

                local hover = AcquireMarkerHover(markerIndex)
                hover:ClearAllPoints()
                hover:SetPoint("CENTER", marker, "CENTER")
                hover:SetSize(MARKER_SIZE + 4, MARKER_SIZE + 4)
                  hover.timestamp = entry.timestamp
                      or (entry.unixtime and date("%Y-%m-%d %H:%M:%S", entry.unixtime))
                      or "Unknown time"
            else
                if IsDescendant(mapID, entry.mapID) then
                    fallbackCount = fallbackCount + 1
                end
            end
        end
    end

    if markerIndex == 0 and fallbackCount > 0 then
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        local mapType = info and info.mapType or nil
        if mapType and mapType <= 2 then
            markerIndex = 1
            local marker = AcquireMarker(markerIndex)
            marker:ClearAllPoints()
            marker:SetPoint("CENTER", overlay, "TOPLEFT", width * 0.5, -height * 0.5)

            local hover = AcquireMarkerHover(markerIndex)
            hover:ClearAllPoints()
            hover:SetPoint("CENTER", marker, "CENTER")
            hover:SetSize(MARKER_SIZE + 6, MARKER_SIZE + 6)
            local dayLabel = date("%Y-%m-%d", dayStart)
            hover.timestamp = string.format("%s (%d entries)", dayLabel, fallbackCount)
        end
    end

    HideUnused(overlay.markers, markerIndex + 1)
    HideUnused(overlay.markerHovers, markerIndex + 1)
    if markerIndex > 0 then
        overlay:Show()
    else
        overlay:Hide()
        DebugPrint("No matching points for map:", tostring(mapID))
    end
end

local function HideOverlay()
    if overlay then
        overlay:Hide()
        HideUnused(overlay.markers, 1)
        HideUnused(overlay.markerHovers, 1)
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
    local isMaster = playerShortName and MASTER_NAME and playerShortName:lower() == MASTER_NAME:lower()
    if IsKittenViewer() and not IsOwnerViewer() and not isMaster then
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
    local _, _, offset = GetSelectedDayRange()
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
    if force or mapID ~= lastMapID or kittenKey ~= lastKitten or stamp ~= lastStamp or offset ~= lastOffset then
        lastMapID = mapID
        lastKitten = kittenKey
        lastStamp = stamp
        lastOffset = offset
        local now = time()
        if now - lastDebug > DEBUG_THROTTLE_SECONDS then
            DebugPrint("Refresh:", "mapID=" .. tostring(mapID), "kitten=" .. tostring(kittenKey), "stamp=" .. tostring(stamp))
            lastDebug = now
        end
        BuildMarkers(mapID, kittenKey, log)
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
